# PokeMini Makefile for Dreamcast

CC = kos-cc
LD = kos-cc
STRIP = strip
POKEROOT = ../../
BUILD = Build
TARGET = PokeMini.elf
LIBS = 

INCDIRS = source resource freebios sourcex dependencies/minizip dependencies/zlib

OBJS = \
 PokeMini_DC.o	\
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
 dependencies/zlib/adler32.o	\
 dependencies/zlib/crc32.o	\
 dependencies/zlib/inffast.o	\
 dependencies/zlib/inflate.o	\
 dependencies/zlib/inftrees.o	\
 dependencies/zlib/zutil.o	\
 sourcex/Zip64comp.o	\
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
 dependencies/zlib/zlib.h	\
 resource/PokeMini_ColorPal.h	\
 resource/PokeMini_Font12.h	\
 resource/PokeMini_Icons12.h	\
 resource/PokeMini_BG3.h

BUILDOBJS = $(addprefix $(BUILD)/, $(notdir $(OBJS)))
DEPENDSHDR = $(addprefix $(POKEROOT), $(DEPENDS))
INCLUDE = $(foreach inc, $(INCDIRS), -I$(POKEROOT)$(inc))
VPATH = $(addprefix $(POKEROOT),$(INCDIRS))

.PHONY: all clean scramble run

all: $(BUILD) $(TARGET)

include $(KOS_BASE)/Makefile.rules

KOS_LOCAL_CFLAGS = -O -Wall $(INCLUDE) -I. -I $(KOS_BASE)/kernel/arch/dreamcast/sound -DFS_DC -DPERFORMANCE
KOS_LOCAL_LDFLAGS = -O $(LIBS)

$(BUILD):
	@[ -d @ ] || mkdir -p $@

$(BUILD)/%.o: %.c $(DEPENDSHDR)
	$(CC) $(KOS_LOCAL_CFLAGS) -o $@ -c $<

$(TARGET): $(BUILDOBJS)
	$(CC) -o $(TARGET) $(BUILDOBJS) $(KOS_LOCAL_LDFLAGS) $(KOS_LIBS)
	$(KOS_STRIP) $(TARGET)

scramble: $(TARGET)
	$(KOS_OBJCOPY) -R .stack -O binary $(TARGET) $(TARGET).bin
	scramble $(TARGET).bin 1ST_READ.BIN

run: $(TARGET)
	$(KOS_LOADER) $<

clean:
	-rm -f $(BUILDOBJS) $(TARGET) $(TARGET).bin 1ST_READ.BIN
	-rmdir --ignore-fail-on-non-empty $(BUILD)
