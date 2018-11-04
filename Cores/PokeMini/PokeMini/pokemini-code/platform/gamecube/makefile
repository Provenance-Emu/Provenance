#---------------------------------------------------------------------------------
# Clear the implicit built in rules
#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------
ifeq ($(strip $(DEVKITPPC)),)
$(error "Please set DEVKITPPC in your environment. export DEVKITPPC=<path to>devkitPPC")
endif

include $(DEVKITPPC)/gamecube_rules

POKEROOT = ../../

#---------------------------------------------------------------------------------
# TARGET is the name of the output
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# INCLUDES is a list of directories containing extra header files
#---------------------------------------------------------------------------------
TARGET		:=	PokeMini
BUILD		:=	build
SOURCES		:=	$(POKEROOT)source $(POKEROOT)resource $(POKEROOT)freebios $(POKEROOT)sourcex $(POKEROOT)dependencies/zlib $(POKEROOT)dependencies/minizip .
DATA		:=	
INCLUDES	:=	$(POKEROOT)source $(POKEROOT)resource $(POKEROOT)freebios $(POKEROOT)sourcex $(POKEROOT)dependencies/zlib $(POKEROOT)dependencies/minizip
NITRODATA	:=	nitrofiles

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------

CFLAGS	= -g -O2 -Wall $(MACHDEP) $(INCLUDE)
CXXFLAGS	=	$(CFLAGS)

LDFLAGS	=	-g $(MACHDEP) -Wl,-Map,$(notdir $@).map

#---------------------------------------------------------------------------------
# any extra libraries we wish to link with the project
#---------------------------------------------------------------------------------
LIBS	:=	-lfat -lasnd -logc -lm
# -liso9660 

#---------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level containing
# include and lib
#---------------------------------------------------------------------------------
LIBDIRS	:=

#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------

export OUTPUT	:=	$(CURDIR)/$(TARGET)

export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
					$(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR	:=	$(CURDIR)/$(BUILD)

ifneq ($(strip $(NITRODATA)),)
	export NITRO_FILES	:=	$(CURDIR)/$(NITRODATA)
endif

# Only include what's really needed
CFILES := PokeMini_GC.c	\
 freebios/freebios.c	\
 source/PMCommon.c	\
 source/PokeMini.c	\
 source/Multicart.c	\
 source/Hardware.c	\
 source/Video.c	\
 source/Video_x1.c	\
 source/Video_x2.c	\
 source/Video_x3.c	\
 source/Video_x4.c	\
 source/Video_x5.c	\
 source/Video_x6.c	\
 source/CommandLine.c	\
 source/MinxCPU.c	\
 source/MinxCPU_XX.c	\
 source/MinxCPU_CE.c	\
 source/MinxCPU_CF.c	\
 source/MinxCPU_SP.c \
 source/MinxTimers.c	\
 source/MinxIO.c	\
 source/MinxIRQ.c	\
 source/MinxPRC.c	\
 source/MinxColorPRC.c	\
 source/MinxLCD.c	\
 source/MinxAudio.c	\
 source/UI.c	\
 source/Joystick.c	\
 dependencies/minizip/unzip.c	\
 dependencies/minizip/ioapi.c	\
 dependencies/zlib/adler32.o	\
 dependencies/zlib/crc32.o	\
 dependencies/zlib/inffast.o	\
 dependencies/zlib/inflate.o	\
 dependencies/zlib/inftrees.o	\
 dependencies/zlib/zutil.o	\
 sourcex/Zip64comp.c	\
 resource/PokeMini_ColorPal.c	\
 resource/PokeMini_Font12.c	\
 resource/PokeMini_Icons12.c	\
 resource/PokeMini_BG2.c	\
 resource/PokeMini_BG3.c	\
 resource/PokeMini_BG4.c	\
 resource/PokeMini_BG5.c	\
 resource/PokeMini_BG6.c

#---------------------------------------------------------------------------------
# automatically build a list of object files for our project
#---------------------------------------------------------------------------------
CFILES		:=	$(notdir $(CFILES))
# CFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
sFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
SFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.S)))
BINFILES	:=	$(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))

#---------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#---------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
	export LD	:=	$(CC)
else
	export LD	:=	$(CXX)
endif

export OFILES	:=	$(addsuffix .o,$(BINFILES)) \
					$(CPPFILES:.cpp=.o) $(CFILES:.c=.o) \
					$(sFILES:.s=.o) $(SFILES:.S=.o)

#---------------------------------------------------------------------------------
# build a list of include paths
#---------------------------------------------------------------------------------
export INCLUDE	:=	$(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
					$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
					-I$(CURDIR)/$(BUILD) \
					-I$(LIBOGC_INC)

#---------------------------------------------------------------------------------
# build a list of library paths
#---------------------------------------------------------------------------------
export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib) \
					-L$(LIBOGC_LIB)

export OUTPUT	:=	$(CURDIR)/$(TARGET)
.PHONY: $(BUILD) clean

#---------------------------------------------------------------------------------
$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

#---------------------------------------------------------------------------------
clean:
	@echo clean ...
	@rm -fr $(BUILD) $(OUTPUT).elf $(OUTPUT).dol

#---------------------------------------------------------------------------------
run:
	$(DEVKITPRO)/emulators/gcube/gcube $(OUTPUT).dol


#---------------------------------------------------------------------------------
else

DEPENDS	:=	$(OFILES:.o=.d)

#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------
$(OUTPUT).dol: $(OUTPUT).elf
$(OUTPUT).elf: $(OFILES)

-include $(DEPENDS)

#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------
