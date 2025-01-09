# SNESticlePS2 makefile
#

ifndef DEV
$(error "DEV not defined!")
endif

ifndef MACHTYPE
$(error Error: MACHTYPE not defined [export MACHTYPE])
endif

#
# Tool versions
#

#export EE_GCC_VERSION  ?= 2.9

#export EE_GCC_VERSION  ?= 3.2.2
export EE_GCC_VERSION  ?= 3.2.2-b1

export IOP_GCC_VERSION ?= 2.8.1
export DVP_GCC_VERSION ?= 3.2.2-beta

#
# Toolchain configuration
#

PS2DEV       ?= $(DEV)/ps2dev

EE_BASE      = $(PS2DEV)/gcc/$(EE_GCC_VERSION)/install/$(MACHTYPE)/ee
IOP_BASE     = $(PS2DEV)/gcc/$(IOP_GCC_VERSION)/install/$(MACHTYPE)/iop
DVP_BASE     = $(PS2DEV)/gcc/$(DVP_GCC_VERSION)/install/$(MACHTYPE)/dvp

EE_PREFIX   = $(EE_BASE)/bin/ee-
EE_CC  	    = $(EE_PREFIX)gcc
EE_CCPLUS   = $(EE_PREFIX)gcc
EE_AS       = $(EE_PREFIX)as
EE_LD       = $(EE_PREFIX)ld
EE_AR       = $(EE_PREFIX)ar
EE_OBJCOPY  = $(EE_PREFIX)objcopy
EE_STRIP    = $(EE_PREFIX)strip

IOP_PREFIX  = $(IOP_BASE)/bin/iop-
IOP_CC      = $(IOP_PREFIX)gcc
IOP_AS      = $(IOP_PREFIX)as
IOP_LD      = $(IOP_PREFIX)ld
IOP_AR      = $(IOP_PREFIX)ar
IOP_OBJCOPY = $(IOP_PREFIX)objcopy
IOP_STRIP   = $(IOP_PREFIX)strip

BIN2C       = $(DEV)/bin/$(MACHTYPE)/bin2c


#
# Build configuration
#


ifdef build
BUILD    := $(build)
endif

ifndef BUILD
BUILD    := debug
endif

BUILD_DIR := $(BUILD)_EE$(EE_GCC_VERSION)


#
# PS2DEV configuration
#

PS2LIB_BASE ?= $(PS2DEV)/ps2lib/dev
PS2IP_BASE  ?= $(PS2DEV)/ps2net/dev/ps2ip
LWIP_BASE   ?= $(PS2DEV)/ps2net/dev/lwip/
PS2DRV_BASE ?= $(PS2DEV)/ps2drv/dev

PS2LIB_EE_INCS     =  -I${PS2LIB_BASE}/common/include -I${PS2LIB_BASE}/ee/include 
PS2IP_EE_INCS      =  -I$(PS2IP_BASE)/include


#
# Target config
#

TARGET   	= SNESticle.elf
LIBS     	= -lmc -lpad -lps2ip -lkernel -lc -lm -lgcc
ifneq ($(EE_GCC_VERSION), 2.9)
LIBS       += -lstdc++
endif

LINKFILE    = ../linkfile

CDDATAPATH	  = /cygdrive/z/iso/SNESticle
PKSHPATH      = /cygdrive/c/dev/bin/i686-pc-cygwin/pksh
INSTALLFILES  =	PS2IP.IRX 	PS2IP.IRX	PS2IPS.IRX 	NETPLAY.IRX	PS2SMAP.IRX
INSTALLFILES +=	MCSAVE.IRX 	SJPCM2.IRX 	CDVD.IRX 	PS2LINK.IRX	TITLE.DB 	ICON.SYS 
CDELFNAME     = SLPS_999.99
ISOPATH 	  = c:/iso/SNESticle.iso

MODULE_BASE = ../../Modules
GEPDIR   	= ../../../Gep
SNESSOURCE 	= ../../Source
NESSOURCE 	= ../../../NESticle/Source

#
# Source search paths
#

