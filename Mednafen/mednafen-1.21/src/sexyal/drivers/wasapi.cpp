/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* wasapi.cpp - Exclusive-Mode WASAPI Sound Driver
**  Copyright (C) 2013-2017 Mednafen Team
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

// TODO: Memory fences and/or atomic types if we want this code to work properly on non-x86 Windows.

#include "../sexyal.h"

#include <windows.h>
#include <windowsx.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <audiopolicy.h>
#include <propidl.h>

//#undef _WIN32_WINNT
//#define _WIN32_WINNT 0x600
//#include <avrt.h>

static const CLSID LV_CLSID_MMDeviceEnumerator = { 0xbcde0395, 0xe52f, 0x467c, { 0x8e,0x3d, 0xc4,0x57,0x92,0x91,0x69,0x2e} }; //__uuidof(MMDeviceEnumerator);
static const IID LV_IID_IMMDeviceEnumerator = { 0xa95664d2, 0x9614, 0x4f35, {0xa7,0x46, 0xde,0x8d,0xb6,0x36,0x17,0xe6} }; //__uuidof(IMMDeviceEnumerator);
static const IID LV_IID_IAudioClient = { 0x1cb9ad4c, 0xdbfa, 0x4c32, {0xb1,0x78, 0xc2,0xf5,0x68,0xa7,0x03,0xb2} }; //__uuidof(IAudioClient);
static const IID LV_IID_IAudioRenderClient = {0xf294acfc, 0x3146, 0x4483, {0xa7,0xbf, 0xad,0xdc,0xa7,0xc2,0x60,0xe2} }; //__uuidof(IAudioRenderClient);
static const GUID LV_KSDATAFORMAT_SUBTYPE_PCM = { 0x00000001, 0x0000, 0x0010, { 0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71 } };

static const PROPERTYKEY LV_PKEY_Device_FriendlyName = { { 0xa45c254e, 0xdf1c, 0x4efd, { 0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0 } }, 14 };
static const PROPERTYKEY LV_PKEY_DeviceInterface_FriendlyName = { { 0x026e516e, 0xb814, 0x414b, { 0x83, 0xcd, 0x85, 0x6d, 0x6f, 0xef, 0x48, 0x22 } }, 2 };

struct SexyAL_WASAPI
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

 volatile uint8* Buffer;
 uint32 BufferBPF;
 uint32 BufferReadBytePos;
 uint32 BufferWriteBytePos;
 uint32 BufferFrameSize;
 uint32 BufferFrameSizeSuper;
 uint32 BufferByteSize;
 uint32 BufferByteSizeSuper;

 // Ostensibly atomic:
 volatile uint32 BufferRBC;	// In audio thread: uint32 tc = BufferWriteCounter - BufferReadCounter;
 volatile uint32 BufferWBC;	// In main thread: uint32 tc = SOMETHING - (BufferWriteCounter - BufferReadCounter);

 volatile char AThreadRunning;
 HANDLE BufferReadEvent;
};


static int Close(SexyAL_device *device);
static int RawCanWrite(SexyAL_device *device, uint32 *can_write);
static int RawWrite(SexyAL_device *device, const void *data, uint32 len);

static int Pause(SexyAL_device *device, int state)
{
 return(0);
}

#define TRYHR(n) { HRESULT hrtmp = (n); if(FAILED(hrtmp)) { printf("HRTMP: %u\n", (unsigned int)hrtmp); assert(0); throw(1); } }

