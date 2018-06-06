/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* openbsd.cpp - OpenBSD Audio Device Sound Driver
**  Copyright (C) 2017 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include "../sexyal.h"

#include <time.h>
#include <unistd.h>
#include <poll.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/audioio.h>
#include <sys/time.h>

struct SexyAL_OpenBSD
{
 int fd;
 unsigned int write_pos;
};

// TODO:
SexyAL_enumdevice* SexyALI_OpenBSD_EnumerateDevices(void)
{
 return NULL;
}

static int Pause(SexyAL_device* device, int state)
{
 SexyAL_OpenBSD* ods = (SexyAL_OpenBSD*)device->private_data;
 struct audio_status st;
 
 if(ioctl(ods->fd, AUDIO_GETSTATUS, &st) == -1)
  return false;

 if(st.pause == state)
  return false;

 if(ioctl(ods->fd, state ? AUDIO_STOP : AUDIO_START) == -1)
  return false;

 return true;
}

static int Clear(SexyAL_device* device)
{
 // TODO?
 return false;
}

static int RawCanWrite(SexyAL_device* device, uint32* can_write)
{
 SexyAL_OpenBSD* ods = (SexyAL_OpenBSD*)device->private_data;
 struct audio_pos pos;

 if(ioctl(ods->fd, AUDIO_GETPOS, &pos) == -1)
  return false;

 const unsigned int buffered_bytes = ods->write_pos - (pos.play_pos - pos.play_xrun);
 unsigned int buffered_frames;

 buffered_frames = (buffered_bytes + SAMPFORMAT_BYTES(device->format.sampformat) * device->format.channels - 1) / (SAMPFORMAT_BYTES(device->format.sampformat) * device->format.channels);
 //printf("Before: %08x\n", buffered_frames);
 buffered_frames += (device->buffering.period_size - (buffered_frames % device->buffering.period_size)) % device->buffering.period_size;
 //printf("After: %08x\n", buffered_frames);
 //assert(buffered_frames <= device->buffering.buffer_size);

 *can_write = (device->buffering.buffer_size - buffered_frames) * SAMPFORMAT_BYTES(device->format.sampformat) * device->format.channels;

 return true;
}

static int RawWrite(SexyAL_device* device, const void* data, uint32 len)
{
 SexyAL_OpenBSD* ods = (SexyAL_OpenBSD*)device->private_data;

 while(len > 0)
 {
  ssize_t written;

  errno = 0;
  written = write(ods->fd, data, len);

  if(written <= 0)
  {
   if(errno != EINTR)
    return false;
  }
  else
  {
   data = (unsigned char*)data + written;
   len -= written;
   ods->write_pos += written;
  }
 }

 return true;
}

static int RawClose(SexyAL_device* device)
{
 if(device)
 {
  if(device->private_data)
  {
   SexyAL_OpenBSD* ods = (SexyAL_OpenBSD*)device->private_data;
   if(ods->fd != -1)
   {
    close(ods->fd);
    ods->fd = -1;
   }
   free(device->private_data);
  }
  free(device);
  return true;
 }
 return false;
}

#define OBSD_INIT_CLEANUP	\
         if(fd != -1) close(fd);  \
         if(ods) free(ods);     \
         if(device) free(device);       

#define OBSD_TRY(func) { 	\
	int error = (func); 	\
	if(error < 0) 		\
	{ 			\
	 printf("OpenBSD Audio Error: %s %s\n", #func, strerror(errno)); 	\
	 OBSD_INIT_CLEANUP	\
	 return NULL; 		\
	} }

