# Russian quiz options for existing videos: pivots every saved English quiz
# (correct+wrong) into natural Russian with Gemini and writes quiz.ru. Only
# rows with EN present and RU missing are touched, so it is resumable.
# Mirror of tools/quiz_th_backfill.py.
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
                 "User-Agent": "Mozilla/5.0 (sinoma-quiz-ru)"},
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

# Condensed from the 8-part Russian grammar integration (Wade, Comprehensive Russian Grammar).
RULES = """MANDATORY RUSSIAN GRAMMAR RULES (standard Russian in Cyrillic; ref. Wade):
1. Write ONLY in Cyrillic — never romanization. Lowercase nationalities/languages/months/days.
2. Heavily inflected: nouns/adjectives/pronouns/numerals/past-tense verbs change ENDINGS by role. A wrong ending is an error.
3. Gender (m consonant/-й, f -а/-я, n -о/-е; -ь mostly f) drives all agreement; adjectives agree in gender+number+case (новый дом, новая книга, новое окно).
4. Six cases by role/preposition: NOM subject; ACC direct object (animate m/pl ACC=GEN); GEN of/possession, after negation of existence (нет времени), quantities & 5+ numerals, after без/для/от/из/у/около/после; DAT indirect object & мне нравится/нужно; INSTR by/with means & after с 'with', был врачом; PREP only after о/в/на/при (в Москве, о тебе).
5. Past tense agrees in gender/number, NOT person (он читал, она читала, они читали). 'To be' is omitted in the present (Он студент).
6. Present conjugation 1st (-е-: читаю/читаешь/читает/читаем/читаете/читают) or 2nd (-и-: говорю/говоришь/говорит...).
7. ASPECT is obligatory: imperfective (process/repetition: читать) vs perfective (completed result: прочитать). Perfective has NO present — its present-form endings = future (прочитаю = I will read). Choose by meaning.
8. Negation: не before the word; genitive of negation for non-existence (нет воды); DOUBLE negation required (никто не знает, ничего не вижу).
9. Prepositions govern fixed cases (в/на + prep = location, + acc = direction; у/без/для/от/из + gen; к/по + dat; с/над/под/перед + instr; о/при + prep).
10. Numerals: 2-4 + genitive singular (два студента), 5+ + genitive plural (пять студентов). Default order SVO but relatively free. Produce natural standard Russian; never a word-for-word calque, never romanized.
"""

def gemini(batch):
    entries = "\n".join(
        f'- id:{r["id"]}\n  chinese: "{r["zh"]}"\n'
        f'  english_correct: "{r["en_c"]}"\n  english_wrong: "{r["en_w"]}"'
        for r in batch)
    prompt = (
        "You are a certified Russian linguist and professional translator.\n"
        + RULES +
        "\nFor each quiz entry below, translate the APPROVED English options "
        "into natural Russian (Cyrillic only). The English carries the vetted "
        "meaning — translate it faithfully and naturally (NOT word-for-word). "
        "Use the Chinese only to disambiguate nuance. english_wrong is already "
        "the chosen distractor: preserve ITS meaning exactly, do not invent a "
        "different one. Both sentences must be grammatically perfect.\n\n"
        "Return ONLY a JSON object: {\"<id>\": {\"c\": \"<Russian of "
        "english_correct>\", \"w\": \"<Russian of english_wrong>\"}, ...}\n\n"
        + entries)
    data = json.dumps({"prompt": prompt, "temperature": 0.3}).encode("utf-8")
    for attempt in range(8):
        req = urllib.request.Request(
            FN_URL, data=data,
            headers={"Content-Type": "application/json",
                     "x-backfill-guard": GUARD,
                     "User-Agent": "Mozilla/5.0 (sinoma-quiz-ru)"},
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
            "and coalesce(quiz->'ru'->>'correctAnswer','') = '' "
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
            ru_json = json.dumps({"correctAnswer": c, "wrongAnswer": w},
                                 ensure_ascii=False)
            sql("update videos set quiz = jsonb_set(coalesce(quiz,'{}'::jsonb),"
                f"'{{ru}}','{esc(ru_json)}'::jsonb) where id = '{esc(vid)}'")
        done += len(ok)
        print(f"quiz ru done {done} (+{len(ok)})", flush=True)
        time.sleep(1.2)
    left = sql("select count(*) n from videos "
               "where status in ('active','backup','pending') "
               "and coalesce(quiz->'en'->>'correctAnswer','') <> '' "
               "and coalesce(quiz->'ru'->>'correctAnswer','') = ''")
    print(f"FINISHED. videos missing quiz.ru: {left[0]['n']}")

if __name__ == "__main__":
    main()
