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

#include "main.h"
#include <stdio.h>
#include <string.h>
#include <math.h>

#include "sound.h"

#include <mednafen/sexyal/sexyal.h>

static SexyAL *Interface = NULL;
static SexyAL_device *Output = NULL;
static SexyAL_format format;
static SexyAL_buffering buffering;

static int16 *EmuModBuffer = NULL;
static int32 EmuModBufferSize = 0;	// In frames.

static double SoundRate = 0;
static bool NeedReInit = false;

bool Sound_NeedReInit(void)
{
 return NeedReInit;
}

double Sound_GetRate(void)
{
 return(SoundRate);
}

uint32 Sound_CanWrite(void)
{
 if(!Output)
  return(0);

 return(Output->CanWrite(Output));
}

void Sound_Write(int16 *Buffer, int Count)
{
 if(!Output)
  return;

 if(!Output->Write(Output, Buffer, Count))
 {
  //
  // TODO; We need to take assert()'s out of the wasapi and wasapish code before we can safely enable this
  //
  //NeedReInit = true;
  //printf("Output->Write failure? %d\n", Count);
 }
}

void Sound_WriteSilence(int ms)
{
 unsigned int frames = (uint64)format.rate * ms / 1000;
 int16 SBuffer[frames * format.channels];

 memset(SBuffer, 0, sizeof(SBuffer));
 Output->Write(Output, SBuffer, frames);
}

#if 0
static bool RunSexyALTest(SexyAL *interface, SexyAL_buffering *buffering, const char *device, int driver_type)
{
 static const int to_format[9] = 
 {
  SEXYAL_FMT_PCMU8,
  SEXYAL_FMT_PCMS8,
  SEXYAL_FMT_PCMU16,
  SEXYAL_FMT_PCMS16,

  SEXYAL_FMT_PCMU24,
  SEXYAL_FMT_PCMS24,
  SEXYAL_FMT_PCMU32,
  SEXYAL_FMT_PCMS32,

  SEXYAL_FMT_PCMFLOAT
 };

 static const char *to_format_name[9] = 
 {
  "8-bit unsigned",
  "8-bit signed",
  "16-bit unsigned",
  "16-bit signed",
  "24-bit unsigned",
  "24-bit signed",
  "32-bit unsigned",
  "32-bit signed",
  "float"
 };

 // TODO: byte order format conversion.
 // TODO: source format.
 const int rate = 48000;
 const int numframes = (rate / 2 + 1) &~ 1;

 for(int src_channels = 1; src_channels <= 2; src_channels++)
 {
  for(int dest_channels = 1; dest_channels <= 2; dest_channels++)
  {
   //for(int src_format = 0; src_format < 9; src_format++)
   int src_format = 3;
   {
    for(int dest_format = 0; dest_format < 9; dest_format++)
    {
     printf("Source Format: %s, Source Channels: %d --- Dest Format: %s, Dest Channels: %d\n\n", to_format_name[src_format], src_channels, to_format_name[dest_format], dest_channels);

     memset(&format,0,sizeof(format));

     Interface = (SexyAL *)SexyAL_Init(0);
     DriverTypes = Interface->EnumerateTypes(Interface);

     format.sampformat = to_format[dest_format];
     format.channels = dest_channels;
     format.revbyteorder = 0;
     format.rate = rate;

     buffering->buffer_size = 0;
     buffering->period_size = 0;
     buffering->latency = 0;
     buffering->bt_gran = 0;

     if(!(Output=Interface->Open(Interface, device, &format, buffering, driver_type)))
     {
      MDFND_PrintError(_("Error opening a sound device."));
      Interface->Destroy(Interface);
      Interface=0;
      return(0);
     }

     if(format.sampformat != to_format[dest_format])
      printf("Warning: Could not set desired device format.\n");

     if(format.channels != dest_channels)
      printf("Warning: Could not set desired device channel count.\n");

     if(format.rate != rate)
      printf("Warning: Could not set desired device rate.\n");

     format.sampformat = to_format[src_format];
     format.channels = src_channels;
     format.revbyteorder = 0;
     format.rate = rate;

     Output->SetConvert(Output, &format);

     if(to_format[src_format] == SEXYAL_FMT_PCMS16)
     {
      int16 samples[numframes * src_channels];

      for(int i = 0; i < numframes; i++)
      {
       int16 sval = 4095 * sin((double)i * 440 * M_PI * 2 / rate);
       
       for(int ch = 0; ch < src_channels; ch++)
        samples[i * src_channels + ch] = sval;
      }
      // Write half in one go, the rest in small chunks.
      if(!Output->Write(Output, samples, numframes / 2))
	printf("Write count error 0\n");

      for(int i = numframes / 2; i < numframes; i += 100)
      {
       int32 towrite = numframes - i;
 
       if(towrite > 100)
        towrite = 100;

       if(!Output->Write(Output, samples + i * src_channels, towrite))
        printf("Write count error 1\n");
      }
     }
     Output->Close(Output);
     Interface->Destroy(Interface);
     sleep(1);
    }
   }
  }
 }
}
#endif

