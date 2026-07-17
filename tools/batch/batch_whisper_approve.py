# Batch: for every pending, non-backup clip with a Whisper transcription,
# apply the Whisper sentence (replacing the ASR one) exactly like the admin
# UI's "Uygula" flow, regenerate quiz options (EN first, then all other UI
# languages pivoted from the approved EN), and approve the clip.
# Clips whose re-derived slot is occupied (would-be backup) are LEFT PENDING
# and reported, mirroring the app's "Yedeğe Al" warning.
import json, re, sys, time, requests, pathlib

# One definition of "this is a decode loop", shared with the ASR pipeline.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "python" / "pipeline"))
from youtube_miner import is_repetition_loop

sys.stdout.reconfigure(encoding="utf-8")

PROJECT = "pqyceostpukueydwuiut"
ANON = "sb_publishable_L_qwvXbTI8URLvDHWUqApg_bgVlf9s1"
FN_BASE = f"https://{PROJECT}.supabase.co/functions/v1"
FN_H = {"Authorization": f"Bearer {ANON}", "apikey": ANON,
        "Content-Type": "application/json"}
LANGS = ["tr", "ko", "ja", "id", "vi", "th", "ru", "es", "pt", "fr", "ar"]
CJK = re.compile(r"^[一-鿿]+$")
# Optional argv: hsk_min hsk_max [limit] (default 1-4, no limit — Berkay's
# standing priority). limit caps how many clips this run processes (e.g. a
# 100-clip HSK-5 trial batch); omitted → every eligible clip.
HSK_MIN = int(sys.argv[1]) if len(sys.argv) > 1 else 1
HSK_MAX = int(sys.argv[2]) if len(sys.argv) > 2 else 4
LIMIT = int(sys.argv[3]) if len(sys.argv) > 3 else None

# ONLY_IDS=<json file of clip ids> restricts the run to exactly those clips, for
# repairing a known set without sweeping the whole pending pool at that level
# (HSK 5-6 must stay raw in Onay Bekleyen unless explicitly batched).
import os
_only = os.environ.get("ONLY_IDS")
ONLY_IDS = json.load(open(_only, encoding="utf-8")) if _only else None

tok = None
with open(r"d:\Masaustu\github\Kandao\.deploy.env", encoding="utf-8") as f:
    for line in f:
        if line.startswith("SUPABASE_ACCESS_TOKEN="):
            tok = line.split("=", 1)[1].strip()
assert tok, "SUPABASE_ACCESS_TOKEN missing"


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
        except (requests.RequestException, ValueError) as e:
            if attempt == tries - 1:
                raise
            time.sleep(2 * (attempt + 1))


def lit(s):
    assert "$qz9$" not in s
    return f"$qz9${s}$qz9$"


def arr(words):
    parts = [r"E'\n'" if w == "\n" else lit(w) for w in words]
    return "ARRAY[" + ",".join(parts) + "]::text[]"


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


def dict_words(cands):
    cands = sorted({c for c in cands if CJK.match(c)})
    found = set()
    for i in range(0, len(cands), 150):
        chunk = cands[i:i + 150]
        rows = sql("select simplified from dictionary where simplified in ("
                   + ",".join(lit(c) for c in chunk) + ");")
        found.update(r["simplified"] for r in rows)
    return found


def pinyin_map(words):
    ws = sorted({w for w in words if CJK.match(w)})
    if not ws:
        return {}
    rows = sql("select simplified, pinyin from dictionary where simplified in ("
               + ",".join(lit(w) for w in ws) + ");")
    return {r["simplified"]: (r["pinyin"] or "") for r in rows}


def proper_nouns(text):
    d = fn("translate", {"text": text, "mode": "proper-nouns"}, tries=2)
    nouns = [str(n) for n in (d or {}).get("nouns", [])]
    return sorted(nouns, key=len, reverse=True)


def segment(line):
    # Greedy longest-match against the dictionary (max len 4); proper nouns win.
    cands = {line[i:i + l] for i in range(len(line)) for l in (2, 3, 4)
             if i + l <= len(line)}
    valid = dict_words(cands)
    nouns = proper_nouns(line)
    out, i = [], 0
    while i < len(line):
        chosen = line[i]
        for n in nouns:
            if len(n) > len(chosen) and line.startswith(n, i):
                chosen = n
        if len(chosen) == 1:
            for l in (4, 3, 2):
                if i + l <= len(line) and line[i:i + l] in valid:
                    chosen = line[i:i + l]
                    break
        out.append(chosen)
        i += len(chosen)
    return out


def first_reading(p):
    return p.split(",")[0].strip()


def quiz_pair(d):
    if not isinstance(d, dict):
        return None
    c = (d.get("correctAnswer") or "").strip()
    w = (d.get("wrongAnswer") or "").strip()
    return {"correctAnswer": c, "wrongAnswer": w} if c and w else None


