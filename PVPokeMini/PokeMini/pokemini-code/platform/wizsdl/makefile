# PokeMini Makefile for WIZ

OPENWIZ = /opt/arm-openwiz-linux-gnu
HOST = arm-openwiz-linux-gnu-

ifeq ($(OPENWIZ),)
CC = $(HOST)gcc
LD = $(HOST)gcc
STRIP = $(HOST)strip
else
CC = $(OPENWIZ)/bin/$(HOST)gcc
LD = $(OPENWIZ)/bin/$(HOST)gcc
STRIP = $(OPENWIZ)/bin/$(HOST)strip
endif

BUILD = Build
TARGET = PokeMiniSDL
POKEROOT = ../../

CFLAGS = -O2 -Wall -I$(OPENWIZ)/include `$(SDL_BASE)sdl-config --cflags` $(INCLUDE) -DPERFORMANCE
SLFLAGS = -O2 -L$(OPENWIZ)/lib -Wl,-rpath,$(OPENWIZ)/lib -lm -lz -lSDL

INCDIRS = source resource freebios dependencies/minizip

OBJS = \
 PokeMini_WIZ.o	\
 freebios/freebios.o	\
 source/PMCommon.o	\
 source/PokeMini.o	\
 source/Multicart.o	\
 source/Hardware.o	\
 source/Video.o	\
 source/Video_x3.o	\
 source/CommandLine.o	\
 source/MinxCPU.o	\
 source/MinxCPU_XX.o	\
 source/MinxCPU_CE.o	\
 source/MinxCPU_CF.o	\
 source/MinxCPU_SP.o \
 source/MinxTimers.o	\
 source/MinxIO.o	\
 source/MinxIRQ.o	\
 source/MinxPRC.o	\
 source/MinxColorPRC.o	\
 source/MinxLCD.o	\
 source/MinxAudio.o	\
 source/UI.o	\
 source/Joystick.o	\
 dependencies/minizip/unzip.o	\
 dependencies/minizip/ioapi.o	\
 resource/PokeMini_ColorPal.o	\
 resource/PokeMini_Font12.o	\
 resource/PokeMini_Icons12.o	\
 resource/PokeMini_BG3.o

DEPENDS = \
 freebios/freebios.h	\
 source/IOMap.h	\
 source/PMCommon.h	\
 source/PokeMini.h	\
 source/PokeMini_Version.h	\
 source/Multicart.h	\
 source/Hardware.h	\
 source/Video.h	\
 source/Video_x3.h	\
 source/CommandLine.h	\
 source/MinxCPU.h	\
 source/MinxTimers.h	\
 source/MinxIO.h	\
 source/MinxIRQ.h	\
 source/MinxPRC.h	\
 source/MinxColorPRC.h	\
 source/MinxLCD.h	\
 source/MinxAudio.h	\
 source/UI.h	\
 source/Joystick.h	\
 dependencies/minizip/unzip.h	\
 dependencies/minizip/ioapi.h	\
 resource/PokeMini_ColorPal.h	\
 resource/PokeMini_Font12.h	\
 resource/PokeMini_Icons12.h	\
 resource/PokeMini_BG3.h

BUILDOBJS = $(addprefix $(BUILD)/, $(notdir $(OBJS)))
DEPENDSHDR = $(addprefix $(POKEROOT), $(DEPENDS))
INCLUDE = $(foreach inc, $(INCDIRS), -I$(POKEROOT)$(inc))
VPATH = $(addprefix $(POKEROOT),$(INCDIRS))

.PHONY: all clean

all: $(BUILD) $(TARGET)

$(BUILD):
	@[ -d @ ] || mkdir -p $@

$(BUILD)/%.o: %.c $(DEPENDSHDR)
	$(CC) $(CFLAGS) -o $@ -c $<

$(TARGET): $(BUILDOBJS)
	$(LD) -o $(TARGET) $(BUILDOBJS) $(SLFLAGS)
	$(STRIP) $(TARGET)

clean:
	-rm -f $(BUILDOBJS) $(TARGET)
	-rmdir --ignore-fail-on-non-empty $(BUILD)

