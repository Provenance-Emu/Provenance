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
#include <assert.h>
#include <inttypes.h>

#include "crc32.h"
#include "lib/lha_decoder.h"

typedef struct {
	char *filename;
	char *algorithm;
	size_t len;
	uint32_t crc;
} DecoderTestData;

typedef struct {
	uint8_t *data;
	size_t data_len;
	unsigned int pos;
} DecompressState;

typedef struct {
	unsigned int calls;
	unsigned int last_pos;
	unsigned int total;
} ProgressState;

static DecoderTestData files[] = {

	// LHA:
	{ "compressed/lh0.bin", "-lh0-", 18092, 0x4e46f4a1 },
	{ "compressed/lh1.bin", "-lh1-", 18092, 0x4e46f4a1 },
	{ "compressed/lh5.bin", "-lh5-", 18092, 0x4e46f4a1 },
	{ "compressed/lh6.bin", "-lh6-", 18092, 0x4e46f4a1 },
	{ "compressed/lh7.bin", "-lh7-", 18092, 0x4e46f4a1 },

	// LArc:
	{ "compressed/lh0.bin", "-lz4-", 18092, 0x4e46f4a1 },
	{ "compressed/lzs.bin", "-lzs-", 18092, 0x4e46f4a1 },
	{ "compressed/lz5.bin", "-lz5-", 18092, 0x4e46f4a1 },

	// PMarc:
	{ "compressed/lh0.bin", "-pm0-", 18092, 0x4e46f4a1 },
	{ "compressed/pm2.bin", "-pm2-", 18176, 0x8e2093a7 },
};

static void read_file_data(char *filename, uint8_t **data, size_t *len)
{
	FILE *fstream;

	fstream = fopen(filename, "rb");
	assert(fstream != NULL);

	// Read file size:

	fseek(fstream, 0, SEEK_END);
	*len = (size_t) ftell(fstream);
	fseek(fstream, 0, SEEK_SET);

	// Allocate buffer and read data:

	*data = malloc(*len);
	assert(*data != NULL);

	assert(fread(*data, 1, *len, fstream) == *len);

	fclose(fstream);
}

// Callback function used by decoder to read compressed data.

static size_t read_compressed_data(void *buf, size_t buf_len, void *user)
{
	DecompressState *state = user;
	size_t result;

	// Copy as many bytes of data as possible:

	result = state->data_len - state->pos;

	if (buf_len < result) {
		result = buf_len;
	}

	memcpy(buf, state->data + state->pos, result);

	// Update stream position.

	state->pos += result;

	return result;
}

// Create an in-memory decoder, reading from the specified buffer.

static LHADecoder *create_decoder(DecompressState *state,
                                  uint8_t *data, size_t data_len,
                                  char *algorithm, size_t uncompressed_len)
{
	LHADecoderType *dtype;
	LHADecoder *decoder;

	// Data structure for reading compressed data from buffer.

	state->data = data;
	state->data_len = data_len;
	state->pos = 0;

	// Create decoder.

	dtype = lha_decoder_for_name(algorithm);
	assert(dtype != NULL);

	decoder = lha_decoder_new(dtype, read_compressed_data, state,
	                          uncompressed_len);
	assert(decoder != NULL);

	return decoder;
}

static uint32_t decompress_and_crc(uint8_t *data, size_t data_len,
                                   char *algorithm, size_t uncompressed_len)
{
	LHADecoder *decoder;
	DecompressState state;
	uint8_t buf[16];
	size_t len;
	uint32_t crc;

	// Create decoder and decompress:

	decoder = create_decoder(&state, data, data_len, algorithm,
	                         uncompressed_len);

	crc = 0;

	for (;;) {
		len = lha_decoder_read(decoder, buf, sizeof(buf));

		if (len == 0) {
			break;
		}

		crc32_buf(&crc, buf, len);
	}

	lha_decoder_free(decoder);

	// Calculated CRC:

	return crc;
}

// Decompress files and check CRC.

static void test_decompress(void)
{
	uint8_t *data;
	size_t data_len;
	uint32_t crc;
	unsigned int i;

	for (i = 0; i < sizeof(files) / sizeof(DecoderTestData); ++i) {
		read_file_data(files[i].filename, &data, &data_len);

		// Decompress and check CRC.

		crc = decompress_and_crc(data, data_len, files[i].algorithm,
		                         files[i].len);

		assert(crc == files[i].crc);

		free(data);
	}
}

static void test_decompress_truncated(void)
{
	uint8_t *data;
	size_t data_len;
	uint32_t crc;
	unsigned int i;

	for (i = 0; i < sizeof(files) / sizeof(DecoderTestData); ++i) {
		read_file_data(files[i].filename, &data, &data_len);

		// Truncate length.

		data_len -= 500;

		// Decompress and check CRC.

		crc = decompress_and_crc(data, data_len, files[i].algorithm,
		                         files[i].len);

		// TODO: Error output from decoder.

		assert(crc != files[i].crc);

		free(data);
	}
}

static void progress_callback(unsigned int blocks, unsigned int total,
                              void *user)
{
	ProgressState *progress = user;

	if (progress->calls == 0) {
		// First call?

		assert(blocks == 0);
		assert(total > 0);
	} else {
		// Must have made progress since the last call.
		// Total must never change.

		assert(blocks > progress->last_pos);
		assert(total == progress->total);
	}

	progress->last_pos = blocks;
	progress->total = total;

	++progress->calls;
}

static void test_progress_for_file(DecoderTestData *file)
{
	DecompressState state;
	ProgressState progress;
	uint8_t *data;
	uint8_t buf[16];
	size_t data_len, x;
	LHADecoder *decoder;

	// Read data and create decoder for it.

	read_file_data(file->filename, &data, &data_len);

	decoder = create_decoder(&state, data, data_len,
	                         file->algorithm, file->len);

	// Set progress callback and check it is invoked.

	progress.calls = 0;
	lha_decoder_monitor(decoder, progress_callback, &progress);
	assert(progress.calls == 1);

	// Decompress data.

	for (;;) {
		x = lha_decoder_read(decoder, buf, sizeof(buf));

		if (x == 0) {
			break;
		}
	}

	// Check progress data for sanity.

	assert(progress.last_pos == progress.total);
	assert(progress.calls == 1 + progress.total);

	lha_decoder_free(decoder);
	free(data);
}

static void test_progress_feedback(void)
{
	unsigned int i;

	for (i = 0; i < sizeof(files) / sizeof(DecoderTestData); ++i) {
		test_progress_for_file(&files[i]);
	}
}

static void test_invalid_type(void)
{
	assert(lha_decoder_for_name("-lzx-") == NULL);
	assert(lha_decoder_for_name("-----") == NULL);
	assert(lha_decoder_for_name("abcde") == NULL);
	assert(lha_decoder_for_name("") == NULL);
}

int main(int argc, char *argv[])
{
	test_decompress();
	test_decompress_truncated();
	test_progress_feedback();
	test_invalid_type();

	return 0;
}

