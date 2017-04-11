/*  Copyright 2004 Stephane Dallongeville
    Copyright 2004-2007 Theo Berkau
    Copyright 2006 Guillaume Duhamel

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

#include "scsp.h"

//////////////////////////////////////////////////////////////////////////////
// Wave File Output Sound Interface
//////////////////////////////////////////////////////////////////////////////

static int SNDWavInit(void);
static void SNDWavDeInit(void);
static int SNDWavReset(void);
static int SNDWavChangeVideoFormat(int vertfreq);
static void SNDWavUpdateAudio(u32 *leftchanbuffer, u32 *rightchanbuffer, u32 num_samples);
static u32 SNDWavGetAudioSpace(void);
static void SNDWavMuteAudio(void);
static void SNDWavUnMuteAudio(void);
static void SNDWavSetVolume(int volume);

SoundInterface_struct SNDWave = {
SNDCORE_WAV,
"Wave File Ouput Interface",
SNDWavInit,
SNDWavDeInit,
SNDWavReset,
SNDWavChangeVideoFormat,
SNDWavUpdateAudio,
SNDWavGetAudioSpace,
SNDWavMuteAudio,
SNDWavUnMuteAudio,
SNDWavSetVolume
};

char *wavefilename=NULL;
static FILE *wavefp;

typedef struct {
   char id[4];
   u32 size;
} chunk_struct;

typedef struct {
   chunk_struct riff;
   char rifftype[4];
} waveheader_struct;

typedef struct {
   chunk_struct chunk;
   u16 compress;
   u16 numchan;
   u32 rate;
   u32 bytespersec;
   u16 blockalign;
   u16 bitspersample;
} fmt_struct;

//////////////////////////////////////////////////////////////////////////////

static int SNDWavInit(void)
{
   waveheader_struct waveheader;
   fmt_struct fmt;
   chunk_struct data;
   IOCheck_struct check;

   if (wavefilename)
   {

      if ((wavefp = fopen(wavefilename, "wb")) == NULL)
         return -1;
   }
   else
   {
      if ((wavefp = fopen("scsp.wav", "wb")) == NULL)
         return -1;
   }

   // Do wave header
   memcpy(waveheader.riff.id, "RIFF", 4);
   waveheader.riff.size = 0; // we'll fix this after the file is closed
   memcpy(waveheader.rifftype, "WAVE", 4);
   ywrite(&check, (void *)&waveheader, 1, sizeof(waveheader_struct), wavefp);

   // fmt chunk
   memcpy(fmt.chunk.id, "fmt ", 4);
   fmt.chunk.size = 16; // we'll fix this at the end
   fmt.compress = 1; // PCM
   fmt.numchan = 2; // Stereo
   fmt.rate = 44100;
   fmt.bitspersample = 16;
   fmt.blockalign = fmt.bitspersample / 8 * fmt.numchan;
   fmt.bytespersec = fmt.rate * fmt.blockalign;
   ywrite(&check, (void *)&fmt, 1, sizeof(fmt_struct), wavefp);

   // data chunk
   memcpy(data.id, "data", 4);
   data.size = 0; // we'll fix this at the end
   ywrite(&check, (void *)&data, 1, sizeof(chunk_struct), wavefp);

   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static void SNDWavDeInit(void)
{
   if (wavefp)
   {
      long length = ftell(wavefp);
      IOCheck_struct check;

      // Let's fix the riff chunk size and the data chunk size
      fseek(wavefp, sizeof(waveheader_struct)-0x8, SEEK_SET);
      length -= 0x4;
      ywrite(&check, (void *)&length, 1, 4, wavefp);

      fseek(wavefp, sizeof(waveheader_struct)+sizeof(fmt_struct)+0x4, SEEK_SET);
      length -= sizeof(waveheader_struct)+sizeof(fmt_struct);
      ywrite(&check, (void *)&length, 1, 4, wavefp);
      fclose(wavefp);
   }
}

//////////////////////////////////////////////////////////////////////////////

static int SNDWavReset(void)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static int SNDWavChangeVideoFormat(UNUSED int vertfreq)
{
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

static void SNDWavUpdateAudio(u32 *leftchanbuffer, u32 *rightchanbuffer, u32 num_samples)
{
   s16 stereodata16[44100 / 50];
   ScspConvert32uto16s((s32 *)leftchanbuffer, (s32 *)rightchanbuffer, (s16 *)stereodata16, num_samples);
   fwrite((void *)stereodata16, sizeof(s16) * 2, num_samples, wavefp);
}

//////////////////////////////////////////////////////////////////////////////

static u32 SNDWavGetAudioSpace(void)
{
   /* A "hack" to get sound core working enough
    * so videos are not "freezing". Values have been
    * found by experiments... I don't have a clue why
    * they are working ^^;
    */
   static int i = 0;
   i++;
   if (i == 55) {
      i = 0;
      return 85;
   } else {
      return 0;
   }
}

//////////////////////////////////////////////////////////////////////////////

static void SNDWavMuteAudio(void)
{
}

//////////////////////////////////////////////////////////////////////////////

static void SNDWavUnMuteAudio(void)
{
}

//////////////////////////////////////////////////////////////////////////////

static void SNDWavSetVolume(UNUSED int volume)
{
}

//////////////////////////////////////////////////////////////////////////////
