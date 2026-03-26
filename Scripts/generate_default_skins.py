#!/usr/bin/env python3
"""
generate_default_skins.py — Generate default DeltaSkin bundles for physical controllers.

Usage:
    python3 Scripts/generate_default_skins.py

Outputs:
    PVUI/Sources/PVUIBase/Resources/DefaultSkins/<Name>-<System>.deltaskin/
    containing info.json and controller.svg for each skin.
"""

import json
import os
import sys
import textwrap

SKINS_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "PVUI", "Sources", "PVUIBase", "Resources", "DefaultSkins",
)


# ---------------------------------------------------------------------------
# SVG helpers
# ---------------------------------------------------------------------------

OPACITY = 0.85

DPAD_STYLE = 'fill="#2a2a3a" stroke="#6a6a8a" stroke-width="2"'
BUTTON_A_STYLE = 'fill="#cc3333" stroke="#ff5555" stroke-width="2"'
BUTTON_B_STYLE = 'fill="#ccaa22" stroke="#ffcc44" stroke-width="2"'
BUTTON_X_STYLE = 'fill="#2255cc" stroke="#4477ff" stroke-width="2"'
BUTTON_Y_STYLE = 'fill="#22aa44" stroke="#44cc66" stroke-width="2"'
BUTTON_C_STYLE = 'fill="#aa33cc" stroke="#cc55ee" stroke-width="2"'
SHOULDER_STYLE = 'fill="#2a2a3a" stroke="#8888aa" stroke-width="2"'
CENTER_STYLE = 'fill="#1a1a2a" stroke="#666688" stroke-width="2"'
LABEL_STYLE = 'fill="#ffffff" font-family="Helvetica Neue, sans-serif" font-weight="bold"'
SCREEN_BORDER_STYLE = 'fill="none" stroke="#444466" stroke-width="1.5"'


def svg_header(width, height):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">'


def svg_footer():
    return '</svg>'


def dpad_cross(cx, cy, size):
    """Draw a cross-shaped d-pad centred at (cx, cy) with given total size."""
    arm = size / 3.0
    half = size / 2.0
    x0 = cx - half
    y0 = cy - half
    points = [
        (x0 + arm, y0),
        (x0 + 2 * arm, y0),
        (x0 + 2 * arm, y0 + arm),
        (x0 + size, y0 + arm),
        (x0 + size, y0 + 2 * arm),
        (x0 + 2 * arm, y0 + 2 * arm),
        (x0 + 2 * arm, y0 + size),
        (x0 + arm, y0 + size),
        (x0 + arm, y0 + 2 * arm),
        (x0, y0 + 2 * arm),
        (x0, y0 + arm),
        (x0 + arm, y0 + arm),
    ]
    pts_str = " ".join(f"{p[0]:.1f},{p[1]:.1f}" for p in points)
    return (
        f'  <polygon points="{pts_str}" '
        f'{DPAD_STYLE} opacity="{OPACITY}" rx="3"/>'
    )


def button_circle(cx, cy, r, style, label=None, font_size=14):
    lines = [
        f'  <circle cx="{cx}" cy="{cy}" r="{r}" {style} opacity="{OPACITY}"/>'
    ]
    if label:
        lines.append(
            f'  <text x="{cx}" y="{cy + font_size * 0.38:.1f}" '
            f'text-anchor="middle" dominant-baseline="middle" '
            f'{LABEL_STYLE} font-size="{font_size}" opacity="1">{label}</text>'
        )
    return "\n".join(lines)


def pill_rect(x, y, w, h, style, label=None, font_size=11):
    rx = min(h / 2.0, 12)
    lines = [
        f'  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx:.1f}" '
        f'{style} opacity="{OPACITY}"/>'
    ]
    if label:
        lines.append(
            f'  <text x="{x + w / 2:.1f}" y="{y + h / 2 + font_size * 0.38:.1f}" '
            f'text-anchor="middle" dominant-baseline="middle" '
            f'{LABEL_STYLE} font-size="{font_size}" opacity="1">{label}</text>'
        )
    return "\n".join(lines)


def shoulder_rect(x, y, w, h, label):
    rx = min(h / 2.0, 10)
    return (
        f'  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx:.1f}" '
        f'{SHOULDER_STYLE} opacity="{OPACITY}"/>\n'
        f'  <text x="{x + w / 2:.1f}" y="{y + h / 2 + 5:.1f}" '
        f'text-anchor="middle" dominant-baseline="middle" '
        f'{LABEL_STYLE} font-size="13" opacity="1">{label}</text>'
    )


def screen_border(x, y, w, h):
    rx = 4
    return (
        f'  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" '
        f'{SCREEN_BORDER_STYLE} opacity="0.5"/>'
    )


