"""
Movie → Supabase pipeline (production).

Local movie file → subtitles (external SRT/VTT, embedded MKV track, or Whisper)
→ per-segment ffmpeg clip → upload each clip to the public Supabase Storage
'clips' bucket → insert a `videos` row (source_type=self_hosted, video_url =
the clip's HTTPS Storage URL) so end users on the deployed site can play them.

Streaming: clips are extracted + uploaded + inserted one at a time, so they
appear in the admin "pending" tab progressively (works for hour-long movies).
Text is converted Traditional→Simplified at the source (see youtube_miner).

Replaces the legacy movie_pipeline.py (Firestore emulator + localhost clips).
"""
from __future__ import annotations

import re
import tempfile
from pathlib import Path
from typing import Any, Callable

import requests

from youtube_asr_pipeline import (
    SUPABASE_URL,
    SUPABASE_SERVICE_KEY,
    analyze_segment,
    classify_segment,
    gate_coherence,
    insert_segments,
)

CLIPS_BUCKET = "clips"
MIN_SEG = 1.5
MAX_SEG = 10.0


def _upload_clip(local_path: Path, dest_path: str) -> str:
    """Upload an MP4 to the public 'clips' bucket; return its public HTTPS URL."""
    data = local_path.read_bytes()
    resp = requests.post(
        f"{SUPABASE_URL}/storage/v1/object/{CLIPS_BUCKET}/{dest_path}",
        headers={
            "apikey": SUPABASE_SERVICE_KEY,
            "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
            "Content-Type": "video/mp4",
            "x-upsert": "true",
        },
        data=data,
        timeout=180,
    )
    if resp.status_code >= 300:
        raise RuntimeError(f"Storage upload {resp.status_code}: {resp.text[:200]}")
    return f"{SUPABASE_URL}/storage/v1/object/public/{CLIPS_BUCKET}/{dest_path}"


