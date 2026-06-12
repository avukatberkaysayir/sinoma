# Downloads public-domain portrait art for the 16 badge figures (Three
# Kingdoms heroes + mythology) from Wikimedia Commons into assets/badges/.
# Uses the Commons search API (namespace File), takes the first raster image
# and saves a 256px thumb. Re-run safe: existing files are skipped.
import json
import os
import sys
import time
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "badges")
os.makedirs(OUT, exist_ok=True)

FIGURES = {
    # id -> ordered search queries (most specific first)
    "xushu": ["Xu Shu Sanguozhi", "Xu Shu Three Kingdoms portrait"],
    "pangtong": ["Pang Tong Sanguozhi", "Pang Tong portrait"],
    "zhugeliang": ["Zhuge Liang Sancai Tuhui", "Zhuge Liang portrait"],
    "jiangziya": ["Jiang Ziya portrait", "Jiang Taigong"],
    "zhaoyun": ["Zhao Yun Sanguozhi", "Zhao Yun portrait"],
    "guanyu": ["Guan Yu Sancai Tuhui", "Guan Yu portrait"],
    "lvbu": ["Lü Bu Sanguozhi", "Lu Bu portrait"],
    "nezha": ["Nezha Fengshen", "Nezha mythology"],
    "liubei": ["Liu Bei Sancai Tuhui", "Liu Bei portrait"],
    "sunquan": ["Sun Quan Sancai Tuhui", "Sun Quan portrait"],
    "caocao": ["Cao Cao Sancai Tuhui", "Cao Cao portrait"],
    "pangu": ["Pangu Sancai Tuhui", "Pangu mythology"],
    "zhangfei": ["Zhang Fei Sanguozhi", "Zhang Fei portrait"],
    "zhouyu": ["Zhou Yu Sanguozhi", "Zhou Yu portrait"],
    "simayi": ["Sima Yi Sanguozhi", "Sima Yi portrait"],
    "nuwa": ["Nuwa Sancai Tuhui", "Nüwa mythology"],
}

API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "SinomaBadges/1.0 (educational app; contact: admin)"}

def get_json(params):
    url = API + "?" + urllib.parse.urlencode(params)
    for attempt in range(6):
        req = urllib.request.Request(url, headers=UA)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(30)
                continue
            raise
    return {}

def find_thumb(query):
    data = get_json({
        "action": "query", "format": "json",
        "generator": "search", "gsrsearch": query,
        "gsrnamespace": "6", "gsrlimit": "8",
        "prop": "imageinfo", "iiprop": "url|mime",
        "iiurlwidth": "256",
    })
    pages = (data.get("query") or {}).get("pages") or {}
    ranked = sorted(pages.values(), key=lambda p: p.get("index", 99))
    for p in ranked:
        info = (p.get("imageinfo") or [{}])[0]
        mime = info.get("mime", "")
        if mime in ("image/jpeg", "image/png"):
            return info.get("thumburl") or info.get("url")
    return None

def main():
    ok = miss = 0
    for fid, queries in FIGURES.items():
        dst = os.path.join(OUT, f"{fid}.jpg")
        if os.path.exists(dst):
            ok += 1
            continue
        url = None
        for q in queries:
            url = find_thumb(q)
            if url:
                break
            time.sleep(2)
        if not url:
            print(f"MISS {fid}")
            miss += 1
            continue
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        with open(dst, "wb") as f:
            f.write(data)
        print(f"{fid}: {url.split('/')[-1][:70]}")
        ok += 1
        time.sleep(2)
    print(f"done: {ok} ok, {miss} missing")

if __name__ == "__main__":
    main()
