#!/usr/bin/env bash
set -euo pipefail

# SPM Validate: Build and test all leaf SPM modules
# Usage: ./Scripts/audits/spm-validate.sh [module-name]
#
# If no module name is given, builds and tests all leaf modules.
# Leaf modules are those that can `swift build && swift test` on macOS
# without the full Xcode workspace.

# Leaf modules that support standalone SPM build. Mostly tier 0-2; the operative
# criterion is `swift build && swift test` on macOS without the Xcode workspace.
LEAF_MODULES=(
    "PVLogging"
    "PVPlists"
    "PVHashing"
    "PVSettings"
    "PVFeatureFlags"
    # Pulls third-party compression backends and ../Dependencies/{SWCompression,LzhArchive},
    # so CI initialises the SWCompression submodule before this script. Its tests could not
    # link until the stray `-Wl,-segalign,4000` was dropped from the lhasa target (swiftc has no `-Wl,`
    # passthrough) — see the note in Dependencies/LzhArchive/Package.swift.
    "PVArchiving"
    # Cross-app library sharing (iFly/iCube). Tier 4 by dependency, but Realm- and
    # UIKit-free on purpose so it builds and tests on the macOS host.
    "PVLibrarySharing"
)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_MODULE="${1:-}"

# NOTE: increment with `VAR=$((VAR + 1))`, never `((VAR++))`.
# Under `set -e` (line 2), `((VAR++))` is fatal the FIRST time it runs: post-increment
# evaluates to the OLD value, so with VAR=0 the arithmetic command's result is zero,
# which bash reports as exit status 1 — killing the script. This silently limited the
# script to the first module that passed, then exited 1 as if validation had failed.
PASSED=0
FAILED=0
SKIPPED=0
FAILURES=()

log() {
    echo "[spm-validate] $(date '+%H:%M:%S') $*"
}

build_and_test() {
    local module="$1"
    local module_dir="${ROOT_DIR}/${module}"

    if [[ ! -d "$module_dir" ]]; then
        log "SKIP: ${module} — directory not found"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    if [[ ! -f "${module_dir}/Package.swift" ]]; then
        log "SKIP: ${module} — no Package.swift"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    log "BUILD: ${module}..."
    if ! (cd "$module_dir" && swift build 2>&1 | tail -5); then
        log "FAIL: ${module} build failed"
        FAILURES+=("${module} (build)")
        FAILED=$((FAILED + 1))
        return 1
    fi

    log "TEST: ${module}..."
    # --no-parallel: several modules' tests share process-global state (notably
    # PVSettings, whose 223 tests all read/write UserDefaults.standard via Defaults).
    # Swift Testing runs suites concurrently by default, which made those flake
    # non-deterministically; `.serialized` only orders tests WITHIN a suite, not across
    # them. These suites run in ~0.04s, so serial execution costs nothing.
    # Some modules may not have tests yet — that's OK
    local test_log
    test_log="$(mktemp -t "spm-validate-${module}")"
    if (cd "$module_dir" && swift test --no-parallel >"$test_log" 2>&1); then
        tail -10 "$test_log"
        log "PASS: ${module}"
        PASSED=$((PASSED + 1))
    else
        tail -10 "$test_log"
        # Check if failure is due to no tests vs actual test failure
        if grep -q "no tests found" "$test_log"; then
            log "PASS: ${module} (no tests, build OK)"
            PASSED=$((PASSED + 1))
        else
            # The tail above only shows the totals; name the failing tests.
            grep -E ": error: |error: -\[|Test Case .* failed|✘ Test" "$test_log" | head -40 || true
            log "FAIL: ${module} tests failed"
            FAILURES+=("${module} (test)")
            FAILED=$((FAILED + 1))
        fi
    fi
    rm -f "$test_log"
}

# Main
log "Starting SPM validation in ${ROOT_DIR}"
echo ""

if [[ -n "$TARGET_MODULE" ]]; then
    # Validate a specific module
    build_and_test "$TARGET_MODULE"
else
    # Validate all leaf modules
    for module in "${LEAF_MODULES[@]}"; do
        build_and_test "$module"
        echo ""
    done
fi

# Summary
echo "========================================"
log "Results: ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
    log "Failures:"
    for f in "${FAILURES[@]}"; do
        echo "  - ${f}"
    done
    exit 1
fi

log "All modules validated successfully!"
exit 0
