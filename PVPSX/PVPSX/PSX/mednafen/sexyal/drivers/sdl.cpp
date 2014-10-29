/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 Note: SDL (incorrectly, one could argue) uses the word "sample" to refer both to monophonic sound samples and
 stereo L/R sample pairs.
*/


#include "../sexyal.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/time.h>
#include <time.h>

#include <algorithm>

#include <SDL.h>

static int64_t Time64(void)
{
 // Don't use gettimeofday(), it's not monotonic.
 // (SDL will use gettimeofday() on UNIXy systems if clock_gettime() is not available, however...)
 int64_t ret;

 ret = (int64_t)SDL_GetTicks() * 1000;

 return(ret);
}

typedef struct
{
	void *Buffer;
	int32_t BufferSize;
	int32_t RealBufferSize;

	int EPMaxVal;   // Extra precision max value, in frames.


	int32_t BufferSize_Raw;
	int32_t RealBufferSize_Raw;
	int32_t BufferRead;
	int32_t BufferWrite;
	int32_t BufferIn;
	int32_t BufferGranularity;

	int StartPaused;
	int ProgPaused;

	int StandAlone;

	int64_t last_time;
} SDLWrap;

#ifdef WIN32
static void fillaudio(void *udata, uint8_t *stream, int len) __attribute__((force_align_arg_pointer));
#endif
static void fillaudio(void *udata, uint8_t *stream, int len)
{
 SexyAL_device *device = (SexyAL_device *)udata;
 SDLWrap *sw = (SDLWrap *)device->private_data;
 int tocopy = len;

 sw->last_time = Time64();

 if(tocopy > sw->BufferIn)
  tocopy = sw->BufferIn;

 //printf("%d\n", len);

 while(len)
 {
  if(tocopy > 0)
  {
   int maxcopy = tocopy;

   if((maxcopy + sw->BufferRead) > sw->RealBufferSize_Raw)
    maxcopy = sw->RealBufferSize_Raw - sw->BufferRead;

   memcpy(stream, (char *)sw->Buffer + sw->BufferRead, maxcopy);

   sw->BufferRead = (sw->BufferRead + maxcopy) % sw->RealBufferSize_Raw;

   sw->BufferIn -= maxcopy;

   stream += maxcopy;
   tocopy -= maxcopy;
   len -= maxcopy;
  }
  else
  {
   //printf("Underrun by: %d\n", len);
  
   // Set "stream" to center position.  Signed is easy, we can just memset
   // the entire buffer to 0.  Unsigned 8-bit is easy as well, but we need to take care with unsigned 16-bit to
   // take into account any byte-order reversal.
   if(SEXYAL_FMT_PCMU8 == device->format.sampformat)
   {
    memset(stream, 0x80, len);
   }
   else if(SEXYAL_FMT_PCMU16 == device->format.sampformat)
   {
    uint16_t fill_value = 0x8000;

    if(device->format.revbyteorder)	// Is byte-order reversed from native?
     fill_value = 0x0080;

    for(int i = 0; i < len; i += 2)
     *(uint16_t *)(stream + i) = fill_value;
   }
   else
    memset(stream, 0, len);

   stream += len;
   len = 0;
  }
 }
}

static int Get_RCW(SexyAL_device *device, uint32_t *can_write, bool want_nega = false)
{
 SDLWrap *sw = (SDLWrap *)device->private_data;
 int64_t curtime;
 int32_t cw;
 int32_t extra_precision;

 SDL_LockAudio();

 curtime = Time64();

 cw = sw->BufferSize_Raw - sw->BufferIn;

 extra_precision = ((curtime - sw->last_time) / 1000 * device->format.rate / 1000);

 if(extra_precision < 0)
 {
  //printf("extra_precision < 0: %d\n", extra_precision);
  extra_precision = 0;
 }
 else if(extra_precision > sw->EPMaxVal)
 {
  //printf("extra_precision > EPMaxVal: %d %d\n", extra_precision, sw->EPMaxVal);
  extra_precision = sw->EPMaxVal;
 }

 cw += extra_precision * device->format.channels * (device->format.sampformat >> 4);

 if(cw < 0)
 {
  if(want_nega)
   *can_write = (uint32_t)(int32_t)cw;
  else
   *can_write = 0;
 }
 else if(cw > sw->BufferSize_Raw)
 {
  *can_write = sw->BufferSize_Raw;
 }
 else 
  *can_write = cw;

 SDL_UnlockAudio();

 return(1);
}

