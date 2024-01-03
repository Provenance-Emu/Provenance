#/usr/bin/env bash
export Vulkan_LIBRARY=1.3.250 # Version of Vulkan SDK
export VULKAN_SDK="./MoltenVK" # Path to Vulkan SDK
export Vulkan_INCLUDE_DIR="./MoltenVK/include"
export FRAMEWORK_VULKAN_LIBS="./MoltenVK/dylib/iOS/libMoltenVK.dylib"
export Vulkan_LIBRARY="./MoltenVK"

# This sets mobile to true...
echo "VULKAN_SDK="${VULKAN_SDK}
cmake ../flycast -G Xcode \
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
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_C_FLAGS_RELEASE="-Ofast -DNDEBUG" \
-DCMAKE_CXX_FLAGS_RELEASE="-Ofast -DNDEBUG" \
-DCMAKE_PREFIX_PATH="${VULKAN_SDK}" \
-DVulkan_INCLUDE_DIR=${Vulkan_INCLUDE_DIR} \
-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="iPhone Developer" \
-DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="XXXXXXXXXX" \
-DCMAKE_XCODE_ATTRIBUTE_PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: *"

# Path adjustements
#python3 xcode_absolute_path_to_relative.py
#find . -name "*.make" -exec rm {} \;
#find . -name "*.cmake" -exec rm {} \;
