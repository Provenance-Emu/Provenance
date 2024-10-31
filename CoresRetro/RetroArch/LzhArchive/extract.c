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
// Local Change: Change special character to UTF8 range / Reset Timestamp

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include "lib/lha_arch.h"

#include "extract.h"
#include "safe.h"
#include "utf8.h"
// Maximum number of dots in progress output:

#define MAX_PROGRESS_LEN 58

typedef struct {
	int invoked;
	LHAFileHeader *header;
	LHAOptions *options;
	char *filename;
	char *operation;
} ProgressCallbackData;

// Given a file header structure, get the path to extract to.
// Returns a newly allocated string that must be free()d.

static char *file_full_path(LHAFileHeader *header, LHAOptions *options)
{
	size_t len;
	char *result;
	char *p;

	// Full path, or filename only?

	len = 0;

	if (options->extract_path != NULL) {
		len += strlen(options->extract_path) + 1;
	}

	if (options->use_path && header->path != NULL) {
		len += strlen(header->path);
	}

	if (header->filename != NULL) {
		len += strlen(header->filename);
	}

	result = malloc(len + 1);

	if (result == NULL) {
		// TODO?
		exit(-1);
	}

	result[0] = '\0';

	if (options->extract_path != NULL) {
		strcat(result, options->extract_path);
		strcat(result, "/");
	}

	// Add path. If it is an absolute path (contains a leading '/')
	// then skip over the leading '/' to make it a relative path.
	// This prevents the possibility of a security threat with a
	// malicious archive that might try to write to arbitrary
	// filesystem locations.
	// It also removes the double '/' when using the -w option.

	if (options->use_path && header->path != NULL) {
		p = header->path;
		while (*p == '/') {
			++p;
		}
		strcat(result, p);
	}

	// The filename header field might conceivably try to include
	// a path separator as well, so skip over any leading '/'
	// here too.

	if (header->filename != NULL) {
		p = header->filename;
		while (*p == '/') {
			++p;
		}
		strcat(result, p);
	}

	return result;
}

static void print_filename(char *filename, char *status)
{
	printf("\r");
	safe_printf("%s", filename);
	printf("\t- %s  ", status);
}

static void print_filename_brief(char *filename)
{
	printf("\r");
	safe_printf("%s :", filename);
}

// Callback function invoked during decompression progress.

static void progress_callback(unsigned int block,
                              unsigned int num_blocks,
                              void *data)
{
	ProgressCallbackData *progress = data;
	unsigned int factor;
	unsigned int i;

	progress->invoked = 1;

	// If the quiet mode options are specified, print a limited amount
	// of information without a progress bar (level 1) or no message
	// at all (level 2).

	if (progress->options->quiet >= 2) {
		return;
	} else if (progress->options->quiet == 1) {
		if (block == 0) {
			print_filename_brief(progress->filename);
			fflush(stdout);
		}

		return;
	}

	// Scale factor for blocks, so that the line is never too long.  When
	// MAX_PROGRESS_LEN is exceeded, the length is halved (factor=2), then
	// progressively larger scale factors are applied.

	factor = 1 + (num_blocks / MAX_PROGRESS_LEN);
	num_blocks = (num_blocks + factor - 1) / factor;

	// First call to specify number of blocks?

	if (block == 0) {
		print_filename(progress->filename, progress->operation);

		for (i = 0; i < num_blocks; ++i) {
			printf(".");
		}

		print_filename(progress->filename, progress->operation);
	} else if (((block + factor - 1) % factor) == 0) {
		// Otherwise, signal progress:

		printf("o");
	}

	fflush(stdout);
}

// Print a line to stdout describing a symlink.

static void print_symlink_line(char *src, char *dest)
{
	safe_printf("Symbolic Link %s -> %s", src, dest);
	printf("\n");
}

// Perform CRC check of an archived file.

static int test_archived_file_crc(LHAReader *reader,
                                  LHAFileHeader *header,
                                  LHAOptions *options)
{
	ProgressCallbackData progress;
	char *filename;
	int success;

	filename = file_full_path(header, options);

	if (options->dry_run) {
		if (strcmp(header->compress_method,
		           LHA_COMPRESS_TYPE_DIR) != 0) {
			safe_printf("VERIFY %s", filename);
			printf("\n");
		}

		free(filename);
		return 1;
	}

	progress.invoked = 0;
	progress.operation = "Testing  :";
	progress.options = options;
	progress.filename = filename;
	progress.header = header;

	success = lha_reader_check(reader, progress_callback, &progress);

	if (progress.invoked && options->quiet < 2) {
		if (success) {
			print_filename(filename, "Tested");
			printf("\n");
		} else {
			print_filename(filename, "CRC error");
			printf("\n");
		}

		fflush(stdout);
	}

	if (!success) {
		// TODO: Exit with error
	}

	free(filename);

	return success;
}

