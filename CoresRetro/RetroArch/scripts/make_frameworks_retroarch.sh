#!/bin/bash
# NOTE: Xcode build phases invoke scripts via /bin/sh, which ignores the shebang.
# This guard re-execs with bash so bash-specific syntax (pattern replacement, arrays,
# etc.) works even when the build phase calls: /bin/sh ".../make_frameworks_retroarch.sh"
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

set -uo pipefail

# Sanity: fail fast if essential bash features are missing (e.g. bash 3.2 without
# associative arrays). We only need pattern replacement (${var//./_}), which works
# on bash 3.2+, but guard against truly ancient shells.
if ! (x="a_b"; test "${x//_/.}" = "a.b") 2>/dev/null; then
    echo "MakeFrameworks: ERROR — shell lacks required pattern-replacement support" >&2
    echo "MakeFrameworks: BASH_VERSION=${BASH_VERSION:-unset}, shell=$0" >&2
    exit 1
fi

# Function to print usage
print_usage() {
    echo "Usage: $0 <source_folder> [bundle_identifier_prefix] [output_folder]"
    echo "If bundle_identifier_prefix is not provided, it defaults to 'org.provenance-emu'"
    echo "If output_folder is not provided, it defaults to the current directory"
}

# Check if the minimum number of arguments is provided
if [ "$#" -lt 1 ]; then
    print_usage
    exit 1
fi

# Prefer the expanded name, if available (unset outside Xcode → use empty default for set -u).
CODE_SIGN_IDENTITY_FOR_ITEMS="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [ -z "${CODE_SIGN_IDENTITY_FOR_ITEMS}" ] ; then
    CODE_SIGN_IDENTITY_FOR_ITEMS="${CODE_SIGN_IDENTITY:-}"
fi

echo "Identity:"
echo "${CODE_SIGN_IDENTITY_FOR_ITEMS}"

BASE_DIR="$1"
MODULES_DIR="$BASE_DIR/modules"

# Read local core names from cores.yml early (before platform alignment)
# so mixed-platform checks can exclude locally-built dylibs.
# Store as colon-delimited string to avoid bash 3.2 empty-array issues with set -u.
_EARLY_LOCAL_CORES=""
_EARLY_CORES_YML="${BASE_DIR}/scripts/cores.yml"
if [ -f "${_EARLY_CORES_YML}" ]; then
    _EARLY_LOCAL_CORES=$(awk '
        /^[[:space:]]*- name:/ { name=$NF; gsub(/["'"'"']/, "", name) }
        /^[[:space:]]*local:[[:space:]]*true/ { print name }
    ' "${_EARLY_CORES_YML}" | paste -sd: -)
fi

# is_early_local_dylib <basename> — true if dylib belongs to a local core
_is_early_local_dylib() {
    local base="$1"
    [ -z "$_EARLY_LOCAL_CORES" ] && return 1
    local IFS=":"
    for cn in $_EARLY_LOCAL_CORES; do
        case "$base" in ${cn}_libretro*) return 0 ;; esac
    done
    return 1
}

# Run Script phases always receive PLATFORM_NAME; PLATFORM_FAMILY_NAME is sometimes unset
# (or inconsistent) — which left BASE_DIR/SUFFIX unset and made dylib_matches_current_platform
# reject every *_tvos.dylib / *_ios.dylib. Prefer PLATFORM_NAME like get-modules.sh.
MF_PLATFORM_FAMILY="${PLATFORM_FAMILY_NAME:-}"
case "${PLATFORM_NAME:-}" in
	appletvos|appletvsimulator)
		MF_PLATFORM_FAMILY="tvOS"
		;;
	iphoneos|iphonesimulator)
		MF_PLATFORM_FAMILY="iOS"
		;;
	macosx)
		MF_PLATFORM_FAMILY="macOS"
		;;
esac

