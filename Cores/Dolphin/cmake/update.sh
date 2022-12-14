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
cmake ../dolphin-ios -G Xcode -DCMAKE_TOOLCHAIN_FILE=../dolphin-ios/Source/iOS/ios.toolchain.cmake -DENABLE_BITCODE=NO -DPLATFORM=OS64COMBINED -DDEPLOYMENT_TARGET="13.0" -DPLATFORM_DEPLOYMENT_TARGET=13 -DENABLE_ANALYTICS=NO-DTARGET_IOS=ON-DCMAKE_BUILD_TYPE=Release -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="iPhone Developer" -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="XXXXXXXXXX" -DCMAKE_XCODE_ATTRIBUTE_PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: *"
# DFRAMEWORK_VULKAN_LIBS=${FRAMEWORK_VULKAN_LIBS} -DUSE_GSH_VULKAN=ON  -DCMAKE_PREFIX_PATH="${VULKAN_SDK}" -DVulkan_INCLUDE_DIR=${Vulkan_INCLUDE_DIR} 