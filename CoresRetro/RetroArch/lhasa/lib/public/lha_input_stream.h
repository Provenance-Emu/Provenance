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


#ifndef LHASA_PUBLIC_LHA_INPUT_STREAM_H
#define LHASA_PUBLIC_LHA_INPUT_STREAM_H

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @file lha_input_stream.h
 *
 * @brief LHA input stream structure.
 *
 * This file defines the functions relating to the @ref LHAInputStream
 * structure, used to read data from an LZH file.
 */

/**
 * Opaque structure, representing an input stream used to read data from
 * an LZH file.
 */

typedef struct _LHAInputStream LHAInputStream;

/**
 * Structure containing pointers to callback functions to read data from
 * the input stream.
 */

typedef struct {

	/**
	 * Read a block of data into the specified buffer.
	 *
	 * @param handle       Handle pointer.
	 * @param buf          Pointer to buffer in which to store read data.
	 * @param buf_len      Size of buffer, in bytes.
	 * @return             Number of bytes read, or -1 for error.
	 */

	int (*read)(void *handle, void *buf, size_t buf_len);


	/**
	 * Skip the specified number of bytes from the input stream.
	 * This is an optional function.
	 *
	 * @param handle       Handle pointer.
	 * @param bytes        Number of bytes to skip.
	 * @return             Non-zero for success, or zero for failure.
	 */

	int (*skip)(void *handle, size_t bytes);

	/**
	 * Close the input stream.
	 *
	 * @param handle       Handle pointer.
	 */

	void (*close)(void *handle);

} LHAInputStreamType;

/**
 * Create new @ref LHAInputStream structure, using a set of generic functions
 * to provide LHA data.
 *
 * @param type         Pointer to a @ref LHAInputStreamType structure
 *                     containing callback functions to read data.
 * @param handle       Handle pointer to be passed to callback functions.
 * @return             Pointer to a new @ref LHAInputStream or NULL for error.
 */

LHAInputStream *lha_input_stream_new(const LHAInputStreamType *type,
                                     void *handle);

/**
 * Create new @ref LHAInputStream, reading from the specified filename.
 * The file is automatically closed when the input stream is freed.
 *
 * @param filename     Name of the file to read from.
 * @return             Pointer to a new @ref LHAInputStream or NULL for error.
 */

LHAInputStream *lha_input_stream_from(char *filename);

/**
 * Create new @ref LHAInputStream, to read from an already-open FILE pointer.
 * The FILE is not closed when the input stream is freed; the calling code
 * must close it.
 *
 * @param stream       The open FILE structure from which to read data.
 * @return             Pointer to a new @ref LHAInputStream or NULL for error.
 */

LHAInputStream *lha_input_stream_from_FILE(FILE *stream);

/**
 * Free an @ref LHAInputStream structure.
 *
 * @param stream       The input stream.
 */

void lha_input_stream_free(LHAInputStream *stream);

#ifdef __cplusplus
}
#endif

#endif /* #ifndef LHASA_PUBLIC_LHA_INPUT_STREAM_H */
