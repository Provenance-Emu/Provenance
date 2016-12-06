/*
 * (C) Gražvydas "notaz" Ignotas, 2009
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

#include <stdlib.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <mmsystem.h>
#include <dsound.h>

#include "dsnd.h"
#include "../lprintf.h"

#define NSEGS 4
#define RELEASE(x) if (x) x->Release();  x=NULL;

static LPDIRECTSOUND DSound;
static LPDIRECTSOUNDBUFFER LoopBuffer;
static LPDIRECTSOUNDNOTIFY DSoundNotify;
static HANDLE seg_played_event;
static int LoopLen, LoopWrite, LoopSeg; // bytes

static int LoopBlank(void)
{
  void *mema=NULL,*memb=NULL;
  DWORD sizea=0,sizeb=0;

  LoopBuffer->Lock(0, LoopLen, &mema,&sizea, &memb,&sizeb, 0);
  
  if (mema) memset(mema,0,sizea);

  LoopBuffer->Unlock(mema,sizea, memb,sizeb);

  return 0;
}

int DSoundInit(HWND wnd_coop, int rate, int stereo, int seg_samples)
{
  DSBUFFERDESC dsbd;
  WAVEFORMATEX wfx;
  DSBPOSITIONNOTIFY notifies[NSEGS];
  int i;

  memset(&dsbd,0,sizeof(dsbd));
  memset(&wfx,0,sizeof(wfx));

  // Make wave format:
  wfx.wFormatTag=WAVE_FORMAT_PCM;
  wfx.nChannels=stereo ? 2 : 1;
  wfx.nSamplesPerSec=rate;
  wfx.wBitsPerSample=16;

  wfx.nBlockAlign=(WORD)((wfx.nChannels*wfx.wBitsPerSample)>>3);
  wfx.nAvgBytesPerSec=wfx.nBlockAlign*wfx.nSamplesPerSec;

  // Create the DirectSound interface:
  DirectSoundCreate(NULL,&DSound,NULL);
  if (DSound==NULL) return 1;

  LoopSeg = seg_samples * 2;
  if (stereo)
    LoopSeg *= 2;

  LoopLen = LoopSeg * NSEGS;

  DSound->SetCooperativeLevel(wnd_coop, DSSCL_PRIORITY);
  dsbd.dwFlags=DSBCAPS_GLOBALFOCUS;  // Play in background
  dsbd.dwFlags|=DSBCAPS_GETCURRENTPOSITION2|DSBCAPS_CTRLPOSITIONNOTIFY;

  // Create the looping buffer:
  dsbd.dwSize=sizeof(dsbd);
  dsbd.dwBufferBytes=LoopLen;
  dsbd.lpwfxFormat=&wfx;

  DSound->CreateSoundBuffer(&dsbd,&LoopBuffer,NULL);
  if (LoopBuffer==NULL) return 1;

  LoopBuffer->QueryInterface(IID_IDirectSoundNotify, (LPVOID*)&DSoundNotify);
  if (DSoundNotify == NULL) {
    lprintf("QueryInterface(IID_IDirectSoundNotify) failed\n");
    goto out;
  }

  seg_played_event = CreateEvent(NULL, 0, 0, NULL);
  if (seg_played_event == NULL)
    goto out;

  for (i = 0; i < NSEGS; i++) {
    notifies[i].dwOffset = i * LoopSeg;
    notifies[i].hEventNotify = seg_played_event;
  }
  i = DSoundNotify->SetNotificationPositions(NSEGS, notifies);
  if (i != DS_OK) {
    lprintf("SetNotificationPositions failed\n");
    goto out;
  }

out:
  LoopBlank();
  LoopBuffer->Play(0, 0, DSBPLAY_LOOPING);
  return 0;
}

void DSoundExit(void)
{
  if (LoopBuffer)
    LoopBuffer->Stop();
  RELEASE(DSoundNotify);
  RELEASE(LoopBuffer)
  RELEASE(DSound)
  CloseHandle(seg_played_event);
  seg_played_event = NULL;
}

static int WriteSeg(const void *buff)
{
  void *mema=NULL,*memb=NULL;
  DWORD sizea=0,sizeb=0;
  int ret;

  // Lock the segment at 'LoopWrite' and copy the next segment in
  ret = LoopBuffer->Lock(LoopWrite, LoopSeg, &mema, &sizea, &memb, &sizeb, 0);
  if (ret != DS_OK)
    lprintf("LoopBuffer->Lock() failed: %i\n", ret);

  if (mema) memcpy(mema,buff,sizea);
//  if (memb) memcpy(memb,DSoundNext+sizea,sizeb);
  if (sizeb != 0) lprintf("sizeb is not 0! (%i)\n", sizeb);

  ret = LoopBuffer->Unlock(mema,sizea, memb, sizeb);
  if (ret != DS_OK)
    lprintf("LoopBuffer->Unlock() failed: %i\n", ret);

  return 0;
}

int DSoundUpdate(const void *buff, int blocking)
{
  DWORD play = 0;
  int pos;

  LoopBuffer->GetCurrentPosition(&play, NULL);
  pos = play;

  // 'LoopWrite' is the next seg in the loop that we want to write
  // First check that the sound 'play' pointer has moved out of it:
  if (blocking) {
    while (LoopWrite <= pos && pos < LoopWrite + LoopSeg) {
      WaitForSingleObject(seg_played_event, 5000);
      LoopBuffer->GetCurrentPosition(&play, NULL);
      pos = play;
    }
  }
  else {
    if (LoopWrite <= pos && pos < LoopWrite + LoopSeg)
      return 1;
  }

  WriteSeg(buff);

  // Advance LoopWrite to next seg:
  LoopWrite += LoopSeg;
  if (LoopWrite + LoopSeg > LoopLen)
    LoopWrite = 0;

  return 0;
}

