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

// Decoder for -pm1- compressed files.
//
// This was difficult to put together. I can't find any versions of
// PMarc that will generate -pm1- encoded files (only -pm2-); however,
// the extraction tool, PMext, will extract them. I have therefore been
// able to reverse engineer the format and write a decoder. I am
// indebted to Alwin Henseler for publishing the Z80 assembly source to
// his UNPMA10 tool, which was apparently decompiled from the original
// PMarc and includes the -pm1- decoding code.

#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include "lha_decoder.h"
#include "bit_stream_reader.c"
#include "pma_common.c"

// Size of the ring buffer used to hold the history.

#define RING_BUFFER_SIZE 16384

// Maximum length of a command representing a block of bytes:

#define MAX_BYTE_BLOCK_LEN 216

// Maximum number of bytes that can be copied by a single copy command.

#define MAX_COPY_BLOCK_LEN 244

// Output buffer length. A single call to lha_pm1_read can perform one
// byte block output followed by a copy command.

#define OUTPUT_BUFFER_SIZE (MAX_BYTE_BLOCK_LEN + MAX_COPY_BLOCK_LEN)

typedef struct {
	BitStreamReader bit_stream_reader;

	// Position in output stream, in bytes.

	unsigned int output_stream_pos;

	// Pointer to the entry in byte_decode_table used to decode
	// byte value indices.

	const uint8_t *byte_decode_tree;

	// History ring buffer.

	uint8_t ringbuf[RING_BUFFER_SIZE];
	unsigned int ringbuf_pos;

	// History linked list, for adaptively encoding byte values.

	HistoryLinkedList history_list;

	// Callback to read more compressed data from the input (see
	// read_callback_wrapper below).

	LHADecoderCallback callback;
	void *callback_data;
} LHAPM1Decoder;

// Table used to decode distance into history buffer to copy data.

static const VariableLengthTable copy_ranges[] = {
	{    0,  6 },  //    0 +  (1 << 6) =    64
	{   64,  8 },  //   64 +  (1 << 8) =   320
	{    0,  6 },  //    0 +  (1 << 6) =    64
	{   64,  9 },  //   64 +  (1 << 9) =   576
	{  576, 11 },  //  576 + (1 << 11) =  2624
	{ 2624, 13 },  // 2624 + (1 << 13) = 10816

	// The above table entries are used after a certain number of
	// bytes have been decoded.
	// Early in the stream, some of the copy ranges are more limited
	// in their range, so that fewer bits are needed. The above
	// table entries are redirected to these entries instead.

	// Table entry #3 (64):
	{   64,  8 },   // < 320 bytes

	// Table entry #4 (576):
	{  576,  8 },   // < 832 bytes
	{  576,  9 },   // < 1088 bytes
	{  576, 10 },   // < 1600 bytes

	// Table entry #5 (2624):
	{ 2624,  8 },   // < 2880 bytes
	{ 2624,  9 },   // < 3136 bytes
	{ 2624, 10 },   // < 3648 bytes
	{ 2624, 11 },   // < 4672 bytes
	{ 2624, 12 },   // < 6720 bytes
};

// Table used to decode byte values.

static const VariableLengthTable byte_ranges[] = {
	{   0, 4 },  //   0 + (1 << 4) = 16
	{  16, 4 },  //  16 + (1 << 4) = 32
	{  32, 5 },  //  32 + (1 << 5) = 64
	{  64, 6 },  //  64 + (1 << 6) = 128
	{ 128, 6 },  // 128 + (1 << 6) = 191
	{ 192, 6 },  // 192 + (1 << 6) = 255
};

// This table is a list of trees to decode indices into byte_ranges.
// Each line is actually a mini binary tree, starting with the first
// byte as the root node. Each nybble of the byte is one of the two
// branches: either a leaf value (a-f) or an offset to the child node.
// Expanded representation is shown in comments below.

