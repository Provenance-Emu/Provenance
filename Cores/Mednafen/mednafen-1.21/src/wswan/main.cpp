/******************************************************************************/
/* Mednafen WonderSwan Emulation Module(based on Cygne)                       */
/******************************************************************************/
/* main.cpp:
**  Copyright (C) 2002 Dox dox@space.pl
**  Copyright (C) 2007-2017 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License version 2.
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

#include "wswan.h"
#include <mednafen/hash/md5.h>
#include <mednafen/mempatcher.h>
#include <mednafen/player.h>

#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <zlib.h>

#include "gfx.h"
#include "memory.h"
#include "start.inc"
#include "sound.h"
#include "v30mz.h"
#include "comm.h"
#include "rtc.h"
#include "eeprom.h"
#include "debug.h"

namespace MDFN_IEN_WSWAN
{

uint32 WS_InDebug = 0;
int 		wsc = 1;			/*color/mono*/
uint32		rom_size;

uint16 WSButtonStatus;


static bool IsWSR;
static uint8 WSRCurrentSong;
static uint8 WSRLastButtonStatus;

static void Reset(void)
{
	v30mz_reset();				/* Reset CPU */
	WSwan_MemoryReset();
	Comm_Reset();
        WSwan_GfxReset();
        WSwan_SoundReset();
	WSwan_InterruptReset();
	RTC_Reset();
	WSwan_EEPROMReset();

	for(unsigned u0 = 0; u0 < 0xc8; u0++)
	{
	 if(u0 != 0xC4 && u0 != 0xC5 && u0 != 0xBA && u0 != 0xBB)
	  WSwan_writeport(u0, startio[u0]);
	}

	v30mz_set_reg(NEC_SS, 0);
	v30mz_set_reg(NEC_SP, 0x2000);

	if(IsWSR)
	{
	 v30mz_set_reg(NEC_AW, WSRCurrentSong);
	}
}

static uint8* PortDeviceData;
static unsigned PortDeviceType;

static void Emulate(EmulateSpecStruct *espec)
{
 espec->DisplayRect.x = 0;
 espec->DisplayRect.y = 0;
 espec->DisplayRect.w = 224;
 espec->DisplayRect.h = 144;

 if(espec->VideoFormatChanged)
  WSwan_SetPixelFormat(espec->surface->format);

 if(espec->SoundFormatChanged)
  WSwan_SetSoundRate(espec->SoundRate);

 WSButtonStatus = MDFN_de16lsb(PortDeviceData);
 
 MDFNMP_ApplyPeriodicCheats();

 while(!wsExecuteLine(espec->surface, espec->skip))
 {

 }

 espec->SoundBufSize = WSwan_SoundFlush(espec->SoundBuf, espec->SoundBufMaxSize);

 espec->MasterCycles = v30mz_timestamp;
 v30mz_timestamp = 0;

 if(IsWSR)
 {
  bool needreload = false;

  Player_Draw(espec->surface, &espec->DisplayRect, WSRCurrentSong, espec->SoundBuf, espec->SoundBufSize);

  if((WSButtonStatus & 0x02) && !(WSRLastButtonStatus & 0x02))
  {
   WSRCurrentSong++;
   needreload = 1;
  }

  if((WSButtonStatus & 0x08) && !(WSRLastButtonStatus & 0x08))
  {
   WSRCurrentSong--;
   needreload = 1;
  }

  if((WSButtonStatus & 0x100) && !(WSRLastButtonStatus & 0x100))
   needreload = 1;

  if((WSButtonStatus & 0x01) && !(WSRLastButtonStatus & 0x01))
  {
   WSRCurrentSong += 10;
   needreload = 1;
  }

  if((WSButtonStatus & 0x04) && !(WSRLastButtonStatus & 0x04))
  {
   WSRCurrentSong -= 10;
   needreload = 1;
  }


  WSRLastButtonStatus = WSButtonStatus;

  if(needreload)
   Reset();
 }
}

typedef struct
{
 const uint8 id;
 const char *name;
} DLEntry;

