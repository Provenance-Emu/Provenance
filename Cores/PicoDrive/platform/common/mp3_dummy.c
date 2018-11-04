/*
 * dummy/none mp3 code
 * (C) notaz, 2013
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>
#include "mp3.h"

int mp3dec_start(FILE *f, int fpos_start)
{
	return -1;
}

int mp3dec_decode(FILE *f, int *file_pos, int file_len)
{
	return -1;
}
