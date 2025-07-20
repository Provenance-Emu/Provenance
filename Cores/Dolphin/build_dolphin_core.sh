#!/bin/bash

set -e

# Ensure build tools are in PATH
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/Applications/CMake.app/Contents/bin"

# Configuration
FRAMEWORK_NAME="PVlibDolphin"
DOL_CORE_BUILD_TARGET="Release"
IPHONEOS_DEPLOYMENT_TARGET="13.0"
TVOS_DEPLOYMENT_TARGET="13.0"

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_DIR="$SCRIPT_DIR/dolphin-ios"
BUILD_DIR="$SCRIPT_DIR/build"
XCFRAMEWORK_DIR="$BUILD_DIR/xcframework"

# Ensure necessary directories exist
mkdir -p "$BUILD_DIR"
mkdir -p "$XCFRAMEWORK_DIR"

# Check for required tools
if ! command -v ninja &> /dev/null; then
    echo "Error: Ninja build tool not found. Please install it with 'brew install ninja'."
    exit 1
fi

if ! command -v cmake &> /dev/null; then
    echo "Error: CMake not found. Please install it with 'brew install cmake'."
    exit 1
fi

# Set compiler paths explicitly
export CC="$(xcrun -find clang)"
export CXX="$(xcrun -find clang++)"

# Function to build for a specific platform
build_platform() {
    local platform=$1
    local deployment_target=$2
    local platform_name=$3
    local output_suffix=$4

    echo "Building for $platform_name..."

    CMAKE_BUILD_DIR="$REPO_ROOT_DIR/build-$platform_name-$DOL_CORE_BUILD_TARGET"
    mkdir -p "$CMAKE_BUILD_DIR"
    cd "$CMAKE_BUILD_DIR"

    # Configure CMake
    cmake "$REPO_ROOT_DIR" \
        -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$REPO_ROOT_DIR/Externals/ios-cmake/ios.toolchain.cmake" \
        -DPLATFORM=$platform \
        -DDEPLOYMENT_TARGET=$deployment_target \
        -DENABLE_VISIBILITY=ON \
        -DENABLE_BITCODE=OFF \
        -DENABLE_ARC=ON \
        -DCMAKE_BUILD_TYPE=$DOL_CORE_BUILD_TARGET \
        -DCMAKE_CXX_FLAGS="-fPIC" \
        -DIOS=ON \
        -DENABLE_ANALYTICS=NO \
        -DUSE_SYSTEM_LIBS=OFF \
        -DENABLE_TESTS=OFF \
        -DCMAKE_POLICY_DEFAULT_CMP0080=NEW \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.19 \
        -DCMAKE_POLICY_VERSION=3.19 \
        -DBUILD_SHARED_LIBS=OFF

    # Build
    ninja

    echo "Build completed for $platform_name"
}

# Build for each platform
build_platform "OS64" "$IPHONEOS_DEPLOYMENT_TARGET" "iphoneos" "-ios"

if [ "$(arch)" = "arm64" ]; then
    build_platform "SIMULATORARM64" "$IPHONEOS_DEPLOYMENT_TARGET" "iphonesimulator" "-ios-sim"
else
    build_platform "SIMULATOR64" "$IPHONEOS_DEPLOYMENT_TARGET" "iphonesimulator" "-ios-sim"
fi

build_platform "TVOS" "$TVOS_DEPLOYMENT_TARGET" "appletvos" "-tvos"
build_platform "SIMULATOR_TVOS" "$TVOS_DEPLOYMENT_TARGET" "appletvsimulator" "-tvos-sim"

# Create XCFramework
echo "Creating XCFramework..."

# Create output directory
mkdir -p "$XCFRAMEWORK_DIR"

# Find the built dylibs
echo "Searching for dolphin dylibs..."
IOS_DYLIB=$(find "$REPO_ROOT_DIR" -path "*/build-iphoneos-$DOL_CORE_BUILD_TARGET/*" -name "libdolphin-ios*.dylib" | head -n 1)
IOS_SIM_DYLIB=$(find "$REPO_ROOT_DIR" -path "*/build-iphonesimulator-$DOL_CORE_BUILD_TARGET/*" -name "libdolphin-ios*.dylib" | head -n 1)
TVOS_DYLIB=$(find "$REPO_ROOT_DIR" -path "*/build-appletvos-$DOL_CORE_BUILD_TARGET/*" -name "libdolphin-tvos*.dylib" | head -n 1)
TVOS_SIM_DYLIB=$(find "$REPO_ROOT_DIR" -path "*/build-appletvsimulator-$DOL_CORE_BUILD_TARGET/*" -name "libdolphin-tvos*.dylib" | head -n 1)

