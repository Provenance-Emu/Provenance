mednafen_SOURCES	+= 	psx/psx.cpp psx/cpu.cpp psx/gte.cpp psx/irq.cpp psx/timer.cpp psx/dma.cpp psx/mdec.cpp psx/sio.cpp psx/cdc.cpp psx/spu.cpp psx/frontio.cpp
mednafen_SOURCES	+=	psx/input/gamepad.cpp psx/input/dualanalog.cpp psx/input/dualshock.cpp psx/input/memcard.cpp psx/input/multitap.cpp psx/input/mouse.cpp psx/input/negcon.cpp psx/input/guncon.cpp psx/input/justifier.cpp
mednafen_SOURCES	+=	psx/gpu.cpp psx/gpu_polygon.cpp psx/gpu_line.cpp psx/gpu_sprite.cpp

if WANT_DEBUGGER
mednafen_SOURCES	+=	psx/debug.cpp psx/dis.cpp
endif

