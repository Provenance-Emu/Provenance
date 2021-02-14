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
#include <alsa/asoundlib.h>
#include <unistd.h>

#include "sndout_alsa.h"

#define PFX "sndout_alsa: "

static snd_pcm_t *handle;
static snd_pcm_uframes_t buffer_size, period_size;
static void *silent_period;
static unsigned int channels;
static int failure_counter;

int sndout_alsa_init(void)
{
	int ret;

	ret = snd_pcm_open(&handle, "default", SND_PCM_STREAM_PLAYBACK, 0);
	if (ret != 0)
		return -1;

	return 0;
}

int sndout_alsa_start(int rate_, int stereo)
{
	snd_pcm_hw_params_t *hwparams = NULL;
	unsigned int rate = rate_;
	int samples, shift;
	int ret;

	samples = rate * 40 / 1000;
	for (shift = 8; (1 << shift) < samples; shift++)
		;
	period_size = 1 << shift;
	buffer_size = 8 * period_size;

	snd_pcm_hw_params_alloca(&hwparams);

	ret  = snd_pcm_hw_params_any(handle, hwparams);
	ret |= snd_pcm_hw_params_set_access(handle, hwparams, SND_PCM_ACCESS_RW_INTERLEAVED);
	ret |= snd_pcm_hw_params_set_format(handle, hwparams, SND_PCM_FORMAT_S16_LE);
	ret |= snd_pcm_hw_params_set_channels(handle, hwparams, stereo ? 2 : 1);
	ret |= snd_pcm_hw_params_set_rate_near(handle, hwparams, &rate, 0);
	ret |= snd_pcm_hw_params_set_buffer_size_near(handle, hwparams, &buffer_size);
	ret |= snd_pcm_hw_params_set_period_size_near(handle, hwparams, &period_size, NULL);

	if (ret != 0) {
		fprintf(stderr, PFX "failed to set hwparams\n");
		goto fail;
	}

	ret = snd_pcm_hw_params(handle, hwparams);
	if (ret != 0) {
		fprintf(stderr, PFX "failed to apply hwparams: %d\n", ret);
		goto fail;
	}

	snd_pcm_hw_params_get_buffer_size(hwparams, &buffer_size);
	snd_pcm_hw_params_get_period_size(hwparams, &period_size, NULL);
	snd_pcm_hw_params_get_channels(hwparams, &channels);

	silent_period = realloc(silent_period, period_size * 2 * channels);
	if (silent_period != NULL)
		memset(silent_period, 0, period_size * 2 * channels);

	ret = snd_pcm_prepare(handle);
	if (ret != 0) {
		fprintf(stderr, PFX "snd_pcm_prepare failed: %d\n", ret);
		goto fail;
	}

	ret = snd_pcm_start(handle);
	if (ret != 0) {
		fprintf(stderr, PFX "snd_pcm_start failed: %d\n", ret);
		goto fail;
	}

	failure_counter = 0;

	return 0;

fail:
	// to flush out redirected logs
	fflush(stdout);
	fflush(stderr);
	return -1;
}

void sndout_alsa_stop(void)
{
	int ret = snd_pcm_drop(handle);
	if (ret != 0)
		fprintf(stderr, PFX "snd_pcm_drop failed: %d\n", ret);
}

void sndout_alsa_wait(void)
{
	snd_pcm_sframes_t left;

	while (1)
	{
		left = snd_pcm_avail(handle);
		if (left < 0 || left >= buffer_size / 2)
			break;

		usleep(4000);
	}
}

int sndout_alsa_write_nb(const void *samples, int len)
{
	snd_pcm_sframes_t left;
	int ret;

	len /= 2;
	if (channels == 2)
		len /= 2;

	left = snd_pcm_avail(handle);
	if (left >= 0 && left < len)
		return 0;

	ret = snd_pcm_writei(handle, samples, len);
	if (ret < 0) {
		ret = snd_pcm_recover(handle, ret, 1);
		if (ret != 0 && failure_counter++ < 5)
			fprintf(stderr, PFX "snd_pcm_recover: %d\n", ret);

		if (silent_period)
			snd_pcm_writei(handle, silent_period, period_size);
		snd_pcm_writei(handle, samples, len);
	}

	return len;
}

void sndout_alsa_exit(void)
{
	snd_pcm_close(handle);
	handle = NULL;
}