static DWORD WINAPI AThreadMain(LPVOID param)
{
 SexyAL_device *dev = (SexyAL_device*)param;
 SexyAL_WASAPI *w = (SexyAL_WASAPI*)dev->private_data;
 BYTE *bd;
 DWORD task_index = 0;
 HANDLE avh;

 if((avh = w->p_AvSetMmThreadCharacteristicsA("Pro Audio", &task_index)) == 0)
 {
  abort();
 }

 if(w->arc->GetBuffer(w->bfc, &bd) != S_OK)
 {
  abort();
  goto Cleanup;
 }

 memset(bd, 0, w->bfc * w->BufferBPF);
 w->arc->ReleaseBuffer(w->bfc, 0);

 if(w->ac->Start() != S_OK)
 {
  abort();
  goto Cleanup;
 }

 while(w->AThreadRunning)
 {
  HRESULT tmp;
  if(WaitForSingleObject(w->evt, 100) != WAIT_OBJECT_0)
  {
   HRESULT st;

   st = w->ac->Start();

   if(st == AUDCLNT_E_DEVICE_INVALIDATED)
    goto Cleanup;

   //printf("HuhBluh? 0x%08x\n", st);

   //continue;
  }

  UINT32 paddie = 0;
  unsigned itercount = 1;

  // Necessary(confounded MSDN documentation suggests otherwise. :/), at least on an old PCI X-Fi card, to avoid nastiness on sound buffer underrun.
  //
  // Note: Before, we tried calling GetBuffer() with a length of w->bfc * 2 - paddie, but that would randomly cause WASAPI and/or the sound card
  // driver to flip out and break.  So to play it safe, only call it with a length of w->bfc, and call it multiple times if necessary.
  if((tmp = w->ac->GetCurrentPadding(&paddie)) == S_OK)
  {
   if(paddie < w->bfc)
   {
    //printf("BRAINS IN THE CUPBOARD!!!  %u\n", paddie);
    itercount = 2;
   }
  }
  //else
  // printf("HARSHIE: 0x%08x\n", tmp);

  while(itercount--)
  {
   // FIXME: Proper integer typecasting for std::min stuff.
   if((tmp = w->arc->GetBuffer(w->bfc, &bd)) == S_OK)
   {
    int32 to_copy = std::min<int32>(w->bfc * w->BufferBPF, w->BufferWBC - w->BufferRBC);
    int32 max_bs_copy = w->BufferByteSizeSuper - w->BufferReadBytePos;

    assert(to_copy >= 0);

    #if 0
    static int sawie = 0;
    for(int i = 0; i < w->bfc; i++)
    {
     ((uint16*)bd)[i * 2 + 0] = sawie;
     ((uint16*)bd)[i * 2 + 1] = sawie;
     sawie += 128;
    }
    #else
    memcpy(bd, (void*)(w->Buffer + w->BufferReadBytePos), std::min<int32>(to_copy, max_bs_copy));
    memcpy(bd + max_bs_copy, (void*)(w->Buffer), std::max<int32>(0, to_copy - max_bs_copy));
    memset(bd + to_copy, 0, (w->bfc * w->BufferBPF) - to_copy);
    #endif
    w->arc->ReleaseBuffer(w->bfc, 0);

    w->BufferReadBytePos = (w->BufferReadBytePos + to_copy) % w->BufferByteSizeSuper;
    w->BufferRBC += to_copy;
    SetEvent(w->BufferReadEvent);	// Call AFTER adding to BufferRBC.
   }
   //else
   // printf("GOOBLES: %u 0x%08x\n", w->bfc, tmp);
  }
 }

 Cleanup: ;
 w->ac->Stop();

 if(avh != NULL)
 {
  w->p_AvRevertMmThreadCharacteristics(avh);
  avh = NULL;
 }

 w->AThreadRunning = false;
 return(0);
}

bool SexyALI_WASAPI_Avail(void)
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

