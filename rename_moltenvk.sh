#!/bin/bash

# Script to rename MoltenVK binary and update Info.plist files
# for MoltenVK-1.2.8.xcframework

XCFRAMEWORK_PATH="/Users/jmattiello/Workspace/Provenance/Provenance/MoltenVK/MoltenVK/dynamic/MoltenVK-1.2.8.xcframework"
NEW_NAME="MoltenVK-1.2.8"
OLD_NAME="MoltenVK"

# Process each platform directory
for platform in ios-arm64 ios-arm64_x86_64-simulator tvos-arm64_arm64e tvos-arm64_x86_64-simulator; do
    echo "Processing $platform..."
    FRAMEWORK_DIR="$XCFRAMEWORK_PATH/$platform/$NEW_NAME.framework"
    
    # Check if binary exists
    if [ -f "$FRAMEWORK_DIR/$OLD_NAME" ]; then
        echo "  Renaming binary $OLD_NAME to $NEW_NAME"
        mv "$FRAMEWORK_DIR/$OLD_NAME" "$FRAMEWORK_DIR/$NEW_NAME"
        
        # Update Info.plist
        echo "  Updating Info.plist CFBundleExecutable"
        plutil -replace CFBundleExecutable -string "$NEW_NAME" "$FRAMEWORK_DIR/Info.plist"
    else
        echo "  WARNING: Binary $OLD_NAME not found in $FRAMEWORK_DIR"
    fi
done

# Special handling for macOS which has a different structure with Versions
platform="macos-arm64_x86_64"
echo "Processing $platform..."
FRAMEWORK_DIR="$XCFRAMEWORK_PATH/$platform/$NEW_NAME.framework"

# Check if Versions directory exists
if [ -d "$FRAMEWORK_DIR/Versions/A" ]; then
    echo "  Renaming binary in Versions/A directory"
    if [ -f "$FRAMEWORK_DIR/Versions/A/$OLD_NAME" ]; then
        mv "$FRAMEWORK_DIR/Versions/A/$OLD_NAME" "$FRAMEWORK_DIR/Versions/A/$NEW_NAME"
        
        # Update symbolic links
        echo "  Updating symbolic links"
        cd "$FRAMEWORK_DIR"
        rm -f "$OLD_NAME"
        ln -s "Versions/Current/$NEW_NAME" "$NEW_NAME"
        
        # Update Info.plist
        echo "  Updating Info.plist CFBundleExecutable"
        plutil -replace CFBundleExecutable -string "$NEW_NAME" "$FRAMEWORK_DIR/Versions/A/Resources/Info.plist"
    else
        echo "  WARNING: Binary $OLD_NAME not found in $FRAMEWORK_DIR/Versions/A"
    fi
else
    echo "  WARNING: Versions/A directory not found in $FRAMEWORK_DIR"
fi

# Update xcframework Info.plist
echo "Updating xcframework Info.plist BinaryPath entries..."
XCFRAMEWORK_INFO="$XCFRAMEWORK_PATH/Info.plist"

# Create a temporary file for the new plist
TMP_PLIST=$(mktemp)

# Use plutil to convert to XML, sed to replace binary paths, then convert back
plutil -convert xml1 -o "$TMP_PLIST" "$XCFRAMEWORK_INFO"
sed -i '' "s|<string>$NEW_NAME.framework/$OLD_NAME</string>|<string>$NEW_NAME.framework/$NEW_NAME</string>|g" "$TMP_PLIST"
sed -i '' "s|<string>$NEW_NAME.framework/Versions/A/$OLD_NAME</string>|<string>$NEW_NAME.framework/Versions/A/$NEW_NAME</string>|g" "$TMP_PLIST"
plutil -convert binary1 -o "$XCFRAMEWORK_INFO" "$TMP_PLIST"

# Clean up
rm "$TMP_PLIST"

echo "Renaming complete!"
