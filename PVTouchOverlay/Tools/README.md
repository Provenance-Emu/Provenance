Run the exporter from the repository root on macOS.

```sh
PVTouchOverlay/Tools/export-skins.sh > overlay-templates.json
PVTouchOverlay/Tools/export-skins.sh --geometry > overlay-geometry.json
```

The template export captures authored data for every bound system and subtype. The geometry export resolves the existing layout engine on the nine Format 2 bake profiles at a 4:3 game aspect. It records group frames and opacity, control draw and hit frames, and screen frames. Compare these before running pixel snapshots on the simulator.

To inspect saved edits, pass a copy of `touch_overlay_layout_v1.json` with `--layout-file PATH`. Add `--game-md5 MD5` to select a game's override or fall back to its shared layout. Add `--keypad` to include groups shown when the keypad toggle is on. The exporter reads the layout file without rewriting it.

Run the geometry bake smoke test with a `skinkit-bake` build that supports
`--allow-hit-overlaps` (SkinKit #148).

```sh
python3 PVTouchOverlay/Tools/check-format2-bakes.py overlay-geometry.json /path/to/skinkit-bake /tmp/overlay-bake-probes
```

The output directory must be new. Each probe keeps the legacy input tokens
and control and screen frames for the selected bake profiles. These archives
contain no controller art and are not the bundled skins. Review any failed
probe's `bake.log` before comparing simulator renders.
