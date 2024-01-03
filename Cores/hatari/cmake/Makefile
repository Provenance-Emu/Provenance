CORE_DIR := .
LIBRETRO_DIR = $(CORE_DIR)/libretro
ZLIB_DIR = $(LIBRETRO_DIR)/utils/zlib
STATIC_LINKING=0
STATIC_LINKING_LINK=0

ifeq ($(platform),)
platform = unix
ifeq ($(shell uname -a),)
   platform = win
else ifneq ($(findstring MINGW,$(shell uname -a)),)
   platform = win
else ifneq ($(findstring Darwin,$(shell uname -a)),)
   platform = osx
else ifneq ($(findstring win,$(shell uname -a)),)
   platform = win
endif
endif

platform=ios-arm64
ARCH=arm64
EXTERNAL_ZLIB ?= 0

TARGET_NAME	:= hatari
GIT_VERSION := " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
	CFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

ifeq ($(ARCH), arm64)
   fpic := -fPIC
   SHARED :=  -lpthread -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined -Wl,--as-needed
   PLATFLAGS := -DLSB_FIRST -DALIGN_DWORD
endif
ifeq ($(platform), unix)
   TARGET := $(TARGET_NAME)_libretro.so
   fpic := -fPIC
   SHARED :=  -lpthread -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined -Wl,--as-needed
   PLATFLAGS := -DLSB_FIRST -DALIGN_DWORD
else ifeq ($(platform), android)
   CC = arm-linux-androideabi-gcc
   AR = @arm-linux-androideabi-ar
   LD = @arm-linux-androideabi-g++ 
   TARGET := $(TARGET_NAME)_libretro.so
   fpic := -fPIC
   SHARED :=  -Wl,--fix-cortex-a8 -llog -lz -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined
   PLATFLAGS := -DAND -DLSB_FIRST -DALIGN_DWORD
   
# Classic Platforms ####################
# Platform affix = classic_<ISA>_<µARCH>
# Help at https://modmyclassic.com/comp

# (armv7 a7, hard point, neon based) ### 
# NESC, SNESC, C64 mini 
else ifeq ($(platform), classic_armv7_a7)
	TARGET := $(TARGET_NAME)_libretro.so
	fpic := -fPIC
	SHARED :=  -lz -lpthread -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined
	CFLAGS += -Ofast \
	-fdata-sections -ffunction-sections -Wl,--gc-sections \
	-fno-stack-protector -fno-ident -fomit-frame-pointer \
	-falign-functions=1 -falign-jumps=1 -falign-loops=1 \
	-fno-unwind-tables -fno-asynchronous-unwind-tables -fno-unroll-loops \
	-fmerge-all-constants -fno-math-errno \
	-marm -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard
	HAVE_NEON = 1
	ARCH = arm
	PLATFLAGS := -DLSB_FIRST -DALIGN_DWORD
	ifeq ($(shell echo `$(CC) -dumpversion` "< 4.9" | bc -l), 1)
	  CFLAGS += -march=armv7-a
	else
	  CFLAGS += -march=armv7ve
	  # If gcc is 5.0 or later
	  ifeq ($(shell echo `$(CC) -dumpversion` ">= 5" | bc -l), 1)
	    LDFLAGS += -static-libgcc -static-libstdc++
	  endif
	endif
#######################################

else ifeq ($(platform), osx)
	TARGET := $(TARGET_NAME)_libretro.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   PLATFLAGS := -DLSB_FIRST -DALIGN_DWORD

# ARM
else ifneq (,$(findstring armv,$(platform)))
   CC = gcc
	TARGET := $(TARGET_NAME)_libretro.so
   fpic := -fPIC -fsigned-char
   SHARED :=  -lz -lpthread -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined
   PLATFLAGS := -DLSB_FIRST -DALIGN_DWORD
   CFLAGS += -marm
