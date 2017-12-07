AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@  @MMX_CFLAGS@ @SSE_CFLAGS@ @SSE2_CFLAGS@ -funroll-loops
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES	=	libsnes_faust.a
libsnes_faust_a_SOURCES	= 	cpu.cpp snes.cpp apu.cpp cart.cpp input.cpp ppu.cpp

#if WANT_DEBUGGER
#libsnes_faust_a_SOURCES+=	debug.cpp
#endif
