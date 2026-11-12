#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
    echo "Set PV97_STYLE=flat|glossy|outline to select the legacy style and candidate theme." >&2
    echo "Set PV97_BASELINE_DIR to reuse the 2× legacy PNGs from a previous run." >&2
    echo "Set PV97_EDITS_TEST_SOURCE to run an additional XCTest source against the working-tree edit projector." >&2
    echo "Set PV97_RUNTIME_ART=1 to exercise the app artwork layer against the bundled source directory." >&2
    echo "Set PV97_ONLY_TESTING to restrict XCTest (target[/class[/method]])." >&2
    echo "Usage: $0 SIMULATOR_UDID SKINKIT_CHECKOUT OUTPUT_DIRECTORY [CANDIDATE_DIRECTORY]" >&2
    exit 2
fi

tools_dir="$(cd "$(dirname "$0")" && pwd)"
overlay="$(cd "$tools_dir/.." && pwd)"
simulator="$1"
skinkit="$(cd "$2" && pwd)"
mkdir -p "$3"
output="$(cd "$3" && pwd)"
style="${PV97_STYLE:-flat}"
runtime_art="${PV97_RUNTIME_ART:-0}"
case "$style" in
    flat|glossy|outline) ;;
    *) echo "Invalid PV97_STYLE: $style (expected flat, glossy, or outline)" >&2; exit 2 ;;
esac
candidates="${4:-}"
if [[ -n "$candidates" ]]; then
    candidates="$(cd "$candidates" && pwd)"
fi
baseline="${PV97_BASELINE_DIR:-}"
if [[ -n "$baseline" ]]; then
    baseline="$(cd "$baseline" && pwd)"
    baseline_style=flat
    if [[ -f "$baseline/style.txt" ]]; then
        baseline_style="$(cat "$baseline/style.txt")"
    fi
    if [[ "$baseline_style" != "$style" ]]; then
        echo "Baseline style $baseline_style does not match PV97_STYLE=$style" >&2
        exit 2
    fi
fi
scratch="$(mktemp -d "${TMPDIR:-/tmp}/pv-overlay-snapshots.XXXXXXXX")"
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/Legacy" "$scratch/Settings" "$scratch/Tests" "$scratch/TouchSelection"
cp "$skinkit/Sources/SkinKitUI/Input/"{SkinTouchSelection,TouchInputRole}.swift "$scratch/TouchSelection/"
# Keep the reference available after the migration removes the legacy renderer.
legacy_ref="${PV97_LEGACY_REF:-b505cac9bb}"
legacy_path="PVTouchOverlay/Sources/PVTouchOverlay"
style_path="PVSettings/Sources/PVSettings/Settings/Model/OverlayStyle.swift"
git -C "$overlay/.." archive "$legacy_ref" "$legacy_path" "$style_path" | tar -xf - -C "$scratch"
for part in Bindings Families Layout Model Touch Render; do
    mv "$scratch/$legacy_path/$part" "$scratch/Legacy/"
done
# Resolve the shared input helpers from the copied sources in the isolated module.
for source in OverlayTouchTracker TouchInputRole; do
    sed -i '' 's/^import SkinKitUI$/import SnapshotTouchSelection/' "$scratch/Legacy/Touch/$source.swift"
done
if [[ "$runtime_art" == 1 ]]; then
    cp "$overlay/Sources/PVTouchOverlay/Render/"{OverlayFormat2Artwork,OverlayHostView,OverlayGroupView,OverlayEditorView,OverlayEditController,OverlayInputSink}.swift "$scratch/Legacy/Render/"
    cp "$overlay/Sources/PVTouchOverlay/Layout/"{OverlayLayoutEngine,OverlayScreenPlanner}.swift "$scratch/Legacy/Layout/"
    cp "$overlay/Sources/PVTouchOverlay/Families/OverlayFamilyKit.swift" "$scratch/Legacy/Families/"
    cp -R "$overlay/Sources/PVTouchOverlay/Store" "$scratch/Legacy/"
    sed -i '' '/^import PVLogging$/d' "$scratch/Legacy/Store/OverlayLayoutStore.swift"
    cat > "$scratch/Legacy/Store/SnapshotLogging.swift" <<'SWIFT'
func WLOG(_ message: String) { print(message) }
func ELOG(_ message: String) { print(message) }
SWIFT
    cp "$overlay/Tests/PVTouchOverlayTests/"{OverlayFormat2RuntimeTests,OverlayLayoutEngineTests,OverlayTouchTrackerTests,OverlayMultiButtonTouchTests,OverlayHostDispatchTests}.swift "$scratch/Tests/"
else
    rm "$scratch/Legacy/Render/OverlayEditorView.swift" "$scratch/Legacy/Render/OverlayEditController.swift"
fi
mv "$scratch/$style_path" "$scratch/Settings/"
cp "$overlay/Tests/PVTouchOverlayTests/OverlayIdleSnapshotTests.swift" "$scratch/Tests/"
if [[ -n "${PV97_EDITS_TEST_SOURCE:-}" ]]; then
    cp "$overlay/Sources/PVTouchOverlay/Layout/OverlayFormat2Edits.swift" "$scratch/Legacy/Layout/"
    cp "$PV97_EDITS_TEST_SOURCE" "$scratch/Tests/"
fi

# Keep the artwork and touch stack unchanged. The isolated settings target only
# needs the production style and the production default for arcade touch.
cat > "$scratch/Settings/ArcadeTouch.swift" <<'SWIFT'
@_exported import Defaults
extension Defaults.Keys {
    public static let arcadeMultiButtonTouch = Key<Bool>("arcadeMultiButtonTouch", default: true)
}
SWIFT

