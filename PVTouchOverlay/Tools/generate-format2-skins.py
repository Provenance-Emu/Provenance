#!/usr/bin/env python3
"""Generate and bake vector pad candidates for simulator parity testing."""

import argparse
from collections import defaultdict
import json
import math
from pathlib import Path
import subprocess

from format2_geometry import make_nodes


def rgba(color, opacity=1):
    channels = [color["red"], color["green"], color["blue"], color["alpha"] * opacity]
    return "#" + "".join(f"{round(channel * 255):02X}" for channel in channels)


SHAPES = {
    "circle": {"kind": "ellipse"},
    "knob": {"kind": "ellipse"},
    "pill": {"kind": "capsule"},
    "key": {"kind": "rect", "cornerRadius": 6},
    "surface": {"kind": "rect", "cornerRadius": 10},
    "cross": {"kind": "cross", "armRatio": 1 / 3, "cornerRadius": 6},
    "kidney": {"kind": "capsule"},
    "bar": {"kind": "trapezoid", "taper": 0.12},
    "ring": {
        "kind": "path",
        "box": [0, 0, 100, 100],
        # Reverse the inner subpath to cut the center out.
        "d": (
            "M50 0 A50 50 0 1 1 50 100 A50 50 0 1 1 50 0 Z "
            "M50 30 A20 20 0 1 0 50 70 A20 20 0 1 0 50 30 Z"
        ),
    },
}



def cross_path(width, height):
    """Match the legacy rounded plus outline, including concave corners."""
    arm = width / 3
    vertices = [
        (arm, 0), (2 * arm, 0), (2 * arm, arm), (width, arm),
        (width, 2 * arm), (2 * arm, 2 * arm), (2 * arm, height),
        (arm, height), (arm, 2 * arm), (0, 2 * arm), (0, arm), (arm, arm),
    ]

    def tangent(point, neighbor):
        dx, dy = neighbor[0] - point[0], neighbor[1] - point[1]
        distance = math.hypot(dx, dy)
        return dx / distance, dy / distance, distance

    path = [f"M {arm:g} {arm / 2:g}"]
    for index, point in enumerate(vertices):
        ax, ay, ad = tangent(point, vertices[index - 1])
        bx, by, bd = tangent(point, vertices[(index + 1) % len(vertices)])
        radius = min(6, ad / 2, bd / 2)
        before = point[0] + radius * ax, point[1] + radius * ay
        after = point[0] + radius * bx, point[1] + radius * by
        clockwise = int(ay * bx - ax * by > 0)
        path.append(f"L {before[0]:g} {before[1]:g}")
        path.append(f"A {radius:g} {radius:g} 0 0 {clockwise} {after[0]:g} {after[1]:g}")
    return {"kind": "path", "box": [0, 0, width, height], "d": " ".join(path) + " Z"}

def solid(color):
    return {"type": "solid", "color": color}


def gradient(stops, end=1):
    return {"type": "linear", "start": [0.5, 0], "end": [0.5, end], "stops": stops}


def artwork(control, palette):
    shape = control["shape"]
    color = palette[control["paletteSlot"]]
    base = rgba(color)
    yield {
        "type": "shape",
        "shape": SHAPES[shape],
        "fills": [solid(base)],
        "strokes": [{"color": "#FFFFFF", "opacity": 0.35, "width": 1.5}],
        "when": [
            {
                "theme": "glossy",
                "fills": [
                    gradient([[base, 0], [rgba(color, 0.6), 1]]),
                    gradient([["#FFFFFF73", 0], ["#FFFFFF00", 1]], end=0.5),
                ],
                "strokes": [{"color": "#000000", "opacity": 0.35, "width": 1.5}],
            },
            {"theme": "outline", "fills": [], "strokes": [{"color": base, "width": 2}]},
        ],
    }
    if "stick" in control["kind"]:
        if control["axis"] == "horizontal":
            layout = {"size": {"height": "80%"}, "aspect": 1}
        else:
            layout = {"size": {"width": "45%", "height": "45%"}}
        yield {
            "type": "shape",
            "role": "knob",
            "shape": {"kind": "ellipse"},
            "layout": layout,
            "fills": [solid(rgba(color, 0.9))],
        }


def add_profile_art(node, control, palette, condition, frame, unit):
    # Legacy SwiftUI caps type and draws padding/rims in physical points.
    # Frame lengths in a Format 2 document are multiplied by its unit.
    shape = node["children"][0]
    if control["shape"] == "cross":
        # Use one silhouette per trait so the corner radius stays in physical points.
        shape["visible"] = False
        shape = dict(shape, shape=cross_path(frame[2] * unit, frame[3] * unit),
                     visible=condition, when=list(shape["when"]))
        node["children"].append(shape)
    color = rgba(palette[control["paletteSlot"]])
    for theme, stroke_color, opacity, width in (
        (None, "#FFFFFF", 0.35, 1.5),
        ("glossy", "#000000", 0.35, 1.5),
        ("outline", color, 1, 2),
    ):
        patch = {**condition, "strokes": [{"color": stroke_color, "opacity": opacity, "width": width / unit}]}
        if theme:
            patch["theme"] = theme
        shape["when"].append(patch)

    label = control.get("label")
    if not label or control["shape"] in ("ring", "surface", "cross"):
        return
    height = frame[3] * unit
    node["children"].append({
        "type": "text",
        "text": label,
        "color": rgba(palette["label"]),
        "font": {"size": min(height * 0.4, 18) / unit, "weight": "semibold"},
        "fit": True,
        "visible": condition,
        "layout": {"inset": dict.fromkeys(("top", "left", "bottom", "right"), 4 / unit)},
    })


