# -*- coding: utf-8 -*-
"""Find videos that carry ENGLISH burned-in subtitles (dry-run, deletes nothing).

An English subtitle is a video-wide trait, so this decides per video, not per
clip: sample frames (reusing the OCR cache where present, downloading a few where
not), OCR the lower band, and count frames whose caption is English prose (via
is_english_line, which rejects pinyin). A video over the threshold has its whole
clip set — active AND pending — reported for deletion.

Writes eng_videos.json: {youtube_id: {frames, english, ratio, examples, clips}}.
"""
import subprocess, sys, pathlib, os, json, collections
sys.stdout.reconfigure(encoding="utf-8")
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "python" / "pipeline"))
from clip_extractor import _ffmpeg_exe
from ocr_subtitle import is_english_line
import requests, cv2
from rapidocr_onnxruntime import RapidOCR

RATIO = 0.30          # >=30% of sampled frames English → English-subtitled video
# Pipeline mode: `eng_scan.py <youtube_id>` scans ONLY that video and, if it is
# English-subtitled, soft-deletes its whole clip set (active + pending). This is
# what runs after a new integration so an English-subtitled video is eliminated
# on the way in. No arg → scan everything and just report (the backfill mode).
ONE = sys.argv[1] if len(sys.argv) > 1 else None
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


CACHE = pathlib.Path(r"D:\tmp\ocr_scan")
WORK = pathlib.Path(r"D:\tmp\eng_scan"); WORK.mkdir(parents=True, exist_ok=True)
COOK = HERE.parents[1] / "python" / "yt_cookies.txt"
FF = _ffmpeg_exe()
ocr = RapidOCR()

# Every video with any clip (active or pending) + its clip counts. In pipeline
# mode, just the one video. 'deleted' clips are excluded so a re-run is a no-op.
where = f"where status <> 'deleted'" + (f" and youtube_id = '{ONE}'" if ONE else "")
vids = sql(f"""select youtube_id,
  count(*) as toplam,
  count(*) filter (where is_active) as aktif,
  count(*) filter (where not is_active) as bekleyen,
  min(start_time) as ilk, max(end_time) as son
  from videos {where} group by 1 order by 2 desc;""")
print(f"{len(vids)} video taranacak{' (pipeline modu)' if ONE else ''}\n", flush=True)


def soft_delete(vid):
    r = sql(f"""update videos set is_active=false, status='deleted',
      level=null, unit=null, phase=null, slot_word=null, slot_grammar=null,
      backup_kind=null, backup_level=null, backup_unit=null,
      backup_phase=null, backup_word=null, backup_grammar=null
      where youtube_id='{vid}' and status <> 'deleted' returning id;""")
    return len(r)

cached = collections.defaultdict(list)
for f in CACHE.glob("*.png"):
    cached[f.stem.split("_")[0]].append(f)


def eng_ratio(vid, span):
    """Return (frames_checked, english_frames, examples) for a video."""
    frames = list(cached.get(vid, []))[:24]
    if len(frames) < 6 and span and span > 30:
        # Not enough cached frames — grab a few short segments to sample.
        for t in (span * 0.3, span * 0.5, span * 0.7):
            mp4 = WORK / f"{vid}_{t:.0f}.mp4"
            if not mp4.exists():
                args = ["--no-check-certificates", "--no-playlist", "--quiet",
                        "--no-warnings", "--force-ipv4", "--js-runtimes", "node",
                        "--ffmpeg-location", FF, "--extractor-args",
                        "youtube:player_client=tv,android,mweb,ios,web_safari;fetch_pot=always",
                        "-f", "bv[height<=480]/bv*[height<=720]/b",
                        "--download-sections", f"*{t}-{t+1}", "--force-keyframes-at-cuts",
                        "-o", str(mp4), f"https://www.youtube.com/watch?v={vid}"]
                if COOK.is_file():
                    args = ["--cookies", str(COOK)] + args
                subprocess.run([sys.executable, "-m", "yt_dlp"] + args,
                               capture_output=True, text=True, timeout=200)
            if mp4.exists():
                png = WORK / f"{vid}_{t:.0f}.png"
                subprocess.run([FF, "-y", "-ss", "0.4", "-i", str(mp4),
                                "-vframes", "1", str(png)], capture_output=True, timeout=60)
                if png.exists():
                    frames.append(png)
    eng = 0
    ex = []
    for f in frames:
        img = cv2.imread(str(f))
        if img is None:
            continue
        h = img.shape[0]
        res, _ = ocr(img[int(h * 0.55):h, :])
        for _, txt, _ in res or []:
            if is_english_line(txt):
                eng += 1
                if len(ex) < 3:
                    ex.append(txt.strip()[:50])
                break
    return len(frames), eng, ex


out = {}
for i, v in enumerate(vids, 1):
    vid = v["youtube_id"]
    n, eng, ex = eng_ratio(vid, float(v["son"] or 0))
    ratio = eng / n if n else 0
    flag = ratio >= RATIO and n >= 4
    out[vid] = {"frames": n, "english": eng, "ratio": round(ratio, 2),
                "toplam": v["toplam"], "aktif": v["aktif"], "bekleyen": v["bekleyen"],
                "examples": ex, "flag": flag}
    tag = "  <== INGILIZCE ALTYAZI" if flag else ""
    print(f"[{i}/{len(vids)}] {vid}: {eng}/{n} kare Ing (%{ratio*100:.0f}), "
          f"{v['toplam']} klip{tag}", flush=True)
    if ex:
        print(f"      ornek: {ex[0]}", flush=True)
    # Pipeline mode acts immediately: an English-subtitled new video is deleted.
    if ONE and flag:
        d = soft_delete(vid)
        print(f"      -> Ingilizce altyazi: {d} klip soft-delete edildi", flush=True)

json.dump(out, open(HERE / "eng_videos.json", "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
flagged = {k: v for k, v in out.items() if v["flag"]}
tot = sum(v["toplam"] for v in flagged.values())
print(f"\n=== TARAMA BITTI ===")
print(f"Ingilizce altyazili video: {len(flagged)}")
print(f"silinecek klip (aktif+bekleyen): {tot}")
for k, v in flagged.items():
    print(f"   {k}: {v['toplam']} klip ({v['aktif']} aktif, {v['bekleyen']} bekleyen)")
