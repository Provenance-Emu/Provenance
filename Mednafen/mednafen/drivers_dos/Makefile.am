AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@  @SDL_CFLAGS@
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES	=	libmdfndos.a

libmdfndos_a_SOURCES = main.cpp sound.cpp ers.cpp args.cpp
# input.cpp input-config.cpp
#libmdfndos_a_SOURCES += fps.cpp video-state.cpp

libmdfndos_a_SOURCES += video.cpp

libmdfndos_a_SOURCES += nongl.cpp nnx.cpp

libmdfndos_a_SOURCES += Joystick.cpp
#Joystick_DOS_Standard.cpp
