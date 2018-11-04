#include <limits.h>
#include "cfg/cfg.h"
#include "oslib/oslib.h"
#include "audiostream.h"
#include "oslib/audiobackend_directsound.h"
#include "oslib/audiobackend_android.h"
#include "oslib/audiobackend_alsa.h"
#include "oslib/audiobackend_oss.h"
#include "oslib/audiobackend_pulseaudio.h"
#include "oslib/audiobackend_coreaudio.h"
#include "oslib/audiobackend_omx.h"
#include "oslib/audiobackend_libao.h"

struct SoundFrame { s16 l;s16 r; };
#define SAMPLE_COUNT 512

SoundFrame RingBuffer[SAMPLE_COUNT];
const u32 RingBufferByteSize = sizeof(RingBuffer);
const u32 RingBufferSampleCount = SAMPLE_COUNT;

volatile u32 WritePtr;  //last WRITEN sample
volatile u32 ReadPtr;   //next sample to read

u32 gen_samples=0;

double time_diff = 128/44100.0;
double time_last;
#ifdef LOG_SOUND
WaveWriter rawout("d:\\aica_out.wav");
#endif

static bool audiobackends_registered = false;
static unsigned int audiobackends_num_max = 1;
static unsigned int audiobackends_num_registered = 0;
static audiobackend_t **audiobackends = static_cast<audiobackend_t**>(calloc(audiobackends_num_max, sizeof(audiobackend_t*)));
static audiobackend_t *audiobackend_current = NULL;

bool RegisterAudioBackend(audiobackend_t *backend)
{
	/* This function announces the availability of an audio backend to reicast. */
	// Check if backend is valid
	if (backend == NULL)
	{
		printf("ERROR: Tried to register invalid audio backend (NULL pointer).\n");
		return false;
	}
	if (backend->slug == "auto" || backend->slug == "none") {
		printf("ERROR: Tried to register invalid audio backend (slug \"%s\" is a reserved keyword).\n", backend->slug.c_str());
		return false;
	}
	// Check if we need to allocate addition memory for storing the pointers and allocate if neccessary
	if (audiobackends_num_registered == audiobackends_num_max)
	{
		// Check for integer overflows
		if (audiobackends_num_max == UINT_MAX)
		{
			printf("ERROR: Registering audio backend \"%s\" (%s) failed. Cannot register more than %u backends\n", backend->slug.c_str(), backend->name.c_str(), audiobackends_num_max);
			return false;
		}
		audiobackends_num_max++;
		audiobackend_t **new_ptr = static_cast<audiobackend_t**>(realloc(audiobackends, audiobackends_num_max*sizeof(audiobackend_t*)));
		// Make sure that allocation worked
		if (new_ptr == NULL)
		{
			printf("ERROR: Registering audio backend \"%s\" (%s) failed. Cannot allocate additional memory.\n", backend->slug.c_str(), backend->name.c_str());
			return false;
		}
		audiobackends = new_ptr;
	}
	audiobackends[audiobackends_num_registered] = backend;
	audiobackends_num_registered++;
	return true;
}

void RegisterAllAudioBackends() {
		#if HOST_OS==OS_WINDOWS
		RegisterAudioBackend(&audiobackend_directsound);
		#endif
		#if ANDROID
		RegisterAudioBackend(&audiobackend_android);
		#endif
		#if USE_OMX
		RegisterAudioBackend(&audiobackend_omx);
		#endif
		#if USE_ALSA
		RegisterAudioBackend(&audiobackend_alsa);
		#endif
		#if USE_OSS
		RegisterAudioBackend(&audiobackend_oss);
		#endif
		#if USE_PULSEAUDIO
		RegisterAudioBackend(&audiobackend_pulseaudio);
		#endif
		#if USE_LIBAO
		RegisterAudioBackend(&audiobackend_libao);
		#endif
        #if HOST_OS == OS_DARWIN
        RegisterAudioBackend(&audiobackend_coreaudio);
        #endif
		audiobackends_registered = true;
}

static audiobackend_t* GetAudioBackend(std::string slug)
{
	if (slug == "none")
	{
			printf("WARNING: Audio backend set to \"none\"!\n");
	}
	else if(audiobackends_num_registered > 0)
	{
		if (slug == "auto")
		{
			/* FIXME: At some point, one might want to insert some intelligent
				 algorithm for autoselecting the approriate audio backend here.
				 I'm too lazy right now. */
			printf("Auto-selected audio backend \"%s\" (%s).\n", audiobackends[0]->slug.c_str(), audiobackends[0]->name.c_str());
			return audiobackends[0];
		}
		else
		{
			for(unsigned int i = 0; i < audiobackends_num_registered; i++)
			{
				if(audiobackends[i]->slug == slug)
				{
						return audiobackends[i];
				}
			}
			printf("WARNING: Audio backend \"%s\" not found!\n", slug.c_str());
		}
	}
	else
	{
			printf("WARNING: No audio backends available!\n");
	}
	return NULL;
}

u32 PushAudio(void* frame, u32 amt, bool wait) {
	if (audiobackend_current != NULL) {
		return audiobackend_current->push(frame, amt, wait);
	}
	return 0;
}

u32 asRingUsedCount()
{
	if (WritePtr>ReadPtr)
		return WritePtr-ReadPtr;
	else
		return RingBufferSampleCount-(ReadPtr-WritePtr);
	//s32 sz=(WritePtr+1)%RingBufferSampleCount-ReadPtr;
	//return sz<0?sz+RingBufferSampleCount:sz;
}
u32 asRingFreeCount()
{
	return RingBufferSampleCount-asRingUsedCount();
}

void WriteSample(s16 r, s16 l)
{
	const u32 ptr=(WritePtr+1)%RingBufferSampleCount;
	RingBuffer[ptr].r=r;
	RingBuffer[ptr].l=l;
	WritePtr=ptr;

	if (WritePtr==(SAMPLE_COUNT-1))
	{
		PushAudio(RingBuffer,SAMPLE_COUNT,settings.aica.LimitFPS);
	}
}

void InitAudio()
{
	if (cfgLoadInt("audio", "disable", 0)) {
		printf("WARNING: Audio disabled in config!\n");
		return;
	}

	cfgSaveInt("audio","disable",0);

	if (!audiobackends_registered) {
		//FIXME: There might some nicer way to do this.
		RegisterAllAudioBackends();
	}

	if (audiobackend_current != NULL) {
		printf("ERROR: The audio backend \"%s\" (%s) has already been initialized, you need to terminate it before you can call audio_init() again!\n", audiobackend_current->slug.c_str(), audiobackend_current->name.c_str());
		return;
	}

	string audiobackend_slug = cfgLoadStr("audio", "backend", "auto"); // FIXME: This could be made a parameter
	audiobackend_current = GetAudioBackend(audiobackend_slug);
	if (audiobackend_current == NULL) {
		printf("WARNING: Running without audio!\n");
		return;
	}
	printf("Initializing audio backend \"%s\" (%s)...\n", audiobackend_current->slug.c_str(), audiobackend_current->name.c_str());
	audiobackend_current->init();	
}

void TermAudio()
{
	if (audiobackend_current != NULL) {
		audiobackend_current->term();
		printf("Terminating audio backend \"%s\" (%s)...\n", audiobackend_current->slug.c_str(), audiobackend_current->name.c_str());
		audiobackend_current = NULL;
	}	
}
