# settings
CROSS=i586-mingw32msvc-

#use_musashi = 1
use_fame = 1
use_cz80 = 1
use_sh2drc = 1
#use_sh2mame = 1

-include Makefile.local

ARCH ?= x86
CC = $(CROSS)gcc
CXX = $(CROSS)g++
LD = $(CROSS)ld
STRIP = $(CROSS)strip

DEFINES = _UNZIP_SUPPORT IN_VK
CFLAGS += -O2 -Wall -falign-functions=2 -ffast-math
CFLAGS += -I../.. -I. -I../../zlib/ -Idirectx/include/
LDFLAGS += -mwindows -L. -Ldirectx/lib/ -lgdi32 -lcomdlg32 -lddraw -ldsound -ldxguid

# frontend
OBJS += main.o plat.o direct.o dsnd.o in_vk.o

# common
OBJS += platform/common/emu.o platform/common/menu.o \
	platform/common/config.o platform/common/fonts.o platform/common/readpng.o \
	platform/common/input.o

OBJS += pico/carthw/svp/compiler.o
OBJS += pico/sound/mix.o
# zlib
OBJS += zlib/gzio.o zlib/inffast.o zlib/inflate.o zlib/inftrees.o zlib/trees.o \
	zlib/deflate.o zlib/crc32.o zlib/adler32.o zlib/zutil.o zlib/compress.o zlib/uncompr.o
# unzip
OBJS += unzip/unzip.o unzip/unzip_stream.o

CFLAGS += $(addprefix -D,$(DEFINES))
CXXFLAGS = $(CFLAGS)

vpath %.c = ../..

DIRS += zlib unzip

TARGET = PicoDrive.exe
all: mkdirs $(TARGET)

include ../common/common.mak
include ../common/revision.mak

clean: tidy
	@$(RM) $(TARGET)
tidy:
	$(RM) $(OBJS) $(TARGET).map
	rm -rf $(DIRS)

$(TARGET) : $(OBJS)
	@echo ">>>" $@
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -lm -lpng -Wl,-Map=$(TARGET).map -o $@
	$(STRIP) $@

# ----------- release -----------
ifneq ($(findstring rel,$(MAKECMDGOALS)),)
ifeq ($(VER),)
$(error need VER)
endif
endif

rel: $(TARGET) readme.txt carthw.cfg
	zip -9 -j ../../PicoDrive_win32_$(VER).zip $^

