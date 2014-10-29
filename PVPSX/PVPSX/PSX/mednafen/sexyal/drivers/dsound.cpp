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

#include <windows.h>
#include <windowsx.h>
#include <stdio.h>

#undef  WINNT
#define NONAMELESSUNION

#define DIRECTSOUND_VERSION  0x0300

#include <dsound.h>

typedef struct 
{
	LPDIRECTSOUND ppDS;		/* DirectSound interface object. */
	LPDIRECTSOUNDBUFFER ppbuf;	/* Primary buffer. */
	LPDIRECTSOUNDBUFFER ppbufsec;	/* Secondary buffer. */
	LPDIRECTSOUNDBUFFER ppbufw;	/* Buffer to do writes to. */
	WAVEFORMATEX wf;		/* Format of the primary and secondary buffers. */
	long DSBufferSize;		/* The size of the buffer that we can write to, in bytes. */

	long BufHowMuch;		/* How many bytes of buffering we sync/wait to. */
	long BufHowMuchOBM;		/* How many bytes of buffering we actually do(at least temporarily). */

	DWORD ToWritePos;		/* Position which the next write to the buffer
					   should write to.
					*/
} DSFobby;


static int Close(SexyAL_device *device);
static int RawCanWrite(SexyAL_device *device, uint32_t *can_write);
static int RawWrite(SexyAL_device *device, const void *data, uint32_t len);

static int CheckStatus(DSFobby *tmp)
{
 DWORD status = 0;

 if(IDirectSoundBuffer_GetStatus(tmp->ppbufw, &status) != DS_OK)
  return(0);

 if(status & DSBSTATUS_BUFFERLOST)
  IDirectSoundBuffer_Restore(tmp->ppbufw);

 if(!(status&DSBSTATUS_PLAYING))
 {
  tmp->ToWritePos = 0;
  IDirectSoundBuffer_SetCurrentPosition(tmp->ppbufsec, 0);
  IDirectSoundBuffer_SetFormat(tmp->ppbufw, &tmp->wf);
  IDirectSoundBuffer_Play(tmp->ppbufw, 0, 0, DSBPLAY_LOOPING);
 }

 return(1);
}

static int Pause(SexyAL_device *device, int state)
{
 return(0);
}



SexyAL_device *SexyALI_DSound_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *dev;
 DSFobby *fobby;

 DSBUFFERDESC DSBufferDesc;
 DSCAPS dscaps;
 //DSBCAPS dsbcaps;

 dev = (SexyAL_device *)calloc(1, sizeof(SexyAL_device));
 fobby = (DSFobby *)calloc(1, sizeof(DSFobby));

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
  hWnd = GetDesktopWindow();
  IDirectSound_SetCooperativeLevel(fobby->ppDS, hWnd, DSSCL_PRIORITY);
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

 fobby->wf.nBlockAlign = fobby->wf.nChannels * (fobby->wf.wBitsPerSample / 8);
 fobby->wf.nAvgBytesPerSec=fobby->wf.nSamplesPerSec*fobby->wf.nBlockAlign;
 if(IDirectSoundBuffer_SetFormat(fobby->ppbuf,&fobby->wf) != DS_OK)
 {
  IDirectSound_Release(fobby->ppbuf);
  IDirectSound_Release(fobby->ppDS);
  free(dev);
  free(fobby);
  return(0);
 }

 //
 // Buffers yay!
 //
 if(!buffering->ms)
 {
  buffering->ms = 52;
 }
 else if(buffering->overhead_kludge)
 {
  buffering->ms += 20;
 }

 buffering->buffer_size = (int64_t)format->rate * buffering->ms / 1000;

 fobby->BufHowMuch = buffering->buffer_size * format->channels * (format->sampformat >> 4);
 fobby->BufHowMuchOBM = fobby->BufHowMuch + ((30 * format->rate + 999) / 1000) * format->channels * (format->sampformat >> 4);

 buffering->latency = buffering->buffer_size; // TODO:  Add estimated WaveOut latency when using an emulated DirectSound device.
 buffering->period_size = 0;

 /* Create secondary sound buffer */
 {
  int64_t padding_extra = (((int64_t)format->rate * 200 + 999) / 1000) * format->channels * (format->sampformat >> 4);

  if(padding_extra < (fobby->BufHowMuchOBM * 2))
   padding_extra = fobby->BufHowMuchOBM * 2;

  fobby->DSBufferSize = SexyAL_rupow2(fobby->BufHowMuchOBM + padding_extra);

  //printf("Bufferbytesizenomnom: %u --- BufHowMuch: %u, BufHowMuchOBM: %u\n", fobby->DSBufferSize, fobby->BufHowMuch, fobby->BufHowMuchOBM);

  if(fobby->DSBufferSize < 65536)
   fobby->DSBufferSize = 65536;
 }
 IDirectSoundBuffer_GetFormat(fobby->ppbuf,&fobby->wf,sizeof(WAVEFORMATEX),0);
 memset(&DSBufferDesc,0x00,sizeof(DSBUFFERDESC));
 DSBufferDesc.dwSize=sizeof(DSBufferDesc);
 DSBufferDesc.dwFlags=DSBCAPS_GETCURRENTPOSITION2;
 DSBufferDesc.dwFlags|=DSBCAPS_GLOBALFOCUS;
 DSBufferDesc.dwBufferBytes = fobby->DSBufferSize;
 DSBufferDesc.lpwfxFormat=&fobby->wf;
 if(IDirectSound_CreateSoundBuffer(fobby->ppDS, &DSBufferDesc, &fobby->ppbufsec, 0) != DS_OK)
 {
  IDirectSound_Release(fobby->ppbuf);
  IDirectSound_Release(fobby->ppDS);
  free(dev);
  free(fobby);
  return(0);
 }

 IDirectSoundBuffer_SetCurrentPosition(fobby->ppbufsec,0);
 fobby->ppbufw=fobby->ppbufsec;

 memcpy(&dev->format, format, sizeof(SexyAL_format));

 //printf("%d\n",fobby->BufHowMuch);
 //fflush(stdout);

 dev->private_data=fobby;
 timeBeginPeriod(1);
 
 dev->RawWrite = RawWrite;
 dev->RawCanWrite = RawCanWrite;
 dev->RawClose = Close;
 dev->Pause = Pause;

 return(dev);
}

