noinst_LIBRARIES	+=	libzstd.a
libzstd_a_CFLAGS	=	@AM_CFLAGS@ @CFLAG_VISIBILITY@
libzstd_a_CPPFLAGS	=	-DZSTD_NO_TRACE=1 -DZSTD_HAVE_WEAK_SYMBOLS=0

libzstd_a_SOURCES	=	zstd/common/entropy_common.c zstd/common/error_private.c zstd/common/fse_decompress.c zstd/common/xxhash.c zstd/common/zstd_common.c	\
				zstd/decompress/huf_decompress.c zstd/decompress/zstd_ddict.c zstd/decompress/zstd_decompress_block.c zstd/decompress/zstd_decompress.c

mednafen_LDADD          +=      libzstd.a
mednafen_DEPENDENCIES   +=      libzstd.a

