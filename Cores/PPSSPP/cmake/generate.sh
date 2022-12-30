#!/usr/bin/env bash
rm -fr C*
if [ ! -d ./ffmpeg ] ; then
  cp -pR ../ppsspp/ffmpeg .
  cp ffmpeg-ios-build.sh ./ffmpeg
  cd ./ffmpeg
  sh ffmpeg-ios-build.sh
  cd ..
fi
export FFMPEG_DIR=../cmake/ffmpeg/ios/universal/
#export FFMPEG_DIR=../cmake/ffmpeg
export LIBZIP_DIR=../ppsspp/ext/native/ext/libzip
cmake \
    -DLIBRETRO=ON \
    -DCMAKE_TOOLCHAIN_FILE=../ppsspp/cmake/Toolchains/ios.cmake \
    -DIOS_PLATFORM=OS \
    -DCMAKE_IOS_SDK_ROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
    -H../ppsspp \
    -B. \
    -GXcode \
    -DCMAKE_PREFIX_PATH=$FFMPEG_DIR \
    -DCMAKE_PREFIX_PATH=$LIBZIP_DIR \
    -DUSE_DISCORD=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_SYSTEM_VERSION=13.0 \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY=1,2,3,4,6 \
    -DCMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET=13.0 
#    -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
#    -DCMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE=NO \
#    -DCMAKE_XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC=YES \
#    -DCMAKE_XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_WEAK=YES \
#    -DCMAKE_XCODE_ATTRIBUTE_CLANG_ENABLE_MODULES=YES 
python3 xcode_absolute_path_to_relative.py
rm -fr CMakeFiles/3.25.0/CompilerIdCXX/XCBuildData/
rm -fr CMakeFiles/3.25.0/CompilerIdC/XCBuildData/
