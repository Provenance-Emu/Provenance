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

#include "../sexyal.h"

#include <unistd.h>
#include <ctype.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sched.h>
#include <sys/soundcard.h>

struct SexyAL_OSS
{
	int fd;
	bool alsa_workaround;		// true if we're using any OSS older than version 4, which includes ALSA(which conforms to 3.x).
					// Applying the workaround on non-ALSA where it's not needed will not hurt too much, it'll
					// just make the stuttering due to buffer underruns a little more severe.
					// (The workaround is to fix a bug which affects, at least, ALSA 1.0.20 when used with a CS46xx card)
	uint8 *dummy_data;
	uint32 dummy_data_len;
};


SexyAL_enumdevice *SexyALI_OSS_EnumerateDevices(void)
{
 SexyAL_enumdevice *ret,*tmp,*last;
 struct stat buf;
 char fn[64];
 char numstring[64];
 unsigned int n;

 n = 0;

 ret = tmp = last = 0;

 for(;;)
 {
  snprintf(numstring, 64, "%d", n);
  snprintf(fn, 64, "/dev/dsp%s", numstring);

  if(stat(fn,&buf)!=0) break;

  tmp = (SexyAL_enumdevice *)calloc(1, sizeof(SexyAL_enumdevice));

  tmp->name = strdup(fn);
  tmp->id = strdup(numstring);

  if(!ret) ret = tmp;
  if(last) last->next = tmp;

  last = tmp;
  n++;
 } 
 return(ret);
}

static int RawWrite(SexyAL_device *device, const void *data, uint32 len)
{
 SexyAL_OSS *ossw = (SexyAL_OSS *)device->private_data;
 const uint8 *datau8 = (const uint8 *)data;

 while(len)
 {
  ssize_t bytes = write(ossw->fd, datau8, len);

  if(bytes < 0)
  {
   if(errno == EINTR)
    continue;

   fprintf(stderr, "OSS: %d, %m\n", errno);
   return(0);
  }
  else if(bytes > len)
  {
   fprintf(stderr, "OSS: written bytes > len ???\n");
   bytes = len;
  }
  len -= bytes;
  datau8 += bytes;
 }

 return(1);
}

static int RawCanWrite(SexyAL_device *device, uint32 *can_write)
{
 SexyAL_OSS *ossw = (SexyAL_OSS *)device->private_data;
 struct audio_buf_info ai;

 TryAgain:

 if(!ioctl(ossw->fd, SNDCTL_DSP_GETOSPACE, &ai))
 {
  if(ai.bytes < 0)
   ai.bytes = 0; // ALSA is weird

  if(ossw->alsa_workaround && (unsigned int)ai.bytes >= (device->buffering.buffer_size * SAMPFORMAT_BYTES(device->format.sampformat) * device->format.channels))
  {
   //puts("Underflow fix");
   //fprintf(stderr, "%d\n",ai.bytes);
   if(!RawWrite(device, ossw->dummy_data, ossw->dummy_data_len))
    return(0);
   goto TryAgain;
  }

  *can_write = ai.bytes;

  return(1);
 }
 else
 {
  puts("Error");
  return(0);
 }
 return(1);
}

static int Pause(SexyAL_device *device, int state)
{
 return(0);
}

static int Clear(SexyAL_device *device)
{
 SexyAL_OSS *ossw = (SexyAL_OSS *)device->private_data;

 ioctl(ossw->fd, SNDCTL_DSP_RESET, 0);
 return(1);
}

static int RawClose(SexyAL_device *device)
{
 if(device)
 {
  if(device->private_data)
  {
   SexyAL_OSS *ossw = (SexyAL_OSS *)device->private_data;

   if(ossw->fd != -1)
   {
    close(ossw->fd);
    ossw->fd = -1;
   }

   if(ossw->dummy_data)
   {
    free(ossw->dummy_data);
    ossw->dummy_data = NULL;
   }

   free(device->private_data);
  }
  free(device);
  return(1);
 }
 return(0);
}

