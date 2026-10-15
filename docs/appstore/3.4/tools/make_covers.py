#!/usr/bin/env python3
"""Render cover art for the fictional App Store demo library.

Every title is invented and every cover is built from geometry plus the OFL
fonts in ./fonts, so the screenshots carry no third-party box art. Covers use
each system's box aspect from PVGame+BoxArt.swift (GBA/GBC square, SNES USA
landscape 1.389, Atari 2600 tall 0.72). Deterministic: seeded by slug.

    python3 make_covers.py OUT_DIR    # writes <rom filename>.png per game
Requires Pillow.
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONTS = Path(__file__).resolve().parent / "fonts"
BASE_H = 1000
SS = 2  # supersample

PINK = (252, 28, 140)
PURPLE = (135, 28, 232)
CYAN = (0, 191, 242)
NAVY = (13, 13, 51)
BLACK = (13, 0, 26)
ORANGE = (255, 158, 61)
YELLOW = (255, 230, 90)
WHITE = (248, 248, 255)
MINT = (120, 255, 200)


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), int(size))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgrad(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(top, bottom, y / (h - 1)))
    return img.convert("RGBA")


def glow(img, draw_fn, blur):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))
    sharp = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(sharp))
    img.alpha_composite(sharp)


# ---------------------------------------------------------------- motifs
# Each motif draws into the upper ~62% of the cover; the title sits below.

def m_sun_grid(img, rng, pal):
    w, h = img.size
    hz = int(h * 0.58)
    def draw(d):
        r = int(w * 0.24)
        cx, cy = w // 2, hz - int(r * 0.35)
        for y in range(cy - r, hz):
            dy = y - cy
            if abs(dy) > r:
                continue
            half = int(math.sqrt(r * r - dy * dy))
            t = (y - (cy - r)) / (2 * r)
            if t > 0.5 and (y // (h // 90)) % 3 == 0:
                continue
            d.line([(cx - half, y), (cx + half, y)], fill=lerp(YELLOW, pal[0], t) + (255,))
        for i in range(-12, 13):
            d.line([(w // 2 + i * w // 60, hz), (w // 2 + i * w // 7, h)], fill=pal[1] + (200,), width=3 * SS)
        y, gap = hz, h // 140
        while y < h:
            d.line([(0, y), (w, y)], fill=pal[1] + (200,), width=3 * SS)
            gap = int(gap * 1.32) + 1
            y += gap
    glow(img, draw, 18 * SS)


def m_planet(img, rng, pal):
    w, h = img.size
    d = ImageDraw.Draw(img)
    for _ in range(260):
        x, y = rng.randrange(w), rng.randrange(int(h * 0.7))
        s = rng.choice((1, 1, 2, 3)) * SS
        d.ellipse([x, y, x + s, y + s], fill=rng.choice((WHITE, CYAN, pal[0])) + (255,))
    cx, cy, r = int(w * 0.62), int(h * 0.3), int(min(w, h) * 0.22)
    def draw(dd):
        dd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=pal[1] + (255,))
        dd.ellipse([cx - r + r // 5, cy - r + r // 8, cx + r - r // 6, cy + r - r // 4], fill=lerp(pal[1], WHITE, 0.25) + (255,))
        dd.arc([cx - int(r * 1.9), cy - r // 3, cx + int(r * 1.9), cy + r // 3], 160, 380, fill=CYAN + (255,), width=6 * SS)
    glow(img, draw, 22 * SS)
    # ship silhouette
    sx, sy, s = int(w * 0.28), int(h * 0.48), int(min(w, h) * 0.07)
    def ship(dd):
        dd.polygon([(sx, sy - 2 * s), (sx - s, sy + s), (sx, sy + s // 2), (sx + s, sy + s)], fill=WHITE + (255,))
        dd.polygon([(sx - s // 3, sy + s // 2), (sx + s // 3, sy + s // 2), (sx, sy + 2 * s)], fill=ORANGE + (255,))
    glow(img, ship, 10 * SS)


def m_skyline(img, rng, pal):
    w, h = img.size
    base = int(h * 0.6)
    d = ImageDraw.Draw(img)
    d.ellipse([int(w * 0.66), int(h * 0.07), int(w * 0.82), int(h * 0.07) + int(w * 0.16)], fill=(255, 240, 220, 255))
    for layer, (col, hmin, hmax) in enumerate(((lerp(pal[1], BLACK, 0.4), 0.18, 0.42), (lerp(pal[1], BLACK, 0.7), 0.1, 0.3))):
        x = -10
        while x < w:
            bw = rng.randint(w // 14, w // 7)
            bh = int(h * rng.uniform(hmin, hmax))
            d.rectangle([x, base - bh, x + bw, base], fill=col + (255,))
            if layer == 0:
                for wy in range(base - bh + 14 * SS, base - 8 * SS, 18 * SS):
                    for wx in range(x + 8 * SS, x + bw - 8 * SS, 14 * SS):
                        if rng.random() < 0.4:
                            d.rectangle([wx, wy, wx + 5 * SS, wy + 7 * SS], fill=rng.choice((YELLOW, CYAN, pal[0])) + (255,))
            x += bw + rng.randint(2, 10) * SS
    def line(dd):
        dd.line([(0, base), (w, base)], fill=pal[0] + (255,), width=6 * SS)
    glow(img, line, 14 * SS)


def m_rings(img, rng, pal):
    w, h = img.size
    cx, cy = w // 2, int(h * 0.32)
    def draw(dd):
        for i in range(9):
            r = int(min(w, h) * (0.04 + i * 0.035))
            dd.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(pal[i % 2] if i % 3 else WHITE) + (255,), width=4 * SS)
        for a in range(0, 360, 30):
            x2 = cx + int(math.cos(math.radians(a)) * min(w, h) * 0.36)
            y2 = cy + int(math.sin(math.radians(a)) * min(w, h) * 0.36)
            dd.line([(cx, cy), (x2, y2)], fill=pal[1] + (120,), width=2 * SS)
        dd.ellipse([cx - 14 * SS, cy - 14 * SS, cx + 14 * SS, cy + 14 * SS], fill=YELLOW + (255,))
    glow(img, draw, 16 * SS)


def m_crystal(img, rng, pal):
    w, h = img.size
    cx, cy, s = w // 2, int(h * 0.3), int(min(w, h) * 0.24)
    def draw(dd):
        top, bot = (cx, cy - s), (cx, cy + int(s * 1.1))
        l, r = (cx - int(s * 0.6), cy - s // 5), (cx + int(s * 0.6), cy - s // 5)
        m = (cx, cy - s // 5)
        dd.polygon([top, l, m], fill=lerp(pal[0], WHITE, 0.3) + (255,))
        dd.polygon([top, m, r], fill=pal[0] + (255,))
        dd.polygon([l, bot, m], fill=pal[1] + (255,))
        dd.polygon([m, bot, r], fill=lerp(pal[1], BLACK, 0.3) + (255,))
        for p, q in ((top, l), (top, r), (l, bot), (r, bot), (top, bot), (l, r)):
            dd.line([p, q], fill=WHITE + (255,), width=3 * SS)
    glow(img, draw, 24 * SS)
    d = ImageDraw.Draw(img)
    for _ in range(40):
        x, y = rng.randrange(w), rng.randrange(int(h * 0.62))
        d.line([(x - 6 * SS, y), (x + 6 * SS, y)], fill=WHITE + (200,), width=SS)
        d.line([(x, y - 6 * SS), (x, y + 6 * SS)], fill=WHITE + (200,), width=SS)


def m_comet(img, rng, pal):
    w, h = img.size
    def draw(dd):
        for i in range(7):
            y0 = int(h * (0.12 + i * 0.05))
            dd.line([(int(w * 0.05), y0 + int(h * 0.25)), (int(w * 0.72), y0)], fill=(pal[i % 2]) + (255,), width=(10 - i) * SS)
        cx, cy, r = int(w * 0.74), int(h * 0.2), int(min(w, h) * 0.07)
        dd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE + (255,))
    glow(img, draw, 20 * SS)


def m_gears(img, rng, pal):
    w, h = img.size
    def gear(dd, cx, cy, r, teeth, col):
        pts = []
        for i in range(teeth * 2):
            a = math.pi * i / teeth
            rr = r if i % 2 == 0 else r * 0.82
            for da in (-0.12, 0.12):
                pts.append((cx + math.cos(a + da * math.pi / teeth * 3) * rr, cy + math.sin(a + da * math.pi / teeth * 3) * rr))
        dd.polygon(pts, fill=col + (255,))
        dd.ellipse([cx - r * 0.35, cy - r * 0.35, cx + r * 0.35, cy + r * 0.35], fill=BLACK + (255,))
    def draw(dd):
        s = min(w, h)
        gear(dd, w * 0.4, h * 0.3, s * 0.2, 12, pal[0])
        gear(dd, w * 0.64, h * 0.18, s * 0.12, 9, pal[1])
        gear(dd, w * 0.66, h * 0.44, s * 0.1, 8, MINT)
    glow(img, draw, 14 * SS)


def m_cabinet_dots(img, rng, pal):
    w, h = img.size
    def draw(dd):
        step = int(min(w, h) * 0.06)
        for gy in range(step, int(h * 0.58), step):
            for gx in range(step, w - step // 2, step):
                if rng.random() < 0.55:
                    r = step // 4
                    dd.ellipse([gx - r, gy - r, gx + r, gy + r], fill=rng.choice((pal[0], pal[1], YELLOW)) + (255,))
        # Joystick: base plate, shaft, ball top.
        cx, cy, r = w // 2, int(h * 0.36), int(min(w, h) * 0.1)
        dd.rounded_rectangle([cx - 2 * r, cy + r // 2, cx + 2 * r, cy + r], radius=r // 4, fill=WHITE + (255,))
        dd.line([(cx, cy + r // 2), (cx + r // 3, cy - r)], fill=WHITE + (255,), width=r // 3)
        dd.ellipse([cx + r // 3 - r // 2, cy - r - r // 2, cx + r // 3 + r // 2, cy - r + r // 2], fill=PINK + (255,))
    glow(img, draw, 12 * SS)


def m_maze(img, rng, pal):
    w, h = img.size
    def draw(dd):
        n = 9
        s = int(min(w, h * 0.6) / (n + 1))
        ox, oy = (w - n * s) // 2, int(h * 0.05)
        for gy in range(n):
            for gx in range(n):
                x, y = ox + gx * s, oy + gy * s
                if rng.random() < 0.5:
                    dd.line([(x, y), (x + s, y)], fill=pal[1] + (255,), width=5 * SS)
                else:
                    dd.line([(x, y), (x, y + s)], fill=pal[1] + (255,), width=5 * SS)
        dd.rectangle([ox, oy, ox + n * s, oy + n * s], outline=pal[0] + (255,), width=6 * SS)
        cx, cy = ox + n * s // 2, oy + n * s // 2
        dd.ellipse([cx - s // 3, cy - s // 3, cx + s // 3, cy + s // 3], fill=YELLOW + (255,))
    glow(img, draw, 12 * SS)


def m_shield(img, rng, pal):
    w, h = img.size
    cx, cy, s = w // 2, int(h * 0.3), int(min(w, h) * 0.22)
    def draw(dd):
        dd.polygon([(cx - s, cy - s), (cx + s, cy - s), (cx + s, cy + s // 4), (cx, cy + int(s * 1.3)), (cx - s, cy + s // 4)], fill=pal[1] + (255,))
        dd.polygon([(cx - s, cy - s), (cx, cy - s), (cx, cy + int(s * 1.3)), (cx - s, cy + s // 4)], fill=pal[0] + (255,))
        dd.line([(cx - int(s * 1.5), cy + int(s * 1.1)), (cx + int(s * 1.4), cy - int(s * 1.2))], fill=WHITE + (255,), width=10 * SS)
        dd.rectangle([cx + int(s * 1.1), cy - int(s * 1.35), cx + int(s * 1.35), cy - int(s * 1.05)], fill=YELLOW + (255,))
    glow(img, draw, 18 * SS)


def m_tower(img, rng, pal):
    w, h = img.size
    def draw(dd):
        bw = int(w * 0.34)
        y = int(h * 0.58)
        for i in range(7):
            bh = int(h * 0.065)
            off = int(math.sin(i * 1.3) * w * 0.04)
            dd.rectangle([w // 2 - bw // 2 + off, y - bh, w // 2 + bw // 2 + off, y - 4 * SS], fill=(pal[i % 2]) + (255,))
            for wx in range(w // 2 - bw // 2 + off + 12 * SS, w // 2 + bw // 2 + off - 12 * SS, 22 * SS):
                dd.rectangle([wx, y - bh + 12 * SS, wx + 9 * SS, y - 16 * SS], fill=YELLOW + (255,))
            y -= bh
            bw = int(bw * 0.9)
        dd.polygon([(w // 2 - bw // 2, y), (w // 2, y - int(h * 0.08)), (w // 2 + bw // 2, y)], fill=WHITE + (255,))
    glow(img, draw, 14 * SS)


def m_lanes(img, rng, pal):
    w, h = img.size
    def draw(dd):
        for i in range(6):
            x = int(w * (0.1 + i * 0.16))
            dd.line([(x, int(h * 0.04)), (x, int(h * 0.58))], fill=pal[i % 2] + (255,), width=6 * SS)
            y = int(h * rng.uniform(0.1, 0.5))
            dd.rectangle([x - 18 * SS, y - 10 * SS, x + 18 * SS, y + 10 * SS], fill=YELLOW + (255,))
    glow(img, draw, 16 * SS)


def m_orbits(img, rng, pal):
    w, h = img.size
    cx, cy = w // 2, int(h * 0.3)
    def draw(dd):
        for i, (rx, ry) in enumerate(((0.42, 0.12), (0.32, 0.2), (0.2, 0.26))):
            dd.ellipse([cx - w * rx, cy - h * ry, cx + w * rx, cy + h * ry], outline=pal[i % 2] + (255,), width=4 * SS)
            a = rng.uniform(0, math.pi * 2)
            px, py = cx + math.cos(a) * w * rx, cy + math.sin(a) * h * ry
            dd.ellipse([px - 14 * SS, py - 14 * SS, px + 14 * SS, py + 14 * SS], fill=MINT + (255,))
        dd.ellipse([cx - 34 * SS, cy - 34 * SS, cx + 34 * SS, cy + 34 * SS], fill=ORANGE + (255,))
    glow(img, draw, 14 * SS)


def m_pinball(img, rng, pal):
    w, h = img.size
    def draw(dd):
        for (fx, fy, r) in ((0.3, 0.2, 0.08), (0.65, 0.16, 0.07), (0.5, 0.36, 0.09)):
            R = int(min(w, h) * r)
            dd.ellipse([w * fx - R, h * fy - R, w * fx + R, h * fy + R], outline=pal[0] + (255,), width=8 * SS)
            dd.ellipse([w * fx - R // 2, h * fy - R // 2, w * fx + R // 2, h * fy + R // 2], fill=pal[1] + (255,))
        dd.line([(w * 0.15, h * 0.56), (w * 0.4, h * 0.6)], fill=WHITE + (255,), width=12 * SS)
        dd.line([(w * 0.85, h * 0.56), (w * 0.6, h * 0.6)], fill=WHITE + (255,), width=12 * SS)
        dd.ellipse([w * 0.47, h * 0.47, w * 0.53, h * 0.47 + w * 0.06], fill=YELLOW + (255,))
    glow(img, draw, 14 * SS)


# ---------------------------------------------------------------- catalogue
# (rom filename, title lines, system label, aspect w/h, motif, top, bottom, accents, font)
GAMES = [
    ("Neon Drift.gba", ["NEON", "DRIFT"], "GBA", 1.0, m_sun_grid, (30, 6, 70), (110, 20, 120), (PINK, PURPLE), "BigShoulders-Bold.ttf"),
    ("Starlight Assault.gba", ["STARLIGHT", "ASSAULT"], "GBA", 1.0, m_planet, (4, 4, 24), (30, 10, 70), (PINK, PURPLE), "Tektur-Medium.ttf"),
    ("Skyline Runner.gba", ["SKYLINE", "RUNNER"], "GBA", 1.0, m_skyline, (16, 8, 50), (90, 24, 120), (PINK, PURPLE), "Outfit-Bold.ttf"),
    ("Pixel Pilgrim.gba", ["PIXEL", "PILGRIM"], "GBA", 1.0, m_rings, (6, 30, 40), (10, 70, 90), (CYAN, MINT), "Jura-Medium.ttf"),
    ("Crystal Meridian.sfc", ["CRYSTAL", "MERIDIAN"], "SNES", 1.3889901527, m_crystal, (10, 10, 50), (40, 20, 100), (CYAN, PURPLE), "Tektur-Medium.ttf"),
    ("Turbo Comet.sfc", ["TURBO", "COMET"], "SNES", 1.3889901527, m_comet, (40, 6, 30), (120, 20, 60), (ORANGE, PINK), "EricaOne-Regular.ttf"),
    ("Garden of Gears.sfc", ["GARDEN", "OF GEARS"], "SNES", 1.3889901527, m_gears, (10, 30, 24), (20, 70, 50), (ORANGE, YELLOW), "Outfit-Bold.ttf"),
    ("Midnight Arcade.sfc", ["MIDNIGHT", "ARCADE"], "SNES", 1.3889901527, m_cabinet_dots, (8, 4, 30), (50, 10, 80), (PINK, CYAN), "BigShoulders-Bold.ttf"),
    ("Moonlit Maze.gbc", ["MOONLIT", "MAZE"], "GBC", 1.0, m_maze, (8, 14, 40), (30, 40, 100), (YELLOW, CYAN), "Tektur-Medium.ttf"),
    ("Byte Knight.gbc", ["BYTE", "KNIGHT"], "GBC", 1.0, m_shield, (30, 8, 20), (90, 20, 50), (PINK, PURPLE), "EricaOne-Regular.ttf"),
    ("Tiny Tower Tactics.gbc", ["TINY TOWER", "TACTICS"], "GBC", 1.0, m_tower, (6, 20, 50), (20, 60, 110), (CYAN, PURPLE), "Outfit-Bold.ttf"),
    ("Comet Courier.nes", ["COMET", "COURIER"], "NES", 0.7251925801, m_comet, (4, 16, 40), (20, 50, 100), (CYAN, YELLOW), "Tektur-Medium.ttf"),
    ("Castle Mapper.nes", ["CASTLE", "MAPPER"], "NES", 0.7251925801, m_tower, (30, 10, 40), (80, 24, 90), (PINK, YELLOW), "BigShoulders-Bold.ttf"),
    ("Thunder Lane.md", ["THUNDER", "LANE"], "GENESIS", 0.719651472, m_sun_grid, (10, 4, 40), (90, 10, 90), (CYAN, PINK), "EricaOne-Regular.ttf"),
    ("Aqua Arcadia.md", ["AQUA", "ARCADIA"], "GENESIS", 0.719651472, m_rings, (2, 20, 50), (0, 70, 110), (CYAN, MINT), "Outfit-Bold.ttf"),
    ("Laser Lanes.a26", ["LASER", "LANES"], "2600", 0.72, m_lanes, (20, 4, 30), (70, 10, 70), (PINK, CYAN), "BigShoulders-Bold.ttf"),
    ("Orbit Orchard.a26", ["ORBIT", "ORCHARD"], "2600", 0.72, m_orbits, (4, 20, 30), (10, 60, 70), (CYAN, PINK), "Jura-Medium.ttf"),
    ("Polar Pinball.a26", ["POLAR", "PINBALL"], "2600", 0.72, m_pinball, (6, 10, 40), (40, 30, 110), (CYAN, PURPLE), "Tektur-Medium.ttf"),
]


def fit(fname, text, max_w, start):
    size = start
    while size > 20:
        f = font(fname, size)
        if f.getbbox(text)[2] <= max_w:
            return f
        size -= 4
    return font(fname, size)


def render(spec):
    fname, lines, system, aspect, motif, top, bottom, pal, display = spec
    h = BASE_H * SS
    w = int(h * aspect)
    rng = random.Random(fname)
    img = vgrad(w, h, top, bottom)
    motif(img, rng, pal)
    d = ImageDraw.Draw(img)
    margin = int(min(w, h) * 0.08)
    # Title block, bottom-aligned.
    y = h - margin - int(h * 0.06)
    sizes = []
    for line in reversed(lines):
        f = fit(display, line, w - 2 * margin, int(h * 0.16))
        sizes.append((line, f))
    for line, f in sizes:
        bbox = f.getbbox(line)
        th = bbox[3] - bbox[1]
        y -= th
        d.text((w // 2, y - bbox[1] + th // 2 + 5 * SS), line, font=f, fill=(0, 0, 0, 170), anchor="mm")
        d.text((w // 2, y - bbox[1] + th // 2), line, font=f, fill=WHITE + (255,), anchor="mm")
        y -= int(th * 0.25)
    whisper = font("Silkscreen-Regular.ttf", h * 0.026)
    d.text((w // 2, h - margin), f"PROVENANCE DEMO  ·  {system}", font=whisper, fill=pal[0] + (255,), anchor="ms")
    inset = int(min(w, h) * 0.025)
    d.rectangle([inset, inset, w - inset, h - inset], outline=WHITE + (90,), width=2 * SS)
    # Scanlines at the edge of perception.
    sl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sl)
    for yy in range(0, h, 6 * SS):
        sd.line([(0, yy), (w, yy)], fill=(0, 0, 0, 28), width=SS)
    img.alpha_composite(sl)
    return img.convert("RGB").resize((w // SS, h // SS), Image.LANCZOS)


def main(argv):
    if len(argv) != 2:
        print("usage: make_covers.py OUT_DIR", file=sys.stderr)
        return 2
    out = Path(argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for spec in GAMES:
        path = out / f"{spec[0]}.png"
        render(spec).save(path)
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
