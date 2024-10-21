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

// Simple program to read the headers from an .lzh file and dump
// the contents. These details can then be compared against a set
// of known good values.

#include <stdio.h>

#include "lib/lha_arch.h"
#include "lib/lha_basic_reader.h"

static void print_header(LHAFileHeader *header)
{
	if (header->path != NULL) {
		printf("path: %s\n", header->path);
	}
	if (header->filename != NULL) {
		printf("filename: %s\n", header->filename);
	}
	if (header->symlink_target != NULL) {
		printf("symlink_target: %s\n", header->symlink_target);
	}

	printf("compress_method: %s\n", header->compress_method);
	printf("compressed_length: %i\n", (int) header->compressed_length);
	printf("length: %i\n", (int) header->length);
	printf("header_level: %i\n", header->header_level);
	printf("os_type: %i", header->os_type);
	if (header->os_type != LHA_OS_TYPE_UNKNOWN) {
		printf(" ('%c')", header->os_type);
	}
	printf("\n");
	printf("crc: %04x\n", header->crc);

	if (header->timestamp != 0) {
		printf("timestamp: %i\n", header->timestamp);
	}
	if (LHA_FILE_HAVE_EXTRA(header, LHA_FILE_WINDOWS_TIMESTAMPS)) {
		printf("win_creation_time: %" PRIu64 "\n",
		       header->win_creation_time);
		printf("win_modification_time: %" PRIu64 "\n",
		       header->win_modification_time);
		printf("win_access_time: %" PRIu64 "\n",
		       header->win_access_time);
	}
	if (LHA_FILE_HAVE_EXTRA(header, LHA_FILE_UNIX_PERMS)) {
		printf("unix_perms: 0%o\n", header->unix_perms);
	}
	if (LHA_FILE_HAVE_EXTRA(header, LHA_FILE_OS9_PERMS)) {
		printf("os9_perms: 0%o\n", header->os9_perms);
	}
	if (LHA_FILE_HAVE_EXTRA(header, LHA_FILE_UNIX_UID_GID)) {
		printf("unix_uid: %i\n", header->unix_uid);
		printf("unix_gid: %i\n", header->unix_gid);
	}
	if (header->unix_group != NULL) {
		printf("unix_group: %s\n", header->unix_group);
	}
	if (header->unix_username != NULL) {
		printf("unix_username: %s\n", header->unix_username);
	}
	if (LHA_FILE_HAVE_EXTRA(header, LHA_FILE_COMMON_CRC)) {
		printf("common_crc: %04x\n", header->common_crc);
	}
}

int main(int argc, char *argv[])
{
	LHAInputStream *stream;
	LHABasicReader *reader;
	LHAFileHeader *header;

	if (argc < 2) {
		printf("Usage: %s <filename>\n", argv[0]);
		exit(-1);
	}

	// Give output in binary mode for cross-platform consistency,
	// so that it can be compared correctly on Windows.

	lha_arch_set_binary(stdout);

	stream = lha_input_stream_from(argv[1]);

	if (stream == NULL) {
		fprintf(stderr, "Failed to open '%s'\n", argv[1]);
		exit(-1);
	}

	reader = lha_basic_reader_new(stream);

	for (;;) {
		header = lha_basic_reader_next_file(reader);

		if (header == NULL) {
			break;
		}

		print_header(header);
		printf("--\n");
	}

	lha_basic_reader_free(reader);
	lha_input_stream_free(stream);

	return 0;
}

