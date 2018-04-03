AC_INIT([src/mednafen.cpp])
AC_GNU_SOURCE
AC_USE_SYSTEM_EXTENSIONS
AC_CONFIG_MACRO_DIR([m4])

#
# Avoid trailing and leading zeroes in the decimal version components to avoid confusing not-so-learned people.
#
MEDNAFEN_VERSION='1.21.1'
MEDNAFEN_VERSION_NUMERIC=0x00102101
#                        0xJJJnnnRR

AC_CANONICAL_HOST
AM_INIT_AUTOMAKE([mednafen], $MEDNAFEN_VERSION)
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES])
AC_CONFIG_HEADERS([include/config.h:include/config.h.in])

AC_PROG_CC
AC_PROG_CPP
AM_PROG_AS
AM_PROG_CC_C_O
AC_PROG_CXX
AC_PROG_CXXCPP
AC_LANG_CPLUSPLUS

CXX="$CXX -std=gnu++11"
CXXCPP="$CXXCPP -std=gnu++11"
CC="$CC -std=gnu99"
CPP="$CPP -std=gnu99"

AX_CFLAGS_GCC_OPTION([-fsigned-char], CC)
AX_CXXFLAGS_GCC_OPTION([-fsigned-char], CXX)

AC_PROG_INSTALL

gl_VISIBILITY

AC_SYS_LARGEFILE
AC_FUNC_FSEEKO
AC_DEFINE(_LARGEFILE64_SOURCE, [1], [Define for largefile support through extra functions.])
AC_DEFINE(_LARGEFILE_SOURCE, [1], [Define for fseeko and ftello on some hosts.])

AM_CONDITIONAL(CROSS_COMPILING, [test x$cross_compiling != xno])

# sizeof tests need to come after largefile support macros

AC_CHECK_TYPE(ptrdiff_t,long)
AC_TYPE_SIZE_T
AC_CHECK_SIZEOF(char)
AC_CHECK_SIZEOF(short)
AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(long)
AC_CHECK_SIZEOF(long long)
AC_CHECK_SIZEOF(double)
AC_CHECK_SIZEOF(__int64)
AC_CHECK_SIZEOF(void *)
AC_CHECK_SIZEOF(size_t)
AC_CHECK_SIZEOF(ptrdiff_t)
AC_CHECK_SIZEOF(off_t)
AC_C_CONST
AC_CHECK_FUNCS(memcmp memcpy memmove memset mmap munmap madvise signal sigaction fork pipe dup2 fcntl getenv putenv setenv gettimeofday getpwuid getuid strerror strerror_r ftello fopen64 fseeko64 ftello64 fstat64 ftruncate64 __mingw_get_crt_info)

AC_SEARCH_LIBS(fmodl, [m])

#
# Check for any libraries that need to be linked against for clock_gettime().
#
# (posix4 is apparently used by much older versions of Solaris according to tar, pre-7, so maybe it's not necessary
#  for Mednafen?)
AC_SEARCH_LIBS(clock_gettime, [rt posix4])
AC_CHECK_FUNCS(clock_gettime nanosleep usleep localtime_r gmtime_r)

AC_CHECK_HEADERS(fcntl.h)
AC_CHECK_HEADERS(stdint.h inttypes.h)
AC_FUNC_MKDIR
PKG_PROG_PKG_CONFIG

AC_CHECK_FUNCS(round nearbyint nearbyintf rint rintf)
AC_CHECK_HEADERS(fenv.h)


AC_DEFINE(MINILZO_HAVE_CONFIG_H, [1], [Define if config.h is present])

AM_ICONV
AM_GNU_GETTEXT

AC_SUBST(LIBICONV)
AC_SUBST(LIBINTL)

dnl Check for zlib
AC_CHECK_LIB([z], [zlibVersion], ZLIB_LIBS="-lz", AC_MSG_ERROR([*** zlib not found!]))
AC_SUBST([ZLIB_LIBS])

