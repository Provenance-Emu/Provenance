# Makefile for directory with message catalog handling library of GNU gettext
# Copyright (C) 1995-1998, 2000-2007, 2009-2010 Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU Library General Public License as published
# by the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
# USA.

PACKAGE = mednafen
VERSION = 1.21.1

SHELL = /bin/sh

srcdir = .
top_srcdir = ..
top_builddir = ..

# The VPATH variables allows builds with $builddir != $srcdir, assuming a
# 'make' program that supports VPATH (such as GNU make). This line is removed
# by autoconf automatically when "$(srcdir)" = ".".
# In this directory, the VPATH handling is particular:
# 1. If INTL_LIBTOOL_SUFFIX_PREFIX is 'l' (indicating a build with libtool),
#    the .c -> .lo rules carefully use $(srcdir), so that VPATH can be omitted.
# 2. If PACKAGE = gettext-tools, VPATH _must_ be omitted, because otherwise
#    'make' does the wrong thing if GNU gettext was configured with
#    "./configure --srcdir=`pwd`", namely it gets confused by the .lo and .la
#    files it finds in srcdir = ../../gettext-runtime/intl.


prefix = /usr/local
exec_prefix = ${prefix}
transform = s,x,x,
libdir = ${exec_prefix}/lib
includedir = ${prefix}/include
datarootdir = ${prefix}/share
datadir = ${datarootdir}
localedir = $(datadir)/locale
gettextsrcdir = $(datadir)/gettext/intl
aliaspath = $(localedir)
subdir = intl

INSTALL = /usr/local/bin/ginstall -c
INSTALL_DATA = ${INSTALL} -m 644

# We use $(mkdir_p).
# In automake <= 1.9.x, $(mkdir_p) is defined either as "mkdir -p --" or as
# "$(mkinstalldirs)" or as "$(install_sh) -d". For these automake versions,
# ${SHELL} /Users/jmattiello/Workspace/Provenance/Provenance-jmattiello/Mednafen/mednafen-1.21/install-sh does not start with $(SHELL), so we add it.
# In automake >= 1.10, /usr/local/bin/gmkdir -p is derived from ${MKDIR_P}, which is defined
# either as "/path/to/mkdir -p" or ".../install-sh -c -d". For these automake
# versions, $(mkinstalldirs) and $(install_sh) are unused.
mkinstalldirs = $(SHELL) ${SHELL} /Users/jmattiello/Workspace/Provenance/Provenance-jmattiello/Mednafen/mednafen-1.21/install-sh -d
install_sh = $(SHELL) ${SHELL} /Users/jmattiello/Workspace/Provenance/Provenance-jmattiello/Mednafen/mednafen-1.21/install-sh
MKDIR_P = /usr/local/bin/gmkdir -p
mkdir_p = /usr/local/bin/gmkdir -p

l = 

AR = ar
CC = gcc -std=gnu99 -fsigned-char
LIBTOOL = @LIBTOOL@
RANLIB = ranlib
YACC = bison -y -d
YFLAGS = --name-prefix=__gettext
# Windows resource compiler (windres). Used when libtool is not used.
WINDRES = 
# Windows resource compiler (windres). Used via libtool.
RC = @RC@

# Support for silent-rules.
AM_V_at = $(am__v_at_$(V))
am__v_at_ = $(am__v_at_1)
am__v_at_0 = @
AM_V_AR = $(am__v_AR_$(V))
am__v_AR_ = $(am__v_AR_1)
am__v_AR_0 = @echo "  AR    " $@;
AM_V_CC = $(am__v_CC_$(V))
am__v_CC_ = $(am__v_CC_1)
am__v_CC_0 = @echo "  CC    " $@;
AM_V_GEN = $(am__v_GEN_$(V))
am__v_GEN_ = $(am__v_GEN_1)
am__v_GEN_0 = @echo "  GEN   " $@;
AM_V_YACC = $(am__v_YACC_$(V))
am__v_YACC_ = $(am__v_YACC_1)
am__v_YACC_0 = @echo "  YACC  " $@;
AM_V_lt = $(am__v_lt_$(V))
am__v_lt_ = $(am__v_lt_1)
am__v_lt_0 = --silent

