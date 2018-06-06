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

#include <unistd.h>
#include <sys/time.h>
#include <time.h>

#include <SDL.h>

static int64 Time64(void)
{
 // Don't use gettimeofday(), it's not monotonic.
 // (SDL will use gettimeofday() on UNIXy systems if clock_gettime() is not available, however...)
 int64 ret;

 ret = (int64)SDL_GetTicks() * 1000;

 return(ret);
}

struct SexyAL_SDL
{
	void *Buffer;
	int32 BufferSize;
	int32 RealBufferSize;

	int EPMaxVal;   // Extra precision max value, in frames.


	int32 BufferSize_Raw;
	int32 RealBufferSize_Raw;
	int32 BufferRead;
	int32 BufferWrite;
	int32 BufferIn;
	int32 BufferGranularity;

	int StartPaused;
	int ProgPaused;

	int StandAlone;

	int64 last_time;
};

#ifdef WIN32
static void fillaudio(void *udata, uint8 *stream, int len) __attribute__((force_align_arg_pointer));
#endif
static void fillaudio(void *udata, uint8 *stream, int len)
{
 SexyAL_device *device = (SexyAL_device *)udata;
 SexyAL_SDL *sw = (SexyAL_SDL *)device->private_data;
 int tocopy = len;

 sw->last_time = Time64();

 if(tocopy > sw->BufferIn)
  tocopy = sw->BufferIn;

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
   if(device->format.sampformat == SEXYAL_FMT_PCMU8)
   {
    memset(stream, 0x80, len);
   }
   else if(device->format.sampformat == SEXYAL_FMT_PCMU16_LE)
   {
    for(int i = 0; i < len; i += 2)
     MDFN_en16lsb<true>(stream + i, 0x8000);
   }
   else if(device->format.sampformat == SEXYAL_FMT_PCMU16_BE)
   {
    for(int i = 0; i < len; i += 2)
     MDFN_en16msb<true>(stream + i, 0x8000);
   }
   else
    memset(stream, 0, len);

   stream += len;
   len = 0;
  }
 }
}

static int Get_RCW(SexyAL_device *device, uint32 *can_write, bool want_nega = false)
{
 SexyAL_SDL *sw = (SexyAL_SDL *)device->private_data;
 int64 curtime;
 int32 cw;
 int32 extra_precision;

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

 cw += extra_precision * device->format.channels * SAMPFORMAT_BYTES(device->format.sampformat);

 if(cw < 0)
 {
  if(want_nega)
   *can_write = (uint32)(int32)cw;
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

static int RawCanWrite(SexyAL_device *device, uint32 *can_write)
{
 return(Get_RCW(device, can_write, false));
}

static int RawWrite(SexyAL_device *device, const void *data, uint32 len)
{
 SexyAL_SDL *sw = (SexyAL_SDL *)device->private_data;
 const uint8 *data_u8 = (const uint8 *)data;

 //printf("Write: %u, %u %u\n", len, sw->BufferIn, sw->RealBufferSize_Raw);

 SDL_LockAudio();
 while(len)
 {
  uint32 maxcopy = len;

  maxcopy = std::min<uint32>(maxcopy, sw->RealBufferSize_Raw - sw->BufferWrite);
  maxcopy = std::min<uint32>(maxcopy, sw->RealBufferSize_Raw - sw->BufferIn);

  if(!maxcopy)
  {
   SDL_UnlockAudio();
   if(MDFN_UNLIKELY(sw->StartPaused))
   {
    sw->StartPaused = 0;
    SDL_PauseAudio(sw->ProgPaused);
   }
   SDL_Delay(1);
   //puts("BJORK");
   SDL_LockAudio();
   continue;
  }
  memcpy((char*)sw->Buffer + sw->BufferWrite, data_u8, maxcopy);

  sw->BufferWrite = (sw->BufferWrite + maxcopy) % sw->RealBufferSize_Raw;
  sw->BufferIn += maxcopy;

  data_u8 += maxcopy;
  len -= maxcopy;
 }
 SDL_UnlockAudio();

 if(MDFN_UNLIKELY(sw->StartPaused))
 {
  sw->StartPaused = 0;
  SDL_PauseAudio(sw->ProgPaused);
 }

 uint32 cw_tmp;

 while(Get_RCW(device, &cw_tmp, true) && (int32)cw_tmp < 0)
 {
  //int64 tt = (int64)(int32)cw_tmp * -1 * 1000 * 1000 * 1000 / (device->format.channels * SAMPFORMAT_BYTES(device->format.sampformat) * device->format.rate);
  //usleep(tt / 1000);
  //printf("%f\n", (double)tt / 1000 / 1000 / 1000);
  SDL_Delay(1);
 }

 return(1);
}

static int Pause(SexyAL_device *device, int state)
{
 SexyAL_SDL *sw = (SexyAL_SDL *)device->private_data;

 sw->ProgPaused = state?1:0;
 SDL_PauseAudio(sw->ProgPaused | sw->StartPaused);

 return(sw->ProgPaused);
}

static int Clear(SexyAL_device *device)
{
 SexyAL_SDL *sw = (SexyAL_SDL *)device->private_data;
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
   SexyAL_SDL *sw = (SexyAL_SDL *)device->private_data;
   SDL_CloseAudio();

   if(sw->StandAlone)
   {
    SDL_Quit();
    //puts("SDL quit");
   }
   //
   //
   //
   if(sw->Buffer)
    free(sw->Buffer);

   free(device->private_data);
  }
  free(device);
  return(1);
 }
 return(0);
}

