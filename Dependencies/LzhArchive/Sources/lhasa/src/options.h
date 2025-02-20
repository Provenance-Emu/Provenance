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

#ifndef LHASA_OPTIONS_H
#define LHASA_OPTIONS_H

typedef enum {
	LHA_OVERWRITE_PROMPT,
	LHA_OVERWRITE_SKIP,
	LHA_OVERWRITE_ALL
} LHAOverwritePolicy;

// Options structure. Populated from command line arguments.

typedef struct {

	// Policy to take when extracting files and a file
	// already exists.

	LHAOverwritePolicy overwrite_policy;

	// "Quiet" level. Normal operation is level 0.

	int quiet;

	// "Verbose" mode.

	int verbose;

	// If true, just perform a dry run of the operations that
	// would normally be performed, printing messages.

	int dry_run;

	// If not NULL, specifies a path into which to extract files.

	char *extract_path;

	// If true, use the directory path for files - otherwise,
	// the directory path is ignored.

	int use_path;

} LHAOptions;

#endif /* #ifndef LHASA_OPTIONS_H */
