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
#include <inttypes.h>

#include "lha_decoder.h"

#include "bit_stream_reader.c"

// Parameters for ring buffer, used for storing history.  This acts
// as the dictionary for copy operations.

#define RING_BUFFER_SIZE 2048
#define START_OFFSET 17

// Threshold offset.  In the copy operation, the copy length is a 4-bit
// value, giving a range 0..15.  The threshold offsets this so that it
// is interpreted as 2..17 - a more useful range.

#define THRESHOLD 2

// Size of output buffer.  Must be large enough to hold the results of
// the maximum copy operation.

#define OUTPUT_BUFFER_SIZE (15 + THRESHOLD)

// Decoder for the -lzs- compression method used by old versions of LArc.
//
// The input stream consists of commands, each of which is either "output
// a literal byte value" or "copy block". A bit at the start of each
// command signals which command it is.

typedef struct {
	BitStreamReader bit_stream_reader;
	uint8_t ringbuf[RING_BUFFER_SIZE];
	unsigned int ringbuf_pos;
} LHALZSDecoder;

static int lha_lzs_init(void *data, LHADecoderCallback callback,
                        void *callback_data)
{
	LHALZSDecoder *decoder = data;

	memset(decoder->ringbuf, ' ', RING_BUFFER_SIZE);
	decoder->ringbuf_pos = RING_BUFFER_SIZE - START_OFFSET;
	bit_stream_reader_init(&decoder->bit_stream_reader, callback,
	                       callback_data);

	return 1;
}

// Add a single byte to the output buffer.

static void output_byte(LHALZSDecoder *decoder, uint8_t *buf,
                        size_t *buf_len, uint8_t b)
{
	buf[*buf_len] = b;
	++*buf_len;

	decoder->ringbuf[decoder->ringbuf_pos] = b;
	decoder->ringbuf_pos = (decoder->ringbuf_pos + 1) % RING_BUFFER_SIZE;
}

// Output a "block" of data from the specified range in the ring buffer.

static void output_block(LHALZSDecoder *decoder,
                         uint8_t *buf,
                         size_t *buf_len,
                         unsigned int start,
                         unsigned int len)
{
	unsigned int i;

	for (i = 0; i < len; ++i) {
		output_byte(decoder, buf, buf_len,
		            decoder->ringbuf[(start + i) % RING_BUFFER_SIZE]);
	}
}

// Process a single command from the LZS input stream.

static size_t lha_lzs_read(void *data, uint8_t *buf)
{
	LHALZSDecoder *decoder = data;
	int bit;
	size_t result;

	// Start from an empty buffer.

	result = 0;

	// Each command starts with a bit that signals the type:

	bit = read_bit(&decoder->bit_stream_reader);

	if (bit < 0) {
		return 0;
	}

	// What type of command is this?

	if (bit) {
		int b;

		b = read_bits(&decoder->bit_stream_reader, 8);

		if (b < 0) {
			return 0;
		}

		output_byte(decoder, buf, &result, (uint8_t) b);
	} else {
		int pos, len;

		pos = read_bits(&decoder->bit_stream_reader, 11);
		len = read_bits(&decoder->bit_stream_reader, 4);

		if (pos < 0 || len < 0) {
			return 0;
		}

		output_block(decoder, buf, &result, (unsigned int) pos,
		             (unsigned int) len + THRESHOLD);
	}

	return result;
}

LHADecoderType lha_lzs_decoder = {
	lha_lzs_init,
	NULL,
	lha_lzs_read,
	sizeof(LHALZSDecoder),
	OUTPUT_BUFFER_SIZE,
	RING_BUFFER_SIZE
};
