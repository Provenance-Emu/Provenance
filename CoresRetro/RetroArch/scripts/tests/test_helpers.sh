#!/bin/bash
# test_helpers.sh — shared test harness utilities

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Setup a temporary test root; call at start of each test file
setup_test_root() {
    TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/pvtest.XXXXXX")
    MOCK_BIN="${TEST_ROOT}/mock_bin"
    mkdir -p "${MOCK_BIN}"
    # Prepend mock bin to PATH so mocks take priority
    export PATH="${MOCK_BIN}:${PATH}"
}

teardown_test_root() {
    [ -n "${TEST_ROOT}" ] && rm -rf "${TEST_ROOT}"
}

# --- Assertion helpers ---

assert_exit() {
    local label="$1" expected="$2" actual="$3"
    if [ "${actual}" -eq "${expected}" ]; then
        pass "${label}: exit code = ${expected}"
    else
        fail "${label}: expected exit ${expected}, got ${actual}"
    fi
}

assert_file_exists() {
    local label="$1" path="$2"
    if [ -f "${path}" ]; then
        pass "${label}: file exists: ${path}"
    else
        fail "${label}: file missing: ${path}"
    fi
}

assert_file_not_exists() {
    local label="$1" path="$2"
    if [ ! -f "${path}" ]; then
        pass "${label}: file correctly absent: ${path}"
    else
        fail "${label}: file should not exist: ${path}"
    fi
}

assert_contains() {
    local label="$1" haystack="$2" needle="$3"
    if echo "${haystack}" | grep -qF "${needle}"; then
        pass "${label}: output contains '${needle}'"
    else
        fail "${label}: output missing '${needle}'"
        echo "    Output was: ${haystack}" >&2
    fi
}

assert_not_contains() {
    local label="$1" haystack="$2" needle="$3"
    if ! echo "${haystack}" | grep -qF "${needle}"; then
        pass "${label}: output correctly absent '${needle}'"
    else
        fail "${label}: output should not contain '${needle}'"
    fi
}

assert_count_ge() {
    local label="$1" actual="$2" minimum="$3"
    if [ "${actual}" -ge "${minimum}" ]; then
        pass "${label}: count ${actual} >= ${minimum}"
    else
        fail "${label}: count ${actual} < ${minimum}"
    fi
}

pass() { echo "    ✅ PASS: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo "    ❌ FAIL: $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
skip() { echo "    ⏭️  SKIP: $1"; TESTS_SKIPPED=$((TESTS_SKIPPED + 1)); }

run_test() {
    local name="$1"
    local fn="$2"
    echo ""
    echo "  ▶ ${name}"
    "${fn}"
}

print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Results: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed, ${TESTS_SKIPPED} skipped"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    [ "${TESTS_FAILED}" -eq 0 ]
}

# --- Mock builders ---

# Create a mock 'xxd' that returns the PK zip magic for files ending in .zip
# and random bytes for others
make_mock_xxd_zip_valid() {
    cat > "${MOCK_BIN}/xxd" << 'EOF'
#!/bin/bash
# Mock xxd: returns PK zip magic for .zip files, garbage otherwise
file="$3"
if [[ "$file" == *.zip ]]; then
    echo "504b0304"
else
    echo "deadbeef"
fi
EOF
    chmod +x "${MOCK_BIN}/xxd"
}

# Create a mock 'xxd' that always returns non-zip magic (simulates corrupt/HTML files)
make_mock_xxd_invalid() {
    cat > "${MOCK_BIN}/xxd" << 'EOF'
#!/bin/bash
echo "3c21444f"  # <!DO (HTML page start)
EOF
    chmod +x "${MOCK_BIN}/xxd"
}

# Create a mock 'curl' that always succeeds and writes valid zip magic to the output file
make_mock_curl_success() {
    local target_dir="$1"
    cat > "${MOCK_BIN}/curl" << EOF
#!/bin/bash
# Parse -o flag to get output filename
output_file=""
url=""
for i in "\$@"; do
    if [ "\$prev" = "-o" ]; then
        output_file="\$i"
    fi
    if [[ "\$i" == http* ]]; then
        url="\$i"
    fi
    prev="\$i"
done
# Write a minimal valid zip (PK magic + padding)
printf '\\x50\\x4b\\x05\\x06\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00' > "\${output_file}"
exit 0
EOF
    chmod +x "${MOCK_BIN}/curl"
}

# Create a mock 'curl' that always fails (returns non-zero exit)
make_mock_curl_fail() {
    cat > "${MOCK_BIN}/curl" << 'EOF'
#!/bin/bash
# Simulate curl --fail returning non-zero for HTTP errors
echo "curl: (22) The requested URL returned error: 404" >&2
exit 22
EOF
    chmod +x "${MOCK_BIN}/curl"
}

# Create a mock 'curl' that writes HTML (404 page) to output but exits 0
# This simulates old-style curl without --fail that silently saves error pages
make_mock_curl_html() {
    cat > "${MOCK_BIN}/curl" << 'EOF'
#!/bin/bash
output_file=""
for i in "$@"; do
    if [ "$prev" = "-o" ]; then
        output_file="$i"
    fi
    prev="$i"
done
# Write a fake 404 HTML page
echo '<html><body><h1>404 Not Found</h1></body></html>' > "${output_file}"
exit 0
EOF
    chmod +x "${MOCK_BIN}/curl"
}

# Create a mock 'file' command that identifies all files as Mach-O
make_mock_file_macho() {
    cat > "${MOCK_BIN}/file" << 'EOF'
#!/bin/bash
echo "Mach-O 64-bit dynamically linked shared library arm64"
EOF
    chmod +x "${MOCK_BIN}/file"
}

# Create a mock 'file' command that identifies files as HTML/text (corrupt)
make_mock_file_corrupt() {
    cat > "${MOCK_BIN}/file" << 'EOF'
#!/bin/bash
echo "HTML document text"
EOF
    chmod +x "${MOCK_BIN}/file"
}

# Create a mock 'codesign' that always succeeds silently
make_mock_codesign() {
    cat > "${MOCK_BIN}/codesign" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${MOCK_BIN}/codesign"
}

# Create a mock 'vtool' that always succeeds silently
make_mock_vtool() {
    cat > "${MOCK_BIN}/vtool" << 'EOF'
#!/bin/bash
if [[ "$*" == *"-show-build"* ]]; then
    echo "    sdk 14.0"
else
    exit 0
fi
EOF
    chmod +x "${MOCK_BIN}/vtool"
}

# Create a mock 'lipo' that copies input to output
make_mock_lipo() {
    cat > "${MOCK_BIN}/lipo" << 'EOF'
#!/bin/bash
# lipo -create <input> -output <output>
input="" output=""
prev=""
for i in "$@"; do
    case "$prev" in
        -output) output="$i" ;;
        -create) input="$i" ;;
    esac
    prev="$i"
done
cp "$input" "$output"
EOF
    chmod +x "${MOCK_BIN}/lipo"
}

# Create a mock 'unzip' that creates a fake .dylib from each zip
make_mock_unzip() {
    local modules_dir="$1"
    local platform="${2:-ios}"
    mkdir -p "${modules_dir}"
    cat > "${MOCK_BIN}/unzip" << UNZIPEOF
#!/bin/bash
# Mock unzip: create a fake dylib for each zip processed
zip_file=""
dest_dir="${modules_dir}"
for i in "\$@"; do
    if [[ "\$i" == *.zip ]]; then
        zip_file="\$i"
    fi
    if [ "\$prev" = "-d" ]; then
        dest_dir="\$i"
    fi
    prev="\$i"
done
if [ -n "\$zip_file" ]; then
    base=\$(basename "\$zip_file" .zip)
    # Write a minimal Mach-O header (magic bytes for arm64)
    printf '\\xcf\\xfa\\xed\\xfe' > "\${dest_dir}/\${base}_libretro_${platform}.dylib"
fi
exit 0
UNZIPEOF
    chmod +x "${MOCK_BIN}/unzip"
}