static unsigned MapSampformatToOSS(const uint32 sampformat)
{
 if(SAMPFORMAT_BYTES(sampformat) >= 2)
 {
  if(SAMPFORMAT_ENC(sampformat) == SEXYAL_ENC_PCM_UINT)
   return SAMPFORMAT_BIGENDIAN(sampformat) ? AFMT_U16_BE : AFMT_U16_LE;
  else
   return SAMPFORMAT_BIGENDIAN(sampformat) ? AFMT_S16_BE : AFMT_S16_LE;
 }
 else
  return (SAMPFORMAT_ENC(sampformat) == SEXYAL_ENC_PCM_UINT) ? AFMT_U8 : AFMT_S8;
}


#define OSS_INIT_ERROR_CLEANUP			\
		if(fd != -1)			\
		{				\
		 close(fd);			\
		 fd = -1;			\
		}				\
		if(ossw)			\
		{				\
		 if(ossw->dummy_data)		\
		  free(ossw->dummy_data);	\
		 free(ossw);			\
		 ossw = NULL;			\
		}				\
		if(device)			\
		{				\
		 free(device);			\
		 device = NULL;			\
		}

SexyAL_device *SexyALI_OSS_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *device = NULL;
 int fd = -1;
 SexyAL_OSS *ossw = NULL;
 int version = 0;
 bool alsa_workaround = false;
 int desired_pt;                // Desired period time, in MICROseconds.
 int desired_buffertime;        // Desired buffer time, in milliseconds

 desired_pt = buffering->period_us ? buffering->period_us : 1250;       // 1.25 milliseconds
 desired_buffertime = buffering->ms ? buffering->ms : 32;               // 32 milliseconds

 if((fd = open(id ? id : "/dev/dsp", O_WRONLY)) == -1)
 {
  puts(strerror(errno));
  return NULL;
 }
 
 if(ioctl(fd, OSS_GETVERSION, &version) == -1 || version < 0x040000)
 {
  puts("\nALSA SNDCTL_DSP_GETOSPACE internal-state-corruption bug workaround mode used.");
  alsa_workaround = true;
 }

 // Try to force at least 16-bit output and 2 channels so we can get lower period sizes(assuming the low-level device driver
 // expresses minimum period size in bytes).
 if(format->channels < 2)
  format->channels = 2;
 if(SAMPFORMAT_BYTES(format->sampformat) < 2)
  format->sampformat = SEXYAL_FMT_PCMS16;

 //
 // Set sample format
 //
 {
  unsigned temp, try_format;

  try_format = MapSampformatToOSS(format->sampformat);
  temp = try_format;
  if(ioctl(fd, SNDCTL_DSP_SETFMT, &temp) == -1 && temp == try_format)
  {
   puts(strerror(errno));
   OSS_INIT_ERROR_CLEANUP
   return NULL;
  }

  switch(temp)
  {
   case AFMT_U8: format->sampformat = SEXYAL_FMT_PCMU8; break;
   case AFMT_S8: format->sampformat = SEXYAL_FMT_PCMS8; break;
   case AFMT_U16_LE: format->sampformat = SEXYAL_FMT_PCMU16_LE; break;
   case AFMT_U16_BE: format->sampformat = SEXYAL_FMT_PCMU16_BE; break;
   case AFMT_S16_LE: format->sampformat = SEXYAL_FMT_PCMS16_LE; break;
   case AFMT_S16_BE: format->sampformat = SEXYAL_FMT_PCMS16_BE; break;

   default:
	OSS_INIT_ERROR_CLEANUP
	return NULL;
  }
 }

 //
 // Set channel count
 //
 {
  unsigned temp = format->channels;
  if(ioctl(fd, SNDCTL_DSP_CHANNELS, &temp) == -1)
  {
   OSS_INIT_ERROR_CLEANUP
   return NULL;
  }

  if(temp < 1 || temp > 2)
  {
   OSS_INIT_ERROR_CLEANUP
   return NULL;
  }

  format->channels = temp;
 }

 //
 // Set rate
 //
 {
  unsigned temp = format->rate;
  if(ioctl(fd, SNDCTL_DSP_SPEED, &temp) == -1)
  {
   OSS_INIT_ERROR_CLEANUP
   return NULL;
  }
  format->rate = temp;
 }

 device = (SexyAL_device*)calloc(1, sizeof(SexyAL_device));
 memcpy(&device->format, format, sizeof(SexyAL_format));
 memcpy(&device->buffering, buffering, sizeof(SexyAL_buffering));

 //
 // Set frag size and number of fragments.
 //
 {
  unsigned fragsize_frames;
  unsigned fragsize_bytes;
  unsigned fragcount;
  audio_buf_info info;

  fragsize_frames = round_nearest_pow2((int64)desired_pt * format->rate / (1000 * 1000), false);
  fragsize_bytes = fragsize_frames * SAMPFORMAT_BYTES(format->sampformat) * format->channels;
  // Partially work around poorly-designed/poorly-implemented OSS API by limiting range of the fragment size:
  fragsize_bytes = std::min<unsigned>(2048, fragsize_bytes);
  fragsize_bytes = std::max<unsigned>(64, fragsize_bytes);
  fragsize_frames = fragsize_bytes / (SAMPFORMAT_BYTES(format->sampformat) * format->channels);

  fragcount = ((int64)desired_buffertime * format->rate * 2 + 1000 * fragsize_frames) / (1000 * fragsize_frames * 2);
  fragcount = std::min<unsigned>(0x7FFF, fragcount);
  fragcount = std::max<unsigned>(2, fragcount);

  unsigned temp = MDFN_log2(fragsize_bytes) | (fragcount << 16);
  if(ioctl(fd, SNDCTL_DSP_SETFRAGMENT, &temp) == -1)
  {
   OSS_INIT_ERROR_CLEANUP
   return NULL;
  }

  if(ioctl(fd, SNDCTL_DSP_GETOSPACE, &info) == -1)
  {
   OSS_INIT_ERROR_CLEANUP
   return NULL;
  }

  fragsize_frames = info.fragsize / (SAMPFORMAT_BYTES(format->sampformat) * format->channels);
  fragcount = info.fragments;

  buffering->buffer_size = fragsize_frames * fragcount;
  buffering->period_size = fragsize_frames;
  buffering->latency = buffering->buffer_size;
 }

 if(!(ossw = (SexyAL_OSS *)calloc(1, sizeof(SexyAL_OSS))))
 {
  OSS_INIT_ERROR_CLEANUP
  return NULL;
 }

 ossw->dummy_data_len = SAMPFORMAT_BYTES(format->sampformat) * format->channels * (format->rate / 128);
 if(!(ossw->dummy_data = (uint8 *)calloc(1, ossw->dummy_data_len)))
 {
  OSS_INIT_ERROR_CLEANUP
  return NULL;
 }

 if(format->sampformat == SEXYAL_FMT_PCMU8 || format->sampformat == SEXYAL_FMT_PCMU16)
  memset(ossw->dummy_data, 0x80, ossw->dummy_data_len);
 else
  memset(ossw->dummy_data, 0, ossw->dummy_data_len);

 ossw->fd = fd;

 ossw->alsa_workaround = alsa_workaround;

 device->private_data = ossw;
 device->RawCanWrite = RawCanWrite;
 device->RawWrite = RawWrite;
 device->RawClose = RawClose;
 device->Clear = Clear;
 device->Pause = Pause;

 memcpy(&device->buffering,buffering,sizeof(SexyAL_buffering));
 memcpy(&device->format,format,sizeof(SexyAL_format));

 return(device);
}

