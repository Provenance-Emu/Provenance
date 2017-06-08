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

#include "PokeMini.h"

TMinxAudio MinxAudio;
int AudioEnabled = 0;
int SoundEngine = MINX_AUDIO_DISABLED;
int PiezoFilter = 0;
int RequireSoundSync = 0;
int16_t *MinxAudio_FIFO = NULL;
volatile int MinxAudio_ReadPtr = 0;
volatile int MinxAudio_WritePtr = 0;
int MinxAudio_FIFOSize = 0;
int MinxAudio_FIFOMask = 0;
int MinxAudio_FIFOThreshold = 0;
int16_t (*MinxAudio_AudioProcess)(void) = NULL;

// Timers counting frequency table
const uint32_t MinxAudio_CountFreq[32] = {
	// Osci1 disabled
	1, 0, 0, 0, 0, 0, 0, 0,
	// Osci1 Enabled
	(4000000/2), (4000000/8), (4000000/32), (4000000/64),
	(4000000/128), (4000000/256), (4000000/1024), (4000000/4096),
	// Osci2 disabled
	0, 0, 0, 0, 0, 0, 0, 0,
	// Osci2 Enabled
	(32768/1), (32768/2), (32768/4), (32768/8),
	(32768/16), (32768/32), (32768/64), (32768/128)
};

//
// FIFO I/O
//

static inline int MinxAudio_iSamplesInBuffer(void)
{
	if (MinxAudio_WritePtr > MinxAudio_ReadPtr) return MinxAudio_WritePtr - MinxAudio_ReadPtr;
	else return (MinxAudio_FIFOSize - MinxAudio_ReadPtr) + MinxAudio_WritePtr;
}

int MinxAudio_TotalSamples(void)
{
	return MinxAudio_FIFOSize;
}

int MinxAudio_SamplesInBuffer(void)
{
	return MinxAudio_iSamplesInBuffer();
}

static inline void MinxAudio_FIFOWrite(int16_t data)
{
	if (MinxAudio_iSamplesInBuffer() < MinxAudio_FIFOSize) {
		MinxAudio_FIFO[MinxAudio_WritePtr] = data;
		MinxAudio_WritePtr = (MinxAudio_WritePtr + 1) & MinxAudio_FIFOMask;
	}
}

static inline int16_t MinxAudio_FIFORead(void)
{
	int16_t data = 0;
	if (MinxAudio_iSamplesInBuffer() > 0) {
		data = MinxAudio_FIFO[MinxAudio_ReadPtr];
		MinxAudio_ReadPtr = (MinxAudio_ReadPtr + 1) & MinxAudio_FIFOMask;
	}
	return data;
}

//
// Functions
//

int MinxAudio_Create(int audioenable, int fifosize)
{
	// Init variables
	AudioEnabled = audioenable;
	SoundEngine = MINX_AUDIO_DISABLED;
	RequireSoundSync = 0;

	// Reset
	MinxAudio_Reset(1);

	// Init FIFO if audio enabled
	MinxAudio_ReadPtr = 0;
	MinxAudio_WritePtr = 0;
	if (fifosize) {
		MinxAudio_FIFOMask = GetMultiple2Mask(fifosize);
		MinxAudio_FIFOSize = MinxAudio_FIFOMask + 1;
		MinxAudio_FIFOThreshold = (fifosize * 3) >> 2;	// ... at 3 / 4
	} else {
		MinxAudio_FIFOMask = 0;
		MinxAudio_FIFOSize = 0;
		MinxAudio_FIFOThreshold = 0;
	}
	if ((audioenable) && (fifosize)) {
		MinxAudio_FIFO = (int16_t *)malloc(MinxAudio_FIFOSize*2);
		if (!MinxAudio_FIFO) return 0;
		memset(MinxAudio_FIFO, 0, MinxAudio_FIFOSize*2);
	}

	return 1;
}

void MinxAudio_Destroy(void)
{
	if (MinxAudio_FIFO) {
		free(MinxAudio_FIFO);
		MinxAudio_FIFO = NULL;
	}
}

void MinxAudio_Reset(int hardreset)
{
	// Initialize State
	memset((void *)&MinxAudio, 0, sizeof(TMinxAudio));
}