SOURCE  = 
SOURCE += $(GEPDIR)/Source/ps2
SOURCE += $(GEPDIR)/Source/common/zlib
SOURCE += $(GEPDIR)/Source/common/unzip
SOURCE += $(GEPDIR)/Source/common
SOURCE += $(GEPDIR)/Source/common/console
SOURCE += $(SNESSOURCE)/ps2
SOURCE += $(SNESSOURCE)/common
SOURCE += $(NESSOURCE)/ps2
SOURCE += $(NESSOURCE)/common/ncpu
SOURCE += $(NESSOURCE)/common
SOURCE += $(MODULE_BASE)/mcsave/ee
SOURCE += $(MODULE_BASE)/sjpcm/ee
SOURCE += $(MODULE_BASE)/netplay/Source/ps2/common
SOURCE += $(MODULE_BASE)/netplay/Source/ps2/ee
SOURCE += $(MODULE_BASE)/libcdvd/ee
SOURCE += ../../Data/icon

#
# Include paths
# 

INCLUDE = 
INCLUDE+= -I$(GEPDIR)/Include/common
INCLUDE+= -I$(GEPDIR)/Include/ps2
INCLUDE+= -I$(GEPDIR)/Source/common/zlib
INCLUDE+= -I$(GEPDIR)/Source/common/unzip
INCLUDE+= -I$(SNESSOURCE)/ps2
INCLUDE+= -I$(SNESSOURCE)/common
INCLUDE+= -I$(NESSOURCE)/ps2
INCLUDE+= -I$(NESSOURCE)/ps2/n6502
INCLUDE+= -I$(NESSOURCE)/common/ncpu
INCLUDE+= -I$(NESSOURCE)/common
INCLUDE+= -I$(MODULE_BASE)/mcsave/ee
INCLUDE+= -I$(MODULE_BASE)/sjpcm/ee
INCLUDE+= -I$(MODULE_BASE)/netplay/Source/common
INCLUDE+= -I$(MODULE_BASE)/netplay/Source/ps2/common
INCLUDE+= -I$(MODULE_BASE)/netplay/Source/ps2/ee
INCLUDE+= -I$(MODULE_BASE)/libcdvd/common
INCLUDE+= -I$(MODULE_BASE)/libcdvd/ee
INCLUDE+= -I$(BUILD_DIR)

#
# Object files
# 

DATAOBJS = memcard_icon.inc # romdisk.o

OBJS = 
OBJS +=	crt0.o
OBJS +=	main.o
OBJS +=	excepHandler.o
OBJS +=	exceptions.o
#OBJS +=	stdio.o 
OBJS +=	array.o
OBJS +=	file.o
OBJS +=	surface.o
OBJS +=	rendersurface.o
OBJS +=	pixelformat.o
OBJS +=	memspace.o 
OBJS +=	inputdevice.o 
OBJS +=	console.o 
#OBJS +=	linebuffer.o 
#OBJS +=	msgnode.o
OBJS +=	bmpfile.o
OBJS +=	mixbuffer.o
OBJS +=	wavfile.o
OBJS +=	dataio.o
OBJS +=	pathext.o
# OBJS += font.o
# OBJS += poly.o
# OBJS += texture.o

OBJS +=	adler32.o 
OBJS +=	compress.o 
OBJS +=	crc32.o 
OBJS +=	deflate.o 
OBJS +=	gzio.o 
OBJS +=	infblock.o 
OBJS +=	infcodes.o 
OBJS +=	inffast.o 
OBJS +=	inflate.o 
OBJS +=	inftrees.o 
OBJS +=	infutil.o 
OBJS +=	trees.o 
OBJS +=	uncompr.o 
OBJS +=	zutil.o 

OBJS +=	explode.o 
OBJS +=	unreduce.o 
OBJS +=	unshrink.o 
OBJS +=	unzip.o 


OBJS +=	prof.o
OBJS +=	proflog.o
OBJS +=	profctr.o

OBJS +=	poly.o 

OBJS +=	cd.o 
OBJS +=	gs.o 
#OBJS +=	pad.o 
OBJS +=	hw.o 
OBJS +=	gpfifo.o 
OBJS +=	libxpad.o 
OBJS +=	libxmtap.o 
OBJS +=	sjpcm_rpc.o 
OBJS +=	cdvd_rpc.o 
OBJS +=	ps2dma.o 
OBJS +=	mcsave_ee.o 
OBJS +=	sjpcmbuffer.o
OBJS +=	gslist.o
OBJS +=	gpprim.o
OBJS += vram.o
OBJS +=	titleman.o 



