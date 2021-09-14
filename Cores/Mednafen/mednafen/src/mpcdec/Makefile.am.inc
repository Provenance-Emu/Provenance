noinst_LIBRARIES 	+=	libmpcdec.a
libmpcdec_a_CFLAGS	=	@AM_CFLAGS@ @CFLAG_VISIBILITY@
libmpcdec_a_CPPFLAGS	=	-DMPC_FIXED_POINT=1

libmpcdec_a_SOURCES = mpcdec/huffman.c mpcdec/mpc_decoder.c mpcdec/mpc_reader.c \
        mpcdec/requant.c mpcdec/streaminfo.c mpcdec/synth_filter.c mpcdec/mpc_bits_reader.c mpcdec/mpc_demux.c \
	mpcdec/crc32.c

mednafen_LDADD          +=	libmpcdec.a
mednafen_DEPENDENCIES   +=	libmpcdec.a

