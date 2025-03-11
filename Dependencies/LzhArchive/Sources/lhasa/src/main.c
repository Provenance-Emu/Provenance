/*

Copyright (c) 2011, 2012, Simon Howard

Permission to use, copy, modify, and/or distribute this software
for any purpose with or without fee is hereby granted, provided
that the above copyright notice and this permission notice appear
in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "lib/lha_arch.h"
#include "lha_reader.h"

#include "config.h"
#include "extract.h"
#include "list.h"

typedef enum {
	MODE_UNKNOWN,
	MODE_LIST,
	MODE_LIST_VERBOSE,
	MODE_CRC_CHECK,
	MODE_EXTRACT,
	MODE_PRINT
} ProgramMode;

static void help_page(char *progname)
{
	printf(
	PACKAGE_NAME " v" PACKAGE_VERSION " command line LHA tool  "
		"- Copyright (C) 2011-2023 Simon Howard\n"
	"usage: %s [-]{lvtxep[q{num}][finv]}[w=<dir>] archive_file [file...]\n"
	"commands:                          options:\n"
	" l,v List / Verbose List            f  Force overwrite (no prompt)\n"
	" t   Test file CRC in archive       i  Ignore directory path\n"
	" x,e Extract from archive           n  Perform dry run\n"
	" p   Print to stdout from archive   q{num}  Quiet mode\n"
	"                                    v  Verbose\n"
	"                                    w=<dir> Specify extract directory\n"
	, progname);

	exit(-1);
}

static int do_command(ProgramMode mode, char *filename,
                      LHAOptions *options,
                      char **filters, unsigned int num_filters)
{
	FILE *fstream;
	LHAInputStream *stream;
	LHAReader *reader;
	LHAFilter filter;
	int result;

	if (!strcmp(filename, "-")) {
		fstream = stdin;
	} else {
		fstream = fopen(filename, "rb");

		if (fstream == NULL) {
			fprintf(stderr, "LHa: Error: %s %s\n",
			                filename, strerror(errno));
			exit(-1);
		}
	}

	stream = lha_input_stream_from_FILE(fstream);
	reader = lha_reader_new(stream);
	lha_filter_init(&filter, reader, filters, num_filters);

	result = 1;

	switch (mode) {
		case MODE_LIST:
			list_file_basic(&filter, options, fstream);
			break;

		case MODE_LIST_VERBOSE:
			list_file_verbose(&filter, options, fstream);
			break;

		case MODE_CRC_CHECK:
			result = test_file_crc(&filter, options);
			break;

		case MODE_EXTRACT:
			result = extract_archive(&filter, options);
			break;

		case MODE_PRINT:
			result = print_archive(&filter, options);
			break;

		case MODE_UNKNOWN:
			break;
	}

	lha_reader_free(reader);
	lha_input_stream_free(stream);

	fclose(fstream);

	return result;
}

static void init_options(LHAOptions *options)
{
	options->overwrite_policy = LHA_OVERWRITE_PROMPT;
	options->quiet = 0;
	options->verbose = 0;
	options->dry_run = 0;
	options->extract_path = NULL;
	options->use_path = 1;
}

// Determine the program mode from the first character of the command
// argument.

static ProgramMode mode_for_char(char c)
{
	switch (c) {
		case 'l':
			return MODE_LIST;
		case 'v':
			return MODE_LIST_VERBOSE;
		case 't':
			return MODE_CRC_CHECK;
		case 'e':
		case 'x':
			return MODE_EXTRACT;
		case 'p':
			return MODE_PRINT;
		default:
			return MODE_UNKNOWN;
	}
}

// Parse the option flags from the command argument.

static int parse_options(char *arg, LHAOptions *options)
{
	for (; *arg != '\0'; ++arg) {
		switch (*arg) {
			// Force overwrite of existing files.
			case 'f':
				options->overwrite_policy = LHA_OVERWRITE_ALL;
				break;

			// -i option turns off paths for extract.
			case 'i':
				options->use_path = 0;
				break;

			// Dry run?
			case 'n':
				options->dry_run = 1;
				break;

			// Quiet mode parsing. The quiet 'level' can be
			// specified - if the level is omitted, level 2
			// is implied. All quiet mode options imply
			// -f (overwrite without confirmation).
			case 'q':
				if (arg[1] >= '0' && arg[1] <= '9') {
					++arg;
					options->quiet = *arg - '0';
				} else {
					options->quiet = 2;
				}
				options->overwrite_policy = LHA_OVERWRITE_ALL;
				break;

			// Verbose mode.
			case 'v':
				options->verbose = 1;
				break;

			// Specify extract directory: must be last option
			// specified. Optional '=' separator.
			case 'w':
				++arg;
				if (*arg == '=') {
					++arg;
				}
				options->extract_path = arg;
				arg += strlen(arg) - 1;
				break;

			default:
				return 0;
		}
	}

	return 1;
}

/**
 * Parse the command line options, initializing the options structure
 * used by the main program code.
 *
 * @param cmd        The 'command' argument (first command line option).
 * @param mode       Pointer to variable to store program mode.
 * @param options    Pointer to options structure to initialize.
 * @return           Non-zero if successful.
 */

static int parse_command_line(char *cmd, ProgramMode *mode,
                              LHAOptions *options)
{
	// Parse program mode argument. Initial '-' is ignored.

	if (*cmd == '-') {
		++cmd;
	}

	*mode = mode_for_char(*cmd);

	if (*mode == MODE_UNKNOWN) {
		return 0;
	}

	// Parse remaining options.

	if (!parse_options(cmd + 1, options)) {
		return 0;
	}

	return 1;
}

int main(int argc, char *argv[])
{
	ProgramMode mode;
	LHAOptions options;

#ifdef TEST_BUILD
	// When running tests, give output to stdout in binary mode;
	// on Windows, this gives the expected output (which was
	// constructed for Unix):

	lha_arch_set_binary(stdout);
#endif

	// Parse the command line options and run command.
	// As a shortcut, a single argument can be provided to list the
	// contents of an archive ("lha foo.lzh" == "lha l foo.lzh").

	init_options(&options);

	if (argc >= 3 && parse_command_line(argv[1], &mode, &options)) {
		return !do_command(mode, argv[2], &options,
		                   argv + 3, argc - 3);
	} else if (argc == 2) {
		return !do_command(MODE_LIST, argv[1], &options, NULL, 0);
	} else {
		help_page(argv[0]);
		return 0;
	}
}
