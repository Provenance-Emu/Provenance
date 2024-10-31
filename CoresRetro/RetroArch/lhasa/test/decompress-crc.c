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

// Simple program that reads an archive, decompresses the first file
// it finds and prints the CRC and length of the decompressed data.
// These can then be compared against known good values.

#include <stdlib.h>
#include <string.h>

#include "crc32.h"
#include "lib/lha_arch.h"
#include "lha_reader.h"

static void decompress_file(LHAReader *reader)
{
	uint8_t buf[128];
	size_t total, bytes;
	uint32_t crc;

	total = 0;
	crc = 0;

	do {
		bytes = lha_reader_read(reader, buf, sizeof(buf));
		crc32_buf(&crc, buf, bytes);
		total += bytes;
	} while (bytes > 0);

	printf("crc: %08x\n", crc);
	printf("length: %i\n", (unsigned int) total);
}

int main(int argc, char *argv[])
{
	LHAInputStream *stream;
	LHAReader *reader;
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

	reader = lha_reader_new(stream);

	for (;;) {
		header = lha_reader_next_file(reader);

		if (header == NULL) {
			break;
		}

		if (!strcmp(header->compress_method, LHA_COMPRESS_TYPE_DIR)) {
			continue;
		}

		decompress_file(reader);
		break;
	}

	lha_reader_free(reader);
	lha_input_stream_free(stream);

	return 0;
}

