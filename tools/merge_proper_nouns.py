# One-shot: merges multi-character proper nouns (巴塞罗那...) that the old
# segmenter split into single characters back into ONE token in target_words,
# for every active/pending/backup video. Unknown merged nouns are queued into
# admin > Sözlük > Önerilen (posts with is_word_suggestion). Idempotent.
import json
import os
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "pqyceostpukueydwuiut"
FN_URL = f"https://{PROJECT}.supabase.co/functions/v1/translate"
ADMIN_UID = "54bb82ba-fe25-4606-b0ea-5b07a7c6ae17"

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
                 "User-Agent": "Mozilla/5.0 (sinoma-nouns)"},
        method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:400]
        raise SystemExit(f"SQL {e.code}: {body}\nQUERY: {query[:300]}")

def proper_nouns(text):
    data = json.dumps({"text": text, "mode": "proper-nouns"}).encode("utf-8")
    for attempt in range(5):
        req = urllib.request.Request(
            FN_URL, data=data,
            headers={"Content-Type": "application/json",
                     "User-Agent": "Mozilla/5.0 (sinoma-nouns)"},
            method="POST")
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                out = json.loads(r.read().decode("utf-8"))
            return sorted({str(n) for n in out.get("nouns", []) if len(str(n)) >= 2},
                          key=len, reverse=True)
        except Exception as ex:
            print(f"  fn err: {ex}", flush=True)
            time.sleep(10)
    return []

def merge(tokens, nouns):
    out = []
    i = 0
    changed = False
    while i < len(tokens):
        merged = None
        for n in nouns:
            acc = ""
            j = i
            while j < len(tokens) and len(acc) < len(n):
                if tokens[j] == "\n":
                    break
                acc += tokens[j]
                j += 1
            # Greedy: the next tokens exactly compose the noun (and it is
            # actually split, i.e. more than one piece).
            if acc == n and j - i > 1:
                merged = (n, j)
                break
        if merged:
            out.append(merged[0])
            i = merged[1]
            changed = True
        else:
            out.append(tokens[i])
            i += 1
    return out, changed

def esc(s):
    return s.replace("'", "''")

def main():
    rows = sql("select id, coalesce(transcription,'') zh, target_words tw "
               "from videos where status in ('active','pending','backup') "
               "and coalesce(transcription,'') <> '' order by id")
    print(f"{len(rows)} videos to scan", flush=True)
    updated = 0
    all_missing = set()
    for r in rows:
        tw = r.get("tw") or []
        if not isinstance(tw, list) or not tw:
            continue
        nouns = proper_nouns(r["zh"])
        if not nouns:
            continue
        merged, changed = merge([str(t) for t in tw], nouns)
        if not changed:
            continue
        arr = ",".join(f"'{esc(t)}'" for t in merged)
        sql(f"update videos set target_words = ARRAY[{arr}]::text[] "
            f"where id = '{esc(r['id'])}'")
        updated += 1
        newly = [n for n in nouns if n in merged]
        print(f"  {r['id']}: merged {newly}", flush=True)
        all_missing.update(newly)
        time.sleep(1.5)
    # Queue merged nouns the dictionary doesn't know into Önerilen.
    if all_missing:
        words = list(all_missing)
        inlist = ",".join(f"'{esc(w)}'" for w in words)
        known = {r["simplified"] for r in sql(
            f"select simplified from dictionary where simplified in ({inlist})")}
        queued = {r["content"] for r in sql(
            "select content from posts "
            "where metadata->>'is_word_suggestion' = 'true' "
            f"and content in ({inlist})")}
        for w in words:
            if w in known or w in queued:
                continue
            meta = json.dumps({"is_word_suggestion": True, "word": w,
                               "suggested_by_email": "proper-noun-backfill"},
                              ensure_ascii=False)
            sql("insert into posts (author_id, content, post_type, likes, metadata) "
                f"values ('{ADMIN_UID}', '{esc(w)}', 'text', ARRAY[]::text[], "
                f"'{esc(meta)}'::jsonb)")
            print(f"  suggested: {w}", flush=True)
    print(f"FINISHED. videos updated: {updated}, "
          f"nouns seen: {len(all_missing)}", flush=True)

if __name__ == "__main__":
    main()
