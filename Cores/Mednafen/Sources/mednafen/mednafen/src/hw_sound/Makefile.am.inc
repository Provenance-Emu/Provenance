if NEED_YM2413_EMU
mednafen_SOURCES	+=	hw_sound/ym2413/emu2413.cpp
endif

if NEED_YM2612_EMU
mednafen_SOURCES	+=	hw_sound/ym2612/Ym2612_Emu.cpp
endif

if NEED_GB_APU_EMU
mednafen_SOURCES	+=	hw_sound/gb_apu/Gb_Apu.cpp hw_sound/gb_apu/Gb_Apu_State.cpp hw_sound/gb_apu/Gb_Oscs.cpp
endif

if NEED_SMS_APU_EMU
mednafen_SOURCES	+=	hw_sound/sms_apu/Sms_Apu.cpp
endif

if NEED_PCE_PSG_EMU
mednafen_SOURCES	+=	hw_sound/pce_psg/pce_psg.cpp
endif

