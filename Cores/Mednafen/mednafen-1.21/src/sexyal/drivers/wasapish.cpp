/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* wasapish.cpp - Shared-Mode WASAPI Sound Driver
**  Copyright (C) 2014-2017 Mednafen Team
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

#include <windows.h>
#include <windowsx.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <audiopolicy.h>
#include <propidl.h>

static const CLSID LV_CLSID_MMDeviceEnumerator = { 0xbcde0395, 0xe52f, 0x467c, { 0x8e,0x3d, 0xc4,0x57,0x92,0x91,0x69,0x2e} }; //__uuidof(MMDeviceEnumerator);
static const IID LV_IID_IMMDeviceEnumerator = { 0xa95664d2, 0x9614, 0x4f35, {0xa7,0x46, 0xde,0x8d,0xb6,0x36,0x17,0xe6} }; //__uuidof(IMMDeviceEnumerator);
static const IID LV_IID_IAudioClient = { 0x1cb9ad4c, 0xdbfa, 0x4c32, {0xb1,0x78, 0xc2,0xf5,0x68,0xa7,0x03,0xb2} }; //__uuidof(IAudioClient);
static const IID LV_IID_IAudioRenderClient = {0xf294acfc, 0x3146, 0x4483, {0xa7,0xbf, 0xad,0xdc,0xa7,0xc2,0x60,0xe2} }; //__uuidof(IAudioRenderClient);
static const GUID LV_KSDATAFORMAT_SUBTYPE_PCM = { 0x00000001, 0x0000, 0x0010, { 0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71 } };

static const PROPERTYKEY LV_PKEY_Device_FriendlyName = { { 0xa45c254e, 0xdf1c, 0x4efd, { 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0 } }, 14 };
static const PROPERTYKEY LV_PKEY_DeviceInterface_FriendlyName = { { 0x026e516e, 0xb814, 0x414b, { 0x83, 0xcd, 0x85, 0x6d, 0x6f, 0xef, 0x48, 0x22 } }, 2 };

struct SexyAL_WASAPISH
{
 IMMDevice *immdev;
 IAudioClient *ac;
 IAudioRenderClient *arc;
 HMODULE avrt_dll;
 HANDLE WINAPI (*p_AvSetMmThreadCharacteristicsA)(LPCSTR TaskName, LPDWORD TaskIndex);
 BOOL WINAPI (*p_AvRevertMmThreadCharacteristics)(HANDLE);
 HANDLE evt;
 HANDLE AThread;
 UINT32 bfc;

 CRITICAL_SECTION crit;

 uint32 BufferBPF;

 UINT32 recent_pad;
 LARGE_INTEGER recent_time;
 uint32 written_since;

 LARGE_INTEGER qpc_freq;

 volatile char AThreadRunning;
};


static int Close(SexyAL_device *device);
static int RawCanWrite(SexyAL_device *device, uint32 *can_write);
static int RawWrite(SexyAL_device *device, const void *data, uint32 len);

static int Pause(SexyAL_device *device, int state)
{
 return(0);
}

static DWORD WINAPI AThreadMain(LPVOID param)
{
 SexyAL_device *dev = (SexyAL_device*)param;
 SexyAL_WASAPISH *w = (SexyAL_WASAPISH*)dev->private_data;
 DWORD task_index = 0;
 HANDLE avh = NULL;

 SetThreadPriority(w->AThread, THREAD_PRIORITY_TIME_CRITICAL);

 if(w->p_AvSetMmThreadCharacteristicsA)
  avh = w->p_AvSetMmThreadCharacteristicsA("Pro Audio", &task_index);

 while(w->AThreadRunning)
 {
  UINT32 paddie = 0;
  LARGE_INTEGER ct;

  if(WaitForSingleObject(w->evt, 100) == WAIT_OBJECT_0)
  {
   if(QueryPerformanceCounter(&ct) != 0)
   {
    EnterCriticalSection(&w->crit);
    if(w->ac->GetCurrentPadding(&paddie) == S_OK)
    {
     w->recent_pad = paddie;
     w->recent_time = ct;
     w->written_since = 0;
    }
    LeaveCriticalSection(&w->crit);
   }
  }
 }

 if(avh != NULL)
 {
  w->p_AvRevertMmThreadCharacteristics(avh);
  avh = NULL;
 }

 w->AThreadRunning = false;
 return(0);
}

