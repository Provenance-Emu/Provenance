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

// Decoder for "new-style" LHA algorithms, used with LHA v2 and onwards
// (-lh4-, -lh5-, -lh6-, -lh7-).
//
// This file is designed to be a template. It is #included by other
// files to generate an optimized decoder.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include "lha_decoder.h"

#include "bit_stream_reader.c"

// Include tree decoder.

typedef uint16_t TreeElement;
#include "tree_decode.c"

// Threshold for copying. The first copy code starts from here.

#define COPY_THRESHOLD       3 /* bytes */

// Ring buffer containing history has a size that is a power of two.
// The number of bits is specified.

#define RING_BUFFER_SIZE     (1 << HISTORY_BITS)

// Required size of the output buffer.  At most, a single call to read()
// might result in a copy of the entire ring buffer.

#define OUTPUT_BUFFER_SIZE   RING_BUFFER_SIZE

// Number of possible codes in the "temporary table" used to encode the
// codes table. This is a function of the number of bits used to encode
// the field that contains the number of temp codes.

#define TEMP_CODE_BITS       5
#define MAX_TEMP_CODES       ((1 << TEMP_CODE_BITS) - 1)

// Similarly, the maximum # of offset codes is a function of the number
// of offset bits.

#define MAX_OFFSET_CODES     ((1 << OFFSET_BITS) - 1)

typedef struct {
	// Input bit stream.

	BitStreamReader bit_stream_reader;

	// Ring buffer of past data.  Used for position-based copies.

	uint8_t ringbuf[RING_BUFFER_SIZE];
	unsigned int ringbuf_pos;

	// Number of commands remaining before we start a new block.

	unsigned int block_remaining;

	// This table is used to encode the temp-tree, which
	// is itself used to encode the code tree.

	TreeElement temp_tree[MAX_TEMP_CODES * 2];

	// Table used for the code tree.

	TreeElement code_tree[NUM_CODES * 2];

	// Table used to encode the offset tree, used to read offsets
	// into the history buffer.

	TreeElement offset_tree[MAX_OFFSET_CODES * 2];
} LHANewDecoder;

// Initialize the history ring buffer.

static void init_ring_buffer(LHANewDecoder *decoder)
{
	memset(decoder->ringbuf, ' ', RING_BUFFER_SIZE);
	decoder->ringbuf_pos = 0;
}

static int lha_lh_new_init(void *data, LHADecoderCallback callback,
                           void *callback_data)
{
	LHANewDecoder *decoder = data;

	// Initialize input stream reader.

	bit_stream_reader_init(&decoder->bit_stream_reader,
	                       callback, callback_data);

	// Initialize data structures.

	init_ring_buffer(decoder);

	// First read starts the first block.

	decoder->block_remaining = 0;

	// Initialize tree tables to a known state.

	init_tree(decoder->code_tree, NUM_CODES * 2);
	init_tree(decoder->offset_tree, MAX_OFFSET_CODES * 2);
	init_tree(decoder->temp_tree, MAX_TEMP_CODES * 2);

	return 1;
}

// Read a length value - this is normally a value in the 0-7 range, but
// sometimes can be longer.

static int read_length_value(LHANewDecoder *decoder)
{
	int i, len;

	len = read_bits(&decoder->bit_stream_reader, 3);

	if (len < 0) {
		return -1;
	}

	if (len == 7) {
		// Read more bits to extend the length until we reach a '0'.

		for (;;) {
			i = read_bit(&decoder->bit_stream_reader);

			if (i < 0) {
				return -1;
			} else if (i == 0) {
				break;
			}

			++len;
		}
	}

	return len;
}

// Read the values from the input stream that define the temporary table
// used for encoding the code table.

static int read_temp_table(LHANewDecoder *decoder)
{
	int i, j, n, len, code;
	uint8_t code_lengths[MAX_TEMP_CODES];

	// How many codes?

	n = read_bits(&decoder->bit_stream_reader, TEMP_CODE_BITS);

	if (n < 0) {
		return 0;
	}

	// n=0 is a special case, meaning only a single code that
	// is of zero length.

	if (n == 0) {
		code = read_bits(&decoder->bit_stream_reader, 5);

		if (code < 0) {
			return 0;
		}

		set_tree_single(decoder->temp_tree, code);
		return 1;
	}

	// Enforce a hard limit on the number of codes.

	if (n > MAX_TEMP_CODES) {
		n = MAX_TEMP_CODES;
	}

	// Read the length of each code.

	for (i = 0; i < n; ++i) {
		len = read_length_value(decoder);

		if (len < 0) {
			return 0;
		}

		code_lengths[i] = len;

		// After the first three lengths, there is a 2-bit
		// field to allow skipping over up to a further three
		// lengths. Not sure of the reason for this ...

		if (i == 2) {
			len = read_bits(&decoder->bit_stream_reader, 2);

			if (len < 0) {
				return 0;
			}

			for (j = 0; j < len; ++j) {
				++i;
				code_lengths[i] = 0;
			}
		}
	}

	build_tree(decoder->temp_tree, MAX_TEMP_CODES * 2, code_lengths, n);

	return 1;
}

