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

#include "crc16.h"

#include "lha_decoder.h"
#include "lha_basic_reader.h"

struct _LHABasicReader {
	LHAInputStream *stream;
	LHAFileHeader *curr_file;
	size_t curr_file_remaining;
	int eof;
};

LHABasicReader *lha_basic_reader_new(LHAInputStream *stream)
{
	LHABasicReader *reader;

	reader = calloc(1, sizeof(LHABasicReader));

	if (reader == NULL) {
		return NULL;
	}

	reader->stream = stream;
	reader->curr_file = NULL;
	reader->curr_file_remaining = 0;
	reader->eof = 0;

	return reader;
}

void lha_basic_reader_free(LHABasicReader *reader)
{
	if (reader->curr_file != NULL) {
		lha_file_header_free(reader->curr_file);
	}

	free(reader);
}

LHAFileHeader *lha_basic_reader_curr_file(LHABasicReader *reader)
{
	return reader->curr_file;
}

LHAFileHeader *lha_basic_reader_next_file(LHABasicReader *reader)
{
	// Free the current file header and skip over any remaining
	// compressed data that hasn't been read yet.

	if (reader->curr_file != NULL) {
		lha_file_header_free(reader->curr_file);
		reader->curr_file = NULL;

		if (!lha_input_stream_skip(reader->stream,
		                           reader->curr_file_remaining)) {
			reader->eof = 1;
		}
	}

	if (reader->eof) {
		return NULL;
	}

	// Read the header for the next file.

	reader->curr_file = lha_file_header_read(reader->stream);

	if (reader->curr_file == NULL) {
		reader->eof = 1;
		return NULL;
	}

	reader->curr_file_remaining = reader->curr_file->compressed_length;

	return reader->curr_file;
}

size_t lha_basic_reader_read_compressed(LHABasicReader *reader, void *buf,
                                        size_t buf_len)
{
	size_t bytes;

	if (reader->eof || reader->curr_file_remaining == 0) {
		return 0;
	}

	// Read up to the number of bytes of compressed data remaining.

	if (buf_len > reader->curr_file_remaining) {
		bytes = reader->curr_file_remaining;
	} else {
		bytes = buf_len;
	}

	if (!lha_input_stream_read(reader->stream, buf, bytes)) {
		reader->eof = 1;
		return 0;
	}

	// Update counter and return success.

	reader->curr_file_remaining -= bytes;

	return bytes;
}

static size_t decoder_callback(void *buf, size_t buf_len, void *user_data)
{
	return lha_basic_reader_read_compressed(user_data, buf, buf_len);
}

// Create the decoder structure to decode the current file.

LHADecoder *lha_basic_reader_decode(LHABasicReader *reader)
{
	LHADecoderType *dtype;

	if (reader->curr_file == NULL) {
		return NULL;
	}

	// Look up the decoder to use for this compression method.

	dtype = lha_decoder_for_name(reader->curr_file->compress_method);

	if (dtype == NULL) {
		return NULL;
	}

	// Create decoder.

	return lha_decoder_new(dtype, decoder_callback, reader,
	                       reader->curr_file->length);
}
