#!/bin/bash

set -euxo pipefail

xcodebuild -project SWCompression.xcodeproj -scheme SWCompression -destination "platform=OS X" clean test | xcpretty -f `xcpretty-travis-formatter`
xcodebuild -project SWCompression.xcodeproj -scheme SWCompression -destination "platform=iOS Simulator,name=iPhone 6S" clean test | xcpretty -f `xcpretty-travis-formatter`
xcodebuild -project SWCompression.xcodeproj -scheme SWCompression -destination "platform=watchOS Simulator,name=Apple Watch - 38mm" clean build | xcpretty -f `xcpretty-travis-formatter`
xcodebuild -project SWCompression.xcodeproj -scheme SWCompression -destination "platform=tvOS Simulator,name=Apple TV" clean test | xcpretty -f `xcpretty-travis-formatter`