static int RawCanWriteInternal(SexyAL_device *device, uint32_t *can_write, const bool OBM, const bool signal_nega = false)
{
 DSFobby *tmp = (DSFobby *)device->private_data;
 DWORD CurWritePos, CurPlayPos = 0;

 if(!CheckStatus(tmp))
  return(0);

 CurWritePos=0;

 if(IDirectSoundBuffer_GetCurrentPosition(tmp->ppbufw,&CurPlayPos,&CurWritePos)==DS_OK)
 {
   //MDFN_DispMessage("%d",CurWritePos-CurPlayPos);
 }

 CurWritePos = (CurPlayPos + tmp->BufHowMuchOBM) % tmp->DSBufferSize;

 /*  If the current write pos is >= half the buffer size less than the to write pos,
     assume DirectSound has wrapped around.
 */
 if(((int32_t)tmp->ToWritePos-(int32_t)CurWritePos) >= (tmp->DSBufferSize/2))
 {
  CurWritePos += tmp->DSBufferSize;
  //printf("Fixit: %d,%d,%d\n",tmp->ToWritePos,CurWritePos,CurWritePos-tmp->DSBufferSize);
 }

 if(tmp->ToWritePos < CurWritePos)
 {
  int32_t howmuch = (int32_t)CurWritePos - (int32_t)tmp->ToWritePos;

  //printf(" HM: %u\n", howmuch);

  // Handle (probably severe) buffer-underflow condition.
  if(howmuch > tmp->BufHowMuchOBM)
  {
   //printf("Underrun: %d %d --- %d --- CWP=%d, TWP=%d\n", howmuch, tmp->BufHowMuchOBM, OBM, CurWritePos, tmp->ToWritePos);

   howmuch = tmp->BufHowMuchOBM;
   tmp->ToWritePos = (CurWritePos + tmp->DSBufferSize - tmp->BufHowMuchOBM) % tmp->DSBufferSize;
  }

  if(false == OBM)
   howmuch -= tmp->BufHowMuchOBM - tmp->BufHowMuch;

  if(howmuch < 0)
  {
   if(signal_nega)
    howmuch = ~0U;
   else
    howmuch = 0;
  }

  *can_write = howmuch;
 }
 else
  *can_write = 0;

 return(1);
}

static int RawCanWrite(SexyAL_device *device, uint32_t *can_write)
{
 return RawCanWriteInternal(device, can_write, false);
}

static int RawWrite(SexyAL_device *device, const void *data, uint32_t len)
{
 DSFobby *tmp = (DSFobby *)device->private_data;

 //printf("Pre: %d\n",SexyALI_DSound_RawCanWrite(device));
 //fflush(stdout);

 if(!CheckStatus(tmp))
  return(0);

 /* In this block, we write as much data as we can, then we write
    the rest of it in >=1ms chunks.
 */
 while(len)
 {
  VOID *LockPtr[2]={0,0};
  DWORD LockLen[2]={0,0};
  uint32_t curlen;
  int rcw_rv;

  while((rcw_rv = RawCanWriteInternal(device, &curlen, true)) && !curlen)
  {
   //puts("WAITER1");
   Sleep(1);
  }

  // If RawCanWrite() failed, RawWrite must fail~
  if(!rcw_rv)
   return(0);

  if(curlen > len)
   curlen = len;

  if(IDirectSoundBuffer_Lock(tmp->ppbufw, tmp->ToWritePos, curlen, &LockPtr[0], &LockLen[0], &LockPtr[1], &LockLen[1], 0) != DS_OK)
  {
   return(0);
  }

  if(LockPtr[1] != 0 && LockPtr[1] != LockPtr[0])
  {
   memcpy(LockPtr[0], data, LockLen[0]);
   memcpy(LockPtr[1], (uint8_t *)data + LockLen[0], len - LockLen[0]);
  }
  else if(LockPtr[0])
  {
   memcpy(LockPtr[0], data, curlen);
  }

  IDirectSoundBuffer_Unlock(tmp->ppbufw, LockPtr[0], LockLen[0], LockPtr[1], LockLen[1]);

  tmp->ToWritePos = (tmp->ToWritePos + curlen) % tmp->DSBufferSize;

  len -= curlen;
  data = (uint8_t *)data + curlen;

  if(len)
   Sleep(1);
 } // end while(len) loop


 // Synchronize to effective buffer size.
 {
  uint32_t curlen;
  int rcw_rv;

  while((rcw_rv = RawCanWriteInternal(device, &curlen, false, true)) && (curlen == ~0U))
  {
   //puts("WAITER2");
   Sleep(1);
  }
  // If RawCanWrite() failed, RawWrite must fail~
  if(!rcw_rv)
   return(0);
 }


 return(1);
}



static int Close(SexyAL_device *device)
{
 if(device)
 {
  if(device->private_data)
  {
   DSFobby *tmp = (DSFobby *)device->private_data;
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
   free(device->private_data);
  }
  free(device);
  timeEndPeriod(1);
  return(1);
 }
 return(0);
}

