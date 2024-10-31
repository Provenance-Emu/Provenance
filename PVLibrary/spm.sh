#!/usr/bin/env bash
set -euo pipefail

# Set up variables
PLATFORM="iphonesimulator"
SDK_PATH=$(xcrun --sdk $PLATFORM --show-sdk-path)
DESTINATION="platform=iOS Simulator,name=iPhone 14,OS=latest"

# Build the package
echo "Building package for iOS Simulator..."
swift build -v \
    --scratch-path .build/ios \
    --enable-parseable-module-interfaces \
    -Xswiftc "-sdk" \
    -Xswiftc "$SDK_PATH" \
    -Xswiftc "-target" \
    -Xswiftc "arm64-apple-ios14.0-simulator" \
    --build-system "xcode" \
    | xcpretty

# Run tests
echo "Running tests on iOS Simulator..."
swift test -v \
    --scratch-path .build/ios \
    --enable-parseable-module-interfaces \
    -Xswiftc "-sdk" \
    -Xswiftc "$SDK_PATH" \
    -Xswiftc "-target" \
    -Xswiftc "arm64-apple-ios14.0-simulator" \
    --build-system "xcode" \
    --test-product DirectoryWatcherPackageTests \
    -Xswiftc "-destination" \
    -Xswiftc "$DESTINATION" \
    | xcpretty

echo "Build and test completed."
