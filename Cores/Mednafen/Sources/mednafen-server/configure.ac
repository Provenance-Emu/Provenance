AC_INIT([src/mednafen-server.cpp])
AC_GNU_SOURCE
AC_USE_SYSTEM_EXTENSIONS

MEDNAFEN_SERVER_VERSION='0.5.2'

AC_CANONICAL_HOST
AC_CANONICAL_TARGET
AM_INIT_AUTOMAKE([mednafen_server], $MEDNAFEN_SERVER_VERSION)
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES])
AM_CONFIG_HEADER([include/config.h:include/config.h.in])

AC_PROG_CC
AC_PROG_CPP
AM_PROG_CC_C_O
AC_PROG_CXX
AC_PROG_CXXCPP
AC_LANG_CPLUSPLUS
AC_PROG_INSTALL

AC_CHECK_FUNCS(gettimeofday nanosleep usleep mlockall strerror_r)


#
# Check for any libraries that need to be linked against for clock_gettime().
#
# (posix4 is apparently used by much older versions of Solaris according to tar, pre-7, so maybe it's not necessary
#  for Mednafen?)
AC_SEARCH_LIBS(clock_gettime, [rt posix4])
AC_CHECK_FUNCS(clock_gettime)

WARNING_FLAGS=""
AX_CFLAGS_GCC_OPTION([-Wall], WARNING_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wextra], WARNING_FLAGS)
AX_CFLAGS_GCC_OPTION([-Winline], WARNING_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wshadow], WARNING_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wvla], WARNING_FLAGS)

MDFN_COMPAT_FLAGS=""
AX_CFLAGS_GCC_OPTION([-fsigned-char], MDFN_COMPAT_FLAGS)

CFLAGS="$MDFN_COMPAT_FLAGS $WARNING_FLAGS $CFLAGS"
CPPFLAGS="$MDFN_COMPAT_FLAGS $WARNING_FLAGS $CPPFLAGS"

AC_OUTPUT([Makefile src/Makefile])
