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
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PORT = 9302
PIPELINE_DIR = Path(__file__).parent
CLIPS_DIR = PIPELINE_DIR.parent / "clips"
CLIPS_DIR.mkdir(parents=True, exist_ok=True)


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
            import shutil
            available = shutil.which("ffmpeg") is not None
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

        cmd = [sys.executable, str(PIPELINE_DIR / "movie_pipeline.py"),
               "--video", video_path]
        if sub_path:
            cmd += ["--sub", sub_path]
        if max_clips:
            cmd += ["--max-clips", str(max_clips)]
        if offset:
            cmd += ["--offset", str(offset)]
        if active:
            cmd.append("--active")

        print(f"\n▶ Movie: {video_path}")
        # Long timeout: ffmpeg extraction for 100 clips ≈ 2-5 min
        result = self._run(cmd, timeout=1800)
        if result is None:
            self._json(504, {"error": "Timed out after 30 minutes."})
            return

        if result.returncode == 0:
            count = result.stdout.count("✓")
            self._json(200, {"success": True, "clipsWritten": count,
                             "message": result.stdout.strip()})
            print(f"✅ Done — {count} clips\n")
        else:
            err = result.stderr.strip() or result.stdout.strip()
            self._json(500, {"success": False, "error": err})
            print(f"❌ Failed: {err[:300]}\n")

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
    server = HTTPServer(("localhost", PORT), _Handler)
    print(f"🚀 Pipeline dev server  →  http://localhost:{PORT}")
    print(f"   POST /process-video   {{\"url\": \"...\"}}")
    print(f"   POST /process-movie   {{\"video_path\": \"C:\\\\...\", \"sub_path\": \"...\"}}")
    print(f"   GET  /clips/<file>    static movie clips")
    print(f"   GET  /ffmpeg-check")
    print("   Press Ctrl+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 Server stopped")


if __name__ == "__main__":
    main()
