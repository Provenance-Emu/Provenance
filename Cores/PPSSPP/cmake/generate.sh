#!/bin/bash
cmake \
    -DUSE_FFMPEG=ON \
    -DHEADLESS=ON \
    -DCOCOA_LIBRARY=UIKit \
    -DLIBRETRO=ON \
    -DUSE_DISCORD=OFF \
    -DUSE_MINIUPNPC=OFF \
    -DUSE_SYSTEM_LIBZIP=ON \
    -DENABLE_CTEST=OFF \
    -DUSE_SYSTEM_LIBPNG=OFF \
    -DBUILD_TESTING=OFF \
    -DUSING_X11_VULKAN=OFF \
    -DIOS_PLATFORM=OS \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_TOOLCHAIN_FILE=../ppsspp/cmake/Toolchains/ios.cmake \
    -GXcode \
    ../ppsspp