dnl -fno-fast-math and -fno-unsafe-math-optimizations to make sure it's disabled, as the fast-math feature on certain older
dnl versions of gcc produces horribly broken code(and even when it's working correctly, it can have somewhat unpredictable effects).
dnl
dnl -fno-aggressive-loop-optimizations because I don't trust gcc's aggressive loop optimizations, and there miiight be old code
dnl in Mednafen that would cause problems.
dnl
dnl -fomit-frame-pointer is required for some x86 inline assembly to compile.
dnl
dnl -fstrict-aliasing for OpenBSD
dnl
OPTIMIZER_FLAGS=""
AX_CFLAGS_GCC_OPTION([-fno-fast-math], OPTIMIZER_FLAGS)
AX_CFLAGS_GCC_OPTION([-fno-unsafe-math-optimizations], OPTIMIZER_FLAGS)
AX_CFLAGS_GCC_OPTION([-fno-aggressive-loop-optimizations], OPTIMIZER_FLAGS)
AX_CFLAGS_GCC_OPTION([-fno-ipa-icf], OPTIMIZER_FLAGS)
AX_CFLAGS_GCC_OPTION([-fno-printf-return-value], OPTIMIZER_FLAGS)
AX_CFLAGS_GCC_OPTION([-fomit-frame-pointer], OPTIMIZER_FLAGS)
AX_CFLAGS_GCC_OPTION([-fstrict-aliasing], OPTIMIZER_FLAGS)

dnl
dnl Aggressively try to disable PIC and PIE, as it has a significant performance overhead and will
dnl break some code(with compile-time failures or run-time assert()s triggering).
dnl
dnl Use -fwrapv instead of -fno-strict-overflow; -fno-strict-overflow is buggy on gcc and does not work as documented/implied.
dnl
dnl -mfunction-return=keep, -mindirect-branch=keep, -mno-indirect-branch-register to disable performance-murdering Spectre mitigations.
dnl
CODEGEN_FLAGS=""
AX_CFLAGS_GCC_OPTION([-fno-pic], CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-fno-pie], CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-fno-PIC], CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-fno-PIE], CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-nopie], CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-no-pie], CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-fwrapv],  CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-fjump-tables], CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-mfunction-return=keep], CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-mindirect-branch=keep], CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-mno-indirect-branch-register], CODEGEN_FLAGS)
AX_CFLAGS_GCC_OPTION([-mno-retpoline], CODEGEN_FLAGS)

CODEGEN_CFLAGS=""

CODEGEN_CXXFLAGS=""
AX_CXXFLAGS_GCC_OPTION([-fexceptions], CODEGEN_CXXFLAGS)

WARNING_FLAGS=""
AX_CFLAGS_GCC_OPTION([-Wall], WARNING_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wshadow], WARNING_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wempty-body], WARNING_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wignored-qualifiers], WARNING_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wvla], WARNING_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wvariadic-macros], WARNING_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wdisabled-optimization], WARNING_FLAGS)
AC_SUBST(WARNING_FLAGS)

#################################
#
# Used as needed in Makefile.am:
#
NO_STACK_PROTECTOR_FLAGS=""
AX_CFLAGS_GCC_OPTION([-fno-stack-protector], NO_STACK_PROTECTOR_FLAGS)
AX_CFLAGS_GCC_OPTION([-fno-stack-protector-all], NO_STACK_PROTECTOR_FLAGS)
AX_CFLAGS_GCC_OPTION([-fno-stack-protector-strong], NO_STACK_PROTECTOR_FLAGS)
AC_SUBST(NO_STACK_PROTECTOR_FLAGS)

# Used for ngp and quicklz
NO_STRICT_ALIASING_FLAGS=""
AX_CFLAGS_GCC_OPTION([-fno-strict-aliasing], NO_STRICT_ALIASING_FLAGS)
AC_SUBST(NO_STRICT_ALIASING_FLAGS)

# -----------------------------------
# Begin snes flags
#
SNES_EXTRA_FLAGS=""
SNES_EXTRA_CXXFLAGS=""
AX_CFLAGS_GCC_OPTION([-Wno-unused], SNES_EXTRA_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wno-shadow], SNES_EXTRA_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wno-sign-compare], SNES_EXTRA_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wno-uninitialized], SNES_EXTRA_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wno-parentheses], SNES_EXTRA_FLAGS)
AX_CFLAGS_GCC_OPTION([-Wno-switch], SNES_EXTRA_FLAGS)
AC_SUBST(SNES_EXTRA_FLAGS)
AC_SUBST(SNES_EXTRA_CXXFLAGS)
#
# End snes flags
# -----------------------------------

# -----------------------------------
# Begin ss flags
#
SS_EXTRA_FLAGS=""
AX_CFLAGS_GCC_OPTION([-mtune=haswell], SS_EXTRA_FLAGS)
AC_SUBST(SS_EXTRA_FLAGS)
#
# End ss flags
# -----------------------------------
#
# End used-as-needed flags
########################################

AM_CONDITIONAL(WANT_DEBUGGER, false)
AM_CONDITIONAL(WANT_FANCY_SCALERS, false)

AC_ARG_ENABLE(debugger,
 AC_HELP_STRING([--enable-debugger], [build with internal debugger [[default=yes]]]),
                  , enable_debugger=yes)

if test x$enable_debugger = xyes; then
                AC_DEFINE([WANT_DEBUGGER], [1], [Define if we are compiling with debugger.])
		AM_CONDITIONAL(WANT_DEBUGGER, true)
fi

AC_ARG_ENABLE(cjk-fonts,
 AC_HELP_STRING([--enable-cjk-fonts], [build with internal CJK(Chinese, Japanese, Korean) fonts [[default=yes]]]),
                  , enable_cjk_fonts=yes)

