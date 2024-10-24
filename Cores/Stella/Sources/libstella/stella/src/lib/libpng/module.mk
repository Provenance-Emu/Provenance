MODULE := src/lib/libpng

MODULE_OBJS := \
	src/lib/libpng/png.o \
	src/lib/libpng/pngerror.o \
	src/lib/libpng/pngget.o \
	src/lib/libpng/pngmem.o \
	src/lib/libpng/pngpread.o \
	src/lib/libpng/pngread.o \
	src/lib/libpng/pngrio.o \
	src/lib/libpng/pngrtran.o \
	src/lib/libpng/pngrutil.o \
	src/lib/libpng/pngset.o \
	src/lib/libpng/pngtrans.o \
	src/lib/libpng/pngwio.o \
	src/lib/libpng/pngwrite.o \
	src/lib/libpng/pngwtran.o \
	src/lib/libpng/pngwutil.o

MODULE_DIRS += \
	src/lib/libpng

# Include common rules
include $(srcdir)/common.rules
