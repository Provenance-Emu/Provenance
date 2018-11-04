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

#define MAX_BUFFER_SIZE 8192

typedef struct
{
    uint nSamplesPerSec;
    word nChannels;
    word wBitsPerSample;
} SOUNDCONFIG;

static const SOUNDCONFIG soundDefaults = {48000, 1, 8};
static SOUNDCONFIG sound_format = soundDefaults;

// ----------------------------------------------------------------------------
// GetSampleLength
// ----------------------------------------------------------------------------
static uint sound_GetSampleLength(uint length, uint unit, uint unitMax)
{
    uint sampleLength = length / unitMax;
    uint sampleRemain = length % unitMax;

    if(sampleRemain != 0 && sampleRemain >= unit)
    {
        sampleLength++;
    }

    return sampleLength;
}

// ----------------------------------------------------------------------------
// Resample
// ----------------------------------------------------------------------------
static void sound_Resample(const byte *source, byte *target, int length)
{
    int measurement = sound_format.nSamplesPerSec;
    int sourceIndex = 0;
    int targetIndex = 0;
    int max = ((prosystem_frequency * prosystem_scanlines) << 1);

    while(targetIndex < length)
    {
        if(measurement >= max)
        {
            target[targetIndex++] = source[sourceIndex];
            measurement -= max;
        }
        else
        {
            sourceIndex++;
            measurement += sound_format.nSamplesPerSec;
        }
    }
}

// ----------------------------------------------------------------------------
// Store
// ----------------------------------------------------------------------------
uint sound_Store(byte *out_buffer)
{
    memset(out_buffer, 0, MAX_BUFFER_SIZE);
    uint length = 48000 / prosystem_frequency; // sound_GetSampleLength(sound_format.nSamplesPerSec, prosystem_frame, prosystem_frequency);
    sound_Resample(tia_buffer, out_buffer, length);

    // Ballblazer, Commando, various homebrew and hacks
    if(cartridge_pokey)
    {
        byte pokeySample[MAX_BUFFER_SIZE];
        memset(pokeySample, 0, MAX_BUFFER_SIZE);
        sound_Resample(pokey_buffer, pokeySample, length);

        for(uint index = 0; index < length; index++)
        {
            out_buffer[index] += pokeySample[index];
            out_buffer[index] = out_buffer[index] / 2;
        }
    }

    return length;
}

// ----------------------------------------------------------------------------
// SetSampleRate
// ----------------------------------------------------------------------------
void sound_SetSampleRate(uint rate)
{
    sound_format.nSamplesPerSec = rate;
}

// ----------------------------------------------------------------------------
// GetSampleRate
// ----------------------------------------------------------------------------
uint sound_GetSampleRate()
{
    return sound_format.nSamplesPerSec;
}
