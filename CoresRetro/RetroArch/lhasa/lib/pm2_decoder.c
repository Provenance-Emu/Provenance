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

//
// Decoder for PMarc -pm2- compression format.  PMarc is a variant
// of LHA commonly used on the MSX computer architecture.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include "lha_decoder.h"

#include "bit_stream_reader.c"
#include "pma_common.c"

// Include tree decoder.

typedef uint8_t TreeElement;
#include "tree_decode.c"

// Size of the ring buffer (in bytes) used to store past history
// for copies.

#define RING_BUFFER_SIZE      8192

// Maximum number of bytes that might be placed in the output buffer
// from a single call to lha_pm2_decoder_read (largest copy size).

#define OUTPUT_BUFFER_SIZE    256

// Number of tree elements in the code tree.

#define CODE_TREE_ELEMENTS    65

// Number of tree elements in the offset tree.

#define OFFSET_TREE_ELEMENTS  17

typedef enum {
	PM2_REBUILD_UNBUILT,          // At start of stream
	PM2_REBUILD_BUILD1,           // After 1KiB
	PM2_REBUILD_BUILD2,           // After 2KiB
	PM2_REBUILD_BUILD3,           // After 4KiB
	PM2_REBUILD_CONTINUING,       // 8KiB onwards...
} PM2RebuildState;

typedef struct {
	BitStreamReader bit_stream_reader;

	// State of decode tree.

	PM2RebuildState tree_state;

	// Number of bytes until we initiate a tree rebuild.

	size_t tree_rebuild_remaining;

	// History ring buffer, for copies:

	uint8_t ringbuf[RING_BUFFER_SIZE];
	unsigned int ringbuf_pos;

	// History linked list, for adaptively encoding byte values.

	HistoryLinkedList history_list;

	// Array representing the huffman tree used for representing
	// code values. A given node of the tree has children
	// code_tree[n] and code_tree[n + 1].  code_tree[0] is the
	// root node.

	TreeElement code_tree[CODE_TREE_ELEMENTS];

	// If zero, we don't need an offset tree:

	int need_offset_tree;

	// Array representing huffman tree used to look up offsets.
	// Same format as code_tree[].

	TreeElement offset_tree[OFFSET_TREE_ELEMENTS];

} LHAPM2Decoder;

// Decode table for history value. Characters that appeared recently in
// the history are more likely than ones that appeared a long time ago,
// so the history value is huffman coded so that small values require
// fewer bits. The history value is then used to search within the
// history linked list to get the actual character.

static const VariableLengthTable history_decode[] = {
	{   0, 3 },   //   0 + (1 << 3) =   8
	{   8, 3 },   //   8 + (1 << 3) =  16
	{  16, 4 },   //  16 + (1 << 4) =  32
	{  32, 5 },   //  32 + (1 << 5) =  64
	{  64, 5 },   //  64 + (1 << 5) =  96
	{  96, 5 },   //  96 + (1 << 5) = 128
	{ 128, 6 },   // 128 + (1 << 6) = 192
	{ 192, 6 },   // 192 + (1 << 6) = 256
};

// Decode table for copies. As with history_decode[], small copies
// are more common, and require fewer bits.

static const VariableLengthTable copy_decode[] = {
	{  17, 3 },   //  17 + (1 << 3) =  25
	{  25, 3 },   //  25 + (1 << 3) =  33
	{  33, 5 },   //  33 + (1 << 5) =  65
	{  65, 6 },   //  65 + (1 << 6) = 129
	{ 129, 7 },   // 129 + (1 << 7) = 256
	{ 256, 0 },   // 256 (unique value)
};

// Initialize PMA decoder.

static int lha_pm2_decoder_init(void *data, LHADecoderCallback callback,
                                void *callback_data)
{
	LHAPM2Decoder *decoder = data;

	bit_stream_reader_init(&decoder->bit_stream_reader,
	                       callback, callback_data);

	// Tree has not been built yet.  It needs to be built on
	// the first call to read().

	decoder->tree_state = PM2_REBUILD_UNBUILT;
	decoder->tree_rebuild_remaining = 0;

	// Initialize ring buffer contents.

	memset(&decoder->ringbuf, ' ', RING_BUFFER_SIZE);
	decoder->ringbuf_pos = 0;

	// Init history lookup list.

	init_history_list(&decoder->history_list);

	// Initialize the lookup trees to a known state.

	init_tree(decoder->code_tree, CODE_TREE_ELEMENTS);
	init_tree(decoder->offset_tree, OFFSET_TREE_ELEMENTS);

	return 1;
}

// Read the list of code lengths to use for the code tree and construct
// the code_tree structure.

