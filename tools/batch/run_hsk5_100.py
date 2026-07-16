# One-off: fresh per-clip Whisper on 100 pending, non-backup HSK-5 clips, then
# the full HSK 1-4 treatment (apply Whisper → re-derive slot → Diğer words →
# EN+11-lang quiz → activate; slot conflicts stay pending with their backup
# mark). Berkay 2026-07-15: "taze whisper kullan".
#
#   python tools/batch/run_hsk5_100.py [count]     # default 100
#
# The 100 are the OLDEST HSK-5 pending non-backup clips (deterministic
# created_at order) so this whisper selection and the batch's `limit` pick the
# exact same rows. Only run with the worker idle and NO split in flight.
import os, subprocess, sys, time, requests

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = "pqyceostpukueydwuiut"
HERE = os.path.dirname(os.path.abspath(__file__))
COUNT = int(sys.argv[1]) if len(sys.argv) > 1 else 100

tok = None
with open(r"d:\Masaustu\github\Kandao\.deploy.env", encoding="utf-8") as f:
    for line in f:
        if line.startswith("SUPABASE_ACCESS_TOKEN="):
            tok = line.split("=", 1)[1].strip()


def sql(query, tries=6):
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


# Safety: never start while a split is (re)processing — its DB-wide dedup would
# delete pending clips out from under us (same race the HSK 1-4 gate prevents).
for _ in range(35):
    busy = sql("select count(*) as n from pipeline_jobs where "
               "job_type='youtube_asr' and status in ('pending','processing');"
               )[0]["n"]
    if not busy:
        break
    print(f"  split aktif ({busy}) — bekliyor…", flush=True)
    time.sleep(60)

# 1) Queue FRESH whisper for the oldest COUNT HSK-5 pending non-backup clips.
#    (They already carry split-ASR whisper_text; transcribe_clip overwrites it
#    with a sharper per-clip pass.)
queued = sql(f"""
insert into pipeline_jobs (job_type, status, payload)
select 'whisper_clip', 'pending',
       jsonb_build_object(
         'url', 'https://www.youtube.com/watch?v=' || youtube_id,
         'start', start_time, 'end', end_time, 'row_id', id)
from (
  select id, youtube_id, start_time, end_time
  from videos
  where status='pending' and backup_kind is null and backup_level is null
    and hsk_level = 5
  order by created_at
  limit {COUNT}
) t
returning id;
""")
job_ids = [r["id"] for r in queued]
print(f"{len(job_ids)} taze whisper isi kuyruga yazildi", flush=True)
if not job_ids:
    print("islenecek HSK-5 klip yok — cikiliyor")
    sys.exit(0)

# 2) Wait until every queued whisper job is done/error (stall guard 25 dk).
id_list = ",".join(f"'{j}'" for j in job_ids)
last_n, last_change = len(job_ids), time.time()
print(f"whisper bekleniyor: {last_n} is", flush=True)
while True:
    left = sql(f"select count(*) as n from pipeline_jobs where id in ({id_list}) "
               f"and status not in ('done','error');")[0]["n"]
    if left == 0:
        print("  tum whisper isleri bitti", flush=True)
        break
    if left != last_n:
        last_n, last_change = left, time.time()
        print(f"  kalan: {left}", flush=True)
    elif time.time() - last_change > 1500:
        print(f"  STALL: 25 dk ilerleme yok, {left} eksikle devam", flush=True)
        break
    time.sleep(30)

# 3) Full batch on exactly these HSK-5 clips (same oldest-COUNT ordering).
print("\n— HSK-5 toplu akis basliyor —\n", flush=True)
r = subprocess.run([sys.executable, "-u", "batch_whisper_approve.py",
                    "5", "5", str(COUNT)], cwd=HERE)
sys.exit(r.returncode)
