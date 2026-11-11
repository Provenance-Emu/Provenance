#!/usr/bin/env python3
"""Smoke-test the baker against legacy control geometry on the bake profiles.

The probe archives have no controller art and are only for developer verification.
"""
import argparse
import collections
import json
import pathlib
import subprocess

from format2_geometry import make_nodes

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("geometry", type=pathlib.Path)
parser.add_argument("baker", type=pathlib.Path)
parser.add_argument("output", type=pathlib.Path)
args = parser.parse_args()
baker = args.baker.resolve()
root = args.output
root.mkdir()
rows = json.loads(args.geometry.read_text())

groups = collections.defaultdict(list)
for row in rows:
    groups[(row["pad"]["system"], row["pad"]["subtype"])].append(row)


failures = 0
for (system, subtype), layouts in sorted(groups.items()):
    by_id = collections.defaultdict(dict)
    for row in layouts:
        profile = row["profile"]
        for node in make_nodes(row, row["unit"]):
            by_id[node["id"]][profile] = node
    nodes = []
    for by_profile in by_id.values():
        node = next(iter(by_profile.values())).copy()
        node["visible"] = False
        node["when"] = []
        for profile, instance in by_profile.items():
            device, display, orientation = profile.split("-")
            node["when"].append(
                dict(
                    device=device,
                    displayType=display,
                    orientation=orientation,
                    visible=True,
                    layout=instance["layout"],
                )
            )
        nodes.append(node)
    requires = sorted(
        {
            f"controls.{n['kind']}"
            for n in nodes
            if n.get("kind") in ("dpad", "touchSurface", "thumbstick")
        }
    )
    folder = root / (system + "." + subtype)
    folder.mkdir()
    source = dict(
        formatVersion="2.0",
        identifier=system + "." + subtype,
        name=system,
        gameTypes=[system],
        requires=requires,
        reference=dict(shortSide=390, minScale=1, maxScale=1.35),
        root=dict(type="group", id="root", children=nodes),
    )
    (folder / "skin.json").write_text(json.dumps(source))
    result = subprocess.run(
        [
            baker,
            "--allow-hit-overlaps",
            str(folder / "skin.json"),
            str(folder / "baked"),
        ],
        text=True,
        capture_output=True,
    )
    (folder / "bake.log").write_text(result.stderr)
    if result.returncode:
        failures += 1
        print(f"FAIL {system} {subtype}: {folder / 'bake.log'}", flush=True)

print(f"{len(groups) - failures}/{len(groups)} system and subtype probes baked")
raise SystemExit(bool(failures))