# -DBUILDING_LIBINTL: Change expansion of LIBINTL_DLL_EXPORTED macro.
# -DBUILDING_DLL: Change expansion of RELOCATABLE_DLL_EXPORTED macro.
DEFS = -DLOCALEDIR=\"$(localedir)\" -DLOCALE_ALIAS_PATH=\"$(aliaspath)\" \
-DLIBDIR=\"$(libdir)\" -DBUILDING_LIBINTL -DBUILDING_DLL -DIN_LIBINTL \
-DENABLE_RELOCATABLE=1 -DIN_LIBRARY -DINSTALLDIR=\"$(libdir)\" -DNO_XMALLOC \
-Dset_relocation_prefix=libintl_set_relocation_prefix \
-Drelocate=libintl_relocate \
-DDEPENDS_ON_LIBICONV=1 -DHAVE_CONFIG_H
CPPFLAGS = 
CFLAGS = -g -O2 -fvisibility=hidden
LDFLAGS =  $(LDFLAGS_no)
LDFLAGS_yes = -Wl,--export-all-symbols
LDFLAGS_no =
LIBS = 

COMPILE = $(CC) -c $(DEFS) $(INCLUDES) $(CPPFLAGS) $(CFLAGS) $(XCFLAGS)

HEADERS = \
  gmo.h \
  gettextP.h \
  hash-string.h \
  loadinfo.h \
  plural-exp.h \
  eval-plural.h \
  localcharset.h \
  lock.h \
  relocatable.h \
  tsearch.h tsearch.c \
  xsize.h \
  printf-args.h printf-args.c \
  printf-parse.h wprintf-parse.h printf-parse.c \
  vasnprintf.h vasnwprintf.h vasnprintf.c \
  os2compat.h \
  libgnuintl.h.in
SOURCES = \
  bindtextdom.c \
  dcgettext.c \
  dgettext.c \
  gettext.c \
  finddomain.c \
  hash-string.c \
  loadmsgcat.c \
  localealias.c \
  textdomain.c \
  l10nflist.c \
  explodename.c \
  dcigettext.c \
  dcngettext.c \
  dngettext.c \
  ngettext.c \
  plural.y \
  plural-exp.c \
  localcharset.c \
  threadlib.c \
  lock.c \
  relocatable.c \
  langprefs.c \
  localename.c \
  log.c \
  printf.c \
  setlocale.c \
  version.c \
  osdep.c \
  os2compat.c \
  intl-exports.c \
  intl-compat.c
OBJECTS = \
  bindtextdom.$lo \
  dcgettext.$lo \
  dgettext.$lo \
  gettext.$lo \
  finddomain.$lo \
  hash-string.$lo \
  loadmsgcat.$lo \
  localealias.$lo \
  textdomain.$lo \
  l10nflist.$lo \
  explodename.$lo \
  dcigettext.$lo \
  dcngettext.$lo \
  dngettext.$lo \
  ngettext.$lo \
  plural.$lo \
  plural-exp.$lo \
  localcharset.$lo \
  threadlib.$lo \
  lock.$lo \
  relocatable.$lo \
  langprefs.$lo \
  localename.$lo \
  log.$lo \
  printf.$lo \
  setlocale.$lo \
  version.$lo \
  osdep.$lo \
  intl-compat.$lo
OBJECTS_RES_yes = libintl.res.$lo
OBJECTS_RES_no =
DISTFILES.common = Makefile.in \
config.charset locale.alias ref-add.sin ref-del.sin export.h libintl.rc \
$(HEADERS) $(SOURCES)
DISTFILES.generated = plural.c
DISTFILES.normal = VERSION
DISTFILES.gettext = COPYING.LIB-2.0 COPYING.LIB-2.1 libintl.glibc README.woe32
DISTFILES.obsolete = xopen-msg.sed linux-msg.sed po2tbl.sed.in cat-compat.c \
COPYING.LIB-2 gettext.h libgettext.h plural-eval.c libgnuintl.h \
libgnuintl.h_vms Makefile.vms libgnuintl.h.msvc-static \
libgnuintl.h.msvc-shared Makefile.msvc

