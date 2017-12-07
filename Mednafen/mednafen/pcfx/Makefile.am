AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@ 
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES	=	libpcfx.a
libpcfx_a_SOURCES 	= 	king.cpp soundbox.cpp pcfx.cpp interrupt.cpp input.cpp timer.cpp rainbow.cpp jrevdct.cpp huc6273.cpp fxscsi.cpp

libpcfx_a_SOURCES	+=	input/gamepad.cpp input/mouse.cpp

if WANT_DEBUGGER
libpcfx_a_SOURCES	+=	debug.cpp
endif
