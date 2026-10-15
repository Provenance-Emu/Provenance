#!/usr/bin/env python3
"""Build the original "demo cartridge" GBA ROMs used for App Store gameplay frames.

Each ROM shows one 240x160 pixel-art scene drawn here from geometry and the
OFL Silkscreen font, so no third-party game content ever appears in a
screenshot. The ROM is the harness ROM from Scripts/dev/make_harness_rom.py
plus a few ARM instructions that switch to bitmap mode 3 and copy the scene
from ROM into VRAM:

    mov r0,#0x04000000 ; DISPCNT = mode 3 | BG2
    mov r1,#0x400 ; orr r1,#3 ; strh r1,[r0]
    mov r0,#0x06000000 ; mov r1,#0x08000000 ; add r1,#0x200 ; mov r2,#19200
    loop: ldr r3,[r1],#4 ; str r3,[r0],#4 ; subs r2,#1 ; bne loop
    b .

mGBA runs it like any cartridge, so Provenance's real renderer, skins,
shaders and pause menu draw over it.

    python3 make_demo_roms.py OUT_DIR      # writes <slug>.gba and <slug>.png
Requires Pillow.
"""
import math
import random
import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONTS = Path(__file__).resolve().parent / "fonts"
W, H = 240, 160

PINK = (252, 28, 140)
PURPLE = (135, 28, 232)
CYAN = (0, 191, 242)
NAVY = (13, 13, 51)
BLACK = (13, 0, 26)
ORANGE = (255, 158, 61)
YELLOW = (255, 230, 90)
WHITE = (248, 248, 255)

BOOT = [
    0xE3A00301, 0xE3A01B01, 0xE3811003, 0xE1C010B0,
    0xE3A00406, 0xE3A01302, 0xE2811C02, 0xE3A02C4B,
    0xE4913004, 0xE4803004, 0xE2522001, 0x1AFFFFFB,
    0xEAFFFFFE,
]
ROM_SIZE = 256 * 1024
BITMAP_OFFSET = 0x200


def hud_font(size=8):
    return ImageFont.truetype(str(FONTS / "Silkscreen-Regular.ttf"), size)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sky(d, top, bottom, horizon):
    # Banded, not smooth: 15-bit hardware gradients step.
    bands = 12
    for y in range(horizon):
        t = math.floor(y / horizon * bands) / bands
        d.line([(0, y), (W, y)], fill=lerp(top, bottom, t))


def stars(d, rng, n, ymax, colors=(WHITE, CYAN, PINK)):
    for _ in range(n):
        x, y = rng.randrange(W), rng.randrange(ymax)
        d.point((x, y), fill=rng.choice(colors))


def sun(d, cx, cy, r, horizon):
    for y in range(cy - r, cy + r + 1):
        if y >= horizon:
            break
        dy = y - cy
        half = int(math.sqrt(max(r * r - dy * dy, 0)))
        t = (y - (cy - r)) / (2 * r)
        # Stripes cut through the lower half, widening toward the horizon.
        if t > 0.45 and (y - cy) % 6 < 1 + int((t - 0.45) * 8):
            continue
        d.line([(cx - half, y), (cx + half, y)], fill=lerp(YELLOW, PINK, t))


