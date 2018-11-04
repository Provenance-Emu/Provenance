/*  Copyright 2005-2010 Lawrence Sebald
    Copyright 2005-2006 Theo Berkau
 
    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

/* This file is adapted from CrabEmu's sound.c for Mac OS X as well as the
   sndsdl.c file in Yabause. */

#include <AudioUnit/AudioUnit.h>
#include <IOKit/audio/IOAudioTypes.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#include "scsp.h"
#include "sndmac.h"

#define BUFFER_LEN 65536

/* Workarounds for APIs changed in Mac OS X 10.6. */
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6
typedef AudioComponent Component;
typedef AudioComponentDescription ComponentDescription;

#define FindNextComponent AudioComponentFindNext
#define OpenAComponent AudioComponentInstanceNew
#define CloseComponent AudioComponentInstanceDispose
#endif

static int SNDMacInit(void);
static void SNDMacDeInit(void);
static int SNDMacReset(void);
static int SNDMacChangeVideoFormat(int vfreq);
static void SNDMacUpdateAudio(u32 *left, u32 *right, u32 cnt);
static u32 SNDMacGetAudioSpace(void);
static void SNDMacMuteAudio(void);
static void SNDMacUnMuteAudio(void);
static void SNDMacSetVolume(int volume);

SoundInterface_struct SNDMac = {
    SNDCORE_MAC,
    "Mac OS X Core Audio Sound Interface",
    &SNDMacInit,
    &SNDMacDeInit,
    &SNDMacReset,
    &SNDMacChangeVideoFormat,
    &SNDMacUpdateAudio,
    &SNDMacGetAudioSpace,
    &SNDMacMuteAudio,
    &SNDMacUnMuteAudio,
    &SNDMacSetVolume
};

static AudioUnit outputAU;
static unsigned char buffer[BUFFER_LEN];
static int muted = 1;
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static UInt32 read_pos = 0, write_pos = 0;
static int soundvolume = 100;

static OSStatus SNDMacMixAudio(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumFrames,
                               AudioBufferList *ioData) {
    UInt32 len = ioData->mBuffers[0].mDataByteSize;
    void *ptr = ioData->mBuffers[0].mData;

    pthread_mutex_lock(&mutex);

    if(muted || (read_pos + len > write_pos && write_pos > read_pos)) {
        memset(ptr, 0, len);
    }
    else {
        memcpy(ptr, buffer + read_pos, len);

        read_pos += len;
        read_pos &= (BUFFER_LEN - 1);
    }

    pthread_mutex_unlock(&mutex);

    return noErr;
}

int SNDMacInit(void) {
    OSStatus error = noErr;
    ComponentDescription desc;
    AudioStreamBasicDescription basic_desc;
    Component comp;
    AURenderCallbackStruct callback;
    UInt32 bufsz;
    int rv = 0;

    /* Clear the sound to silence. */
    memset(buffer, 0, BUFFER_LEN);

    /* Find the default audio output unit */
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_DefaultOutput;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;

    comp = FindNextComponent(NULL, &desc);

    if(comp == NULL) {
        rv = -1;
        goto err1;
    }

    /* We got the component, make sure we can actually open it up. */
    error = OpenAComponent(comp, &outputAU);

    if(error != noErr) {
        rv = -2;
        goto err1;
    }

    /* Set up the AudioStreamBasicDescription - 32-bit Stereo PCM @ 44100Hz */
    basic_desc.mFormatID = kAudioFormatLinearPCM;
    basic_desc.mFormatFlags = kLinearPCMFormatFlagIsPacked | 
        kLinearPCMFormatFlagIsSignedInteger;
    basic_desc.mChannelsPerFrame = 2;
    basic_desc.mSampleRate = 44100;
    basic_desc.mBitsPerChannel = 16;
    basic_desc.mFramesPerPacket = 1;
    basic_desc.mBytesPerFrame = 4;
    basic_desc.mBytesPerPacket = 4;

    /* Set the stream format that we set up above */
    error = AudioUnitSetProperty(outputAU, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Input, 0, &basic_desc,
                                 sizeof(basic_desc));

    if(error != noErr) {
        rv = -3;
        goto err2;
    }

    /* Set the callback for getting sound data. */
    callback.inputProc = &SNDMacMixAudio;
    callback.inputProcRefCon = NULL;

    error = AudioUnitSetProperty(outputAU, kAudioUnitProperty_SetRenderCallback,
                                 kAudioUnitScope_Input, 0, &callback,
                                 sizeof(callback));

    if(error != noErr) {
        rv = -4;
        goto err2;
    }

    bufsz = 2048;
    error = AudioUnitSetProperty(outputAU,
                                 kAudioUnitProperty_MaximumFramesPerSlice,
                                 kAudioUnitScope_Global, 0, &bufsz,
                                 sizeof(UInt32));

    if(error != noErr) {
        rv = -7;
        goto err3;
    }

    /* Initialize the Audio Unit for our use now that its set up. */
    error = AudioUnitInitialize(outputAU);

    if(error != noErr) {
        rv = -8;
        goto err3;
    }

    /* We're ready to output now */
    error = AudioOutputUnitStart(outputAU);

    if(error != noErr) {
        rv = -9;
        goto err4;
    }

    muted = 0;
    soundvolume = 100;

    return 0;

    /* Error conditions. Errors cause cascading deinitialization, so hence this
       chain of labels. */
err4:
    AudioUnitUninitialize(outputAU);

err3:
    callback.inputProc = NULL;
    callback.inputProcRefCon = NULL;

    AudioUnitSetProperty(outputAU, kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input, 0, &callback,
                         sizeof(callback));

err2:
    CloseComponent(outputAU);

err1:
    return rv;
}