if test x$enable_cjk_fonts = xyes; then
                AC_DEFINE([WANT_INTERNAL_CJK], [1], [Define if we are compiling with internal CJK fonts.])
fi

AC_ARG_ENABLE(fancy-scalers,
 AC_HELP_STRING([--enable-fancy-scalers], [build with fancy(2xsai, hq2x, etc.) CPU-intensive software video scalers [[default=yes]]]),
                  , enable_fancy_scalers=yes)

if test x$enable_fancy_scalers = xyes; then
                AC_DEFINE([WANT_FANCY_SCALERS], [1], [Define if we are compiling with with fancy CPU-intensive software video scalers.])
		AM_CONDITIONAL(WANT_FANCY_SCALERS, true)
fi

dnl
dnl The code that uses $enable_altivec is lower, in the CPU architecture section.
dnl
AC_ARG_ENABLE(altivec,
 AC_HELP_STRING([--enable-altivec], [use AltiVec extensions on PowerPC/POWER ISA processors [[default=yes]]]),
                  , enable_altivec=yes)


AM_CONDITIONAL(WANT_GB_EMU, false)
AM_CONDITIONAL(WANT_GBA_EMU, false)
AM_CONDITIONAL(WANT_LYNX_EMU, false)
AM_CONDITIONAL(WANT_MD_EMU, false)
AM_CONDITIONAL(WANT_SMS_EMU, false)
AM_CONDITIONAL(WANT_NES_EMU, false)
AM_CONDITIONAL(WANT_NGP_EMU, false)
AM_CONDITIONAL(WANT_PCE_EMU, false)
AM_CONDITIONAL(WANT_PCE_FAST_EMU, false)
AM_CONDITIONAL(WANT_PCFX_EMU, false)
AM_CONDITIONAL(WANT_PSX_EMU, false)
AM_CONDITIONAL(WANT_SMS_EMU, false)
AM_CONDITIONAL(WANT_SNES_EMU, false)
AM_CONDITIONAL(WANT_SNES_FAUST_EMU, false)
AM_CONDITIONAL(WANT_SS_EMU, false)
AM_CONDITIONAL(WANT_SSFPLAY_EMU, false)
AM_CONDITIONAL(WANT_VB_EMU, false)
AM_CONDITIONAL(WANT_WSWAN_EMU, false)

AM_CONDITIONAL(NEED_GB_APU_EMU, false)
AM_CONDITIONAL(NEED_YM2413_EMU, false)
AM_CONDITIONAL(NEED_YM2612_EMU, false)
AM_CONDITIONAL(NEED_PCE_PSG_EMU, false)
AM_CONDITIONAL(NEED_SMS_APU_EMU, false)

AM_CONDITIONAL(NEED_68K_EMU, false)
AM_CONDITIONAL(NEED_Z80_EMU, false)
AM_CONDITIONAL(NEED_V810_EMU, false)

AM_CONDITIONAL(NEED_HUC6270_EMU, false)
AM_CONDITIONAL(NEED_ARCADE_CARD_EMU, false)

AC_ARG_ENABLE(gb,
 AC_HELP_STRING([--enable-gb], [build with GameBoy emulation [[default=yes]]]),
                  , enable_gb=yes)

if test x$enable_gb = xyes; then
                AC_DEFINE([WANT_GB_EMU], [1], [Define if we are compiling with GB emulation.])
		AM_CONDITIONAL(WANT_GB_EMU, true)
		AM_CONDITIONAL(NEED_GB_APU_EMU, true)
fi

AC_ARG_ENABLE(gba,
 AC_HELP_STRING([--enable-gba], [build with GameBoy Advance emulation [[default=yes]]]),
                  , enable_gba=yes)

if test x$enable_gba = xyes; then
                AC_DEFINE([WANT_GBA_EMU], [1], [Define if we are compiling with GBA emulation.])
		AM_CONDITIONAL(WANT_GBA_EMU, true)
		AM_CONDITIONAL(NEED_GB_APU_EMU, true)
fi

AC_ARG_ENABLE(lynx,
 AC_HELP_STRING([--enable-lynx], [build with Atari Lynx emulation [[default=yes]]]),
                  , enable_lynx=yes)

if test x$enable_lynx = xyes; then
                AC_DEFINE([WANT_LYNX_EMU], [1], [Define if we are compiling with Lynx emulation.])
		AM_CONDITIONAL(WANT_LYNX_EMU, true)
fi

AC_ARG_ENABLE(md,
 AC_HELP_STRING([--enable-md], [build with Sega Genesis/MegaDrive emulation [[default=yes]]]),
                  , enable_md=yes)

if test x$enable_md = xyes; then
                AC_DEFINE([WANT_MD_EMU], [1], [Define if we are compiling with Sega Genesis/MegaDrive emulation.])
                AM_CONDITIONAL(WANT_MD_EMU, true)
		AM_CONDITIONAL(NEED_68K_EMU, true)
		AM_CONDITIONAL(NEED_Z80_EMU, true)
		AM_CONDITIONAL(NEED_YM2612_EMU, true)
		AM_CONDITIONAL(NEED_SMS_APU_EMU, true)
