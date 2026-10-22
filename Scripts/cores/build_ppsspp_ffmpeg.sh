#!/bin/bash
# Build the legacy PPSSPP codec ABI for Apple simulators without modifying the submodule.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CORE="$ROOT/Cores/PPSSPP"
SOURCE="$CORE/libretro_ppsspp/ffmpeg"
WORK="${PV_PPSSPP_FFMPEG_BUILD:-$ROOT/build/ppsspp-ffmpeg}"
OUTPUT="$CORE/SwiftPM/FFmpeg/PPSSPPFFmpeg.xcframework"
JOBS="${JOBS:-4}"
mkdir -p "$WORK"
# Use the upstream feature set, preserving the decoder/encoder ABI used by this core.
. "$SOURCE/shared_options.sh"
for sdk in iphonesimulator appletvsimulator; do
    case "$sdk" in
        iphonesimulator) triple=arm64-apple-ios17.0-simulator ;;
        appletvsimulator) triple=arm64-apple-tvos17.0-simulator ;;
    esac
    build="$WORK/$sdk"
    mkdir -p "$build"
    (
        cd "$build"
        "$SOURCE/configure" --prefix="$build/install" --enable-cross-compile \
            --arch=aarch64 --target-os=darwin --cpu=generic --enable-pic \
            --cc="$(xcrun --sdk "$sdk" -f clang)" \
            --sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)" \
            --extra-cflags="-target $triple -D_DARWIN_FEATURE_CLOCK_GETTIME=0 -Wno-incompatible-function-pointer-types" \
            --extra-ldflags="-target $triple" \
            $CONFIGURE_OPTS
        make -j"$JOBS"
        make install
        xcrun libtool -static -o "$build/libPPSSPPFFmpeg.a" "$build"/install/lib/*.a
    )
done
# Keep the already-shipped device code. Never rewrite its Mach-O platform to simulate a slice.
for platform in ios tvos; do
    mkdir -p "$WORK/$platform"
    case "$platform" in
        ios) libraries="$CORE/cmake/ffmpeg/ios/universal/lib" ;;
        tvos) libraries="$CORE/cmake/ffmpeg/appletvos/lib" ;;
    esac
    xcrun libtool -static -o "$WORK/$platform/libPPSSPPFFmpeg.a" "$libraries"/*.a
done
mkdir -p "$(dirname "$OUTPUT")"
# Build a new bundle before replacing the previous output, so failures preserve the last good one.
rm -rf "$WORK/PPSSPPFFmpeg.xcframework"
xcodebuild -create-xcframework \
    -library "$WORK/ios/libPPSSPPFFmpeg.a" \
    -library "$WORK/iphonesimulator/libPPSSPPFFmpeg.a" \
    -library "$WORK/tvos/libPPSSPPFFmpeg.a" \
    -library "$WORK/appletvsimulator/libPPSSPPFFmpeg.a" \
    -output "$WORK/PPSSPPFFmpeg.xcframework"
rm -rf "$OUTPUT"
cp -R "$WORK/PPSSPPFFmpeg.xcframework" "$OUTPUT"
