AC_INIT([Lhasa],[0.4.0],[fraggle@gmail.com],[lhasa])
AC_CONFIG_AUX_DIR(autotools)

AM_INIT_AUTOMAKE([no-define])
LT_INIT

m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

AC_PROG_CC
AC_PROG_CXX
AM_PROG_CC_C_O
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_CONFIG_MACRO_DIR([m4])

if [[ "$GCC" = "yes" ]]; then
	is_gcc=true
else
	is_gcc=false
fi

TEST_CFLAGS="-DTEST_BUILD"

# Turn on all warnings for gcc.  Turn off optimisation for the test build.

if $is_gcc; then
	WARNINGS="-Wall -Wsign-compare"
	CFLAGS="$CFLAGS $WARNINGS"
	TEST_CFLAGS="$TEST_CFLAGS $WARNINGS -O0"
fi

# Support for coverage analysis via gcov:

coverage=false
AC_ARG_ENABLE(coverage,
[  --enable-coverage       Enable coverage testing. ],
[ coverage=true ])

if $coverage; then
        if $is_gcc; then
                TEST_CFLAGS="$TEST_CFLAGS -fprofile-arcs -ftest-coverage"
        else
                AC_MSG_ERROR([Can only enable coverage when using gcc.])
        fi
fi

AM_CONDITIONAL(BUILD_COVERAGE, $coverage)

# Support for running test cases using valgrind:

use_valgrind=false
AC_ARG_ENABLE(valgrind,
[  --enable-valgrind       Use valgrind when running unit tests. ],
[ use_valgrind=true ])

if [[ "$use_valgrind" = "true" ]]; then
        AC_CHECK_PROG(HAVE_VALGRIND, valgrind, yes, no)

        if [[ "$HAVE_VALGRIND" = "no" ]]; then
                AC_MSG_ERROR([Valgrind not found in PATH. ])
        fi
fi

AM_CONDITIONAL(USE_VALGRIND, $use_valgrind)

# Save the default CFLAGS and clear them, so that the test build
# of the library doesn't get the optimisation flags.

MAIN_CFLAGS="$CFLAGS"
CFLAGS=""

AC_SUBST(MAIN_CFLAGS)
AC_SUBST(TEST_CFLAGS)
AC_SUBST(ac_aux_dir)

AC_CONFIG_HEADERS([config.h:config.hin])

AC_CONFIG_FILES([
    liblhasa.pc
    rpm.spec
    Makefile
    doc/Makefile
    lib/Makefile
    lib/public/Makefile
    pkg/Makefile
    pkg/config.make
    src/Makefile
    test/Makefile
])

AC_OUTPUT
