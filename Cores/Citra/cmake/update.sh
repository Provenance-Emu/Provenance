#!/usr/bin/env bash
#export Vulkan_LIBRARY=1.3.204.1 # Version of Vulkan SDK
#export VULKAN_SDK="~/VulkanSDK/${Vulkan_LIBRARY}/macOS" # Path to Vulkan SDK
#export Vulkan_INCLUDE_DIR="~/VulkanSDK/${Vulkan_LIBRARY}/MoltenVK/include"
#export FRAMEWORK_VULKAN_LIBS="~/VulkanSDK/${Vulkan_LIBRARY}/MoltenVK/dylib/iOS"
#export Vulkan_LIBRARY="~/VulkanSDK/${Vulkan_LIBRARY}/"

# export Vulkan_LIBRARY=1.3.217 # Version of Vulkan SDK
# export VULKAN_SDK="./" # Path to Vulkan SDK
# export Vulkan_INCLUDE_DIR="../../../MoltenVK/MoltenVK/include"
# export FRAMEWORK_VULKAN_LIBS="../../../MoltenVK/MoltenVK/dylib/iOS/libMoltenVK.dylib"
# export Vulkan_LIBRARY="./"
# ln -s ../../../Cores/Dolphin/dolphin-ios/Externals/MoltenVK lib
# ln -s ../../../../MoltenVK/MoltenVK ../Play-/Source/MoltenVK

#export Vulkan_LIBRARY=1.3.204 # Version of Vulkan SDK
#export VULKAN_SDK="./MoltenVK" # Path to Vulkan SDK
#export Vulkan_INCLUDE_DIR="./MoltenVK/include"
#export FRAMEWORK_VULKAN_LIBS="./MoltenVK/dylib/iOS/libMoltenVK.dylib"
#export Vulkan_LIBRARY="./MoltenVK"
#ln -s ../../../cmake/MoltenVK ../Play-/Source/ui_ios/MoltenVK

# This sets mobile to true...
# cp ../PVPlayCore/Core/GSH_VulkanPlatformDefs.h ../Play-/Source/gs/GSH_Vulkan/
# echo "VULKAN_SDK="${VULKAN_SDK}
# cmake ../citra -G Xcode -DCMAKE_TOOLCHAIN_FILE=../citra/CMakeModules/iOS/ios.toolchain.cmake -DENABLE_BITCODE=NO -DPLATFORM=OS64COMBINED -DDEPLOYMENT_TARGET="13.0" -DPLATFORM_DEPLOYMENT_TARGET=13 -DENABLE_ANALYTICS=NO-DTARGET_IOS=ON-DCMAKE_BUILD_TYPE=Release -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="iPhone Developer" -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="XXXXXXXXXX" -DCMAKE_XCODE_ATTRIBUTE_PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: *"
# DFRAMEWORK_VULKAN_LIBS=${FRAMEWORK_VULKAN_LIBS} -DUSE_GSH_VULKAN=ON  -DCMAKE_PREFIX_PATH="${VULKAN_SDK}" -DVulkan_INCLUDE_DIR=${Vulkan_INCLUDE_DIR} 


# export Qt5_DIR=$(brew --prefix)/opt/qt5
# ../citra/externals/sdl2/SDL/src/render/metal/build-metal-shaders.sh
# -DCMAKE_OSX_ARCHITECTURES="arm64"
cmake ../citra -G Xcode -DCMAKE_OSX_ARCHITECTURES="arm64" -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=../citra/CMakeModules/ios.toolchain.cmake -DCMAKE_MACOSX_BUNDLE=NO -DENABLE_BITCODE=NO -DPLATFORM=OS64COMBINED -DDEPLOYMENT_TARGET="13.0" -DPLATFORM_DEPLOYMENT_TARGET=13 -DENABLE_ANALYTICS=NO -DTARGET_IOS=ON -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="iPhone Developer" -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="XXXXXXXXXX" -DCMAKE_XCODE_ATTRIBUTE_PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: *"
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