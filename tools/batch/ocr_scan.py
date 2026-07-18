# -*- coding: utf-8 -*-
"""Scan active clips for burned-in-subtitle homophone fixes.

For every active clip: download its [start,end] segment, OCR the bottom band on
several frames, keep only characters the OCR reads CONSISTENTLY and CONFIDENTLY
(multi-frame + confidence guard), then run the homophone engine (pinyin match +
jieba word veto). Writes the proposed (id, before, after, subs) to a JSON file.

Dry-run by default — it changes nothing. Apply is a separate, reviewed step:
changing whisper_text re-derives words/pinyin/slot/criterion/quiz downstream.

  python tools/batch/ocr_scan.py [limit_per_video]
"""
import subprocess, sys, pathlib, os, json, collections
sys.stdout.reconfigure(encoding="utf-8")
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "python" / "pipeline"))
from clip_extractor import _ffmpeg_exe
from ocr_subtitle import homophone_fix
import requests, cv2
from rapidocr_onnxruntime import RapidOCR
from pypinyin import lazy_pinyin

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 0     # per-video cap, 0 = all
MIN_CONF = 0.80        # a frame's OCR line must beat this to vote
MIN_VOTES = 2          # the winning text must appear in >= this many frames

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


WORK = pathlib.Path(r"D:\tmp\ocr_scan"); WORK.mkdir(parents=True, exist_ok=True)
COOK = HERE.parents[1] / "python" / "yt_cookies.txt"
FF = _ffmpeg_exe()
ocr = RapidOCR()


def han(s):
    return "".join(c for c in (s or "") if "一" <= c <= "鿿")


def read_clip(vid, a, b):
    """Multi-frame + confidence: return the caption text that wins a majority of
    frames above the confidence floor, else '' (no trustworthy subtitle)."""
    mp4 = WORK / f"{vid}_{a:.0f}.mp4"
    if not mp4.exists():
        args = ["--no-check-certificates", "--no-playlist", "--quiet", "--no-warnings",
                "--force-ipv4", "--js-runtimes", "node", "--ffmpeg-location", FF,
                "--extractor-args",
                "youtube:player_client=tv,android,mweb,ios,web_safari;fetch_pot=always",
                "-f", "bv[height<=480]/bv*[height<=720]/b",
                "--download-sections", f"*{a}-{b}", "--force-keyframes-at-cuts",
                "-o", str(mp4), f"https://www.youtube.com/watch?v={vid}"]
        if COOK.is_file():
            args = ["--cookies", str(COOK)] + args
        r = subprocess.run([sys.executable, "-m", "yt_dlp"] + args,
                           capture_output=True, text=True, timeout=300)
        if r.returncode != 0 or not mp4.exists():
            return None
    votes = collections.Counter()
    dur = max(b - a, 0.1)
    for t in (0.2, 0.4, 0.6, 0.8):
        png = WORK / f"{vid}_{a:.0f}_{t}.png"
        subprocess.run([FF, "-y", "-ss", str(dur * t), "-i", str(mp4),
                        "-vframes", "1", str(png)], capture_output=True, timeout=60)
        if not png.exists():
            continue
        img = cv2.imread(str(png))
        if img is None:
            continue
        h = img.shape[0]
        res, _ = ocr(img[int(h * 0.70):h, :])
        line = han("".join(x for _, x, c in (res or []) if float(c) >= MIN_CONF))
        if len(line) >= 2:
            votes[line] += 1
    if not votes:
        return None
    text, n = votes.most_common(1)[0]
    return text if n >= MIN_VOTES else None


vids = sql("""select youtube_id, count(*) as n from videos
             where is_active group by 1 order by 2 desc;""")
print(f"{len(vids)} video, aktif klipler taranacak (LIMIT/video={LIMIT or 'hepsi'})\n",
      flush=True)

proposals = []
seen_sub = collections.Counter()
for vi, v in enumerate(vids, 1):
    vid = v["youtube_id"]
    q = f"""select id, start_time, end_time, transcription, hsk_level
            from videos where youtube_id='{vid}' and is_active
            order by start_time {f'limit {LIMIT}' if LIMIT else ''};"""
    clips = sql(q)
    fixes = 0
    for c in clips:
        o = read_clip(vid, float(c["start_time"]), float(c["end_time"]))
        if not o:
            continue
        new, subs = homophone_fix(c["transcription"], o)
        if subs:
            fixes += 1
            for a, b in subs:
                seen_sub[f"{a}->{b}"] += 1
            proposals.append({"id": c["id"], "youtube_id": vid,
                              "hsk_level": c["hsk_level"],
                              "before": c["transcription"], "after": new,
                              "ocr": o, "subs": subs})
    print(f"[{vi}/{len(vids)}] {vid} ({v['n']} aktif): {fixes} duzeltme", flush=True)

out = HERE.parents[1] / "tools" / "batch" / "ocr_proposals.json"
json.dump(proposals, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"\n=== TARAMA BITTI ===")
print(f"duzeltilecek aktif klip: {len(proposals)}")
print(f"en sik degisimler: {seen_sub.most_common(12)}")
print(f"kayit: {out}")
