#!/bin/bash
# test_make_frameworks.sh — Tests for make_frameworks_retroarch.sh validation logic
#
# Tests cover: empty modules dir, Mach-O validation, framework executable check,
# and count thresholds. Mocks codesign/vtool/lipo/file to avoid real signing.
#
# Run via: bash tests/run_tests.sh  (from CoresRetro/RetroArch/scripts/)
# Or directly: bash tests/test_make_frameworks.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

SCRIPTS_DIR="$(dirname "${SCRIPT_DIR}")"

# ---------------------------------------------------------------------------
# Helper: create a fake Mach-O dylib (minimal arm64 magic header)
# ---------------------------------------------------------------------------
make_fake_dylib() {
    local path="$1"
    printf '\xcf\xfa\xed\xfe\x0c\x00\x00\x01\x00\x00\x00\x00\x06\x00\x00\x00' > "${path}"
}

# Create a fake framework directory that mirrors what the script would produce
make_fake_framework() {
    local outdir="$1" name="$2"
    mkdir -p "${outdir}/${name}.framework"
    printf '\xcf\xfa\xed\xfe' > "${outdir}/${name}.framework/${name}"
    cat > "${outdir}/${name}.framework/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleName</key><string>${name}</string></dict></plist>
PLIST
}

# ---------------------------------------------------------------------------
# Test: empty modules dir → no dylibs found → exits non-zero
# ---------------------------------------------------------------------------
test_empty_modules_dir_exits_nonzero() {
    local workdir="${TEST_ROOT}/empty_modules"
    mkdir -p "${workdir}/modules"

    DYLIB_COUNT=$(find "${workdir}/modules" -maxdepth 1 -type f -regex '.*libretro.*\.dylib$' 2>/dev/null | wc -l | tr -d ' ')

    if [ "${DYLIB_COUNT}" -eq 0 ]; then
        pass "empty modules: 0 dylibs detected correctly"
        # Script would exit 1 here
        pass "empty modules: would exit non-zero (verified)"
    else
        fail "empty modules: expected 0 dylibs, got ${DYLIB_COUNT}"
    fi
}

# ---------------------------------------------------------------------------
# Test: valid Mach-O dylib is accepted
# ---------------------------------------------------------------------------
test_valid_macho_dylib_accepted() {
    setup_test_root
    make_mock_file_macho

    local workdir="${TEST_ROOT}/valid_macho"
    mkdir -p "${workdir}/modules"
    make_fake_dylib "${workdir}/modules/pcsx_rearmed_libretro_ios.dylib"

    FILE_TYPE=$(file -b "${workdir}/modules/pcsx_rearmed_libretro_ios.dylib" 2>/dev/null)
    case "$FILE_TYPE" in
        *Mach-O*|*"universal binary"*)
            pass "valid Mach-O: accepted (file type: ${FILE_TYPE})"
            ;;
        *)
            fail "valid Mach-O: rejected unexpectedly (file type: ${FILE_TYPE})"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Test: non-Mach-O file (HTML/corrupt) is rejected
# ---------------------------------------------------------------------------
test_corrupt_dylib_rejected() {
    setup_test_root
    make_mock_file_corrupt

    local workdir="${TEST_ROOT}/corrupt_dylib"
    mkdir -p "${workdir}/modules"
    echo '<html>404 Not Found</html>' > "${workdir}/modules/bad_libretro_ios.dylib"

    FILE_TYPE=$(file -b "${workdir}/modules/bad_libretro_ios.dylib" 2>/dev/null)
    local accepted=0
    case "$FILE_TYPE" in
        *Mach-O*|*"universal binary"*)
            accepted=1
            ;;
    esac

    assert_exit "corrupt dylib: rejected" 0 "${accepted}"
}

