"""
YouTube ASR pipeline — yt-dlp audio + faster-whisper → Supabase production.

Tries caption download first (fast). Falls back to Whisper ASR for
burned-in subtitle videos.

Requires python/.env with:
    SUPABASE_URL=https://...
    SUPABASE_SERVICE_ROLE_KEY=eyJ...
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Callable

import requests

# ── .env loader ───────────────────────────────────────────────────────────────

def _load_dotenv() -> None:
    env_path = Path(__file__).parent.parent / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        os.environ.setdefault(key.strip(), val.strip())

_load_dotenv()

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://pqyceostpukueydwuiut.supabase.co")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

# ── HSK analysis via Supabase REST ───────────────────────────────────────────

def _supabase_headers() -> dict[str, str]:
    return {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
    }


def _extract_candidates(text: str) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for chunk in re.findall(r"[一-鿿]+", text):
        for i in range(len(chunk)):
            for length in range(1, min(5, len(chunk) - i + 1)):
                word = chunk[i : i + length]
                if word not in seen:
                    seen.add(word)
                    result.append(word)
    return result


def _query_dictionary(candidates: list[str]) -> list[dict[str, Any]]:
    """Batch-query Supabase dictionary for up to 100 candidates at a time."""
    if not candidates or not SUPABASE_SERVICE_KEY:
        return []
    rows: list[dict[str, Any]] = []
    batch_size = 100
    for i in range(0, len(candidates), batch_size):
        batch = candidates[i : i + batch_size]
        encoded = ",".join(batch)
        resp = requests.get(
            f"{SUPABASE_URL}/rest/v1/dictionary",
            params={"simplified": f"in.({encoded})", "select": "id,simplified,hsk_level"},
            headers=_supabase_headers(),
            timeout=30,
        )
        if resp.status_code < 300:
            rows.extend(resp.json())
    return rows


def analyze_segment(text: str) -> tuple[list[str], int]:
    """Return (word_ids, hsk_level) for a segment text. hsk_level=0 means no match."""
    candidates = _extract_candidates(text)
    if not candidates:
        return [], 0
    rows = _query_dictionary(candidates)
    if not rows:
        return [], 0
    word_ids = [r["id"] for r in rows]
    levels = [r["hsk_level"] for r in rows if r.get("hsk_level")]
    hsk_level = min(6, max(1, max(levels))) if levels else 0
    return word_ids, hsk_level


# ── Supabase insert ───────────────────────────────────────────────────────────

def insert_segments(rows: list[dict[str, Any]]) -> None:
    resp = requests.post(
        f"{SUPABASE_URL}/rest/v1/videos",
        json=rows,
        headers={**_supabase_headers(), "Prefer": "return=minimal"},
        timeout=60,
    )
    if resp.status_code >= 300:
        raise RuntimeError(
            f"Supabase insert failed {resp.status_code}: {resp.text[:300]}"
        )


# ── Main pipeline ─────────────────────────────────────────────────────────────

def run(
    url: str,
    active: bool = False,
    hsk_filter: list[int] | None = None,
    on_progress: Callable[[int], None] | None = None,
) -> dict[str, Any]:
    """Full pipeline: YouTube URL → audio → Whisper → Supabase.

    Returns {"segmentsWritten": N, "method": "subtitles"|"whisper"}.
    hsk_filter: if set, only segments whose hsk_level is in this list are inserted.
    """
    if not SUPABASE_SERVICE_KEY:
        raise RuntimeError(
            "SUPABASE_SERVICE_ROLE_KEY ayarlı değil.\n"
            "python/.env dosyasına SUPABASE_SERVICE_ROLE_KEY= satırı ekleyin.\n"
            "(Supabase Dashboard → Settings → API → Service role key)"
        )

    import tempfile
    from youtube_miner import (
        download_audio,
        download_subtitles,
        parse_subtitle_file,
        transcribe_with_whisper,
        build_segments,
        extract_youtube_id,
        normalize_youtube_url,
    )
    from pinyin_helper import get_pinyin

    url = normalize_youtube_url(url)
    youtube_id = extract_youtube_id(url)
    print(f"\n▶ YouTube ASR pipeline: {url} ({youtube_id})")

    entries: list[dict[str, Any]] = []
    method = "subtitles"

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)

        print("  Önce altyazı deneniyor…")
        sub_path = download_subtitles(url, tmp)
        if sub_path:
            print(f"  Altyazı bulundu: {sub_path.name}")
            entries = parse_subtitle_file(sub_path)
            print(f"  {len(entries)} cue.")

        if not entries:
            method = "whisper"
            print("  Altyazı yok → ses indiriliyor (Whisper ASR)…")
            audio_path = download_audio(url, tmp)
            # download_audio raises RuntimeError on failure — audio_path is always valid here
            size_kb = audio_path.stat().st_size // 1024
            print(f"  Ses: {audio_path.name} ({size_kb} KB)")
            entries = transcribe_with_whisper(audio_path)
            if not entries:
                raise RuntimeError(
                    "Whisper Çince metin üretemedi — "
                    "video Mandarin içermiyor veya ses kalitesi yetersiz."
                )

    print(f"  {len(entries)} giriş → segmentler oluşturuluyor…")
    segments = build_segments(entries)
    if not segments:
        raise RuntimeError("Segment oluşturulamadı (girişler çok kısa?).")

    print(f"  {len(segments)} segment. HSK analizi…")
    from pinyin_helper import get_pinyin  # noqa: F811 (already imported above)
    rows: list[dict[str, Any]] = []
    for seg in segments:
        word_ids, hsk_level = analyze_segment(seg["text"])
        rows.append({
            "source_type": "youtube",
            "youtube_id": youtube_id,
            "start_time": seg["start"],
            "end_time": seg["end"],
            "transcription": seg["text"],
            "pinyin": get_pinyin(seg["text"]),
            "hsk_level": hsk_level,
            "target_words": word_ids,
            "quiz_category": "general",
            "quiz": {"question": "", "correctAnswer": "", "wrongAnswer": ""},
            "is_active": active,
        })

    # Filter out hsk_level=0 (no dictionary match) and apply hsk_filter if set
    rows = [r for r in rows if r["hsk_level"] != 0]
    if hsk_filter:
        rows = [r for r in rows if r["hsk_level"] in hsk_filter]

    if not rows:
        raise RuntimeError(
            "Hiçbir segment sözlükle eşleşmedi veya filtre kapsamında değil. "
            "Farklı bir HSK filtresi deneyin ya da filtreyi kaldırın."
        )

    _BATCH = 10
    total = 0
    for i in range(0, len(rows), _BATCH):
        chunk = rows[i : i + _BATCH]
        insert_segments(chunk)
        total += len(chunk)
        print(f"  ✓ {total}/{len(rows)} segment yazıldı")
        if on_progress:
            on_progress(total)
    return {"segmentsWritten": total, "method": method}


def _audio_cache_path(youtube_id: str) -> Path:
    import tempfile
    d = Path(tempfile.gettempdir()) / "sinoma_audio_cache"
    d.mkdir(parents=True, exist_ok=True)
    return d / f"{youtube_id}.mp4"


def transcribe_clip(
    url: str,
    start: float,
    end: float,
    row_id: str,
    on_progress: Callable[[int], None] | None = None,
) -> dict[str, Any]:
    """Whisper-transcribe ONLY the [start, end] window of the clip (not the whole
    video) and write videos.whisper_text for that one row. The full audio is
    cached per youtube_id so repeated clips of the same video are fast."""
    if not SUPABASE_SERVICE_KEY:
        raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY ayarlı değil.")

    import shutil
    import tempfile
    from faster_whisper import WhisperModel
    from faster_whisper.audio import decode_audio
    from youtube_miner import (
        download_audio,
        extract_youtube_id,
        normalize_youtube_url,
    )

    url = normalize_youtube_url(url)
    youtube_id = extract_youtube_id(url)
    print(f"\n▶ Whisper clip {start:.1f}-{end:.1f}s: {youtube_id} (row {row_id[:8]})")

    cache = _audio_cache_path(youtube_id)
    if not cache.exists():
        with tempfile.TemporaryDirectory() as tmpdir:
            audio_path = download_audio(url, Path(tmpdir))
            shutil.copy(str(audio_path), str(cache))
        print(f"  Ses indirildi → cache")
    else:
        print(f"  Ses cache'ten")

    audio = decode_audio(str(cache))  # 16kHz mono float32, no ffmpeg (PyAV)
    sr = 16000
    a = max(0, int(start * sr))
    b = min(len(audio), int(end * sr))
    clip = audio[a:b] if b > a else audio
    if on_progress:
        on_progress(1)

    print(f"  [ASR] Whisper 'small' — {len(clip) / sr:.1f}s dinleniyor…")
    model = WhisperModel("small", device="cpu", compute_type="int8")
    segments, _info = model.transcribe(clip, language="zh", beam_size=1)
    text = "".join(
        s.text for s in segments
        if any("一" <= ch <= "鿿" for ch in s.text)
    ).strip()

    requests.patch(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={"id": f"eq.{row_id}"},
        json={"whisper_text": text},
        headers=_supabase_headers(),
        timeout=15,
    )
    print(f"  ✓ whisper_text yazıldı: {text[:40]}")
    return {"whisper_text": text}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--active", action="store_true")
    args = parser.parse_args()
    result = run(args.url, active=args.active)
    print(json.dumps(result, ensure_ascii=False))
