#!/usr/bin/env bash
set -euo pipefail
swift build -v \
    --experimental-explicit-module-build \
    --scratch-path .build/ios \
    --emit-swift-module-separately \
    --use-integrated-swift-driver \
    --enable-parseable-module-interfaces \
    --build-system "xcode" \
    -Xswiftc "-sdk" \
    -Xswiftc "`xcrun --sdk iphonesimulator --show-sdk-path`" \
    -Xswiftc "-target" \
    -Xswiftc "arm64-apple-ios13.0-simulator" \
    -Xswiftc "-Xfrontend" \
    -Xswiftc "-debug-time-function-bodies" \
    -Xswiftc "-Xfrontend" \
    -Xswiftc "-debug-time-expression-type-checking" | xcpretty