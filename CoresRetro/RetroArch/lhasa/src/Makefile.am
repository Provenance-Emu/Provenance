bin_PROGRAMS=lha
check_PROGRAMS=test-lha

SOURCE_FILES=                             \
	main.c                            \
	              options.h           \
	filter.c      filter.h            \
	list.c        list.h              \
	extract.c     extract.h           \
	safe.c        safe.h

lha_SOURCES=$(SOURCE_FILES)
lha_CFLAGS=$(MAIN_CFLAGS) -I$(top_builddir)/lib/public -I$(top_builddir) -I$(top_srcdir)/lib/public -I$(top_srcdir)
lha_LDADD=$(top_builddir)/lib/liblhasa.la

test_lha_SOURCES=$(SOURCE_FILES)
test_lha_CFLAGS=$(TEST_CFLAGS) -I$(top_builddir)/lib/public -I$(top_builddir) -I$(top_srcdir)/lib/public -I$(top_srcdir)
test_lha_LDADD=$(top_builddir)/lib/liblhasatest.a

clean-local:
	rm -f *.gcno *.gcda *.c.gcov