_scope = ("and id in (" + ",".join(lit(i) for i in ONLY_IDS) + ")") if ONLY_IDS else ""

# Ön geçiş — "temelde aynı" cümle eleme (noktalama + cümle-sonu edatı farkını
# yok say): video içinde tekrar eden replikler ve zaten AKTİF olan bir cümlenin
# pending kopyaları silinir. Pipeline'daki _drop_text_duplicates'in SQL eşi;
# eski worker koduyla bölünmüş koşular için güvenlik ağı.
deduped = sql(f"""
with norm as (
  select id, youtube_id, start_time,
         rtrim(regexp_replace(transcription, '[^一-鿿]', '', 'g'),
               '呢吧啊吗呀哦啦嘛哈嘞喽') as n
  from videos where status='pending' {_scope}
),
ranked as (
  select id, n, youtube_id,
         row_number() over (partition by youtube_id, n order by start_time) as rn
  from norm where length(n) >= 3
),
act as (
  select distinct rtrim(regexp_replace(transcription, '[^一-鿿]', '', 'g'),
                        '呢吧啊吗呀哦啦嘛哈嘞喽') as n
  from videos where status='active'
)
delete from videos v
using ranked r
where v.id = r.id and (r.rn > 1 or r.n in (select n from act))
returning v.id;
""")
if deduped:
    print(f"on-gecis: {len(deduped)} tekrar-cumleli pending klip silindi")

rows = sql(f"""
select id, whisper_text, coalesce(quiz->>'question','') as question
from videos
where status='pending' and backup_kind is null and backup_level is null
  and coalesce(whisper_text,'') <> ''
  and hsk_level between {HSK_MIN} and {HSK_MAX}
  {_scope}
order by hsk_level, created_at
{f'limit {LIMIT}' if LIMIT else ''};
""")
print(f"{len(rows)} klip islenecek\n")

report = {"approved": [], "slot_conflict": [], "quiz_failed": [], "error": []}

