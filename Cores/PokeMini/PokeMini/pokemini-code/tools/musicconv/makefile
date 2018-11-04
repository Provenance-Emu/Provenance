CC = gcc
LD = gcc
STRIP = strip
BUILD = Build
TARGET = pokemini_musicconv
POKEROOT = ../../
LIBS = -lopenal

WINTARGET = pokemini_musicconv.exe
WINLIBS = -lOpenAL32

CFLAGS = -O -Wall $(INCLUDE) -DNO_ZIP
SLFLAGS = -O -lm -lz

INCDIRS = source sourcex resource

OBJS = \
 pokemini_musicconv.o	\
 pm_music.o	\
 saudio_al.o	\
 raw_input.o	\
 sourcex/ExportCode.o	\
 sourcex/ExportC.o	\
 sourcex/ExportASM.o	\
 sourcex/ExportWAV.o	\
 source/MinxTimers.o	\
 source/MinxAudio.o	\
 source/PMCommon.o

DEPENDS_LOCAL = \
 saudio_al.h	\
 raw_input.h	\
 pokemini_musicconv.h	\
 pm_music.h

DEPENDS = \
 sourcex/ExportCode.h	\
 sourcex/ExportC.h	\
 sourcex/ExportASM.h	\
 sourcex/ExportWAV.h	\
 source/PokeMini.h	\
 source/MinxTimers.h	\
 source/MinxAudio.h	\
 source/PMCommon.h

BUILDOBJS = $(addprefix $(BUILD)/, $(notdir $(OBJS)))
DEPENDSHDR = $(addprefix $(POKEROOT), $(DEPENDS))
INCLUDE = $(foreach inc, $(INCDIRS), -I$(POKEROOT)$(inc))
VPATH = $(addprefix $(POKEROOT),$(INCDIRS))

.PHONY: all win clean

all: $(BUILD) $(TARGET)

$(BUILD):
	@[ -d @ ] || mkdir -p $@

$(BUILD)/%.o: %.c $(DEPENDSHDR) $(DEPENDS_LOCAL)
	$(CC) $(CFLAGS) -o $@ -c $<

$(TARGET): $(BUILDOBJS)
	$(LD) -o $(TARGET) $(BUILDOBJS) $(SLFLAGS) $(LIBS)
	$(STRIP) $(TARGET)
	if [ -d release ]; then cp $(TARGET) release; fi

win: $(BUILD) $(WINTARGET)

$(WINTARGET): $(BUILDOBJS) $(WINRES_SRC)
	$(LD) -o $(WINTARGET) $(BUILDOBJS) $(WINRES_TRG) $(SLFLAGS) $(WINLIBS)
	$(STRIP) $(WINTARGET)
	if [ -d release ]; then cp $(WINTARGET) release; fi

clean:
	-rm -f $(BUILDOBJS) $(TARGET) $(WINTARGET)
	-rmdir --ignore-fail-on-non-empty $(BUILD)