static const DLEntry Developers[] =
{
 { 0x01, "Bandai" },
 { 0x02, "Taito" },
 { 0x03, "Tomy" },
 { 0x04, "Koei" },
 { 0x05, "Data East" },
 { 0x06, "Asmik" }, // Asmik Ace?
 { 0x07, "Media Entertainment" },
 { 0x08, "Nichibutsu" },
 { 0x0A, "Coconuts Japan" },
 { 0x0B, "Sammy" },
 { 0x0C, "Sunsoft" },
 { 0x0D, "Mebius" },
 { 0x0E, "Banpresto" },
 { 0x10, "Jaleco" },
 { 0x11, "Imagineer" },
 { 0x12, "Konami" },
 { 0x16, "Kobunsha" },
 { 0x17, "Bottom Up" },
 { 0x18, "Naxat" },	// Mechanic Arms?  Media Entertainment? Argh!
 { 0x19, "Sunrise" },
 { 0x1A, "Cyberfront" },
 { 0x1B, "Megahouse" },
 { 0x1D, "Interbec" },
 { 0x1E, "NAC" },
 { 0x1F, "Emotion" }, // Bandai Visual??
 { 0x20, "Athena" },
 { 0x21, "KID" },
 { 0x22, "HAL" },
 { 0x23, "Yuki-Enterprise" },
 { 0x24, "Omega Micott" },
 { 0x25, "Upstar" },
 { 0x26, "Kadokawa/Megas" },
 { 0x27, "Cocktail Soft" },
 { 0x28, "Squaresoft" },
 { 0x2A, "NTT DoCoMo" },
 { 0x2B, "TomCreate" },
 { 0x2D, "Namco" },
 { 0x2F, "Gust" },
 { 0x31, "Vanguard" },	// or Elorg?
 { 0x32, "Megatron" },
 { 0x33, "WiZ" },
 { 0x36, "Capcom" },
};

static bool TestMagic(MDFNFILE *fp)
{
 if(fp->ext != "ws" && fp->ext != "wsc" && fp->ext != "wsr")
  return false;

 if(fp->size() < 65536)
  return false;

 return true;
}

static void Cleanup(void)
{
 Comm_Kill();
 WSwan_MemoryKill();

 WSwan_SoundKill();

 if(wsCartROM)
 {
  delete[] wsCartROM;
  wsCartROM = NULL;
 }
}


static void CloseGame(void)
{
 if(!IsWSR)
 {
  try
  {
   WSwan_MemorySaveNV();	// Must be called before we delete[] wsCartRom.
  }
  catch(std::exception &e)
  {
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
  }
 }

 Cleanup();
}

