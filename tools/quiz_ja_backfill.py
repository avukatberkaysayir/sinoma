# Japanese quiz options for existing videos: pivots every saved English quiz
# (correct+wrong) into natural Japanese with Gemini and writes quiz.ja. Only
# rows with EN present and JA missing are touched, so it is resumable.
# Mirror of tools/quiz_ko_backfill.py.
import json
import os
import time
import urllib.request
import urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "pqyceostpukueydwuiut"
MODEL = "gemini-2.5-flash-lite"

def load_pat():
    with open(os.path.join(ROOT, ".deploy.env"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("SUPABASE_ACCESS_TOKEN="):
                return line.split("=", 1)[1].strip()
    raise SystemExit("no PAT")

PAT = load_pat()
# Gemini keys only exist server-side; all traffic goes through the temporary
# ko-batch edge function (a generic prompt proxy).
FN_URL = f"https://{PROJECT}.supabase.co/functions/v1/ko-batch"
GUARD = "sinoma-ko-backfill-2026"

def sql(query):
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={"Authorization": f"Bearer {PAT}",
                 "Content-Type": "application/json",
                 "User-Agent": "Mozilla/5.0 (sinoma-quiz-ja)"},
        method="POST")
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")[:300]
            if e.code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(5 * (attempt + 1)); continue
            raise SystemExit(f"SQL fail {e.code}: {body}")
        except Exception:
            if attempt < 3:
                time.sleep(5); continue
            raise

# Condensed from the 5-part Japanese grammar integration (Tae Kim's guide).
RULES = """MANDATORY JAPANESE GRAMMAR RULES (authority: 文化庁; ref. Tae Kim's guide):
1. Strict SOV / head-final order; the predicate (verb or state-of-being) closes the clause. Modifiers and relative clauses precede their noun (no relative pronoun).
2. Correct particles: は (topic, 'wa'), が (subject/identifier), を (object), に (target/time/destination), で (place of action/means), へ (direction), と (and/with), の (possessive/nominalizer), も (also, replaces は/が/を). Pick は vs が by information structure.
3. Polite 丁寧語 (です・ます体) consistently; do not mix with plain だ/する endings mid-sentence.
4. Adjectives: i-adjectives take no だ, negate as 〜くない, past 〜かった; na-adjectives need な to modify a noun and conjugate like nouns. いい conjugates from よい (よくない/よかった).
5. Verb forms: te-form chains (tense set by final predicate); potential 〜られる/〜える (object takes が); causative 〜(さ)せる; passive 〜(ら)れる; conditionals と/なら/ば/たら used correctly.
6. Counters with numbers (〜個/〜人/〜回 …); no articles, no plural, no gender.
7. Keigo only when register demands: honorific 尊敬語 for others, humble 謙譲語 for oneself — never reversed.
8. Idiomatic Japanese — what a native would actually say; never a word-for-word calque (no 直訳/翻訳調).
"""

def gemini(batch):
    entries = "\n".join(
        f'- id:{r["id"]}\n  chinese: "{r["zh"]}"\n'
        f'  english_correct: "{r["en_c"]}"\n  english_wrong: "{r["en_w"]}"'
        for r in batch)
    prompt = (
        "You are a certified Japanese linguist and professional translator.\n"
        + RULES +
        "\nFor each quiz entry below, translate the APPROVED English options "
        "into natural Japanese. The English carries the vetted meaning — "
        "translate it faithfully and naturally (NOT word-for-word). Use the "
        "Chinese only to disambiguate nuance. english_wrong is already the "
        "chosen distractor: preserve ITS meaning exactly, do not invent a "
        "different one. Both sentences must be grammatically perfect.\n\n"
        "Return ONLY a JSON object: {\"<id>\": {\"c\": \"<Japanese of "
        "english_correct>\", \"w\": \"<Japanese of english_wrong>\"}, ...}\n\n"
        + entries)
    data = json.dumps({"prompt": prompt, "temperature": 0.3}).encode("utf-8")
    for attempt in range(8):
        req = urllib.request.Request(
            FN_URL, data=data,
            headers={"Content-Type": "application/json",
                     "x-backfill-guard": GUARD,
                     "User-Agent": "Mozilla/5.0 (sinoma-quiz-ja)"},
            method="POST")
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                out = json.loads(r.read().decode("utf-8"))
            return json.loads(out["text"])
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")[:200]
            print(f"  fn {e.code}: {body}", flush=True)
            time.sleep(10 if e.code in (429, 502) else 5)
        except Exception as ex:
            print(f"  fn err: {ex}", flush=True)
            time.sleep(5)
    return {}

def esc(s):
    return s.replace("'", "''")

def main():
    done = 0
    while True:
        rows = sql(
            "select id, coalesce(transcription,'') zh, "
            "quiz->'en'->>'correctAnswer' en_c, "
            "coalesce(quiz->'en'->>'wrongAnswer','') en_w "
            "from videos where status in ('active','backup','pending') "
            "and coalesce(quiz->'en'->>'correctAnswer','') <> '' "
            "and coalesce(quiz->'ja'->>'correctAnswer','') = '' "
            "order by id limit 10")
        if not rows:
            break
        result = gemini(rows)
        ok = {}
        for r in rows:
            v = result.get(str(r["id"]))
            if isinstance(v, dict) and isinstance(v.get("c"), str) and v["c"].strip():
                ok[r["id"]] = (v["c"].strip(), str(v.get("w") or "").strip())
        if not ok:
            print("empty batch, retry in 20s"); time.sleep(20); continue
        for vid, (c, w) in ok.items():
            ja_json = json.dumps({"correctAnswer": c, "wrongAnswer": w},
                                 ensure_ascii=False)
            sql("update videos set quiz = jsonb_set(coalesce(quiz,'{}'::jsonb),"
                f"'{{ja}}','{esc(ja_json)}'::jsonb) where id = '{esc(vid)}'")
        done += len(ok)
        print(f"quiz ja done {done} (+{len(ok)})", flush=True)
        time.sleep(1.2)
    left = sql("select count(*) n from videos "
               "where status in ('active','backup','pending') "
               "and coalesce(quiz->'en'->>'correctAnswer','') <> '' "
               "and coalesce(quiz->'ja'->>'correctAnswer','') = ''")
    print(f"FINISHED. videos missing quiz.ja: {left[0]['n']}")

if __name__ == "__main__":
    main()