OBJS +=	netplay_ee.o 

OBJS +=	font.o 
OBJS +=	texture.o 
OBJS +=	font_04b16b.o 


OBJS +=	input.o 
OBJS +=	version.o 
OBJS +=	mainloop.o
OBJS +=	uiBrowser.o
OBJS +=	uiNetwork.o
OBJS +=	uiMenu.o
OBJS +=	uiLog.o
OBJS +=	memcard.o

OBJS +=	emurom.o 
OBJS +=	emusys.o 
OBJS +=	emumovie.o
#OBJS +=	emushell.o 

#
# SNES objects
#

OBJS +=	snstate.o 

OBJS +=	sncpu_c.o 
OBJS +=	snrom.o 
OBJS +=	sndisasm.o 
OBJS +=	snspcdisasm.o 
OBJS +=	sncpu.o 

OBJS +=	snio.o 
OBJS +=	sndma.o 
OBJS +=	snppu.o 
OBJS +=	snes.o 
OBJS +=	snesreg.o 
OBJS +=	sn65816.o 
OBJS +=	snmemmap.o 

#OBJS +=	snppublend_c.o 
#OBJS +=	snppublend_mm.o 
OBJS +=	snppucolor.o 
OBJS +=	snppublend_gs.o 

OBJS +=	snppurender.o 
OBJS +=	snppurender8.o 
# OBJS +=	snppurender8p.o 
OBJS +=	snppubg.o 
OBJS +=	snppuobj.o 

OBJS +=	snspctimer.o 
OBJS +=	snspcio.o 
OBJS +=	snspc_c.o 
OBJS +=	snspcdsp.o 
OBJS +=	snspcmix.o 
OBJS +=	snspcbrr.o 
OBJS +=	snspc.o 
#OBJS +=	snspc700.o 

OBJS +=	snmask128.o 
OBJS +=	snspcrom.o 

#
# NES objects
#

OBJS +=	nesdisk.o 
OBJS +=	nesio.o 
OBJS +=	nesmmu.o 
OBJS +=	n6502.o 
OBJS +=	ncpu_c.o 
OBJS +=	ndisasm.o 
OBJS +=	nescpu.o 
OBJS +=	nesppu.o 
OBJS +=	nesppurender.o 
OBJS +=	nespal.o 
OBJS +=	nesrom.o 
OBJS +=	nesspu.o 
OBJS +=	nesspumix.o 
OBJS +=	nesstate.o 
OBJS +=	nes.o 


#
# Compiler configuration
#

ifeq ($(BUILD), debug)
	EE_BUILDDEFINES = -DCODE_PROFILE=0 -DCODE_DEBUG=1 -DCODE_RELEASE=0
else    
ifeq ($(BUILD), final)
	EE_BUILDDEFINES = -DCODE_PROFILE=0 -DCODE_DEBUG=0 -DCODE_RELEASE=0
else    
ifeq ($(BUILD), release)
	EE_BUILDDEFINES = -DCODE_PROFILE=0 -DCODE_DEBUG=0 -DCODE_RELEASE=1
else    
ifeq ($(BUILD), profile)
	EE_BUILDDEFINES = -DCODE_PROFILE=1 -DCODE_DEBUG=0 -DCODE_RELEASE=0
endif    
endif    
endif    
endif    

EE_DEFINES  = $(EE_BUILDDEFINES) -DPS2_EE -D_EE -DLSB_FIRST -DALIGN_DWORD -DCODE_PLATFORM=3

EE_AFLAGS   = -EL -ahlsm 
EE_CFLAGS   = -G0 -O2 -EL -pipe -Wall -Werror -Wa,-al -fomit-frame-pointer -fstrict-aliasing -fno-common -ffreestanding -fno-builtin -fshort-double -mlong64 -mhard-float -mno-abicalls
EE_CPPFLAGS = -fno-exceptions -fno-common -fno-rtti
EE_LDFLAGS  = -nostartfiles -T$(LINKFILE) -Wl,-Map,SNESticle.map 
EE_LIBDIRS  = -L$(EE_BASE)/ee/lib -L$(PS2LIB_BASE)/ee/lib -L$(PS2IP_BASE)/ee/lib -L. 
EE_INCS     = $(PS2LIB_EE_INCS) $(PS2IP_EE_INCS)


