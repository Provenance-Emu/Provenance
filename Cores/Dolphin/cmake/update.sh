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
cmake ../dolphin-ios -G Xcode \
-DCMAKE_TOOLCHAIN_FILE=../dolphin-ios/Source/iOS/ios.toolchain.cmake \
-DENABLE_ANALYTICS=NO \
-DENABLE_AUTOUPDATE=NO \
-DENABLE_BITCODE=NO \
-DENABLE_CLI_TOOL=NO \
-DENABLE_CLI_TOOLS=NO \
-DSDL_HIDAPI=NO \
-DSDL_FRAMEWORK=YES \
-DENABLE_HEADLESS=YES \
-DSDL_RENDER_D3D=NO \
-DENABLE_LTO=YES \
-DENABLE_METAL=YES \
-DENABLE_PULSEAUDIO=NO \
-DSDL_HIDAPI_LIBUSB=NO \
-DSDL_HIDAPI_LIBUSB_SHARED=NO \
-DENABLE_QT=NO \
-DENABLE_SDL=NO \
-DENABLE_TESTS=NO \
-DENABLE_VULKAN=ON \
-DENCODE_FRAMEDUMPS=NO \
-DFMT_INSTALL=YES \
-DMACOS_CODE_SIGNING=NO \
-DPLATFORM=OS64COMBINED \
-DENABLE_NOGUI=NO \
-DSKIP_POSTPROCESS_BUNDLE=ON \
-DUSE_DISCORD_PRESENCE=NO \
-DUSE_MGBA=NO \
-DUSE_RETRO_ACHIEVEMENTS=NO \
-DDEPLOYMENT_TARGET="13.0" \
-DPLATFORM_DEPLOYMENT_TARGET=13 \
-DTARGET_IOS=ON \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="iPhone Developer" \
-DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="XXXXXXXXXX" \
-DCMAKE_XCODE_ATTRIBUTE_PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: *"
# DFRAMEWORK_VULKAN_LIBS=${FRAMEWORK_VULKAN_LIBS} -DUSE_GSH_VULKAN=ON  -DCMAKE_PREFIX_PATH="${VULKAN_SDK}" -DVulkan_INCLUDE_DIR=${Vulkan_INCLUDE_DIR}
python3 xcode_absolute_path_to_relative.py
