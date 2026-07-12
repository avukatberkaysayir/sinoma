"""Keeps dev_server.py alive: health-checks :9302 every minute and (re)starts
it when unresponsive. Launched hidden at Windows logon (shell:startup .vbs);
safe to run alongside a manual dev_server.py — it only starts one when the
health check fails. Also runs the weekly integrity scan (docs/butunluk_raporu.md)
when the last-scan stamp is older than 7 days."""
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

PIPELINE_DIR = Path(__file__).parent
PYTHONW = Path(sys.executable).with_name("pythonw.exe")
SCAN = PIPELINE_DIR.parent.parent / "tools" / "batch" / "integrity_scan.py"
STAMP = PIPELINE_DIR / ".last_integrity_scan"
WEEK = 7 * 24 * 3600


def maybe_scan() -> None:
    try:
        if STAMP.exists() and (time.time() - STAMP.stat().st_mtime) < WEEK:
            return
        subprocess.run([sys.executable, str(SCAN)], timeout=600,
                       creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        STAMP.touch()
    except Exception:
        pass  # scan is best-effort; never break the watchdog loop


def alive() -> bool:
    try:
        with urllib.request.urlopen("http://localhost:9302/health", timeout=3):
            return True
    except Exception:
        return False


while True:
    if not alive():
        flags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        subprocess.Popen(
            [str(PYTHONW if PYTHONW.is_file() else sys.executable), "dev_server.py"],
            cwd=PIPELINE_DIR,
            creationflags=flags,
        )
        time.sleep(30)  # give the server time to bind before re-checking
    maybe_scan()
    time.sleep(60)
