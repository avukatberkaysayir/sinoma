"""
ADIM 10 — YouTube Content Pipeline V2

Downloads Chinese subtitles via yt-dlp, segments them into 5-10s windows,
assigns HSK levels, tags grammar → QuizCategory, generates pinyin, extracts
target words, and produces Firestore-ready JSON for the `videos` collection.

All output documents have isActive=False and empty quiz fields — a human
reviewer sets isActive=True and fills quiz data before content goes live.

Usage:
    # Download subtitles automatically (yt-dlp required):
    python youtube_miner.py \\
        --url "https://www.youtube.com/watch?v=VIDEO_ID" \\
        --hsk-map hsk_map.json \\
        --output video_segments.json

    # Use a locally downloaded SRT/VTT file:
    python youtube_miner.py \\
        --url "https://www.youtube.com/watch?v=VIDEO_ID" \\
        --sub-file captions.vtt \\
        --hsk-map hsk_map.json \\
        --output video_segments.json
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

from grammar_tagger import tag_grammar
from pinyin_helper import get_pinyin

try:
    import jieba  # type: ignore
    _JIEBA_AVAILABLE = True
except ImportError:
    _JIEBA_AVAILABLE = False

try:
    from faster_whisper import WhisperModel  # type: ignore
    _WHISPER_AVAILABLE = True
except ImportError:
    _WHISPER_AVAILABLE = False

WHISPER_MODEL_SIZE = "small"  # tiny|small|medium — small is best for Mandarin speed/accuracy

MIN_SEGMENT_SECONDS = 5.0
MAX_SEGMENT_SECONDS = 10.0
MAX_TARGET_WORDS = 3


# ---------------------------------------------------------------------------
# yt-dlp subtitle download
# ---------------------------------------------------------------------------

_YTDLP_BASE_ARGS = [
    # tv_embedded works without JS runtime or PO Token for most videos
    "--extractor-args", "youtube:player_client=tv_embedded",
    "--no-check-certificates",
    "--quiet",
    "--no-warnings",
]


def download_subtitles(url: str, output_dir: Path) -> Path | None:
    """Download Chinese subtitles (auto-generated preferred) via yt-dlp.

    Returns path to the downloaded .vtt file, or None if not found.
    """
    cmd = [
        sys.executable, "-m", "yt_dlp",
        *_YTDLP_BASE_ARGS,
        "--skip-download",
        "--write-auto-sub",
        "--write-sub",
        "--sub-lang", "zh-Hans,zh,zh-CN,zh-TW",
        "--sub-format", "vtt",
        "--convert-subs", "vtt",
        "--output", str(output_dir / "%(id)s.%(ext)s"),
        url,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"yt-dlp subtitle error: {result.stderr[:300]}", file=sys.stderr)
        return None

    vtt_files = list(output_dir.glob("*.vtt"))
    if not vtt_files:
        srt_files = list(output_dir.glob("*.srt"))
        return srt_files[0] if srt_files else None
    return vtt_files[0]


def extract_youtube_id(url: str) -> str:
    """Parse YouTube video ID from URL."""
    m = re.search(r"(?:v=|youtu\.be/|shorts/)([A-Za-z0-9_-]{11})", url)
    return m.group(1) if m else "unknown"


def download_audio(url: str, output_dir: Path) -> Path | None:
    """Download best audio track without requiring ffmpeg.

    Uses --format bestaudio to get the native audio container (webm/m4a/opus).
    faster-whisper reads these via PyAV without ffmpeg.
    """
    # Request audio-only streams that can be downloaded directly without ffmpeg.
    # Prefer webm/opus (251) or m4a (140) — both readable by PyAV/Whisper.
    cmd = [
        sys.executable, "-m", "yt_dlp",
        *_YTDLP_BASE_ARGS,
        "--format",
        "bestaudio[vcodec=none][protocol=https]"
        "/bestaudio[protocol=https]"
        "/18",                         # 360p mp4 with audio — last resort
        "--output", str(output_dir / "%(id)s.%(ext)s"),
        url,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"yt-dlp audio error: {result.stderr[:400]}", file=sys.stderr)
        return None

    # Accept any container — Whisper/PyAV handles webm, m4a, opus, mp4
    for pattern in ("*.webm", "*.m4a", "*.opus", "*.ogg", "*.mp4", "*.mp3"):
        files = list(output_dir.glob(pattern))
        if files:
            return files[0]
    return None


def transcribe_with_whisper(audio_path: Path) -> list[dict[str, Any]]:
    """Transcribe a Mandarin audio file with faster-whisper.

    Returns the same [{start, end, text}] format as parse_vtt/parse_srt.
    First call downloads the model from Hugging Face (~480 MB for 'small').
    """
    if not _WHISPER_AVAILABLE:
        print("faster-whisper not installed. Run: py -m pip install faster-whisper",
              file=sys.stderr)
        return []

    print(f"  Loading Whisper model '{WHISPER_MODEL_SIZE}' (downloads on first use)…")
    model = WhisperModel(WHISPER_MODEL_SIZE, device="cpu", compute_type="int8")

    print(f"  Transcribing {audio_path.name} …")
    segments, info = model.transcribe(
        str(audio_path),
        language="zh",
        beam_size=5,
        vad_filter=True,              # skip silence
        vad_parameters={"min_silence_duration_ms": 500},
    )

    entries: list[dict[str, Any]] = []
    for seg in segments:
        text = re.sub(r"\s+", "", seg.text.strip())
        if text and re.search(r"[一-鿿]", text):
            entries.append({"start": seg.start, "end": seg.end, "text": text})

    print(f"  Whisper produced {len(entries)} Chinese cues "
          f"(detected language: {info.language}, "
          f"probability: {info.language_probability:.0%})")
    return entries


def extract_video_id_from_path(sub_path: Path) -> str:
    """Infer YouTube video ID from the subtitle filename (yt-dlp naming)."""
    stem = sub_path.stem
    # yt-dlp names files like: "VIDEO_TITLE [VIDEO_ID].zh-Hans.vtt"
    # or "VIDEO_ID.zh-Hans.vtt" — extract the bracketed or bare ID
    bracketed = re.search(r'\[([A-Za-z0-9_-]{11})\]', stem)
    if bracketed:
        return bracketed.group(1)
    # Try bare 11-char ID at start or end
    bare = re.match(r'^([A-Za-z0-9_-]{11})', stem)
    if bare:
        return bare.group(1)
    return stem


# ---------------------------------------------------------------------------
# VTT parser
# ---------------------------------------------------------------------------

def _parse_vtt_timestamp(ts: str) -> float:
    """Parse VTT timestamp HH:MM:SS.mmm or MM:SS.mmm to seconds."""
    parts = ts.strip().split(":")
    if len(parts) == 3:
        h, m, s = parts
        return int(h) * 3600 + int(m) * 60 + float(s)
    if len(parts) == 2:
        m, s = parts
        return int(m) * 60 + float(s)
    return float(parts[0])


def parse_vtt(content: str) -> list[dict[str, Any]]:
    """Parse WebVTT subtitle content into list of {start, end, text}."""
    entries: list[dict[str, Any]] = []
    seen_texts: set[str] = set()

    blocks = re.split(r"\n\s*\n", content)
    for block in blocks:
        lines = [l.strip() for l in block.strip().splitlines() if l.strip()]
        if not lines:
            continue

        # Find the --> timestamp line
        ts_line_idx = -1
        for i, line in enumerate(lines):
            if " --> " in line:
                ts_line_idx = i
                break
        if ts_line_idx == -1:
            continue

        ts_line = lines[ts_line_idx]
        # VTT timestamps can have position metadata after the times
        ts_match = re.match(
            r"([\d:\.]+)\s+-->\s+([\d:\.]+)", ts_line
        )
        if not ts_match:
            continue

        start = _parse_vtt_timestamp(ts_match.group(1))
        end = _parse_vtt_timestamp(ts_match.group(2))

        # Collect all text lines after the timestamp
        raw = " ".join(lines[ts_line_idx + 1 :])

        # Strip inline VTT timestamps like <00:00:01.234>
        text = re.sub(r"<\d+:\d+:\d+\.\d+>", "", raw)
        # Strip tags: <c>, </c>, <b>, etc.
        text = re.sub(r"<[^>]+>", "", text)
        # Collapse whitespace (Chinese doesn't need spaces between chars)
        text = re.sub(r"\s+", "", text).strip()

        # Skip empty, pure punctuation, or exact duplicates of previous cue
        if not text or not re.search(r"[一-鿿]", text):
            continue
        if text in seen_texts:
            continue
        seen_texts.add(text)

        entries.append({"start": start, "end": end, "text": text})

    return entries


# ---------------------------------------------------------------------------
# SRT parser (fallback)
# ---------------------------------------------------------------------------

_SRT_TS_RE = re.compile(
    r"(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*"
    r"(\d{2}):(\d{2}):(\d{2})[,.](\d{3})"
)


def parse_srt(content: str) -> list[dict[str, Any]]:
    """Parse SRT subtitle content into list of {start, end, text}."""
    entries: list[dict[str, Any]] = []
    blocks = re.split(r"\n\s*\n", content.strip())
    for block in blocks:
        lines = block.strip().splitlines()
        if len(lines) < 3:
            continue
        match = _SRT_TS_RE.search(lines[1] if len(lines) > 1 else lines[0])
        if not match:
            continue
        g = match.groups()
        start = int(g[0]) * 3600 + int(g[1]) * 60 + int(g[2]) + int(g[3]) / 1000
        end = int(g[4]) * 3600 + int(g[5]) * 60 + int(g[6]) + int(g[7]) / 1000
        text = re.sub(r"\s+", "", " ".join(lines[2:]).strip())
        if text and re.search(r"[一-鿿]", text):
            entries.append({"start": start, "end": end, "text": text})
    return entries


def parse_subtitle_file(path: Path) -> list[dict[str, Any]]:
    """Auto-detect VTT or SRT and parse."""
    content = path.read_text(encoding="utf-8", errors="replace")
    if path.suffix.lower() == ".vtt" or content.startswith("WEBVTT"):
        return parse_vtt(content)
    return parse_srt(content)


# ---------------------------------------------------------------------------
# Segmentation
# ---------------------------------------------------------------------------

def build_segments(
    entries: list[dict[str, Any]],
    min_sec: float = MIN_SEGMENT_SECONDS,
    max_sec: float = MAX_SEGMENT_SECONDS,
) -> list[dict[str, Any]]:
    """Merge caption entries into 5-10s segments."""
    segments: list[dict[str, Any]] = []
    current_text = ""
    current_start: float | None = None

    for entry in entries:
        if current_start is None:
            current_start = entry["start"]

        current_text += entry["text"]
        duration = entry["end"] - current_start

        if duration >= min_sec:
            if duration <= max_sec or not current_text:
                segments.append({
                    "start": round(current_start, 3),
                    "end": round(entry["end"], 3),
                    "text": current_text,
                })
                current_text = ""
                current_start = None
            # If exceeded max, force flush
            elif duration > max_sec:
                segments.append({
                    "start": round(current_start, 3),
                    "end": round(entry["end"], 3),
                    "text": current_text,
                })
                current_text = ""
                current_start = None

    # Flush any remaining text that met minimum
    if current_text and current_start is not None:
        duration = entries[-1]["end"] - current_start if entries else 0
        if duration >= min_sec:
            segments.append({
                "start": round(current_start, 3),
                "end": round(entries[-1]["end"], 3),
                "text": current_text,
            })

    return [s for s in segments if len(s["text"]) >= 3]


# ---------------------------------------------------------------------------
# HSK scoring + target word extraction
# ---------------------------------------------------------------------------

def compute_hsk_level(text: str, hsk_map: dict[str, int]) -> int:
    """Return highest HSK level of any word found in text."""
    max_level = 1
    for word, level in hsk_map.items():
        if word in text and level > max_level:
            max_level = level
    return max_level


def extract_target_words(
    text: str,
    hsk_map: dict[str, int],
    max_words: int = MAX_TARGET_WORDS,
) -> list[str]:
    """Return up to max_words HSK words from text, sorted by HSK level desc."""
    if _JIEBA_AVAILABLE:
        tokens = list(jieba.cut(text))
    else:
        # Fallback: try all substrings of length 1-4
        tokens = [text[i:i+n] for n in range(1, 5) for i in range(len(text) - n + 1)]

    seen: set[str] = set()
    candidates: list[tuple[str, int]] = []
    for token in tokens:
        if token in hsk_map and token not in seen:
            seen.add(token)
            candidates.append((token, hsk_map[token]))

    candidates.sort(key=lambda x: -x[1])
    return [w for w, _ in candidates[:max_words]]


# ---------------------------------------------------------------------------
# Firestore document builder
# ---------------------------------------------------------------------------

def build_firestore_segment(
    youtube_id: str,
    segment: dict[str, Any],
    hsk_map: dict[str, int],
    index: int,
) -> dict[str, Any]:
    text = segment["text"]
    hsk_level = compute_hsk_level(text, hsk_map)
    target_words = extract_target_words(text, hsk_map)
    quiz_category = tag_grammar(text)
    pinyin = get_pinyin(text)

    return {
        "videoId": f"{youtube_id}_seg{index:03d}",
        "sourceType": "youtube",
        "youtubeId": youtube_id,
        "videoUrl": None,
        "startTime": segment["start"],
        "endTime": segment["end"],
        "hskLevel": hsk_level,
        "transcription": text,
        "pinyin": pinyin,
        "targetWords": target_words,
        "quizCategory": quiz_category,
        "quiz": {
            "question": "",
            "correctAnswer": "",
            "wrongAnswer": "",
        },
        "isActive": False,
        "createdAt": None,  # set by firestore_uploader to SERVER_TIMESTAMP
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run(
    url: str,
    hsk_map: dict[str, int],
    output_path: Path,
    sub_file: Path | None = None,
    min_sec: float = MIN_SEGMENT_SECONDS,
    max_sec: float = MAX_SEGMENT_SECONDS,
) -> None:
    entries: list[dict[str, Any]] = []

    if sub_file:
        sub_path = sub_file
        youtube_id = extract_video_id_from_path(sub_path)
        print(f"Using local subtitle file: {sub_path}")
        print("Parsing subtitles...")
        entries = parse_subtitle_file(sub_path)
        print(f"  {len(entries)} caption cues.")
    else:
        youtube_id = extract_youtube_id(url)
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)

            # ── Step 1: try subtitle download ─────────────────────────────
            print(f"Downloading subtitles for: {url}")
            sub_path = download_subtitles(url, tmp)

            if sub_path:
                dest = Path(f"subtitles_{sub_path.name}")
                dest.write_bytes(sub_path.read_bytes())
                print(f"  Saved subtitles to: {dest}")
                print("Parsing subtitles...")
                entries = parse_subtitle_file(dest)
                print(f"  {len(entries)} caption cues.")
            else:
                # ── Step 2: Whisper ASR fallback ──────────────────────────
                print("No Chinese subtitles found → falling back to Whisper ASR.")
                print("Downloading audio…")
                audio_path = download_audio(url, tmp)
                if not audio_path:
                    print("Audio download failed.", file=sys.stderr)
                    sys.exit(1)
                entries = transcribe_with_whisper(audio_path)
                if not entries:
                    print("Whisper produced no Chinese text.", file=sys.stderr)
                    sys.exit(1)

    print(f"  YouTube ID: {youtube_id}")

    print("Building segments...")
    segments = build_segments(entries, min_sec=min_sec, max_sec=max_sec)
    print(f"  {len(segments)} segments ({min_sec:.0f}–{max_sec:.0f}s).")

    print("Enriching (HSK level, grammar tag, pinyin, target words)...")
    docs = [
        build_firestore_segment(youtube_id, seg, hsk_map, i)
        for i, seg in enumerate(segments)
    ]

    # Summary stats
    from collections import Counter
    cat_counts = Counter(d["quizCategory"] for d in docs)
    hsk_counts = Counter(d["hskLevel"] for d in docs)
    print(f"  QuizCategory breakdown: {dict(cat_counts)}")
    print(f"  HSK level breakdown:    {dict(sorted(hsk_counts.items()))}")

    output_path.write_text(
        json.dumps(docs, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"Output written to {output_path}  ({len(docs)} documents)")
    print("Next step: review quiz fields, set isActive=True, then run firestore_uploader.py")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="YouTube → Firestore VideoSegmentModel pipeline"
    )
    parser.add_argument("--url", required=True, help="YouTube video URL")
    parser.add_argument(
        "--sub-file", type=Path,
        help="Local .vtt or .srt file (skips yt-dlp download)"
    )
    parser.add_argument(
        "--hsk-map", required=True, type=Path,
        help="JSON {word: level} map (output of hsk_analyzer.py)"
    )
    parser.add_argument(
        "--output", default=Path("video_segments.json"), type=Path
    )
    parser.add_argument("--min-sec", type=float, default=MIN_SEGMENT_SECONDS)
    parser.add_argument("--max-sec", type=float, default=MAX_SEGMENT_SECONDS)
    args = parser.parse_args()

    hsk_map: dict[str, int] = json.loads(
        args.hsk_map.read_text(encoding="utf-8")
    )

    run(
        url=args.url,
        hsk_map=hsk_map,
        output_path=args.output,
        sub_file=args.sub_file,
        min_sec=args.min_sec,
        max_sec=args.max_sec,
    )


if __name__ == "__main__":
    main()
