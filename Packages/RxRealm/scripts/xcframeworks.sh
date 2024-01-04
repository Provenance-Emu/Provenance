#!/usr/bin/env bash

set -euo pipefail
brew bundle
rm -rf RxRealm-SPM.xcodeproj
rm -rf xcarchives/*
rm -rf RxRealm.xcframework.zip
rm -rf RxRealm.xcframework

xcodegen --spec project-spm.yml

xcodebuild archive -quiet -project RxRealm-SPM.xcodeproj -configuration Release -scheme "RxRealm iOS" -destination "generic/platform=iOS" -archivePath "xcarchives/RxRealm-iOS" SKIP_INSTALL=NO SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE="bitcode" ENABLE_BITCODE=YES | xcpretty --color --simple
xcodebuild archive -quiet -project RxRealm-SPM.xcodeproj -configuration Release -scheme "RxRealm iOS" -destination "generic/platform=iOS Simulator" -archivePath "xcarchives/RxRealm-iOS-Simulator" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE="bitcode" ENABLE_BITCODE=YES | xcpretty --color --simple
xcodebuild archive -quiet -project RxRealm-SPM.xcodeproj -configuration Release -scheme "RxRealm tvOS" -destination "generic/platform=tvOS" -archivePath "xcarchives/RxRealm-tvOS" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE="bitcode" ENABLE_BITCODE=YES | xcpretty --color --simple
xcodebuild archive -quiet -project RxRealm-SPM.xcodeproj -configuration Release -scheme "RxRealm tvOS" -destination "generic/platform=tvOS Simulator"  -archivePath "xcarchives/RxRealm-tvOS-Simulator" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE="bitcode" ENABLE_BITCODE=YES | xcpretty --color --simple
xcodebuild archive -quiet -project RxRealm-SPM.xcodeproj -configuration Release -scheme "RxRealm macOS" -destination "generic/platform=macOS" -archivePath "xcarchives/RxRealm-macOS" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE="bitcode" ENABLE_BITCODE=YES | xcpretty --color --simple
xcodebuild archive -quiet -project RxRealm-SPM.xcodeproj -configuration Release -scheme "RxRealm watchOS" -destination "generic/platform=watchOS" -archivePath "xcarchives/RxRealm-watchOS" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE="bitcode" ENABLE_BITCODE=YES | xcpretty --color --simple
xcodebuild archive -quiet -project RxRealm-SPM.xcodeproj -configuration Release -scheme "RxRealm watchOS" -destination "generic/platform=watchOS Simulator" -archivePath "xcarchives/RxRealm-watchOS-Simulator" SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE="bitcode" ENABLE_BITCODE=YES | xcpretty --color --simple

xcodebuild -create-xcframework \
-framework "xcarchives/RxRealm-iOS-Simulator.xcarchive/Products/Library/Frameworks/RxRealm.framework" \
-debug-symbols ""$(pwd)"/xcarchives/RxRealm-iOS-Simulator.xcarchive/dSYMs/RxRealm.framework.dSYM" \
-framework "xcarchives/RxRealm-iOS.xcarchive/Products/Library/Frameworks/RxRealm.framework" \
-debug-symbols ""$(pwd)"/xcarchives/RxRealm-iOS.xcarchive/dSYMs/RxRealm.framework.dSYM" \
-framework "xcarchives/RxRealm-tvOS-Simulator.xcarchive/Products/Library/Frameworks/RxRealm.framework" \
-debug-symbols ""$(pwd)"/xcarchives/RxRealm-tvOS-Simulator.xcarchive/dSYMs/RxRealm.framework.dSYM" \
-framework "xcarchives/RxRealm-tvOS.xcarchive/Products/Library/Frameworks/RxRealm.framework" \
-debug-symbols ""$(pwd)"/xcarchives/RxRealm-tvOS.xcarchive/dSYMs/RxRealm.framework.dSYM" \
-framework "xcarchives/RxRealm-macOS.xcarchive/Products/Library/Frameworks/RxRealm.framework" \
-debug-symbols ""$(pwd)"/xcarchives/RxRealm-macOS.xcarchive/dSYMs/RxRealm.framework.dSYM" \
-framework "xcarchives/RxRealm-watchOS-Simulator.xcarchive/Products/Library/Frameworks/RxRealm.framework" \
-debug-symbols ""$(pwd)"/xcarchives/RxRealm-watchOS-Simulator.xcarchive/dSYMs/RxRealm.framework.dSYM" \
-framework "xcarchives/RxRealm-watchOS.xcarchive/Products/Library/Frameworks/RxRealm.framework" \
-debug-symbols ""$(pwd)"/xcarchives/RxRealm-watchOS.xcarchive/dSYMs/RxRealm.framework.dSYM" \
-output "RxRealm.xcframework" 

zip -r RxRealm.xcframework.zip RxRealm.xcframework
rm -rf xcarchives/*
rm -rf RxRealm.xcframework
rm -rf RxRealm-SPM.xcodeproj