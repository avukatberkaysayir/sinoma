# -*- coding: utf-8 -*-
"""Apply the burned-in-subtitle homophone fixes found by ocr_scan.py.

Changing whisper_text is not a one-field edit: title, pinyin, slot, criterion,
words, quiz and Diğer entries are all derived from it. So this does the minimum
and hands the rest to the standard pipeline — it writes the corrected text back,
clears everything derived, marks the clip pending, then runs the approve batch
scoped to exactly these ids (ONLY_IDS), which re-derives all of it and re-places
the clip. A clip whose new slot is taken drops to backup, same rule as always.

  python tools/batch/ocr_apply.py            # apply every proposal
  python tools/batch/ocr_apply.py --dry      # show what would change, do nothing
"""
import json, os, subprocess, sys, pathlib, requests
sys.stdout.reconfigure(encoding="utf-8")
HERE = pathlib.Path(__file__).resolve().parent
DRY = "--dry" in sys.argv

env = pathlib.Path(HERE.parents[1] / ".deploy.env").read_text(encoding="utf-8")
tok = [l.split("=", 1)[1].strip().strip('"') for l in env.splitlines()
       if l.startswith("SUPABASE_ACCESS_TOKEN")][0]


def sql(q, tries=4):
    import time
    for _ in range(tries):
        try:
            d = requests.post(
                "https://api.supabase.com/v1/projects/pqyceostpukueydwuiut/database/query",
                headers={"Authorization": f"Bearer {tok}"}, json={"query": q},
                timeout=90).json()
            if isinstance(d, list):
                return d
        except Exception:
            pass
        time.sleep(10)
    raise SystemExit("SQL failed")


def lit(s):
    return "'" + str(s).replace("'", "''") + "'"


props = json.load(open(HERE / "ocr_proposals.json", encoding="utf-8"))
# Guard: only touch a clip whose CURRENT text still matches what the scan saw.
# If a later run already re-derived it, "before" won't match and we skip — no
# double-apply, no clobbering newer text.
ids = [p["id"] for p in props]
cur = {r["id"]: r for r in sql(
    "select id, transcription, is_active from videos where id in (" +
    ",".join(lit(i) for i in ids) + ");")}

todo = []
for p in props:
    c = cur.get(p["id"])
    if not c:
        continue
    if (c["transcription"] or "") != p["before"]:
        continue  # already changed by something else → skip
    todo.append(p)

print(f"{len(props)} oneri, uygulanacak {len(todo)} "
      f"(atlanan {len(props) - len(todo)}: metin degismis/klip yok)\n")
for p in todo[:15]:
    print(f"  {p['subs']}\n   once : {p['before'][:46]}\n   sonra: {p['after'][:46]}")

if DRY:
    print("\n[--dry] hicbir sey degistirilmedi")
    raise SystemExit

if not todo:
    print("uygulanacak bir sey yok")
    raise SystemExit

# 1) Write corrected text, clear everything derived, mark pending. Sequential so
# each row is independent (the batch re-derives from whisper_text).
for p in todo:
    sql(f"""update videos set
      whisper_text = {lit(p['after'])},
      transcription = {lit(p['after'])},
      is_active = false, status = 'pending',
      level = null, unit = null, phase = null,
      slot_word = null, slot_grammar = null,
      pinyin = null, target_words = null, quiz = null,
      backup_kind = null, backup_level = null, backup_unit = null,
      backup_phase = null, backup_word = null, backup_grammar = null
    where id = {lit(p['id'])};""")
print(f"\n{len(todo)} klip guncellendi (whisper duzeltildi, turetilenler temizlendi)")

# 2) Hand the ids to the standard approve batch (1-6, but ONLY these ids, so the
# raw HSK 5-6 pending pool is never swept).
only = HERE / "ocr_apply_ids.json"
json.dump([p["id"] for p in todo], open(only, "w"))
print("batch_whisper_approve calistiriliyor (ONLY_IDS, HSK 1-6)…\n", flush=True)
os.environ["ONLY_IDS"] = str(only)
r = subprocess.run([sys.executable, "-u", "batch_whisper_approve.py", "1", "6"],
                   cwd=str(HERE))
sys.exit(r.returncode)
