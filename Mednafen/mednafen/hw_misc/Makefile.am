AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@ 
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES        =       libmdfnhwmisc.a

libmdfnhwmisc_a_SOURCES		=

if NEED_ARCADE_CARD_EMU
libmdfnhwmisc_a_SOURCES		+= arcade_card/arcade_card.cpp
endif
