#!/usr/bin/env python3
"""Render bezel candidates on macOS and write an HTML review sheet.

Usage: python3 Scripts/shaders/audit_bezels.py SLANG_LIBRARY OUTPUT_DIRECTORY
Pass --reuse to assemble a sheet from previously rendered previews.
"""

import argparse
import html
import json
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import quote


SIZES = (640, 480, 1920)
ROOT = Path(__file__).resolve().parents[2]


def candidates(library):
    manifest = json.loads((library / "manifest.json").read_text())
    return sorted(preset["id"] for preset in manifest["presets"]
                  if any(word in preset["id"].lower() for word in ("bezel", "border")))


def preview_path(preset, width):
    return Path("previews") / f"{preset.replace('/', '__')}-{width}.png"


def source_size(preset):
    """Use native inputs where a handheld overlay assumes a particular pixel grid."""
    if "handheld" not in preset and not preset.startswith(("border/sgb", "border/gameboy-player")):
        return 320, 240
    name = preset.rsplit("/", 1)[-1]
    if "gba" in name or "gameboy-player" in name:
        return 240, 160
    if name == "psp":
        return 480, 272
    if name == "ngpc":
        return 160, 152
    if name == "nds-auto-gap":
        return 256, 384
    if name == "3ds-auto-gap":
        return 400, 480
    return 160, 144


def render(library, output, presets):
    with tempfile.TemporaryDirectory(prefix="pv-bezel-audit-") as scratch:
        package = Path(scratch)
        (package / "Sources").mkdir()
        (package / "Sources/PVSlangRuntime").symlink_to(ROOT / "PVShaders/Sources/PVSlangRuntime")
        (package / "Sources/Audit").symlink_to(ROOT / "Scripts/shaders/bezel-audit")
        (package / "Package.swift").write_text("""// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Audit", platforms: [.macOS(.v14)], targets: [
    .target(name: "PVSlangRuntime", resources: [.process("Resources")]),
    .executableTarget(name: "Audit", dependencies: ["PVSlangRuntime"])
], swiftLanguageModes: [.v5])
""")
        build = ["xcrun", "swift", "build", "-c", "release"]
        subprocess.run(build, cwd=package, check=True)
        products = subprocess.check_output([*build, "--show-bin-path"], cwd=package, text=True).strip()
        with (output / "results.tsv").open("w") as results:
            for preset in presets:
                for width in SIZES:
                    (output / preview_path(preset, width)).unlink(missing_ok=True)
                try:
                    run = subprocess.run([str(Path(products) / "Audit"), str(library), str(output / "previews"), preset,
                                          *map(str, source_size(preset))],
                                         capture_output=True, text=True, timeout=45)
                    results.write(run.stdout if run.returncode == 0 else f"{preset}\tfailed ({run.returncode})\n")
                except subprocess.TimeoutExpired:
                    results.write(f"{preset}\ttimed out\n")
                results.flush()


def sheet(output, presets):
    rows = []
    for preset in presets:
        name = html.escape(preset)
        cells = []
        for width in SIZES:
            preview = preview_path(preset, width)
            if (output / preview).is_file():
                url = quote(preview.as_posix())
                cells.append(f'<a href="{url}"><img loading="lazy" src="{url}" alt="{name}, {width}px"></a>')
            else:
                cells.append(f"<span>{width}px unavailable</span>")
        width, height = source_size(preset)
        rows.append(f"<section><h2>{name} · input {width}×{height}</h2><div>{''.join(cells)}</div></section>")
    (output / "index.html").write_text("""<!doctype html>
<meta charset="utf-8"><title>Slang bezel audit</title>
<style>
body { background:#171717; color:#eee; font:16px system-ui; margin:2rem; }
section { margin-bottom:2rem; } h2 { font-size:1rem; overflow-wrap:anywhere; }
section div { display:grid; grid-template-columns:repeat(3,1fr); gap:12px; }
img { display:block; width:100%; } a { color:inherit; }
</style>
<h1>Slang bezel audit</h1>
<p>640×360, 480×360, and 1920×1080. Select a preview to inspect its full size.</p>
""" + "\n".join(rows))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("library", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--reuse", action="store_true")
    parser.add_argument("--preset", action="append", help="Render only this manifest ID. May be repeated.")
    args = parser.parse_args()
    library, output = args.library.resolve(), args.output.resolve()
    presets = candidates(library)
    if args.preset:
        unknown = set(args.preset) - set(presets)
        if unknown:
            parser.error(f"Unknown bezel IDs: {', '.join(sorted(unknown))}")
        presets = sorted(set(args.preset))
    (output / "previews").mkdir(parents=True, exist_ok=True)
    if not args.reuse:
        render(library, output, presets)
    sheet(output, presets)
    print(output / "index.html")


if __name__ == "__main__":
    main()
