# Repair pass: regenerate the 12-language quiz for clips whose Whisper apply
# succeeded but whose quiz generation failed mid-batch. Status is left as-is.
import json, sys, time, requests

sys.stdout.reconfigure(encoding="utf-8")

PROJECT = "pqyceostpukueydwuiut"
ANON = "sb_publishable_L_qwvXbTI8URLvDHWUqApg_bgVlf9s1"
FN_BASE = f"https://{PROJECT}.supabase.co/functions/v1"
FN_H = {"Authorization": f"Bearer {ANON}", "apikey": ANON,
        "Content-Type": "application/json"}
LANGS = ["tr", "ko", "ja", "id", "vi", "th", "ru", "es", "pt", "fr", "ar"]
SKIP_IDS = set(sys.argv[1:])  # ids still owned by the main batch

# ONLY_IDS=<json id file> restricts the run to those clips. Without it the
# selection below sweeps every pending clip missing a quiz — 2600 rows, most of
# them HSK 5-6 that must stay raw in Onay Bekleyen (Berkay's rule) — and burns
# Gemini quota on all of them.
import json as _json
import os as _os
_only = _os.environ.get("ONLY_IDS")
ONLY_IDS = set(_json.load(open(_only, encoding="utf-8"))) if _only else None

tok = None
with open(r"d:\Masaustu\github\Kandao\.deploy.env", encoding="utf-8") as f:
    for line in f:
        if line.startswith("SUPABASE_ACCESS_TOKEN="):
            tok = line.split("=", 1)[1].strip()


def sql(query, tries=3):
    for attempt in range(tries):
        try:
            r = requests.post(
                f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
                headers={"Authorization": f"Bearer {tok}"},
                json={"query": query}, timeout=60)
            data = r.json()
            if isinstance(data, list):
                return data
            raise RuntimeError(f"sql error {r.status_code}: {str(data)[:300]}")
        except (requests.RequestException, ValueError):
            if attempt == tries - 1:
                raise
            time.sleep(2 * (attempt + 1))


def lit(s):
    assert "$qz9$" not in s
    return f"$qz9${s}$qz9$"


def fn(name, body, tries=3, timeout=120):
    for attempt in range(tries):
        try:
            r = requests.post(f"{FN_BASE}/{name}", headers=FN_H, json=body,
                              timeout=timeout)
            if r.status_code < 300:
                return r.json()
            print(f"    fn {name} -> {r.status_code}: {r.text[:200]}")
        except (requests.RequestException, ValueError) as e:
            print(f"    fn {name} attempt {attempt+1}: {type(e).__name__}")
        time.sleep(3 * (attempt + 1))
    return None


def quiz_pair(d):
    if not isinstance(d, dict):
        return None
    c = (d.get("correctAnswer") or "").strip()
    w = (d.get("wrongAnswer") or "").strip()
    return {"correctAnswer": c, "wrongAnswer": w} if c and w else None


rows = sql("""
select id, status, transcription, pinyin,
       array_to_string(target_words, '') as tq,
       coalesce(quiz->>'question','') as question
from videos
where coalesce(whisper_text,'') <> ''
  and not (quiz ? 'en')
  and status in ('backup','pending','active')
order by created_at;
""")
rows = [r for r in rows if r["id"] not in SKIP_IDS]
if ONLY_IDS is not None:
    rows = [r for r in rows if r["id"] in ONLY_IDS]
print(f"{len(rows)} klip onarilacak\n", flush=True)
ok = fail = 0
for i, row in enumerate(rows, 1):
    vid = row["id"]
    tq = row["tq"] or row["transcription"]
    print(f"[{i}/{len(rows)}] {vid} ({row['status']}) — {tq[:30]}")
    en = quiz_pair(fn("generate-quiz", {
        "transcription": tq, "pinyin": row["pinyin"] or "", "lang": "en"}))
    if not en:
        print("    EN uretilemedi")
        fail += 1
        continue
    time.sleep(1.5)
    batch = fn("generate-quiz", {
        "transcription": tq, "pinyin": row["pinyin"] or "", "lang": "en",
        "sourceEn": en["correctAnswer"], "sourceEnWrong": en["wrongAnswer"],
        "targetLangs": LANGS}) or {}
    extra = batch.get("extra") or {}
    pairs = {l: quiz_pair(extra.get(l)) for l in LANGS}
    for l in [l for l in LANGS if not pairs[l]]:
        time.sleep(1.5)
        pairs[l] = quiz_pair(fn("generate-quiz", {
            "transcription": tq, "pinyin": row["pinyin"] or "", "lang": l,
            "sourceEn": en["correctAnswer"],
            "sourceEnWrong": en["wrongAnswer"]}, tries=2))
    missing = [l for l in LANGS if not pairs[l]]
    if missing:
        print(f"    eksik kaldi: {missing}")
        fail += 1
        continue
    quiz = {"question": row["question"],
            "correctAnswer": pairs["tr"]["correctAnswer"],
            "wrongAnswer": pairs["tr"]["wrongAnswer"],
            "en": en}
    for l in LANGS:
        if l != "tr":
            quiz[l] = pairs[l]
    sql(f"update videos set quiz = {lit(json.dumps(quiz, ensure_ascii=False))}::jsonb "
        f"where id = '{vid}';")
    print("    quiz yazildi ✓")
    ok += 1
    time.sleep(1.5)
print(f"\nOnarilan: {ok}  Basarisiz: {fail}")

