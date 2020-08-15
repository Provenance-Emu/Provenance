/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
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

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "sdl.h"

#ifdef USE_SEXYAL

#include "../sexyal/sexyal.h"

static SexyAL *Interface;
static SexyAL_device *Output;
static SexyAL_format format;
static SexyAL_buffering buffering;

uint32 GetMaxSound(void)
{
 return(buffering.totalsize);
}

uint32 GetWriteSound(void)
{
 return(Output->CanWrite(Output));
}

void WriteSound(int32 *Buffer, int Count)
{
 //printf("%d\n",Output->CanWrite(Output));
 Output->Write(Output, Buffer, Count);
}

int InitSound(FCEUGI *gi)
{
 if(!_sound) return(0);

 memset(&format,0,sizeof(format));
 memset(&buffering,0,sizeof(buffering));

 FCEUI_SetSoundVolume(soundvol);
 FCEUI_SetSoundQuality(soundq);

 Interface=SexyAL_Init(0);

 format.sampformat=SEXYAL_FMT_PCMS32S16;
 format.channels=gi->soundchan?gi->soundchan:1;
 format.rate=gi->soundrate?gi->soundrate:soundrate;
 buffering.fragcount=buffering.fragsize=0;
 buffering.ms=soundbufsize;

 FCEUI_printf("\nInitializing sound...");
 if(!(Output=Interface->Open(Interface,SEXYAL_ID_UNUSED,&format,&buffering)))
 {
  FCEUD_PrintError("Error opening a sound device.");
  Interface->Destroy(Interface);
  Interface=0;
  return(0);
 }

 if(soundq && format.rate!=48000 && format.rate!=44100 && format.rate!=96000)
 {
  FCEUD_PrintError("Set sound playback rate neither 44100, 48000, nor 96000, but needs to be when in high-quality sound mode.");
  KillSound();   
  return(0);
 }

 if(format.rate<8192 || format.rate > 96000)
 {
  FCEUD_PrintError("Set rate is out of range [8192-96000]");
  KillSound();
  return(0);
 }
 FCEUI_printf("\n Bits: %u\n Rate: %u\n Channels: %u\n Byte order: CPU %s\n Buffer size: %u sample frames(%f ms)\n",(format.sampformat>>4)*8,format.rate,format.channels,format.byteorder?"Reversed":"Native",buffering.totalsize,(double)buffering.totalsize*1000/format.rate);

 format.sampformat=SEXYAL_FMT_PCMS32S16;
 format.channels=gi->soundchan?gi->soundchan:1;
 format.byteorder=0;

 //format.rate=gi->soundrate?gi->soundrate:soundrate;

 Output->SetConvert(Output,&format);

 FCEUI_Sound(format.rate);
 return(1);
}

void SilenceSound(int n)
{

}

int KillSound(void)
{
 FCEUI_Sound(0);
 if(Output)
  Output->Close(Output);
 if(Interface)
  Interface->Destroy(Interface);
 Interface=0;
 if(!Output) return(0);
 Output=0;
 return(1);
}

#elif USE_JACKACK	/* Use JACK Audio Connection Kit */

#include <jack/jack.h>
#include <jack/ringbuffer.h>

static jack_port_t *output_port = NULL;
static jack_client_t *client = NULL;
static jack_ringbuffer_t *tmpbuf = NULL;
static unsigned int BufferSize;

static int process(jack_nframes_t nframes, void *arg)
{
 jack_default_audio_sample_t *out = (jack_default_audio_sample_t *) jack_port_get_buffer(output_port, nframes);
 size_t canread;

 canread = jack_ringbuffer_read_space(tmpbuf) / sizeof(jack_default_audio_sample_t);

 if(canread > nframes)
  canread = nframes;

 jack_ringbuffer_read(tmpbuf, out,canread * sizeof(jack_default_audio_sample_t));
 nframes -= canread;

 if(nframes)	/* Buffer underflow.  Hmm. */
 {

 }

}

uint32 GetMaxSound(void)
{
 return(BufferSize);
}  
 
uint32 GetWriteSound(void)
{
 return(jack_readbuffer_write_space / sizeof(jack_default_audio_sample_t));
}


static void DeadSound(void *arg)
{
 puts("AGH!  Sound server hates us!  Let's go on a rampage.");
}

int InitSound(FCEUGI *gi)
{
 const char **ports;

 client = jack_client_new("FCE Ultra");

 jack_set_process_callback(client, process, 0);
 jack_on_shutdown(client, DeadSound, 0);

 printf("%ld\n",jack_get_sample_rate(client));

 output_port = jack_port_register(client, "output", JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);

 BufferSize = soundbufsize * soundrate / 1000;
  
 tmpbuf = jack_ringbuffer_create(BufferSize * sizeof(jack_default_audio_sample_t));

 jack_activate(client);


 ports = jack_get_ports(client, NULL, NULL, JackPortIsPhysical | JackPortIsInput);
 jack_connect(client, jack_port_name(output_port), ports[0]);
 free(ports);
}