static void Cleanup(SexyAL_device* device)
{
 if(device)
 {
  if(device->private_data)
  {
   SexyAL_WASAPISH *w = (SexyAL_WASAPISH *)device->private_data;

   w->AThreadRunning = false;
   if(w->AThread)
   {
    WaitForSingleObject(w->AThread, INFINITE);
    CloseHandle(w->AThread);
    DeleteCriticalSection(&w->crit);
    w->AThread = NULL;
   }

   if(w->immdev)
   {
    w->immdev->Release();
    w->immdev = NULL;
   }

   if(w->ac)
   {
    w->ac->Release();
    w->ac = NULL;
   }

   if(w->arc)
   {
    w->arc->Release();
    w->arc = NULL;
   }

   if(w->evt != NULL)
   {
    CloseHandle(w->evt);
    w->evt = NULL;
   }

   if(w->avrt_dll != NULL)
   {
    FreeLibrary(w->avrt_dll);
    w->avrt_dll = NULL;
   }

   free(device->private_data);
  }

  timeEndPeriod(1);
  free(device);
 }
}

bool SexyALI_WASAPISH_Avail(void)
{
 IMMDeviceEnumerator *imd = NULL;
 HRESULT hr;

 hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
 if(hr != S_OK && hr != S_FALSE)
  return(false);

 hr = CoCreateInstance(LV_CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, LV_IID_IMMDeviceEnumerator, (void**)&imd);
 if(FAILED(hr))
  return(false);

 imd->Release();

 return(true);
}

