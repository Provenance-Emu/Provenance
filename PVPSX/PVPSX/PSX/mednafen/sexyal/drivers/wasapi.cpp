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

// TODO: Memory fences and/or atomic types if we want this code to work properly on non-x86 Windows.

#include "../sexyal.h"

#include <windows.h>
#include <windowsx.h>
#include <stdio.h>
#include <string.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <audiopolicy.h>
#include <propidl.h>
#include <algorithm>
#include <assert.h>

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

struct WASWrap
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

 volatile uint8_t* Buffer;
 uint32_t BufferBPF;
 uint32_t BufferReadBytePos;
 uint32_t BufferWriteBytePos;
 uint32_t BufferFrameSize;
 uint32_t BufferFrameSizeSuper;
 uint32_t BufferByteSize;
 uint32_t BufferByteSizeSuper;

 // Ostensibly atomic:
 volatile uint32_t BufferRBC;	// In audio thread: uint32 tc = BufferWriteCounter - BufferReadCounter;
 volatile uint32_t BufferWBC;	// In main thread: uint32 tc = SOMETHING - (BufferWriteCounter - BufferReadCounter);

 volatile char AThreadRunning;
 HANDLE BufferReadEvent;
};


static int Close(SexyAL_device *device);
static int RawCanWrite(SexyAL_device *device, uint32_t *can_write);
static int RawWrite(SexyAL_device *device, const void *data, uint32_t len);

static int Pause(SexyAL_device *device, int state)
{
 return(0);
}

#define TRYHR(n) { HRESULT hrtmp = (n); if(FAILED(hrtmp)) { printf("HRTMP: %u\n", (unsigned int)hrtmp); assert(0); throw(1); } }