fi

AC_ARG_ENABLE(nes,
 AC_HELP_STRING([--enable-nes], [build with Nintendo Entertainment System emulation [[default=yes]]]),
                  , enable_nes=yes)

if test x$enable_nes = xyes; then
                AC_DEFINE([WANT_NES_EMU], [1], [Define if we are compiling with NES emulation.])
                AM_CONDITIONAL(WANT_NES_EMU, true)
fi

AC_ARG_ENABLE(ngp,
 AC_HELP_STRING([--enable-ngp], [build with Neo Geo Pocket emulation [[default=yes]]]),
                  , enable_ngp=yes)

if test x$enable_ngp = xyes; then
                AC_DEFINE([WANT_NGP_EMU], [1], [Define if we are compiling with NGP emulation.])
		AM_CONDITIONAL(WANT_NGP_EMU, true)
		AM_CONDITIONAL(NEED_Z80_EMU, true)
fi

AC_ARG_ENABLE(pce,
 AC_HELP_STRING([--enable-pce], [build with PC Engine(TurboGrafx 16) emulation [[default=yes]]]),
                  , enable_pce=yes)

if test x$enable_pce = xyes; then
                AC_DEFINE([WANT_PCE_EMU], [1], [Define if we are compiling with PCE emulation.])
		AM_CONDITIONAL(WANT_PCE_EMU, true)
		AM_CONDITIONAL(NEED_PCE_PSG_EMU, true)
		AM_CONDITIONAL(NEED_HUC6270_EMU, true)
		AM_CONDITIONAL(NEED_ARCADE_CARD_EMU, true)
fi

AC_ARG_ENABLE(pce-fast,
 AC_HELP_STRING([--enable-pce-fast], [build the separate, fast PC Engine(TurboGrafx 16) emulation [[default=yes]]]),
                  , enable_pce_fast=yes)

if test x$enable_pce_fast = xyes; then
                AC_DEFINE([WANT_PCE_FAST_EMU], [1], [Define if we are compiling with separate fast PCE emulation.])
                AM_CONDITIONAL(WANT_PCE_FAST_EMU, true)
		AM_CONDITIONAL(NEED_ARCADE_CARD_EMU, true)
fi

AC_ARG_ENABLE(pcfx,
 AC_HELP_STRING([--enable-pcfx], [build with PC-FX emulation [[default=yes]]]),
                  , enable_pcfx=yes)

if test x$enable_pcfx = xyes; then
                AC_DEFINE([WANT_PCFX_EMU], [1], [Define if we are compiling with PC-FX emulation.])
		AM_CONDITIONAL(WANT_PCFX_EMU, true)
		AM_CONDITIONAL(NEED_V810_EMU, true)
		AM_CONDITIONAL(NEED_PCE_PSG_EMU, true)
		AM_CONDITIONAL(NEED_HUC6270_EMU, true)
fi

AC_ARG_ENABLE(psx,
 AC_HELP_STRING([--enable-psx], [build with PlayStation emulation [[default=yes]]]),
                  , enable_psx=yes)

if test x$enable_psx = xyes; then
                AC_DEFINE([WANT_PSX_EMU], [1], [Define if we are compiling with PlayStation emulation.])
                AM_CONDITIONAL(WANT_PSX_EMU, true)
fi

AC_ARG_ENABLE(sms,
 AC_HELP_STRING([--enable-sms], [build with SMS+GG emulation [[default=yes]]]),
                  , enable_sms=yes)

if test x$enable_sms = xyes; then
                AC_DEFINE([WANT_SMS_EMU], [1], [Define if we are compiling with SMS+GG emulation.])
                AM_CONDITIONAL(WANT_SMS_EMU, true)
		AM_CONDITIONAL(NEED_Z80_EMU, true)
		AM_CONDITIONAL(NEED_SMS_APU_EMU, true)
		AM_CONDITIONAL(NEED_YM2413_EMU, true)
fi

AC_ARG_ENABLE(snes,
 AC_HELP_STRING([--enable-snes], [build with SNES emulation [[default=yes]]]),
                  , enable_snes=yes)

if test x$enable_snes = xyes; then
                AC_DEFINE([WANT_SNES_EMU], [1], [Define if we are compiling with SNES emulation.])
                AM_CONDITIONAL(WANT_SNES_EMU, true)
fi

AC_ARG_ENABLE(snes-faust,
 AC_HELP_STRING([--enable-snes-faust], [build with experimental fast SNES emulation [[default=yes]]]),
                  , enable_snes_faust=yes)

if test x$enable_snes_faust = xyes; then
                AC_DEFINE([WANT_SNES_FAUST_EMU], [1], [Define if we are compiling with experimental fast SNES emulation.])
                AM_CONDITIONAL(WANT_SNES_FAUST_EMU, true)
