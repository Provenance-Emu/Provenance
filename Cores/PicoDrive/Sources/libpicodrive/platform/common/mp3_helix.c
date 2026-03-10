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
#include <dlfcn.h>

#include <pico/pico_int.h>
/*#include "helix/pub/mp3dec.h"*/
#include "mp3.h"

#ifndef _MP3DEC_H
typedef void *HMP3Decoder;
#define ERR_MP3_INDATA_UNDERFLOW -1
#define ERR_MP3_MAINDATA_UNDERFLOW -2
#endif

static void *mp3dec;
static unsigned char mp3_input_buffer[2 * 1024];

#ifdef __GP2X__
#define mp3dec_decode _mp3dec_decode
#define mp3dec_start _mp3dec_start
#endif

static void *libhelix;
HMP3Decoder (*p_MP3InitDecoder)(void);
void (*p_MP3FreeDecoder)(HMP3Decoder);
int (*p_MP3Decode)(HMP3Decoder, unsigned char **, int *, short *, int);

int mp3dec_decode(FILE *f, int *file_pos, int file_len)
{
	unsigned char *readPtr;
	int bytesLeft;
	int offset; // mp3 frame offset from readPtr
	int had_err;
	int err = 0;
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
		readPtr = mp3_input_buffer + offset;
		bytesLeft -= offset;

		had_err = err;
		err = p_MP3Decode(mp3dec, &readPtr, &bytesLeft, cdda_out_buffer, 0);
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
	while (err && --retry > 0);

	return !!err;
}

int mp3dec_start(FILE *f, int fpos_start)
{
	if (libhelix == NULL) {
		libhelix = dlopen("./libhelix.so", RTLD_NOW);
		if (libhelix == NULL) {
			lprintf("mp3dec: load libhelix.so: %s\n", dlerror());
			return -1;
		}

		p_MP3InitDecoder = dlsym(libhelix, "MP3InitDecoder");
		p_MP3FreeDecoder = dlsym(libhelix, "MP3FreeDecoder");
		p_MP3Decode = dlsym(libhelix, "MP3Decode");

		if (p_MP3InitDecoder == NULL || p_MP3FreeDecoder == NULL
		    || p_MP3Decode == NULL)
		{
			lprintf("mp3dec: missing symbol(s) in libhelix.so\n");
			dlclose(libhelix);
			libhelix = NULL;
			return -1;
		}
	}

	// must re-init decoder for new track
	if (mp3dec)
		p_MP3FreeDecoder(mp3dec);
	mp3dec = p_MP3InitDecoder();

	return (mp3dec == 0) ? -1 : 0;
}