all: all-yes
all-yes: libintl.$la libintl.h charset.alias ref-add.sed ref-del.sed
all-no: all-no-yes
all-no-yes: libgnuintl.$la
all-no-no:

libintl.a libgnuintl.a: $(OBJECTS)
	$(AM_V_at)rm -f $@
	$(AM_V_AR)$(AR) cru $@ $(OBJECTS)
	$(AM_V_at)$(RANLIB) $@

libintl.la libgnuintl.la: $(OBJECTS) $(OBJECTS_RES_no)
	$(AM_V_GEN)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=link \
	  $(CC) $(CPPFLAGS) $(CFLAGS) $(XCFLAGS) $(LDFLAGS) -o $@ \
	  $(OBJECTS) -liconv -Wl,-framework -Wl,CoreFoundation $(LIBS)  -lc \
	  $(OBJECTS_RES_no) \
	  -version-info $(LTV_CURRENT):$(LTV_REVISION):$(LTV_AGE) \
	  -rpath $(libdir) \
	  -no-undefined

# Libtool's library version information for libintl.
# Before making a gettext release, the gettext maintainer must change this
# according to the libtool documentation, section "Library interface versions".
# Maintainers of other packages that include the intl directory must *not*
# change these values.
LTV_CURRENT=9
LTV_REVISION=1
LTV_AGE=1

.SUFFIXES:
.SUFFIXES: .c .y .o .lo .sin .sed

.c.o:
	$(AM_V_CC)$(COMPILE) $<

.y.c:
	$(AM_V_YACC)$(YACC) $(YFLAGS) --output $@ $<
	$(AM_V_at)rm -f $*.h

bindtextdom.lo: $(srcdir)/bindtextdom.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/bindtextdom.c
dcgettext.lo: $(srcdir)/dcgettext.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/dcgettext.c
dgettext.lo: $(srcdir)/dgettext.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/dgettext.c
gettext.lo: $(srcdir)/gettext.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/gettext.c
finddomain.lo: $(srcdir)/finddomain.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/finddomain.c
hash-string.lo: $(srcdir)/hash-string.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/hash-string.c
loadmsgcat.lo: $(srcdir)/loadmsgcat.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/loadmsgcat.c
localealias.lo: $(srcdir)/localealias.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/localealias.c
textdomain.lo: $(srcdir)/textdomain.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/textdomain.c
l10nflist.lo: $(srcdir)/l10nflist.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/l10nflist.c
explodename.lo: $(srcdir)/explodename.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/explodename.c
dcigettext.lo: $(srcdir)/dcigettext.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/dcigettext.c
dcngettext.lo: $(srcdir)/dcngettext.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/dcngettext.c
dngettext.lo: $(srcdir)/dngettext.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/dngettext.c
ngettext.lo: $(srcdir)/ngettext.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/ngettext.c
plural.lo: $(srcdir)/plural.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/plural.c
plural-exp.lo: $(srcdir)/plural-exp.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/plural-exp.c
localcharset.lo: $(srcdir)/localcharset.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/localcharset.c
threadlib.lo: $(srcdir)/threadlib.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/threadlib.c
lock.lo: $(srcdir)/lock.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/lock.c
relocatable.lo: $(srcdir)/relocatable.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/relocatable.c
langprefs.lo: $(srcdir)/langprefs.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/langprefs.c
localename.lo: $(srcdir)/localename.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/localename.c
log.lo: $(srcdir)/log.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/log.c
printf.lo: $(srcdir)/printf.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/printf.c
setlocale.lo: $(srcdir)/setlocale.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/setlocale.c
version.lo: $(srcdir)/version.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/version.c
osdep.lo: $(srcdir)/osdep.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/osdep.c
intl-compat.lo: $(srcdir)/intl-compat.c
	$(AM_V_CC)$(LIBTOOL) $(AM_V_lt) --tag=CC --mode=compile $(COMPILE) $(srcdir)/intl-compat.c

