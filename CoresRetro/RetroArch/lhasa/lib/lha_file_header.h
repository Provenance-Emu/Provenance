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


#ifndef LHASA_LHA_FILE_HEADER_H
#define LHASA_LHA_FILE_HEADER_H

#include "public/lha_file_header.h"
#include "lha_input_stream.h"

/**
 * Read a file header from the input stream.
 *
 * @param stream         The input stream to read from.
 * @return               Pointer to a new LHAFileHeader structure, or NULL
 *                       if an error occurred or a valid header could not
 *                       be read.
 */

LHAFileHeader *lha_file_header_read(LHAInputStream *stream);

/**
 * Free a file header structure.
 *
 * @param header         The file header to free.
 */

void lha_file_header_free(LHAFileHeader *header);

/**
 * Add a reference to the specified file header, to stop it from being
 * freed.
 *
 * @param header         The file header to add a reference to.
 */

void lha_file_header_add_ref(LHAFileHeader *header);

/**
 * Get the full path for the given file header.
 *
 * @param header     Pointer to the file header structure.
 * @return           Pointer to an allocated string containing the full
 *                   file or directory path, or NULL for failure. The
 *                   string must be freed by the caller.
 */

char *lha_file_header_full_path(LHAFileHeader *header);

#endif /* #ifndef LHASA_LHA_FILE_HEADER_H */
