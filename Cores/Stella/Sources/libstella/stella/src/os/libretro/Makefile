DEBUG = 0
HAVE_EXCEPTIONS = 1
HAVE_STRINGS_H = 1

LTO ?= -flto
SPACE :=
SPACE := $(SPACE) $(SPACE)
BACKSLASH :=
BACKSLASH := \$(BACKSLASH)
filter_out1 = $(filter-out $(firstword $1),$1)
filter_out2 = $(call filter_out1,$(call filter_out1,$1))

ifeq ($(platform),)
   platform = unix
   ifeq ($(shell uname -s),)
      platform = win
   else ifneq ($(findstring MINGW,$(shell uname -s)),)
      platform = win
   else ifneq ($(findstring Darwin,$(shell uname -s)),)
      platform = osx
      arch = intel
      ifeq ($(shell uname -p),powerpc)
         arch = ppc
      endif
      ifeq ($(shell uname -p),arm)
         arch = arm
      endif
   else ifneq ($(findstring win,$(shell uname -s)),)
      platform = win
   endif
else ifneq (,$(findstring armv,$(platform)))
   ifeq (,$(findstring classic_,$(platform)))
      override platform += unix
   endif
else ifneq (,$(findstring rpi,$(platform)))
   override platform += unix
endif

ifneq ($(platform), osx)
   ifeq ($(findstring Haiku,$(shell uname -a)),)
      PTHREAD_FLAGS = -lpthread
   endif
endif

TARGET_NAME = stella


ifeq (,$(findstring msvc,$(platform)))
   CXXFLAGS += -std=c++17 -fno-rtti
   LIBS := -lm
else
   LIBS :=
endif

GIT_VERSION := " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
   CXXFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

GET_STATIC_ARG=$(if $(filter $(shell $(CXX) -print-file-name=$1.a),$1.a),,-static-$1)
# Unix
ifneq (,$(findstring unix,$(platform)))
   CXXFLAGS += $(LTO)
   LDFLAGS += $(LTO) $(PTHREAD_FLAGS) $(call GET_STATIC_ARG,libgcc) $(call GET_STATIC_ARG,libstdc++)
   TARGET := $(TARGET_NAME)_libretro.so
   fpic := -fPIC
   ifneq ($(findstring SunOS,$(shell uname -a)),)
      CXX = g++
      SHARED := -shared -z defs
   else
      SHARED := -shared -Wl,--version-script=link.T -Wl,-z,defs
   endif

   # ARM
   ifneq (,$(findstring armv,$(platform)))
      CXXFLAGS += -DARM
   # Raspberry Pi
   else ifneq (,$(findstring rpi,$(platform)))
      CXXFLAGS += -DARM
   endif

# OS X
else ifeq ($(platform), osx)
   CXXFLAGS += $(LTO) -stdlib=libc++
   LDFLAGS += $(LTO) $(PTHREAD_FLAGS) -stdlib=libc++
   TARGET := $(TARGET_NAME)_libretro.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   MINVERSION :=
   arch = intel
   ifeq ($(shell uname -p),powerpc)
      arch = ppc
   endif
   ifeq ($(arch),ppc)
      CXXFLAGS += -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   endif
   OSXVER = $(shell sw_vers -productVersion | cut -d. -f 2)
   OSX_GT_MOJAVE = $(shell (( $(OSXVER) >= 14)) && echo "YES")
   ifneq ($(OSX_GT_MOJAVE),YES)
      #this breaks compiling on Mac OS Mojave
      MINVERSION = -mmacosx-version-min=10.7
   endif
   fpic += $(MINVERSION)

   ifeq ($(CROSS_COMPILE),1)
		TARGET_RULE   = -target $(LIBRETRO_APPLE_PLATFORM) -isysroot $(LIBRETRO_APPLE_ISYSROOT)
		CFLAGS   += $(TARGET_RULE)
		CPPFLAGS += $(TARGET_RULE)
		CXXFLAGS += $(TARGET_RULE)
		LDFLAGS  += $(TARGET_RULE)
   endif

   CFLAGS    += $(ARCHFLAGS)
   CXXFLAGS  += $(ARCHFLAGS)
   LDFLAGS   += $(ARCHFLAGS)

