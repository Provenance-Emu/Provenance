/*
 * sound_oss.c - Open Sound System driver
 *
 * Copyright (C) 1995-1998 David Firth
 * Copyright (C) 1998-2013 Atari800 development team (see DOC/CREDITS)
 *
 * This file is part of the Atari800 emulator project which emulates
 * the Atari 400, 800, 800XL, 130XE, and 5200 8-bit computers.
 *
 * Atari800 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Atari800 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Atari800; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/soundcard.h>
/* XXX: #include <machine/soundcard.h> */

#include "atari.h"
#include "log.h"
#include "platform.h"
#include "sound.h"

#define DEBUG 0

static const char * const dspname = "/dev/dsp";

static int dsp_fd;

/* When opening an OSS audio device, we don't limit number of sound fragments
   that OSS creates. To minimise latency resulting from too many fragments,
   we take advantage of the fact that OSS usually starts playback after fully
   filling 2 fragments, and ensure that we never have more filled fragments
   than MAX_FILLED_FRAGMENTS (which is <> 2 for some additional headroom). */
enum { MAX_FILLED_FRAGMENTS = 4 };

int PLATFORM_SoundSetup(Sound_setup_t *setup)
{
	int format;
	int frag_size;
	int setfragment;

	if (Sound_enabled)
		close(dsp_fd);

	dsp_fd = open(dspname, O_WRONLY);
	if (dsp_fd == -1) {
		perror(dspname);
		return FALSE;
	}

	if (setup->frag_frames == 0)
		/* Set frag_frames automatically. */
		frag_size = setup->freq / 50;
	else
		frag_size = setup->frag_frames;
	frag_size *= setup->channels * setup->sample_size;

	/* By setting number of fragments to 0x7fff (ie. don't limit) we ensure
	   that the obtained fragment size will be as close to the requested value
	   as possible. */
	setfragment = 0x7fff0000;
	{
		/* Compute the closest power of two. */
		int pow_val = 1;
		int val = frag_size;
		while (val >>= 1) {
			pow_val <<= 1;
			++setfragment;
		}
		if (pow_val < frag_size)
			/* Ensure fragment size is not smaller than user-provided value. */
			++setfragment;
	}
	if (ioctl(dsp_fd, SNDCTL_DSP_SETFRAGMENT, &setfragment) == -1) {
		Log_print("%s: SNDCTL_DSP_SETFRAGMENT(%.8x) failed", dspname, setfragment);
		close(dsp_fd);
		return FALSE;
	}

	format = setup->sample_size == 2 ? AFMT_S16_NE : AFMT_U8;
	if (ioctl(dsp_fd, SNDCTL_DSP_SETFMT, &format) == -1) {
		Log_print("%s: SNDCTL_DSP_SETFMT(%i) failed", dspname, format);
		close(dsp_fd);
		return FALSE;
	}
	if (format == AFMT_S16_NE)
		setup->sample_size = 2;
	else if (format == AFMT_U8)
		setup->sample_size = 1;
	else {
		Log_print("%s: Obtained format %i not supported", dspname, format);
		close(dsp_fd);
		return FALSE;
	}

	if (ioctl(dsp_fd, SNDCTL_DSP_CHANNELS, &setup->channels) == -1) {
		Log_print("%s: SNDCTL_DSP_CHANNELS(%u) failed", dspname, setup->channels);
		close(dsp_fd);
		return FALSE;
	}

	if (ioctl(dsp_fd, SNDCTL_DSP_SPEED, &setup->freq) == -1) {
		Log_print("%s: SNDCTL_DSP_SPEED(%u) failed", dspname, setup->freq);
		close(dsp_fd);
		return FALSE;
	}

	if (ioctl(dsp_fd, SNDCTL_DSP_GETBLKSIZE, &frag_size) == -1) {
		Log_print("%s: SNDCTL_DSP_GETBLKSIZE failed", dspname);
		close(dsp_fd);
		return FALSE;
	}

	setup->frag_frames = frag_size / setup->channels / setup->sample_size;
	{
		audio_buf_info bi;
		if (ioctl(dsp_fd, SNDCTL_DSP_GETOSPACE, &bi) == -1) {
			Log_print("%s: cannot retrieve ospace", dspname);
			return 0;
		}
#if DEBUG
		Log_print("fragments=%i, fragstotal=%i, fragsize=%i, bytes=%i", bi.fragments, bi.fragstotal, bi.fragsize, bi.bytes);
		Log_print("frag_size=%i, buf_Frames=%u", frag_size, setup->frag_frames);
#endif
	}

	return TRUE;
}

void PLATFORM_SoundExit(void)
{
	close(dsp_fd);
}

void PLATFORM_SoundPause(void)
{
	/* flush buffers */
	ioctl(dsp_fd, SNDCTL_DSP_POST, NULL);
}

void PLATFORM_SoundContinue(void)
{
	/* do nothing */
}

unsigned int PLATFORM_SoundAvailable(void)
{
	audio_buf_info bi;
	int filled_frags;
	enum { MAX_FILLED_FRAGMENTS = 4 };

	if (ioctl(dsp_fd, SNDCTL_DSP_GETOSPACE, &bi) == -1) {
		Log_print("%s: cannot retrieve ospace", dspname);
		return 0;
	}
#if DEBUG
	Log_print("fragments=%i, fragstotal=%i, fragsize=%i, bytes=%i", bi.fragments, bi.fragstotal, bi.fragsize, bi.bytes);*/
#endif

	/* Usually OSS playback starts when 2 fragments are fully filled. Take
	   advantage of it: write audio only if at most MAX_FILLED_FRAGS fragments
	   are filled, to minimize latency regardless of actual total number of
	   fragments. */
	filled_frags = bi.fragstotal - bi.fragments;
	if (filled_frags <= MAX_FILLED_FRAGMENTS)
		return bi.fragsize * (MAX_FILLED_FRAGMENTS - filled_frags);
	else if (bi.fragstotal <= MAX_FILLED_FRAGMENTS)
		return bi.bytes;
	else
		return 0;
}

void PLATFORM_SoundWrite(UBYTE const *buffer, unsigned int size)
{
	int wsize = write(dsp_fd, buffer, size);
	if (wsize < size) {
		/* TODO: handle problem */
	}
}
