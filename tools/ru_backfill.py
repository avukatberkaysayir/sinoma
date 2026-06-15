# Russian dictionary backfill: translates every dictionary entry's gloss into
# natural Russian (definitions.ru) with Gemini, then mirrors it onto
# path_word_slots.ru. Resumable: only rows with empty ru are fetched.
# Mirror of tools/th_backfill.py.
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
FN_URL = f"https://{PROJECT}.supabase.co/functions/v1/ko-batch"
GUARD = "sinoma-ko-backfill-2026"

def sql(query):
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={"Authorization": f"Bearer {PAT}",
                 "Content-Type": "application/json",
                 "User-Agent": "Mozilla/5.0 (sinoma-ru-backfill)"},
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
    "You are a professional Chinese-Russian lexicographer compiling a "
    "китайско-русский словарь (Chinese-Russian learner's dictionary) for Russian "
    "native speakers studying Mandarin.\n"
    "For each entry below, write the Russian dictionary gloss of the Chinese "
    "word. Rules:\n"
    "- Natural, idiomatic standard Russian in Cyrillic exactly as a published "
    "Russian dictionary would print it. NEVER use romanization/transliteration. "
    "Never translate word-by-word from English.\n"
    "- Citation form: nouns in nominative singular (with correct gender), verbs "
    "as the infinitive (give the aspect partner where useful: писать/написать), "
    "adjectives in masculine nominative singular.\n"
    "- 1-3 senses, comma-separated, concise. No sentences, no explanations, "
    "no pinyin.\n"
    "- Particles/measure words/grammar words: give the standard Russian "
    "linguistic description (e.g. 的 -> 'притяжательная/определительная частица').\n"
    "- Match the part of speech given.\n"
    "Return ONLY a JSON object mapping each id to its Russian gloss string.\n\n"
    "Entries:\n"
)

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
                     "User-Agent": "Mozilla/5.0 (sinoma-ru-backfill)"},
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
                model_i += 1
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
            "where coalesce(definitions->>'ru','') = '' "
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
            "jsonb_set(coalesce(d.definitions,'{}'::jsonb),'{ru}',"
            "to_jsonb(v.ru)) "
            f"from (values {values}) as v(id, ru) where d.id = v.id")
        total_done += len(ok)
        print(f"done {total_done} (+{len(ok)})", flush=True)
        time.sleep(4)
    sql("update path_word_slots s set ru = d.definitions->>'ru' "
        "from dictionary d where d.simplified = s.word "
        "and coalesce(d.definitions->>'ru','') <> '' "
        "and coalesce(s.ru,'') = ''")
    left = sql("select count(*) n from dictionary "
               "where coalesce(definitions->>'ru','') = ''")
    slots = sql("select count(*) n from path_word_slots "
                "where coalesce(ru,'') = ''")
    print(f"FINISHED. dictionary missing ru: {left[0]['n']}, "
          f"slots missing ru: {slots[0]['n']}")

if __name__ == "__main__":
    main()
