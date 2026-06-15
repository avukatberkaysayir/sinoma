# Portuguese quiz options for existing videos: pivots every saved English quiz
# (correct+wrong) into natural Brazilian Portuguese with Gemini and writes
# quiz.pt. Only rows with EN present and PT missing are touched, so it is
# resumable. Mirror of tools/quiz_es_backfill.py.
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
                 "User-Agent": "Mozilla/5.0 (sinoma-quiz-pt)"},
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

# Condensed from the 6-part Portuguese grammar integration (Celegatti Althoff).
RULES = """MANDATORY PORTUGUESE GRAMMAR RULES (neutral Brazilian Portuguese; ref. Celegatti Althoff):
1. Full orthography: accents (á â ã, é ê, í, ó ô õ, ú), ç, nasal ã/õ and -ão. Lowercase nationalities/languages/months/days.
2. Nouns have gender (m -o / f -a, -ção, -dade, -gem; exceptions o problema, o dia); articles & adjectives agree in gender AND number; adjectives usually follow the noun.
3. Prepositions contract: de+o=do, em+a=na, a+o=ao, a+a=à, por+a=pela, de+este=deste. Always use contractions.
4. SER (identity/trait/time: É alto; São duas) vs ESTAR (location/temporary/progressive: Está cansado; Estou comendo) vs FICAR (become/located). Possession & existence = TER (Eu tenho; Tem um livro na mesa). gostar takes DE (gosto de café).
5. você takes 3rd-person verb; 'a gente' = we (singular verb). Object pronouns: proclisis is default in Brazil (Eu te amo; Ele me viu).
6. Pretérito perfeito = completed past (comi, fui, fez); Imperfeito = ongoing/habitual/description/time&age (comia, era, eram três horas). Choose by aspect.
7. Future = ir + infinitive (Vou comer). Compound = TER + participle (tenho comido = repeated, NOT one-off). Progressive = estar + -ndo (Estou comendo). Personal infinitive inflects (para eles falarem).
8. SUBJUNCTIVE after wish/emotion/doubt/impersonal value + que (Quero que você venha; Duvido que seja). FUTURE SUBJUNCTIVE after quando/se/assim que for future (Quando eu chegar; Se você quiser). Contrary-to-fact: Se eu tivesse…, …ria.
9. Commands: você affirmative & all negatives use subjunctive (Fale!, Não fale). Double negation: não … nada/ninguém/nunca (Não vejo nada).
10. Comparatives mais/menos (do) que; irregular melhor/pior/maior/menor. por (pelo/pela: cause/through/exchange) vs para (purpose/destination/recipient). Produce natural Brazilian Portuguese; never a word-for-word calque.
"""

def gemini(batch):
    entries = "\n".join(
        f'- id:{r["id"]}\n  chinese: "{r["zh"]}"\n'
        f'  english_correct: "{r["en_c"]}"\n  english_wrong: "{r["en_w"]}"'
        for r in batch)
    prompt = (
        "You are a certified Portuguese linguist and professional translator.\n"
        + RULES +
        "\nFor each quiz entry below, translate the APPROVED English options "
        "into natural Brazilian Portuguese. The English carries the vetted "
        "meaning — translate it faithfully and naturally (NOT word-for-word). "
        "Use the Chinese only to disambiguate nuance. english_wrong is already "
        "the chosen distractor: preserve ITS meaning exactly, do not invent a "
        "different one. Both sentences must be grammatically perfect.\n\n"
        "Return ONLY a JSON object: {\"<id>\": {\"c\": \"<Portuguese of "
        "english_correct>\", \"w\": \"<Portuguese of english_wrong>\"}, ...}\n\n"
        + entries)
    data = json.dumps({"prompt": prompt, "temperature": 0.3}).encode("utf-8")
    for attempt in range(8):
        req = urllib.request.Request(
            FN_URL, data=data,
            headers={"Content-Type": "application/json",
                     "x-backfill-guard": GUARD,
                     "User-Agent": "Mozilla/5.0 (sinoma-quiz-pt)"},
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
            "and coalesce(quiz->'pt'->>'correctAnswer','') = '' "
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
            pt_json = json.dumps({"correctAnswer": c, "wrongAnswer": w},
                                 ensure_ascii=False)
            sql("update videos set quiz = jsonb_set(coalesce(quiz,'{}'::jsonb),"
                f"'{{pt}}','{esc(pt_json)}'::jsonb) where id = '{esc(vid)}'")
        done += len(ok)
        print(f"quiz pt done {done} (+{len(ok)})", flush=True)
        time.sleep(1.2)
    left = sql("select count(*) n from videos "
               "where status in ('active','backup','pending') "
               "and coalesce(quiz->'en'->>'correctAnswer','') <> '' "
               "and coalesce(quiz->'pt'->>'correctAnswer','') = ''")
    print(f"FINISHED. videos missing quiz.pt: {left[0]['n']}")

if __name__ == "__main__":
    main()