int MinxAudio_LoadState(FILE *fi, uint32_t bsize)
{
	POKELOADSS_START(32);
	POKELOADSS_32(MinxAudio.AudioCCnt);
	POKELOADSS_32(MinxAudio.AudioSCnt);
	POKELOADSS_16(MinxAudio.Volume);
	POKELOADSS_16(MinxAudio.PWMMul);
	POKELOADSS_X(20);
	POKELOADSS_END(32);
}

int MinxAudio_SaveState(FILE *fi)
{
	POKESAVESS_START(32);
	POKESAVESS_32(MinxAudio.AudioCCnt);
	POKESAVESS_32(MinxAudio.AudioSCnt);
	POKESAVESS_16(MinxAudio.Volume);
	POKESAVESS_16(MinxAudio.PWMMul);
	POKESAVESS_X(20);
	POKESAVESS_END(32);
}

void MinxAudio_ChangeEngine(int engine)
{
	if (PokeMini_Flags & POKEMINI_GENSOUND) {
		engine = engine ? 1 : 0;
	}
	SoundEngine = engine;
	switch (engine) {
		case MINX_AUDIO_GENERATED:
			RequireSoundSync = 0;
			MinxAudio_AudioProcess = NULL;
			break;
		case MINX_AUDIO_DIRECT:
			RequireSoundSync = 1;
			MinxAudio_AudioProcess = MinxAudio_AudioProcessDirect;
			break;
		case MINX_AUDIO_EMULATED:
			RequireSoundSync = 1;
			MinxAudio_AudioProcess = MinxAudio_AudioProcessEmulated;
			break;
		case MINX_AUDIO_DIRECTPWM:
			RequireSoundSync = 1;
			MinxAudio_AudioProcess = MinxAudio_AudioProcessDirectPWM;
			break;
		default:
			RequireSoundSync = 0;
			MinxAudio_AudioProcess = NULL;
			break;
	}
}

void MinxAudio_ChangeFilter(int piezo)
{
	PiezoFilter = piezo;
}

void MinxAudio_Sync(void)
{
	// Process single audio sample
	MinxAudio.AudioCCnt += MINX_AUDIOINC * PokeHWCycles;
	if (MinxAudio.AudioCCnt >= 0x01000000) {
		MinxAudio.AudioCCnt -= 0x01000000;
		if (MinxAudio_AudioProcess) {
			if (PiezoFilter) {
				MinxAudio_FIFOWrite(MinxAudio_PiezoFilter(MinxAudio_AudioProcess()));
			} else {
				MinxAudio_FIFOWrite(MinxAudio_AudioProcess());
			}
		}
	}
}

uint8_t MinxAudio_ReadReg(uint8_t reg)
{
	// 0x70 to 0x71
	switch(reg) {
		case 0x70: // Unknown Audio Control
			return PMR_AUD_CTRL & 0x07;
		case 0x71: // Audio Volume Control
			return PMR_AUD_VOL & 0x07;
		default:
			return 0;
	}
}

void MinxAudio_WriteReg(uint8_t reg, uint8_t val)
{
	// 0x70 to 0x71
	switch(reg) {
		case 0x70: // Unknown Audio Control
			PMR_AUD_CTRL = val & 0x07;
			break;
		case 0x71: // Audio Volume Control
			PMR_AUD_VOL = val & 0x07;
			break;
	}

	// Calculate volume
	if (PMR_AUD_CTRL & 0x03) {
		// Mute audio
		MinxAudio.Volume = 0;
	} else {
		switch (PMR_AUD_VOL & 3) {
			case 0:
				// 0% Sound
				MinxAudio.Volume = MINX_AUDIO_SILENCE;
				MinxAudio.PWMMul = 0;
				break;
			case 1:
			case 2:
				// 50% Sound
				MinxAudio.Volume = MINX_AUDIO_MED_VOL;
				MinxAudio.PWMMul = 1;
				break;
			case 3:
				// 100% Sound
				MinxAudio.Volume = MINX_AUDIO_MAX_VOL;
				MinxAudio.PWMMul = 2;
				break;
		}
	}
}

