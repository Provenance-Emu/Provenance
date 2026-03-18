#!/bin/bash
# check-dylib-updates.sh — Check for newer RetroArch buildbot nightly snapshots.
#
# Usage:
#   ./check-dylib-updates.sh              # report only
#   ./check-dylib-updates.sh --update     # report and bump pin to latest date if newer
#   ./check-dylib-updates.sh --update 2026-04-01  # bump to a specific date
#
# Exit codes:
#   0  — pin is up-to-date (or no pin set)
#   1  — newer snapshot available (without --update)
#   2  — error (network failure, bad date, missing cores.yml)
#
# This script queries the buildbot by following the redirect from the
# canonical "latest" URL.  No special tooling required — just curl and sed.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
CORES_YML="${SCRIPTS_DIR}/cores.yml"

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
die() { echo "Error: $1" >&2; exit 2; }
warn() { echo "Warning: $1" >&2; }

# --------------------------------------------------------------------------
# Parse args
# --------------------------------------------------------------------------
DO_UPDATE=0
FORCED_DATE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --update)
            DO_UPDATE=1
            shift
            if [ $# -gt 0 ] && echo "$1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
                FORCED_DATE="$1"
                shift
            fi
            ;;
        -h|--help)
            head -20 "$0" | grep '^#' | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            die "Unknown argument: $1.  Use --help for usage."
            ;;
    esac
done

# --------------------------------------------------------------------------
# Read current pinned date from cores.yml
# --------------------------------------------------------------------------
[ -f "${CORES_YML}" ] || die "${CORES_YML} not found"

_PINNED_LINES=$(grep -v '^[[:space:]]*#' "${CORES_YML}" \
    | grep -E '^[[:space:]]*pinned_date:')
_PINNED_COUNT=$(printf '%s' "${_PINNED_LINES}" | grep -c . 2>/dev/null || echo 0)
if [ "${_PINNED_COUNT}" -gt 1 ] 2>/dev/null; then
    die "Multiple 'pinned_date:' entries found in ${CORES_YML}; ensure exactly one is set."
fi
PINNED_DATE=$(printf '%s\n' "${_PINNED_LINES}" \
    | head -1 \
    | sed 's/.*pinned_date:[[:space:]]*//' \
    | tr -d '"' | tr -d "'" | tr -d '[:space:]')

if [ -z "${PINNED_DATE}" ]; then
    echo "INFO: No pinned_date set in cores.yml — builds track 'latest' (non-reproducible)."
    echo "      Run update-dylib-pins.sh to lock to a specific date."
    exit 0
fi

if ! echo "${PINNED_DATE}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    die "pinned_date '${PINNED_DATE}' is not a valid YYYY-MM-DD date."
fi

echo "Current pin : ${PINNED_DATE}"

# --------------------------------------------------------------------------
# Query the buildbot for the latest snapshot date
# --------------------------------------------------------------------------
# The buildbot serves a redirect from /latest/ to the actual dated folder.
# We follow that redirect and extract the date from the Location header.
BUILDBOT_BASE="https://buildbot.libretro.com/nightly/apple/ios-arm64"

# Try curl with redirect follow; extract the final URL path component (the date).
LATEST_DATE=$(curl --silent --max-time 15 --location --write-out '%{url_effective}' \
    --output /dev/null "${BUILDBOT_BASE}/latest/" 2>/dev/null \
    | sed 's|.*/\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)/.*|\1|' \
    | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') || true

# Fallback: if redirect-based detection failed, try fetching the parent index
# and parsing the most recent dated directory link.
if [ -z "${LATEST_DATE}" ]; then
    warn "Redirect detection failed; trying directory index fallback..."
    LATEST_DATE=$(curl --silent --max-time 15 "${BUILDBOT_BASE}/" 2>/dev/null \
        | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' \
        | sort -r \
        | head -1) || true
fi

if [ -z "${LATEST_DATE}" ]; then
    warn "Could not determine latest buildbot date (network unavailable or buildbot layout changed)."
    warn "Current pin: ${PINNED_DATE}.  Visit ${BUILDBOT_BASE}/ manually."
    exit 2
fi

echo "Latest on buildbot: ${LATEST_DATE}"

# --------------------------------------------------------------------------
# If a forced date was given, apply it directly — skip the latest comparison.
# This ensures --update YYYY-MM-DD works even when pinned_date == latest.
# --------------------------------------------------------------------------
if [ "${DO_UPDATE}" = "1" ] && [ -n "${FORCED_DATE}" ]; then
    TARGET_DATE="${FORCED_DATE}"
    if [ "${PINNED_DATE}" = "${TARGET_DATE}" ]; then
        echo "✅ Pin is already at ${TARGET_DATE}; nothing to do."
        exit 0
    fi
    echo "Bumping pin from ${PINNED_DATE} to ${TARGET_DATE}..."
    "${SCRIPTS_DIR}/update-dylib-pins.sh" "${TARGET_DATE}"
    echo ""
    echo "Next steps:"
    echo "  git add CoresRetro/RetroArch/scripts/cores.yml"
    echo "  git commit -m 'build: pin RetroArch dylibs to ${TARGET_DATE}'"
    exit 0
fi

# --------------------------------------------------------------------------
# Compare dates against latest buildbot snapshot (lexicographic for YYYY-MM-DD)
# --------------------------------------------------------------------------
if [ "${PINNED_DATE}" = "${LATEST_DATE}" ]; then
    echo "✅ Pin is up-to-date."
    exit 0
elif [ "${PINNED_DATE}" > "${LATEST_DATE}" ]; then
    # This shouldn't happen in practice but handle gracefully.
    warn "Pinned date (${PINNED_DATE}) is newer than buildbot latest (${LATEST_DATE}) — unusual."
    exit 0
else
    # Pin is behind latest.
    echo "⚠️  Newer snapshot available: ${LATEST_DATE}  (currently pinned: ${PINNED_DATE})"
    if [ "${DO_UPDATE}" = "0" ]; then
        echo "   Run:  ./check-dylib-updates.sh --update"
        echo "   Or:   ./update-dylib-pins.sh ${LATEST_DATE}"
        exit 1
    fi

    # --update was passed (no forced date): bump to latest.
    echo "Bumping pin to ${LATEST_DATE}..."
    "${SCRIPTS_DIR}/update-dylib-pins.sh" "${LATEST_DATE}"
    echo ""
    echo "Next steps:"
    echo "  git add CoresRetro/RetroArch/scripts/cores.yml"
    echo "  git commit -m 'build: pin RetroArch dylibs to ${LATEST_DATE}'"
    exit 0
fi