def mountains(d, rng, horizon, color, peak, step):
    x, pts = 0, [(0, horizon)]
    y = horizon - peak // 2
    while x <= W:
        pts.append((x, y))
        x += step
        y = max(horizon - peak, min(horizon - 2, y + rng.randint(-peak // 2, peak // 2)))
    pts += [(W, horizon)]
    d.polygon(pts, fill=color)


def grid(d, horizon, color, phase=0):
    vx = W // 2
    for i in range(-14, 15):
        d.line([(vx + i * 6, horizon), (vx + i * 40, H)], fill=color)
    y, gap = horizon + 2, 2
    while y < H:
        d.line([(0, int(y)), (W, int(y))], fill=color)
        gap *= 1.35
        y += gap


def text(d, xy, s, fill, size=8, anchor="la", shadow=BLACK):
    f = hud_font(size)
    if shadow:
        d.text((xy[0] + 1, xy[1] + 1), s, font=f, fill=shadow, anchor=anchor)
    d.text(xy, s, font=f, fill=fill, anchor=anchor)


# --------------------------------------------------------------------------
# scenes
# --------------------------------------------------------------------------

def scene_neon_drift(rng):
    """Out-run style racer: sunset, road to the horizon, car from behind."""
    img = Image.new("RGB", (W, H), BLACK)
    d = ImageDraw.Draw(img)
    horizon = 92
    sky(d, (24, 6, 58), (196, 40, 120), horizon)
    stars(d, rng, 50, 50)
    sun(d, 120, 70, 30, horizon)
    mountains(d, rng, horizon, (60, 14, 96), 26, 12)
    mountains(d, rng, horizon, (30, 6, 60), 14, 8)
    d.rectangle([0, horizon, W, H], fill=(18, 2, 34))
    grid(d, horizon, (120, 24, 160))
    # Road
    road = [(112, horizon), (128, horizon), (226, H), (14, H)]
    d.polygon(road, fill=(28, 10, 48))
    d.line([(112, horizon), (14, H)], fill=CYAN)
    d.line([(128, horizon), (226, H)], fill=CYAN)
    y, gap = horizon + 3, 2.0
    while y < H:
        t = (y - horizon) / (H - horizon)
        d.rectangle([120 - 1 - int(t * 2), int(y), 120 + int(t * 2), int(y + gap * 0.6)], fill=YELLOW)
        gap *= 1.45
        y += gap * 1.8
    # Car (rear view), centred low.
    cx, cy = 120, 140
    d.rectangle([cx - 26, cy - 6, cx + 26, cy + 10], fill=PINK)
    d.rectangle([cx - 20, cy - 16, cx + 20, cy - 6], fill=(200, 16, 110))
    d.rectangle([cx - 16, cy - 14, cx + 16, cy - 8], fill=(40, 200, 240))
    d.rectangle([cx - 30, cy - 4, cx + 30, cy - 1], fill=(120, 0, 70))
    for sx in (-22, 14):
        d.rectangle([cx + sx, cy - 2, cx + sx + 8, cy + 1], fill=(255, 60, 60))
    for wx in (-28, 20):
        d.rectangle([cx + wx, cy + 6, cx + wx + 8, cy + 16], fill=(10, 0, 20))
    d.rectangle([cx - 6, cy + 4, cx + 6, cy + 7], fill=WHITE)
    # HUD
    text(d, (6, 4), "LAP 2/3", WHITE)
    text(d, (6, 14), "TIME 01:24.62", CYAN)
    text(d, (234, 4), "POS 1ST", YELLOW, anchor="ra")
    text(d, (234, H - 12), "248 KM/H", WHITE, anchor="ra")
    for i in range(10):
        d.rectangle([6 + i * 7, H - 10, 10 + i * 7, H - 5], fill=PINK if i < 8 else (70, 20, 60))
    return img


def scene_starlight(rng):
    """Vertical-ish shmup frame: starfield, planet, ship, enemy wave, bullets."""
    img = Image.new("RGB", (W, H), (4, 2, 16))
    d = ImageDraw.Draw(img)
    stars(d, rng, 140, H)
    for _ in range(14):  # streaks
        x, y = rng.randrange(W), rng.randrange(H)
        d.line([(x, y), (x, y + rng.randint(3, 8))], fill=(60, 80, 160))
    # Planet with ring
    d.ellipse([150, 14, 226, 90], fill=(70, 20, 120))
    d.ellipse([156, 18, 214, 76], fill=(110, 30, 170))
    d.arc([126, 40, 250, 66], 160, 380, fill=CYAN, width=2)
    # Player ship
    px, py = 70, 120
    d.polygon([(px, py - 14), (px - 10, py + 8), (px, py + 3), (px + 10, py + 8)], fill=WHITE)
    d.polygon([(px, py - 8), (px - 4, py + 4), (px + 4, py + 4)], fill=CYAN)
    d.rectangle([px - 14, py + 2, px - 10, py + 10], fill=PINK)
    d.rectangle([px + 10, py + 2, px + 14, py + 10], fill=PINK)
    d.polygon([(px - 3, py + 8), (px + 3, py + 8), (px, py + 18)], fill=ORANGE)
    # Shots
    for i in range(5):
        d.rectangle([px - 1, py - 22 - i * 14, px + 1, py - 16 - i * 14], fill=YELLOW)
    # Enemy wave
    for i in range(5):
        ex, ey = 30 + i * 30, 30 + int(10 * math.sin(i))
        d.polygon([(ex, ey + 8), (ex - 9, ey - 4), (ex, ey), (ex + 9, ey - 4)], fill=PINK)
        d.rectangle([ex - 2, ey - 2, ex + 2, ey + 2], fill=YELLOW)
    for i in range(7):  # enemy bullets
        bx, by = 40 + i * 24, 50 + (i * 13) % 50
        d.ellipse([bx - 2, by - 2, bx + 2, by + 2], fill=(255, 120, 200))
    # Explosion
    for r, c in ((10, ORANGE), (6, YELLOW), (3, WHITE)):
        d.ellipse([120 - r, 46 - r, 120 + r, 46 + r], fill=c)
    text(d, (6, 4), "1UP 0048200", WHITE)
    text(d, (234, 4), "HI 0250000", PINK, anchor="ra")
    for i in range(3):
        d.polygon([(10 + i * 10, H - 6), (6 + i * 10, H - 2), (14 + i * 10, H - 2)], fill=CYAN)
    text(d, (234, H - 12), "STAGE 3", YELLOW, anchor="ra")
    return img


def scene_skyline(rng):
    """Side-scrolling platformer over a neon city at night."""
    img = Image.new("RGB", (W, H), BLACK)
    d = ImageDraw.Draw(img)
    sky(d, (10, 6, 40), (80, 20, 110), 110)
    stars(d, rng, 40, 60)
    d.ellipse([186, 12, 210, 36], fill=(255, 240, 220))
    d.ellipse([192, 10, 214, 32], fill=(10, 6, 40))
    # Far skyline
    x = 0
    while x < W:
        w, h = rng.randint(10, 22), rng.randint(30, 70)
        d.rectangle([x, 110 - h, x + w, 110], fill=(40, 16, 80))
        for wy in range(110 - h + 4, 108, 6):
            for wx in range(x + 2, x + w - 2, 4):
                if rng.random() < 0.35:
                    d.point((wx, wy), fill=rng.choice((YELLOW, CYAN, PINK)))
        x += w + 2
    # Near skyline
    x = -6
    while x < W:
        w, h = rng.randint(18, 30), rng.randint(20, 44)
        d.rectangle([x, 126 - h, x + w, 126], fill=(22, 6, 46))
        d.line([(x, 126 - h), (x + w, 126 - h)], fill=PURPLE)
        x += w + 4
    # Ground tiles
    for tx in range(0, W, 16):
        d.rectangle([tx, 132, tx + 15, H], fill=(60, 20, 100))
        d.rectangle([tx, 132, tx + 15, 135], fill=PINK)
        d.rectangle([tx + 2, 140, tx + 13, 150], fill=(80, 30, 130))
    # Floating platforms + coins
    for (px, py, n) in ((40, 104, 4), (128, 88, 5), (196, 108, 3)):
        for i in range(n):
            d.rectangle([px + i * 10, py, px + i * 10 + 9, py + 7], fill=CYAN)
            d.rectangle([px + i * 10 + 1, py + 1, px + i * 10 + 8, py + 2], fill=WHITE)
        for i in range(n - 1):
            cx, cy = px + 8 + i * 10, py - 10
            d.ellipse([cx - 3, cy - 4, cx + 3, cy + 4], fill=YELLOW)
            d.line([(cx, cy - 2), (cx, cy + 2)], fill=ORANGE)
    # Hero mid-jump
    hx, hy = 92, 104
    d.rectangle([hx, hy, hx + 9, hy + 13], fill=CYAN)            # body
    d.rectangle([hx + 1, hy - 8, hx + 8, hy], fill=(255, 210, 170))  # head
    d.rectangle([hx, hy - 10, hx + 9, hy - 7], fill=PINK)         # visor band
    d.rectangle([hx + 6, hy - 6, hx + 7, hy - 5], fill=BLACK)
    d.rectangle([hx - 4, hy + 3, hx, hy + 6], fill=CYAN)
    d.rectangle([hx + 9, hy - 1, hx + 13, hy + 2], fill=CYAN)
    d.rectangle([hx, hy + 13, hx + 3, hy + 18], fill=PURPLE)
    d.rectangle([hx + 6, hy + 13, hx + 9, hy + 16], fill=PURPLE)
    # Enemy drone
    d.ellipse([160, 118, 174, 130], fill=(255, 80, 80))
    d.rectangle([164, 122, 170, 125], fill=WHITE)
    text(d, (6, 4), "x 37", YELLOW)
    d.ellipse([0, 4, 0, 4], fill=YELLOW)
    text(d, (120, 4), "SKYLINE 2-1", WHITE, anchor="ma")
    for i in range(3):
        x0 = 206 + i * 10
        d.polygon([(x0 + 4, 14), (x0, 9), (x0 + 2, 6), (x0 + 4, 8), (x0 + 6, 6), (x0 + 8, 9)], fill=PINK)
    return img


SCENES = {
    "neon-drift": ("NEON DRIFT", scene_neon_drift),
    "starlight-assault": ("STARLIGHT", scene_starlight),
    "skyline-runner": ("SKYLINE RUN", scene_skyline),
}


def to_bgr555(img):
    out = bytearray()
    for r, g, b in img.getdata():
        out += struct.pack("<H", (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10))
    return bytes(out)


def rom(img, title):
    data = bytearray(ROM_SIZE)
    data[0:4] = (0xEA000000 | ((0xC0 - 8) // 4)).to_bytes(4, "little")  # b 0xC0
    data[0xA0:0xAC] = title.encode()[:12].ljust(12, b"\0")
    data[0xAC:0xB0] = b"PVDM"
    data[0xB0:0xB2] = b"01"
    data[0xB2] = 0x96
    data[0xBD] = (-(sum(data[0xA0:0xBD]) + 0x19)) & 0xFF
    for i, word in enumerate(BOOT):
        data[0xC0 + i * 4:0xC4 + i * 4] = word.to_bytes(4, "little")
    pixels = to_bgr555(img)
    data[BITMAP_OFFSET:BITMAP_OFFSET + len(pixels)] = pixels
    return bytes(data)


def main(argv):
    if len(argv) != 2:
        print("usage: make_demo_roms.py OUT_DIR", file=sys.stderr)
        return 2
    out = Path(argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for slug, (title, fn) in SCENES.items():
        img = fn(random.Random(slug))
        img.save(out / f"{slug}.png")
        (out / f"{slug}.gba").write_bytes(rom(img, title))
        print(out / f"{slug}.gba")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
