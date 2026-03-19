#!/bin/bash
# run_tests.sh — Run all RetroArch script tests
#
# Usage: bash CoresRetro/RetroArch/scripts/tests/run_tests.sh
#    or: cd CoresRetro/RetroArch/scripts && bash tests/run_tests.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔══════════════════════════════════════════════════╗"
echo "║   RetroArch Script Test Suite                   ║"
echo "╚══════════════════════════════════════════════════╝"

OVERALL_PASS=0

run_suite() {
    local suite="$1"
    echo ""
    echo "Running: ${suite}"
    echo "──────────────────────────────────────────────────"
    if bash "${SCRIPT_DIR}/${suite}"; then
        echo "Suite PASSED: ${suite}"
    else
        echo "Suite FAILED: ${suite}"
        OVERALL_PASS=1
    fi
}

run_suite "test_get_modules.sh"
run_suite "test_make_frameworks.sh"

echo ""
if [ "${OVERALL_PASS}" -eq 0 ]; then
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  ✅ ALL SUITES PASSED                           ║"
    echo "╚══════════════════════════════════════════════════╝"
    exit 0
else
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  ❌ ONE OR MORE SUITES FAILED                   ║"
    echo "╚══════════════════════════════════════════════════╝"
    exit 1
fi
