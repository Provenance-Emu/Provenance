/*
 * (C) Gražvydas "notaz" Ignotas, 2009-2010
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

/* sound output via OSS */
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/soundcard.h>
#include <unistd.h>

#include "sndout_oss.h"

int sndout_oss_frag_frames = 1;
int sndout_oss_can_restart = 1;

static int sounddev = -1, mixerdev = -1;
static int can_write_safe;

#define FRAG_COUNT 4

int sndout_oss_init(void)
{
	if (mixerdev >= 0) close(mixerdev);
  	mixerdev = open("/dev/mixer", O_RDWR);
	if (mixerdev == -1)
	{
		perror("open(\"/dev/mixer\")");
	}

	return 0;
}

void sndout_oss_stop(void)
{
	/* restarting audio on GP2X causes trouble,
	 * not restarting on Caanoo causes trouble */
	if (!sndout_oss_can_restart)
		return;

	if (sounddev < 0)
		return;

	// sync causes trouble on Caanoo..
	//ioctl(sounddev, SOUND_PCM_SYNC, 0);

	close(sounddev);
	sounddev = -1;
}

int sndout_oss_start(int rate, int stereo)
{
	static int s_oldrate = 0, s_oldstereo = 0;
	int frag, bsize, bits, ret;

	// GP2X: if no settings change, we don't need to do anything,
	// since audio is never stopped there
	if (sounddev >= 0 && rate == s_oldrate && s_oldstereo == stereo)
		return 0;

	sndout_oss_stop();
	sounddev = open("/dev/dsp", O_WRONLY);
	if (sounddev == -1)
	{
		perror("open(\"/dev/dsp\")");
		sounddev = open("/dev/dsp1", O_WRONLY);
		if (sounddev == -1) {
			perror("open(\"/dev/dsp1\")");
			return -1;
		}
	}

	// try to fit sndout_oss_frag_frames (video) frames
	// worth of sound data in OSS fragment
	// ignore mono because it's unlikely to be used and
	// both GP2X and Wiz mixes mono to stereo anyway.
	bsize = (sndout_oss_frag_frames * rate / 50) * 4;

	for (frag = 0; bsize; bsize >>= 1, frag++)
		;

	frag |= FRAG_COUNT << 16;	// fragment count
	ret = ioctl(sounddev, SNDCTL_DSP_SETFRAGMENT, &frag);
	if (ret < 0)
		perror("SNDCTL_DSP_SETFRAGMENT failed");

	bits = 16;
	ret = ioctl(sounddev, SNDCTL_DSP_STEREO, &stereo);
	if (ret == 0)
		ret = ioctl(sounddev, SNDCTL_DSP_SETFMT, &bits);
	if (ret == 0)
		ret = ioctl(sounddev, SNDCTL_DSP_SPEED, &rate);
	if (ret < 0)
		perror("failed to set audio format");

#ifdef __GP2X__
	// not sure if this is still needed (avoiding driver bugs?)
	usleep(192*1024);
#endif

	printf("sndout_oss_start: %d/%dbit/%s, %d buffers of %i bytes\n",
		rate, bits, stereo ? "stereo" : "mono", frag >> 16, 1 << (frag & 0xffff));

	s_oldrate = rate; s_oldstereo = stereo;
	can_write_safe = 0;
	return 0;
}

int sndout_oss_write(const void *buff, int len)
{
	return write(sounddev, buff, len);
}

#include "../plat.h"

/* not really non-blocking, just detects if blocking occurs
 * and starts skipping writes in case it does. */
int sndout_oss_write_nb(const void *buff, int len)
{
	static int lag_counter, skip_counter;
	unsigned int t;
	int ret;

	if (lag_counter > 2) {
		// skip writes if audio starts blocking
		lag_counter = 0;
		skip_counter = FRAG_COUNT;
	}

	if (skip_counter > 0) {
		skip_counter--;
		return len;
	}

	t = plat_get_ticks_ms();
	ret = sndout_oss_write(buff, len);
	t = plat_get_ticks_ms() - t;
	if (t > 1) {
		// this shouldn't really happen, most likely audio is out of sync
		lag_counter++;
		if (lag_counter > 2)
			printf("audio lag %u\n", t);
	}
	else
		lag_counter = 0;

	return ret;
}

int sndout_oss_can_write(int bytes)
{
	audio_buf_info bi;
	int ret;

#ifdef __GP2X__
	// note: SNDCTL_DSP_GETOSPACE crashes F100 kernel for some reason
	// if called too early, so we work around here
	if (can_write_safe++ < 8)
		return 1;
#endif
	ret = ioctl(sounddev, SNDCTL_DSP_GETOSPACE, &bi);
	if (ret < 0)
		return 1;

	// have enough bytes to write + 1 frag
	return bi.bytes - bi.fragsize >= bytes ? 1 : 0;
}

void sndout_oss_wait(void)
{
	// FIXME?
	ioctl(sounddev, SOUND_PCM_SYNC, 0);
}

void sndout_oss_setvol(int l, int r)
{
	if (mixerdev < 0) return;

 	l=l<0?0:l; l=l>255?255:l; r=r<0?0:r; r=r>255?255:r;
 	l<<=8; l|=r;
 	ioctl(mixerdev, SOUND_MIXER_WRITE_PCM, &l); /*SOUND_MIXER_WRITE_VOLUME*/
}

void sndout_oss_exit(void)
{
	if (sounddev >= 0) close(sounddev); sounddev = -1;
	if (mixerdev >= 0) close(mixerdev); mixerdev = -1;
}

