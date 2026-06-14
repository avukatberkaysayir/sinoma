# Indonesian quiz options for existing videos: pivots every saved English quiz
# (correct+wrong) into natural Indonesian with Gemini and writes quiz.id. Only
# rows with EN present and ID missing are touched, so it is resumable.
# Mirror of tools/quiz_ja_backfill.py.
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
FN_URL = f"https://{PROJECT}.supabase.co/functions/v1/ko-batch"
GUARD = "sinoma-ko-backfill-2026"

def sql(query):
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={"Authorization": f"Bearer {PAT}",
                 "Content-Type": "application/json",
                 "User-Agent": "Mozilla/5.0 (sinoma-quiz-id)"},
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

# Condensed from the 5-part Indonesian grammar integration (Djenar).
RULES = """MANDATORY INDONESIAN GRAMMAR RULES (authority: EYD/KBBI; ref. Djenar):
1. SVO word order; verbs do NOT conjugate — tense shown by adverbs (sudah, sedang, akan, belum, masih).
2. Noun phrase is head-initial: noun first, then possessor/adjective/demonstrative/yang-clause (rumah besar, buku saya, orang yang datang).
3. 'To be': adalah/ialah only between two nouns (often omitted); NEVER before an adjective or verb (Dia pintar, not Dia adalah pintar).
4. Negation: tidak (verbs/adjectives), bukan (nouns/pronouns), belum (not yet), jangan (negative command). Choose correctly by word class.
5. Verb affixation must be correct: ber- (intransitive/stative), meN- (active transitive, with nasalisation mem-/men-/meng-/meny-/menge-), di- (passive), -kan (causative/benefactive), -i (locative/iterative), ter- (accidental/superlative).
6. Object-focus: 3rd-person agent → di-verb (+ oleh); 1st/2nd-person agent → Object + pronoun + bare root, never di- with saya/kamu.
7. Counters with numbers (orang/ekor/buah); no articles, no gender; plural by context or reduplication but NOT after a numeral.
8. yang = relative 'who/which/that'; -nya = his/her/the/nominaliser.
9. Comparison: lebih … daripada, paling/ter- (most), se-/sama … dengan (as … as).
10. Produce natural standard Indonesian (bahasa baku); never a word-for-word calque (no terjemahan harfiah).
"""

def gemini(batch):
    entries = "\n".join(
        f'- id:{r["id"]}\n  chinese: "{r["zh"]}"\n'
        f'  english_correct: "{r["en_c"]}"\n  english_wrong: "{r["en_w"]}"'
        for r in batch)
    prompt = (
        "You are a certified Indonesian linguist and professional translator.\n"
        + RULES +
        "\nFor each quiz entry below, translate the APPROVED English options "
        "into natural Indonesian. The English carries the vetted meaning — "
        "translate it faithfully and naturally (NOT word-for-word). Use the "
        "Chinese only to disambiguate nuance. english_wrong is already the "
        "chosen distractor: preserve ITS meaning exactly, do not invent a "
        "different one. Both sentences must be grammatically perfect.\n\n"
        "Return ONLY a JSON object: {\"<id>\": {\"c\": \"<Indonesian of "
        "english_correct>\", \"w\": \"<Indonesian of english_wrong>\"}, ...}\n\n"
        + entries)
    data = json.dumps({"prompt": prompt, "temperature": 0.3}).encode("utf-8")
    for attempt in range(8):
        req = urllib.request.Request(
            FN_URL, data=data,
            headers={"Content-Type": "application/json",
                     "x-backfill-guard": GUARD,
                     "User-Agent": "Mozilla/5.0 (sinoma-quiz-id)"},
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
            "and coalesce(quiz->'id'->>'correctAnswer','') = '' "
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
            id_json = json.dumps({"correctAnswer": c, "wrongAnswer": w},
                                 ensure_ascii=False)
            sql("update videos set quiz = jsonb_set(coalesce(quiz,'{}'::jsonb),"
                f"'{{id}}','{esc(id_json)}'::jsonb) where id = '{esc(vid)}'")
        done += len(ok)
        print(f"quiz id done {done} (+{len(ok)})", flush=True)
        time.sleep(1.2)
    left = sql("select count(*) n from videos "
               "where status in ('active','backup','pending') "
               "and coalesce(quiz->'en'->>'correctAnswer','') <> '' "
               "and coalesce(quiz->'id'->>'correctAnswer','') = ''")
    print(f"FINISHED. videos missing quiz.id: {left[0]['n']}")

if __name__ == "__main__":
    main()
