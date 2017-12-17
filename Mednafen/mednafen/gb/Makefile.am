AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@  
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES        =       libgb.a
gb_SOURCES     =	gb.cpp gfx.cpp gbGlobals.cpp memory.cpp sound.cpp z80.cpp

libgb_a_SOURCES        =       $(gb_SOURCES)
