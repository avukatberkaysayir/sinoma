# STANDARD pipeline for every Orni unit-mascot animation upload:
# AI-generated chroma-key video (green/magenta bg, any size, with audio) ->
# transparent looping animated WebP, auto-cropped to the character and scaled
# to the 256px icon standard, silent by construction — then (optionally)
# uploaded straight into the path-assets bucket as the unit's 'mascot' slot.
#
#   python tools/process_mascot_video.py <video.mp4> [--upload L U]
#
# Upload goes through the guarded admin-asset edge function (the local PAT has
# no storage/SQL rights): it stores path-assets/L<L>/U<U>/mascot_0.webp and
# upserts the path_assets row — the home path shows it immediately.
import json
import os
import re
import subprocess
import sys
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FF_BIN = r"D:\UserData\tools\ffmpeg-8.1.2-essentials_build\bin"
FFMPEG = os.path.join(FF_BIN, "ffmpeg.exe")
FFPROBE = os.path.join(FF_BIN, "ffprobe.exe")
PROJECT = "pqyceostpukueydwuiut"
MAX_SIDE = 256   # icon standard (icons8 landmark icons are 256px)
PAD = 12         # transparent breathing room around the character (src px, pre-scale)
SPEED = 1.5      # playback speed-up — the AI loops animate too languidly at 1x


def probe(src):
    out = subprocess.run(
        [FFPROBE, "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height", "-of", "json", src],
        capture_output=True, text=True, check=True)
    s = json.loads(out.stdout)["streams"][0]
    return s["width"], s["height"]


def corner_color(src, w, h):
    # Median of the 4 corners of the first frame = the chroma background.
    raw = subprocess.run(
        [FFMPEG, "-v", "error", "-i", src, "-frames:v", "1",
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True, check=True).stdout
    px = []
    for (x, y) in [(8, 8), (w - 9, 8), (8, h - 9), (w - 9, h - 9)]:
        i = (y * w + x) * 3
        px.append((raw[i], raw[i + 1], raw[i + 2]))
    px.sort()
    r, g, b = px[len(px) // 2]
    return r, g, b


def key_filter(rgb):
    # RGB-space colorkey, tight tolerance, NO despill: Orni's turquoise body
    # shares a hue family with the green screen — chromakey (UV distance) eats
    # the body and despill shifts it blue. The bold black cartoon outlines
    # already mask any residual edge spill. The trailing drawbox blanks the
    # AI-generator sparkle watermark in the bottom-right corner (the prompts
    # keep the character clear of the frame edges, so nothing real is lost).
    r, g, b = rgb
    return (f"colorkey=0x{r:02X}{g:02X}{b:02X}:0.14:0.05,format=rgba,"
            "drawbox=x=iw*0.76:y=ih*0.84:w=iw*0.24:h=ih*0.16:"
            "color=black@0:t=fill:replace=1")


def union_bbox(src, keyf, w, h):
    # Pass A: bounding box of the visible character across ALL frames.
    out = subprocess.run(
        [FFMPEG, "-v", "info", "-i", src,
         "-vf", f"{keyf},alphaextract,bbox=min_val=32",
         "-f", "null", "-"],
        capture_output=True, text=True)
    x1s, y1s, x2s, y2s = [], [], [], []
    for m in re.finditer(
            r"x1:(\d+)\s+x2:(\d+)\s+y1:(\d+)\s+y2:(\d+)", out.stderr):
        x1s.append(int(m.group(1)))
        x2s.append(int(m.group(2)))
        y1s.append(int(m.group(3)))
        y2s.append(int(m.group(4)))
    if not x1s:
        return 0, 0, w, h
    x1 = max(0, min(x1s) - PAD)
    y1 = max(0, min(y1s) - PAD)
    x2 = min(w - 1, max(x2s) + PAD)
    y2 = min(h - 1, max(y2s) + PAD)
    # Even dimensions keep every encoder happy.
    cw, ch = (x2 - x1 + 1) & ~1, (y2 - y1 + 1) & ~1
    return x1, y1, cw, ch


def process(src, dst):
    w, h = probe(src)
    rgb = corner_color(src, w, h)
    keyf = key_filter(rgb)
    print(f"{w}x{h}, bg RGB{rgb}, filter: {keyf}")
    x, y, cw, ch = union_bbox(src, keyf, w, h)
    print(f"character bbox: {cw}x{ch}+{x}+{y}")
    scale = (f"scale={MAX_SIDE}:-2" if cw >= ch else f"scale=-2:{MAX_SIDE}")
    # mpdecimate drops near-duplicate frames, setpts speeds playback up SPEED×
    # and the fps cap brings the sped-up stream back to the source's 24fps —
    # perceived smoothness is unchanged while a third of the frames (and
    # bytes) disappear; max compression_level squeezes the rest harder. That
    # keeps the mascot small enough to precache with the unit's icons.
    vf = (f"{keyf},crop={cw}:{ch}:{x}:{y},{scale},"
          f"mpdecimate,setpts=PTS/{SPEED},fps=24")
    subprocess.run(
        [FFMPEG, "-y", "-v", "error", "-i", src, "-vf", vf, "-an",
         "-c:v", "libwebp_anim", "-loop", "0", "-q:v", "85",
         "-compression_level", "6", "-fps_mode", "passthrough",
         dst],
        check=True)
    kb = os.path.getsize(dst) // 1024
    print(f"wrote {dst} ({kb} KB)")
    if kb > 7500:
        print("WARN: near the 8MB bucket limit — consider lowering -q:v")


GUARD = "sinoma-admin-asset-2026"


def upload(dst, level, unit):
    data = open(dst, "rb").read()
    req = urllib.request.Request(
        f"https://{PROJECT}.supabase.co/functions/v1/admin-asset"
        f"?level={level}&unit={unit}&kind=mascot&slot=0&ext=webp",
        data=data, method="POST",
        headers={"Content-Type": "image/webp", "x-backfill-guard": GUARD})
    with urllib.request.urlopen(req, timeout=300) as r:
        out = json.loads(r.read().decode())
    print(f"uploaded + row upserted: {out['url']}")


def main():
    src = sys.argv[1]
    dst = os.path.splitext(src)[0] + ".webp"
    process(src, dst)
    if "--upload" in sys.argv:
        i = sys.argv.index("--upload")
        upload(dst, int(sys.argv[i + 1]), int(sys.argv[i + 2]))


if __name__ == "__main__":
    main()
