#!/bin/bash

# Script to update CFBundleIdentifier in MoltenVK-1.2.8.xcframework
# to avoid conflicts with the original MoltenVK framework

XCFRAMEWORK_PATH="/Users/jmattiello/Workspace/Provenance/Provenance/MoltenVK/MoltenVK/dynamic/MoltenVK-1.2.8.xcframework"
NEW_BUNDLE_ID="com.moltenvk.framework.128"
FRAMEWORK_NAME="MoltenVK-1.2.8"

# Process each platform directory
for platform in ios-arm64 ios-arm64_x86_64-simulator tvos-arm64_arm64e tvos-arm64_x86_64-simulator; do
    echo "Processing $platform..."
    FRAMEWORK_DIR="$XCFRAMEWORK_PATH/$platform/$FRAMEWORK_NAME.framework"
    
    # Update Info.plist
    echo "  Updating Info.plist CFBundleIdentifier to $NEW_BUNDLE_ID"
    plutil -replace CFBundleIdentifier -string "$NEW_BUNDLE_ID" "$FRAMEWORK_DIR/Info.plist"
    
    # Verify the change
    CURRENT_ID=$(plutil -p "$FRAMEWORK_DIR/Info.plist" | grep CFBundleIdentifier | awk -F'"' '{print $4}')
    echo "  Verified new bundle ID: $CURRENT_ID"
done

# Special handling for macOS which has Info.plist in Resources directory
platform="macos-arm64_x86_64"
echo "Processing $platform..."
FRAMEWORK_DIR="$XCFRAMEWORK_PATH/$platform/$FRAMEWORK_NAME.framework"

# Check if Versions directory exists
if [ -d "$FRAMEWORK_DIR/Versions/A/Resources" ]; then
    echo "  Updating Info.plist in Versions/A/Resources"
    plutil -replace CFBundleIdentifier -string "$NEW_BUNDLE_ID" "$FRAMEWORK_DIR/Versions/A/Resources/Info.plist"
    
    # Verify the change
    CURRENT_ID=$(plutil -p "$FRAMEWORK_DIR/Versions/A/Resources/Info.plist" | grep CFBundleIdentifier | awk -F'"' '{print $4}')
    echo "  Verified new bundle ID: $CURRENT_ID"
else
    echo "  WARNING: Resources directory not found in $FRAMEWORK_DIR/Versions/A"
fi

echo "Bundle ID update complete!"
