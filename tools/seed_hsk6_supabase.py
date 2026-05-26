"""
Reads hsk6_words.dart and seeds all words directly into Supabase dictionary table.
Uses service role key (bypasses RLS).
"""

import re
import json
import time
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "requests"])
    import requests

SUPABASE_URL = "https://pqyceostpukueydwuiut.supabase.co"
SERVICE_ROLE_KEY = ""  # set SUPABASE_SERVICE_ROLE_KEY env var before running

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates",
}

ACCENT_MAP = {
    'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
    'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
    'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
    'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
    'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
    'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
}

def strip_accents(pinyin: str) -> str:
    return ''.join(ACCENT_MAP.get(c, c) for c in pinyin)


def parse_dart_entries(dart_file: Path) -> list[dict]:
    text = dart_file.read_text(encoding="utf-8")
    pattern = re.compile(
        r"\[\s*'((?:[^'\\]|\\.)*)'\s*,\s*'((?:[^'\\]|\\.)*)'\s*,\s*'((?:[^'\\]|\\.)*)'\s*,\s*'((?:[^'\\]|\\.)*)'\s*,\s*'((?:[^'\\]|\\.)*)'\s*\]",
        re.DOTALL
    )
    rows = []
    seen = set()
    for m in pattern.finditer(text):
        simplified, pinyin, pos, en, tr = (
            m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
        )
        if simplified in seen:
            continue
        seen.add(simplified)
        rows.append({
            "id": simplified,
            "simplified": simplified,
            "traditional": simplified,
            "pinyin": pinyin,
            "pinyin_ascii": strip_accents(pinyin),
            "hsk_level": 6,
            "definitions": {"en": en, "tr": tr, "vi": "", "pos": pos},
            "ai_context_cache": {},
            "radicals": [],
            "stroke_count": 0,
        })
    return rows


def upsert_batch(rows: list[dict]) -> int:
    url = f"{SUPABASE_URL}/rest/v1/dictionary"
    resp = requests.post(url, headers=HEADERS, data=json.dumps(rows), timeout=30)
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"HTTP {resp.status_code}: {resp.text[:300]}")
    return len(rows)


def main():
    dart_file = Path(__file__).parent.parent / "lib" / "core" / "constants" / "hsk6_words.dart"
    print(f"Parsing {dart_file}...")
    rows = parse_dart_entries(dart_file)
    print(f"Parsed {len(rows)} entries")

    batch_size = 50
    total = 0
    batches = [rows[i:i+batch_size] for i in range(0, len(rows), batch_size)]
    print(f"Uploading {len(batches)} batches of {batch_size}...\n")

    for idx, batch in enumerate(batches, 1):
        try:
            upsert_batch(batch)
            total += len(batch)
            print(f"  Batch {idx}/{len(batches)} — {total}/{len(rows)} words uploaded", end="\r")
        except RuntimeError as e:
            print(f"\nERROR at batch {idx}: {e}")
            print("Aborting.")
            sys.exit(1)
        time.sleep(0.05)  # avoid rate-limiting

    print(f"\n\nDone! {total} HSK6 words seeded into Supabase.")


if __name__ == "__main__":
    main()
