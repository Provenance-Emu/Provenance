#!/usr/bin/env python3
"""Frame raw simulator captures into App Store screenshots (Provenance retrowave).

Layout follows the iFly store set: a benefit-led caption on top, the real
screen below in a device bezel, one consistent background system across the
set. The background is procedural (gradient sky, striped sun, perspective
grid) in the PVThemes RetroWave palette, so it renders sharp at every size.

    python3 compose.py shots.json RAW_DIR OUT_DIR [--only NAME]

shots.json: {"devices": {...}, "shots": [{"name", "device", "raw", "title",
"accent", "subtitle"}]}. Output is flattened RGB PNG at the exact canvas size.
Requires Pillow.
"""
import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

FONTS = Path(__file__).resolve().parent / "fonts"

PINK = (252, 28, 140)
PURPLE = (135, 28, 232)
CYAN = (0, 191, 242)
NAVY = (13, 13, 51)
BLACK = (13, 0, 26)
YELLOW = (255, 230, 90)
WHITE = (255, 255, 255)


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), int(size))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def background(w, h, seed):
    """Night sky -> magenta horizon, sun, grid floor. Horizon sits low so the
    caption reads on the dark sky and the device covers most of the floor."""
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    hz = int(h * 0.80)
    stops = [(0.0, (8, 2, 22)), (0.45, (26, 8, 64)), (0.8, (96, 20, 120)), (1.0, (196, 36, 128))]
    for y in range(hz):
        t = y / hz
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                d.line([(0, y), (w, y)], fill=lerp(c0, c1, (t - t0) / (t1 - t0)))
                break
    rng = random.Random(seed)
    for _ in range(int(w * h / 9000)):
        x, y = rng.randrange(w), rng.randrange(int(hz * 0.75))
        r = rng.choice((1, 1, 1, 2, 2, 3))
        d.ellipse([x - r, y - r, x + r, y + r], fill=lerp((120, 110, 200), WHITE, rng.random()))
    # Sun, striped toward the horizon.
    s = min(w, h)
    r = int(s * 0.30)
    cx, cy = w // 2, hz - int(r * 0.25)
    sun = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sun)
    stripe = max(4, h // 260)
    for y in range(cy - r, hz):
        dy = y - cy
        if abs(dy) > r:
            continue
        half = int(math.sqrt(r * r - dy * dy))
        t = (y - (cy - r)) / (2 * r)
        if t > 0.42:
            band = int((y - cy + r) / (stripe * 3))
            if (y - cy + r) % (stripe * 3) < int(stripe * (t - 0.4) * 3.5):
                continue
        sd.line([(cx - half, y), (cx + half, y)], fill=lerp(YELLOW, PINK, t) + (255,))
    halo = sun.filter(ImageFilter.GaussianBlur(s // 18))
    img.paste(halo, (0, 0), halo)
    img.paste(sun, (0, 0), sun)
    # Floor + grid.
    d.rectangle([0, hz, w, h], fill=(18, 2, 34))
    grid = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    lw = max(2, s // 500)
    for i in range(-30, 31):
        gd.line([(w // 2 + i * w // 40, hz), (w // 2 + i * w // 3, h + h // 2)], fill=PINK + (200,), width=lw)
    y, gap = hz, max(3, h // 400)
    while y < h:
        gd.line([(0, y), (w, y)], fill=PINK + (200,), width=lw)
        gap = gap * 1.3 + 1
        y += int(gap)
    glow = grid.filter(ImageFilter.GaussianBlur(lw * 4))
    img.paste(glow, (0, 0), glow)
    img.paste(grid, (0, 0), grid)
    d.line([(0, hz), (w, hz)], fill=lerp(PINK, WHITE, 0.4), width=lw * 2)
    return img


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def device(screen, kind):
    """Wrap a capture in a simple bezel: black body, thin metallic rim."""
    sw, sh = screen.size
    if kind == "tv":
        bezel, radius, inner = int(sw * 0.012), int(sw * 0.012), 0
    elif kind == "ipad":
        bezel, radius, inner = int(min(sw, sh) * 0.035), int(min(sw, sh) * 0.07), int(min(sw, sh) * 0.035)
    else:
        bezel, radius, inner = int(sw * 0.035), int(sw * 0.17), int(sw * 0.135)
    w, h = sw + 2 * bezel, sh + 2 * bezel
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    rim = max(3, bezel // 5)
    bd.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius + bezel // 2, fill=(70, 66, 92, 255))
    bd.rounded_rectangle([rim, rim, w - 1 - rim, h - 1 - rim], radius=radius + bezel // 2 - rim, fill=(6, 4, 12, 255))
    scr = screen.convert("RGBA")
    if inner:
        scr.putalpha(ImageChops.multiply(scr.getchannel("A"), rounded_mask(scr.size, inner)))
    body.alpha_composite(scr, (bezel, bezel))
    return body


def shadowed(layer, blur, color=(0, 0, 0, 170), glow_color=None):
    pad = blur * 3
    out = Image.new("RGBA", (layer.width + 2 * pad, layer.height + 2 * pad), (0, 0, 0, 0))
    a = layer.getchannel("A")
    shadow = Image.new("RGBA", layer.size, color)
    shadow.putalpha(ImageChops.multiply(a, Image.new("L", layer.size, color[3])))
    out.alpha_composite(shadow, (pad, pad + blur // 2))
    out = out.filter(ImageFilter.GaussianBlur(blur))
    if glow_color:
        g = Image.new("RGBA", out.size, (0, 0, 0, 0))
        gl = Image.new("RGBA", layer.size, glow_color)
        gl.putalpha(ImageChops.multiply(a, Image.new("L", layer.size, glow_color[3])))
        g.alpha_composite(gl, (pad, pad))
        out.alpha_composite(g.filter(ImageFilter.GaussianBlur(blur * 2)))
    out.alpha_composite(layer, (pad, pad))
    return out, pad


def caption(img, title, accent, subtitle, box, title_px):
    """Title in white with the accent word in pink, subtitle in cyan, centred."""
    d = ImageDraw.Draw(img)
    x0, y0, x1, _ = box
    maxw = x1 - x0
    tf = font("Outfit-Bold.ttf", title_px)
    sf = font("Outfit-Regular.ttf", title_px * 0.46)
    # Greedy wrap of the title.
    words, lines, cur = title.split(), [], ""
    for wd in words:
        trial = (cur + " " + wd).strip()
        if tf.getlength(trial) <= maxw:
            cur = trial
        else:
            lines.append(cur)
            cur = wd
    lines.append(cur)
    y = y0
    lh = int(title_px * 1.08)
    acc = set(accent.split()) if accent else set()
    for line in lines:
        lw = tf.getlength(line)
        x = (x0 + x1) / 2 - lw / 2
        for i, wd in enumerate(line.split()):
            piece = wd + (" " if i < len(line.split()) - 1 else "")
            col = PINK if wd.strip(".,!") in acc else WHITE
            if col == PINK:
                glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
                ImageDraw.Draw(glow).text((x, y), wd, font=tf, fill=PINK + (200,))
                g = glow.filter(ImageFilter.GaussianBlur(title_px // 6))
                img.paste(g, (0, 0), g)
            d.text((x, y), piece, font=tf, fill=col)
            x += tf.getlength(piece)
        y += lh
    if subtitle:
        y += int(title_px * 0.18)
        swords, slines, cur = subtitle.split(), [], ""
        for wd in swords:
            trial = (cur + " " + wd).strip()
            if sf.getlength(trial) <= maxw:
                cur = trial
            else:
                slines.append(cur)
                cur = wd
        slines.append(cur)
        for line in slines:
            d.text(((x0 + x1) / 2, y), line, font=sf, fill=CYAN, anchor="ma")
            y += int(title_px * 0.58)
    return y


def compose(spec, dev, raw_dir):
    W, H = dev["size"]
    img = background(W, H, spec["name"])
    raw = Image.open(raw_dir / dev.get("raw_dir", "") / spec["raw"]).convert("RGB")
    margin = int(min(W, H) * dev.get("margin", 0.07))
    title_px = int(min(W, H) * dev["title"])
    bottom = caption(img, spec["title"], spec.get("accent", ""), spec.get("subtitle", ""),
                     (margin, int(H * dev.get("top", 0.045)), W - margin, 0), title_px)
    # Device fills the remaining space.
    avail_h = H - bottom - int(H * dev.get("gap", 0.035)) - int(H * dev.get("foot", 0.0))
    avail_w = W - 2 * int(W * dev.get("side", 0.09))
    body = device(raw, dev["kind"])
    scale = min(avail_w / body.width, avail_h / body.height)
    body = body.resize((int(body.width * scale), int(body.height * scale)), Image.LANCZOS)
    layer, pad = shadowed(body, max(8, int(min(W, H) * 0.02)), glow_color=PURPLE + (110,))
    x = (W - body.width) // 2 - pad
    y = H - int(H * dev.get("foot", 0.0)) - body.height - pad
    if dev.get("center_device"):
        y = bottom + int(H * dev.get("gap", 0.035)) + (avail_h - body.height) // 2 - pad
    canvas = img.convert("RGBA")
    canvas.alpha_composite(layer, (x, y)) if x >= 0 and y >= 0 else canvas.paste(layer, (x, y), layer)
    out = canvas.convert("RGB")
    assert out.size == (W, H), out.size
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest")
    ap.add_argument("raw_dir")
    ap.add_argument("out_dir")
    ap.add_argument("--only", action="append")
    a = ap.parse_args()
    m = json.loads(Path(a.manifest).read_text())
    out = Path(a.out_dir)
    for spec in m["shots"]:
        if a.only and spec["name"] not in a.only:
            continue
        dev = m["devices"][spec["device"]]
        dest = out / dev["dir"] / f"{spec['name']}.png"
        dest.parent.mkdir(parents=True, exist_ok=True)
        compose(spec, dev, Path(a.raw_dir)).save(dest, optimize=True)
        print(dest)


if __name__ == "__main__":
    main()