#define TRYHR(n) { HRESULT hrtmp = (n); if(FAILED(hrtmp)) { printf(#n " failed: 0x%08x\n", (unsigned)hrtmp); Cleanup(dev); return(NULL); } }
SexyAL_device *SexyALI_WASAPISH_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *dev;
 SexyAL_WASAPISH *w;
 IMMDeviceEnumerator *immdeven = NULL;
 WAVEFORMATEXTENSIBLE wfe;
 HRESULT hr;

 if(!(dev = (SexyAL_device *)calloc(1, sizeof(SexyAL_device))))
 {
  printf("calloc failed.\n");
  return(NULL);
 }
 timeBeginPeriod(1);

 w = (SexyAL_WASAPISH *)calloc(1, sizeof(SexyAL_WASAPISH));
 dev->private_data = w;
 if(!w)
 {
  printf("calloc failed.\n");
  Cleanup(dev);
  return(NULL);
 }

 //
 //
 //
 hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
 if(hr != S_OK && hr != S_FALSE)
 {
  printf("CoInitializeEx() failed: 0x%08x\n", (unsigned)hr);
  Cleanup(dev);
  return(NULL);
 }

 //printf("NOODLES: 0x%08x 0x%08x\n", LV_CLSID_MMDeviceEnumerator.Data1, LV_IID_IMMDeviceEnumerator.Data1);

 TRYHR(CoCreateInstance(LV_CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, LV_IID_IMMDeviceEnumerator, (void**)&immdeven));

 if(id == NULL)
 {
  TRYHR(immdeven->GetDefaultAudioEndpoint(eRender, eConsole, &w->immdev));
 }
 else
 {
  IMMDeviceCollection *devcoll = NULL;
  UINT numdevs = 0;
  wchar_t *id16 = (wchar_t *)calloc(strlen(id) + 1, sizeof(wchar_t));

  w->immdev = NULL;

  MultiByteToWideChar(CP_UTF8, 0, id, -1, id16, strlen(id) + 1);

  TRYHR(immdeven->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &devcoll));
  TRYHR(devcoll->GetCount(&numdevs));

  for(UINT i = 0; i < numdevs && w->immdev == NULL; i++)
  {
   IMMDevice *tmpdev = NULL;
   IPropertyStore *props = NULL;
   PROPVARIANT prop_fname;

   PropVariantInit(&prop_fname);

   TRYHR(devcoll->Item(i, &tmpdev));
   TRYHR(tmpdev->OpenPropertyStore(STGM_READ, &props));
   TRYHR(props->GetValue(LV_PKEY_Device_FriendlyName, &prop_fname));

   printf("Device: %S\n", prop_fname.pwszVal);

   if(!wcscmp(id16, prop_fname.pwszVal))
    w->immdev = tmpdev;
   else
   {
    tmpdev->Release();
    tmpdev = NULL;
   }

   PropVariantClear(&prop_fname);

   if(props != NULL)
   {
    props->Release();
    props = NULL;
   }
  }

  if(id16 != NULL)
  {
   free(id16);
   id16 = NULL;
  }

  if(devcoll != NULL)
  {
   devcoll->Release();
   devcoll = NULL;
  }

  if(w->immdev == NULL)
  {
   puts("Device not found!");
   Cleanup(dev);
   return(NULL);
  }
 }

 TRYHR(w->immdev->Activate(LV_IID_IAudioClient, CLSCTX_ALL, NULL, (void**)&w->ac));

 {
  WAVEFORMATEX *mf = NULL;

  TRYHR(w->ac->GetMixFormat(&mf));

  memcpy(&wfe, mf, std::min<unsigned>(sizeof(WAVEFORMATEXTENSIBLE), sizeof(WAVEFORMATEX) + mf->cbSize));
  if(wfe.Format.cbSize > 22)
   wfe.Format.cbSize = 22;

  wfe.Format.wBitsPerSample = 16;
  wfe.Format.nBlockAlign = (wfe.Format.nChannels * wfe.Format.wBitsPerSample) / 8;
  wfe.Format.nAvgBytesPerSec = wfe.Format.nSamplesPerSec * wfe.Format.nBlockAlign;

  if(wfe.Format.wFormatTag == WAVE_FORMAT_EXTENSIBLE)
  {
   wfe.Samples.wValidBitsPerSample = wfe.Format.wBitsPerSample;
   wfe.SubFormat = LV_KSDATAFORMAT_SUBTYPE_PCM;
  }
  else
  {
   wfe.Format.wFormatTag = WAVE_FORMAT_PCM;
  }

  CoTaskMemFree(mf);
 }

 format->rate = wfe.Format.nSamplesPerSec;
 format->sampformat = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, wfe.Format.wBitsPerSample >> 3, wfe.Format.wBitsPerSample, 0, MDFN_IS_BIGENDIAN);

 format->channels = wfe.Format.nChannels;
 format->noninterleaved = false;

 //
 //
 //
 {
  REFERENCE_TIME raw_ac_latency;
  int32 des_effbuftime = buffering->ms ? buffering->ms : 52;
  int32 des_effbufsize = (int64)des_effbuftime * wfe.Format.nSamplesPerSec / 1000;
  int32 des_realbuftime = des_effbuftime + 40;

  //printf("%u\n", wfe.Format.wFormatTag);
  //printf("%u\n", wfe.Format.nChannels);
  //printf("%u\n", wfe.Format.nSamplesPerSec);

  //printf("%u\n", wfe.Format.wBitsPerSample);
  //printf("%u\n", wfe.Format.nBlockAlign);
  //printf("%u\n", wfe.Format.nAvgBytesPerSec);

  TRYHR(w->ac->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_EVENTCALLBACK, (REFERENCE_TIME)des_realbuftime * 10000, 0, (WAVEFORMATEX*)&wfe, NULL));

  TRYHR(w->ac->GetBufferSize(&w->bfc));

  TRYHR(w->ac->GetStreamLatency(&raw_ac_latency));

  w->BufferBPF = wfe.Format.wBitsPerSample / 8 * wfe.Format.nChannels;

  buffering->buffer_size = std::min<int32>(des_effbufsize, w->bfc);
  buffering->period_size = 0;
  buffering->latency = buffering->buffer_size + (((int64)raw_ac_latency * format->rate + 5000000) / 10000000);
  buffering->bt_gran = 0;
 }

 if(!(w->evt = CreateEvent(NULL, FALSE, FALSE, NULL)))
 {
  printf("Error creating event.\n");
  Cleanup(dev);
  return(NULL);
 }

 if((w->avrt_dll = LoadLibrary("avrt.dll")) != NULL)
 {
  if(!(w->p_AvSetMmThreadCharacteristicsA = (HANDLE WINAPI (*)(LPCSTR, LPDWORD))(GetProcAddress(w->avrt_dll, "AvSetMmThreadCharacteristicsA"))))
  {
   printf("Error getting pointer to AvSetMmThreadCharacteristicsA.\n");
   Cleanup(dev);
   return(NULL);
  }

  if(!(w->p_AvRevertMmThreadCharacteristics = (BOOL WINAPI (*)(HANDLE))(GetProcAddress(w->avrt_dll, "AvRevertMmThreadCharacteristics"))))
  {
   printf("Error getting pointer to AvRevertMmThreadCharacteristics.\n");
   Cleanup(dev);
   return(NULL);
  }
 }

 TRYHR(w->ac->SetEventHandle(w->evt));

 TRYHR(w->ac->GetService(LV_IID_IAudioRenderClient, (void**)&w->arc));

 memcpy(&dev->buffering, buffering, sizeof(SexyAL_buffering));
 memcpy(&dev->format, format, sizeof(SexyAL_format));
 dev->RawWrite = RawWrite;
 dev->RawCanWrite = RawCanWrite;
 dev->RawClose = Close;
 dev->Pause = Pause;

 //
 // Clear buffer.
 //
 {
  BYTE *bd;

  TRYHR(w->arc->GetBuffer(w->bfc, &bd));

  memset(bd, 0, w->bfc * w->BufferBPF);

  w->arc->ReleaseBuffer(w->bfc, 0);
 }

