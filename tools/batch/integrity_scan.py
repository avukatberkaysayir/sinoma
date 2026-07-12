# Haftalık bütünlük taraması: çift kayıt / eksik quiz / yerleşimsiz aktif /
# takılı iş kontrolleri → docs/butunluk_raporu.md. Bekçi (worker_watchdog)
# 7 günde bir otomatik çalıştırır; elle de çalıştırılabilir.
import os, sys, time, requests
from datetime import datetime

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = "pqyceostpukueydwuiut"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "docs", "butunluk_raporu.md")

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


def scan():
    checks = {
        "Çift kayıt (aynı video+zaman)": """
select count(*) as n from (select youtube_id, start_time from videos
 group by youtube_id, start_time having count(*) > 1) x;""",
        "Aynı normalize cümle (aktifler)": """
select count(*) as n from (
 select rtrim(regexp_replace(transcription,'[^一-鿿]','','g'),
              '呢吧啊吗呀哦啦嘛哈嘞喽') as t
 from videos where status='active'
 group by 1 having count(*) > 1 and length(min(transcription)) > 4) x;""",
        "Eksik quiz'li aktif": """
select count(*) as n from videos where status='active' and not (quiz ? 'en');""",
        "Yerleşimsiz aktif": """
select count(*) as n from videos where status='active' and level is null;""",
        "İşlenmemiş HSK 1-4 (whisper'lı)": """
select count(*) as n from videos where status='pending'
 and hsk_level between 1 and 4 and backup_level is null and backup_kind is null
 and coalesce(whisper_text,'') <> '';""",
        "24 saatten eski takılı iş": """
select count(*) as n from pipeline_jobs where status='processing'
 and updated_at < now() - interval '24 hours';""",
    }
    lines = [f"# Bütünlük Raporu — {datetime.now():%Y-%m-%d %H:%M}", ""]
    problems = 0
    for name, q in checks.items():
        n = sql(q)[0]["n"]
        mark = "✅" if n == 0 else "⚠️"
        if n:
            problems += 1
        lines.append(f"- {mark} {name}: **{n}**")
        print(f"{mark} {name}: {n}")
    counts = sql("""
select (select count(*) from videos where status='active') as aktif,
       (select count(*) from videos where status='pending') as bekleyen,
       (select count(*) from dictionary where hsk_level=7) as diger;""")[0]
    lines += ["", f"Aktif: {counts['aktif']} · Bekleyen: {counts['bekleyen']} · "
                  f"Diğer kelime: {counts['diger']}",
              "", "⚠ görürsen Claude'a 'bütünlük raporuna bak' demen yeterli."]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"rapor: {OUT} — sorunlu kontrol: {problems}")
    return problems


if __name__ == "__main__":
    scan()
