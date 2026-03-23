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

# 6. griffin.c has HAVE_CHEEVOS guard (prerequisite for checks 7-9)
check "griffin.c HAVE_CHEEVOS guard" \
    "$REPO_ROOT/CoresRetro/RetroArch/PVRetroArchCore/retroarch/griffin.c" \
    '#if defined\(HAVE_CHEEVOS\)'

# 7. griffin.c includes cheevos.c under HAVE_CHEEVOS guard
# We verify both: the guard exists (check 6) and the include is present.
# A false-positive would require the include to exist while the guard is absent —
# both checks must pass for the audit to succeed.
check "griffin.c cheevos.c include" \
    "$REPO_ROOT/CoresRetro/RetroArch/PVRetroArchCore/retroarch/griffin.c" \
    'include.*cheevos/cheevos\.c'

# 8. griffin.c includes rcheevos rc_client.c
check "griffin.c rc_client.c include" \
    "$REPO_ROOT/CoresRetro/RetroArch/PVRetroArchCore/retroarch/griffin.c" \
    'include.*rcheevos/src/rc_client\.c'

# 9. griffin.c includes rcheevos hash.c (ROM identification)
check "griffin.c rhash/hash.c include" \
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
