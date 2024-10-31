#
# Copyright (c) 2011, 2012, Simon Howard
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose with or without fee is hereby granted, provided
# that the above copyright notice and this permission notice appear
# in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
# NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
#
# This file contains common definitions for use across the
# different tests.


# Fail when a command fails:

set -eu

# set up a temporary directory within which tests are to be run
wd=$(mktemp -dt lhasa-test.XXXXXX)
trap "rmdir '$wd'" INT EXIT

# Some of the test output is time zone-dependent, and output (eg.
# from 'lha l') can be different in different time zones. Use the
# TZ environment variable to force the behavior to the London
# time zone.

TZ=Europe/London
export TZ

# When listing files, the list output (eg. from 'lha l') can vary
# depending on the date. Files less than 6 months old show the time in
# addition to the date, whereas after 6 months this is replaced by the
# year instead for disambiguation reasons.
# Unfortunately this functionality means that some tests can break as
# the date changes. So run the tests using a fixed date (2012-05-01)
# for repeatability.

TEST_NOW_TIME=1335830400
export TEST_NOW_TIME

# Expected result of invoking the lha command.

SUCCESS_EXPECTED=true

# Is this a Cygwin build?

if uname -s | grep -qi cygwin; then
	is_cygwin=true
else
	is_cygwin=false
fi

build_arch=$(./build-arch)

# Location of tests and the test-build version of the lha tool:

test_base="$PWD"

# Get the path to a test archive file.

test_arc_file() {
	filename=$1

	if $is_cygwin; then
		cygpath -w "$test_base/archives/$filename"
	else
		echo "$test_base/archives/$filename"
	fi
}

# Wrapper command to invoke the test-lha tool and print an error
# if the command exits with a failure.

test_lha() {
	local test_binary="$test_base/../src/test-lha"

	if [ "$build_arch" = "windows" ]; then
		test_binary="$test_base/../src/test-lha.exe"
	fi

	if $SUCCESS_EXPECTED; then
		if ! "$test_binary" "$@"; then
			fail "Command failed: lha $*"
		fi
	else
		if "$test_binary" "$@"; then
			fail "Command succeeded, should have failed: lha $*"
		fi
	fi
}

# These options are used to run the Unix LHA tool to gather output
# for comparison. When GATHER=true, canonical output is gathered.

LHA_TOOL=/usr/bin/lha
GATHER=false
#GATHER=true

# Exit with failure with an error message.

fail() {
	for d in "$@"; do
		echo "$d"
	done >&2
	exit 1
}

# There doesn't seem to be a portable way to do this in shell. Sigh.

if stat -c "%Y" / >/dev/null 2>&1; then
	STAT_COMMAND_TYPE="GNU"
else
	STAT_COMMAND_TYPE="BSD"
fi

# Read file modification time.

file_mod_time() {
	if [ $STAT_COMMAND_TYPE = "GNU" ]; then
		stat -c "%Y" "$@"
	else
		stat -f "%m" "$@"
	fi
}

# Read file permissions.

file_perms() {
	if [ $STAT_COMMAND_TYPE = "GNU" ]; then
		stat -c "%a" "$@"
	else
		stat -f "%p" "$@"
	fi
}

# Swiss Army Knife-function to process the -hdr files containing data on
# the archives. Can be used in three modes:
#
# get_file_data archive.lzh
#   - Prints filenames of the files stored in the specified archive.
# get_file_data archive.lzh path/file
#   - Gets the values for the specified archived file, in the form:
#        var: value
# get_file_data archive.lzh path/file var
#   - Prints the value of the specified value for the specified file.

get_file_data() {
	local archive_file=$1
	local target=
	local var=

	if [ $# -gt 1 ]; then
		target=$2
	fi
	if [ $# -gt 2 ]; then
		var=$3
	fi

	awk -v target="$target" -v var="$var" -- '
		BEGIN {
			FS = ": "
		}
		/^--/ {
			if (target == "") {
				print path filename
			}
			path = ""
			filename = ""
			next
		}
		/^path:/ {
			path = $2
			next
		}
		/^filename:/ {
			filename = $2
			next
		}
		target == path filename {
			if (var == "") {
				print $0
			} else if ($1 == var) {
				print $2
				exit 0
			}
		}
	' < "$test_base/output/$archive_file-hdr.txt"
}