// Code table codes can indicate that a sequence of codes should be
// skipped over. The number to skip is Huffman-encoded. Given a skip
// range (0-2), this reads the number of codes to skip over.

static int read_skip_count(LHANewDecoder *decoder, int skiprange)
{
	int result;

	// skiprange=0 => 1 code.

	if (skiprange == 0) {
		result = 1;
	}

	// skiprange=1 => 3-18 codes.

	else if (skiprange == 1) {
		result = read_bits(&decoder->bit_stream_reader, 4);

		if (result < 0) {
			return -1;
		}

		result += 3;
	}

	// skiprange=2 => 20+ codes.

	else {
		result = read_bits(&decoder->bit_stream_reader, 9);

		if (result < 0) {
			return -1;
		}

		result += 20;
	}

	return result;
}

static int read_code_table(LHANewDecoder *decoder)
{
	int i, j, n, skip_count, code;
	uint8_t code_lengths[NUM_CODES];

	// How many codes?

	n = read_bits(&decoder->bit_stream_reader, 9);

	if (n < 0) {
		return 0;
	}

	// n=0 implies a single code of zero length; all inputs
	// decode to the same code.

	if (n == 0) {
		code = read_bits(&decoder->bit_stream_reader, 9);

		if (code < 0) {
			return 0;
		}

		set_tree_single(decoder->code_tree, code);

		return 1;
	}

	if (n > NUM_CODES) {
		n = NUM_CODES;
	}

	// Read the length of each code.
	// The lengths are encoded using the temp-table previously read.

	i = 0;

	while (i < n) {
		code = read_from_tree(&decoder->bit_stream_reader,
		                      decoder->temp_tree);

		if (code < 0) {
			return 0;
		}

		// The code that was read can have different meanings.
		// If in the range 0-2, it indicates that a number of
		// codes are unused and should be skipped over.
		// Values greater than two represent a frequency count.

		if (code <= 2) {
			skip_count = read_skip_count(decoder, code);

			if (skip_count < 0) {
				return 0;
			}

			for (j = 0; j < skip_count && i < n; ++j) {
				code_lengths[i] = 0;
				++i;
			}
		} else {
			code_lengths[i] = code - 2;
			++i;
		}
	}

	build_tree(decoder->code_tree, NUM_CODES * 2, code_lengths, n);

	return 1;
}

static int read_offset_table(LHANewDecoder *decoder)
{
	int i, n, len, code;
	uint8_t code_lengths[MAX_OFFSET_CODES];

	// How many codes?

	n = read_bits(&decoder->bit_stream_reader, OFFSET_BITS);

	if (n < 0) {
		return 0;
	}

	// n=0 is a special case, meaning only a single code that
	// is of zero length.

	if (n == 0) {
		code = read_bits(&decoder->bit_stream_reader, OFFSET_BITS);

		if (code < 0) {
			return 0;
		}

		set_tree_single(decoder->offset_tree, code);
		return 1;
	}

	// Enforce a hard limit on the number of codes.

	if (n > MAX_OFFSET_CODES) {
		n = MAX_OFFSET_CODES;
	}

	// Read the length of each code.

	for (i = 0; i < n; ++i) {
		len = read_length_value(decoder);

		if (len < 0) {
			return 0;
		}

		code_lengths[i] = len;
	}

	build_tree(decoder->offset_tree, MAX_OFFSET_CODES * 2, code_lengths, n);

	return 1;
}

// Start reading a new block from the input stream.

static int start_new_block(LHANewDecoder *decoder)
{
	int len;

	// Read length of new block (in commands).

	len = read_bits(&decoder->bit_stream_reader, 16);

	if (len < 0) {
		return 0;
	}

	decoder->block_remaining = (size_t) len;

	// Read the temporary decode table, used to encode the codes table.

	if (!read_temp_table(decoder)) {
		return 0;
	}

	// Read the code table; this is encoded *using* the temp table.

	if (!read_code_table(decoder)) {
		return 0;
	}

	// Read the offset table.

	if (!read_offset_table(decoder)) {
		return 0;
	}

	return 1;
}

// Read the next code from the input stream. Returns the code, or -1 if
// an error occurred.

static int read_code(LHANewDecoder *decoder)
{
	return read_from_tree(&decoder->bit_stream_reader, decoder->code_tree);
}