def system_label(cx, y, text, font_size=18):
    return (
        f'  <text x="{cx}" y="{y}" text-anchor="middle" '
        f'{LABEL_STYLE} font-size="{font_size}" opacity="0.9">{text}</text>'
    )


# ---------------------------------------------------------------------------
# Portrait grip controller SVG (PocketTaco / Soolra)
# ---------------------------------------------------------------------------

def portrait_grip_svg(width, height, system_name, has_xy=False, is_genesis=False, is_n64=False):
    """
    Generate SVG for a portrait-grip controller skin.

    Coordinate system matches DeltaSkin mapping: phone in top portion,
    physical controls in grip body below ~y=640 (for 750×1334).
    """
    # Scale factors from reference 750×1334
    sx = width / 750.0
    sy = height / 1334.0

    def s(x, y):
        return x * sx, y * sy

    def sr(x, y, w, h):
        return x * sx, y * sy, w * sx, h * sy

    elements = []

    # Screen border (very subtle)
    screen_x, screen_y, screen_w, screen_h = sr(0, 80, 750, 560)
    elements.append(screen_border(screen_x, screen_y, screen_w, screen_h))

    # System label just below screen
    lx, ly = s(375, 665)
    elements.append(system_label(lx, ly, system_name, font_size=int(18 * sx)))

    # Left shoulder
    lx0, ly0, lw, lh = sr(0, 0, 225, 70)
    elements.append(shoulder_rect(lx0, ly0, lw, lh, "L"))

    # Right shoulder
    rx0, ry0, rw, rh = sr(525, 0, 225, 70)
    elements.append(shoulder_rect(rx0, ry0, rw, rh, "R"))

    # D-pad cross centred at (150, 1080) in 750×1334 space
    dcx, dcy = s(150, 1080)
    elements.append(dpad_cross(dcx, dcy, 190 * sx))

    if is_n64:
        # N64: A/B face buttons + C buttons
        # C buttons: top/left/right/down cluster
        c_styles = {
            "A": (BUTTON_A_STYLE, 600, 1080),
            "B": (BUTTON_B_STYLE, 510, 1130),
            "C↑": (BUTTON_C_STYLE, 600, 980),
            "C→": (BUTTON_C_STYLE, 660, 1050),
            "C↓": (BUTTON_C_STYLE, 600, 1155),
            "C←": (BUTTON_C_STYLE, 535, 1050),
        }
        for lbl, (style, bx, by) in c_styles.items():
            bcx, bcy = s(bx, by)
            r = int(38 * sx)
            font = max(9, int(12 * sx))
            elements.append(button_circle(bcx, bcy, r, style, lbl, font))

        # Z trigger (top-center shoulder area)
        zx, zy, zw, zh = sr(262, 0, 226, 70)
        elements.append(shoulder_rect(zx, zy, zw, zh, "Z"))
    elif is_genesis:
        # Genesis: A / B / C buttons in a row
        genesis_btns = [
            (BUTTON_A_STYLE, "A", 462 + 42, 1005 + 42),
            (BUTTON_B_STYLE, "B", 555 + 42, 1005 + 42),
            (BUTTON_C_STYLE, "C", 648 + 42, 1005 + 42),
        ]
        for style, lbl, bx, by in genesis_btns:
            bcx, bcy = s(bx, by)
            r = int(40 * sx)
            font = max(9, int(13 * sx))
            elements.append(button_circle(bcx, bcy, r, style, lbl, font))
    elif has_xy:
        # SNES-style: X/Y/A/B diamond
        btns = [
            (BUTTON_X_STYLE, "X", 597, 1010),
            (BUTTON_Y_STYLE, "Y", 507, 1100),
            (BUTTON_A_STYLE, "A", 690, 1100),
            (BUTTON_B_STYLE, "B", 597, 1190),
        ]
        for style, lbl, bx, by in btns:
            bcx, bcy = s(bx, by)
            r = int(40 * sx)
            font = max(9, int(13 * sx))
            elements.append(button_circle(bcx, bcy, r, style, lbl, font))
    else:
        # NES / GBA: A and B only
        bcx_a, bcy_a = s(685, 1090)
        bcx_b, bcy_b = s(580, 1090)
        r = int(42 * sx)
        font = max(9, int(13 * sx))
        elements.append(button_circle(bcx_a, bcy_a, r, BUTTON_A_STYLE, "A", font))
        elements.append(button_circle(bcx_b, bcy_b, r, BUTTON_B_STYLE, "B", font))

    # Start / Select pills
    sel_x, sel_y, sel_w, sel_h = sr(270, 1210, 90, 55)
    sta_x, sta_y, sta_w, sta_h = sr(390, 1210, 90, 55)
    elements.append(pill_rect(sel_x, sel_y, sel_w, sel_h, CENTER_STYLE, "SEL", max(8, int(10 * sx))))
    elements.append(pill_rect(sta_x, sta_y, sta_w, sta_h, CENTER_STYLE, "STA", max(8, int(10 * sx))))

    # Menu circle centred between start/select
    mcx, mcy = s(375, 1162)
    elements.append(button_circle(mcx, mcy, int(28 * sx), CENTER_STYLE, "☰", max(9, int(11 * sx))))

    svg_lines = [svg_header(width, height)] + elements + [svg_footer()]
    return "\n".join(svg_lines) + "\n"


