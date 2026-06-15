# Spanish quiz options for existing videos: pivots every saved English quiz
# (correct+wrong) into natural Spanish with Gemini and writes quiz.es. Only
# rows with EN present and ES missing are touched, so it is resumable.
# Mirror of tools/quiz_ru_backfill.py.
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
                 "User-Agent": "Mozilla/5.0 (sinoma-quiz-es)"},
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

# Condensed from the 6-part Spanish grammar integration (Nissenberg, Complete Spanish Grammar).
RULES = """MANDATORY SPANISH GRAMMAR RULES (standard/neutral Spanish; ref. Nissenberg):
1. Full orthography: accents (á é í ó ú), ñ, and BOTH ¿…? and ¡…!. Lowercase nationalities/languages/months/days.
2. Nouns have gender (m -o / f -a, -ción, -dad; exceptions el día, la mano); articles & adjectives agree in gender AND number; descriptive adjectives usually follow the noun.
3. SER (identity, origin, traits, time: Es alto; Son las dos) vs ESTAR (location, temporary state, progressive: Está cansado; Está en casa). hay = there is/are.
4. Subject pronouns usually omitted (ending shows person). Stem changes e>ie, o>ue, e>i in present (quiero, puedo, pido).
5. Preterite = completed past event (comí, fue), Imperfect = ongoing/habitual/description/time&age (comía, era, eran las tres). Choose by aspect.
6. Future/conditional add endings to the infinitive (hablaré, hablaría); ir a + infinitive for near future. Compound = haber + invariable participle (he comido). Progressive = estar + -ando/-iendo.
7. SUBJUNCTIVE after wish/emotion/doubt/impersonal value with 'que' + different subject (Quiero que vengas; Dudo que sea), after para que/antes de que/cuando(future), and contrary-to-fact si (Si tuviera…, …ría).
8. Commands: tú afirmative = 3sg (¡Habla!); usted/ustedes & all negatives use subjunctive (hable, no hables). Pronouns attach to affirmative (dímelo), precede negative (no me lo digas).
9. Double negation: no … nada/nadie/nunca (No veo nada). Object pronoun order INDIRECT+DIRECT; le/les→se before lo/la (Se lo di). Personal 'a' before specific human objects (Veo a María). gustar inverts (Me gusta el café; Me gustan los libros).
10. por (cause/exchange/duration/through) vs para (purpose/recipient/destination/deadline). Comparatives más/menos…que, de before numbers; irregular mejor/peor. Produce natural standard Spanish; never a word-for-word calque.
"""

def gemini(batch):
    entries = "\n".join(
        f'- id:{r["id"]}\n  chinese: "{r["zh"]}"\n'
        f'  english_correct: "{r["en_c"]}"\n  english_wrong: "{r["en_w"]}"'
        for r in batch)
    prompt = (
        "You are a certified Spanish linguist and professional translator.\n"
        + RULES +
        "\nFor each quiz entry below, translate the APPROVED English options "
        "into natural Spanish. The English carries the vetted meaning — "
        "translate it faithfully and naturally (NOT word-for-word). Use the "
        "Chinese only to disambiguate nuance. english_wrong is already the "
        "chosen distractor: preserve ITS meaning exactly, do not invent a "
        "different one. Both sentences must be grammatically perfect.\n\n"
        "Return ONLY a JSON object: {\"<id>\": {\"c\": \"<Spanish of "
        "english_correct>\", \"w\": \"<Spanish of english_wrong>\"}, ...}\n\n"
        + entries)
    data = json.dumps({"prompt": prompt, "temperature": 0.3}).encode("utf-8")
    for attempt in range(8):
        req = urllib.request.Request(
            FN_URL, data=data,
            headers={"Content-Type": "application/json",
                     "x-backfill-guard": GUARD,
                     "User-Agent": "Mozilla/5.0 (sinoma-quiz-es)"},
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
            "and coalesce(quiz->'es'->>'correctAnswer','') = '' "
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
            es_json = json.dumps({"correctAnswer": c, "wrongAnswer": w},
                                 ensure_ascii=False)
            sql("update videos set quiz = jsonb_set(coalesce(quiz,'{}'::jsonb),"
                f"'{{es}}','{esc(es_json)}'::jsonb) where id = '{esc(vid)}'")
        done += len(ok)
        print(f"quiz es done {done} (+{len(ok)})", flush=True)
        time.sleep(1.2)
    left = sql("select count(*) n from videos "
               "where status in ('active','backup','pending') "
               "and coalesce(quiz->'en'->>'correctAnswer','') <> '' "
               "and coalesce(quiz->'es'->>'correctAnswer','') = ''")
    print(f"FINISHED. videos missing quiz.es: {left[0]['n']}")

if __name__ == "__main__":
    main()