# This rule is executed only on Woe32 systems.
# The following sed expressions come from the windres-options script. They are
# inlined here, so that they can be written in a Makefile without requiring a
# temporary file. They must contain literal newlines rather than semicolons,
# so that they work with the sed-3.02 that is shipped with MSYS.
libintl.res.o: $(srcdir)/libintl.rc
	nlinit=`echo 'nl="'; echo '"'`; eval "$$nlinit"; \
	sed_extract_major='/^[0-9]/{'$${nl}'s/^\([0-9]*\).*/\1/p'$${nl}q$${nl}'}'$${nl}'c\'$${nl}0$${nl}q; \
	sed_extract_minor='/^[0-9][0-9]*[.][0-9]/{'$${nl}'s/^[0-9]*[.]\([0-9]*\).*/\1/p'$${nl}q$${nl}'}'$${nl}'c\'$${nl}0$${nl}q; \
	sed_extract_subminor='/^[0-9][0-9]*[.][0-9][0-9]*[.][0-9]/{'$${nl}'s/^[0-9]*[.][0-9]*[.]\([0-9]*\).*/\1/p'$${nl}q$${nl}'}'$${nl}'c\'$${nl}0$${nl}q; \
	$(WINDRES) \
	  "-DPACKAGE_VERSION_STRING=\\\"$(VERSION)\\\"" \
	  "-DPACKAGE_VERSION_MAJOR="`echo '$(VERSION)' | sed -n -e "$$sed_extract_major"` \
	  "-DPACKAGE_VERSION_MINOR="`echo '$(VERSION)' | sed -n -e "$$sed_extract_minor"` \
	  "-DPACKAGE_VERSION_SUBMINOR="`echo '$(VERSION)' | sed -n -e "$$sed_extract_subminor"` \
	  -i $(srcdir)/libintl.rc -o libintl.res.o --output-format=coff
libintl.res.lo: $(srcdir)/libintl.rc
	nlinit=`echo 'nl="'; echo '"'`; eval "$$nlinit"; \
	sed_extract_major='/^[0-9]/{'$${nl}'s/^\([0-9]*\).*/\1/p'$${nl}q$${nl}'}'$${nl}'c\'$${nl}0$${nl}q; \
	sed_extract_minor='/^[0-9][0-9]*[.][0-9]/{'$${nl}'s/^[0-9]*[.]\([0-9]*\).*/\1/p'$${nl}q$${nl}'}'$${nl}'c\'$${nl}0$${nl}q; \
	sed_extract_subminor='/^[0-9][0-9]*[.][0-9][0-9]*[.][0-9]/{'$${nl}'s/^[0-9]*[.][0-9]*[.]\([0-9]*\).*/\1/p'$${nl}q$${nl}'}'$${nl}'c\'$${nl}0$${nl}q; \
	$(LIBTOOL) --mode=compile --tag=RC $(RC) \
	  "-DPACKAGE_VERSION_STRING=\\\"$(VERSION)\\\"" \
	  "-DPACKAGE_VERSION_MAJOR="`echo '$(VERSION)' | sed -n -e "$$sed_extract_major"` \
	  "-DPACKAGE_VERSION_MINOR="`echo '$(VERSION)' | sed -n -e "$$sed_extract_minor"` \
	  "-DPACKAGE_VERSION_SUBMINOR="`echo '$(VERSION)' | sed -n -e "$$sed_extract_subminor"` \
	  -i $(srcdir)/libintl.rc -o libintl.res.lo --output-format=coff

ref-add.sed: $(srcdir)/ref-add.sin
	sed -e '/^#/d' -e 's/@''PACKAGE''@/mednafen/g' $(srcdir)/ref-add.sin > t-ref-add.sed
	mv t-ref-add.sed ref-add.sed
