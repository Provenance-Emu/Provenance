# KallistiOS Ogg/Vorbis Decoder Library
#
# Library Makefile
# (c)2001 Thorsten Titze
# Based on KOS Makefiles by Dan Potter

BUILD    = debug
TARGET   = gep.elf
LIBS     = -lkallisti -lm -lgcc
#DATAOBJS = romdisk.o
SOURCE   = ../../source/dc ../../source/common ../../source/common/console ./$(BUILD)
INCLUDE  = -I../../Include/common -I../../Include/dc
OBJS     = \
	main.o \
	array.o \
	file.o \
	surface.o \
	pixelformat.o \
	memspace.o \
	inputdevice.o \
	console.o \
	linebuffer.o \
	msgnode.o



#
# KOS configuration
#

KOS_ARCH     =  dreamcast
KOS_BASE     =  /d/proj/kos
KOS_ARCH_DIR =  $(KOS_BASE)/kernel/arch/$(KOS_ARCH)
KOS_START    =  $(KOS_ARCH_DIR)/kernel/startup.o
KOS_INCS     =  -I${KOS_BASE}/include -I$(KOS_BASE)/kernel/arch/$(KOS_ARCH)/include

#
# Build configuration
#

KOS_CFLAGS   = -Wall -g -ml -m4-single-only -O1 -fno-builtin -fno-strict-aliasing -fomit-frame-pointer
KOS_DEFINES  = -D_arch_$(KOS_ARCH)
KOS_CPPFLAGS = -fno-operator-names -fno-rtti -fno-exceptions
KOS_AFLAGS   = -little
KOS_LDFLAGS  = -ml -m4-single-only -nostartfiles -nostdlib -Wl,-Ttext=0x8c010000


#

vpath % $(SOURCE)
vpath %.d ./$(BUILD)

all: $(TARGET)

#
# Build rules
#

%.o: %.c
	@echo Compiling $<...
	@$(KOS_CC) $(KOS_CFLAGS) $(KOS_DEFINES) $(KOS_INCS) $(INCLUDE) -c $< -o $(BUILD)/$@

%.o: %.cc
	@echo Compiling $<...
	@$(KOS_CCPLUS) $(KOS_CFLAGS) $(KOS_DEFINES) $(KOS_CPPFLAGS) $(KOS_INCS) $(INCLUDE) -c $< -o $(BUILD)/$@

%.o: %.cpp
	@echo Compiling $<...
	@$(KOS_CCPLUS) $(KOS_CFLAGS) $(KOS_DEFINES) $(KOS_CPPFLAGS) $(KOS_INCS) $(INCLUDE) -c $< -o $(BUILD)/$@

%.o: %.s
	@echo Assembling $<...
	@$(KOS_AS) $(KOS_AFLAGS) $< -o $(BUILD)/$@

clean:
	@echo Cleaning $(BUILD)
	rm -f $(BUILD)/*.d 
	rm -f $(BUILD)/*.o 
	rm -f $(BUILD)/*.elf

$(BUILD)/%.d: %.c
	@echo Building dependencies $<...
	@set -e; \
	$(KOS_CC) $(KOS_CFLAGS) $(KOS_DEFINES) $(KOS_INCS) $(INCLUDE) -MM $< \
	| sed 's/\($*\)\.o[ :]*/\1.o $*.d : /g' > $@ ; \
	[ -s $@ ] || rm -f $@

$(BUILD)/%.d: %.cpp
	@echo Building dependencies $< $@...
	@set -e; \
	$(KOS_CCPLUS) $(KOS_CFLAGS) $(KOS_DEFINES) $(KOS_CPPFLAGS) $(KOS_INCS) $(INCLUDE) -MM $< \
	| sed 's/\($*\)\.o[ :]*/\1.o $*.d : /g' > $@ ; \
	[ -s $@ ] || rm -f $@

$(TARGET): $(OBJS) $(DATAOBJS)
	@echo Linking $@...
	@cd $(BUILD) ; \
	$(KOS_CC) $(KOS_CFLAGS) $(KOS_LDFLAGS) -o $(TARGET) $(KOS_START) \
	      $(OBJS) $(DATAOBJS) $(OBJEXTRA) -L$(KOS_BASE)/lib $(LIBS)

#romdisk.img:
#	${KOS_BASE}/utils/genromfs/genromfs -f $(BUILD)/romdisk.img -d romdisk -v

#romdisk.o: romdisk.img
#	$(KOS_BASE)/utils/bin2o/bin2o $(BUILD)/romdisk.img romdisk $(BUILD)/romdisk.o

run: $(TARGET)
	$(KOS_LOADER) $(BUILD)/$(TARGET)

dist:
	@cd $(BUILD) ; \
	rm -f $(OBJS) ; \
	$(KOS_CC_BASE)/bin/sh-elf-strip $(TARGET)


#
# dependencies
#

include $(OBJS:%.o=$(BUILD)/%.d)