ifneq (,$(findstring neon,$(platform)))
   CFLAGS += -mfpu=neon
   ASFLAGS += -mfpu=neon
   HAVE_NEON = 1
endif
ifneq (,$(findstring softfloat,$(platform)))
   CFLAGS += -mfloat-abi=softfp
   ASFLAGS += -mfloat-abi=softfp
else ifneq (,$(findstring hardfloat,$(platform)))
   CFLAGS += -mfloat-abi=hard
   ASFLAGS += -mfloat-abi=hard
endif
   CFLAGS += -DARM

# iOS
else ifneq (,$(findstring ios,$(platform)))

	TARGET := $(TARGET_NAME)_libretro_ios.dylib
	fpic := -fPIC
	SHARED := -dynamiclib

	ifeq ($(IOSSDK),)
		IOSSDK := $(shell xcodebuild -version -sdk iphoneos Path)
	endif
   ifeq ($(platform),ios-arm64)
     CC = cc -arch arm64 -isysroot $(IOSSDK)      
   else
	  CC = cc -arch armv7 -isysroot $(IOSSDK)
   endif
   CFLAGS += -DIOS -marm -DHAVE_POSIX_MEMALIGN=1 -w

ifeq ($(platform),$(filter $(platform),ios9 ios-arm64))
	CC += -miphoneos-version-min=8.0
	CFLAGS += -miphoneos-version-min=8.0
else
	CC += -miphoneos-version-min=5.0
	CFLAGS += -miphoneos-version-min=5.0
endif

else ifeq ($(platform), tvos-arm64)
	TARGET := $(TARGET_NAME)_libretro_tvos.dylib
	fpic := -fPIC
	SHARED := -dynamiclib

	ifeq ($(IOSSDK),)
		IOSSDK := $(shell xcodebuild -version -sdk appletvos Path)
	endif
	CFLAGS += -DIOS -marm -DHAVE_POSIX_MEMALIGN=1 -w

else ifeq ($(platform), wii)
	TARGET := $(TARGET_NAME)_libretro_wii.a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-gcc$(EXE_EXT)
   CXX = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)   
   CFLAGS += -DSDL_BYTEORDER=SDL_BIG_ENDIAN -DMSB_FIRST -DBYTE_ORDER=BIG_ENDIAN  -DBYTE_ORDER=BIG_ENDIAN \
	-DHAVE_MEMALIGN -DHAVE_ASPRINTF -I$(ZLIB_DIR) -I$(DEVKITPRO)/libogc/include \
	-D__powerpc__ -D__POWERPC__ -DGEKKO -DHW_RVL -mrvl -mcpu=750 -meabi -mhard-float -D__ppc__
   SHARED :=   -lm -lpthread -lc
   PLATFLAGS :=  -DALIGN_DWORD
   EXTERNAL_ZLIB = 1
	STATIC_LINKING=1
	STATIC_LINKING_LINK=1
# Nintendo Game Cube / Wii / WiiU
else ifeq ($(platform), wiiu)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-gcc$(EXE_EXT)
   CXX = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)  
   PLATFORM_DEFINES += -DSDL_BYTEORDER=SDL_BIG_ENDIAN -DMSB_FIRST -DBYTE_ORDER=BIG_ENDIAN  -DBYTE_ORDER=BIG_ENDIAN 
   PLATFORM_DEFINES += -DGEKKO -mcpu=750 -meabi -mhard-float -DHAVE_STRTOF_L -DHAVE_LOCALE
   PLATFORM_DEFINES += -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int -D_GNU_SOURCE
   PLATFORM_DEFINES += -DWIIU -DHW_RVL -mwup -DWORDS_BIGENDIAN=1 -Dpowerpc -D__POWERPC__ -D__ppc__ 
   STATIC_LINKING=1
   STATIC_LINKING_LINK = 1
   CFLAGS +=  -DALIGN_DWORD $(PLATFORM_DEFINES) -I$(ZLIB_DIR) 