ref-del.sed: $(srcdir)/ref-del.sin
	sed -e '/^#/d' -e 's/@''PACKAGE''@/mednafen/g' $(srcdir)/ref-del.sin > t-ref-del.sed
	mv t-ref-del.sed ref-del.sed

INCLUDES = -I. -I$(srcdir) -I../include

libgnuintl.h: $(srcdir)/libgnuintl.h.in
	sed -e '/IN_LIBGLOCALE/d' \
	    -e 's,@''HAVE_POSIX_PRINTF''@,1,g' \
	    -e 's,@''HAVE_ASPRINTF''@,1,g' \
	    -e 's,@''HAVE_NEWLOCALE''@,1,g' \
	    -e 's,@''HAVE_SNPRINTF''@,1,g' \
	    -e 's,@''HAVE_WPRINTF''@,0,g' \
	  < $(srcdir)/libgnuintl.h.in \
	| if test 'no' = yes; then \
	    sed -e 's/extern \([^()]*\);/extern __declspec (dllimport) \1;/'; \
	  else \
	    cat; \
	  fi \
	| sed -e 's/extern \([^"]\)/extern LIBINTL_DLL_EXPORTED \1/' \
	      -e "/#define _LIBINTL_H/r $(srcdir)/export.h" \
	| sed -e 's,@''HAVE_VISIBILITY''@,1,g' \
	  > libgnuintl.h

libintl.h: $(srcdir)/libgnuintl.h.in
	sed -e '/IN_LIBGLOCALE/d' \
	    -e 's,@''HAVE_POSIX_PRINTF''@,1,g' \
	    -e 's,@''HAVE_ASPRINTF''@,1,g' \
	    -e 's,@''HAVE_NEWLOCALE''@,1,g' \
	    -e 's,@''HAVE_SNPRINTF''@,1,g' \
	    -e 's,@''HAVE_WPRINTF''@,0,g' \
	  < $(srcdir)/libgnuintl.h.in > libintl.h

charset.alias: $(srcdir)/config.charset
	$(SHELL) $(srcdir)/config.charset 'x86_64-apple-darwin17.4.0' > t-$@
	mv t-$@ $@

check: all