# ---------------------------------------------------------------------------
# Landscape clamshell controller SVG (Backbone / Kishi)
# ---------------------------------------------------------------------------

def landscape_clamshell_svg(width, height, system_name, has_analog=True):
    """
    Generate SVG for a landscape clamshell controller skin (phone in middle).

    Reference: 1334×750 mapping.
    """
    sx = width / 1334.0
    sy = height / 750.0

    def s(x, y):
        return x * sx, y * sy

    def sr(x, y, w, h):
        return x * sx, y * sy, w * sx, h * sy

    elements = []

    # Screen border
    sc_x, sc_y, sc_w, sc_h = sr(417, 75, 500, 600)
    elements.append(screen_border(sc_x, sc_y, sc_w, sc_h))

    # System label above screen area
    lx, ly = s(667, 68)
    elements.append(system_label(lx, ly, system_name, font_size=int(16 * sx)))

    # LEFT SIDE
    # ZL trigger
    zlx, zly, zlw, zlh = sr(0, 0, 200, 55)
    elements.append(shoulder_rect(zlx, zly, zlw, zlh, "ZL"))
    # L bumper
    lbx, lby, lbw, lbh = sr(0, 55, 200, 45)
    elements.append(shoulder_rect(lbx, lby, lbw, lbh, "L"))

    # D-pad centred at (150, 430)
    dcx, dcy = s(150, 430)
    elements.append(dpad_cross(dcx, dcy, 130 * sx))

    if has_analog:
        # Left analog stub
        lacx, lacy = s(250, 545)
        elements.append(button_circle(lacx, lacy, int(42 * sx), DPAD_STYLE, "⬤", int(18 * sx)))

    # Minus / select
    mx, my, mw, mh = sr(560, 355, 55, 30)
    elements.append(pill_rect(mx, my, mw, mh, CENTER_STYLE, "−", max(8, int(11 * sx))))

    # RIGHT SIDE
    # ZR trigger
    zrx, zry, zrw, zrh = sr(1134, 0, 200, 55)
    elements.append(shoulder_rect(zrx, zry, zrw, zrh, "ZR"))
    # R bumper
    rbx, rby, rbw, rbh = sr(1134, 55, 200, 45)
    elements.append(shoulder_rect(rbx, rby, rbw, rbh, "R"))

    # Face buttons (diamond)
    face_btns = [
        (BUTTON_X_STYLE, "X", 1155, 385),
        (BUTTON_Y_STYLE, "Y", 1110, 440),
        (BUTTON_A_STYLE, "A", 1200, 440),
        (BUTTON_B_STYLE, "B", 1155, 495),
    ]
    for style, lbl, bx, by in face_btns:
        bcx, bcy = s(bx, by)
        r = int(32 * sx)
        font = max(9, int(13 * sx))
        elements.append(button_circle(bcx, bcy, r, style, lbl, font))

    if has_analog:
        # Right analog stub
        racx, racy = s(1060, 540)
        elements.append(button_circle(racx, racy, int(42 * sx), DPAD_STYLE, "⬤", int(18 * sx)))

    # Plus / start
    px, py, pw, ph = sr(719, 355, 55, 30)
    elements.append(pill_rect(px, py, pw, ph, CENTER_STYLE, "+", max(8, int(11 * sx))))

    # Home
    hcx, hcy = s(667, 435)
    elements.append(button_circle(hcx, hcy, int(20 * sx), CENTER_STYLE, "⌂", int(12 * sx)))

    svg_lines = [svg_header(width, height)] + elements + [svg_footer()]
    return "\n".join(svg_lines) + "\n"


# ---------------------------------------------------------------------------
# JSON info helpers
# ---------------------------------------------------------------------------

def make_portrait_representation(
    mapping_w, mapping_h,
    screen_input_w, screen_input_h,
    screen_y, screen_h,
    items,
    svg_name="controller.svg",
):
    return {
        "assets": {"resizable": svg_name},
        "translucent": True,
        "mappingSize": {"width": mapping_w, "height": mapping_h},
        "gameScreenFrame": {"x": 0, "y": screen_y, "width": mapping_w, "height": screen_h},
        "screens": [
            {
                "inputFrame": {"x": 0, "y": 0, "width": screen_input_w, "height": screen_input_h},
                "outputFrame": {"x": 0, "y": screen_y, "width": mapping_w, "height": screen_h},
                "placement": "controller",
            }
        ],
        "items": items,
        "extendedEdges": {"top": 7, "bottom": 7, "left": 7, "right": 7},
    }