# Lightweight PS3 Homebrew SDK
else ifneq (,$(filter $(platform), ps3 psl1ght))
	TARGET := $(TARGET_NAME)_libretro_$(platform).a
	CC = $(PS3DEV)/ppu/bin/ppu-$(COMMONLV)gcc$(EXE_EXT)
	CXX = $(PS3DEV)/ppu/bin/ppu-$(COMMONLV)g++$(EXE_EXT)
	AR = $(PS3DEV)/ppu/bin/ppu-$(COMMONLV)ar$(EXE_EXT)
	SHARED := -lm -lpthread -lc
	CFLAGS += -DSDL_BYTEORDER=SDL_BIG_ENDIAN -DMSB_FIRST -DBYTE_ORDER=BIG_ENDIAN  -DBYTE_ORDER=BIG_ENDIAN \
		-D__PS3__ -DHAVE_MEMALIGN -DHAVE_ASPRINTF -I$(ZLIB_DIR) 
	PLATFLAGS := -DALIGN_DWORD 
	EXTERNAL_ZLIB = 1
	ifeq ($(platform), psl1ght)
		CFLAGS += -D__PSL1GHT__
	endif
	STATIC_LINKING=1
	STATIC_LINKING_LINK=1

else ifeq ($(platform), vita)
	TARGET := $(TARGET_NAME)_libretro_vita.a
   CC = arm-vita-eabi-gcc
   CXX = arm-vita-eabi-g++
   AR = arm-vita-eabi-ar
	CFLAGS += -DLSB_FIRST -DSDL_BYTEORDER=SDL_LIL_ENDIAN 
   PLATFLAGS :=  -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int -DHAVE_STRTOUL -DVITA -I$(ZLIB_DIR) -DHAVE_ALPHASORT -DHAVE_SCANDIR
	STATIC_LINKING=1
	STATIC_LINKING_LINK=1
else
   PLATFLAGS :=  -DLSB_FIRST -DALIGN_DWORD -DWIN32PORT -DWIN32
	TARGET := $(TARGET_NAME)_libretro.dll
   SHARED := -shared -static-libgcc -s -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined 
	EXTERNAL_ZLIB = 1
endif

ZLIB =
ifneq ($(EXTERNAL_ZLIB), 1)
ZLIB = -lz
endif

ifeq ($(capsimg), 1)
PLATFLAGS += -DHAVE_CAPSIMAGE -DCAPSIMAGE_VERSION=5 -I$(capssrc)/LibIPF/ -I$(capssrc)/Core/
endif

ifeq ($(DEBUG), 1)
CFLAGS += -Og -g
else
CFLAGS += -funroll-loops -ffast-math -fomit-frame-pointer -O3
endif
CFLAGS += -fsigned-char -D__LIBRETRO__ -fno-builtin

CFLAGS   += $(fpic) $(PLATFLAGS)
CXXFLAGS := $(CFLAGS)
CPPFLAGS := $(CFLAGS)

EMU = $(CORE_DIR)/src
CPU = $(EMU)/uae-cpu
FALCON = $(EMU)/falcon
DBG = $(EMU)/debug
FLP = $(EMU)
GUI = $(LIBRETRO_DIR)/gui-retro
CPU_PREGEN = $(LIBRETRO_DIR)/uae-cpu-pregen
LIBUTILS = $(LIBRETRO_DIR)/utils

include Makefile.common

OBJECTS := $(SOURCES_C:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJECTS)
ifeq ($(STATIC_LINKING_LINK),1)
	$(AR) rcs $@ $(OBJECTS) 
else
	$(CC) $(CFLAGS) $(INCFLAGS) $(LDFLAGS) $(OBJECTS) -o $@ -lm $(ZLIB) $(SHARED)
endif

%.o: %.c
	$(CC) $(CFLAGS) $(INCFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJECTS) $(TARGET) 

.PHONY: clean