// Check that the specified directory exists, and create it if it
// does not.

static int check_parent_directory(char *path)
{
	LHAFileType file_type;

	file_type = lha_arch_exists(path);

	switch (file_type) {

		case LHA_FILE_DIRECTORY:
			// Already exists.
			break;

		case LHA_FILE_NONE:
			// Create the missing directory:

			if (!lha_arch_mkdir(path, 0755)) {
				fprintf(stderr,
				        "Failed to create parent directory %s\n",
				        path);
				return 0;
			}
			break;

		case LHA_FILE_FILE:
			fprintf(stderr, "Parent path %s is not a directory!\n",
			        path);
			return 0;

		case LHA_FILE_ERROR:
			fprintf(stderr, "Failed to stat %s\n", path);
			return 0;
	}

	return 1;
}

// Given a filename, create its parent directories as necessary.

static int make_parent_directories(char *orig_path)
{
	int result;
	char *p;
	char *path;

	result = 1;

	// Duplicate the path and strip off any trailing '/'s:

	path = strdup(orig_path);

	if (path == NULL) {
		exit(-1);
	}

	p = path + strlen(path) - 1;

	while (p >= path && *p == '/') {
		*p = '\0';
		--p;
	}

	// Iterate through the string, finding each path separator. At
	// each place, temporarily chop off the end of the path to get
	// each parent directory in turn.

	for (p = path; *p == '/'; ++p);

	for (;;) {
		p = strchr(p, '/');

		if (p == NULL) {
			break;
		}

		*p = '\0';

		// Check if this parent directory exists and create it:

		if (!check_parent_directory(path)) {
			result = 0;
			break;
		}

		// Restore path separator and advance to the next path.

		*p = '/';
		++p;
	}

	free(path);

	return result;
}

// Prompt the user with a message, and return the first character of
// the typed response.

static char prompt_user(char *message)
{
	char result;
	int c;

	fprintf(stderr, "%s", message);
	fflush(stderr);

	// Read characters until a newline is found, saving the first
	// character entered.

	result = 0;

	do {
		c = getchar();

		if (c < 0) {
			exit(-1);
		}

		if (result == 0) {
			result = c;
		}
	} while (c != '\n');

	return result;
}

// A file to be extracted already exists. Apply the overwrite policy
// to decide whether to overwrite the existing file, prompting the
// user if necessary.

static int confirm_file_overwrite(char *filename, LHAOptions *options)
{
	char response;

	switch (options->overwrite_policy) {
		case LHA_OVERWRITE_PROMPT:
			break;
		case LHA_OVERWRITE_SKIP:
			return 0;
		case LHA_OVERWRITE_ALL:
			return 1;
	}

	for (;;) {
		safe_fprintf(stderr, "%s ", filename);

		response = prompt_user("OverWrite ?(Yes/[No]/All/Skip) ");

		switch (tolower((unsigned int) response)) {
			case 'y':
				return 1;
			case 'n':
			case '\n':
				return 0;
			case 'a':
				options->overwrite_policy = LHA_OVERWRITE_ALL;
				return 1;
			case 's':
				options->overwrite_policy = LHA_OVERWRITE_SKIP;
				return 0;
			default:
				break;
		}
	}

	return 0;
}

// Check if the file pointed to by the specified header exists.

static int file_exists(char *filename)
{
	LHAFileType file_type;

	file_type = lha_arch_exists(filename);

	if (file_type == LHA_FILE_ERROR) {
		fprintf(stderr, "Failed to read file type of '%s'\n", filename);
		exit(-1);
	}

	return file_type != LHA_FILE_NONE;
}

// Extract an archived file.

static int extract_archived_file(LHAReader *reader,
                                 LHAFileHeader *header,
                                 LHAOptions *options)
{
	ProgressCallbackData progress;
	char *filename;
	int success;
	int is_dir, is_symlink;
    
    // Local Change: Change special character to UTF8 range
    u8_unescape(header->filename, strlen(header->filename), header->filename);
    int is_ext=0;
    for( int i = 0; i < strlen(header->filename); ++i ) {
        if (header->filename[i] == '.') {
            is_ext = 1;
        } else if (is_ext) {
            header->filename[i] = tolower(header->filename[i]);
        }
    }
    header->timestamp=time(NULL);
    
	filename = file_full_path(header, options);
	is_symlink = header->symlink_target != NULL;
	is_dir = !strcmp(header->compress_method, LHA_COMPRESS_TYPE_DIR)
	      && !is_symlink;

	// If a file already exists with this name, confirm overwrite.

	if (!is_dir && !is_symlink && file_exists(filename)
	 && !confirm_file_overwrite(filename, options)) {
		if (options->overwrite_policy == LHA_OVERWRITE_SKIP) {
			safe_printf("%s : Skipped...", filename);
			printf("\n");
		}
		free(filename);
		return 1;
	}

	// No need to extract directories if use_path is disabled.

	if (!options->use_path && is_dir) {
		free(filename);
		return 1;
	}

	// Create parent directories for file:

	if (!make_parent_directories(filename)) {
		free(filename);
		return 0;
	}

	progress.invoked = 0;
	progress.operation = "Melting  :";
	progress.options = options;
	progress.header = header;
	progress.filename = filename;

	success = lha_reader_extract(reader, filename,
	                             progress_callback, &progress);

	if (!lha_reader_current_is_fake(reader) && options->quiet < 2) {
		if (progress.invoked) {
			if (success) {
				print_filename(filename, "Melted");
				printf("\n");
			} else {
				print_filename(filename, "Failure");
				printf("\n");
			}
		} else if (is_symlink) {
			print_symlink_line(filename, header->symlink_target);
		}

		fflush(stdout);
	}

	if (!success) {
		// TODO: Exit with error
	}

	free(filename);

	return success;
}

