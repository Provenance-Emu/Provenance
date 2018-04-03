/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* cdplay.cpp:
**  Copyright (C) 2010-2016 Mednafen Team
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

// TODO: Clear Q subchannel data on disc change and manual track change, add Q subchannel mode have variable(s).

#include <mednafen/mednafen.h>
#include <mednafen/cdrom/cdromif.h>
#include <trio/trio.h>

using namespace CDUtility;

#include <mednafen/resampler/resampler.h>

extern MDFNGI EmulatedCDPlay;

namespace MDFN_IEN_CDPLAY
{

static std::vector<float> sin_lut; //[65536];
static SpeexResamplerState *resampler = NULL;

static uint8 *controller_ptr;
static uint8 last_controller;

enum
{
 PLAYMODE_PAUSE = -1,
 PLAYMODE_STOP = 0,
 PLAYMODE_PLAY = 1,
 PLAYMODE_SCAN_FORWARD = 2,
 PLAYMODE_SCAN_REVERSE = 3,
};

static int PlayMode;
static int32 PlaySector;
static int16 CDDABuffer[588 * 2];

static int16 ResampBuffer[588 * 2][2];	// Resampler input buffer, * 2 for resampler leftovers
static uint32 ResampBufferPos;
static uint32 PrevRate;

static std::vector<CDIF *> *cdifs;

static uint32 CurrentATLI;

struct AudioTrackInfo
{
 inline AudioTrackInfo(unsigned disc_, int32 track_, int32 lba_, int32 final_lba_)
 {
  disc = disc_;
  track = track_;
  lba = lba_;
  final_lba = final_lba_;
 }