static const uint8_t byte_decode_trees[][5] = {
       { 0x12, 0x2d, 0xef, 0x1c, 0xab },    // ((((a b) c) d) (e f))
       { 0x12, 0x23, 0xde, 0xab, 0xcf },    // (((a b) (c f)) (d e))
       { 0x12, 0x2c, 0xd2, 0xab, 0xef },    // (((a b) c) (d (e f)))
       { 0x12, 0xa2, 0xd2, 0xbc, 0xef },    // ((a (b c)) (d (e f)))

       { 0x12, 0xa2, 0xc2, 0xbd, 0xef },    // ((a (b d)) (c (e f)))
       { 0x12, 0xa2, 0xcd, 0xb1, 0xef },    // ((a (b (e f))) (c d))
       { 0x12, 0xab, 0x12, 0xcd, 0xef },    // ((a b) ((c d) (e f)))
       { 0x12, 0xab, 0x1d, 0xc1, 0xef },    // ((a b) ((c (e f)) d))

       { 0x12, 0xab, 0xc1, 0xd1, 0xef },    // ((a b) (c (d (e f))))
       { 0xa1, 0x12, 0x2c, 0xde, 0xbf },    // (a (((b f) c) (d e)))
       { 0xa1, 0x1d, 0x1c, 0xb1, 0xef },    // (a (((b (e f)) c) d))
       { 0xa1, 0x12, 0x2d, 0xef, 0xbc },    // (a (((b c) d) (e f)))

       { 0xa1, 0x12, 0xb2, 0xde, 0xcf },    // (a ((b (c f)) (d e)))
       { 0xa1, 0x12, 0xbc, 0xd1, 0xef },    // (a ((b c) (d (e f))))
       { 0xa1, 0x1c, 0xb1, 0xd1, 0xef },    // (a ((b (d (e f))) c))
       { 0xa1, 0xb1, 0x12, 0xcd, 0xef },    // (a (b ((c d) (e f))))

       { 0xa1, 0xb1, 0xc1, 0xd1, 0xef },    // (a (b (c (d (e f)))))
       { 0x12, 0x1c, 0xde, 0xab },          // (((d e) c) (d e)) <- BROKEN!
       { 0x12, 0xa2, 0xcd, 0xbe },          // ((a (b e)) (c d))
       { 0x12, 0xab, 0xc1, 0xde },          // ((a b) (c (d e)))

       { 0xa1, 0x1d, 0x1c, 0xbe },          // (a (((b e) c) d))
       { 0xa1, 0x12, 0xbc, 0xde },          // (a ((b c) (d e)))
       { 0xa1, 0x1c, 0xb1, 0xde },          // (a ((b (d e)) c))
       { 0xa1, 0xb1, 0xc1, 0xde },          // (a (b (c (d e))))

       { 0x1d, 0x1c, 0xab },                // (((a b) c) d)
       { 0x1c, 0xa1, 0xbd },                // ((a (b d)) c)
       { 0x12, 0xab, 0xcd },                // ((a b) (c d))
       { 0xa1, 0x1c, 0xbd },                // (a ((b d) c))

       { 0xa1, 0xb1, 0xcd },                // (a (b (c d)))
       { 0xa1, 0xbc },                      // (a (b c))
       { 0xab },                            // (a b)
       { 0x00 },                            // -- special entry: 0, no tree
};

// Wrapper function invoked to read more data from the input. This mostly just
// calls the real function that does the read. However, when the end of file
// is reached, instead of returning zero, the buffer is filled with zero bytes
// instead. There seem to be archive files that actually depend on this
// ability to read "beyond" the length of the compressed data.

static size_t read_callback_wrapper(void *buf, size_t buf_len, void *user_data)
{
	LHAPM1Decoder *decoder = user_data;
	size_t result;

	result = decoder->callback(buf, buf_len, decoder->callback_data);

	if (result == 0) {
		memset(buf, 0, buf_len);
		result = buf_len;
	}

	return result;
}