static void SNDMacDeInit(void) {
    OSStatus error;
    AURenderCallbackStruct callback;

    /* Stop the Audio Unit from playing any further */
    error = AudioOutputUnitStop(outputAU);

    if(error != noErr)
        return;

    /* Clear the callback */
    callback.inputProc = NULL;
    callback.inputProcRefCon = NULL;

    error = AudioUnitSetProperty(outputAU, kAudioUnitProperty_SetRenderCallback,
                                 kAudioUnitScope_Input, 0, &callback,
                                 sizeof(callback));

    if(error != noErr)
        return;

    /* Uninitialize the Audio Unit, now that we're done with it */
    error = AudioUnitUninitialize(outputAU);

    if(error != noErr)
        return;

    /* Close it, we're done */
    CloseComponent(outputAU);
}

static int SNDMacReset(void) {
    /* NOP */
    return 0;
}

static int SNDMacChangeVideoFormat(int vfreq) {
    /* NOP */
    return 0;
}

static void macConvert32uto16s(s32 *srcL, s32 *srcR, s16 *dst, u32 len) {
    u32 i;
    
    for(i = 0; i < len; i++) {
        // Left Channel
        *srcL = (*srcL * soundvolume) / 100;
        if (*srcL > 0x7FFF) *dst = 0x7FFF;
        else if (*srcL < -0x8000) *dst = -0x8000;
        else *dst = *srcL;
        srcL++;
        dst++;
        // Right Channel
        *srcR = (*srcR * soundvolume) / 100;
        if (*srcR > 0x7FFF) *dst = 0x7FFF;
        else if (*srcR < -0x8000) *dst = -0x8000;
        else *dst = *srcR;
        srcR++;
        dst++;
    } 
}

static void SNDMacUpdateAudio(u32 *left, u32 *right, u32 cnt) {
    u32 copy1size=0, copy2size=0;

    pthread_mutex_lock(&mutex);

    if((BUFFER_LEN - write_pos) < (cnt << 2)) {
        copy1size = (BUFFER_LEN - write_pos);
        copy2size = (cnt << 2) - copy1size;
    }
    else {
        copy1size = (cnt << 2);
        copy2size = 0;
    }

    macConvert32uto16s((s32 *)left, (s32 *)right,
                       (s16 *)(((u8 *)buffer) + write_pos),
                       copy1size >> 2);

    if(copy2size) {
        macConvert32uto16s((s32 *)left + (copy1size >> 2),
                           (s32 *)right + (copy1size >> 2),
                           (s16 *)buffer, copy2size >> 2);
    }

    write_pos += copy1size + copy2size;   
    write_pos %= (BUFFER_LEN);

    pthread_mutex_unlock(&mutex);
}

static u32 SNDMacGetAudioSpace(void) {
    u32 fs = 0;

    if(write_pos > read_pos) {
        fs = BUFFER_LEN - write_pos + read_pos;
    }
    else {
        fs = read_pos - write_pos;
    }
    
    return (fs >> 2);
}

static void SNDMacMuteAudio(void) {
    muted = 1;
}

static void SNDMacUnMuteAudio(void) {
    muted = 0;
}

static void SNDMacSetVolume(int volume) {
    soundvolume = volume;
}
