noinst_LIBRARIES	+=	libvorbisidec.a
libvorbisidec_a_CFLAGS	=	@AM_CFLAGS@ @CFLAG_VISIBILITY@ -Wno-shadow -Wno-unused
libvorbisidec_a_CPPFLAGS=	-I$(srcdir)/tremor

libvorbisidec_a_SOURCES = tremor/mdct.c tremor/block.c tremor/window.c \
                        tremor/synthesis.c tremor/info.c \
                        tremor/floor1.c tremor/floor0.c tremor/vorbisfile.c \
                        tremor/res012.c tremor/mapping0.c tremor/registry.c tremor/codebook.c \
			tremor/sharedbook.c tremor/framing.c tremor/bitwise.c

mednafen_LDADD          +=      libvorbisidec.a
mednafen_DEPENDENCIES   +=      libvorbisidec.a

