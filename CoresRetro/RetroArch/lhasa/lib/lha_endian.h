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

#ifndef LHASA_LHA_ENDIAN_H
#define LHASA_LHA_ENDIAN_H

#include <inttypes.h>

/**
 * Decode a 16-bit little-endian unsigned integer.
 *
 * @param buf       Pointer to buffer containing value to decode.
 * @return          Decoded value.
 */

uint16_t lha_decode_uint16(uint8_t *buf);

/**
 * Decode a 32-bit little-endian unsigned integer.
 *
 * @param buf       Pointer to buffer containing value to decode.
 * @return          Decoded value.
 */

uint32_t lha_decode_uint32(uint8_t *buf);

/**
 * Decode a 64-bit little-endian unsigned integer.
 *
 * @param buf       Pointer to buffer containing value to decode.
 * @return          Decoded value.
 */

uint64_t lha_decode_uint64(uint8_t *buf);

/**
 * Decode a 16-bit big-endian unsigned integer.
 *
 * @param buf       Pointer to buffer containing value to decode.
 * @return          Decoded value.
 */

uint16_t lha_decode_be_uint16(uint8_t *buf);

/**
 * Decode a 32-bit big-endian unsigned integer.
 *
 * @param buf       Pointer to buffer containing value to decode.
 * @return          Decoded value.
 */

uint32_t lha_decode_be_uint32(uint8_t *buf);

#endif /* #ifndef LHASA_LHA_ENDIAN_H */
