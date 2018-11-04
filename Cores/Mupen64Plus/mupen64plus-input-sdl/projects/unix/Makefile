#/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
# *   Mupen64plus-input-sdl - Makefile                                      *
# *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
# *   Copyright (C) 2007-2009 Richard Goedeken                              *
# *                                                                         *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 2 of the License, or     *
# *   (at your option) any later version.                                   *
# *                                                                         *
# *   This program is distributed in the hope that it will be useful,       *
# *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
# *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
# *   GNU General Public License for more details.                          *
# *                                                                         *
# *   You should have received a copy of the GNU General Public License     *
# *   along with this program; if not, write to the                         *
# *   Free Software Foundation, Inc.,                                       *
# *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
# Makefile for SDL Input plugin in Mupen64plus

# detect operating system
UNAME ?= $(shell uname -s)
OS := NONE
ifeq ("$(UNAME)","Linux")
  OS = LINUX
  SO_EXTENSION = so
  SHARED = -shared
endif
ifeq ("$(UNAME)","linux")
  OS = LINUX
  SO_EXTENSION = so
  SHARED = -shared
endif
ifneq ("$(filter GNU hurd,$(UNAME))","")
  OS = LINUX
  SO_EXTENSION = so
  SHARED = -shared
endif
ifeq ("$(UNAME)","Darwin")
  OS = OSX
  SO_EXTENSION = dylib
  SHARED = -bundle
endif
ifeq ("$(UNAME)","FreeBSD")
  OS = FREEBSD
  SO_EXTENSION = so
  SHARED = -shared
