/*
  PokeMini Music Converter
  Copyright (C) 2011-2012  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include <AL/al.h>
#include <AL/alc.h>

#include "saudio_al.h"

static ALCdevice *saudio_dev;
static ALCcontext *saudio_ctx;
static int saudio_buffsize;
static ALuint saudio_buffer[NUMSNDBUFFERS];
static ALuint saudio_source;
static int16_t *saudio_bdata;
static saudio_fillcb saudio_fill;

int init_saudio(saudio_fillcb cb, int bufsize)
{
	int i;

	saudio_dev = alcOpenDevice(NULL);
	if (!saudio_dev) {
		printf("Error opening audio device\n");
		return 0;
	}

	saudio_ctx = alcCreateContext(saudio_dev, NULL);
	alcMakeContextCurrent(saudio_ctx);
	if (!saudio_ctx)
	{
		printf("Error creating audio context\n");
		return 0;
	}

	// Clear errors
	alGetError();

	// Generate buffers
	alGenBuffers(4, saudio_buffer);
	if (alGetError() != AL_NO_ERROR) {
		printf("Error creating audio buffers\n");
		return 0;
	}

	// Generate sources
	alGenSources(1, &saudio_source);
	if (alGetError() != AL_NO_ERROR) {
		printf("Error creating audio sources\n");
		return 0;
	}

	// Setup
	saudio_fill = cb;
	saudio_buffsize = bufsize;
	saudio_bdata = (int16_t *)malloc(saudio_buffsize);
	if (!saudio_bdata) {
		printf("Error allocating buffer data\n");
		return 0;
	}

	// Initialize buffer content
	for (i=0; i<(saudio_buffsize>>1); i++) saudio_bdata[i] = 0;
	alBufferData(saudio_buffer[0], AL_FORMAT_MONO16, saudio_bdata, saudio_buffsize, 44100.0);
	alBufferData(saudio_buffer[1], AL_FORMAT_MONO16, saudio_bdata, saudio_buffsize, 44100.0);
	alBufferData(saudio_buffer[2], AL_FORMAT_MONO16, saudio_bdata, saudio_buffsize, 44100.0);
	alBufferData(saudio_buffer[3], AL_FORMAT_MONO16, saudio_bdata, saudio_buffsize, 44100.0);
	if (alGetError() != AL_NO_ERROR) {
		printf("Error setting buffer data\n");
		return 0;
	}
	alSourceQueueBuffers(saudio_source, NUMSNDBUFFERS, saudio_buffer);

	return 1;
}

void term_saudio()
{
	int val;

	do {
		alGetSourcei(saudio_source, AL_SOURCE_STATE, &val);
	} while (val == AL_PLAYING);
	if (saudio_bdata) free((void *)saudio_bdata);

	alDeleteSources(1, &saudio_source);
	alDeleteBuffers(NUMSNDBUFFERS, saudio_buffer);

	alcMakeContextCurrent(NULL);
	alcDestroyContext(saudio_ctx);
	alcCloseDevice(saudio_dev);
}

int play_saudio()
{
	alSourcePlay(saudio_source);
	if (alGetError() != AL_NO_ERROR) return 0;

	return 1;
}

int stop_saudio()
{
	alSourceStop(saudio_source);
	if (alGetError() != AL_NO_ERROR) return 0;

	return 1;
}

int sync_saudio()
{
	ALuint buffer;
	int val;

	alGetSourcei(saudio_source, AL_BUFFERS_PROCESSED, &val);
	if (val <= 0) return 1;
	while (val--) {
		alSourceUnqueueBuffers(saudio_source, 1, &buffer);
		if (saudio_fill) {
			memset(saudio_bdata, 0, saudio_buffsize);
			saudio_fill(saudio_bdata, saudio_buffsize);
		}
		alBufferData(buffer, AL_FORMAT_MONO16, saudio_bdata, saudio_buffsize, 44100.0);
		alSourceQueueBuffers(saudio_source, 1, &buffer);
		if (alGetError() != AL_NO_ERROR) {
			printf("Error while buffering\n");
			return 0;
		}
	}
	alGetSourcei(saudio_source, AL_SOURCE_STATE, &val);
	if (val != AL_PLAYING) alSourcePlay(saudio_source);
	return 0;
}

#ifdef _WIN32

#include <windows.h>

void sleep_saudio(int ms)
{
	Sleep(ms);
}

#else

#include <time.h>

void sleep_saudio(int ms)
{
	struct timespec req={0};
	req.tv_sec = (time_t)(ms/1000);
	req.tv_nsec = ms * 1000000L;
	while (nanosleep(&req, &req) == -1);
}

#endif
