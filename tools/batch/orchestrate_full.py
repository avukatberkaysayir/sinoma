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

# 1b) Never proceed while the split is still (re)processing: its DB-wide dedup
# (_drop_text_duplicates) deletes pending clips out from under us. Gate on job
# state (2026-07-15: a stalled split the guard skipped past kept running and a
# watchdog requeue re-ran it, deleting 8 clips mid-run).
#
# Orphan watchdog: a split can finish producing clips yet leave its job stuck at
# 'processing' (seen on a 4-hour video, 2026-07-23) — no ffmpeg alive, last clip
# an hour ago, job never marked done. Then this gate would wait its whole budget
# for nothing. So if the pending count hasn't moved for 15 min, treat the job as
# orphaned, mark it done and go on — the split really is finished.
stuck_since = None
last_pending = None
for _ in range(90):
    try:
        busy = sql("select count(*) as n from pipeline_jobs where "
                   "job_type='youtube_asr' and status in ('pending','processing');"
                   )[0]["n"]
        pend = sql("select count(*) as n from videos where status='pending';")[0]["n"]
    except RuntimeError:
        time.sleep(60)
        continue
    if not busy:
        break
    if pend == last_pending:
        if stuck_since is None:
            stuck_since = time.time()
        elif time.time() - stuck_since > 900:   # 15 min with no new clip
            closed = sql("update pipeline_jobs set status='done' where "
                         "job_type='youtube_asr' and status='processing' and "
                         "created_at < now() - interval '20 minutes' returning id;")
            print(f"  oksuz bolme isi kapatildi ({len(closed)}) — 15 dk klip yok, "
                  "parcalama bitmis sayiliyor", flush=True)
            break
    else:
        stuck_since = None
        last_pending = pend
    print(f"  split hala aktif ({busy}) — bekleniyor (dedup yarisini onlemek icin)",
          flush=True)
    time.sleep(60)

# Which video did this run integrate?
new_vid = None
try:
    import re
    row = sql("select payload->>'url' as url from pipeline_jobs "
              "where job_type='youtube_asr' order by created_at desc limit 1;")
    m = re.search(r"v=([\w-]+)", row[0]["url"]) if row else None
    new_vid = m.group(1) if m else None
except Exception:
    pass

# 1c) English burned-in subtitles → delete those clips FIRST, per clip, before any
# Whisper/quiz work is spent on them (Berkay 2026-07-23: scan then integrate). A
# caption can be English in one stretch and Chinese in another, so each clip is
# judged on its own [start,end]; only the English ones go, at every HSK level.
if new_vid:
    print("\n— Ingilizce gomulu altyazi filtresi (klip-bazi, HSK 1-4, entegrasyondan ONCE) —\n",
          flush=True)
    try:
        # HSK 1-4 only — the clips this run integrates. HSK 5-6 stays raw and is
        # scanned when it is later integrated, so a 4-hour video isn't thousands
        # of extra downloads here.
        subprocess.run([sys.executable, "-u", "eng_scan.py", new_vid],
                       cwd=SCRATCH, timeout=10800,
                       env={**os.environ, "ENG_HSK_MAX": "4"})
    except Exception as e:
        print(f"  Ingilizce filtresi atlandi: {e}", flush=True)

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

# 4) Approve batch (includes auto-define of unknown words).
print("\n— toplu akis basliyor —\n", flush=True)
r = subprocess.run([sys.executable, "-u", "batch_whisper_approve.py"], cwd=SCRATCH)

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