def children_for(rows, templates, palette):
    nodes = {}
    for row in rows:
        device, display, orientation = row["profile"].split("-")
        condition = {"device": device, "displayType": display, "orientation": orientation}
        template = templates[orientation]
        art = {
            group["id"] + "." + control["id"]: (group, control)
            for group in template["groups"]
            for control in group["controls"]
        }
        for node in make_nodes(row, row["unit"]):
            identifier = node["id"]
            group, control = art.get(identifier, (None, None))
            visible = {"flag": "keypad"} if group and group.get("toggledBy") == "keypad" else True
            if identifier not in nodes:
                node["visible"] = False
                node["when"] = []
                if control and node["kind"] != "touchSurface":
                    node["children"] = list(artwork(control, palette))
                    node["opacity"] = group["opacity"]
                    node["states"] = {"pressed": {"scale": 0.92}}
                    if node["kind"] == "thumbstick":
                        node["travel"] = "30%"
                nodes[identifier] = node
            nodes[identifier]["when"].append({**condition, "visible": visible, "layout": node["layout"]})
            if control and node["kind"] != "touchSurface":
                add_profile_art(nodes[identifier], control, palette, condition, node["layout"]["frame"], row["unit"])
    return list(nodes.values())


def document_for(system, layouts):
    by_subtype = defaultdict(dict)
    for layout in system["layouts"]:
        by_subtype[layout["subtype"]][layout["orientation"]] = layout["template"]
    default = system["defaultSubtype"]
    identifier = system["system"]
    trees = {
        subtype: children_for(layouts[identifier, subtype], templates, system["palette"])
        for subtype, templates in by_subtype.items()
    }
    features = {"shapes.parametric", "paint.gradients", "themes", "states", "text"}
    for children in trees.values():
        for node in children:
            if any(art.get("shape", {}).get("kind") == "path" for art in node.get("children", [])):
                features.add("shapes.path")
            if node.get("kind") in ("dpad", "thumbstick", "touchSurface"):
                features.add(f"controls.{node['kind']}")
    variants = {
        subtype: {"label": subtype, "match": {"any": True}, "patch": [{"target": "#root", "children": tree}]}
        for subtype, tree in trees.items() if subtype != default
    }
    if variants:
        features.add("variants")
    doc = {
        "formatVersion": "2.0",
        "identifier": identifier + ".default-overlay",
        "name": identifier + " Default Overlay",
        "gameTypes": [identifier],
        "requires": sorted(features),
        "reference": {"shortSide": 390, "minScale": 1, "maxScale": 1.35},
        "themes": {"glossy": {}, "outline": {}},
        "root": {"type": "group", "id": "root", "children": trees[default]},
    }
    if variants:
        doc["variants"] = variants
    return doc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("templates", type=Path)
    parser.add_argument("geometry", type=Path, help="geometry export with --keypad")
    parser.add_argument("baker", type=Path)
    parser.add_argument("output", type=Path, help="new output directory")
    parser.add_argument("--source-only", action="store_true", help="skip archive baking during snapshot iteration")
    args = parser.parse_args()
    layouts = defaultdict(list)
    for row in json.loads(args.geometry.read_text()):
        layouts[row["pad"]["system"], row["pad"]["subtype"]].append(row)
    systems = json.loads(args.templates.read_text())
    args.output.mkdir()
    failures = []
    archives = 0
    for system in systems:
        identifier = system["system"]
        folder = args.output / identifier
        folder.mkdir()
        source = folder / "skin.json"
        source.write_text(json.dumps(document_for(system, layouts), sort_keys=True, separators=(",", ":")) + "\n")
        if args.source_only:
            continue
        result = subprocess.run(
            [args.baker.resolve(), "--allow-hit-overlaps", source, folder / "baked"],
            text=True, capture_output=True,
        )
        (folder / "bake.log").write_text(result.stderr)
        if result.returncode:
            failures.append(identifier)
            print(f"FAIL {identifier}: {folder / 'bake.log'}", flush=True)
        else:
            archives += len(list((folder / "baked").glob("*.deltaskin")))
    if args.source_only:
        print(f"Generated {len(systems)} source documents")
    else:
        print(f"Baked {len(systems) - len(failures)}/{len(systems)} systems into {archives} archives")
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
