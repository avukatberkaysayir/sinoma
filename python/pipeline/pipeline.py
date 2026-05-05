"""
ADIM 10 / 17 — End-to-End Content Pipeline Orchestrator

Supports two source modes:
  youtube  (ADIM 10) — YouTube embed-only via yt-dlp subtitles
  cc       (ADIM 17) — CC-BY/CC-BY-SA self-hosted via Internet Archive + Whisper

YouTube usage:
    python pipeline.py \\
        --url "https://www.youtube.com/watch?v=VIDEO_ID" \\
        --hsk-map hsk_map.json \\
        --output segments.json

CC / self-hosted usage:
    python pipeline.py --source cc \\
        --url "https://archive.org/download/ID/video.mp4" \\
        --identifier ia_item_001 \\
        --storage firebase --bucket YOUR_BUCKET.appspot.com \\
        --hsk-map hsk_map.json \\
        --output cc_segments.json \\
        --upload --credentials serviceAccount.json

Batch YouTube with Firestore upload:
    python pipeline.py \\
        --urls-file channels.txt \\
        --hsk-map hsk_map.json \\
        --output all_segments.json \\
        --upload --credentials path/to/serviceAccount.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from youtube_miner import run as mine_video


def load_urls(url: str | None, urls_file: Path | None) -> list[str]:
    urls: list[str] = []
    if url:
        urls.append(url)
    if urls_file:
        lines = urls_file.read_text(encoding="utf-8").splitlines()
        for line in lines:
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                urls.append(stripped)
    return urls


def run_pipeline(
    urls: list[str],
    hsk_map: dict[str, int],
    merged_output: Path,
    sub_files: list[Path] | None = None,
    min_sec: float = 5.0,
    max_sec: float = 10.0,
    upload: bool = False,
    credentials: Path | None = None,
    collection: str = "videos",
) -> list[dict]:
    all_docs: list[dict] = []

    sub_file_queue = list(sub_files) if sub_files else []

    for i, url in enumerate(urls):
        sub_file = sub_file_queue[i] if i < len(sub_file_queue) else None
        tmp_out = Path(f"_tmp_pipeline_{i:04d}.json")

        print(f"\n{'='*60}")
        print(f"[{i+1}/{len(urls)}] {url}")

        try:
            mine_video(
                url=url,
                hsk_map=hsk_map,
                output_path=tmp_out,
                sub_file=sub_file,
                min_sec=min_sec,
                max_sec=max_sec,
            )
            docs = json.loads(tmp_out.read_text(encoding="utf-8"))
            all_docs.extend(docs)
            print(f"  → {len(docs)} segments collected (total so far: {len(all_docs)})")
        except SystemExit as exc:
            print(f"  ✗ Skipped (pipeline error: {exc})", file=sys.stderr)
        finally:
            if tmp_out.exists():
                tmp_out.unlink()

    print(f"\n{'='*60}")
    print(f"Total segments: {len(all_docs)}")

    merged_output.write_text(
        json.dumps(all_docs, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"Merged output written to {merged_output}")

    if upload:
        if not credentials:
            print("--credentials required for --upload. Skipping Firestore upload.", file=sys.stderr)
        else:
            _upload(all_docs, credentials, collection)

    return all_docs


def run_cc_pipeline(
    video_url: str,
    identifier: str,
    hsk_map: dict[str, int],
    merged_output: Path,
    storage: str,
    bucket: str,
    sub_url: str | None = None,
    r2_endpoint: str | None = None,
    r2_access_key: str | None = None,
    r2_secret_key: str | None = None,
    credentials: Path | None = None,
    whisper_model: str = "small",
    min_sec: float = 5.0,
    max_sec: float = 10.0,
    upload: bool = False,
    collection: str = "videos",
) -> list[dict]:
    from cc_video_processor import process_cc_video

    print(f"\n{'='*60}")
    print(f"CC video: {video_url}")
    print(f"Identifier: {identifier}")

    docs = process_cc_video(
        video_url=video_url,
        identifier=identifier,
        hsk_map=hsk_map,
        output_path=merged_output,
        storage=storage,
        bucket=bucket,
        sub_url=sub_url,
        r2_endpoint=r2_endpoint,
        r2_access_key=r2_access_key,
        r2_secret_key=r2_secret_key,
        credentials_path=str(credentials) if credentials else None,
        whisper_model=whisper_model,
        min_sec=min_sec,
        max_sec=max_sec,
    )

    if upload and docs:
        if not credentials:
            print("--credentials required for --upload. Skipping Firestore upload.", file=sys.stderr)
        else:
            _upload(docs, credentials, collection)

    return docs


def _upload(docs: list[dict], credentials: Path, collection: str) -> None:
    try:
        import firebase_admin
        from firebase_admin import credentials as fb_creds, firestore
        from google.cloud.firestore_v1 import SERVER_TIMESTAMP
    except ImportError:
        print(
            "firebase-admin not installed. Run: pip install firebase-admin",
            file=sys.stderr,
        )
        return

    if not firebase_admin._apps:
        cred = fb_creds.Certificate(str(credentials))
        firebase_admin.initialize_app(cred)

    db = firestore.client()
    batch_size = 500
    total = len(docs)
    uploaded = 0

    for i in range(0, total, batch_size):
        batch = db.batch()
        chunk = docs[i : i + batch_size]
        for doc in chunk:
            doc_id = doc.get("videoId")
            if not doc_id:
                continue
            payload = {k: v for k, v in doc.items() if k != "videoId"}
            if payload.get("createdAt") is None:
                payload["createdAt"] = SERVER_TIMESTAMP
            ref = db.collection(collection).document(doc_id)
            batch.set(ref, payload, merge=True)
        batch.commit()
        uploaded += len(chunk)
        print(f"  Uploaded {uploaded}/{total}...")

    print(f"Done. {uploaded} documents written to `{collection}`.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="End-to-end Mandarin Academy content pipeline"
    )
    parser.add_argument(
        "--source", choices=["youtube", "cc"], default="youtube",
        help="Content source: 'youtube' (ADIM 10) or 'cc' (ADIM 17 self-hosted)"
    )

    # YouTube mode arguments
    yt_group = parser.add_mutually_exclusive_group()
    yt_group.add_argument("--url", help="Single YouTube URL (youtube mode) or video URL (cc mode)")
    yt_group.add_argument("--urls-file", type=Path, help="File with one YouTube URL per line (youtube mode)")
    parser.add_argument(
        "--sub-files", type=Path, nargs="+",
        help="Local .vtt/.srt files (one per URL, youtube mode only)"
    )

    # CC mode arguments
    parser.add_argument("--identifier", help="Unique slug for the CC video (cc mode)")
    parser.add_argument("--sub-url", help="Direct URL to .vtt/.srt subtitle file (cc mode)")
    parser.add_argument(
        "--storage", choices=["firebase", "r2"], default="firebase",
        help="Storage backend (cc mode)"
    )
    parser.add_argument("--bucket", help="Firebase bucket or R2 bucket name (cc mode)")
    parser.add_argument("--r2-endpoint", default=None, help="R2 endpoint URL (cc mode)")
    parser.add_argument("--r2-access-key", default=None, help="R2 access key (cc mode)")
    parser.add_argument("--r2-secret-key", default=None, help="R2 secret key (cc mode)")
    parser.add_argument(
        "--whisper-model", default="small",
        choices=["tiny", "base", "small", "medium", "large"],
        help="Whisper model size for transcription fallback (cc mode)"
    )

    # Shared arguments
    parser.add_argument("--hsk-map", required=True, type=Path)
    parser.add_argument("--output", default=Path("segments.json"), type=Path)
    parser.add_argument("--min-sec", type=float, default=5.0)
    parser.add_argument("--max-sec", type=float, default=10.0)
    parser.add_argument("--upload", action="store_true", help="Upload to Firestore after processing")
    parser.add_argument("--credentials", type=Path, help="Firebase service account JSON")
    parser.add_argument("--collection", default="videos", help="Firestore collection name")
    args = parser.parse_args()

    hsk_map: dict[str, int] = json.loads(
        args.hsk_map.read_text(encoding="utf-8")
    )

    if args.source == "cc":
        if not args.url:
            parser.error("--source cc requires --url (direct video URL)")
        if not args.identifier:
            parser.error("--source cc requires --identifier")
        if not args.bucket:
            parser.error("--source cc requires --bucket")

        run_cc_pipeline(
            video_url=args.url,
            identifier=args.identifier,
            hsk_map=hsk_map,
            merged_output=args.output,
            storage=args.storage,
            bucket=args.bucket,
            sub_url=args.sub_url,
            r2_endpoint=args.r2_endpoint,
            r2_access_key=args.r2_access_key,
            r2_secret_key=args.r2_secret_key,
            credentials=args.credentials,
            whisper_model=args.whisper_model,
            min_sec=args.min_sec,
            max_sec=args.max_sec,
            upload=args.upload,
            collection=args.collection,
        )
    else:
        if not args.url and not args.urls_file:
            parser.error("--source youtube requires --url or --urls-file")

        urls = load_urls(args.url, args.urls_file)
        if not urls:
            print("No URLs found. Check --url or --urls-file content.", file=sys.stderr)
            sys.exit(1)

        run_pipeline(
            urls=urls,
            hsk_map=hsk_map,
            merged_output=args.output,
            sub_files=args.sub_files,
            min_sec=args.min_sec,
            max_sec=args.max_sec,
            upload=args.upload,
            credentials=args.credentials,
            collection=args.collection,
        )


if __name__ == "__main__":
    main()