# When modules/ contains only one platform suffix, align MF with that tree — Xcode sometimes
# leaves PLATFORM_FAMILY_NAME=iOS while building tvOS (or omits env), which skips every *_tvos.dylib.
# When PLATFORM_NAME clearly targets one OS but modules/ only has the other suffix, fail with a direct message.
align_or_resolve_platform() {
	local n_ios n_tvos pn
	pn="${PLATFORM_NAME:-}"
	if [ ! -d "$MODULES_DIR" ]; then
		return 0
	fi
	# Count non-local dylibs per platform (local cores legitimately have both)
	n_ios=0
	n_tvos=0
	for _dyl in $(find "$MODULES_DIR" -maxdepth 1 -type f -name '*_ios.dylib' 2>/dev/null); do
		_is_early_local_dylib "$(basename "$_dyl")" || n_ios=$((n_ios + 1))
	done
	for _dyl in $(find "$MODULES_DIR" -maxdepth 1 -type f -name '*_tvos.dylib' 2>/dev/null); do
		_is_early_local_dylib "$(basename "$_dyl")" || n_tvos=$((n_tvos + 1))
	done
	if [ "${n_ios}" -gt 0 ] && [ "${n_tvos}" -gt 0 ]; then
		echo "MakeFrameworks: ERROR — modules/ contains both *_ios.dylib and *_tvos.dylib (excluding local cores). Remove stale dylibs or re-run get-modules.sh for this platform." >&2
		exit 1
	fi
	case "$pn" in
		appletvos|appletvsimulator)
			if [ "${n_tvos}" -eq 0 ] && [ "${n_ios}" -gt 0 ]; then
				echo "MakeFrameworks: ERROR — building for tvOS but modules/ only has *_ios.dylib. Run get-modules for tvOS or remove stale iOS dylibs." >&2
				exit 1
			fi
			if [ "${n_tvos}" -gt 0 ] && [ "${n_ios}" -eq 0 ] && [ "$MF_PLATFORM_FAMILY" != "tvOS" ]; then
				echo "MakeFrameworks: modules/ has only *_tvos.dylib — forcing tvOS (was MF=${MF_PLATFORM_FAMILY:-unset}, PLATFORM_FAMILY_NAME=${PLATFORM_FAMILY_NAME:-unset})" >&2
				MF_PLATFORM_FAMILY="tvOS"
			fi
			;;
		iphoneos|iphonesimulator)
			if [ "${n_ios}" -eq 0 ] && [ "${n_tvos}" -gt 0 ]; then
				echo "MakeFrameworks: ERROR — building for iOS but modules/ only has *_tvos.dylib. Run get-modules for iOS or remove stale tvOS dylibs." >&2
				exit 1
			fi
			if [ "${n_ios}" -gt 0 ] && [ "${n_tvos}" -eq 0 ] && [ "$MF_PLATFORM_FAMILY" != "iOS" ]; then
				echo "MakeFrameworks: modules/ has only *_ios.dylib — forcing iOS (was MF=${MF_PLATFORM_FAMILY:-unset}, PLATFORM_FAMILY_NAME=${PLATFORM_FAMILY_NAME:-unset})" >&2
				MF_PLATFORM_FAMILY="iOS"
			fi
			;;
	esac
	# Some Run Script invocations omit PLATFORM_NAME; PLATFORM_FAMILY_NAME can still be wrong for the destination.
	if [ -z "$pn" ]; then
		if [ "${n_tvos}" -gt 0 ] && [ "${n_ios}" -eq 0 ] && [ "$MF_PLATFORM_FAMILY" = "iOS" ]; then
			echo "MakeFrameworks: modules/ only *_tvos.dylib but PLATFORM_NAME unset and MF=iOS — using tvOS" >&2
			MF_PLATFORM_FAMILY="tvOS"
		elif [ "${n_ios}" -gt 0 ] && [ "${n_tvos}" -eq 0 ] && [ "$MF_PLATFORM_FAMILY" = "tvOS" ]; then
			echo "MakeFrameworks: modules/ only *_ios.dylib but PLATFORM_NAME unset and MF=tvOS — using iOS" >&2
			MF_PLATFORM_FAMILY="iOS"
		fi
	fi
	if [ -z "${MF_PLATFORM_FAMILY:-}" ]; then
		if [ "${n_tvos}" -gt 0 ] && [ "${n_ios}" -eq 0 ]; then
			echo "MakeFrameworks: PLATFORM_NAME unset/unknown; inferring tvOS from modules/ (only *_tvos.dylib)" >&2
			MF_PLATFORM_FAMILY="tvOS"
		elif [ "${n_ios}" -gt 0 ] && [ "${n_tvos}" -eq 0 ]; then
			echo "MakeFrameworks: PLATFORM_NAME unset/unknown; inferring iOS from modules/ (only *_ios.dylib)" >&2
			MF_PLATFORM_FAMILY="iOS"
		fi
	fi
}

