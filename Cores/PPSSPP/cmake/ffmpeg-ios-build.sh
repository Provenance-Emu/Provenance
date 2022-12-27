#!/bin/bash
#build ffmpeg for all archs and uses lipo to create fat libraries and deletes the originals

set -e

. shared_options.sh
PATH=$(PWD)/gas-preprocessor:$PATH

ARCHS="arm64"

for arch in ${ARCHS}; do
  rm -f config.h

  ffarch=${arch}
  versionmin=6.0
  cpu=generic

  if [[ ${arch} == "arm64" ]]; then
    sdk=iphoneos
    ffarch=aarch64
    versionmin=7.0
  elif [[ ${arch} == "i386" ]]; then
    sdk=iphonesimulator
    ffarch=x86
  elif [[ ${arch} == "x86_64" ]]; then
    sdk=iphonesimulator
  fi

  ./configure \
    --prefix=ios/${arch} \
    --enable-cross-compile \
    --arch=${ffarch} \
    --cc=$(xcrun -f clang) \
    --sysroot="$(xcrun --sdk ${sdk} --show-sdk-path)" \
    --extra-cflags="-arch ${arch} -D_DARWIN_FEATURE_CLOCK_GETTIME=0 -miphoneos-version-min=${versionmin} ${cflags}" \
    ${CONFIGURE_OPTS} \
    --extra-ldflags="-arch ${arch} -isysroot $(xcrun --sdk ${sdk} --show-sdk-path) -miphoneos-version-min=${versionmin}" \
    --target-os=darwin \
    ${extraopts} \
    --cpu=${cpu} \
    --enable-pic

  make clean
  make -j8 install
done

cd ios
mkdir -p universal/lib

for i in arm64/lib/*.a; do
  libname=$(basename $i)
  xcrun lipo -create $(
    for a in ${ARCHS}; do
      echo -arch ${a} ${a}/lib/${libname}
    done
  ) -output universal/lib/${libname}
done

cp -r arm64/include universal/

rm -rf ${ARCHS}