#if 0
 {
  UINT32 paddie = 0;

  printf("buffer_size=%u\n", buffering->buffer_size);
  printf("bfc=%u\n", w->bfc);
  w->ac->GetCurrentPadding(&paddie);
  printf("paddie=%u\n", paddie);
  printf("snoo=%d\n", (int)buffering->buffer_size - paddie);
 }
#endif

 TRYHR(w->ac->Start());

 if(QueryPerformanceFrequency(&w->qpc_freq) == 0)
 {
  printf("QueryPerformanceFrequency() failed.\n");
  Cleanup(dev);
  return(NULL);
 }

 //printf("qpc_freq=%f\n", (double)w->qpc_freq.QuadPart);

 w->AThreadRunning = true;
 if(!(w->AThread = CreateThread(NULL, 0, AThreadMain, dev, CREATE_SUSPENDED, NULL)))
 {
  printf("Error creating thread.\n");
  Cleanup(dev);
  return(NULL);
 }
 InitializeCriticalSection(&w->crit);
 ResumeThread(w->AThread);

 return(dev);
}

static inline int64 MooCowGoesMoo(SexyAL_device *device)
{
 SexyAL_WASAPISH *w = (SexyAL_WASAPISH *)device->private_data;
 UINT32 local_recent_pad;
 LARGE_INTEGER local_recent_time;
 LARGE_INTEGER current_time;
 uint32 local_written_since;
 int64 extra_prec;

 current_time.QuadPart = 0;

 //
 EnterCriticalSection(&w->crit);

 local_recent_pad = w->recent_pad;
 local_recent_time = w->recent_time;
 local_written_since = w->written_since;

 LeaveCriticalSection(&w->crit);
 //

 QueryPerformanceCounter(&current_time);

 if(current_time.QuadPart < local_recent_time.QuadPart)
  current_time.QuadPart = local_recent_time.QuadPart;

#if 1
 extra_prec = (int64)(((double)(current_time.QuadPart - local_recent_time.QuadPart) / w->qpc_freq.QuadPart) * device->format.rate) - local_written_since;
#else
 w->ac->GetCurrentPadding(&local_recent_pad);
 extra_prec = 0;
#endif

 return std::min<int64>(device->buffering.buffer_size, ((int64)device->buffering.buffer_size - local_recent_pad) + extra_prec);
}

static int RawCanWrite(SexyAL_device *device, uint32 *can_write)
{
 SexyAL_WASAPISH *w = (SexyAL_WASAPISH *)device->private_data;

 *can_write = std::max<int64>(0, w->BufferBPF * MooCowGoesMoo(device));

 return(1);
}

static int RawWrite(SexyAL_device *device, const void *data, uint32 len)
{
 SexyAL_WASAPISH *w = (SexyAL_WASAPISH *)device->private_data;
 const uint8* data8 = (uint8*)data;

 while(len > 0)
 {
  HRESULT hr;
  UINT32 paddie = 0;
  UINT32 toget;
  BYTE *bd;

  if(w->ac->GetCurrentPadding(&paddie) != S_OK)
   return(0);

  toget = std::min<uint32>(w->bfc - paddie, (len / w->BufferBPF));

  EnterCriticalSection(&w->crit);
  if((hr = w->arc->GetBuffer(toget, &bd)) == S_OK)
  {
   memcpy(bd, data8, toget * w->BufferBPF);
   w->arc->ReleaseBuffer(toget, 0);
   w->written_since += toget;
  }
  LeaveCriticalSection(&w->crit);

  if(hr != S_OK)
   return(0);

  data8 += toget * w->BufferBPF;
  len -= toget * w->BufferBPF;

  if(len > 0)
   Sleep(1);
 }

 for(;;)
 {
  int64 milk = MooCowGoesMoo(device);

  if(milk >= -(int64)(device->format.rate / 2000))
   break;

  Sleep(std::max<int64>(1, -milk * 1000 / device->format.rate));
 }

 return(1);
}



static int Close(SexyAL_device *device)
{
 if(device)
 {
  Cleanup(device);
  return(1);
 }
 return(0);
}