case "${PLATFORM_NAME:-}" in
	macosx) ;;
	*) align_or_resolve_platform ;;
esac

echo "MakeFrameworks: PLATFORM_NAME=${PLATFORM_NAME:-unset} PLATFORM_FAMILY_NAME=${PLATFORM_FAMILY_NAME:-unset} -> MF_PLATFORM_FAMILY=${MF_PLATFORM_FAMILY:-unset}"

if [ "$MF_PLATFORM_FAMILY" = "tvOS" ] ; then
    SUFFIX="_tvos"
    PLATFORM="tvos"
    DEPLOYMENT_TARGET="${TVOS_DEPLOYMENT_TARGET:-}"
elif [ "$MF_PLATFORM_FAMILY" = "iOS" ] ; then
    SUFFIX="_ios"
    PLATFORM="ios"
    DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-}"
elif [ "$MF_PLATFORM_FAMILY" = "macOS" ] ; then
    SUFFIX=
    PLATFORM=
    DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-}"
else
    echo "MakeFrameworks: ERROR — Unrecognized platform (PLATFORM_NAME=${PLATFORM_NAME:-} PLATFORM_FAMILY_NAME=${PLATFORM_FAMILY_NAME:-})" >&2
    exit 1
fi

if [ -n "${BUILT_PRODUCTS_DIR:-}" ] && [ -n "${FRAMEWORKS_FOLDER_PATH:-}" ] ; then
    OUTDIR="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
else
    OUTDIR="$BASE_DIR"/Frameworks
fi

# Echo the directory that will be created next
echo "MakeFrameworks: Creating directory: $OUTDIR"

mkdir -p "$OUTDIR"

# Optional filter list: if a URL list file is passed as $2, only process dylibs
# whose basenames appear in that file. This allows build variants (AppStore vs XL)
# to share the same modules/ directory without bloating the app bundle.
FILTER_LIST="${2:-}"
FILTER_NAMES=""
if [ -n "$FILTER_LIST" ] && [ -f "$FILTER_LIST" ]; then
    # Extract dylib basenames from URLs (strip path and .zip suffix)
    FILTER_NAMES=$(grep -v '^#' "$FILTER_LIST" | sed 's|.*/||' | sed 's/\.zip$//' | sort -u)
    echo "MakeFrameworks: Filtering dylibs using $(echo "$FILTER_NAMES" | wc -l | tr -d ' ') entries from $FILTER_LIST"
fi

# Locally-built dylibs that are never downloaded from the buildbot but should
# always be included in every build variant.  Must match the patterns used by
# get-modules.sh so they are never purged OR filtered out.
LOCAL_DYLIB_PATTERNS=( "*-jitless*" )

