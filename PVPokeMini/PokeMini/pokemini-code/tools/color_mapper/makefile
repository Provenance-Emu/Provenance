# Color Mapper Makefile for GTK

CC = gcc
LD = gcc
STRIP = strip
POKEROOT = ../../
BUILD = Build
TARGET = color_mapper

RELEASE_DIR = ../../release

WINTARGET = color_mapper.exe
WINRES_TRG = $(BUILD)/color_mapper_rc.o
WINRES_SRC = color_mapper.rc

CFLAGS = -march=i686 -O -Wall `pkg-config --cflags gtk+-2.0` $(INCLUDE)
SLFLAGS = -march=i686 -O `pkg-config --libs gtk+-2.0` -lm -mwindows

INCDIRS = source sourcex resource

OBJS = \
 color_mapper.o	\
 color_info.o	\
 color_display.o	\
 gtkx_colormapper.o	\
 gtkx_pickedcolor.o	\
 gtkx_palettepicker.o	\
 sourcex/GtkXDialogs.o	\
 sourcex/PokeMiniIcon_96x128.o	\
 sourcex/ExportBMP.o	\
 sourcex/HelpSupport.o	\
 source/PMCommon.o	\
 source/CommandLine.o	\
 resource/PokeMini_ColorPal.o

DEPENDS_LOCAL = \
 color_mapper.h	\
 color_info.h	\
 color_display.h	\
 gtkx_colormapper.h	\
 gtkx_pickedcolor.h	\
 gtkx_palettepicker.h

DEPENDS = \
 sourcex/GtkXDialogs.h	\
 sourcex/PokeMiniIcon_96x128.h	\
 sourcex/ExportBMP.h	\
 sourcex/HelpSupport.h	\
 source/PMCommon.h	\
 source/CommandLine.h	\
 resource/PokeMini_ColorPal.h	\

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
	if [ -d $(RELEASE_DIR) ]; then cp $(TARGET) $(RELEASE_DIR); fi

win: $(BUILD) $(WINTARGET)

$(WINTARGET): $(BUILDOBJS) $(WINRES_SRC)
	windres $(INCLUDE) $(WINRES_SRC) $(WINRES_TRG)
	$(LD) -o $(WINTARGET) $(BUILDOBJS) $(WINRES_TRG) $(SLFLAGS)
	$(STRIP) $(WINTARGET)
	if [ -d $(RELEASE_DIR) ]; then cp $(TARGET) $(RELEASE_DIR); fi

clean:
	-rm -f $(BUILDOBJS) $(TARGET) $(WINTARGET) $(WINRES_TRG)
	-rmdir --ignore-fail-on-non-empty $(BUILD)
