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

#ifndef LHASA_PUBLIC_LHA_DECODER_H
#define LHASA_PUBLIC_LHA_DECODER_H

#include <stdlib.h>
#include <inttypes.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @file lha_decoder.h
 *
 * @brief Raw LHA data decoder.
 *
 * This file defines the interface to the decompression code, which can
 * be used to decompress the raw compressed data from an LZH file.
 *
 * Implementations of the various compression algorithms used in LZH
 * archives are provided - these are represented by the
 * @ref LHADecoderType structure, and can be retrieved using the
 * @ref lha_decoder_for_name function. One of these can then be passed to
 * the @ref lha_decoder_new function to create a @ref LHADecoder structure
 * and decompress the data.
 */

/**
 * Opaque type representing a type of decoder.
 *
 * This is an implementation of the decompression code for one of the
 * algorithms used in LZH archive files. Pointers to these structures are
 * retrieved by using the @ref lha_decoder_for_name function.
 */

typedef struct _LHADecoderType LHADecoderType;

/**
 * Opaque type representing an instance of a decoder.
 *
 * This is a decoder structure being used to decompress a stream of
 * compressed data. Instantiated using the @ref lha_decoder_new
 * function and freed using the @ref lha_decoder_free function.
 */

typedef struct _LHADecoder LHADecoder;

/**
 * Callback function invoked when a decoder wants to read more compressed
 * data.
 *
 * @param buf        Pointer to the buffer in which to store the data.
 * @param buf_len    Size of the buffer, in bytes.
 * @param user_data  Extra pointer to pass to the decoder.
 * @return           Number of bytes read.
 */

typedef size_t (*LHADecoderCallback)(void *buf, size_t buf_len,
                                     void *user_data);

/**
 * Callback function used for monitoring decode progress.
 * The callback is invoked for every block processed (block size depends on
 * decode algorithm).
 *
 * @param num_blocks      Number of blocks processed so far.
 * @param total_blocks    Total number of blocks to process.
 * @param callback_data  Extra user-specified data passed to the callback.
 */

typedef void (*LHADecoderProgressCallback)(unsigned int num_blocks,
                                           unsigned int total_blocks,
                                           void *callback_data);

/**
 * Get the decoder type for the specified name.
 *
 * @param name           String identifying the decoder type, for
 *                       example, "-lh1-".
 * @return               Pointer to the decoder type, or NULL if there
 *                       is no decoder type for the specified name.
 */

LHADecoderType *lha_decoder_for_name(char *name);

/**
 * Allocate a new decoder for the specified type.
 *
 * @param dtype          The decoder type.
 * @param callback       Callback function for the decoder to call to read
 *                       more compressed data.
 * @param callback_data  Extra data to pass to the callback function.
 * @param stream_length  Length of the uncompressed data, in bytes. When
 *                       this point is reached, decompression will stop.
 * @return               Pointer to the new decoder, or NULL for failure.
 */

LHADecoder *lha_decoder_new(LHADecoderType *dtype,
                            LHADecoderCallback callback,
                            void *callback_data,
                            size_t stream_length);

/**
 * Free a decoder.
 *
 * @param decoder        The decoder to free.
 */

void lha_decoder_free(LHADecoder *decoder);

/**
 * Set a callback function to monitor decode progress.
 *
 * @param decoder        The decoder.
 * @param callback       Callback function to monitor decode progress.
 * @param callback_data  Extra data to pass to the decoder.
 */

void lha_decoder_monitor(LHADecoder *decoder,
                         LHADecoderProgressCallback callback,
                         void *callback_data);

/**
 * Decode (decompress) more data.
 *
 * @param decoder        The decoder.
 * @param buf            Pointer to buffer to store decompressed data.
 * @param buf_len        Size of the buffer, in bytes.
 * @return               Number of bytes decompressed.
 */

size_t lha_decoder_read(LHADecoder *decoder, uint8_t *buf, size_t buf_len);

/**
 * Get the current 16-bit CRC of the decompressed data.
 *
 * This should be called at the end of decompression to check that the
 * data was extracted correctly, and the value compared against the CRC
 * from the file header.
 *
 * @param decoder        The decoder.
 * @return               16-bit CRC of the data decoded so far.
 */

uint16_t lha_decoder_get_crc(LHADecoder *decoder);

/**
 * Get the count of the number of bytes decoded.
 *
 * This should be called at the end of decompression, and the value
 * compared against the file length from the file header.
 *
 * @param decoder        The decoder.
 * @return               The number of decoded bytes.
 */

size_t lha_decoder_get_length(LHADecoder *decoder);

#ifdef __cplusplus
}
#endif

#endif /* #ifndef LHASA_LHA_DECODER_H */