static int RawCanWrite(SexyAL_device *device, uint32_t *can_write)
{
 return(Get_RCW(device, can_write, false));
}

static int RawWrite(SexyAL_device *device, const void *data, uint32_t len)
{
 SDLWrap *sw = (SDLWrap *)device->private_data;
 const uint8_t *data_u8 = (const uint8_t *)data;

 //printf("Write: %u, %u %u\n", len, sw->BufferIn, sw->RealBufferSize_Raw);

 SDL_LockAudio();
 while(len)
 {
  int maxcopy = len;

  if((maxcopy + sw->BufferWrite) > sw->RealBufferSize_Raw)
   maxcopy = sw->RealBufferSize_Raw - sw->BufferWrite;

  if((maxcopy + sw->BufferIn) > sw->RealBufferSize_Raw)
  {
   maxcopy = sw->RealBufferSize_Raw - sw->BufferIn;
   if(!maxcopy)
   {
    SDL_UnlockAudio();
    SDL_Delay(1);
    //puts("BJORK");
    SDL_LockAudio();
    continue;
   }
  }
  memcpy((char*)sw->Buffer + sw->BufferWrite, data_u8, maxcopy);

  sw->BufferWrite = (sw->BufferWrite + maxcopy) % sw->RealBufferSize_Raw;
  sw->BufferIn += maxcopy;

  data_u8 += maxcopy;
  len -= maxcopy;
 }
 SDL_UnlockAudio();

 if(sw->StartPaused)
 {
  sw->StartPaused = 0;
  SDL_PauseAudio(sw->ProgPaused);
 }

 uint32_t cw_tmp;

 while(Get_RCW(device, &cw_tmp, true) && (int32_t)cw_tmp < 0)
 {
  //int64_t tt = (int64_t)(int32_t)cw_tmp * -1 * 1000 * 1000 * 1000 / (device->format.channels * (device->format.sampformat >> 4) * device->format.rate);
  //usleep(tt / 1000);
  //printf("%f\n", (double)tt / 1000 / 1000 / 1000);
  SDL_Delay(1);
 }

 return(1);
}

static int Pause(SexyAL_device *device, int state)
{
 SDLWrap *sw = (SDLWrap *)device->private_data;

 sw->ProgPaused = state?1:0;
 SDL_PauseAudio(sw->ProgPaused | sw->StartPaused);

 return(sw->ProgPaused);
}

static int Clear(SexyAL_device *device)
{
 SDLWrap *sw = (SDLWrap *)device->private_data;
 SDL_LockAudio();

 SDL_PauseAudio(1);
 sw->StartPaused = 1;
 sw->BufferRead = sw->BufferWrite = sw->BufferIn = 0;

 SDL_UnlockAudio();
 return(1);
}

static int RawClose(SexyAL_device *device)
{
 if(device)
 {
  if(device->private_data)
  {
   SDLWrap *sw = (SDLWrap *)device->private_data;
   if(sw->Buffer)
    free(sw->Buffer);
   SDL_CloseAudio();
   free(device->private_data);

   if(sw->StandAlone)
   {
    SDL_Quit();
    //puts("SDL quit");
   }
  }
  free(device);
  return(1);
 }
 return(0);
}

