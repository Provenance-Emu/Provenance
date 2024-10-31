/*

Copyright (c) 2011, 2012, 2013, Simon Howard

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
// Decoder for the -lhx- algorithm. Provided by Multi.
//
// -lhx- is Unlha32.dll's original extension. Some unique archivers
// support it.
//

// 128 KiB history ring buffer:
// -lhx-'s maximum dictionary size is 2^19. 2x ring buffer is required.

#define HISTORY_BITS    20   /* 2^20 = 1048576. */

// Number of bits to encode HISTORY_BITS:

#define OFFSET_BITS     5

// Name of the variable for the encoder:

#define DECODER_NAME lha_lhx_decoder

// Number of different command codes. 0-255 range are literal byte
// values, while higher values indicate copy from history.

#define NUM_CODES            510

// The actual algorithm code is contained in lh_new_decoder.c, which
// acts as a template for -lh4-, -lh5-, -lh6-, -lh7- and -lhx-.

#include "lh_new_decoder.c"