static DWORD WINAPI AThreadMain(LPVOID param)
{
 SexyAL_device *dev = (SexyAL_device*)param;
 WASWrap *w = (WASWrap*)dev->private_data;
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
    int32_t to_copy = std::min<int32_t>(w->bfc * w->BufferBPF, w->BufferWBC - w->BufferRBC);
    int32_t max_bs_copy = w->BufferByteSizeSuper - w->BufferReadBytePos;

    assert(to_copy >= 0);

    #if 0
    static int sawie = 0;
    for(int i = 0; i < w->bfc; i++)
    {
     ((uint16_t*)bd)[i * 2 + 0] = sawie;
     ((uint16_t*)bd)[i * 2 + 1] = sawie;
     sawie += 128;
    }
    #else
    memcpy(bd, (void*)(w->Buffer + w->BufferReadBytePos), std::min<int32_t>(to_copy, max_bs_copy));
    memcpy(bd + max_bs_copy, (void*)(w->Buffer), std::max<int32_t>(0, to_copy - max_bs_copy));
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
 WASWrap *w;
 IMMDeviceEnumerator *immdeven = NULL;
 WAVEFORMATEXTENSIBLE wfe;
 HRESULT hr;
 const bool exclusive_mode = true;

 dev = (SexyAL_device *)calloc(1, sizeof(SexyAL_device));
 timeBeginPeriod(1);

 w = (WASWrap *)calloc(1, sizeof(WASWrap));
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

 if(exclusive_mode == false)
 {
  WAVEFORMATEX *mf = NULL;

  TRYHR(w->ac->GetMixFormat(&mf));

#if 0
  printf("wFormatTag: 0x%08x\n", mf->wFormatTag);
  printf("nChannels: 0x%08x\n", mf->nChannels);
  printf("nSamplesPerSec: 0x%08x\n", mf->nSamplesPerSec);
  printf("wBitsPerSample: 0x%08x\n", mf->wBitsPerSample);
  printf("nBlockAlign: 0x%08x\n", mf->nBlockAlign);
  printf("cbSize: 0x%08x\n", mf->cbSize);
  fflush(stdout);
#endif

  memset(&wfe, 0, sizeof(wfe));
  wfe.Format.wFormatTag = WAVE_FORMAT_PCM;
  wfe.Format.nChannels = format->channels;
  wfe.Format.nSamplesPerSec = mf->nSamplesPerSec;
  wfe.Format.wBitsPerSample = 16;
  wfe.Format.nBlockAlign = (wfe.Format.nChannels * wfe.Format.wBitsPerSample) / 8;
  wfe.Format.nAvgBytesPerSec = wfe.Format.nSamplesPerSec * wfe.Format.nBlockAlign;
  wfe.Format.cbSize = 0;

  CoTaskMemFree(mf);

  goto SuppFormatFound;
 }
 else
 {
  const uint32_t rates[7] = { format->rate, 48000, 96000, 192000, 44100, 88200, 22050 };
  const uint32_t chans[4] = { format->channels, 2, 1, 8 };
  const int bits[3] = { 16, 32, 8 };

  for(int chantry = 0; chantry < 4; chantry++)
  {
   for(int ratetry = 0; ratetry < 7; ratetry++)
   {
    for(int bittry = 0; bittry < 3; bittry++)
    {
     for(int vbtry = (bits[bittry] == 32) ? 32 : 16; vbtry >= 16; vbtry--)
     {
      memset(&wfe, 0, sizeof(wfe));

      wfe.Format.wFormatTag = WAVE_FORMAT_PCM;
      wfe.Format.nChannels = chans[chantry];
      wfe.Format.nSamplesPerSec = rates[ratetry];
      wfe.Format.wBitsPerSample = SexyAL_rupow2(bits[bittry]);

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

      if(w->ac->IsFormatSupported(AUDCLNT_SHAREMODE_EXCLUSIVE, (WAVEFORMATEX*)&wfe, NULL) == S_OK)
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
 format->sampformat = ((wfe.Format.wBitsPerSample >> 3) << 4) | 1;

 if(wfe.Format.wBitsPerSample == 32)
  format->sampformat |= 2;

 format->channels = wfe.Format.nChannels;
 format->revbyteorder = false;
 format->noninterleaved = false;

 if(exclusive_mode == false)
 {
  REFERENCE_TIME periodicity;

  TRYHR(w->ac->GetDevicePeriod(&periodicity, NULL));	// Default periodicity for a shared-mode stream.

  TRYHR(w->ac->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_EVENTCALLBACK, periodicity, 0, (WAVEFORMATEX*)&wfe, NULL));

  TRYHR(w->ac->GetBufferSize(&w->bfc));
 }
 else
 {
  REFERENCE_TIME periodicity;

  TRYHR(w->ac->GetDevicePeriod(NULL, &periodicity));

  if(buffering->period_us > 0 && ((int64_t)buffering->period_us * 10) >= periodicity)	// >= rather than > so the else-if doesn't run for < 2ms minimum case
   periodicity = buffering->period_us * 10;
  else if(periodicity < 20000)	// Don't use a periodicity smaller than 2ms unless the user specifically asks for it(handled above).
   periodicity = 20000;

  //printf("PERIODICITYYYY: %d\n", (int)periodicity);

  hr = w->ac->Initialize(AUDCLNT_SHAREMODE_EXCLUSIVE, AUDCLNT_STREAMFLAGS_EVENTCALLBACK, periodicity, periodicity, (WAVEFORMATEX*)&wfe, NULL);
  if(hr == AUDCLNT_E_BUFFER_SIZE_NOT_ALIGNED)
  {
   UINT32 tmp_bs;

   TRYHR(w->ac->GetBufferSize(&tmp_bs));
   periodicity = ((int64_t)tmp_bs * 10000 * 1000 + (wfe.Format.nSamplesPerSec >> 1)) / wfe.Format.nSamplesPerSec;
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

  int32_t dtbfs = (int64_t)(buffering->ms ? buffering->ms : 32) * wfe.Format.nSamplesPerSec / 1000;
  int32_t des_local_bufsize = std::max<int32_t>(dtbfs, w->bfc);
  int32_t des_local_bufsize_super = des_local_bufsize + ((30 * wfe.Format.nSamplesPerSec + 999) / 1000);

  w->BufferRBC = 0;
  w->BufferWBC = 0;
  w->BufferReadBytePos = 0;
  w->BufferWriteBytePos = 0;

  w->Buffer = (uint8_t*)calloc(wfe.Format.wBitsPerSample / 8 * wfe.Format.nChannels, des_local_bufsize_super);
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

static int RawCanWrite(SexyAL_device *device, uint32_t *can_write)
{
 WASWrap *w = (WASWrap *)device->private_data;
 int32_t bytes_in = w->BufferWBC - w->BufferRBC;

 assert(bytes_in >= 0);

 *can_write = std::max<int32_t>(0, (int32_t)w->BufferByteSize - bytes_in);

 return(1);
}

static int RawWrite(SexyAL_device *device, const void *data, uint32_t len)
{
 WASWrap *w = (WASWrap *)device->private_data;
 const uint8_t* data8 = (uint8_t*)data;

 while(len > 0)
 {
  int32_t bytes_in = w->BufferWBC - w->BufferRBC;
  int32_t cwt = w->BufferByteSizeSuper - bytes_in;
  int32_t to_copy = std::min<int32_t>(cwt, len);
  int32_t max_bs_copy = w->BufferByteSizeSuper - w->BufferWriteBytePos;

  //printf("%u - %d %d %d %d --- %08x %08x, %08x\n", len, bytes_in, cwt, to_copy, max_bs_copy, w->BufferWBC, w->BufferRBC, w->BufferByteSizeSuper);
  assert(bytes_in >= 0);
  assert(to_copy >= 0);

  memcpy((void*)(w->Buffer + w->BufferWriteBytePos), data8, std::min<int32_t>(to_copy, max_bs_copy));
  memcpy((void*)(w->Buffer), data8 + max_bs_copy, std::max<int32_t>(0, to_copy - max_bs_copy));

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
  int32_t bytes_in = w->BufferWBC - w->BufferRBC;
  int32_t tcw = (int32_t)w->BufferByteSize - bytes_in;

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
   WASWrap *w = (WASWrap *)device->private_data;

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