static unsigned MapSampformatToSDL(const uint32 sampformat)
{
 if(SAMPFORMAT_BYTES(sampformat) >= 2)
 {
  if(SAMPFORMAT_ENC(sampformat) == SEXYAL_ENC_PCM_UINT)
   return SAMPFORMAT_BIGENDIAN(sampformat) ? AUDIO_U16MSB : AUDIO_U16LSB;
  else
   return SAMPFORMAT_BIGENDIAN(sampformat) ? AUDIO_S16MSB : AUDIO_S16LSB;
 }
 else
  return (SAMPFORMAT_ENC(sampformat) == SEXYAL_ENC_PCM_UINT) ? AUDIO_U8 : AUDIO_S8;
}

SexyAL_device *SexyALI_SDL_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *device;
 SexyAL_SDL *sw;
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

 sw = (SexyAL_SDL *)calloc(1, sizeof(SexyAL_SDL));

 sw->StandAlone = StandAlone;

 device = (SexyAL_device *)calloc(1, sizeof(SexyAL_device));
 device->private_data = sw;

 memset(&desired, 0, sizeof(SDL_AudioSpec));
 memset(&obtained, 0, sizeof(SDL_AudioSpec));

 int desired_pt = buffering->period_us ? buffering->period_us : 5333;
 int psize = round_nearest_pow2((int64)desired_pt * format->rate / (1000 * 1000), false);

 desired.freq = format->rate;
 desired.format = MapSampformatToSDL(format->sampformat);
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

 switch(obtained.format)
 {
  default: abort(); break;
 
  case AUDIO_U8: format->sampformat = SEXYAL_FMT_PCMU8; break;
  case AUDIO_S8: format->sampformat = SEXYAL_FMT_PCMS8; break;
  case AUDIO_S16LSB: format->sampformat = SEXYAL_FMT_PCMS16_LE; break;
  case AUDIO_S16MSB: format->sampformat = SEXYAL_FMT_PCMS16_BE; break;
  case AUDIO_U16LSB: format->sampformat = SEXYAL_FMT_PCMU16_LE; break;
  case AUDIO_U16MSB: format->sampformat = SEXYAL_FMT_PCMU16_BE; break;
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
 sw->RealBufferSize = round_up_pow2(sw->BufferSize + sw->EPMaxVal * 2 + ((30 * format->rate + 999) / 1000) );

 sw->BufferIn = sw->BufferRead = sw->BufferWrite = 0;

 buffering->buffer_size = sw->BufferSize;

 buffering->latency = sw->BufferSize + obtained.samples;
 buffering->period_size = obtained.samples;
 buffering->bt_gran = 1;

 //printf("%d\n", buffering->latency);

 sw->BufferSize_Raw = sw->BufferSize * format->channels * SAMPFORMAT_BYTES(format->sampformat);
 sw->RealBufferSize_Raw = sw->RealBufferSize * format->channels * SAMPFORMAT_BYTES(format->sampformat);

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

