# PokeMini Makefile for SDL 2.x (Linux)

POKEROOT = ../../
BUILD = Build
TARGET = PokeMini

WINTARGET = PokeMini.exe
WINRES_TRG = $(BUILD)/pokemini_rc.o
WINRES_SRC = $(POKEROOT)resource/pokemini.rc

CFLAGS += -Wall `$(SDL_BASE)sdl2-config --cflags` $(INCLUDE)
SLFLAGS += `$(SDL_BASE)sdl2-config --libs` -lm -lz

INCDIRS = source sourcex resource freebios dependencies/minizip

OBJS = \
 PokeMini_SDL2.o	\
 sourcex/KeybMapSDL2.o	\
 sourcex/ExportBMP.o	\
 sourcex/ExportWAV.o	\
 freebios/freebios.o	\
 source/PMCommon.o	\
 source/PokeMini.o	\
 source/Multicart.o	\
 source/Hardware.o	\
 source/Video.o	\
 source/Video_x1.o	\
 source/Video_x2.o	\
 source/Video_x3.o	\
 source/Video_x4.o	\
 source/Video_x5.o	\
 source/Video_x6.o	\
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
 source/Keyboard.o	\
 dependencies/minizip/unzip.o	\
 dependencies/minizip/ioapi.o	\
 resource/PokeMini_ColorPal.o	\
 resource/PokeMini_Font12.o	\
 resource/PokeMini_Icons12.o	\
 resource/PokeMini_BG2.o	\
 resource/PokeMini_BG3.o	\
 resource/PokeMini_BG4.o	\
 resource/PokeMini_BG5.o	\
 resource/PokeMini_BG6.o

DEPENDS = \
 sourcex/KeybMapSDL2.h	\
 sourcex/ExportBMP.h	\
 sourcex/ExportWAV.h	\
 freebios/freebios.h	\
 source/IOMap.h	\
 source/PMCommon.h	\
 source/PokeMini.h	\
 source/PokeMini_Version.h	\
 source/Multicart.h	\
 source/Hardware.h	\
 source/Video.h	\
 source/Video_x1.h	\
 source/Video_x2.h	\
 source/Video_x3.h	\
 source/Video_x4.h	\
 source/Video_x5.h	\
 source/Video_x6.h	\
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
 source/Keyboard.h	\
 dependencies/minizip/unzip.h	\
 dependencies/minizip/ioapi.h	\
 resource/PokeMini_ColorPal.h	\
 resource/PokeMini_Font12.h	\
 resource/PokeMini_Icons12.h	\
 resource/PokeMini_BG2.h	\
 resource/PokeMini_BG3.h	\
 resource/PokeMini_BG4.h	\
 resource/PokeMini_BG5.h	\
 resource/PokeMini_BG6.h

BUILDOBJS = $(addprefix $(BUILD)/, $(notdir $(OBJS)))
DEPENDSHDR = $(addprefix $(POKEROOT), $(DEPENDS))
INCLUDE = $(foreach inc, $(INCDIRS), -I$(POKEROOT)$(inc))
VPATH = $(addprefix $(POKEROOT),$(INCDIRS))

.PHONY: all win clean

all: $(BUILD) $(TARGET)

$(BUILD):
	@[ -d @ ] || mkdir -p $@

$(BUILD)/%.o: %.c $(DEPENDSHDR)
	$(CC) $(CFLAGS) -o $@ -c $<

$(TARGET): $(BUILDOBJS)
	$(CC) -o $(TARGET) $(BUILDOBJS) $(SLFLAGS)

win:
	make -f makefile.win

clean:
	-rm -f $(BUILDOBJS) $(TARGET) $(WINTARGET) $(WINRES_TRG)
	-rmdir --ignore-fail-on-non-empty $(BUILD)
