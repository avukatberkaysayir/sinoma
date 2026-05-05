"""
ADIM 17 — CC Content Pipeline V2: process a CC-licensed video into
self-hosted Firestore segments.

Pipeline:
  1. Download video file from URL (Internet Archive or any HTTPS source).
  2. Attempt to download existing subtitles (VTT/SRT) from subtitle_url.
  3. If no subtitles, run Whisper transcription (faster-whisper).
  4. Upload video to Firebase Storage (or Cloudflare R2 via boto3 S3 interface).
  5. Segment transcription using youtube_miner helpers.
  6. Return Firestore-ready JSON docs with sourceType='self_hosted'.

Usage:
    # Single video — Firebase Storage:
    python cc_video_processor.py \\
        --video-url "https://archive.org/download/ID/video.mp4" \\
        --identifier my_video_001 \\
        --storage firebase \\
        --bucket YOUR_BUCKET.appspot.com \\
        --hsk-map hsk_map.json \\
        --output segments.json

    # Single video — Cloudflare R2:
    python cc_video_processor.py \\
        --video-url "https://..." \\
        --identifier my_video_001 \\
        --storage r2 \\
        --bucket r2-bucket-name \\
        --r2-endpoint https://ACCOUNT.r2.cloudflarestorage.com \\
        --r2-access-key KEY --r2-secret-key SECRET \\
        --hsk-map hsk_map.json \\
        --output segments.json

    # With existing subtitle file:
    python cc_video_processor.py \\
        --video-url "..." --identifier id \\
        --sub-url "https://archive.org/.../subs.vtt" \\
        --storage firebase --bucket BUCKET \\
        --hsk-map hsk_map.json --output out.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import urllib.request
from pathlib import Path
from typing import Any

from grammar_tagger import tag_grammar
from pinyin_helper import get_pinyin
from youtube_miner import (
    build_segments,
    compute_hsk_level,
    extract_target_words,
    parse_subtitle_file,
)

try:
    from faster_whisper import WhisperModel  # type: ignore
    _WHISPER_AVAILABLE = True
except ImportError:
    _WHISPER_AVAILABLE = False

try:
    import boto3  # type: ignore
    _BOTO3_AVAILABLE = True
except ImportError:
    _BOTO3_AVAILABLE = False


# ---------------------------------------------------------------------------
# Download helpers
# ---------------------------------------------------------------------------

def _download_file(url: str, dest: Path) -> Path:
    """Download url to dest, return dest path."""
    print(f"  Downloading: {url}")
    urllib.request.urlretrieve(url, dest)
    print(f"  Saved to: {dest}")
    return dest


# ---------------------------------------------------------------------------
# Whisper transcription
# ---------------------------------------------------------------------------

def transcribe_with_whisper(
    video_path: Path,
    model_size: str = "small",
    language: str = "zh",
) -> list[dict[str, Any]]:
    """Transcribe video audio via faster-whisper.

    Returns list of {start, end, text} matching youtube_miner format.
    """
    if not _WHISPER_AVAILABLE:
        print(
            "faster-whisper not installed. Run: pip install faster-whisper",
            file=sys.stderr,
        )
        return []

    print(f"  Transcribing with Whisper ({model_size}) — language: {language}")
    model = WhisperModel(model_size, device="cpu", compute_type="int8")
    segments, _ = model.transcribe(
        str(video_path),
        language=language,
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 300},
    )

    entries: list[dict[str, Any]] = []
    for seg in segments:
        text = seg.text.strip()
        if text and any("一" <= c <= "鿿" for c in text):
            entries.append({
                "start": round(seg.start, 3),
                "end": round(seg.end, 3),
                "text": text,
            })
    print(f"  Whisper produced {len(entries)} Chinese caption segments.")
    return entries


# ---------------------------------------------------------------------------
# Storage upload
# ---------------------------------------------------------------------------

def upload_to_firebase_storage(
    video_path: Path,
    bucket_name: str,
    object_name: str,
    credentials_path: str | None = None,
) -> str:
    """Upload video to Firebase Storage, return public download URL."""
    try:
        import firebase_admin  # type: ignore
        from firebase_admin import credentials as fa_creds, storage as fa_storage  # type: ignore
    except ImportError:
        print("firebase-admin not installed. Run: pip install firebase-admin", file=sys.stderr)
        sys.exit(1)

    if not firebase_admin._apps:
        if credentials_path:
            cred = fa_creds.Certificate(credentials_path)
        else:
            cred = fa_creds.ApplicationDefault()
        firebase_admin.initialize_app(cred, {"storageBucket": bucket_name})

    bucket = fa_storage.bucket(bucket_name)
    blob = bucket.blob(object_name)
    blob.upload_from_filename(str(video_path), content_type="video/mp4")
    blob.make_public()
    url = blob.public_url
    print(f"  Firebase Storage → {url}")
    return url


def upload_to_r2(
    video_path: Path,
    bucket_name: str,
    object_name: str,
    endpoint_url: str,
    access_key: str,
    secret_key: str,
) -> str:
    """Upload video to Cloudflare R2 (S3-compatible), return public CDN URL."""
    if not _BOTO3_AVAILABLE:
        print("boto3 not installed. Run: pip install boto3", file=sys.stderr)
        sys.exit(1)

    s3 = boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name="auto",
    )
    s3.upload_file(
        str(video_path),
        bucket_name,
        object_name,
        ExtraArgs={"ContentType": "video/mp4"},
    )
    # R2 public URL pattern: https://<bucket>.<account>.r2.cloudflarestorage.com/<key>
    # or a custom domain. The caller is responsible for setting the CDN domain.
    # We return the endpoint-based URL for now; swap to CDN URL in Firestore data if needed.
    base = endpoint_url.rstrip("/")
    url = f"{base}/{bucket_name}/{object_name}"
    print(f"  R2 → {url}")
    return url


# ---------------------------------------------------------------------------
# Firestore document builder (self_hosted variant)
# ---------------------------------------------------------------------------

def build_self_hosted_segment(
    identifier: str,
    video_url: str,
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
        "videoId": f"{identifier}_seg{index:03d}",
        "sourceType": "self_hosted",
        "youtubeId": None,
        "videoUrl": video_url,
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
# Main pipeline
# ---------------------------------------------------------------------------

def process_cc_video(
    video_url: str,
    identifier: str,
    hsk_map: dict[str, int],
    output_path: Path,
    storage: str,
    bucket: str,
    sub_url: str | None = None,
    r2_endpoint: str | None = None,
    r2_access_key: str | None = None,
    r2_secret_key: str | None = None,
    credentials_path: str | None = None,
    whisper_model: str = "small",
    min_sec: float = 5.0,
    max_sec: float = 10.0,
) -> list[dict[str, Any]]:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)

        # 1. Download video
        video_ext = Path(video_url).suffix or ".mp4"
        video_path = tmp / f"{identifier}{video_ext}"
        _download_file(video_url, video_path)

        # 2. Upload to storage → get hosted URL
        object_name = f"videos/{identifier}{video_ext}"
        if storage == "firebase":
            hosted_url = upload_to_firebase_storage(
                video_path, bucket, object_name, credentials_path
            )
        elif storage == "r2":
            if not r2_endpoint or not r2_access_key or not r2_secret_key:
                print("R2 upload requires --r2-endpoint, --r2-access-key, --r2-secret-key", file=sys.stderr)
                sys.exit(1)
            hosted_url = upload_to_r2(
                video_path, bucket, object_name,
                r2_endpoint, r2_access_key, r2_secret_key,
            )
        else:
            print(f"Unknown storage backend: {storage}", file=sys.stderr)
            sys.exit(1)

        # 3. Get subtitles
        entries: list[dict[str, Any]] = []
        if sub_url:
            sub_ext = Path(sub_url).suffix or ".vtt"
            sub_path = tmp / f"{identifier}_sub{sub_ext}"
            _download_file(sub_url, sub_path)
            entries = parse_subtitle_file(sub_path)
            print(f"  Loaded {len(entries)} caption cues from subtitle file.")

        if not entries:
            print("  No subtitle file — falling back to Whisper transcription.")
            entries = transcribe_with_whisper(video_path, model_size=whisper_model)

        if not entries:
            print("  Could not obtain transcription. Skipping.", file=sys.stderr)
            return []

        # 4. Segment and enrich
        segments = build_segments(entries, min_sec=min_sec, max_sec=max_sec)
        print(f"  Built {len(segments)} segments.")

        docs = [
            build_self_hosted_segment(identifier, hosted_url, seg, hsk_map, i)
            for i, seg in enumerate(segments)
        ]

    from collections import Counter
    hsk_counts = Counter(d["hskLevel"] for d in docs)
    cat_counts = Counter(d["quizCategory"] for d in docs)
    print(f"  HSK breakdown:      {dict(sorted(hsk_counts.items()))}")
    print(f"  Category breakdown: {dict(cat_counts)}")

    output_path.write_text(
        json.dumps(docs, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"Output written to {output_path}  ({len(docs)} documents)")
    return docs


def main() -> None:
    parser = argparse.ArgumentParser(
        description="CC video → Firebase Storage / R2 → Firestore segments"
    )
    parser.add_argument("--video-url", required=True, help="Direct HTTPS URL to the video file")
    parser.add_argument("--identifier", required=True, help="Unique slug for this video (e.g. ia_item_id)")
    parser.add_argument("--hsk-map", required=True, type=Path, help="JSON {word: level} map")
    parser.add_argument("--output", default=Path("cc_segments.json"), type=Path)
    parser.add_argument(
        "--storage", choices=["firebase", "r2"], default="firebase",
        help="Storage backend"
    )
    parser.add_argument("--bucket", required=True, help="Firebase bucket name or R2 bucket name")
    parser.add_argument("--sub-url", default=None, help="URL to .vtt or .srt subtitle file")
    parser.add_argument("--credentials", default=None, help="Path to Firebase service account JSON")
    parser.add_argument("--r2-endpoint", default=None)
    parser.add_argument("--r2-access-key", default=os.environ.get("R2_ACCESS_KEY"))
    parser.add_argument("--r2-secret-key", default=os.environ.get("R2_SECRET_KEY"))
    parser.add_argument("--whisper-model", default="small",
                        choices=["tiny", "base", "small", "medium", "large"],
                        help="Whisper model size (used only when no subtitles found)")
    parser.add_argument("--min-sec", type=float, default=5.0)
    parser.add_argument("--max-sec", type=float, default=10.0)
    args = parser.parse_args()

    hsk_map: dict[str, int] = json.loads(
        args.hsk_map.read_text(encoding="utf-8")
    )

    process_cc_video(
        video_url=args.video_url,
        identifier=args.identifier,
        hsk_map=hsk_map,
        output_path=args.output,
        storage=args.storage,
        bucket=args.bucket,
        sub_url=args.sub_url,
        r2_endpoint=args.r2_endpoint,
        r2_access_key=args.r2_access_key,
        r2_secret_key=args.r2_secret_key,
        credentials_path=args.credentials,
        whisper_model=args.whisper_model,
        min_sec=args.min_sec,
        max_sec=args.max_sec,
    )


if __name__ == "__main__":
    main()