static void Load(MDFNFILE *fp)
{
 try
 {
  bool IsWW = false;
  const uint64 fp_in_size = fp->size();
  uint32 real_rom_size;

  if(fp_in_size < 65536)
  {
   throw MDFN_Error(0, _("ROM image is too small."));
  }

  if(fp_in_size > 64 * 1024 * 1024)
  {
   throw MDFN_Error(0, _("ROM image is too large."));
  }

  real_rom_size = (fp_in_size + 0xFFFF) & ~0xFFFF;
  rom_size = round_up_pow2(real_rom_size);

  wsCartROM = new uint8[rom_size];
  memset(wsCartROM, 0, rom_size);

  // This real_rom_size vs rom_size funny business is intended primarily for handling
  // WSR files.
  if(real_rom_size < rom_size)
   memset(wsCartROM, 0xFF, rom_size - real_rom_size);

  fp->read(wsCartROM + (rom_size - real_rom_size), fp_in_size);

  if(!memcmp(wsCartROM + (rom_size - real_rom_size) + fp_in_size - 0x20, "WSRF", 4))
  {
   const uint8 *wsr_footer = wsCartROM + (rom_size - real_rom_size) + fp_in_size - 0x20;

   IsWSR = true;
   WSRCurrentSong = wsr_footer[0x5];
   WSRLastButtonStatus = 0xFF;

   Player_Init(256, "", "", "");
  }
  else
  {
   IsWSR = false;

   if(rom_size == 524288 && !memcmp(&wsCartROM[0x70000], "ELISA", 5) && crc32(0, &wsCartROM[0x7FFF0], 0x10) == 0x0d05ed64)
   {
    uint32 crc32_sans_l64k = crc32(0, wsCartROM, 0x70000);
    uint32 bl[] = { 0x63f00316, 0x60fd569b, 0xe11538f8 };
    bool blisted = false;

    //printf("%08x\n", crc32_sans_l64k);

    for(auto ch : bl)
    {
     if(crc32_sans_l64k == ch)
     {
      blisted = true;
      break;
     }
    }
 
    IsWW = !blisted;
   }
  }

  MDFN_printf(_("ROM:       %uKiB\n"), real_rom_size / 1024);
  md5_context md5;
  md5.starts();
  md5.update(wsCartROM, rom_size);
  md5.finish(MDFNGameInfo->MD5);
  MDFN_printf(_("ROM MD5:   0x%s\n"), md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str());

  uint8 header[10];
  memcpy(header, wsCartROM + rom_size - 10, 10);

  {
   const char *developer_name = "???";
   for(unsigned int x = 0; x < sizeof(Developers) / sizeof(DLEntry); x++)
   {
    if(Developers[x].id == header[0])
    {
     developer_name = Developers[x].name;
     break;
    }
   }
   MDFN_printf(_("Developer: %s (0x%02x)\n"), developer_name, header[0]);
  }

  uint32 SRAMSize = 0;
  eeprom_size = 0;

  switch(header[5])
  {
   case 0x01: SRAMSize =   8 * 1024; break;
   case 0x02: SRAMSize =  32 * 1024; break;

   case 0x03: SRAMSize = 128 * 1024; break;	// Taikyoku Igo.  Maybe it should only be 65536 bytes?

   case 0x04: SRAMSize = 256 * 1024; break;	// Dicing Knight, Judgement Silversword
   case 0x05: SRAMSize = 512 * 1024; break;	// Wonder Gate

   case 0x10: eeprom_size = 128; break;
   case 0x20: eeprom_size = 2*1024; break;
   case 0x50: eeprom_size = 1024; break;
  }

  //printf("Header5: %02x\n", header[5]);

  if(eeprom_size)
   MDFN_printf(_("EEPROM:  %d bytes\n"), eeprom_size);

  if(SRAMSize)
   MDFN_printf(_("Battery-backed RAM:  %d bytes\n"), SRAMSize);

  MDFN_printf(_("Recorded Checksum:  0x%04x\n"), header[8] | (header[9] << 8));
  {
   uint16 real_crc = 0;
   for(unsigned int i = 0; i < rom_size - 2; i++)
    real_crc += wsCartROM[i];
   MDFN_printf(_("Real Checksum:      0x%04x\n"), real_crc);
  }

  if(IsWW)
   MDFN_printf(_("WonderWitch firmware detected.\n"));

  if((header[8] | (header[9] << 8)) == 0x8de1 && (header[0]==0x01)&&(header[2]==0x27)) /* Detective Conan */
  {
   //puts("HAX");
   /* WS cpu is using cache/pipeline or there's protected ROM bank where pointing CS */
   wsCartROM[0xfffe8]=0xea;
   wsCartROM[0xfffe9]=0x00;
   wsCartROM[0xfffea]=0x00;
   wsCartROM[0xfffeb]=0x00;
   wsCartROM[0xfffec]=0x20;
  }

  if(!IsWSR)
  {
   if(header[6] & 0x1)
    MDFNGameInfo->rotated = MDFN_ROTATE90;
  }

  MDFNMP_Init(16384, (1 << 20) / 1024);

  #ifdef WANT_DEBUGGER
  WSwanDBG_Init();
  #endif

  WSwan_MemoryInit(MDFN_GetSettingB("wswan.language"), wsc, SRAMSize, IsWW);

  if(!IsWSR)
   WSwan_MemoryLoadNV();

  Comm_Init(MDFN_GetSettingB("wswan.excomm") ? MDFN_GetSettingS("wswan.excomm.path").c_str() : NULL);

  WSwan_GfxInit();
  MDFNGameInfo->fps = (uint32)((uint64)3072000 * 65536 * 256 / (159*256));
  MDFNGameInfo->GameSetMD5Valid = false;

  WSwan_SoundInit();

  RTC_Init();

  wsMakeTiles();

  Reset();
 }
 catch(...)
 {
  Cleanup();

  throw;
 }
}

static void SetInput(unsigned port, const char *type, uint8 *ptr)
{
 if(!port)
 {
  PortDeviceData = (uint8 *)ptr;
  PortDeviceType = strcmp(type, "gamepad");
 }
}

