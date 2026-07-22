# Full chain for a freshly submitted video:
#   1) wait for the youtube_asr split job to finish (stall guard 25 dk),
#   2) enqueue whisper_clip jobs for pending clips missing whisper_text,
#   3) wait until they are filled (stall guard 20 dk),
#   4) run the approve batch (Whisper apply + words + pinyin + placement +
#      EN-pivot 12-language quiz + approve + auto-define unknown words;
#      slot-conflict clips stay pending with their backup mark).
import os, subprocess, sys, time, requests

sys.stdout.reconfigure(encoding="utf-8")

PROJECT = "pqyceostpukueydwuiut"
SCRATCH = os.path.dirname(os.path.abspath(__file__))

tok = None
with open(r"d:\Masaustu\github\Kandao\.deploy.env", encoding="utf-8") as f:
    for line in f:
        if line.startswith("SUPABASE_ACCESS_TOKEN="):
            tok = line.split("=", 1)[1].strip()


def sql(query, tries=6):
    # 6 deneme + artan bekleme: Management API'nin dakikalarca süren kesintileri
    # (RemoteDisconnected) saatlik zinciri bir kez öldürmüştü (2026-07-13).
    for attempt in range(tries):
        try:
            r = requests.post(
                f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
                headers={"Authorization": f"Bearer {tok}"},
                json={"query": query}, timeout=60)
            data = r.json()
            if isinstance(data, list):
                return data
        except (requests.RequestException, ValueError):
            pass
        time.sleep(min(10 * (attempt + 1), 60))
    raise RuntimeError("sql failed")


# 1) Split job (pending count is the progress signal; result arrives at end).
# Bekleme döngüsü API kesintisinde ASLA ölmez — o turu atlar.
print("bolme isi bekleniyor…", flush=True)
last_n, last_change = -1, time.time()
while True:
    try:
        st = sql("select status from pipeline_jobs where job_type='youtube_asr' "
                 "order by created_at desc limit 1;")[0]["status"]
        n = sql("select count(*) as n from videos where status='pending';")[0]["n"]
    except RuntimeError:
        print("  API kesintisi — 2 dk sonra tekrar", flush=True)
        time.sleep(120)
        continue
    if n != last_n:
        last_n, last_change = n, time.time()
        print(f"  pending klip: {n} (is: {st})", flush=True)
    if st in ("done", "error"):
        print(f"  bolme isi: {st}", flush=True)
        break
    if time.time() - last_change > 1500:
        print("  STALL: 25 dk ilerleme yok, eldekilerle devam", flush=True)
        break
    time.sleep(60)

# 2) Whisper jobs for clips missing whisper_text — HSK 1-4 only (Berkay'ın
# önceliği); HSK 5-6 klipler beklemede dokunulmadan kalır, istenirse sonra.
queued = sql("""
insert into pipeline_jobs (job_type, status, payload)
select 'whisper_clip', 'pending',
       jsonb_build_object(
         'url', 'https://www.youtube.com/watch?v=' || youtube_id,
         'start', start_time, 'end', end_time, 'row_id', id)
from videos
where status='pending' and coalesce(whisper_text,'') = ''
  and hsk_level between 1 and 4
order by hsk_level, created_at
returning id;
""")
print(f"\n{len(queued)} whisper isi kuyruga yazildi", flush=True)

# 3) Wait for fill.
if queued:
    def missing():
        return sql("select count(*) as n from videos where status='pending' "
                   "and coalesce(whisper_text,'')='' "
                   "and hsk_level between 1 and 4;")[0]["n"]
    last_n, last_change = missing(), time.time()
    print(f"whisper bekleniyor: {last_n} eksik", flush=True)
    while last_n > 0:
        time.sleep(60)
        n = missing()
        if n != last_n:
            last_n, last_change = n, time.time()
            print(f"  kalan: {n}", flush=True)
        elif time.time() - last_change > 1200:
            print(f"  STALL: 20 dk ilerleme yok, {n} eksikle devam", flush=True)
            break

# 3b) Never start the batch while a split is still (re)processing: the split's
# DB-wide dedup (_drop_text_duplicates) deletes pending clips out from under the
# batch's SELECT — the row vanishes before its UPDATE and the clip is lost
# (2026-07-15: a stalled split that the 25-min guard skipped past kept running,
# and a watchdog requeue re-ran it during the batch → 8 clips deleted mid-run).
# The stall guard above can fire while the split is merely plateaued in its
# final dedup/coherence phase, so gate explicitly on job state here.
for _ in range(35):
    try:
        busy = sql("select count(*) as n from pipeline_jobs where "
                   "job_type='youtube_asr' and status in ('pending','processing');"
                   )[0]["n"]
    except RuntimeError:
        time.sleep(60)
        continue
    if not busy:
        break
    print(f"  split hala aktif ({busy}) — batch bekliyor (dedup yarisini onlemek icin)",
          flush=True)
    time.sleep(60)

# 4) Approve batch (includes auto-define of unknown words).
print("\n— toplu akis basliyor —\n", flush=True)
r = subprocess.run([sys.executable, "-u", "batch_whisper_approve.py"], cwd=SCRATCH)

# Which video did this run integrate? (for the per-video OCR steps below)
new_vid = None
try:
    import re
    row = sql("select payload->>'url' as url from pipeline_jobs "
              "where job_type='youtube_asr' order by created_at desc limit 1;")
    m = re.search(r"v=([\w-]+)", row[0]["url"]) if row else None
    new_vid = m.group(1) if m else None
except Exception:
    pass

# 5) English burned-in subtitles → delete those clips, PER CLIP. A caption can be
# English in one part of a video and Chinese in another, so each clip is judged on
# its own [start,end]; only the English ones go. Runs before the homophone fix so
# a clip about to be deleted isn't corrected first.
if new_vid:
    print("\n— Ingilizce gomulu altyazi filtresi (klip-bazi) —\n", flush=True)
    try:
        subprocess.run([sys.executable, "-u", "eng_scan.py", new_vid],
                       cwd=SCRATCH, timeout=7200)
    except Exception as e:
        print(f"  Ingilizce filtresi atlandi: {e}", flush=True)

# 6) Burned-in-subtitle homophone fix for the clips this run just activated.
# ocr_scan resumes from its checkpoint (ocr_scan_done.json), so it downloads and
# OCRs only videos it hasn't seen — i.e. this run's — then ocr_apply corrects any
# clip whose Whisper text disagrees with the on-screen caption and re-derives it.
# A failure here must not fail the integration: the clips are already live and
# correct enough; the fix is an enhancement. So the batch's exit code is what we
# return, and OCR problems are logged, not fatal.
print("\n— OCR altyazi homofon duzeltmesi —\n", flush=True)
try:
    subprocess.run([sys.executable, "-u", "ocr_scan.py"], cwd=SCRATCH, timeout=7200)
    subprocess.run([sys.executable, "-u", "ocr_apply.py"], cwd=SCRATCH, timeout=7200)
except Exception as e:
    print(f"  OCR adimi atlandi (hatasiz devam): {e}", flush=True)

sys.exit(r.returncode)
