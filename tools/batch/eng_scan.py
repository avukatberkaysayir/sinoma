# -*- coding: utf-8 -*-
"""Delete clips whose burned-in subtitle is ENGLISH — decided PER CLIP.

A caption can be English in one part of a video and Chinese in another, so the
unit is the clip, not the video (Berkay, 2026-07-22). Each active/pending clip is
OCR'd over its own [start,end]; if the caption is English prose (is_english_line,
which rejects pinyin) the clip is hard-deleted. Chinese/absent captions are kept.

Shares the ocr_scan frame cache (D:\\tmp\\ocr_scan), so a clip already downloaded
for the homophone pass isn't fetched again. Checkpoints per clip so a restart
resumes. No video-level blocklist — a video is never deleted wholesale.

  python tools/batch/eng_scan.py            # all active+pending clips
  python tools/batch/eng_scan.py <id>       # only that video's clips (pipeline)
"""
import subprocess, sys, pathlib, os, json, collections
sys.stdout.reconfigure(encoding="utf-8")
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "python" / "pipeline"))
from clip_extractor import _ffmpeg_exe
from ocr_subtitle import is_english_line
import requests, cv2
from rapidocr_onnxruntime import RapidOCR

ONE = sys.argv[1] if len(sys.argv) > 1 else None
MIN_CONF = 0.80
env = pathlib.Path(HERE.parents[1] / ".deploy.env").read_text(encoding="utf-8")
tok = [l.split("=", 1)[1].strip().strip('"') for l in env.splitlines()
       if l.startswith("SUPABASE_ACCESS_TOKEN")][0]


def sql(q, tries=6):
    import time
    for n in range(tries):
        try:
            d = requests.post(
                "https://api.supabase.com/v1/projects/pqyceostpukueydwuiut/database/query",
                headers={"Authorization": f"Bearer {tok}"}, json={"query": q},
                timeout=90).json()
            if isinstance(d, list):
                return d
        except Exception:
            pass
        time.sleep(min(15 * (n + 1), 90))
    raise SystemExit("SQL failed")


def lit(s):
    return "'" + str(s).replace("'", "''") + "'"


CACHE = pathlib.Path(r"D:\tmp\ocr_scan")   # shared with ocr_scan
CACHE.mkdir(parents=True, exist_ok=True)
COOK = HERE.parents[1] / "python" / "yt_cookies.txt"
FF = _ffmpeg_exe()
ocr = RapidOCR()
DONE = HERE / "eng_done_clips.json"
done = set(json.load(open(DONE, encoding="utf-8"))) if DONE.exists() else set()


def caption_is_english(vid, a, b):
    """OCR the clip's lower band over a few frames; True if a MAJORITY of the
    frames that carry text read English (not pinyin)."""
    mp4 = CACHE / f"{vid}_{a:.0f}.mp4"
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
        # A single slow/hung download must not kill the whole multi-thousand-clip
        # run — swallow the timeout/error and skip this clip (treated as no
        # caption, so kept; a later pass can revisit it).
        try:
            r = subprocess.run([sys.executable, "-m", "yt_dlp"] + args,
                               capture_output=True, text=True, timeout=180)
        except Exception:
            return None
        if r.returncode != 0 or not mp4.exists():
            return None
    eng = txt = 0
    dur = max(b - a, 0.1)
    for t in (0.2, 0.4, 0.6, 0.8):
        png = CACHE / f"{vid}_{a:.0f}_{t}.png"
        if not png.exists():
            try:
                subprocess.run([FF, "-y", "-ss", str(dur * t), "-i", str(mp4),
                                "-vframes", "1", str(png)], capture_output=True, timeout=60)
            except Exception:
                pass
        if not png.exists():
            continue
        img = cv2.imread(str(png))
        if img is None:
            continue
        h = img.shape[0]
        res, _ = ocr(img[int(h * 0.55):h, :])
        line = " ".join(x for _, x, c in (res or []) if float(c) >= MIN_CONF)
        if line.strip():
            txt += 1
            if is_english_line(line):
                eng += 1
    if txt == 0:
        return False              # no caption read → not English
    return eng >= max(2, txt * 0.5)


# ENG_ACTIVE_ONLY=1 → active clips first (they're what the learner sees, and are
# already in the OCR cache so no download). Pending comes as a later pass.
# ENG_HSK_MAX=N → only HSK 1..N. In pipeline mode this limits the scan to the
# clips this run will integrate (HSK 1-4); HSK 5-6 stays raw in Onay Bekleyen and
# gets scanned when it is later integrated — essential on a 4-hour video where
# scanning every clip would be thousands of downloads.
where = "where status <> 'deleted'" + (f" and youtube_id = '{ONE}'" if ONE else "")
if os.environ.get("ENG_ACTIVE_ONLY"):
    where += " and is_active"
_hmax = os.environ.get("ENG_HSK_MAX")
if _hmax:
    where += f" and hsk_level between 1 and {int(_hmax)}"
clips = sql(f"""select id, youtube_id, start_time, end_time, is_active
             from videos {where} order by is_active desc, youtube_id, start_time;""")
clips = [c for c in clips if c["id"] not in done]
print(f"{len(clips)} klip taranacak (klip-bazı){' [pipeline]' if ONE else ''}\n", flush=True)

deleted = kept = 0
by_vid = collections.Counter()
for i, c in enumerate(clips, 1):
    vid = c["youtube_id"]
    eng = caption_is_english(vid, float(c["start_time"]), float(c["end_time"]))
    done.add(c["id"])
    if eng:
        sql(f"delete from pipeline_jobs where payload->>'row_id' = {lit(c['id'])};")
        sql(f"delete from videos where id = {lit(c['id'])};")
        deleted += 1
        by_vid[vid] += 1
    else:
        kept += 1
    if i % 25 == 0:
        json.dump(sorted(done), open(DONE, "w"))
        print(f"  [{i}/{len(clips)}] silinen {deleted}, tutulan {kept}", flush=True)

json.dump(sorted(done), open(DONE, "w"))
print(f"\n=== TARAMA BITTI ===")
print(f"İngilizce altyazılı klip silindi: {deleted}")
print(f"tutulan (Çince/altyazısız): {kept}")
print("video başına silinen:", dict(by_vid.most_common()))
