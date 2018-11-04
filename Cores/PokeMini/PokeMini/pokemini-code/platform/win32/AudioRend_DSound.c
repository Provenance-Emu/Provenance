/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

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

#include <windows.h>
#include <dsound.h>
#include <stdio.h>
#include "AudioRend.h"

// Local variables
static int RendWasInit = 0;
static int RendWasIsPlaying = 0;
static int RendBuffblock = 0;
static int RendBuffsize = 0;
static HANDLE RendThread = NULL;
static volatile int RendThreadRun = 0;
static AudioRend_Callback RendCallback = NULL;
static LPDIRECTSOUND pDS = NULL;
static LPDIRECTSOUNDBUFFER pDSBP = NULL;
static LPDIRECTSOUNDBUFFER pDSBS = NULL;
static WAVEFORMATEX Wavf;
static int SndNextWriteOffset = 0;

// Prototypes
int AudioRend_DSound_WasInit(void);
int AudioRend_DSound_Init(HWND hWnd, int freq, int bits, int channels, int buffsize, AudioRend_Callback callback);
void AudioRend_DSound_Terminate(void);
void AudioRend_DSound_Enable(int play);

// Audio was initialized?
int AudioRend_DSound_WasInit(void)
{
	return RendWasInit;
}

// Audio initialize, return if was successful
int AudioRend_DSound_Init(HWND hWnd, int freq, int bits, int channels, int buffsize, AudioRend_Callback callback)
{
	WAVEFORMATEX pcmwf;
	DSBUFFERDESC dsbdesc;

	// Create and set cooperative level
	if FAILED(DirectSoundCreate(NULL, &pDS, NULL)) {
		MessageBox(0, "DirectSoundCreate() Failed", "DirectSound", MB_OK | MB_ICONERROR);
		AudioRend_DSound_Terminate();
		return 0;
	}
	if FAILED(IDirectSound_SetCooperativeLevel(pDS, hWnd, DSSCL_EXCLUSIVE)) {
		MessageBox(0, "SetCooperativeLevel Failed", "DirectSound", MB_OK | MB_ICONERROR);
		AudioRend_DSound_Terminate();
		return 0;
	}

	// Create the primary buffer and set the format
	ZeroMemory(&dsbdesc, sizeof(DSBUFFERDESC));
	dsbdesc.dwSize = sizeof(DSBUFFERDESC);
	dsbdesc.dwFlags = DSBCAPS_PRIMARYBUFFER;
	if FAILED(IDirectSound_CreateSoundBuffer(pDS, &dsbdesc, &pDSBP, NULL)) {
		MessageBox(0, "CreateSoundBuffer Failed", "DirectSound", MB_OK | MB_ICONERROR);
		AudioRend_DSound_Terminate();
		return 0;
	}
	ZeroMemory(&pcmwf, sizeof(PCMWAVEFORMAT));
	pcmwf.wFormatTag = WAVE_FORMAT_PCM;
	pcmwf.nChannels = channels;
	pcmwf.nSamplesPerSec = freq;
	pcmwf.wBitsPerSample = bits;
	pcmwf.nBlockAlign = (unsigned short)(((unsigned short)pcmwf.nChannels * (unsigned short)pcmwf.wBitsPerSample) / 8);
	pcmwf.nAvgBytesPerSec = pcmwf.nSamplesPerSec * pcmwf.nBlockAlign;
	if FAILED(IDirectSoundBuffer_SetFormat(pDSBP, &pcmwf)) {
		MessageBox(0, "SetFormat Failed", "DirectX", MB_OK | MB_ICONERROR);
		AudioRend_DSound_Terminate();
		return 0;
	}

	// Create the secondary buffer
	dsbdesc.dwSize = sizeof(DSBUFFERDESC);
	dsbdesc.dwFlags = DSBCAPS_CTRLVOLUME | DSBCAPS_GETCURRENTPOSITION2 | DSBCAPS_GLOBALFOCUS;
	dsbdesc.dwBufferBytes = buffsize*2;
	dsbdesc.lpwfxFormat = (LPWAVEFORMATEX)&pcmwf;
	if FAILED(IDirectSound_CreateSoundBuffer(pDS, &dsbdesc, &pDSBS, NULL)) {
		MessageBox(0, "CreateSoundBuffer 2 Failed", "DirectX", MB_OK | MB_ICONERROR);
		AudioRend_DSound_Terminate();
		return 0;
	}

	RendCallback = callback;
	RendWasInit = 1;
	RendWasIsPlaying = 0;
	RendBuffblock = buffsize;
	RendBuffsize = buffsize*2;
	return 1;
}

