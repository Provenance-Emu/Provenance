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
#include <sys/time.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <jack/jack.h>
#include <jack/ringbuffer.h>

static INLINE int64 Time64(void)
{
 return jack_get_time();
}

struct SexyAL_JACK
{
	jack_port_t *output_port[2];
	jack_client_t *client;
	jack_ringbuffer_t *tmpbuf[2];
	int BufferSize;
	int RealBufferSize;

	int EPMaxVal;	// Extra precision max value, in frames.

	// Written to in process(), read from in the main program thread.
	jack_ringbuffer_t *timebuf;

	// Read/written to in the main program thread.
	int64 last_time;
	int32 write_space;

	int closed;

	uint64 underrun_frames;
	uint64 underrun_chunks;

	bool NeedActivate;
};

static int RawClose(SexyAL_device *device);


static bool DoActivate(SexyAL_device *device)
{
 SexyAL_JACK *jw = (SexyAL_JACK *)device->private_data;
 const char **ports;

 if(!jw->NeedActivate)
  return(1);

 jw->NeedActivate = 0;

 jw->last_time = Time64();
 jw->write_space = jw->RealBufferSize * sizeof(float);

 if(jack_activate(jw->client))
 {
  RawClose(device);
  return(0);
 }

 if(!(ports = jack_get_ports(jw->client, NULL, NULL, JackPortIsPhysical | JackPortIsInput)))
 {
  RawClose(device);
  return(0);
 }
 jack_connect(jw->client, jack_port_name(jw->output_port[0]), ports[0]);

 if(device->format.channels == 2)
  jack_connect(jw->client, jack_port_name(jw->output_port[1]), ports[1]);
 else
  jack_connect(jw->client, jack_port_name(jw->output_port[0]), ports[1]);

 free(ports);

 //printf("%d\n", (int)jack_port_get_total_latency(jw->client, jw->output_port[0]));

 return(1);
}

static int process(jack_nframes_t nframes, void *arg)
{
 SexyAL_JACK *jw = (SexyAL_JACK *)arg;
 int tch = 1;
 int ch;
 int canread = jack_ringbuffer_read_space(jw->tmpbuf[0]) / sizeof(jack_default_audio_sample_t);

 if(jw->tmpbuf[1])
  tch = 2;

 if(tch == 2)
 {
  int canread2 = jack_ringbuffer_read_space(jw->tmpbuf[1]) / sizeof(jack_default_audio_sample_t);

  if(canread2 < canread) canread = canread2;
 }

 if(canread > (int)nframes)
  canread = nframes;

 for(ch = 0; ch < tch; ch++)
 {
  jack_default_audio_sample_t *out = (jack_default_audio_sample_t *) jack_port_get_buffer(jw->output_port[ch], nframes);

  jack_ringbuffer_read(jw->tmpbuf[ch], (char *)out,canread * sizeof(jack_default_audio_sample_t));

  if((int)nframes - canread)    /* Buffer underrun.  Hmm. */
  {
   for(int i = 0; i < (int)nframes - canread; i++)
    out[i + canread] = 0;	//rand() & 1;
   //printf("%d\n", nframes);
  }
 }

 jw->underrun_frames += nframes - canread;

 if(nframes - canread)
  jw->underrun_chunks++;

 {
  int64 buf[2];
  
  buf[0] = Time64();
  buf[1] = jw->RealBufferSize * sizeof(float) - (int64)jack_ringbuffer_read_space(jw->tmpbuf[0]);

  if(jack_ringbuffer_write(jw->timebuf, (const char *)buf, sizeof(buf)) != sizeof(buf))
  {
   puts("oops");
  }
 }
 //printf("%d\n", nframes);
 // Return success(0)
 return(0);
}

