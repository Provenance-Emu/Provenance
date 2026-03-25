#!/usr/bin/env bash
# audit_localization.sh — Localization coverage audit for Provenance
#
# Usage:  Scripts/audit_localization.sh [REPO_ROOT]
# Output: Summary printed to stdout; details written to ${TMPDIR:-/tmp}/localization_audit/
#
# Part of #2862 / #2868

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$(dirname "$SCRIPT_DIR")}"
OUT_DIR="${TMPDIR:-/tmp}/localization_audit"

mkdir -p "$OUT_DIR"

# ─── Helpers ─────────────────────────────────────────────────────────────────

hr() { printf '%0.s─' {1..72}; echo; }

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
EXTENSIONS_DIR="$REPO_ROOT/Extensions"
WATCHAPP_DIR="$REPO_ROOT/Provenance Mini Watch App"

# Build PV_DIRS list while avoiding duplicates, without Bash 4 associative arrays
PV_DIRS=()
PV_DIR_REALPATHS=()

add_pv_dir() {
    local dir="$1"
    [ -d "$dir" ] || return 0

    local real
    real="$(realpath "$dir" 2>/dev/null || echo "$dir")"

    local existing
    for existing in ${PV_DIR_REALPATHS[@]+"${PV_DIR_REALPATHS[@]}"}; do
        if [ "$existing" = "$real" ]; then
            return 0
        fi
    done

    PV_DIRS+=("$dir")
    PV_DIR_REALPATHS+=("$real")
}

add_pv_dir "$PVUI_DIR"
add_pv_dir "$PROVENANCE_DIR"
add_pv_dir "$PROVENANCETV_DIR"
add_pv_dir "$EXTENSIONS_DIR"
add_pv_dir "$WATCHAPP_DIR"

# Add any PV* top-level module dirs (but skip Cores, which are upstreams)
for d in "$REPO_ROOT"/PV*/; do
    if [ -d "$d" ]; then
        add_pv_dir "$d"
    fi
done
unset d PV_DIR_REALPATHS

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

echo "=== 1. SwiftUI Text(\"…\") calls (uses LocalizedStringKey — verify keys exist in .strings) ==="
echo ""

for d in "${PV_DIRS[@]}"; do
    [ -d "$d" ] || continue
    lines=$({ grep -r 'Text("' --include="*.swift" "$d" 2>/dev/null || true; } | wc -l)
    files=$({ grep -rl 'Text("' --include="*.swift" "$d" 2>/dev/null || true; } | wc -l)
    if [ "$lines" -gt 0 ]; then
        module="$(basename "$d")"
        printf "  %-40s %4d occurrences in %3d files\n" "$module" "$lines" "$files"
        SWIFTUI_TEXT_LINES=$((SWIFTUI_TEXT_LINES + lines))
        SWIFTUI_TEXT_FILES=$((SWIFTUI_TEXT_FILES + files))
    fi
done

echo ""
printf "  TOTAL SwiftUI Text(\"…\") (LocalizedStringKey): %d occurrences across %d files\n" \
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
    lines=$({ grep -rE 'NSLocalizedString|LocalizedStringKey' \
        --include="*.swift" --include="*.m" --include="*.mm" \
        "$d" 2>/dev/null || true; } | wc -l)
    files=$({ grep -rlE 'NSLocalizedString|LocalizedStringKey' \
        --include="*.swift" --include="*.m" --include="*.mm" \
        "$d" 2>/dev/null || true; } | wc -l)
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

{ grep -rnE 'NSLocalizedString|LocalizedStringKey' \
    --include="*.swift" --include="*.m" --include="*.mm" \
    "${PV_DIRS[@]}" 2>/dev/null || true; } \
    > "$OUT_DIR/nslocalizedstring_usage.txt"
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
    diff_lines=$({ diff "$f" "$EN_STRINGS" 2>/dev/null || true; } | { grep -c '^[<>]' || true; })
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

# Extract keys used in NSLocalizedString calls (Swift and ObjC forms).
# The pattern handles optional whitespace between '(' and the string literal
# so both NSLocalizedString("key" and NSLocalizedString( @"key" are matched.
grep -rh 'NSLocalizedString(' \
    --include="*.swift" --include="*.m" --include="*.mm" \
    "${PV_DIRS[@]}" 2>/dev/null \
    | grep -oE 'NSLocalizedString\([[:space:]]*@?"[^"]+' \
    | sed 's/NSLocalizedString([[:space:]]*@\{0,1\}"//g' \
    | sort -u \
    > "$OUT_DIR/used_nls_keys.txt" || true

