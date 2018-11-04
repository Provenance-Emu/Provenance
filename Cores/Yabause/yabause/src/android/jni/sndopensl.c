/*  Copyright 2012 Guillaume Duhamel
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

#include <assert.h>
#include <jni.h>
#include <android/log.h>
#include "sndopensl.h"

// for native audio
#include <SLES/OpenSLES.h>
#include <SLES/OpenSLES_Android.h>

// for native asset manager
#include <sys/types.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>

  
#include "debug.h" 

static int SNDOpenSLInit(void);
static void SNDOpenSLDeInit(void);
static int SNDOpenSLReset(void);
static int SNDOpenSLChangeVideoFormat(int vertfreq);
static void SNDOpenSLUpdateAudio(u32 *leftchanbuffer, u32 *rightchanbuffer, u32 num_samples);
static u32 SNDOpenSLGetAudioSpace(void);
static void SNDOpenSLMuteAudio(void);
static void SNDOpenSLUnMuteAudio(void);
static void SNDOpenSLSetVolume(int volume);

SoundInterface_struct SNDOpenSL = {
SNDCORE_OPENSL,
"OpenSL Sound Interface",
SNDOpenSLInit,
SNDOpenSLDeInit,
SNDOpenSLReset,
SNDOpenSLChangeVideoFormat,
SNDOpenSLUpdateAudio,
SNDOpenSLGetAudioSpace,
SNDOpenSLMuteAudio,
SNDOpenSLUnMuteAudio,
SNDOpenSLSetVolume
};

extern JavaVM * yvm;


// engine interfaces
static SLObjectItf engineObject = NULL;
static SLEngineItf engineEngine;

// output mix interfaces
static SLObjectItf outputMixObject = NULL;
static SLEnvironmentalReverbItf outputMixEnvironmentalReverb = NULL;

// buffer queue player interfaces
static SLObjectItf bqPlayerObject = NULL;
static SLPlayItf bqPlayerPlay;
static SLAndroidSimpleBufferQueueItf bqPlayerBufferQueue;
static SLEffectSendItf bqPlayerEffectSend;
static SLMuteSoloItf bqPlayerMuteSolo;
static SLVolumeItf bqPlayerVolume;

// pointer and size of the next player buffer to enqueue, and number of remaining buffers
static short *nextBuffer;
static unsigned nextSize;
static int nextCount;


int mbufferSizeInBytes;
#define MAX_BUFFER_CNT  (2)
static u16 *stereodata16[MAX_BUFFER_CNT];
static int currentpos = 0;
static int soundbufsize=0;
static int soundoffset[MAX_BUFFER_CNT]={0};
static u8 soundvolume;
static u8 soundmaxvolume;

#define MAX_QUEUE (32)
static int queue_head = 0;
static int queue_tail = 0;
static int index_queue[MAX_QUEUE]={0};

static int muted;

void push_index( int index )
{
   index_queue[queue_tail] = index;
   queue_tail++;      
   if( queue_tail >= MAX_QUEUE ) queue_tail = 0;
}

int pop_index()
{
   int val = index_queue[queue_head];
   queue_head++;      
   if( queue_head >= MAX_QUEUE ) queue_head = 0;
   return val;
}

// this callback handler is called every time a buffer finishes playing
void bqPlayerCallback(SLAndroidSimpleBufferQueueItf bq, void *context)
{
    assert(bq == bqPlayerBufferQueue);
    assert(NULL == context);
    
  
   int playpos = pop_index();
   //printf("bqPlayerCallback %d,%d",playpos,soundoffset[playpos]);
   soundoffset[playpos] = 0;

}


//////////////////////////////////////////////////////////////////////////////

static int SNDOpenSLInit(void)
{
   int i;
   
    // configure audio source
    SLDataLocator_AndroidSimpleBufferQueue loc_bufq = {SL_DATALOCATOR_ANDROIDSIMPLEBUFFERQUEUE, 2};
    SLDataFormat_PCM format_pcm = {SL_DATAFORMAT_PCM, 2, SL_SAMPLINGRATE_44_1,
        SL_PCMSAMPLEFORMAT_FIXED_16, SL_PCMSAMPLEFORMAT_FIXED_16,
        (SL_SPEAKER_FRONT_LEFT | SL_SPEAKER_FRONT_RIGHT), SL_BYTEORDER_LITTLEENDIAN};
    SLDataSource audioSrc = {&loc_bufq, &format_pcm};
   
   SLresult result;
   

   // create engine
   result = slCreateEngine(&engineObject, 0, NULL, 0, NULL, NULL);
   assert(SL_RESULT_SUCCESS == result);

   // realize the engine
   result = (*engineObject)->Realize(engineObject, SL_BOOLEAN_FALSE);
   assert(SL_RESULT_SUCCESS == result);

   // get the engine interface, which is needed in order to create other objects
   result = (*engineObject)->GetInterface(engineObject, SL_IID_ENGINE, &engineEngine);
   assert(SL_RESULT_SUCCESS == result);

   // create output mix, with environmental reverb specified as a non-required interface
   const SLInterfaceID ids[1] = {SL_IID_ENVIRONMENTALREVERB};
   const SLboolean req[1] = {SL_BOOLEAN_FALSE};
 
   result = (*engineEngine)->CreateOutputMix(engineEngine, &outputMixObject, 1, ids, req);
   assert(SL_RESULT_SUCCESS == result);

   // realize the output mix
   result = (*outputMixObject)->Realize(outputMixObject, SL_BOOLEAN_FALSE);
   assert(SL_RESULT_SUCCESS == result);

    // configure audio sink
    SLDataLocator_OutputMix loc_outmix = {SL_DATALOCATOR_OUTPUTMIX, outputMixObject};
    SLDataSink audioSnk = {&loc_outmix, NULL};

    // create audio player
    const SLInterfaceID aids[3] = {SL_IID_BUFFERQUEUE, SL_IID_EFFECTSEND, /*SL_IID_MUTESOLO,*/ SL_IID_VOLUME};
    const SLboolean areq[3] = {SL_BOOLEAN_TRUE, SL_BOOLEAN_TRUE,/*SL_BOOLEAN_TRUE,*/ SL_BOOLEAN_TRUE};
    result = (*engineEngine)->CreateAudioPlayer(engineEngine, &bqPlayerObject, &audioSrc, &audioSnk,
            3, aids, areq);
    assert(SL_RESULT_SUCCESS == result);

    // realize the player
    result = (*bqPlayerObject)->Realize(bqPlayerObject, SL_BOOLEAN_FALSE);
    assert(SL_RESULT_SUCCESS == result);

    // get the play interface
    result = (*bqPlayerObject)->GetInterface(bqPlayerObject, SL_IID_PLAY, &bqPlayerPlay);
    assert(SL_RESULT_SUCCESS == result);

    // get the buffer queue interface
    result = (*bqPlayerObject)->GetInterface(bqPlayerObject, SL_IID_BUFFERQUEUE,
            &bqPlayerBufferQueue);
    assert(SL_RESULT_SUCCESS == result);

    // register callback on the buffer queue
    result = (*bqPlayerBufferQueue)->RegisterCallback(bqPlayerBufferQueue, bqPlayerCallback, NULL);
    assert(SL_RESULT_SUCCESS == result);

    // get the effect send interface
    result = (*bqPlayerObject)->GetInterface(bqPlayerObject, SL_IID_EFFECTSEND,
            &bqPlayerEffectSend);
    assert(SL_RESULT_SUCCESS == result);

