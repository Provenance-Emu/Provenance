// ----------------------------------------------------------------------------
//   ___  ___  ___  ___       ___  ____  ___  _  _
//  /__/ /__/ /  / /__  /__/ /__    /   /_   / |/ /
// /    / \  /__/ ___/ ___/ ___/   /   /__  /    /  emulator
//
// ----------------------------------------------------------------------------
// Copyright 2005 Greg Stanton
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
// ----------------------------------------------------------------------------
// Sound.cpp
// ----------------------------------------------------------------------------
#include "Sound.h"
#define SOUND_LATENCY_SCALE 4

byte sound_latency = SOUND_LATENCY_VERY_LOW;

static const WAVEFORMATEX SOUND_DEFAULT_FORMAT = {WAVE_FORMAT_PCM, 1, 44100, 44100, 1, 8, 0};
static LPDIRECTSOUND sound_dsound = NULL;
static LPDIRECTSOUNDBUFFER sound_primaryBuffer = NULL;
static LPDIRECTSOUNDBUFFER sound_buffer = NULL;
static WAVEFORMATEX sound_format = SOUND_DEFAULT_FORMAT;
static uint sound_counter = 0;
static bool sound_muted = false;

// ----------------------------------------------------------------------------
// GetSampleLength
// ----------------------------------------------------------------------------
static uint sound_GetSampleLength(uint length, uint unit, uint unitMax) {
  uint sampleLength = length / unitMax;
  uint sampleRemain = length % unitMax;
  if(sampleRemain != 0 && sampleRemain >= unit) {
    sampleLength++;
  }
  return sampleLength;
}

// ----------------------------------------------------------------------------
// Resample
// ----------------------------------------------------------------------------
static void sound_Resample(const byte* source, byte* target, int length) {
  int measurement = sound_format.nSamplesPerSec;
  int sourceIndex = 0;
  int targetIndex = 0;
  
  while(targetIndex < length) {
    if(measurement >= 31440) {
      target[targetIndex++] = source[sourceIndex];
      measurement -= 31440;
    }
    else {
      sourceIndex++;
      measurement += sound_format.nSamplesPerSec;
    }
  }
}

// ----------------------------------------------------------------------------
// RestoreBuffer
// ----------------------------------------------------------------------------
static bool sound_RestoreBuffer( ) {
  if(sound_buffer != NULL) {
    HRESULT hr = sound_buffer->Restore( );
    if(FAILED(hr)) {
      logger_LogError(IDS_SOUND1,"");
      logger_LogError("",common_Format(hr));
      return false;
    }
  }
  return true;
}

// ----------------------------------------------------------------------------
// ReleaseBuffer
// ----------------------------------------------------------------------------
static bool sound_ReleaseBuffer(LPDIRECTSOUNDBUFFER buffer) {
  if(buffer != NULL) {
    HRESULT hr = buffer->Release( );
    sound_buffer = NULL;
    if(FAILED(hr)) {
      logger_LogError(IDS_SOUND2,"");
      logger_LogError("",common_Format(hr));
      return false;
    }
  }
  return true;
}

// ----------------------------------------------------------------------------
// ReleaseSound
// ----------------------------------------------------------------------------
static bool sound_ReleaseSound( ) {
  if(sound_dsound != NULL) {
    HRESULT hr = sound_dsound->Release( );
    sound_dsound = NULL;
    if(FAILED(hr)) {
      logger_LogError(IDS_SOUND3,"");
      logger_LogError("",common_Format(hr));
      return false;
    }
  }
  return true;
}

// ----------------------------------------------------------------------------
// Initialize
// ----------------------------------------------------------------------------
bool sound_Initialize(HWND hWnd) {
  if(hWnd == NULL) {
    logger_LogError(IDS_INPUT1,"");
    return false;
  }
  
  HRESULT hr = DirectSoundCreate(NULL, &sound_dsound, NULL);
  if(FAILED(hr) || sound_dsound == NULL) {
    logger_LogError(IDS_SOUND4,"");
    logger_LogError("",common_Format(hr));
    return false;
  }
  
  hr = sound_dsound->SetCooperativeLevel(hWnd, DSSCL_PRIORITY);
  if(FAILED(hr)) {
    logger_LogError(IDS_INPUT6,"");
    logger_LogError("",common_Format(hr));
    return false;
  }
  
  DSBUFFERDESC primaryDesc;
  primaryDesc.dwReserved = 0;
  primaryDesc.dwSize = sizeof(DSBUFFERDESC);
  primaryDesc.dwFlags = DSBCAPS_PRIMARYBUFFER;
  primaryDesc.dwBufferBytes = 0;
  primaryDesc.lpwfxFormat = NULL;
  
  hr = sound_dsound->CreateSoundBuffer(&primaryDesc, &sound_primaryBuffer, NULL);
  if(FAILED(hr) || sound_primaryBuffer == NULL) {
    logger_LogError(IDS_SOUND5,"");  
    logger_LogError("",common_Format(hr));
    return false;
  }

  if(!sound_SetFormat(SOUND_DEFAULT_FORMAT)) {
    logger_LogError(IDS_SOUND6,"");
    return false;
  }

//Leonis
sound_SetSampleRate(samplerate);
  return true;
}

