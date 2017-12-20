/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2015  JustBurn

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

#ifndef MINXHW_AUDIO
#define MINXHW_AUDIO

#include "MinxTimers.h"

#include <stdio.h>
#include <stdint.h>

typedef struct {
	// Internal processing
	int32_t AudioCCnt;	// Audio cycle counter 8.24 (Needs signed)
	uint32_t AudioSCnt;	// Audio sample counter 8.24 (Needs unsigned)
	int16_t Volume;		// Volume (S16 sample)
	int16_t PWMMul;		// PWM Multiplication
} TMinxAudio;

// Export Audio state
extern TMinxAudio MinxAudio;

// Audio enabled
extern int AudioEnabled;

// Sound engine
extern int SoundEngine;

// Piezo Filter
extern int PiezoFilter;

// Require sound sync
extern int RequireSoundSync;


enum {
	MINX_AUDIO_DISABLED = 0,	// Disabled
	MINX_AUDIO_GENERATED,		// Generated (Doesn't require sync)
	MINX_AUDIO_DIRECT,		// Direct from Timer 3
	MINX_AUDIO_EMULATED,		// Emulated
	MINX_AUDIO_DIRECTPWM		// Direct from Timer 3 with PWM support
};

enum {
	MINX_AUDIO_SILENCE = 0x0000,
	MINX_AUDIO_MED_VOL = 0x2000,
	MINX_AUDIO_MAX_VOL = 0x4000,
	MINX_AUDIO_PWM_RAG = 0x1FFF	// Max + Pwm*2 must not be over 0x7FFF
};

#ifndef MINX_AUDIOFREQ
#define MINX_AUDIOFREQ	(44100)
#endif

// Aproximate value of 1 sample per cycle at 44100Hz (16M / ( 4M / 44K ))
#ifndef MINX_AUDIOINC
#define MINX_AUDIOINC	(184969)
#endif

// Conversion for the generator counter
#define MINX_AUDIOCONV	(2147483647/(MINX_AUDIOFREQ)*2)


int MinxAudio_Create(int audioenable, int fifosize);

void MinxAudio_Destroy(void);

void MinxAudio_Reset(int hardreset);

int MinxAudio_LoadState(FILE *fi, uint32_t bsize);

int MinxAudio_SaveState(FILE *fi);

void MinxAudio_ChangeEngine(int engine);

void MinxAudio_ChangeFilter(int piezo);

void MinxAudio_Sync(void);

uint8_t MinxAudio_ReadReg(uint8_t reg);

void MinxAudio_WriteReg(uint8_t reg, uint8_t val);

int MinxAudio_TotalSamples(void);

int MinxAudio_SamplesInBuffer(void);

void MinxAudio_GetEmulated(int *Sound_Frequency, int *Pulse_Width);

int16_t MinxAudio_AudioProcessDirect(void);

int16_t MinxAudio_AudioProcessEmulated(void);

int16_t MinxAudio_AudioProcessDirectPWM(void);

int16_t MinxAudio_PiezoFilter(int32_t Sample);

void MinxAudio_GetSamplesU8(uint8_t *soundout, int numsamples);

void MinxAudio_GetSamplesS16(int16_t *soundout, int numsamples);

void MinxAudio_GetSamplesU8Ch(uint8_t *soundout, int numsamples, int channels);

void MinxAudio_GetSamplesS16Ch(int16_t *soundout, int numsamples, int channels);

int MinxAudio_SyncWithAudio(void);

void MinxAudio_GenerateEmulatedU8(uint8_t *soundout, int numsamples, int channels);

void MinxAudio_GenerateEmulatedS8(int8_t *soundout, int numsamples, int channels);

void MinxAudio_GenerateEmulatedS16(int16_t *soundout, int numsamples, int channels);

#endif
