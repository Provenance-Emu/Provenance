/*
 * MP3 decoding using minimp3
 * (C) irixxxx, 2020
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>

#include <pico/pico_int.h>
#define MINIMP3_IMPLEMENTATION
#include "minimp3/minimp3.h"
#include "mp3.h"

static mp3dec_t mp3dec;
static unsigned char mp3_input_buffer[2 * 1024];

int mp3dec_start(FILE *f, int fpos_start)
{
	mp3dec_init(&mp3dec);
	return 0;
}

int mp3dec_decode(FILE *f, int *file_pos, int file_len)
{
	mp3dec_frame_info_t info;
	unsigned char *readPtr;
	int bytesLeft;
	int offset; // mp3 frame offset from readPtr
	int len;
	int retry = 3;

	do
	{
		if (*file_pos >= file_len)
			return 1; /* EOF, nothing to do */

		fseek(f, *file_pos, SEEK_SET);
		bytesLeft = fread(mp3_input_buffer, 1, sizeof(mp3_input_buffer), f);

		offset = mp3_find_sync_word(mp3_input_buffer, bytesLeft);
		if (offset < 0) {
			lprintf("find_sync_word (%i/%i) err %i\n",
				*file_pos, file_len, offset);
			*file_pos = file_len;
			return 1; // EOF
		}
		*file_pos += offset;
		readPtr = mp3_input_buffer + offset;
		bytesLeft -= offset;

		len = mp3dec_decode_frame(&mp3dec, readPtr, bytesLeft, cdda_out_buffer, &info);
		if (len > 0)			// retrieved decoded data
			*file_pos += info.frame_bytes;
		else if (info.frame_bytes > 0)	// no output but input consumed?
			*file_pos += 1;			// try to skip frame
		else if (offset == 0)		// bad frame?
			*file_pos += 1;			// try resyncing
		// else				// truncated frame, try more data
	}
	while (len <= 0 && --retry > 0);

	return len <= 0;
}
