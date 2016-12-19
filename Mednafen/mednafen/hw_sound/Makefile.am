AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@ 
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES        =       libmdfnhwsound.a

libmdfnhwsound_a_SOURCES	=

if NEED_YM2413_EMU
libmdfnhwsound_a_SOURCES	+=       ym2413/emu2413.cpp
endif

if NEED_YM2612_EMU
libmdfnhwsound_a_SOURCES	+=       ym2612/Ym2612_Emu.cpp
endif

if NEED_GB_APU_EMU
libmdfnhwsound_a_SOURCES	+=       gb_apu/Gb_Apu.cpp gb_apu/Gb_Apu_State.cpp gb_apu/Gb_Oscs.cpp
endif

if NEED_SMS_APU_EMU
libmdfnhwsound_a_SOURCES	+=       sms_apu/Sms_Apu.cpp
endif

if NEED_PCE_PSG_EMU
libmdfnhwsound_a_SOURCES	+=	pce_psg/pce_psg.cpp
endif

