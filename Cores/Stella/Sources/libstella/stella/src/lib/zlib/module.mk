MODULE := src/lib/zlib

MODULE_OBJS := \
	src/lib/zlib/adler32.o \
	src/lib/zlib/compress.o \
	src/lib/zlib/crc32.o \
	src/lib/zlib/gzclose.o \
	src/lib/zlib/gzlib.o \
	src/lib/zlib/gzread.o \
	src/lib/zlib/gzwrite.o \
	src/lib/zlib/uncompr.o \
	src/lib/zlib/deflate.o \
	src/lib/zlib/trees.o \
	src/lib/zlib/zutil.o \
	src/lib/zlib/inflate.o \
	src/lib/zlib/infback.o \
	src/lib/zlib/inftrees.o \
	src/lib/zlib/inffast.o

MODULE_DIRS += \
	src/lib/zlib

# Include common rules
include $(srcdir)/common.rules
