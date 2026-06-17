# Appends the French gloss as a 14th column to every word-list Dart file
# (hsk1..6_words.dart + diger_words.dart): [simplified, pinyin, pos, en, tr,
# ko, ja, id, vi, th, ru, es, pt, fr]. French comes from the dictionary table
# (definitions->>'fr'), which the Gemini backfill (fr_backfill.py) filled.
# Idempotent: rows that already have 14 columns are left alone.
# Mirror of tools/add_pt_to_wordlists.py.
import json
import os
import re
import sys
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "pqyceostpukueydwuiut"

def load_pat():
    with open(os.path.join(ROOT, ".deploy.env"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("SUPABASE_ACCESS_TOKEN="):
                return line.split("=", 1)[1].strip()
    raise SystemExit("no PAT")

PAT = load_pat()

def sql(query):
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={"Authorization": f"Bearer {PAT}",
                 "Content-Type": "application/json",
                 "User-Agent": "Mozilla/5.0 (sinoma-wordlists)"},
        method="POST")
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode("utf-8"))

def fetch_fr_map():
    fr = {}
    page = 2000
    off = 0
    while True:
        rows = sql("select simplified s, coalesce(definitions->>'fr','') k "
                   f"from dictionary order by id limit {page} offset {off}")
        for r in rows:
            if r["k"]:
                fr.setdefault(r["s"], r["k"])
        if len(rows) < page:
            break
        off += page
    return fr

ROW = re.compile(r"^(\s*\[)\s*('(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\")(.*?)(\],?\s*)$")

def dart_str(m):
    q = m[0]
    return m[1:-1].replace("\\" + q, q).replace("\\\\", "\\")

def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")

def count_cols(line_mid):
    return len(re.findall(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"", line_mid))

def process(path, fr):
    src = open(path, encoding="utf-8").read()
    out = []
    changed = missing = 0
    for line in src.split("\n"):
        m = ROW.match(line)
        if not m:
            out.append(line)
            continue
        head, word_lit, mid, tail = m.groups()
        if count_cols(mid) >= 13:  # word excluded → already has ko..pt+fr
            out.append(line)
            continue
        word = dart_str(word_lit)
        k = fr.get(word, "")
        if not k:
            missing += 1
        out.append(f"{head}{word_lit}{mid.rstrip()}, '{esc(k)}'{tail}")
        changed += 1
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print(f"{os.path.basename(path)}: +fr on {changed} rows, "
          f"{missing} without a dictionary match")

def fix_header(path):
    src = open(path, encoding="utf-8").read()
    src = src.replace("[simplified, pinyin, pos, en, tr, ko, ja, id, vi, th, ru, es, pt]",
                      "[simplified, pinyin, pos, en, tr, ko, ja, id, vi, th, ru, es, pt, fr]")
    open(path, "w", encoding="utf-8", newline="\n").write(src)

def main():
    fr = fetch_fr_map()
    print(f"dictionary fr entries: {len(fr)}")
    base = os.path.join(ROOT, "lib", "core", "constants")
    for name in ["hsk1_words.dart", "hsk2_words.dart", "hsk3_words.dart",
                 "hsk4_words.dart", "hsk5_words.dart", "hsk6_words.dart",
                 "diger_words.dart"]:
        p = os.path.join(base, name)
        process(p, fr)
        fix_header(p)

if __name__ == "__main__":
    main()
