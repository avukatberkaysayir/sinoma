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


# Enclosed backdrop pockets (between the ship-wheel spokes, under the chin —
# L1/4) never touch the frame border, so the connectivity rule keeps them.
# They ARE near-exact backdrop colour though, so a much tighter band keys them
# without risking Orni's loosely-similar watercolour body shading.
TSIM, TBLEND = 0.05, 0.02


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
    # Enclosed pockets: tight-band backdrop colour anywhere else.
    tight = (d < (TSIM + TBLEND)) & ~bgmask
    tramp = np.clip((d - TSIM) / TBLEND, 0.0, 1.0) * 255
    alpha[tight] = np.minimum(alpha[tight], tramp[tight].astype(np.uint8))
    # Blank the AI-generator sparkle watermark (bottom-right corner).
    h, w = d.shape
    alpha[int(h * 0.84):, int(w * 0.76):] = 0
    return alpha


def _hsv(f):
    mx, mn = f.max(axis=2), f.min(axis=2)
    c = mx - mn
    hue = np.zeros_like(mx)
    m = c > 1e-6
    g, b, r = f[..., 1], f[..., 2], f[..., 0]
    for i, (p, q) in enumerate([(g, b), (b, r), (r, g)]):
        idx = m & (mx == f[..., i])
        hue[idx] = (((p - q)[idx] / c[idx]) + 2 * i) % 6
    hue *= 60.0
    sat = np.where(mx > 1e-6, c / np.maximum(mx, 1e-6), 0.0)
    return hue, sat, mx


def _hsv_to_rgb(hue, sat, val):
    c = val * sat
    hp = (hue % 360.0) / 60.0
    x = c * (1 - np.abs(hp % 2 - 1))
    z = np.zeros_like(c)
    hp3 = hp[..., None]
    rgb = np.select(
        [hp3 < 1, hp3 < 2, hp3 < 3, hp3 < 4, hp3 < 5, hp3 >= 5],
        [np.stack([c, x, z], -1), np.stack([x, c, z], -1),
         np.stack([z, c, x], -1), np.stack([z, x, c], -1),
         np.stack([x, z, c], -1), np.stack([c, z, x], -1)])
    return rgb + (val - c)[..., None]


# Selective hue rotation (--recolor h1,h2,smin,vmin,dh): pixels whose hue sits
# in [h1,h2] with saturation>=smin and value>=vmin get their hue shifted by dh
# degrees. Feathered 1px so the shift fades at the selection edge instead of
# snapping. Used to match the sailor Orni's red beak (H~13) to the standard
# orange beak (H~28) without touching the brown wheel (S<=0.54) or the dark
# hands (S~0.46).
def shift_hue(frame, h1, h2, smin, vmin, dh):
    f = frame.astype(np.float32) / 255.0
    hue, sat, mx = _hsv(f)
    sel = ((hue >= h1) & (hue <= h2) & (sat >= smin) & (mx >= vmin))
    if not sel.any():
        return frame
    w = ndimage.gaussian_filter(sel.astype(np.float32), 1.0)
    hue2 = hue + dh * np.clip(w, 0.0, 1.0)
    out = _hsv_to_rgb(hue2, sat, mx) * 255.0
    blend = np.clip(w, 0.0, 1.0)[..., None]
    res = f * 255.0 * (1 - blend) + out * blend
    return np.clip(res, 0, 255).astype(np.uint8)


# Interior spill fix: backdrop light BLEEDS INTO the artwork (chin/neck on
# L1/4 is painted green-tinted), which keying can't touch — those pixels are
# opaque character. Pixels in the green hue band (bg 125 deg; body teal 173
# stays OUT of the band) borrow hue+sat from the nearest clean opaque pixel
# and keep their own value, so shadow shading survives, green tint does not.
def despill_interior(rgb, a):
    f = rgb.astype(np.float32) / 255.0
    hue, sat, mx = _hsv(f)
    spill = (hue > 105) & (hue < 165) & (sat > 0.12) & (a > 16)
    if not spill.any():
        return rgb
    clean = (a > 200) & ((hue <= 100) | (hue >= 170)) & (sat > 0.05)
    if not clean.any():
        return rgb
    iy, ix = ndimage.distance_transform_edt(
        ~clean, return_distances=False, return_indices=True)
    w = np.clip(ndimage.gaussian_filter(spill.astype(np.float32), 1.0), 0, 1)
    fixed = _hsv_to_rgb(hue[iy, ix], sat[iy, ix], mx) * 255.0
    res = rgb.astype(np.float32) * (1 - w[..., None]) + fixed * w[..., None]
    return np.clip(res, 0, 255).astype(np.uint8)


def process(src, dst, recolor=None):
    w, h, fps = probe(src)
    first = next(decode_frames(src, w, h))
    bg = corner_color(first, w, h)
    sim, blend = tolerances(bg)
    print(f"{w}x{h}@{fps:g}, bg RGB{bg}, key ±{sim}/{blend} border-connected")

    def prep(frame):
        return shift_hue(frame, *recolor) if recolor else frame

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
        rgb = despill_interior(prep(frame), a)
        # Edge-bleed guard: transparent/soft pixels still carry backdrop green
        # in RGB, and the straight-alpha downscale smears it into the visible
        # outline (green fringe on the beige app bg). Replace every non-core
        # pixel's colour with its nearest fully-opaque pixel's colour — the
        # soft edge lives in alpha alone.
        core = a >= 200
        if core.any() and not core.all():
            iy, ix = ndimage.distance_transform_edt(
                ~core, return_distances=False, return_indices=True)
            rgb = np.where(core[..., None], rgb, rgb[iy, ix])
        rgba = np.dstack([rgb, a])[y1:y1 + ch, x1:x1 + cw]
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
    recolor = None
    if "--recolor" in sys.argv:  # h1,h2,smin,vmin,dh
        parts = sys.argv[sys.argv.index("--recolor") + 1].split(",")
        recolor = tuple(float(p) for p in parts)
    process(src, dst, recolor=recolor)
    if "--upload" in sys.argv:
        i = sys.argv.index("--upload")
        upload(dst, int(sys.argv[i + 1]), int(sys.argv[i + 2]))


if __name__ == "__main__":
    main()
