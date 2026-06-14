# Vietnamese quiz options for existing videos: pivots every saved English quiz
# (correct+wrong) into natural Vietnamese with Gemini and writes quiz.vi. Only
# rows with EN present and VI missing are touched, so it is resumable.
# Mirror of tools/quiz_id_backfill.py.
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
                 "User-Agent": "Mozilla/5.0 (sinoma-quiz-vi)"},
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

# Condensed from the 5-part Vietnamese grammar integration (Emeneau + modern).
RULES = """MANDATORY VIETNAMESE GRAMMAR RULES (standard Vietnamese; ref. Emeneau):
1. Isolating language: words never inflect (no conjugation/plural/case/gender/articles); relations by word order + function words.
2. SVO word order; noun phrase is head-initial: (number) + classifier + NOUN + adjective + possessor + demonstrative (con mèo đen này).
3. Classifiers obligatory with numbers/demonstratives (ba con chó, cái này): cái/con/người/quyển/chiếc/tờ. Choose correctly.
4. Copula là links two NOUNS only (Tôi là sinh viên); NEVER before an adjective (Tôi mệt, not Tôi là mệt). Adjectives are stative verbs and follow the noun.
5. Tense/aspect by preverbal markers (đã, đang, sẽ, vừa/mới, sắp) and final 'rồi'/'chưa' — no conjugation.
6. Negation: không (verb/adj), chưa (not yet), đừng (don't), 'không phải (là)' (noun).
7. Questions keep the question word in situ (ai/gì/đâu/nào/bao giờ/sao/thế nào/bao nhiêu); yes/no: 'có … không?', '… phải không?', 'đã … chưa?'.
8. Comparison: 'A [adj] hơn B', '[adj] nhất', 'bằng/như'. Degree: rất before adj, lắm/quá after.
9. Voice: bị (adverse) / được (favourable, also postverbal ability). Pronouns are kinship/age based — pick by relationship.
10. ALWAYS use correct Vietnamese diacritics/tone marks. Produce natural standard Vietnamese; never a word-for-word calque (no dịch word-by-word).
"""

def gemini(batch):
    entries = "\n".join(
        f'- id:{r["id"]}\n  chinese: "{r["zh"]}"\n'
        f'  english_correct: "{r["en_c"]}"\n  english_wrong: "{r["en_w"]}"'
        for r in batch)
    prompt = (
        "You are a certified Vietnamese linguist and professional translator.\n"
        + RULES +
        "\nFor each quiz entry below, translate the APPROVED English options "
        "into natural Vietnamese. The English carries the vetted meaning — "
        "translate it faithfully and naturally (NOT word-for-word). Use the "
        "Chinese only to disambiguate nuance. english_wrong is already the "
        "chosen distractor: preserve ITS meaning exactly, do not invent a "
        "different one. Both sentences must be grammatically perfect.\n\n"
        "Return ONLY a JSON object: {\"<id>\": {\"c\": \"<Vietnamese of "
        "english_correct>\", \"w\": \"<Vietnamese of english_wrong>\"}, ...}\n\n"
        + entries)
    data = json.dumps({"prompt": prompt, "temperature": 0.3}).encode("utf-8")
    for attempt in range(8):
        req = urllib.request.Request(
            FN_URL, data=data,
            headers={"Content-Type": "application/json",
                     "x-backfill-guard": GUARD,
                     "User-Agent": "Mozilla/5.0 (sinoma-quiz-vi)"},
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
            "and coalesce(quiz->'vi'->>'correctAnswer','') = '' "
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
            vi_json = json.dumps({"correctAnswer": c, "wrongAnswer": w},
                                 ensure_ascii=False)
            sql("update videos set quiz = jsonb_set(coalesce(quiz,'{}'::jsonb),"
                f"'{{vi}}','{esc(vi_json)}'::jsonb) where id = '{esc(vid)}'")
        done += len(ok)
        print(f"quiz vi done {done} (+{len(ok)})", flush=True)
        time.sleep(1.2)
    left = sql("select count(*) n from videos "
               "where status in ('active','backup','pending') "
               "and coalesce(quiz->'en'->>'correctAnswer','') <> '' "
               "and coalesce(quiz->'vi'->>'correctAnswer','') = ''")
    print(f"FINISHED. videos missing quiz.vi: {left[0]['n']}")

if __name__ == "__main__":
    main()
