#!/bin/bash

CROSS_BASE="$HOME/mednafen-cross"
CROSS32_PATH="$CROSS_BASE/win32"
CROSS64_PATH="$CROSS_BASE/win64"
CROSS9X_PATH="$CROSS_BASE/win9x"
export PATH="$CROSS32_PATH/bin:$CROSS64_PATH/bin:$CROSS9X_PATH/bin:$PATH"

rm --one-file-system -r build9x
mkdir build9x && \
cd build9x && \
cp "$CROSS9X_PATH/i486-w64-mingw32/lib/"*.dll . && \
cp "$CROSS9X_PATH/bin/"*.dll . && \
PKG_CONFIG_PATH="$CROSS9X_PATH/lib/pkgconfig" PATH="$CROSS9X_PATH/bin:$PATH" CPPFLAGS="-I$CROSS9X_PATH/include -DNTDDI_VERSION=0x0410" LDFLAGS="-L$CROSS9X_PATH/lib -static-libstdc++" CFLAGS="-O2 -march=i686 -mtune=pentium2" CXXFLAGS="$CFLAGS" ../mednafen/configure --host=i486-w64-mingw32 --disable-alsa --disable-jack --enable-threads=win32 --with-sdl-prefix="$CROSS9X_PATH" && \
make -j4 V=0 && \
cd .. && \
#
#
#
echo "Done."