# iOS
else ifneq (,$(findstring ios,$(platform)))
   CXXFLAGS += $(LTO) -stdlib=libc++
   LDFLAGS += $(LTO) $(PTHREAD_FLAGS) -stdlib=libc++
   TARGET := $(TARGET_NAME)_libretro_ios.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   MINVERSION :=
   ifeq ($(IOSSDK),)
      IOSSDK := $(shell xcodebuild -version -sdk iphoneos Path)
   endif
   ifeq ($(platform),ios-arm64)
      CC  = cc -arch arm64 -isysroot $(IOSSDK)
      CXX = c++ -arch arm64 -isysroot $(IOSSDK)
   else
      CC  = cc -arch armv7 -isysroot $(IOSSDK)
      CXX = c++ -arch armv7 -isysroot $(IOSSDK)
   endif
   CXXFLAGS += -DIOS -DARM -fno-aligned-allocation
   ifeq ($(platform),$(filter $(platform),ios9 ios-arm64))
      MINVERSION = -miphoneos-version-min=8.0
   else
      MINVERSION = -miphoneos-version-min=5.0
   endif
   CXXFLAGS += $(MINVERSION)

# tvOS
else ifeq ($(platform), tvos-arm64)
   CXXFLAGS += $(LTO) $(PTHREAD_FLAGS) -stdlib=libc++
   LDFLAGS += $(LTO) $(PTHREAD_FLAGS) -stdlib=libc++
   TARGET := $(TARGET_NAME)_libretro_tvos.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   ifeq ($(IOSSDK),)
      IOSSDK := $(shell xcodebuild -version -sdk appletvos Path)
   endif
   CXXFLAGS += -DIOS
   CXXFLAGS += -DARM

   CC  = cc -arch arm64 -isysroot $(IOSSDK)
   CXX = c++ -arch arm64 -isysroot $(IOSSDK)

# Nintendo Switch (libnx)
else ifeq ($(platform), libnx)
   include $(DEVKITPRO)/libnx/switch_rules
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   DEFINES := -DSWITCH=1 -D__SWITCH__ -DARM
   CXXFLAGS += $(DEFINES) -fPIE -I$(LIBNX)/include/ -ffunction-sections -fdata-sections -ftls-model=local-exec -specs=$(LIBNX)/switch.specs
   CXXFLAGS += -march=armv8-a -mtune=cortex-a57 -mtp=soft -mcpu=cortex-a57+crc+fp+simd -ffast-math $(ASFLAGS)
   STATIC_LINKING = 1

# Classic Platforms ####################
# Platform affix = classic_<ISA>_<µARCH>
# Help at https://modmyclassic.com/comp

# (armv7 a7, hard point, neon based) ###
# NESC, SNESC, C64 mini
else ifeq ($(platform), classic_armv7_a7)
   TARGET := $(TARGET_NAME)_libretro.so
   fpic := -fPIC
   SHARED := -shared -Wl,--version-script=link.T -Wl,--no-undefined
   CXXFLAGS += -Ofast \
               -flto=4 -fwhole-program -fuse-linker-plugin \
               -fdata-sections -ffunction-sections -Wl,--gc-sections \
               -fno-stack-protector -fno-ident -fomit-frame-pointer \
               -falign-functions=1 -falign-jumps=1 -falign-loops=1 \
               -fno-unwind-tables -fno-asynchronous-unwind-tables -fno-unroll-loops \
               -fmerge-all-constants -fno-math-errno \
              -marm -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard
   HAVE_NEON = 1
   ARCH = arm
   BUILTIN_GPU = neon
   USE_DYNAREC = 1
   ifeq ($(shell echo `$(CXX) -dumpversion` "< 4.9" | bc -l), 1)
      CXXFLAGS += -march=armv7-a
   else
      CXXFLAGS += -march=armv7ve
      # If gcc is 5.0 or later
      ifeq ($(shell echo `$(CXX) -dumpversion` ">= 5" | bc -l), 1)
         LDFLAGS += -static-libgcc -static-libstdc++
      endif
   endif


