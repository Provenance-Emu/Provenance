AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@ 
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES        =       libmdfnhwvideo.a

libmdfnhwvideo_a_SOURCES	=

if NEED_HUC6270_EMU
libmdfnhwvideo_a_SOURCES	+= huc6270/vdc.cpp
endif

