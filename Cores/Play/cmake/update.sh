#!/usr/bin/env bash
export Vulkan_LIBRARY=1.3.204.1 # Version of Vulkan SDK
export VULKAN_SDK="~/VulkanSDK/${Vulkan_LIBRARY}/macOS" # Path to Vulkan SDK
export Vulkan_INCLUDE_DIR="~/VulkanSDK/${Vulkan_LIBRARY}/MoltenVK/include"
export FRAMEWORK_VULKAN_LIBS="~/VulkanSDK/${Vulkan_LIBRARY}/MoltenVK/dylib/iOS"
export Vulkan_LIBRARY="~/VulkanSDK/${Vulkan_LIBRARY}/"

# export Vulkan_LIBRARY=1.3.217 # Version of Vulkan SDK
# export VULKAN_SDK="../../../MoltenVK/MoltenVK/" # Path to Vulkan SDK
# export Vulkan_INCLUDE_DIR=".../../../MoltenVK/MoltenVK/include"
# export FRAMEWORK_VULKAN_LIBS=".../../../MoltenVK/MoltenVK/dylib/iOS"
# export Vulkan_LIBRARY="../../../MoltenVK/MoltenVK/"

echo "VULKAN_SDK="${VULKAN_SDK}
cmake ../Play- -G Xcode -DCMAKE_TOOLCHAIN_FILE=../Play-/deps/Dependencies/cmake-ios/ios.cmake -DTARGET_IOS=ON -DFRAMEWORK_VULKAN_LIBS=${FRAMEWORK_VULKAN_LIBS} -DUSE_GSH_VULKAN=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=${VULKAN_SDK} -DVulkan_INCLUDE_DIR=${Vulkan_INCLUDE_DIR} -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="iPhone Developer" -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="XXXXXXXXXX" -DCMAKE_XCODE_ATTRIBUTE_PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: *"
