#!/bin/bash
# NOTE: Xcode build phases invoke scripts via /bin/sh, which ignores the shebang.
# This guard re-execs with bash so bash-specific syntax (pattern replacement, arrays,
# etc.) works even when the build phase calls: /bin/sh ".../make_frameworks_retroarch.sh"
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

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

# Prefer the expanded name, if available.
CODE_SIGN_IDENTITY_FOR_ITEMS="${EXPANDED_CODE_SIGN_IDENTITY}"
if [ "${CODE_SIGN_IDENTITY_FOR_ITEMS}" = "" ] ; then
    # Fall back to old behavior.
    CODE_SIGN_IDENTITY_FOR_ITEMS="${CODE_SIGN_IDENTITY}"
fi

echo "Identity:"
echo "${CODE_SIGN_IDENTITY_FOR_ITEMS}"

if [ "$PLATFORM_FAMILY_NAME" = "tvOS" ] ; then
    BASE_DIR="$1"
    SUFFIX="_tvos"
    PLATFORM="tvos"
    DEPLOYMENT_TARGET="${TVOS_DEPLOYMENT_TARGET}"
elif [ "$PLATFORM_FAMILY_NAME" = "iOS" ] ; then
    BASE_DIR="$1"
    SUFFIX="_ios"
    PLATFORM="ios"
    DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET}"
elif [ "$PLATFORM_FAMILY_NAME" = "macOS" ] ; then
    BASE_DIR="$1"
    SUFFIX=
    PLATFORM=
    DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}"
fi

if [ -n "$BUILT_PRODUCTS_DIR" -a -n "$FRAMEWORKS_FOLDER_PATH" ] ; then
    OUTDIR="$BUILT_PRODUCTS_DIR"/"$FRAMEWORKS_FOLDER_PATH"
else
    OUTDIR="$BASE_DIR"/Frameworks
fi

# Echo the directory that will be created next
echo "MakeFrameworks: Creating directory: $OUTDIR"

mkdir -p "$OUTDIR"

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

for dylib in $(find "$BASE_DIR"/modules -maxdepth 1 -type f -regex '.*libretro.*\.dylib$') ; do
    intermediate=$(basename "$dylib")
    intermediate="${intermediate/%.dylib/}"
    if [ -n "$SUFFIX" ] ; then
        intermediate="${intermediate/%$SUFFIX/}"
    fi
    fwName="${intermediate//_/.}"

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

    fwDir="${OUTDIR}/${fwName}.framework"
    mkdir -p "$fwDir"
    if [ "$PLATFORM_FAMILY_NAME" = "iOS" -o "$PLATFORM_FAMILY_NAME" = "tvOS" ] ; then
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
    if [ "$PLATFORM_FAMILY_NAME" = "macOS" ] ; then
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

echo "MakeFrameworks: Created ${FW_COUNT} frameworks from ${DYLIB_COUNT} dylibs (${FW_FAIL} failed)"

if [ "${FW_COUNT}" -eq 0 ] && [ "${DYLIB_COUNT}" -gt 0 ]; then
    echo "MakeFrameworks: ERROR — 0 frameworks created from ${DYLIB_COUNT} dylibs! All cores broken." >&2
    exit 1
fi

# Warn if significantly fewer frameworks than dylibs (> 20% loss)
if [ "${DYLIB_COUNT}" -gt 0 ]; then
    THRESHOLD=$((DYLIB_COUNT * 80 / 100))
    if [ "${FW_COUNT}" -lt "${THRESHOLD}" ]; then
        echo "MakeFrameworks: WARNING — only ${FW_COUNT}/${DYLIB_COUNT} frameworks created. Check logs for failures." >&2
    fi
fi

exit 0