# Read local core names from cores.yml (cores with "local: true").
# These bypass the filter list so they're included in all build variants.
LOCAL_CORES_FROM_YML=()
CORES_YML_PATH="${BASE_DIR}/scripts/cores.yml"
if [ -f "${CORES_YML_PATH}" ]; then
    _local_tmp=$(mktemp "${TMPDIR:-/tmp}/local_cores.XXXXXX")
    awk '
        /^[[:space:]]*- name:/ { name=$NF; gsub(/["'"'"']/, "", name) }
        /^[[:space:]]*local:[[:space:]]*true/ { print name }
    ' "${CORES_YML_PATH}" > "$_local_tmp"
    while IFS= read -r _local_core; do
        [ -n "$_local_core" ] && LOCAL_CORES_FROM_YML+=("$_local_core")
    done < "$_local_tmp"
    rm -f "$_local_tmp"
fi
unset _local_core _local_tmp
if [ "${#LOCAL_CORES_FROM_YML[@]}" -gt 0 ]; then
    echo "MakeFrameworks: local cores from cores.yml (bypass filter): ${LOCAL_CORES_FROM_YML[*]}"
fi

# is_local_core <dylib_basename> — returns 0 if this dylib belongs to a local core
is_local_core() {
    local base="$1"
    local pat core_name
    for pat in "${LOCAL_DYLIB_PATTERNS[@]}"; do
        case "$base" in ${pat}*) return 0 ;; esac
    done
    for core_name in "${LOCAL_CORES_FROM_YML[@]}"; do
        case "$base" in
            ${core_name}_libretro*.dylib) return 0 ;;
        esac
    done
    return 1
}

# Count input dylibs
DYLIB_COUNT=$(find "$BASE_DIR"/modules -maxdepth 1 -type f -regex '.*libretro.*\.dylib$' 2>/dev/null | wc -l | tr -d ' ')
echo "MakeFrameworks: Found ${DYLIB_COUNT} input dylibs in $BASE_DIR/modules/"

if [ "${DYLIB_COUNT}" -eq 0 ]; then
    echo "MakeFrameworks: ERROR — No dylibs found in $BASE_DIR/modules/" >&2
    echo "MakeFrameworks: ERROR — Run get-modules.sh first, or check that downloads succeeded." >&2
    echo "MakeFrameworks: ERROR — Cores will NOT load at runtime!" >&2
    # Exit non-zero to fail the Xcode build phase
    exit 1
fi

FW_COUNT=0
FW_FAIL=0
FW_SKIP=0

# Cache file tracks which dylibs have already been processed.
# Format: one line per dylib with "filename:md5hash"
CACHE_FILE="${BASE_DIR}/modules/.fw_cache_${PLATFORM:-unknown}"

# Temp file to build new cache (bash 3.2 has no associative arrays)
NEW_CACHE_FILE="${CACHE_FILE}.tmp"
: > "$NEW_CACHE_FILE"

# cached_hash <filename> — prints cached hash or empty string
cached_hash() {
    if [ -f "$CACHE_FILE" ]; then
        grep "^${1}:" "$CACHE_FILE" 2>/dev/null | head -1 | cut -d: -f2
    fi
}

# True if dylib basename is allowed by urls filter. Zip URLs use platform-neutral
# names (e.g. fmsx_libretro.dylib) while buildbot archives contain *_ios / *_tvos dylibs.
dylib_matches_filter_list() {
    local b="$1"
    [ -z "$FILTER_NAMES" ] && return 0
    echo "$FILTER_NAMES" | grep -qx "$b" && return 0
    case "$b" in
        *_ios.dylib)
            local stem="${b%.dylib}"
            stem="${stem%_ios}"
            echo "$FILTER_NAMES" | grep -qx "${stem}.dylib" && return 0
            ;;
        *_tvos.dylib)
            local stem="${b%.dylib}"
            stem="${stem%_tvos}"
            echo "$FILTER_NAMES" | grep -qx "${stem}.dylib" && return 0
            ;;
    esac
    return 1
}

