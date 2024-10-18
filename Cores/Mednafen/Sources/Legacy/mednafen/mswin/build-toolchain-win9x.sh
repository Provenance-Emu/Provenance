#!/bin/bash

#
# apt-get install build-essential pkg-config libmpfr-dev libgmp-dev libmpc-dev gawk
#
GCC_CC="/usr/local/gcc-4.9.4/bin/gcc"
GCC_CXX="/usr/local/gcc-4.9.4/bin/g++"

CROSS_BUILD="/tmp/mednafen-cross-build"
CROSS_SOURCES="$HOME/mednafen-cross-sources"
CROSS_BASE="$HOME/mednafen-cross"
CROSS32_PATH="$CROSS_BASE/win32"
CROSS64_PATH="$CROSS_BASE/win64"
CROSS9X_PATH="$CROSS_BASE/win9x"

PKGNAME_BINUTILS="binutils-2.28"
PKGNAME_MINGWW64="mingw-w64-v5.0.3"
PKGNAME_GCC="gcc-4.9.4"
PKGNAME_LIBICONV="libiconv-1.15"
PKGNAME_FLAC="flac-1.3.2"
PKGNAME_ZLIB="zlib-1.2.8"
PKGNAME_SDL2="SDL-2.0.8-11835"
#
#
#
#
export PATH="$CROSS9X_PATH/bin:$PATH"

mkdir -p "$CROSS_BUILD" && cd "$CROSS_BUILD" && \
rm --one-file-system -rf "buffaloam9x" && mkdir buffaloam9x && cd buffaloam9x && \
tar -jxf "$CROSS_SOURCES/$PKGNAME_BINUTILS.tar.bz2" && \
tar -jxf "$CROSS_SOURCES/$PKGNAME_MINGWW64.tar.bz2" && \
tar -jxf "$CROSS_SOURCES/$PKGNAME_GCC.tar.bz2" && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_LIBICONV.tar.gz" && \
tar -Jxf "$CROSS_SOURCES/$PKGNAME_FLAC.tar.xz" && \

patch -p0 < "$CROSS_SOURCES/$PKGNAME_GCC-win9x.patch" && \
patch -p0 < "$CROSS_SOURCES/$PKGNAME_MINGWW64-win9x.patch" && \
patch -p0 < "$CROSS_SOURCES/$PKGNAME_FLAC-win9x.patch" && cd "$PKGNAME_FLAC" && ./autogen.sh && cd .. && \
cd .. && \

rm --one-file-system -rf "buffalo9x" && mkdir buffalo9x && cd buffalo9x && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_ZLIB.tar.gz" && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_SDL2.tar.gz" && \
patch -p0 < "$CROSS_SOURCES/$PKGNAME_ZLIB-mingw-w64.patch" && \
patch -p0 < "$CROSS_SOURCES/$PKGNAME_ZLIB-win9x.patch" && \
patch -p0 < "$CROSS_SOURCES/$PKGNAME_SDL2-win9x.patch" && \
cd .. && \

#
#
#
#
#
#
#
#
#
cd buffalo9x && \
#
# binutils
#
mkdir binutils && cd binutils && \
../../buffaloam9x/"$PKGNAME_BINUTILS"/configure --prefix="$CROSS9X_PATH" --target=i486-w64-mingw32 --disable-multilib && \
make -j4 && make install && \
cd .. && \

#
# mingw-w64 headers
#
mkdir headers && cd headers && \
../../buffaloam9x/"$PKGNAME_MINGWW64"/mingw-w64-headers/configure --prefix="$CROSS9X_PATH"/i486-w64-mingw32 --target=i486-w64-mingw32 && \
make && make install && \
cd .. && \

#
# gcc
#
mkdir gcc && cd gcc && \
CC="$GCC_CC" CXX="$GCC_CXX" ../../buffaloam9x/"$PKGNAME_GCC"/configure --prefix="$CROSS9X_PATH" --target=i486-w64-mingw32 --disable-multilib --enable-languages=c,c++ --disable-sjlj-exceptions --with-dwarf2 && \
make all-gcc -j4 && make install-gcc && \
cd .. && \

#
# mingw-w64 CRT
#
mkdir crt && cd crt && \
CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables -march=i486 -mtune=pentium2" ../../buffaloam9x/"$PKGNAME_MINGWW64"/mingw-w64-crt/configure --prefix="$CROSS9X_PATH"/i486-w64-mingw32 --host=i486-w64-mingw32 && \
make -j4 && make install && \
cd .. && \

#
# gcc finish
#
cd gcc && \
make -j4 && make install && \
cd .. && \

##################################################################


#
# libiconv
#
mkdir libiconv && cd libiconv && \
CPPFLAGS="-I$CROSS9X_PATH/include" CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables -march=i486 -mtune=pentium2" LDFLAGS="-L$CROSS9X_PATH/lib" \
	../../buffaloam9x/"$PKGNAME_LIBICONV"/configure --prefix="$CROSS9X_PATH" --host=i486-w64-mingw32 --enable-extra-encodings --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

#
# zlib
#
cd "$PKGNAME_ZLIB" && \
CPPFLAGS="-I$CROSS9X_PATH/include" LDFLAGS="-L$CROSS9X_PATH/lib" \
	CFLAGS="-O2 -Wall -mstackrealign -D_LFS64_LARGEFILE=1 -fno-exceptions -fno-asynchronous-unwind-tables -march=i486 -mtune=pentium2" RANLIB=i486-w64-mingw32-ranlib AR=i486-w64-mingw32-ar \
	CC=i486-w64-mingw32-gcc CXX=i486-w64-mingw32-g++ CPP=i486-w64-mingw32-cpp \
	./configure --prefix="$CROSS9X_PATH" --static && \
make -j4 && make install && \
cd .. && \

#
# SDL 2.0
#
cd "$PKGNAME_SDL2" && \
CPPFLAGS="-I$CROSS9X_PATH/include" LDFLAGS="-L$CROSS9X_PATH/lib" \
	CFLAGS="-O2 -mstackrealign -fomit-frame-pointer -g -march=i486 -mtune=pentium2 -fno-exceptions -fno-asynchronous-unwind-tables" \
	./configure --prefix="$CROSS9X_PATH" --host=i486-w64-mingw32 --disable-pthreads --disable-shared --enable-static --disable-audio --disable-render --disable-joystick --disable-haptic --disable-power --disable-ime --disable-filesystem --disable-file --disable-sse --disable-sse2 --disable-sse3 --disable-ssemath --disable-libsamplerate --disable-video-opengles --disable-video-opengles1 --disable-video-opengles2 --disable-video-vulkan && \
make -j4 && make install && \
cd .. && \

#
# flac
#
mkdir flac && cd flac && \
PKG_CONFIG_PATH="$CROSS9X_PATH/lib/pkgconfig" CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables -march=i486 -mtune=pentium2" CPPFLAGS="-I$CROSS9X_PATH/include" LDFLAGS="-L$CROSS9X_PATH/lib" \
        ../../buffaloam9x/"$PKGNAME_FLAC"/configure --prefix="$CROSS9X_PATH" --host=i486-w64-mingw32 --disable-shared --enable-static --disable-sse --disable-ogg --disable-oggtest --disable-xmms-plugin --disable-cpplibs && \
make -j4 && make install && \
cd .. && \

#
#
#
cd .. && \
#
#
#
echo "Done."