python3 - "$scratch" "$skinkit" "$output" "$candidates" "$baseline" "$style" "$runtime_art" <<'PYTHON'
import json
import pathlib
import sys

scratch, skinkit, output, candidates, baseline, style, runtime_art = sys.argv[1:]
runtime_flag = '.define("OVERLAY_RUNTIME_ART"), ' if runtime_art == "1" else ""
quote = lambda value: json.dumps(value, ensure_ascii=False)
root = pathlib.Path(scratch)
(root / "Tests" / "SnapshotPaths.swift").write_text(
    f"let snapshotOutput = {quote(output)}\nlet snapshotCandidates = {quote(candidates)}\nlet snapshotBaseline = {quote(baseline)}\n"
    f"let snapshotStyle = {quote(style)}\n"
)
(root / "Package.swift").write_text(f"""// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OverlaySnapshots",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(name: "SkinKit", path: {quote(skinkit)}),
        .package(url: "https://github.com/Provenance-Emu/PVSystems.git", exact: "1.0.0"),
        .package(url: "https://github.com/sindresorhus/Defaults.git", exact: "9.0.2")
    ],
    targets: [
        .target(name: "SnapshotTouchSelection", path: "TouchSelection"),
        .target(name: "PVSettings", dependencies: ["Defaults"], path: "Settings"),
        .target(name: "PVTouchOverlay", dependencies: [
            "PVSettings", .product(name: "PVSystems", package: "PVSystems"),
            "SnapshotTouchSelection", .product(name: "SkinKit2Core", package: "SkinKit"),
            .product(name: "SkinKit2Render", package: "SkinKit")
        ], path: "Legacy"),
        .testTarget(name: "OverlaySnapshots", dependencies: [
            "PVTouchOverlay", "PVSettings", .product(name: "PVSystems", package: "PVSystems"),
            .product(name: "SkinKit2Core", package: "SkinKit"),
            .product(name: "SkinKit2Render", package: "SkinKit")
        ], path: "Tests", swiftSettings: [.define("OVERLAY_SNAPSHOT_HARNESS"), {runtime_flag}.unsafeFlags(["-O"])])
    ],
    swiftLanguageModes: [.v5]
)
""")
PYTHON

cd "$scratch"
test_status=0
test_filters=()
if [[ -n "${PV97_ONLY_TESTING:-}" ]]; then
    test_filters+=("-only-testing:$PV97_ONLY_TESTING")
fi
xcodebuild test ${test_filters[@]+"${test_filters[@]}"} -scheme OverlaySnapshots-Package -destination "platform=iOS Simulator,id=$simulator" \
    -derivedDataPath "$scratch/Build" -parallel-testing-enabled NO -jobs 2 -quiet \
    -resultBundlePath "$output/snapshots.xcresult" || test_status=$?

if [[ -n "$candidates" && ( -z "${PV97_ONLY_TESTING:-}" || -f "$output/pixels.csv" ) ]]; then
    if [[ ! -f "$output/pixels.csv" ]]; then
        echo "Snapshot test did not emit pixels.csv" >&2
        if ((test_status == 0)); then test_status=1; fi
        exit "$test_status"
    fi
    npm install --prefix "$scratch" --no-audit --no-fund --silent pixelmatch@7.1.0 pngjs@7.0.0
    cat > "$scratch/compare.mjs" <<'JS'
import fs from 'node:fs';
import path from 'node:path';
import pixelmatch from 'pixelmatch';
import pngjs from 'pngjs';

const output = process.argv[2];
const report = fs.readFileSync(path.join(output, 'pixels.csv'), 'utf8').trimEnd().split('\n');
const rows = ['system,subtype,profile,pixels,pixelmatchChanged,pixelmatchPercent,within025Percent'];
const expected = report.length - 1;
let failures = 0;
for (const row of report.slice(1)) {
    const [system, subtype, profile, status] = row.split(',');
    if (status !== 'compared') continue;
    const prefix = path.join(output, system, subtype, profile);
    const legacyPath = prefix + '.legacy.png';
    const candidatePath = prefix + '.candidate.png';
    if (!fs.existsSync(legacyPath) || !fs.existsSync(candidatePath)) continue;
    const legacy = pngjs.PNG.sync.read(fs.readFileSync(legacyPath));
    const candidate = pngjs.PNG.sync.read(fs.readFileSync(candidatePath));
    if (legacy.width !== candidate.width || legacy.height !== candidate.height) {
        throw new Error('Image dimensions differ for ' + prefix);
    }
    const pixels = legacy.width * legacy.height;
    const changed = pixelmatch(legacy.data, candidate.data, null, legacy.width, legacy.height,
        { threshold: 0.1, includeAA: false });
    const percent = 100 * changed / pixels;
    const withinTolerance = percent <= 0.25;
    if (!withinTolerance) failures += 1;
    rows.push([system, subtype, profile, pixels, changed, percent, withinTolerance].join(','));
}
fs.writeFileSync(path.join(output, 'pixelmatch.csv'), rows.join('\n') + '\n');
const compared = rows.length - 1;
console.log(`Compared ${compared}/${expected} pairs. ${failures} exceeded 0.25%.`);
if (expected === 0 || compared !== expected || failures !== 0) process.exitCode = 1;
JS
    node "$scratch/compare.mjs" "$output"
fi
exit "$test_status"
