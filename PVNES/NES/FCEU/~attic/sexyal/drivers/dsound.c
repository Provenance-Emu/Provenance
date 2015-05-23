#include <windows.h>
#include <windowsx.h>
#include <stdio.h>

#undef  WINNT
#define NONAMELESSUNION

#define DIRECTSOUND_VERSION  0x0300

#include <dsound.h>
#include "../sexyal.h"

typedef struct 
{
	LPDIRECTSOUND ppDS;		/* DirectSound interface object. */
	LPDIRECTSOUNDBUFFER ppbuf;	/* Primary buffer. */
	LPDIRECTSOUNDBUFFER ppbufsec;	/* Secondary buffer. */
	LPDIRECTSOUNDBUFFER ppbufw;	/* Buffer to do writes to. */
	WAVEFORMATEX wf;		/* Format of the primary and secondary buffers. */
	long DSBufferSize;		/* The size of the buffer that we can write to, in bytes. */

	long BufHowMuch;		/* How many bytes we should try to buffer. */
	DWORD ToWritePos;		/* Position which the next write to the buffer
					   should write to.
					*/
} DSFobby;

static void CheckStatus(DSFobby *tmp)
{
 DWORD status=0;

 IDirectSoundBuffer_GetStatus(tmp->ppbufw, &status);
 if(status&DSBSTATUS_BUFFERLOST)
  IDirectSoundBuffer_Restore(tmp->ppbufw);

 if(!(status&DSBSTATUS_PLAYING))
 {
  tmp->ToWritePos=0;
  IDirectSoundBuffer_SetCurrentPosition(tmp->ppbufsec,0);
  IDirectSoundBuffer_SetFormat(tmp->ppbufw,&tmp->wf);
  IDirectSoundBuffer_Play(tmp->ppbufw,0,0,DSBPLAY_LOOPING);
 }
}

SexyAL_device *SexyALI_DSound_Open(uint64_t id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *dev;
 DSFobby *fobby;

 DSBUFFERDESC DSBufferDesc;
 DSCAPS dscaps;
 DSBCAPS dsbcaps;

 dev=malloc(sizeof(SexyAL_device));
 fobby=malloc(sizeof(DSFobby));
 memset(fobby,0,sizeof(DSFobby));

 memset(&fobby->wf,0,sizeof(WAVEFORMATEX));
 fobby->wf.wFormatTag = WAVE_FORMAT_PCM;
 fobby->wf.nChannels = format->channels;
 fobby->wf.nSamplesPerSec = format->rate;

 if(DirectSoundCreate(0,&fobby->ppDS,0) != DS_OK)
 {
  free(dev);
  free(fobby);
  return(0);
 }

 {
  //HWND hWnd = GetForegroundWindow();    // Ugly.
  //if(!hWnd)
  //{ hWnd=GetDesktopWindow(); exit(1); }
  HWND hWnd;
  hWnd=GetDesktopWindow();
  IDirectSound_SetCooperativeLevel(fobby->ppDS,hWnd,DSSCL_PRIORITY);
 }
 memset(&dscaps,0x00,sizeof(dscaps));
 dscaps.dwSize=sizeof(dscaps);
 IDirectSound_GetCaps(fobby->ppDS,&dscaps);
 IDirectSound_Compact(fobby->ppDS);

 /* Create primary buffer */
 memset(&DSBufferDesc,0x00,sizeof(DSBUFFERDESC));
 DSBufferDesc.dwSize=sizeof(DSBufferDesc);
 DSBufferDesc.dwFlags=DSBCAPS_PRIMARYBUFFER;

 if(IDirectSound_CreateSoundBuffer(fobby->ppDS,&DSBufferDesc,&fobby->ppbuf,0) != DS_OK)
 {
  IDirectSound_Release(fobby->ppDS);
  free(dev);
  free(fobby);
  return(0);
 }

 /* Set primary buffer format. */
 if(format->sampformat == SEXYAL_FMT_PCMU8)
  fobby->wf.wBitsPerSample=8;
 else // if(format->sampformat == SEXYAL_FMT_PCMS16)
 {
  fobby->wf.wBitsPerSample=16;
  format->sampformat=SEXYAL_FMT_PCMS16;
 }

 fobby->wf.nBlockAlign=fobby->wf.wBitsPerSample>>3;
 fobby->wf.nAvgBytesPerSec=fobby->wf.nSamplesPerSec*fobby->wf.nBlockAlign;
 if(IDirectSoundBuffer_SetFormat(fobby->ppbuf,&fobby->wf) != DS_OK)
 {
  IDirectSound_Release(fobby->ppbuf);
  IDirectSound_Release(fobby->ppDS);
  free(dev);
  free(fobby);
  return(0);
 }

 /* Create secondary sound buffer */
 IDirectSoundBuffer_GetFormat(fobby->ppbuf,&fobby->wf,sizeof(WAVEFORMATEX),0);
 memset(&DSBufferDesc,0x00,sizeof(DSBUFFERDESC));
 DSBufferDesc.dwSize=sizeof(DSBufferDesc);
 DSBufferDesc.dwFlags=DSBCAPS_GETCURRENTPOSITION2;
 DSBufferDesc.dwFlags|=DSBCAPS_GLOBALFOCUS;
 DSBufferDesc.dwBufferBytes=65536;
 DSBufferDesc.lpwfxFormat=&fobby->wf;
 if(IDirectSound_CreateSoundBuffer(fobby->ppDS, &DSBufferDesc, &fobby->ppbufsec, 0) != DS_OK)
 {
  IDirectSound_Release(fobby->ppbuf);
  IDirectSound_Release(fobby->ppDS);
  free(dev);
  free(fobby);
  return(0);
 }

 fobby->DSBufferSize=65536;
 IDirectSoundBuffer_SetCurrentPosition(fobby->ppbufsec,0);
 fobby->ppbufw=fobby->ppbufsec;

 memcpy(&dev->format,format,sizeof(SexyAL_format));

 if(!buffering->ms)
  buffering->ms=53;

 buffering->totalsize=(int64_t)format->rate*buffering->ms/1000;
 fobby->BufHowMuch=buffering->totalsize* format->channels * (format->sampformat>>4);
 //printf("%d\n",fobby->BufHowMuch);
 //fflush(stdout);

 dev->private=fobby;
 timeBeginPeriod(1);

 return(dev);
}