ifeq ($(EE_GCC_VERSION), 3.2.2-b1)
EE_AFLAGS   += -march=r5900 -mtune=r5900
EE_CFLAGS   += -march=r5900	-mtune=r5900
else
EE_AFLAGS   += -mcpu=r5900 
EE_CFLAGS   += -mcpu=r5900  -mips3
endif


#

vpath %.d ./$(BUILD_DIR)
vpath %.o ./$(BUILD_DIR)
vpath %.inc ./$(BUILD_DIR)
vpath % $(SOURCE)

#all: relink $(TARGET)
all: $(TARGET)

outdir:
	@mkdir -p $(BUILD_DIR) 

cdelf: 
	make build=release
	cp $(TARGET) $(CDDATAPATH)/$(CDELFNAME)
	cp $(INSTALLFILES) $(CDDATAPATH)
	cp -R $(PKSHPATH) $(CDDATAPATH)

cdiso:
	mkisofs  -J -o $(ISOPATH) $(CDDATAPATH)
	ps2bootgen -cd -japan $(ISOPATH)

dvdiso:
	mkisofs  -J -o $(ISOPATH) $(CDDATAPATH)
	ps2bootgen -dvd -japan $(ISOPATH)	

dvdlicense:
	ps2bootgen -dvd -japan $(ISOPATH)	

cdlicense:
	ps2bootgen -cd -japan $(ISOPATH)

clean_target:
	@rm -f $(TARGET)
	@rm -f $(BUILD_DIR)/$(TARGET)

relink: clean_target $(TARGET)


#
# modules
#

modules: netplay sjpcm mcsave cdvd

netplay:
	make -C $(MODULE_BASE)/netplay/project/ps2
	cp $(MODULE_BASE)/netplay/project/ps2/netplay.irx .
	cp /usr/ps2dev/ps2ip/iop/bin/ps2ip.irx .
	cp /usr/ps2dev/ps2eth/bin/ps2smap.irx .
	cp /usr/ps2dev/ps2ip/iop/bin/ps2ips.irx .

clean_netplay:
	make clean -C $(MODULE_BASE)/netplay/project/ps2

sjpcm:
	make -C $(MODULE_BASE)/sjpcm/iop
	cp $(MODULE_BASE)/sjpcm/iop/sjpcm2.irx .

clean_sjpcm:
	make clean -C $(MODULE_BASE)/sjpcm/iop


mcsave:
	make -C $(MODULE_BASE)/mcsave/iop
	cp $(MODULE_BASE)/mcsave/iop/mcsave.irx .

clean_mcsave:
	make clean -C $(MODULE_BASE)/mcsave/iop

eeputs:
	make -C $(MODULE_BASE)/eeputs/iop
	cp $(MODULE_BASE)/eeputs/iop/eeputs.irx .

clean_eeputs:
	make clean -C $(MODULE_BASE)/eeputs/iop

clean_cdvd:
	make clean -C $(MODULE_BASE)/libcdvd/iop

cdvd:
	make -C $(MODULE_BASE)/libcdvd/iop
	cp $(MODULE_BASE)/libcdvd/lib/cdvd.irx .

ps2fs:
	make -C /usr/ps2dev/ps2fs/iop
	cp /usr/ps2dev/ps2fs/iop/ps2fs.irx .

ps2lib:
	make -C $(PS2LIB_BASE)/ee
		  

#
# Build rules
#

%.o: %.c
	@echo Compiling $<...
	@$(EE_CC) $(EE_CFLAGS) $(EE_DEFINES) $(EE_INCS) $(INCLUDE) -c $< -o $(BUILD_DIR)/$@ > $(BUILD_DIR)/$*.lst

%.o: %.cc
	@echo Compiling $<...
	@$(EE_CCPLUS) $(EE_CFLAGS) $(EE_DEFINES) $(EE_CPPFLAGS) $(EE_INCS) $(INCLUDE) -c $< -o $(BUILD_DIR)/$@ > $(BUILD_DIR)/$*.lst