static void TransformInput(void)
{
 if(PortDeviceType)
 {
  uint16 butt_data = MDFN_de16lsb(PortDeviceData);
  unsigned x = (butt_data >> 0) & 0xF;
  unsigned y = (butt_data >> 4) & 0xF;
  unsigned b = (butt_data >> 8) & 0xF;
  const unsigned offs = MDFNGameInfo->rotated;
  x = ((x << offs) | (x >> (4 - offs))) & 0xF;
  y = ((y << offs) | (y >> (4 - offs))) & 0xF;
  b = ((b << offs) | (b >> (4 - offs))) & 0xF;

  if(MDFNGameInfo->rotated == MDFN_ROTATE90)
  {
   std::swap(x, y);
   std::swap(x, b);
  }
  b = ((b & 1) << 1) | ((b & 8) >> 1) | (b & 0x6) | ((butt_data >> 12) & 1);
  butt_data = (x << 0) | (y << 4) | (b << 8);
  //printf("%04x\n", butt_data);
  MDFN_en16lsb(PortDeviceData, butt_data);
 }
}

static void StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 if(IsWSR)
 {
  SFORMAT StateRegs[] =
  {
   SFVAR(WSRCurrentSong),
   SFVAR(WSRLastButtonStatus),
   SFEND
  };
  MDFNSS_StateAction(sm, load, data_only, StateRegs, "WSRP");
 }

 v30mz_StateAction(sm, load, data_only);
 if(load)
 {
  //printf("%d\n", v30mz_ICount);
  if(v30mz_ICount > 256)
   v30mz_ICount = 256;
 }

 // Call MemoryStateAction before others StateActions...
 WSwan_MemoryStateAction(sm, load, data_only);

 WSwan_GfxStateAction(sm, load, data_only);

 RTC_StateAction(sm, load, data_only);

 WSwan_InterruptStateAction(sm, load, data_only);

 WSwan_SoundStateAction(sm, load, data_only);

 WSwan_EEPROMStateAction(sm, load, data_only);

 Comm_StateAction(sm, load, data_only);
}

static void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_POWER:
  case MDFN_MSC_RESET:
	Reset();
	break;
 }
}

static const MDFNSetting_EnumList SexList[] =
{
 { "m", WSWAN_SEX_MALE },
 { "male", WSWAN_SEX_MALE, gettext_noop("Male") },

 { "f", WSWAN_SEX_FEMALE },
 { "female", WSWAN_SEX_FEMALE, gettext_noop("Female") },

 { "3", 3 },

 { NULL, 0 },
};

static const MDFNSetting_EnumList BloodList[] =
{
 { "a", WSWAN_BLOOD_A, "A" },
 { "b", WSWAN_BLOOD_B, "B" },
 { "o", WSWAN_BLOOD_O, "O" },
 { "ab", WSWAN_BLOOD_AB, "AB" },

 { "5", 5 },

 { NULL, 0 },
};

static const MDFNSetting_EnumList LanguageList[] =
{
 { "japanese", 0, gettext_noop("Japanese") },
 { "0", 0 },

 { "english", 1, gettext_noop("English") },
 { "1", 1 },

 { NULL, 0 },
};

