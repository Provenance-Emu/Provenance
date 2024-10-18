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

// Null decoder, for uncompressed files.

#include <stdlib.h>
#include <inttypes.h>

#include "lha_decoder.h"

#define BLOCK_READ_SIZE 1024

typedef struct {
	LHADecoderCallback callback;
	void *callback_data;
} LHANullDecoder;

static int lha_null_init(void *data, LHADecoderCallback callback,
                         void *callback_data)
{
	LHANullDecoder *decoder = data;

	decoder->callback = callback;
	decoder->callback_data = callback_data;

	return 1;
}

static size_t lha_null_read(void *data, uint8_t *buf)
{
	LHANullDecoder *decoder = data;

	return decoder->callback(buf, BLOCK_READ_SIZE, decoder->callback_data);
}

LHADecoderType lha_null_decoder = {
	lha_null_init,
	NULL,
	lha_null_read,
	sizeof(LHANullDecoder),
	BLOCK_READ_SIZE,
	2048
};