%.o: %.cpp
	@echo Compiling $<...
	@$(EE_CCPLUS) $(EE_CFLAGS) $(EE_DEFINES) $(EE_CPPFLAGS) $(EE_INCS) $(INCLUDE) -c $< -o $(BUILD_DIR)/$@ > $(BUILD_DIR)/$*.lst

%.s: %.cpp
	@echo Compiling to assembly $<...
	@$(EE_CCPLUS) $(EE_CFLAGS) $(EE_DEFINES) $(EE_CPPFLAGS) $(EE_INCS) $(INCLUDE) -S $< -o $(BUILD_DIR)/$*.s

%.o: %.S
	@echo Assembling w/ preprocessor $<...
	@cpp  $< > $(BUILD_DIR)/$*.sp
	@$(EE_AS) $(EE_AFLAGS) $(BUILD_DIR)/$*.sp -o $(BUILD_DIR)/$@ > $(BUILD_DIR)/$*.lst

%.o: %.s
	@echo Assembling $<...
	@$(EE_AS) $(EE_AFLAGS) $< -o $(BUILD_DIR)/$@ > $(BUILD_DIR)/$*.lst

%.o: %.dsm
	@echo DVP Assembling $<...
	@$(EE_DVP_AS) $(INCLUDE) $< -o $(BUILD_DIR)/$@ > $(BUILD_DIR)/$*.lst

%.inc: %.icn
	@echo Converting icon $<...
	$(BIN2C) $< $(BUILD_DIR)/$@
	echo >> $(BUILD_DIR)/$@

clean:
	@echo Cleaning $(BUILD_DIR)
	rm -f $(BUILD_DIR)/*.d 
	rm -f $(BUILD_DIR)/*.o 
	rm -f $(BUILD_DIR)/*.inc
	rm -f $(BUILD_DIR)/*.s
	rm -f $(BUILD_DIR)/*.elf


$(BUILD_DIR)/%.d: %.s 
	@echo Building dependencies $<...
	@touch $@

$(BUILD_DIR)/%.d: %.S
	@echo Building dependencies $<...
	@touch $@

$(BUILD_DIR)/%.d: %.dsm
	@echo Building dependencies $<...
	@touch $@

$(BUILD_DIR)/%.d: %.c
	@mkdir -p $(BUILD_DIR) 
	@echo Building dependencies $<...
	@set -e; \
	$(EE_CC) $(EE_CFLAGS) $(EE_DEFINES) $(EE_INCS) $(INCLUDE) -MM $< \
	| sed 's/\($*\)\.o[ :]*/\1.o $*.d : /g' > $@ ; \
	[ -s $@ ] || rm -f $@

$(BUILD_DIR)/%.d: %.cpp 
	@mkdir -p $(BUILD_DIR) 
	@echo Building dependencies $< $@...
	@set -e; \
	$(EE_CCPLUS) $(EE_CFLAGS) $(EE_DEFINES) $(EE_CPPFLAGS) $(EE_INCS) $(INCLUDE) -MM $< \
	| sed 's/\($*\)\.o[ :]*/\1.o $*.d : /g' > $@ ; \
	[ -s $@ ] || rm -f $@

$(TARGET): outdir $(DATAOBJS) $(OBJS) 
	@echo EE-GCC $(EE_GCC_VERSION) $(EE_BASE)
	@echo Linking $@...
	@cd $(BUILD_DIR) ; \
	$(EE_CC) $(EE_LDFLAGS) $(EE_LIBDIRS) -o temp.elf $(OBJS) $(LIBDIRS) $(LIBS) 
	@$(EE_STRIP) -F elf32-littlemips $(BUILD_DIR)/temp.elf -o $(BUILD_DIR)/$(TARGET) 
	@cp $(BUILD_DIR)/$(TARGET) .
	@rm $(BUILD_DIR)/temp.elf

run: relink $(TARGET)
	$(EE_LOADER) $(BUILD_DIR)/$(TARGET)


#
# dependencies
#
include $(OBJS:%.o=$(BUILD_DIR)/%.d)