static const MDFNSetting WSwanSettings[] =
{
 { "wswan.language", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Language games should display text in."), gettext_noop("The only game this setting is known to affect is \"Digimon Tamers - Battle Spirit\"."), MDFNST_ENUM, "english", NULL, NULL, NULL, NULL, LanguageList },
 { "wswan.name", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Name"), NULL, MDFNST_STRING, "Mednafen" },
 { "wswan.byear", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Birth Year"), NULL, MDFNST_UINT, "1989", "0", "9999" },
 { "wswan.bmonth", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Birth Month"), NULL, MDFNST_UINT, "6", "1", "12" },
 { "wswan.bday", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Birth Day"), NULL, MDFNST_UINT, "23", "1", "31" },
 { "wswan.sex", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Sex"), NULL, MDFNST_ENUM, "F", NULL, NULL, NULL, NULL, SexList },
 { "wswan.blood", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Blood Type"), NULL, MDFNST_ENUM, "O", NULL, NULL, NULL, NULL, BloodList },

 { "wswan.excomm", MDFNSF_EMU_STATE | MDFNSF_SUPPRESS_DOC, gettext_noop("Enable comms to external program."), NULL, MDFNST_BOOL, "0" },
 { "wswan.excomm.path", MDFNSF_EMU_STATE | MDFNSF_SUPPRESS_DOC, gettext_noop("Comms external program path."), NULL, MDFNST_STRING, "wonderfence" },

 { NULL }
};

//
// X* and Y* buttons are discrete buttons and not D-pads nor sticks(so for example, it's possible to press "up" and "down" simultaneously).
//
static const IDIISG IDII_GP =
{
 IDIIS_Button("up-x",   	"X1(X UP ↑)", 0),
 IDIIS_Button("right-x",	"X2(X RIGHT →)", 3),
 IDIIS_Button("down-x",	"X3(X DOWN ↓)", 1),
 IDIIS_Button("left-x",	"X4(X LEFT ←)", 2),

 IDIIS_Button("up-y", 	"Y1(Y UP ↑)", 4),
 IDIIS_Button("right-y", 	"Y2(Y RIGHT →)", 7),
 IDIIS_Button("down-y", 	"Y3(Y DOWN ↓)", 5),
 IDIIS_Button("left-y", 	"Y4(Y LEFT ←)", 6),

 IDIIS_Button("start", "Start", 8),
 IDIIS_ButtonCR("a", "A", 10),
 IDIIS_ButtonCR("b", "B", 9),
};

static const IDIISG IDII_GPRAA =
{
 IDIIS_Button("up-x",   	"X1(X UP ↑)", 0),
 IDIIS_Button("right-x",	"X2(X RIGHT →)", 3),
 IDIIS_Button("down-x",	"X3(X DOWN ↓)", 1),
 IDIIS_Button("left-x",	"X4(X LEFT ←)", 2),

 IDIIS_Button("up-y", 	"Y1(Y UP ↑)", 4),
 IDIIS_Button("right-y", 	"Y2(Y RIGHT →)", 7),
 IDIIS_Button("down-y", 	"Y3(Y DOWN ↓)", 5),
 IDIIS_Button("left-y", 	"Y4(Y LEFT ←)", 6),

 IDIIS_Button("ap","A'(center, upper)", 11),
 IDIIS_Button("a", "A (right)", 12),
 IDIIS_Button("b", "B (center, lower)", 10),
 IDIIS_Button("bp","B'(left)", 9),

 IDIIS_Button("start", "Start", 8),
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfo =
{
 {
  "gamepad",
  "Gamepad",
  NULL,
  IDII_GP,
 },

 {
  "gamepadraa",
  "Gamepad(Rotation Auto-Adjust)",
  NULL,
  IDII_GPRAA,
 }
};

static const std::vector<InputPortInfoStruct> PortInfo =
{
 { "builtin", "Built-In", InputDeviceInfo, "gamepad" }
};

#ifdef WANT_DEBUGGER
static DebuggerInfoStruct DBGInfo =
{
 "shift_jis",
 7 + 1 + 8,	// Fixme, probably not right...  maximum number of prefixes + 1 for opcode + 4 for operand(go with 8 to be safe)
 1,             // Instruction alignment(bytes)
 16,
 20,
 0x0000,
 ~0U,

 WSwanDBG_MemPeek,
 WSwanDBG_Disassemble,
 WSwanDBG_ToggleSyntax,
 WSwanDBG_IRQ,
 NULL, //NESDBG_GetVector,
 WSwanDBG_FlushBreakPoints,
 WSwanDBG_AddBreakPoint,
 WSwanDBG_SetCPUCallback,
 WSwanDBG_EnableBranchTrace,
 WSwanDBG_GetBranchTrace,
 WSwan_GfxSetGraphicsDecode,
};
#endif

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".ws", gettext_noop("WonderSwan ROM Image") },
 { ".wsc", gettext_noop("WonderSwan Color ROM Image") },
 { ".wsr", gettext_noop("WonderSwan Music Rip") },
 { NULL, NULL }
};

}

using namespace MDFN_IEN_WSWAN;

MDFNGI EmulatedWSwan =
{
 "wswan",
 "WonderSwan",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 #ifdef WANT_DEBUGGER
 &DBGInfo,
 #else
 NULL,
 #endif
 PortInfo,
 Load,
 TestMagic,
 NULL,
 NULL,
 CloseGame,

 WSwan_SetLayerEnableMask,
 "Background\0Foreground\0Sprites\0",

 NULL,
 NULL,

 NULL,
 0,

 CheatInfo_Empty,

 false,
 StateAction,
 Emulate,
 TransformInput,
 SetInput,
 NULL,
 DoSimpleCommand,
 NULL,
 WSwanSettings,
 MDFN_MASTERCLOCK_FIXED(3072000),
 0,
 false, // Multires possible?

 224,   // lcm_width
 144,   // lcm_height
 NULL,  // Dummy

 224,	// Nominal width
 144,	// Nominal height

 224,	// Framebuffer width
 144,	// Framebuffer height

 2,     // Number of output sound channels
};