#ifdef LHARK
static int lhark_read_offset_code(LHANewDecoder *decoder, int code)
{
	unsigned int num_low_bits;
	int low_bits;

	if (code < 4) {
		return code;
	}

	num_low_bits = (code - 2) / 2;
	low_bits = read_bits(&decoder->bit_stream_reader, num_low_bits);
	if (low_bits < 0) {
		return -1;
	}
	return ((2 + (code % 2)) << num_low_bits)
	     + low_bits;
}
#endif

// Read an offset distance from the input stream.
// Returns the code, or -1 if an error occurred.

static int read_offset_code(LHANewDecoder *decoder)
{
	int bits;

	bits = read_from_tree(&decoder->bit_stream_reader,
	                      decoder->offset_tree);

	if (bits < 0) {
		return -1;
	}

	// The code read indicates the length of the offset in bits.
	//
	// The returned value looks like this:
	//   bits = 0  ->         0
	//   bits = 1  ->         1
	//   bits = 2  ->        1x
	//   bits = 3  ->       1xx
	//   bits = 4  ->      1xxx
	//             etc.

	if (bits == 0) {
		return 0;
	} else if (bits == 1) {
		return 1;
#ifdef LHARK
	} else {
		return lhark_read_offset_code(decoder, bits);
	}
#else
	} else {
		int result;
		result = read_bits(&decoder->bit_stream_reader, bits - 1);

		if (result < 0) {
			return -1;
		}

		return result + (1 << (bits - 1));
	}
#endif
}

// Add a byte value to the output stream.

static void output_byte(LHANewDecoder *decoder, uint8_t *buf,
                        size_t *buf_len, uint8_t b)
{
	buf[*buf_len] = b;
	++*buf_len;

	decoder->ringbuf[decoder->ringbuf_pos] = b;
	decoder->ringbuf_pos = (decoder->ringbuf_pos + 1) % RING_BUFFER_SIZE;
}

// Copy a block from the history buffer.

static void copy_from_history(LHANewDecoder *decoder, uint8_t *buf,
                              size_t *buf_len, size_t count)
{
	int offset;
	unsigned int i, start;

	offset = read_offset_code(decoder);

	if (offset < 0) {
		return;
	}

	start = decoder->ringbuf_pos + RING_BUFFER_SIZE
	      - (unsigned int) offset - 1;

	for (i = 0; i < count; ++i) {
		output_byte(decoder, buf, buf_len,
		            decoder->ringbuf[(start + i) % RING_BUFFER_SIZE]);
	}
}

#ifdef LHARK
static int lhark_decode_copy_count(LHANewDecoder *decoder, int code)
{
	if (code < 264) {
		return code - 256 + COPY_THRESHOLD;
	} else if (code < 288) {
		int low_bits, num_low_bits;
		num_low_bits = (code - 260) / 4;
		low_bits = read_bits(&decoder->bit_stream_reader,
				     num_low_bits);
		if (low_bits < 0) {
			return -1;
		}
		return ((4 + (code % 4)) << num_low_bits) + low_bits + 3;
	} else {
		return 514;
	}
}
#endif

static size_t lha_lh_new_read(void *data, uint8_t *buf)
{
	LHANewDecoder *decoder = data;
	size_t result;
	int code, copy_count;

	// Start of new block?

	while (decoder->block_remaining == 0) {
		if (!start_new_block(decoder)) {
			return 0;
		}
	}

	--decoder->block_remaining;

	// Read next command from input stream.

	result = 0;

	code = read_code(decoder);

	if (code < 0) {
		return 0;
	}

	// The code may be either a literal byte value or a copy command.

	if (code < 256) {
		output_byte(decoder, buf, &result, (uint8_t) code);
	} else {
#ifdef LHARK
		copy_count = lhark_decode_copy_count(decoder, code);
		if (copy_count < 0) {
			return 0;
		}
#else
		copy_count = code - 256 + COPY_THRESHOLD;
#endif

		copy_from_history(decoder, buf, &result, copy_count);
	}

	return result;
}

LHADecoderType DECODER_NAME = {
	lha_lh_new_init,
	NULL,
	lha_lh_new_read,
	sizeof(LHANewDecoder),
	OUTPUT_BUFFER_SIZE,
	RING_BUFFER_SIZE / 2
};

// This is a hack for -lh4-:

#ifdef DECODER2_NAME
LHADecoderType DECODER2_NAME = {
	lha_lh_new_init,
	NULL,
	lha_lh_new_read,
	sizeof(LHANewDecoder),
	OUTPUT_BUFFER_SIZE,
	RING_BUFFER_SIZE / 4
};
#endif
