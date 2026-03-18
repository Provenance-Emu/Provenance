#!/bin/bash
# update-dylib-pins.sh — Update the pinned buildbot date in cores.yml.
#
# Usage:
#   ./update-dylib-pins.sh            # pin to today's date
#   ./update-dylib-pins.sh 2026-03-01 # pin to a specific date
#
# After running this script, commit the updated cores.yml to lock all
# developers and CI to the same buildbot nightly snapshot.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
CORES_YML="${SCRIPTS_DIR}/cores.yml"

if [ ! -f "${CORES_YML}" ]; then
    echo "Error: ${CORES_YML} not found" >&2
    exit 1
fi

if [ $# -ge 1 ]; then
    NEW_DATE="$1"
else
    NEW_DATE=$(date -u '+%Y-%m-%d')
fi

# Validate YYYY-MM-DD format
if ! echo "${NEW_DATE}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    echo "Error: date must be in YYYY-MM-DD format, got: ${NEW_DATE}" >&2
    exit 1
fi

# Replace the pinned_date value in cores.yml
sed -i.bak "s|pinned_date:.*|pinned_date: \"${NEW_DATE}\"|" "${CORES_YML}"
rm -f "${CORES_YML}.bak"

echo "Updated pinned_date to ${NEW_DATE} in cores.yml"
echo "Run: git add CoresRetro/RetroArch/scripts/cores.yml && git commit -m 'build: pin RetroArch dylibs to ${NEW_DATE}'"
