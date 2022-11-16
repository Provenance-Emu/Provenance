#!/usr/bin/env bash
rm -fr C*
if [ ! -d ./ffmpeg ] ; then
  cp -pR ../libretro_ppsspp/ffmpeg .
  cp ffmpeg-ios-build.sh ./ffmpeg
  cd ./ffmpeg
  sh ffmpeg-ios-build.sh
  cd ..
fi
export FFMPEG_DIR=../cmake/ffmpeg/ios/universal/
#export FFMPEG_DIR=../cmake/ffmpeg
export LIBZIP_DIR=../libretro_ppsspp/ext/native/ext/libzip
cmake \
    -DCMAKE_TOOLCHAIN_FILE=../libretro_ppsspp/cmake/Toolchains/ios.cmake \
    -DIOS_PLATFORM=OS \
    -DCMAKE_IOS_SDK_ROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
    -H../libretro_ppsspp \
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
rm -fr build
rm -fr CMakeFiles/3.25.0/CompilerIdCXX/XCBuildData/
rm -fr CMakeFiles/3.25.0/CompilerIdC/XCBuildData/
rm -fr CMakeFiles/3.25.0/CompilerIdC/CompilerIdC.build/
rm -fr CMakeFiles/3.25.0/CompilerIdCXX/CompilerIdCXX.build/
rm -fr CMakeFiles/3.25.0/CompilerIdCXX/CompilerIdCXX.build/
rm -fr PPSSPP.xcodeproj/project.xcworkspace/xcuserdata/
rm -fr CMakeFiles
python3 xcode_absolute_path_to_relative.py
echo 'Please open / compile the project with  "open PPSSPP.xcodeproj", apply customizations / adjustments, then run "sh generate_post.sh"'