static int lha_pm1_init(void *data, LHADecoderCallback callback,
                        void *callback_data)
{
	LHAPM1Decoder *decoder = data;

	memset(decoder, 0, sizeof(LHAPM1Decoder));

	// Unlike other decoders, the bitstream code must call the wrapper
	// function above to read data.

	decoder->callback = callback;
	decoder->callback_data = callback_data;

	bit_stream_reader_init(&decoder->bit_stream_reader,
	                       read_callback_wrapper, decoder);

	decoder->output_stream_pos = 0;
	decoder->byte_decode_tree = NULL;
	decoder->ringbuf_pos = 0;

	init_history_list(&decoder->history_list);

	return 1;
}

// Read the 5-bit header from the start of the input stream. This
// specifies the table entry to use for byte decodes.

static int read_start_header(LHAPM1Decoder *decoder)
{
	int index;

	index = read_bits(&decoder->bit_stream_reader, 5);

	if (index < 0) {
		return 0;
	}

	decoder->byte_decode_tree = byte_decode_trees[index];

	return 1;
}

// Function called when a new byte is outputted, to update the
// appropriate data structures.

static void outputted_byte(LHAPM1Decoder *decoder, uint8_t b)
{
	// Add to history ring buffer.

	decoder->ringbuf[decoder->ringbuf_pos] = b;
	decoder->ringbuf_pos
	    = (decoder->ringbuf_pos + 1) % RING_BUFFER_SIZE;

	// Other updates: history linked list, output stream position:

	update_history_list(&decoder->history_list, b);
	++decoder->output_stream_pos;
}

// Decode a count of the number of bytes to copy in a copy command.
// Returns -1 for failure.

static int read_copy_byte_count(LHAPM1Decoder *decoder)
{
	int x;

	// This is a form of static huffman encoding that uses less bits
	// to encode short copy amounts (again).

	// Value in the range 3..5?
	// Length values start at 3: if it was 2, a different copy
	// range would have been used and this function would not
	// have been called.

	x = read_bits(&decoder->bit_stream_reader, 2);

	if (x < 0) {
		return -1;
	} else if (x < 3) {
		return x + 3;
	}

	// Value in range 6..10?

	x = read_bits(&decoder->bit_stream_reader, 3);

	if (x < 0) {
		return -1;
	} else if (x < 5) {
		return x + 6;
	}

	// Value in range 11..14?

	else if (x == 5) {
		x = read_bits(&decoder->bit_stream_reader, 2);

		if (x < 0) {
			return -1;
		} else {
			return x + 11;
		}
	}

	// Value in range 15..22?

	else if (x == 6) {
		x = read_bits(&decoder->bit_stream_reader, 3);

		if (x < 0) {
			return -1;
		} else {
			return x + 15;
		}
	}

	// else x == 7...

	x = read_bits(&decoder->bit_stream_reader, 6);

	if (x < 0) {
		return -1;
	} else if (x < 62) {
		return x + 23;
	}

	// Value in range 85..116?

	else if (x == 62) {
		x = read_bits(&decoder->bit_stream_reader, 5);

		if (x < 0) {
			return -1;
		} else {
			return x + 85;
		}
	}

	// Value in range 117..244?

	else {  // a = 63
		x = read_bits(&decoder->bit_stream_reader, 7);

		if (x < 0) {
			return -1;
		} else {
			return x + 117;
		}
	}
}

// Read a single bit from the input stream, but only once the specified
// point is reached in the output stream. Before that point is reached,
// return the value of 'def' instead. Returns -1 for error.

static int read_bit_after_threshold(LHAPM1Decoder *decoder,
                                    unsigned int threshold,
				    int def)
{
	if (decoder->output_stream_pos >= threshold) {
		return read_bit(&decoder->bit_stream_reader);
	} else {
		return def;
	}
}

// Read the range index for the copy type used when performing a copy command.

