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

// Parameters for ring buffer, used for storing history.  This acts
// as the dictionary for copy operations.

#define RING_BUFFER_SIZE 4096
#define START_OFFSET 18

// Threshold offset.  In the copy operation, the copy length is a 4-bit
// value, giving a range 0..15.  The threshold offsets this so that it
// is interpreted as 3..18 - a more useful range.

#define THRESHOLD 3

// Size of output buffer.  Must be large enough to hold the results of
// a complete "run" (see below).

#define OUTPUT_BUFFER_SIZE (15 + THRESHOLD) * 8

// Decoder for the -lz5- compression method used by LArc.
//
// This processes "runs" of eight commands, each of which is either
// "output a character" or "copy block".  The result of that run
// is written into the output buffer.

typedef struct {
	uint8_t ringbuf[RING_BUFFER_SIZE];
	unsigned int ringbuf_pos;
	LHADecoderCallback callback;
	void *callback_data;
} LHALZ5Decoder;

static void fill_initial(LHALZ5Decoder *decoder)
{
	unsigned int i, j;
	uint8_t *p;

	p = decoder->ringbuf;

	// For each byte value, the history buffer includes a run of 13
	// bytes all with that value. This is useful eg. for text files
	// that include a long run like this (eg. ===========).
	for (i = 0; i < 256; ++i) {
		for (j = 0; j < 13; ++j) {
			*p++ = (uint8_t) i;
		}
	}

	// Next we include all byte values ascending and descending.
	for (i = 0; i < 256; ++i) {
		*p++ = (uint8_t) i;
	}
	for (i = 0; i < 256; ++i) {
		*p++ = (uint8_t) (255 - i);
	}

	// Block of zeros, and then ASCII space characters. I think these are
	// towards the end of the range because they're most likely to be
	// useful and therefore last to get overwritten?
	for (i = 0; i < 128; ++i) {
		*p++ = 0;
	}
	for (i = 0; i < 110; ++i) {
		*p++ = ' ';
	}

	// Final 18 characters are all zeros, probably because of START_OFFSET.
	for (i = 0; i < 18; ++i) {
		*p++ = 0;
	}
}

static int lha_lz5_init(void *data, LHADecoderCallback callback,
                        void *callback_data)
{
	LHALZ5Decoder *decoder = data;

	fill_initial(decoder);
	decoder->ringbuf_pos = RING_BUFFER_SIZE - START_OFFSET;
	decoder->callback = callback;
	decoder->callback_data = callback_data;

	return 1;
}

// Add a single byte to the output buffer.

static void output_byte(LHALZ5Decoder *decoder, uint8_t *buf,
                        size_t *buf_len, uint8_t b)
{
	buf[*buf_len] = b;
	++*buf_len;

	decoder->ringbuf[decoder->ringbuf_pos] = b;
	decoder->ringbuf_pos = (decoder->ringbuf_pos + 1) % RING_BUFFER_SIZE;
}

// Output a "block" of data from the specified range in the ring buffer.

static void output_block(LHALZ5Decoder *decoder,
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

// Process a "run" of LZ5-compressed data (a control byte followed by
// eight "commands").

static size_t lha_lz5_read(void *data, uint8_t *buf)
{
	LHALZ5Decoder *decoder = data;
	uint8_t bitmap;
	unsigned int bit;
	size_t result;

	// Start from an empty buffer.

	result = 0;

	// Read the bitmap byte first.

	if (!decoder->callback(&bitmap, 1, decoder->callback_data)) {
		return 0;
	}

	// Each bit in the bitmap is a command.
	// If the bit is set, it is an "output byte" command.
	// If it is not set, it is a "copy block" command.

	for (bit = 0; bit < 8; ++bit) {
		if ((bitmap & (1 << bit)) != 0) {
			uint8_t b;

			if (!decoder->callback(&b, 1, decoder->callback_data)) {
				break;
			}

			output_byte(decoder, buf, &result, b);
		} else {
			uint8_t cmd[2];
			unsigned int seqstart, seqlen;

			if (!decoder->callback(cmd, 2, decoder->callback_data)) {
				break;
			}

			seqstart = (((unsigned int) cmd[1] & 0xf0) << 4)
			         | cmd[0];
			seqlen = ((unsigned int) cmd[1] & 0x0f) + THRESHOLD;

			output_block(decoder, buf, &result, seqstart, seqlen);
		}
	}

	return result;
}

LHADecoderType lha_lz5_decoder = {
	lha_lz5_init,
	NULL,
	lha_lz5_read,
	sizeof(LHALZ5Decoder),
	OUTPUT_BUFFER_SIZE,
	RING_BUFFER_SIZE
};