fi

AC_ARG_ENABLE(ss,
 AC_HELP_STRING([--enable-ss], [build with Sega Saturn emulation [[default=x86_64 amd64 aarch64* arm64* ppc64* powerpc64*]]]),
                  , [enable_ss="x86_64 amd64 aarch64* arm64* ppc64* powerpc64*"])
for i in $enable_ss; do case $host_cpu in $i) enable_ss=yes ;; esac; done

if test "x$enable_ss" = "xyes"; then
                AC_DEFINE([WANT_SS_EMU], [1], [Define if we are compiling with Sega Saturn emulation.])
                AM_CONDITIONAL(WANT_SS_EMU, true)
		AM_CONDITIONAL(NEED_68K_EMU, true)
fi

AC_ARG_ENABLE(ssfplay,
 AC_HELP_STRING([--enable-ssfplay], [build with SSF playback support [[default=yes]]]),
                  , enable_ssfplay=yes)

if test x$enable_ssfplay = xyes; then
                AC_DEFINE([WANT_SSFPLAY_EMU], [1], [Define if we are compiling with SSF playback support.])
                AM_CONDITIONAL(WANT_SSFPLAY_EMU, true)
                AM_CONDITIONAL(NEED_68K_EMU, true)
fi

AC_ARG_ENABLE(vb,
 AC_HELP_STRING([--enable-vb], [build with Virtual Boy emulation [[default=yes]]]),
                  , enable_vb=yes)

if test x$enable_vb = xyes; then
                AC_DEFINE([WANT_VB_EMU], [1], [Define if we are compiling with Virtual Boy emulation.])
                AM_CONDITIONAL(WANT_VB_EMU, true)
		AM_CONDITIONAL(NEED_V810_EMU, true)
fi


AC_ARG_ENABLE(wswan,
 AC_HELP_STRING([--enable-wswan], [build with WonderSwan emulation [[default=yes]]]),
                  , enable_wswan=yes)

if test x$enable_wswan = xyes; then
                AC_DEFINE([WANT_WSWAN_EMU], [1], [Define if we are compiling with WonderSwan emulation.])
                AM_CONDITIONAL(WANT_WSWAN_EMU, true)
fi

##
## ALSA and JACK checking code ripped from SDL's autoconf file, with heavy modifications
##
#
# ALSA
#
AM_CONDITIONAL(HAVE_ALSA, false)
AC_ARG_ENABLE(alsa, AC_HELP_STRING([--enable-alsa], [support the ALSA audio API [[default=yes]]]),
	[],
	[enable_alsa=yes])
if test x$enable_alsa = xyes; then
	AM_PATH_ALSA(1.0.0, have_alsa=yes, have_alsa=no)

	# Restore all flags from before the ALSA detection runs
	CFLAGS="$alsa_save_CFLAGS"
	LDFLAGS="$alsa_save_LDFLAGS"
	LIBS="$alsa_save_LIBS"

	if test x$have_alsa = xyes; then
		AM_CONDITIONAL(HAVE_ALSA, true)
		AC_DEFINE([HAVE_ALSA], [1], [Define if we are compiling with ALSA support.])
	fi
fi
AC_SUBST([ALSA_LIBS])
AC_SUBST([ALSA_CFLAGS])


#
# JACK
#
AM_CONDITIONAL(HAVE_JACK, false)
AC_ARG_ENABLE(jack, AC_HELP_STRING([--enable-jack], [support the JACK audio API [[default=yes]]]),
	[],
	[enable_jack=yes])
if test x$enable_jack = xyes; then
	PKG_CHECK_MODULES(JACK, jack, [have_jack=yes], [have_jack=no])

	if test x$have_jack = xyes; then
		AM_CONDITIONAL(HAVE_JACK, true)
		AC_DEFINE([HAVE_JACK], [1], [Define if we are compiling with JACK support.])
	fi
fi
AC_SUBST([JACK_LIBS])
AC_SUBST([JACK_CFLAGS])


#
# OpenBSD Audio
#
AM_CONDITIONAL(HAVE_OPENBSD_AUDIO, false)
AC_MSG_CHECKING([for OpenBSD audio])
AC_TRY_COMPILE([
	#include <sys/types.h>
	#include <sys/ioctl.h>
	#include <sys/audioio.h>
	#include <string.h>
	],
	[
	struct audio_swpar par;
	struct audio_pos pos;
	struct audio_status status;
	AUDIO_INITPAR(&par);
	],
	[AC_MSG_RESULT([yes])
	 AM_CONDITIONAL(HAVE_OPENBSD_AUDIO, true)
	 AC_DEFINE([HAVE_OPENBSD_AUDIO], [1], [Define if we are compiling with OpenBSD audio support.])],
	[AC_MSG_RESULT([no])])

