"""
Reads HSK1-5 dart files, collects all simplified characters,
then filters hsk6_words.dart to remove any duplicates.
Writes a clean hsk6_words.dart in place.
"""

import re
import sys
from pathlib import Path

CONSTANTS_DIR = Path(__file__).parent.parent / "lib" / "core" / "constants"
HSK6_FILE = CONSTANTS_DIR / "hsk6_words.dart"

ENTRY_RE = re.compile(r"\[\s*'([^']+)'")


def extract_simplified_chars(dart_file: Path) -> set[str]:
    chars = set()
    for line in dart_file.read_text(encoding="utf-8").splitlines():
        m = ENTRY_RE.search(line)
        if m:
            chars.add(m.group(1))
    return chars


def parse_hsk6_entries(text: str) -> list[str]:
    """Return a list of raw entry lines (the bracket content with trailing comma)."""
    entries = []
    inside = False
    for line in text.splitlines():
        stripped = line.strip()
        if not inside and stripped.startswith("['") or (stripped.startswith("['")):
            inside = True
        if inside or stripped.startswith("['"):
            entries.append(line)
            inside = False
    return entries


def main():
    hsk_levels = [1, 2, 3, 4, 5]
    existing = set()
    for level in hsk_levels:
        f = CONSTANTS_DIR / f"hsk{level}_words.dart"
        if not f.exists():
            print(f"WARNING: {f} not found, skipping")
            continue
        chars = extract_simplified_chars(f)
        print(f"HSK{level}: {len(chars)} words")
        existing.update(chars)

    print(f"\nTotal HSK1-5 words: {len(existing)}")

    hsk6_text = HSK6_FILE.read_text(encoding="utf-8")

    # Split into header and entries block
    # Header = everything up to and including the opening "const List<..."
    header_match = re.search(r"(.*?const List<List<String>> kHsk6Words = \[)", hsk6_text, re.DOTALL)
    if not header_match:
        print("ERROR: Could not find kHsk6Words declaration")
        sys.exit(1)

    header = header_match.group(1)
    rest = hsk6_text[header_match.end():]

    # Parse individual entries — each is a multi-token line starting with ['
    # Use a state machine to capture complete bracket groups
    entry_pattern = re.compile(
        r"\[\s*'([^'\\]|\\.)*?'\s*,\s*'([^'\\]|\\.)*?'\s*,\s*'([^'\\]|\\.)*?'\s*,\s*'([^'\\]|\\.)*?'\s*,\s*'([^'\\]|\\.)*?'\s*\],?",
        re.DOTALL
    )

    all_entries = entry_pattern.findall(hsk6_text)
    # We need the full match strings, not just groups
    all_entry_spans = [(m.start(), m.end(), m.group(0)) for m in entry_pattern.finditer(hsk6_text)]

    print(f"Total HSK6 entries found: {len(all_entry_spans)}")

    kept = []
    removed = []

    for start, end, full_match in all_entry_spans:
        # Extract the simplified character (first field)
        first_field = re.search(r"\[\s*'((?:[^'\\]|\\.)*)'", full_match)
        if not first_field:
            kept.append(full_match)
            continue
        simplified = first_field.group(1)
        if simplified in existing:
            removed.append(simplified)
        else:
            kept.append(full_match)

    print(f"Removed (duplicate with HSK1-5): {len(removed)}")
    print(f"Kept (clean HSK6): {len(kept)}")
    if removed:
        print("Removed words sample:", removed[:20])

    # Rebuild the dart file
    lines = []
    lines.append("// ignore_for_file: constant_identifier_names")
    lines.append(f"// HSK Level 6 vocabulary — {len(kept)} words (filtered, New HSK 2021 standard)")
    lines.append("// Format: [simplified, pinyin, pos, en, tr]")
    lines.append("")
    lines.append("const List<List<String>> kHsk6Words = [")

    for entry in kept:
        # Normalize: ensure the entry ends with ],
        entry_clean = entry.strip()
        if entry_clean.endswith("],"):
            pass
        elif entry_clean.endswith("]"):
            entry_clean = entry_clean + ","
        lines.append(f"  {entry_clean}")

    lines.append("];")

    output = "\n".join(lines) + "\n"
    HSK6_FILE.write_text(output, encoding="utf-8")
    print(f"\nWrote {HSK6_FILE} ({len(kept)} entries)")


if __name__ == "__main__":
    main()
