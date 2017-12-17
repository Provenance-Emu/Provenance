/*
 * sound.c - platform-independent interface for platform-specific sound output.
 *
 * Copyright (C) 2013 Tomasz Krasuski
 * Copyright (C) 2013-2014 Atari800 development team (see DOC/CREDITS)
 *
 * This file is part of the Atari800 emulator project which emulates
 * the Atari 400, 800, 800XL, 130XE, and 5200 8-bit computers.

 * Atari800 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.

 * Atari800 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License along
 * with Atari800; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <stdlib.h>
#include <stdio.h>

#include "sound.h"

#include "atari.h"
#include "log.h"
#include "platform.h"
#include "pokeysnd.h"
#include "util.h"

#define DEBUG 0

int Sound_enabled = 1;

Sound_setup_t Sound_desired = {
	44100,
	2,
	1,
	0
};

Sound_setup_t Sound_out;

static int paused = TRUE;

#ifndef SOUND_CALLBACK
static UBYTE *process_buffer = NULL;
static unsigned int process_buffer_size;
#endif /* !SOUND_CALLBACK */

#ifdef SYNCHRONIZED_SOUND
static UBYTE *sync_buffer = NULL;
static unsigned int sync_buffer_size;
/* Two invariants are held:
   a) 0 <= sync_read_pos < sync_buffer_size
   b) sync_read_pos <= sync_write_pos <= sync_buffer_size + sync_read_pos
   sync_write_pos may be >= sync_buffer_size. In such case the actual write
   position is sync_write_pos % sync_buffer_size. */
static unsigned int sync_write_pos;
static unsigned int sync_read_pos;

unsigned int Sound_latency = 20;
/* Cumulative audio difference. */
static double avg_fill;
/* Estimated fill of sync_buffer */
static unsigned int sync_est_fill;
/* If sync_est_fill goes outside this bounds, emulation speed is adjusted. */
static unsigned int sync_min_fill;
static unsigned int sync_max_fill;
#ifdef SOUND_CALLBACK
#endif /* SOUND_CALLBACK */
/* Time of last write of sudio to output device (either by Sound_Callback or
   WriteOut). */
double last_audio_write_time;
#endif /* SYNCHRONIZED_SOUND */

enum { MAX_SAMPLE_SIZE = 2, /* for 16-bit */
#ifdef STEREO_SOUND
       MAX_CHANNELS = 2,
#else /* !STEREO_SOUND */
       MAX_CHANNELS = 1,
#endif /* !STEREO_SOUND */
       MAX_FRAME_SIZE = MAX_SAMPLE_SIZE * MAX_CHANNELS
};

int Sound_ReadConfig(char *option, char *ptr)
{
	if (strcmp(option, "SOUND_ENABLED") == 0)
		return (Sound_enabled = Util_sscanbool(ptr)) != -1;
	else if (strcmp(option, "SOUND_RATE") == 0)
		return (Sound_desired.freq = Util_sscandec(ptr)) != -1;
	else if (strcmp(option, "SOUND_BITS") == 0) {
		int bits = Util_sscandec(ptr);
		if (bits != 8 && bits != 16)
			return FALSE;
		Sound_desired.sample_size = bits / 8;
	}
	else if (strcmp(option, "SOUND_FRAG_FRAMES") == 0) {
		int val = Util_sscandec(ptr);
		if (val == -1)
			return FALSE;
		Sound_desired.frag_frames = val;
	}
#ifdef SYNCHRONIZED_SOUND
	else if (strcmp(option, "SOUND_LATENCY") == 0)
		return (Sound_latency = Util_sscandec(ptr)) != -1;
#endif /* SYNCHRONIZED_SOUND */
	else
		return FALSE;
	return TRUE;
}

void Sound_WriteConfig(FILE *fp)
{
	fprintf(fp, "SOUND_ENABLED=%u\n", Sound_enabled);
	fprintf(fp, "SOUND_RATE=%u\n", Sound_desired.freq);
	fprintf(fp, "SOUND_BITS=%u\n", Sound_desired.sample_size * 8);
	fprintf(fp, "SOUND_FRAG_FRAMES=%u\n", Sound_desired.frag_frames);
#ifdef SYNCHRONIZED_SOUND
	fprintf(fp, "SOUND_LATENCY=%u\n", Sound_latency);
#endif /* SYNCHRONIZED_SOUND */
}

