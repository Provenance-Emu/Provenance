#!/bin/bash

#
# apt-get install build-essential pkg-config libmpfr-dev libgmp-dev libmpc-dev gawk
#

CROSS32_PATH="$HOME/cross-mswin32"
CROSS64_PATH="$HOME/cross-mswin64"
CROSS_SOURCES="$HOME/toolchain-sources"
CROSS_BUILD="$HOME/cross-mswin-build"

PKGNAME_BINUTILS="binutils-2.28"
PKGNAME_MINGWW64="mingw-w64-v5.0.3"
PKGNAME_GCC="gcc-4.9.4"
PKGNAME_LIBICONV="libiconv-1.15"
PKGNAME_FLAC="flac-1.3.2"
PKGNAME_LIBOGG="libogg-1.3.3"
PKGNAME_LIBVORBIS="libvorbis-1.3.5"
PKGNAME_LIBSNDFILE="libsndfile-1.0.28"
PKGNAME_ZLIB="zlib-1.2.8"
PKGNAME_SDL="SDL-1.2.15"
PKGNAME_SDL2="SDL-2.0.8-11835"

export PATH="$CROSS32_PATH/bin:$CROSS64_PATH/bin:$PATH"

mkdir -p "$CROSS_BUILD" && cd "$CROSS_BUILD" && \
rm --one-file-system -rf "buffaloam" && mkdir buffaloam && cd buffaloam && \
tar -jxf "$CROSS_SOURCES/$PKGNAME_BINUTILS.tar.bz2" && \
tar -jxf "$CROSS_SOURCES/$PKGNAME_MINGWW64.tar.bz2" && \
tar -jxf "$CROSS_SOURCES/$PKGNAME_GCC.tar.bz2" && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_LIBICONV.tar.gz" && \
tar -Jxf "$CROSS_SOURCES/$PKGNAME_FLAC.tar.xz" && \
tar -Jxf "$CROSS_SOURCES/$PKGNAME_LIBOGG.tar.xz" && \
tar -Jxf "$CROSS_SOURCES/$PKGNAME_LIBVORBIS.tar.xz" && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_LIBSNDFILE.tar.gz" && \

patch -p0 < "$CROSS_SOURCES/$PKGNAME_GCC-mingw-w64-noforcepic-smalljmptab.patch" && \
cd .. && \

rm --one-file-system -rf "buffalo32" && mkdir buffalo32 && cd buffalo32 && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_ZLIB.tar.gz" && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_SDL.tar.gz" && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_SDL2.tar.gz" && \
patch -p0 < "$CROSS_SOURCES/$PKGNAME_ZLIB-mingw-w64.patch" && \
cd .. && \

rm --one-file-system -rf "buffalo64" && mkdir buffalo64 && cd buffalo64 && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_ZLIB.tar.gz" && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_SDL.tar.gz" && \
tar -zxf "$CROSS_SOURCES/$PKGNAME_SDL2.tar.gz" && \
patch -p0 < "$CROSS_SOURCES/$PKGNAME_ZLIB-mingw-w64.patch" && \
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
cd buffalo32 && \
#
# binutils
#
mkdir binutils && cd binutils && \
../../buffaloam/"$PKGNAME_BINUTILS"/configure --prefix="$CROSS32_PATH" --target=i686-w64-mingw32 --disable-multilib && \
make -j4 && make install && \
cd .. && \

#
# mingw-w64 headers
#
mkdir headers && cd headers && \
../../buffaloam/"$PKGNAME_MINGWW64"/mingw-w64-headers/configure --prefix="$CROSS32_PATH"/i686-w64-mingw32 --target=i686-w64-mingw32 && \
make && make install && \
cd .. && \

#
# gcc
#
mkdir gcc && cd gcc && \
../../buffaloam/"$PKGNAME_GCC"/configure --prefix="$CROSS32_PATH" --target=i686-w64-mingw32 --disable-multilib --enable-languages=c,c++ --disable-sjlj-exceptions --with-dwarf2 && \
make all-gcc -j4 && make install-gcc && \
cd .. && \

#
# mingw-w64 CRT
#
mkdir crt && cd crt && \
CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables -march=i686 -mtune=pentium3" ../../buffaloam/"$PKGNAME_MINGWW64"/mingw-w64-crt/configure --prefix="$CROSS32_PATH"/i686-w64-mingw32 --host=i686-w64-mingw32 && \
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
CPPFLAGS="-I$CROSS32_PATH/include" CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables -march=i686 -mtune=pentium3" LDFLAGS="-L$CROSS32_PATH/lib" \
	../../buffaloam/"$PKGNAME_LIBICONV"/configure --prefix="$CROSS32_PATH" --host=i686-w64-mingw32 --enable-extra-encodings --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