static int Get_RCW(SexyAL_device *device, uint32 *can_write, bool want_nega = false)
{
 SexyAL_JACK *jw = (SexyAL_JACK *)device->private_data;
 int32 cw;
 size_t can_read;
 int64 buf[2];
 int32 extra_precision;

 DoActivate(device);

 if(jw->closed)
  return(0);

 can_read = jack_ringbuffer_read_space(jw->timebuf);

 can_read &= ~(sizeof(buf) - 1);

 if(can_read)
 {
  if(can_read - sizeof(buf))
   jack_ringbuffer_read_advance(jw->timebuf, can_read - sizeof(buf));

  jack_ringbuffer_read(jw->timebuf, (char *)buf, sizeof(buf));

  jw->last_time = buf[0];
  jw->write_space = buf[1];

  //printf("%lld %lld\n", jw->last_time, jw->write_space);
 }

 cw = jw->write_space - (jw->RealBufferSize - jw->BufferSize) * sizeof(float);

 extra_precision = ((Time64() - jw->last_time) / 1000 * device->format.rate / 1000);

 if(extra_precision < 0) // Shouldn't happen...maybe if jack is forced to use gettimeofday() instead of clock_gettime() it will
 {
  //printf("extra_precision < 0: %d\n", extra_precision);
  extra_precision = 0;
 }
 else if(extra_precision > jw->EPMaxVal)	// May happen if jackd freezes or system is heavily loaded.
 {
  extra_precision = jw->EPMaxVal;
  //printf("extra_precision > EPMaxVal: %d %d\n", extra_precision, jw->EPMaxVal);
 }

 cw += extra_precision * sizeof(float);

 if(cw < 0)
 {
  if(want_nega)
   cw = ~0U;
  else
   cw = 0;

  *can_write = cw;

  return(1);
 }
 else if((uint32)cw > jw->RealBufferSize * sizeof(float))
  cw = jw->RealBufferSize * sizeof(float);

 *can_write = cw * device->format.channels;

 return(1);
}

static int RawCanWrite(SexyAL_device *device, uint32 *can_write)
{
 return(Get_RCW(device, can_write, false));
}

static int RawWrite(SexyAL_device *device, const void *data, uint32 len)
{
 SexyAL_JACK *jw = (SexyAL_JACK *)device->private_data;
 uint8 *data8 = (uint8*)data;
 DoActivate(device);

 if(jw->closed)
  return(0);

 //printf("%u %u\n", len / 2, jack_ringbuffer_write_space(jw->tmpbuf[0]));

 while(len)
 {
  uint32 sublen = len / device->format.channels;

  for(unsigned int ch = 0; ch < device->format.channels; ch++)
  {
   // Avoid causing a float misalignment issue...
   size_t ws = jack_ringbuffer_write_space(jw->tmpbuf[ch]) / sizeof(float) * sizeof(float);

   if(sublen > ws)
   {
    sublen = ws;
    //printf("SPOOOON: %u %u\n", ch, sublen);
   }
  }

  for(unsigned ch = 0; ch < device->format.channels; ch++)
  {
   if(jack_ringbuffer_write(jw->tmpbuf[ch], (const char *)data8 + (ch * sublen), sublen) != sublen)
   {
    puts("JACK ringbuffer write failure?");
    return(0);
   }
  }

  jw->write_space -= sublen;
  data8 += sublen;
  len -= sublen * device->format.channels;

  if(len)
   usleep(1000);
 } // end while(len)

 uint32 cw_tmp;

 while(Get_RCW(device, &cw_tmp, true) && cw_tmp == ~0U)
 {
  usleep(1000);
 }

 return(1);
}

// TODO: How should be implement this without causing race conditions?
static int Clear(SexyAL_device *device)
{
 //SexyAL_JACK *jw = (SexyAL_JACK *)device->private_data;

 DoActivate(device);

 return(1);
}

static int RawClose(SexyAL_device *device)
{
 if(device)
 {
  if(device->private_data)
  {
   SexyAL_JACK *jw = (SexyAL_JACK *)device->private_data;

   if(jw->client)
    jack_deactivate(jw->client);

   if(jw->tmpbuf[0])
   {
    jack_ringbuffer_free(jw->tmpbuf[0]);
   }

   if(jw->tmpbuf[1])
   {
    jack_ringbuffer_free(jw->tmpbuf[1]);
   }

   if(jw->timebuf)
    jack_ringbuffer_free(jw->timebuf);

   if(jw->client && !jw->closed)
    jack_client_close(jw->client);

   printf("\n%llu underrun frames in %llu chunks.\n", (unsigned long long)jw->underrun_frames, (unsigned long long)jw->underrun_chunks);
   free(device->private_data);
  }
  free(device);
  return(1);
 }
 return(0);
}

