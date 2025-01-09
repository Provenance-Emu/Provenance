#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 <source_folder> <framework_name> [bundle_identifier_prefix]"
    echo "If bundle_identifier_prefix is not provided, it defaults to 'org.provenance-emu'"
}

# Check if the minimum number of arguments is provided
if [ "$#" -lt 2 ]; then
    print_usage
    exit 1
fi

# Assign input arguments to variables
SOURCE_FOLDER="$1"
FRAMEWORK_NAME="$2"
BUNDLE_ID_PREFIX="${3:-org.provenance-emu}"

# Create temporary directories for iOS and tvOS frameworks
TEMP_IOS_FRAMEWORK="${FRAMEWORK_NAME}_iOS.framework"
TEMP_TVOS_FRAMEWORK="${FRAMEWORK_NAME}_tvOS.framework"

# Function to create a platform-specific framework
create_platform_framework() {
    local platform=$1
    local temp_framework=$2
    local dylibs=("$SOURCE_FOLDER"/*${platform}*.dylib)

    mkdir -p "${temp_framework}/Headers"

    # Combine all .dylib files for the platform into a single library
    if [ ${#dylibs[@]} -eq 0 ]; then
        echo "No ${platform} .dylib files found in ${SOURCE_FOLDER}"
        return 1
    fi

    if [ ${#dylibs[@]} -eq 1 ]; then
        cp "${dylibs[0]}" "${temp_framework}/${FRAMEWORK_NAME}"
    else
        # Use the first dylib as a base and link the others
        cp "${dylibs[0]}" "${temp_framework}/${FRAMEWORK_NAME}"
        for dylib in "${dylibs[@]:1}"; do
            # Extract symbols from each additional dylib
            nm -g "$dylib" | grep ' T ' | awk '{print $3}' | xargs -I {} echo "_{}" > symbols.txt
            # Link the symbols into the combined library
            ld -r -arch arm64 -o "${temp_framework}/${FRAMEWORK_NAME}.o" "${temp_framework}/${FRAMEWORK_NAME}" "$dylib" -exported_symbols_list symbols.txt
            mv "${temp_framework}/${FRAMEWORK_NAME}.o" "${temp_framework}/${FRAMEWORK_NAME}"
            rm symbols.txt
        done
    fi

    # Copy header files
    cp "$SOURCE_FOLDER"/*.h "${temp_framework}/Headers/" 2>/dev/null

    # Create Info.plist
    cat > "${temp_framework}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID_PREFIX}.${FRAMEWORK_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>12.0</string>
</dict>
</plist>
EOF

    echo "${platform} framework created successfully."
}

# Create iOS and tvOS frameworks
create_platform_framework "iOS" "$TEMP_IOS_FRAMEWORK"
create_platform_framework "tvOS" "$TEMP_TVOS_FRAMEWORK"

# Create XCFramework
XCFRAMEWORK_NAME="${FRAMEWORK_NAME}.xcframework"
xcodebuild -create-xcframework \
    -framework "$TEMP_IOS_FRAMEWORK" \
    -framework "$TEMP_TVOS_FRAMEWORK" \
    -output "$XCFRAMEWORK_NAME"

# Clean up temporary frameworks
rm -rf "$TEMP_IOS_FRAMEWORK" "$TEMP_TVOS_FRAMEWORK"

echo "XCFramework ${XCFRAMEWORK_NAME} created successfully."
echo "Bundle Identifier: ${BUNDLE_ID_PREFIX}.${FRAMEWORK_NAME}"