int Sound_Initialise(int *argc, char *argv[])
{
	int i, j;
	int help_only = FALSE;

	for (i = j = 1; i < *argc; i++) {
		int i_a = (i + 1 < *argc);		/* is argument available? */
		int a_m = FALSE;			/* error, argument missing! */
		int a_i = FALSE; /* error, argument invalid! */

		if (strcmp(argv[i], "-sound") == 0)
			Sound_enabled = 1;
		else if (strcmp(argv[i], "-nosound") == 0)
			Sound_enabled = 0;
		else if (strcmp(argv[i], "-dsprate") == 0) {
			if (i_a)
				a_i = (Sound_desired.freq = Util_sscandec(argv[++i])) == -1;
			else a_m = TRUE;
		}
		else if (strcmp(argv[i], "-audio16") == 0)
			Sound_desired.sample_size = 2;
		else if (strcmp(argv[i], "-audio8") == 0)
			Sound_desired.sample_size = 1;
		else if (strcmp(argv[i], "snd-fragsize") == 0) {
			if (i_a) {
				int val = Util_sscandec(argv[++i]);
				if (val == -1)
					a_i = TRUE;
				else
					Sound_desired.frag_frames = val;
			}
			else a_m = TRUE;
		}
#ifdef SYNCHRONIZED_SOUND
		else if (strcmp(argv[i], "-snddelay") == 0)
			if (i_a)
				Sound_latency = Util_sscandec(argv[++i]);
			else a_m = TRUE;
#endif /* SYNCHRONIZED_SOUND */
		else {
			if (strcmp(argv[i], "-help") == 0) {
				help_only = TRUE;
				Log_print("\t-sound               Enable sound");
				Log_print("\t-nosound             Disable sound");
				Log_print("\t-dsprate <rate>      Set sound output frequency in Hz");
				Log_print("\t-audio16             Set sound output format to 16-bit");
				Log_print("\t-audio8              Set sound output format to 8-bit");
				Log_print("\t-snd-fragsize <num>  Set size of the hardware sound buffer (fragment size)");
#ifdef SYNCHRONIZED_SOUND
				Log_print("\t-snddelay <time>       Set sound latency in milliseconds");
#endif /* SYNCHRONIZED_SOUND */
			}
			argv[j++] = argv[i];
		}

		if (a_m) {
			Log_print("Missing argument for '%s'", argv[i]);
			return FALSE;
		} else if (a_i) {
			Log_print("Invalid argument for '%s'", argv[--i]);
			return FALSE;
		}
	}
	*argc = j;

	if (help_only)
		Sound_enabled = FALSE;

	return TRUE;
}