# Theos
else ifeq ($(platform), theos_ios)
   CXXFLAGS += $(LTO)
   LDFLAGS += $(LTO)
   DEPLOYMENT_IOSVERSION = 5.0
   TARGET = iphone:latest:$(DEPLOYMENT_IOSVERSION)
   ARCHS = armv7 armv7s
   TARGET_IPHONEOS_DEPLOYMENT_VERSION=$(DEPLOYMENT_IOSVERSION)
   THEOS_BUILD_DIR := objs
   include $(THEOS)/makefiles/common.mk
   LIBRARY_NAME = $(TARGET_NAME)_libretro_ios

# QNX
else ifeq ($(platform), qnx)
   TARGET := $(TARGET_NAME)_libretro_$(platform).so
   fpic := -fPIC
   SHARED := -shared -Wl,--version-script=link.T
   CXX = QCC -Vgcc_notarmv7le
   AR = QCC -Vgcc_ntoarmv7le
   CXXFLAGS += -D__BLACKBERRY_QNX__
   CXXFLAGS += -DARM
   HAVE_EXCEPTIONS = 1

# Vita
else ifeq ($(platform), vita)
   CXXFLAGS += $(LTO) $(PTHREAD_FLAGS)
   LDFLAGS += $(LTO) $(PTHREAD_FLAGS)
   TARGET := $(TARGET_NAME)_libretro_$(platform).so
   fpic := -fPIC
   CXX = arm-vita-eabi-g++$(EXE_EXT)
   AR = arm-vita-eabi-ar$(EXE_EXT)
   CXXFLAGS += -DVITA
   CXXFLAGS += -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int
   HAVE_EXCEPTIONS = 1

# PS3
else ifneq (,$(filter $(platform), ps3 sncps3 psl1ght))
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CXXFLAGS += -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   STATIC_LINKING = 1
   HAVE_STRINGS_H = 0

   # sncps3
   ifneq (,$(findstring sncps3,$(platform)))
      TARGET := $(TARGET_NAME)_libretro_ps3.a
      CXX = $(CELL_SDK)/host-win32/sn/bin/ps3ppusnc.exe
      AR = $(CELL_SDK)/host-win32/sn/bin/ps3snarl.exe
   # PS3
   else ifneq (,$(findstring ps3,$(platform)))
      CXX = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-g++.exe
      AR = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-ar.exe
   # Lightweight PS3 Homebrew SDK
   else ifneq (,$(findstring psl1ght,$(platform)))
      CXX = $(PS3DEV)/ppu/bin/ppu-g++$(EXE_EXT)
      AR = $(PS3DEV)/ppu/bin/ppu-ar$(EXE_EXT)
   endif

# CTR (3DS)
else ifeq ($(platform), ctr)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CXX = $(DEVKITARM)/bin/arm-none-eabi-g++$(EXE_EXT)
   AR = $(DEVKITARM)/bin/arm-none-eabi-ar$(EXE_EXT)
   ENDIANNESS_DEFINES := -DLSB_FIRST
   CXXFLAGS += -DARM11 -D_3DS
   CXXFLAGS += -march=armv6k -mtune=mpcore -mfloat-abi=hard
   CXXFLAGS += -mword-relocations
   CXXFLAGS += -fomit-frame-pointer -fstrict-aliasing -ffast-math
   CXXFLAGS += -fno-rtti
   CXXFLAGS += -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int
   STATIC_LINKING = 1
   LOAD_FROM_MEMORY = 0

# Xbox 360
else ifeq ($(platform), xenon)
   CXXFLAGS += $(LTO)
   LDFLAGS += $(LTO)
   TARGET := $(TARGET_NAME)_libretro_xenon360.a
   CXX = xenon-g++$(EXE_EXT)
   AR = xenon-ar$(EXE_EXT)
   CXXFLAGS += -D__LIBXENON__ -m32 -D__ppc__
   LIBS := $(PTHREAD_FLAGS)
   STATIC_LINKING = 1

