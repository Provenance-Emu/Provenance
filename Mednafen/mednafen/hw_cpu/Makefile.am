AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@  
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES        =       libmdfnhwcpu.a

libmdfnhwcpu_a_SOURCES	=

if NEED_68K_EMU
if !CROSS_COMPILING
noinst_PROGRAMS = gen68k$(EXEEXT)
gen68k_SOURCES = c68k/gen68k.cpp
gen68k_CFLAGS = -DC68K_GEN
gen68k_LDFLAGS = -DC68K_GEN
gen68k_LDADD = @LIBINTL@ @LIBICONV@
nodist_pkgdata_DATA = c68k/c68k_op0.inc
c68k/c68k_op0.inc: gen68k$(EXEEXT)
	cd c68k && ../gen68k$(EXEEXT)
endif

libmdfnhwcpu_a_SOURCES	+=	c68k/c68kexec.cpp c68k/c68k.cpp
endif

if NEED_Z80_EMU
libmdfnhwcpu_a_SOURCES	+=      z80-fuse/z80.cpp z80-fuse/z80_ops.cpp
endif

if NEED_V810_EMU
libmdfnhwcpu_a_SOURCES	+=	v810/v810_cpu.cpp v810/v810_cpuD.cpp v810/v810_fp_ops.cpp
endif

if NEED_HUC6280_EMU
libmdfnhwcpu_a_SOURCES  +=      huc6280/huc6280.cpp

if WANT_DEBUGGER
libmdfnhwcpu_a_SOURCES	+=	huc6280/dis6280.cpp
endif
endif
