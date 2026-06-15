# Appends the Portuguese gloss as a 13th column to every word-list Dart file
# (hsk1..6_words.dart + diger_words.dart): [simplified, pinyin, pos, en, tr,
# ko, ja, id, vi, th, ru, es, pt]. Portuguese comes from the dictionary table
# (definitions->>'pt'), which the Gemini backfill (pt_backfill.py) filled.
# Idempotent: rows that already have 13 columns are left alone.
# Mirror of tools/add_es_to_wordlists.py.
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

def fetch_pt_map():
    pt = {}
    page = 2000
    off = 0
    while True:
        rows = sql("select simplified s, coalesce(definitions->>'pt','') k "
                   f"from dictionary order by id limit {page} offset {off}")
        for r in rows:
            if r["k"]:
                pt.setdefault(r["s"], r["k"])
        if len(rows) < page:
            break
        off += page
    return pt

ROW = re.compile(r"^(\s*\[)\s*('(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\")(.*?)(\],?\s*)$")

def dart_str(m):
    q = m[0]
    return m[1:-1].replace("\\" + q, q).replace("\\\\", "\\")

def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")

def count_cols(line_mid):
    return len(re.findall(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"", line_mid))

def process(path, pt):
    src = open(path, encoding="utf-8").read()
    out = []
    changed = missing = 0
    for line in src.split("\n"):
        m = ROW.match(line)
        if not m:
            out.append(line)
            continue
        head, word_lit, mid, tail = m.groups()
        if count_cols(mid) >= 12:  # word excluded → already has ko..es+pt
            out.append(line)
            continue
        word = dart_str(word_lit)
        k = pt.get(word, "")
        if not k:
            missing += 1
        out.append(f"{head}{word_lit}{mid.rstrip()}, '{esc(k)}'{tail}")
        changed += 1
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print(f"{os.path.basename(path)}: +pt on {changed} rows, "
          f"{missing} without a dictionary match")

def fix_header(path):
    src = open(path, encoding="utf-8").read()
    src = src.replace("[simplified, pinyin, pos, en, tr, ko, ja, id, vi, th, ru, es]",
                      "[simplified, pinyin, pos, en, tr, ko, ja, id, vi, th, ru, es, pt]")
    open(path, "w", encoding="utf-8", newline="\n").write(src)

def main():
    pt = fetch_pt_map()
    print(f"dictionary pt entries: {len(pt)}")
    base = os.path.join(ROOT, "lib", "core", "constants")
    for name in ["hsk1_words.dart", "hsk2_words.dart", "hsk3_words.dart",
                 "hsk4_words.dart", "hsk5_words.dart", "hsk6_words.dart",
                 "diger_words.dart"]:
        p = os.path.join(base, name)
        process(p, pt)
        fix_header(p)

if __name__ == "__main__":
    main()
