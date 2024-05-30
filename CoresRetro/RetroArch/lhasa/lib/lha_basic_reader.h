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

#ifndef LHASA_LHA_BASIC_READER_H
#define LHASA_LHA_BASIC_READER_H

#include "lha_input_stream.h"
#include "lha_file_header.h"
#include "lha_decoder.h"

/**
 * Basic LHA stream reader.
 *
 * The basic reader structure just reads @ref LHAFileHeader structures
 * from an input stream and decompresses files. The more elaborate
 * @ref LHAReader builds upon this to offer more complicated functionality.
 */

typedef struct _LHABasicReader LHABasicReader;

/**
 * Create a new LHA reader to read data from an input stream.
 *
 * @param stream     The input stream to read from.
 * @return           Pointer to an LHABasicReader structure, or NULL for error.
 */

LHABasicReader *lha_basic_reader_new(LHAInputStream *stream);

/**
 * Free an LHA reader.
 *
 * @param reader     The LHABasicReader structure.
 */

void lha_basic_reader_free(LHABasicReader *reader);

/**
 * Return the last file read by @ref lha_basic_reader_next_file.
 *
 * @param reader     The LHABasicReader structure.
 * @return           Last file returned by @ref lha_basic_reader_next_file,
 *                   or NULL if no file has been read yet.
 */

LHAFileHeader *lha_basic_reader_curr_file(LHABasicReader *reader);

/**
 * Read the header of the next archived file from the input stream.
 *
 * @param reader     The LHABasicReader structure.
 * @return           Pointer to an LHAFileHeader structure, or NULL if
 *                   an error occurred.  This pointer is only valid until
 *                   the next time that lha_basic_reader_next_file is called.
 */

LHAFileHeader *lha_basic_reader_next_file(LHABasicReader *reader);

/**
 * Read some of the compressed data for the current archived file.
 *
 * @param reader     The LHABasicReader structure.
 * @param buf        Pointer to the buffer in which to store the data.
 * @param buf_len    Size of the buffer, in bytes.
 */

size_t lha_basic_reader_read_compressed(LHABasicReader *reader, void *buf,
                                       size_t buf_len);

/**
 * Create a decoder object to decompress the compressed data in the
 * current file.
 *
 * @param reader     The LHABasicReader structure.
 * @return           Pointer to a @ref LHADecoder structure to decompress
 *                   the current file, or NULL for failure.
 */

LHADecoder *lha_basic_reader_decode(LHABasicReader *reader);

#endif /* #ifndef LHASA_LHA_BASIC_READER_H */
