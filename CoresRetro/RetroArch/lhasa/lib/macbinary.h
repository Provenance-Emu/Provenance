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

#ifndef LHASA_MACBINARY_H
#define LHASA_MACBINARY_H

#include "lha_decoder.h"
#include "lha_file_header.h"

/**
 * Create a passthrough decoder to handle MacBinary headers added
 * by MacLHA.
 *
 * The new decoder reads from the specified decoder and filters
 * out the header. The contents of the MacBinary header must match
 * the details from the specified file header.
 *
 * @param decoder      The "inner" decoder from which to read data.
 * @param header       The file header, that the contents of the
 *                     MacBinary header must match.
 * @return             A new decoder, which passes through the
 *                     contents of the inner decoder, stripping
 *                     off the MacBinary header and truncating
 *                     as appropriate. Both decoders must be freed
 *                     by the caller.
 */

LHADecoder *lha_macbinary_passthrough(LHADecoder *decoder,
                                      LHAFileHeader *header);

#endif /* #ifndef LHASA_MACBINARY_H */