# Nintendo Game Cube / Wii / WiiU
else ifneq (,$(filter $(platform), ngc wii wiiu))
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CXX = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)
   CXXFLAGS += -mcpu=750 -meabi -mhard-float -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   CXXFLAGS += -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int
   STATIC_LINKING = 1

   # Nintendo WiiU
   ifneq (,$(findstring wiiu,$(platform)))
      CXXFLAGS += -mwup
   # Nintendo Wii
   else ifneq (,$(findstring wii,$(platform)))
      CXXFLAGS += -DGEKKO -mrvl
   # Nintendo Game Cube
   else ifneq (,$(findstring ngc,$(platform)))
      CXXFLAGS += -DGEKKO -mrvl
   endif

# Emscripten
else ifeq ($(platform), emscripten)
   TARGET := $(TARGET_NAME)_libretro_$(platform).bc
   STATIC_LINKING = 1
   CXXFLAGS += $(PTHREAD_FLAGS) -std=c++17
   LDFLAGS += $(PTHREAD_FLAGS) -std=c++17

# Genode
else ifeq ($(platform), genode)
   TARGET  := $(TARGET_NAME)_libretro.lib.so
   PKG_CONFIG := genode-lib genode-stdcxx
   CXXFLAGS += -D__GENODE__
   CXXFLAGS += $(shell pkg-config --cflags $(PKG_CONFIG))

   LDFLAGS += -shared --version-script=link.T
   LDFLAGS += $(shell pkg-config --libs $(PKG_CONFIG))

   CXX = $(shell pkg-config genode-base --variable=cxx)
   LD  = $(shell pkg-config genode-base --variable=ld)
   AR  = $(shell pkg-config genode-base --variable=ar) -rcs

# Windows MSVC 2003 Xbox 1
else ifeq ($(platform), xbox1_msvc2003)
   CXXFLAGS += -D__WIN32__
   TARGET := $(TARGET_NAME)_libretro_xdk1.lib
   MSVCBINDIRPREFIX = $(XDK)/xbox/bin/vc71
   CXX  = "$(MSVCBINDIRPREFIX)/CL.exe"
   LD   = "$(MSVCBINDIRPREFIX)/lib.exe"

   export INCLUDE := $(XDK)/xbox/include
   export LIB := $(XDK)/xbox/lib
   PSS_STYLE :=2
   CXXFLAGS += -D_XBOX -D_XBOX1
   STATIC_LINKING=1
   HAS_GCC := 0

# Windows MSVC 2010 Xbox 360
else ifeq ($(platform), xbox360_msvc2010)
   CXXFLAGS += -D__WIN32__
   TARGET := $(TARGET_NAME)_libretro_xdk360.lib
   MSVCBINDIRPREFIX = $(XEDK)/bin/win32
   CXX  = "$(MSVCBINDIRPREFIX)/cl.exe"
   LD   = "$(MSVCBINDIRPREFIX)/lib.exe"

   export INCLUDE := $(XEDK)/include/xbox
   export LIB := $(XEDK)/lib/xbox
   PSS_STYLE :=2
   CXXFLAGS += -D_XBOX -D_XBOX360
   STATIC_LINKING=1
   HAS_GCC := 0