void AudioRend_DSound_Terminate(void)
{
	if (RendWasIsPlaying) AudioRend_DSound_Enable(0);
	if (pDSBS) IDirectSoundBuffer_Release(pDSBS);
	if (pDSBP) IDirectSoundBuffer_Release(pDSBP);
	if (pDS) IDirectSound_Release(pDS);
	RendWasInit = 0;
}

// Calculate distance on a circular buffer
static int Sound_Distance(int play, int write)
{
	if (play > write) {
		// Warparound
		return (RendBuffsize - play) + write;
	} else {
		// Doesn't warp-around
		return write - play;
	}
}

static DWORD WINAPI AudioRend_DSound_Thread(LPVOID lpParameter)
{
	int hr;
	LPVOID pData1;
	DWORD dwData1Size;
	LPVOID pData2;
	DWORD dwData2Size;
	DWORD writep;
	DWORD dwStatus;

	while (RendThreadRun) {
		// Restore lost buffer
		IDirectSoundBuffer_GetStatus(pDSBS, &dwStatus);
		if (dwStatus && DSBSTATUS_BUFFERLOST) {
			do {
				hr = IDirectSoundBuffer_Restore(pDSBS);
				if (hr == DSERR_BUFFERLOST) Sleep(10);
				if (!RendThreadRun) return 0;
			} while ((hr = IDirectSoundBuffer_Restore(pDSBS)) == DSERR_BUFFERLOST);
		}

		// Wait until we sync the buffers
		if (dwStatus && DSBSTATUS_PLAYING) {
			do {
				Sleep(20);
				IDirectSoundBuffer_GetCurrentPosition(pDSBS, 0, &writep);
				if (Sound_Distance(writep, SndNextWriteOffset) <= RendBuffblock) break;
			} while (RendThreadRun);
		}

		// Transfer the buffer data
		IDirectSoundBuffer_Lock(pDSBS, SndNextWriteOffset, RendBuffblock, &pData1, &dwData1Size, &pData2, &dwData2Size, 0);
		SndNextWriteOffset = (SndNextWriteOffset + RendBuffblock) % RendBuffsize;
		if (RendCallback) RendCallback((void *)pData1, dwData1Size);
		if (pData2) if (RendCallback) ((void *)pData2, dwData2Size);
		IDirectSoundBuffer_Unlock(pDSBS, pData1, dwData1Size, pData2, dwData2Size);
	}

	return 1;
}

void AudioRend_DSound_Enable(int play)
{
	DWORD ThrID;
	if (!RendWasInit) return;
	if (play && !RendWasIsPlaying) {
		// Clear the sound and start looping
		IDirectSoundBuffer_SetCurrentPosition(pDSBS, 0);
		IDirectSoundBuffer_Play(pDSBS, 0, 0, DSBPLAY_LOOPING);
		RendThreadRun = 1;
		RendThread = CreateThread(NULL, 0, AudioRend_DSound_Thread, NULL, 0, &ThrID);
	}
	if (!play && RendWasIsPlaying) {
		RendThreadRun = 0;
		WaitForSingleObject(RendThread, INFINITE);
		IDirectSoundBuffer_Stop(pDSBS);
	}
	RendWasIsPlaying = play;
}

// Video render driver
const TAudioRend AudioRend_DSound = {
	AudioRend_DSound_WasInit,
	AudioRend_DSound_Init,
	AudioRend_DSound_Terminate,
	AudioRend_DSound_Enable,
};
