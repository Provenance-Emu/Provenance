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

#include        "mednafen.h"

#include	<sys/types.h>
#include	<sys/stat.h>
#include	<unistd.h>
#include	<trio/trio.h>

#include	"netplay.h"
#include	"netplay-driver.h"
#include	"general.h"
#include	<mednafen/string/string.h>

#include	"state.h"
#include	"movie.h"
#include	"state_rewind.h"
#include        "video.h"
#include	"video/Deinterlacer.h"
#include	"file.h"
#include	"sound/WAVRecord.h"
#include	"cdrom/cdromif.h"
#include	"mempatcher.h"
//#include	<minilzo/minilzo.h>
#include	"tests.h"
#include	"video/tblur.h"
#include	"qtrecord.h"
#include	<mednafen/hash/md5.h>
#include	<mednafen/MemoryStream.h>
#include	<mednafen/Time.h>
#include	"sound/Fir_Resampler.h"

#include	"string/escape.h"

#include	"cdrom/CDUtility.h"

static void SettingChanged(const char* name);

static const char *CSD_forcemono = gettext_noop("Force monophonic sound output.");
static const char *CSD_enable = gettext_noop("Enable (automatic) usage of this module.");
static const char *CSD_tblur = gettext_noop("Enable video temporal blur(50/50 previous/current frame by default).");
static const char *CSD_tblur_accum = gettext_noop("Accumulate color data rather than discarding it.");
static const char *CSD_tblur_accum_amount = gettext_noop("Blur amount in accumulation mode, specified in percentage of accumulation buffer to mix with the current frame.");

static const MDFNSetting_EnumList VCodec_List[] =
{
// { "raw", (int)QTRecord::VCODEC_RAW, "Raw",
//	gettext_noop("A fast codec, computationally, but will cause enormous file size and may exceed your storage medium's sustained write rate.") },
//
// { "cscd", (int)QTRecord::VCODEC_CSCD, "CamStudio Screen Codec",
//	gettext_noop("A good balance between performance and compression ratio.") },
//
// { "png", (int)QTRecord::VCODEC_PNG, "PNG",
//	gettext_noop("Has a better compression ratio than \"cscd\", but is much more CPU intensive.  Use for compatibility with official QuickTime in cases where you have insufficient disk space for \"raw\".") },

 { NULL, 0 },
};

static const MDFNSetting_EnumList Deinterlacer_List[] =
{
 { "weave", Deinterlacer::DEINT_WEAVE, gettext_noop("Good for low-motion video; can be used in conjunction with negative <system>.scanlines setting values.") },
 { "bob", Deinterlacer::DEINT_BOB, gettext_noop("Good for causing a headache.  All glory to Bob.") },
 { "bob_offset", Deinterlacer::DEINT_BOB_OFFSET, gettext_noop("Good for high-motion video, but is a bit flickery; reduces the subjective vertical resolution.") },

 { NULL, 0 },
};

static const char* const fname_extra = gettext_noop("See fname_format.txt for more information.  Edit at your own risk.");

static const MDFNSetting MednafenSettings[] =
{
  { "netplay.password", MDFNSF_NOFLAGS, gettext_noop("Server password."), gettext_noop("Password to connect to the netplay server."), MDFNST_STRING, "" },
  { "netplay.localplayers", MDFNSF_NOFLAGS, gettext_noop("Local player count."), gettext_noop("Number of local players for network play.  This number is advisory to the server, and the server may assign fewer players if the number of players requested is higher than the number of controllers currently available."), MDFNST_UINT, "1", "0", "16" },
  { "netplay.nick", MDFNSF_NOFLAGS, gettext_noop("Nickname."), gettext_noop("Nickname to use for network play chat."), MDFNST_STRING, "" },
  { "netplay.gamekey", MDFNSF_NOFLAGS, gettext_noop("Key to hash with the MD5 hash of the game."), NULL, MDFNST_STRING, "" },

  { "srwframes", MDFNSF_NOFLAGS, gettext_noop("Number of frames to keep states for when state rewinding is enabled."), 
	gettext_noop("WARNING: Setting this to a large value may cause excessive RAM usage in some circumstances, such as with games that stream large volumes of data off of CDs."), MDFNST_UINT, "600", "10", "99999" },

  { "cd.image_memcache", MDFNSF_NOFLAGS, gettext_noop("Cache entire CD images in memory."), gettext_noop("Reads the entire CD image(s) into memory at startup(which will cause a small delay).  Can help obviate emulation hiccups due to emulated CD access.  May cause more harm than good on low memory systems, systems with swap enabled, and/or when the disc images in question are on a fast SSD."), MDFNST_BOOL, "0" },

  { "filesys.untrusted_fip_check", MDFNSF_NOFLAGS, gettext_noop("Enable untrusted file-inclusion path security check."),
	gettext_noop("When this setting is set to \"1\", the default, paths to files referenced from files like CUE sheets and PSF rips are checked for certain characters that can be used in directory traversal, and if found, loading is aborted.  Set it to \"0\" if you want to allow constructs like absolute paths in CUE sheets, but only if you understand the security implications of doing so(see \"Security Issues\" section in the documentation)."), MDFNST_BOOL, "1" },

  { "filesys.path_snap", MDFNSF_CAT_PATH, gettext_noop("Path to directory for screen snapshots."), NULL, MDFNST_STRING, "snaps" },
  { "filesys.path_sav", MDFNSF_CAT_PATH, gettext_noop("Path to directory for save games and nonvolatile memory."), gettext_noop("WARNING: Do not set this path to a directory that contains Famicom Disk System disk images, or you will corrupt them when you load an FDS game and exit Mednafen."), MDFNST_STRING, "sav" },
  { "filesys.path_savbackup", MDFNSF_CAT_PATH, gettext_noop("Path to directory for backups of save games and nonvolatile memory."), NULL, MDFNST_STRING, "b" },
  { "filesys.path_state", MDFNSF_CAT_PATH, gettext_noop("Path to directory for save states."), NULL, MDFNST_STRING, "mcs" },
  { "filesys.path_movie", MDFNSF_CAT_PATH, gettext_noop("Path to directory for movies."), NULL, MDFNST_STRING, "mcm" },
  { "filesys.path_cheat", MDFNSF_CAT_PATH, gettext_noop("Path to directory for cheats."), NULL, MDFNST_STRING, "cheats" },
  { "filesys.path_palette", MDFNSF_CAT_PATH, gettext_noop("Path to directory for custom palettes."), NULL, MDFNST_STRING, "palettes" },
  { "filesys.path_pgconfig", MDFNSF_CAT_PATH, gettext_noop("Path to directory for per-game configuration override files."), NULL, MDFNST_STRING, "pgconfig" },
  { "filesys.path_firmware", MDFNSF_CAT_PATH, gettext_noop("Path to directory for firmware."), NULL, MDFNST_STRING, "firmware" },

  { "filesys.fname_movie", MDFNSF_CAT_PATH, gettext_noop("Format string for movie filename."), fname_extra, MDFNST_STRING, "%f.%M%p.%x" },
  { "filesys.fname_state", MDFNSF_CAT_PATH, gettext_noop("Format string for state filename."), fname_extra, MDFNST_STRING, "%f.%M%X" /*"%F.%M%p.%x"*/ },
  { "filesys.fname_sav", MDFNSF_CAT_PATH, gettext_noop("Format string for save games filename."), gettext_noop("WARNING: %x should always be included, otherwise you run the risk of overwriting save data for games that create multiple save data files.\n\nSee fname_format.txt for more information.  Edit at your own risk."), MDFNST_STRING, "%F.%M%x" },
  { "filesys.fname_savbackup", MDFNSF_CAT_PATH, gettext_noop("Format string for save game backups filename."), gettext_noop("WARNING: %x and %p should always be included.\n\nSee fname_format.txt for more information.  Edit at your own risk."), MDFNST_STRING, "%F.%m%z%p.%x" },
  { "filesys.fname_snap", MDFNSF_CAT_PATH, gettext_noop("Format string for screen snapshot filenames."), gettext_noop("WARNING: %x or %p should always be included, otherwise there will be a conflict between the numeric counter text file and the image data file.\n\nSee fname_format.txt for more information.  Edit at your own risk."), MDFNST_STRING, "%f-%p.%x" },

  { "filesys.state_comp_level", MDFNSF_NOFLAGS, gettext_noop("Save state file compression level."), gettext_noop("gzip/deflate compression level for save states saved to files.  -1 will disable gzip compression and wrapping entirely."), MDFNST_INT, "6", "-1", "9" },


  { "qtrecord.w_double_threshold", MDFNSF_NOFLAGS, gettext_noop("Double the raw image's width if it's below this threshold."), NULL, MDFNST_UINT, "384", "0", "1073741824" },
  { "qtrecord.h_double_threshold", MDFNSF_NOFLAGS, gettext_noop("Double the raw image's height if it's below this threshold."), NULL, MDFNST_UINT, "256", "0", "1073741824" },

  { "qtrecord.vcodec", MDFNSF_NOFLAGS, gettext_noop("Video codec to use."), NULL, MDFNST_ENUM, "cscd", NULL, NULL, NULL, NULL, VCodec_List },

  { "video.deinterlacer", MDFNSF_CAT_VIDEO, gettext_noop("Deinterlacer to use for interlaced video."), NULL, MDFNST_ENUM, "weave", NULL, NULL, NULL, SettingChanged, Deinterlacer_List },

  { NULL }
};

