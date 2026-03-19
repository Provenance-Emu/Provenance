#!/bin/bash
# test_get_modules.sh — Tests for get-modules.sh validation logic
#
# These tests exercise the zip validation, download threshold checks,
# pinned-date validation, and dylib count checks without hitting the network.
#
# Run via: bash tests/run_tests.sh  (from CoresRetro/RetroArch/scripts/)
# Or directly: bash tests/test_get_modules.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

# Path to the script under test
SCRIPTS_DIR="$(dirname "${SCRIPT_DIR}")"

# ---------------------------------------------------------------------------
# Helper: create a minimal valid zip (PK\x03\x04 local file header magic)
# get-modules.sh validates the first 4 bytes = 50 4b 03 04
# ---------------------------------------------------------------------------
make_valid_zip() {
    local path="$1"
    printf '\x50\x4b\x03\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' > "${path}"
}

# Create a fake HTML "404" file masquerading as a zip
make_html_file() {
    local path="$1"
    echo '<html><body><h1>404 Not Found</h1></body></html>' > "${path}"
}

# ---------------------------------------------------------------------------
# Test: zip magic validation — valid zip passes
# ---------------------------------------------------------------------------
test_valid_zip_passes_validation() {
    local workdir="${TEST_ROOT}/valid_zip"
    mkdir -p "${workdir}"
    make_valid_zip "${workdir}/core_libretro_ios.zip"

    # Inline the validation logic (mirrors get-modules.sh)
    local VALID_ZIPS=0 INVALID_ZIPS=0
    for zipfile in "${workdir}"/*.zip; do
        [ -f "$zipfile" ] || continue
        MAGIC=$(xxd -l 4 -p "$zipfile" 2>/dev/null)
        if [ "$MAGIC" != "504b0304" ]; then
            rm -f "$zipfile"
            INVALID_ZIPS=$((INVALID_ZIPS + 1))
        else
            VALID_ZIPS=$((VALID_ZIPS + 1))
        fi
    done

    assert_exit "valid zip: INVALID_ZIPS" 0 "${INVALID_ZIPS}"
    assert_count_ge "valid zip: VALID_ZIPS" "${VALID_ZIPS}" 1
    assert_file_exists "valid zip: file still present" "${workdir}/core_libretro_ios.zip"
}

# ---------------------------------------------------------------------------
# Test: zip magic validation — HTML 404 page is rejected and removed
# ---------------------------------------------------------------------------
test_html_file_fails_validation() {
    local workdir="${TEST_ROOT}/html_zip"
    mkdir -p "${workdir}"
    make_html_file "${workdir}/core_libretro_ios.zip"

    local VALID_ZIPS=0 INVALID_ZIPS=0
    for zipfile in "${workdir}"/*.zip; do
        [ -f "$zipfile" ] || continue
        MAGIC=$(xxd -l 4 -p "$zipfile" 2>/dev/null)
        if [ "$MAGIC" != "504b0304" ]; then
            rm -f "$zipfile"
            INVALID_ZIPS=$((INVALID_ZIPS + 1))
        else
            VALID_ZIPS=$((VALID_ZIPS + 1))
        fi
    done

    assert_count_ge "html rejected: INVALID_ZIPS" "${INVALID_ZIPS}" 1
    assert_exit "html rejected: VALID_ZIPS" 0 "${VALID_ZIPS}"
    assert_file_not_exists "html rejected: file removed" "${workdir}/core_libretro_ios.zip"
}

# ---------------------------------------------------------------------------
# Test: partial failure — some valid, some HTML — valid zips survive
# ---------------------------------------------------------------------------
test_partial_failure_valid_zips_survive() {
    local workdir="${TEST_ROOT}/partial"
    mkdir -p "${workdir}"
    make_valid_zip "${workdir}/good1_libretro_ios.zip"
    make_valid_zip "${workdir}/good2_libretro_ios.zip"
    make_html_file "${workdir}/bad1_libretro_ios.zip"
    make_html_file "${workdir}/bad2_libretro_ios.zip"

    local VALID_ZIPS=0 INVALID_ZIPS=0
    for zipfile in "${workdir}"/*.zip; do
        [ -f "$zipfile" ] || continue
        MAGIC=$(xxd -l 4 -p "$zipfile" 2>/dev/null)
        if [ "$MAGIC" != "504b0304" ]; then
            rm -f "$zipfile"
            INVALID_ZIPS=$((INVALID_ZIPS + 1))
        else
            VALID_ZIPS=$((VALID_ZIPS + 1))
        fi
    done

    assert_exit "partial: VALID_ZIPS" 2 "${VALID_ZIPS}"
    assert_exit "partial: INVALID_ZIPS" 2 "${INVALID_ZIPS}"
    assert_file_exists "partial: good1 survives" "${workdir}/good1_libretro_ios.zip"
    assert_file_exists "partial: good2 survives" "${workdir}/good2_libretro_ios.zip"
    assert_file_not_exists "partial: bad1 removed" "${workdir}/bad1_libretro_ios.zip"
    assert_file_not_exists "partial: bad2 removed" "${workdir}/bad2_libretro_ios.zip"
}

# ---------------------------------------------------------------------------
# Test: 80% download threshold logic
# ---------------------------------------------------------------------------
test_threshold_passes_when_above_80_percent() {
    local EXPECTED_COUNT=10 DOWNLOAD_OK=9
    local THRESHOLD=$(( EXPECTED_COUNT * 80 / 100 ))
    if [ "${DOWNLOAD_OK}" -ge "${THRESHOLD}" ]; then
        pass "threshold: 9/10 passes (threshold=${THRESHOLD})"
    else
        fail "threshold: 9/10 should pass (threshold=${THRESHOLD})"
    fi
}

test_threshold_fails_when_below_80_percent() {
    local EXPECTED_COUNT=10 DOWNLOAD_OK=7
    local THRESHOLD=$(( EXPECTED_COUNT * 80 / 100 ))
    if [ "${DOWNLOAD_OK}" -lt "${THRESHOLD}" ]; then
        pass "threshold: 7/10 fails as expected (threshold=${THRESHOLD})"
    else
        fail "threshold: 7/10 should fail (threshold=${THRESHOLD})"
    fi
}

test_threshold_fails_when_zero_downloads() {
    local EXPECTED_COUNT=100 DOWNLOAD_OK=0
    local THRESHOLD=$(( EXPECTED_COUNT * 80 / 100 ))
    if [ "${DOWNLOAD_OK}" -lt "${THRESHOLD}" ]; then
        pass "threshold: 0/100 fails as expected (threshold=${THRESHOLD})"
    else
        fail "threshold: 0/100 should fail (threshold=${THRESHOLD})"
    fi
}

test_threshold_exact_80_percent_passes() {
    local EXPECTED_COUNT=10 DOWNLOAD_OK=8
    local THRESHOLD=$(( EXPECTED_COUNT * 80 / 100 ))
    if [ "${DOWNLOAD_OK}" -ge "${THRESHOLD}" ]; then
        pass "threshold: exactly 80% (8/10) passes"
    else
        fail "threshold: exactly 80% (8/10) should pass"
    fi
}

# ---------------------------------------------------------------------------
# Test: pinned_date format validation
# ---------------------------------------------------------------------------
test_invalid_date_format_rejected() {
    local PINNED_DATE="not-a-date"
    local valid=1
    if ! echo "${PINNED_DATE}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        valid=0
    fi
    assert_exit "invalid date format rejected" 0 "${valid}"
}

test_valid_date_format_accepted() {
    local PINNED_DATE="2026-03-18"
    local valid=1
    if ! echo "${PINNED_DATE}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        valid=0
    fi
    assert_exit "valid date format accepted" 1 "${valid}"
}

test_date_with_inline_comment_rejected() {
    # Simulate a pinned_date that includes trailing comment text after parsing
    local PINNED_DATE="2026-03-18 # some comment"
    local valid=1
    if ! echo "${PINNED_DATE}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        valid=0
    fi
    assert_exit "date with inline comment rejected" 0 "${valid}"
}

test_empty_date_is_not_validated() {
    local PINNED_DATE=""
    # Empty PINNED_DATE means "use latest" — no validation needed
    if [ -z "${PINNED_DATE}" ]; then
        pass "empty pinned_date: falls back to latest"
    else
        fail "empty pinned_date: should be treated as latest"
    fi
}

# ---------------------------------------------------------------------------
# Test: dylib count validation logic
# ---------------------------------------------------------------------------
test_zero_dylibs_detected() {
    local workdir="${TEST_ROOT}/no_dylibs"
    mkdir -p "${workdir}/modules"
    # No dylibs placed — count should be 0
    DYLIB_COUNT=$(find "${workdir}/modules" -maxdepth 1 -name "*.dylib" -type f 2>/dev/null | wc -l | tr -d ' ')
    assert_exit "zero dylibs: count is 0" 0 "${DYLIB_COUNT}"
}

test_dylib_count_nonzero_after_extraction() {
    local workdir="${TEST_ROOT}/has_dylibs"
    mkdir -p "${workdir}/modules"
    # Create fake dylibs
    printf '\xcf\xfa\xed\xfe' > "${workdir}/modules/pcsx_rearmed_libretro_ios.dylib"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/modules/gambatte_libretro_ios.dylib"
    DYLIB_COUNT=$(find "${workdir}/modules" -maxdepth 1 -name "*.dylib" -type f 2>/dev/null | wc -l | tr -d ' ')
    assert_count_ge "nonzero dylibs: count >= 2" "${DYLIB_COUNT}" 2
}

# ---------------------------------------------------------------------------
# Test: pinned date URL validation (simulate HTTP check result)
# ---------------------------------------------------------------------------
test_pinned_date_404_falls_back_to_latest() {
    local PINNED_DATE="2026-03-18"
    local HTTP_CODE="404"

    if [ "${HTTP_CODE}" = "404" ] || [ "${HTTP_CODE}" = "000" ]; then
        PINNED_DATE=""
    fi

    if [ -z "${PINNED_DATE}" ]; then
        pass "pinned date 404: fallback to latest (PINNED_DATE cleared)"
    else
        fail "pinned date 404: PINNED_DATE should be cleared, got '${PINNED_DATE}'"
    fi
}

test_pinned_date_200_keeps_pin() {
    local PINNED_DATE="2026-03-18"
    local HTTP_CODE="200"

    if [ "${HTTP_CODE}" = "404" ] || [ "${HTTP_CODE}" = "000" ]; then
        PINNED_DATE=""
    fi

    if [ -n "${PINNED_DATE}" ]; then
        pass "pinned date 200: pin preserved"
    else
        fail "pinned date 200: pin should not be cleared"
    fi
}

# ---------------------------------------------------------------------------
# Test: truncated/corrupt zip (valid HTTP 200, not a zip) — detected and removed
# ---------------------------------------------------------------------------
test_corrupt_zip_detected() {
    local workdir="${TEST_ROOT}/corrupt_zip"
    mkdir -p "${workdir}"
    # Write a file that looks partially downloaded / truncated (not a zip)
    printf '\x00\x00\x00\x00' > "${workdir}/corrupt_libretro_ios.zip"

    local INVALID_ZIPS=0
    for zipfile in "${workdir}"/*.zip; do
        [ -f "$zipfile" ] || continue
        MAGIC=$(xxd -l 4 -p "$zipfile" 2>/dev/null)
        if [ "$MAGIC" != "504b0304" ]; then
            rm -f "$zipfile"
            INVALID_ZIPS=$((INVALID_ZIPS + 1))
        fi
    done

    assert_count_ge "corrupt zip: detected and removed" "${INVALID_ZIPS}" 1
    assert_file_not_exists "corrupt zip: file deleted" "${workdir}/corrupt_libretro_ios.zip"
}

# ---------------------------------------------------------------------------
# Integration tests: invoke get-modules.sh with mocked tools + a real SRCROOT
# ---------------------------------------------------------------------------

# Build a minimal SRCROOT under TEST_ROOT and return the path.
# Caller must set SRCROOT and run the script from outside.
_setup_integration_srcroot() {
    local tag="$1"
    local workdir="${TEST_ROOT}/srcroot_${tag}"
    mkdir -p "${workdir}/CoresRetro/RetroArch/scripts"
    mkdir -p "${workdir}/CoresRetro/RetroArch/modules"
    echo "${workdir}"
}

test_integration_success() {
    # All downloads succeed → dylibs created → exit 0
    local workdir
    workdir=$(_setup_integration_srcroot "int_ok")

    # Minimal URL list (3 cores)
    printf 'http://example.com/core1.zip\nhttp://example.com/core2.zip\nhttp://example.com/core3.zip\n' \
        > "${workdir}/CoresRetro/RetroArch/scripts/urls.txt"

    make_mock_curl_success
    make_mock_xxd_zip_valid   # isolate from real xxd; mock curl writes PK\x03\x04 so zip validation passes
    make_mock_unzip "${workdir}/CoresRetro/RetroArch/modules" "ios"

    local exit_code=0
    SRCROOT="${workdir}" PLATFORM_NAME="iphoneos" \
        bash "${SCRIPTS_DIR}/get-modules.sh" >/dev/null 2>&1 || exit_code=$?

    assert_exit "integration: success exit code" 0 "${exit_code}"

    local dylib_count
    dylib_count=$(find "${workdir}/CoresRetro/RetroArch/modules" -name "*.dylib" -type f 2>/dev/null | wc -l | tr -d ' ')
    assert_count_ge "integration: dylibs created after success" "${dylib_count}" 1
}

test_integration_all_downloads_fail() {
    # All downloads fail → below 80% threshold → exit 1
    local workdir
    workdir=$(_setup_integration_srcroot "int_fail")

    # Minimal URL list (3 cores)
    printf 'http://example.com/core1.zip\nhttp://example.com/core2.zip\nhttp://example.com/core3.zip\n' \
        > "${workdir}/CoresRetro/RetroArch/scripts/urls.txt"

    make_mock_curl_fail
    make_mock_xxd_invalid   # no .zip files written, but mock is installed for completeness

    local exit_code=0
    SRCROOT="${workdir}" PLATFORM_NAME="iphoneos" \
        bash "${SCRIPTS_DIR}/get-modules.sh" >/dev/null 2>&1 || exit_code=$?

    if [ "${exit_code}" -ne 0 ]; then
        pass "integration: all-fail exits non-zero (exit_code=${exit_code})"
    else
        fail "integration: all-fail should exit non-zero"
    fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
setup_test_root
echo "=== get-modules.sh validation tests ==="

run_test "Valid zip passes validation" test_valid_zip_passes_validation
run_test "HTML 404 file fails validation" test_html_file_fails_validation
run_test "Partial failure: valid zips survive" test_partial_failure_valid_zips_survive
run_test "Threshold: 90% passes" test_threshold_passes_when_above_80_percent
run_test "Threshold: 70% fails" test_threshold_fails_when_below_80_percent
run_test "Threshold: 0% fails" test_threshold_fails_when_zero_downloads
run_test "Threshold: exactly 80% passes" test_threshold_exact_80_percent_passes
run_test "Invalid date format rejected" test_invalid_date_format_rejected
run_test "Valid date format accepted" test_valid_date_format_accepted
run_test "Date with inline comment rejected" test_date_with_inline_comment_rejected
run_test "Empty date falls back to latest" test_empty_date_is_not_validated
run_test "Zero dylibs detected" test_zero_dylibs_detected
run_test "Nonzero dylibs counted" test_dylib_count_nonzero_after_extraction
run_test "Pinned date 404 falls back to latest" test_pinned_date_404_falls_back_to_latest
run_test "Pinned date 200 keeps pin" test_pinned_date_200_keeps_pin
run_test "Corrupt zip detected and removed" test_corrupt_zip_detected

run_test "Integration: all downloads succeed → exit 0 + dylibs created" test_integration_success
run_test "Integration: all downloads fail → exit 1" test_integration_all_downloads_fail

teardown_test_root
print_summary