#
# zlib
#
cd "$PKGNAME_ZLIB" && \
CPPFLAGS="-I$CROSS32_PATH/include" LDFLAGS="-L$CROSS32_PATH/lib" \
	CFLAGS="-O2 -Wall -mstackrealign -D_LFS64_LARGEFILE=1 -fno-exceptions -fno-asynchronous-unwind-tables -march=i686 -mtune=pentium3" RANLIB=i686-w64-mingw32-ranlib AR=i686-w64-mingw32-ar \
	CC=i686-w64-mingw32-gcc CXX=i686-w64-mingw32-g++ CPP=i686-w64-mingw32-cpp \
	./configure --prefix="$CROSS32_PATH" --static && \
make -j4 && make install && \
cd .. && \

#
# SDL 1.2
#
cd "$PKGNAME_SDL" && \
CPPFLAGS="-I$CROSS32_PATH/include" LDFLAGS="-L$CROSS32_PATH/lib" \
	CFLAGS="-O2 -mstackrealign -fomit-frame-pointer -g -march=i686 -mtune=pentium3 -fno-exceptions -fno-asynchronous-unwind-tables" \
	./configure --prefix="$CROSS32_PATH" --host=i686-w64-mingw32 --disable-pthreads --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

#
# SDL 2.0
#
cd "$PKGNAME_SDL2" && \
CPPFLAGS="-I$CROSS32_PATH/include" LDFLAGS="-L$CROSS32_PATH/lib" \
	CFLAGS="-O2 -mstackrealign -fomit-frame-pointer -g -march=i686 -mtune=pentium3 -fno-exceptions -fno-asynchronous-unwind-tables" \
	./configure --prefix="$CROSS32_PATH" --host=i686-w64-mingw32 --disable-pthreads --enable-shared --disable-static --disable-filesystem --disable-file --disable-ssemath --disable-libsamplerate && \
make -j4 && make install && \
cd .. && \

#
# libogg
#
mkdir libogg && cd libogg && \
CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables -march=i686 -mtune=pentium3" CPPFLAGS="-I$CROSS32_PATH/include" LDFLAGS="-L$CROSS32_PATH/lib" \
        ../../buffaloam/"$PKGNAME_LIBOGG"/configure --prefix="$CROSS32_PATH" --host=i686-w64-mingw32 --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

#
# vorbis
#
mkdir libvorbis && cd libvorbis && \
PKG_CONFIG_PATH="$CROSS32_PATH/lib/pkgconfig" CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables -march=i686 -mtune=pentium3" CPPFLAGS="-I$CROSS32_PATH/include" LDFLAGS="-L$CROSS32_PATH/lib" \
        ../../buffaloam/"$PKGNAME_LIBVORBIS"/configure --prefix="$CROSS32_PATH" --host=i686-w64-mingw32 --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

#
# flac
#
mkdir flac && cd flac && \
PKG_CONFIG_PATH="$CROSS32_PATH/lib/pkgconfig" CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables -march=i686 -mtune=pentium3" CPPFLAGS="-I$CROSS32_PATH/include" LDFLAGS="-L$CROSS32_PATH/lib" \
        ../../buffaloam/"$PKGNAME_FLAC"/configure --prefix="$CROSS32_PATH" --host=i686-w64-mingw32 --enable-shared --disable-static --disable-sse && \
make -j4 && make install && \
cd .. && \

#
# libsndfile
#
mkdir libsndfile && cd libsndfile && \
PKG_CONFIG_PATH="$CROSS32_PATH/lib/pkgconfig" CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables -march=i686 -mtune=pentium3" CPPFLAGS="-I$CROSS32_PATH/include" LDFLAGS="-L$CROSS32_PATH/lib" \
        ../../buffaloam/"$PKGNAME_LIBSNDFILE"/configure --prefix="$CROSS32_PATH" --host=i686-w64-mingw32 --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

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
cd buffalo64 && \
#
# binutils
#
mkdir binutils && cd binutils && \
../../buffaloam/"$PKGNAME_BINUTILS"/configure --prefix="$CROSS64_PATH" --target=x86_64-w64-mingw32 --disable-multilib && \
make -j4 && make install && \
cd .. && \

#
# mingw-w64 headers
#
mkdir headers && cd headers && \
../../buffaloam/"$PKGNAME_MINGWW64"/mingw-w64-headers/configure --prefix="$CROSS64_PATH"/x86_64-w64-mingw32 --target=x86_64-w64-mingw32 && \
make && make install && \
cd .. && \

