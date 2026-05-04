"""
ADIM 10 — Firestore Batch Uploader

Reads JSON output from hsk_analyzer.py or youtube_miner.py and
batch-uploads documents to Firestore.

Usage:
    python firestore_uploader.py \
        --input dictionary_seed.json \
        --collection dictionary \
        --id-field wordId \
        --credentials path/to/serviceAccount.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore


BATCH_SIZE = 500


def upload_collection(
    db: firestore.Client,
    collection: str,
    documents: list[dict],
    id_field: str,
) -> None:
    total = len(documents)
    uploaded = 0

    for i in range(0, total, BATCH_SIZE):
        batch = db.batch()
        chunk = documents[i : i + BATCH_SIZE]

        for doc in chunk:
            doc_id = doc.get(id_field)
            if not doc_id:
                print(f"Warning: missing '{id_field}' in document, skipping.", file=sys.stderr)
                continue
            payload = {k: v for k, v in doc.items() if k != id_field}
            ref = db.collection(collection).document(doc_id)
            batch.set(ref, payload, merge=True)

        batch.commit()
        uploaded += len(chunk)
        print(f"  Uploaded {uploaded}/{total}...")

    print(f"Done. {uploaded} documents written to `{collection}`.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Firestore batch uploader")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--collection", required=True)
    parser.add_argument("--id-field", required=True, help="Field to use as Firestore document ID")
    parser.add_argument("--credentials", required=True, type=Path)
    args = parser.parse_args()

    print(f"Loading {args.input}...")
    documents: list[dict] = json.loads(args.input.read_text(encoding="utf-8"))
    print(f"  {len(documents)} documents to upload.")

    cred = credentials.Certificate(str(args.credentials))
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    upload_collection(db, args.collection, documents, args.id_field)


if __name__ == "__main__":
    main()
