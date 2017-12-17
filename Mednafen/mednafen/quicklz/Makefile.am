AM_CFLAGS = @AM_CFLAGS@ -fno-strict-aliasing -Wno-shadow -Wno-unused-but-set-variable
AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@ -fno-strict-aliasing
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES	=	libmdfnquicklz.a

libmdfnquicklz_a_SOURCES  =	quicklz.c
