#!/bin/sh

# Parse command line arguments
SIGN_DYLIBS=true
BUNDLE_ID_PREFIX="org.provenance-emu"

for arg in "$@"
do
    case $arg in
        -no-dylib)
        SIGN_DYLIBS=false
        shift
        ;;
        --org-identifier=*)
        NEW_PREFIX="${arg#*=}"
        if [ -n "$NEW_PREFIX" ]; then
            BUNDLE_ID_PREFIX="$NEW_PREFIX"
        fi
        shift
        ;;
    esac
done

# Set up variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
CORES_DIR="$PROJECT_DIR/Cores"

# Find the most recently modified .app bundle
APP_BUNDLE=$(find "$DERIVED_DATA_DIR" -name "*.app" -type d -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -1 | cut -d" " -f2-)

if [ -z "$APP_BUNDLE" ]; then
    echo "Error: No .app bundle found in $DERIVED_DATA_DIR"
    exit 1
fi

FRAMEWORKS_PATH="$APP_BUNDLE/Frameworks"

# Get the signing identity
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "iPhone Developer" | head -1 | awk '{print $2}')

if [ -z "$SIGNING_IDENTITY" ]; then
    echo "Error: No iPhone Developer signing identity found"
    exit 1
fi

echo "Using signing identity: $SIGNING_IDENTITY"
echo "Signing cores in: $FRAMEWORKS_PATH"

# Sign the frameworks (cores)
find "$FRAMEWORKS_PATH" -name "*.framework" -type d | while read -r framework
do
    framework_name=$(basename "$framework" .framework)
    framework_id="$BUNDLE_ID_PREFIX.framework.$framework_name"

    echo "Signing framework: $framework_name"
    codesign --force --sign "$SIGNING_IDENTITY" --verbose \
             --identifier "$framework_id" \
             "$framework"
done

# Sign the dynamic libraries if SIGN_DYLIBS is true
if [ "$SIGN_DYLIBS" = true ] ; then
    find "$FRAMEWORKS_PATH" -name "*.dylib" -type f | while read -r dylib
    do
        dylib_name=$(basename "$dylib" .dylib)
        dylib_id="$BUNDLE_ID_PREFIX.dylib.$dylib_name"

        echo "Signing dylib: $dylib_name"
        codesign --force --sign "$SIGNING_IDENTITY" --verbose \
                 --identifier "$dylib_id" \
                 "$dylib"
    done
fi

echo "Core signing complete."
