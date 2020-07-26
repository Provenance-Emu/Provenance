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

#include <jni.h>
#include <android/log.h>
#include "sndaudiotrack.h"
#include "debug.h"

static int SNDAudioTrackInit(void);
static void SNDAudioTrackDeInit(void);
static int SNDAudioTrackReset(void);
static int SNDAudioTrackChangeVideoFormat(int vertfreq);
static void SNDAudioTrackUpdateAudio(u32 *leftchanbuffer, u32 *rightchanbuffer, u32 num_samples);
static u32 SNDAudioTrackGetAudioSpace(void);
static void SNDAudioTrackMuteAudio(void);
static void SNDAudioTrackUnMuteAudio(void);
static void SNDAudioTrackSetVolume(int volume);

SoundInterface_struct SNDAudioTrack = {
SNDCORE_AUDIOTRACK,
"Audio Track Sound Interface",
SNDAudioTrackInit,
SNDAudioTrackDeInit,
SNDAudioTrackReset,
SNDAudioTrackChangeVideoFormat,
SNDAudioTrackUpdateAudio,
SNDAudioTrackGetAudioSpace,
SNDAudioTrackMuteAudio,
SNDAudioTrackUnMuteAudio,
SNDAudioTrackSetVolume
};

extern JavaVM * yvm;

jobject gtrack = NULL;

jclass cAudioTrack = NULL;

jmethodID mWrite = NULL;

int mbufferSizeInBytes;

static u16 *stereodata16;
static u8 soundvolume;
static u8 soundmaxvolume;
static u8 soundbufsize;
static int soundoffset;
static int muted;

//////////////////////////////////////////////////////////////////////////////

static int SNDAudioTrackInit(void)
{
   int sampleRateInHz = 44100;
   int channelConfig = 12; //AudioFormat.CHANNEL_OUT_STEREO
   int audioFormat = 2; //AudioFormat.ENCODING_PCM_16BIT
   JNIEnv * env;
   jobject mtrack = NULL;
   jmethodID mPlay = NULL;
   jmethodID mGetMinBufferSize = NULL;
   jmethodID mAudioTrack = NULL;

   if ((*yvm)->GetEnv(yvm, (void**) &env, JNI_VERSION_1_6) != JNI_OK)
       return -1;

   cAudioTrack = (*env)->FindClass(env, "android/media/AudioTrack");
   cAudioTrack = (jclass) (*env)->NewGlobalRef(env, cAudioTrack);

   mAudioTrack = (*env)->GetMethodID(env, cAudioTrack, "<init>", "(IIIIII)V");

   mWrite = (*env)->GetMethodID(env, cAudioTrack, "write", "([BII)I");

   mPlay = (*env)->GetMethodID(env, cAudioTrack, "play", "()V");

   mGetMinBufferSize = (*env)->GetStaticMethodID(env, cAudioTrack, "getMinBufferSize", "(III)I");

   mbufferSizeInBytes = (*env)->CallStaticIntMethod(env, cAudioTrack, mGetMinBufferSize, sampleRateInHz, channelConfig, audioFormat);

   mtrack = (*env)->NewObject(env, cAudioTrack, mAudioTrack, 3 /* STREAM_MUSIC */, sampleRateInHz, channelConfig, audioFormat, mbufferSizeInBytes, 1 /* MODE_STREAM */);

   gtrack = (*env)->NewGlobalRef(env, mtrack);

   (*env)->CallNonvirtualVoidMethod(env, gtrack, cAudioTrack, mPlay);

   if ((stereodata16 = (u16 *)malloc(2 * mbufferSizeInBytes)) == NULL)
      return -1;
   memset(stereodata16, 0, soundbufsize);

   soundvolume = 100;
   soundmaxvolume = 100;
   soundbufsize = 85;
   soundoffset = 0;
   muted = 0;

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static void SNDAudioTrackDeInit(void)
{
   JNIEnv * env;

   if ((*yvm)->GetEnv(yvm, (void**) &env, JNI_VERSION_1_6) != JNI_OK)
       return;

   free(stereodata16);
   stereodata16 = NULL;

   (*env)->DeleteGlobalRef(env, gtrack);
}

//////////////////////////////////////////////////////////////////////////////

static int SNDAudioTrackReset(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static int SNDAudioTrackChangeVideoFormat(int vertfreq)
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

static void SNDAudioTrackUpdateAudio(u32 *leftchanbuffer, u32 *rightchanbuffer, u32 num_samples)
{
   u32 copy1size=0;

   copy1size = (num_samples * sizeof(s16) * 2);

   sdlConvert32uto16s((s32 *)leftchanbuffer, (s32 *)rightchanbuffer, (s16 *)(((u8 *)stereodata16)+soundoffset), copy1size / sizeof(s16) / 2);

   soundoffset += copy1size;

   if (soundoffset > mbufferSizeInBytes) {
      if (! muted) {
         JNIEnv * env;
         jbyteArray array;

         if ((*yvm)->GetEnv(yvm, (void**) &env, JNI_VERSION_1_6) != JNI_OK)
             return;

         array = (*env)->NewByteArray(env, soundoffset);
         if(array) {
            (*env)->SetByteArrayRegion(env, array, 0, soundoffset, (u8 *) stereodata16);
         }

         (*env)->CallNonvirtualIntMethod(env, gtrack, cAudioTrack, mWrite, array, 0, soundoffset);
      }

      soundoffset = 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

static u32 SNDAudioTrackGetAudioSpace(void)
{
   static int i = 0;
   i++;
   if (i == 55) {
      i = 0;
      return mbufferSizeInBytes;
   } else {
      return 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void SNDAudioTrackMuteAudio(void)
{
   muted = 1;
}

//////////////////////////////////////////////////////////////////////////////

static void SNDAudioTrackUnMuteAudio(void)
{
   muted = 0;
}

//////////////////////////////////////////////////////////////////////////////

static void SNDAudioTrackSetVolume(int volume)
{
   soundvolume = volume;
}