 unsigned disc;
 int32 track;
 int32 lba;
 int32 final_lba;	// Inclusive.
};

static std::vector<AudioTrackInfo> AudioTrackList;

static void InitLUT(void);

static void LoadCD(std::vector<CDIF *> *CDInterfaces)
{
 cdifs = CDInterfaces;

 AudioTrackList.clear();

 for(unsigned disc = 0; disc < cdifs->size(); disc++)
 {
  TOC toc;

  (*cdifs)[disc]->ReadTOC(&toc);

  for(int32 track = toc.first_track; track <= toc.last_track; track++)
  {
   if(toc.tracks[track].valid && !(toc.tracks[track].control & 0x4))
   {
    AudioTrackList.push_back(AudioTrackInfo(disc, track, toc.tracks[track].lba, toc.tracks[(track == toc.last_track) ? 100 : track + 1].lba - 1));
   }
  }
 }

 if(!AudioTrackList.size())
  throw MDFN_Error(0, _("Audio track doesn't exist."));

 CurrentATLI = 0;
 PlaySector = AudioTrackList[CurrentATLI].lba;
 PlayMode = PLAYMODE_PLAY;   //STOP;

 {
  int err;
  resampler = speex_resampler_init(2, 44100, (int)48000, 5, &err);
  PrevRate = 48000;
 }
 ResampBufferPos = 0;

 InitLUT();

 //
 //
 EmulatedCDPlay.RMD->Drives.clear();
 EmulatedCDPlay.RMD->DrivesDefaults.clear();
 EmulatedCDPlay.RMD->MediaTypes.clear();
 EmulatedCDPlay.RMD->Media.clear();
}

static bool TestMagicCD(std::vector<CDIF *> *CDInterfaces)
{
 CDUtility::TOC magic_toc;

 for(unsigned i = 0; i < CDInterfaces->size(); i++)
 {
  (*CDInterfaces)[i]->ReadTOC(&magic_toc);

  // If any audio track is found, return true.
  for(int32 track = magic_toc.first_track; track <= magic_toc.last_track; track++)
   if(magic_toc.tracks[track].valid && !(magic_toc.tracks[track].control & 0x4))
    return(true);
 }

 return(false);
}

static void CloseGame(void)
{
 if(resampler)
 {
  speex_resampler_destroy(resampler);
  resampler = NULL;
 }
 sin_lut.resize(0);
}

static uint8 SubQBuf[3][0xC];
//static bool SubQHave[3];
static uint8 SubQBuf_LastValid[0xC];

static void GenSubQFromSubPW(uint8 *SubPWBuf)
{
 uint8 sq[0xC];

 memset(sq, 0, 0xC);

 for(int i = 0; i < 96; i++)
  sq[i >> 3] |= ((SubPWBuf[i] & 0x40) >> 6) << (7 - (i & 7));

 if(!subq_check_checksum(sq))
  puts("SubQ checksum error!");
 else
 {
  uint8 adr = sq[0] & 0xF;

  if(adr <= 0x3)
   memcpy(SubQBuf[adr], sq, 0xC);

  memcpy(SubQBuf_LastValid, sq, 0xC);
 }
}

static void InitLUT(void)
{
 sin_lut.resize(65536);

 for(int i = 0; i < 65536; i++)
  sin_lut[i] = sin((double)i * M_PI * 2 / 65536);
}

static void Emulate(EmulateSpecStruct *espec)
{
 uint8 sector_buffer[2352 + 96];
 uint8 new_controller = *controller_ptr;

 espec->MasterCycles = 588;

 //printf("%d %d\n", toc.tracks[100].lba, AudioTrackList[AudioTrackList.size() - 1] + 1);

 if(PlaySector < AudioTrackList[CurrentATLI].lba)	// Reverse-scanning handling.
 {
  if(CurrentATLI > 0)
  {
   CurrentATLI--;
   PlaySector = AudioTrackList[CurrentATLI].final_lba;
  }
  else
  {
   CurrentATLI = 0;
   PlayMode = PLAYMODE_STOP;
   PlaySector = AudioTrackList[CurrentATLI].lba;
  }
 }
 else if(PlaySector > AudioTrackList[CurrentATLI].final_lba)
 {
  if((CurrentATLI + 1) < AudioTrackList.size())
   CurrentATLI++;
  else
  {
   CurrentATLI = 0;
   PlayMode = PLAYMODE_STOP;
  }

  PlaySector = AudioTrackList[CurrentATLI].lba;
 }

 if(PlayMode == PLAYMODE_STOP || PlayMode == PLAYMODE_PAUSE)
 {
  //memset(CDDABuffer, 0, sizeof(CDDABuffer));
  for(int i = 0; i < 588; i++)
  {
   ResampBuffer[ResampBufferPos][0] = 0;
   ResampBuffer[ResampBufferPos][1] = 0;
   ResampBufferPos++;
  }
 }
 else
 {
  (*cdifs)[AudioTrackList[CurrentATLI].disc]->ReadRawSector(sector_buffer, PlaySector);
  GenSubQFromSubPW(sector_buffer + 2352);

  for(int i = 0; i < 588 * 2; i++)
  {
   CDDABuffer[i] = MDFN_de16lsb(&sector_buffer[i * sizeof(int16)]);

   ResampBuffer[ResampBufferPos + (i >> 1)][i & 1] = (CDDABuffer[i] * 3 + 2) >> 2;
  }
  ResampBufferPos += 588;
 }

 if(espec->SoundBuf)
 {
  if((int)espec->SoundRate == 44100)
  {
   memcpy(espec->SoundBuf, ResampBuffer, ResampBufferPos * 2 * sizeof(int16));
   espec->SoundBufSize = ResampBufferPos;
   ResampBufferPos = 0;
  }
  else
  {
   spx_uint32_t in_len;
   spx_uint32_t out_len;

   if(PrevRate != (uint32)espec->SoundRate)
   {
    speex_resampler_set_rate(resampler, 44100, (uint32)espec->SoundRate);
    PrevRate = (uint32)espec->SoundRate;
   }

   in_len = ResampBufferPos;
   out_len = 524288;	// FIXME, real size.

   speex_resampler_process_interleaved_int(resampler, (const spx_int16_t *)ResampBuffer, &in_len, (spx_int16_t *)espec->SoundBuf, &out_len);

   assert(in_len <= ResampBufferPos);

   if((ResampBufferPos - in_len) > 0)
    memmove(ResampBuffer, ResampBuffer + in_len, (ResampBufferPos - in_len) * sizeof(int16) * 2);

   ResampBufferPos -= in_len;

   //printf("%d\n", ResampBufferPos);
   assert((ResampBufferPos + 588) <= (sizeof(ResampBuffer) / sizeof(int16) / 2));

   espec->SoundBufSize = out_len;
  }
 }
 else
  ResampBufferPos = 0;

// for(int i = 0; i < espec->SoundBufSize * 2; i++)
//  espec->SoundBuf[i] = (rand() & 0x7FFF) - 0x4000;	//(rand() * 192) >> 8

 if(!espec->skip)
 {
  char tmpbuf[256];
  const MDFN_PixelFormat &format = espec->surface->format;
  uint32 *pixels = espec->surface->pixels;
  uint32 text_color = format.MakeColor(0xE0, 0xE0, 0xE0);
  uint32 text_shadow_color = format.MakeColor(0x20, 0x20, 0x20);
  uint32 wf_color = format.MakeColor(0xE0, 0x00, 0xE0);
  uint32 cur_sector = PlaySector;

  espec->DisplayRect.x = 0;
  espec->DisplayRect.y = 0;

  espec->DisplayRect.w = 192;
  espec->DisplayRect.h = 144;

  espec->surface->Fill(0, 0, 0, 0);

  if(MDFN_GetSettingB("cdplay.visualization"))
  {
   static const int lobes = 2;
   static const int oversample_shift = 5;	// Don't increase without resolving integer overflow issues.
   static const int oversample = 1 << oversample_shift;

   for(int i = 0; i < 588; i++)
   { 
    const float rawp_adjust = 1.0 / (1 * M_PI * 2 / 65536);
    const float unip_samp = (float)(((CDDABuffer[i * 2 + 0] + CDDABuffer[i * 2 + 1]) >> 1) + 32768) / 65536;
    const float next_unip_samp = (float)(((CDDABuffer[(i * 2 + 2) % 1176] + CDDABuffer[(i * 2 + 3) % 1176]) >> 1) + 32768) / 65536;
    const float sample_inc = (next_unip_samp - unip_samp) / oversample;
    float sample = (unip_samp - 0.5) / 2;

    for(int osi = 0; osi < oversample; osi++, sample += sample_inc)
    {
     unsigned x;	// Make sure x and y are unsigned, else we need to change our in-bounds if() check.
     unsigned y;
     float x_raw, y_raw;
     float x_raw2, y_raw2;
     float x_raw_prime, y_raw_prime;
     int32 theta_i = (uint32)65536 * (i * oversample + osi) / (oversample * 588);

     float radius = sin_lut[(lobes * theta_i) & 0xFFFF];
     float radius2 = sin_lut[(lobes * (theta_i + 1)) & 0xFFFF];

     x_raw = radius * sin_lut[(16384 + theta_i) & 0xFFFF];
     y_raw = radius * sin_lut[theta_i & 0xFFFF];

     x_raw2 = radius2 * sin_lut[(16384 + theta_i + 1) & 0xFFFF];
     y_raw2 = radius2 * sin_lut[(theta_i + 1) & 0xFFFF];

     // Approximation, of course.
     x_raw_prime = (x_raw2 - x_raw) * rawp_adjust;
     y_raw_prime = (y_raw2 - y_raw) * rawp_adjust;

     x_raw_prime = x_raw_prime / (float)sqrt(x_raw_prime * x_raw_prime + y_raw_prime * y_raw_prime);
     y_raw_prime = y_raw_prime / (float)sqrt(x_raw_prime * x_raw_prime + y_raw_prime * y_raw_prime);

     x_raw += sample * y_raw_prime;
     y_raw += sample * -x_raw_prime;

     x = 96 + 60 * x_raw;
     y = 72 + 60 * y_raw;

     if(x < 192 && y < 144)
      pixels[x + y * espec->surface->pitch32] = wf_color;
    }
   }
  }

  int32 text_y = 0;

  {
   TOC toc;
   const char *disctype_string = "";

   (*cdifs)[AudioTrackList[CurrentATLI].disc]->ReadTOC(&toc);

   if(toc.disc_type == 0x10)
    disctype_string = "(CD-i)";
   else if(toc.disc_type == 0x20)
    disctype_string = "(CD-ROM XA)";
   else if(toc.disc_type != 0x00)
    disctype_string = "(unknown type)";

   trio_snprintf(tmpbuf, 256, "Disc: %u/%u %s", AudioTrackList[CurrentATLI].disc + 1, (unsigned)cdifs->size(), disctype_string);
   DrawTextShadow(espec->surface, 0, text_y, tmpbuf, text_color, text_shadow_color, MDFN_FONT_6x13_12x13);
   text_y += 13;

   trio_snprintf(tmpbuf, 256, "Track: %d/%d", AudioTrackList[CurrentATLI].track, toc.last_track);
   DrawTextShadow(espec->surface, 0, text_y, tmpbuf, text_color, text_shadow_color, MDFN_FONT_6x13_12x13);
   text_y += 13;

   trio_snprintf(tmpbuf, 256, "Sector: %d/%d", cur_sector, toc.tracks[100].lba - 1);
   DrawTextShadow(espec->surface, 0, text_y, tmpbuf, text_color, text_shadow_color, MDFN_FONT_6x13_12x13);
   text_y += 13;

   //assert(AudioTrackList[CurrentATLI].track == toc.FindTrackByLBA(cur_sector));
  }

  text_y += 13;


  //trio_snprintf(tmpbuf, 256, "Q-Mode: %01x", SubQBuf[1][0] & 0xF);
  //DrawTextShadow(espec->surface, 0, text_y, tmpbuf, text_color, text_shadow_color, 0, MDFN_FONT_6x13_12x13);
  //text_y += 13;

  trio_snprintf(tmpbuf, 256, "Track: %d", BCD_to_U8(SubQBuf[1][1]));
  DrawTextShadow(espec->surface, 0, text_y, tmpbuf, text_color, text_shadow_color, MDFN_FONT_6x13_12x13);
  text_y += 13;

  trio_snprintf(tmpbuf, 256, "Index: %d", BCD_to_U8(SubQBuf[1][2]));
  DrawTextShadow(espec->surface, 0, text_y, tmpbuf, text_color, text_shadow_color, MDFN_FONT_6x13_12x13);
  text_y += 13;


  trio_snprintf(tmpbuf, 256, "Relative: %02d:%02d:%02d", BCD_to_U8(SubQBuf[1][3]), BCD_to_U8(SubQBuf[1][4]), BCD_to_U8(SubQBuf[1][5]));
  DrawTextShadow(espec->surface, 0, text_y, tmpbuf, text_color, text_shadow_color, MDFN_FONT_6x13_12x13);
  text_y += 13;

  trio_snprintf(tmpbuf, 256, "Absolute: %02d:%02d:%02d", BCD_to_U8(SubQBuf[1][7]), BCD_to_U8(SubQBuf[1][8]), BCD_to_U8(SubQBuf[1][9]));
  DrawTextShadow(espec->surface, 0, text_y, tmpbuf, text_color, text_shadow_color, MDFN_FONT_6x13_12x13);
  text_y += 13;

  trio_snprintf(tmpbuf, 256, "Control: 0x%02x", (SubQBuf_LastValid[0] >> 4) & 0xF);
  DrawTextShadow(espec->surface, 0, text_y, tmpbuf, text_color, text_shadow_color, MDFN_FONT_6x13_12x13);
  text_y += 13;


  // Catalog
  trio_snprintf(tmpbuf, 256, "Catalog: %x%x%x%x%x%x%x%x%x%x%x%x%x",
						(SubQBuf[2][1] >> 4) & 0xF, (SubQBuf[2][1] >> 0) & 0xF, (SubQBuf[2][2] >> 4) & 0xF, (SubQBuf[2][2] >> 0) & 0xF,
					        (SubQBuf[2][3] >> 4) & 0xF, (SubQBuf[2][3] >> 0) & 0xF, (SubQBuf[2][4] >> 4) & 0xF, (SubQBuf[2][4] >> 0) & 0xF,
					        (SubQBuf[2][5] >> 4) & 0xF, (SubQBuf[2][5] >> 0) & 0xF, (SubQBuf[2][6] >> 4) & 0xF, (SubQBuf[2][6] >> 0) & 0xF,
						(SubQBuf[2][7] >> 4) & 0xF);
  DrawTextShadow(espec->surface, 0, text_y, tmpbuf, text_color, text_shadow_color, MDFN_FONT_6x13_12x13);
  text_y += 13;
 }

 if(PlayMode != PLAYMODE_STOP && PlayMode != PLAYMODE_PAUSE)
 {
  const int scan_amount = 4; //16;

  if(new_controller & 0x40)
   PlaySector += scan_amount;
  else if(new_controller & 0x80)
   PlaySector -= scan_amount;
  else
   PlaySector++;
 }

 if(!(last_controller & 0x1) && (new_controller & 1))
 {
  PlayMode = (PlayMode == PLAYMODE_PLAY) ? PLAYMODE_PAUSE : PLAYMODE_PLAY;
 }

 if(!(last_controller & 0x2) && (new_controller & 2)) // Stop
 {
  PlayMode = PLAYMODE_STOP;
  PlaySector = AudioTrackList[CurrentATLI].lba;
 }

 if(!(last_controller & 0x4) && (new_controller & 4))
 {
  if(CurrentATLI < (AudioTrackList.size() - 1))
   CurrentATLI++;

  PlaySector = AudioTrackList[CurrentATLI].lba;
 }

 if(!(last_controller & 0x8) && (new_controller & 8))
 {
  if(CurrentATLI)
   CurrentATLI--;

  PlaySector = AudioTrackList[CurrentATLI].lba;
 }

 if(!(last_controller & 0x10) && (new_controller & 0x10))
 {
  CurrentATLI = std::min<unsigned>(CurrentATLI + 10, AudioTrackList.size() - 1);
  PlaySector = AudioTrackList[CurrentATLI].lba;
 }

 if(!(last_controller & 0x20) && (new_controller & 0x20))
 {
  CurrentATLI -= std::min<unsigned>(CurrentATLI, 10);
  PlaySector = AudioTrackList[CurrentATLI].lba;
 }


 last_controller = new_controller;
}

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { NULL, NULL }
};

