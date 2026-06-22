#!/usr/bin/env python3
"""
Mandarin Academy — Local pipeline dev server
Runs on localhost:9302.

Endpoints:
  GET  /health           — liveness check
  GET  /ffmpeg-check     — returns {"available": true/false}
  POST /process-video    — YouTube URL → subtitles → Firestore
  POST /process-movie    — local video file → ffmpeg clips → Firestore
  GET  /clips/<name>     — serve extracted movie clips (static)
"""

from __future__ import annotations

import json
import mimetypes
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PORT = 9302
PIPELINE_DIR = Path(__file__).parent
CLIPS_DIR = PIPELINE_DIR.parent / "clips"
CLIPS_DIR.mkdir(parents=True, exist_ok=True)

# bgutil PO-Token provider: YouTube's web clients need a PO token to pass the
# "confirm you're not a bot" gate. The node server mints tokens locally on :4416;
# youtube_miner points yt-dlp at it. Start it here so the worker has it ready.
POT_PORT = 4416
POT_SERVER_JS = Path(
    os.environ.get("BGUTIL_POT_JS", r"D:\UserData\bgutil-pot\server\build\main.js")
)


def _pot_running() -> bool:
    import urllib.request
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{POT_PORT}/ping", timeout=2):
            return True
    except Exception:
        return False


def _ensure_pot_server() -> None:
    if _pot_running():
        print(f"✓ PO-Token sunucusu zaten çalışıyor (:{POT_PORT})")
        return
    if not POT_SERVER_JS.is_file():
        print(f"⚠️  PO-Token sunucusu yok ({POT_SERVER_JS}) — yt-dlp token'sız den/ "
              "bgutil-pot derleyin")
        return
    try:
        flags = (
            subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW
            if sys.platform == "win32" else 0
        )
        subprocess.Popen(
            ["node", str(POT_SERVER_JS)],
            cwd=str(POT_SERVER_JS.parent),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=flags,
        )
        import time
        for _ in range(15):
            time.sleep(0.4)
            if _pot_running():
                print(f"🔑 PO-Token sunucusu başlatıldı (:{POT_PORT})")
                return
        print("⚠️  PO-Token sunucusu başladı ama yanıt vermiyor")
    except FileNotFoundError:
        print("⚠️  node bulunamadı — PO-Token sunucusu atlandı")
    except Exception as e:
        print(f"⚠️  PO-Token sunucusu başlatılamadı: {e}")


