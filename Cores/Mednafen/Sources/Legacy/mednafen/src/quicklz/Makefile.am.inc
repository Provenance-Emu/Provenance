noinst_LIBRARIES	+=	libmdfnquicklz.a
libmdfnquicklz_a_CFLAGS	=	@AM_CFLAGS@ @NO_STRICT_ALIASING_FLAGS@ -Wno-shadow -Wno-unused-but-set-variable

libmdfnquicklz_a_SOURCES=	quicklz/quicklz.c

mednafen_LDADD          +=      libmdfnquicklz.a
mednafen_DEPENDENCIES   +=      libmdfnquicklz.a

