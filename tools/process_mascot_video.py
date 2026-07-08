# STANDARD pipeline for every Orni unit-mascot animation upload:
# AI-generated chroma-key video (green/magenta bg, any size, with audio) ->
# transparent looping animated WebP, auto-cropped to the character, scaled to
# the 256px icon standard, played at 1.5x, silent by construction — then
# (optionally) uploaded into the path-assets bucket as the unit's mascot slot.
#
#   python tools/process_mascot_video.py <video.mp4> [--upload L U]
#
# Background removal is SPATIAL, not purely chromatic: a pixel goes
# transparent only when its colour is near the backdrop AND it belongs to a
# component connected to the frame border. Colour distance alone mottled
# Orni's watercolour body shading (greenish teal ≈ dull green backdrop,
# L1/4.mp4) — interior tones now survive untouched, matching the source video.
#
# Upload goes through the guarded admin-asset edge function (the local PAT has
# no storage/SQL rights): it stores path-assets/L<L>/U<U>/mascot_0.webp and
# upserts the path_assets row — the home path shows it immediately.
import json
import os
import subprocess
import sys
import urllib.request

import numpy as np
from scipy import ndimage

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FF_BIN = r"D:\UserData\tools\ffmpeg-8.1.2-essentials_build\bin"
FFMPEG = os.path.join(FF_BIN, "ffmpeg.exe")
FFPROBE = os.path.join(FF_BIN, "ffprobe.exe")
PROJECT = "pqyceostpukueydwuiut"
MAX_SIDE = 256   # icon standard (icons8 landmark icons are 256px)
PAD = 12         # transparent breathing room around the character (src px)
SPEED = 1.5      # playback speed-up — the AI loops animate too languidly at 1x
DIAG = 441.673   # sqrt(3) * 255, full-scale RGB distance
EIGHT = np.ones((3, 3), dtype=bool)  # 8-connectivity for the bg component


def probe(src):
    out = subprocess.run(
        [FFPROBE, "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height,r_frame_rate", "-of", "json", src],
        capture_output=True, text=True, check=True)
    s = json.loads(out.stdout)["streams"][0]
    num, den = s["r_frame_rate"].split("/")
    return s["width"], s["height"], float(num) / float(den)


def decode_frames(src, w, h):
    # stderr silenced: abandoning the generator early (first-frame peek) breaks
    # the pipe and ffmpeg would spam harmless muxer errors.
    proc = subprocess.Popen(
        [FFMPEG, "-v", "error", "-i", src,
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    n = w * h * 3
    while True:
        buf = proc.stdout.read(n)
        if len(buf) < n:
            break
        yield np.frombuffer(buf, np.uint8).reshape(h, w, 3)
    proc.stdout.close()
    proc.wait()


def corner_color(frame, w, h):
    px = sorted(tuple(int(v) for v in frame[y, x])
                for (x, y) in [(8, 8), (w - 9, 8), (8, h - 9), (w - 9, h - 9)])
    return px[len(px) // 2]


def tolerances(rgb):
    # Vivid chroma backdrops key generously; when the AI painted a DULL one
    # (L1/4.mp4: #48754D) the dark-brown hands sit close to it in RGB space,
    # so the band tightens. Interior body tones need no chromatic margin at
    # all — the border-connectivity rule protects them.
    vivid = max(rgb) > 170 and (max(rgb) - min(rgb)) > 120
    return (0.14, 0.05) if vivid else (0.10, 0.03)


def alpha_mask(frame, bg, sim, blend):
    # Distance to the backdrop colour, normalized 0..1.
    d = np.sqrt(((frame.astype(np.float32) - bg) ** 2).sum(axis=2)) / DIAG
    similar = d < (sim + blend)
    labels, _ = ndimage.label(similar, structure=EIGHT)
    edge = np.unique(np.concatenate([
        labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    edge = edge[edge != 0]
    bgmask = np.isin(labels, edge)
    alpha = np.full(d.shape, 255, np.uint8)
    # Soft edge: alpha ramps over [sim, sim+blend] inside the bg component.
    ramp = np.clip((d - sim) / blend, 0.0, 1.0) * 255
    alpha[bgmask] = ramp[bgmask].astype(np.uint8)
    # Blank the AI-generator sparkle watermark (bottom-right corner).
    h, w = d.shape
    alpha[int(h * 0.84):, int(w * 0.76):] = 0
    return alpha


def process(src, dst):
    w, h, fps = probe(src)
    first = next(decode_frames(src, w, h))
    bg = corner_color(first, w, h)
    sim, blend = tolerances(bg)
    print(f"{w}x{h}@{fps:g}, bg RGB{bg}, key ±{sim}/{blend} border-connected")

    # Pass 1: union bounding box of the character across all frames.
    x1, y1, x2, y2 = w, h, 0, 0
    for frame in decode_frames(src, w, h):
        a = alpha_mask(frame, bg, sim, blend)
        ys, xs = np.nonzero(a > 16)
        if len(xs):
            x1, y1 = min(x1, xs.min()), min(y1, ys.min())
            x2, y2 = max(x2, xs.max()), max(y2, ys.max())
    x1, y1 = max(0, x1 - PAD), max(0, y1 - PAD)
    x2, y2 = min(w - 1, x2 + PAD), min(h - 1, y2 + PAD)
    cw, ch = (x2 - x1 + 1) & ~1, (y2 - y1 + 1) & ~1
    print(f"character bbox: {cw}x{ch}+{x1}+{y1}")

    # Pass 2: alpha + crop in numpy, encode via rawvideo pipe. The fps cap
    # brings the sped-up stream back to ~24fps (a third fewer frames, same
    # perceived smoothness); mpdecimate drops near-duplicates; max
    # compression_level squeezes the same q:v 85 pixels harder.
    scale = (f"scale={MAX_SIDE}:-2" if cw >= ch else f"scale=-2:{MAX_SIDE}")
    enc = subprocess.Popen(
        [FFMPEG, "-y", "-v", "error",
         "-f", "rawvideo", "-pix_fmt", "rgba", "-s", f"{cw}x{ch}",
         "-framerate", f"{fps:g}", "-i", "-",
         "-vf", f"{scale},mpdecimate,setpts=PTS/{SPEED},fps=24",
         "-c:v", "libwebp_anim", "-loop", "0", "-q:v", "85",
         "-compression_level", "6", "-fps_mode", "passthrough", dst],
        stdin=subprocess.PIPE)
    for frame in decode_frames(src, w, h):
        a = alpha_mask(frame, bg, sim, blend)
        rgba = np.dstack([frame, a])[y1:y1 + ch, x1:x1 + cw]
        enc.stdin.write(np.ascontiguousarray(rgba).tobytes())
    enc.stdin.close()
    enc.wait()
    if enc.returncode:
        raise SystemExit(f"encoder failed ({enc.returncode})")
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