void WriteSound(int32 *buf, int Count)
{
 jack_default_audio_sample_t jbuf[Count];
 int x;

 for(x=0;x<Count;x++,buf++)
  jbuf[x] = *buf;

 jack_ringbuffer_write(tmpbuf, jbuf, sizeof(jack_default_audio_sample_t) * Count);
}

void SilenceSound(int n)
{


}

int KillSound(void)
{
 if(tmpbuf)
 {
  jack_ringbuffer_free(tmpbuf);
  tmpbuf = NULL;
 }
 if(client)
 {
  jack_client_close(client);
  client = NULL;
 } 
 return(1);
}

#else	/* So we'll use SDL's evil sound support.  Ok. */
static volatile int *Buffer = 0;
static unsigned int BufferSize;
static unsigned int BufferRead;
static unsigned int BufferWrite;
static volatile unsigned int BufferIn;

static void fillaudio(void *udata, uint8 *stream, int len)
{
 int16 *tmps = (int16*)stream;
 len >>= 1;

 while(len)
 {
  int16 sample = 0;
  if(BufferIn)
  {
   sample = Buffer[BufferRead];
   BufferRead = (BufferRead + 1) % BufferSize;
   BufferIn--;
  }
  else sample = 0;

  *tmps = sample;
  tmps++;
  len--;
 }
}

int InitSound(FCEUGI *gi)
{
 SDL_AudioSpec spec;
 if(!_sound) return(0);

 memset(&spec,0,sizeof(spec));
 if(SDL_InitSubSystem(SDL_INIT_AUDIO)<0)
 {
  puts(SDL_GetError());
  KillSound();
  return(0);
 }

 spec.freq = soundrate;
 spec.format = AUDIO_S16SYS;
 spec.channels = 1;
 spec.samples = 256;
 spec.callback = fillaudio;
 spec.userdata = 0;

 BufferSize = soundbufsize * soundrate / 1000;

 BufferSize -= spec.samples * 2;		/* SDL uses at least double-buffering, so
						   multiply by 2. */

 if(BufferSize < spec.samples) BufferSize = spec.samples;

 Buffer = malloc(sizeof(int) * BufferSize);
 BufferRead = BufferWrite = BufferIn = 0;

 //printf("SDL Size: %d, Internal size: %d\n",spec.samples,BufferSize);

 if(SDL_OpenAudio(&spec,0)<0)
 {
  puts(SDL_GetError());
  KillSound();
  return(0);
 }
 SDL_PauseAudio(0);
 FCEUI_Sound(soundrate);
 return(1);
} 


uint32 GetMaxSound(void)
{
 return(BufferSize);
}

uint32 GetWriteSound(void)
{
 return(BufferSize - BufferIn);
}

void WriteSound(int32 *buf, int Count)
{
 while(Count)
 {
  while(BufferIn == BufferSize) SDL_Delay(1);
  Buffer[BufferWrite] = *buf;
  Count--;
  BufferWrite = (BufferWrite + 1) % BufferSize;
  BufferIn++;
  buf++;
 }
}

void SilenceSound(int n)
{ 
 SDL_PauseAudio(n);   
}

int KillSound(void)
{
 FCEUI_Sound(0);
 SDL_CloseAudio();
 SDL_QuitSubSystem(SDL_INIT_AUDIO);
 if(Buffer)
 {
  free(Buffer);
  Buffer = 0;
 }
 return(0);
}


#endif


static int mute=0;
static int soundvolume=100;
void FCEUD_SoundVolumeAdjust(int n)
{
	switch(n)
	{
	case -1:	soundvolume-=10; if(soundvolume<0) soundvolume=0; break;
	case 0:		soundvolume=100; break;
	case 1:		soundvolume+=10; if(soundvolume>150) soundvolume=150; break;
	}
	mute=0;
	FCEUI_SetSoundVolume(soundvolume);
	FCEU_DispMessage("Sound volume %d.", soundvolume);
}
void FCEUD_SoundToggle(void)
{
	if(mute)
	{
		mute=0;
		FCEUI_SetSoundVolume(soundvolume);
		FCEU_DispMessage("Sound mute off.");
	}
	else
	{
		mute=1;
		FCEUI_SetSoundVolume(0);
		FCEU_DispMessage("Sound mute on.");
	}
}
