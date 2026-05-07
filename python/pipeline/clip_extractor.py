"""ffmpeg wrapper for extracting video clips from local movie files."""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path


def check_ffmpeg() -> bool:
    return shutil.which("ffmpeg") is not None


def extract_clip(
    video_path: Path,
    start: float,
    end: float,
    output_path: Path,
) -> bool:
    """Extract [start, end] seconds from video_path → output_path (H.264/AAC MP4 at 480p)."""
    duration = max(end - start, 0.5)
    cmd = [
        "ffmpeg", "-y",
        "-ss", f"{start:.3f}",
        "-i", str(video_path),
        "-t", f"{duration:.3f}",
        "-vf", "scale='min(854,iw)':'min(480,ih)':force_original_aspect_ratio=decrease",
        "-c:v", "libx264",
        "-preset", "fast",
        "-crf", "28",
        "-c:a", "aac",
        "-b:a", "96k",
        "-movflags", "+faststart",
        "-loglevel", "error",
        str(output_path),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0 and result.stderr:
        print(f"    ffmpeg: {result.stderr[:200]}")
    return result.returncode == 0


def extract_embedded_subs(video_path: Path, output_srt: Path) -> bool:
    """Extract the first Chinese subtitle track from MKV into output_srt.

    Returns True if a Chinese subtitle stream was found and extracted.
    """
    probe = subprocess.run(
        [
            "ffprobe", "-v", "quiet",
            "-print_format", "json",
            "-show_streams", "-select_streams", "s",
            str(video_path),
        ],
        capture_output=True, text=True,
    )
    if probe.returncode != 0:
        return False

    try:
        streams = json.loads(probe.stdout).get("streams", [])
    except Exception:
        return False

    zh_langs = {"chi", "zh", "zho", "zh-hans", "zh-cn", "cmn", "Chinese"}
    target_index: int | None = None
    for stream in streams:
        lang = stream.get("tags", {}).get("language", "")
        if any(z.lower() in lang.lower() for z in zh_langs):
            target_index = stream["index"]
            break

    if target_index is None and streams:
        target_index = streams[0]["index"]

    if target_index is None:
        return False

    result = subprocess.run(
        [
            "ffmpeg", "-y",
            "-i", str(video_path),
            "-map", f"0:{target_index}",
            "-c:s", "srt",
            "-loglevel", "error",
            str(output_srt),
        ],
        capture_output=True, text=True,
    )
    return result.returncode == 0 and output_srt.exists() and output_srt.stat().st_size > 0