echo "iOS dylib: $iOS_DYLIB"
echo "iOS Simulator dylib: $iOS_SIM_DYLIB"
echo "tvOS dylib: $TVOS_DYLIB"
echo "tvOS Simulator dylib: $TVOS_SIM_DYLIB"

# Function to create a framework from a dylib
create_framework() {
    local dylib_path="$1"
    local platform="$2"
    local framework_path="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME-$platform.framework"

    echo "Creating framework for $platform from $dylib_path"

    # Create framework directory structure
    mkdir -p "$framework_path"

    # Get the actual filename without path
    local dylib_filename=$(basename "$dylib_path")
    
    # Copy dylib to framework and rename it to match framework name
    cp "$dylib_path" "$framework_path/$FRAMEWORK_NAME-$platform"
    
    # Make sure the binary is executable
    chmod +x "$framework_path/$FRAMEWORK_NAME-$platform"
    
    # Fix the install name to match the framework structure
    install_name_tool -id "@rpath/$FRAMEWORK_NAME-$platform.framework/$FRAMEWORK_NAME-$platform" "$framework_path/$FRAMEWORK_NAME-$platform"

    # Create Info.plist
    cat > "$framework_path/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_NAME-$platform</string>
    <key>CFBundleIdentifier</key>
    <string>org.dolphin-emu.$FRAMEWORK_NAME-$platform</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_NAME-$platform</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>11.0</string>
</dict>
</plist>
EOF

    echo "Framework created at $framework_path"
}

# Create frameworks for each platform
# Check if dylibs exist
if [ -f "$IOS_DYLIB" ]; then
    create_framework "$IOS_DYLIB" "ios"
else
    echo "Warning: iOS dylib not found"
fi

if [ -f "$IOS_SIM_DYLIB" ]; then
    create_framework "$IOS_SIM_DYLIB" "ios-sim"
else
    echo "Warning: iOS Simulator dylib not found"
fi

if [ -f "$TVOS_DYLIB" ]; then
    create_framework "$TVOS_DYLIB" "tvos"
else
    echo "Warning: tvOS dylib not found"
fi

if [ -f "$TVOS_SIM_DYLIB" ]; then
    create_framework "$TVOS_SIM_DYLIB" "tvos-sim"
else
    echo "Warning: tvOS Simulator dylib not found"
fi

# Create XCFramework
echo "Creating XCFramework..."
XCFRAMEWORK_PATH="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME.xcframework"

# Remove existing XCFramework if it exists
if [ -d "$XCFRAMEWORK_PATH" ]; then
    rm -rf "$XCFRAMEWORK_PATH"
fi

# Build the xcodebuild command
XCFRAMEWORK_CMD="xcodebuild -create-xcframework -output $XCFRAMEWORK_PATH"

# Add frameworks to command if they exist
if [ -f "$IOS_DYLIB" ]; then
    IOS_FRAMEWORK="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME-ios.framework"
    XCFRAMEWORK_CMD="$XCFRAMEWORK_CMD -framework $IOS_FRAMEWORK"
fi

if [ -f "$IOS_SIM_DYLIB" ]; then
    IOS_SIM_FRAMEWORK="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME-ios-sim.framework"
    XCFRAMEWORK_CMD="$XCFRAMEWORK_CMD -framework $IOS_SIM_FRAMEWORK"
fi

if [ -f "$TVOS_DYLIB" ]; then
    TVOS_FRAMEWORK="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME-tvos.framework"
    XCFRAMEWORK_CMD="$XCFRAMEWORK_CMD -framework $TVOS_FRAMEWORK"
fi

if [ -f "$TVOS_SIM_DYLIB" ]; then
    TVOS_SIM_FRAMEWORK="$XCFRAMEWORK_DIR/$FRAMEWORK_NAME-tvos-sim.framework"
    XCFRAMEWORK_CMD="$XCFRAMEWORK_CMD -framework $TVOS_SIM_FRAMEWORK"
fi

# Execute the command if at least one framework exists
if [[ "$XCFRAMEWORK_CMD" != "xcodebuild -create-xcframework -output $XCFRAMEWORK_PATH" ]]; then
    echo "Executing: $XCFRAMEWORK_CMD"
    eval "$XCFRAMEWORK_CMD"
    echo "XCFramework created at $XCFRAMEWORK_PATH"
else
    echo "Error: No frameworks found to create XCFramework"
    exit 1
fi

echo "XCFramework created at $XCFRAMEWORK_PATH"
ls -la "$XCFRAMEWORK_PATH"

# Copy XCFramework to the expected output location
OUTPUT_PATH="$BUILT_PRODUCTS_DIR/$FRAMEWORK_NAME.xcframework"
echo "Copying XCFramework to $OUTPUT_PATH"
rm -rf "$OUTPUT_PATH"
cp -R "$XCFRAMEWORK_PATH" "$OUTPUT_PATH"

echo "Build completed successfully!"