// Get emulated frequency and pulsewidth
// Sound_Frequency is in Hz
// Pulse_Width is between 0 to 4095 (0% to ~99.99%)
void MinxAudio_GetEmulated(int *Sound_Frequency, int *Pulse_Width)
{
	int Timer3_Frequency;
	int Preset_Value, Sound_Pivot;

	// Calculate timer 3 frequency
	Timer3_Frequency = MinxAudio_CountFreq[(PMR_TMR3_SCALE & 0xF) | ((PMR_TMR3_OSC & 0x01) << 4)];
	if (!(PMR_TMR3_CTRL_L & 0x04)) Timer3_Frequency = 0;
	if (PMR_TMR3_OSC & 0x01) {
		// Osci2
		if (!MinxTimers.TmrXEna2) Timer3_Frequency = 0;
	} else {
		// Osci1
		if (!MinxTimers.TmrXEna1) Timer3_Frequency = 0;
	}

	if (Timer3_Frequency) {
		// Calculate preset value
		Preset_Value = (MinxTimers.Tmr3PreA >> 24) + ((MinxTimers.Tmr3PreB >> 24) << 8);

		// Calculate sound frequency
		*Sound_Frequency = Timer3_Frequency / (Preset_Value + 1);

		// ... and pulse width
		if (Preset_Value) {
			Sound_Pivot = (int)MinxTimers.Timer3Piv;
			*Pulse_Width = 4095 - (Sound_Pivot * 4096 / Preset_Value);
			if (*Pulse_Width < 0) *Pulse_Width = 0;
		} else *Pulse_Width = 0;
	} else {
		*Sound_Frequency = 0;
		*Pulse_Width = 0;
	}
}

int16_t MinxAudio_AudioProcessDirect(void)
{
	uint16_t TmrCnt;
	TmrCnt = (MinxTimers.Tmr3CntA >> 24) | ((MinxTimers.Tmr3CntB >> 24) << 8);

	if (TmrCnt <= MinxTimers.Timer3Piv) {
		return MinxAudio.Volume;
	}
	return MINX_AUDIO_SILENCE;
}

int16_t MinxAudio_AudioProcessEmulated(void)
{
	int Sound_Frequency, Pulse_Width;
	MinxAudio_GetEmulated(&Sound_Frequency, &Pulse_Width);
	if (Sound_Frequency < 50) {
		// Silence
		return MINX_AUDIO_SILENCE;
	} else if (Sound_Frequency < 20000) {
		// Normal
		MinxAudio.AudioSCnt -= Sound_Frequency * MINX_AUDIOCONV;
		if ((MinxAudio.AudioSCnt & 0xFFF00000) >= (Pulse_Width << 20)) {
			return MinxAudio.Volume;
		}
		return MINX_AUDIO_SILENCE;
	}
	// PWM
	if (Pulse_Width > 4095) Pulse_Width = 4095;
	return MINX_AUDIO_SILENCE + (Pulse_Width << 2) * MinxAudio.PWMMul;
}

int16_t MinxAudio_AudioProcessDirectPWM(void)
{
	uint16_t TmrCnt, TmrPre;
	uint32_t Pwm;
	TmrCnt = (MinxTimers.Tmr3CntA >> 24) | ((MinxTimers.Tmr3CntB >> 24) << 8);
	TmrPre = (MinxTimers.Tmr3PreA >> 24) | ((MinxTimers.Tmr3PreB >> 24) << 8);

	// Affect sound based of PWM
	if (TmrPre) Pwm = MinxTimers.Timer3Piv * MINX_AUDIO_PWM_RAG / TmrPre; else Pwm = 0;
	if (Pwm > MINX_AUDIO_PWM_RAG) Pwm = MINX_AUDIO_PWM_RAG-1;	// Avoid clipping
	if (TmrPre < 128) TmrCnt = 0;					// Avoid high hizz

	// Output
	if (TmrCnt <= MinxTimers.Timer3Piv) {
		return MinxAudio.Volume + Pwm * MinxAudio.PWMMul;
	}
	return MINX_AUDIO_SILENCE + Pwm * MinxAudio.PWMMul;
}