# Only consume dylibs for the Xcode destination being built. If both *_ios and *_tvos
# dylibs are present in modules/ (stale mixed tree), find order is non-deterministic and
# the wrong binary can end up in a *.libretro.framework — and orphan diagnostics explode.
dylib_matches_current_platform() {
    local b="$1"
    case "$b" in
        *_ios.dylib)
            [ "$MF_PLATFORM_FAMILY" = "iOS" ] && return 0
            return 1
            ;;
        *_tvos.dylib)
            [ "$MF_PLATFORM_FAMILY" = "tvOS" ] && return 0
            return 1
            ;;
        *)
            # Neutral names (e.g. dolphin_libretro.dylib, ppsspp_libretro.dylib)
            return 0
            ;;
    esac
}

FW_FILTER=0
for dylib in $(find "$BASE_DIR"/modules -maxdepth 1 -type f -regex '.*libretro.*\.dylib$') ; do
    DYLIB_BASE=$(basename "$dylib")

    if ! dylib_matches_current_platform "$DYLIB_BASE"; then
        FW_FILTER=$((FW_FILTER + 1))
        continue
    fi

    # Skip dylibs not in the filter list (if a filter is active),
    # but always include locally-built dylibs (LOCAL_DYLIB_PATTERNS + cores.yml local: true).
    if [ -n "$FILTER_NAMES" ]; then
        if ! is_local_core "$DYLIB_BASE" && ! dylib_matches_filter_list "$DYLIB_BASE"; then
            FW_FILTER=$((FW_FILTER + 1))
            continue
        fi
    fi

    intermediate="${DYLIB_BASE/%.dylib/}"
    if [ -n "$SUFFIX" ] ; then
        intermediate="${intermediate/%$SUFFIX/}"
    fi
    fwName="${intermediate//_/.}"
    fwDir="${OUTDIR}/${fwName}.framework"

    # Compute hash of the input dylib to detect changes
    DYLIB_HASH=$(md5 -q "$dylib" 2>/dev/null || md5sum "$dylib" | awk '{print $1}')
    echo "${DYLIB_BASE}:${DYLIB_HASH}" >> "$NEW_CACHE_FILE"

    # Skip if dylib unchanged AND framework already exists with executable
    PREV_HASH=$(cached_hash "$DYLIB_BASE")
    if [ "$PREV_HASH" = "$DYLIB_HASH" ] && \
       { [ -f "$fwDir/$fwName" ] || [ -L "$fwDir/$fwName" ]; }; then
        FW_SKIP=$((FW_SKIP + 1))
        continue
    fi

    # Validate the dylib is actually a Mach-O binary, not a corrupt/truncated file
    FILE_TYPE=$(file -b "$dylib" 2>/dev/null)
    case "$FILE_TYPE" in
        *Mach-O*|*"universal binary"*)
            ;;
        *)
            echo "MakeFrameworks: SKIPPING ${fwName} — not a Mach-O binary: ${FILE_TYPE}" >&2
            FW_FAIL=$((FW_FAIL + 1))
            continue
            ;;
    esac

    echo "MakeFrameworks: Making framework $fwName from $dylib"

    mkdir -p "$fwDir"
    if [ "$MF_PLATFORM_FAMILY" = "iOS" ] || [ "$MF_PLATFORM_FAMILY" = "tvOS" ] ; then
        build_sdk=$(vtool -show-build "$dylib" | grep sdk | awk '{print $2}')
        if ! vtool -set-build-version "${PLATFORM}" "${DEPLOYMENT_TARGET}" "${build_sdk}" -set-build-tool "$PLATFORM" ld 1115.7.3 -set-source-version 0.0 -replace -output "$dylib" "$dylib"; then
            echo "MakeFrameworks: WARNING — vtool failed for ${fwName}; build version metadata may be missing" >&2
        fi
    fi
    if ! lipo -create "$dylib" -output "$fwDir/$fwName"; then
        echo "MakeFrameworks: ERROR — lipo failed for ${fwName}" >&2
        FW_FAIL=$((FW_FAIL + 1))
        continue
    fi
    if ! sed -e "s,%CORE%,$fwName," -e "s,%BUNDLE%,$fwName," -e "s,%IDENTIFIER%,$fwName," -e "s,%OSVER%,$DEPLOYMENT_TARGET," "$BASE_DIR"/fw.tmpl > "$fwDir/Info.plist"; then
        echo "MakeFrameworks: ERROR — Info.plist creation failed for ${fwName}" >&2
        FW_FAIL=$((FW_FAIL + 1))
        continue
    fi
    if [ "$MF_PLATFORM_FAMILY" = "macOS" ] ; then
        mkdir -p "$fwDir"/Versions/A/Resources
        mv "$fwDir/$fwName" "$fwDir"/Versions/A
        mv "$fwDir"/Info.plist "$fwDir"/Versions/A/Resources
        ln -sf A "$fwDir"/Versions/Current
        ln -sf Versions/Current/Resources "$fwDir"/Resources
        ln -sf "Versions/Current/$fwName" "$fwDir/$fwName"
    fi

    # Validate the executable was created inside the framework
    if [ ! -f "$fwDir/$fwName" ] && [ ! -L "$fwDir/$fwName" ]; then
        echo "MakeFrameworks: ERROR — framework ${fwName}.framework has no executable!" >&2
        FW_FAIL=$((FW_FAIL + 1))
        continue
    fi

    echo "MakeFrameworks: signing $fwName"
    if ! codesign --force --verbose --sign "${CODE_SIGN_IDENTITY_FOR_ITEMS}" "$fwDir"; then
        echo "MakeFrameworks: ERROR — codesign failed for ${fwName}" >&2
        FW_FAIL=$((FW_FAIL + 1))
        continue
    fi
    FW_COUNT=$((FW_COUNT + 1))
