#!/bin/bash

CROSS_BASE="$HOME/mednafen-cross"
CROSS32_PATH="$CROSS_BASE/win32"
CROSS64_PATH="$CROSS_BASE/win64"
CROSS9X_PATH="$CROSS_BASE/win9x"
export PATH="$CROSS32_PATH/bin:$CROSS64_PATH/bin:$CROSS9X_PATH/bin:$PATH"

rm --one-file-system -r build32 build64
mkdir build32 build64 && \
cd build32 && \
cp "$CROSS32_PATH/i686-w64-mingw32/lib/"*.dll . && \
cp "$CROSS32_PATH/bin/"*.dll . && \
PKG_CONFIG_PATH="$CROSS32_PATH/lib/pkgconfig" PATH="$CROSS32_PATH/bin:$PATH" CPPFLAGS="-I$CROSS32_PATH/include -DUNICODE=1 -D_UNICODE=1" LDFLAGS="-L$CROSS32_PATH/lib -static-libstdc++" ../mednafen/configure --host=i686-w64-mingw32 --disable-alsa --disable-jack --enable-threads=win32 --with-sdl-prefix="$CROSS32_PATH" && \
make -j4 V=0 && \
cd .. && \
#
#
#
cd build64 && \
cp "$CROSS64_PATH/x86_64-w64-mingw32/lib/"*.dll . && \
cp "$CROSS64_PATH/bin/"*.dll . && \
PKG_CONFIG_PATH="$CROSS64_PATH/lib/pkgconfig" PATH="$CROSS64_PATH/bin:$PATH" CPPFLAGS="-I$CROSS64_PATH/include -DUNICODE=1 -D_UNICODE=1" LDFLAGS="-L$CROSS64_PATH/lib -static-libstdc++" ../mednafen/configure --host=x86_64-w64-mingw32 --disable-alsa --disable-jack --enable-threads=win32 --with-sdl-prefix="$CROSS64_PATH" && \
make -j4 V=0 && \
cd .. && \
#
#
#
echo "Done."
