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

#ifndef LHASA_EXT_HEADER_H
#define LHASA_EXT_HEADER_H

#include <stdlib.h>

#include "lha_file_header.h"

/**
 * Decode the specified extended header.
 *
 * @param header    The file header in which to store decoded data.
 * @param num       Extended header type.
 * @param data      Pointer to the data to decode.
 * @param data_len  Size of the data to decode, in bytes.
 * @return          Non-zero for success, or zero if not decoded.
 */

int lha_ext_header_decode(LHAFileHeader *header,
                          uint8_t num,
                          uint8_t *data,
                          size_t data_len);

#endif /* #ifndef LHASA_EXT_HEADER_H */
