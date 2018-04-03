mednafen_SOURCES 	+= 	pcfx/king.cpp pcfx/soundbox.cpp pcfx/pcfx.cpp pcfx/interrupt.cpp pcfx/input.cpp pcfx/timer.cpp pcfx/rainbow.cpp pcfx/jrevdct.cpp pcfx/huc6273.cpp pcfx/fxscsi.cpp
mednafen_SOURCES	+=	pcfx/input/gamepad.cpp pcfx/input/mouse.cpp

if WANT_DEBUGGER
mednafen_SOURCES	+=	pcfx/debug.cpp
endif
