# Boş-slot hedef raporu: her seviyede AKTİF klibi olmayan kelime ve gramer
# slotlarını docs/bos_slot_raporu.md'ye yazar — video seçerken hedef listesi.
# Batch sonunda otomatik çalışır; elle de çalıştırılabilir.
import os, sys, time, requests

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = "pqyceostpukueydwuiut"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "docs", "bos_slot_raporu.md")

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


def generate():
    words = sql("""
select s.level, s.unit, s.phase, s.word
from path_word_slots s
where not exists (select 1 from videos a where a.status='active'
                  and a.slot_word = s.word and a.level = s.level)
order by s.level, s.unit, s.phase;
""")
    grams = sql("""
select gl.level, gl.unit, gl.name, coalesce(gl.symbol,'') as symbol, gl.zh
from grammar_levels gl
where not exists (select 1 from videos a where a.status='active'
                  and a.slot_grammar = gl.name)
order by gl.level, gl.unit;
""")
    lines = ["# Boş Slot Hedef Raporu",
             "", "Video seçerken bu kelime/gramerleri içeren içerik boş slotları doldurur.",
             "Admin > Ekle > İçerik Filtresi'nde kırmızı OLMAYANLAR = bu liste.", ""]
    for lvl in range(1, 7):
        lw = [w for w in words if w["level"] == lvl]
        lg = [g for g in grams if g["level"] == lvl]
        lines.append(f"## L{lvl} — boş kelime slotu: {len(lw)}, boş gramer slotu: {len(lg)}")
        if lg:
            lines.append("**Gramer:** " + "、".join(
                (g["symbol"] or g["zh"] or g["name"]) for g in lg))
        if lw:
            by_unit = {}
            for w in lw:
                by_unit.setdefault(w["unit"], []).append(w["word"])
            for u in sorted(by_unit):
                lines.append(f"- Ü{u}: " + "、".join(by_unit[u]))
        lines.append("")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"rapor yazildi: {OUT} (kelime {len(words)}, gramer {len(grams)})")


if __name__ == "__main__":
    generate()