# Windows MSVC 2017 all architectures
else ifneq (,$(findstring windows_msvc2017,$(platform)))
   CXXFLAGS += -D__WIN32__

   PlatformSuffix = $(subst windows_msvc2017_,,$(platform))
   ifneq (,$(findstring desktop,$(PlatformSuffix)))
      WinPartition = desktop
      MSVC2017CompileFlags = -DWINAPI_FAMILY=WINAPI_FAMILY_DESKTOP_APP
      LDFLAGS += -MANIFEST -LTCG:incremental -NXCOMPAT -DYNAMICBASE -DEBUG -OPT:REF -INCREMENTAL:NO -SUBSYSTEM:WINDOWS -MANIFESTUAC:"level='asInvoker' uiAccess='false'" -OPT:ICF -ERRORREPORT:PROMPT -NOLOGO -TLBID:1
      LIBS += kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib
   else ifneq (,$(findstring uwp,$(PlatformSuffix)))
      WinPartition = uwp
      MSVC2017CompileFlags = -DWINAPI_FAMILY=WINAPI_FAMILY_APP -D_WINDLL -D_UNICODE -DUNICODE -D__WRL_NO_DEFAULT_LIB__ -ZW:nostdlib -EHsc
      LDFLAGS += -APPCONTAINER -NXCOMPAT -DYNAMICBASE -MANIFEST:NO -LTCG -OPT:REF -SUBSYSTEM:CONSOLE -MANIFESTUAC:NO -OPT:ICF -ERRORREPORT:PROMPT -NOLOGO -TLBID:1 -DEBUG:FULL -WINMD:NO
      LIBS += WindowsApp.lib
   endif

   # Specific to this core
   MSVC2017CompileFlags += -D__WIN32__ /std:c++17

   CXX = cl.exe
   CXXFLAGS += $(MSVC2017CompileFlags)

   TargetArchMoniker = $(subst $(WinPartition)_,,$(PlatformSuffix))

   reg_query = $(call filter_out2,$(subst $2,,$(shell reg query "$2" -v "$1" 2>nul)))
   fix_path = $(subst $(SPACE),\ ,$(subst \,/,$1))

   ProgramFiles86w := $(shell cmd //c "echo %PROGRAMFILES(x86)%")
   ProgramFiles86 := $(shell cygpath "$(ProgramFiles86w)")

   WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0)
   WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_CURRENT_USER\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0)
   WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0)
   WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_CURRENT_USER\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0)
   WindowsSdkDir := $(WindowsSdkDir)

   WindowsSDKVersion ?= $(firstword $(foreach folder,$(subst $(subst \,/,$(WindowsSdkDir)Include/),,$(wildcard $(call fix_path,$(WindowsSdkDir)Include\*))),$(if $(wildcard $(call fix_path,$(WindowsSdkDir)Include/$(folder)/um/Windows.h)),$(folder),)))$(BACKSLASH)
   WindowsSDKVersion := $(WindowsSDKVersion)

   VsInstallBuildTools = $(ProgramFiles86)/Microsoft Visual Studio/2017/BuildTools
   VsInstallEnterprise = $(ProgramFiles86)/Microsoft Visual Studio/2017/Enterprise
   VsInstallProfessional = $(ProgramFiles86)/Microsoft Visual Studio/2017/Professional
   VsInstallCommunity = $(ProgramFiles86)/Microsoft Visual Studio/2017/Community
   VsInstallRoot ?= $(shell if [ -d "$(VsInstallBuildTools)" ]; then echo "$(VsInstallBuildTools)"; fi)

   ifeq ($(VsInstallRoot), )
      VsInstallRoot = $(shell if [ -d "$(VsInstallEnterprise)" ]; then echo "$(VsInstallEnterprise)"; fi)
   endif
   ifeq ($(VsInstallRoot), )
      VsInstallRoot = $(shell if [ -d "$(VsInstallProfessional)" ]; then echo "$(VsInstallProfessional)"; fi)
   endif
   ifeq ($(VsInstallRoot), )
      VsInstallRoot = $(shell if [ -d "$(VsInstallCommunity)" ]; then echo "$(VsInstallCommunity)"; fi)
   endif

   VsInstallRoot := $(VsInstallRoot)
   VcCompilerToolsVer := $(shell cat "$(VsInstallRoot)/VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt" | grep -o '[0-9\.]*')
   VcCompilerToolsDir := $(VsInstallRoot)/VC/Tools/MSVC/$(VcCompilerToolsVer)

   WindowsSDKSharedIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\shared")
   WindowsSDKUCRTIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\ucrt")
   WindowsSDKUMIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\um")
   WindowsSDKUCRTLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib\$(WindowsSDKVersion)\ucrt\$(TargetArchMoniker)")
   WindowsSDKUMLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib\$(WindowsSDKVersion)\um\$(TargetArchMoniker)")

   # For some reason the HostX86 compiler doesn't like compiling for x64
   # ("no such file" opening a shared library), and vice-versa.
   # Work around it for now by using the strictly x86 compiler for x86, and x64 for x64.
   # NOTE: What about ARM?
   ifneq (,$(findstring x64,$(TargetArchMoniker)))
      VCCompilerToolsBinDir := $(VcCompilerToolsDir)\bin\HostX64
   else
      VCCompilerToolsBinDir := $(VcCompilerToolsDir)\bin\HostX86
   endif

   PATH := $(shell IFS=$$'\n'; cygpath "$(VCCompilerToolsBinDir)/$(TargetArchMoniker)"):$(PATH)
   PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VsInstallRoot)/Common7/IDE")
   INCLUDE := $(shell IFS=$$'\n'; cygpath -w "$(VcCompilerToolsDir)/include")
   LIB := $(shell IFS=$$'\n'; cygpath -w "$(VcCompilerToolsDir)/lib/$(TargetArchMoniker)")
   ifneq (,$(findstring uwp,$(PlatformSuffix)))
      LIB := $(shell IFS=$$'\n'; cygpath -w "$(LIB)/store")
   endif

   export INCLUDE := $(INCLUDE);$(WindowsSDKSharedIncludeDir);$(WindowsSDKUCRTIncludeDir);$(WindowsSDKUMIncludeDir)
   export LIB := $(LIB);$(WindowsSDKUCRTLibDir);$(WindowsSDKUMLibDir)
   TARGET := $(TARGET_NAME)_libretro.dll
   PSS_STYLE :=2
   LDFLAGS += -DLL

