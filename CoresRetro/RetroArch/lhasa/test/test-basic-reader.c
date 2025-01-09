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

#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "lib/lha_basic_reader.h"
#include "crc32.h"

static LHABasicReader *reader_for_file(char *filename, LHAInputStream **stream)
{
	LHABasicReader *reader;

	*stream = lha_input_stream_from(filename);

	assert(*stream != NULL);

	reader = lha_basic_reader_new(*stream);
	assert(reader != NULL);

	return reader;
}

static void test_create_free(void)
{
	LHAInputStream *stream;
	LHABasicReader *reader;
	uint8_t buf[16];

	reader = reader_for_file("archives/lha213/lh5.lzh", &stream);

	// Sensible start conditions:

	assert(lha_basic_reader_curr_file(reader) == NULL);
	assert(lha_basic_reader_decode(reader) == NULL);
	assert(lha_basic_reader_read_compressed(reader, buf, sizeof(buf)) == 0);

	lha_basic_reader_free(reader);
	lha_input_stream_free(stream);
}

// Check that the specified file contains an archived file with the
// specified name.

static void check_directory_for(char *filename, char *archived)
{
	LHAInputStream *stream;
	LHABasicReader *reader;
	LHAFileHeader *header;
	uint8_t buf[16];

	reader = reader_for_file(filename, &stream);

	// Should be a single file:

	header = lha_basic_reader_next_file(reader);
	assert(header != NULL);
	assert(!strcmp(header->filename, archived));

	assert(lha_basic_reader_curr_file(reader) == header);

	// Only one file.

	assert(lha_basic_reader_next_file(reader) == NULL);
	assert(lha_basic_reader_curr_file(reader) == NULL);

	// Can't read at end of file.

	assert(lha_basic_reader_read_compressed(reader, buf, sizeof(buf)) == 0);
	assert(lha_basic_reader_decode(reader) == NULL);

	lha_basic_reader_free(reader);
	lha_input_stream_free(stream);
}

static void test_read_directory(void)
{
	check_directory_for("archives/larc333/lz4.lzs",       "gpl-2.gz");
	check_directory_for("archives/larc333/lz5.lzs",       "gpl-2");

	check_directory_for("archives/lha213/lh0.lzh",        "gpl-2.gz");
	check_directory_for("archives/lha213/lh5.lzh",        "gpl-2");

	check_directory_for("archives/lha255e/lh0.lzh",       "gpl-2.gz");
	check_directory_for("archives/lha255e/lh5.lzh",       "gpl-2");

	check_directory_for("archives/lha_amiga_122/lh0.lzh", "gpl-2.gz");
	check_directory_for("archives/lha_amiga_122/lh1.lzh", "gpl-2");
	check_directory_for("archives/lha_amiga_122/lh4.lzh", "gpl-2");
	check_directory_for("archives/lha_amiga_122/lh5.lzh", "gpl-2");
	check_directory_for("archives/lha_amiga_212/lh1.lzh", "gpl-2");
	check_directory_for("archives/lha_amiga_212/lh6.lzh", "gpl-2");

	check_directory_for("archives/lha_unix114i/h1_lh0.lzh", "gpl-2.gz");
	check_directory_for("archives/lha_unix114i/h1_lh5.lzh", "gpl-2");
	check_directory_for("archives/lha_unix114i/h1_lh6.lzh", "gpl-2");
	check_directory_for("archives/lha_unix114i/h1_lh7.lzh", "gpl-2");

	check_directory_for("archives/lharc113/lh0.lzh",      "gpl-2.gz");
	check_directory_for("archives/lharc113/lh1.lzh",      "gpl-2");

	check_directory_for("archives/pmarc2/pm0.pma",        "gpl-2.gz");
	check_directory_for("archives/pmarc2/pm2.pma",        "gpl-2.");
}