def make_landscape_representation(
    mapping_w, mapping_h,
    screen_input_w, screen_input_h,
    screen_x, screen_y, screen_w, screen_h,
    items,
    svg_name="controller.svg",
):
    return {
        "assets": {"resizable": svg_name},
        "translucent": True,
        "mappingSize": {"width": mapping_w, "height": mapping_h},
        "gameScreenFrame": {"x": screen_x, "y": screen_y, "width": screen_w, "height": screen_h},
        "screens": [
            {
                "inputFrame": {"x": 0, "y": 0, "width": screen_input_w, "height": screen_input_h},
                "outputFrame": {"x": screen_x, "y": screen_y, "width": screen_w, "height": screen_h},
                "placement": "controller",
            }
        ],
        "items": items,
        "extendedEdges": {"top": 7, "bottom": 7, "left": 7, "right": 7},
    }


def dpad_item(x, y, w, h):
    return {
        "inputs": {"up": "up", "down": "down", "left": "left", "right": "right"},
        "frame": {"x": x, "y": y, "width": w, "height": h},
        "extendedEdges": {"top": 10, "bottom": 10, "left": 10, "right": 10},
    }


def btn(inputs, x, y, w, h, ext=8):
    item = {"inputs": inputs, "frame": {"x": x, "y": y, "width": w, "height": h}}
    if ext:
        item["extendedEdges"] = {"top": ext, "bottom": ext, "left": ext, "right": ext}
    return item


def scale_items(items, sx, sy):
    """Scale all item frames and extended edges by sx/sy."""
    scaled = []
    for item in items:
        new_item = dict(item)
        f = item["frame"]
        new_item["frame"] = {
            "x": round(f["x"] * sx),
            "y": round(f["y"] * sy),
            "width": round(f["width"] * sx),
            "height": round(f["height"] * sy),
        }
        scaled.append(new_item)
    return scaled


# ---------------------------------------------------------------------------
# Portrait grip controller definitions
# ---------------------------------------------------------------------------

# Reference items at 750×1334 for each system
def nes_portrait_items_750():
    return [
        dpad_item(40, 970, 220, 220),
        btn(["a"], 640, 1045, 90, 90),
        btn(["b"], 535, 1045, 90, 90),
        btn(["start"], 390, 1210, 90, 55, 0),
        btn(["select"], 270, 1210, 90, 55, 0),
        btn(["menu"], 330, 1135, 90, 55, 0),
    ]


def snes_portrait_items_750():
    return [
        dpad_item(40, 970, 220, 220),
        btn(["x"], 555, 965, 85, 85),
        btn(["y"], 462, 1055, 85, 85),
        btn(["a"], 648, 1055, 85, 85),
        btn(["b"], 555, 1145, 85, 85),
        btn(["l"], 0, 0, 225, 80, 0),
        btn(["r"], 525, 0, 225, 80, 0),
        btn(["start"], 390, 1210, 90, 55, 0),
        btn(["select"], 270, 1210, 90, 55, 0),
        btn(["menu"], 330, 1135, 90, 55, 0),
    ]


def gba_portrait_items_750():
    return [
        dpad_item(40, 970, 220, 220),
        btn(["a"], 640, 1045, 90, 90),
        btn(["b"], 535, 1045, 90, 90),
        btn(["l"], 0, 0, 225, 80, 0),
        btn(["r"], 525, 0, 225, 80, 0),
        btn(["start"], 390, 1210, 90, 55, 0),
        btn(["select"], 270, 1210, 90, 55, 0),
        btn(["menu"], 330, 1135, 90, 55, 0),
    ]


def gbc_portrait_items_750():
    return [
        dpad_item(40, 970, 220, 220),
        btn(["a"], 640, 1045, 90, 90),
        btn(["b"], 535, 1045, 90, 90),
        btn(["start"], 390, 1210, 90, 55, 0),
        btn(["select"], 270, 1210, 90, 55, 0),
        btn(["menu"], 330, 1135, 90, 55, 0),
    ]


def genesis_portrait_items_750():
    return [
        dpad_item(40, 970, 220, 220),
        btn(["a"], 462, 1005, 85, 85),
        btn(["b"], 555, 1005, 85, 85),
        btn(["c"], 648, 1005, 85, 85),
        btn(["start"], 330, 1210, 90, 55, 0),
        btn(["menu"], 330, 1135, 90, 55, 0),
    ]


