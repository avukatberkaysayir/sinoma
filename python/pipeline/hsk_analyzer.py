"""
ADIM 2 — HSK Analyzer Pipeline

Loads CC-CEDICT dictionary + HSK word lists, injects hskLevel into each
entry, and outputs Firestore-ready JSON for the `dictionary` collection.

Usage:
    python hsk_analyzer.py \
        --cedict path/to/cedict_ts.u8 \
        --hsk-dir path/to/hsk_lists/ \
        --output dictionary_seed.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Iterator


HSK_FILENAMES = {
    1: "hsk1.txt",
    2: "hsk2.txt",
    3: "hsk3.txt",
    4: "hsk4.txt",
    5: "hsk5.txt",
    6: "hsk6.txt",
}


def load_hsk_words(hsk_dir: Path) -> dict[str, int]:
    """Returns {simplified_word: hsk_level} for all 6 HSK levels."""
    word_level: dict[str, int] = {}
    for level, filename in HSK_FILENAMES.items():
        filepath = hsk_dir / filename
        if not filepath.exists():
            print(f"Warning: {filepath} not found, skipping HSK {level}.", file=sys.stderr)
            continue
        for line in filepath.read_text(encoding="utf-8").splitlines():
            word = line.strip()
            if word:
                word_level[word] = level
    return word_level


def parse_cedict(cedict_path: Path) -> Iterator[dict]:
    """
    Yields one dict per CEDICT entry:
      simplified, traditional, pinyin, definitions (list[str])
    """
    pattern = re.compile(
        r"^(\S+)\s+(\S+)\s+\[([^\]]+)\]\s+/(.+)/$"
    )
    for line in cedict_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            continue
        match = pattern.match(line.strip())
        if not match:
            continue
        traditional, simplified, pinyin_raw, defs_raw = match.groups()
        yield {
            "simplified": simplified,
            "traditional": traditional,
            "pinyin": pinyin_raw.strip(),
            "definitions": [d.strip() for d in defs_raw.split("/") if d.strip()],
        }


def build_word_id(simplified: str) -> str:
    return f"word_{simplified}"


def build_firestore_entry(
    cedict_entry: dict,
    hsk_words: dict[str, int],
) -> dict:
    simplified = cedict_entry["simplified"]
    hsk_level = hsk_words.get(simplified, 0)
    english_def = "; ".join(cedict_entry["definitions"])

    return {
        "wordId": build_word_id(simplified),
        "simplified": simplified,
        "traditional": cedict_entry["traditional"],
        "pinyin": cedict_entry["pinyin"],
        "hskLevel": hsk_level,
        "definitions": {
            "tr": "",
            "en": english_def,
            "vi": "",
        },
        "aiContextCache": {},
        "radicals": [],
        "strokeCount": 0,
    }


def run(cedict_path: Path, hsk_dir: Path, output_path: Path) -> None:
    print("Loading HSK word lists...")
    hsk_words = load_hsk_words(hsk_dir)
    print(f"  Loaded {len(hsk_words)} HSK words across 6 levels.")

    print("Parsing CC-CEDICT...")
    entries: list[dict] = []
    seen: set[str] = set()

    for cedict_entry in parse_cedict(cedict_path):
        simplified = cedict_entry["simplified"]
        if simplified in seen:
            continue
        seen.add(simplified)
        entries.append(build_firestore_entry(cedict_entry, hsk_words))

    print(f"  Parsed {len(entries)} unique entries.")

    hsk_only = [e for e in entries if e["hskLevel"] > 0]
    print(f"  {len(hsk_only)} entries have an HSK level assigned.")

    output_path.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Output written to {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="CC-CEDICT + HSK injector")
    parser.add_argument("--cedict", required=True, type=Path)
    parser.add_argument("--hsk-dir", required=True, type=Path)
    parser.add_argument("--output", default=Path("dictionary_seed.json"), type=Path)
    args = parser.parse_args()

    run(
        cedict_path=args.cedict,
        hsk_dir=args.hsk_dir,
        output_path=args.output,
    )


if __name__ == "__main__":
    main()