SexyAL_device *SexyALI_WASAPI_Open(const char *id, SexyAL_format *format, SexyAL_buffering *buffering)
{
 SexyAL_device *dev;
 SexyAL_WASAPI *w;
 IMMDeviceEnumerator *immdeven = NULL;
 WAVEFORMATEXTENSIBLE wfe;
 HRESULT hr;

 dev = (SexyAL_device *)calloc(1, sizeof(SexyAL_device));
 timeBeginPeriod(1);

 w = (SexyAL_WASAPI *)calloc(1, sizeof(SexyAL_WASAPI));
 dev->private_data = w;
 //
 //
 //
 hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
 if(hr != S_OK && hr != S_FALSE)
  assert(0);

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
   return(NULL);
  }
 }

 TRYHR(w->immdev->Activate(LV_IID_IAudioClient, CLSCTX_ALL, NULL, (void**)&w->ac));

 {
  const uint32 rates[] = { format->rate, 48000, 96000, 192000, 44100, 88200, 64000, 32000, 22050 };
  const uint32 chans[] = { format->channels, 2, 8, 1 };
  const uint32 bits[] = { 8 * SAMPFORMAT_BYTES(format->sampformat), 16, 32, 24, 8 };

  for(unsigned chantry = 0; chantry < sizeof(chans) / sizeof(chans[0]); chantry++)
  {
   for(unsigned ratetry = 0; ratetry < sizeof(rates) / sizeof(rates[0]); ratetry++)
   {
    for(unsigned bittry = 0; bittry < sizeof(bits) / sizeof(bits[0]); bittry++)
    {
     for(unsigned vbtry = std::max<unsigned>(16, bits[bittry]); vbtry >= 16; vbtry--)
     {
      memset(&wfe, 0, sizeof(wfe));

      wfe.Format.wFormatTag = WAVE_FORMAT_PCM;
      wfe.Format.nChannels = chans[chantry];
      wfe.Format.nSamplesPerSec = rates[ratetry];
      wfe.Format.wBitsPerSample = bits[bittry];
      wfe.Samples.wValidBitsPerSample = bits[bittry];	// Simplifies SAMPFORMAT_MAKE()

      wfe.Format.nBlockAlign = (wfe.Format.nChannels * wfe.Format.wBitsPerSample) / 8;
      wfe.Format.nAvgBytesPerSec = wfe.Format.nSamplesPerSec * wfe.Format.nBlockAlign;
      wfe.Format.cbSize = 0;

      if(bits[bittry] > 16)
      {
       wfe.Format.wFormatTag = WAVE_FORMAT_EXTENSIBLE;
       wfe.Format.cbSize = sizeof(WAVEFORMATEXTENSIBLE) - sizeof(WAVEFORMATEX);

       wfe.Samples.wValidBitsPerSample = vbtry;

       if(wfe.Format.nChannels >= 2)
        wfe.dwChannelMask = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
       else
        wfe.dwChannelMask = SPEAKER_FRONT_CENTER;

       wfe.SubFormat = LV_KSDATAFORMAT_SUBTYPE_PCM;
      }

      if(w->ac->IsFormatSupported(AUDCLNT_SHAREMODE_EXCLUSIVE, (const WAVEFORMATEX*)&wfe, NULL) == S_OK)
      {
       goto SuppFormatFound;
      }
     }
    }
   }
  }
 }

 // No supported format found. :(
 assert(0); //throw(1);

 SuppFormatFound: ;

 format->rate = wfe.Format.nSamplesPerSec;
 format->sampformat = SAMPFORMAT_MAKE(SEXYAL_ENC_PCM_SINT, wfe.Format.wBitsPerSample >> 3, wfe.Samples.wValidBitsPerSample, wfe.Format.wBitsPerSample - wfe.Samples.wValidBitsPerSample, MDFN_IS_BIGENDIAN);

 format->channels = wfe.Format.nChannels;
 format->noninterleaved = false;

 {
  REFERENCE_TIME periodicity;

  TRYHR(w->ac->GetDevicePeriod(NULL, &periodicity));

  if(buffering->period_us > 0 && ((int64)buffering->period_us * 10) >= periodicity)	// >= rather than > so the else-if doesn't run for < 2ms minimum case
   periodicity = buffering->period_us * 10;
  else if(periodicity < 20000)	// Don't use a periodicity smaller than 2ms unless the user specifically asks for it(handled above).
   periodicity = 20000;

  //printf("PERIODICITYYYY: %d\n", (int)periodicity);

  hr = w->ac->Initialize(AUDCLNT_SHAREMODE_EXCLUSIVE, AUDCLNT_STREAMFLAGS_EVENTCALLBACK, periodicity, periodicity, (WAVEFORMATEX*)&wfe, NULL);
  if(hr == AUDCLNT_E_BUFFER_SIZE_NOT_ALIGNED)
  {
   UINT32 tmp_bs;

   TRYHR(w->ac->GetBufferSize(&tmp_bs));
   periodicity = ((int64)tmp_bs * 10000 * 1000 + (wfe.Format.nSamplesPerSec >> 1)) / wfe.Format.nSamplesPerSec;
   //printf("PERIODICITYYYY(AGAIAIAAAIN): %d\n", (int)periodicity);

   w->ac->Release();
   w->ac = NULL;

   TRYHR(w->immdev->Activate(LV_IID_IAudioClient, CLSCTX_ALL, NULL, (void**)&w->ac));
   TRYHR(w->ac->Initialize(AUDCLNT_SHAREMODE_EXCLUSIVE, AUDCLNT_STREAMFLAGS_EVENTCALLBACK, periodicity, periodicity, (WAVEFORMATEX*)&wfe, NULL));
  }
  else
  {
   TRYHR(hr);
  }
 }

 //
 //
 //
 {
  REFERENCE_TIME raw_ac_latency;

  TRYHR(w->ac->GetBufferSize(&w->bfc));
  TRYHR(w->ac->GetStreamLatency(&raw_ac_latency));

  //printf("MOOMOOOOO: %u\n", (unsigned)raw_ac_latency);

  int32 dtbfs = (int64)(buffering->ms ? buffering->ms : 32) * wfe.Format.nSamplesPerSec / 1000;
  int32 des_local_bufsize = std::max<int32>(dtbfs, w->bfc);
  int32 des_local_bufsize_super = des_local_bufsize + ((30 * wfe.Format.nSamplesPerSec + 999) / 1000);

  w->BufferRBC = 0;
  w->BufferWBC = 0;
  w->BufferReadBytePos = 0;
  w->BufferWriteBytePos = 0;

  w->Buffer = (uint8*)calloc(wfe.Format.wBitsPerSample / 8 * wfe.Format.nChannels, des_local_bufsize_super);
  w->BufferBPF = wfe.Format.wBitsPerSample / 8 * wfe.Format.nChannels;
  w->BufferFrameSize = des_local_bufsize;
  w->BufferFrameSizeSuper = des_local_bufsize_super;
  w->BufferByteSize = w->BufferFrameSize * w->BufferBPF;
  w->BufferByteSizeSuper = w->BufferFrameSizeSuper * w->BufferBPF;

  buffering->buffer_size = des_local_bufsize;
  buffering->period_size = w->bfc;
  buffering->latency = des_local_bufsize + w->bfc;
  buffering->bt_gran = 0;
 }

 w->evt = CreateEvent(NULL, FALSE, FALSE, NULL);
 if(w->evt == NULL)
  assert(0); //throw(1);

 w->BufferReadEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
 if(w->evt == NULL)
  assert(0);

 if(!(w->avrt_dll = LoadLibrary("avrt.dll")))
  assert(0);

 if(!(w->p_AvSetMmThreadCharacteristicsA = (HANDLE WINAPI (*)(LPCSTR, LPDWORD))(GetProcAddress(w->avrt_dll, "AvSetMmThreadCharacteristicsA"))))
  assert(0);

 if(!(w->p_AvRevertMmThreadCharacteristics = (BOOL WINAPI (*)(HANDLE))(GetProcAddress(w->avrt_dll, "AvRevertMmThreadCharacteristics"))))
  assert(0);

 TRYHR(w->ac->SetEventHandle(w->evt));

 TRYHR(w->ac->GetService(LV_IID_IAudioRenderClient, (void**)&w->arc));

 memcpy(&dev->buffering, buffering, sizeof(SexyAL_buffering));
 memcpy(&dev->format, format, sizeof(SexyAL_format));
 dev->RawWrite = RawWrite;
 dev->RawCanWrite = RawCanWrite;
 dev->RawClose = Close;
 dev->Pause = Pause;

 w->AThreadRunning = true;
 if(!(w->AThread = CreateThread(NULL, 0, AThreadMain, dev, 0, NULL)))
  assert(0);

 return(dev);
}

