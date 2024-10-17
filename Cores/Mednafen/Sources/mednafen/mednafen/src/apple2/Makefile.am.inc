mednafen_SOURCES	+=	apple2/apple2.cpp apple2/disk2.cpp apple2/video.cpp apple2/sound.cpp apple2/kbio.cpp apple2/gameio.cpp apple2/hdd.cpp

#if WANT_DEBUGGER
#mednafen_SOURCES	+=	apple2/debug.cpp
#mednafen_SOURCES	+=	apple2/dis6502.cpp
#endif
