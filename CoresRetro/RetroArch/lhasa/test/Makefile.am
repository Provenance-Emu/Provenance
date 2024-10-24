
AM_CFLAGS=$(TEST_CFLAGS) -I$(top_builddir)/lib/public -I$(top_builddir) -g -I$(top_srcdir)/lib/public -I$(top_srcdir)
LDADD=$(top_builddir)/lib/liblhasatest.a libtestframework.a

COMPILED_TESTS=                       \
	test-crc16                    \
	test-basic-reader             \
	test-decoder

UNCOMPILED_TESTS=                     \
	test-decompress               \
	test-file-headers             \
	test-list-output              \
	test-crc-output               \
	test-print                    \
	test-dry-run                  \
	test-extract

EXTRA_DIST=                           \
	archives                      \
	compressed                    \
	output                        \
	test_common.sh                \
	$(UNCOMPILED_TESTS)

TESTS=$(COMPILED_TESTS) $(UNCOMPILED_TESTS)

EXTRA_PROGRAMS=fuzzer ghost-tester
SUPPORT_COMMANDS = \
	dump-headers decompress-crc build-arch string-replace
check_PROGRAMS=$(COMPILED_TESTS) $(SUPPORT_COMMANDS)
check_LIBRARIES=libtestframework.a

$(TEST_LOGS): $(TESTS) $(SUPPORT_COMMANDS) ../src/test-lha

libtestframework_a_SOURCES=     \
	crc32.c crc32.h

clean-local:
	rm -f *.gcno *.gcda *.c.gcov

if BUILD_COVERAGE

# Delete .gcda files before running tests.

check-am: check-prerun

check-prerun:
	@rm -f $(top_builddir)/lib/*.gcda   \
	       $(top_builddir)/src/*.gcda   \
	       $(top_builddir)/test/*.gcda

# Display coverage summary after running tests.

check: report-coverage

report-coverage: check-am
	@cd $(top_builddir); ./gencov lib/*.c src/*.c

endif

fuzzer_SOURCES = fuzzer.c
build_arch_SOURCES = build-arch.c
dump_headers_SOURCES = dump-headers.c
decompress_crc_SOURCES = decompress-crc.c
ghost_tester_SOURCES = ghost-tester.c
string_replace_SOURCES = string-replace.c

