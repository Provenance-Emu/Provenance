DEBUG = 0
FORCE_GLES ?= 0
FORCE_GLES3 ?= 0
LLE ?= 1
HAVE_PARALLEL_RSP ?= 0
HAVE_PARALLEL_RDP ?= 0

SYSTEM_MINIZIP ?= 0
SYSTEM_LIBPNG ?= 0
SYSTEM_XXHASH ?= 0
SYSTEM_ZLIB ?= 0

HAVE_LTCG ?= 0
DYNAFLAGS :=
INCFLAGS  :=
COREFLAGS :=
CPUFLAGS  :=
GLFLAGS   :=
AWK       ?= awk
STRINGS   ?= strings
TR        ?= tr

UNAME=$(shell uname -a)

# Dirs
ROOT_DIR := .
LIBRETRO_DIR := $(ROOT_DIR)/libretro
DEPSDIR	:=	$(CURDIR)/

ifeq ($(platform),)
   platform = unix
   ifeq ($(UNAME),)
      platform = win
   else ifneq ($(findstring MINGW,$(UNAME)),)
      platform = win
   else ifneq ($(findstring Darwin,$(UNAME)),)
      platform = osx
   else ifneq ($(findstring win,$(UNAME)),)
      platform = win
   endif
else ifneq (,$(findstring armv,$(platform)))
   override platform += unix
endif

# system platform
platform=ios-arm64
ARCH=arm64
system_platform = ios-arm64
arch = arm64
# ifeq ($(shell uname -a),)
#    EXE_EXT = .exe
#    system_platform = win
# else ifneq ($(findstring Darwin,$(shell uname -a)),)
#    system_platform = osx
#    arch = intel
# ifeq ($(shell uname -p),powerpc)
#    arch = ppc
# endif
# else ifneq ($(findstring MINGW,$(shell uname -a)),)
#    system_platform = win
# endif

# Cross compile ?

ifeq (,$(ARCH))
   ARCH = $(shell uname -m)
endif

# Target Dynarec
WITH_DYNAREC ?= $(ARCH)

PIC = 1
# on 32bit Haiku the output of "uname -m" is "BePC"
ifeq ($(ARCH), $(filter $(ARCH), i386 i686 BePC))
   WITH_DYNAREC = x86
   PIC = 0
else ifeq ($(ARCH), $(filter $(ARCH), arm))
   WITH_DYNAREC = arm
endif

TARGET_NAME := mupen64plus_next
CC_AS ?= $(CC)
NASM  ?= nasm

GIT_VERSION ?= " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
	COREFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

ifneq ($(CORE_NAME),)
	COREFLAGS += -DCORE_NAME=\""$(CORE_NAME)"\"
endif