def n64_portrait_items_750():
    # N64 physical layout: D-pad, A, B, C-buttons, Z, L, R, Start
    return [
        dpad_item(40, 970, 220, 220),
        btn(["a"], 625, 1045, 80, 80),
        btn(["b"], 520, 1110, 80, 80),
        btn(["cUp"], 580, 950, 75, 75),
        btn(["cRight"], 650, 1010, 75, 75),
        btn(["cDown"], 580, 1130, 75, 75),
        btn(["cLeft"], 510, 1010, 75, 75),
        btn(["l"], 0, 0, 225, 80, 0),
        btn(["r"], 525, 0, 225, 80, 0),
        btn(["z"], 262, 0, 226, 80, 0),
        btn(["start"], 330, 1210, 90, 55, 0),
        btn(["menu"], 330, 1135, 90, 55, 0),
    ]


PORTRAIT_SYSTEMS = {
    "nes": {
        "game_type": "com.rileytestut.delta.game.nes",
        "screen_input": (256, 240),
        "screen_y_std": 80,
        "screen_h_std": 703,
        "screen_y_e2e": 42,
        "screen_h_e2e": 369,
        "items_750": nes_portrait_items_750,
        "has_xy": False,
        "is_genesis": False,
        "is_n64": False,
        "display_name": "NES",
    },
    "snes": {
        "game_type": "com.rileytestut.delta.game.snes",
        "screen_input": (256, 224),
        "screen_y_std": 80,
        "screen_h_std": 656,
        "screen_y_e2e": 42,
        "screen_h_e2e": 344,
        "items_750": snes_portrait_items_750,
        "has_xy": True,
        "is_genesis": False,
        "is_n64": False,
        "display_name": "SNES",
    },
    "gba": {
        "game_type": "com.rileytestut.delta.game.gba",
        "screen_input": (240, 160),
        "screen_y_std": 80,
        "screen_h_std": 500,
        "screen_y_e2e": 42,
        "screen_h_e2e": 262,
        "items_750": gba_portrait_items_750,
        "has_xy": False,
        "is_genesis": False,
        "is_n64": False,
        "display_name": "GBA",
    },
    "gbc": {
        "game_type": "com.rileytestut.delta.game.gbc",
        "screen_input": (160, 144),
        "screen_y_std": 80,
        "screen_h_std": 563,
        "screen_y_e2e": 42,
        "screen_h_e2e": 295,
        "items_750": gbc_portrait_items_750,
        "has_xy": False,
        "is_genesis": False,
        "is_n64": False,
        "display_name": "GBC",
    },
    "genesis": {
        "game_type": "com.rileytestut.delta.game.genesis",
        "screen_input": (320, 224),
        "screen_y_std": 80,
        "screen_h_std": 525,
        "screen_y_e2e": 42,
        "screen_h_e2e": 275,
        "items_750": genesis_portrait_items_750,
        "has_xy": False,
        "is_genesis": True,
        "is_n64": False,
        "display_name": "Genesis",
    },
    "n64": {
        "game_type": "com.rileytestut.delta.game.n64",
        "screen_input": (320, 240),
        "screen_y_std": 80,
        "screen_h_std": 563,
        "screen_y_e2e": 42,
        "screen_h_e2e": 295,
        "items_750": n64_portrait_items_750,
        "has_xy": False,
        "is_genesis": False,
        "is_n64": True,
        "display_name": "N64",
    },
}


PORTRAIT_CONTROLLERS = {
    "PocketTaco": {
        "full_name": "GameSir Pocket Taco",
        "id_prefix": "pockettaco",
        "systems": ["nes", "snes", "gba", "gbc", "n64"],
    },
    "Soolra": {
        "full_name": "Soolra Controller",
        "id_prefix": "soolra",
        "systems": ["nes", "snes", "gba", "gbc", "genesis"],
    },
}