#
# gcc
#
mkdir gcc && cd gcc && \
../../buffaloam/"$PKGNAME_GCC"/configure --prefix="$CROSS64_PATH" --target=x86_64-w64-mingw32 --disable-multilib --enable-languages=c,c++ && \
make all-gcc -j4 && make install-gcc && \
cd .. && \

#
# mingw-w64 CRT
#
mkdir crt && cd crt && \
CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables" ../../buffaloam/"$PKGNAME_MINGWW64"/mingw-w64-crt/configure --prefix="$CROSS64_PATH"/x86_64-w64-mingw32 --host=x86_64-w64-mingw32 --disable-lib32 --enable-lib64 && \
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
CPPFLAGS="-I$CROSS64_PATH/include" CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables" LDFLAGS="-L$CROSS64_PATH/lib" \
	../../buffaloam/"$PKGNAME_LIBICONV"/configure --prefix="$CROSS64_PATH" --host=x86_64-w64-mingw32 --enable-extra-encodings --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

#
# zlib
#
cd "$PKGNAME_ZLIB" && \
CPPFLAGS="-I$CROSS64_PATH/include" LDFLAGS="-L$CROSS64_PATH/lib" \
	CFLAGS="-O2 -Wall -mstackrealign -D_LFS64_LARGEFILE=1 -fno-exceptions -fno-asynchronous-unwind-tables" RANLIB=x86_64-w64-mingw32-ranlib AR=x86_64-w64-mingw32-ar \
	CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ CPP=x86_64-w64-mingw32-cpp \
	./configure --prefix="$CROSS64_PATH" --static && \
make -j4 && make install && \
cd .. && \

#
# SDL 1.2
#
cd "$PKGNAME_SDL" && \
CPPFLAGS="-I$CROSS64_PATH/include" LDFLAGS="-L$CROSS64_PATH/lib" \
	CFLAGS="-O2 -mstackrealign -fomit-frame-pointer -g -fno-exceptions -fno-asynchronous-unwind-tables" \
	./configure --prefix="$CROSS64_PATH" --host=x86_64-w64-mingw32 --disable-pthreads --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

#
# SDL 2.0
#
cd "$PKGNAME_SDL2" && \
CPPFLAGS="-I$CROSS64_PATH/include" LDFLAGS="-L$CROSS64_PATH/lib" \
	CFLAGS="-O2 -mstackrealign -fomit-frame-pointer -g -fno-exceptions -fno-asynchronous-unwind-tables" \
	./configure --prefix="$CROSS64_PATH" --host=x86_64-w64-mingw32 --disable-pthreads --enable-shared --disable-static --disable-filesystem --disable-file --disable-libsamplerate && \
make -j4 && make install && \
cd .. && \

#
# libogg
#
mkdir libogg && cd libogg && \
CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables" CPPFLAGS="-I$CROSS64_PATH/include" LDFLAGS="-L$CROSS64_PATH/lib" \
        ../../buffaloam/"$PKGNAME_LIBOGG"/configure --prefix="$CROSS64_PATH" --host=x86_64-w64-mingw32 --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

#
# vorbis
#
mkdir libvorbis && cd libvorbis && \
PKG_CONFIG_PATH="$CROSS64_PATH/lib/pkgconfig" CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables" CPPFLAGS="-I$CROSS64_PATH/include" LDFLAGS="-L$CROSS64_PATH/lib" \
        ../../buffaloam/"$PKGNAME_LIBVORBIS"/configure --prefix="$CROSS64_PATH" --host=x86_64-w64-mingw32 --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

#
# flac
#
mkdir flac && cd flac && \
PKG_CONFIG_PATH="$CROSS64_PATH/lib/pkgconfig" CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables" CPPFLAGS="-I$CROSS64_PATH/include" LDFLAGS="-L$CROSS64_PATH/lib" \
        ../../buffaloam/"$PKGNAME_FLAC"/configure --prefix="$CROSS64_PATH" --host=x86_64-w64-mingw32 --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \

#
# libsndfile
#
mkdir libsndfile && cd libsndfile && \
PKG_CONFIG_PATH="$CROSS64_PATH/lib/pkgconfig" CFLAGS="-O2 -g -fno-exceptions -fno-asynchronous-unwind-tables" CPPFLAGS="-I$CROSS64_PATH/include" LDFLAGS="-L$CROSS64_PATH/lib" \
        ../../buffaloam/"$PKGNAME_LIBSNDFILE"/configure --prefix="$CROSS64_PATH" --host=x86_64-w64-mingw32 --enable-shared --disable-static && \
make -j4 && make install && \
cd .. && \
echo "Done."

