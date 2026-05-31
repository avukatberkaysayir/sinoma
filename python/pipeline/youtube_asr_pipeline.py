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


def transcribe_and_fill_whisper(
    url: str,
    on_progress: Callable[[int], None] | None = None,
) -> dict[str, Any]:
    """Whisper-transcribe a video ONCE and fill videos.whisper_text for every
    existing clip of that youtube_id (matched by time overlap). The admin then
    compares the auto-caption transcription with this Whisper draft and picks."""
    if not SUPABASE_SERVICE_KEY:
        raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY ayarlı değil.")

    import tempfile
    from youtube_miner import (
        download_audio,
        transcribe_with_whisper,
        extract_youtube_id,
        normalize_youtube_url,
    )

    url = normalize_youtube_url(url)
    youtube_id = extract_youtube_id(url)
    print(f"\n▶ Whisper draft: {url} ({youtube_id})")

    with tempfile.TemporaryDirectory() as tmpdir:
        audio_path = download_audio(url, Path(tmpdir))
        print(f"  Ses indirildi → Whisper…")
        entries = transcribe_with_whisper(audio_path)
    if not entries:
        raise RuntimeError("Whisper Çince metin üretemedi.")

    resp = requests.get(
        f"{SUPABASE_URL}/rest/v1/videos",
        params={
            "youtube_id": f"eq.{youtube_id}",
            "select": "id,start_time,end_time",
        },
        headers=_supabase_headers(),
        timeout=30,
    )
    clips = resp.json() if resp.status_code < 300 else []
    if not clips:
        raise RuntimeError("Bu videonun klibi bulunamadı (önce içe aktarın).")

    margin = 0.6
    filled = 0
    for clip in clips:
        s = float(clip["start_time"])
        e = float(clip["end_time"])
        text = "".join(
            en["text"] for en in entries
            if en["end"] > s - margin and en["start"] < e + margin
        ).strip()
        if not text:
            continue
        requests.patch(
            f"{SUPABASE_URL}/rest/v1/videos",
            params={"id": f"eq.{clip['id']}"},
            json={"whisper_text": text},
            headers=_supabase_headers(),
            timeout=15,
        )
        filled += 1
        if on_progress:
            on_progress(filled)

    print(f"  ✓ {filled}/{len(clips)} klibe Whisper metni yazıldı")
    return {"whisperFilled": filled, "clips": len(clips)}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--active", action="store_true")
    args = parser.parse_args()
    result = run(args.url, active=args.active)
    print(json.dumps(result, ensure_ascii=False))
