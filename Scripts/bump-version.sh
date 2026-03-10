#!/usr/bin/env bash
# bump-version.sh — Increment version and/or build number in Build.xcconfig
#
# Usage:
#   bump-version.sh                      # Increment build number by 1
#   bump-version.sh --build              # Same as above (explicit)
#   bump-version.sh --minor              # Bump minor: 3.3.1 → 3.4.0
#   bump-version.sh --major              # Bump major: 3.3.1 → 4.0.0
#   bump-version.sh --set-marketing X.Y.Z  # Set exact marketing version
#   bump-version.sh --set-build N        # Set exact build number
#   bump-version.sh --dry-run            # Show changes without writing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
XCCONFIG="$REPO_ROOT/Build.xcconfig"

# ── Parse arguments ───────────────────────────────────────────────────────────
BUMP_TYPE="build"  # default
SET_MARKETING=""
SET_BUILD=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build)        BUMP_TYPE="build" ;;
        --minor)        BUMP_TYPE="minor" ;;
        --major)        BUMP_TYPE="major" ;;
        --set-marketing) SET_MARKETING="$2"; shift ;;
        --set-build)    SET_BUILD="$2"; shift ;;
        --dry-run)      DRY_RUN=true ;;
        --help|-h)
            sed -n '2,12p' "$0" | sed 's/^# *//'
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

if [[ "$BUMP_TYPE" == "minor" && "$BUMP_TYPE" == "major" ]]; then
    echo "Error: cannot specify both --minor and --major" >&2
    exit 1
fi

# ── Read current values ───────────────────────────────────────────────────────
if [[ ! -f "$XCCONFIG" ]]; then
    echo "Error: Build.xcconfig not found at $XCCONFIG" >&2
    exit 1
fi

CURRENT_MARKETING=$(grep -E '^MARKETING_VERSION\s*=' "$XCCONFIG" | sed 's/.*=\s*//' | tr -d '[:space:]')
CURRENT_BUILD=$(grep -E '^CURRENT_PROJECT_VERSION\s*=' "$XCCONFIG" | sed 's/.*=\s*//' | tr -d '[:space:]')

if [[ -z "$CURRENT_MARKETING" ]]; then
    echo "Error: MARKETING_VERSION not found in $XCCONFIG" >&2
    exit 1
fi
if [[ -z "$CURRENT_BUILD" ]]; then
    echo "Error: CURRENT_PROJECT_VERSION not found in $XCCONFIG" >&2
    exit 1
fi

IFS='.' read -r MAJ_PART MIN_PART PAT_PART <<< "$CURRENT_MARKETING"
MAJ_PART="${MAJ_PART:-0}"
MIN_PART="${MIN_PART:-0}"
PAT_PART="${PAT_PART:-0}"

# ── Calculate new values ──────────────────────────────────────────────────────
NEW_BUILD="$CURRENT_BUILD"
NEW_MARKETING="$CURRENT_MARKETING"

if [[ -n "$SET_MARKETING" ]]; then
    NEW_MARKETING="$SET_MARKETING"
fi

if [[ -n "$SET_BUILD" ]]; then
    NEW_BUILD="$SET_BUILD"
elif [[ "$BUMP_TYPE" == "build" ]]; then
    NEW_BUILD=$(( CURRENT_BUILD + 1 ))
elif [[ "$BUMP_TYPE" == "minor" ]]; then
    NEW_BUILD=$(( CURRENT_BUILD + 1 ))
    NEW_MARKETING="${MAJ_PART}.$(( MIN_PART + 1 )).0"
elif [[ "$BUMP_TYPE" == "major" ]]; then
    NEW_BUILD=$(( CURRENT_BUILD + 1 ))
    NEW_MARKETING="$(( MAJ_PART + 1 )).0.0"
fi

# ── Show diff ─────────────────────────────────────────────────────────────────
echo "Version:  $CURRENT_MARKETING → $NEW_MARKETING"
echo "Build:    $CURRENT_BUILD → $NEW_BUILD"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "(dry-run — no files modified)"
    exit 0
fi

# ── Write changes (BSD sed compatible) ───────────────────────────────────────
sed -i '' "s/^MARKETING_VERSION\s*=.*/MARKETING_VERSION = $NEW_MARKETING/" "$XCCONFIG"
sed -i '' "s/^CURRENT_PROJECT_VERSION\s*=.*/CURRENT_PROJECT_VERSION = $NEW_BUILD/" "$XCCONFIG"

echo "Updated $XCCONFIG"

# Stage if inside a git repo
if git -C "$REPO_ROOT" rev-parse --git-dir &>/dev/null; then
    git -C "$REPO_ROOT" add "$XCCONFIG"
    echo "Staged Build.xcconfig"
fi