static int read_code_tree(LHAPM2Decoder *decoder)
{
	uint8_t code_lengths[31];
	int num_codes, min_code_length, length_bits, val;
	unsigned int i;

	// Read the number of codes in the tree.

	num_codes = read_bits(&decoder->bit_stream_reader, 5);

	// Read min_code_length, which is used as an offset.

	min_code_length = read_bits(&decoder->bit_stream_reader, 3);

	if (min_code_length < 0 || num_codes < 0) {
		return 0;
	}

	// Store flag variable indicating whether we want to read
	// the offset tree as well.

	decoder->need_offset_tree
	    = num_codes >= 10
	   && !(num_codes == 29 && min_code_length == 0);

	// Minimum length of zero means a tree containing a single code.

	if (min_code_length == 0) {
		set_tree_single(decoder->code_tree, num_codes - 1);
		return 1;
	}

	// How many bits are used to represent each table entry?

	length_bits = read_bits(&decoder->bit_stream_reader, 3);

	if (length_bits < 0) {
		return 0;
	}

	// Read table of code lengths:

	for (i = 0; i < (unsigned int) num_codes; ++i) {

		// Read a table entry.  A value of zero represents an
		// unused code.  Otherwise the value represents
		// an offset from the minimum length (previously read).

		val = read_bits(&decoder->bit_stream_reader,
		                (unsigned int) length_bits);

		if (val < 0) {
			return 0;
		} else if (val == 0) {
			code_lengths[i] = 0;
		} else {
			code_lengths[i] = (uint8_t) (min_code_length + val - 1);
		}
	}

	// Build the tree.

	build_tree(decoder->code_tree, sizeof(decoder->code_tree),
	           code_lengths, (unsigned int) num_codes);

	return 1;
}

// Read the code lengths for the offset tree and construct the offset
// tree lookup table.

static int read_offset_tree(LHAPM2Decoder *decoder,
                            unsigned int num_offsets)
{
	uint8_t offset_lengths[8];
	unsigned int off;
	unsigned int single_offset, num_codes;
	int len;

	if (!decoder->need_offset_tree) {
		return 1;
	}

	// Read 'num_offsets' 3-bit length values.  For each offset
	// value 'off', offset_lengths[off] is the length of the
	// code that will represent 'off', or 0 if it will not
	// appear within the tree.

	num_codes = 0;
	single_offset = 0;

	for (off = 0; off < num_offsets; ++off) {
		len = read_bits(&decoder->bit_stream_reader, 3);

		if (len < 0) {
			return 0;
		}

		offset_lengths[off] = (uint8_t) len;

		// Track how many actual codes were in the tree.

		if (len != 0) {
			single_offset = off;
			++num_codes;
		}
	}

	// If there was a single code, this is a single node tree.

	if (num_codes == 1) {
		set_tree_single(decoder->offset_tree, single_offset);
		return 1;
	}

	// Build the tree.

	build_tree(decoder->offset_tree, sizeof(decoder->offset_tree),
	           offset_lengths, num_offsets);

	return 1;
}

// Rebuild the decode trees used to compress data.  This is called when
// decoder->tree_rebuild_remaining reaches zero.

static void rebuild_tree(LHAPM2Decoder *decoder)
{
	switch (decoder->tree_state) {

		// Initial tree build, from start of stream:

		case PM2_REBUILD_UNBUILT:
			read_code_tree(decoder);
			read_offset_tree(decoder, 5);
			decoder->tree_state = PM2_REBUILD_BUILD1;
			decoder->tree_rebuild_remaining = 1024;
			break;

		// Tree rebuild after 1KiB of data has been read:

		case PM2_REBUILD_BUILD1:
			read_offset_tree(decoder, 6);
			decoder->tree_state = PM2_REBUILD_BUILD2;
			decoder->tree_rebuild_remaining = 1024;
			break;

		// Tree rebuild after 2KiB of data has been read:

		case PM2_REBUILD_BUILD2:
			read_offset_tree(decoder, 7);
			decoder->tree_state = PM2_REBUILD_BUILD3;
			decoder->tree_rebuild_remaining = 2048;
			break;

		// Tree rebuild after 4KiB of data has been read:

		case PM2_REBUILD_BUILD3:
			if (read_bit(&decoder->bit_stream_reader) == 1) {
				read_code_tree(decoder);
			}
			read_offset_tree(decoder, 8);
			decoder->tree_state = PM2_REBUILD_CONTINUING;
			decoder->tree_rebuild_remaining = 4096;
			break;

		// Tree rebuild after 8KiB of data has been read,
		// and every 4KiB after that:

		case PM2_REBUILD_CONTINUING:
			if (read_bit(&decoder->bit_stream_reader) == 1) {
				read_code_tree(decoder);
				read_offset_tree(decoder, 8);
			}
			decoder->tree_rebuild_remaining = 4096;
			break;
	}
}

