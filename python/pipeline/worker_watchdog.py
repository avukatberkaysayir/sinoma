"""Keeps dev_server.py alive: health-checks :9302 every minute and (re)starts
it when unresponsive. Launched hidden at Windows logon (shell:startup .vbs);
safe to run alongside a manual dev_server.py — it only starts one when the
health check fails."""
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

PIPELINE_DIR = Path(__file__).parent
PYTHONW = Path(sys.executable).with_name("pythonw.exe")


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
    time.sleep(60)
