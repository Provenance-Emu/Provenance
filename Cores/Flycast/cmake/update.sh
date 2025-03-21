#/usr/bin/env bash
export Vulkan_LIBRARY=1.3.250 # Version of Vulkan SDK
export VULKAN_SDK="../../../MoltenVK/MoltenVK" # Path to Vulkan SDK
export Vulkan_INCLUDE_DIR="../../../MoltenVK/MoltenVK/include"
export FRAMEWORK_VULKAN_LIBS="../../../MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework"
export Vulkan_LIBRARY="../../../MoltenVK/MoltenVK"
export RELATIVE_PATH=1
export CMAKE_USE_RELATIVE_PATHS=ON
export CMAKE_SKIP_RPATH=ON
export VERBOSE=1

# Remove previous CMake configuration
rm -rf CMakeCache.txt CMakeFiles/

# This sets mobile to true...
echo "VULKAN_SDK="${VULKAN_SDK}
cmake -B . -S ../flycast -G Xcode \
-DCMAKE_SYSTEM_NAME=iOS \
-DUSE_GLES2=ON \
-DLIBRETRO=ON \
-DTARGET_IOS=ON \
-DUSE_OPENMP=ON \
-DUSE_OPENGL=OFF \
-DIOS=ON \
-DAPPLE=ON \
-DTARGET_NO_EXCEPTIONS=ON \
-D_OPENMP=ON \
-D__APPLE__=ON \
-DFRAMEWORK_VULKAN_LIBS=${FRAMEWORK_VULKAN_LIBS} \
-DCMAKE_USE_RELATIVE_PATHS=ON \
-DCMAKE_SKIP_RPATH=ON \
-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=OFF \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_C_FLAGS_RELEASE="-Ofast -DNDEBUG" \
-DCMAKE_CXX_FLAGS_RELEASE="-Ofast -DNDEBUG" \
-DCMAKE_PREFIX_PATH="${VULKAN_SDK}" \
-DVulkan_INCLUDE_DIR=${Vulkan_INCLUDE_DIR} \
-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="iPhone Developer" \
-DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="XXXXXXXXXX" \
-DCMAKE_XCODE_ATTRIBUTE_PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: *"

# Path adjustements
python3 xcode_absolute_path_to_relative.py
find . -name "*.make" -exec rm {} \;
find . -name "*.cmake" -exec rm {} \;
