AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(localedir)\" @DEFS@  @SDL_CFLAGS@
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_builddir)/intl

noinst_LIBRARIES	=	libmdfnsdl.a

libmdfnsdl_a_SOURCES = main.cpp args.cpp help.cpp ers.cpp sound.cpp netplay.cpp

if WIN32
libmdfnsdl_a_SOURCES += thread_win32.cpp
else
libmdfnsdl_a_SOURCES += thread_sdl.cpp
endif

libmdfnsdl_a_SOURCES += input.cpp mouse.cpp keyboard.cpp
libmdfnsdl_a_SOURCES += Joystick.cpp Joystick_SDL.cpp

if HAVE_LINUX_JOYSTICK
libmdfnsdl_a_SOURCES += Joystick_Linux.cpp
endif

if WIN32
libmdfnsdl_a_SOURCES += Joystick_XInput.cpp
libmdfnsdl_a_SOURCES += Joystick_DX5.cpp
endif

libmdfnsdl_a_SOURCES += console.cpp cheat.cpp fps.cpp video-state.cpp remote.cpp rmdui.cpp

libmdfnsdl_a_SOURCES += opengl.cpp shader.cpp nongl.cpp nnx.cpp video.cpp

if WANT_FANCY_SCALERS
libmdfnsdl_a_SOURCES += hqxx-common.cpp hq2x.cpp hq3x.cpp hq4x.cpp scale2x.c scale3x.c scalebit.c 2xSaI.cpp
endif

if WANT_DEBUGGER
libmdfnsdl_a_SOURCES += debugger.cpp gfxdebugger.cpp memdebugger.cpp logdebugger.cpp prompt.cpp
endif