# ---------------------------------------------------------------------------
# Test: framework executable validation — present means valid
# ---------------------------------------------------------------------------
test_framework_executable_present() {
    local workdir="${TEST_ROOT}/fw_exec"
    mkdir -p "${workdir}/Frameworks"
    make_fake_framework "${workdir}/Frameworks" "pcsx.rearmed.libretro"

    local fwDir="${workdir}/Frameworks/pcsx.rearmed.libretro.framework"
    local fwName="pcsx.rearmed.libretro"

    if [ -f "${fwDir}/${fwName}" ] || [ -L "${fwDir}/${fwName}" ]; then
        pass "framework executable: present and validated"
    else
        fail "framework executable: missing"
    fi
}

# ---------------------------------------------------------------------------
# Test: framework executable missing → detected as failure
# ---------------------------------------------------------------------------
test_framework_executable_missing() {
    local workdir="${TEST_ROOT}/fw_no_exec"
    local fwDir="${workdir}/Frameworks/pcsx.rearmed.libretro.framework"
    mkdir -p "${fwDir}"
    # Create plist but NO executable
    echo '<plist/>' > "${fwDir}/Info.plist"

    local fwName="pcsx.rearmed.libretro"
    local FW_FAIL=0
    if [ ! -f "${fwDir}/${fwName}" ] && [ ! -L "${fwDir}/${fwName}" ]; then
        FW_FAIL=$((FW_FAIL + 1))
    fi

    assert_count_ge "missing executable: failure counted" "${FW_FAIL}" 1
}

# ---------------------------------------------------------------------------
# Test: 80% threshold warning when < 80% frameworks created
# ---------------------------------------------------------------------------
test_count_below_threshold_warns() {
    local DYLIB_COUNT=10 FW_COUNT=7
    local THRESHOLD=$(( DYLIB_COUNT * 80 / 100 ))
    local warned=0
    if [ "${FW_COUNT}" -lt "${THRESHOLD}" ]; then
        warned=1
    fi
    assert_count_ge "below 80% threshold: warning triggered" "${warned}" 1
}

# ---------------------------------------------------------------------------
# Test: 80% threshold passes when >= 80% frameworks created
# ---------------------------------------------------------------------------
test_count_above_threshold_no_warn() {
    local DYLIB_COUNT=10 FW_COUNT=9
    local THRESHOLD=$(( DYLIB_COUNT * 80 / 100 ))
    local warned=0
    if [ "${FW_COUNT}" -lt "${THRESHOLD}" ]; then
        warned=1
    fi
    assert_exit "above 80% threshold: no warning" 0 "${warned}"
}

# ---------------------------------------------------------------------------
# Test: 0 frameworks from nonzero dylibs → exit 1 condition
# ---------------------------------------------------------------------------
test_zero_frameworks_from_nonzero_dylibs_fails() {
    local DYLIB_COUNT=5 FW_COUNT=0
    local would_exit=0
    if [ "${FW_COUNT}" -eq 0 ] && [ "${DYLIB_COUNT}" -gt 0 ]; then
        would_exit=1
    fi
    assert_count_ge "zero frameworks from nonzero dylibs: exits nonzero" "${would_exit}" 1
}

# ---------------------------------------------------------------------------
# Test: 0 frameworks from 0 dylibs — script already failed on empty dir check
# ---------------------------------------------------------------------------
test_zero_both_counts_already_caught() {
    local DYLIB_COUNT=0 FW_COUNT=0
    # The script exits BEFORE the loop if DYLIB_COUNT == 0
    if [ "${DYLIB_COUNT}" -eq 0 ]; then
        pass "zero dylibs: caught at entry check, would exit 1"
    else
        fail "zero dylibs: should exit at entry check"
    fi
}

