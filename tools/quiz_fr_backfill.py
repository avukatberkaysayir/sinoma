# French quiz options for existing videos: pivots every saved English quiz
# (correct+wrong) into natural French with Gemini and writes quiz.fr. Only
# rows with EN present and FR missing are touched, so it is resumable.
# Mirror of tools/quiz_pt_backfill.py.
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
                 "User-Agent": "Mozilla/5.0 (sinoma-quiz-fr)"},
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

# Condensed from the 5-part French grammar integration (Heminway, Complete French Grammar).
RULES = """MANDATORY FRENCH GRAMMAR RULES (standard French; ref. Heminway):
1. Full orthography: accents (é è ê, à â, î, ô, ù, ç) and elision (l'ami, j'ai, qu'il, n'a). Lowercase nationalities/languages/months/days. Put a space before ? ! : ;.
2. Nouns have gender; articles & adjectives agree in gender AND number. Contractions: à+le=au, à+les=aux, de+le=du, de+les=des; after negation partitive→de (pas de pain). Most adjectives follow the noun; beau/bon/grand/petit/jeune/vieux/joli/nouveau precede.
3. être (je suis…) and avoir (j'ai…); many states use avoir (avoir faim/froid/20 ans). il y a = there is/are; c'est + noun vs il/elle est + adjective.
4. Subject pronouns obligatory; on = informal we (3sg). Pronominal verbs: se lever (je me lève).
5. Negation wraps the verb: ne … pas/jamais/plus/rien/personne/que — keep BOTH parts.
6. Passé composé = completed past (avoir/être + participle); imparfait = ongoing/habitual/description (mangeais, était). Choose by aspect. être-verbs (aller/venir/partir… + pronominals) agree with subject (elle est allée); avoir agrees only with a preceding direct object.
7. Future: aller + infinitive (je vais manger) or futur simple (je parlerai). Conditional polite (je voudrais).
8. Object pronoun order before verb: me/te/se/nous/vous > le/la/les > lui/leur > y > en (Je le lui donne; J'en veux). Stressed pronouns after prepositions (avec moi).
9. SUBJONCTIF after will/emotion/doubt/necessity + que (Je veux que tu viennes; Il faut que tu sois là). Imperative drops subject (Parle ! Finis !); affirmative pronouns follow with hyphen (Donne-le-moi).
10. Comparatives plus/moins/aussi … que; irregular meilleur (adj.)/mieux (adv.). Relatives qui/que/où/dont. en/au/aux + country. Produce natural standard French; never a word-for-word calque.
"""

def gemini(batch):
    entries = "\n".join(
        f'- id:{r["id"]}\n  chinese: "{r["zh"]}"\n'
        f'  english_correct: "{r["en_c"]}"\n  english_wrong: "{r["en_w"]}"'
        for r in batch)
    prompt = (
        "You are a certified French linguist and professional translator.\n"
        + RULES +
        "\nFor each quiz entry below, translate the APPROVED English options "
        "into natural French. The English carries the vetted meaning — "
        "translate it faithfully and naturally (NOT word-for-word). Use the "
        "Chinese only to disambiguate nuance. english_wrong is already the "
        "chosen distractor: preserve ITS meaning exactly, do not invent a "
        "different one. Both sentences must be grammatically perfect.\n\n"
        "Return ONLY a JSON object: {\"<id>\": {\"c\": \"<French of "
        "english_correct>\", \"w\": \"<French of english_wrong>\"}, ...}\n\n"
        + entries)
    data = json.dumps({"prompt": prompt, "temperature": 0.3}).encode("utf-8")
    for attempt in range(8):
        req = urllib.request.Request(
            FN_URL, data=data,
            headers={"Content-Type": "application/json",
                     "x-backfill-guard": GUARD,
                     "User-Agent": "Mozilla/5.0 (sinoma-quiz-fr)"},
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
            "and coalesce(quiz->'fr'->>'correctAnswer','') = '' "
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
            fr_json = json.dumps({"correctAnswer": c, "wrongAnswer": w},
                                 ensure_ascii=False)
            sql("update videos set quiz = jsonb_set(coalesce(quiz,'{}'::jsonb),"
                f"'{{fr}}','{esc(fr_json)}'::jsonb) where id = '{esc(vid)}'")
        done += len(ok)
        print(f"quiz fr done {done} (+{len(ok)})", flush=True)
        time.sleep(1.2)
    left = sql("select count(*) n from videos "
               "where status in ('active','backup','pending') "
               "and coalesce(quiz->'en'->>'correctAnswer','') <> '' "
               "and coalesce(quiz->'fr'->>'correctAnswer','') = ''")
    print(f"FINISHED. videos missing quiz.fr: {left[0]['n']}")

if __name__ == "__main__":
    main()
