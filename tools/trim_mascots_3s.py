# Trim every uploaded unit-mascot animation to the first N seconds (default 3)
# and re-upload it. The AI loops run ~6-7s at 1.5x; the 3rd-node mascot only
# needs a short idle cycle, and the full clip was ~1.5MB each (37MB across 26
# units) — halving the frames roughly halves the file, so units reveal faster.
#
#   python tools/trim_mascots_3s.py [seconds]     # default 3
#
# Source mp4s aren't kept and this ffmpeg build can't decode animated WebP, so
# the trim runs through PIL (already a pipeline dep): keep whole frames until
# their cumulative play time reaches N seconds, re-encode as a looping WebP.
# Re-upload goes through the same guarded admin-asset path as the standard
# pipeline (dims are unchanged, so the stored display scale stays correct).
import io
import os
import sys
import time

import requests
from PIL import Image, ImageSequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from process_mascot_video import upload  # reuse the tested edge-fn upload

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = "pqyceostpukueydwuiut"
TRIM_MS = int(float(sys.argv[1]) * 1000) if len(sys.argv) > 1 else 3000
QUALITY = 82  # ~matches the pipeline's q78 source; frame-count cut is the win

tok = None
with open(r"d:\Masaustu\github\Kandao\.deploy.env", encoding="utf-8") as f:
    for line in f:
        if line.startswith("SUPABASE_ACCESS_TOKEN="):
            tok = line.split("=", 1)[1].strip()


def sql(q):
    r = requests.post(
        f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
        headers={"Authorization": f"Bearer {tok}"},
        json={"query": q}, timeout=60)
    d = r.json()
    if not isinstance(d, list):
        raise RuntimeError(str(d)[:300])
    return d


def trim(data: bytes) -> tuple[bytes, int, int, int]:
    im = Image.open(io.BytesIO(data))
    frames, durs, acc = [], [], 0
    for fr in ImageSequence.Iterator(im):
        d = fr.info.get("duration", 0) or 55
        frames.append(fr.convert("RGBA").copy())
        durs.append(d)
        acc += d
        if acc >= TRIM_MS:
            break
    total_frames = getattr(im, "n_frames", len(frames))
    out = io.BytesIO()
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=durs,
                   loop=0, format="WEBP", quality=QUALITY, method=4)
    return out.getvalue(), len(frames), total_frames, sum(durs)


rows = sql("select level, unit, url from path_assets "
           "where kind='mascot' order by level, unit;")
print(f"{len(rows)} mascot, hedef ilk {TRIM_MS/1000:g}sn\n")
saved = 0
for i, r in enumerate(rows, 1):
    lv, un, url = r["level"], r["unit"], r["url"]
    tag = f"L{lv}U{un}"
    try:
        src = requests.get(url, timeout=60).content
        kept, total, ms = 0, 0, 0
        new, kept, total, ms = trim(src)
        if kept >= total:  # already <= N seconds, leave it
            print(f"[{i}/{len(rows)}] {tag}: {total}f/{ms}ms zaten kisa — atlandi")
            continue
        tmp = os.path.join(os.path.dirname(__file__), f"_mascot_{tag}.webp")
        with open(tmp, "wb") as fo:
            fo.write(new)
        before, after = len(src) // 1024, len(new) // 1024
        upload(tmp, lv, un)          # re-upload + row upsert (same path/scale)
        os.remove(tmp)
        saved += before - after
        print(f"[{i}/{len(rows)}] {tag}: {total}f→{kept}f  {before}KB→{after}KB ✓")
        time.sleep(0.5)
    except Exception as e:
        print(f"[{i}/{len(rows)}] {tag}: HATA {type(e).__name__}: {e}")

print(f"\nToplam kazanc: ~{saved//1024}MB")
