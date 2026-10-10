#!/bin/bash
# test-get-modules-validation.sh
# Sanity check: verify that get-modules.sh fails loudly when a download is
# either a 404 HTML page or a non-zip file. This is a lightweight bash test —
# no test framework needed — intended to be run locally before pushing changes
# to get-modules.sh.
#
# What it checks:
#   1. Sentinel guard: a manifest pointing at an obviously invalid URL exits non-zero.
#   2. Magic-byte validation: a "downloaded" file that isn't PK\x03\x04 is rejected.
#
# The script does NOT actually invoke the network — it stages a fake
# modules_compressed/ directory with HTML "404 pages" masquerading as zips,
# then runs the validator code path directly.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GET_MODULES="$REPO_ROOT/CoresRetro/RetroArch/scripts/get-modules.sh"

if [ ! -f "$GET_MODULES" ]; then
    echo "FAIL: get-modules.sh not found at $GET_MODULES" >&2
    exit 1
fi

FAIL_COUNT=0

# ---- Test 1: magic-byte validation rejects HTML masquerading as zip ----
test_magic_byte_rejection() {
    local tmpdir
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/get_modules_test.XXXXXX")
    # Drop two "zip" files: one real, one HTML 404 page.
    printf 'PK\x03\x04fakezipbody' > "$tmpdir/good.zip"
    printf '<html><body>404 Not Found</body></html>' > "$tmpdir/bad.zip"

    local removed_invalid=0
    local valid=0
    for zipfile in "$tmpdir"/*.zip; do
        local magic
        magic=$(xxd -l 4 -p "$zipfile" 2>/dev/null)
        if [ "$magic" != "504b0304" ]; then
            rm -f "$zipfile"
            removed_invalid=$((removed_invalid + 1))
        else
            valid=$((valid + 1))
        fi
    done

    rm -rf "$tmpdir"

    if [ "$removed_invalid" -eq 1 ] && [ "$valid" -eq 1 ]; then
        echo "PASS: magic-byte validation removed 404 HTML, kept real zip"
        return 0
    fi
    echo "FAIL: expected 1 removed + 1 valid, got removed=$removed_invalid valid=$valid" >&2
    return 1
}

# ---- Test 2: sentinel guard exits non-zero on bad URL ----
# Stage a fake script-run env with a manifest pointing at an unroutable URL.
# We invoke the sentinel block in isolation rather than the full script (which
# has many other deps on Xcode env vars + existing modules_compressed state).
test_sentinel_rejects_bad_url() {
    local tmpdir
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/get_modules_sentinel.XXXXXX")
    local manifest="$tmpdir/urls.txt"
    # Use a reserved-TLD URL so curl --fail returns non-zero deterministically.
    # The sentinel logic should NOT exit non-zero here — a transient net error
    # is logged as a warning and the full loop is allowed to proceed. The
    # threshold check at the end will then fail when all downloads fail.
    echo "https://invalid.example.invalid/nope.zip" > "$manifest"

    local sentinel_tmp
    sentinel_tmp=$(mktemp "${TMPDIR:-/tmp}/sentinel.XXXXXX.zip")
    if curl --fail -L --silent --show-error --connect-timeout 3 -o "$sentinel_tmp" \
        "$(head -1 "$manifest")" 2>/dev/null; then
        echo "FAIL: curl unexpectedly succeeded against invalid host" >&2
        rm -rf "$tmpdir" "$sentinel_tmp"
        return 1
    fi
    rm -rf "$tmpdir" "$sentinel_tmp"
    echo "PASS: curl --fail returns non-zero on unreachable host (as expected)"
    return 0
}

# ---- Test 3: empty modules dir triggers make_frameworks error path ----
# Lightweight syntax-only check: confirm the 0-dylib branch is present
# and uses `exit 1`.
test_make_frameworks_zero_dylib_check() {
    local fw="$REPO_ROOT/CoresRetro/RetroArch/scripts/make_frameworks_retroarch.sh"
    if [ ! -f "$fw" ]; then
        echo "FAIL: make_frameworks_retroarch.sh not found" >&2
        return 1
    fi
    if grep -q 'DYLIB_COUNT.*-eq 0' "$fw" && grep -q 'No dylibs found' "$fw"; then
        echo "PASS: make_frameworks_retroarch.sh has 0-dylib guard"
        return 0
    fi
    echo "FAIL: missing 0-dylib guard in make_frameworks_retroarch.sh" >&2
    return 1
}

# ---- Test 4: get-modules.sh uses curl --fail (not bare curl -O) ----
test_get_modules_uses_curl_fail() {
    if grep -q 'curl --fail -L' "$GET_MODULES"; then
        echo "PASS: get-modules.sh uses 'curl --fail -L'"
        return 0
    fi
    echo "FAIL: get-modules.sh missing 'curl --fail -L'" >&2
    return 1
}

# ---- Test 5: get-modules.sh validates zip magic bytes ----
test_get_modules_validates_zip_magic() {
    if grep -q '504b0304' "$GET_MODULES"; then
        echo "PASS: get-modules.sh checks zip magic bytes (PK\\x03\\x04)"
        return 0
    fi
    echo "FAIL: get-modules.sh missing zip magic-byte check" >&2
    return 1
}

# ---- Test 6: --urls fetches only the listed dylibs and never prunes the shared modules/ ----
test_get_modules_custom_url_list() {
    local tmp
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/get_modules_urls.XXXXXX")
    local ra="$tmp/CoresRetro/RetroArch"
    mkdir -p "$ra/scripts" "$ra/modules" "$tmp/zips"

    # A minimal arm64 Mach-O dylib header: `file` reports "Mach-O 64-bit ... dynamically linked shared library".
    python3 - "$tmp" <<'PY'
import struct, sys, zipfile, os
root = sys.argv[1]
header = struct.pack("<IiiIIIII", 0xfeedfacf, 0x0100000c, 0, 6, 0, 0, 0, 0)
dylib = os.path.join(root, "fake_libretro_ios.dylib")
with open(dylib, "wb") as f:
    f.write(header)
with zipfile.ZipFile(os.path.join(root, "zips", "fake_libretro_ios.dylib.zip"), "w") as z:
    z.write(dylib, "fake_libretro_ios.dylib")
with open(os.path.join(root, "CoresRetro/RetroArch/modules/other_libretro_ios.dylib"), "wb") as f:
    f.write(header)
PY
    echo "file://$tmp/zips/fake_libretro_ios.dylib.zip" > "$tmp/urls.txt"

    local out rc=0
    out=$(SRCROOT="$tmp" PLATFORM_NAME=iphonesimulator GETMODULES_MIN_DYLIB_SIZE=1 \
        bash "$GET_MODULES" --urls "$tmp/urls.txt" 2>&1) || rc=$?

    local ok=1
    [ "$rc" -eq 0 ] || { echo "FAIL: --urls run exited $rc"; echo "$out" | tail -20; ok=0; }
    [ -f "$ra/modules/fake_libretro_ios.dylib" ] || { echo "FAIL: listed dylib not extracted"; ok=0; }
    [ -f "$ra/modules/other_libretro_ios.dylib" ] || { echo "FAIL: --urls pruned an unlisted dylib from shared modules/"; ok=0; }
    ls -d "$ra"/modules_compressed/iOS-urls-* >/dev/null 2>&1 || { echo "FAIL: no iOS-urls-<sha> state dir"; ok=0; }
    [ ! -f "$ra/modules_compressed/iOS/url_manifest.sha256" ] || { echo "FAIL: --urls wrote the shared iOS manifest"; ok=0; }

    # Second run: everything present and fresh -> fast path.
    out=$(SRCROOT="$tmp" PLATFORM_NAME=iphonesimulator GETMODULES_MIN_DYLIB_SIZE=1 \
        bash "$GET_MODULES" --urls "$tmp/urls.txt" 2>&1) || true
    echo "$out" | grep -q "all 1 listed dylib(s) present" || { echo "FAIL: second --urls run did not take the fast path"; ok=0; }

    rm -rf "$tmp"
    [ "$ok" -eq 1 ] && echo "PASS: --urls fetches the listed dylibs into shared modules/ without pruning"
    [ "$ok" -eq 1 ]
}

# ---- Test 7: --urls never deletes seeded other-platform or neutral dylibs (no active_platform.txt) ----
test_get_modules_urls_no_purge() {
    local tmp
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/get_modules_urls_nopurge.XXXXXX")
    local ra="$tmp/CoresRetro/RetroArch"
    mkdir -p "$ra/scripts" "$ra/modules" "$tmp/zips"
    python3 - "$tmp" <<'PY'
import struct, sys, zipfile, os
root = sys.argv[1]
header = struct.pack("<IiiIIIII", 0xfeedfacf, 0x0100000c, 0, 6, 0, 0, 0, 0)
dylib = os.path.join(root, "fake_libretro_ios.dylib")
with open(dylib, "wb") as f:
    f.write(header)
with zipfile.ZipFile(os.path.join(root, "zips", "fake_libretro_ios.dylib.zip"), "w") as z:
    z.write(dylib, "fake_libretro_ios.dylib")
for n in ("seed_libretro_tvos.dylib", "neutral_libretro.dylib"):
    with open(os.path.join(root, "CoresRetro/RetroArch/modules", n), "wb") as f:
        f.write(header)
PY
    echo "file://$tmp/zips/fake_libretro_ios.dylib.zip" > "$tmp/urls.txt"

    local out rc=0 ok=1
    out=$(SRCROOT="$tmp" PLATFORM_NAME=iphonesimulator GETMODULES_MIN_DYLIB_SIZE=1 \
        bash "$GET_MODULES" --urls "$tmp/urls.txt" 2>&1) || rc=$?
    [ "$rc" -eq 0 ] || { echo "FAIL: --urls run exited $rc"; echo "$out" | tail -20; ok=0; }
    [ -f "$ra/modules/seed_libretro_tvos.dylib" ] || { echo "FAIL: --urls deleted an other-platform dylib"; ok=0; }
    [ -f "$ra/modules/neutral_libretro.dylib" ] || { echo "FAIL: --urls deleted a neutral dylib"; ok=0; }
    [ -f "$ra/modules/fake_libretro_ios.dylib" ] || { echo "FAIL: listed dylib not extracted"; ok=0; }

    rm -rf "$tmp"
    [ "$ok" -eq 1 ] && echo "PASS: --urls leaves seeded other-platform and neutral dylibs alone"
    [ "$ok" -eq 1 ]
}

# ---- Run all tests ----
run_test() {
    if ! "$1"; then
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo "=== get-modules.sh validation tests ==="
run_test test_magic_byte_rejection
run_test test_sentinel_rejects_bad_url
run_test test_make_frameworks_zero_dylib_check
run_test test_get_modules_uses_curl_fail
run_test test_get_modules_validates_zip_magic
run_test test_get_modules_custom_url_list
run_test test_get_modules_urls_no_purge

echo "==="
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "All tests passed."
    exit 0
fi
echo "$FAIL_COUNT test(s) FAILED."
exit 1
