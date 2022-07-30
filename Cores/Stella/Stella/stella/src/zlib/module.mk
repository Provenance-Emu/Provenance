MODULE := src/zlib

MODULE_OBJS := \
	src/zlib/adler32.o \
	src/zlib/compress.o \
	src/zlib/crc32.o \
	src/zlib/gzclose.o \
	src/zlib/gzlib.o \
	src/zlib/gzread.o \
	src/zlib/gzwrite.o \
	src/zlib/uncompr.o \
	src/zlib/deflate.o \
	src/zlib/trees.o \
	src/zlib/zutil.o \
	src/zlib/inflate.o \
	src/zlib/infback.o \
	src/zlib/inftrees.o \
	src/zlib/inffast.o

MODULE_DIRS += \
	src/zlib

# Include common rules 
include $(srcdir)/common.rules
