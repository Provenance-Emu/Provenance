#!/bin/bash
cmake \
    -DHEADLESS=OFF \
    -DLIBRETRO=ON \
    -DUSE_SYSTEM_LIBZIP=ON \
    -DENABLE_CTEST=OFF \
    -DBUILD_TESTING=OFF \
    -DUSING_X11_VULKAN=OFF \
    -DIOS_PLATFORM=OS \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_TOOLCHAIN_FILE=../ppsspp/cmake/Toolchains/ios.cmake \
    -GXcode \
    ../ppsspp
