/*
 * Some mp3 related code for Sega/Mega CD.
 * Uses the Helix Fixed-point MP3 decoder
 * (C) notaz, 2007-2009
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <string.h>

#include <pico/pico_int.h>
#include <pico/sound/mix.h>
#include "helix/pub/mp3dec.h"
#include "mp3.h"
#include "lprintf.h"

static HMP3Decoder mp3dec;
static unsigned char mp3_input_buffer[2 * 1024];

#ifdef __GP2X__
#define mp3_update mp3_update_local
#define mp3_start_play mp3_start_play_local
#endif

int mp3dec_decode(FILE *f, int *file_pos, int file_len)
{
	unsigned char *readPtr;
	int bytesLeft;
	int offset; // mp3 frame offset from readPtr
	int had_err;
	int err = 0;

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
		readPtr = mp3_input_buffer + offset;
		bytesLeft -= offset;

		had_err = err;
		err = MP3Decode(mp3dec, &readPtr, &bytesLeft, cdda_out_buffer, 0);
		if (err) {
			if (err == ERR_MP3_MAINDATA_UNDERFLOW && !had_err) {
				// just need another frame
				*file_pos += readPtr - mp3_input_buffer;
				continue;
			}
			if (err == ERR_MP3_INDATA_UNDERFLOW && !had_err) {
				if (offset == 0)
					// something's really wrong here, frame had to fit
					*file_pos = file_len;
				else
					*file_pos += offset;
				continue;
			}
			if (-12 <= err && err <= -6) {
				// ERR_MP3_INVALID_FRAMEHEADER, ERR_MP3_INVALID_*
				// just try to skip the offending frame..
				*file_pos += offset + 1;
				continue;
			}
			lprintf("MP3Decode err (%i/%i) %i\n",
				*file_pos, file_len, err);
			*file_pos = file_len;
			return 1;
		}
		*file_pos += readPtr - mp3_input_buffer;
	}
	while (0);

	return 0;
}

int mp3dec_start(FILE *f, int fpos_start)
{
	// must re-init decoder for new track
	if (mp3dec)
		MP3FreeDecoder(mp3dec);
	mp3dec = MP3InitDecoder();

	return (mp3dec == 0) ? -1 : 0;
}
