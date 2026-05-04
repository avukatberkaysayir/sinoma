"""
ADIM 10 — YouTube Content Pipeline V1

Fetches captions from a YouTube video via the official YouTube Data API v3
(no scraping), segments them into 5-10 second windows, assigns HSK levels,
and produces Firestore-ready JSON for the `videos` collection.

Usage:
    python youtube_miner.py \
        --video-id dQw4w9WgXcQ \
        --api-key YOUR_YOUTUBE_API_KEY \
        --hsk-map hsk_map.json \
        --output video_segments.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

import requests

YOUTUBE_CAPTIONS_LIST_URL = "https://www.googleapis.com/youtube/v3/captions"
YOUTUBE_VIDEOS_URL = "https://www.googleapis.com/youtube/v3/videos"

MIN_SEGMENT_SECONDS = 5.0
MAX_SEGMENT_SECONDS = 10.0


# ---------------------------------------------------------------------------
# YouTube Data API helpers
# ---------------------------------------------------------------------------

def fetch_video_metadata(video_id: str, api_key: str) -> dict[str, Any]:
    resp = requests.get(
        YOUTUBE_VIDEOS_URL,
        params={
            "part": "snippet,contentDetails",
            "id": video_id,
            "key": api_key,
        },
        timeout=15,
    )
    resp.raise_for_status()
    items = resp.json().get("items", [])
    if not items:
        raise ValueError(f"Video {video_id} not found or is private.")
    return items[0]


def fetch_caption_track_id(video_id: str, api_key: str, language: str = "zh") -> str | None:
    resp = requests.get(
        YOUTUBE_CAPTIONS_LIST_URL,
        params={"part": "snippet", "videoId": video_id, "key": api_key},
        timeout=15,
    )
    resp.raise_for_status()
    for item in resp.json().get("items", []):
        lang = item["snippet"]["language"]
        if lang.startswith(language):
            return item["id"]
    return None


# ---------------------------------------------------------------------------
# SRT / VTT parser
# ---------------------------------------------------------------------------

_TIMESTAMP_RE = re.compile(
    r"(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*"
    r"(\d{2}):(\d{2}):(\d{2})[,.](\d{3})"
)


def parse_timestamp(h: str, m: str, s: str, ms: str) -> float:
    return int(h) * 3600 + int(m) * 60 + int(s) + int(ms) / 1000


def parse_srt(raw: str) -> list[dict]:
    """Returns list of {start, end, text} from SRT content."""
    entries = []
    blocks = re.split(r"\n\s*\n", raw.strip())
    for block in blocks:
        lines = block.strip().splitlines()
        if len(lines) < 2:
            continue
        match = _TIMESTAMP_RE.search(lines[1] if len(lines) > 1 else lines[0])
        if not match:
            continue
        start = parse_timestamp(*match.groups()[:4])
        end = parse_timestamp(*match.groups()[4:])
        text = " ".join(lines[2:]).strip() if len(lines) > 2 else ""
        if text:
            entries.append({"start": start, "end": end, "text": text})
    return entries


# ---------------------------------------------------------------------------
# Segmentation
# ---------------------------------------------------------------------------

def build_segments(
    caption_entries: list[dict],
    hsk_map: dict[str, int],
    min_sec: float = MIN_SEGMENT_SECONDS,
    max_sec: float = MAX_SEGMENT_SECONDS,
) -> list[dict]:
    segments = []
    current_text = ""
    current_start: float | None = None

    for entry in caption_entries:
        if current_start is None:
            current_start = entry["start"]

        current_text += entry["text"] + " "
        duration = entry["end"] - current_start

        if duration >= min_sec:
            if duration <= max_sec or not current_text.strip():
                segments.append({
                    "start": current_start,
                    "end": entry["end"],
                    "text": current_text.strip(),
                })
                current_text = ""
                current_start = None

    return [s for s in segments if len(s["text"]) >= 3]


def compute_hsk_level(text: str, hsk_map: dict[str, int]) -> int:
    max_level = 1
    for word, level in hsk_map.items():
        if word in text and level > max_level:
            max_level = level
    return max_level


# ---------------------------------------------------------------------------
# Firestore document builder
# ---------------------------------------------------------------------------

def build_firestore_segment(
    video_id: str,
    segment: dict,
    hsk_map: dict[str, int],
    index: int,
) -> dict:
    hsk_level = compute_hsk_level(segment["text"], hsk_map)
    return {
        "videoId": f"{video_id}_seg{index:03d}",
        "sourceType": "youtube",
        "youtubeId": video_id,
        "videoUrl": None,
        "startTime": segment["start"],
        "endTime": segment["end"],
        "hskLevel": hsk_level,
        "transcription": segment["text"],
        "pinyin": "",
        "targetWords": [],
        "quiz": {
            "question": "",
            "correctAnswer": "",
            "wrongAnswer": "",
        },
        "isActive": False,
        "createdAt": None,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run(video_id: str, api_key: str, hsk_map: dict[str, int], output_path: Path) -> None:
    print(f"Fetching metadata for video {video_id}...")
    metadata = fetch_video_metadata(video_id, api_key)
    title = metadata["snippet"]["title"]
    print(f"  Title: {title}")

    caption_id = fetch_caption_track_id(video_id, api_key, language="zh")
    if not caption_id:
        print("No Chinese caption track found. Exiting.", file=sys.stderr)
        sys.exit(1)
    print(f"  Caption track ID: {caption_id}")

    print("Note: Caption download requires OAuth (not just API key).")
    print("For now, place the SRT file at ./captions.srt and re-run with --srt flag.")
    sys.exit(0)


def run_from_srt(video_id: str, srt_path: Path, hsk_map: dict[str, int], output_path: Path) -> None:
    print(f"Parsing SRT: {srt_path}")
    raw = srt_path.read_text(encoding="utf-8")
    captions = parse_srt(raw)
    print(f"  {len(captions)} caption entries.")

    segments = build_segments(captions, hsk_map)
    print(f"  {len(segments)} valid segments (5–10s).")

    docs = [build_firestore_segment(video_id, seg, hsk_map, i) for i, seg in enumerate(segments)]
    output_path.write_text(json.dumps(docs, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Output written to {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="YouTube content pipeline")
    parser.add_argument("--video-id", required=True)
    parser.add_argument("--api-key")
    parser.add_argument("--srt", type=Path, help="Path to local SRT file (bypasses API download)")
    parser.add_argument("--hsk-map", required=True, type=Path, help="JSON file: {word: level}")
    parser.add_argument("--output", default=Path("video_segments.json"), type=Path)
    args = parser.parse_args()

    hsk_map: dict[str, int] = json.loads(args.hsk_map.read_text(encoding="utf-8"))

    if args.srt:
        run_from_srt(args.video_id, args.srt, hsk_map, args.output)
    elif args.api_key:
        run(args.video_id, args.api_key, hsk_map, args.output)
    else:
        parser.error("Provide either --api-key or --srt")


if __name__ == "__main__":
    main()