# Linux
ifneq (,$(findstring unix,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined

   ifeq ($(FORCE_GLES),1)
      GLES = 1
      GL_LIB := -lGLESv2
   else ifeq ($(FORCE_GLES3),1)
      GLES3 = 1
      GL_LIB := -lGLESv2
   else
      GL_LIB := -lGL
   endif

   COREFLAGS += -DOS_LINUX
   ifeq ($(ARCH), x86_64)
      ASFLAGS = -f elf64 -d ELF_TYPE
   else
      ASFLAGS = -f elf -d ELF_TYPE
   endif

   ifneq (,$(findstring armv,$(platform)))
      CPUFLAGS += -DARM -marm
      ifneq (,$(findstring cortexa8,$(platform)))
         CPUFLAGS += -mcpu=cortex-a8
      else ifneq (,$(findstring cortexa9,$(platform)))
         CPUFLAGS += -mcpu=cortex-a9
      else
         CPUFLAGS += -mcpu=cortex-a7
      endif
      ifneq (,$(findstring neon,$(platform)))
          CPUFLAGS += -mfpu=neon
          HAVE_NEON = 1
      endif
      ifneq (,$(findstring softfloat,$(platform)))
          CPUFLAGS += -mfloat-abi=softfp
      else ifneq (,$(findstring hardfloat,$(platform)))
          CPUFLAGS += -mfloat-abi=hard
      endif
   endif

# Raspberry Pi
else ifneq (,$(findstring rpi,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined -ldl
   ifeq ($(FORCE_GLES3),1)
      GLES3 = 1
   else
      GLES = 1
   endif
   ifneq (,$(findstring mesa,$(platform)))
      MESA = 1
   endif
   ifneq (,$(findstring rpi4,$(platform)))
      MESA = 1
   endif
   ifeq ($(MESA), 1)
      GL_LIB := -lGLESv2
   else
      LLE = 0
      COREFLAGS += -DVC -DGL_USE_DLSYM
      GL_LIB := -L/opt/vc/lib -lbrcmGLESv2
      EGL_LIB := -lbrcmEGL
      INCFLAGS += -I/opt/vc/include -I/opt/vc/include/interface/vcos -I/opt/vc/include/interface/vcos/pthreads
   endif
   HAVE_NEON = 1
   ifneq (,$(findstring rpi2,$(platform)))
      CPUFLAGS += -mcpu=cortex-a7
      ARM_CPUFLAGS = -mfpu=neon-vfpv4
   else ifneq (,$(findstring rpi3,$(platform)))
      ifneq (,$(findstring rpi3_64,$(platform)))
         CPUFLAGS += -mcpu=cortex-a53 -mtune=cortex-a53
      else
         CPUFLAGS += -march=armv8-a+crc -mtune=cortex-a53
         ARM_CPUFLAGS = -mfpu=neon-fp-armv8
      endif
   else ifneq (,$(findstring rpi4,$(platform)))
      ifneq (,$(findstring rpi4_64,$(platform)))
         CPUFLAGS += -mcpu=cortex-a72 -mtune=cortex-a72
      else
         CPUFLAGS += -march=armv8-a+crc -mtune=cortex-a72
         ARM_CPUFLAGS = -mfpu=neon-fp-armv8
      endif
   else ifneq (,$(findstring rpi,$(platform)))
      CPUFLAGS += -mcpu=arm1176jzf-s
      ARM_CPUFLAGS = -mfpu=vfp
      HAVE_NEON = 0
   endif
   ifeq ($(ARCH), aarch64)
      WITH_DYNAREC=aarch64
      HAVE_NEON = 0
   else
      WITH_DYNAREC=arm
      CPUFLAGS += $(ARM_CPUFLAGS) -mfloat-abi=hard
   endif
   COREFLAGS += -DOS_LINUX
   ASFLAGS = -f elf -d ELF_TYPE

# Nintendo Switch
else ifeq ($(platform), libnx)
   include $(DEVKITPRO)/devkitA64/base_tools
   PORTLIBS := $(PORTLIBS_PATH)/switch
   PATH := $(PORTLIBS)/bin:$(PATH)
   LIBNX ?= $(DEVKITPRO)/libnx
   STRINGS := $(PREFIX)$(STRINGS)
   EGL := 1
   PIC = 1
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CPUOPTS := -g -march=armv8-a+crc -mtune=cortex-a57 -mtp=soft -mcpu=cortex-a57+crc+fp+simd
   PLATCFLAGS = -O3 -ffast-math -funsafe-math-optimizations -fPIE -I$(PORTLIBS)/include/ -I$(LIBNX)/include/ -ffunction-sections -fdata-sections -ftls-model=local-exec -specs=$(LIBNX)/switch.specs
   PLATCFLAGS += $(INCLUDE) -D__SWITCH__=1 -DSWITCH -DHAVE_LIBNX -D_GLIBCXX_USE_C99_MATH_TR1 -D_LDBL_EQ_DBL -funroll-loops #-DM64P_NETPLAY
   CXXFLAGS += -fno-rtti -std=gnu++11
   COREFLAGS += -DOS_LINUX -DEGL
   GLES = 0
   WITH_DYNAREC = aarch64
   STATIC_LINKING = 1

# Jetson Xavier NX
else ifeq ($(platform), jetson-xavier)
   TARGET := $(TARGET_NAME)_libretro.so
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined
   GL_LIB := -lGL
   CPUOPTS := -march=armv8.2-a+crc -mtune=cortex-a75 -mcpu=cortex-a75+crc+fp+simd
   PLATCFLAGS = -O3 -ffast-math -funsafe-math-optimizations
   CXXFLAGS += -std=gnu++11
   COREFLAGS += -DOS_LINUX
   WITH_DYNAREC = aarch64
   HAVE_PARALLEL_RSP = 1
   HAVE_PARALLEL_RDP = 1
   HAVE_THR_AL = 1
   LLE = 1
   COREFLAGS += -ftree-vectorize -ftree-vectorizer-verbose=2 -funsafe-math-optimizations -fno-finite-math-only

# 64 bit ODROIDs
else ifneq (,$(findstring odroid64,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined
   BOARD ?= $(shell cat /proc/cpuinfo | grep -i odroid | awk '{print $$3}')
   GLES = 1
   GL_LIB := -lGLESv2
   WITH_DYNAREC := aarch64
   ifneq (,$(findstring C2,$(BOARD)))
      # ODROID-C2
      CPUFLAGS += -mcpu=cortex-a53
   else ifneq (,$(findstring C4,$(BOARD)))
      # ODROID-C4
      CPUFLAGS += -mcpu=cortex-a55
      GLES3 = 1
   else ifneq (,$(findstring N1,$(BOARD)))
      # ODROID-N1
      CPUFLAGS += -mcpu=cortex-a72.cortex-a53
   else ifneq (,$(findstring N2,$(BOARD)))
      # ODROID-N2
      CPUFLAGS += -mcpu=cortex-a73.cortex-a53
      GLES = 0
      GLES3= 1
      GL_LIB := -lGLESv3
   endif

   COREFLAGS += -DOS_LINUX
   ASFLAGS = -f elf -d ELF_TYPE

# ODROIDs
else ifneq (,$(findstring odroid,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined
   BOARD ?= $(shell cat /proc/cpuinfo | grep -i odroid | awk '{print $$3}')
   GLES = 1
   GL_LIB := -lGLESv2
   CPUFLAGS += -marm -mfloat-abi=hard
   HAVE_NEON = 1
   WITH_DYNAREC=arm
   ifneq (,$(findstring ODROIDC,$(BOARD)))
      # ODROID-C1
      CPUFLAGS += -mcpu=cortex-a5 -mfpu=neon
   else ifneq (,$(findstring ODROID-XU,$(BOARD)))
      # ODROID-XU3 & -XU3 Lite and -XU4
      ifeq "$(shell expr `gcc -dumpversion` \>= 4.9)" "1"
         CPUFLAGS += -mcpu=cortex-a15 -mtune=cortex-a15.cortex-a7 -mfpu=neon-vfpv4 -mvectorize-with-neon-quad
      else
         CPUFLAGS += -mcpu=cortex-a9 -mfpu=neon
      endif
      # ODROIDGOA
   else ifneq (,$(findstring ODROIDGOA,$(BOARD)))
      CPUFLAGS += -march=armv8-a+crc -mfpu=neon-fp-armv8 -mcpu=cortex-a35 -mtune=cortex-a35
   else
      # ODROID-U2, -U3, -X & -X2
      CPUFLAGS += -mcpu=cortex-a9 -mfpu=neon
   endif

   COREFLAGS += -DOS_LINUX
   ASFLAGS = -f elf -d ELF_TYPE

# Amlogic S905/S905X/S912 (AMLGXBB/AMLGXL/AMLGXM) e.g. Khadas VIM1/2 / S905X2 (AMLG12A) & S922X/A311D (AMLG12B) e.g. Khadas VIM3 - 32-bit userspace
else ifneq (,$(findstring AMLG,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined -ldl
   CPUFLAGS += -march=armv8-a+crc -mfloat-abi=hard -mfpu=neon-fp-armv8

   ifneq (,$(findstring AMLG12,$(platform)))
      ifneq (,$(findstring AMLG12B,$(platform)))
         CPUFLAGS += -mtune=cortex-a73.cortex-a53
      else
         CPUFLAGS += -mtune=cortex-a53
      endif
      GLES3 = 1
   else ifneq (,$(findstring AMLGX,$(platform)))
      CPUFLAGS += -mtune=cortex-a53
      ifneq (,$(findstring AMLGXM,$(platform)))
         GLES3 = 1
      else
         GLES = 1
      endif
   endif

   ifneq (,$(findstring mesa,$(platform)))
      COREFLAGS += -DEGL_NO_X11
   endif

   ifneq (,$(findstring mali,$(platform)))
      GL_LIB := -lGLESv3
   else
      GL_LIB := -lGLESv2
   endif
  
   HAVE_NEON = 1
   WITH_DYNAREC=arm
   COREFLAGS += -DUSE_GENERIC_GLESV2 -DOS_LINUX
   ASFLAGS = -f elf -d ELF_TYPE

# Amlogic S905/S912
else ifneq (,$(findstring amlogic,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined -ldl
   GLES = 1
   GL_LIB := -lGLESv2
   CPUFLAGS += -marm -mfloat-abi=hard -mfpu=neon
   HAVE_NEON = 1
   WITH_DYNAREC=arm
   COREFLAGS += -DUSE_GENERIC_GLESV2 -DOS_LINUX
   CPUFLAGS += -march=armv8-a -mcpu=cortex-a53 -mtune=cortex-a53

# Generic AArch64 Cortex-A53 GLES 2.0 target
else ifneq (,$(findstring arm64_cortex_a53_gles2,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined -ldl
   GL_LIB := -lGLESv2
   WITH_DYNAREC := aarch64
   CPUFLAGS += -mcpu=cortex-a53 -mtune=cortex-a53
   GLES = 1
   COREFLAGS += -DOS_LINUX
   ASFLAGS = -f elf64 -d ELF_TYPE

# Generic AArch64 Cortex-A53 GLES 3.0 target
else ifneq (,$(findstring arm64_cortex_a53_gles3,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined -ldl
   GL_LIB := -lGLESv2
   WITH_DYNAREC := aarch64
   CPUFLAGS += -mcpu=cortex-a53 -mtune=cortex-a53
   GLES3 = 1
   COREFLAGS += -DOS_LINUX
   ASFLAGS = -f elf64 -d ELF_TYPE

# Rockchip RK3288 e.g. Asus Tinker Board / RK3328 e.g. PINE64 Rock64 / RK3399 e.g. PINE64 RockPro64 - 32-bit userspace
else ifneq (,$(findstring RK,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined -ldl

   ifneq (,$(findstring RK33,$(platform)))
      CPUFLAGS += -march=armv8-a+crc -mfloat-abi=hard -mfpu=neon-fp-armv8
      ifneq (,$(findstring RK3399,$(platform)))
         CPUFLAGS += -mtune=cortex-a72.cortex-a53
         GLES3 = 1
      else ifneq (,$(findstring RK3328,$(platform)))
         CPUFLAGS += -mtune=cortex-a53
         GLES = 1
      endif
   else ifneq (,$(findstring RK3288,$(platform)))
      CPUFLAGS += -march=armv7ve -mtune=cortex-a17 -mfloat-abi=hard -mfpu=neon-vfpv4
      GLES3 = 1
   endif

   ifneq (,$(findstring mesa,$(platform)))
      COREFLAGS += -DEGL_NO_X11
   endif

   GL_LIB := -lGLESv2
   HAVE_NEON = 1
   WITH_DYNAREC=arm
   COREFLAGS += -DUSE_GENERIC_GLESV2 -DOS_LINUX
   ASFLAGS = -f elf -d ELF_TYPE

# OS X
else ifneq (,$(findstring osx,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.dylib
   LDFLAGS += -dynamiclib
   OSXVER = `sw_vers -productVersion | cut -d. -f 2`
   OSX_LT_MAVERICKS = `(( $(OSXVER) <= 9)) && echo "YES"`
        LDFLAGS += -mmacosx-version-min=10.7
   LDFLAGS += -stdlib=libc++

   PLATCFLAGS += -D__MACOSX__ -DOSX -DOS_MAC_OS_X
   GL_LIB := -framework OpenGL

   # Target Dynarec
   ifeq ($(ARCH), $(filter $(ARCH), ppc))
      WITH_DYNAREC =
   endif

   COREFLAGS += -DOS_LINUX
   ASFLAGS = -f elf -d ELF_TYPE
# iOS
else ifneq (,$(findstring ios,$(platform)))
   ifeq ($(IOSSDK),)
      IOSSDK := $(shell xcodebuild -version -sdk iphoneos Path)
   endif

   TARGET := $(TARGET_NAME)_libretro_ios.dylib
   DEFINES += -DIOS
   GLES = 1
	ifeq ($(platform),ios-arm64)
		# WITH_DYNAREC = aarch64
		GLES = 1
		GLES3 = 1
		FORCE_GLES3 = 1
		EGL := 0
		HAVE_NEON=1
		HAVE_PARALLEL_RDP = 1
#		HAVE_PARALLEL_RSP = 1
		HAVE_THR_AL = 1
		LLE = 1
		NO_ASM = 1

		#__aarch64__

		PLATCFLAGS += -Ofast
		PLATCFLAGS += -ffast-math -funsafe-math-optimizations
		PLATCFLAGS += -DHAVE_POSIX_MEMALIGN
		PLATCFLAGS += -DNO_ASM
		PLATCFLAGS += -DIOS -DOS_IOS
#		PLATCFLAGS += -mfloat-abi=softfp -marm -mfpu=neon

		COREFLAGS += -Ofast
		COREFLAGS += -ffast-math -funsafe-math-optimizations
		COREFLAGS += -DNO_ASM
#		COREFLAGS += -mfloat-abi=softfp -marm -mfpu=neon

		CPUFLAGS += -Ofast
		CPUFLAGS += -ffast-math -funsafe-math-optimizations
		CPUFLAGS += -DNO_ASM
#		CPUFLAGS += -DARM_ASM -DARM
#		CPUFLAGS += -mfloat-abi=softfp -marm -mfpu=neon

		CC_AS = perl ./custom/tools/gas-preprocessor.pl $(CC)
		CC_AS      += -miphoneos-version-min=8.0
		CC         += -miphoneos-version-min=8.0
		CXX        += -miphoneos-version-min=8.0
		PLATCFLAGS += -miphoneos-version-min=8.0 -Wno-error=implicit-function-declaration

		CC = clang -arch arm64 -isysroot $(IOSSDK)
		CXX = clang++ -arch arm64 -isysroot $(IOSSDK)
	else
		PLATCFLAGS += -DOS_MAC_OS_X
		PLATCFLAGS += -DHAVE_POSIX_MEMALIGN -DNO_ASM
		PLATCFLAGS += -DIOS -marm
		CPUFLAGS += -DNO_ASM  -DARM -D__arm__ -DARM_ASM -D__NEON_OPT
		CPUFLAGS += -marm -mcpu=cortex-a8 -mfpu=neon -mfloat-abi=softfp
		WITH_DYNAREC=arm
		HAVE_NEON=1
		CC         += -miphoneos-version-min=5.0
		CC_AS      += -miphoneos-version-min=5.0
		CXX        += -miphoneos-version-min=5.0
		PLATCFLAGS += -miphoneos-version-min=5.0
		CC = clang -arch armv7 -isysroot $(IOSSDK)
		CC_AS = perl ./custom/tools/gas-preprocessor.pl $(CC)
		CXX = clang++ -arch armv7 -isysroot $(IOSSDK)
	endif
   LDFLAGS += -dynamiclib
   GL_LIB := -framework OpenGLES
# Android
else ifneq (,$(findstring android,$(platform)))
   ANDROID = 1
   LDFLAGS += -shared -Wl,--version-script=$(LIBRETRO_DIR)/link.T -Wl,--no-undefined -Wl,--warn-common -llog
   INCFLAGS += -I$(ROOT_DIR)/GLideN64/src/GLideNHQ/inc
   ifneq (,$(findstring x86,$(platform)))
      CC = i686-linux-android-gcc
      CXX = i686-linux-android-g++
      WITH_DYNAREC = x86
      LDFLAGS += -L$(ROOT_DIR)/custom/android/x86
   else
      CC = arm-linux-androideabi-gcc
      CXX = arm-linux-androideabi-g++
      WITH_DYNAREC = arm
      HAVE_NEON = 1
      CPUFLAGS += -march=armv7-a -mfloat-abi=softfp -mfpu=neon
      LDFLAGS += -march=armv7-a -L$(ROOT_DIR)/custom/android/arm
   endif
   ifneq (,$(findstring gles3,$(platform)))
      GL_LIB := -lGLESv3
      GLES3 = 1
      TARGET := $(TARGET_NAME)_gles3_libretro_android.so
   else
      GL_LIB := -lGLESv2
      GLES = 1
      TARGET := $(TARGET_NAME)_gles2_libretro_android.so
   endif
   CPUFLAGS += -DANDROID -DEGL_EGLEXT_PROTOTYPES
   COREFLAGS += -DOS_LINUX
   ASFLAGS = -f elf -d ELF_TYPE
# emscripten
else ifeq ($(platform), emscripten)
   TARGET := $(TARGET_NAME)_libretro_emscripten.bc
   GLES := 1
   WITH_DYNAREC :=
   CPUFLAGS += -DEMSCRIPTEN -DNO_ASM -s USE_ZLIB=1
   PLATCFLAGS += \
      -Dsinc_resampler=glupen_sinc_resampler \
      -DCC_resampler=glupen_CC_resampler \
      -Drglgen_symbol_map=glupen_rglgen_symbol_map \
      -Drglgen_resolve_symbols_custom=glupen_rglgen_resolve_symbols_custom \
      -Drglgen_resolve_symbols=glupen_rglgen_resolve_symbols \
      -Dmemalign_alloc=glupen_memalign_alloc \
      -Dmemalign_free=glupen_memalign_free \
      -Dmemalign_alloc_aligned=glupen_memalign_alloc_aligned \
      -Daudio_resampler_driver_find_handle=glupen_audio_resampler_driver_find_handle \
      -Daudio_resampler_driver_find_ident=glupen_audio_resampler_driver_find_ident \
      -Drarch_resampler_realloc=glupen_rarch_resampler_realloc \
      -Dconvert_float_to_s16_C=glupen_convert_float_to_s16_C \
      -Dconvert_float_to_s16_init_simd=glupen_convert_float_to_s16_init_simd \
      -Dconvert_s16_to_float_C=glupen_convert_s16_to_float_C \
      -Dconvert_s16_to_float_init_simd=glupen_convert_s16_to_float_init_simd \
      -Dcpu_features_get_perf_counter=glupen_cpu_features_get_perf_counter \
      -Dcpu_features_get_time_usec=glupen_cpu_features_get_time_usec \
      -Dcpu_features_get_core_amount=glupen_cpu_features_get_core_amount \
      -Dcpu_features_get=glupen_cpu_features_get \
      -Dffs=glupen_ffs \
      -Dstrlcpy_retro__=glupen_strlcpy_retro__ \
      -Dstrlcat_retro__=glupen_strlcat_retro__
   CC = emcc
   CXX = em++
   HAVE_NEON = 0

   COREFLAGS += -DOS_LINUX
   ASFLAGS = -f elf -d ELF_TYPE
# Windows
else
   TARGET := $(TARGET_NAME)_libretro.dll
   LDFLAGS += -shared -static-libgcc -static-libstdc++ -Wl,--version-script=$(LIBRETRO_DIR)/link.T #-static -lmingw32 -lSDL2main -lSDL2 -mwindows -lm -ldinput8 -ldxguid -ldxerr8 -luser32 -lgdi32 -lwinmm -limm32 -lole32 -loleaut32 -lshell32 -lversion -luuid  -lsdl2_net -lsdl2 -lws2_32 -lSetupapi -lIPHLPAPI
   GL_LIB := -lopengl32
   
   ifeq ($(MSYSTEM),MINGW64)
      CC ?= x86_64-w64-mingw32-gcc
      CXX ?= x86_64-w64-mingw32-g++
      WITH_DYNAREC = x86_64
      COREFLAGS += -DWIN64 #-DM64P_NETPLAY
      ASFLAGS = -f win64 -d WIN64
      PIC = 1
   else ifeq ($(MSYSTEM),MINGW32)
      CC ?= i686-w64-mingw32-gcc
      CXX ?= i686-w64-mingw32-g++
      WITH_DYNAREC = x86
      COREFLAGS += -DWIN32
      PIC = 1
      ASFLAGS = -f win32 -d WIN32 -d LEADING_UNDERSCORE
   endif

   HAVE_PARALLEL_RSP = 1
   HAVE_PARALLEL_RDP = 1
   HAVE_THR_AL = 1
   LLE = 1
   COREFLAGS += -DOS_WINDOWS -DMINGW -DUNICODE
   CXXFLAGS += -fpermissive
endif

ifeq ($(STATIC_LINKING), 1)
   ifneq (,$(findstring win,$(platform)))
      TARGET := $(TARGET:.dll=.lib)
   else ifneq ($(platform), $(filter $(platform), osx ios))
      TARGET := $(TARGET:.dylib=.a)            
   else
      TARGET := $(TARGET:.so=.a)
   endif
endif

include Makefile.common

ifeq ($(HAVE_NEON), 1)
   COREFLAGS += -DHAVE_NEON -D__ARM_NEON__ -D__NEON_OPT -ftree-vectorize -funsafe-math-optimizations -fno-finite-math-only
   ifneq ($(platform), ios-arm64)
   COREFLAGS += -mvectorize-with-neon-quad -ftree-vectorizer-verbose=2
   endif
endif

ifeq ($(LLE), 1)
   COREFLAGS += -DHAVE_LLE
endif

COREFLAGS += -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -D__LIBRETRO__ -DUSE_FILE32API -DM64P_PLUGIN_API -DM64P_CORE_PROTOTYPES -D_ENDUSER_RELEASE -DSINC_LOWER_QUALITY -DTXFILTER_LIB -D__VEC4_OPT -DMUPENPLUSAPI

ifeq ($(DEBUG), 1)
   CPUOPTS += -O0 -g
   CPUOPTS += -DOPENGL_DEBUG
else
   CPUOPTS += -DNDEBUG -fsigned-char -ffast-math -fno-strict-aliasing -fomit-frame-pointer -fvisibility=hidden
ifneq ($(platform), libnx)
   CPUOPTS := -O3 $(CPUOPTS)
endif
   CXXFLAGS += -fvisibility-inlines-hidden
endif

# Use -fcommon
CPUOPTS += -fcommon

# set C/C++ standard to use
CFLAGS += -std=gnu11 -D_CRT_SECURE_NO_WARNINGS -Wno-discarded-qualifiers
CXXFLAGS += -std=gnu++11 -D_CRT_SECURE_NO_WARNINGS

ifeq ($(HAVE_LTCG),1)
   CPUFLAGS += -flto
endif

ifeq ($(PIC), 1)
   fpic = -fPIC
else
   fpic = -fno-PIC
endif

OBJECTS     += $(SOURCES_CXX:.cpp=.o) $(SOURCES_C:.c=.o) $(SOURCES_ASM:.S=.o) $(SOURCES_NASM:.asm=.o)
CXXFLAGS    += $(CPUOPTS) $(COREFLAGS) $(INCFLAGS) $(PLATCFLAGS) $(fpic) $(CPUFLAGS) $(GLFLAGS) $(DYNAFLAGS)
CFLAGS      += $(CPUOPTS) $(COREFLAGS) $(INCFLAGS) $(PLATCFLAGS) $(fpic) $(CPUFLAGS) $(GLFLAGS) $(DYNAFLAGS)

ifeq (,$(findstring android,$(platform)))
   LDFLAGS    += -lpthread
endif

ifeq ($(platform), ios-arm64)
	LDFLAGS    += $(fpic) -O3 $(CPUOPTS) $(PLATCFLAGS) $(CPUFLAGS)
else
	LDFLAGS    += $(fpic) -O3 $(CPUOPTS) $(PLATCFLAGS) $(CPUFLAGS)
endif

-include $(OBJECTS:.o=.d)
all: $(TARGET)
$(TARGET): $(OBJECTS)

ifeq ($(STATIC_LINKING), 1)
	$(AR) rcs $@ $(OBJECTS)
else
	$(CXX) -o $@ $(OBJECTS) $(LDFLAGS) $(GL_LIB)
endif

# Script hackery fll or generating ASM include files for the new dynarec assembly code
$(AWK_DEST_DIR)/asm_defines_gas.h: $(AWK_DEST_DIR)/asm_defines_nasm.h
$(AWK_DEST_DIR)/asm_defines_nasm.h: $(ASM_DEFINES_OBJ)
	$(STRINGS) "$<" | $(TR) -d '\r' | $(AWK) -v dest_dir="$(AWK_DEST_DIR)" -f $(CORE_DIR)/tools/gen_asm_defines.awk

%.o: %.asm $(AWK_DEST_DIR)/asm_defines_gas.h
	$(NASM) -i$(AWK_DEST_DIR)/ $(ASFLAGS) $< -o $@

%.o: %.S $(AWK_DEST_DIR)/asm_defines_gas.h
	$(CC_AS) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

%.o: %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

clean:
	find . -name "*.o" -type f -delete
	find . -name "*.d" -type f -delete
	rm -f $(TARGET)

.PHONY: clean