done

# Write updated cache
mv "$NEW_CACHE_FILE" "$CACHE_FILE"

# Delete *.libretro.framework bundles in OUTDIR that have no matching dylib in
# modules/ (e.g. core removed from cores.yml but framework left from an old build).
EXPECTED_FW_TMP=$(mktemp)
for dylib in $(find "$BASE_DIR"/modules -maxdepth 1 -type f -regex '.*libretro.*\.dylib$') ; do
    DYLIB_BASE=$(basename "$dylib")
    if ! dylib_matches_current_platform "$DYLIB_BASE"; then
        continue
    fi
    if [ -n "$FILTER_NAMES" ]; then
        if ! is_local_core "$DYLIB_BASE" && ! dylib_matches_filter_list "$DYLIB_BASE"; then
            continue
        fi
    fi
    intermediate="${DYLIB_BASE/%.dylib/}"
    if [ -n "$SUFFIX" ] ; then
        intermediate="${intermediate/%$SUFFIX/}"
    fi
    echo "${intermediate//_/.}"
done | sort -u > "$EXPECTED_FW_TMP"

_orphan_tmp=$(mktemp "${TMPDIR:-/tmp}/orphan_fw.XXXXXX")
find "$OUTDIR" -maxdepth 1 -type d -name "*.libretro.framework" 2>/dev/null > "$_orphan_tmp"
while IFS= read -r fwdir; do
    [ -n "$fwdir" ] || continue
    [ -d "$fwdir" ] || continue
    fwbase=$(basename "$fwdir" .framework)
    if ! grep -qx "$fwbase" "$EXPECTED_FW_TMP"; then
        echo "MakeFrameworks: removing orphan framework (no dylib for current filter/manifest): ${fwbase}.framework"
        rm -rf "$fwdir"
    fi
done < "$_orphan_tmp"
rm -f "$_orphan_tmp"
rm -f "$EXPECTED_FW_TMP"

if [ "$FW_FILTER" -gt 0 ]; then
    echo "MakeFrameworks: Created ${FW_COUNT} frameworks from ${DYLIB_COUNT} dylibs (skipped ${FW_SKIP} unchanged, filtered ${FW_FILTER}, ${FW_FAIL} failed)."
