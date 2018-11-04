#include "oslib/audiobackend_omx.h"
#if USE_OMX

#include <IL/OMX_Broadcom.h>
#include <unistd.h>

#define PORT_INDEX 100
#define OUTPUT_FREQ 44100

static OMX_HANDLETYPE omx_handle;
static OMX_STATETYPE omx_state = OMX_StateInvalid;
static size_t audio_buffer_idx;
static OMX_BUFFERHEADERTYPE** audio_buffers = NULL;
static u32 latency_max;
static u32 buffer_count;
static u32 buffer_size;
static u32 buffer_length;
static pthread_mutex_t audio_lock;
static pthread_cond_t omx_state_cond;

OMX_ERRORTYPE EventHandler(
		OMX_IN OMX_HANDLETYPE hComponent,
		OMX_IN OMX_PTR pAppData,
		OMX_IN OMX_EVENTTYPE eEvent,
		OMX_IN OMX_U32 nData1,
		OMX_IN OMX_U32 nData2,
		OMX_IN OMX_PTR pEventData)
{
	pthread_mutex_lock(&audio_lock);
	if(eEvent == OMX_EventCmdComplete && nData1 == OMX_CommandStateSet)
	{
		omx_state = (OMX_STATETYPE)nData2;
		pthread_cond_signal(&omx_state_cond);
	}
	pthread_mutex_unlock(&audio_lock);
	return OMX_ErrorNone;
}

OMX_ERRORTYPE EmptyBufferDone(
		OMX_IN OMX_HANDLETYPE hComponent,
		OMX_IN OMX_PTR pAppData,
		OMX_IN OMX_BUFFERHEADERTYPE* pBuffer)
{
	return OMX_ErrorNone;
}

OMX_ERRORTYPE FillBufferDone(
		OMX_OUT OMX_HANDLETYPE hComponent,
		OMX_OUT OMX_PTR pAppData,
		OMX_OUT OMX_BUFFERHEADERTYPE* pBuffer)
{
	return OMX_ErrorNone;
}

void omx_wait_for_state(OMX_STATETYPE state)
{
	pthread_mutex_lock(&audio_lock);
	while(omx_state != state)
		pthread_cond_wait(&omx_state_cond, &audio_lock);
	pthread_mutex_unlock(&audio_lock);
}

static u32 omx_get_latency()
{
	OMX_PARAM_U32TYPE param;
	memset(&param, 0, sizeof(OMX_PARAM_U32TYPE));
	param.nSize = sizeof(OMX_PARAM_U32TYPE);
	param.nVersion.nVersion = OMX_VERSION;
	param.nPortIndex = PORT_INDEX;

	OMX_ERRORTYPE error = OMX_GetConfig(omx_handle, OMX_IndexConfigAudioRenderingLatency, &param);
	if(error != OMX_ErrorNone)
		fprintf(stderr, "OMX: failed to get OMX configuration (OMX_IndexConfigAudioRenderingLatency). Error 0x%X\n", error);

	return param.nU32 * 1000 / OUTPUT_FREQ;
}

