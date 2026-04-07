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

test_threshold_minimum_one_for_single_core() {
    # EXPECTED_COUNT=1 → 1*80/100=0 without the minimum; 0/1 would incorrectly pass.
    # The script now enforces THRESHOLD >= 1, so 0/1 must fail.
    local EXPECTED_COUNT=1 DOWNLOAD_OK=0
    local THRESHOLD=$(( EXPECTED_COUNT * 80 / 100 ))
    [ "${THRESHOLD}" -lt 1 ] && THRESHOLD=1
    if [ "${DOWNLOAD_OK}" -lt "${THRESHOLD}" ]; then
        pass "threshold minimum: 0/1 fails as expected (threshold enforced to ${THRESHOLD})"
    else
        fail "threshold minimum: 0/1 should fail (threshold=${THRESHOLD})"
    fi
}

test_threshold_minimum_one_passes_with_one_success() {
    # EXPECTED_COUNT=1 DOWNLOAD_OK=1 → should pass threshold=1
    local EXPECTED_COUNT=1 DOWNLOAD_OK=1
    local THRESHOLD=$(( EXPECTED_COUNT * 80 / 100 ))
    [ "${THRESHOLD}" -lt 1 ] && THRESHOLD=1
    if [ "${DOWNLOAD_OK}" -ge "${THRESHOLD}" ]; then
        pass "threshold minimum: 1/1 passes (threshold=${THRESHOLD})"
    else
        fail "threshold minimum: 1/1 should pass (threshold=${THRESHOLD})"
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

# Writes url_manifest.sha256 the same way get-modules.sh fingerprints MODULE_LIST
# (pinned_date line from cores.yml if valid YYYY-MM-DD, else "latest", then urls file bytes).
# Required for fast-path / skip-download tests after manifest-based cache invalidation.
_write_integration_url_manifest_fp() {
    local urls_file="$1"
    local fp_path="$2"
    local pin="latest"
    local yml
    yml="$(dirname "${urls_file}")/cores.yml"
    if [ -f "${yml}" ]; then
        pin=$(grep -v '^[[:space:]]*#' "${yml}" | grep -E '^[[:space:]]*pinned_date:' | sed 's/.*pinned_date:[[:space:]]*//' | tr -d '"' | tr -d "'" | tr -d '[:space:]' || true)
        if [ -z "${pin}" ]; then
            pin="latest"
        elif ! echo "${pin}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
            pin="latest"
        fi
    fi
    local sha=""
    sha=$( { printf '%s\n' "${pin}"; cat "${urls_file}"; } | shasum -a 256 2>/dev/null | awk '{print $1}' )
    if [ -z "${sha}" ]; then
        sha=$( { printf '%s\n' "${pin}"; cat "${urls_file}"; } | openssl dgst -sha256 2>/dev/null | awk '{print $NF}' )
    fi
    mkdir -p "$(dirname "${fp_path}")"
    printf '%s\n' "${sha}" > "${fp_path}"
}

test_integration_success() {
    # All downloads succeed → dylibs created → exit 0
    local workdir
    workdir=$(_setup_integration_srcroot "int_ok")

    # Minimal URL list (3 cores)
    printf 'http://example.com/core1_libretro.dylib.zip\nhttp://example.com/core2_libretro.dylib.zip\nhttp://example.com/core3_libretro.dylib.zip\n' \
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
    printf 'http://example.com/core1_libretro.dylib.zip\nhttp://example.com/core2_libretro.dylib.zip\nhttp://example.com/core3_libretro.dylib.zip\n' \
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
# Tests: platform tracking — active_platform.txt and fast-path
# ---------------------------------------------------------------------------

test_active_platform_written_after_extraction() {
    # After a successful run, active_platform.txt should record the built platform.
    local workdir
    workdir=$(_setup_integration_srcroot "platform_write")

    printf 'http://example.com/core1_libretro.dylib.zip\nhttp://example.com/core2_libretro.dylib.zip\nhttp://example.com/core3_libretro.dylib.zip\n' \
        > "${workdir}/CoresRetro/RetroArch/scripts/urls.txt"

    make_mock_curl_success
    make_mock_xxd_zip_valid
    make_mock_unzip "${workdir}/CoresRetro/RetroArch/modules" "ios"

    set +e
    SRCROOT="${workdir}" PLATFORM_NAME="iphoneos" \
        bash "${SCRIPTS_DIR}/get-modules.sh" >/dev/null 2>&1
    local exit_code=$?
    set -e
    if [ "${exit_code}" -eq 0 ]; then
        pass "get-modules.sh exited successfully"
    else
        fail "get-modules.sh exited with code ${exit_code}"
    fi

    local platform_file="${workdir}/CoresRetro/RetroArch/modules/active_platform.txt"
    assert_file_exists "platform file written after extraction" "${platform_file}"
    if [ -f "${platform_file}" ]; then
        local stored_platform
        stored_platform=$(cat "${platform_file}")
        if [ "${stored_platform}" = "ios" ]; then
            pass "platform file contains 'ios'"
        else
            fail "platform file should contain 'ios', got '${stored_platform}'"
        fi
    fi
}

test_fastpath_skips_extraction_when_platform_unchanged() {
    # When: same platform as active_platform.txt, timestamp is fresh, ≥80% dylibs present.
    # Expected: script exits 0 immediately without calling unzip.
    local workdir
    workdir=$(_setup_integration_srcroot "fastpath")

    local urls_ios="${workdir}/CoresRetro/RetroArch/scripts/urls.txt"
    printf 'http://example.com/core1_libretro.dylib.zip\nhttp://example.com/core2_libretro.dylib.zip\nhttp://example.com/core3_libretro.dylib.zip\n' \
        > "${urls_ios}"

    # Pre-populate modules/ with enough iOS dylibs (≥80% of 3 expected)
    mkdir -p "${workdir}/CoresRetro/RetroArch/modules"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/CoresRetro/RetroArch/modules/core1_libretro_ios.dylib"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/CoresRetro/RetroArch/modules/core2_libretro_ios.dylib"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/CoresRetro/RetroArch/modules/core3_libretro_ios.dylib"
    echo "ios" > "${workdir}/CoresRetro/RetroArch/modules/active_platform.txt"

    # Write a far-future timestamp so the download interval has not expired
    mkdir -p "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS"
    echo "9999999999" > "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/timestamp.txt"
    _write_integration_url_manifest_fp "${urls_ios}" "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/url_manifest.sha256"

    # Mock unzip to create a sentinel file when called — fast-path must NOT call it
    local flag_file="${workdir}/unzip_called"
    cat > "${MOCK_BIN}/unzip" << UNZIPEOF
#!/bin/bash
touch "${flag_file}"
exit 0
UNZIPEOF
    chmod +x "${MOCK_BIN}/unzip"

    local output exit_code=0
    output=$(SRCROOT="${workdir}" PLATFORM_NAME="iphoneos" \
        bash "${SCRIPTS_DIR}/get-modules.sh" 2>&1) || exit_code=$?

    assert_exit "fastpath: exits 0" 0 "${exit_code}"
    assert_contains "fastpath: logs skipping message" "${output}" "skipping extraction"
    assert_file_not_exists "fastpath: unzip was not called" "${flag_file}"
}

test_platform_switch_purges_old_dylibs() {
    # When active_platform is ios but we build for tvOS, ios dylibs must be purged.
    local workdir
    workdir=$(_setup_integration_srcroot "platform_switch")

    printf 'http://example.com/core1_libretro.dylib.zip\nhttp://example.com/core2_libretro.dylib.zip\nhttp://example.com/core3_libretro.dylib.zip\n' \
        > "${workdir}/CoresRetro/RetroArch/scripts/urls-tv.txt"

    # Pre-populate modules/ with iOS dylibs and record ios as the active platform
    mkdir -p "${workdir}/CoresRetro/RetroArch/modules"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/CoresRetro/RetroArch/modules/core1_libretro_ios.dylib"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/CoresRetro/RetroArch/modules/core2_libretro_ios.dylib"
    echo "ios" > "${workdir}/CoresRetro/RetroArch/modules/active_platform.txt"

    make_mock_curl_success
    make_mock_xxd_zip_valid
    make_mock_unzip "${workdir}/CoresRetro/RetroArch/modules" "tvos"

    local exit_code=0
    SRCROOT="${workdir}" PLATFORM_NAME="appletvos" \
        bash "${SCRIPTS_DIR}/get-modules.sh" >/dev/null 2>&1 || exit_code=$?

    assert_exit "platform switch: exits 0" 0 "${exit_code}"
    assert_file_not_exists "platform switch: ios dylib 1 purged" \
        "${workdir}/CoresRetro/RetroArch/modules/core1_libretro_ios.dylib"
    assert_file_not_exists "platform switch: ios dylib 2 purged" \
        "${workdir}/CoresRetro/RetroArch/modules/core2_libretro_ios.dylib"

    local platform_file="${workdir}/CoresRetro/RetroArch/modules/active_platform.txt"
    if [ -f "${platform_file}" ]; then
        local stored_platform
        stored_platform=$(cat "${platform_file}")
        if [ "${stored_platform}" = "tvos" ]; then
            pass "platform file updated to 'tvos' after switch"
        else
            fail "platform file should be 'tvos', got '${stored_platform}'"
        fi
    else
        fail "platform file should exist after switch"
    fi
}

test_fastpath_requires_sentinel_file() {
    # When active_platform.txt does NOT exist (first run / sentinel cleared), the
    # fast-path must NOT fire — even if the timestamp is fresh and dylibs are present.
    # Regression test for: PLATFORM_CHANGED=0 when STORED_PLATFORM="" masking first run.
    local workdir
    workdir=$(_setup_integration_srcroot "fastpath_no_sentinel")

    printf 'http://example.com/core1_libretro.dylib.zip\nhttp://example.com/core2_libretro.dylib.zip\nhttp://example.com/core3_libretro.dylib.zip\n' \
        > "${workdir}/CoresRetro/RetroArch/scripts/urls.txt"

    # Pre-populate modules/ with iOS dylibs — but do NOT write active_platform.txt
    mkdir -p "${workdir}/CoresRetro/RetroArch/modules"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/CoresRetro/RetroArch/modules/core1_libretro_ios.dylib"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/CoresRetro/RetroArch/modules/core2_libretro_ios.dylib"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/CoresRetro/RetroArch/modules/core3_libretro_ios.dylib"
    # Intentionally: no active_platform.txt — STORED_PLATFORM will be ""

    # Write a far-future timestamp so the download interval has not expired.
    # Also pre-populate the zip cache so the extraction step has files to process —
    # without cached zips the find/unzip step would silently skip (no files found),
    # and the unzip_called assertion below would always fail regardless of fast-path.
    mkdir -p "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS"
    echo "9999999999" > "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/timestamp.txt"
    printf '\x50\x4b\x03\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' \
        > "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/core1_libretro.dylib.zip"
    printf '\x50\x4b\x03\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' \
        > "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/core2_libretro.dylib.zip"
    printf '\x50\x4b\x03\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' \
        > "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/core3_libretro.dylib.zip"

    # Mock unzip to record whether it was called — fast-path must NOT prevent this call
    local flag_file="${workdir}/unzip_called"
    cat > "${MOCK_BIN}/unzip" << UNZIPEOF
#!/bin/bash
touch "${flag_file}"
exit 0
UNZIPEOF
    chmod +x "${MOCK_BIN}/unzip"

    make_mock_curl_success
    make_mock_xxd_zip_valid

    local exit_code=0
    SRCROOT="${workdir}" PLATFORM_NAME="iphoneos" \
        bash "${SCRIPTS_DIR}/get-modules.sh" >/dev/null 2>&1 || exit_code=$?

    assert_exit "no-sentinel: exits 0" 0 "${exit_code}"
    assert_file_exists "no-sentinel: unzip was called (fast-path not taken)" "${flag_file}"
    assert_file_exists "no-sentinel: active_platform.txt written after run" \
        "${workdir}/CoresRetro/RetroArch/modules/active_platform.txt"
}

test_platform_switch_back_reuses_cached_dylibs() {
    # Simulate: built iOS, then tvOS, then back to iOS.
    # On the return to iOS: tvOS dylibs are purged and iOS ones re-extracted from cached
    # zips (no re-download because the iOS timestamp is still fresh).
    local workdir
    workdir=$(_setup_integration_srcroot "switch_back")

    local urls_ios="${workdir}/CoresRetro/RetroArch/scripts/urls.txt"
    printf 'http://example.com/core1_libretro.dylib.zip\nhttp://example.com/core2_libretro.dylib.zip\nhttp://example.com/core3_libretro.dylib.zip\n' \
        > "${urls_ios}"

    # modules/ currently has tvOS dylibs (last platform was tvOS)
    mkdir -p "${workdir}/CoresRetro/RetroArch/modules"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/CoresRetro/RetroArch/modules/core1_libretro_tvos.dylib"
    echo "tvos" > "${workdir}/CoresRetro/RetroArch/modules/active_platform.txt"

    # Simulate previously-cached iOS zip archives + a fresh timestamp (no re-download needed)
    mkdir -p "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS"
    echo "9999999999" > "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/timestamp.txt"
    _write_integration_url_manifest_fp "${urls_ios}" "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/url_manifest.sha256"
    # Write minimal valid zip files so the zip-validation loop finds something to extract
    printf '\x50\x4b\x03\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' \
        > "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/core1_libretro.dylib.zip"
    printf '\x50\x4b\x03\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' \
        > "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/core2_libretro.dylib.zip"
    printf '\x50\x4b\x03\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' \
        > "${workdir}/CoresRetro/RetroArch/modules_compressed/iOS/core3_libretro.dylib.zip"

    # Mock tools: curl should NOT be called (timestamp is fresh); unzip creates ios dylibs
    make_mock_curl_fail   # if download is accidentally triggered, fail loudly
    make_mock_xxd_zip_valid
    make_mock_unzip "${workdir}/CoresRetro/RetroArch/modules" "ios"

    local exit_code=0
    SRCROOT="${workdir}" PLATFORM_NAME="iphoneos" \
        bash "${SCRIPTS_DIR}/get-modules.sh" >/dev/null 2>&1 || exit_code=$?

    assert_exit "switch back: exits 0" 0 "${exit_code}"
    # tvOS dylibs should have been purged when we switched back to iOS
    assert_file_not_exists "switch back: tvos dylib purged" \
        "${workdir}/CoresRetro/RetroArch/modules/core1_libretro_tvos.dylib"

    local platform_file="${workdir}/CoresRetro/RetroArch/modules/active_platform.txt"
    if [ -f "${platform_file}" ]; then
        local stored_platform
        stored_platform=$(cat "${platform_file}")
        if [ "${stored_platform}" = "ios" ]; then
            pass "switch back: platform file updated to 'ios'"
        else
            fail "switch back: platform file should be 'ios', got '${stored_platform}'"
        fi
    else
        fail "switch back: platform file should exist"
    fi
}

test_platform_switch_replaces_neutral_dylibs() {
    # Neutral dylibs (no ios/tvos suffix, e.g. dolphin_libretro.dylib) must be
    # replaced when switching platforms, not silently reused via unzip -n.
    local workdir
    workdir=$(_setup_integration_srcroot "neutral_switch")

    printf 'http://example.com/core1_libretro.dylib.zip\nhttp://example.com/core2_libretro.dylib.zip\nhttp://example.com/dolphin_libretro.dylib.zip\n' \
        > "${workdir}/CoresRetro/RetroArch/scripts/urls-tv.txt"

    # Pre-populate modules/ with: one neutral dylib (shared name across platforms)
    # and the ios active-platform sentinel. Simulates having previously built iOS.
    # Use a distinct content marker so we can verify it was replaced after the switch.
    mkdir -p "${workdir}/CoresRetro/RetroArch/modules"
    printf '\xcf\xfa\xed\xfe' > "${workdir}/CoresRetro/RetroArch/modules/dolphin_libretro.dylib"
    echo "ios" > "${workdir}/CoresRetro/RetroArch/modules/active_platform.txt"

    # Create a mock unzip that records calls *and* arguments, then writes tvos dylibs.
    # We write the full argument list to flag_file so we can assert that -o was passed.
    # The mock writes DIFFERENT content to dolphin_libretro.dylib so the content-change
    # assertion below can verify the file was actually overwritten, not just kept.
    local flag_file="${workdir}/unzip_called"
    local tvos_modules_dir="${workdir}/CoresRetro/RetroArch/modules"
    mkdir -p "${tvos_modules_dir}"
    cat > "${MOCK_BIN}/unzip" << UNZIPEOF
#!/bin/bash
# Record all arguments so the test can verify -o was present.
echo "\$*" > "${flag_file}"
zip_file=""
dest_dir="${tvos_modules_dir}"
for i in "\$@"; do
    if [[ "\$i" == *.zip ]]; then zip_file="\$i"; fi
    if [ "\$prev" = "-d" ]; then dest_dir="\$i"; fi
    prev="\$i"
done
if [ -n "\$zip_file" ]; then
    base=\$(basename "\$zip_file" .zip)
    case "\$base" in
        *_libretro.dylib)
            stem="\${base%_libretro.dylib}"
            printf '\\xcf\\xfa\\xed\\xfe' > "\${dest_dir}/\${stem}_libretro_tvos.dylib"
            ;;
        *)
            printf '\\xcf\\xfa\\xed\\xfe' > "\${dest_dir}/\${base}_libretro_tvos.dylib"
            ;;
    esac
    # Simulate overwrite of the neutral dylib with new (distinct) contents so the
    # content-change assertion below can confirm the old iOS-built file was replaced.
    printf '\\xca\\xfe\\xba\\xbe' > "\${dest_dir}/dolphin_libretro.dylib"
fi
exit 0
UNZIPEOF
    chmod +x "${MOCK_BIN}/unzip"

    make_mock_curl_success
    make_mock_xxd_zip_valid

    local exit_code=0
    SRCROOT="${workdir}" PLATFORM_NAME="appletvos" \
        bash "${SCRIPTS_DIR}/get-modules.sh" >/dev/null 2>&1 || exit_code=$?

    assert_exit "neutral switch: exits 0" 0 "${exit_code}"
    # Neutral dylib was removed before extraction and re-created by mock unzip
    assert_file_exists "neutral switch: dolphin_libretro.dylib re-extracted" \
        "${workdir}/CoresRetro/RetroArch/modules/dolphin_libretro.dylib"
    # Verify the neutral dylib content changed — proves it was replaced, not left as-is.
    # Use system xxd: PATH still has the mock used by get-modules (returns "deadbeef" for non-.zip).
    local new_magic
    new_magic=$(PATH="/usr/bin:/bin" xxd -l 4 -p "${workdir}/CoresRetro/RetroArch/modules/dolphin_libretro.dylib" 2>/dev/null || echo "")
    if [ "${new_magic}" = "cafebabe" ]; then
        pass "neutral switch: dolphin_libretro.dylib contents replaced (old iOS bytes overwritten)"
    else
        fail "neutral switch: dolphin_libretro.dylib should have new content (cafebabe), got '${new_magic}'"
    fi
    # unzip was called (flag_file contains the argument list)
    assert_file_exists "neutral switch: unzip was called" "${flag_file}"
    # Verify unzip was invoked with -o (overwrite) on platform change.
    # Use a regex that matches -o at the start of the string OR between spaces,
    # because get-modules.sh calls: unzip -o <zip> -d <dir>  (i.e. -o is first arg).
    if grep -qE '(^| )-o( |$)' "${flag_file}"; then
        pass "neutral switch: unzip called with -o (overwrite)"
    else
        fail "neutral switch: unzip should be called with -o (overwrite); args were: $(cat "${flag_file}")"
    fi
    # platform file updated to tvos
    local stored_platform
    stored_platform=$(cat "${workdir}/CoresRetro/RetroArch/modules/active_platform.txt" 2>/dev/null || echo "")
    if [ "${stored_platform}" = "tvos" ]; then
        pass "neutral switch: platform file updated to 'tvos'"
    else
        fail "neutral switch: platform file should be 'tvos', got '${stored_platform}'"
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
run_test "Threshold minimum: 0/1 fails (integer-division guard)" test_threshold_minimum_one_for_single_core
run_test "Threshold minimum: 1/1 passes" test_threshold_minimum_one_passes_with_one_success
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

run_test "Platform tracking: active_platform.txt written after extraction" test_active_platform_written_after_extraction
run_test "Platform fast-path: skips extraction on same platform + fresh timestamp" test_fastpath_skips_extraction_when_platform_unchanged
run_test "Platform fast-path: does not skip when sentinel is absent (first run)" test_fastpath_requires_sentinel_file
run_test "Platform switch: iOS→tvOS purges ios dylibs" test_platform_switch_purges_old_dylibs
run_test "Platform switch-back: tvOS→iOS purges tvos dylibs, reuses cached ios zips" test_platform_switch_back_reuses_cached_dylibs
run_test "Platform switch: neutral dylibs replaced on platform change" test_platform_switch_replaces_neutral_dylibs

teardown_test_root
print_summary
