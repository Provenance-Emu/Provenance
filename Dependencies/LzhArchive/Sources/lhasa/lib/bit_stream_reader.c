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
// Data structure used to read bits from an input source as a stream.
//
// This file is designed to be #included by other source files to
// make a complete decoder.
//

typedef struct {

	// Callback function to invoke to read more data from the
	// input stream.

	LHADecoderCallback callback;
	void *callback_data;

	// Bits from the input stream that are waiting to be read.

	uint32_t bit_buffer;
	unsigned int bits;

} BitStreamReader;

// Initialize bit stream reader structure.

static void bit_stream_reader_init(BitStreamReader *reader,
                                   LHADecoderCallback callback,
                                   void *callback_data)
{
	reader->callback = callback;
	reader->callback_data = callback_data;

	reader->bits = 0;
	reader->bit_buffer = 0;
}

// Return the next n bits waiting to be read from the input stream,
// without removing any.  Returns -1 for failure.

static int peek_bits(BitStreamReader *reader,
                     unsigned int n)
{
	uint8_t buf[4];
	size_t bytes, i;

	if (n == 0) {
		return 0;
	}

	// If there are not enough bits in the buffer to satisfy this
	// request, we need to fill up the buffer with more bits.

	while (reader->bits < n) {

		// Maximum number of bytes we can fill?

		const unsigned int fill_bytes = (32 - reader->bits) / 8;

		// Read from input and fill bit_buffer.

		bytes = reader->callback(buf, fill_bytes,
		                         reader->callback_data);

		// End of file?

		if (bytes == 0) {
			return -1;
		}

		for (i = 0; i < bytes; i++) {
			reader->bit_buffer |=
				(uint32_t) buf[i] << (24 - reader->bits);
			reader->bits += 8;
		}
	}

	return (signed int) (reader->bit_buffer >> (32 - n));
}

// Read a bit from the input stream.
// Returns -1 for failure.

static int read_bits(BitStreamReader *reader,
                     unsigned int n)
{
	int result;

	result = peek_bits(reader, n);

	if (result >= 0) {
		reader->bit_buffer <<= n;
		reader->bits -= n;
	}

	return result;
}


// Read a bit from the input stream.
// Returns -1 for failure.

static int read_bit(BitStreamReader *reader)
{
	return read_bits(reader, 1);
}