static void omx_init()
{
	OMX_ERRORTYPE error;

	error = OMX_Init();
	if(error != OMX_ErrorNone)
	{
		fprintf(stderr, "OMX: OMX_Init() failed. Error 0x%X\n", error);
		return;
	}

	// Initialize settings
	latency_max = settings.omx.Audio_Latency;
	buffer_size = settings.aica.BufferSize * 4;
	buffer_count = 2 + OUTPUT_FREQ * latency_max / (buffer_size * 1000);

	OMX_CALLBACKTYPE callbacks;
	callbacks.EventHandler = EventHandler;
	callbacks.EmptyBufferDone = EmptyBufferDone;
	callbacks.EmptyBufferDone = FillBufferDone;

	error = OMX_GetHandle(&omx_handle, (OMX_STRING)"OMX.broadcom.audio_render", NULL, &callbacks);
	if(error != OMX_ErrorNone)
	{
		fprintf(stderr, "OMX: OMX_GetHandle() failed. Error 0x%X\n", error);
		return;
	}

	OMX_PARAM_PORTDEFINITIONTYPE param;
	memset(&param, 0, sizeof(OMX_PARAM_PORTDEFINITIONTYPE));
	param.nSize = sizeof(OMX_PARAM_PORTDEFINITIONTYPE);
	param.nVersion.nVersion = OMX_VERSION;
	param.nPortIndex = PORT_INDEX;
	param.nBufferSize = buffer_size;
	param.nBufferCountActual = buffer_count;
	param.format.audio.eEncoding = OMX_AUDIO_CodingPCM;

	error = OMX_SetParameter(omx_handle, OMX_IndexParamPortDefinition, &param);
	if(error != OMX_ErrorNone)
		fprintf(stderr, "OMX: failed to set OMX_IndexParamPortDefinition. Error 0x%X\n", error);

	OMX_AUDIO_PARAM_PCMMODETYPE pcm;
	memset(&pcm, 0, sizeof(OMX_AUDIO_PARAM_PCMMODETYPE));
	pcm.nSize = sizeof(OMX_AUDIO_PARAM_PCMMODETYPE);
	pcm.nVersion.nVersion = OMX_VERSION;
	pcm.nPortIndex = PORT_INDEX;
	pcm.nChannels = 2;
	pcm.eNumData = OMX_NumericalDataSigned;
	pcm.eEndian = OMX_EndianLittle;
	pcm.nSamplingRate = OUTPUT_FREQ;
	pcm.bInterleaved = OMX_TRUE;
	pcm.nBitPerSample = 16;
	pcm.ePCMMode = OMX_AUDIO_PCMModeLinear;
	pcm.eChannelMapping[1] = OMX_AUDIO_ChannelRF;
	pcm.eChannelMapping[0] = OMX_AUDIO_ChannelLF;

	error = OMX_SetParameter(omx_handle, OMX_IndexParamAudioPcm, &pcm);
	if(error != OMX_ErrorNone)
		fprintf(stderr, "OMX: failed to set OMX_IndexParamAudioPcm. Error 0x%X\n", error);

	// Disable all ports
	error = OMX_SendCommand(omx_handle, OMX_CommandPortDisable, PORT_INDEX, NULL);
	if(error != OMX_ErrorNone)
		fprintf(stderr, "OMX: failed to do OMX_CommandPortDisable. Error 0x%X\n", error);

	OMX_PORT_PARAM_TYPE param2;
	memset(&param2, 0, sizeof(OMX_PORT_PARAM_TYPE));
	param2.nSize = sizeof(OMX_PORT_PARAM_TYPE);
	param2.nVersion.nVersion = OMX_VERSION;
	error = OMX_GetParameter(omx_handle, OMX_IndexParamOtherInit, &param2);
	if(error != OMX_ErrorNone)
	{
		fprintf(stderr, "OMX: failed to get OMX_IndexParamOtherInit. Error 0x%X\n", error);
	}
	else
	{
		for(u32 i = 0; i < param2.nPorts; i++)
		{
			u32 port = param2.nStartPortNumber + i;
			error = OMX_SendCommand(omx_handle, OMX_CommandPortDisable, port, NULL);
			if(error != OMX_ErrorNone)
				fprintf(stderr, "OMX: failed to do OMX_CommandPortDisable on port %u. Error 0x%X\n", port, error);
		}
	}

	// Go into idle state
	error = OMX_SendCommand(omx_handle, OMX_CommandStateSet, OMX_StateIdle, NULL);
	if(error != OMX_ErrorNone)
	{
		fprintf(stderr, "OMX: failed to set OMX_CommandStateSet. Error 0x%X\n", error);
		return;
	}
	omx_wait_for_state(OMX_StateIdle);

	// Check if we're in a state able to recieve buffers
	OMX_STATETYPE state;
	error = OMX_GetState(omx_handle, &state);
	if(error != OMX_ErrorNone || !(state == OMX_StateIdle || state == OMX_StateExecuting || state == OMX_StatePause))
	{
		fprintf(stderr, "OMX: state is incorrect. State 0x%X; Error 0x%X\n", state, error);
		return;
	}

	// Create audio buffers
	fprintf(stderr, "OMX: creating %u buffers\n", buffer_count);

	// Enable port
	error = OMX_SendCommand(omx_handle, OMX_CommandPortEnable, PORT_INDEX, NULL);
	if(error != OMX_ErrorNone)
		fprintf(stderr, "OMX: failed to do OMX_CommandPortEnable. Error 0x%X\n", error);

	// Free audio buffers if they're allocated
	if(audio_buffers != NULL)
		delete[] audio_buffers;

	// Allocate buffers
	audio_buffers = new OMX_BUFFERHEADERTYPE*[buffer_count];
	for(size_t i = 0; i < buffer_count; i++)
	{
		error = OMX_AllocateBuffer(omx_handle, &audio_buffers[i], PORT_INDEX, NULL, buffer_size);
		if(error != OMX_ErrorNone)
		{
			fprintf(stderr, "OMX: failed to allocate buffer[%u]. Error 0x%X\n", i, error);
			return;
		}
	}

	// Set state to executing
	error = OMX_SendCommand(omx_handle, OMX_CommandStateSet, OMX_StateExecuting, NULL);
	if(error != OMX_ErrorNone)
	{
		fprintf(stderr, "OMX: failed to do OMX_CommandStateSet. Error 0x%X\n", error);
		return;
	}
	omx_wait_for_state(OMX_StateExecuting);

	// Empty buffers
	for(size_t i = 0; i < buffer_count; i++)
	{
		memset(audio_buffers[i]->pBuffer, 0, buffer_size);
		audio_buffers[i]->nOffset = 0;
		audio_buffers[i]->nFilledLen = buffer_size;

		error = OMX_EmptyThisBuffer(omx_handle, audio_buffers[i]);
		if(error != OMX_ErrorNone)
			fprintf(stderr, "OMX: failed to empty buffer[%u]. Error 0x%X\n", i, error);
	}

	char* output_device = "local";
	if(settings.omx.Audio_HDMI)
		output_device = (char*)"hdmi";

	// Set audio destination
	OMX_CONFIG_BRCMAUDIODESTINATIONTYPE ar_dest;
	memset(&ar_dest, 0, sizeof(ar_dest));
	ar_dest.nSize = sizeof(OMX_CONFIG_BRCMAUDIODESTINATIONTYPE);
	ar_dest.nVersion.nVersion = OMX_VERSION;
	strcpy((char *)ar_dest.sName, output_device);
	error = OMX_SetConfig(omx_handle, OMX_IndexConfigBrcmAudioDestination, &ar_dest);
	if(error != OMX_ErrorNone)
	{
		fprintf(stderr, "OMX: failed to set OMX configuration (OMX_IndexConfigBrcmAudioDestination). Error 0x%X\n", error);
		return;
	}

	audio_buffer_idx = 0;
	buffer_length = 0;

	fprintf(stderr, "OMX: audio output to '%s'\n", ar_dest.sName);
}