def run(
    video_path: Path,
    sub_path: Path | None = None,
    active: bool = False,
    hsk_filter: list[int] | None = None,
    max_clips: int = 0,
    offset: int = 0,
    on_progress: Callable[[int], None] | None = None,
) -> dict[str, Any]:
    """Process a local movie file → Supabase. Returns {clipsWritten, method}."""
    if not SUPABASE_SERVICE_KEY:
        raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY ayarlı değil (python/.env).")

    from clip_extractor import check_ffmpeg, extract_clip, extract_embedded_subs
    from youtube_miner import (
        parse_subtitle_file,
        stream_segments,
        iter_whisper_cues,
    )
    from pinyin_helper import get_pinyin

    if not check_ffmpeg():
        raise RuntimeError(
            "ffmpeg bulunamadı. `pip install imageio-ffmpeg` veya "
            "`winget install Gyan.FFmpeg` ile kurun."
        )
    if not video_path.exists():
        raise RuntimeError(f"Video bulunamadı: {video_path}")

    slug = re.sub(r"[^A-Za-z0-9_-]", "_", video_path.stem)[:28] or "movie"
    print(f"\n🎬 Movie → Supabase: {video_path.name} (slug={slug})")

    # ── Resolve a cue source (entries iterable of {start,end,text}, Simplified) ──
    method = "subtitles"
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        if sub_path and sub_path.exists():
            print(f"  📄 Altyazı dosyası: {sub_path.name}")
            cues: Any = parse_subtitle_file(sub_path)
        else:
            embedded = tmp / "embedded.srt"
            if extract_embedded_subs(video_path, embedded):
                print("  📄 Gömülü altyazı bulundu.")
                cues = parse_subtitle_file(embedded)
            else:
                method = "whisper"
                print("  🎙️  Altyazı yok → Whisper ASR (uzun videolarda yavaş)…")
                cues = iter_whisper_cues(video_path)

        inserted = 0
        seg_index = 0
        gated = 0
        buf: list[dict[str, Any]] = []
        pending: list[dict[str, Any]] = []  # gate-approved candidates queue

        def _flush(force: bool = False) -> None:
            nonlocal inserted, buf
            if buf and (force or len(buf) >= 5):
                insert_segments(buf)
                inserted += len(buf)
                buf = []
                print(f"  ✓ {inserted} klip yazıldı (akışlı)")
                if on_progress:
                    on_progress(inserted)

        def _process(cand: dict[str, Any]) -> None:
            """ffmpeg-clip + upload + buffer one gate-approved candidate."""
            nonlocal seg_index
            seg_index += 1
            clip_path = tmp / f"{slug}_{seg_index:04d}.mp4"
            if not extract_clip(video_path, cand["start"], cand["end"], clip_path):
                print(f"    ✗ ffmpeg klip {seg_index} başarısız, atlanıyor")
                return
            dest = f"{slug}/{seg_index:04d}.mp4"
            try:
                clip_url = _upload_clip(clip_path, dest)
            except RuntimeError as exc:
                print(f"    ✗ upload {seg_index}: {exc}")
                return
            try:
                clip_path.unlink()
            except OSError:
                pass
            grammar, life = classify_segment(cand["text"])
            buf.append({
                "source_type": "self_hosted",
                "video_url": clip_url,
                "start_time": 0.0,
                "end_time": round(cand["end"] - cand["start"], 3),
                "transcription": cand["text"],
                "pinyin": get_pinyin(cand["text"]),
                "hsk_level": cand["hsk_level"],
                "hsk_levels": [cand["hsk_level"]],
                "target_words": cand["word_ids"],
                "quiz_category": grammar[0],
                "quiz_categories": grammar,
                "life_category": life[0],
                "life_categories": life,
                "quiz": {"question": "", "correctAnswer": "", "wrongAnswer": ""},
                "is_active": active,
            })
            _flush()

        def _drain(force: bool = False) -> None:
            """Run the coherence gate (layer E) over queued candidates BEFORE any
            clip is cut/uploaded, so hallucinated text never produces an orphan
            file in storage."""
            nonlocal pending, gated
            if pending and (force or len(pending) >= 8):
                keep = gate_coherence([c["text"] for c in pending])
                for cand, k in zip(pending, keep):
                    if k:
                        if not (max_clips and inserted >= max_clips):
                            _process(cand)
                    else:
                        gated += 1
                pending = []

        cand_seen = 0
        for seg in stream_segments(cues, min_sec=MIN_SEG, max_sec=MAX_SEG):
            if offset and cand_seen < offset:
                cand_seen += 1
                continue
            if max_clips and inserted >= max_clips:
                break

            word_ids, hsk_level = analyze_segment(seg["text"])
            if hsk_level == 0:
                continue
            if hsk_filter and hsk_level not in hsk_filter:
                continue
            cand_seen += 1
            pending.append({
                "text": seg["text"], "start": seg["start"], "end": seg["end"],
                "word_ids": word_ids, "hsk_level": hsk_level,
            })
            _drain()

        _drain(force=True)
        _flush(force=True)

    if gated:
        print(f"  ⚠ {gated} segment tutarlılık kapısında elendi (halüsinasyon)")
    if cand_seen == 0:
        raise RuntimeError("Çince diyalog bulunamadı (altyazı/ses yetersiz).")
    if inserted == 0:
        raise RuntimeError(
            "Hiçbir segment yazılamadı — sözlük eşleşmesi yok, filtre dışı, "
            "veya tutarlılık kapısı hepsini halüsinasyon saydı."
        )
    return {"clipsWritten": inserted, "method": method, "gatedOut": gated}


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(
        description="Local movie file → Supabase Storage clips + videos rows"
    )
    parser.add_argument("--video", required=True, type=Path)
    parser.add_argument("--sub", type=Path, help="External .srt/.vtt/.ass (optional)")
    parser.add_argument("--active", action="store_true")
    parser.add_argument("--max-clips", type=int, default=0)
    parser.add_argument("--offset", type=int, default=0)
    args = parser.parse_args()
    res = run(
        args.video,
        sub_path=args.sub,
        active=args.active,
        max_clips=args.max_clips,
        offset=args.offset,
        on_progress=lambda n: None,
    )
    print(res)


if __name__ == "__main__":
    main()
