"""
Movie Scene Pipeline: local video file → ffmpeg clips → Firestore Emulator

Reads Chinese subtitles from:
  1. An external .srt / .vtt / .ass file  (fastest)
  2. Embedded subtitle tracks in MKV      (fast, needs ffprobe)
  3. Whisper ASR fallback                 (slow, last resort)

Extracts each dialogue segment as a short MP4 clip, saves to python/clips/,
and writes a Firestore VideoSegmentModel doc (sourceType=self_hosted).

The pipeline dev server (localhost:9302) serves the clips/ folder, so the
Flutter video_player widget can play them without any extra setup.

Usage:
    py movie_pipeline.py --video "C:\\Movies\\movie.mkv"
    py movie_pipeline.py --video movie.mkv --sub movie.srt
    py movie_pipeline.py --video movie.mkv --sub movie.srt --max-clips 100 --active
    py movie_pipeline.py --video movie.mkv --offset 50 --max-clips 50  # batch mode

Requirements:
    ffmpeg on PATH:  winget install Gyan.FFmpeg
    pip install requests jieba pypinyin faster-whisper
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

from clip_extractor import check_ffmpeg, extract_clip, extract_embedded_subs
from youtube_miner import (
    _BUILTIN_HSK_MAP,
    build_firestore_segment,
    build_segments,
    compute_hsk_level,
    extract_target_words,
    parse_subtitle_file,
    transcribe_with_whisper,
)
from grammar_tagger import tag_grammar
from pinyin_helper import get_pinyin

# ── Paths & URLs ──────────────────────────────────────────────────────────────

CLIPS_DIR = Path(__file__).parent.parent / "clips"
CLIPS_URL_BASE = "http://localhost:9302/clips"

FIRESTORE_BASE = (
    "http://localhost:9299/v1/projects/demo-mandarin-academy"
    "/databases/(default)/documents"
)
_HEADERS = {
    "Content-Type": "application/json",
    "Authorization": "Bearer owner",
}

MIN_SEG = 3.0   # slightly shorter than YouTube — movie dialogue is denser
MAX_SEG = 12.0
DEFAULT_MAX_CLIPS = 0  # 0 = unlimited


# ── Firestore encoding ────────────────────────────────────────────────────────

def _enc(v: Any) -> dict:
    if v is None:
        return {"nullValue": None}
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, datetime):
        return {"timestampValue": v.astimezone(timezone.utc).isoformat()}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, list):
        return {"arrayValue": {"values": [_enc(i) for i in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: _enc(vv) for k, vv in v.items()}}}
    return {"stringValue": str(v)}


def _write(doc_id: str, data: dict) -> None:
    url = f"{FIRESTORE_BASE}/videos/{doc_id}"
    body = json.dumps({"fields": {k: _enc(v) for k, v in data.items()}})
    res = requests.patch(url, headers=_HEADERS, data=body, timeout=10)
    if res.status_code >= 300:
        raise RuntimeError(f"{res.status_code}: {res.text[:200]}")


def _emulator_ok() -> bool:
    try:
        return requests.get(
            f"{FIRESTORE_BASE}/videos?pageSize=1",
            headers=_HEADERS, timeout=3,
        ).status_code < 300
    except Exception:
        return False


# ── Subtitle resolution ───────────────────────────────────────────────────────

def _resolve_subtitles(
    video_path: Path,
    sub_path: Path | None,
    tmp_dir: Path,
) -> list[dict[str, Any]]:
    if sub_path and sub_path.exists():
        print(f"  📄 Using subtitle file: {sub_path.name}")
        entries = parse_subtitle_file(sub_path)
        print(f"     {len(entries)} cues parsed.")
        return entries

    print("  🔍 Looking for embedded Chinese subtitles...")
    tmp_srt = tmp_dir / "embedded.srt"
    if extract_embedded_subs(video_path, tmp_srt):
        entries = parse_subtitle_file(tmp_srt)
        if entries:
            print(f"     {len(entries)} cues from embedded subtitles.")
            return entries
        print("     Embedded subtitles found but no Chinese text.")
    else:
        print("     No embedded Chinese subtitles found.")

    print("  🎙️  Falling back to Whisper ASR (slow for long videos)...")
    return transcribe_with_whisper(video_path)


# ── Core ──────────────────────────────────────────────────────────────────────

def run(
    video_path: Path,
    sub_path: Path | None,
    hsk_map: dict[str, int],
    max_clips: int = DEFAULT_MAX_CLIPS,
    offset: int = 0,
    active: bool = False,
    min_sec: float = MIN_SEG,
    max_sec: float = MAX_SEG,
) -> int:
    """Process a local video file. Returns number of clips written."""
    CLIPS_DIR.mkdir(parents=True, exist_ok=True)

    movie_slug = re.sub(r"[^A-Za-z0-9_-]", "_", video_path.stem)[:28]
    print(f"\n🎬 Movie : {video_path.name}")
    print(f"   Slug  : {movie_slug}")
    print(f"   Clips → {CLIPS_DIR}\n")

    with tempfile.TemporaryDirectory() as tmpdir:
        entries = _resolve_subtitles(video_path, sub_path, Path(tmpdir))

    if not entries:
        print("❌ No Chinese dialogue found.", file=sys.stderr)
        return 0

    segments = build_segments(entries, min_sec=min_sec, max_sec=max_sec)
    total = len(segments)
    print(f"\n📐 {total} segments before slicing.")

    # Apply offset + limit
    segments = segments[offset:]
    if max_clips and max_clips > 0:
        segments = segments[:max_clips]
    print(f"   Processing {len(segments)} segments"
          + (f" (offset {offset})" if offset else "")
          + (f", limit {max_clips}" if max_clips else "")
          + ".\n")

    now_ts = datetime.now(timezone.utc)
    success = errors = 0

    for i, seg in enumerate(segments):
        global_index = offset + i
        clip_name = f"{movie_slug}_{global_index:04d}.mp4"
        clip_path = CLIPS_DIR / clip_name
        clip_url = f"{CLIPS_URL_BASE}/{clip_name}"
        clip_dur = round(seg["end"] - seg["start"], 3)

        label = seg["text"][:28] + ("…" if len(seg["text"]) > 28 else "")
        print(f"  [{i+1:3d}/{len(segments)}] {seg['start']:7.1f}s → {seg['end']:7.1f}s  "
              f"'{label}'", end="  ")

        # ── Extract clip ──────────────────────────────────────────────────────
        if clip_path.exists() and clip_path.stat().st_size > 1024:
            print("(cached)", end="  ")
        else:
            if not extract_clip(video_path, seg["start"], seg["end"], clip_path):
                print("✗ ffmpeg failed")
                errors += 1
                continue

        # ── Build Firestore document ──────────────────────────────────────────
        text = seg["text"]
        doc_id = f"{movie_slug}_{global_index:04d}"
        doc = {
            "videoId": doc_id,
            "sourceType": "self_hosted",
            "youtubeId": None,
            "videoUrl": clip_url,
            "startTime": 0.0,
            "endTime": clip_dur,
            "hskLevel": compute_hsk_level(text, hsk_map),
            "transcription": text,
            "pinyin": get_pinyin(text),
            "targetWords": extract_target_words(text, hsk_map),
            "quizCategory": tag_grammar(text),
            "quiz": {"question": "", "correctAnswer": "", "wrongAnswer": ""},
            "isActive": active,
            "createdAt": now_ts,
        }

        try:
            _write(doc_id, doc)
            print("✓")
            success += 1
        except RuntimeError as e:
            print(f"✗ Firestore: {e}")
            errors += 1

    remaining = total - offset - len(segments)
    print(f"\n✅ Done!  {success} clips written"
          + (f", {errors} errors" if errors else ""))
    if remaining > 0:
        next_offset = offset + len(segments)
        print(f"   {remaining} more segments available — run with --offset {next_offset}")
    print(f"   Clips served at: {CLIPS_URL_BASE}/")
    return success


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Local movie → ffmpeg clips → Firestore Emulator"
    )
    parser.add_argument("--video", required=True, type=Path,
                        help="Path to video file (MP4, MKV, AVI…)")
    parser.add_argument("--sub", type=Path,
                        help="External subtitle file (.srt, .vtt, .ass). "
                             "Auto-detected from embedded tracks if omitted.")
    parser.add_argument("--hsk-map", type=Path,
                        help="JSON {word:level} file. Uses built-in map if omitted.")
    parser.add_argument("--max-clips", type=int, default=DEFAULT_MAX_CLIPS,
                        help="Clip limit per run. 0 = unlimited (default).")
    parser.add_argument("--offset", type=int, default=0,
                        help="Skip first N segments (for batched processing).")
    parser.add_argument("--active", action="store_true",
                        help="Set isActive=True on all clips immediately.")
    parser.add_argument("--min-sec", type=float, default=MIN_SEG)
    parser.add_argument("--max-sec", type=float, default=MAX_SEG)
    args = parser.parse_args()

    if not check_ffmpeg():
        print(
            "❌ ffmpeg not found on PATH.\n"
            "   Windows install:  winget install Gyan.FFmpeg\n"
            "   Then restart your terminal.",
            file=sys.stderr,
        )
        sys.exit(1)

    if not args.video.exists():
        print(f"❌ Video file not found: {args.video}", file=sys.stderr)
        sys.exit(1)

    print("🔌 Checking Firestore emulator...")
    if not _emulator_ok():
        print("❌ Emulator not reachable. Start with start_dev.bat", file=sys.stderr)
        sys.exit(1)
    print("   ✓ Emulator running\n")

    if args.hsk_map and args.hsk_map.exists():
        hsk_map: dict[str, int] = json.loads(
            args.hsk_map.read_text(encoding="utf-8")
        )
        print(f"📖 Loaded HSK map: {len(hsk_map)} words")
    else:
        hsk_map = _BUILTIN_HSK_MAP
        print(f"📖 Using built-in HSK map ({len(hsk_map)} words)")

    run(
        video_path=args.video,
        sub_path=args.sub,
        hsk_map=hsk_map,
        max_clips=args.max_clips,
        offset=args.offset,
        active=args.active,
        min_sec=args.min_sec,
        max_sec=args.max_sec,
    )


if __name__ == "__main__":
    main()