static u32 omx_push(void* frame, u32 samples, bool wait)
{
	if(audio_buffers == NULL)
		return 1;

	size_t data_size = samples * 4;

	while(data_size > 0)
	{
		size_t copy_size = std::min(buffer_size, data_size);

		// Don't have more than maximum audio latency
		u32 latency = omx_get_latency();
		if(latency > latency_max)
		{
			usleep((latency - latency_max) * 1000);
		}
		else if(latency == 0)
		{
			fprintf(stderr, "OMX: underrun occurred\n");
		}

		memcpy(audio_buffers[audio_buffer_idx]->pBuffer + buffer_length, frame, copy_size);
		buffer_length += copy_size;

		// Flush buffer and swap
		if(buffer_length >= buffer_size)
		{
			audio_buffers[audio_buffer_idx]->nOffset = 0;
			audio_buffers[audio_buffer_idx]->nFilledLen = buffer_size;

			OMX_ERRORTYPE error = OMX_EmptyThisBuffer(omx_handle, audio_buffers[audio_buffer_idx]);
			if(error != OMX_ErrorNone)
				fprintf(stderr, "OMX: failed to empty buffer[%u]. Error 0x%X\n", audio_buffer_idx, error);

			audio_buffer_idx = (audio_buffer_idx + 1) % buffer_count;
			buffer_length = 0;
		}

		data_size -= copy_size;
	}

	return 1;
}

static void omx_term()
{
	OMX_ERRORTYPE error;

	// Is there anything else that needs to be done for omx?

	error = OMX_Deinit();
	if(error != OMX_ErrorNone)
		fprintf(stderr, "OMX: OMX_Deinit() failed. Error 0x%X\n", error);

	if(audio_buffers != NULL)
	{
		delete[] audio_buffers;
		audio_buffers = NULL;
	}
}

audiobackend_t audiobackend_omx = {
    "omx", // Slug
    "OpenMAX IL", // Name
    &omx_init,
    &omx_push,
    &omx_term
};

#endif
