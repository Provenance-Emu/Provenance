#!/bin/bash
# Builds a Tuist focused app for the iOS Simulator, installs it on the booted simulator, runs
# the dev harness against a ROM and copies its outputs to build/harness/<Scheme>/.
# ROMs: Scripts/dev/make_harness_rom.py <out.a26|out.gba> writes a synthetic loop ROM (GBA runs on
# mGBA: core com.provenance.core.mGBA; 2600 on Stella: com.provenance.core.stella).
# Usage: Scripts/dev/run_harness.sh <rom path> [ui|azahar] [frames] [core identifier]
# Exit: 0 success, 1 harness error (error.txt) or missing outputs, 2 usage/setup error.
# Provenance-Dev-Thin is device-only: buildbot libretro dylibs are iOS-platform binaries and
# cannot be dlopen'ed in a simulator process.
# SIM_DEVICE (default "booted") picks the simulator when several are booted.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROM="${1:-}"
TARGET="${2:-ui}"
FRAMES="${3:-300}"
CORE="${4:-}"
SIM="${SIM_DEVICE:-booted}"
[ -n "$ROM" ] && [ -f "$ROM" ] || { echo "usage: $0 <rom path> [ui|azahar] [frames] [core id]" >&2; exit 2; }

case "$TARGET" in
    ui) SCHEME="Provenance-Dev-UI" ;;
    azahar) SCHEME="Provenance-Dev-Azahar" ;;
    thin) echo "run_harness: Provenance-Dev-Thin runs the harness on a device only (libretro dylibs can't load in the simulator)" >&2; exit 2 ;;
    *) echo "run_harness: unknown target '$TARGET' (ui|azahar)" >&2; exit 2 ;;
esac

xcrun simctl list devices booted | grep -q Booted || { echo "run_harness: boot a simulator first (xcrun simctl boot \"iPhone 17\")" >&2; exit 2; }

DERIVED="${DEV_DERIVED:-$ROOT/build/dev-dd}"
(cd "$ROOT" && mise exec -- tuist generate --no-open)
# Ad-hoc signing for simulator SDKs comes from Dev/Config/Dev.xcconfig.
xcodebuild build -workspace "$ROOT/Provenance-Dev.xcworkspace" -scheme "$SCHEME" \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" \
    -skipPackagePluginValidation -skipMacroValidation 2>&1 | tail -3

APP="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
[ -d "$APP" ] || { echo "run_harness: build produced no $APP" >&2; exit 2; }
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
xcrun simctl install "$SIM" "$APP"

OUT_REL="Documents/Harness/run"
DATA=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)
rm -rf "${DATA:?}/$OUT_REL"
ROM_ABS="$(cd "$(dirname "$ROM")" && pwd)/$(basename "$ROM")"
ARGS=(-PVHarnessROM "$ROM_ABS" -PVHarnessFrames "$FRAMES" -PVHarnessOut "$OUT_REL")
[ -n "$CORE" ] && ARGS+=(-PVHarnessCore "$CORE")

# --console-pty blocks until the app exits; the harness calls exit() when it is done.
xcrun simctl launch --console-pty --terminate-running-process "$SIM" "$BUNDLE" "${ARGS[@]}" || true

DEST="$ROOT/build/harness/$SCHEME"
rm -rf "$DEST" && mkdir -p "$DEST"
cp -R "$DATA/$OUT_REL/." "$DEST/" 2>/dev/null || true
ls -1 "$DEST"
if [ -f "$DEST/error.txt" ]; then
    echo "run_harness: harness error: $(cat "$DEST/error.txt")"
    exit 1
fi
for f in frames.json screenshot.png log.txt; do
    [ -f "$DEST/$f" ] || { echo "run_harness: missing $f" >&2; exit 1; }
done
cat "$DEST/frames.json"
