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

#include <mednafen/Time.h>

typedef struct
{
 int paused;
 int64 paused_time;

 int64 buffering_us;

 int64 data_written_to;

} Dummy_Driver_t;

static int RawCanWrite(SexyAL_device *device, uint32 *can_write)
{
 Dummy_Driver_t *dstate = (Dummy_Driver_t *)device->private_data;
 uint32 ret;
 int64 curtime = Time::MonoUS();

 if(dstate->paused)
  curtime = dstate->paused_time;

 if(curtime < dstate->data_written_to)
 {
  ret = 0;
  //printf("%ld\n", curtime - dstate->data_written_to);
 }
 else
  ret = (curtime - dstate->data_written_to) / 1000 * device->format.rate / 1000;

 if(ret > device->buffering.buffer_size)
 {
  ret = device->buffering.buffer_size;
  dstate->data_written_to = curtime - dstate->buffering_us;
 }

 *can_write = ret * device->format.channels * SAMPFORMAT_BYTES(device->format.sampformat);

 return(1);
}

static int RawWrite(SexyAL_device *device, const void *data, uint32 len)
{
 Dummy_Driver_t *dstate = (Dummy_Driver_t *)device->private_data;

 while(len)
 {
  uint32 can_write = 0;

  RawCanWrite(device, &can_write);

  if(can_write > len) 
   can_write = len;

  dstate->data_written_to += can_write / (device->format.channels * SAMPFORMAT_BYTES(device->format.sampformat)) * 1000000 / device->format.rate;

  len -= can_write;

  if(len)
  {
   Time::SleepMS(1);
  }
 }

 return(1);
}

static int Pause(SexyAL_device *device, int state)
{
 Dummy_Driver_t *dstate = (Dummy_Driver_t *)device->private_data;

 if(state != dstate->paused)
 {
  dstate->paused = state;

  if(state)
  {
   dstate->paused_time = Time::MonoUS();
  }
  else
  {
   dstate->data_written_to = Time::MonoUS() - (dstate->paused_time - dstate->data_written_to);
  }
 }

 return(dstate->paused);
}

static int Clear(SexyAL_device *device)
{
 Dummy_Driver_t *dstate = (Dummy_Driver_t *)device->private_data;
 int64 curtime = Time::MonoUS();

 if(dstate->paused)
  curtime = dstate->paused_time;

 dstate->data_written_to = curtime - dstate->buffering_us;

 return(1);
}

static int RawClose(SexyAL_device *device)
{
 Dummy_Driver_t *dstate = (Dummy_Driver_t *)device->private_data;

 if(dstate)
 {
  free(dstate);
  device->private_data = NULL;
 }

 return(1);
}


#define DUMMY_INIT_CLEANUP		\
	if(device) free(device);	\
	if(dstate) free(dstate);

SexyAL_device *SexyALI_Dummy_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *device = NULL;
 Dummy_Driver_t *dstate = NULL;

 if(!(device = (SexyAL_device *)calloc(1, sizeof(SexyAL_device))))
 {
  DUMMY_INIT_CLEANUP
  return(NULL);
 }

 if(!(dstate = (Dummy_Driver_t *)calloc(1, sizeof(Dummy_Driver_t))))
 {
  DUMMY_INIT_CLEANUP
  return(NULL);
 }

 device->private_data = dstate;

 if(!buffering->ms) 
  buffering->ms = 32;

 buffering->buffer_size = buffering->ms * format->rate / 1000;
 buffering->ms = buffering->buffer_size * 1000 / format->rate;
 buffering->latency = buffering->buffer_size;

 dstate->buffering_us = (int64)buffering->buffer_size * 1000 * 1000 / format->rate;

 memcpy(&device->format, format, sizeof(SexyAL_format));
 memcpy(&device->buffering, buffering, sizeof(SexyAL_buffering));

 device->RawCanWrite = RawCanWrite;
 device->RawWrite = RawWrite;
 device->RawClose = RawClose;
 device->Clear = Clear;
 device->Pause = Pause;

 return(device);
}