static int read_copy_type_range(LHAPM1Decoder *decoder)
{
	int x;

	// This is another static huffman tree, but the path grows as
	// more data is decoded. The progression is as follows:
	//  1. Initially, only '0' and '2' can be returned.
	//  2. After 64 bytes, '1' and '3' can be returned as well.
	//  3. After 576 bytes, '4' can be returned.
	//  4. After 2624 bytes, '5' can be returned.

	x = read_bit(&decoder->bit_stream_reader);

	if (x < 0) {
		return -1;
	} else if (x == 0) {
		x = read_bit_after_threshold(decoder, 576, 0);

		if (x < 0) {
			return -1;
		} else if (x != 0) {
			return 4;
		} else {
			// Return either 0 or 1.
			return read_bit_after_threshold(decoder, 64, 0);
		}
	} else {
		x = read_bit_after_threshold(decoder, 64, 1);

		if (x < 0) {
			return -1;
		} else if (x == 0) {
			return 3;
		}

		x = read_bit_after_threshold(decoder, 2624, 1);

		if (x < 0) {
			return -1;
		} else if (x != 0) {
			return 2;
		} else {
			return 5;
		}
	}

}

// Read a copy command from the input stream and copy from history.
// Returns 0 for failure.

static size_t read_copy_command(LHAPM1Decoder *decoder, uint8_t *buf)
{
	int range_index;
	int history_distance;
	int copy_index, i;
	int count;

	range_index = read_copy_type_range(decoder);

	if (range_index < 0) {
		return 0;
	}

	// The first two entries in the copy_ranges table are used as
	// a shorthand to copy two bytes. Otherwise, decode the number
	// of bytes to copy.

	if (range_index < 2) {
		count = 2;
	} else {
		count = read_copy_byte_count(decoder);

		if (count < 0) {
			return 0;
		}
	}

	// The 'range_index' variable is an index into the copy_ranges
	// array. As a special-case hack, early in the output stream
	// some history ranges are inaccessible, so fewer bits can be
	// used. Redirect range_index to special entries to do this.

	if (range_index == 3) {
		if (decoder->output_stream_pos < 320) {
			range_index = 6;
		}
	} else if (range_index == 4) {
		if (decoder->output_stream_pos < 832) {
			range_index = 7;
		} else if (decoder->output_stream_pos < 1088) {
			range_index = 8;
		} else if (decoder->output_stream_pos < 1600) {
			range_index = 9;
		}
	} else if (range_index == 5) {
		if (decoder->output_stream_pos < 2880) {
			range_index = 10;
		} else if (decoder->output_stream_pos < 3136) {
			range_index = 11;
		} else if (decoder->output_stream_pos < 3648) {
			range_index = 12;
		} else if (decoder->output_stream_pos < 4672) {
			range_index = 13;
		} else if (decoder->output_stream_pos < 6720) {
			range_index = 14;
		}
	}

	// Calculate the number of bytes back into the history buffer
	// to read.

	history_distance = decode_variable_length(&decoder->bit_stream_reader,
	                                          copy_ranges, range_index);

	if (history_distance < 0
	 || (unsigned) history_distance >= decoder->output_stream_pos) {
		return 0;
	}

	// Copy from the ring buffer.

	copy_index = (decoder->ringbuf_pos + RING_BUFFER_SIZE
	              - history_distance - 1) % RING_BUFFER_SIZE;

	for (i = 0; i < count; ++i) {
		buf[i] = decoder->ringbuf[copy_index];
		outputted_byte(decoder, decoder->ringbuf[copy_index]);
		copy_index = (copy_index + 1) % RING_BUFFER_SIZE;
	}

	return count;
}

// Read the index into the byte decode table, using the byte_decode_tree
// set at the start of the stream. Returns -1 for failure.

static int read_byte_decode_index(LHAPM1Decoder *decoder)
{
	const uint8_t *ptr;
	unsigned int child;
	int bit;

	ptr = decoder->byte_decode_tree;

	if (ptr[0] == 0) {
		return 0;
	}

	// Walk down the tree, reading a bit at each node to determine
	// which path to take.

	for (;;) {
		bit = read_bit(&decoder->bit_stream_reader);

		if (bit < 0) {
			return -1;
		} else if (bit == 0) {
			child = (*ptr >> 4) & 0x0f;
		} else {
			child = *ptr & 0x0f;
		}

		// Reached a leaf node?

		if (child >= 10) {
			return child - 10;
		}

		ptr += child;
	}
}