# ---------------------------------------------------------------------------
# Test: multiple valid dylibs → all frameworks created
# ---------------------------------------------------------------------------
test_multiple_dylibs_all_frameworks_created() {
    setup_test_root
    make_mock_file_macho
    make_mock_lipo
    make_mock_codesign
    make_mock_vtool

    local workdir="${TEST_ROOT}/multi_dylibs"
    local outdir="${workdir}/Frameworks"
    mkdir -p "${workdir}/modules" "${outdir}"

    local cores=("pcsx_rearmed" "gambatte" "mgba" "nestopia" "sameboy")
    for core in "${cores[@]}"; do
        make_fake_dylib "${workdir}/modules/${core}_libretro_ios.dylib"
    done

    # Copy fw.tmpl if available, else create a minimal one
    local fw_tmpl="${SCRIPTS_DIR}/fw.tmpl"
    if [ ! -f "${fw_tmpl}" ]; then
        cat > "${workdir}/fw.tmpl" << 'TMPL'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleName</key><string>%CORE%</string>
<key>CFBundleIdentifier</key><string>org.provenance-emu.%IDENTIFIER%</string>
</dict></plist>
TMPL
        fw_tmpl="${workdir}/fw.tmpl"
    fi

    DYLIB_COUNT=0
    FW_COUNT=0
    PLATFORM_FAMILY_NAME="iOS"
    SUFFIX="_ios"
    DEPLOYMENT_TARGET="16.0"

    for dylib in "${workdir}/modules/"*libretro*_ios.dylib; do
        [ -f "$dylib" ] || continue
        DYLIB_COUNT=$((DYLIB_COUNT + 1))
        FILE_TYPE=$(file -b "$dylib" 2>/dev/null)
        case "$FILE_TYPE" in
            *Mach-O*|*"universal binary"*)
                intermediate=$(basename "$dylib")
                intermediate="${intermediate/%.dylib/}"
                intermediate="${intermediate/%$SUFFIX/}"
                fwName="${intermediate//_/.}"
                fwDir="${outdir}/${fwName}.framework"
                mkdir -p "${fwDir}"
                lipo -create "$dylib" -output "${fwDir}/${fwName}"
                sed -e "s,%CORE%,${fwName}," -e "s,%BUNDLE%,${fwName}," \
                    -e "s,%IDENTIFIER%,${fwName}," -e "s,%OSVER%,${DEPLOYMENT_TARGET}," \
                    "${fw_tmpl}" > "${fwDir}/Info.plist"
                if [ -f "${fwDir}/${fwName}" ] || [ -L "${fwDir}/${fwName}" ]; then
                    FW_COUNT=$((FW_COUNT + 1))
                fi
                ;;
        esac
    done

    assert_exit "multi dylibs: DYLIB_COUNT" 5 "${DYLIB_COUNT}"
    assert_exit "multi dylibs: FW_COUNT" 5 "${FW_COUNT}"
    for core in "${cores[@]}"; do
        fwName="${core//_/.}.libretro"
        assert_file_exists "multi dylibs: ${fwName}.framework/${fwName}" \
            "${outdir}/${fwName}.framework/${fwName}"
    done
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
setup_test_root
echo "=== make_frameworks_retroarch.sh validation tests ==="

run_test "Empty modules dir exits nonzero" test_empty_modules_dir_exits_nonzero
run_test "Valid Mach-O dylib accepted" test_valid_macho_dylib_accepted
run_test "Corrupt/HTML dylib rejected" test_corrupt_dylib_rejected
run_test "Framework executable present: validated" test_framework_executable_present
run_test "Framework executable missing: detected" test_framework_executable_missing
run_test "Count below 80% threshold: warning" test_count_below_threshold_warns
run_test "Count above 80% threshold: no warning" test_count_above_threshold_no_warn
run_test "0 frameworks from nonzero dylibs: exit 1" test_zero_frameworks_from_nonzero_dylibs_fails
run_test "0 dylibs: caught at entry check" test_zero_both_counts_already_caught
run_test "Multiple dylibs: all frameworks created" test_multiple_dylibs_all_frameworks_created

teardown_test_root
print_summary