#
# mpcdec
#
AM_CONDITIONAL(HAVE_EXTERNAL_MPCDEC, false)
AC_ARG_WITH([external-mpcdec], [AS_HELP_STRING([--with-external-mpcdec], [compile and link with external mpcdec @<:@default=no@:>@])],
	[],
	[with_external_mpcdec=no])
if test x$with_external_mpcdec = xyes; then
	AC_CHECK_LIB([mpcdec], [mpc_demux_init], [], AC_MSG_ERROR([*** mpcdec not found!]))
	AC_CHECK_HEADER([mpc/mpcdec.h], [], AC_MSG_ERROR([*** mpcdec not found!]))

	AC_DEFINE([HAVE_EXTERNAL_MPCDEC], [1], [Define if we are compiling and linking with external mpcdec.])
	AM_CONDITIONAL(HAVE_EXTERNAL_MPCDEC, true)
	AC_SUBST([MPCDEC_LIBS], ["-lmpcdec"])
else
	AC_DEFINE([MPC_FIXED_POINT], [1], [Define to use fixed-point MPC decoder.])
fi

#
# tremor
#
AM_CONDITIONAL(HAVE_EXTERNAL_TREMOR, false)
AC_ARG_WITH([external-tremor], [AS_HELP_STRING([--with-external-tremor], [compile and link with external tremor @<:@default=no@:>@])],
	[],
	[with_external_tremor=no])
if test x$with_external_tremor = xyes; then
	AC_CHECK_LIB([vorbisidec], [ov_read], [], AC_MSG_ERROR([*** libvorbisidec not found!]))
	AC_CHECK_HEADER([tremor/ivorbisfile.h], [], AC_MSG_ERROR([*** libvorbisidec not found!]))

	AC_DEFINE([HAVE_EXTERNAL_TREMOR], [1], [Define if we are compiling and linking with external tremor.])
	AM_CONDITIONAL(HAVE_EXTERNAL_TREMOR, true)
	AC_SUBST([TREMOR_LIBS], ["-lvorbisidec"])
fi

#
# trio
#
AM_CONDITIONAL(HAVE_EXTERNAL_TRIO, false)
AC_ARG_WITH([external-trio], [AS_HELP_STRING([--with-external-trio], [compile and link with external trio @<:@default=no@:>@])],
	[],
	[with_external_trio=no])
if test x$with_external_trio = xyes; then
	AC_CHECK_LIB([trio], [trio_printf], [], AC_MSG_ERROR([*** libtrio not found!]))
	AC_CHECK_HEADER([trio.h], [], AC_MSG_ERROR([*** libtrio not found!]))

	AC_DEFINE([HAVE_EXTERNAL_TRIO], [1], [Define if we are compiling and linking with external trio.])
	AM_CONDITIONAL(HAVE_EXTERNAL_TRIO, true)
	AC_SUBST([TRIO_LIBS], ["-ltrio"])
	trio_include_symsrc="include/trio_external"
else
	trio_include_symsrc="src/trio"
fi
AC_CONFIG_LINKS([include/trio/triodef.h:$trio_include_symsrc/triodef.h])
AC_CONFIG_LINKS([include/trio/trio.h:$trio_include_symsrc/trio.h])
AC_CONFIG_LINKS([include/trio/trionan.h:$trio_include_symsrc/trionan.h])
AC_CONFIG_LINKS([include/trio/triop.h:$trio_include_symsrc/triop.h])
AC_CONFIG_LINKS([include/trio/triostr.h:$trio_include_symsrc/triostr.h])

#
# minilzo/lzo
#
AM_CONDITIONAL(HAVE_EXTERNAL_LZO2, false)
AC_ARG_WITH([external-lzo], [AS_HELP_STRING([--with-external-lzo], [compile and link with external LZO @<:@default=no@:>@])],
	[],
	[with_external_lzo=no])
if test x$with_external_lzo = xyes; then
	PKG_CHECK_MODULES(LZO2, lzo2 >= 2.0.9, [], AC_MSG_ERROR([*** lzo2 >= 2.0.9 not found!]))
	AC_SUBST([LZO2_LIBS])
	AC_SUBST([LZO2_CFLAGS])
	AC_DEFINE([HAVE_EXTERNAL_LZO2], [1], [Define if we are compiling and linking with external LZO.])
	AM_CONDITIONAL(HAVE_EXTERNAL_LZO2, true)
	minilzo_include_symsrc="include/minilzo_external"
else
	minilzo_include_symsrc="include/minilzo_internal"
fi
AC_CONFIG_LINKS([include/minilzo/minilzo.h:$minilzo_include_symsrc/minilzo.h])

#
# libsndfile
#
AM_CONDITIONAL(HAVE_LIBSNDFILE, false)
AC_ARG_WITH([libsndfile],
            [AS_HELP_STRING([--with-libsndfile],
              [support various sound file formats in ripped CD images @<:@default=yes@:>@])],
            [],
            [with_libsndfile=yes])