def build_portrait_skin(ctrl_key, sys_key):
    ctrl = PORTRAIT_CONTROLLERS[ctrl_key]
    sys = PORTRAIT_SYSTEMS[sys_key]

    # Standard iPhone portrait (750×1334)
    items_750 = sys["items_750"]()
    sin_w, sin_h = sys["screen_input"]

    std_rep = make_portrait_representation(
        750, 1334,
        sin_w, sin_h,
        sys["screen_y_std"], sys["screen_h_std"],
        items_750,
    )

    # Edge-to-edge iPhone portrait (393×852)
    sx = 393 / 750
    sy = 852 / 1334
    items_e2e = scale_items(items_750, sx, sy)
    e2e_rep = make_portrait_representation(
        393, 852,
        sin_w, sin_h,
        sys["screen_y_e2e"], sys["screen_h_e2e"],
        items_e2e,
    )

    # iPad standard portrait (768×1024)
    sx_ipad = 768 / 750
    sy_ipad = 1024 / 1334
    items_ipad_std = scale_items(items_750, sx_ipad, sy_ipad)
    ipad_std_sh = round(sys["screen_h_std"] * sy_ipad)
    ipad_std_sy = round(sys["screen_y_std"] * sy_ipad)
    ipad_std_rep = make_portrait_representation(
        768, 1024,
        sin_w, sin_h,
        ipad_std_sy, ipad_std_sh,
        items_ipad_std,
    )

    # iPad edge-to-edge portrait (820×1180)
    sx_ipad_e2e = 820 / 750
    sy_ipad_e2e = 1180 / 1334
    items_ipad_e2e = scale_items(items_750, sx_ipad_e2e, sy_ipad_e2e)
    ipad_e2e_sh = round(sys["screen_h_std"] * sy_ipad_e2e)
    ipad_e2e_sy = round(sys["screen_y_std"] * sy_ipad_e2e)
    ipad_e2e_rep = make_portrait_representation(
        820, 1180,
        sin_w, sin_h,
        ipad_e2e_sy, ipad_e2e_sh,
        items_ipad_e2e,
    )

    sys_label = sys["display_name"]
    info = {
        "name": f"{ctrl['full_name']} \u2014 {sys_label}",
        "identifier": f"com.provenance.defaultskins.{ctrl['id_prefix']}.{sys_key}",
        "gameTypeIdentifier": sys["game_type"],
        "debug": False,
        "representations": {
            "iphone": {
                "standard": {"portrait": std_rep},
                "edgeToEdge": {"portrait": e2e_rep},
            },
            "ipad": {
                "standard": {"portrait": ipad_std_rep},
                "edgeToEdge": {"portrait": ipad_e2e_rep},
            },
        },
    }

    svg_std = portrait_grip_svg(
        750, 1334, sys_label,
        has_xy=sys["has_xy"],
        is_genesis=sys["is_genesis"],
        is_n64=sys["is_n64"],
    )

    return info, svg_std


# ---------------------------------------------------------------------------
# Landscape clamshell controller definitions (Backbone, Kishi)
# ---------------------------------------------------------------------------

def nes_landscape_items_1334():
    return [
        dpad_item(50, 360, 130, 130),
        btn(["a"], 1185, 415, 65, 65),
        btn(["b"], 1140, 470, 65, 65),
        btn(["select"], 565, 355, 55, 30, 0),
        btn(["start"], 715, 355, 55, 30, 0),
        btn(["menu"], 645, 435, 44, 44, 0),
        btn(["zl"], 0, 0, 200, 55, 0),
        btn(["zr"], 1134, 0, 200, 55, 0),
        btn(["l"], 0, 55, 200, 45, 0),
        btn(["r"], 1134, 55, 200, 45, 0),
    ]


def snes_landscape_items_1334():
    return [
        dpad_item(50, 360, 130, 130),
        btn(["x"], 1155, 390, 60, 60),
        btn(["y"], 1110, 445, 60, 60),
        btn(["a"], 1200, 445, 60, 60),
        btn(["b"], 1155, 500, 60, 60),
        btn(["l"], 0, 55, 200, 45, 0),
        btn(["r"], 1134, 55, 200, 45, 0),
        btn(["zl"], 0, 0, 200, 55, 0),
        btn(["zr"], 1134, 0, 200, 55, 0),
        btn(["select"], 565, 355, 55, 30, 0),
        btn(["start"], 715, 355, 55, 30, 0),
        btn(["menu"], 645, 435, 44, 44, 0),
    ]


def gba_landscape_items_1334():
    return [
        dpad_item(50, 370, 130, 130),
        btn(["a"], 1200, 440, 65, 65),
        btn(["b"], 1140, 490, 65, 65),
        btn(["l"], 0, 55, 200, 45, 0),
        btn(["r"], 1134, 55, 200, 45, 0),
        btn(["zl"], 0, 0, 200, 55, 0),
        btn(["zr"], 1134, 0, 200, 55, 0),
        btn(["select"], 565, 355, 55, 30, 0),
        btn(["start"], 715, 355, 55, 30, 0),
        btn(["menu"], 645, 435, 44, 44, 0),
    ]


def gbc_landscape_items_1334():
    return [
        dpad_item(50, 370, 130, 130),
        btn(["a"], 1200, 440, 65, 65),
        btn(["b"], 1140, 490, 65, 65),
        btn(["zl"], 0, 0, 200, 55, 0),
        btn(["zr"], 1134, 0, 200, 55, 0),
        btn(["l"], 0, 55, 200, 45, 0),
        btn(["r"], 1134, 55, 200, 45, 0),
        btn(["select"], 565, 355, 55, 30, 0),
        btn(["start"], 715, 355, 55, 30, 0),
        btn(["menu"], 645, 435, 44, 44, 0),
    ]