endif
ifeq ("$(UNAME)","OpenBSD")
  OS = FREEBSD
  SO_EXTENSION = so
  SHARED = -shared
  $(warning OS type "$(UNAME)" not officially supported.')
endif
ifneq ("$(filter GNU/kFreeBSD kfreebsd,$(UNAME))","")
  OS = LINUX
  SO_EXTENSION = so
  SHARED = -shared
endif
ifeq ("$(patsubst MINGW%,MINGW,$(UNAME))","MINGW")
  OS = MINGW
  SO_EXTENSION = dll
  SHARED = -shared
  PIC = 0
endif
ifeq ("$(OS)","NONE")
  $(error OS type "$(UNAME)" not supported.  Please file bug report at 'http://code.google.com/p/mupen64plus/issues')
endif

# detect system architecture
HOST_CPU ?= $(shell uname -m)
NO_ASM ?= 1
CPU := NONE
ifneq ("$(filter x86_64 amd64,$(HOST_CPU))","")
  CPU := X86
  ifeq ("$(BITS)", "32")
    ARCH_DETECTED := 64BITS_32
    PIC ?= 0
  else
    ARCH_DETECTED := 64BITS
    PIC ?= 1
  endif
endif
ifneq ("$(filter pentium i%86,$(HOST_CPU))","")
  CPU := X86
  ARCH_DETECTED := 32BITS
  PIC ?= 0
endif
ifneq ("$(filter ppc macppc socppc powerpc,$(HOST_CPU))","")
  CPU := PPC
  ARCH_DETECTED := 32BITS
  BIG_ENDIAN := 1
  PIC ?= 1
  $(warning Architecture "$(HOST_CPU)" not officially supported.')
endif
ifneq ("$(filter ppc64 powerpc64,$(HOST_CPU))","")
  CPU := PPC
  ARCH_DETECTED := 64BITS
  BIG_ENDIAN := 1
  PIC ?= 1
  $(warning Architecture "$(HOST_CPU)" not officially supported.')
endif
ifneq ("$(filter arm%,$(HOST_CPU))","")
  ifeq ("$(filter arm%b,$(HOST_CPU))","")
    CPU := ARM
    ARCH_DETECTED := 32BITS
    PIC ?= 1
    $(warning Architecture "$(HOST_CPU)" not officially supported.')
  endif
endif
ifeq ("$(CPU)","NONE")
  $(error CPU type "$(HOST_CPU)" not supported.  Please file bug report at 'http://code.google.com/p/mupen64plus/issues')
endif

# base CFLAGS, LDLIBS, and LDFLAGS
OPTFLAGS ?= -O3 -flto
WARNFLAGS ?= -Wall
CFLAGS += $(OPTFLAGS) $(WARNFLAGS) -ffast-math -fno-strict-aliasing -fvisibility=hidden -I../../src -D_GNU_SOURCE=1
LDFLAGS += $(SHARED)

# Since we are building a shared library, we must compile with -fPIC on some architectures
# On 32-bit x86 systems we do not want to use -fPIC because we don't have to and it has a big performance penalty on this arch
ifeq ($(PIC), 1)
  CFLAGS += -fPIC
else
  CFLAGS += -fno-PIC
endif

ifeq ($(BIG_ENDIAN), 1)
  CFLAGS += -DM64P_BIG_ENDIAN
endif

# tweak flags for 32-bit build on 64-bit system
ifeq ($(ARCH_DETECTED), 64BITS_32)
  CFLAGS += -m32
  LDFLAGS += -Wl,-m,elf_i386
endif

# set special flags per-system
ifeq ($(OS), FREEBSD)
  ifeq ($(ARCH_DETECTED), 64BITS_32)
    $(error Do not use the BITS=32 option with FreeBSD, use -m32 and -m elf_i386)
  endif
endif
ifeq ($(OS), LINUX)
  LDLIBS += -ldl
endif
ifeq ($(OS), OSX)
  # Select the proper SDK
  # Also, SDKs are stored in a different location since XCode 4.3
  OSX_SDK ?= $(shell sw_vers -productVersion | cut -f1 -f2 -d .)
  OSX_XCODEMAJ = $(shell xcodebuild -version | grep '[0-9]*\.[0-9]*' | cut -f2 -d ' ' | cut -f1 -d .)
  OSX_XCODEMIN = $(shell xcodebuild -version | grep '[0-9]*\.[0-9]*' | cut -f2 -d ' ' | cut -f2 -d .)
  OSX_XCODEGE43 = $(shell echo "`expr $(OSX_XCODEMAJ) \>= 4``expr $(OSX_XCODEMIN) \>= 3`")
  ifeq ($(OSX_XCODEGE43), 11)
    OSX_SYSROOT := /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs
  else
    OSX_SYSROOT := /Developer/SDKs
  endif

  ifeq ($(CPU), X86)
    ifeq ($(ARCH_DETECTED), 64BITS)
      CFLAGS += -arch x86_64 -mmacosx-version-min=$(OSX_SDK) -isysroot $(OSX_SYSROOT)/MacOSX$(OSX_SDK).sdk
      LDLIBS += -ldl
    else
      CFLAGS += -mmmx -msse -fomit-frame-pointer -arch i686 -mmacosx-version-min=$(OSX_SDK) -isysroot $(OSX_SYSROOT)/MacOSX$(OSX_SDK).sdk
      LDLIBS += -ldl -read_only_relocs suppress
    endif
  endif
endif

# test for presence of SDL
ifeq ($(origin SDL_CFLAGS) $(origin SDL_LDLIBS), undefined undefined)
  SDL_CONFIG = $(CROSS_COMPILE)sdl-config
  ifeq ($(shell which $(SDL_CONFIG) 2>/dev/null),)
    $(error No SDL development libraries found!)
  endif
  SDL_CFLAGS  += $(shell $(SDL_CONFIG) --cflags)
  SDL_LDLIBS += $(shell $(SDL_CONFIG) --libs)
endif
CFLAGS += $(SDL_CFLAGS)
LDLIBS += $(SDL_LDLIBS)

# set mupen64plus core API header path
ifneq ("$(APIDIR)","")
  CFLAGS += "-I$(APIDIR)"
else
  TRYDIR = ../../../mupen64plus-core/src/api
  ifneq ("$(wildcard $(TRYDIR)/m64p_types.h)","")
    CFLAGS += -I$(TRYDIR)
  else
    TRYDIR = /usr/local/include/mupen64plus
    ifneq ("$(wildcard $(TRYDIR)/m64p_types.h)","")
      CFLAGS += -I$(TRYDIR)
    else
      TRYDIR = /usr/include/mupen64plus
      ifneq ("$(wildcard $(TRYDIR)/m64p_types.h)","")
        CFLAGS += -I$(TRYDIR)
      else
        $(error Mupen64Plus API header files not found! Use makefile parameter APIDIR to force a location.)
      endif
    endif
  endif
endif

# reduced compile output when running make without V=1
ifneq ($(findstring $(MAKEFLAGS),s),s)
ifndef V
    Q_CC = @echo '    CC  '$@;
    Q_LD = @echo '    LD  '$@;
endif
endif

# set base program pointers and flags
CC        = $(CROSS_COMPILE)gcc
CXX       = $(CROSS_COMPILE)g++
RM       ?= rm -f
INSTALL  ?= install
MKDIR ?= mkdir -p
COMPILE.c = $(Q_CC)$(CC) $(CFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c
LINK.o = $(Q_LD)$(CC) $(CFLAGS) $(LDFLAGS) $(TARGET_ARCH)

# set special flags for given Makefile parameters
ifeq ($(DEBUG),1)
  CFLAGS += -g
  INSTALL_STRIP_FLAG ?= 
else
  ifneq ($(OS),OSX)
    INSTALL_STRIP_FLAG ?= -s
  endif
endif
ifeq ($(PLUGINDBG), 1)
  CFLAGS += -D_DEBUG
endif

# set installation options
ifeq ($(PREFIX),)
  PREFIX := /usr/local
endif
ifeq ($(SHAREDIR),)
  SHAREDIR := $(PREFIX)/share/mupen64plus
endif
ifeq ($(LIBDIR),)
  LIBDIR := $(PREFIX)/lib
endif
ifeq ($(PLUGINDIR),)
  PLUGINDIR := $(LIBDIR)/mupen64plus
endif

SRCDIR = ../../src
OBJDIR = _obj$(POSTFIX)

# list of source files to compile
SOURCE = \
	$(SRCDIR)/plugin.c \
	$(SRCDIR)/autoconfig.c \
	$(SRCDIR)/config.c

ifeq ($(OS),MINGW)
SOURCE += $(SRCDIR)/osal_dynamiclib_win32.c
else
SOURCE += $(SRCDIR)/osal_dynamiclib_unix.c
endif

# generate a list of object files build, make a temporary directory for them
OBJECTS := $(patsubst $(SRCDIR)/%.c, $(OBJDIR)/%.o, $(filter %.c, $(SOURCE)))
OBJDIRS = $(dir $(OBJECTS))
$(shell $(MKDIR) $(OBJDIRS))

# build targets
TARGET = mupen64plus-input-sdl$(POSTFIX).$(SO_EXTENSION)

targets:
	@echo "Mupen64Plus-input-sdl makefile. "
	@echo "  Targets:"
	@echo "    all           == Build Mupen64Plus SDL input plugin"
	@echo "    clean         == remove object files"
	@echo "    rebuild       == clean and re-build all"
	@echo "    install       == Install Mupen64Plus SDL input plugin"
	@echo "    uninstall     == Uninstall Mupen64Plus SDL input plugin"
	@echo "  Options:"
	@echo "    BITS=32       == build 32-bit binaries on 64-bit machine"
	@echo "    APIDIR=path   == path to find Mupen64Plus Core headers"
	@echo "    OPTFLAGS=flag == compiler optimization (default: -O3 -flto)"
	@echo "    WARNFLAGS=flag == compiler warning levels (default: -Wall)"
	@echo "    PIC=(1|0)     == Force enable/disable of position independent code"
	@echo "    POSTFIX=name  == String added to the name of the the build (default: '')"
	@echo "  Install Options:"
	@echo "    PREFIX=path   == install/uninstall prefix (default: /usr/local)"
	@echo "    SHAREDIR=path == path to install shared data files (default: PREFIX/share/mupen64plus)"
	@echo "    LIBDIR=path   == library prefix (default: PREFIX/lib)"
	@echo "    PLUGINDIR=path == path to install plugin libraries (default: LIBDIR/mupen64plus)"
	@echo "    DESTDIR=path  == path to prepend to all installation paths (only for packagers)"
	@echo "  Debugging Options:"
	@echo "    DEBUG=1       == add debugging symbols"
	@echo "    PLUGINDBG=1   == print extra debugging information while running"
	@echo "    V=1           == show verbose compiler output"

all: $(TARGET)

install: $(TARGET)
	$(INSTALL) -d "$(DESTDIR)$(PLUGINDIR)"
	$(INSTALL) -m 0644 $(INSTALL_STRIP_FLAG) $(TARGET) "$(DESTDIR)$(PLUGINDIR)"
	$(INSTALL) -d "$(DESTDIR)$(SHAREDIR)"
	$(INSTALL) -m 0644 "../../data/InputAutoCfg.ini" "$(DESTDIR)$(SHAREDIR)"

uninstall:
	$(RM) "$(DESTDIR)$(PLUGINDIR)/$(TARGET)"
	$(RM) "$(DESTDIR)$(SHAREDIR)/InputAutoCfg.ini"

clean:
	$(RM) -r $(OBJDIR) $(TARGET)

rebuild: clean all

# build dependency files
CFLAGS += -MD
-include $(OBJECTS:.o=.d)

# standard build rules
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	$(COMPILE.c) -o $@ $<

$(TARGET): $(OBJECTS)
	$(LINK.o) $^ $(LOADLIBES) $(LDLIBS) -o $@

.PHONY: all clean install uninstall targets