if test x$with_libsndfile = xyes; then
	PKG_CHECK_MODULES(SNDFILE, sndfile >= 1.0.2, [], AC_MSG_ERROR([*** libsndfile >= 1.0.2 not found!]))
	AC_DEFINE([HAVE_LIBSNDFILE], [1], [Define if we are compiling with libsndfile support.])
	AM_CONDITIONAL(HAVE_LIBSNDFILE, true)
fi
AC_SUBST([SNDFILE_LIBS])
AC_SUBST([SNDFILE_CFLAGS])


AM_CONDITIONAL(HAVE_OSSDSP, false)
AM_CONDITIONAL(HAVE_DIRECTSOUND, false)
AM_CONDITIONAL(HAVE_WASAPI, false)
AM_CONDITIONAL(HAVE_SDL, false)
AM_CONDITIONAL(DOS, false)
AM_CONDITIONAL(WIN32, false)
AM_CONDITIONAL(UNIX, false)
AM_CONDITIONAL(HAVE_LINUX_JOYSTICK, false)
NEED_SDL=true

if expr x"$host" : 'x.*-mingw*' > /dev/null; then
	AC_CHECK_TOOL([WINDRES], [windres])

	if test x$host_cpu != xx86_64; then
		# Enable larger address space support(for the 32-bit build).
		LDFLAGS="$LDFLAGS -Wl,--large-address-aware"
		AX_CFLAGS_GCC_OPTION([-march=i686], OPTIMIZER_FLAGS)
		AX_CFLAGS_GCC_OPTION([-mtune=pentium3], OPTIMIZER_FLAGS)
	else
		AX_CFLAGS_GCC_OPTION([-mtune=amdfam10], OPTIMIZER_FLAGS)
	fi

	# Always build with DirectSound support.
	AM_CONDITIONAL(HAVE_DIRECTSOUND,true)
	AC_DEFINE([HAVE_DIRECTSOUND], [1], [Define if we are compiling with DirectSound support.])
	LIBS="-ldxguid -lwinmm -ldsound $LIBS"

	# Always build with WASAPI support.
	AM_CONDITIONAL(HAVE_WASAPI,true)
	AC_DEFINE([HAVE_WASAPI], [1], [Define if we are compiling with WASAPI support.])
	LIBS="-lole32 $LIBS"

        AC_DEFINE([PSS_STYLE],[2], [Defines the filesystem path-separator type.])
	AC_DEFINE([WIN32], [1], [Define if we are compiling for Win32.])
	AM_CONDITIONAL(WIN32, true)

	LIBS="-mconsole -lws2_32 -ldxguid -lwinmm -ldinput $LIBS -lwinmm"
	CPPFLAGS="-D_LFS64_LARGEFILE=1 $CPPFLAGS"
elif expr x"$host" : 'x.*djgpp' > /dev/null; then
       	AC_DEFINE([PSS_STYLE],[2], [Defines the filesystem path-separator type.])
       	AC_DEFINE([DOS], [1], [Define if we are compiling for DOS.])
       	AM_CONDITIONAL(DOS, true)
	NEED_SDL=false
else
	AC_DEFINE([PSS_STYLE],[1], [Defines the filesystem path-separator type.])

	AC_CHECK_HEADER([sys/soundcard.h],[AM_CONDITIONAL(HAVE_OSSDSP,true) AC_DEFINE([HAVE_OSSDSP], [1], [Define if we are compiling with OSS support.])])
	AC_CHECK_HEADER([linux/joystick.h],[AM_CONDITIONAL(HAVE_LINUX_JOYSTICK,true) AC_DEFINE([HAVE_LINUX_JOYSTICK], [1], [Define if we are compiling with Linux joystick support.])])
fi

if $NEED_SDL
then
	SDL_VERSION=2.0.5
	AM_PATH_SDL2($SDL_VERSION, HAVE_SDL=true, HAVE_SDL=false)
	if $HAVE_SDL
	then
		AM_CONDITIONAL(HAVE_SDL, true)
		AC_DEFINE([HAVE_SDL], [1], [Define if we are compiling with SDL.])
		AC_SUBST(SDL_LIBS)
		AC_SUBST(SDL_CFLAGS)
	else
		AC_MSG_ERROR([*** SDL >= 2.0.5 not found!])
	fi
fi


dnl
dnl FIXME: Make sure POSIX/BSD sockets API detection doesn't have any false positives(like when targeting Windows).
dnl
AM_CONDITIONAL(HAVE_POSIX_SOCKETS, false)
dnl
dnl
HAVE_POSIX_SOCKETS=yes

dnl
dnl Solaris may require "nsl" and "socket" libraries.
dnl
AC_SEARCH_LIBS([gethostbyname], [nsl])
AC_SEARCH_LIBS([socket], [socket network])