#if 0   // mute/solo is not supported for sources that are known to be mono, as this is
    // get the mute/solo interface
    result = (*bqPlayerObject)->GetInterface(bqPlayerObject, SL_IID_MUTESOLO, &bqPlayerMuteSolo);
    assert(SL_RESULT_SUCCESS == result);
#endif

    // get the volume interface
    result = (*bqPlayerObject)->GetInterface(bqPlayerObject, SL_IID_VOLUME, &bqPlayerVolume);
    assert(SL_RESULT_SUCCESS == result);

    InitSoundBuff();
      
   
   // set the player's state to playing
   result = (*bqPlayerPlay)->SetPlayState(bqPlayerPlay, SL_PLAYSTATE_PLAYING);
   assert(SL_RESULT_SUCCESS == result);

   muted = 0;

   return 0;
}

int InitSoundBuff()
{
   int i;
   
   // 5msec( 2byte * 44100Hz * 0.005 )
   mbufferSizeInBytes = 2940*4; //2 * 44100 * 2 *0.016;
   soundbufsize = mbufferSizeInBytes*2;

   for( i=0; i< MAX_BUFFER_CNT; i++ )
   {
      if ((stereodata16[i] = (u16 *)malloc(soundbufsize)) == NULL)
         return -1;
      memset(stereodata16[i], 0, soundbufsize);
      soundoffset[i] = 0;   
   }
   
   soundvolume = 100;
   soundmaxvolume = 100;
   
   printf("InitSoundBuff %d,%d\n",mbufferSizeInBytes,soundbufsize);
   printf("SNDOpenSLInit %08x,%08X,%08x,%08x",stereodata16[0],(int)(stereodata16[0]) + soundbufsize, stereodata16[1],(int)(stereodata16[1]) + soundbufsize);
   return 0;
   
}

