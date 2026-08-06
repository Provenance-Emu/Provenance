#!/usr/bin/env bash
set -euo pipefail

# SPM Validate: Build and test all leaf SPM modules
# Usage: ./Scripts/spm-validate.sh [module-name]
#
# If no module name is given, builds and tests all leaf modules.
# Leaf modules are those that can `swift build && swift test` on macOS
# without the full Xcode workspace.

# Tier 0-2 leaf modules that support standalone SPM build
LEAF_MODULES=(
    "PVLogging"
    "PVPlists"
    "PVHashing"
    "PVSettings"
    "PVFeatureFlags"
)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
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
    if (cd "$module_dir" && swift test --no-parallel 2>&1 | tail -10); then
        log "PASS: ${module}"
        PASSED=$((PASSED + 1))
    else
        # Check if failure is due to no tests vs actual test failure
        if (cd "$module_dir" && swift test --no-parallel 2>&1 | grep -q "no tests found"); then
            log "PASS: ${module} (no tests, build OK)"
            PASSED=$((PASSED + 1))
        else
            log "FAIL: ${module} tests failed"
            FAILURES+=("${module} (test)")
            FAILED=$((FAILED + 1))
        fi
    fi
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