for idx, row in enumerate(rows, 1):
    vid = row["id"]
    wt = row["whisper_text"].strip()
    print(f"[{idx}/{len(rows)}] {vid} — {wt[:40]}")
    # A decode loop ("我喜欢读书。"×12) must never reach a slot: title, pinyin,
    # criterion and quiz would all be derived from text nobody says in the video.
    # 42 such clips went live before this gate existed (2026-07-17).
    if is_repetition_loop(wt):
        report["error"].append({"id": vid, "err": "whisper tekrar dongusu — atlandi"})
        print("    tekrar dongusu tespit edildi — beklemede birakildi")
        continue
    try:
        # Latin-ad kapısı: cümledeki Latin özel adlar Çince karşılığına çekilir
        # (Durian→榴莲); karşılığı yoksa Çince'ye uygun çevriyazım, o da olmazsa
        # olduğu gibi kalır (Berkay'ın kuralı, 2026-07-12).
        if re.search(r"[A-Za-z]{2,}", wt):
            sz = fn("translate", {"text": wt, "mode": "sinicize"}, tries=2)
            fixed = (sz or {}).get("text", "").strip()
            if fixed and fixed != wt:
                print(f"    latin-ad: {wt[:25]} -> {fixed[:25]}")
                wt = fixed
        lines = [l.strip() for l in wt.split("\n") if l.strip()]
        words = []
        for line in lines:
            ws = segment(line)
            if not ws:
                continue
            if words:
                words.append("\n")
            words.extend(ws)
        if not words:
            report["error"].append({"id": vid, "err": "segment empty"})
            continue
        spoken = [w for w in words if w != "\n"]
        pmap = pinyin_map(spoken)
        pinyin = " ".join(
            fr for fr in (first_reading(pmap.get(w, "")) for w in spoken) if fr)
        transcription = "\n".join(lines)

        _upd = sql(f"""
update videos set
  transcription = {lit(transcription)},
  pinyin = {lit(pinyin)},
  target_words = {arr(words)},
  level = null, unit = null, phase = null,
  slot_grammar = null, slot_word = null
where id = '{vid}'
returning level, unit, phase, backup_level, backup_unit, backup_phase,
          backup_kind, backup_grammar, backup_word, hsk_level;
""")
        if not _upd:
            # The row vanished between the SELECT and here — a concurrent split's
            # DB-wide dedup (_drop_text_duplicates) or an admin delete removed it.
            # Skip cleanly instead of crashing on [0] (IndexError).
            report["error"].append({"id": vid, "err": "klip kayboldu (eszamanli silme)"})
            print("    klip kayboldu (eszamanli dedup) — atlandi")
            continue
        upd = _upd[0]

        # EN quiz, then all other languages pivoted from that EN pair.
        tq = "".join(words)
        en = quiz_pair(fn("generate-quiz", {
            "transcription": tq, "pinyin": pinyin, "lang": "en"}))
        if not en:
            report["quiz_failed"].append({"id": vid, "err": "EN uretim"})
            continue
        time.sleep(1.5)
        batch = fn("generate-quiz", {
            "transcription": tq, "pinyin": pinyin, "lang": "en",
            "sourceEn": en["correctAnswer"], "sourceEnWrong": en["wrongAnswer"],
            "targetLangs": LANGS}) or {}
        extra = batch.get("extra") or {}
        pairs = {l: quiz_pair(extra.get(l)) for l in LANGS}
        for l in [l for l in LANGS if not pairs[l]]:
            time.sleep(1.5)
            pairs[l] = quiz_pair(fn("generate-quiz", {
                "transcription": tq, "pinyin": pinyin, "lang": l,
                "sourceEn": en["correctAnswer"],
                "sourceEnWrong": en["wrongAnswer"]}, tries=2))
        missing = [l for l in LANGS if not pairs[l]]
        if missing:
            report["quiz_failed"].append({"id": vid, "err": f"eksik: {missing}"})
            continue

        quiz = {"question": row["question"],
                "correctAnswer": pairs["tr"]["correctAnswer"],
                "wrongAnswer": pairs["tr"]["wrongAnswer"],
                "en": en}
        for l in LANGS:
            if l != "tr":
                quiz[l] = pairs[l]

        # Auto-define unknown words as "Diğer" dictionary entries (validity
        # gate + 12 languages, server-side). Rejected/failed words drop into
        # Sözlük > Önerilen so nothing is silently lost.
        unknown = [w for w in dict.fromkeys(spoken)
                   if CJK.match(w) and w not in pmap]
        for w in unknown:
            d = fn("define-word", {"word": w, "context": transcription},
                   tries=2) or {}
            if d.get("valid") is not True:
                sql(f"""
insert into posts (author_id, content, post_type, likes, metadata)
select coalesce(
         (select author_id from posts
          where metadata->>'is_word_suggestion'='true' limit 1),
         (select id from users limit 1)),
       {lit(w)}, 'text', '{{}}',
       jsonb_build_object('is_word_suggestion', true, 'word', {lit(w)},
                          'source', 'batch', 'reason',
                          {lit(str(d.get('reason') or d.get('error') or '?'))})
where not exists (select 1 from posts where content = {lit(w)}
                  and metadata->>'is_word_suggestion' = 'true');
""")
                print(f"    sozluk: {w} -> Onerilen ({d.get('reason') or d.get('error')})")
            elif d.get("saved"):
                print(f"    sozluk: {w} -> Diger eklendi")

        # Activate ONLY when the clip actually landed in a slot (level set). A
        # clip with no free slot is left pending — the trigger marks it backup
        # if it maps to a slot, else it's bare pending. Never active-placeless
        # (Berkay 2026-07-16: every active clip must sit in a slot).
        placed = upd["level"] is not None
        approve = ", status='active', is_active=true" if placed else ""
        sql(f"update videos set quiz = {lit(json.dumps(quiz, ensure_ascii=False))}::jsonb"
            f"{approve} where id = '{vid}';")
        if not placed:
            crit = upd.get("backup_grammar") or upd.get("backup_word") or "?"
            slot = (f"L{upd['backup_level']} U{upd['backup_unit']} B{upd['backup_phase']}"
                    if upd["backup_level"] is not None else "slotsuz")
            report["slot_conflict"].append({
                "id": vid, "sentence": transcription, "criterion": crit, "slot": slot})
            print(f"    yer yok ({crit}) -> beklemede (yedek: {slot})")
        else:
            report["approved"].append({
                "id": vid, "sentence": transcription,
                "slot": f"L{upd['level']} U{upd['unit']} B{upd['phase']}"})
            print("    onaylandi ✓")
        time.sleep(1.5)
    except Exception as e:
        report["error"].append({"id": vid, "err": f"{type(e).__name__}: {e}"})
        print(f"    HATA: {e}")

with open("batch_report.json", "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=1)
print(f"\nOnaylanan: {len(report['approved'])}  Slot dolu (beklemede): "
      f"{len(report['slot_conflict'])}  Quiz hatasi: {len(report['quiz_failed'])}  "
      f"Hata: {len(report['error'])}")

# Kalıcı son-adımlar: yerleşimsiz aktifleri boş slotlara oturt + boş-slot
# hedef raporunu tazele (her parçalama/yerleştirme turunda otomatik).
import os, subprocess
_here = os.path.dirname(os.path.abspath(__file__))
for step in ("place_actives.py", "empty_slot_report.py"):
    try:
        subprocess.run([sys.executable, "-u", os.path.join(_here, step)],
                       timeout=900)
    except Exception as e:
        print(f"son-adim {step} atlandi: {e}")
