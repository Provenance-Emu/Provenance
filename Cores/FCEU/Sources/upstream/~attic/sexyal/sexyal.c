#include <stdlib.h>
#include <string.h>
#include "sexyal.h"
#include "convert.h"

#ifdef WIN32

#else
#include "drivers/oss.h"
#endif

static uint32_t FtoB(const SexyAL_format *format, uint32_t frames)
{
 return(frames*format->channels*(format->sampformat>>4));
}
/*
static uint32_t BtoF(const SexyAL_format *format, uint32_t bytes)
{
 return(bytes / (format->channels * (format->sampformat>>4)));
}
*/
static uint32_t CanWrite(SexyAL_device *device)
{
 uint32_t bytes,frames;

 #ifdef WIN32
 bytes=SexyALI_DSound_RawCanWrite(device);
 #else
 bytes=SexyALI_OSS_RawCanWrite(device);
 #endif
 frames=bytes / device->format.channels / (device->format.sampformat>>4);

 return(frames);
}

static uint32_t Write(SexyAL_device *device, void *data, uint32_t frames)
{
 uint8_t buffer[2048*4];

 while(frames)
 {
  int32_t tmp;

  tmp=frames;
  if(tmp>2048) 
  { 
   tmp=2048;
   frames-=2048;
  }
  else frames-=tmp;

  SexiALI_Convert(&device->srcformat, &device->format, buffer, data, tmp);
  //printf("%02x, %02x, %02x\n", device->srcformat.sampformat, device->srcformat.byteorder, device->srcformat.channels);
  //printf("buffer: %d\n",buffer[0]);
  /* FIXME:  Return the actual number of frame written. It should always equal
             the number of frames requested to be written, except in cases of sound device
	     failures.  
  */
  #ifdef WIN32
  SexyALI_DSound_RawWrite(device,buffer,FtoB(&device->format,tmp));
  #else
  SexyALI_OSS_RawWrite(device,buffer,FtoB(&device->format,tmp));
  #endif
 }
 return(frames);
}

static int Close(SexyAL_device *device)
{
 #ifdef WIN32
 return(SexyALI_DSound_Close(device));
 #else
 return(SexyALI_OSS_Close(device));
 #endif
}

int SetConvert(struct __SexyAL_device *device, SexyAL_format *format)
{
 memcpy(&device->srcformat,format,sizeof(SexyAL_format));
 return(1);
}

static SexyAL_device *Open(SexyAL *iface, uint64_t id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *ret;

 #ifdef WIN32
 if(!(ret=SexyALI_DSound_Open(id,format,buffering))) return(0);
 #else
 if(!(ret=SexyALI_OSS_Open(id,format,buffering))) return(0);
 #endif
 
 ret->Write=Write;
 ret->Close=Close;
 ret->CanWrite=CanWrite;
 ret->SetConvert=SetConvert;
 return(ret);
}

void Destroy(SexyAL *iface)
{
 free(iface);
}

void *SexyAL_Init(int version)
{
 SexyAL *iface;
 if(!version != 1) return(0);

 iface=malloc(sizeof(SexyAL));

 iface->Open=Open;
 iface->Destroy=Destroy;
 return((void *)iface);
}
