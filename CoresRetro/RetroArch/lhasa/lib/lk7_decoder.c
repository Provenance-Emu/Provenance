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
// Decoder for the -lk7- algorithm, AKA LHARK's -lh7-.
//
// This algorithm is a modified version of -lh5- that appeared in Kerwin
// Medina's LHARK tool named as -lh7-. Within Lhasa we rename this to
// -lk7- to distinguish it from the normal -lh7- that other tools
// recognize and generate.
//
// I'm indebted to Jason Summers, his tool DEARK, and his comprehensive
// article "Notes on LHARK compression format", found here:
// <https://entropymine.wordpress.com/2020/12/24/notes-on-lhark-compression-format/>
//

// 64 KiB history ring buffer:

#define HISTORY_BITS    16   /* 2^16 = 65536 */

// Number of bits to encode HISTORY_BITS:

#define OFFSET_BITS     6

// Name of the variable for the encoder:

#define DECODER_NAME lha_lk7_decoder

// Number of different command codes. 0-255 range are literal byte
// values, while higher values indicate copy from history.

#define NUM_CODES            289

// We enable some special behavior that is specific to this algorithm.

#define LHARK

// The actual algorithm code is contained in lh_new_decoder.c, which
// acts as a template for this and other algorithms.

#include "lh_new_decoder.c"
