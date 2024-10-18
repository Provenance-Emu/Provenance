AUTOMAKE_OPTIONS = subdir-objects
DEFS = @DEFS@ @SDL_CFLAGS@ @ALSA_CFLAGS@ @JACK_CFLAGS@
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_builddir)/intl

noinst_LIBRARIES        =       libsexyal.a

libsexyal_a_SOURCES	=      sexyal.cpp convert.cpp drivers/dummy.cpp

if HAVE_DIRECTSOUND
TMP_DIRECTSOUND	=	drivers/dsound.cpp
endif

if HAVE_WASAPI
TMP_WASAPI	=	drivers/wasapi.cpp drivers/wasapish.cpp
endif

if HAVE_OSSDSP
TMP_OSSDSP	=	drivers/oss.cpp
endif

if HAVE_OPENBSD_AUDIO
TMP_OPENBSD	=	drivers/openbsd.cpp
endif

if HAVE_JACK
TMP_JACK	=	drivers/jack.cpp
endif

if HAVE_SDL
TMP_SDL		=	drivers/sdl.cpp
libsexyal_a_CFLAGS = @SDL_CFLAGS@
endif

if HAVE_ALSA
TMP_ALSA	=	drivers/alsa.cpp
endif

if DOS
TMP_DOS		=	drivers/dos_common.cpp drivers/cmi8738.cpp drivers/es1370.cpp drivers/es1371.cpp drivers/sb.cpp
endif

libsexyal_a_SOURCES	+=	$(TMP_DIRECTSOUND) $(TMP_WASAPI) $(TMP_OSSDSP) $(TMP_OPENBSD) $(TMP_JACK) $(TMP_SDL) $(TMP_ALSA) $(TMP_DOS)