// ----------------------------------------------------------------------------
// SetFormat
// ----------------------------------------------------------------------------
bool sound_SetFormat(WAVEFORMATEX format) {
  if(sound_dsound == NULL) {
    logger_LogError(IDS_SOUND7,"");
    return false;
  }
  if(sound_primaryBuffer == NULL) {
    logger_LogError(IDS_SOUND8,"");
    return false;
  }
  
  HRESULT hr = sound_primaryBuffer->SetFormat(&format);
  if(FAILED(hr)) {
    logger_LogError(IDS_SOUND9,"");
    logger_LogError("",common_Format(hr));    
    return false;
  }
  
  DSBUFFERDESC secondaryDesc;
  secondaryDesc.dwReserved = 0;
  secondaryDesc.dwSize = sizeof(DSBUFFERDESC);
  secondaryDesc.dwFlags = DSBCAPS_GLOBALFOCUS;
  secondaryDesc.dwBufferBytes = format.nSamplesPerSec;
  secondaryDesc.lpwfxFormat = &format;
  
  hr = sound_dsound->CreateSoundBuffer(&secondaryDesc, &sound_buffer, NULL);
  if(FAILED(hr) || sound_buffer == NULL) {
    logger_LogError(IDS_SOUND10,"");
    logger_LogError("",common_Format(hr));
    return false;
  }    

  sound_format = format;
  return true;
}

// ----------------------------------------------------------------------------
// Store
// ----------------------------------------------------------------------------
bool sound_Store( ) {
  if(sound_dsound == NULL) {
    logger_LogError(IDS_SOUND7,"");
    return false;
  }
  if(sound_primaryBuffer == NULL) {
    logger_LogError(IDS_SOUND8,"");
    return false;
  }
  if(sound_buffer == NULL) {
    logger_LogError(IDS_SOUND11,"");
    return false;
  }
    
  byte sample[1920];
  uint length = sound_GetSampleLength(sound_format.nSamplesPerSec, prosystem_frame, prosystem_frequency);
  sound_Resample(tia_buffer, sample, length);
  
  if(cartridge_pokey) {
    byte pokeySample[1920];
    sound_Resample(pokey_buffer, pokeySample, length);
    for(int index = 0; index < length; index++) {
      sample[index] += pokeySample[index];
      sample[index] = sample[index] / 2;
    }
  }
  
  DWORD lockCount = 0;
  byte* lockStream = NULL;
  DWORD wrapCount = 0;
  byte* wrapStream = NULL;
  
  HRESULT hr = sound_buffer->Lock(sound_counter, length, (void**)&lockStream, &lockCount, (void**)&wrapStream, &wrapCount, 0);
  if(FAILED(hr) || lockStream == NULL) {
    logger_LogError(IDS_SOUND12,"");
    logger_LogError("",common_Format(hr));
    if(hr != DSERR_BUFFERLOST || !sound_RestoreBuffer( )) {
      return false;
    }
  }

  uint bufferCounter = 0;
  for(uint lockIndex = 0; lockIndex < lockCount; lockIndex++) {
    lockStream[lockIndex] = sample[bufferCounter++];
  }
  
  for(uint wrapIndex = 0; wrapIndex < wrapCount; wrapIndex++) {
    wrapStream[wrapIndex] = sample[bufferCounter++];
  }
  
  hr = sound_buffer->Unlock(lockStream, lockCount, wrapStream, wrapCount);
  if(FAILED(hr)) {
    logger_LogError(IDS_SOUND13,"");
    logger_LogError("",common_Format(hr));
    if(hr != DSERR_BUFFERLOST || !sound_RestoreBuffer( )) {
      return false;
    }
  }  
 
  sound_counter += length;
  if(sound_counter >= sound_format.nSamplesPerSec) {
    sound_counter -= sound_format.nSamplesPerSec;
  }
    
  return true;
}

