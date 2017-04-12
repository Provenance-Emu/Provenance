AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@ 
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES	=	libmd.a

libmd_a_SOURCES         =	vdp.cpp genesis.cpp genio.cpp header.cpp mem68k.cpp membnk.cpp memvdp.cpp memz80.cpp sound.cpp system.cpp

libmd_a_SOURCES 	+= 	cart/cart.cpp cart/map_eeprom.cpp cart/map_realtec.cpp cart/map_ssf2.cpp cart/map_ff.cpp cart/map_rom.cpp cart/map_sbb.cpp cart/map_yase.cpp cart/map_rmx3.cpp cart/map_sram.cpp cart/map_svp.cpp
# cart/ssp16.c

libmd_a_SOURCES		+=	input/multitap.cpp input/4way.cpp input/megamouse.cpp input/gamepad.cpp

libmd_a_SOURCES		+=	cd/cd.cpp cd/timer.cpp cd/interrupt.cpp cd/pcm.cpp cd/cdc_cdd.cpp

if WANT_DEBUGGER
libmd_a_SOURCES		+=	debug.cpp
endif