SexyAL_device* SexyALI_OpenBSD_Open(const char* id, SexyAL_format* format, SexyAL_buffering* buffering)
{
 SexyAL_OpenBSD* ods = NULL;
 SexyAL_device* device = NULL;
 int fd = -1;
 struct audio_swpar par;

 //
 // Try to force at least 16-bit output so we can get lower period sizes(assuming the low-level device driver
 // expresses minimum period size in bytes).
 //
 if(SAMPFORMAT_BYTES(format->sampformat) < 2)
  format->sampformat = SEXYAL_FMT_PCMS16;

 AUDIO_INITPAR(&par);

 OBSD_TRY(fd = open(id ? id : "/dev/audio", O_WRONLY));

 par.bits = SAMPFORMAT_BITS(format->sampformat);
 par.bps = SAMPFORMAT_BYTES(format->sampformat);
 par.sig = SAMPFORMAT_ENC(format->sampformat) != SEXYAL_ENC_PCM_UINT;
 par.le = !SAMPFORMAT_BIGENDIAN(format->sampformat);
 par.msb = (bool)SAMPFORMAT_LSBPAD(format->sampformat);

 par.pchan = format->channels;
 par.rate = format->rate;

 //
 // Format negotiation code below makes a lot of assumptions about how the kernel and drivers will behave, but it should be ok...
 //
 const uint32 desired_pt = buffering->period_us ? buffering->period_us : 1250;
 const uint32 desired_buft = (buffering->ms ? buffering->ms : 32);
 //
 // Initial try, don't know what rate it'll restrict us to...
 //
 par.round = std::max<int64>(1, ((int64)desired_pt * par.rate + 500000) / 1000000);
 par.nblks = std::max<int64>(2, ((int64)desired_buft * par.rate * 2 + (int64)par.round * 1000) / ((int64)2 * par.round * 1000));
 OBSD_TRY(ioctl(fd, AUDIO_SETPAR, &par));
 OBSD_TRY(ioctl(fd, AUDIO_GETPAR, &par));

 //
 // Try to force at least 2 channels so we can get lower period sizes(assuming the low-level device driver
 // expresses minimum period size in bytes).  But don't do it if it results in a lower sample resolution
 // or lower rate.
 //
 if(par.pchan < 2)
 {
  struct audio_swpar newpar;

  memcpy(&newpar, &par, sizeof(struct audio_swpar));
  newpar.pchan = 2;
  OBSD_TRY(ioctl(fd, AUDIO_SETPAR, &newpar));
  OBSD_TRY(ioctl(fd, AUDIO_GETPAR, &newpar));

  if(newpar.pchan > par.pchan && newpar.rate >= par.rate && newpar.bits >= par.bits)
   memcpy(&par, &newpar, sizeof(struct audio_swpar));
 }

 //
 // Recalculate frag size and # of frags based on available rate.
 //
 par.round = std::max<int64>(1, ((int64)desired_pt * par.rate + 500000) / 1000000);
 par.nblks = std::max<int64>(2, ((int64)desired_buft * par.rate * 2 + (int64)par.round * 1000) / ((int64)2 * par.round * 1000));
 OBSD_TRY(ioctl(fd, AUDIO_SETPAR, &par));
 OBSD_TRY(ioctl(fd, AUDIO_GETPAR, &par));

 //
 // Recalculate # of frags based on available frag size.
 //
 par.nblks = std::max<int64>(2, ((int64)desired_buft * par.rate * 2 + (int64)par.round * 1000) / ((int64)2 * par.round * 1000));
 OBSD_TRY(ioctl(fd, AUDIO_SETPAR, &par));
 OBSD_TRY(ioctl(fd, AUDIO_GETPAR, &par));


 format->noninterleaved = false;
 format->rate = par.rate;
 format->channels = par.pchan;
 format->sampformat = SAMPFORMAT_MAKE(par.sig ? SEXYAL_ENC_PCM_SINT : SEXYAL_ENC_PCM_UINT, par.bps, par.bits, par.msb ? (8 * par.bps - par.bits) : 0, !par.le);

 buffering->period_size = par.round;
 buffering->buffer_size = par.round * par.nblks;
 buffering->latency = buffering->buffer_size;

 // OBSD_TRY(ioctl(fd, AUDIO_START));
 //
 //
 //
 device = (SexyAL_device*)calloc(1, sizeof(SexyAL_device));
 ods = (SexyAL_OpenBSD*)calloc(1, sizeof(SexyAL_OpenBSD));

 ods->fd = fd;
 ods->write_pos = 0;

 device->private_data = ods;
 device->RawWrite = RawWrite;
 device->RawCanWrite = RawCanWrite;
 device->RawClose = RawClose;
 device->Pause = Pause;
 device->Clear = Clear;

 memcpy(&device->buffering, buffering, sizeof(SexyAL_buffering));
 memcpy(&device->format, format, sizeof(SexyAL_format));

 return device;
}