NLS_UNIQUE_KEYS=$(wc -l < "$OUT_DIR/used_nls_keys.txt")

# Extract keys from SwiftUI Text("…") calls (LocalizedStringKey), excluding
# interpolated strings (those containing '\(') which can't map to .strings keys.
grep -rh 'Text("' \
    --include="*.swift" \
    "${PV_DIRS[@]}" 2>/dev/null \
    | grep -oE 'Text\("[^"]+' \
    | sed 's/Text("//g' \
    | grep -v '\\(' \
    | sort -u \
    > "$OUT_DIR/used_text_keys.txt" || true

TEXT_UNIQUE_KEYS=$(wc -l < "$OUT_DIR/used_text_keys.txt")

# Combine all keys used in code
sort -u "$OUT_DIR/used_nls_keys.txt" "$OUT_DIR/used_text_keys.txt" \
    > "$OUT_DIR/all_used_keys.txt" || true

ALL_UNIQUE_KEYS=$(wc -l < "$OUT_DIR/all_used_keys.txt")

# Extract keys defined in EN strings files
{
  grep -h '^"' "$EN_STRINGS" 2>/dev/null | grep -oE '^"[^"]+"' | tr -d '"'
  grep -h '^"' "$EN_LOCALIZABLE" 2>/dev/null | grep -oE '^"[^"]+"' | tr -d '"'
} | sort -u > "$OUT_DIR/defined_en_keys.txt" || true

DEFINED_EN_KEYS=$(wc -l < "$OUT_DIR/defined_en_keys.txt")

# Keys used but not defined
comm -23 \
    <(sort "$OUT_DIR/all_used_keys.txt") \
    <(sort "$OUT_DIR/defined_en_keys.txt") \
    > "$OUT_DIR/missing_keys.txt" || true

MISSING_KEYS=$(wc -l < "$OUT_DIR/missing_keys.txt")

printf "  NSLocalizedString unique keys in use:   %3d\n" "$NLS_UNIQUE_KEYS"
printf "  SwiftUI Text(\"…\") unique keys in use:   %3d\n" "$TEXT_UNIQUE_KEYS"
printf "  Total unique keys in code:              %3d\n" "$ALL_UNIQUE_KEYS"
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
printf "  %-45s  %6d\n" "SwiftUI Text(\"…\") calls (LocalizedStringKey)" "$SWIFTUI_TEXT_LINES"
printf "  %-45s  %6d\n" "Files with Text(\"…\") calls" "$SWIFTUI_TEXT_FILES"
printf "  %-45s  %6d\n" "NSLocalizedString / LocalizedStringKey calls" "$NLS_LINES"
printf "  %-45s  %6d\n" "English baseline keys (all .strings files)" "$TOTAL_EN_KEYS"
printf "  %-45s  %6d\n" "Unique keys in code (NLS + Text)" "$ALL_UNIQUE_KEYS"
printf "  %-45s  %6d\n" "Keys missing from EN strings files" "$MISSING_KEYS"
echo ""

# Both Text("…") (LocalizedStringKey) and NSLocalizedString are localized
# mechanisms, so comparing them to each other is not meaningful. Instead,
# report what fraction of all unique code keys have a matching .strings entry.
if [ "$ALL_UNIQUE_KEYS" -gt 0 ]; then
    covered_keys=$(( ALL_UNIQUE_KEYS - MISSING_KEYS ))
    coverage=$(( covered_keys * 100 / ALL_UNIQUE_KEYS ))
    printf "  Keys with EN .strings coverage:            ~%d%%  (%d / %d)\n" \
        "$coverage" "$covered_keys" "$ALL_UNIQUE_KEYS"
    echo "  (unique keys referenced in code that have a matching entry in .strings files)"
fi

echo ""
echo "  Output files:"
echo "    $OUT_DIR/hardcoded_swiftui_text.txt  — all Text(\"…\") calls with file/line"
echo "    $OUT_DIR/nslocalizedstring_usage.txt — all NSLocalizedString usages"
echo "    $OUT_DIR/used_nls_keys.txt            — unique NSLocalizedString keys"
echo "    $OUT_DIR/used_text_keys.txt           — unique SwiftUI Text(\"…\") keys (no interpolated strings)"
echo "    $OUT_DIR/all_used_keys.txt            — all unique keys combined"
echo "    $OUT_DIR/defined_en_keys.txt          — keys present in EN strings files"
echo "    $OUT_DIR/missing_keys.txt             — keys used in code but absent from files"
echo ""
hr
