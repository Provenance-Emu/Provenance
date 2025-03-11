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

// Automated tester for 'ghost' archive formats.
//
// Some old tools support 'ghost' archive formats: compression algorithms
// that can be decompressed, but for which no version of the tool can be
// found that actually generates archives that use them. These formats were
// likely beta versions of the mainstream algorithms that are more widely
// used.
//
// Ideally, these archive formats should still be supported. However, testing
// poses a problem, because test archives cannot be generated to test the
// decompression code. This tool provides an alternative: it uses the
// decompression code to generate a random archive which, assuming the
// correctness of the code, should be a valid archive. The original legacy
// tool can then be run via DOSbox to extract the archive. The data extracted
// by the two tools can then be compared.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>
#include <unistd.h>

#include "lib/lha_arch.h"
#include "lha_decoder.h"
#include "crc32.h"

// Filename to use for archive file:

#define TEST_ARCHIVE_FILENAME "testdata.lzh"

// Filename to use for archived file:

#define TEST_FILENAME "TESTDATA.BIN"

// Minimum length of a level 0 LHA header:

#define MIN_HEADER_LEN  24

// Number of bytes of random "compressed" data to generate:

#define COMPRESSED_DATA_LEN    (64 * 1024)

// Length of uncompressed data (for header):

#define UNCOMPRESSED_DATA_LEN  (64 * 1024)

// Byte location at which to align compressed files within the archive:

#define ARCHIVED_FILE_ALIGN  1024

typedef struct {
	uint8_t *buf;
	size_t buf_len;
	unsigned int buf_pos;
} ReadDataCallback;

// Write a 32-bit integer into the specified buffer.

static void write_uint32(uint8_t *buf, uint32_t value)
{
	buf[0] = value & 0xff;
	buf[1] = (value >> 8) & 0xff;
	buf[2] = (value >> 16) & 0xff;
	buf[3] = (value >> 24) & 0xff;
}

// Write a 16-bit integer into the specified buffer.

static void write_uint16(uint8_t *buf, uint16_t value)
{
	buf[0] = value & 0xff;
	buf[1] = (value >> 8) & 0xff;
}

// Fill the specified buffer with random data.

static void fill_random(uint8_t *buf, size_t buf_len)
{
	unsigned int i;

	for (i = 0; i < buf_len; ++i) {
		buf[i] = rand() & 0xff;
	}
}

/**
 * Callback function used by LHADecoder to read more data.
 *
 * @param buf        Buffer in which to read the data.
 * @param buf_len    Length of the buffer.
 * @param user_data  Pointer to the ReadDataCallback structure containing
 *                   the stream decompression state.
 * @return           Number of bytes read.
 */

static size_t read_data(void *buf, size_t buf_len, void *user_data)
{
	ReadDataCallback *callback_data = user_data;
	size_t to_copy;

	to_copy = callback_data->buf_len - callback_data->buf_pos;

	if (to_copy > buf_len) {
		to_copy = buf_len;
	}

	memcpy(buf, callback_data->buf + callback_data->buf_pos, to_copy);
	callback_data->buf_pos += to_copy;

	return to_copy;
}

/**
 * Generate some test data that can be successfully decompressed using
 * the specified algorithm type.
 *
 * @param type             The algorithm to use for decompression.
 * @param buf              Pointer to the buffer to store the data.
 * @param buf_len          Length of the buffer.
 * @param uncompressed_len Number of bytes to decompress before stopping.
 * @param crc16            Pointer to a variable to store the 16-bit CRC.
 * @param crc32            Pointer to a variable to store the 32-bit CRC.
 */

static void generate_data(char *type, uint8_t *buf, size_t buf_len,
                          size_t uncompressed_len,
                          uint16_t *crc16, uint32_t *crc32)
{
	LHADecoderType *dtype;
	ReadDataCallback callback_data;
	LHADecoder *decoder;
	size_t decoded_stream_len;

	dtype = lha_decoder_for_name(type);
	assert(dtype != NULL);

	// Fill the buffer with random data:

	fill_random(buf, buf_len);

	// Decompress as much data as possible. If we fail to decompress
	// all the data, modify some of the data from the point just
	// before we stopped and try again.
	// This is essentially a genetic algorithm.

	for (;;) {
		callback_data.buf = buf;
		callback_data.buf_len = buf_len;
		callback_data.buf_pos = 0;

		decoder = lha_decoder_new(dtype, read_data, &callback_data,
					  uncompressed_len);

		decoded_stream_len = 0;
		*crc32 = 0;

		for (;;) {
			uint8_t decode_buf[128];
			size_t decoded_bytes;

			decoded_bytes = lha_decoder_read(decoder, decode_buf,
							 sizeof(decode_buf));
			if (decoded_bytes == 0) {
				break;
			}

			crc32_buf(crc32, decode_buf, decoded_bytes);

			decoded_stream_len += decoded_bytes;
		}

		*crc16 = lha_decoder_get_crc(decoder);

		lha_decoder_free(decoder);

		// Successfully decompressed all the data? We are done.

		if (decoded_stream_len >= uncompressed_len) {
			break;
		}

		// Modify some data from the end of the stream and try again.

		if (callback_data.buf_pos < 6) {
			fill_random(callback_data.buf, 6);
		} else {
			fill_random(callback_data.buf
			            + callback_data.buf_pos - 6, 6);
		}
	}
}

