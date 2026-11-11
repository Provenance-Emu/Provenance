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

Generate and bake the vector candidates before running the renderer comparison.
Use a SkinKit checkout containing #148 to build `skinkit-bake`.

```sh
PVTouchOverlay/Tools/export-skins.sh > overlay-templates.json
PVTouchOverlay/Tools/export-skins.sh --geometry --keypad > overlay-geometry-keypad.json
python3 PVTouchOverlay/Tools/generate-format2-skins.py \
  overlay-templates.json overlay-geometry-keypad.json /path/to/skinkit-bake /tmp/default-pad-candidates
PVTouchOverlay/Tools/run-overlay-snapshots.sh SIMULATOR_UDID /path/to/SkinKit \
  /tmp/default-pad-snapshots /tmp/default-pad-candidates
```

The output includes one source per system, the classic archive for its default
pad and any selectable subtypes, and a log for each bake. It also includes the
flat, glossy, and outline styles. `--source-only` skips archive writes during
render iteration. Candidate frames are authored for the nine bake profiles.
Use the app's resolved geometry when integrating arbitrary viewport sizes and
live core aspect ratios.

To verify migration through the actual Format 2 resolver, run the snapshot
script with `PV97_EDITS_TEST_SOURCE` pointing to
`PVTouchOverlay/Tests/PVTouchOverlayTests/OverlayFormat2ResolverSnapshotTests.swift`
and `PV97_ONLY_TESTING=OverlaySnapshots/OverlayFormat2ResolverSnapshotTests`.
This uses the legacy layout keys and per-game fallback and leaves the saved file
in its original format.

The snapshot runner captures the same idle artwork with the legacy SwiftUI
control views and with SkinKit on an iOS simulator at 2×. Select a style with
`PV97_STYLE=flat|glossy|outline`. It writes both images and `pixelmatch.csv`
and fails the comparison if a pair exceeds 0.25% at threshold 0.1 with
antialiasing excluded. Use `PV97_BASELINE_DIR` to reuse captures from the
same style.