bool Sound_Init(MDFNGI *gi)
{
 SexyAL_DriverInfo CurDriver;

 NeedReInit = false;
 SoundRate = 0;

 memset(&format, 0, sizeof(format));
 memset(&buffering, 0, sizeof(buffering));

 Interface = new SexyAL();

 format.sampformat = SEXYAL_FMT_PCMS16;

 assert(gi->soundchan);
 format.channels = gi->soundchan;

 format.revbyteorder = 0;
 format.noninterleaved = false;
 format.rate = MDFN_GetSettingUI("sound.rate");

 buffering.ms = MDFN_GetSettingUI("sound.buffer_time");

 if(!buffering.ms)
 {
  buffering.overhead_kludge = true;
  buffering.ms = 7 + floor(0.5 + 1.5 * 1000.0 / gi->fps * (256 * 65536));
 }
 else
  buffering.overhead_kludge = false;

 buffering.period_us = MDFN_GetSettingUI("sound.period_time");

 std::string zedevice = MDFN_GetSettingS("sound.device");
 std::string zedriver = MDFN_GetSettingS("sound.driver");

 MDFNI_printf(_("\nInitializing sound...\n"));
 MDFN_indent(1);

 if(!Interface->FindDriver(&CurDriver, zedriver.c_str()))
 {
  std::vector<SexyAL_DriverInfo> DriverTypes = Interface->GetDriverList();

  MDFN_printf(_("\nUnknown sound driver \"%s\".  Compiled-in sound drivers:\n"), zedriver.c_str());

  MDFN_indent(2);
  for(unsigned x = 0; x < DriverTypes.size(); x++)
  {
   MDFN_printf("%s\n", DriverTypes[x].short_name);
  }
  MDFN_indent(-2);
  MDFN_printf("\n");

  delete Interface;
  Interface = NULL;

  MDFN_indent(-1);
  return(FALSE);
 }

 if(!strcasecmp(zedevice.c_str(), "default"))
  MDFNI_printf(_("Using \"%s\" audio driver with SexyAL's default device selection."), CurDriver.name);
 else
  MDFNI_printf(_("Using \"%s\" audio driver with device \"%s\":"), CurDriver.name, zedevice.c_str());
 MDFN_indent(1);

 //RunSexyALTest(Interface, &buffering, zedevice.c_str(), CurDriver.type);
 //exit(1);
 if(!(Output=Interface->Open(zedevice.c_str(), &format, &buffering, CurDriver.type)))
 {
  MDFND_PrintError(_("Error opening a sound device."));

  delete Interface;
  Interface = NULL;
  MDFN_indent(-2);
  return(FALSE);
 }

 if(format.rate < 22050 || format.rate > 192000)
 {
  MDFND_PrintError(_("Set rate is out of range [22050-192000]"));
  Sound_Kill();
  MDFN_indent(-2);
  return(FALSE);
 }
 MDFNI_printf(_("\nBits: %u%s\nRate: %u\nChannels: %u%s\nByte order: CPU %s\nBuffer size: %u sample frames(%f ms)\n"), (format.sampformat>>4)*8, (format.sampformat == SEXYAL_FMT_PCMFLOAT) ? _(" (floating-point)") : "",format.rate,format.channels,format.noninterleaved ? _(" (non-interleaved) ") : "", format.revbyteorder?"Reversed":"Native", buffering.buffer_size, (double)buffering.buffer_size * 1000 / format.rate);
 MDFNI_printf(_("Latency: %u sample frames(%f ms)\n"), buffering.latency, (double)buffering.latency * 1000 / format.rate);

 if(buffering.period_size)
 {
  //int64_t pt_test_result = ((int64_t)buffering.period_size * (1000 * 1000) / format.rate);
  int64_t bt_test_result = ((int64_t)(buffering.bt_gran ? buffering.bt_gran : buffering.period_size) * (1000 * 1000) / format.rate);
  MDFNI_printf(_("Period size: %u sample frames(%f ms)\n"), buffering.period_size, (double)buffering.period_size * 1000 / format.rate);

  if(bt_test_result > 5333)
  {
   MDFN_indent(1);

   if(!buffering.bt_gran)
    MDFN_printf(_("Warning: Period time is too large(it should be <= ~5.333ms).  Video will appear very jerky.\n"));
   else
    MDFN_printf(_("Warning: Buffer update timing granularity is too large(%f; it should be <= ~5.333ms).  Video will appear very jerky.\n"), (double)buffering.bt_gran * 1000 / format.rate);
   MDFN_indent(-1);
  }
 }

 format.sampformat = SEXYAL_FMT_PCMS16;
 format.channels = gi->soundchan?gi->soundchan:1;
 format.revbyteorder = 0;
 format.noninterleaved = false;
 //format.rate=gi->soundrate?gi->soundrate:soundrate;

 Output->SetConvert(Output, &format);

 EmuModBufferSize = (500 * format.rate + 999) / 1000;
 EmuModBuffer = (int16 *)calloc(sizeof(int16) * format.channels, EmuModBufferSize);

 SoundRate = format.rate;
 MDFN_indent(-2);

 return(1);
}

bool Sound_Kill(void)
{
 SoundRate = 0;

 if(EmuModBuffer)
 {
  free(EmuModBuffer);
  EmuModBuffer = NULL;

  EmuModBufferSize = 0;
 }

 if(Output)
  Output->Close(Output);

 if(Interface)
 {
  delete Interface;
  Interface = NULL;
 }

 if(!Output)
  return(FALSE);

 Output = NULL;

 return(TRUE);
}


int16 *Sound_GetEmuModBuffer(int32 *max_size_bytes)
{
 *max_size_bytes = EmuModBufferSize;

 return(EmuModBuffer);
}
