# Unplaced ACTIVE clips → empty path slots. The assignment trigger treats a
# PENDING clip's insert-time placement as occupying the slot, so actives kept
# failing to place while the path (which only shows actives) stayed empty.
# Greedy match here considers only ACTIVE occupants; a pending holding the
# chosen slot gets its reservation cleared (its own trigger re-derives it into
# another free slot or a backup mark on its next touch — nothing is deleted).
# Runs standalone and as the approve-batch post-pass.
import sys, time, requests

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = "pqyceostpukueydwuiut"

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
        except (requests.RequestException, ValueError):
            pass
        time.sleep(2 * (attempt + 1))
    raise RuntimeError("sql failed")


def lit(s):
    assert "$pz9$" not in s
    return f"$pz9${s}$pz9$"


def place_unplaced_actives():
    videos = sql("""
select v.id, v.hsk_level, v.target_words, v.quiz_categories
from videos v
where v.status='active' and v.level is null and v.hsk_level between 1 and 6
order by v.created_at;
""")
    if not videos:
        print("yerlesimsiz aktif yok")
        return 0

    # Grammar slots (unit derives from grammar_levels; phase is always 1) and
    # word slots free of ACTIVE occupants.
    free_g = {r["name"]: r for r in sql("""
select gl.name, gl.level, gl.unit from grammar_levels gl
where not exists (select 1 from videos a
                  where a.status='active' and a.slot_grammar = gl.name);
""")}
    free_w = {}
    for r in sql("""
select s.word, s.level, s.unit, s.phase from path_word_slots s
where not exists (select 1 from videos a
                  where a.status='active' and a.slot_word = s.word
                  and a.level = s.level);
"""):
        free_w.setdefault((r["level"], r["word"]), r)

    placed = 0
    for v in videos:
        lvl = v["hsk_level"]
        target = None
        # Mirror the trigger's preference: grammar slot first, then word slot,
        # both AT the clip's level.
        for c in (v["quiz_categories"] or []):
            g = free_g.get(c)
            if g and g["level"] == lvl:
                target = ("grammar", c, g["level"], g["unit"], 1)
                break
        if target is None:
            for w in (v["target_words"] or []):
                s = free_w.get((lvl, w))
                if s:
                    target = ("word", w, s["level"], s["unit"], s["phase"])
                    break
        if target is None:
            continue
        kind, crit, L, U, P = target
        crit_col = "slot_grammar" if kind == "grammar" else "slot_word"
        # Free the slot from any pending reservation, then take it.
        sql(f"""
update videos set level=null, unit=null, phase=null,
                  slot_grammar=null, slot_word=null
where status='pending' and {crit_col} = {lit(crit)} and level is not null;
""")
        sql(f"""
update videos set level={L}, unit={U}, phase={P},
                  slot_grammar={"null" if kind != "grammar" else lit(crit)},
                  slot_word={"null" if kind != "word" else lit(crit)},
                  backup_level=null, backup_unit=null, backup_phase=null,
                  backup_kind=null, backup_grammar=null, backup_word=null
where id = '{v["id"]}';
""")
        if kind == "grammar":
            free_g.pop(crit, None)
        else:
            free_w.pop((lvl, crit), None)
        placed += 1
        print(f"  yerlesti: L{L} U{U} B{P} [{crit}] <- {v['id'][:8]}")
    print(f"toplam yerlesen: {placed}/{len(videos)}")
    return placed


if __name__ == "__main__":
    place_unplaced_actives()