# Windows MSVC 2010 x64
else ifeq ($(platform), windows_msvc2010_x64)
   CXXFLAGS += -D__WIN32__
   CXX = cl.exe

   PATH := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/bin/amd64"):$(PATH)
   PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../IDE")
   LIB := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/lib/amd64")
   INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/include")

   WindowsSdkDir := $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.0A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')lib/x64
   WindowsSdkDir ?= $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')lib/x64

   WindowsSdkDirInc := $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.0A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')Include
   WindowsSdkDirInc ?= $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')Include

   INCFLAGS_PLATFORM = -I"$(WindowsSdkDirInc)"
   export INCLUDE := $(INCLUDE)
   export LIB := $(LIB);$(WindowsSdkDir)
   TARGET := $(TARGET_NAME)_libretro.dll
   PSS_STYLE :=2
   LDFLAGS += -DLL
   LIBS :=

# Windows MSVC 2010 x86
else ifeq ($(platform), windows_msvc2010_x86)
   CXXFLAGS += -D__WIN32__
   CXX = cl.exe

   PATH := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/bin"):$(PATH)
   PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../IDE")
   LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS100COMNTOOLS)../../VC/lib")
   INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/include")

   WindowsSdkDir := $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.0A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')lib
   WindowsSdkDir ?= $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')lib

   WindowsSdkDirInc := $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.0A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')Include
   WindowsSdkDirInc ?= $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')Include

   INCFLAGS_PLATFORM = -I"$(WindowsSdkDirInc)"
   export INCLUDE := $(INCLUDE)
   export LIB := $(LIB);$(WindowsSdkDir)
   TARGET := $(TARGET_NAME)_libretro.dll
   PSS_STYLE :=2
   LDFLAGS += -DLL
   LIBS :=