int Sound_Setup(void)
{
	/* Sanitize freq. */
	if (POKEYSND_enable_new_pokey && Sound_desired.freq < 8192)
		/* MZ POKEY seems to segfault or remain silent with rate < 8009 Hz. */
		Sound_desired.freq = 8192;
	else if (Sound_desired.freq < 1000)
		/* Such low value is impractical. */
		Sound_desired.freq = 1000;
	else if (Sound_desired.freq > 65535)
		/* POKEY emulation doesn't support rate > 65535 Hz. */
		Sound_desired.freq = 65535;

	/* 0 indicates setting frag_size automatically. */
	if (Sound_desired.frag_frames != 0) {
		/* Make sure frag_frames is a power of 2. */
		unsigned int pow_val = 1;
		unsigned int val = Sound_desired.frag_frames;
		while (val >>= 1)
			pow_val <<= 1;
		if (pow_val < Sound_desired.frag_frames)
			pow_val <<= 1;
		Sound_desired.frag_frames = pow_val;

		if (Sound_desired.frag_frames < 16)
			/* Lower values are simply not practical. */
			Sound_desired.frag_frames = 16;
	}

	Sound_out = Sound_desired;
	if (!(Sound_enabled = PLATFORM_SoundSetup(&Sound_out)))
		return FALSE;

	/* Now setup contains actual audio output settings. */
	if ((POKEYSND_enable_new_pokey && Sound_out.freq < 8192)
		|| Sound_out.freq < 1000 || Sound_out.freq > 65535) {
		Log_print("%d frequency not supported", Sound_out.freq);
		Sound_Exit();
		return FALSE;
	}
	if (Sound_out.channels > MAX_CHANNELS) {
		Log_print("%d channels not supported", Sound_out.channels);
		Sound_Exit();
		return FALSE;
	}

	POKEYSND_stereo_enabled = Sound_out.channels == 2;
#ifndef SOUND_CALLBACK
	free(process_buffer);
	process_buffer_size = Sound_out.frag_frames * Sound_out.channels * Sound_out.sample_size;
	process_buffer = Util_malloc(process_buffer_size);
#endif /* !SOUND_CALLBACK */

	POKEYSND_Init(POKEYSND_FREQ_17_EXACT, Sound_out.freq, Sound_out.channels, Sound_out.sample_size == 2 ? POKEYSND_BIT16 : 0);

#ifdef SYNCHRONIZED_SOUND
	Sound_SetLatency(Sound_latency);
#endif /* SYNCHRONIZED_SOUND */

	Sound_desired.freq = Sound_out.freq;
	Sound_desired.sample_size = Sound_out.sample_size;
	Sound_desired.channels = Sound_out.channels;
	/* Don't copy Sound_out.frag_frames to Sound_desired.frag_frames.
       Reason: some backends (e.g. SDL on PulseAudio) always
	   decrease the desired frag_size when opening audio. If the
	   obtained value was copied, repeated calls to Sound_Setup
	   would quickly decrease frag_size to 0. */

	paused = TRUE;
	return TRUE;
}

void Sound_Exit(void)
{
	if (Sound_enabled) {
		PLATFORM_SoundExit();
		Sound_enabled = FALSE;
#ifndef SOUND_CALLBACK
		free(process_buffer);
		process_buffer = NULL;
#endif /* !SOUND_CALLBACK */
#ifdef SYNCHRONIZED_SOUND
		free(sync_buffer);
		sync_buffer = NULL;
#endif /* SYNCHRONIZED_SOUND */
	}
}

void Sound_Pause(void)
{
	if (Sound_enabled && !paused) {
		/* stop audio output */
		PLATFORM_SoundPause();
		paused = TRUE;
	}
}

void Sound_Continue(void)
{
	if (Sound_enabled && paused) {
		/* start audio output */
#ifdef SYNCHRONIZED_SOUND
/*		sync_write_pos = sync_read_pos + sync_min_fill;
		avg_fill = sync_min_fill;*/
		last_audio_write_time = Util_time();
#endif /* SYNCHRONIZED_SOUND */
		PLATFORM_SoundContinue();
		paused = FALSE;
	}
}

/* Fills buffer BUFFER with SIZE bytes of audio samples. */
static void FillBuffer(UBYTE *buffer, unsigned int size)
{
#ifdef SYNCHRONIZED_SOUND
	unsigned int new_read_pos;
	static UBYTE last_frame[MAX_FRAME_SIZE];
	unsigned int bytes_per_frame = Sound_out.channels * Sound_out.sample_size;
	unsigned int to_write = sync_write_pos - sync_read_pos;

	if (to_write > 0) {
		if (to_write > size)
			to_write = size;

		new_read_pos = sync_read_pos + to_write;

		if (new_read_pos <= sync_buffer_size)
			/* no wrap */
			memcpy(buffer, sync_buffer + sync_read_pos, to_write);
		else {
			/* wraps */
			unsigned int first_part_size = sync_buffer_size - sync_read_pos;
			memcpy(buffer, sync_buffer + sync_read_pos, first_part_size);
			memcpy(buffer + first_part_size, sync_buffer, to_write - first_part_size);
		}

		sync_read_pos = new_read_pos;
		if (sync_read_pos > sync_buffer_size) {
			sync_read_pos -= sync_buffer_size;
			sync_write_pos -= sync_buffer_size;
		}
		/* Save the last frame as we may need it to fill underflow. */
		memcpy(last_frame, buffer + to_write - bytes_per_frame, bytes_per_frame);
	}


	/* Just repeat the last good frame if underflow. */
	if (to_write < size) {
#if DEBUG
		Log_print("Sound buffer underflow: fill %d, needed %d",
		          to_write/Sound_out.channels/Sound_out.sample_size,
		          size/Sound_out.channels/Sound_out.sample_size);
#endif
		do {
			memcpy(buffer + to_write, last_frame, bytes_per_frame);
			to_write += bytes_per_frame;
		} while (to_write < size);
	}
#else /* !SYNCHRONIZED_SOUND */
	POKEYSND_Process(buffer, size / Sound_out.sample_size);
#endif /* !SYNCHRONIZED_SOUND */
}

