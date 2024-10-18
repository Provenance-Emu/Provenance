SUBDIRS = public

lib_LTLIBRARIES=liblhasa.la
check_LIBRARIES=liblhasatest.a

EXTRA_DIST =                                            \
	bit_stream_reader.c                             \
	lh_new_decoder.c                                \
	pma_common.c                                    \
	tree_decode.c

SRC =                                                   \
	crc16.c                 crc16.h                 \
	ext_header.c            ext_header.h            \
	lha_arch_unix.c         lha_arch.h              \
	lha_arch_win32.c                                \
	lha_decoder.c           lha_decoder.h           \
	lha_endian.c            lha_endian.h            \
	lha_file_header.c       lha_file_header.h       \
	lha_input_stream.c      lha_input_stream.h      \
	lha_basic_reader.c      lha_basic_reader.h      \
	lha_reader.c                                    \
	macbinary.c             macbinary.h             \
	null_decoder.c                                  \
	lh1_decoder.c                                   \
	lh5_decoder.c                                   \
	lh6_decoder.c                                   \
	lh7_decoder.c                                   \
	lhx_decoder.c                                   \
	lk7_decoder.c                                   \
	lz5_decoder.c                                   \
	lzs_decoder.c                                   \
	pm1_decoder.c                                   \
	pm2_decoder.c

liblhasatest_a_CFLAGS=$(TEST_CFLAGS) -DALLOC_TESTING -I../test -g
liblhasatest_a_SOURCES=$(SRC) $(HEADER_FILES)

liblhasa_la_CFLAGS=$(MAIN_CFLAGS)
liblhasa_la_SOURCES=$(SRC) $(HEADER_FILES)
liblhasa_la_LDFLAGS=-no-undefined

clean-local:
	rm -f *.gcno *.gcda *.c.gcov