static void output_byte(LHAPM2Decoder *decoder, uint8_t *buf,
                        size_t *buf_len, uint8_t b)
{
	// Add to history ring buffer.

	decoder->ringbuf[decoder->ringbuf_pos] = b;
	decoder->ringbuf_pos = (decoder->ringbuf_pos + 1) % RING_BUFFER_SIZE;

	// Add to output buffer.

	buf[*buf_len] = b;
	++*buf_len;

	// Update history chain.

	update_history_list(&decoder->history_list, b);

	// Count down until it is time to perform a rebuild of the
	// lookup trees.

	--decoder->tree_rebuild_remaining;

	if (decoder->tree_rebuild_remaining == 0) {
		rebuild_tree(decoder);
	}
}

// Read a single byte from the input stream and add it to the output
// buffer.

static void read_single_byte(LHAPM2Decoder *decoder, unsigned int code,
                             uint8_t *buf, size_t *buf_len)
{
	int offset;
	uint8_t b;

	offset = decode_variable_length(&decoder->bit_stream_reader,
	                                history_decode, code);

	if (offset < 0) {
		return;
	}

	b = find_in_history_list(&decoder->history_list, (uint8_t) offset);
	output_byte(decoder, buf, buf_len, b);
}

// Calculate how many bytes from history to copy:

static int history_get_count(LHAPM2Decoder *decoder, unsigned int code)
{
	// How many bytes to copy?  A small value represents the
	// literal number of bytes to copy; larger values are a header
	// for a variable length value to be decoded.

	if (code < 15) {
		return (int) code + 2;
	} else {
		return decode_variable_length(&decoder->bit_stream_reader,
		                              copy_decode, code - 15);
	}
}

// Calculate the offset within history at which to start copying:

static int history_get_offset(LHAPM2Decoder *decoder, unsigned int code)
{
	unsigned int bits;
	int result, val;

	result = 0;

	// Calculate number of bits to read.

	// Code of zero indicates a simple 6-bit value giving the offset.

	if (code == 0) {
		bits = 6;
	}

	// Mid-range encoded offset value.
	// Read a code using the offset tree, indicating the length
	// of the offset value to follow.  The code indicates the
	// number of bits (values 0-7 = 6-13 bits).

	else if (code < 20) {

		val = read_from_tree(&decoder->bit_stream_reader,
		                     decoder->offset_tree);

		if (val < 0) {
			return -1;
		} else if (val == 0) {
			bits = 6;
		} else {
			bits = (unsigned int) val + 5;
			result = 1 << bits;
		}
	}

	// Large copy values start from offset zero.

	else {
		return 0;
	}

	// Read a number of bits representing the offset value.  The
	// number of length of this value is variable, and is calculated
	// above.

	val = read_bits(&decoder->bit_stream_reader, bits);

	if (val < 0) {
		return -1;
	}

	result += val;

	return result;
}

static void copy_from_history(LHAPM2Decoder *decoder, unsigned int code,
                              uint8_t *buf, size_t *buf_len)
{
	int to_copy, offset;
	unsigned int i, pos, start;

	// Read number of bytes to copy and offset within history to copy
	// from.

	to_copy = history_get_count(decoder, code);
	offset = history_get_offset(decoder, code);

	if (to_copy < 0 || offset < 0) {
		return;
	}

	// Sanity check to prevent the potential for buffer overflow.

	if (to_copy > OUTPUT_BUFFER_SIZE) {
		return;
	}

	// Perform copy.

	start = decoder->ringbuf_pos + RING_BUFFER_SIZE - 1
	      - (unsigned int) offset;

	for (i = 0; i < (unsigned int) to_copy; ++i) {
		pos = (start + i) % RING_BUFFER_SIZE;

		output_byte(decoder, buf, buf_len, decoder->ringbuf[pos]);
	}
}

// Decode data and store it into buf[], returning the number of
// bytes decoded.

static size_t lha_pm2_decoder_read(void *data, uint8_t *buf)
{
	LHAPM2Decoder *decoder = data;
	size_t result;
	int code;

	// On first pass through, build initial lookup trees.

	if (decoder->tree_state == PM2_REBUILD_UNBUILT) {

		// First bit in stream is discarded?

		read_bit(&decoder->bit_stream_reader);
		rebuild_tree(decoder);
	}

	result = 0;

	code = read_from_tree(&decoder->bit_stream_reader, decoder->code_tree);

	if (code < 0) {
		return 0;
	}

	if (code < 8) {
		read_single_byte(decoder, (unsigned int) code, buf, &result);
	} else {
		copy_from_history(decoder, (unsigned int) code - 8,
		                  buf, &result);
	}

	return result;
}

LHADecoderType lha_pm2_decoder = {
	lha_pm2_decoder_init,
	NULL,
	lha_pm2_decoder_read,
	sizeof(LHAPM2Decoder),
	OUTPUT_BUFFER_SIZE,
	RING_BUFFER_SIZE
};