uint32_t SexyALI_DSound_RawCanWrite(SexyAL_device *device)
{
 DSFobby *tmp=device->private;
 DWORD CurWritePos,CurPlayPos=0;
 CheckStatus(tmp);

 CurWritePos=0;

 if(IDirectSoundBuffer_GetCurrentPosition(tmp->ppbufw,&CurPlayPos,&CurWritePos)==DS_OK)
 {
   //FCEU_DispMessage("%d",CurWritePos-CurPlayPos);
 }
 CurWritePos=(CurPlayPos+tmp->BufHowMuch)%tmp->DSBufferSize;

 /*  If the current write pos is >= half the buffer size less than the to write pos,
     assume DirectSound has wrapped around.
 */

 if(((int32_t)tmp->ToWritePos-(int32_t)CurWritePos) >= (tmp->DSBufferSize/2))
 {
  CurWritePos+=tmp->DSBufferSize;
  //printf("Fixit: %d,%d,%d\n",tmp->ToWritePos,CurWritePos,CurWritePos-tmp->DSBufferSize);
 }
 if(tmp->ToWritePos<CurWritePos)
 {
  int32_t howmuch=(int32_t)CurWritePos-(int32_t)tmp->ToWritePos;
  if(howmuch > tmp->BufHowMuch)      /* Oopsie.  Severe buffer overflow... */
  {
   tmp->ToWritePos=CurWritePos%tmp->DSBufferSize;
   //IDirectSoundBuffer_Stop(tmp->ppbufsec);
   //IDirectSoundBuffer_SetCurrentPosition(tmp->ppbufsec,tmp->ToWritePos);
   //puts("Oops");
   //fflush(stdout);
   //return(0);
  }
  return(CurWritePos-tmp->ToWritePos);
 }
 else
  return(0);
}

int SexyALI_DSound_RawWrite(SexyAL_device *device, void *data, uint32_t len)
{
 DSFobby *tmp=device->private;
// uint32_t cw;

 //printf("Pre: %d\n",SexyALI_DSound_RawCanWrite(device));
 //fflush(stdout);

 CheckStatus(tmp);
 /* In this block, we write as much data as we can, then we write
    the rest of it in >=1ms chunks.
 */
 while(len)
 {
  VOID *LockPtr[2]={0,0};
  DWORD LockLen[2]={0,0};
  int32_t curlen;

  while(!(curlen=SexyALI_DSound_RawCanWrite(device)))
  {   
   Sleep(1);
  }

  if(curlen>len) curlen=len;

  if(DS_OK == IDirectSoundBuffer_Lock(tmp->ppbufw,tmp->ToWritePos,curlen,&LockPtr[0],&LockLen[0],&LockPtr[1],&LockLen[1],0))
  {
  }

  if(LockPtr[1] != 0 && LockPtr[1] != LockPtr[0])
  {
   memcpy(LockPtr[0],data,LockLen[0]);
   memcpy(LockPtr[1],data+LockLen[0],len-LockLen[0]);
  }
  else if(LockPtr[0])
  {
   memcpy(LockPtr[0],data,curlen);
  }
  IDirectSoundBuffer_Unlock(tmp->ppbufw,LockPtr[0],LockLen[0],LockPtr[1],LockLen[1]);
  tmp->ToWritePos=(tmp->ToWritePos+curlen)%tmp->DSBufferSize;

  len-=curlen;
  (uint8_t *) data+=curlen;
  if(len)
   Sleep(1);
 } // end while(len) loop


 return(1);
}



int SexyALI_DSound_Close(SexyAL_device *device)
{
 if(device)
 {
  if(device->private)
  {
   DSFobby *tmp=device->private;
   if(tmp->ppbufsec)
   {
    IDirectSoundBuffer_Stop(tmp->ppbufsec);
    IDirectSoundBuffer_Release(tmp->ppbufsec);
   }
   if(tmp->ppbuf)
   {
    IDirectSoundBuffer_Stop(tmp->ppbuf);
    IDirectSoundBuffer_Release(tmp->ppbuf);
   }
   if(tmp->ppDS)
   {
    IDirectSound_Release(tmp->ppDS);
   }
   free(device->private);
  }
  free(device);
  timeEndPeriod(1);
  return(1);
 }
 return(0);
}

