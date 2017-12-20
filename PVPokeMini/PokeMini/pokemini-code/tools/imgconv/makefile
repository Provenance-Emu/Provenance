CC = gcc
LD = gcc
STRIP = strip
BUILD = Build
TARGET = pokemini_imgconv
POKEROOT = ../../

WINTARGET = pokemini_imgconv.exe

CFLAGS = -O -Wall $(INCLUDE)
SLFLAGS = -O -lm -lfreeimage

INCDIRS = source sourcex resource

OBJS = \
 pokemini_imgconv.o	\
 sourcex/ExportCode.o	\
 sourcex/ExportC.o	\
 sourcex/ExportASM.o	\
 source/PMCommon.o

DEPENDS_LOCAL = \
 pokemini_imgconv.h

DEPENDS = \
 sourcex/ExportCode.h	\
 sourcex/ExportC.h	\
 sourcex/ExportASM.h	\
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
	$(LD) -o $(TARGET) $(BUILDOBJS) $(SLFLAGS)
	$(STRIP) $(TARGET)
	if [ -d release ]; then cp $(TARGET) release; fi

win: $(BUILD) $(WINTARGET)

$(WINTARGET): $(BUILDOBJS) $(WINRES_SRC)
	$(LD) -o $(WINTARGET) $(BUILDOBJS) $(WINRES_TRG) $(SLFLAGS)
	$(STRIP) $(WINTARGET)
	if [ -d release ]; then cp $(WINTARGET) release; fi

clean:
	-rm -f $(BUILDOBJS) $(TARGET) $(WINTARGET)
	-rmdir --ignore-fail-on-non-empty $(BUILD)