class _Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args: object) -> None:
        print(f"  [server] {fmt % args}")

    # ── CORS preflight ──────────────────────────────────────────────────────

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(200)
        self._cors()
        self.end_headers()

    # ── GET ─────────────────────────────────────────────────────────────────

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            self._json(200, {"status": "ok", "port": PORT})

        elif self.path == "/ffmpeg-check":
            try:
                from clip_extractor import check_ffmpeg
                available = check_ffmpeg()  # PATH or bundled imageio-ffmpeg
            except Exception:
                available = False
            self._json(200, {"available": available})

        elif self.path.startswith("/clips/"):
            self._serve_clip()

        else:
            self.send_response(404)
            self._cors()
            self.end_headers()

    # ── POST ────────────────────────────────────────────────────────────────

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/process-video":
            self._process_video()
        elif self.path == "/process-movie":
            self._process_movie()
        elif self.path == "/process-youtube-asr":
            self._process_youtube_asr()
        else:
            self.send_response(404)
            self._cors()
            self.end_headers()

    # ── Handlers ────────────────────────────────────────────────────────────

    def _process_video(self) -> None:
        try:
            body = self._read_json()
        except Exception as e:
            self._json(400, {"error": f"Invalid JSON: {e}"})
            return

        url: str = body.get("url", "").strip()
        active: bool = body.get("active", False)

        if not url:
            self._json(400, {"error": "url is required"})
            return

        cmd = [sys.executable, str(PIPELINE_DIR / "seed_video.py"), "--url", url]
        if active:
            cmd.append("--active")

        print(f"\n▶ YouTube: {url}")
        result = self._run(cmd, timeout=600)
        if result is None:
            self._json(504, {
                "error": "Timed out after 10 minutes. "
                         "If the video has no Chinese subtitles, Whisper needs more time. "
                         "Try a video with manual subtitles."
            })
            return

        if result.returncode == 0:
            count = result.stdout.count("✓ ")
            self._json(200, {"success": True, "segmentsWritten": count,
                             "message": result.stdout.strip()})
            print(f"✅ Done — {count} segments\n")
        else:
            err = result.stderr.strip() or result.stdout.strip()
            self._json(500, {"success": False, "error": err})
            print(f"❌ Failed: {err[:200]}\n")

    def _process_movie(self) -> None:
        try:
            body = self._read_json()
        except Exception as e:
            self._json(400, {"error": f"Invalid JSON: {e}"})
            return

        video_path: str = body.get("video_path", "").strip()
        sub_path: str = body.get("sub_path", "").strip()
        max_clips: int = int(body.get("max_clips", 0))
        offset: int = int(body.get("offset", 0))
        active: bool = body.get("active", False)

        if not video_path:
            self._json(400, {"error": "video_path is required"})
            return

        if not Path(video_path).exists():
            self._json(400, {"error": f"File not found: {video_path}"})
            return

        print(f"\n▶ Movie → Supabase: {video_path}")
        try:
            from movie_supabase_pipeline import run as movie_run
            result = movie_run(
                Path(video_path),
                sub_path=Path(sub_path) if sub_path else None,
                active=active,
                max_clips=max_clips or 0,
                offset=offset or 0,
            )
            self._json(200, {"success": True, **result})
            print(f"✅ Done — {result.get('clipsWritten', 0)} clips\n")
        except Exception as e:
            err = str(e)
            self._json(500, {"success": False, "error": err})
            print(f"❌ Failed: {err[:300]}\n")

    def _process_youtube_asr(self) -> None:
        try:
            body = self._read_json()
        except Exception as e:
            self._json(400, {"error": f"Invalid JSON: {e}"})
            return

        url: str = body.get("url", "").strip()
        active: bool = body.get("active", False)

        if not url:
            self._json(400, {"error": "url zorunlu"})
            return

        print(f"\n▶ YouTube ASR: {url}")
        try:
            from youtube_asr_pipeline import run as asr_run
            result = asr_run(url, active=active)
            self._json(200, result)
            print(f"✅ ASR done — {result.get('segmentsWritten', 0)} segments\n")
        except Exception as e:
            err = str(e)
            self._json(500, {"error": err})
            print(f"❌ ASR failed: {err[:300]}\n")

    def _serve_clip(self) -> None:
        filename = self.path[len("/clips/"):]
        # Prevent path traversal
        if ".." in filename or "/" in filename:
            self.send_response(403)
            self._cors()
            self.end_headers()
            return

        clip_path = CLIPS_DIR / filename
        if not clip_path.exists():
            self.send_response(404)
            self._cors()
            self.end_headers()
            return

        mime, _ = mimetypes.guess_type(str(clip_path))
        data = clip_path.read_bytes()
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", mime or "video/mp4")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        self.wfile.write(data)

    # ── Helpers ─────────────────────────────────────────────────────────────

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length))

    def _run(self, cmd: list[str], timeout: int) -> subprocess.CompletedProcess | None:
        try:
            return subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=str(PIPELINE_DIR),
                timeout=timeout,
            )
        except subprocess.TimeoutExpired:
            return None
        except Exception as e:
            # Return a fake failed result
            class _FakeResult:
                returncode = 1
                stdout = ""
                stderr = str(e)
            return _FakeResult()  # type: ignore[return-value]

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, status: int, data: dict) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self._cors()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    # Start the local PO-Token provider first so the worker's downloads have it.
    _ensure_pot_server()

    # Start Supabase job poller in background thread
    try:
        from youtube_asr_pipeline import SUPABASE_URL, SUPABASE_SERVICE_KEY
        if SUPABASE_SERVICE_KEY:
            from pipeline_poller import start as start_poller
            start_poller(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        else:
            print("⚠️  SUPABASE_SERVICE_ROLE_KEY eksik — job poller devre dışı")
    except Exception as e:
        print(f"⚠️  Poller başlatılamadı: {e}")

    server = HTTPServer(("localhost", PORT), _Handler)
    print(f"🚀 Pipeline dev server  →  http://localhost:{PORT}")
    print(f"   POST /process-video        {{\"url\": \"...\"}}")
    print(f"   POST /process-youtube-asr  {{\"url\": \"...\", \"active\": false}}")
    print(f"   POST /process-movie        {{\"video_path\": \"C:\\\\...\", \"sub_path\": \"...\"}}")
    print(f"   GET  /clips/<file>         static movie clips")
    print(f"   GET  /ffmpeg-check")
    print("   Press Ctrl+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 Server stopped")


if __name__ == "__main__":
    main()
