noinst_LIBRARIES	+=	libsnes.a
libsnes_a_CFLAGS 	=	@AM_CFLAGS@ @SNES_EXTRA_FLAGS@
libsnes_a_CXXFLAGS 	=	@AM_CXXFLAGS@ @SNES_EXTRA_FLAGS@ @SNES_EXTRA_CXXFLAGS@
libsnes_a_CPPFLAGS	=	-DNOMINMAX -I$(srcdir)/snes/src/lib
# @AM_CPPFLAGS@


libsnes_a_SOURCES	=	snes/interface.cpp

libsnes_a_SOURCES	+=	snes/src/lib/libco/libco.c

#################
### utilities ###
#################

libsnes_a_SOURCES	+=	snes/src/cartridge/cartridge.cpp snes/src/cheat/cheat.cpp

##############
### memory ###
##############

libsnes_a_SOURCES	+=	snes/src/memory/memory.cpp snes/src/memory/smemory/smemory.cpp

###########
### cpu ###
###########

libsnes_a_SOURCES	+=	snes/src/cpu/cpu.cpp snes/src/cpu/core/core.cpp snes/src/cpu/scpu/scpu.cpp

###########
### smp ###
###########

libsnes_a_SOURCES	+=	snes/src/smp/smp.cpp

###########
### dsp ###
###########

libsnes_a_SOURCES	+=	snes/src/sdsp/sdsp.cpp

###########
### ppu ###
###########

libsnes_a_SOURCES	+=	snes/src/ppu/ppu.cpp

##############
### system ###
##############

libsnes_a_SOURCES	+=	snes/src/system/system.cpp

#####################
### special chips ###
#####################

libsnes_a_SOURCES	+=	snes/src/chip/sa1/sa1.cpp snes/src/chip/bsx/bsx.cpp snes/src/chip/srtc/srtc.cpp snes/src/chip/sdd1/sdd1.cpp
libsnes_a_SOURCES	+=	snes/src/chip/spc7110/spc7110.cpp snes/src/chip/cx4/cx4.cpp

libsnes_a_SOURCES	+=	snes/src/chip/dsp1/dsp1.cpp snes/src/chip/dsp2/dsp2.cpp snes/src/chip/dsp3/dsp3.cpp snes/src/chip/dsp4/dsp4.cpp

libsnes_a_SOURCES	+=	snes/src/chip/obc1/obc1.cpp

libsnes_a_SOURCES	+=	snes/src/chip/st010/st010.cpp

libsnes_a_SOURCES	+=	snes/src/chip/superfx/superfx.cpp

mednafen_LDADD          +=      libsnes.a
mednafen_DEPENDENCIES   +=      libsnes.a

