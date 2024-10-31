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

// Fuzz testing system for stress-testing the decompressors.
// This works by repeatedly generating new random streams of
// data and feeding them to the decompressor.

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <signal.h>
#include <assert.h>
#include <unistd.h>
#include <time.h>

#include "lib/lha_decoder.h"

// Maximum amount of data to read before stopping.

#define MAX_FUZZ_LEN (2 * 1024 * 1024)

// Input data to feed to the decompressor:

static uint8_t *input_data;
static size_t input_data_len;

// Position in input stream:

static unsigned int input_pos;

// Decompressor algorithm we are processing.

static char *algorithm;

// Contents of "canary buffer" that is put around allocated blocks to
// check their contents.

static const uint8_t canary_block[] = {
	0xdf, 0xba, 0x18, 0xa0, 0x51, 0x91, 0x3c, 0xd6,
	0x03, 0xfb, 0x2c, 0xa6, 0xd6, 0x88, 0xa5, 0x75,
};

static void dump_input_data(char *filename)
{
	FILE *fstream;

	fstream = fopen(filename, "wb");
	fwrite(input_data, 1, input_data_len, fstream);
	fclose(fstream);
}

// Abort function, invoked when a test fails. Dumps the input for the
// failing test to a file, and exits with SIGABRT (to trigger a
// coredump.

static void error_abort(char *message)
{
	char filename[32];

	fprintf(stderr, "\n--\nTest failed: Error: %s\n", message);
	sprintf(filename, "input-data.%s.%i", algorithm, getpid());
	dump_input_data(filename);
	fprintf(stderr, "Trigger input data dumped to %s\n", filename);

	abort();
}

// Signal function invoked when SIGALRM is raised.

static void alarm_signal(int sig)
{
	error_abort("Alarm expired");
}

// Signal function invoked when SIGSEGV is raised.

static void crash_signal(int sig)
{
	error_abort("Segmentation violation");
}

// Allocate some memory with canary blocks surrounding it.

static void *canary_malloc(size_t nbytes)
{
	uint8_t *result;

	result = malloc(nbytes + 2 * sizeof(canary_block) + sizeof(size_t));
	assert(result != NULL);

	memcpy(result, &nbytes, sizeof(size_t));
	memcpy(result + sizeof(size_t), canary_block, sizeof(canary_block));
	memset(result + sizeof(size_t) + sizeof(canary_block), 0, nbytes);
	memcpy(result + sizeof(size_t) + sizeof(canary_block) + nbytes,
	       canary_block, sizeof(canary_block));

	return result + sizeof(size_t) + sizeof(canary_block);
}

// Free memory allocated with canary_malloc().

static void canary_free(void *data)
{
	if (data != NULL) {
		free((uint8_t *) data - sizeof(size_t) - sizeof(canary_block));
	}
}

// Check the canary blocks surrounding memory allocated with canary_malloc().

static void canary_check(void *_data)
{
	uint8_t *data = _data;
	size_t nbytes;

	memcpy(&nbytes, data - sizeof(size_t) - sizeof(canary_block),
	       sizeof(size_t));

	if (memcmp(data - sizeof(canary_block), canary_block,
	           sizeof(canary_block)) != 0
	 || memcmp(data + nbytes, canary_block,
	           sizeof(canary_block)) != 0) {
		error_abort("Canary area check failed");
	}
}

// Fill in the specified block with random data.

static void fuzz_block(uint8_t *data, unsigned int data_len)
{
	unsigned int i;

	for (i = 0; i < data_len; ++i) {
		data[i] = rand() & 0xff;
	}
}

// Callback function used to read more data from the signature being
// processed.

static size_t read_more_data(void *buf, size_t buf_len, void *user_data)
{
	// Return end of file when we reach the end of the data.

	if (input_pos >= input_data_len) {
		return 0;
	}

	// Only copy a single byte at a time. This allows us to
	// accurately track how much of the signature is valid.

	memcpy(buf, input_data + input_pos, 1);
	++input_pos;

	return 1;
}

