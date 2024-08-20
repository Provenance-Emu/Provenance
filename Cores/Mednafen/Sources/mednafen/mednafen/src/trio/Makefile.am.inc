noinst_LIBRARIES	+=	libtrio.a
libtrio_a_CFLAGS	=	@AM_CFLAGS@ @TRIO_CFLAGS@ @CFLAG_VISIBILITY@

libtrio_a_SOURCES 	= 	trio/trio.c trio/trionan.c trio/triostr.c

mednafen_LDADD 		+=	libtrio.a
mednafen_DEPENDENCIES	+=	libtrio.a