else
    echo "MakeFrameworks: Created ${FW_COUNT} frameworks from ${DYLIB_COUNT} dylibs (skipped ${FW_SKIP} unchanged, ${FW_FAIL} failed)."
fi

# Final validation: confirm every produced framework has a Mach-O executable inside.
# Strips frameworks that somehow ended up with a missing / non-binary executable
# (e.g. lipo produced a 0-byte file, codesign mangled it). Counts deletions as a
# fatal error if it brings the total to 0.
PROD_VALIDATION_FAIL=0
PROD_VALIDATION_OK=0
for fwdir in "${OUTDIR}"/*.libretro.framework; do
    [ -d "$fwdir" ] || continue
    fwbase=$(basename "$fwdir" .framework)
    bin="${fwdir}/${fwbase}"
    # macOS uses Versions/A; resolve via symlink if present
    if [ "$MF_PLATFORM_FAMILY" = "macOS" ] && [ -L "$bin" ]; then
        :
    fi
    if [ ! -f "$bin" ] && [ ! -L "$bin" ]; then
        echo "MakeFrameworks: ERROR — ${fwbase}.framework has no binary at ${bin} — removing" >&2
        rm -rf "$fwdir"
        PROD_VALIDATION_FAIL=$((PROD_VALIDATION_FAIL + 1))
        continue
    fi
    FTYPE=$(file -b "$bin" 2>/dev/null)
    case "$FTYPE" in
        *Mach-O*|*"universal binary"*)
            PROD_VALIDATION_OK=$((PROD_VALIDATION_OK + 1))
            ;;
        *)
            echo "MakeFrameworks: ERROR — ${fwbase}.framework binary is not Mach-O (${FTYPE}) — removing" >&2
            rm -rf "$fwdir"
            PROD_VALIDATION_FAIL=$((PROD_VALIDATION_FAIL + 1))
            ;;
    esac
done

if [ "${PROD_VALIDATION_FAIL}" -gt 0 ]; then
    echo "MakeFrameworks: WARNING — removed ${PROD_VALIDATION_FAIL} invalid framework(s) after validation" >&2
fi

FW_TOTAL=$((FW_COUNT + FW_SKIP))

# Recount frameworks that survived final Mach-O validation. PROD_VALIDATION_OK reflects
# the actual on-disk count after stripping zero-byte / non-Mach-O bundles, which is the
# only number that matters at runtime.
FW_ONDISK=$(find "$OUTDIR" -maxdepth 1 -type d -name "*.libretro.framework" 2>/dev/null | wc -l | tr -d ' ')

echo "MakeFrameworks: ${FW_ONDISK} framework(s) on disk, ${PROD_VALIDATION_OK} Mach-O-validated."

if [ "${FW_ONDISK}" -eq 0 ] && [ "${DYLIB_COUNT}" -gt 0 ]; then
    echo "MakeFrameworks: ERROR — 0 frameworks remain after validation from ${DYLIB_COUNT} dylibs! All cores broken." >&2
    exit 1
fi

if [ "${FW_TOTAL}" -eq 0 ] && [ "${DYLIB_COUNT}" -gt 0 ]; then
    echo "MakeFrameworks: ERROR — 0 frameworks created from ${DYLIB_COUNT} dylibs! All cores broken." >&2
    exit 1
fi

# Warn if significantly fewer frameworks than dylibs (> 20% loss)
if [ "${DYLIB_COUNT}" -gt 0 ]; then
    THRESHOLD=$((DYLIB_COUNT * 80 / 100))
    if [ "${FW_TOTAL}" -lt "${THRESHOLD}" ]; then
        echo "MakeFrameworks: WARNING — only ${FW_TOTAL}/${DYLIB_COUNT} frameworks available. Check logs for failures." >&2
    fi
fi

exit 0