static void test_read_sfx(void)
{
	check_directory_for("archives/larc333/sfx.com",       "gpl-2.gz");
	check_directory_for("archives/lha213/sfx.exe",        "gpl-2");
	check_directory_for("archives/lha255e/sfx.exe",       "gpl-2");
	check_directory_for("archives/lha_amiga_122/sfx.run", "gpl-2");
	check_directory_for("archives/lharc113/sfx.com",      "gpl-2");
	check_directory_for("archives/lharc_atari_313a/sfx.tos", "gpl2");
	check_directory_for("archives/pmarc2/sfx.com",        "gpl-2.");
}

// Check CRC of compressed data.

static void check_crc_for(char *filename, uint32_t expected_crc,
                          size_t expected_len)
{
	LHAInputStream *stream;
	LHABasicReader *reader;
	LHAFileHeader *header;
	uint8_t buf[16];
	uint32_t crc;
	size_t len;

	reader = reader_for_file(filename, &stream);

	// Get the first archived file:

	header = lha_basic_reader_next_file(reader);
	assert(header != NULL);

	// Read all the compressed data:

	crc = 0; len = 0;

	for (;;) {
		size_t count;

		count = lha_basic_reader_read_compressed(reader, buf,
		                                         sizeof(buf));

		if (count == 0) {
			break;
		}

		len += count;

		crc32_buf(&crc, buf, count);
	}

	// Check final CRC / length:

	assert(crc == expected_crc);
	assert(len == expected_len);

	lha_basic_reader_free(reader);
	lha_input_stream_free(stream);
}

static void test_read_compressed(void)
{
	check_crc_for("archives/larc333/lz5.lzs",  0x2c1539b5, 8480);
	check_crc_for("archives/lha213/lh0.lzh",   0xe4690583, 6829);
	check_crc_for("archives/lha213/lh5.lzh",   0x45b943c8, 7004);

	check_crc_for("archives/lha213/sfx.exe",   0x45b943c8, 7004);
	check_crc_for("archives/pmarc2/sfx.com",   0x3751177e, 7098);
}

static void check_decode_for(char *filename)
{
	LHAInputStream *stream;
	LHABasicReader *reader;
	LHAFileHeader *header;
	LHADecoder *decoder;

	reader = reader_for_file(filename, &stream);

	// Get the first archived file:

	header = lha_basic_reader_next_file(reader);
	assert(header != NULL);

	// Check that it is possible to create a decoder for this file.

	decoder = lha_basic_reader_decode(reader);
	assert(decoder != NULL);
	lha_decoder_free(decoder);
	lha_basic_reader_free(reader);
	lha_input_stream_free(stream);
}

static void test_decode(void)
{
	check_decode_for("archives/larc333/lz4.lzs");
	check_decode_for("archives/larc333/lz5.lzs");

	check_decode_for("archives/lha213/lh0.lzh");
	check_decode_for("archives/lha213/lh5.lzh");

	check_decode_for("archives/lha255e/lh0.lzh");
	check_decode_for("archives/lha255e/lh5.lzh");

	check_decode_for("archives/lha_amiga_122/lh0.lzh");
	check_decode_for("archives/lha_amiga_122/lh1.lzh");
	check_decode_for("archives/lha_amiga_122/lh4.lzh");
	check_decode_for("archives/lha_amiga_122/lh5.lzh");
	check_decode_for("archives/lha_amiga_212/lh1.lzh");
	check_decode_for("archives/lha_amiga_212/lh6.lzh");

	check_decode_for("archives/lha_unix114i/h1_lh0.lzh");
	check_decode_for("archives/lha_unix114i/h1_lh5.lzh");
	check_decode_for("archives/lha_unix114i/h1_lh6.lzh");
	check_decode_for("archives/lha_unix114i/h1_lh7.lzh");

	check_decode_for("archives/lharc113/lh0.lzh");
	check_decode_for("archives/lharc113/lh1.lzh");

	check_decode_for("archives/pmarc2/pm0.pma");
	check_decode_for("archives/pmarc2/pm2.pma");
}

int main(int argc, char *argv[])
{
	test_create_free();
	test_read_directory();
	test_read_sfx();
	test_read_compressed();
	test_decode();

	return 0;
}