SexyAL_device *SexyALI_SDL_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *device;
 SDLWrap *sw;
 SDL_AudioSpec desired, obtained;
 const char *env_standalone;
 int iflags;
 int StandAlone = 0;

 env_standalone = getenv("SEXYAL_SDL_STANDALONE");
 if(env_standalone && atoi(env_standalone))
 {
  StandAlone = 1;
  //puts("Standalone");
 }

 iflags = SDL_INIT_AUDIO | SDL_INIT_TIMER;

 #ifdef SDL_INIT_EVENTTHREAD
 iflags |= SDL_INIT_EVENTTHREAD;
 #endif

 if(StandAlone)
 {
  if(SDL_Init(iflags) < 0)
  {
   puts(SDL_GetError());
   return(0);
  }
 }
 else
 {
  //printf("%08x %08x %08x\n", iflags, SDL_WasInit(iflags), SDL_WasInit(iflags) ^ iflags);
  if(SDL_InitSubSystem(SDL_WasInit(iflags) ^ iflags) < 0)
  {
   puts(SDL_GetError());
   return(0);
  }
 }

 sw = (SDLWrap *)calloc(1, sizeof(SDLWrap));

 sw->StandAlone = StandAlone;

 device = (SexyAL_device *)calloc(1, sizeof(SexyAL_device));
 device->private_data = sw;

 memset(&desired, 0, sizeof(SDL_AudioSpec));
 memset(&obtained, 0, sizeof(SDL_AudioSpec));

 int desired_pt = buffering->period_us ? buffering->period_us : 5333;
 int psize = SexyAL_rnearestpow2((int64_t)desired_pt * format->rate / (1000 * 1000), false);

 desired.freq = format->rate;
 desired.format = AUDIO_S16;
 desired.channels = format->channels;
 desired.callback = fillaudio;
 desired.userdata = (void *)device;
 desired.samples = psize;

 if(SDL_OpenAudio(&desired, &obtained) < 0)
 {
  puts(SDL_GetError());
  RawClose(device);
  return(0);
 }

 format->channels = obtained.channels;
 format->rate = obtained.freq;

 if(obtained.format == AUDIO_U8)
  format->sampformat = SEXYAL_FMT_PCMU8;
 else if(obtained.format == AUDIO_S8)
  format->sampformat = SEXYAL_FMT_PCMS8;
 else if(obtained.format == AUDIO_S16LSB || obtained.format == AUDIO_S16MSB)
 {
  format->sampformat = SEXYAL_FMT_PCMS16;

  if(obtained.format != AUDIO_S16SYS)
   format->revbyteorder = 1;
 }
 else if(obtained.format == AUDIO_U16LSB || obtained.format == AUDIO_U16MSB)
 {
  format->sampformat = SEXYAL_FMT_PCMU16;

  if(obtained.format != AUDIO_U16SYS)
   format->revbyteorder = 1;
 }

 if(!buffering->ms) 
  buffering->ms = 100;
 else if(buffering->ms > 1000)
  buffering->ms = 1000;

 sw->EPMaxVal = obtained.samples;

 sw->BufferSize = (format->rate * buffering->ms / 1000);

 if(sw->BufferSize < obtained.samples)
  sw->BufferSize = obtained.samples;

 //printf("%d\n", sw->BufferSize);

 // *2 for safety room, and 30ms extra.
 sw->RealBufferSize = SexyAL_rupow2(sw->BufferSize + sw->EPMaxVal * 2 + ((30 * format->rate + 999) / 1000) );

 sw->BufferIn = sw->BufferRead = sw->BufferWrite = 0;

 buffering->buffer_size = sw->BufferSize;

 buffering->latency = sw->BufferSize + obtained.samples;
 buffering->period_size = obtained.samples;
 buffering->bt_gran = 1;

 //printf("%d\n", buffering->latency);

 sw->BufferSize_Raw = sw->BufferSize * format->channels * (format->sampformat >> 4);
 sw->RealBufferSize_Raw = sw->RealBufferSize * format->channels * (format->sampformat >> 4);

 sw->Buffer = malloc(sw->RealBufferSize_Raw);

 memcpy(&device->format, format, sizeof(SexyAL_format));
 memcpy(&device->buffering, buffering, sizeof(SexyAL_buffering));

 device->RawCanWrite = RawCanWrite;
 device->RawWrite = RawWrite;
 device->RawClose = RawClose;
 device->Clear = Clear;
 device->Pause = Pause;

 sw->StartPaused = 1;
 //SDL_PauseAudio(0);
 return(device);
}

