AM_CFLAGS = @AM_CFLAGS@ @SNES_EXTRA_FLAGS@
AM_CXXFLAGS = @AM_CXXFLAGS@ @SNES_EXTRA_FLAGS@ @SNES_EXTRA_CXXFLAGS@
AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@  -DNOMINMAX
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl -I$(srcdir)/src/lib

noinst_LIBRARIES	=	libsnes.a

meow			=	interface.cpp


meow	+=	src/lib/libco/libco.c

#################
### utilities ###
#################

meow	+=	src/cartridge/cartridge.cpp src/cheat/cheat.cpp

##############
### memory ###
##############

meow	+=	src/memory/memory.cpp src/memory/smemory/smemory.cpp

###########
### cpu ###
###########

meow	+=	src/cpu/cpu.cpp src/cpu/core/core.cpp src/cpu/scpu/scpu.cpp

###########
### smp ###
###########

meow	+=	src/smp/smp.cpp

###########
### dsp ###
###########

meow	+=	src/sdsp/sdsp.cpp

###########
### ppu ###
###########

meow	+=	src/ppu/ppu.cpp

##############
### system ###
##############

meow	+=	src/system/system.cpp

#####################
### special chips ###
#####################

meow	+=	src/chip/sa1/sa1.cpp src/chip/bsx/bsx.cpp src/chip/srtc/srtc.cpp src/chip/sdd1/sdd1.cpp
meow	+=	src/chip/spc7110/spc7110.cpp src/chip/cx4/cx4.cpp

meow	+=	src/chip/dsp1/dsp1.cpp src/chip/dsp2/dsp2.cpp src/chip/dsp3/dsp3.cpp src/chip/dsp4/dsp4.cpp

meow	+=	src/chip/obc1/obc1.cpp

meow	+=	src/chip/st010/st010.cpp

meow	+=	src/chip/superfx/superfx.cpp

libsnes_a_SOURCES	=	$(meow)

