#!/usr/bin/env python3
"""
Mandarin Academy — Local pipeline dev server
Runs on localhost:9302 and exposes HTTP endpoints that the Flutter admin
panel calls to process YouTube videos without any terminal interaction.

Start manually:  python pipeline/dev_server.py
Or via:          start_dev.bat  (starts this automatically)
"""

from __future__ import annotations

import json
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PORT = 9302
PIPELINE_DIR = Path(__file__).parent


class _Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args: object) -> None:  # noqa: D401
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
        else:
            self.send_response(404)
            self._cors()
            self.end_headers()

    # ── POST ────────────────────────────────────────────────────────────────

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/process-video":
            self._process_video()
        else:
            self.send_response(404)
            self._cors()
            self.end_headers()

    # ── Handlers ────────────────────────────────────────────────────────────

    def _process_video(self) -> None:
        try:
            length = int(self.headers.get("Content-Length", 0))
            body: dict = json.loads(self.rfile.read(length))
        except Exception as e:
            self._json(400, {"error": f"Invalid JSON: {e}"})
            return

        url: str = body.get("url", "").strip()
        active: bool = body.get("active", True)

        if not url:
            self._json(400, {"error": "url is required"})
            return

        cmd = [sys.executable, str(PIPELINE_DIR / "seed_video.py"), "--url", url]
        if active:
            cmd.append("--active")

        print(f"\n▶ Processing: {url}")
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=str(PIPELINE_DIR),
                timeout=180,
            )
        except subprocess.TimeoutExpired:
            self._json(504, {"error": "Timed out after 3 minutes"})
            return
        except Exception as e:
            self._json(500, {"error": str(e)})
            return

        output = result.stdout.strip()
        err = result.stderr.strip()

        if result.returncode == 0:
            # Count '✓ ' occurrences to determine segments written
            count = output.count("✓ ")
            self._json(200, {
                "success": True,
                "segmentsWritten": count,
                "message": output,
            })
            print(f"✅ Done — {count} segments written\n")
        else:
            combined = err or output
            self._json(500, {"success": False, "error": combined})
            print(f"❌ Failed: {combined}\n")

    # ── Helpers ─────────────────────────────────────────────────────────────

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
    print(f"   POST /process-video  {{\"url\": \"...\", \"active\": true}}")
    print(f"   GET  /health")
    print("   Press Ctrl+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 Server stopped")


if __name__ == "__main__":
    main()