# Windows MSVC 2003 x86
else ifeq ($(platform), windows_msvc2003_x86)
   CXXFLAGS += -D__WIN32__
   CXX = cl.exe

   PATH := $(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../../Vc7/bin"):$(PATH)
   PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../IDE")
   INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../../Vc7/include")
   LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS71COMNTOOLS)../../Vc7/lib")
   BIN := $(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../../Vc7/bin")

   WindowsSdkDir := $(INETSDK)

   export INCLUDE := $(INCLUDE);$(INETSDK)/Include;src/drivers/libretro/msvc/msvc-2005
   export LIB := $(LIB);$(WindowsSdkDir);$(INETSDK)/Lib
   TARGET := $(TARGET_NAME)_libretro.dll
   PSS_STYLE :=2
   LDFLAGS += -DLL
   CXXFLAGS += -D_CRT_SECURE_NO_DEPRECATE

# Windows MSVC 2005 x86
else ifeq ($(platform), windows_msvc2005_x86)
   CXXFLAGS += -D__WIN32__
   CXX = cl.exe

   PATH := $(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../../VC/bin"):$(PATH)
   PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../IDE")
   INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../../VC/include")
   LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS80COMNTOOLS)../../VC/lib")
   BIN := $(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../../VC/bin")

   WindowsSdkDir := $(INETSDK)

   export INCLUDE := $(INCLUDE);$(INETSDK)/Include;libretro-common/include/compat/msvc
   export LIB := $(LIB);$(WindowsSdkDir);$(INETSDK)/Lib
   TARGET := $(TARGET_NAME)_libretro.dll
   PSS_STYLE :=2
   LDFLAGS += -DLL
   CXXFLAGS += -D_CRT_SECURE_NO_DEPRECATE

# Windows
else
   TARGET := $(TARGET_NAME)_libretro.dll
   CXX ?= g++
   SHARED := -shared -static-libgcc -static-libstdc++ -s -Wl,--version-script=link.T
   CXXFLAGS += -D__WIN32__
endif

CORE_DIR := ../..

ifeq ($(DEBUG), 1)
   ifneq (,$(findstring msvc,$(platform)))
      CXXFLAGS += -Od -Zi -DDEBUG -D_DEBUG

      ifeq ($(STATIC_LINKING),1)
         CXXFLAGS += -MTd
      else
         CXXFLAGS += -MDd
      endif
   else
      CXXFLAGS += -O0 -g -DDEBUG
   endif
else
   ifneq (,$(findstring msvc,$(platform)))
      CXXFLAGS += -O2 -DNDEBUG
   else
      CXXFLAGS += -O3 -DNDEBUG
   endif

   ifneq (,$(findstring msvc,$(platform)))
      ifeq ($(STATIC_LINKING),1)
         CXXFLAGS += -MT
      else
         CXXFLAGS += -MD
      endif
   endif
endif

include Makefile.common

OBJECTS := $(SOURCES_CXX:.cxx=.o) $(SOURCES_C:.c=.o)

ifeq ($(platform), sncps3)
   WARNINGS_DEFINES =
   CODE_DEFINES =
else ifneq (,$(findstring msvc,$(platform)))
   WARNINGS_DEFINES =
   CODE_DEFINES =
else
   WARNINGS_DEFINES = -Wall -W -Wno-unused-parameter
   CODE_DEFINES =
endif

CXXFLAGS += $(CODE_DEFINES) $(WARNINGS_DEFINES) $(fpic)
CXXFLAGS += -D__LIB_RETRO__ -DSOUND_SUPPORT
CXXFLAGS += -DHAVE_STDINT_H

ifeq (,$(findstring msvc,$(platform)))
   ifeq ($(HAVE_STRINGS_H), 1)
      CXXFLAGS += -DHAVE_STRINGS_H
   endif
   CXXFLAGS += -fno-rtti -pedantic
   ifneq ($(HAVE_EXCEPTIONS), 1)
      CXXFLAGS += -fno-exceptions
   endif
endif

OBJOUT  = -o
LINKOUT = -o

ifneq (,$(findstring msvc,$(platform)))
   OBJOUT = -Fo
   LINKOUT = -out:
   ifeq ($(STATIC_LINKING),1)
      LD ?= lib.exe
      STATIC_LINKING=0
   else
      LD = link.exe
   endif
else ifneq ($(platform),genode)
   LD = $(CXX)
endif

INCFLAGS += $(INCFLAGS_PLATFORM)

ifeq ($(platform), theos_ios)
   COMMON_FLAGS := -DIOS -DARM $(COMMON_DEFINES) $(INCFLAGS) -I$(THEOS_INCLUDE_PATH) -Wno-error
   $(LIBRARY_NAME)_CXXFLAGS += $(CXXFLAGS) $(COMMON_FLAGS)
   ${LIBRARY_NAME}_FILES = $(SOURCES_CXX) $(SOURCES_C)
   include $(THEOS_MAKE_PATH)/library.mk
else
all: $(TARGET)

$(TARGET): $(OBJECTS)
ifeq ($(STATIC_LINKING), 1)
	$(AR) rcs $@ $(OBJECTS)
else
	+$(LD) $(fpic) $(SHARED) $(LINKOUT)$@ $(OBJECTS) $(LDFLAGS) $(LIBS)
endif

%.o: %.cxx
	$(CXX) $(INCFLAGS) $(CPPFLAGS) $(CXXFLAGS) -c $(OBJOUT)$@ $<

%.o: %.c
	$(CC) $(INCFLAGS) -c $(OBJOUT)$@ $<

clean:
	rm -f $(OBJECTS) $(TARGET)
endif