// lha -t command.

int test_file_crc(LHAFilter *filter, LHAOptions *options)
{
	int result;

	result = 1;

	for (;;) {
		LHAFileHeader *header;

		header = lha_filter_next_file(filter);

		if (header == NULL) {
			break;
		}

		if (!test_archived_file_crc(filter->reader, header, options)) {
			result = 0;
		}
	}

	return result;
}

// lha -en / -xn / -pn:
// Simulate extracting an archive file, but just print the operations
// that would have been performed to stdout.

static int extract_archive_dry_run(LHAFilter *filter, LHAOptions *options)
{
	char *filename;
	int result;

	result = 1;

	for (;;) {
		LHAFileHeader *header;

		header = lha_filter_next_file(filter);

		if (header == NULL) {
			break;
		}

		filename = file_full_path(header, options);

		// Every line begins the same - "EXTRACT filename..."

		safe_printf("EXTRACT %s", filename);

		// After the filename we might print something extra.
		// The message if we have an existing file is weird, but this
		// is just accurately duplicating what the Unix LHA tool says.
		// The symlink handling is particularly odd - they are treated
		// as directories (a bleed-through of the way in which
		// symlinks are stored).

		if (header->symlink_target != NULL) {
			safe_printf("|%s (directory)", header->symlink_target);
		} else if (!strcmp(header->compress_method,
		                   LHA_COMPRESS_TYPE_DIR)) {
			safe_printf(" (directory)");
		} else if (file_exists(filename)) {
			safe_printf(" but file is exist.");
		}
		printf("\n");

		free(filename);
	}

	return result;
}

// lha -e / -x

int extract_archive(LHAFilter *filter, LHAOptions *options)
{
	int result;

	if (options->dry_run) {
		return extract_archive_dry_run(filter, options);
	}

	result = 1;

	for (;;) {
		LHAFileHeader *header;

		header = lha_filter_next_file(filter);

		if (header == NULL) {
			break;
		}

		if (!extract_archived_file(filter->reader, header, options)) {
			result = 0;
		}
	}

	return result;
}

// Dump contents of the current file from the specified reader to stdout.

static int print_archived_file(LHAReader *reader)
{
	char buf[512];
	size_t bytes;

	for (;;) {
		bytes = lha_reader_read(reader, buf, sizeof(buf));
		if (bytes <= 0) {
			break;
		}

		if (fwrite(buf, 1, bytes, stdout) < bytes) {
			return 0;
		}
	}

	return 1;
}

// lha -p

int print_archive(LHAFilter *filter, LHAOptions *options)
{
	LHAFileHeader *header;
	int is_normal_file;
	char *full_path;

	// As a weird quirk of Unix LHA, lha -pn is equivalent to lha -en:

	if (options->dry_run) {
		return extract_archive_dry_run(filter, options);
	}

	for (;;) {
		header = lha_filter_next_file(filter);

		if (header == NULL) {
			break;
		}

		is_normal_file = strcmp(header->compress_method,
		                        LHA_COMPRESS_TYPE_DIR) != 0;

		// Print "header" before the file containing the filename.
		// For normal files this is a three line separator.
		// Symlinks get shown in the same way as during extract.
		// Directories are ignored.

		if (options->quiet < 2) {
			full_path = file_full_path(header, options);

			if (header->symlink_target != NULL) {
				print_symlink_line(full_path,
				                   header->symlink_target);
			} else if (is_normal_file) {
				printf("::::::::\n");
				safe_printf("%s", full_path);
				printf("\n::::::::\n");
			}

			free(full_path);
		}

		// If this is a normal file, dump the contents to stdout.

		if (is_normal_file && !print_archived_file(filter->reader)) {
			return 0;
		}
	}

	return 1;
}