// Read a single byte value from the input stream.
// Returns -1 for failure.

static int read_byte(LHAPM1Decoder *decoder)
{
	int index;
	int count;

	// Read the index into the byte_ranges table to use.

	index = read_byte_decode_index(decoder);

	if (index < 0) {
		return -1;
	}

	// Decode value using byte_ranges table. This is actually
	// a distance to walk along the history linked list - it
	// is static huffman encoding, so that recently used byte
	// values use fewer bits.

	count = decode_variable_length(&decoder->bit_stream_reader,
	                               byte_ranges, index);

	if (count < 0) {
		return -1;
	}

	// Walk through the history linked list to get the actual
	// value.

	return find_in_history_list(&decoder->history_list, count);
}

// Read the length of a block of bytes.

static int read_byte_block_count(BitStreamReader *reader)
{
	int x;

	// This is a form of static huffman coding, where smaller
	// lengths are encoded using shorter bit sequences.

	// Value in the range 1..3?

	x = read_bits(reader, 2);

	if (x < 0) {
		return 0;
	} else if (x < 3) {
		return x + 1;
	}

	// Value in the range 4..10?

	x = read_bits(reader, 3);

	if (x < 0) {
		return 0;
	} else if (x < 7) {
		return x + 4;
	}

	// Value in the range 11..25?

	x = read_bits(reader, 4);

	if (x < 0) {
		return 0;
	} else if (x < 14) {
		return x + 11;
	} else if (x == 14) {
		// Value in the range 25-88:

		x = read_bits(reader, 6);

		if (x < 0) {
			return 0;
		} else {
			return x + 25;
		}
	} else { // x = 15
		// Value in the range 89-216:

		x = read_bits(reader, 7);

		if (x < 0) {
			return 0;
		} else {
			return x + 89;
		}
	}
}

// Read a block of bytes from the input stream.
// Returns 0 for failure.

static size_t read_byte_block(LHAPM1Decoder *decoder, uint8_t *buf)
{
	size_t result, result2;
	int byteval;
	int block_len;
	int i;

	// How many bytes to decode?

	block_len = read_byte_block_count(&decoder->bit_stream_reader);

	if (block_len == 0) {
		return 0;
	}

	// Decode the byte values and add them to the output buffer.

	for (i = 0; i < block_len; ++i) {
		byteval = read_byte(decoder);

		if (byteval < 0) {
			return 0;
		}

		buf[i] = byteval;
		outputted_byte(decoder, byteval);
	}

	result = (size_t) block_len;

	// Because this is a block of bytes, it can be assumed that the
	// block ended for a copy command. The one exception is that if
	// the maximum block length was reached, the block may have
	// ended just because it could not be any larger.

	if (result == MAX_BYTE_BLOCK_LEN) {
		return result;
	}

	result2 = read_copy_command(decoder, buf + result);

	if (result2 == 0) {
		return 0;
	}

	return result + result2;
}

static size_t lha_pm1_read(void *data, uint8_t *buf)
{
	LHAPM1Decoder *decoder = data;
	int command_type;

	// Start of input stream? Read the header.

	if (decoder->byte_decode_tree == NULL
	 && !read_start_header(decoder)) {
		return 0;
	}

	// Read what type of command this is.

	command_type = read_bit(&decoder->bit_stream_reader);

	if (command_type == 0) {
		return read_copy_command(decoder, buf);
	} else {
		return read_byte_block(decoder, buf);
	}
}

LHADecoderType lha_pm1_decoder = {
	lha_pm1_init,
	NULL,
	lha_pm1_read,
	sizeof(LHAPM1Decoder),
	OUTPUT_BUFFER_SIZE,
	2048
};
