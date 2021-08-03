/*
 * (C) notaz, 2013
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

#include <SDL.h>
#include "sndout_sdl.h"

// ~1/3s at 44kHz
// set this to power of 2
#define BUF_LEN 32768
#define BUF_MASK (BUF_LEN - 1)

static short buf[BUF_LEN];
static int buf_w, buf_r;
static int started;

static void callback(void *userdata, Uint8 *stream, int len)
{
	int have = (buf_w - buf_r) & BUF_MASK;
	int buf_left = BUF_LEN - buf_r;

	len /= 2;
	if (have > len)
		have = len;
	if (have > 0) {
		if (have > buf_left) {
			memcpy(stream, buf + buf_r, buf_left * 2);
			stream += buf_left * 2;
			buf_r = 0;
			have -= buf_left;
			len -= buf_left;
		}
		memcpy(stream, buf + buf_r, have * 2);
		stream += have * 2;
		buf_r = (buf_r + have) & BUF_MASK;
		len -= have;
	}

	if (len > 0) {
		// put in some silence..
		memset(stream, 0, len * 2);
	}
}

int sndout_sdl_init(void)
{
	int ret;

	ret = SDL_InitSubSystem(SDL_INIT_AUDIO);
	if (ret != 0)
		return -1;

	return 0;
}

int sndout_sdl_start(int rate, int stereo)
{
	SDL_AudioSpec desired;
	int samples, shift;
	int ret;

	if (started)
		sndout_sdl_stop();

	desired.freq = rate;
	desired.format = AUDIO_S16LSB;
	desired.channels = stereo ? 2 : 1;
	desired.callback = callback;
	desired.userdata = NULL;

	samples = rate >> 6;
	for (shift = 8; (1 << shift) < samples; shift++)
		;
	desired.samples = 1 << shift;

	ret = SDL_OpenAudio(&desired, NULL);
	if (ret != 0) {
		fprintf(stderr, "SDL_OpenAudio: %s\n", SDL_GetError());
		return -1;
	}

	buf_w = buf_r = 0;

	SDL_PauseAudio(0);
	started = 1;

	return 0;
}

void sndout_sdl_stop(void)
{
	SDL_PauseAudio(1);
	SDL_CloseAudio();
	started = 0;
}

void sndout_sdl_wait(void)
{
	int left;

	while (1)
	{
		left = (buf_r - buf_w - 2) & BUF_MASK;
		if (left >= BUF_LEN / 2)
			break;

		SDL_Delay(4);
	}
}

int sndout_sdl_write_nb(const void *samples, int len)
{
	int maxlen = (buf_r - buf_w - 2) & BUF_MASK;
	int buf_left = BUF_LEN - buf_w;
	int retval;

	len /= 2;
	if (len > maxlen)
		// not enough space
		len = maxlen;
	if (len == 0)
		// totally full
		return 0;

	retval = len;

	if (len > buf_left) {
		memcpy(buf + buf_w, samples, buf_left * 2);
		samples = (const short *)samples + buf_left;
		len -= buf_left;
		buf_w = 0;
	}
	memcpy(buf + buf_w, samples, len * 2);
	buf_w = (buf_w + len) & BUF_MASK;

	return retval;
}

void sndout_sdl_exit(void)
{
	if (started)
		sndout_sdl_stop();
	SDL_QuitSubSystem(SDL_INIT_AUDIO);
}
