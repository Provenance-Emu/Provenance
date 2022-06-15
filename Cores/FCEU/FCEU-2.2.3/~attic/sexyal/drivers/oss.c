#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sched.h>
#include <sys/soundcard.h>

#include "../sexyal.h"
#include "../md5.h"
#include "../smallc.h"

#include "oss.h"

#define IDBASE	0x1000

void SexyALI_OSS_Enumerate(int (*func)(uint8_t *name, uint64_t id, void *udata), void *udata)
{
 struct stat buf;
 char fn[64];
 unsigned int n;

 n=0;

 do
 {
  sal_strcpy(fn,"/dev/dsp");
  sal_strcat(fn,sal_uinttos(n));
  if(stat(fn,&buf)!=0) break;
 } while(func(fn,n+IDBASE,udata));
}

static int FODevice(uint64_t id)
{
 char fn[64];

 if(id==SEXYAL_ID_DEFAULT)
 {
  sal_strcpy(fn,"/dev/dsp");
  return(open(fn,O_WRONLY));
 }
 else if(id==SEXYAL_ID_UNUSED)
 {
  int x=-1;
  int dspfd;
  do 
  {
   sal_strcpy(fn,"/dev/dsp");
   if(x!=-1)
    sal_strcat(fn,sal_uinttos(x));
   dspfd=open(fn,O_WRONLY|O_NONBLOCK);
   if(dspfd!=-1) break;
   x++;   
  } while(errno!=ENOENT);
  if(dspfd==-1) return(0);
  fcntl(dspfd,F_SETFL,fcntl(dspfd,F_GETFL)&~O_NONBLOCK);
  return(dspfd);
 }
 else
 {
  sal_strcpy(fn,"/dev/dsp");
  sal_strcat(fn,sal_uinttos(id-IDBASE));
  return(open(fn,O_WRONLY));
 }
}

unsigned int Log2(unsigned int value)
{
 int x=0;

 value>>=1;
 while(value)
 {
  value>>=1;
  x++;
 }
 return(x?x:1);
}

SexyAL_device *SexyALI_OSS_Open(uint64_t id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *device;
 int fd;
 unsigned int temp;

 if(!(fd=FODevice(id))) return(0);

 /* Set sample format. */
 /* TODO:  Handle devices with byte order different from native byte order. */
 /* TODO:  Fix fragment size calculation to work well with lower/higher playback rates,
    as reported by OSS.
 */

 if(format->sampformat == SEXYAL_FMT_PCMU8)
  temp=AFMT_U8;
 else if(format->sampformat == SEXYAL_FMT_PCMS8)
  temp=AFMT_S8;
 else if(format->sampformat == SEXYAL_FMT_PCMU16)
  temp=AFMT_U16_LE;
 else 
  temp=AFMT_S16_NE;

 format->byteorder=0;

 ioctl(fd,SNDCTL_DSP_SETFMT,&temp);
 switch(temp)
 {
  case AFMT_U8: format->sampformat = SEXYAL_FMT_PCMU8;break;
  case AFMT_S8: format->sampformat = SEXYAL_FMT_PCMS8;break;
  case AFMT_U16_LE: 
		    #ifndef LSB_FIRST
                    format->byteorder=1;
                    #endif
		    format->sampformat = SEXYAL_FMT_PCMU16;break;
  case AFMT_U16_BE: 
		    #ifdef LSB_FIRST
                    format->byteorder=1;
                    #endif
		    format->sampformat = SEXYAL_FMT_PCMU16;break;
  case AFMT_S16_LE: 
		    #ifndef LSB_FIRST
		    format->byteorder=1;
		    #endif
		    format->sampformat = SEXYAL_FMT_PCMS16;break;
  case AFMT_S16_BE: 
		    #ifdef LSB_FIRST
                    format->byteorder=1;
                    #endif
		    format->sampformat = SEXYAL_FMT_PCMS16;break;
  default: close(fd); return(0);
 }

 /* Set number of channels. */
 temp=format->channels;
 if(ioctl(fd,SNDCTL_DSP_CHANNELS,&temp)==-1)
 {
  close(fd);
  return(0);
 }

 if(temp<1 || temp>2)
 {
  close(fd);
  return(0);
 }

 format->channels=temp;

 /* Set frame rate. */
 temp=format->rate;
 if(ioctl(fd,SNDCTL_DSP_SPEED,&temp)==-1)
 {
  close(fd);
  return(0);
 }
 format->rate=temp;
 device=malloc(sizeof(SexyAL_device));
 sal_memcpy(&device->format,format,sizeof(SexyAL_format));
 sal_memcpy(&device->buffering,buffering,sizeof(SexyAL_buffering));

 if(buffering->fragcount == 0 || buffering->fragsize == 0)
 {
  buffering->fragcount=16;
  buffering->fragsize=64;
 }
 else
 {
  if(buffering->fragsize<32) buffering->fragsize=32;
  if(buffering->fragcount<2) buffering->fragcount=2;
 }
 
 if(buffering->ms)
 {
  int64_t tc;

  //printf("%d\n",buffering->ms);
  
  /* 2*, >>1, |1 for crude rounding(it will always round 0.5 up, so it is a bit biased). */

  tc=2*buffering->ms * format->rate / 1000 / buffering->fragsize;
  //printf("%f\n",(double)buffering->ms * format->rate / 1000 / buffering->fragsize);
  buffering->fragcount=(tc>>1)+(tc&1); //1<<Log2(tc);
  //printf("%d\n",buffering->fragcount);
 }

 temp=Log2(buffering->fragsize*(format->sampformat>>4)*format->channels);
 temp|=buffering->fragcount<<16;
 ioctl(fd,SNDCTL_DSP_SETFRAGMENT,&temp);

 {
  audio_buf_info info;
  ioctl(fd,SNDCTL_DSP_GETOSPACE,&info);
  buffering->fragsize=info.fragsize/(format->sampformat>>4)/format->channels;
  buffering->fragcount=info.fragments;
  buffering->totalsize=buffering->fragsize*buffering->fragcount;
  //printf("Actual:  %d, %d\n",buffering->fragsize,buffering->fragcount);
 }
 device->private=malloc(sizeof(int));
 *(int*)device->private=fd;
 return(device);
}

int SexyALI_OSS_Close(SexyAL_device *device)
{
 if(device)
 {
  if(device->private) 
  {
   close(*(int*)device->private);
   free(device->private);
  }
  free(device);
  return(1);
 }
 return(0);
}

uint32_t SexyALI_OSS_RawWrite(SexyAL_device *device, void *data, uint32_t len)
{
 ssize_t bytes;

 bytes = write(*(int *)device->private,data,len);
 if(bytes <= 0) return(0);			/* FIXME:  What to do on -1? */
 return(bytes);
}

uint32_t SexyALI_OSS_RawCanWrite(SexyAL_device *device)
{
 struct audio_buf_info ai;
 if(!ioctl(*(int *)device->private,SNDCTL_DSP_GETOSPACE,&ai))
  return(ai.bytes);
 else
  return(0);
}