AC_CHECK_FUNCS(socket bind listen connect accept send recv close gethostbyname gethostbyaddr getaddrinfo freeaddrinfo gai_strerror select poll getsockopt setsockopt, [], 
	[HAVE_POSIX_SOCKETS=no])

if test x$HAVE_POSIX_SOCKETS = xyes; then
	AM_CONDITIONAL(HAVE_POSIX_SOCKETS, true)
        AC_DEFINE([HAVE_POSIX_SOCKETS], [1], [Define if we are compiling with POSIX sockets support.])
fi

AM_CONDITIONAL(ARCH_X86, false)
AM_CONDITIONAL(ARCH_X86_32, false)
AM_CONDITIONAL(ARCH_X86_64, false)
AM_CONDITIONAL(ARCH_POWERPC, false)
AM_CONDITIONAL(ARCH_POWERPC_ALTIVEC, false)

TRIO_CFLAGS=""

dnl OpenBSD...
AC_TRY_COMPILE([], [asm volatile("vcvtss2si %xmm6,%ecx\n\tvhaddps %ymm7,%ymm7,%ymm7\n\tvzeroupper\n\t");],
	AC_DEFINE([HAVE_INLINEASM_AVX], [1], [Define if GNU-style AVX inline assembly is supported.]),
	[])

case "$host_cpu" in
	x86_64|amd64)
	        AC_DEFINE([ARCH_X86], [1], [Define if we are compiling for 32-bit or 64-bit x86 architectures.])
	        AM_CONDITIONAL(ARCH_X86, true)
                AC_DEFINE([ARCH_X86_64], [1], [Define if we are compiling for 64-bit x86 architectures.])
                AM_CONDITIONAL(ARCH_X86_64, true)
		AX_CFLAGS_GCC_OPTION([-mcmodel=small], CODEGEN_FLAGS)
		;;

	i*86)
                AC_DEFINE([ARCH_X86], [1], [Define if we are compiling for 32-bit or 64-bit x86 architectures.])
                AM_CONDITIONAL(ARCH_X86, true)
                AC_DEFINE([ARCH_X86_32], [1], [Define if we are compiling for 32-bit x86 architectures.])
                AM_CONDITIONAL(ARCH_X86_32, true)
		;;

	powerpc)
	        AC_DEFINE([ARCH_POWERPC], [1], [Define if we are compiling for PPC architectures.])
	        AM_CONDITIONAL(ARCH_POWERPC, true)

	        if test x$enable_altivec = xyes; then
        	        ALTIVEC_FLAGS=""
                	AX_CFLAGS_GCC_OPTION([-faltivec], ALTIVEC_FLAGS)
	                AX_CFLAGS_GCC_OPTION([-maltivec], ALTIVEC_FLAGS)
	                if test "x$ALTIVEC_FLAGS" != "x"; then
        	                AC_DEFINE([ARCH_POWERPC_ALTIVEC], [1], [Define if we are compiling with AltiVec usage.])
                	        AM_CONDITIONAL(ARCH_POWERPC_ALTIVEC, true)

				altivec_save_CPPFLAGS="$CPPFLAGS"
				CPPFLAGS="$CPPFLAGS $ALTIVEC_FLAGS"
				AC_CHECK_HEADER([altivec.h],
					AC_DEFINE([HAVE_ALTIVEC_H], [1], [Define if altivec.h is present and usable.]),
					[] )
				CPPFLAGS="$altivec_save_CPPFLAGS"
	                fi
	        fi
		;;

	alpha*)
		AX_CFLAGS_GCC_OPTION([-mieee], TRIO_CFLAGS)
		;;
esac
AC_SUBST(TRIO_CFLAGS)

AC_C_BIGENDIAN([AC_DEFINE([MSB_FIRST],[1],[Define on big-endian platforms.])], 
[
 AC_DEFINE([LSB_FIRST],[1],[Define on little-endian platforms.])
])
AC_DEFINE_UNQUOTED([MEDNAFEN_VERSION],"$MEDNAFEN_VERSION", [Mednafen version definition.])
AC_DEFINE_UNQUOTED([MEDNAFEN_VERSION_NUMERIC],$MEDNAFEN_VERSION_NUMERIC, [Mednafen version numeric.])

AC_SUBST([AM_CFLAGS], "$ALTIVEC_FLAGS $OPTIMIZER_FLAGS $WARNING_FLAGS $CODEGEN_FLAGS $CODEGEN_CFLAGS")
AC_SUBST([AM_CXXFLAGS], "$ALTIVEC_FLAGS $OPTIMIZER_FLAGS $WARNING_FLAGS $CODEGEN_FLAGS $CODEGEN_CXXFLAGS")

dnl Output Makefiles
AC_OUTPUT([Makefile po/Makefile.in intl/Makefile src/Makefile src/drivers/Makefile src/drivers_dos/Makefile src/sexyal/Makefile src/ss/Makefile])