// Decode data from the specified signature block, using a decoder
// of the specified type.

static unsigned int run_fuzz_test(LHADecoderType *dtype,
                                  uint8_t *data,
                                  size_t data_len)
{
	uint8_t *read_buf;
	size_t result;
	void *handle;

	// Throw an alarm after 5 minutes if it doesn't complete.

	alarm(5 * 60);

	// Init decoder.

	input_data = data;
	input_data_len = data_len;
	input_pos = 0;

	handle = canary_malloc(dtype->extra_size);
	assert(dtype->init(handle, read_more_data, NULL));

	// Create a buffer into which to decompress data.

	read_buf = canary_malloc(dtype->max_read);
	assert(read_buf != NULL);

	for (;;) {
		memset(read_buf, 0, dtype->max_read);
		result = dtype->read(handle, read_buf);
		canary_check(read_buf);

		//printf("read: %i\n", result);
		if (result == 0) {
			break;
		}
	}

	// Destroy the decoder and free buffers.

	if (dtype->free != NULL) {
		dtype->free(handle);
	}

	canary_check(handle);
	canary_free(handle);
	canary_free(read_buf);

	//printf("Fuzz test complete, %i bytes read\n", cb_data.read);

	// Cancel alarm.

	alarm(0);

	return input_pos;
}

static void fuzz_test(LHADecoderType *dtype, size_t data_len)
{
	unsigned int count;
	void *data;

	// Generate a block of random data.

	data = malloc(data_len);
	assert(data != NULL);
	fuzz_block(data, data_len);

	// Run the decoder with the data as input.

	count = run_fuzz_test(dtype, data, data_len);

	if (count >= data_len) {
		printf("\tTest complete (end of file)\n");
	} else {
		printf("\tTest complete (read %i bytes)\n", count);
	}

	free(data);
}

static void run_from_file(LHADecoderType *dtype, char *filename)
{
	FILE *fstream;
	uint8_t *data;
	size_t data_len;
	unsigned int count;

	fstream = fopen(filename, "rb");

	if (fstream == NULL) {
		fprintf(stderr, "Failed to open '%s'\n", filename);
		exit(-1);
	}

	fseek(fstream, 0, SEEK_END);
	data_len = ftell(fstream);
	fseek(fstream, 0, SEEK_SET);

	data = malloc(data_len);
	assert(data != NULL);
	fread(data, 1, data_len, fstream);

	printf("Running input from %s:\n", filename);

	count = run_fuzz_test(dtype, data, data_len);

	if (count >= data_len) {
		printf("\tTest complete (end of file)\n");
	} else {
		printf("\tTest complete (read %i bytes)\n", count);
	}

	free(data);
}

int main(int argc, char *argv[])
{
	LHADecoderType *dtype;
	unsigned int i;
	time_t now;
	char timestr[32];

	if (argc < 2) {
		printf("Usage: %s <decoder-type> [filename]\n", argv[0]);
		exit(-1);
	}

	algorithm = argv[1];

	dtype = lha_decoder_for_name(algorithm);

	if (dtype == NULL) {
		fprintf(stderr, "Unknown decoder type '%s'\n", algorithm);
		exit(-1);
	}

	if (argc >= 3) {
		run_from_file(dtype, argv[2]);
	} else {
		signal(SIGALRM, alarm_signal);
		signal(SIGSEGV, crash_signal);

		srand(time(NULL));

		for (i = 0; ; ++i) {
			now = time(NULL);
			strftime(timestr, sizeof(timestr),
			         "%Y-%m-%dT%H:%M:%S", localtime(&now));
			printf("%s - Iteration %i:\n", timestr, i);
			fuzz_test(dtype, MAX_FUZZ_LEN);
		}
	}

	return 0;
}

