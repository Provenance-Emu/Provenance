#!/usr/bin/env bash
#export Vulkan_LIBRARY=1.3.204.1 # Version of Vulkan SDK
#export VULKAN_SDK="~/VulkanSDK/${Vulkan_LIBRARY}/macOS" # Path to Vulkan SDK
#export Vulkan_INCLUDE_DIR="~/VulkanSDK/${Vulkan_LIBRARY}/MoltenVK/include"
#export FRAMEWORK_VULKAN_LIBS="~/VulkanSDK/${Vulkan_LIBRARY}/MoltenVK/dylib/iOS"
#export Vulkan_LIBRARY="~/VulkanSDK/${Vulkan_LIBRARY}/"

export Vulkan_LIBRARY=1.3.217 # Version of Vulkan SDK
export VULKAN_SDK="./" # Path to Vulkan SDK
export Vulkan_INCLUDE_DIR="../../../MoltenVK/MoltenVK/include"
export FRAMEWORK_VULKAN_LIBS="../../../MoltenVK/MoltenVK/dylib/iOS/libMoltenVK.dylib"
export Vulkan_LIBRARY="./"
ln -s ../../../Cores/Dolphin/dolphin-ios/Externals/MoltenVK lib
# ln -s ../../../../MoltenVK/MoltenVK ../Play-/Source/MoltenVK

#export Vulkan_LIBRARY=1.3.204 # Version of Vulkan SDK
#export VULKAN_SDK="./MoltenVK" # Path to Vulkan SDK
#export Vulkan_INCLUDE_DIR="./MoltenVK/include"
#export FRAMEWORK_VULKAN_LIBS="./MoltenVK/dylib/iOS/libMoltenVK.dylib"
#export Vulkan_LIBRARY="./MoltenVK"
#ln -s ../../../cmake/MoltenVK ../Play-/Source/ui_ios/MoltenVK

# This sets mobile to true...
# cp ../PVPlayCore/Core/GSH_VulkanPlatformDefs.h ../Play-/Source/gs/GSH_Vulkan/
rm CMakeCache.txt
echo "VULKAN_SDK="${VULKAN_SDK}
cmake ../duckstation -G Xcode \
-DCMAKE_BUILD_TYPE=Release \
-DPLATFORM=OS64COMBINED \
-DTARGET_IOS=ON \
-DDEPLOYMENT_TARGET=13.0 \
-DENABLE_BITCODE=OFF \
-DFRAMEWORK_VULKAN_LIBS=${FRAMEWORK_VULKAN_LIBS} \
-DUSE_GSH_VULKAN=ON \
-DBUILD_NOGUI_FRONTEND=ON \
-DBUILD_QT_FRONTEND=OFF \
-DUSE_SDL2=OFF \
-DBUILD_REGTEST=OFF \
-DENABLE_CUBEB=OFF \
-DENABLE_VULKAN=ON \
-DENABLE_OPENGL=ON \
-DENABLE_DISCORD_PRESENCE=OFF \
-DENABLE_CHEEVOS=OFF \
-DUSE_SDL2=OFF \
-DUSE_X11=OFF \
-DUSE_WAYLAND=OFF \
-DCMAKE_C_FLAGS_RELEASE="-Os -DNDEBUG" \
-DCMAKE_CXX_FLAGS_RELEASE="-Os -DNDEBUG" \
-DCMAKE_PREFIX_PATH="${VULKAN_SDK}" \
-DVulkan_INCLUDE_DIR=${Vulkan_INCLUDE_DIR} \
-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="iPhone Developer" \
-DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="XXXXXXXXXX" \
-DCMAKE_TOOLCHAIN_FILE=../ios.toolchain.cmake \
-DCMAKE_XCODE_ATTRIBUTE_PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: *"

# -Bbuild-release \
# -DUSE_EGL=ON \

# Path adjustements
python3 xcode_absolute_path_to_relative.py
