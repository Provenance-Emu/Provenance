#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 <source_folder> <framework_name> [bundle_identifier_prefix]"
    echo "If bundle_identifier_prefix is not provided, it defaults to 'com.joemattiello'"
}

# Check if the minimum number of arguments is provided
if [ "$#" -lt 2 ]; then
    print_usage
    exit 1
fi

# Assign input arguments to variables
SOURCE_FOLDER="$1"
FRAMEWORK_NAME="$2"
BUNDLE_ID_PREFIX="${3:-com.joemattiello}"

# Create the framework structure
FRAMEWORK_FOLDER="${FRAMEWORK_NAME}.framework"
mkdir -p "${FRAMEWORK_FOLDER}/Versions/A/Headers"
mkdir -p "${FRAMEWORK_FOLDER}/Versions/A/Resources"

# Create symbolic links
ln -s "A" "${FRAMEWORK_FOLDER}/Versions/Current"
ln -s "Versions/Current/Headers" "${FRAMEWORK_FOLDER}/Headers"
ln -s "Versions/Current/Resources" "${FRAMEWORK_FOLDER}/Resources"
ln -s "Versions/Current/${FRAMEWORK_NAME}" "${FRAMEWORK_FOLDER}/${FRAMEWORK_NAME}"

# Combine all .dylib files into a single library
COMBINED_LIB="${FRAMEWORK_FOLDER}/Versions/A/${FRAMEWORK_NAME}"
DYLIBS=("${SOURCE_FOLDER}"/*.dylib)

if [ ${#DYLIBS[@]} -eq 0 ]; then
    echo "No .dylib files found in ${SOURCE_FOLDER}"
    exit 1
fi

if [ ${#DYLIBS[@]} -eq 1 ]; then
    cp "${DYLIBS[0]}" "${COMBINED_LIB}"
else
    # Use the first dylib as a base and link the others
    cp "${DYLIBS[0]}" "${COMBINED_LIB}"
    for dylib in "${DYLIBS[@]:1}"; do
        # Extract symbols from each additional dylib
        nm -g "$dylib" | grep ' T ' | awk '{print $3}' | xargs -I {} echo "_{}" > symbols.txt
        # Link the symbols into the combined library
        ld -r -arch arm64 -o "${COMBINED_LIB}.o" "${COMBINED_LIB}" "$dylib" -exported_symbols_list symbols.txt
        mv "${COMBINED_LIB}.o" "${COMBINED_LIB}"
        rm symbols.txt
    done
fi

# Create Info.plist
cat > "${FRAMEWORK_FOLDER}/Resources/Info.plist" << EOF
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

# Copy header files (assuming they exist in the source folder)
cp "${SOURCE_FOLDER}"/*.h "${FRAMEWORK_FOLDER}/Headers/" 2>/dev/null

echo "Framework ${FRAMEWORK_NAME}.framework created successfully."
echo "Bundle Identifier: ${BUNDLE_ID_PREFIX}.${FRAMEWORK_NAME}"