def genesis_landscape_items_1334():
    return [
        dpad_item(50, 360, 130, 130),
        btn(["a"], 1120, 450, 60, 60),
        btn(["b"], 1180, 420, 60, 60),
        btn(["c"], 1220, 480, 60, 60),
        btn(["zl"], 0, 0, 200, 55, 0),
        btn(["zr"], 1134, 0, 200, 55, 0),
        btn(["l"], 0, 55, 200, 45, 0),
        btn(["r"], 1134, 55, 200, 45, 0),
        btn(["start"], 715, 355, 55, 30, 0),
        btn(["menu"], 645, 435, 44, 44, 0),
    ]


def n64_landscape_items_1334():
    return [
        dpad_item(50, 360, 110, 110),
        btn(["a"], 1200, 440, 65, 65),
        btn(["b"], 1140, 490, 60, 60),
        btn(["cUp"], 1155, 380, 55, 55),
        btn(["cRight"], 1215, 435, 55, 55),
        btn(["cDown"], 1155, 490, 55, 55),
        btn(["cLeft"], 1095, 435, 55, 55),
        btn(["l"], 0, 55, 200, 45, 0),
        btn(["r"], 1134, 55, 200, 45, 0),
        btn(["zl"], 0, 0, 200, 55, 0),
        btn(["zr"], 1134, 0, 200, 55, 0),
        btn(["start"], 715, 355, 55, 30, 0),
        btn(["menu"], 645, 435, 44, 44, 0),
    ]


LANDSCAPE_SYSTEMS = {
    "nes": {
        "game_type": "com.rileytestut.delta.game.nes",
        "screen_input": (256, 240),
        "screen_pos": (417, 75, 500, 600),
        "items_1334": nes_landscape_items_1334,
        "display_name": "NES",
    },
    "snes": {
        "game_type": "com.rileytestut.delta.game.snes",
        "screen_input": (256, 224),
        "screen_pos": (417, 75, 500, 600),
        "items_1334": snes_landscape_items_1334,
        "display_name": "SNES",
    },
    "gba": {
        "game_type": "com.rileytestut.delta.game.gba",
        "screen_input": (240, 160),
        "screen_pos": (417, 115, 500, 520),
        "items_1334": gba_landscape_items_1334,
        "display_name": "GBA",
    },
    "gbc": {
        "game_type": "com.rileytestut.delta.game.gbc",
        "screen_input": (160, 144),
        "screen_pos": (417, 90, 500, 560),
        "items_1334": gbc_landscape_items_1334,
        "display_name": "GBC",
    },
    "genesis": {
        "game_type": "com.rileytestut.delta.game.genesis",
        "screen_input": (320, 224),
        "screen_pos": (417, 90, 500, 560),
        "items_1334": genesis_landscape_items_1334,
        "display_name": "Genesis",
    },
    "n64": {
        "game_type": "com.rileytestut.delta.game.n64",
        "screen_input": (320, 240),
        "screen_pos": (417, 75, 500, 600),
        "items_1334": n64_landscape_items_1334,
        "display_name": "N64",
    },
}


LANDSCAPE_CONTROLLERS = {
    "Backbone": {
        "full_name": "Backbone One",
        "id_prefix": "backbone",
        "systems": ["nes", "snes", "gba", "gbc", "genesis", "n64"],
    },
    "RazerKishi": {
        "full_name": "Razer Kishi v2",
        "id_prefix": "razerkishi",
        "systems": ["nes", "snes", "gba", "gbc", "genesis", "n64"],
    },
}


