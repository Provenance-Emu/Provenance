AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(localedir)\" @DEFS@
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_builddir)/intl

noinst_LIBRARIES	=	libmdfnxxx.a libmdfnxxx_extra.a
libmdfnxxx_a_SOURCES    =	main.cpp
libmdfnxxx_extra_a_SOURCES =	interface.cpp CDInterface_EXT.cpp
