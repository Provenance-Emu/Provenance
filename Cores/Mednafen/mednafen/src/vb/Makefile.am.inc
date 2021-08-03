mednafen_SOURCES 	+= 	vb/vb.cpp vb/timer.cpp vb/input.cpp vb/vip.cpp vb/vsu.cpp

if WANT_DEBUGGER
mednafen_SOURCES	+=	vb/debug.cpp
endif