static void DeadSound(void *arg)
{
 SexyAL_JACK *jw = (SexyAL_JACK *)arg;

 jw->closed = 1;
 jw->NeedActivate = 0;

 puts("AGH!  Sound server hates us!  Let's go on a rampage.");
}

// TODO
static int Pause(SexyAL_device *device, int state)
{
 //SexyAL_JACK *jw = (SexyAL_JACK *)device->private_data;

 DoActivate(device);

 return(0);
}

SexyAL_device *SexyALI_JACK_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *device;
 SexyAL_JACK *jw;

 jw = (SexyAL_JACK *)calloc(1, sizeof(SexyAL_JACK));

 device = (SexyAL_device *)calloc(1, sizeof(SexyAL_device));

 device->private_data = jw;

 if(!(jw->client = jack_client_open("Mednafen", (jack_options_t)(JackServerName | JackNoStartServer), NULL, id ? id : "default")))
 {
  RawClose(device);
  return(0);
 }

 jack_set_process_callback(jw->client, process, jw);
 jack_on_shutdown(jw->client, DeadSound, jw);

 format->rate = jack_get_sample_rate(jw->client);
 format->sampformat = SEXYAL_FMT_PCMFLOAT;

 if(!(jw->output_port[0] = jack_port_register(jw->client, "output", JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0)))
 {
  RawClose(device);
  return(0);
 }

 format->noninterleaved = false;
 if(format->channels == 2)
 {
  format->noninterleaved = true;
  if(!(jw->output_port[1] = jack_port_register(jw->client, "output-right", JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0)))
  {
   RawClose(device);
   return(0);
  }
 }


 if(!buffering->ms)
  buffering->ms = 40;

 if(buffering->ms > 1000)
  buffering->ms = 1000;

 // about 50ms extra precision, maximum.
 jw->EPMaxVal = (50 * format->rate + 999) / 1000;

 jw->BufferSize = format->rate * buffering->ms / 1000;

 jw->RealBufferSize = round_up_pow2(jw->BufferSize + jw->EPMaxVal + ((30 * format->rate + 999) / 1000));

 buffering->buffer_size = jw->BufferSize;

 if(!(jw->tmpbuf[0] = jack_ringbuffer_create(jw->RealBufferSize * sizeof(jack_default_audio_sample_t))))
 {
  RawClose(device);
  return(0);
 }

 if(format->channels == 2)
 {
  if(!(jw->tmpbuf[1] = jack_ringbuffer_create(jw->RealBufferSize * sizeof(jack_default_audio_sample_t))))
  {
   RawClose(device);
   return(0);
  }
  //format->split_stereo = 1;
 }
 //else
  //format->split_stereo = 0;

 // Overkill size, to be on the safe side. :3
 if(!(jw->timebuf = jack_ringbuffer_create(sizeof(int64) * 8192)))
 {
  RawClose(device);
  return(0);
 }

 jw->NeedActivate = 1;

 buffering->latency = jw->BufferSize;	// FIXME, jw->BufferSize + jack_port_get_latency_range() ???
 buffering->period_size = 0;

 memcpy(&device->format,format,sizeof(SexyAL_format));
 memcpy(&device->buffering,buffering,sizeof(SexyAL_buffering));

 device->RawCanWrite = RawCanWrite;
 device->RawWrite = RawWrite;
 device->RawClose = RawClose;
 device->Clear = Clear;
 device->Pause = Pause;

#if 0
 //
 DoActivate(device);
 //
 {
  jack_latency_range_t rn;

  memset(&rn, 0, sizeof(rn));
  jack_port_get_latency_range(jw->output_port[0], JackPlaybackLatency, &rn);

  //printf("%d\n", (int)jack_port_get_total_latency(jw->client, jw->output_port[0]));
  buffering->latency = jw->BufferSize + rn.max;
 }
#endif
 return(device);
}