static void SetInput(unsigned port, const char *type, uint8* ptr)
{
 controller_ptr = ptr;
}

static void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_POWER:
  case MDFN_MSC_RESET: break;
 }
}

static const MDFNSetting CDPlaySettings[] =
{
 { "cdplay.visualization", MDFNSF_NOFLAGS, gettext_noop("Enable simple waveform visualization."), NULL, MDFNST_BOOL, "1" },
 { NULL }
};

static const IDIISG IDII =
{
 IDIIS_Button("play_pause", "Play/Pause", 0, NULL),
 IDIIS_Button("stop", "Stop", 1, NULL),
 IDIIS_Button("next_track", "Next Track", 2, NULL),
 IDIIS_Button("previous_track", "Previous Track", 3, NULL),

 IDIIS_Button("next_track_10", "Next Track 10", 4, NULL),
 IDIIS_Button("previous_track_10", "Previous Track 10", 5, NULL),

 IDIIS_Button("scan_forward", "Scan Forward", 6, NULL),
 IDIIS_Button("scan_reverse", "Scan Reverse", 7, NULL),

 //IDIIS_Button("reverse_seek", "Reverse Seek", 1, NULL),
 //IDIIS_Button("forward_seek", "Forward Seek", 2, NULL),
 //IDIIS_Button("fast_reverse_seek", "Fast Reverse Seek", 3, NULL),
 //IDIIS_Button("fast_forward_seek", "Fast Forward Seek", 4, NULL),
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfo =
{
 {
  "controller",
  "Controller",
  NULL,
  IDII,
 }
};

static const std::vector<InputPortInfoStruct> PortInfo =
{
 { "builtin", "Built-In", InputDeviceInfo }
};
}

using namespace MDFN_IEN_CDPLAY;

MDFNGI EmulatedCDPlay =
{
 "cdplay",
 "CD-DA Player",
 KnownExtensions,
 MODPRIO_INTERNAL_EXTRA_LOW,
 NULL,          // Debug info
 PortInfo,    //
 NULL,
 NULL,
 LoadCD,
 TestMagicCD,
 CloseGame,

 NULL,
 NULL,            // Layer names, null-delimited

 NULL,
 NULL,

 NULL,
 0,

 CheatInfo_Empty,

 false,
 NULL, //StateAction,
 Emulate,
 NULL,
 SetInput,
 NULL,
 DoSimpleCommand,
 NULL,
 CDPlaySettings,
 MDFN_MASTERCLOCK_FIXED(44100),
 75 * 65536 * 256,
 false, // Multires possible?

 192,   // lcm_width
 144,   // lcm_height
 NULL,  // Dummy


 192,   // Nominal width
 144,    // Nominal height

 192, 			// Framebuffer width
 144 + 1,                  	// Framebuffer height

 2,     // Number of output sound channels
};

