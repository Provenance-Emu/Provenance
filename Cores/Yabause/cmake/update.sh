#!/usr/bin/env bash

# export Qt5_DIR=$(brew --prefix)/opt/qt5
# ../citra/externals/sdl2/SDL/src/render/metal/build-metal-shaders.sh

# rm CMakeCache.txt
# rm -rf CMakeFiles

#brew install glslang clangformat

cmake ../yabause/yabause -G Xcode \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_MACOSX_BUNDLE=NO \
-DENABLE_BITCODE=NO \
-DYAB_WANT_SDL=NO \
-DPLATFORM="OS64" \
-DDEPLOYMENT_TARGET="13.0" \
-DPLATFORM_DEPLOYMENT_TARGET="13.0" \
-DENABLE_ANALYTICS=NO \
-DTARGET_IOS=ON \
-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="iPhone Developer" \
-DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="XXXXXXXXXX" \
-DCMAKE_XCODE_ATTRIBUTE_PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: *"

#-DCMAKE_TOOLCHAIN_FILE=../citra/CMakeModules/ios2.cmake \


#-DCMAKE_OSX_ARCHITECTURES="arm64" \

#

# -DCMAKE_OSX_ARCHITECTURES="arm64"

# cmake --build . --config Release
# cmake --install . --config Release # Necessary to build combined library

# Platform flag options (-DPLATFORM=flag)

# OS - to build for iOS (armv7, armv7s, arm64) DEPRECATED in favour of OS64
# OS64 - to build for iOS (arm64 only)
# OS64COMBINED - to build for iOS & iOS Simulator (FAT lib) (arm64, x86_64)
# SIMULATOR - to build for iOS simulator 32 bit (i386) DEPRECATED
# SIMULATOR64 - to build for iOS simulator 64 bit (x86_64)
# SIMULATORARM64 - to build for iOS simulator 64 bit (arm64)
# TVOS - to build for tvOS (arm64)
# TVOSCOMBINED - to build for tvOS & tvOS Simulator (arm64, x86_64)
# SIMULATOR_TVOS - to build for tvOS Simulator (x86_64)
# WATCHOS - to build for watchOS (armv7k, arm64_32)
# WATCHOSCOMBINED - to build for watchOS & Simulator (armv7k, arm64_32, i386)
# SIMULATOR_WATCHOS - to build for watchOS Simulator (i386)
# MAC - to build for macOS (x86_64)
# MAC_ARM64 - to build for macOS on Apple Silicon (arm64)
# MAC_UNIVERSAL - to build for macOS on x86_64 and Apple Silicon (arm64) combined
# MAC_CATALYST - to build iOS for Mac (Catalyst, x86_64)
# MAC_CATALYST_ARM64 - to build iOS for Mac on Apple Silicon (Catalyst, arm64)

# Additional Options

# -DENABLE_BITCODE=(BOOL) - Enabled by default, specify FALSE or 0 to disable bitcode

# -DENABLE_ARC=(BOOL) - Enabled by default, specify FALSE or 0 to disable ARC

# -DENABLE_VISIBILITY=(BOOL) - Disabled by default, specify TRUE or 1 to enable symbol visibility support

# -DENABLE_STRICT_TRY_COMPILE=(BOOL) - Disabled by default, specify TRUE or 1 to enable strict compiler checks (will run linker on all compiler checks whenever needed)

# -DARCHS=(STRING) - Valid values are: armv7, armv7s, arm64, i386, x86_64, armv7k, arm64_32. By default it will build for all valid architectures based on -DPLATFORM (see above)