#include "oslib/audiobackend_oss.h"
#ifdef USE_OSS
#include <sys/ioctl.h>
#include <sys/fcntl.h>
#include <unistd.h>
#include <sys/soundcard.h>

static int oss_audio_fd = -1;

static void oss_init()
{
	oss_audio_fd = open("/dev/dsp", O_WRONLY);
	if (oss_audio_fd < 0)
	{
		printf("Couldn't open /dev/dsp.\n");
	}
	else
	{
		printf("sound enabled, dsp opened for write\n");
		int tmp=44100;
		int err_ret;
		err_ret=ioctl(oss_audio_fd,SNDCTL_DSP_SPEED,&tmp);
		printf("set Frequency to %i, return %i (rate=%i)\n", 44100, err_ret, tmp);
		int channels=2;
		err_ret=ioctl(oss_audio_fd, SNDCTL_DSP_CHANNELS, &channels);
		printf("set dsp to stereo (%i => %i)\n", channels, err_ret);
		int format=AFMT_S16_LE;
		err_ret=ioctl(oss_audio_fd, SNDCTL_DSP_SETFMT, &format);
		printf("set dsp to %s audio (%i/%i => %i)\n", "16bits signed", AFMT_S16_LE, format, err_ret);
	}
}

static u32 oss_push(void* frame, u32 samples, bool wait)
{
	write(oss_audio_fd, frame, samples*4);
	return 1;
}

static void oss_term() {
	if(oss_audio_fd >= 0)
	{
		close(oss_audio_fd);
	}
}

audiobackend_t audiobackend_oss = {
		"oss", // Slug
		"Open Sound System", // Name
		&oss_init,
		&oss_push,
		&oss_term
};

#endif
