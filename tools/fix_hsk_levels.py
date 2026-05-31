"""
Fixes dictionary hsk_level for words that appear in more than one HSK list.

Source of truth = lib/core/constants/hsk{1..6}_words.dart. A word that occurs in
several lists (e.g. 头 in HSK2 as a noun and HSK5 as a suffix) must be stored at
its LOWEST level. Seeding kept the higher one, so the app shows the wrong level.

Dry run (default): prints what would change.
Apply:  python tools/fix_hsk_levels.py --apply
Needs:  SUPABASE_SERVICE_ROLE_KEY env var.
"""

import os
import re
import sys
from pathlib import Path

import requests

SUPABASE_URL = "https://pqyceostpukueydwuiut.supabase.co"
KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
if not KEY:
    print("SUPABASE_SERVICE_ROLE_KEY not set")
    sys.exit(1)

H = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
}
APPLY = "--apply" in sys.argv

base = Path("lib/core/constants")
word_levels: dict[str, set[int]] = {}
row_re = re.compile(r"\s*\[\s*'([^']+)'")
for n in range(1, 7):
    for line in (base / f"hsk{n}_words.dart").read_text(encoding="utf-8").splitlines():
        m = row_re.match(line)
        if m:
            word_levels.setdefault(m.group(1), set()).add(n)

dups = {w: min(ls) for w, ls in word_levels.items() if len(ls) > 1}
print(f"{len(word_levels)} HSK words total; {len(dups)} appear at multiple levels")

changed = 0
for word, min_level in sorted(dups.items(), key=lambda x: x[1]):
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/dictionary",
        headers=H,
        params={"simplified": f"eq.{word}", "select": "simplified,hsk_level"},
    )
    rows = r.json() if r.ok else []
    if not rows:
        continue
    cur = rows[0].get("hsk_level")
    levels = sorted(word_levels[word])
    if cur != min_level:
        print(f"  {word}: {cur} -> {min_level}   (lists: {levels})")
        if APPLY:
            pr = requests.patch(
                f"{SUPABASE_URL}/rest/v1/dictionary",
                headers=H,
                params={"simplified": f"eq.{word}"},
                json={"hsk_level": min_level},
            )
            if not pr.ok:
                print(f"    PATCH failed {pr.status_code}: {pr.text[:120]}")
                continue
        changed += 1

print(f"{'CHANGED' if APPLY else 'WOULD CHANGE'} {changed} rows")
