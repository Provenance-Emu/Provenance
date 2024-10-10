#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 <source_folder> [bundle_identifier_prefix] [output_folder]"
    echo "If bundle_identifier_prefix is not provided, it defaults to 'com.joemattiello'"
    echo "If output_folder is not provided, it defaults to the current directory"
}

# Check if the minimum number of arguments is provided
if [ "$#" -lt 1 ]; then
    print_usage
    exit 1
fi

# Assign input arguments to variables
SOURCE_FOLDER="$1"
BUNDLE_ID_PREFIX="${2:-com.joemattiello}"
OUTPUT_FOLDER="${3:-.}"

# Ensure output folder exists
mkdir -p "$OUTPUT_FOLDER"

# Function to create a dynamic framework from a dylib
create_framework() {
    local dylib_path="$1"
    local framework_name=$(basename "${dylib_path%.*}")
    local framework_path="$OUTPUT_FOLDER/${framework_name}.framework"

    echo "Creating framework for $framework_name..."

    # Create framework structure
    mkdir -p "$framework_path/Versions/A/Headers"
    mkdir -p "$framework_path/Versions/A/Resources"

    # Copy dylib to framework
    cp "$dylib_path" "$framework_path/Versions/A/${framework_name}"

    # Create symbolic links
    ln -s "A" "$framework_path/Versions/Current"
    ln -s "Versions/Current/Headers" "$framework_path/Headers"
    ln -s "Versions/Current/Resources" "$framework_path/Resources"
    ln -s "Versions/Current/${framework_name}" "$framework_path/${framework_name}"

    # Create Info.plist
    cat > "$framework_path/Versions/A/Resources/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${framework_name}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID_PREFIX}.${framework_name}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${framework_name}</string>
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

    # Set correct install name
    install_name_tool -id "@rpath/${framework_name}.framework/${framework_name}" "$framework_path/Versions/A/${framework_name}"

    # Make sure the framework is for iOS
    if ! lipo -info "$framework_path/Versions/A/${framework_name}" | grep -q "arm64"; then
        echo "Warning: ${framework_name} is not built for arm64 (iOS). It may not be compatible with the App Store."
    fi

    echo "Framework $framework_name created successfully."
}

# Find all dylib files in the source folder
dylibs=$(find "$SOURCE_FOLDER" -name "*.dylib")

# Loop through each dylib and create a framework
for dylib in $dylibs; do
    create_framework "$dylib"
done

echo "All frameworks have been created in $OUTPUT_FOLDER"
