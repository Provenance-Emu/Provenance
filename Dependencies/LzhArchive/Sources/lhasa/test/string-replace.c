/*

Copyright (c) 2022, Simon Howard

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

// Simple string replace filter program, written from scratch to avoid
// the inconsistencies between how different versions of sed handle
// newlines at EOF.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#define CHUNKSIZE 256

int main(int argc, char *argv[])
{
	char *buf = NULL;
	size_t nbytes = 0, i, needle_len;

	assert(argc == 3);

	while (!feof(stdin)) {
		buf = realloc(buf, nbytes + CHUNKSIZE);
		assert(buf != NULL);
		nbytes += fread(buf + nbytes, 1, CHUNKSIZE, stdin);
	}

	needle_len = strlen(argv[1]);

	for (i = 0; i < nbytes; ) {
		if (nbytes - i >= needle_len
		 && !memcmp(&buf[i], argv[1], needle_len)) {
			printf("%s", argv[2]);
			i += needle_len;
		} else {
			putchar(buf[i]);
			i++;
		}
	}

	free(buf);
	return 0;
}

