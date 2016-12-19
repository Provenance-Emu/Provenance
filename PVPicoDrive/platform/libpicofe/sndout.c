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

#include <stdio.h>
#include <string.h>

#include "linux/sndout_oss.h"
#include "linux/sndout_alsa.h"
#include "sndout_sdl.h"
#include "sndout.h"

static int sndout_null_init(void)
{
	return 0;
}

static void sndout_null_exit(void)
{
}

static int sndout_null_start(int rate, int stereo)
{
	return 0;
}

static void sndout_null_stop(void)
{
}

static void sndout_null_wait(void)
{
}

static int sndout_null_write_nb(const void *data, int bytes)
{
	return bytes;
}

#define SNDOUT_DRIVER(name) { \
	#name, \
	sndout_##name##_init, \
	sndout_##name##_exit, \
	sndout_##name##_start, \
	sndout_##name##_stop, \
	sndout_##name##_wait, \
	sndout_##name##_write_nb, \
}

static struct sndout_driver sndout_avail[] =
{
#ifdef HAVE_SDL
	SNDOUT_DRIVER(sdl),
#endif
#ifdef HAVE_ALSA
	SNDOUT_DRIVER(alsa),
#endif
#ifdef HAVE_OSS
	SNDOUT_DRIVER(oss),
#endif
	SNDOUT_DRIVER(null)
};

struct sndout_driver sndout_current;

void sndout_init(void)
{
	int i;

	for (i = 0; i < sizeof(sndout_avail) / sizeof(sndout_avail[0]); i++) {
		if (sndout_avail[i].init() == 0)
			break;
	}

	memcpy(&sndout_current, &sndout_avail[i], sizeof(sndout_current));
	printf("using %s audio output driver\n", sndout_current.name);
}