static int RawCanWrite(SexyAL_device *device, uint32 *can_write)
{
 SexyAL_WASAPI *w = (SexyAL_WASAPI *)device->private_data;
 int32 bytes_in = w->BufferWBC - w->BufferRBC;

 assert(bytes_in >= 0);

 *can_write = std::max<int32>(0, (int32)w->BufferByteSize - bytes_in);

 return(1);
}

static int RawWrite(SexyAL_device *device, const void *data, uint32 len)
{
 SexyAL_WASAPI *w = (SexyAL_WASAPI *)device->private_data;
 const uint8* data8 = (uint8*)data;

 while(len > 0)
 {
  int32 bytes_in = w->BufferWBC - w->BufferRBC;
  int32 cwt = w->BufferByteSizeSuper - bytes_in;
  int32 to_copy = std::min<int32>(cwt, len);
  int32 max_bs_copy = w->BufferByteSizeSuper - w->BufferWriteBytePos;

  //printf("%u - %d %d %d %d --- %08x %08x, %08x\n", len, bytes_in, cwt, to_copy, max_bs_copy, w->BufferWBC, w->BufferRBC, w->BufferByteSizeSuper);
  assert(bytes_in >= 0);
  assert(to_copy >= 0);

  memcpy((void*)(w->Buffer + w->BufferWriteBytePos), data8, std::min<int32>(to_copy, max_bs_copy));
  memcpy((void*)(w->Buffer), data8 + max_bs_copy, std::max<int32>(0, to_copy - max_bs_copy));

  w->BufferWriteBytePos = (w->BufferWriteBytePos + to_copy) % w->BufferByteSizeSuper;
  w->BufferWBC += to_copy;
  data8 += to_copy;
  len -= to_copy;

  if(len)
  {
   if(!w->AThreadRunning)
    return(0);

   WaitForSingleObject(w->BufferReadEvent, 20);
  }
 }

 for(;;)
 {
  int32 bytes_in = w->BufferWBC - w->BufferRBC;
  int32 tcw = (int32)w->BufferByteSize - bytes_in;

  assert(bytes_in >= 0);

  if(tcw >= 0)
   break;

  if(!w->AThreadRunning)
   return(0);

  WaitForSingleObject(w->BufferReadEvent, 20);
 }

 return(1);
}



static int Close(SexyAL_device *device)
{
 if(device)
 {
  if(device->private_data)
  {
   SexyAL_WASAPI *w = (SexyAL_WASAPI *)device->private_data;

   w->AThreadRunning = false;
   if(w->AThread)
   {
    WaitForSingleObject(w->AThread, INFINITE);
    CloseHandle(w->AThread);
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

   if(w->BufferReadEvent != NULL)
   {
    CloseHandle(w->BufferReadEvent);
    w->BufferReadEvent = NULL;
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

  return(1);
 }
 return(0);
}

