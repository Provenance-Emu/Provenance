noinst_LIBRARIES	+=	libngp.a
libngp_a_CFLAGS		=	@AM_CFLAGS@ @NO_STRICT_ALIASING_FLAGS@
libngp_a_CXXFLAGS	=	@AM_CXXFLAGS@ @NO_STRICT_ALIASING_FLAGS@
libngp_a_SOURCES 	=	ngp/bios.cpp ngp/biosHLE.cpp ngp/dma.cpp ngp/flash.cpp ngp/gfx.cpp ngp/T6W28_Apu.cpp	\
	ngp/gfx_scanline_mono.cpp ngp/gfx_scanline_colour.cpp ngp/interrupt.cpp ngp/mem.cpp ngp/neopop.cpp \
	ngp/rom.cpp ngp/rtc.cpp ngp/sound.cpp ngp/Z80_interface.cpp \
	ngp/TLCS-900h/TLCS900h_disassemble_extra.cpp ngp/TLCS-900h/TLCS900h_disassemble_reg.cpp \
	ngp/TLCS-900h/TLCS900h_interpret_single.cpp ngp/TLCS-900h/TLCS900h_disassemble_src.cpp \
	ngp/TLCS-900h/TLCS900h_interpret.cpp ngp/TLCS-900h/TLCS900h_registers.cpp ngp/TLCS-900h/TLCS900h_interpret_reg.cpp \
	ngp/TLCS-900h/TLCS900h_disassemble.cpp ngp/TLCS-900h/TLCS900h_interpret_src.cpp \
	ngp/TLCS-900h/TLCS900h_interpret_dst.cpp ngp/TLCS-900h/TLCS900h_disassemble_dst.cpp

mednafen_LDADD          +=      libngp.a
mednafen_DEPENDENCIES   +=      libngp.a

