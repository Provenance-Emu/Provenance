/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* ssf.cpp - SSF Playback Sub-Module
**  Copyright (C) 2015-2017 Mednafen Team
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

#include <mednafen/mednafen.h>
#include <mednafen/general.h>
#include <mednafen/FileStream.h>
#include <mednafen/PSFLoader.h>
#include <mednafen/SSFLoader.h>
#include <mednafen/player.h>

using namespace Mednafen;

#define MDFN_SSFPLAY_COMPILE
#define SS_DBG(a, ...) ((void)0)
#define CDB_GetCDDA(n) ((void)0)
#define SS_SetPhysMemMap(...) ((void)0)
typedef int32 sscpu_timestamp_t;
#include "sound.cpp"
#undef SS_SetPhysMemMap
#undef CDB_GetCDDA
#undef SS_DBG
#undef MDFN_SSFPLAY_COMPILE

namespace MDFN_IEN_SSFPLAY
{
static SSFLoader* ssf_loader = NULL;

static void Emulate(EmulateSpecStruct* espec)
{
 SOUND_Set68KActive(true);
 SOUND_SetClockRatio(0x80000000);
 SOUND_StartFrame(espec->SoundRate / espec->soundmultiplier, MDFN_GetSettingUI("ssfplay.resamp_quality"));
 espec->soundmultiplier = 1;

 const int32 target_timestamp = 588 * 512;
 SOUND_Update(target_timestamp);
 espec->MasterCycles = target_timestamp >> 1;
 espec->SoundBufSize = SOUND_FlushOutput(espec->SoundBuf, espec->SoundBufMaxSize, espec->NeedSoundReverse);
 espec->NeedSoundReverse = false;
 SOUND_AdjustTS(-target_timestamp);

 if(!espec->skip)
 {
  espec->LineWidths[0] = ~0;
  Player_Draw(espec->surface, &espec->DisplayRect, 0, espec->SoundBuf, espec->SoundBufSize);
 }
}

static MDFN_COLD void Cleanup(void)
{
 if(ssf_loader)
 {
  delete ssf_loader;
  ssf_loader = NULL;
 }

 SOUND_Kill();
}


static MDFN_COLD bool TestMagic(GameFile* gf)
{
 if(SSFLoader::TestMagic(gf->stream))
  return true;

 return false;
}

static MDFN_COLD void Reset(void)
{
 SOUND_Reset(true);
 //{
 // FileStream tmp("/tmp/ssfdump.bin", FileStream::MODE_WRITE);
 // tmp.write(ssf_loader->RAM_Data.map(), ssf_loader->RAM_Data.map_size());
 //}

 for(unsigned i = 0; i < ssf_loader->RAM_Data.map_size(); i++)
 {
  SOUND_Write8(i, ssf_loader->RAM_Data.map()[i]);
 }
}

static MDFN_COLD void Load(GameFile* gf)
{
 try
 {
  std::vector<std::string> SongNames;

  ssf_loader = new SSFLoader(gf->vfs, gf->dir, gf->stream);

  SongNames.push_back(ssf_loader->tags.GetTag("title"));
  Player_Init(1, ssf_loader->tags.GetTag("game"), ssf_loader->tags.GetTag("artist"), ssf_loader->tags.GetTag("copyright"), SongNames, false);

  SOUND_Init();

  MDFNGameInfo->fps = 75 * 65536 * 256;
  MDFNGameInfo->MasterClock = MDFN_MASTERCLOCK_FIXED(44100 * 256);

  Reset();
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

static MDFN_COLD void CloseGame(void)
{
 Cleanup();
}

static MDFN_COLD void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_POWER:
  case MDFN_MSC_RESET:
	Reset();
	break;
 }
}

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".ssf", -20, gettext_noop("SSF Rip") },
 { ".minissf", -20, gettext_noop("MiniSSF Rip") },

 { NULL, 0, NULL }
};


static const MDFNSetting SSFPlaySettings[] =
{
 { "ssfplay.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("SCSP output resampler quality."),
	gettext_noop("0 is lowest quality and CPU usage, 10 is highest quality and CPU usage.  The resampler that this setting refers to is used for converting from 44.1KHz to the sampling rate of the host audio device Mednafen is using.  Changing Mednafen's output rate, via the \"sound.rate\" setting, to \"44100\" may bypass the resampler, which can decrease CPU usage by Mednafen, and can increase or decrease audio quality, depending on various operating system and hardware factors."), MDFNST_UINT, "4", "0", "10" },

 { NULL },
};


static std::vector<InputPortInfoStruct> DummyPortInfo;
}

using namespace MDFN_IEN_SSFPLAY;

MDFN_HIDE extern const MDFNGI EmulatedSSFPlay =
{
 "ssfplay",
 "Sega Saturn Sound Format Player",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 NULL,
 DummyPortInfo,
 NULL,
 Load,
 TestMagic,
 NULL,
 NULL,
 CloseGame,

 NULL,
 "\0",

 NULL,
 NULL,

 NULL,
 0,

 CheatInfo_Empty,

 false,
 SOUND_StateAction,
 Emulate,
 NULL,
 NULL,
 NULL,
 DoSimpleCommand,
 NULL,
 SSFPlaySettings,
 0,
 0,

 EVFSUPPORT_RGB555 | EVFSUPPORT_RGB565,

 false, // Multires possible?

 480,	// lcm_width
 300,	// lcm_height
 NULL,  // Dummy

 480,   // Nominal width
 300,   // Nominal height

 480,   // Framebuffer width
 300,   // Framebuffer height
 //
 //
 //

 2,     // Number of output sound channels
};