#ifdef SOUND_CALLBACK
void Sound_Callback(UBYTE *buffer, unsigned int size)
{
#if DEBUG >= 2
		Log_print("Callback: fill %u, needed %u",
		          (sync_write_pos - sync_read_pos) / Sound_out.channels / Sound_out.sample_size,
		          size / Sound_out.channels / Sound_out.sample_size);
#endif
	FillBuffer(buffer, size);
#ifdef SYNCHRONIZED_SOUND
	last_audio_write_time = Util_time();
#endif /* SYNCHRONIZED_SOUND */
}
#else /* !SOUND_CALLBACK */
/* Write audio to output device. */
static void WriteOut(void)
{
	unsigned int avail = PLATFORM_SoundAvailable();

	if (avail > 0) {
#if DEBUG >= 2
		Log_print("WriteOut: fill %u, needed %u",
		          (sync_write_pos - sync_read_pos) / Sound_out.channels / Sound_out.sample_size,
		          avail / Sound_out.channels / Sound_out.sample_size);
#endif
		/* On some platforms (eg. NestedVM) avail may be larger than process_buffer_size. */
		do {
			unsigned int len = avail > process_buffer_size ? process_buffer_size : avail;
			FillBuffer(process_buffer, len);
			PLATFORM_SoundWrite(process_buffer, len);
			avail -= len;
		} while (avail > 0);
#ifdef SYNCHRONIZED_SOUND
		last_audio_write_time = Util_time();
#endif /* SYNCHRONIZED_SOUND */
	}
}
#endif /* !SOUND_CALLBACK */

#ifdef SYNCHRONIZED_SOUND
static void UpdateSyncBuffer(void)
{
	unsigned int bytes_written;
	unsigned int samples_written;
	unsigned int fill;
	unsigned int new_write_pos;

	PLATFORM_SoundLock();
	/* Current fill of the audio buffer. */
	fill = sync_write_pos - sync_read_pos;

	/* Update sync_est_fill. */
	{
		unsigned int est_gap;
		est_gap = (Util_time() - last_audio_write_time)*Sound_out.freq*Sound_out.channels*Sound_out.sample_size;
		if (fill < est_gap)
			sync_est_fill = 0;
		else
			sync_est_fill = fill - est_gap;
	}

	if (Atari800_turbo && sync_est_fill > sync_max_fill) {
		PLATFORM_SoundUnlock();
		return;
	}

	/* produce samples from the sound emulation */
	samples_written = POKEYSND_UpdateProcessBuffer();
	bytes_written = Sound_out.sample_size * samples_written;

	/* if there isn't enough room... */
	if (bytes_written > sync_buffer_size - fill) {
		/* Overflow of sync_buffer. */
#if DEBUG
		Log_print("Sound buffer overflow: free %d, needed %d",
				  (sync_buffer_size - fill)/Sound_out.channels/Sound_out.sample_size,
				  bytes_written/Sound_out.channels/Sound_out.sample_size);
#endif
		/* Wait until hardware buffer can be filled, or wait until callback
		   makes place in the buffer. */
		do {
			PLATFORM_SoundUnlock();
			/* Sleep for the duration of one full HW buffer. */
			Util_sleep((double)Sound_out.frag_frames / Sound_out.freq);
			PLATFORM_SoundLock();
#ifndef SOUND_CALLBACK
			WriteOut(); /* Write to audio buffer as much as possible. */
#endif /* SOUND_CALLBACK */
			fill = sync_write_pos - sync_read_pos;
		} while (bytes_written > sync_buffer_size - fill);
	}
	/* Now bytes_written <= audio_buffer_size + dsp_read_pos - dsp_write_pos) */

#if DEBUG >= 2
	Log_print("UpdateSyncBuffer: est_gap: %f, fill %u, write %u",
			(Util_time() - last_audio_write_time)*Sound_out.freq,
	          fill / Sound_out.channels/Sound_out.sample_size,
	          bytes_written / Sound_out.channels/Sound_out.sample_size);
#endif
	/* now we copy the data into the buffer and adjust the positions */
	new_write_pos = sync_write_pos + bytes_written;
	if (new_write_pos/sync_buffer_size == sync_write_pos/sync_buffer_size)
		/* no wrap */
		memcpy(sync_buffer + sync_write_pos%sync_buffer_size, POKEYSND_process_buffer, bytes_written);
	else {
		/* wraps */
		int first_part_size = sync_buffer_size - sync_write_pos%sync_buffer_size;
		memcpy(sync_buffer + sync_write_pos%sync_buffer_size, POKEYSND_process_buffer, first_part_size);
		memcpy(sync_buffer, POKEYSND_process_buffer + first_part_size, bytes_written - first_part_size);
	}

	sync_write_pos = new_write_pos;
	if (sync_write_pos > sync_read_pos + sync_buffer_size)
		sync_write_pos -= sync_buffer_size;
	PLATFORM_SoundUnlock();
}
#endif /* SYNCHRONIZED_SOUND */

