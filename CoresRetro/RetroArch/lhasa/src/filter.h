/*

Copyright (c) 2012, Simon Howard

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

#ifndef LHASA_FILTER_H
#define LHASA_FILTER_H

#include "lha_reader.h"

typedef struct _LHAFilter LHAFilter;

struct _LHAFilter {
	LHAReader *reader;
	char **filters;
	unsigned int num_filters;
};

/**
 * Initialize a @ref LHAFilter structure to read files from
 * the specified @ref LHAReader, applying the specified list of
 * filters.
 *
 * @param filter       The filter structure to initialize.
 * @param reader       The reader object to read files from.
 * @param filters      List of strings containing glob-style filters
 *                     to apply to the filenames to read.
 * @param num_filters  Number of filters in the 'filters' array.
 */

void lha_filter_init(LHAFilter *filter, LHAReader *reader,
                     char **filters, unsigned int num_filters);

/**
 * Read the next file from the input stream.
 *
 * @param filter       The filter structure.
 * @return             File header structure for the next file that
 *                     matches the filters, or NULL for end of file
 *                     or error.
 */

LHAFileHeader *lha_filter_next_file(LHAFilter *filter);

#endif /* #ifndef LHASA_FILTER_H */