/**
 * Calculate the LHA level 0 header checksum for the specified buffer.
 *
 * @param buf         Pointer to buffer containing the data to checksum.
 * @param buf_len     Length of the buffer.
 * @return            Checksum of the buffer.
 */

static uint8_t calculate_checksum(uint8_t *buf, size_t buf_len)
{
	uint8_t result;
	unsigned int i;

	result = 0;

	for (i = 0; i < buf_len; ++i) {
		result = (result + buf[i]) & 0xff;
	}

	return result;
}

/**
 * Generate an archive file.
 *
 * @param out_filename     Location to save the generate file.
 * @param type             The algorithm to use for decompression.
 * @param filename         Filename to use for the archived file.
 * @return                 32-bit CRC of the decompressed data.
 */

static uint32_t generate_archive(char *out_filename, char *type,
                                 char *filename)
{
	FILE *outfile;
	uint8_t *buf;
	size_t buf_len;
	uint16_t crc16;
	uint32_t crc32;

	buf_len = COMPRESSED_DATA_LEN + MIN_HEADER_LEN + strlen(filename);

	buf = malloc(buf_len);
	assert(buf != NULL);

	generate_data(type, buf + MIN_HEADER_LEN + strlen(filename),
	              COMPRESSED_DATA_LEN, UNCOMPRESSED_DATA_LEN,
	              &crc16, &crc32);

	// Construct header:

	buf[0] = MIN_HEADER_LEN + strlen(filename) - 2;     // Header length
	memcpy(buf + 2, type, 5);                           // Compression type
	write_uint32(buf + 7, COMPRESSED_DATA_LEN);         // Packed len
	write_uint32(buf + 11, UNCOMPRESSED_DATA_LEN);      // Original len
	write_uint32(buf + 15, 0);                          // Mod date/time
	write_uint16(buf + 19, 0x0020);                     // DOS attribute
	buf[21] = strlen(filename);                         // Filename
	memcpy(buf + 22, filename, strlen(filename));
	write_uint16(buf + 22 + strlen(filename), crc16);   // CRC
	buf[1] = calculate_checksum(buf + 2,
	                            MIN_HEADER_LEN + strlen(filename) - 2);

	outfile = fopen(out_filename, "wb");
	fwrite(buf, buf_len, 1, outfile);
	fclose(outfile);

	free(buf);

	return crc32;
}

/**
 * Invoke DOSbox to run the specified command.
 *
 * @param command       Command string of the form 'cmd %s'.
 * @param filename      Filename of the file to extract.
 */

static void run_dosbox(char *command, char *filename)
{
	char cmdbuf1[64];
	char cmdbuf2[128];

	sprintf(cmdbuf1, command, filename);
	sprintf(cmdbuf2, "dosbox -c 'mount c .' -c 'c:' -c '%s' -c exit",
	                 cmdbuf1);
	system(cmdbuf2);
}

/**
 * Check the extracted file has the expected CRC32.
 *
 * @param archive       Path to the archive file.
 * @param filename      Filename of the file to check.
 * @param crc           Expected 32-bit CRC.
 */

static void check_file_crc(char *archive, char *filename, uint32_t crc)
{
	uint8_t buf[64];
	FILE *fstream;
	uint32_t check_crc;
	size_t bytes;

	fstream = fopen(filename, "rb");

	if (fstream == NULL) {
		fprintf(stderr, "\n\nFailed to extract file:\n"
		                "Archive: %s\nFilename: %s\n",
		                archive, filename);
		exit(-1);
	}

	check_crc = 0;

	while (!feof(fstream)) {
		bytes = fread(buf, 1, sizeof(buf), fstream);
		crc32_buf(&check_crc, buf, bytes);
	}

	fclose(fstream);

	if (check_crc != crc) {
		fprintf(stderr, "\n\nExtracted file failed CRC check:\n"
		                "Archive: %s\nFilename: %s\n"
		                "Expected CRC: %08x, Actual CRC: %08x\n",
		                archive, filename, crc, check_crc);
		exit(-1);
	}
}

int main(int argc, char *argv[])
{
	uint32_t crc;

	if (argc < 4) {
		printf("Usage: %s <compression type> <test directory> "
		       "<command>\n", argv[0]);
		printf("  where command is of the form 'cmd %%s'\n");
		exit(-1);
	}

	assert(chdir(argv[2]) != 0);
	srand(time(NULL));

	for (;;) {
		remove(TEST_ARCHIVE_FILENAME);
		remove(TEST_FILENAME);

		crc = generate_archive(TEST_ARCHIVE_FILENAME, argv[1],
		                       TEST_FILENAME);

		run_dosbox(argv[3], TEST_ARCHIVE_FILENAME);
		check_file_crc(TEST_ARCHIVE_FILENAME, TEST_FILENAME, crc);
	}

	return 0;
}

