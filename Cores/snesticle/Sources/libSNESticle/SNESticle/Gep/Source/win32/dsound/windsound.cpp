

#define INITGUID
#include <windows.h>
#include <dsound.h>
#include "types.h"
#include "windsound.h"
#include "console.h"
#include "dsbuffer.h"

static LPDIRECTSOUND		_DSound_pObject = NULL;
static LPDIRECTSOUNDBUFFER  _DSound_pPrimary = NULL;
static DSBuffer		   *_DSound_pBuffer = NULL;
static Bool				_DSound_bActive;

DSoundObjectT DSoundGetObject()
{
	return _DSound_pObject;
}

void DSoundInit(HWND hWnd)
{
	DSoundShutdown();

	if (DirectSoundCreate(NULL, &_DSound_pObject, NULL) == DS_OK)
	{
		DSBUFFERDESC dsbdesc;

		// Set co-op level
		_DSound_pObject->SetCooperativeLevel(hWnd, DSSCL_PRIORITY);
		
		// Obtain primary buffer
		ZeroMemory(&dsbdesc, sizeof(DSBUFFERDESC));
		dsbdesc.dwSize = sizeof(DSBUFFERDESC);
		dsbdesc.dwFlags = DSBCAPS_PRIMARYBUFFER;
		if (_DSound_pObject->CreateSoundBuffer(&dsbdesc, &_DSound_pPrimary, NULL)!=DS_OK)
		{
			return;
		}

		ConPrint("DirectSound initialized\n");
	}
}

void DSoundShutdown()
{
	if (_DSound_pBuffer)
	{
		delete _DSound_pBuffer;
		_DSound_pBuffer = NULL;
	}

	if (_DSound_pPrimary)
	{
		_DSound_pPrimary->Release();
		_DSound_pPrimary = NULL;
	}

	if (_DSound_pObject)
	{
		 _DSound_pObject->Release();
		_DSound_pObject = NULL;
	}
}


void DSoundSetFormat(Uint32 uSampleRate, Uint32 nSampleBits, Uint32 nChannels, Uint32 nSamples)
{
	if (_DSound_pPrimary)
	{
		WAVEFORMATEX wfx;

		if (_DSound_pBuffer)
		{
			delete _DSound_pBuffer;
			_DSound_pBuffer = NULL;
		}
		
		memset(&wfx, 0, sizeof(wfx)); 
		wfx.wFormatTag		= WAVE_FORMAT_PCM; 
		wfx.nChannels		= nChannels; 
		wfx.nSamplesPerSec	= uSampleRate; 
		wfx.wBitsPerSample	= nSampleBits; 
		wfx.nBlockAlign		= wfx.wBitsPerSample / 8 * wfx.nChannels;
		wfx.nAvgBytesPerSec = wfx.nSamplesPerSec * wfx.nBlockAlign;
		_DSound_pPrimary->SetFormat(&wfx);

		_DSound_pPrimary->GetFormat(&wfx, sizeof(wfx), NULL);
		ConPrint("DirectSound Primary: %dhz %d-bit %s\n",
			wfx.nSamplesPerSec, wfx.wBitsPerSample, wfx.nChannels == 2 ? "stereo" : "mono");

		// create secondary buffer
		_DSound_pBuffer = new DSBuffer(wfx.nSamplesPerSec, wfx.wBitsPerSample, wfx.nChannels, nSamples);
	}
}

CMixBuffer *DSoundGetBuffer()
{
	return _DSound_pBuffer;
}

