#!/usr/bin/env bash
# generate_package_sources.sh
#
# Scans the picodrive submodule (Sources/libpicodrive/picodrive) and outputs
# Swift source arrays for use in Package.swift. Run this after bumping the
# submodule to detect added/removed .c files. Upstream's authoritative core
# list is SRCS_COMMON in picodrive/platform/common/common.mak plus the
# PLATFORM=libretro block of picodrive/Makefile; cross-check against those.
#
# Usage:
#   cd Cores/PicoDrive
#   bash generate_package_sources.sh
#
# The output can be copy-pasted into the `sources` array in Package.swift
# for the `libpicodrive` target.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/Sources/libpicodrive"
LIBPICO_DIR="$TARGET_DIR/picodrive"

if [ ! -d "$LIBPICO_DIR" ]; then
    echo "ERROR: picodrive submodule not found at $LIBPICO_DIR (git submodule update --init --recursive)" >&2
    exit 1
fi

echo "# Scanning: $LIBPICO_DIR"
echo ""

# Helper: print .c files relative to TARGET_DIR for a given subdir
find_sources() {
    local subdir="$1"
    local maxdepth="${2:-1}"
    local dir="$LIBPICO_DIR/$subdir"
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth "$maxdepth" -name "*.c" \
            -not -name "*_arm*" -not -name "*_amips*" | \
            sort | \
            sed "s|$TARGET_DIR/||" | \
            awk '{ printf "                    \"%s\",\n", $0 }'
    fi
}

echo "// ---- cpu (selected files used by libpicodrive target) ----"
for f in cpu/cz80/cz80.c cpu/drc/cmn.c cpu/fame/famec.c cpu/sh2/mame/sh2pico.c cpu/sh2/sh2.c; do
    if [ -f "$LIBPICO_DIR/$f" ]; then
        printf "                    \"picodrive/%s\",\n" "$f"
    else
        echo "  # WARNING: $f NOT FOUND" >&2
    fi
done
echo ""

echo "// ---- pico/32x ----"
find_sources "pico/32x"
echo ""

echo "// ---- pico top-level .c files ----"
find "$LIBPICO_DIR/pico" -maxdepth 1 -name "*.c" | sort | \
    sed "s|$TARGET_DIR/||" | \
    awk '{ printf "                    \"%s\",\n", $0 }'
echo ""

echo "// ---- pico/carthw ----"
find_sources "pico/carthw"
echo ""

echo "// ---- pico/carthw/svp ----"
find_sources "pico/carthw/svp"
echo ""

echo "// ---- pico/cd ----"
find_sources "pico/cd"
echo ""

echo "// ---- pico/pico ----"
find_sources "pico/pico"
echo ""

echo "// ---- pico/sound ----"
find_sources "pico/sound"
echo ""

echo "// ---- platform/common (mp3 files only) ----"
find "$LIBPICO_DIR/platform/common" -maxdepth 1 -name "mp3*.c" | sort | \
    sed "s|$TARGET_DIR/||" | \
    awk '{ printf "                    \"%s\",\n", $0 }'
echo ""

echo "// ---- platform/libretro/libretro.c ----"
printf "                    \"picodrive/platform/libretro/libretro.c\",\n"
echo ""

echo "// ---- platform/libretro/libretro-common (all .c) ----"
find "$LIBPICO_DIR/platform/libretro/libretro-common" -name "*.c" | sort | \
    sed "s|$TARGET_DIR/||" | \
    awk '{ printf "                    \"%s\",\n", $0 }'