# We must not install the libintl.h/libintl.a files if we are on a
# system which has the GNU gettext() function in its C library or in a
# separate library.
# If you want to use the one which comes with this version of the
# package, you have to use `configure --with-included-gettext'.
install: install-exec install-data
install-exec: all
	if { test "$(PACKAGE)" = "gettext-runtime" || test "$(PACKAGE)" = "gettext-tools"; } \
	   && test 'yes' = yes; then \
	  $(mkdir_p) $(DESTDIR)$(libdir) $(DESTDIR)$(includedir); \
	  $(INSTALL_DATA) libintl.h $(DESTDIR)$(includedir)/libintl.h; \
	  $(LIBTOOL) --mode=install \
	    $(INSTALL_DATA) libintl.$la $(DESTDIR)$(libdir)/libintl.$la; \
	  if test "@RELOCATABLE@" = yes; then \
	    dependencies=`sed -n -e 's,^dependency_libs=\(.*\),\1,p' < $(DESTDIR)$(libdir)/libintl.la | sed -e "s,^',," -e "s,'\$$,,"`; \
	    if test -n "$$dependencies"; then \
	      rm -f $(DESTDIR)$(libdir)/libintl.la; \
	    fi; \
	  fi; \
	else \
	  : ; \
	fi
	if test "$(PACKAGE)" = "gettext-tools" \
	   && test 'yes' = no \
	   && test no != no; then \
	  $(mkdir_p) $(DESTDIR)$(libdir); \
	  $(LIBTOOL) --mode=install \
	    $(INSTALL_DATA) libgnuintl.$la $(DESTDIR)$(libdir)/libgnuintl.$la; \
	  rm -f $(DESTDIR)$(libdir)/preloadable_libintl.so; \
	  $(INSTALL_DATA) $(DESTDIR)$(libdir)/libgnuintl.so $(DESTDIR)$(libdir)/preloadable_libintl.so; \
	  $(LIBTOOL) --mode=uninstall \
	    rm -f $(DESTDIR)$(libdir)/libgnuintl.$la; \
	else \
	  : ; \
	fi
	if test 'yes' = yes; then \
	  if test no = no; then \
	    case 'darwin17.4.0' in \
	      darwin[56]*) \
	        need_charset_alias=true ;; \
	      darwin* | cygwin* | mingw* | pw32* | cegcc*) \
	        need_charset_alias=false ;; \
	      *) \
	        need_charset_alias=true ;; \
	    esac; \
	  else \
	    need_charset_alias=false; \
	  fi; \
	  if $$need_charset_alias; then \
	    $(mkdir_p) $(DESTDIR)$(libdir); \
	  fi; \
	  temp=$(DESTDIR)$(libdir)/t-charset.alias; \
	  dest=$(DESTDIR)$(libdir)/charset.alias; \
	  if test -f $(DESTDIR)$(libdir)/charset.alias; then \
	    orig=$(DESTDIR)$(libdir)/charset.alias; \
	    sed -f ref-add.sed $$orig > $$temp; \
	    $(INSTALL_DATA) $$temp $$dest; \
	    rm -f $$temp; \
	  else \
	    if $$need_charset_alias; then \
	      orig=charset.alias; \
	      sed -f ref-add.sed $$orig > $$temp; \
	      $(INSTALL_DATA) $$temp $$dest; \
	      rm -f $$temp; \
	    fi; \
	  fi; \
	  $(mkdir_p) $(DESTDIR)$(localedir); \
	  test -f $(DESTDIR)$(localedir)/locale.alias \
	    && orig=$(DESTDIR)$(localedir)/locale.alias \
	    || orig=$(srcdir)/locale.alias; \
	  temp=$(DESTDIR)$(localedir)/t-locale.alias; \
	  dest=$(DESTDIR)$(localedir)/locale.alias; \
	  sed -f ref-add.sed $$orig > $$temp; \
	  $(INSTALL_DATA) $$temp $$dest; \
	  rm -f $$temp; \
	else \
	  : ; \
	fi
install-data: all
	if test "$(PACKAGE)" = "gettext-tools"; then \
	  $(mkdir_p) $(DESTDIR)$(gettextsrcdir); \
	  $(INSTALL_DATA) VERSION $(DESTDIR)$(gettextsrcdir)/VERSION; \
	  $(INSTALL_DATA) ChangeLog.inst $(DESTDIR)$(gettextsrcdir)/ChangeLog; \
	  dists="COPYING.LIB-2.0 COPYING.LIB-2.1 $(DISTFILES.common)"; \
	  for file in $$dists; do \
	    $(INSTALL_DATA) $(srcdir)/$$file \
			    $(DESTDIR)$(gettextsrcdir)/$$file; \
	  done; \
	  chmod a+x $(DESTDIR)$(gettextsrcdir)/config.charset; \
	  dists="$(DISTFILES.generated)"; \
	  for file in $$dists; do \
	    if test -f $$file; then dir=.; else dir=$(srcdir); fi; \
	    $(INSTALL_DATA) $$dir/$$file \
			    $(DESTDIR)$(gettextsrcdir)/$$file; \
	  done; \
	  dists="$(DISTFILES.obsolete)"; \
	  for file in $$dists; do \
	    rm -f $(DESTDIR)$(gettextsrcdir)/$$file; \
	  done; \
	else \
	  : ; \
	fi

install-strip: install

install-dvi install-html install-info install-ps install-pdf:

installdirs:
	if { test "$(PACKAGE)" = "gettext-runtime" || test "$(PACKAGE)" = "gettext-tools"; } \
	   && test 'yes' = yes; then \
	  $(mkdir_p) $(DESTDIR)$(libdir) $(DESTDIR)$(includedir); \
	else \
	  : ; \
	fi
	if test "$(PACKAGE)" = "gettext-tools" \
	   && test 'yes' = no \
	   && test no != no; then \
	  $(mkdir_p) $(DESTDIR)$(libdir); \
	else \
	  : ; \
	fi
	if test 'yes' = yes; then \
	  if test no = no; then \
	    case 'darwin17.4.0' in \
	      darwin[56]*) \
	        need_charset_alias=true ;; \
	      darwin* | cygwin* | mingw* | pw32* | cegcc*) \
	        need_charset_alias=false ;; \
	      *) \
	        need_charset_alias=true ;; \
	    esac; \
	  else \
	    need_charset_alias=false; \
	  fi; \
	  if $$need_charset_alias; then \
	    $(mkdir_p) $(DESTDIR)$(libdir); \
	  fi; \
	  $(mkdir_p) $(DESTDIR)$(localedir); \
	else \
	  : ; \
	fi
	if test "$(PACKAGE)" = "gettext-tools"; then \
	  $(mkdir_p) $(DESTDIR)$(gettextsrcdir); \
	else \
	  : ; \
	fi

# Define this as empty until I found a useful application.
installcheck:

uninstall:
	if { test "$(PACKAGE)" = "gettext-runtime" || test "$(PACKAGE)" = "gettext-tools"; } \
	   && test 'yes' = yes; then \
	  rm -f $(DESTDIR)$(includedir)/libintl.h; \
	  $(LIBTOOL) --mode=uninstall \
	    rm -f $(DESTDIR)$(libdir)/libintl.$la; \
	else \
	  : ; \
	fi
	if test "$(PACKAGE)" = "gettext-tools" \
	   && test 'yes' = no \
	   && test no != no; then \
	  rm -f $(DESTDIR)$(libdir)/preloadable_libintl.so; \
	else \
	  : ; \
	fi
	if test 'yes' = yes; then \
	  if test -f $(DESTDIR)$(libdir)/charset.alias; then \
	    temp=$(DESTDIR)$(libdir)/t-charset.alias; \
	    dest=$(DESTDIR)$(libdir)/charset.alias; \
	    sed -f ref-del.sed $$dest > $$temp; \
	    if grep '^# Packages using this file: $$' $$temp > /dev/null; then \
	      rm -f $$dest; \
	    else \
	      $(INSTALL_DATA) $$temp $$dest; \
	    fi; \
	    rm -f $$temp; \
	  fi; \
	  if test -f $(DESTDIR)$(localedir)/locale.alias; then \
	    temp=$(DESTDIR)$(localedir)/t-locale.alias; \
	    dest=$(DESTDIR)$(localedir)/locale.alias; \
	    sed -f ref-del.sed $$dest > $$temp; \
	    if grep '^# Packages using this file: $$' $$temp > /dev/null; then \
	      rm -f $$dest; \
	    else \
	      $(INSTALL_DATA) $$temp $$dest; \
	    fi; \
	    rm -f $$temp; \
	  fi; \
	else \
	  : ; \
	fi
	if test "$(PACKAGE)" = "gettext-tools"; then \
	  for file in VERSION ChangeLog COPYING.LIB-2.0 COPYING.LIB-2.1 $(DISTFILES.common) $(DISTFILES.generated); do \
	    rm -f $(DESTDIR)$(gettextsrcdir)/$$file; \
	  done; \
	else \
	  : ; \
	fi

info dvi ps pdf html:

$(OBJECTS): ../include/config.h libgnuintl.h
bindtextdom.$lo dcgettext.$lo dcigettext.$lo dcngettext.$lo dgettext.$lo dngettext.$lo finddomain.$lo gettext.$lo intl-compat.$lo loadmsgcat.$lo localealias.$lo ngettext.$lo setlocale.$lo textdomain.$lo: $(srcdir)/gettextP.h $(srcdir)/gmo.h $(srcdir)/loadinfo.h
localename.$lo: $(srcdir)/gettextP.h
hash-string.$lo dcigettext.$lo loadmsgcat.$lo: $(srcdir)/hash-string.h
explodename.$lo l10nflist.$lo: $(srcdir)/loadinfo.h
dcigettext.$lo loadmsgcat.$lo plural.$lo plural-exp.$lo: $(srcdir)/plural-exp.h
dcigettext.$lo: $(srcdir)/eval-plural.h
localcharset.$lo: $(srcdir)/localcharset.h
bindtextdom.$lo dcigettext.$lo finddomain.$lo loadmsgcat.$lo localealias.$lo lock.$lo log.$lo: $(srcdir)/lock.h
localealias.$lo localcharset.$lo relocatable.$lo: $(srcdir)/relocatable.h
printf.$lo: $(srcdir)/printf-args.h $(srcdir)/printf-args.c $(srcdir)/printf-parse.h $(srcdir)/wprintf-parse.h $(srcdir)/xsize.h $(srcdir)/printf-parse.c $(srcdir)/vasnprintf.h $(srcdir)/vasnwprintf.h $(srcdir)/vasnprintf.c

# A bison-2.1 generated plural.c includes <libintl.h> if ENABLE_NLS.
PLURAL_DEPS_yes = libintl.h
PLURAL_DEPS_no =
plural.$lo: $(PLURAL_DEPS_yes)

tags: TAGS

TAGS: $(HEADERS) $(SOURCES)
	here=`pwd`; cd $(srcdir) && etags -o $$here/TAGS $(HEADERS) $(SOURCES)

ctags: CTAGS

CTAGS: $(HEADERS) $(SOURCES)
	here=`pwd`; cd $(srcdir) && ctags -o $$here/CTAGS $(HEADERS) $(SOURCES)

id: ID

ID: $(HEADERS) $(SOURCES)
	here=`pwd`; cd $(srcdir) && mkid -f$$here/ID $(HEADERS) $(SOURCES)


mostlyclean:
	rm -f *.a *.la *.o *.obj *.lo core core.*
	rm -f libgnuintl.h libintl.h charset.alias ref-add.sed ref-del.sed
	rm -f -r .libs _libs

clean: mostlyclean

distclean: clean
	rm -f Makefile ID TAGS
	if test "$(PACKAGE)" = "gettext-runtime" || test "$(PACKAGE)" = "gettext-tools"; then \
	  rm -f ChangeLog.inst $(DISTFILES.normal); \
	else \
	  : ; \
	fi

maintainer-clean: distclean
	@echo "This command is intended for maintainers to use;"
	@echo "it deletes files that may require special tools to rebuild."


# GNU gettext needs not contain the file `VERSION' but contains some
# other files which should not be distributed in other packages.
distdir = ../$(PACKAGE)-$(VERSION)/$(subdir)
dist distdir: Makefile
	if test "$(PACKAGE)" = "gettext-tools"; then \
	  : ; \
	else \
	  if test "$(PACKAGE)" = "gettext-runtime"; then \
	    additional="$(DISTFILES.gettext)"; \
	  else \
	    additional="$(DISTFILES.normal)"; \
	  fi; \
	  $(MAKE) $(DISTFILES.common) $(DISTFILES.generated) $$additional; \
	  for file in ChangeLog $(DISTFILES.common) $(DISTFILES.generated) $$additional; do \
	    if test -f $$file; then dir=.; else dir=$(srcdir); fi; \
	    cp -p $$dir/$$file $(distdir) || test $$file = Makefile.in || exit 1; \
	  done; \
	fi

Makefile: $(srcdir)/Makefile.in $(top_builddir)/config.status
	cd $(top_builddir) && $(SHELL) ./config.status
# This would be more efficient, but doesn't work any more with autoconf-2.57,
# when AC_CONFIG_FILES([intl/Makefile:somedir/Makefile.in]) is used.
#	cd $(top_builddir) && $(SHELL) ./config.status $(subdir)/$@

# Tell versions [3.59,3.63) of GNU make not to export all variables.
# Otherwise a system limit (for SysV at least) may be exceeded.
.NOEXPORT:
