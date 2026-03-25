#!/usr/bin/env bash
# audit_localization.sh — Localization coverage audit for Provenance
#
# Usage:  Scripts/audit_localization.sh [REPO_ROOT]
# Output: Summary printed to stdout; details written to /tmp/localization_audit/
#
# Part of #2862 / #2868

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$(dirname "$SCRIPT_DIR")}"
OUT_DIR="${TMPDIR:-/tmp}/localization_audit"

mkdir -p "$OUT_DIR"

# ─── Helpers ─────────────────────────────────────────────────────────────────

hr() { printf '%0.s─' {1..72}; echo; }

count_grep() {
    # count_grep <pattern> <dir> [glob-expr]
    local pattern="$1" dir="$2"
    local globs=("${@:3}")
    local total=0
    if [ "${#globs[@]}" -eq 0 ]; then
        globs=("*.swift" "*.m" "*.mm")
    fi
    for g in "${globs[@]}"; do
        local n
        n=$(grep -rl "$pattern" --include="$g" "$dir" 2>/dev/null | wc -l)
        total=$((total + n))
    done
    echo "$total"
}

count_grep_lines() {
    local pattern="$1" dir="$2"
    local globs=("${@:3}")
    local total=0
    if [ "${#globs[@]}" -eq 0 ]; then
        globs=("*.swift" "*.m" "*.mm")
    fi
    for g in "${globs[@]}"; do
        local n
        n=$(grep -r "$pattern" --include="$g" "$dir" 2>/dev/null | wc -l)
        total=$((total + n))
    done
    echo "$total"
}

strings_key_count() {
    # Count key = value; lines in a .strings file
    local f="$1"
    [ -f "$f" ] || { echo 0; return; }
    grep -c '^"' "$f" 2>/dev/null || echo 0
}

# ─── Source tree roots ───────────────────────────────────────────────────────

PVUI_DIR="$REPO_ROOT/PVUI"
PROVENANCE_DIR="$REPO_ROOT/Provenance"
PROVENANCETV_DIR="$REPO_ROOT/ProvenanceTV"
PV_DIRS=("$PVUI_DIR" "$PROVENANCE_DIR" "$PROVENANCETV_DIR")

# Add any PV* top-level module dirs (but skip Cores, which are upstreams)
for d in "$REPO_ROOT"/PV*/; do
    [ -d "$d" ] && PV_DIRS+=("$d")
done

# ─── 1. Hardcoded SwiftUI Text("…") ─────────────────────────────────────────

echo ""
hr
echo "  PROVENANCE LOCALIZATION AUDIT"
printf "  Generated: %s\n" "$(date -u '+%Y-%m-%d %H:%M UTC')"
echo "  Repo:       $REPO_ROOT"
hr
echo ""

SWIFTUI_TEXT_LINES=0
SWIFTUI_TEXT_FILES=0

echo "=== 1. Hardcoded SwiftUI Text(\"…\") calls ==="
echo ""

for d in "${PV_DIRS[@]}"; do
    [ -d "$d" ] || continue
    lines=$(grep -r 'Text("' --include="*.swift" "$d" 2>/dev/null | wc -l)
    files=$(grep -rl 'Text("' --include="*.swift" "$d" 2>/dev/null | wc -l)
    if [ "$lines" -gt 0 ]; then
        module="$(basename "$d")"
        printf "  %-40s %4d occurrences in %3d files\n" "$module" "$lines" "$files"
        SWIFTUI_TEXT_LINES=$((SWIFTUI_TEXT_LINES + lines))
        SWIFTUI_TEXT_FILES=$((SWIFTUI_TEXT_FILES + files))
    fi
done

echo ""
printf "  TOTAL hardcoded Text(\"…\"): %d occurrences across %d files\n" \
    "$SWIFTUI_TEXT_LINES" "$SWIFTUI_TEXT_FILES"

# Dump full list to file
grep -rn 'Text("' --include="*.swift" "${PV_DIRS[@]}" 2>/dev/null \
    > "$OUT_DIR/hardcoded_swiftui_text.txt" || true
echo "  → Full list: $OUT_DIR/hardcoded_swiftui_text.txt"

echo ""

# ─── 2. NSLocalizedString usage ─────────────────────────────────────────────

echo "=== 2. NSLocalizedString / LocalizedStringKey usage ==="
echo ""

NLS_LINES=0
NLS_FILES=0

for d in "${PV_DIRS[@]}"; do
    [ -d "$d" ] || continue
    lines=$(grep -r 'NSLocalizedString\|LocalizedStringKey' \
        --include="*.swift" --include="*.m" --include="*.mm" \
        "$d" 2>/dev/null | wc -l)
    files=$(grep -rl 'NSLocalizedString\|LocalizedStringKey' \
        --include="*.swift" --include="*.m" --include="*.mm" \
        "$d" 2>/dev/null | wc -l)
    if [ "$lines" -gt 0 ]; then
        module="$(basename "$d")"
        printf "  %-40s %4d occurrences in %3d files\n" "$module" "$lines" "$files"
        NLS_LINES=$((NLS_LINES + lines))
        NLS_FILES=$((NLS_FILES + files))
    fi
done

echo ""
printf "  TOTAL NSLocalizedString: %d occurrences across %d files\n" \
    "$NLS_LINES" "$NLS_FILES"

grep -rn 'NSLocalizedString\|LocalizedStringKey' \
    --include="*.swift" --include="*.m" --include="*.mm" \
    "${PV_DIRS[@]}" 2>/dev/null \
    > "$OUT_DIR/nslocalizedstring_usage.txt" || true
echo "  → Full list: $OUT_DIR/nslocalizedstring_usage.txt"

echo ""

# ─── 3. Existing .strings file coverage ─────────────────────────────────────

echo "=== 3. Existing .strings files ==="
echo ""

EN_STRINGS="$PROVENANCE_DIR/Resources/en.lproj/Strings.strings"
EN_LOCALIZABLE="$PVUI_DIR/Sources/PVSwiftUI/Resources/en.lproj/Localizable.strings"

EN_STRINGS_COUNT=$(strings_key_count "$EN_STRINGS")
EN_LOCALIZABLE_COUNT=$(strings_key_count "$EN_LOCALIZABLE")
TOTAL_EN_KEYS=$((EN_STRINGS_COUNT + EN_LOCALIZABLE_COUNT))

printf "  %-55s  %3d keys\n" "Provenance/Resources/en.lproj/Strings.strings" "$EN_STRINGS_COUNT"
printf "  %-55s  %3d keys\n" "PVUI/.../en.lproj/Localizable.strings" "$EN_LOCALIZABLE_COUNT"
echo ""
printf "  TOTAL English baseline keys: %d\n" "$TOTAL_EN_KEYS"

echo ""
echo "=== 4. Non-English translation status ==="
echo ""

LANGS=("nl" "ja" "zh-Hans" "it" "ru" "es" "pt-BR")

printf "  %-10s  %-12s  %-12s  %-12s  %s\n" \
    "Language" "Strings.str" "Same as EN?" "Translated?" "Notes"
printf "  %-10s  %-12s  %-12s  %-12s  %s\n" \
    "--------" "-----------" "-----------" "-----------" "-----"

for lang in "${LANGS[@]}"; do
    f="$PROVENANCE_DIR/Resources/${lang}.lproj/Strings.strings"
    if [ ! -f "$f" ]; then
        printf "  %-10s  %-12s  %-12s  %-12s\n" "$lang" "MISSING" "-" "NO"
        continue
    fi
    key_count=$(strings_key_count "$f")
    diff_lines=$(diff "$f" "$EN_STRINGS" 2>/dev/null | grep '^[<>]' | wc -l)
    if [ "$diff_lines" -eq 0 ]; then
        same="YES (copy)"
        translated="NO"
    else
        same="no"
        translated="YES"
    fi
    printf "  %-10s  %-12d  %-12s  %-12s\n" "$lang" "$key_count" "$same" "$translated"
done

echo ""

# ─── 5. Gap analysis ─────────────────────────────────────────────────────────

echo "=== 5. Gap analysis ==="
echo ""

# Extract keys used in NSLocalizedString calls
grep -rh 'NSLocalizedString(' \
    --include="*.swift" --include="*.m" --include="*.mm" \
    "${PV_DIRS[@]}" 2>/dev/null \
    | grep -oE 'NSLocalizedString\("[^"]+' \
    | sed 's/NSLocalizedString("//g' \
    | sort -u \
    > "$OUT_DIR/used_nls_keys.txt" || true

NLS_UNIQUE_KEYS=$(wc -l < "$OUT_DIR/used_nls_keys.txt")

# Extract keys defined in EN strings files
{
  grep -h '^"' "$EN_STRINGS" 2>/dev/null | grep -oE '^"[^"]+"' | tr -d '"'
  grep -h '^"' "$EN_LOCALIZABLE" 2>/dev/null | grep -oE '^"[^"]+"' | tr -d '"'
} | sort -u > "$OUT_DIR/defined_en_keys.txt" || true

DEFINED_EN_KEYS=$(wc -l < "$OUT_DIR/defined_en_keys.txt")

# Keys used but not defined
comm -23 \
    <(sort "$OUT_DIR/used_nls_keys.txt") \
    <(sort "$OUT_DIR/defined_en_keys.txt") \
    > "$OUT_DIR/missing_keys.txt" || true

MISSING_KEYS=$(wc -l < "$OUT_DIR/missing_keys.txt")

printf "  NSLocalizedString unique keys in use:   %3d\n" "$NLS_UNIQUE_KEYS"
printf "  Keys defined in EN strings files:       %3d\n" "$DEFINED_EN_KEYS"
printf "  Keys used but NOT in strings files:     %3d\n" "$MISSING_KEYS"
echo ""
echo "  Missing keys (used in code, absent from .strings):"
if [ "$MISSING_KEYS" -gt 0 ]; then
    while IFS= read -r key; do
        printf "    - %s\n" "$key"
    done < "$OUT_DIR/missing_keys.txt"
else
    echo "    (none)"
fi

echo ""

# ─── 6. Summary table ────────────────────────────────────────────────────────

hr
echo "  SUMMARY"
hr
echo ""
printf "  %-45s  %6d\n" "Hardcoded Text(\"…\") calls (SwiftUI)" "$SWIFTUI_TEXT_LINES"
printf "  %-45s  %6d\n" "Files with hardcoded Text(\"…\")" "$SWIFTUI_TEXT_FILES"
printf "  %-45s  %6d\n" "NSLocalizedString / LocalizedStringKey calls" "$NLS_LINES"
printf "  %-45s  %6d\n" "English baseline keys (all .strings files)" "$TOTAL_EN_KEYS"
printf "  %-45s  %6d\n" "NSLocalizedString keys used in code" "$NLS_UNIQUE_KEYS"
printf "  %-45s  %6d\n" "Keys missing from EN strings files" "$MISSING_KEYS"
echo ""

if [ "$SWIFTUI_TEXT_LINES" -gt 0 ]; then
    coverage=$(( 100 - (SWIFTUI_TEXT_LINES * 100 / (SWIFTUI_TEXT_LINES + NLS_LINES + 1)) ))
    printf "  Estimated i18n wrapping coverage:          ~%d%%\n" "$coverage"
    echo "  (strings wrapped via NSLocalizedString / LocalizedStringKey vs. hardcoded)"
fi

echo ""
echo "  Output files:"
echo "    $OUT_DIR/hardcoded_swiftui_text.txt  — all hardcoded Text(\"…\") with file/line"
echo "    $OUT_DIR/nslocalizedstring_usage.txt — all NSLocalizedString usages"
echo "    $OUT_DIR/used_nls_keys.txt            — unique keys extracted from code"
echo "    $OUT_DIR/defined_en_keys.txt          — keys present in EN strings files"
echo "    $OUT_DIR/missing_keys.txt             — keys used in code but absent from files"
echo ""
hr
