# Indonesian dictionary backfill: translates every dictionary entry's gloss into
# natural Indonesian (definitions.id) with Gemini, then mirrors it onto
# path_word_slots.id. Resumable: only rows with empty id are fetched.
# Mirror of tools/ja_backfill.py.
import json
import os
import sys
import time
import urllib.request
import urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "pqyceostpukueydwuiut"
MODEL = "gemini-2.5-flash-lite"
BATCH = 40

def load_pat():
    with open(os.path.join(ROOT, ".deploy.env"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("SUPABASE_ACCESS_TOKEN="):
                return line.split("=", 1)[1].strip()
    raise SystemExit("no PAT")

PAT = load_pat()
# Gemini keys only exist server-side, so all Gemini traffic goes through the
# temporary ko-batch edge function (a generic prompt proxy, reused here).
FN_URL = f"https://{PROJECT}.supabase.co/functions/v1/ko-batch"
GUARD = "sinoma-ko-backfill-2026"

def sql(query):
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={"Authorization": f"Bearer {PAT}",
                 "Content-Type": "application/json",
                 "User-Agent": "Mozilla/5.0 (sinoma-id-backfill)"},
        method="POST")
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")[:300]
            if e.code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(5 * (attempt + 1)); continue
            raise SystemExit(f"SQL fail {e.code}: {body}\n{query[:200]}")
        except Exception:
            if attempt < 3:
                time.sleep(5); continue
            raise

PROMPT = (
    "You are a professional Chinese-Indonesian lexicographer compiling a "
    "kamus Tionghoa-Indonesia (Chinese-Indonesian learner's dictionary) for "
    "Indonesian native speakers studying Mandarin.\n"
    "For each entry below, write the Indonesian dictionary gloss of the Chinese "
    "word. Rules:\n"
    "- Natural, idiomatic standard Indonesian (bahasa baku) exactly as a "
    "published KBBI-style dictionary would print it. Never translate "
    "word-by-word from English.\n"
    "- 1-3 senses, comma-separated, concise. No sentences, no explanations, "
    "no pinyin.\n"
    "- Verbs in their standard form with correct affixation (e.g. belajar, "
    "membaca, pergi); adjectives plain (besar, cantik); nouns as plain nouns.\n"
    "- Particles/measure words/grammar words: give the standard Indonesian "
    "linguistic description (e.g. 的 -> 'partikel kepemilikan/penghubung').\n"
    "- Match the part of speech given.\n"
    "Return ONLY a JSON object mapping each id to its Indonesian gloss string.\n\n"
    "Entries:\n"
)

# Each model has its own free-tier quota bucket — rotate when one runs dry.
MODELS = ["gemini-flash-lite-latest", "gemini-flash-latest",
          "gemini-2.5-flash", "gemini-2.5-flash-lite"]
model_i = 0

def gemini(batch):
    global model_i
    entries = "\n".join(
        f"- id:{r['id']} word:{r['zh']} pinyin:{r['pinyin']} pos:{r['pos']} "
        f"english:{r['en']}" for r in batch)
    for attempt in range(10):
        data = json.dumps({"prompt": PROMPT + entries,
                           "temperature": 0.2,
                           "model": MODELS[model_i % len(MODELS)]
                           }).encode("utf-8")
        req = urllib.request.Request(
            FN_URL, data=data,
            headers={"Content-Type": "application/json",
                     "x-backfill-guard": GUARD,
                     "User-Agent": "Mozilla/5.0 (sinoma-id-backfill)"},
            method="POST")
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                out = json.loads(r.read().decode("utf-8"))
            return json.loads(out["text"])
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")[:200]
            print(f"  fn {e.code} [{MODELS[model_i % len(MODELS)]}]: {body}",
                  flush=True)
            if e.code in (429, 502):
                model_i += 1  # try the next quota bucket immediately
                time.sleep(5)
            else:
                time.sleep(5)
        except Exception as ex:
            print(f"  fn err: {ex}", flush=True)
            time.sleep(5)
    return {}

def esc(s):
    return s.replace("'", "''")

def main():
    total_done = 0
    while True:
        rows = sql(
            "select id, simplified zh, pinyin, "
            "coalesce(definitions->>'en','') en, "
            "coalesce(definitions->>'pos','') pos "
            "from dictionary "
            "where coalesce(definitions->>'id','') = '' "
            "order by hsk_level, id limit %d" % BATCH)
        if not rows:
            break
        result = gemini(rows)
        ok = {str(k): v.strip() for k, v in result.items()
              if isinstance(v, str) and v.strip()}
        if not ok:
            print("empty gemini batch, retrying after 20s"); time.sleep(20)
            continue
        values = ",".join(f"('{esc(i)}','{esc(k)}')" for i, k in ok.items())
        sql("update dictionary d set definitions = "
            "jsonb_set(coalesce(d.definitions,'{}'::jsonb),'{id}',"
            "to_jsonb(v.idn)) "
            f"from (values {values}) as v(id, idn) where d.id = v.id")
        total_done += len(ok)
        print(f"done {total_done} (+{len(ok)})", flush=True)
        time.sleep(4)  # stay under the shared 20 req/min free-tier window
    # Mirror onto path slots (word matches dictionary.simplified).
    sql("update path_word_slots s set id = d.definitions->>'id' "
        "from dictionary d where d.simplified = s.word "
        "and coalesce(d.definitions->>'id','') <> '' "
        "and coalesce(s.id,'') = ''")
    left = sql("select count(*) n from dictionary "
               "where coalesce(definitions->>'id','') = ''")
    slots = sql("select count(*) n from path_word_slots "
                "where coalesce(id,'') = ''")
    print(f"FINISHED. dictionary missing id: {left[0]['n']}, "
          f"slots missing id: {slots[0]['n']}")

if __name__ == "__main__":
    main()