static const MDFNSetting RenamedSettings[] =
{
 { "path_snap", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS  , 	"filesys.path_snap"	},
 { "path_sav", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS  , 	"filesys.path_sav"	},
 { "path_state", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS  ,	"filesys.path_state"	},
 { "path_movie", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS  , 	"filesys.path_movie"	},
 { "path_cheat", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS  , 	"filesys.path_cheat"	},
 { "path_palette", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS  , 	"filesys.path_palette"	},
 { "path_firmware", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS  , "filesys.path_firmware"	},

 { "sounddriver", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS  , "sound.driver"      },
 { "sounddevice", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS  , "sound.device"      },
 { "soundrate", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS    , "sound.rate"        },
 { "soundvol", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS     , "sound.volume"      },
 { "soundbufsize", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS , "sound.buffer_time" },

 { "nethost", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS         , "netplay.host"   },
 { "netport", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS         , "netplay.port"   },
 { "netpassword", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS     , "netplay.password"},
 { "netlocalplayers", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS , "netplay.localplayers" },
 { "netnick", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS         , "netplay.nick"   },
 { "netgamekey", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS      , "netplay.gamekey"        },
 { "netsmallfont", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS    , "netplay.smallfont" },

 { "frameskip", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS       , "video.frameskip" },
 { "vdriver", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS         , "video.driver" },
 { "glvsync", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS         , "video.glvsync" },
 { "fs", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS              , "video.fs" },

 { "autofirefreq", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS    , "input.autofirefreq" },
 { "analogthreshold", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS , "input.joystick.axis_threshold" },
 { "ckdelay", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS         , "input.ckdelay" },


 { "psx.input.port1.multitap", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS         , "psx.input.pport1.multitap" },
 { "psx.input.port2.multitap", MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS         , "psx.input.pport2.multitap" },

 { "snes_faust.spexf",	       MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS         , "snes_faust.spex" },

 { "netplay.smallfont",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "netplay.console.font" },

 { "cdplay.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "cdplay.shader" },
 { "demo.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "demo.shader" },
 { "gb.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "gb.shader" },
 { "gba.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "gba.shader" },
 { "gg.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "gg.shader" },
 { "lynx.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "lynx.shader" },
 { "md.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "md.shader" },
 { "nes.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "nes.shader" },
 { "ngp.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "ngp.shader" },
 { "pce.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "pce.shader" },
 { "pce_fast.pixshader",	MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "pce_fast.shader" },
 { "pcfx.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "pcfx.shader" },
 { "player.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "player.shader" },
 { "psx.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "psx.shader" },
 { "sms.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "sms.shader" },
 { "snes.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "snes.shader" },
 { "snes_faust.pixshader",	MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "snes_faust.shader" },
 { "ss.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "ss.shader" },
 { "ssfplay.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "ssfplay.shader" },
 { "vb.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "vb.shader" },
 { "wswan.pixshader",		MDFNSF_NOFLAGS, NULL, NULL, MDFNST_ALIAS	, "wswan.shader" },

 { NULL }
};

static uint8* CustomPalette = NULL;
static uint32 CustomPaletteNumEntries = 0;

static uint32 PortDevice[16];
static uint8* PortData[16];
static uint32 PortDataLen[16];

MDFNGI *MDFNGameInfo = NULL;

//static QTRecord *qtrecorder = NULL;
static WAVRecord *wavrecorder = NULL;
static Fir_Resampler<16> ff_resampler;
static double LastSoundMultiplier;
static double last_sound_rate;
static MDFN_PixelFormat last_pixel_format;
static bool PrevInterlaced;
static Deinterlacer deint;

static bool FFDiscard = false; // TODO:  Setting to discard sound samples instead of increasing pitch

static std::vector<CDIF *> CDInterfaces;	// FIXME: Cleanup on error out.

struct DriveMediaStatus
{
 uint32 state_idx = 0; 
 uint32 media_idx = 0;
 uint32 orientation_idx = 0;
};

static std::vector<DriveMediaStatus> DMStatus;

static void SettingChanged(const char* name)
{
 if(!strcmp(name, "video.deinterlacer"))
  deint.SetType(MDFN_GetSettingUI(name));
}

bool MDFNI_StartWAVRecord(const char *path, double SoundRate)
{
 try
 {
  wavrecorder = new WAVRecord(path, SoundRate, MDFNGameInfo->soundchan);
 }
 catch(std::exception &e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
  return(false);
 }

 return(true);
}

bool MDFNI_StartAVRecord(const char *path, double SoundRate)
{
// try
// {
//  QTRecord::VideoSpec spec;
//
//  memset(&spec, 0, sizeof(spec));
//
//  spec.SoundRate = SoundRate;
//  spec.SoundChan = MDFNGameInfo->soundchan;
//  spec.VideoWidth = MDFNGameInfo->lcm_width;
//  spec.VideoHeight = MDFNGameInfo->lcm_height;
//  spec.VideoCodec = MDFN_GetSettingI("qtrecord.vcodec");
//  spec.MasterClock = MDFNGameInfo->MasterClock;
//
//  if(spec.VideoWidth < MDFN_GetSettingUI("qtrecord.w_double_threshold"))
//   spec.VideoWidth *= 2;
//
//  if(spec.VideoHeight < MDFN_GetSettingUI("qtrecord.h_double_threshold"))
//   spec.VideoHeight *= 2;
//
//
//  spec.AspectXAdjust = ((double)MDFNGameInfo->nominal_width * 2) / spec.VideoWidth;
//  spec.AspectYAdjust = ((double)MDFNGameInfo->nominal_height * 2) / spec.VideoHeight;
//
//  MDFN_printf("\n");
//  MDFN_printf(_("Starting QuickTime recording to file \"%s\":\n"), path);
//  MDFN_indent(1);
//  MDFN_printf(_("Video width: %u\n"), spec.VideoWidth);
//  MDFN_printf(_("Video height: %u\n"), spec.VideoHeight);
//  MDFN_printf(_("Video codec: %s\n"), MDFN_GetSettingS("qtrecord.vcodec").c_str());
//
//  if(spec.SoundRate && spec.SoundChan)
//  {
//   MDFN_printf(_("Sound rate: %u\n"), std::min<uint32>(spec.SoundRate, 64000));
//   MDFN_printf(_("Sound channels: %u\n"), spec.SoundChan);
//  }
//  else
//   MDFN_printf(_("Sound: Disabled\n"));
//
//  MDFN_indent(-1);
//  MDFN_printf("\n");
//
//  qtrecorder = new QTRecord(path, spec);
// }
// catch(std::exception &e)
// {
//  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
//  return(false);
// }
 return(true);
}

void MDFNI_StopAVRecord(void)
{
// if(qtrecorder)
// {
//  delete qtrecorder;
//  qtrecorder = NULL;
// }
}

void MDFNI_StopWAVRecord(void)
{
 if(wavrecorder)
 {
  delete wavrecorder;
  wavrecorder = NULL;
 }
}

void MDFNI_CloseGame(void)
{
 if(MDFNGameInfo)
 {
  MDFNI_NetplayDisconnect();

  MDFNSRW_End();
  MDFNMOV_Stop();

  if(MDFNGameInfo->GameType != GMT_PLAYER)
   MDFN_FlushGameCheats(0);

  MDFNGameInfo->CloseGame();

  //
  //
  //
  MDFNGameInfo->name.clear();

  if(MDFNGameInfo->RMD)
  {
   delete MDFNGameInfo->RMD;
   MDFNGameInfo->RMD = NULL;
  }

  MDFNMP_Kill();


  //
  //
  memset(MDFNGameInfo->MD5, 0, sizeof(MDFNGameInfo->MD5));
  memset(MDFNGameInfo->GameSetMD5, 0, sizeof(MDFNGameInfo->GameSetMD5));
  MDFNGameInfo->GameSetMD5Valid = false;
  MDFNGameInfo = NULL;

  for(unsigned i = 0; i < CDInterfaces.size(); i++)
   delete CDInterfaces[i];
  CDInterfaces.clear();
 }
 TBlur_Kill();

 #ifdef WANT_DEBUGGER
 MDFNDBG_Kill();
 #endif

 for(unsigned x = 0; x < 16; x++)
 {
  if(PortData[x])
  {
   free(PortData[x]);
   PortData[x] = NULL;
  }

  PortDevice[x] = ~0U;
  PortDataLen[x] = 0;
 }

 if(CustomPalette != NULL)
 {
  delete[] CustomPalette;
  CustomPalette = NULL;
 }
 CustomPaletteNumEntries = 0;

 MDFN_ClearAllOverrideSettings();
}

#ifdef WANT_NES_EMU
extern MDFNGI EmulatedNES;
#endif

#ifdef WANT_SNES_EMU
extern MDFNGI EmulatedSNES;
#endif

#ifdef WANT_SNES_FAUST_EMU
extern MDFNGI EmulatedSNES_Faust;
#endif

#ifdef WANT_GBA_EMU
extern MDFNGI EmulatedGBA;
#endif

#ifdef WANT_GB_EMU
extern MDFNGI EmulatedGB;
#endif

#ifdef WANT_LYNX_EMU
extern MDFNGI EmulatedLynx;
#endif

#ifdef WANT_MD_EMU
extern MDFNGI EmulatedMD;
#endif

#ifdef WANT_NGP_EMU
extern MDFNGI EmulatedNGP;
#endif

#ifdef WANT_PCE_EMU
extern MDFNGI EmulatedPCE;
#endif

#ifdef WANT_PCE_FAST_EMU
extern MDFNGI EmulatedPCE_Fast;
#endif

#ifdef WANT_PCFX_EMU
extern MDFNGI EmulatedPCFX;
#endif

#ifdef WANT_PSX_EMU
extern MDFNGI EmulatedPSX;
#endif

#ifdef WANT_SS_EMU
extern MDFNGI EmulatedSS;
#endif

#ifdef WANT_SSFPLAY_EMU
extern MDFNGI EmulatedSSFPlay;
#endif

#ifdef WANT_VB_EMU
extern MDFNGI EmulatedVB;
#endif

#ifdef WANT_WSWAN_EMU
extern MDFNGI EmulatedWSwan;
#endif

#ifdef WANT_SMS_EMU
extern MDFNGI EmulatedSMS, EmulatedGG;
#endif

extern MDFNGI EmulatedCDPlay;
extern MDFNGI EmulatedDEMO;

std::vector<MDFNGI *> MDFNSystems;
static std::list<MDFNGI *> MDFNSystemsPrio;

bool MDFNSystemsPrio_CompareFunc(const MDFNGI* first, const MDFNGI* second)
{
 if(first->ModulePriority > second->ModulePriority)
  return true;

 return false;
}

static void AddSystem(MDFNGI *system)
{
 MDFNSystems.push_back(system);
}

void MDFNI_DumpModulesDef(const char *fn)
{
 FileStream fp(fn, FileStream::MODE_WRITE);

 fp.print_format("%s\n", MEDNAFEN_VERSION);

 for(unsigned int i = 0; i < MDFNSystems.size(); i++)
 {
  fp.print_format("%s\n", MDFNSystems[i]->shortname);
  fp.print_format("%s\n", MDFNSystems[i]->fullname);
  fp.print_format("%d\n", MDFNSystems[i]->nominal_width);
  fp.print_format("%d\n", MDFNSystems[i]->nominal_height);

  size_t cpcount = 0;

  if(MDFNSystems[i]->CPInfo)
   for(auto cpi = MDFNSystems[i]->CPInfo; cpi->description || cpi->name_override; cpi++)
    cpcount++;

  fp.print_format("%zu\n", cpcount);

  if(MDFNSystems[i]->CPInfo)
  {
   for(auto cpi = MDFNSystems[i]->CPInfo; cpi->description || cpi->name_override; cpi++)
   {
    fp.print_format("%s.pal\n", cpi->name_override ? cpi->name_override : MDFNSystems[i]->shortname);
    fp.print_format("%s\n", cpi->description);
    for(unsigned vec : cpi->valid_entry_count)
    {
     if(!vec)
      break;
     fp.print_format("%u ", vec);
    }
    fp.print_format("\n");
   }
  }
 }

 fp.close();
}

struct M3U_ListEntry
{
 std::string path;
 std::unique_ptr<std::string> name;
};

static MDFN_COLD void ReadM3U(std::vector<M3U_ListEntry> &file_list, size_t* default_cd, std::string path, unsigned depth = 0)
{
 MemoryStream m3u_file(new FileStream(path, FileStream::MODE_READ));
 std::string dir_path;
 std::string linebuf;
 std::unique_ptr<std::string> name;
 int termc;

 if(!m3u_file.read_utf8_bom())
 {
  m3u_file.mswin_utf8_convert_kludge();
 }

 MDFN_GetFilePathComponents(path, &dir_path);

 linebuf.reserve(2048);

 while((termc = m3u_file.get_line(linebuf)) >= 0)
 {
  std::string efp;

  MDFN_rtrim(linebuf);

  // Blank line, skip it.
  if(linebuf.size() == 0)
   continue;

  // Comment line, skip it.
  if(linebuf[0] == '#')
  {
   if(!strcmp(linebuf.c_str(), "#MEDNAFEN_DEFAULT"))
    *default_cd = file_list.size();
   else if(!strncmp(linebuf.c_str(), "#MEDNAFEN_LABEL", 15))
   {
    name.reset(new std::string(linebuf.substr(15)));
    UTF8_sanitize(*name);
    MDFN_zapctrlchars(*name);
    MDFN_trim(*name);
   }
   continue;
  }

  efp = MDFN_EvalFIP(dir_path, linebuf);

  if(efp.size() >= 4 && !MDFN_strazicmp(efp.substr(efp.size() - 4).c_str(), ".m3u"))
  {
   if(efp == path)
    throw(MDFN_Error(0, _("M3U at \"%s\" references self."), efp.c_str()));

   if(depth == 99)
    throw(MDFN_Error(0, _("M3U load recursion too deep!")));

   ReadM3U(file_list, default_cd, efp, depth++);
  }
  else
   file_list.emplace_back(M3U_ListEntry({efp, std::move(name)}));
 }
}

static MDFN_COLD void PrintDiscsLayout(std::vector<CDIF *> *ifaces)
{
 MDFN_AutoIndent aind(1);

 for(unsigned i = 0; i < (*ifaces).size(); i++)
 {
  CDUtility::TOC toc;

  (*ifaces)[i]->ReadTOC(&toc);

  MDFN_printf(_("CD %u TOC:\n"), i + 1);
  {
   MDFN_AutoIndent aindd(1);
   int32 eff_lt = 0;
   const char* disc_type_string;

   switch(toc.disc_type)
   {
    default:
	disc_type_string = "";
	break;

    case CDUtility::DISC_TYPE_CDDA_OR_M1:
	disc_type_string = _(" (CD-DA or Mode 1)");
	break;

    case CDUtility::DISC_TYPE_CD_I:
	disc_type_string = _(" (CD-i)");
	break;

    case CDUtility::DISC_TYPE_CD_XA:
	disc_type_string = _(" (CD-XA)");
	break;
   }

   MDFN_printf(_("Disc Type: 0x%02x%s\n"), toc.disc_type, disc_type_string);
   MDFN_printf(_("First Track: %2d\n"), toc.first_track);
   MDFN_printf(_("Last Track:  %2d\n"), toc.last_track);

   for(int32 track = 1; track <= 99; track++)
   {
    if(!toc.tracks[track].valid)
     continue;

    eff_lt = track;

    uint8 m, s, f;

    CDUtility::LBA_to_AMSF(toc.tracks[track].lba, &m, &s, &f);

    MDFN_printf(_("Track %2d, MSF: %02d:%02d:%02d, LBA: %6d  %s%s\n"),
		track,
		m, s, f,
		toc.tracks[track].lba,
		(toc.tracks[track].control & 0x4) ? "DATA" : "AUDIO",
		(track < toc.first_track || track > toc.last_track) ? _(" (Hidden)") : "");
   }

   MDFN_printf(_("Leadout: %6d  %s\n"), toc.tracks[100].lba, (toc.tracks[100].control & 0x4) ? "DATA" : "AUDIO");

   if((toc.tracks[eff_lt].control & 0x4) != (toc.tracks[100].control & 0x4))
    MDFN_printf(_("WARNING:  DATA/AUDIO TYPE MISMATCH BETWEEN LAST TRACK AND LEADOUT AREA."));

   MDFN_printf("\n");
  }
 }
}

static MDFN_COLD void CalcDiscsLayoutMD5(std::vector<CDIF *> *ifaces, uint8 out_md5[16])
{
  md5_context layout_md5;

  layout_md5.starts();

  for(unsigned i = 0; i < (*ifaces).size(); i++)
  {
   CD_TOC toc;

   (*ifaces)[i]->ReadTOC(&toc);

   layout_md5.update_u32_as_lsb(toc.first_track);
   layout_md5.update_u32_as_lsb(toc.last_track);
   layout_md5.update_u32_as_lsb(toc.tracks[100].lba);

   for(uint32 track = 1; track <= 99; track++)
   {
    if(!toc.tracks[track].valid)
     continue;

    layout_md5.update_u32_as_lsb(toc.tracks[track].lba);
    layout_md5.update_u32_as_lsb(toc.tracks[track].control & 0x4);
   }
  }

  layout_md5.finish(out_md5);
}

static MDFN_COLD void LoadCustomPalette(void)
{
 if(!MDFNGameInfo->CPInfo)
  return;

 for(auto cpi = MDFNGameInfo->CPInfo; cpi->description || cpi->name_override; cpi++)
 {
  if(!(MDFNGameInfo->CPInfoActiveBF & (1U << (cpi - MDFNGameInfo->CPInfo))))
   continue;

  std::string colormap_fn = MDFN_MakeFName(MDFNMKF_PALETTE, 0, cpi->name_override);

  MDFN_printf("\n");
  MDFN_printf(_("Loading custom palette from \"%s\"...\n"),  colormap_fn.c_str());
  {
   MDFN_AutoIndent aind(1);

   try
   {
    FileStream fp(colormap_fn, FileStream::MODE_READ);
    const uint64 fpsz = fp.size();
   
    for(auto vec = cpi->valid_entry_count; *vec; vec++)
    {
     if(fpsz == *vec * 3)
     {
      CustomPaletteNumEntries = *vec;
      CustomPalette = new uint8[CustomPaletteNumEntries * 3];

      fp.read(CustomPalette, CustomPaletteNumEntries * 3);

      return;
     }
    }

    //
    // File size is not valid, print out an error message with helpful information.
    //
    std::string vfszs;
    for(auto vec = cpi->valid_entry_count; *vec; vec++)
    {
     if(vfszs.size())
      vfszs += _(", ");

     vfszs += std::to_string(3 * *vec);
    }

    throw MDFN_Error(0, _("Custom palette file's size(%llu bytes) is incorrect.  Valid sizes are: %s"), (unsigned long long)fpsz, vfszs.c_str());
   }
   catch(MDFN_Error &e)
   {
    MDFN_printf(_("Error: %s\n"), e.what());

    if(e.GetErrno() != ENOENT)
     throw;

    return;
   }
   catch(std::exception &e)
   {
    MDFN_printf(_("Error: %s\n"), e.what());
    throw;
   }
  }
  break;
 }
}

static MDFN_COLD void LoadCommonPost(const char* path)
{
	DMStatus.resize(MDFNGameInfo->RMD->Drives.size());

	if(MDFNGameInfo->name.size() == 0 && path)
	{
	 MDFN_GetFilePathComponents(path, NULL, &MDFNGameInfo->name);

	 for(auto& c : MDFNGameInfo->name)
	  if(c == '_' || (uint8)c < 0x20)
	   c = ' ';

	 MDFN_trim(MDFNGameInfo->name);
	}

        //
        //
        //

	LoadCustomPalette();
	if(MDFNGameInfo->GameType != GMT_PLAYER)
	{
	 MDFN_LoadGameCheats(NULL);
	 MDFNMP_InstallReadPatches();
	}

	MDFNI_SetLayerEnableMask(~0ULL);

	#ifdef WANT_DEBUGGER
	MDFNDBG_PostGameLoad(); 
	#endif

	MDFNSS_CheckStates();
	MDFNMOV_CheckMovies();

	PrevInterlaced = false;
	deint.ClearState();
	SettingChanged("video.deinterlacer");

	TBlur_Init();

	MDFNSRW_Begin();

	LastSoundMultiplier = 1;
	last_sound_rate = -1;
	last_pixel_format = MDFN_PixelFormat();
}

static MDFNGI *LoadCD(const char *force_module, const char *path)
{
 std::vector<M3U_ListEntry> file_list;
 uint8 LayoutMD5[16];
 size_t default_cd = 0;

 try
 {
  MDFN_AutoIndent aind(1);
  const bool image_memcache = MDFN_GetSettingB("cd.image_memcache");

  if(strlen(path) > 4 && !MDFN_strazicmp(path + strlen(path) - 4, ".m3u"))
   ReadM3U(file_list, &default_cd, path);
  else
   file_list.emplace_back(M3U_ListEntry({ path }));

  CDInterfaces.resize(file_list.size());
  for(size_t i = 0; i < file_list.size(); i++)
   CDInterfaces[i] = CDIF_Open(file_list[i].path, image_memcache);

  GetFileBase(path);
 }
 catch(std::exception &e)
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, _("Error opening CD: %s"), e.what());

  for(unsigned i = 0; i < CDInterfaces.size(); i++)
  {
   if(CDInterfaces[i])
   {
    delete CDInterfaces[i];
    CDInterfaces[i] = NULL;
   }
  }
  CDInterfaces.clear();

  MDFNGameInfo = NULL;

  return(NULL);
 }

 MDFN_printf("\n");

 //
 // Print out a track list for all discs.
 //
 PrintDiscsLayout(&CDInterfaces);

 //
 // Calculate layout MD5.  The system emulation LoadCD() code is free to ignore this value and calculate
 // its own, or to use it to look up a game in its database.
 //
 CalcDiscsLayoutMD5(&CDInterfaces, LayoutMD5);

 try
 {
	std::unique_ptr<RMD_Layout> rmd(new RMD_Layout());
	MDFNGameInfo = NULL;

	{
  	 RMD_Drive dr;

	 dr.Name = std::string("Virtual CD Drive");
	 dr.PossibleStates.push_back(RMD_State({"Tray Open", false, false, true}));
	 dr.PossibleStates.push_back(RMD_State({"Tray Closed (Empty)", false, false, false}));
	 dr.PossibleStates.push_back(RMD_State({"Tray Closed", true, true, false}));
	 dr.CompatibleMedia.push_back(0);
	 dr.MediaMtoPDelay = 2000;

	 rmd->Drives.push_back(dr);
	 rmd->DrivesDefaults.push_back(RMD_DriveDefaults({0, 0, 0}));
	 rmd->MediaTypes.push_back(RMD_MediaType({"CD"}));
	}

	for(size_t i = 0; i < CDInterfaces.size(); i++)
	{
         if(i == default_cd)
         {
	  rmd->DrivesDefaults[0].State = 2;	// Tray Closed
	  rmd->DrivesDefaults[0].Media = i;
          rmd->DrivesDefaults[0].Orientation = 0;
         }

	 if(file_list[i].name)
	  rmd->Media.push_back(RMD_Media({std::string(1, '"') + *file_list[i].name + '"', 0}));
	 else
	 {
	  char namebuf[128];
	  trio_snprintf(namebuf, sizeof(namebuf), _("Disc %zu of %zu"), i + 1, CDInterfaces.size());
	  rmd->Media.push_back(RMD_Media({namebuf, 0}));
	 }
	}

        for(std::list<MDFNGI *>::iterator it = MDFNSystemsPrio.begin(); it != MDFNSystemsPrio.end(); it++)  //_unsigned int x = 0; x < MDFNSystems.size(); x++)
        {
         if(force_module)
         {
          if(!strcmp(force_module, (*it)->shortname))
          {
           MDFNGameInfo = *it;
           break;
          }
         }
         else
         {
          char tmpstr[256];
          trio_snprintf(tmpstr, 256, "%s.enable", (*it)->shortname);

          // Is module enabled?
          if(!MDFN_GetSettingB(tmpstr))
	  {
	   MDFN_printf(_("Skipping module \"%s\" per \"%s\" setting.\n"), (*it)->shortname, tmpstr);
           continue; 
	  }

          if(!(*it)->LoadCD || !(*it)->TestMagicCD)
           continue;

          if((*it)->TestMagicCD(&CDInterfaces))
          {
           MDFNGameInfo = *it;
           break;
          }
         }
        }

        if(!MDFNGameInfo)
        {
	 if(force_module)
	  throw MDFN_Error(0, _("Unrecognized system \"%s\"!"), force_module);
	 else
 	  throw MDFN_Error(0, _("Could not find a system that supports this CD."));
        }

	// This if statement will be true if force_module references a system without CDROM support.
        if(!MDFNGameInfo->LoadCD)
         throw MDFN_Error(0, _("Specified system \"%s\" doesn't support CDs!"), force_module);

        MDFN_printf(_("Using module: %s(%s)\n"), MDFNGameInfo->shortname, MDFNGameInfo->fullname);
	{
	 MDFN_AutoIndent aindentgm(1);

	 assert(MDFNGameInfo->soundchan != 0);

         MDFNGameInfo->name.clear();
	 MDFNGameInfo->DesiredInput.clear();
         MDFNGameInfo->rotated = 0;
	 MDFNGameInfo->RMD = rmd.get();

	 memcpy(MDFNGameInfo->MD5, LayoutMD5, 16);

	 {
	  std::string modoverride_settings_file_path = MDFN_GetBaseDirectory() + std::string(PSS) + std::string(MDFNGameInfo->shortname) + std::string(".cfg");
	  MDFN_LoadSettings(modoverride_settings_file_path.c_str(), true);
	 }
	 {
	  std::string pgcoverride_settings_file_path = MDFN_MakeFName(MDFNMKF_PGCONFIG, 0, NULL);
	  MDFN_LoadSettings(pgcoverride_settings_file_path.c_str(), true);
 	 }

	 MDFN_printf("\n");

	 MDFNGameInfo->LoadCD(&CDInterfaces);
	}

	LoadCommonPost(path);

	//
	//
	rmd.release();
 }
 catch(std::exception &e)
 {
	MDFN_Notify(MDFN_NOTICE_ERROR, "%s", e.what());

	for(unsigned i = 0; i < CDInterfaces.size(); i++)
	{
	 if(CDInterfaces[i])
	 {
	  delete CDInterfaces[i];
	  CDInterfaces[i] = NULL;
	 }
	}
	CDInterfaces.clear();

	if(MDFNGameInfo != NULL)
	{
	 memset(MDFNGameInfo->MD5, 0, sizeof(MDFNGameInfo->MD5));
	 MDFNGameInfo->RMD = NULL;
	 MDFNGameInfo = NULL;
	}

	if(CustomPalette != NULL)
	{
	 delete[] CustomPalette;
	 CustomPalette = NULL;
	}
	CustomPaletteNumEntries = 0;

	MDFN_ClearAllOverrideSettings();

	return NULL;
 }

 return MDFNGameInfo;
}

static MDFN_COLD void LoadIPS(MDFNFILE* GameFile, const std::string& path)
{
 MDFN_printf(_("Applying IPS file \"%s\"...\n"), path.c_str());

 try
 {
  FileStream IPSFile(path, FileStream::MODE_READ);

  GameFile->ApplyIPS(&IPSFile);
 }
 catch(MDFN_Error &e)
 {
  MDFN_indent(1);
  MDFN_printf(_("Failed: %s\n"), e.what());
  MDFN_indent(-1);
  if(e.GetErrno() != ENOENT)
   throw;
 }
 catch(std::exception &e)
 {
  MDFN_indent(1);
  MDFN_printf(_("Failed: %s\n"), e.what());
  MDFN_indent(-1);
  throw;
 }
}

static MDFN_COLD MDFNGI* FindCompatibleModule(const char* force_module, MDFNFILE* gf)
{
 //for(unsigned pass = 0; pass < 2; pass++)
 //{
	for(std::list<MDFNGI *>::iterator it = MDFNSystemsPrio.begin(); it != MDFNSystemsPrio.end(); it++)  //_unsigned int x = 0; x < MDFNSystems.size(); x++)
	{
	 if(force_module)
	 {
          if(!strcmp(force_module, (*it)->shortname))
          {
	   if(!(*it)->Load)
	   {
	    if((*it)->LoadCD)
             throw MDFN_Error(0, _("Specified system only supports CD(physical, or image files, such as *.cue and *.toc) loading."));
	    else
             throw MDFN_Error(0, _("Specified system does not support normal file loading."));
	   }
           return(*it);
          }
	 }
	 else
	 {
	  char tmpstr[256];
	  trio_snprintf(tmpstr, 256, "%s.enable", (*it)->shortname);

	  // Is module enabled?
	  if(!MDFN_GetSettingB(tmpstr))
	  {
	   MDFN_printf(_("Skipping module \"%s\" per \"%s\" setting.\n"), (*it)->shortname, tmpstr);
	   continue; 
	  }

	  if(!(*it)->Load || !(*it)->TestMagic)
	   continue;

	  gf->rewind();

	  if((*it)->TestMagic(gf))
	  {
	   return(*it);
	  }
	 }
	}
 //}

 return(NULL);
}

MDFNGI *MDFNI_LoadGame(const char *force_module, const char* path, bool force_cd)
{
 assert(path != nullptr);
 const size_t path_len = strlen(path);

 MDFNI_CloseGame();

 MDFN_printf(_("Loading %s...\n"), path);

 if(force_cd || (path_len > 4 && (!MDFN_strazicmp(path + path_len - 4, ".cue") || !MDFN_strazicmp(path + path_len - 4, ".toc") || !MDFN_strazicmp(path + path_len - 4, ".ccd") || !MDFN_strazicmp(path + path_len - 4, ".m3u"))))
 {
  return LoadCD(force_module, path);
 }

 try
 {
	MDFN_AutoIndent aind(1);
	std::vector<FileExtensionSpecStruct> valid_iae;
	std::unique_ptr<RMD_Layout> rmd(new RMD_Layout());

	MDFNGameInfo = NULL;

        GetFileBase(path);

	// Construct a NULL-delimited list of known file extensions for MDFNFILE
	for(unsigned int i = 0; i < MDFNSystems.size(); i++)
	{
	 const FileExtensionSpecStruct *curexts = MDFNSystems[i]->FileExtensions;

	 // If we're forcing a module, only look for extensions corresponding to that module
	 if(force_module && strcmp(MDFNSystems[i]->shortname, force_module))
	  continue;

	 if(curexts)	
 	  while(curexts->extension && curexts->description)
	  {
	   valid_iae.push_back(*curexts);
           curexts++;
 	  }
	}
	{
	 FileExtensionSpecStruct tmpext = { NULL, NULL };
	 valid_iae.push_back(tmpext);
	}

	MDFNFILE GameFile(path, &valid_iae[0], _("game"));
	//printf("FBASE=%s,EXT=%s\n", GameFile.fbase, GameFile.ext);

	LoadIPS(&GameFile, MDFN_MakeFName(MDFNMKF_IPS, 0, 0));

	MDFNGameInfo = FindCompatibleModule(force_module, &GameFile);;

        if(!MDFNGameInfo)
        {
	 if(force_module)
          throw MDFN_Error(0, _("Unrecognized system \"%s\"!"), force_module);
	 else
          throw MDFN_Error(0, _("Unrecognized file format."));
        }

	MDFN_printf(_("Using module: %s(%s)\n"), MDFNGameInfo->shortname, MDFNGameInfo->fullname);
	{
	 MDFN_AutoIndent aindentgm(1);

	 assert(MDFNGameInfo->soundchan != 0);

         MDFNGameInfo->name.clear();
	 MDFNGameInfo->DesiredInput.clear();
         MDFNGameInfo->rotated = 0;
	 MDFNGameInfo->RMD = rmd.get();

         {
	  std::string modoverride_settings_file_path = MDFN_GetBaseDirectory() + std::string(PSS) + std::string(MDFNGameInfo->shortname) + std::string(".cfg");
	  MDFN_LoadSettings(modoverride_settings_file_path.c_str(), true);
         }
	 {
	  std::string pgcoverride_settings_file_path = MDFN_MakeFName(MDFNMKF_PGCONFIG, 0, NULL);
	  MDFN_LoadSettings(pgcoverride_settings_file_path.c_str(), true);
 	 }

	 MDFN_printf("\n");

	 GameFile.rewind();
         MDFNGameInfo->Load(&GameFile);
	}

	LoadCommonPost(path);
	rmd.release();
 }
 catch(std::exception &e)
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, "%s", e.what());

  if(MDFNGameInfo != NULL)
  {
   MDFNGameInfo->RMD = NULL;
   MDFNGameInfo = NULL;
  }

  if(CustomPalette != NULL)
  {
   delete[] CustomPalette;
   CustomPalette = NULL;
  }
  CustomPaletteNumEntries = 0;

  MDFN_ClearAllOverrideSettings();

  return(NULL);
 }

 return(MDFNGameInfo);
}

static void BuildDynamicSetting(MDFNSetting *setting, const char *system_name, const char *name, uint32 flags, const char *description, MDFNSettingType type,
        const char *default_value, const char *minimum = NULL, const char *maximum = NULL,
        bool (*validate_func)(const char *name, const char *value) = NULL, void (*ChangeNotification)(const char *name) = NULL)
{
 char setting_name[256];

 memset(setting, 0, sizeof(MDFNSetting));

 trio_snprintf(setting_name, 256, "%s.%s", system_name, name);

 setting->name = strdup(setting_name);
 setting->description = description;
 setting->type = type;
 setting->flags = flags;
 setting->default_value = default_value;
 setting->minimum = minimum;
 setting->maximum = maximum;
 setting->validate_func = validate_func;
 setting->ChangeNotification = ChangeNotification;
}

bool MDFNI_InitializeModules(void)
{
 Time::Time_Init();
 CDUtility::CDUtility_Init();
 //
 //
 //
 static MDFNGI *InternalSystems[] =
 {
  #ifdef WANT_NES_EMU
  &EmulatedNES,
  #endif

  #ifdef WANT_SNES_EMU
  &EmulatedSNES,
  #endif

  #ifdef WANT_SNES_FAUST_EMU
  &EmulatedSNES_Faust,
  #endif

  #ifdef WANT_GB_EMU
  &EmulatedGB,
  #endif

  #ifdef WANT_GBA_EMU
  &EmulatedGBA,
  #endif

  #ifdef WANT_PCE_EMU
  &EmulatedPCE,
  #endif

  #ifdef WANT_PCE_FAST_EMU
  &EmulatedPCE_Fast,
  #endif

  #ifdef WANT_LYNX_EMU
  &EmulatedLynx,
  #endif

  #ifdef WANT_MD_EMU
  &EmulatedMD,
  #endif

  #ifdef WANT_PCFX_EMU
  &EmulatedPCFX,
  #endif

  #ifdef WANT_NGP_EMU
  &EmulatedNGP,
  #endif

  #ifdef WANT_PSX_EMU
  &EmulatedPSX,
  #endif

  #ifdef WANT_SS_EMU
  &EmulatedSS,
  #endif

  #ifdef WANT_SSFPLAY_EMU
  &EmulatedSSFPlay,
  #endif

  #ifdef WANT_VB_EMU
  &EmulatedVB,
  #endif

  #ifdef WANT_WSWAN_EMU
  &EmulatedWSwan,
  #endif

  #ifdef WANT_SMS_EMU
  &EmulatedSMS,
  &EmulatedGG,
  #endif

  &EmulatedCDPlay,
  &EmulatedDEMO
 };

	// Static, clear it first
	MDFNSystems.clear();

 static_assert(MEDNAFEN_VERSION_NUMERIC >= 0x00102101, "Bad MEDNAFEN_VERSION_NUMERIC");

 for(unsigned int i = 0; i < sizeof(InternalSystems) / sizeof(MDFNGI *); i++)
  AddSystem(InternalSystems[i]);

 for(unsigned int i = 0; i < MDFNSystems.size(); i++)
  MDFNSystemsPrio.push_back(MDFNSystems[i]);

 MDFNSystemsPrio.sort(MDFNSystemsPrio_CompareFunc);
 //
 //
 //
 std::string modules_string;
 for(auto& m : MDFNSystemsPrio)
 {
  if(modules_string.size())
   modules_string += " ";
  modules_string += std::string(m->shortname);
 }
 MDFNI_printf(_("Emulation modules: %s\n"), modules_string.c_str());

 return(1);
}

int MDFNI_Initialize(const char *basedir, const std::vector<MDFNSetting> &DriverSettings)
{
	// FIXME static
	static std::vector<MDFNSetting> dynamic_settings;
	dynamic_settings.clear();

	// DO NOT REMOVE/DISABLE THESE MATH AND COMPILER SANITY TESTS.  THEY EXIST FOR A REASON.
	//uint64 st = Time::MonoUS();
//	if(!MDFN_RunMathTests())
//	{
//	 return(0);
//	}
	//printf("tests time: %llu\n", Time::MonoUS() - st);

	for(unsigned x = 0; x < 16; x++)
	{
	 PortDevice[x] = ~0U;
	 PortData[x] = NULL;
	 PortDataLen[x] = 0;
	}

//	lzo_init();

	MDFN_SetBaseDirectory(basedir);

	MDFN_InitFontData();

	// Generate dynamic settings
	for(unsigned int i = 0; i < MDFNSystems.size(); i++)
	{
	 MDFNSetting setting;
	 const char *sysname;

	 sysname = (const char *)MDFNSystems[i]->shortname;

	 if(!MDFNSystems[i]->soundchan)
	  printf("0 sound channels for %s????\n", sysname);

	 if(MDFNSystems[i]->soundchan == 2)
	 {
	  BuildDynamicSetting(&setting, sysname, "forcemono", MDFNSF_COMMON_TEMPLATE | MDFNSF_CAT_SOUND, CSD_forcemono, MDFNST_BOOL, "0");
	  dynamic_settings.push_back(setting);
	 }

	 BuildDynamicSetting(&setting, sysname, "enable", MDFNSF_COMMON_TEMPLATE, CSD_enable, MDFNST_BOOL, "1");
	 dynamic_settings.push_back(setting);

	 BuildDynamicSetting(&setting, sysname, "tblur", MDFNSF_COMMON_TEMPLATE | MDFNSF_CAT_VIDEO, CSD_tblur, MDFNST_BOOL, "0");
         dynamic_settings.push_back(setting);

         BuildDynamicSetting(&setting, sysname, "tblur.accum", MDFNSF_COMMON_TEMPLATE | MDFNSF_CAT_VIDEO, CSD_tblur_accum, MDFNST_BOOL, "0");
         dynamic_settings.push_back(setting);

         BuildDynamicSetting(&setting, sysname, "tblur.accum.amount", MDFNSF_COMMON_TEMPLATE | MDFNSF_CAT_VIDEO, CSD_tblur_accum_amount, MDFNST_FLOAT, "50", "0", "100");
	 dynamic_settings.push_back(setting);
	}

	// First merge all settable settings, then load the settings from the SETTINGS FILE OF DOOOOM
	MDFN_MergeSettings(MednafenSettings);
        MDFN_MergeSettings(dynamic_settings);
	MDFN_MergeSettings(MDFNMP_Settings);

	if(DriverSettings.size())
 	 MDFN_MergeSettings(DriverSettings);

	for(unsigned int x = 0; x < MDFNSystems.size(); x++)
	{
	 if(MDFNSystems[x]->Settings)
	  MDFN_MergeSettings(MDFNSystems[x]->Settings);
	}

	MDFN_MergeSettings(RenamedSettings);

	MDFN_FinalizeSettings();

	#ifdef WANT_DEBUGGER
	MDFNDBG_Init();
	#endif

        return(1);
}

int MDFNI_LoadSettings(const char* path)
{
 try
 {
  if(!MDFN_LoadSettings(path))
   return -1;
 }
 catch(std::exception &e)
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, "%s", e.what());
  return 0;
 }

 return 1;
}

bool MDFNI_SaveSettings(const char* path)
{
 try
 {
  MDFN_SaveSettings(path);
 }
 catch(std::exception &e)
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, "%s", e.what());
  return false;
 } 
 return true;
}

void MDFNI_Kill(void)
{
 MDFN_KillSettings();
}

static double multiplier_save, volume_save;
static std::vector<int16> SoundBufPristine;

static void ProcessAudio(EmulateSpecStruct *espec)
{
 if(espec->SoundVolume != 1)
  volume_save = espec->SoundVolume;

 if(espec->soundmultiplier != 1)
  multiplier_save = espec->soundmultiplier;

 if(espec->SoundBuf && espec->SoundBufSize)
 {
  int16 *const SoundBuf = espec->SoundBuf + espec->SoundBufSizeALMS * MDFNGameInfo->soundchan;
  int32 SoundBufSize = espec->SoundBufSize - espec->SoundBufSizeALMS;
  const int32 SoundBufMaxSize = espec->SoundBufMaxSize - espec->SoundBufSizeALMS;

  //
  // Sound reverse code goes before copying sound data to SoundBufPristine.
  //
  if(espec->NeedSoundReverse)
  {
   int16 *yaybuf = SoundBuf;
   int32 slen = SoundBufSize;

   if(MDFNGameInfo->soundchan == 1)
   {
    for(int x = 0; x < (slen / 2); x++)    
    {
     int16 cha = yaybuf[slen - x - 1];
     yaybuf[slen - x - 1] = yaybuf[x];
     yaybuf[x] = cha;
    }
   }
   else if(MDFNGameInfo->soundchan == 2)
   {
    for(int x = 0; x < (slen * 2) / 2; x++)
    {
     int16 cha = yaybuf[slen * 2 - (x&~1) - ((x&1) ^ 1) - 1];
     yaybuf[slen * 2 - (x&~1) - ((x&1) ^ 1) - 1] = yaybuf[x];
     yaybuf[x] = cha;
    }
   }
  }


//  if(qtrecorder && (volume_save != 1 || multiplier_save != 1))
//  {
//   int32 orig_size = SoundBufPristine.size();
//
//   SoundBufPristine.resize(orig_size + SoundBufSize * MDFNGameInfo->soundchan);
//   for(int i = 0; i < SoundBufSize * MDFNGameInfo->soundchan; i++)
//    SoundBufPristine[orig_size + i] = SoundBuf[i];
//  }

  try
  {
   if(wavrecorder)
    wavrecorder->WriteSound(SoundBuf, SoundBufSize);
  }
  catch(std::exception &e)
  {
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
   delete wavrecorder;
   wavrecorder = NULL;
  }

  if(multiplier_save != LastSoundMultiplier)
  {
   ff_resampler.time_ratio(multiplier_save, 0.9965);
   LastSoundMultiplier = multiplier_save;
  }

  if(multiplier_save != 1)
  {
   if(FFDiscard)
   {
    if(SoundBufSize >= multiplier_save)
     SoundBufSize /= multiplier_save;
   }
   else
   {
    if(MDFNGameInfo->soundchan == 2)
    {
     assert(ff_resampler.max_write() >= SoundBufSize * 2);

     for(int i = 0; i < SoundBufSize * 2; i++)
      ff_resampler.buffer()[i] = SoundBuf[i];
    }
    else
    {
     assert(ff_resampler.max_write() >= SoundBufSize * 2);

     for(int i = 0; i < SoundBufSize; i++)
     {
      ff_resampler.buffer()[i * 2] = SoundBuf[i];
      ff_resampler.buffer()[i * 2 + 1] = 0;
     }
    }   
    ff_resampler.write(SoundBufSize * 2);

    int avail = ff_resampler.avail();
    int real_read = std::min((int)(SoundBufMaxSize * MDFNGameInfo->soundchan), avail);

    if(MDFNGameInfo->soundchan == 2)
     SoundBufSize = ff_resampler.read(SoundBuf, real_read ) >> 1;
    else
     SoundBufSize = ff_resampler.read_mono_hack(SoundBuf, real_read );

    avail -= real_read;

    if(avail > 0)
    {
     printf("ff_resampler.avail() > espec->SoundBufMaxSize * MDFNGameInfo->soundchan - %d\n", avail);
     ff_resampler.clear();
    }
   }
  }

  if(volume_save != 1)
  {
   if(volume_save < 1)
   {
    int volume = (int)(16384 * volume_save);

    for(int i = 0; i < SoundBufSize * MDFNGameInfo->soundchan; i++)
     SoundBuf[i] = (SoundBuf[i] * volume) >> 14;
   }
   else
   {
    int volume = (int)(256 * volume_save);

    for(int i = 0; i < SoundBufSize * MDFNGameInfo->soundchan; i++)
    {
     int temp = ((SoundBuf[i] * volume) >> 8) + 32768;

     temp = clamp_to_u16(temp);

     SoundBuf[i] = temp - 32768;
    }
   }
  }

  // TODO: Optimize this.
  if(MDFNGameInfo->soundchan == 2 && MDFN_GetSettingB(std::string(std::string(MDFNGameInfo->shortname) + ".forcemono")))
  {
   for(int i = 0; i < SoundBufSize * MDFNGameInfo->soundchan; i += 2)
   {
    // We should use division instead of arithmetic right shift for correctness(rounding towards 0 instead of negative infinitininintinity), but I like speed.
    int32 mixed = (SoundBuf[i + 0] + SoundBuf[i + 1]) >> 1;

    SoundBuf[i + 0] =
    SoundBuf[i + 1] = mixed;
   }
  }

  espec->SoundBufSize = espec->SoundBufSizeALMS + SoundBufSize;
 } // end to:  if(espec->SoundBuf && espec->SoundBufSize)
}

void MDFN_MidSync(EmulateSpecStruct *espec)
{
 if(!MDFNnetplay)
 {
  ProcessAudio(espec);

  MDFND_MidSync(espec);

  espec->SoundBufSizeALMS = espec->SoundBufSize;
  espec->MasterCyclesALMS = espec->MasterCycles;

  if(MDFNGameInfo->TransformInput)	// Call after MDFND_MidSync, and before MDFNMOV_ProcessInput
   MDFNGameInfo->TransformInput();
 }

 // Call even during netplay, so input-recording movies recorded during netplay will play back properly.
 MDFNMOV_ProcessInput(PortData, PortDataLen, MDFNGameInfo->PortInfo.size());
}

void MDFN_MidLineUpdate(EmulateSpecStruct *espec, int y)
{
 //MDFND_MidLineUpdate(espec, y);
}

void MDFNI_Emulate(EmulateSpecStruct *espec)
{
 multiplier_save = 1;
 volume_save = 1;

 espec->CustomPalette = CustomPalette;
 espec->CustomPaletteNumEntries = CustomPaletteNumEntries;

 // Initialize some espec member data to zero, to catch some types of bugs.
 espec->DisplayRect.x = 0;
 espec->DisplayRect.w = 0;
 espec->DisplayRect.y = 0;
 espec->DisplayRect.h = 0;

 assert((bool)(espec->SoundBuf != NULL) == (bool)espec->SoundRate && (bool)espec->SoundRate == (bool)espec->SoundBufMaxSize);

 espec->SoundBufSize = 0;

 espec->VideoFormatChanged = false;
 espec->SoundFormatChanged = false;

 if(last_pixel_format != espec->surface->format)
 {
  espec->VideoFormatChanged = true;

  last_pixel_format = espec->surface->format;
 }

 if(espec->SoundRate != last_sound_rate)
 {
  espec->SoundFormatChanged = true;
  last_sound_rate = espec->SoundRate;

  ff_resampler.buffer_size((espec->SoundRate / 2) * 2);
 }

 // We want to record movies without any dropped video frames and without fast-forwarding sound distortion and without custom volume.
 // The same goes for WAV recording(sans the dropped video frames bit :b).
// if(qtrecorder || wavrecorder)
// {
//  multiplier_save = espec->soundmultiplier;
//  espec->soundmultiplier = 1;
//
//  volume_save = espec->SoundVolume;
//  espec->SoundVolume = 1;
// }

 if(MDFNGameInfo->TransformInput)
  MDFNGameInfo->TransformInput();

 Netplay_Update(PortDevice, PortData, PortDataLen);

 MDFNMOV_ProcessInput(PortData, PortDataLen, MDFNGameInfo->PortInfo.size());

// if(qtrecorder)
//  espec->skip = 0;

 if(TBlur_IsOn())
  espec->skip = 0;

 if(espec->NeedRewind)
 {
  if(MDFNnetplay)
  {
   espec->NeedRewind = false;
   MDFN_Notify(MDFN_NOTICE_STATUS, _("Can't rewind during netplay."));
  }
 }

 // Don't even save states with state rewinding if netplay is enabled, it will degrade netplay performance, and can cause
 // desynchs with some emulation(IE SNES based on bsnes).

 if(MDFNnetplay)
  espec->NeedSoundReverse = false;
 else
  espec->NeedSoundReverse = MDFNSRW_Frame(espec->NeedRewind);

 MDFNGameInfo->Emulate(espec);

 if(MDFNnetplay)
  Netplay_PostProcess(PortDevice, PortData, PortDataLen);

 //
 // Sanity checks
 //
 if(!espec->skip)
 {
  if(espec->DisplayRect.h == 0)
  {
   fprintf(stderr, "[BUG] espec->DisplayRect.h == 0\n");
  }
 }

 if(!espec->MasterCycles)
 {
  fprintf(stderr, "[BUG] espec->MasterCycles == 0\n");
 }

 if(espec->MasterCycles < espec->MasterCyclesALMS)
 {
  fprintf(stderr, "[BUG] espec->MasterCycles < espec->MasterCyclesALMS\n");
 }

 //
 //
 //

 if(espec->InterlaceOn)
 {
  if(!PrevInterlaced)
   deint.ClearState();

  deint.Process(espec->surface, espec->DisplayRect, espec->LineWidths, espec->InterlaceField);
  PrevInterlaced = true;
 }
 else
  PrevInterlaced = false;

 ProcessAudio(espec);

// if(qtrecorder)
// {
//  int16 *sb_backup = espec->SoundBuf;
//  int32 sbs_backup = espec->SoundBufSize;
//
//  if(SoundBufPristine.size())
//  {
//   espec->SoundBuf = &SoundBufPristine[0];
//   espec->SoundBufSize = SoundBufPristine.size() / MDFNGameInfo->soundchan;
//  }
//
//  try
//  {
//   qtrecorder->WriteFrame(espec->surface, espec->DisplayRect, espec->LineWidths, espec->SoundBuf, espec->SoundBufSize, espec->MasterCycles);
//  }
//  catch(std::exception &e)
//  {
//   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
//   delete qtrecorder;
//   qtrecorder = NULL;
//  }
//
//  SoundBufPristine.clear();
//
//  espec->SoundBuf = sb_backup;
//  espec->SoundBufSize = sbs_backup;
// }

 if(TBlur_IsOn())
  TBlur_Run(espec);
}

static void StateAction_RINP(StateMem* sm, const unsigned load, const bool data_only)
{
 char namebuf[16][2 + 8 + 1];

 if(!data_only)
 {
  for(unsigned x = 0; x < 16; x++)
  {
   trio_snprintf(namebuf[x], sizeof(namebuf[x]), "%02x%08x", x, PortDevice[x]);
  }
 }

 #define SFRIH(x) SFPTR8N(PortData[x], PortDataLen[x], namebuf[x])
 SFORMAT StateRegs[] =
 {
  SFRIH(0), SFRIH(1), SFRIH(2), SFRIH(3), SFRIH(4), SFRIH(5), SFRIH(6), SFRIH(7),
  SFRIH(8), SFRIH(9), SFRIH(10), SFRIH(11), SFRIH(12), SFRIH(13), SFRIH(14), SFRIH(15),
  SFEND
 };
 #undef SFRIH

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MDFNRINP", true);
}

void MDFN_StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 for(unsigned i = 0; i < DMStatus.size(); i++)
 {
  struct DriveMediaStatus tmp = DMStatus[i];
  char sname[32];
  SFORMAT StateRegs[] =
  {
   SFVARN(tmp.state_idx, "state_idx"),
   SFVARN(tmp.media_idx, "media_idx"),
   SFVARN(tmp.orientation_idx, "orientation_idx"),

   SFEND
  };

  trio_snprintf(sname, sizeof(sname), "MDFNDRIVE_%08x", i);

  if(MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, true) && load)
  {
   // Be sure to set media before loading the emulation module state, as setting media
   // may affect what state is saved in the emulation module code, and setting media
   // can also have side effects(that will be undone by the state load).
   if(tmp.state_idx != DMStatus[i].state_idx || tmp.media_idx != DMStatus[i].media_idx || tmp.orientation_idx != DMStatus[i].orientation_idx)
    MDFN_UntrustedSetMedia(i, tmp.state_idx, tmp.media_idx, tmp.orientation_idx);
  }
 }

 StateAction_RINP(sm, load, data_only);

 if(data_only)
  MDFNMOV_StateAction(sm, load);

 MDFNGameInfo->StateAction(sm, load, data_only);
}

static int curindent = 0;

void MDFN_indent(int indent)
{
 curindent += indent;
 if(curindent < 0)
 {
  fprintf(stderr, "MDFN_indent negative!\n");
  curindent = 0;
 }
}

static uint8 lastchar = 0;
void MDFN_printf(const char *format, ...) noexcept
{
 char *format_temp;
 char *temp;
 unsigned int x, newlen;

 va_list ap;
 va_start(ap,format);


 // First, determine how large our format_temp buffer needs to be.
 uint8 lastchar_backup = lastchar; // Save lastchar!
 for(newlen=x=0;x<strlen(format);x++)
 {
  if(lastchar == '\n' && format[x] != '\n')
  {
   int y;
   for(y=0;y<curindent;y++)
    newlen++;
  }
  newlen++;
  lastchar = format[x];
 }

 format_temp = (char *)malloc(newlen + 1); // Length + NULL character, duh
 
 // Now, construct our format_temp string
 lastchar = lastchar_backup; // Restore lastchar
 for(newlen=x=0;x<strlen(format);x++)
 {
  if(lastchar == '\n' && format[x] != '\n')
  {
   int y;
   for(y=0;y<curindent;y++)
    format_temp[newlen++] = ' ';
  }
  format_temp[newlen++] = format[x];
  lastchar = format[x];
 }

 format_temp[newlen] = 0;

 temp = trio_vaprintf(format_temp, ap);
 free(format_temp);

 MDFND_OutputInfo(temp);
 free(temp);

 va_end(ap);
}

void MDFN_Notify(MDFN_NoticeType t, const char* format, ...) noexcept
{
 char* s;
 va_list ap;

 va_start(ap, format);

 s = trio_vaprintf(format, ap);
 if(!s)
 {
  MDFND_OutputNotice(t, "Error allocating memory for the message!");
 }
 else
 {
  MDFND_OutputNotice(t, s);
  free(s);
 }

 va_end(ap);
}

void MDFN_DebugPrintReal(const char *file, const int line, const char *format, ...)
{
 char *temp;

 va_list ap;

 va_start(ap, format);

 temp = trio_vaprintf(format, ap);
 printf("%s:%d  %s\n", file, line, temp);
 free(temp);

 va_end(ap);
}

void MDFN_DoSimpleCommand(int cmd)
{
 MDFNGameInfo->DoSimpleCommand(cmd);
}

void MDFN_QSimpleCommand(int cmd)
{
 if(MDFNnetplay)
  NetplaySendCommand(cmd, 0);
 else
 {
  if(!MDFNMOV_IsPlaying())
  {
   MDFN_DoSimpleCommand(cmd);
   MDFNMOV_AddCommand(cmd);
  }
 }
}

void MDFNI_Power(void)
{
 assert(MDFNGameInfo);

 MDFN_QSimpleCommand(MDFN_MSC_POWER);
}

void MDFNI_Reset(void)
{
 assert(MDFNGameInfo);

 MDFN_QSimpleCommand(MDFN_MSC_RESET);
}

// Arcade-support functions


//
// Quick and dirty kludge until we can (re-)abstract DIP switch handling properly.
//
#ifdef WANT_NES_EMU
namespace MDFN_IEN_NES
{
void MDFN_VSUniToggleDIPView(void);
}
#endif
void MDFNI_ToggleDIPView(void)
{
#ifdef WANT_NES_EMU
 if(MDFNGameInfo == &EmulatedNES)
 {
  MDFN_IEN_NES::MDFN_VSUniToggleDIPView();
 }
#endif
}

void MDFNI_ToggleDIP(int which)
{
 assert(MDFNGameInfo);
 assert(which >= 0);

 MDFN_QSimpleCommand(MDFN_MSC_TOGGLE_DIP0 + which);
}

void MDFNI_InsertCoin(void)
{
 assert(MDFNGameInfo);
 
 MDFN_QSimpleCommand(MDFN_MSC_INSERT_COIN);
}

//
// Disk/Disc-based system support functions
//

/* Normal chain: MDFNI_SetMedia() -> NetplaySendCommand()
				-> MDFNMOVAddCommand()
				-> MDFN_UntrustedSetMedia()->MDFNGameInfo->SetMedia
							   ->MDFN_MediaSetNotification->MDFND_MediaSetNotification()

  MDFN_UntrustedSetMedia() may be called from the movie and netplay code after receiving command data.
  MDFN_UntrustedSetMedia() may be called from the core Mednafen save state code.

  MDFN_MediaSetNotification() might be called(in the future) from the emulation module code, particularly to notify the core and driver interface
  code of a program-triggered state change(like insert/ejecting a CD); assuming we ever emulate a system with such capabilities.
*/
void MDFN_MediaSetNotification(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{
 assert(drive_idx < DMStatus.size());
 //if(drive_idx >= DMStatus.size())
 // DMStatus.resize(drive_idx + 1);

 DMStatus[drive_idx].state_idx = state_idx;
 DMStatus[drive_idx].media_idx = media_idx;
 DMStatus[drive_idx].orientation_idx = orientation_idx;

 MDFND_MediaSetNotification(drive_idx, state_idx, media_idx, orientation_idx);
}

bool MDFN_UntrustedSetMedia(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{
 //printf("MDFN_UntrustedSetMedia: %d %d %d %d\n", drive_idx, state_idx, media_idx, orientation_idx);

 if(!MDFNGameInfo->SetMedia)
  return(false);

 if(drive_idx >= MDFNGameInfo->RMD->Drives.size())
  return(false);

 if(state_idx >= MDFNGameInfo->RMD->Drives[drive_idx].PossibleStates.size())
  return(false);

 if(media_idx >= MDFNGameInfo->RMD->Media.size())
  return(false);

 if(orientation_idx && orientation_idx >= MDFNGameInfo->RMD->Media[media_idx].Orientations.size())
  return(false);

 if(MDFNGameInfo->SetMedia(drive_idx, state_idx, media_idx, orientation_idx))
  MDFN_MediaSetNotification(drive_idx, state_idx, media_idx, orientation_idx);

 return(true);
}

bool MDFNI_SetMedia(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{
 assert(MDFNGameInfo);

 if(MDFNnetplay || MDFNMOV_IsRecording())
 {
  uint8 buf[4 * 4];

  MDFN_en32lsb(&buf[0x0], drive_idx);
  MDFN_en32lsb(&buf[0x4], state_idx);
  MDFN_en32lsb(&buf[0x8], media_idx);
  MDFN_en32lsb(&buf[0xC], orientation_idx);

  if(MDFNnetplay)
   NetplaySendCommand(MDFNNPCMD_SET_MEDIA, sizeof(buf), buf);

  if(MDFNMOV_IsRecording())
   MDFNMOV_AddCommand(MDFNNPCMD_SET_MEDIA, sizeof(buf), buf);
 }

 if(!MDFNnetplay && !MDFNMOV_IsPlaying())
  return MDFN_UntrustedSetMedia(drive_idx, state_idx, media_idx, orientation_idx);
 else
  return false;
}

void MDFNI_SetLayerEnableMask(uint64 mask)
{
 if(MDFNGameInfo && MDFNGameInfo->SetLayerEnableMask)
 {
  MDFNGameInfo->SetLayerEnableMask(mask);
 }
}

uint8* MDFNI_SetInput(const uint32 port, const uint32 type)
{
 if(MDFNGameInfo)
 {
  assert(port < 16 && port < MDFNGameInfo->PortInfo.size());
  assert(type < MDFNGameInfo->PortInfo[port].DeviceInfo.size());

  if(type != PortDevice[port])
  {
   size_t tmp_len = MDFNGameInfo->PortInfo[port].DeviceInfo[type].IDII.InputByteSize;
   uint8* tmp_ptr;

   tmp_ptr = (uint8*)malloc(tmp_len ? tmp_len : 1);	// Ensure PortData[port], for valid port, is never NULL, for easier handling in regards to stuff like memcpy()
							// (which may have "undefined" behavior when a pointer argument is NULL even when length == 0).
   memset(tmp_ptr, 0, tmp_len);

   if(PortData[port] != NULL)
    free(PortData[port]);

   PortData[port] = tmp_ptr;
   PortDataLen[port] = tmp_len;
   PortDevice[port] = type;

   MDFNGameInfo->SetInput(port, MDFNGameInfo->PortInfo[port].DeviceInfo[type].ShortName, PortData[port]);
   //MDFND_InputSetNotification(port, type, PortData[port]);
  }

  return PortData[port];
 }
 else
  return(NULL);
}

