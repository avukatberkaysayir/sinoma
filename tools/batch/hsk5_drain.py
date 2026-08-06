# -*- coding: utf-8 -*-
"""Resilient, resumable driver: finish ALL HSK-5 non-backup pending in 100-clip
parts, non-stop, surviving crashes / reboots / network drops.

Why it's safe against data loss:
  Every completed clip is written to Supabase (cloud) per-clip and atomically by
  batch_whisper_approve (whisper_text -> quiz -> activate). The DB is the single
  source of truth, so a crash loses AT MOST the one in-flight clip; everything
  finished is already persisted remotely. Re-running this driver resumes from the
  DB state — hsk_integrate re-selects the oldest pending and skips done work
  ("bitmis, atlandi"), so it is fully idempotent.

Resilience layers:
  1. Per-clip cloud persistence (above)          -> no lost work
  2. PID lockfile                                 -> never two drivers at once
  3. ensure_worker(): restarts dev_server if down -> whisper keeps flowing
  4. Robust SQL retry/backoff                     -> survives network blips
  5. Append-only progress log (JSONL)             -> audit + external resume
  6. Stall guard                                  -> stops at the irreducible
     (whisperless) tail instead of spinning forever
  A logon Scheduled Task (Sinoma_HSK5_Drain) relaunches this after a reboot.

  python tools/batch/hsk5_drain.py            # drains until pool empty or stalls
"""
import json, os, subprocess, sys, time, pathlib, requests
sys.stdout.reconfigure(encoding="utf-8")
HERE = pathlib.Path(__file__).resolve().parent
PY = sys.executable
LEVEL = 5
PROJECT = "pqyceostpukueydwuiut"
PROG = HERE / "hsk5_drain_progress.jsonl"
LOCK = HERE / "hsk5_drain.lock"

env = pathlib.Path(HERE.parents[1] / ".deploy.env").read_text(encoding="utf-8")
tok = [l.split("=", 1)[1].strip().strip('"') for l in env.splitlines()
       if l.startswith("SUPABASE_ACCESS_TOKEN")][0]


def sql(q, tries=10):
    for n in range(tries):
        try:
            d = requests.post(
                f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
                headers={"Authorization": f"Bearer {tok}"}, json={"query": q},
                timeout=90).json()
            if isinstance(d, list):
                return d
        except Exception:
            pass
        time.sleep(min(20 * (n + 1), 120))
    raise SystemExit("SQL kalici sekilde basarisiz")


def pool():
    return sql(f"select count(*) as n from videos where hsk_level={LEVEL} "
               f"and status='pending' and backup_kind is null "
               f"and backup_level is null;")[0]["n"]


def worker_up():
    try:
        return requests.get("http://localhost:9302/health", timeout=5).status_code == 200
    except Exception:
        return False


def ensure_worker():
    if worker_up():
        return
    dev = HERE.parents[1] / "python" / "pipeline" / "dev_server.py"
    logf = open(r"d:/tmp/dev_server.log", "a", encoding="utf-8")
    # DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP -> outlives this driver.
    flags = 0x00000008 | 0x00000200
    subprocess.Popen([PY, "-u", str(dev)], cwd=str(dev.parent),
                     stdout=logf, stderr=subprocess.STDOUT,
                     creationflags=flags, close_fds=True)
    for _ in range(25):
        time.sleep(3)
        if worker_up():
            logp({"event": "worker_restarted"})
            return
    logp({"event": "worker_start_failed"})


def logp(rec):
    rec["ts"] = int(time.time())
    with PROG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    print("  [drain] " + json.dumps(rec, ensure_ascii=False), flush=True)


def _pid_alive(pid):
    try:
        out = subprocess.run(["tasklist", "/FI", f"PID eq {pid}"],
                             capture_output=True, text=True).stdout
        return str(pid) in out
    except Exception:
        return True  # assume alive -> safer (won't double-run)


def acquire_lock():
    if LOCK.exists():
        try:
            old = int(LOCK.read_text().strip())
            if _pid_alive(old):
                print(f"Baska bir drain zaten calisiyor (pid {old}) — cikiliyor.")
                sys.exit(0)
        except Exception:
            pass
    LOCK.write_text(str(os.getpid()))


def main():
    acquire_lock()
    logp({"event": "driver_start", "pid": os.getpid()})
    part = 0
    try:
        while True:
            ensure_worker()
            # Don't collide with a live split job.
            for _ in range(60):
                busy = sql("select count(*) as n from pipeline_jobs where "
                           "job_type='youtube_asr' and status in "
                           "('pending','processing');")[0]["n"]
                if not busy:
                    break
                time.sleep(60)
            n0 = pool()
            if n0 == 0:
                logp({"event": "done", "pool": 0})
                break
            part += 1
            logp({"event": "part_start", "part": part, "pool_before": n0})
            r = subprocess.run([PY, "-u", "hsk_integrate.py", str(LEVEL), "100"],
                               cwd=str(HERE))
            n1 = pool()
            logp({"event": "part_end", "part": part, "pool_before": n0,
                  "pool_after": n1, "drained": n0 - n1, "rc": r.returncode})
            # Irreducible tail (e.g. whisperless clips keep getting re-picked):
            # stop rather than spin. The remaining clips need manual review.
            if n1 >= n0 or (n0 - n1) < 3:
                logp({"event": "stalled", "pool": n1,
                      "note": "kuyruk azalmadi — whispersiz kalinti olabilir, "
                              "manuel inceleme gerek"})
                break
    finally:
        try:
            LOCK.unlink()
        except Exception:
            pass
    print("=== HSK5 DRAIN DONE ===")


if __name__ == "__main__":
    main()
