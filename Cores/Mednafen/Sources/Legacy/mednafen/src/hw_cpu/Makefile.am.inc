if NEED_68K_EMU
mednafen_SOURCES	+=	hw_cpu/m68k/m68k.cpp
endif

if NEED_Z80_EMU
mednafen_SOURCES	+=      hw_cpu/z80-fuse/z80.cpp hw_cpu/z80-fuse/z80_ops.cpp
endif

if NEED_V810_EMU
mednafen_SOURCES	+=	hw_cpu/v810/v810_cpu.cpp hw_cpu/v810/v810_cpuD.cpp hw_cpu/v810/v810_fp_ops.cpp
endif