//////////////////////////////////////////////////////////////////////////////

static void SNDOpenSLDeInit(void)
{
   int i;
   JNIEnv * env;

   for( i=0; i< MAX_BUFFER_CNT; i++ )
   {
      free(stereodata16[i]);
      stereodata16[i] = NULL;
   }

}

//////////////////////////////////////////////////////////////////////////////

static int SNDOpenSLReset(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static int SNDOpenSLChangeVideoFormat(int vertfreq)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static void sdlConvert32uto16s(s32 *srcL, s32 *srcR, s16 *dst, u32 len) {
   u32 i;

   for (i = 0; i < len; i++)
   {
      // Left Channel
      *srcL = ( *srcL *soundvolume ) / soundmaxvolume;
      if (*srcL > 0x7FFF) *dst = 0x7FFF;
      else if (*srcL < -0x8000) *dst = -0x8000;
      else *dst = *srcL;
      srcL++;
      dst++;
      // Right Channel
      *srcR = ( *srcR *soundvolume ) / soundmaxvolume;
      if (*srcR > 0x7FFF) *dst = 0x7FFF;
      else if (*srcR < -0x8000) *dst = -0x8000;
      else *dst = *srcR;
      srcR++;
      dst++;
   }
   
}

static void SNDOpenSLUpdateAudio(u32 *leftchanbuffer, u32 *rightchanbuffer, u32 num_samples)
{
//   return;


   u32 copy1size=0;
   int nextpos;

   copy1size = (num_samples * sizeof(s16) * 2);
   //printf("SNDOpenSLUpdateAudio %08X,%08X,%08X",currentpos,soundoffset[currentpos],copy1size);

   sdlConvert32uto16s((s32 *)leftchanbuffer, (s32 *)rightchanbuffer, (s16 *)(((u8 *)stereodata16[currentpos])+soundoffset[currentpos] ), copy1size / sizeof(s16) / 2);

   soundoffset[currentpos] += copy1size;
   
   if (soundoffset[currentpos] >= mbufferSizeInBytes) {

      if (!muted) {
         // here we only enqueue one buffer because it is a long clip,
         // but for streaming playback we would typically enqueue at least 2 buffers to start
         SLresult result;
         push_index(currentpos);
         result = (*bqPlayerBufferQueue)->Enqueue(bqPlayerBufferQueue, stereodata16[currentpos], soundoffset[currentpos]);
         if (SL_RESULT_SUCCESS != result) {
            printf("Fail to Add queue");
               return;
         }
      }
      nextpos = currentpos+1;
      if( nextpos >= MAX_BUFFER_CNT ) { nextpos = 0; }
      currentpos = nextpos;
      
   }
   
}

//////////////////////////////////////////////////////////////////////////////

static u32 SNDOpenSLGetAudioSpace(void)
{
   
   // printf("SNDOpenSLGetAudioSpace %d,%d",soundoffset,mbufferSizeInBytes);
   
   int val = (mbufferSizeInBytes-soundoffset[currentpos]);
   if( val < 0 ) return 0;
   return val;
}

//////////////////////////////////////////////////////////////////////////////

static void SNDOpenSLMuteAudio(void)
{
   muted = 1;
}

//////////////////////////////////////////////////////////////////////////////

static void SNDOpenSLUnMuteAudio(void)
{
   muted = 0;
}

//////////////////////////////////////////////////////////////////////////////

static void SNDOpenSLSetVolume(int volume)
{
}