void Sound_Update(void)
{
	if (!Sound_enabled || paused)
		return;
#ifdef SYNCHRONIZED_SOUND
	UpdateSyncBuffer();
#endif /* SYNCHRONIZED_SOUND */
#ifndef SOUND_CALLBACK
	WriteOut();
#endif /* !SOUND_CALLBACK */
}

#ifdef SYNCHRONIZED_SOUND
void Sound_SetLatency(unsigned int latency)
{
	Sound_latency = latency;
	if (Sound_enabled) {
		/* how many fragments in the audio buffer */
		enum { SYNC_BUFFER_FRAGS = 5 };
		unsigned int bytes_per_frame = Sound_out.channels * Sound_out.sample_size;
		unsigned int latency_frames = Sound_out.freq*Sound_latency/1000;
		PLATFORM_SoundLock();
		sync_buffer_size = (latency_frames + SYNC_BUFFER_FRAGS*Sound_out.frag_frames) * bytes_per_frame;
		sync_min_fill = latency_frames * bytes_per_frame;
		sync_max_fill = sync_min_fill + Sound_out.frag_frames * bytes_per_frame;
		avg_fill = sync_min_fill;
		sync_read_pos = 0;
		sync_write_pos = sync_min_fill;
		free(sync_buffer);
		sync_buffer = Util_malloc(sync_buffer_size);
		memset(sync_buffer, 0, sync_buffer_size);
		PLATFORM_SoundUnlock();
	}
}

double Sound_AdjustSpeed(void)
{
	double delay_mult = 1.0;
	static double const alpha = 2.0/(1.0+40.0);

	if (Sound_enabled && !paused) {
#if 1
		avg_fill = avg_fill + alpha * (sync_est_fill - avg_fill);
		if (avg_fill < sync_min_fill)
			delay_mult = 0.95;
		else if (avg_fill > sync_max_fill)
			delay_mult = 1.05;
#endif
#if 0
		if (sync_est_fill < sync_min_fill)
			delay_mult = 0.95;
		else if (sync_est_fill > sync_max_fill)
			delay_mult = 1.05;
#endif
#if DEBUG >= 2
		Log_print("delay_mult: %f, est_fill: %u, avg_fill: %f, buf_size: %u, min_fill: %u, max_fill: %u",
		          delay_mult,
		          sync_est_fill / Sound_out.channels / Sound_out.sample_size,
		          avg_fill / Sound_out.channels / Sound_out.sample_size,
		          sync_buffer_size / Sound_out.channels / Sound_out.sample_size,
		          sync_min_fill / Sound_out.channels / Sound_out.sample_size,
		          sync_max_fill / Sound_out.channels / Sound_out.sample_size);
#endif
	}
	return delay_mult;
}
#endif /* SYNCHRONIZED_SOUND */
