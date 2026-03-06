#!/usr/bin/env bash
# capture-gameplay-screenshots.sh
#
# Developer script to capture gameplay screenshots for App Store submission.
# Run this locally on a Mac with a real device or simulator that supports Metal.
#
# IMPORTANT: GitHub Actions runners do NOT support Metal/GPU.
# See: https://github.com/actions/runner-images/issues/7085
# This script is intended for local developer use or self-hosted Metal-capable runners.
#
# Usage:
#   ./scripts/capture-gameplay-screenshots.sh [options]
#
# Options:
#   -d, --device <name>     Simulator name or device UDID (default: "iPhone 16 Pro")
#   -o, --output <dir>      Output directory (default: fastlane/screenshots/gameplay)
#   -h, --help              Show this help message
#
# Prerequisites:
#   - Xcode 16.2 installed at /Applications/Xcode_16.2.app
#   - xcrun simctl (for simulators)
#   - idb (for physical devices, optional): brew install idb-companion
#
# Example:
#   ./scripts/capture-gameplay-screenshots.sh --device "iPhone 16 Pro"
#   ./scripts/capture-gameplay-screenshots.sh --device <udid>  # physical device

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
DEVICE_NAME="iPhone 16 Pro"
OUTPUT_DIR="fastlane/screenshots/gameplay"
DEVELOPER_DIR="/Applications/Xcode_16.2.app/Contents/Developer"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device)   DEVICE_NAME="$2"; shift 2 ;;
    -o|--output)   OUTPUT_DIR="$2";  shift 2 ;;
    -h|--help)
      sed -n '4,30p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

export DEVELOPER_DIR

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "[capture-gameplay] $*"; }
die() { echo "[capture-gameplay] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "'$1' is not installed. $2"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
require_cmd xcrun "Install Xcode command-line tools."
require_cmd xcpretty "Install xcpretty: gem install xcpretty" 2>/dev/null || true

mkdir -p "$OUTPUT_DIR"
log "Output directory: $OUTPUT_DIR"

# ── Determine if target is a simulator or physical device ─────────────────────
# Match both classic uppercase UDIDs (XXXXXXXX-XXXX-...) and modern lowercase/mixed hex UDIDs.
SIMULATOR_UDID=""
if [[ "$DEVICE_NAME" =~ ^[0-9A-Fa-f-]+$ ]]; then
  log "Using physical device UDID: $DEVICE_NAME"
  DESTINATION="id=$DEVICE_NAME"
else
  log "Looking up simulator: $DEVICE_NAME"
  # Pass DEVICE_NAME as an argument rather than interpolating it into the Python
  # source string, to prevent code injection via crafted device names.
  SIMULATOR_UDID=$(xcrun simctl list devices available --json \
    | python3 -c '
import json, sys
device_name = sys.argv[1]
data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    for d in devices:
        if d.get("name") == device_name and d.get("isAvailable"):
            print(d["udid"])
            sys.exit(0)
sys.exit(1)
' "$DEVICE_NAME" 2>/dev/null) || die "Simulator '$DEVICE_NAME' not found. Run 'xcrun simctl list devices' to see available simulators."

  log "Booting simulator $DEVICE_NAME ($SIMULATOR_UDID)"
  xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
  DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
fi

# ── Build app for screenshots ─────────────────────────────────────────────────
log "Building UITesting scheme..."
BUILD_DIR="$(mktemp -d)/build"

set +e
xcodebuild build-for-testing \
  -workspace Provenance.xcworkspace \
  -scheme UITesting \
  -destination "$DESTINATION" \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  SCREENSHOT_MODE=1 \
  2>&1 | tee /tmp/xcodebuild-screenshot.log | xcpretty 2>/dev/null
BUILD_EXIT=${PIPESTATUS[0]}
set -e

if [[ $BUILD_EXIT -ne 0 ]]; then
  die "Build failed. See /tmp/xcodebuild-screenshot.log for details."
fi

# ── Run screenshot tests ───────────────────────────────────────────────────────
log "Running ScreenshotUITests..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="$OUTPUT_DIR/results_$TIMESTAMP.xcresult"

set +e
xcodebuild test-without-building \
  -workspace Provenance.xcworkspace \
  -scheme UITesting \
  -destination "$DESTINATION" \
  -derivedDataPath "$BUILD_DIR" \
  -resultBundlePath "$RESULTS_DIR" \
  -only-testing UITestingUITests/ScreenshotUITests \
  CODE_SIGNING_ALLOWED=NO \
  SCREENSHOT_MODE=1 \
  2>&1 | xcpretty 2>/dev/null
TEST_EXIT=${PIPESTATUS[0]}
set -e

if [[ $TEST_EXIT -ne 0 ]]; then
  log "WARNING: ScreenshotUITests failed (exit code $TEST_EXIT). Screenshots may be missing or incomplete."
fi

# ── Extract attachments from .xcresult ────────────────────────────────────────
log "Extracting screenshots from $RESULTS_DIR..."
ATTACHMENT_DIR="$OUTPUT_DIR/$TIMESTAMP"
mkdir -p "$ATTACHMENT_DIR"

# The Python script fetches xcresult data itself; no need to pipe xcresulttool output here.
python3 - "$RESULTS_DIR" "$ATTACHMENT_DIR" <<'PYEOF'
import json, sys, subprocess, os

results_path = sys.argv[1]
output_dir   = sys.argv[2]

raw = subprocess.run(
    ["xcrun", "xcresulttool", "get", "--path", results_path, "--format", "json"],
    capture_output=True, text=True
)
data = json.loads(raw.stdout)

def walk(node, depth=0):
    if isinstance(node, dict):
        if node.get("_type", {}).get("_name") == "ActionTestAttachment":
            name     = node.get("name", {}).get("_value", "screenshot")
            ref      = node.get("payloadRef", {}).get("id", {}).get("_value", "")
            filename = node.get("filename", {}).get("_value", f"{name}.png")
            if ref:
                dest = os.path.join(output_dir, filename)
                subprocess.run(
                    ["xcrun", "xcresulttool", "export", "--path", results_path,
                     "--id", ref, "--output-path", dest, "--type", "file"],
                    check=False
                )
                print(f"  Saved: {filename}")
        for v in node.values():
            walk(v, depth + 1)
    elif isinstance(node, list):
        for item in node:
            walk(item, depth + 1)

walk(data)
PYEOF

# ── Shutdown simulator if we booted it ───────────────────────────────────────
if [[ -n "$SIMULATOR_UDID" ]]; then
  log "Shutting down simulator $SIMULATOR_UDID"
  xcrun simctl shutdown "$SIMULATOR_UDID" 2>/dev/null || true
fi

log "Done! Screenshots saved to: $ATTACHMENT_DIR"
