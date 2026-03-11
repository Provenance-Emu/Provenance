#!/usr/bin/env bash
# generate_cheatdb_if_needed.sh
#
# Generates the libretro_cheats.sqlite.zip database if it doesn't exist.
# Used as a pre-build / pre-test step so PVLookup tests can run on CI
# (including Linux runners) without committing the ~MB database to git.
#
# Usage:
#   ./PVLookup/Scripts/generate_cheatdb_if_needed.sh
#
# Requires: python3, git

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESOURCE_DIR="$REPO_ROOT/PVLookup/Sources/LibretroCheatDB/Resources"
ZIP_FILE="$RESOURCE_DIR/libretro_cheats.sqlite.zip"
GENERATOR="$REPO_ROOT/Scripts/generate_cheatdb.py"

if [ -f "$ZIP_FILE" ] && [ "$(stat -c%s "$ZIP_FILE" 2>/dev/null || stat -f%z "$ZIP_FILE" 2>/dev/null)" -gt 1000 ]; then
    echo "libretro_cheats.sqlite.zip exists and appears valid, skipping generation."
    exit 0
fi

echo "libretro_cheats.sqlite.zip is missing or empty — generating..."

if ! command -v python3 &>/dev/null; then
    echo "Error: python3 is required but not found" >&2
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Cloning libretro-database (shallow)..."
git clone --depth=1 --quiet https://github.com/libretro/libretro-database.git "$TMPDIR/libretro-database"

echo "Running generate_cheatdb.py..."
python3 "$GENERATOR" "$TMPDIR/libretro-database/cht/" \
    --dat-dir "$TMPDIR/libretro-database" \
    --output "$RESOURCE_DIR/libretro_cheats.sqlite"

echo "Done — $(du -h "$ZIP_FILE" | cut -f1) generated."
