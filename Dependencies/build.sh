#!/usr/bin/env bash
# #########
# https://github.com/Provenance-Emu/MoltenVK#building-from-the-command-line
# Build script for MoltenVK
#
# This script will build MoltenVK for macOS and iOS.
# It will also build the MoltenVK Package for macOS.
# Options
# MVK_HIDE_VULKAN_SYMBOLS=1
# MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS=1
# #########

#export Vulkan_LIBRARY=
#export VULKAN_SDK="~/VulkanSDK/${Vulkan_LIBRARY}/macOS" # Path to Vulkan SDK
#export Vulkan_INCLUDE_DIR="~/VulkanSDK/${Vulkan_LIBRARY}/MoltenVK/include"
#export FRAMEWORK_VULKAN_LIBS="~/VulkanSDK/${Vulkan_LIBRARY}/MoltenVK/dylib/iOS"
#export Vulkan_LIBRARY="~/VulkanSDK/${Vulkan_LIBRARY}/"
brew install cmake
brew install python3
brew install ninja
cd MoltenVK
./fetchDependencies --all
make clean
make -j8 all
# xcodebuild build -quiet -project MoltenVKPackaging.xcodeproj -scheme "MoltenVK Package (macOS only)" -configuration "Debug"