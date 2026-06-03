"""
ADIM 10 — YouTube Content Pipeline V2

Downloads Chinese subtitles via yt-dlp, segments them into 5-10s windows,
assigns HSK levels, tags grammar → QuizCategory, generates pinyin, extracts
target words, and produces Firestore-ready JSON for the `videos` collection.

Fallback chain: manual subs → auto subs → audio download + Whisper ASR.
Each step tries multiple yt-dlp client strategies and browser cookie sources.
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

# Traditional → Simplified: captions / Whisper output are often Traditional, but
# the dictionary, quiz and UI are Simplified. Convert at the source so HSK
# analysis matches and stored transcriptions are Simplified.
try:
    import zhconv  # type: ignore

    def _to_simplified(text: str) -> str:
        try:
            return zhconv.convert(text, "zh-cn")
        except Exception:
            return text
except ImportError:
    def _to_simplified(text: str) -> str:
        return text

WHISPER_MODEL_SIZE = "small"
MIN_SEGMENT_SECONDS = 1.0
MAX_SEGMENT_SECONDS = 6.0
MAX_TARGET_WORDS = 3


# ---------------------------------------------------------------------------
# Structured logging
# ---------------------------------------------------------------------------

def _log(tag: str, msg: str) -> None:
    print(f"  [{tag}] {msg}", flush=True)


# ---------------------------------------------------------------------------
# yt-dlp strategy matrix
# ---------------------------------------------------------------------------

_YTDLP_BASE_ARGS = [
    "--no-check-certificates",
    "--no-playlist",
    "--quiet",
    "--no-warnings",
    "--force-ipv4",
    "--socket-timeout", "30",
    "--retries", "3",
]

# Ordered from most permissive to most restricted.
# tv_embedded skips PO Token requirement for most videos.
# mweb is mobile web, often unblocked. android/web are fallbacks.
_CLIENTS: list[list[str]] = [
    ["--extractor-args", "youtube:player_client=tv_embedded"],
    ["--extractor-args", "youtube:player_client=mweb"],
    ["--extractor-args", "youtube:player_client=web"],
    ["--extractor-args", "youtube:player_client=android"],
    [],  # yt-dlp default
]

# Cookie sources; empty list = no cookies (fastest, tried first).
_COOKIE_GROUPS: list[list[str]] = [
    [],
    ["--cookies-from-browser", "chrome"],
    ["--cookies-from-browser", "edge"],
    ["--cookies-from-browser", "firefox"],
]

# Full strategy matrix: (client_args, cookie_args)
# First phase: no cookies × all clients (most common fix — tv_embedded bypasses PO Token).
# Second phase: chrome cookies × all clients (handles bot-detection gating).
# Third phase: edge/firefox if chrome not available.
_STRATEGIES: list[tuple[list[str], list[str]]] = (
    [(c, []) for c in _CLIENTS]
    + [(c, ["--cookies-from-browser", "chrome"]) for c in _CLIENTS]
    + [(c, ["--cookies-from-browser", "edge"]) for c in _CLIENTS[:2]]
    + [(c, ["--cookies-from-browser", "firefox"]) for c in _CLIENTS[:2]]
)


def _strategy_label(client_args: list[str], cookie_args: list[str]) -> str:
    client = client_args[1].split("=")[-1] if client_args else "default"
    cookie = cookie_args[1] if cookie_args else "no-cookies"
    return f"client={client} cookies={cookie}"


def _is_truly_permanent(text: str) -> bool:
    """Return True ONLY for permanent failures where no retry or client change will help.

    NOTE: "video unavailable" and "this video is not available" are intentionally
    excluded — YouTube returns them for bot/IP/PO Token blocks that CAN be bypassed
    by trying a different client strategy.
    """
    t = text.lower()
    return any(k in t for k in (
        "members only", "members-only",
        "join to watch",
        "private video",
        "video is private",
        "age-restricted",
        "age restricted",
        "has been removed",
        "video has been removed",
        "account has been terminated",
    ))


def _probe_accessible(url: str) -> str | None:
    """Probe video metadata (title only, no download) to test real accessibility.

    A returned title proves the video EXISTS — extraction failures are then
    bot/IP/anti-bot issues, not genuine unavailability.
    Returns video title string, or None if all probe strategies fail.
    """
    _log("PROBE", f"checking real accessibility: {url}")
    for client_args, cookie_args in _STRATEGIES[:8]:
        sl = _strategy_label(client_args, cookie_args)
        try:
            result = _run_ytdlp(
                _YTDLP_BASE_ARGS + cookie_args + client_args + [
                    "--skip-download",
                    "--print", "%(title)s",
                    url,
                ],
                timeout=30,
            )
            title = result.stdout.strip()
            if result.returncode == 0 and title and title not in ("NA", "%(title)s", ""):
                _log("PROBE", f"accessible — title='{title[:60]}' via {sl}")
                return title
        except subprocess.TimeoutExpired:
            _log("PROBE", f"timeout ({sl})")
            continue
        _log("PROBE", f"no title via {sl}")
    _log("PROBE", "all probe strategies failed — video likely truly inaccessible")
    return None


def _run_ytdlp(args: list[str], timeout: int = 180) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, "-m", "yt_dlp"] + args,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


# ---------------------------------------------------------------------------
# Subtitle download
# ---------------------------------------------------------------------------

def download_subtitles(url: str, output_dir: Path) -> Path | None:
    """Download Chinese subtitles (manual then auto-generated) with multi-strategy retry.

    Returns path to a .vtt or .srt file, or None if none found.
    """
    _log("SUBTITLE_SEARCH", f"url={url}")

    def _find_sub() -> Path | None:
        for pattern in ("*.vtt", "*.srt"):
            hits = [f for f in output_dir.glob(pattern) if f.stat().st_size > 0]
            if hits:
                return hits[0]
        return None

    def _sub_base_args(auto: bool) -> list[str]:
        flags = ["--skip-download"]
        if auto:
            flags += ["--write-auto-sub"]
        else:
            flags += ["--write-sub"]
        return flags + [
            "--sub-lang", "zh-Hans,zh,zh-CN,zh-TW,zh-Hant",
            "--sub-format", "vtt",
            "--convert-subs", "vtt",
            "--output", str(output_dir / "%(id)s.%(ext)s"),
            url,
        ]

    # Try manual subs with all client/cookie combos first.
    # If any strategy returns exit code 0 but no files, the video has no subs of that type.
    no_manual_sub_confirmed = False
    no_auto_sub_confirmed = False

    for auto in (False, True):
        label = "auto-sub" if auto else "manual-sub"
        if auto and no_auto_sub_confirmed:
            continue

        for client_args, cookie_args in _STRATEGIES:
            sl = _strategy_label(client_args, cookie_args)
            _log("SUBTITLE_SEARCH", f"{label} {sl}")

            try:
                result = _run_ytdlp(
                    _YTDLP_BASE_ARGS + cookie_args + client_args + _sub_base_args(auto)
                )
            except subprocess.TimeoutExpired:
                _log("SUBTITLE_SEARCH", f"timeout ({sl}) — next")
                continue

            found = _find_sub()
            if found:
                size = found.stat().st_size
                _log("SUBTITLE_SEARCH", f"found: {found.name} ({size} bytes) via {sl}")
                return found

            combined = result.stderr + result.stdout
            if _is_truly_permanent(combined):
                _log("SUBTITLE_SEARCH", f"truly permanent block: {combined[:200]}")
                raise RuntimeError(f"Video kalıcı olarak erişilemiyor — {combined.strip()[:180]}")

            if result.returncode == 0:
                # Video is accessible, just has no subs of this type.
                _log("SUBTITLE_SEARCH", f"no {label} files (video accessible, no subs for this type)")
                if auto:
                    no_auto_sub_confirmed = True
                else:
                    no_manual_sub_confirmed = True
                break  # Skip remaining clients for this sub type

            _log("SUBTITLE_SEARCH", f"error (rc={result.returncode}): {combined[:120]}")

    _log("SUBTITLE_SEARCH", "no subtitles found across all strategies")
    return None


# ---------------------------------------------------------------------------
# URL helpers
# ---------------------------------------------------------------------------

def extract_youtube_id(url: str) -> str:
    url = url.strip()
    # Accept a bare 11-char video ID directly (no URL prefix)
    if re.fullmatch(r'[A-Za-z0-9_-]{11}', url):
        return url
    m = re.search(r"(?:v=|youtu\.be/|shorts/)([A-Za-z0-9_-]{11})", url)
    return m.group(1) if m else "unknown"


def normalize_youtube_url(url: str) -> str:
    video_id = extract_youtube_id(url)
    if video_id == "unknown":
        return url
    return f"https://www.youtube.com/watch?v={video_id}"


# ---------------------------------------------------------------------------
# Audio download
# ---------------------------------------------------------------------------

def download_audio(url: str, output_dir: Path) -> Path | None:
    """Download best audio track with multi-strategy retry.

    No [protocol=https] restriction — DASH/fragmented streams are fine.
    faster-whisper reads webm/m4a/opus via PyAV without ffmpeg.
    Returns path to audio file (size > 1 KB), or None on failure.
    """
    _log("AUDIO_DOWNLOAD", f"start url={url}")

    # Best-first format chain; no protocol restriction so DASH streams are accepted.
    FMT = "bestaudio[ext=webm]/bestaudio[ext=m4a]/bestaudio[ext=opus]/bestaudio/worstaudio/18"

    def _find_audio() -> Path | None:
        for pattern in ("*.webm", "*.m4a", "*.opus", "*.ogg", "*.mp4", "*.mp3", "*.wav"):
            hits = [f for f in output_dir.glob(pattern) if f.stat().st_size > 1024]
            if hits:
                return hits[0]
        return None

    for client_args, cookie_args in _STRATEGIES:
        sl = _strategy_label(client_args, cookie_args)
        _log("AUDIO_DOWNLOAD", sl)

        dl_args = (
            _YTDLP_BASE_ARGS
            + cookie_args
            + client_args
            + ["--format", FMT,
               "--output", str(output_dir / "%(id)s.%(ext)s"),
               url]
        )

        try:
            result = _run_ytdlp(dl_args, timeout=300)
        except subprocess.TimeoutExpired:
            _log("AUDIO_DOWNLOAD", f"timeout ({sl}) — next")
            continue

        found = _find_audio()
        if found:
            size_kb = found.stat().st_size // 1024
            _log("AUDIO_DOWNLOAD", f"success: {found.name} ({size_kb} KB) via {sl}")
            return found

        combined = result.stderr + result.stdout
        if _is_truly_permanent(combined):
            _log("AUDIO_DOWNLOAD", f"truly permanent block: {combined[:200]}")
            raise RuntimeError(f"Video kalıcı olarak erişilemiyor — {combined.strip()[:180]}")

        # Log the actual yt-dlp error and continue to next strategy
        _log("AUDIO_DOWNLOAD", f"failed (rc={result.returncode}): {combined[:200]}")

    # All 19 strategies exhausted without a permanent block.
    # Probe metadata to distinguish "extraction failure" from "truly unavailable".
    _log("AUDIO_DOWNLOAD", "all strategies exhausted — running accessibility probe…")
    title = _probe_accessible(url)
    if title:
        raise RuntimeError(
            f"YouTube ses indirme katmanı engellendi (anti-bot / IP kısıtlaması).\n"
            f"Video '{title[:80]}' erişilebilir durumdadır ama yt-dlp indiremedi.\n"
            f"Öneriler:\n"
            f"  1. yt-dlp güncelleyin: py -m pip install -U yt-dlp\n"
            f"  2. Birkaç dakika bekleyip tekrar deneyin (YouTube rate-limit)\n"
            f"  3. Chrome oturumu açık bırakın (cookie stratejisi daha iyi çalışır)"
        )
    raise RuntimeError(
        "Video erişilemiyor — tüm 19 strateji denendi ve hiçbiri başarılı olmadı.\n"
        "Olası nedenler: video gerçekten kaldırılmış, sadece belirli bölgelerde erişilebilir,\n"
        "veya çok agresif YouTube IP bloğu.\n"
        "Normal tarayıcıda videoyu açıp kontrol edin."
    )


# ---------------------------------------------------------------------------
# Whisper transcription
# ---------------------------------------------------------------------------

def iter_whisper_cues(audio_path: Path):
    """Stream Mandarin cues from faster-whisper as they are transcribed.

    Yields {start, end, text} (Simplified, duration-capped) one cue at a time —
    faster-whisper's transcribe() is a lazy generator, so downstream segmenting
    + DB insert can happen WHILE the rest of the audio is still being processed.
    Model (~480 MB for 'small') downloads automatically on first use.
    """
    if not _WHISPER_AVAILABLE:
        _log("ASR", "faster-whisper not installed. Run: py -m pip install faster-whisper")
        return

    _log("ASR", f"loading Whisper '{WHISPER_MODEL_SIZE}' model (downloads on first use)…")
    model = WhisperModel(WHISPER_MODEL_SIZE, device="cpu", compute_type="int8")

    _log("ASR", f"transcribing {audio_path.name} (streaming)…")
    segments, info = model.transcribe(
        str(audio_path),
        language="zh",
        beam_size=5,
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 500},
    )

    for seg in segments:
        text = _to_simplified(re.sub(r"\s+", "", seg.text.strip()))
        if text and re.search(r"[一-鿿]", text):
            # Whisper sometimes bridges a silent/musical gap into one cue with a
            # huge duration (e.g. a 13-char line tagged 195s). Cap the end by a
            # char-rate estimate so such cues don't become a 3-minute segment.
            cap = seg.start + max(2.0, len(text) * 0.6)
            yield {"start": seg.start, "end": min(seg.end, cap), "text": text}


def transcribe_with_whisper(audio_path: Path) -> list[dict[str, Any]]:
    """Batch wrapper around iter_whisper_cues (collects all cues into a list)."""
    return list(iter_whisper_cues(audio_path))


# ---------------------------------------------------------------------------
# VTT parser
# ---------------------------------------------------------------------------

def _parse_vtt_timestamp(ts: str) -> float:
    parts = ts.strip().split(":")
    if len(parts) == 3:
        h, m, s = parts
        return int(h) * 3600 + int(m) * 60 + float(s)
    if len(parts) == 2:
        m, s = parts
        return int(m) * 60 + float(s)
    return float(parts[0])


def parse_vtt(content: str) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    seen: set[str] = set()

    for block in re.split(r"\n\s*\n", content):
        lines = [l.strip() for l in block.strip().splitlines() if l.strip()]
        if not lines:
            continue
        ts_idx = next((i for i, l in enumerate(lines) if " --> " in l), -1)
        if ts_idx == -1:
            continue
        m = re.match(r"([\d:\.]+)\s+-->\s+([\d:\.]+)", lines[ts_idx])
        if not m:
            continue
        start = _parse_vtt_timestamp(m.group(1))
        end = _parse_vtt_timestamp(m.group(2))

        raw = " ".join(lines[ts_idx + 1:])
        text = re.sub(r"<\d+:\d+:\d+\.\d+>", "", raw)
        text = re.sub(r"<[^>]+>", "", text)
        text = re.sub(r"\s+", "", text).strip()

        if not text or not re.search(r"[一-鿿]", text) or text in seen:
            continue
        seen.add(text)
        entries.append({"start": start, "end": end, "text": _to_simplified(text)})

    return entries


# ---------------------------------------------------------------------------
# SRT parser
# ---------------------------------------------------------------------------

_SRT_TS_RE = re.compile(
    r"(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*"
    r"(\d{2}):(\d{2}):(\d{2})[,.](\d{3})"
)


def parse_srt(content: str) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for block in re.split(r"\n\s*\n", content.strip()):
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
            entries.append({"start": start, "end": end, "text": _to_simplified(text)})
    return entries


def parse_subtitle_file(path: Path) -> list[dict[str, Any]]:
    content = path.read_text(encoding="utf-8", errors="replace")
    if path.suffix.lower() == ".vtt" or content.startswith("WEBVTT"):
        return parse_vtt(content)
    return parse_srt(content)


# ---------------------------------------------------------------------------
# Segmentation
# ---------------------------------------------------------------------------

def stream_segments(
    entries: "Any",
    min_sec: float = MIN_SEGMENT_SECONDS,
    max_sec: float = 10.0,
    max_chars: int = 45,
    max_gap: float = 1.0,
):
    """Incremental, SENTENCE-focused segmentation. A segment closes on sentence
    punctuation, on a silence gap before the next cue (natural boundary), or at
    the max_sec hard cap (10s). max_chars (45 ≈ ~10s of speech) is only a runaway
    safety, so a sentence is NOT chopped mid-way at an arbitrary char/second
    count — it runs to its natural end up to ~10s. Yields each segment as it
    closes so callers can insert/show progressively. `entries` may be a list or
    a generator."""
    cur_text = ""
    cur_start: float | None = None
    last_end = 0.0

    def ends_sentence(t: str) -> bool:
        return bool(re.search(r"[。！？!?…；;]\s*$", t.strip()))

    def hanzi(t: str) -> int:
        return len(re.findall(r"[一-鿿]", t))

    def ready() -> bool:
        return (cur_start is not None and len(cur_text.strip()) >= 2
                and (last_end - cur_start) >= min_sec)

    def make() -> dict[str, Any]:
        return {"start": round(cur_start, 3), "end": round(last_end, 3),
                "text": cur_text.strip()}

    for entry in entries:
        # Pause since the previous cue → close the current segment first.
        if cur_start is not None and entry["start"] - last_end > max_gap:
            if ready():
                yield make()
            cur_text = ""
            cur_start = None
        if cur_start is None:
            cur_start = entry["start"]
        cur_text += entry["text"]
        last_end = entry["end"]
        if (ends_sentence(entry["text"])
                or (last_end - cur_start) >= max_sec
                or hanzi(cur_text) >= max_chars):
            if ready():
                yield make()
            cur_text = ""
            cur_start = None
    if ready():
        yield make()


def build_segments(
    entries: list[dict[str, Any]],
    min_sec: float = MIN_SEGMENT_SECONDS,
    max_sec: float = 10.0,
    max_chars: int = 45,
    max_gap: float = 1.0,
) -> list[dict[str, Any]]:
    """Batch wrapper around stream_segments (collects all segments into a list)."""
    return list(stream_segments(entries, min_sec, max_sec, max_chars, max_gap))


# ---------------------------------------------------------------------------
# HSK scoring + target word extraction
# ---------------------------------------------------------------------------

def compute_hsk_level(text: str, hsk_map: dict[str, int]) -> int:
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
    if _JIEBA_AVAILABLE:
        tokens = list(jieba.cut(text))
    else:
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

def extract_video_id_from_path(sub_path: Path) -> str:
    stem = sub_path.stem
    bracketed = re.search(r'\[([A-Za-z0-9_-]{11})\]', stem)
    if bracketed:
        return bracketed.group(1)
    bare = re.match(r'^([A-Za-z0-9_-]{11})', stem)
    if bare:
        return bare.group(1)
    return stem


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
        "quiz": {"question": "", "correctAnswer": "", "wrongAnswer": ""},
        "isActive": False,
        "createdAt": None,
    }


# ---------------------------------------------------------------------------
# Main (CLI usage)
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
        youtube_id = extract_video_id_from_path(sub_file)
        print(f"Using local subtitle file: {sub_file}")
        entries = parse_subtitle_file(sub_file)
        print(f"  {len(entries)} caption cues.")
    else:
        url = normalize_youtube_url(url)
        youtube_id = extract_youtube_id(url)
        print(f"  Normalized URL: {url}")
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            sub_path = download_subtitles(url, tmp)
            if sub_path:
                dest = Path(f"subtitles_{sub_path.name}")
                dest.write_bytes(sub_path.read_bytes())
                print(f"  Saved subtitles to: {dest}")
                entries = parse_subtitle_file(dest)
                print(f"  {len(entries)} caption cues.")
            else:
                print("No Chinese subtitles → falling back to Whisper ASR.")
                try:
                    audio_path = download_audio(url, tmp)
                except RuntimeError as exc:
                    print(f"Audio download failed: {exc}", file=sys.stderr)
                    sys.exit(1)
                entries = transcribe_with_whisper(audio_path)
                if not entries:
                    print("Whisper produced no Chinese text.", file=sys.stderr)
                    sys.exit(1)

    print(f"  YouTube ID: {youtube_id}")
    print("Building segments…")
    segments = build_segments(entries, min_sec=min_sec, max_sec=max_sec)
    print(f"  {len(segments)} segments ({min_sec:.0f}–{max_sec:.0f}s).")

    print("Enriching (HSK level, grammar tag, pinyin, target words)…")
    docs = [
        build_firestore_segment(youtube_id, seg, hsk_map, i)
        for i, seg in enumerate(segments)
    ]

    from collections import Counter
    cat_counts = Counter(d["quizCategory"] for d in docs)
    hsk_counts = Counter(d["hskLevel"] for d in docs)
    print(f"  QuizCategory breakdown: {dict(cat_counts)}")
    print(f"  HSK level breakdown:    {dict(sorted(hsk_counts.items()))}")

    output_path.write_text(
        json.dumps(docs, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"Output written to {output_path}  ({len(docs)} documents)")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="YouTube → Firestore VideoSegmentModel pipeline"
    )
    parser.add_argument("--url", required=True)
    parser.add_argument("--sub-file", type=Path)
    parser.add_argument("--hsk-map", required=True, type=Path)
    parser.add_argument("--output", default=Path("video_segments.json"), type=Path)
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
