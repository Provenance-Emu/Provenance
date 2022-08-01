MODULE := src/libpng

MODULE_OBJS := \
	src/libpng/png.o \
	src/libpng/pngerror.o \
	src/libpng/pngget.o \
	src/libpng/pngmem.o \
	src/libpng/pngpread.o \
	src/libpng/pngread.o \
	src/libpng/pngrio.o \
	src/libpng/pngrtran.o \
	src/libpng/pngrutil.o \
	src/libpng/pngset.o \
	src/libpng/pngtrans.o \
	src/libpng/pngwio.o \
	src/libpng/pngwrite.o \
	src/libpng/pngwtran.o \
	src/libpng/pngwutil.o

MODULE_DIRS += \
	src/libpng

# Include common rules 
include $(srcdir)/common.rules
