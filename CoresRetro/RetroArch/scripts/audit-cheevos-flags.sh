#!/usr/bin/env bash
# audit-cheevos-flags.sh — Verify HAVE_CHEEVOS is defined in all build configurations.
#
# Usage: ./CoresRetro/RetroArch/scripts/audit-cheevos-flags.sh [REPO_ROOT]
#
# Exit codes:
#   0 — HAVE_CHEEVOS is present in all expected locations
#   1 — One or more locations are missing HAVE_CHEEVOS
#
# Part of issue #3386 — LibRetro cheevos audit

# Re-exec with bash if invoked under /bin/sh (e.g. from an Xcode build phase).
# This script uses bash-only features (local variables, etc.) and must run under bash.
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PASS=0
FAIL=0

check() {
    local description="$1"
    local file="$2"
    local pattern="$3"

    if [ ! -f "$file" ]; then
        echo "MISSING  [$description] file not found: $file"
        FAIL=$((FAIL + 1))
        return
    fi

    if grep -qE "$pattern" "$file"; then
        echo "OK       [$description] $file"
        PASS=$((PASS + 1))
    else
        echo "MISSING  [$description] pattern '$pattern' not found in $file"
        FAIL=$((FAIL + 1))
    fi
}

# check_in_cheevos_block — like check(), but verifies the pattern appears inside
# the `#if defined(HAVE_CHEEVOS) ... #endif` block rather than anywhere in the file.
# This prevents false positives if an include moves outside the guard.
check_in_cheevos_block() {
    local description="$1"
    local file="$2"
    local pattern="$3"

    if [ ! -f "$file" ]; then
        echo "MISSING  [$description] file not found: $file"
        FAIL=$((FAIL + 1))
        return
    fi

    # awk: enter block on `#if defined(HAVE_CHEEVOS)`, track nested #if depth so we
    # only exit when we see the matching #endif for the HAVE_CHEEVOS guard.
    # Nested #if/#ifdef/#ifndef directives inside the block increment depth;
    # #endif decrements depth (or closes the guard when depth reaches 0).
    # found=1 if pattern matches while in the HAVE_CHEEVOS block.
    if awk -v pat="$pattern" '
        /^[[:space:]]*#if[[:space:]]+defined\(HAVE_CHEEVOS\)/ { in_block=1; depth=0; next }
        in_block && /^[[:space:]]*#if(n?def)?\b/ { depth++; next }
        in_block && /^[[:space:]]*#endif\b/ {
            if (depth > 0) {
                depth--
            } else {
                in_block=0
            }
            next
        }
        in_block && $0 ~ pat { found=1 }
        END { exit (found ? 0 : 1) }
    ' "$file"; then
        echo "OK       [$description] $file"
        PASS=$((PASS + 1))
    else
        echo "MISSING  [$description] '$pattern' not found inside #if defined(HAVE_CHEEVOS) block in $file"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== HAVE_CHEEVOS Audit ==="
echo "Repo root: $REPO_ROOT"
echo ""

# 1. Global Xcode build settings
check "Global xcconfig" \
    "$REPO_ROOT/Build.xcconfig" \
    '^[[:space:]]*GCC_PREPROCESSOR_DEFINITIONS[[:space:]]*=.*HAVE_CHEEVOS'

# 2. RetroArch core C flags (release)
check "BuildFlags OTHER_CFLAGS" \
    "$REPO_ROOT/CoresRetro/RetroArch/BuildFlags.xcconfig" \
    '^[[:space:]]*OTHER_CFLAGS[[:space:]]*=.*HAVE_CHEEVOS'

# 3. RetroArch core C flags (debug)
check "BuildFlags OTHER_DEBUG_CFLAGS" \
    "$REPO_ROOT/CoresRetro/RetroArch/BuildFlags.xcconfig" \
    '^[[:space:]]*OTHER_DEBUG_CFLAGS[[:space:]]*=.*HAVE_CHEEVOS'

# 4. SPM Package.swift debug configuration
check "CoresRetro Package.swift (debug)" \
    "$REPO_ROOT/CoresRetro/Package.swift" \
    'define\("HAVE_CHEEVOS".*debug\)'

# 5. SPM Package.swift release configuration
check "CoresRetro Package.swift (release)" \
    "$REPO_ROOT/CoresRetro/Package.swift" \
    'define\("HAVE_CHEEVOS".*release\)'

# 6. griffin.c has HAVE_CHEEVOS guard
check "griffin.c HAVE_CHEEVOS guard" \
    "$REPO_ROOT/CoresRetro/RetroArch/PVRetroArchCore/retroarch/griffin.c" \
    '#if defined\(HAVE_CHEEVOS\)'

# 7–9. Verify key cheevos includes appear *inside* the #if defined(HAVE_CHEEVOS) block.
# check_in_cheevos_block uses awk to scope the search to the guarded region,
# preventing false positives from includes that have moved outside the guard.
check_in_cheevos_block "griffin.c cheevos.c include" \
    "$REPO_ROOT/CoresRetro/RetroArch/PVRetroArchCore/retroarch/griffin.c" \
    'include.*cheevos/cheevos\.c'

check_in_cheevos_block "griffin.c rc_client.c include" \
    "$REPO_ROOT/CoresRetro/RetroArch/PVRetroArchCore/retroarch/griffin.c" \
    'include.*rcheevos/src/rc_client\.c'

check_in_cheevos_block "griffin.c rhash/hash.c include" \
    "$REPO_ROOT/CoresRetro/RetroArch/PVRetroArchCore/retroarch/griffin.c" \
    'include.*rhash/hash\.c'

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "ACTION REQUIRED: $FAIL check(s) failed. HAVE_CHEEVOS may not be active in all builds."
    exit 1
else
    echo "All checks passed. HAVE_CHEEVOS is correctly defined for all build variants."
    exit 0
fi
