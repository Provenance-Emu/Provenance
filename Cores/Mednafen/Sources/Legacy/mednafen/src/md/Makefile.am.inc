mednafen_SOURCES	+=	md/vdp.cpp md/genesis.cpp md/genio.cpp md/header.cpp md/mem68k.cpp md/membnk.cpp md/memvdp.cpp md/memz80.cpp md/sound.cpp md/system.cpp

mednafen_SOURCES 	+= 	md/cart/cart.cpp md/cart/map_eeprom.cpp md/cart/map_realtec.cpp md/cart/map_ssf2.cpp md/cart/map_ff.cpp md/cart/map_rom.cpp md/cart/map_sbb.cpp md/cart/map_yase.cpp md/cart/map_rmx3.cpp md/cart/map_sram.cpp md/cart/map_svp.cpp
# md/cart/ssp16.c

mednafen_SOURCES	+=	md/input/multitap.cpp md/input/4way.cpp md/input/megamouse.cpp md/input/gamepad.cpp

mednafen_SOURCES	+=	md/cd/cd.cpp md/cd/timer.cpp md/cd/interrupt.cpp md/cd/pcm.cpp md/cd/cdc_cdd.cpp

if WANT_DEBUGGER
mednafen_SOURCES	+=	md/debug.cpp
endif
