#!/usr/bin/env bash
set -euo pipefail
swift build -v \
    --scratch-path .build/ios \
    --enable-parseable-module-interfaces \
    -Xswiftc "-sdk" \
    -Xswiftc "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
    -Xswiftc "-target" \
    -Xswiftc "arm64-apple-ios13.0-simulator" | xcpretty

    # --build-system "xcode" \
    # --emit-swift-module-separately \
    # --use-integrated-swift-driver \
    # --experimental-explicit-module-build \
	# -Xswiftc "-Xfrontend" \
	# -Xswiftc "-debug-time-function-bodies" \
	# -Xswiftc "-Xfrontend" \
	# -Xswiftc "-debug-time-expression-type-checking"
