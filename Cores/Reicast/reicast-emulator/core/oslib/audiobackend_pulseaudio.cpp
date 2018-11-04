#include "oslib/audiobackend_pulseaudio.h"
#ifdef USE_PULSEAUDIO
#include <sys/ioctl.h>
#include <sys/fcntl.h>
#include <sys/unistd.h>
#include <pulse/simple.h>

static pa_simple *pulse_stream;

static void pulseaudio_init()
{
	pa_sample_spec ss;
	ss.format = PA_SAMPLE_S16LE;
	ss.channels = 2;
	ss.rate = 44100;
	/* Create a new playback stream */
	pulse_stream = pa_simple_new(NULL, "reicast", PA_STREAM_PLAYBACK, NULL, "reicast", &ss, NULL, NULL, NULL);
  if (!pulse_stream) {
    fprintf(stderr, "PulseAudio: pa_simple_new() failed!\n");
  }
}

static u32 pulseaudio_push(void* frame, u32 samples, bool wait)
{
	if (pa_simple_write(pulse_stream, frame, (size_t) samples*4, NULL) < 0) {
      fprintf(stderr, "PulseAudio: pa_simple_write() failed!\n");
	}
}

static void pulseaudio_term() {
	if(pulse_stream != NULL)
	{
		// Make sure that every single sample was played
		if (pa_simple_drain(pulse_stream, NULL) < 0) {
        fprintf(stderr, "PulseAudio: pa_simple_drain() failed!\n");
    }
		pa_simple_free(pulse_stream);
	}
}

audiobackend_t audiobackend_pulseaudio = {
		"pulse", // Slug
		"PulseAudio", // Name
		&pulseaudio_init,
		&pulseaudio_push,
		&pulseaudio_term
};
#endif
