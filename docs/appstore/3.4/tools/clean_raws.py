#!/usr/bin/env python3
"""Remove the DEBUG-only overlay toggle from Dev-UI emulator captures.

Dev apps are Debug builds, so EmulatorWithSkinView draws a `#if DEBUG`
ladybug button in the bottom-right corner of every emulator screen. Release
builds never show it. This paints that corner box with the surrounding colour,
and only when the box's border is uniformly near-black (the letterbox area),
so a capture where something else sits there is left alone and reported.

    python3 clean_raws.py RAW_DIR      # edits iphone/ and ipad/ captures in place
Requires Pillow.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

# Ladybug box per capture size (pixels), measured on iPhone 17 Pro Max and
# iPad Pro 13" captures, padded by a few pixels.
BOXES = {
    (1320, 2868): (1166, 2715, 1248, 2799),
    (2064, 2752): (1958, 2647, 2018, 2708),
}
EMULATOR_SHOTS = ("gameplay-", "pause-menu", "layout-editor")
DARK = 24


def border_is_dark(img, box):
    x0, y0, x1, y1 = box
    px = img.load()
    edge = [(x, y0) for x in range(x0, x1)] + [(x, y1) for x in range(x0, x1)]
    edge += [(x0, y) for y in range(y0, y1)] + [(x1, y) for y in range(y0, y1)]
    colours = [px[x, y] for x, y in edge]
    return all(max(c[:3]) <= DARK for c in colours), colours[0]


def main(argv):
    raw = Path(argv[1])
    for path in sorted(raw.glob("*/*.png")):
        if not path.name.startswith(EMULATOR_SHOTS):
            continue
        img = Image.open(path).convert("RGB")
        box = BOXES.get(img.size)
        if not box:
            continue
        ok, colour = border_is_dark(img, box)
        if not ok:
            print(f"skip (corner not dark): {path}")
            continue
        ImageDraw.Draw(img).rectangle(box, fill=colour)
        img.save(path)
        print(f"cleaned {path}")


if __name__ == "__main__":
    sys.exit(main(sys.argv))