int16_t MinxAudio_PiezoFilter(int32_t Sample)
{
	int32_t HP_pCoeff = 40960;
	int32_t LP_pCoeff = 4096;
	int32_t LP_nCoeff = (65535 - LP_pCoeff);
	static int32_t HPSamples[4], LPSamples[4];
	int32_t TmpSamples[4];

	// High pass to simulate a piezo crystal speaker
	TmpSamples[0] = Sample;
	TmpSamples[1] = (HP_pCoeff * (TmpSamples[0] + HPSamples[1] - HPSamples[0])) >> 16;
	TmpSamples[2] = (HP_pCoeff * (TmpSamples[1] + HPSamples[2] - HPSamples[1])) >> 16;
	TmpSamples[3] = (HP_pCoeff * (TmpSamples[2] + HPSamples[3] - HPSamples[2])) >> 16;
	memcpy(HPSamples, TmpSamples, sizeof(HPSamples));

	// Amplify by 4
	Sample = TmpSamples[3] << 2;
	if (Sample < -32768) Sample = -32768;
	if (Sample > 32767) Sample = 32767;

	// Low pass to kill the spikes in sound
	LPSamples[0] = Sample;
	LPSamples[1] = (LPSamples[1] * LP_pCoeff + LPSamples[0] * LP_nCoeff) >> 16;
	LPSamples[2] = (LPSamples[2] * LP_pCoeff + LPSamples[1] * LP_nCoeff) >> 16;
	LPSamples[3] = (LPSamples[3] * LP_pCoeff + LPSamples[2] * LP_nCoeff) >> 16;

	// Amplify by 2, clamp and output
	Sample = LPSamples[3] << 1;
	if (Sample < -32768) Sample = -32768;
	if (Sample > 32767) Sample = 32767;

	return Sample;
}

void MinxAudio_GetSamplesU8(uint8_t *soundout, int numsamples)
{
	if (SoundEngine == MINX_AUDIO_GENERATED) {
		MinxAudio_GenerateEmulatedU8(soundout, numsamples, 1);
		return;
	}
	if (AudioEnabled && SoundEngine) {
		while (numsamples--) {
			*soundout++ = 0x80 + (MinxAudio_FIFORead() >> 8);
		}
	} else {
		while (numsamples--) *soundout++ = 0x80;
	}
}

void MinxAudio_GetSamplesS16(int16_t *soundout, int numsamples)
{
	if (SoundEngine == MINX_AUDIO_GENERATED) {
		MinxAudio_GenerateEmulatedS16(soundout, numsamples, 1);
		return;
	}
	if (AudioEnabled && SoundEngine) {
		while (numsamples--) {
			*soundout++ = MinxAudio_FIFORead();
		}
	} else {
		while (numsamples--) *soundout++ = 0x0000;
	}
}

void MinxAudio_GetSamplesU8Ch(uint8_t *soundout, int numsamples, int channels)
{
	int j;
	if (SoundEngine == MINX_AUDIO_GENERATED) {
		MinxAudio_GenerateEmulatedU8(soundout, numsamples, channels);
		return;
	}
	if (AudioEnabled && SoundEngine) {
		while (numsamples--) {
			uint8_t sample = 0x80 + (MinxAudio_FIFORead() >> 8);
			for (j=0; j<channels; j++) *soundout++ = sample;
		}
	} else {
		while (numsamples--) for (j=0; j<channels; j++) *soundout++ = 0x80;
	}
}

void MinxAudio_GetSamplesS16Ch(int16_t *soundout, int numsamples, int channels)
{
	int j;
	if (SoundEngine == MINX_AUDIO_GENERATED) {
		MinxAudio_GenerateEmulatedS16(soundout, numsamples, channels);
		return;
	}
	if (AudioEnabled && SoundEngine) {
		while (numsamples--) {
			int16_t sample = MinxAudio_FIFORead();
			for (j=0; j<channels; j++) *soundout++ = sample;
		}
	} else {
		while (numsamples--) for (j=0; j<channels; j++) *soundout++ = 0x0000;
	}
}

int MinxAudio_SyncWithAudio(void)
{
	if (!RequireSoundSync) return 0;
	return MinxAudio_iSamplesInBuffer() >= MinxAudio_FIFOThreshold;
}

// This doesn't require audio to be created:

void MinxAudio_GenerateEmulatedU8(uint8_t *soundout, int numsamples, int channels)
{
	int i, j, Sound_Frequency, Pulse_Width;
	if (numsamples <= 0) return;
	MinxAudio_GetEmulated(&Sound_Frequency, &Pulse_Width);
	for (i=0; i<numsamples; i++) {
		if ((Sound_Frequency >= 50) && (Sound_Frequency < 20000)) {
			MinxAudio.AudioSCnt += Sound_Frequency * MINX_AUDIOCONV;
			if ((MinxAudio.AudioSCnt & 0xFFF00000) >= (Pulse_Width << 20)) {
				if (PiezoFilter) {
					for (j=0; j<channels; j++) *soundout++ = 0x80 + (MinxAudio_PiezoFilter(MinxAudio.Volume) >> 8);
				} else {
					for (j=0; j<channels; j++) *soundout++ = 0x80 + (MinxAudio.Volume >> 8);
				}
			} else {
				if (PiezoFilter) {
					for (j=0; j<channels; j++) *soundout++ = 0x80 + (MinxAudio_PiezoFilter(MINX_AUDIO_SILENCE) >> 8);
				} else {
					for (j=0; j<channels; j++) *soundout++ = 0x80;
				}
			}
		} else {
			if (PiezoFilter) {
				for (j=0; j<channels; j++) *soundout++ = 0x80 + (MinxAudio_PiezoFilter(MINX_AUDIO_SILENCE) >> 8);
			} else {
				for (j=0; j<channels; j++) *soundout++ = 0x80;
			}
		}
	}
}

void MinxAudio_GenerateEmulatedS8(int8_t *soundout, int numsamples, int channels)
{
	int i, j, Sound_Frequency, Pulse_Width;
	if (numsamples <= 0) return;
	MinxAudio_GetEmulated(&Sound_Frequency, &Pulse_Width);
	for (i=0; i<numsamples; i++) {
		if ((Sound_Frequency >= 50) && (Sound_Frequency < 20000)) {
			MinxAudio.AudioSCnt += Sound_Frequency * MINX_AUDIOCONV;
			if ((MinxAudio.AudioSCnt & 0xFFF00000) >= (Pulse_Width << 20)) {
				if (PiezoFilter) {
					for (j=0; j<channels; j++) *soundout++ = (MinxAudio_PiezoFilter(MinxAudio.Volume) >> 8);
				} else {
					for (j=0; j<channels; j++) *soundout++ = (MinxAudio.Volume >> 8);
				}
			} else {
				if (PiezoFilter) {
					for (j=0; j<channels; j++) *soundout++ = (MinxAudio_PiezoFilter(MINX_AUDIO_SILENCE) >> 8);
				} else {
					for (j=0; j<channels; j++) *soundout++ = 0;
				}
			}
		} else {
			if (PiezoFilter) {
				for (j=0; j<channels; j++) *soundout++ = (MinxAudio_PiezoFilter(MINX_AUDIO_SILENCE) >> 8);
			} else {
				for (j=0; j<channels; j++) *soundout++ = 0;
			}
		}
	}
}

void MinxAudio_GenerateEmulatedS16(int16_t *soundout, int numsamples, int channels)
{
	int i, j, Sound_Frequency, Pulse_Width;
	if (numsamples <= 0) return;
	MinxAudio_GetEmulated(&Sound_Frequency, &Pulse_Width);
	for (i=0; i<numsamples; i++) {
		if ((Sound_Frequency >= 50) && (Sound_Frequency < 20000)) {
			MinxAudio.AudioSCnt += Sound_Frequency * MINX_AUDIOCONV;
			if ((MinxAudio.AudioSCnt & 0xFFF00000) >= (Pulse_Width << 20)) {
				if (PiezoFilter) {
					for (j=0; j<channels; j++) *soundout++ = MinxAudio_PiezoFilter(MinxAudio.Volume);
				} else {
					for (j=0; j<channels; j++) *soundout++ = MinxAudio.Volume;
				}
			} else {
				if (PiezoFilter) {
					for (j=0; j<channels; j++) *soundout++ = MinxAudio_PiezoFilter(MINX_AUDIO_SILENCE);
				} else {
					for (j=0; j<channels; j++) *soundout++ = 0;
				}
			}
		} else {
			if (PiezoFilter) {
				for (j=0; j<channels; j++) *soundout++ = MinxAudio_PiezoFilter(MINX_AUDIO_SILENCE);
			} else {
				for (j=0; j<channels; j++) *soundout++ = 0;
			}
		}
	}
}
