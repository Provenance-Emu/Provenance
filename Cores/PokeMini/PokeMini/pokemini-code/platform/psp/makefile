# PokeMini Makefile for PSP

TARGET = PokeMini
POKEROOT = ../../

OBJS = \
 PokeMini_PSP.o	\
 PSPStuffz.o	\
 $(POKEROOT)freebios/freebios.o	\
 $(POKEROOT)source/PMCommon.o	\
 $(POKEROOT)source/PokeMini.o	\
 $(POKEROOT)source/Multicart.o	\
 $(POKEROOT)source/Hardware.o	\
 $(POKEROOT)source/Video.o	\
 $(POKEROOT)source/Video_x1.o	\
 $(POKEROOT)source/Video_x2.o	\
 $(POKEROOT)source/Video_x3.o	\
 $(POKEROOT)source/Video_x4.o	\
 $(POKEROOT)source/MinxCPU.o	\
 $(POKEROOT)source/MinxCPU_XX.o	\
 $(POKEROOT)source/MinxCPU_CE.o	\
 $(POKEROOT)source/MinxCPU_CF.o	\
 $(POKEROOT)source/MinxCPU_SP.o	\
 $(POKEROOT)source/MinxIRQ.o	\
 $(POKEROOT)source/MinxTimers.o	\
 $(POKEROOT)source/MinxIO.o	\
 $(POKEROOT)source/MinxPRC.o	\
 $(POKEROOT)source/MinxColorPRC.o	\
 $(POKEROOT)source/MinxLCD.o	\
 $(POKEROOT)source/MinxAudio.o	\
 $(POKEROOT)source/CommandLine.o	\
 $(POKEROOT)source/UI.o	\
 $(POKEROOT)source/Joystick.o	\
 $(POKEROOT)dependencies/minizip/unzip.o	\
 $(POKEROOT)dependencies/minizip/ioapi.o	\
 $(POKEROOT)dependencies/zlib/adler32.o	\
 $(POKEROOT)dependencies/zlib/crc32.o	\
 $(POKEROOT)dependencies/zlib/inffast.o	\
 $(POKEROOT)dependencies/zlib/inflate.o	\
 $(POKEROOT)dependencies/zlib/inftrees.o	\
 $(POKEROOT)dependencies/zlib/zutil.o	\
 $(POKEROOT)sourcex/Zip64comp.o	\
 $(POKEROOT)resource/PokeMini_Font12.o	\
 $(POKEROOT)resource/PokeMini_Icons12.o	\
 $(POKEROOT)resource/PokeMini_BG2.o	\
 $(POKEROOT)resource/PokeMini_BG3.o	\
 $(POKEROOT)resource/PokeMini_BG4.o	\
 $(POKEROOT)resource/PokeMini_ColorPal.o

INCDIR = $(POKEROOT)source $(POKEROOT)resource $(POKEROOT)freebios \
 $(POKEROOT)sourcex $(POKEROOT)dependencies/minizip $(POKEROOT)dependencies/zlib

CFLAGS = -G0 -Wall -O2 -DPERFORMANCE
CXXFLAGS = $(CFLAGS) -fno-exceptions -fno-rtti $(INCLUDE)
ASFLAGS = $(CFLAGS)

LIBDIR =
LDFLAGS =
LIBS= -lpspgum -lpspgu -lpspaudiolib -lpspaudio -lpsppower -lpsprtc -lm

EXTRA_TARGETS = EBOOT.PBP
PSP_EBOOT_TITLE = PokeMini 0.60 PSP
PSP_EBOOT_ICON = icon0.png

PSPSDK=$(shell psp-config --pspsdk-path)
include $(PSPSDK)/lib/build.mak