def build_landscape_skin(ctrl_key, sys_key):
    ctrl = LANDSCAPE_CONTROLLERS[ctrl_key]
    sys = LANDSCAPE_SYSTEMS[sys_key]

    sin_w, sin_h = sys["screen_input"]
    sp_x, sp_y, sp_w, sp_h = sys["screen_pos"]
    items_1334 = sys["items_1334"]()

    std_rep = make_landscape_representation(
        1334, 750,
        sin_w, sin_h,
        sp_x, sp_y, sp_w, sp_h,
        items_1334,
    )

    # Edge-to-edge landscape (852×393)
    sx = 852 / 1334
    sy = 393 / 750
    items_e2e = scale_items(items_1334, sx, sy)
    e2e_sp_x = round(sp_x * sx)
    e2e_sp_y = round(sp_y * sy)
    e2e_sp_w = round(sp_w * sx)
    e2e_sp_h = round(sp_h * sy)
    e2e_rep = make_landscape_representation(
        852, 393,
        sin_w, sin_h,
        e2e_sp_x, e2e_sp_y, e2e_sp_w, e2e_sp_h,
        items_e2e,
    )

    # iPad standard landscape (1366×1024)
    sx_ipad = 1366 / 1334
    sy_ipad = 1024 / 750
    items_ipad_std = scale_items(items_1334, sx_ipad, sy_ipad)
    ipad_std_rep = make_landscape_representation(
        1366, 1024,
        sin_w, sin_h,
        round(sp_x * sx_ipad), round(sp_y * sy_ipad),
        round(sp_w * sx_ipad), round(sp_h * sy_ipad),
        items_ipad_std,
    )

    # iPad edge-to-edge landscape (1180×820)
    sx_ipad_e2e = 1180 / 1334
    sy_ipad_e2e = 820 / 750
    items_ipad_e2e = scale_items(items_1334, sx_ipad_e2e, sy_ipad_e2e)
    ipad_e2e_rep = make_landscape_representation(
        1180, 820,
        sin_w, sin_h,
        round(sp_x * sx_ipad_e2e), round(sp_y * sy_ipad_e2e),
        round(sp_w * sx_ipad_e2e), round(sp_h * sy_ipad_e2e),
        items_ipad_e2e,
    )

    sys_label = sys["display_name"]
    info = {
        "name": f"{ctrl['full_name']} \u2014 {sys_label}",
        "identifier": f"com.provenance.defaultskins.{ctrl['id_prefix']}.{sys_key}",
        "gameTypeIdentifier": sys["game_type"],
        "debug": False,
        "representations": {
            "iphone": {
                "standard": {"landscape": std_rep},
                "edgeToEdge": {"landscape": e2e_rep},
            },
            "ipad": {
                "standard": {"landscape": ipad_std_rep},
                "edgeToEdge": {"landscape": ipad_e2e_rep},
            },
        },
    }

    svg = landscape_clamshell_svg(1334, 750, sys_label)

    return info, svg


# ---------------------------------------------------------------------------
# Write helpers
# ---------------------------------------------------------------------------

def write_bundle(bundle_dir, info, svg_content):
    os.makedirs(bundle_dir, exist_ok=True)

    # Write info.json
    info_path = os.path.join(bundle_dir, "info.json")
    with open(info_path, "w", encoding="utf-8") as fh:
        json.dump(info, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    # Write controller.svg
    svg_path = os.path.join(bundle_dir, "controller.svg")
    with open(svg_path, "w", encoding="utf-8") as fh:
        fh.write(svg_content)

    # Keep transparent.png for backward compatibility if it already exists
    png_path = os.path.join(bundle_dir, "transparent.png")
    if not os.path.exists(png_path):
        # Write minimal 1×1 transparent PNG
        # PNG signature + IHDR + IDAT + IEND (1x1 RGBA transparent)
        png_bytes = bytes([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  # IHDR length + type
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  # 1×1
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,  # 8bit RGBA CRC
            0x89, 0x00, 0x00, 0x00, 0x0B, 0x49, 0x44, 0x41,  # IDAT
            0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02,  # IDAT data
            0x00, 0x01, 0xE2, 0x21, 0xBC, 0x33, 0x00, 0x00,  # IDAT crc
            0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,  # IEND
            0x60, 0x82,
        ])
        with open(png_path, "wb") as fh:
            fh.write(png_bytes)

    print(f"  Written: {os.path.relpath(bundle_dir)}/")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Mapping from system key to bundle-name suffix.
# Abbreviations stay upper-cased; full names use title case.
SYSTEM_BUNDLE_SUFFIX = {
    "nes": "NES",
    "snes": "SNES",
    "gba": "GBA",
    "gbc": "GBC",
    "genesis": "Genesis",
    "n64": "N64",
    "gb": "GB",
    "nds": "NDS",
}


def sys_bundle_name(sys_key):
    """Return the display suffix for a system key in a bundle directory name."""
    return SYSTEM_BUNDLE_SUFFIX.get(sys_key, sys_key.upper())


def main():
    print(f"Output directory: {SKINS_DIR}")
    os.makedirs(SKINS_DIR, exist_ok=True)

    # Portrait grip controllers
    print("\n--- Portrait grip controllers ---")
    for ctrl_key, ctrl in PORTRAIT_CONTROLLERS.items():
        for sys_key in ctrl["systems"]:
            bundle_name = f"{ctrl_key}-{sys_bundle_name(sys_key)}.deltaskin"
            bundle_dir = os.path.join(SKINS_DIR, bundle_name)
            info, svg = build_portrait_skin(ctrl_key, sys_key)
            write_bundle(bundle_dir, info, svg)

    # Landscape clamshell controllers
    print("\n--- Landscape clamshell controllers ---")
    for ctrl_key, ctrl in LANDSCAPE_CONTROLLERS.items():
        for sys_key in ctrl["systems"]:
            bundle_name = f"{ctrl_key}-{sys_bundle_name(sys_key)}.deltaskin"
            bundle_dir = os.path.join(SKINS_DIR, bundle_name)
            info, svg = build_landscape_skin(ctrl_key, sys_key)
            write_bundle(bundle_dir, info, svg)

    print("\nDone.")


if __name__ == "__main__":
    main()