// ----------------------------------------------------------------------------
// Clear
// ----------------------------------------------------------------------------
bool sound_Clear( ) {
  if(sound_dsound == NULL) {
    logger_LogError(IDS_SOUND7,"");
    return false;
  }
  if(sound_primaryBuffer == NULL) {
    logger_LogError(IDS_SOUND8,"");
    return false;
  }
  if(sound_buffer == NULL) {
    logger_LogError(IDS_SOUND11,"");
    return false;
  }

  byte* lockStream = NULL;  
  DWORD lockCount = 0;
  HRESULT hr = sound_buffer->Lock(0, sound_format.nSamplesPerSec, (void**)&lockStream, &lockCount, NULL, NULL, DSBLOCK_ENTIREBUFFER);
  if(FAILED(hr) || lockStream == NULL) {
    logger_LogError(IDS_SOUND12,"");
    logger_LogError("",common_Format(hr));
    if(hr != DSERR_BUFFERLOST || !sound_RestoreBuffer( )) {
      return false;
    }
  }

  for(uint lockIndex = 0; lockIndex < lockCount; lockIndex++) {
    lockStream[lockIndex] = 0;
  }  

  hr = sound_buffer->Unlock(lockStream, lockCount, NULL, NULL);
  if(FAILED(hr)) {
    logger_LogError(IDS_SOUND13,"");
    logger_LogError("",common_Format(hr));
    if(hr != DSERR_BUFFERLOST || !sound_RestoreBuffer( )) {
      return false;
    }
  }    
 
  return true;
}

// ----------------------------------------------------------------------------
// Play
// ----------------------------------------------------------------------------
bool sound_Play( ) {
  if(sound_dsound == NULL) {
    logger_LogError(IDS_SOUND7,"");
    return false;
  }
  if(sound_primaryBuffer == NULL) {
    logger_LogError(IDS_SOUND8,"");
    return false;
  }
  if(sound_buffer == NULL) {
    logger_LogError(IDS_SOUND11,"");
    return false;
  }

  if(!sound_muted) {
    HRESULT hr = sound_buffer->SetCurrentPosition(0);
    if(FAILED(hr)) {
      logger_LogError(IDS_SOUND14,"");
      logger_LogError("",common_Format(hr));
      return false;
    }
  
    hr = sound_buffer->Play(0, 0, DSBPLAY_LOOPING);
    if(FAILED(hr)) {
      logger_LogError(IDS_SOUND15,"");
      logger_LogError("",common_Format(hr));
      if(hr != DSERR_BUFFERLOST || !sound_RestoreBuffer( )) {
        return false;
      }    
    }
    sound_counter = (sound_format.nSamplesPerSec / prosystem_frequency) * (sound_latency * SOUND_LATENCY_SCALE);
  }
  return true;
}

// ----------------------------------------------------------------------------
// Stop
// ----------------------------------------------------------------------------
bool sound_Stop( ) {
  if(sound_dsound == NULL) {
    logger_LogError(IDS_SOUND7,"");
    return false;
  }
  if(sound_primaryBuffer == NULL) {
    logger_LogError(IDS_SOUND8,"");
    return false;
  }
  if(sound_buffer == NULL) {
    logger_LogError(IDS_SOUND11,"");
    return false;
  }
  
  HRESULT hr = sound_buffer->Stop( );
  if(FAILED(hr)) {
    logger_LogError(IDS_SOUND16,"");
    logger_LogError("",common_Format(hr));
    if(hr != DSERR_BUFFERLOST || !sound_RestoreBuffer( )) {
      return false;
    }
  }

  return true;
}

// ----------------------------------------------------------------------------
// SetSampleRate
// ----------------------------------------------------------------------------
bool sound_SetSampleRate(uint rate) {
  sound_format.nSamplesPerSec = rate;
  sound_format.nAvgBytesPerSec = rate;
  return sound_SetFormat(sound_format);
}

// ----------------------------------------------------------------------------
// GetSampleRate
// ----------------------------------------------------------------------------
uint sound_GetSampleRate( ) {
  return sound_format.nSamplesPerSec;
}

// ----------------------------------------------------------------------------
// SetMuted
// ----------------------------------------------------------------------------
bool sound_SetMuted(bool muted) {
  if(sound_muted != muted) {
    if(!muted) {
      if(!sound_Play( )) {
        return false;
      }
    }
    else {
      if(!sound_Stop( )) {
        return false;
      }
    }
    sound_muted = muted;
  }
  return true;
}

// ----------------------------------------------------------------------------
// IsMuted
// ----------------------------------------------------------------------------
bool sound_IsMuted( ) {
  return sound_muted;
}

// ----------------------------------------------------------------------------
// Release
// ----------------------------------------------------------------------------
void sound_Release( ) {
  sound_ReleaseBuffer(sound_buffer);
  sound_ReleaseBuffer(sound_primaryBuffer);
  sound_ReleaseSound( );
}