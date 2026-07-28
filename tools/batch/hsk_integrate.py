# -*- coding: utf-8 -*-
"""Integrate N pending clips of one HSK level, with the full modern treatment.

Berkay's model, applied to a level's Onay Bekleyen backlog: scan then integrate.
Pick the oldest N non-backup pending clips of the level ONCE, then run every step
on that exact set:
  1) English burned-in subtitle filter (per clip) — delete the English ones
  2) fresh per-clip Whisper on the survivors
  3) approve batch (slot/criterion re-derive → 12-lang quiz → Diğer → activate)
  4) homophone fix from the burned-in Chinese subtitle

Fixing the set once (not "oldest N" per step) keeps the English filter and the
batch acting on the same rows — no clip slips in un-scanned.

  python tools/batch/hsk_integrate.py <level> <count>     # e.g. 5 50
"""
import json, os, subprocess, sys, time, pathlib, requests
sys.stdout.reconfigure(encoding="utf-8")
HERE = pathlib.Path(__file__).resolve().parent
PY = sys.executable
LEVEL = int(sys.argv[1]) if len(sys.argv) > 1 else 5
COUNT = int(sys.argv[2]) if len(sys.argv) > 2 else 50

env = pathlib.Path(HERE.parents[1] / ".deploy.env").read_text(encoding="utf-8")
tok = [l.split("=", 1)[1].strip().strip('"') for l in env.splitlines()
       if l.startswith("SUPABASE_ACCESS_TOKEN")][0]


def sql(q, tries=6):
    for n in range(tries):
        try:
            d = requests.post(
                "https://api.supabase.com/v1/projects/pqyceostpukueydwuiut/database/query",
                headers={"Authorization": f"Bearer {tok}"}, json={"query": q},
                timeout=90).json()
            if isinstance(d, list):
                return d
        except Exception:
            pass
        time.sleep(min(15 * (n + 1), 90))
    raise SystemExit("SQL failed")


def lit(s):
    return "'" + str(s).replace("'", "''") + "'"


# Never run while a split is (re)processing — its dedup would delete rows here.
for _ in range(35):
    busy = sql("select count(*) as n from pipeline_jobs where job_type='youtube_asr' "
               "and status in ('pending','processing');")[0]["n"]
    if not busy:
        break
    print(f"  split aktif ({busy}) — bekleniyor", flush=True)
    time.sleep(60)

# 0) Pick the oldest COUNT non-backup pending clips of the level, ONCE.
rows = sql(f"""select id from videos
  where status='pending' and backup_kind is null and backup_level is null
    and hsk_level={LEVEL}
  order by created_at limit {COUNT};""")
ids = [r["id"] for r in rows]
if not ids:
    print(f"HSK-{LEVEL}: islenecek pending klip yok")
    sys.exit(0)
idfile = HERE / f"hsk{LEVEL}_ids.json"
json.dump(ids, open(idfile, "w"))
print(f"HSK-{LEVEL}: {len(ids)} klip secildi", flush=True)

# 1) English filter on exactly these clips.
print(f"\n— 1) Ingilizce eleme (HSK {LEVEL}, {len(ids)} klip) —", flush=True)
subprocess.run([PY, "-u", "eng_scan.py"], cwd=str(HERE),
               env={**os.environ, "ENG_ONLY_IDS": str(idfile)})

# Survivors (the English ones are gone).
alive = sql(f"select id from videos where id in ({','.join(lit(i) for i in ids)});")
surv = [r["id"] for r in alive]
print(f"  Ingilizce eleme sonrasi kalan: {len(surv)}/{len(ids)}", flush=True)
if not surv:
    print("hepsi elendi — cikiliyor")
    sys.exit(0)
survfile = HERE / f"hsk{LEVEL}_surv.json"
json.dump(surv, open(survfile, "w"))

# 2) Fresh per-clip Whisper on the survivors.
print(f"\n— 2) taze whisper ({len(surv)} klip) —", flush=True)
sql(f"""insert into pipeline_jobs (job_type, status, payload)
  select 'whisper_clip','pending', jsonb_build_object(
    'url','https://www.youtube.com/watch?v='||youtube_id,
    'start',start_time,'end',end_time,'row_id',id)
  from videos where id in ({','.join(lit(i) for i in surv)});""")
last, since = None, time.time()
while True:
    n = sql("select count(*) as n from pipeline_jobs where job_type='whisper_clip' "
            "and status in ('pending','processing') and created_at > now() - interval '3 hours';")[0]["n"]
    if n == 0:
        print("  whisper bitti", flush=True); break
    if n != last:
        last, since = n, time.time(); print(f"  kalan: {n}", flush=True)
    elif time.time() - since > 1500:
        print("  STALL 25 dk — devam", flush=True); break
    time.sleep(60)

# 3) Approve batch on exactly the survivors (HSK level range = the level).
print(f"\n— 3) toplu akis (HSK {LEVEL}) —", flush=True)
subprocess.run([PY, "-u", "batch_whisper_approve.py", str(LEVEL), str(LEVEL)],
               cwd=str(HERE), env={**os.environ, "ONLY_IDS": str(survfile)})

# 4) Homophone fix (ocr_scan resumes; ocr_apply is idempotent).
print("\n— 4) OCR homofon duzeltmesi —", flush=True)
try:
    subprocess.run([PY, "-u", "ocr_scan.py"], cwd=str(HERE), timeout=7200)
    subprocess.run([PY, "-u", "ocr_apply.py"], cwd=str(HERE), timeout=7200)
except Exception as e:
    print(f"  OCR adimi atlandi: {e}", flush=True)

print(f"\n=== HSK-{LEVEL} ENTEGRASYON BITTI ===")
