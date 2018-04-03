/*
    Copyright (C) 1998-2004  Charles MacDonald

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#include "shared.h"
#include <mednafen/mempatcher.h>

namespace MDFN_IEN_SMS
{

bitmap_t bitmap;
input_t input;
static int32 SoftResetCount;
static unsigned sls, sle;

/* Run the virtual console emulation for one frame */
void system_frame(int skip_render)
{
    /* Debounce pause key */
    if(input.system & INPUT_PAUSE)
    {
        if(!sms.paused)
        {
            sms.paused = 1;

	    z80_nmi();
        }
    }
    else
    {
         sms.paused = 0;
    }

    if(SoftResetCount)
    {
     SoftResetCount--;
     if(!SoftResetCount)
      input.system &= ~INPUT_RESET;     
    }
    SMS_VDPRunFrame(skip_render);
}


void system_reset(void)
{
    SoftResetCount = 0;

    Cart_Reset();

    sms_reset();
    pio_reset();
    vdp_reset();
    render_reset();
    SMS_SoundReset();
}

static void StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(SoftResetCount),
  SFVAR(sms.cycle_counter),
  SFPTR8N(sms.wram, 0x2000, "RAM"),

  SFVAR(sms.paused),

  SFVAR(input.pad[0]),
  SFVAR(input.pad[1]),

  SFVAR(input.analog[0]),
  SFVAR(input.analog[1]),

  SFVAR(input.system),

  SFVAR(sms.fm_detect),
  SFVAR(sms.memctrl),

  //SFVAR(z80_runtime),
  //SFPTR8(CPUExRAM, 16384),
  //SFVAR(FlashStatusEnable),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAIN");
 z80_state_action(sm, load, data_only, "Z80");
 Cart_StateAction(sm, load, data_only);
 SMS_PIOStateAction(sm, load, data_only);
 SMS_SoundStateAction(sm, load, data_only);
 SMS_VDPStateAction(sm, load, data_only);

 if(load)
 {
  if(sms.cycle_counter > 1000)
  {
   sms.cycle_counter = 1000;
   puts("sms.cycle_counter sanity failed");
  }
 } 
}

static uint8 *InputPtrs[2];

static void SetInput(unsigned port, const char *type, uint8 *ptr)
{
 InputPtrs[port] = (uint8 *)ptr;
}

static void Emulate(EmulateSpecStruct *espec)
{
 if(espec->VideoFormatChanged)
  SMS_VDPSetPixelFormat(espec->surface->format, espec->CustomPalette);

 if(espec->SoundFormatChanged)
  SMS_SetSoundRate(espec->SoundRate);


 sms.timestamp = 0;

 input.pad[0] = *InputPtrs[0] & 0x3F;

 if(IS_SMS)
 {
  input.pad[1] = *InputPtrs[1] & 0x3F;

  if((*InputPtrs[0] | *InputPtrs[1]) & 0x40)
   input.system |= INPUT_PAUSE;
  else
   input.system &= ~INPUT_PAUSE;
 }
 else // GG:
 {
  if(*InputPtrs[0] & 0x40)
  {
   input.system |= INPUT_START;
  }
  else
   input.system &= ~INPUT_START;
 }

 MDFNMP_ApplyPeriodicCheats();

 if(sms.console == CONSOLE_GG)
 {
  espec->DisplayRect.x = 48;
  espec->DisplayRect.y = 48;
  espec->DisplayRect.w = 160;
  espec->DisplayRect.h = 144;
 }
 else
 {
  espec->DisplayRect.x = 0;
  espec->DisplayRect.y = sls;
  espec->DisplayRect.w = 256;
  espec->DisplayRect.h = sle + 1 - sls;
 }

 bitmap.data = (uint8*)espec->surface->pixels;
 bitmap.width = 256;
 bitmap.height = 240;
 bitmap.pitch = espec->surface->pitchinpix * sizeof(uint32);

 system_frame(espec->skip);

 espec->MasterCycles = sms.timestamp;
 espec->SoundBufSize = SMS_SoundFlush(espec->SoundBuf, espec->SoundBufMaxSize);
}

static void Cleanup(void)
{
 Cart_Close();
 sms_shutdown();
 pio_shutdown();
 vdp_shutdown();
 render_shutdown();
 SMS_SoundClose();
}

static void CloseGame(void)
{
 try
 {
  Cart_SaveNV();
 }
 catch(std::exception &e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
 }

 Cleanup();
}

static void LoadCommon(MDFNFILE *fp)
{
 try
 {
  /* Assign default settings (US NTSC machine) */
  sms.display     = DISPLAY_NTSC;

  sms.territory   = MDFN_GetSettingI("sms.territory");
  sms.use_fm      = false;

  Cart_Init(fp);
  Cart_LoadNV();

  if(IS_SMS && sms.territory == TERRITORY_DOMESTIC)
   sms.use_fm = MDFN_GetSettingB("sms.fm");

  MDFNMP_Init(1024, 65536 / 1024);

  system_assign_device(PORT_A, DEVICE_PAD2B);
  system_assign_device(PORT_B, DEVICE_PAD2B);

  MDFNMP_AddRAM(8192, 0xC000, sms.wram);

  sms_init();
  pio_init();
  vdp_init(IS_SMS && sms.territory == TERRITORY_DOMESTIC);
  render_init();

  MDFNGameInfo->GameSetMD5Valid = false;

  uint32 sndclk;

  if(sms.display == DISPLAY_PAL)
  {
   sndclk = 3546893;
   MDFNGameInfo->fps = (uint32)((uint64)65536 * 256 * sndclk / 313 / 228); //6144000 * 65536 * 256 / 515 / 198); // 3072000 * 2 * 10000 / 515 / 198
  }
  else
  {
   sndclk = 3579545;
   MDFNGameInfo->fps = (uint32)((uint64)65536 * 256 * sndclk / 262 / 228); //6144000 * 65536 * 256 / 515 / 198); // 3072000 * 2 * 10000 / 515 / 198
  }

  if(sms.console != CONSOLE_GG)
  {
   sls = MDFN_GetSettingUI((sms.display == DISPLAY_PAL) ? "sms.slstartp" : "sms.slstart");
   sle = MDFN_GetSettingUI((sms.display == DISPLAY_PAL) ? "sms.slendp" : "sms.slend");

   if(sle < sls)
    std::swap(sls, sle);

   MDFNGameInfo->lcm_height = sle + 1 - sls;
   MDFNGameInfo->nominal_height = sle + 1 - sls;
  }

  MDFNGameInfo->MasterClock = MDFN_MASTERCLOCK_FIXED(sndclk);

  SMS_SoundInit(sndclk, sms.use_fm);

  sms.save = 0;

  system_reset();
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

static bool TestMagicSMS(MDFNFILE *fp)
{
 if(fp->ext != "sms" && fp->ext != "sg" && fp->ext != "sc")
  return false;

 return true;
}

static bool TestMagicGG(MDFNFILE *fp)
{
 if(fp->ext != "gg")
  return false;

 return true;
}


static void LoadSMS(MDFNFILE *fp)
{
 sms.console = CONSOLE_SMS;

 LoadCommon(fp);
}

static void LoadGG(MDFNFILE *fp)
{
 sms.console = CONSOLE_GG;

 LoadCommon(fp);
}

}

static const IDIISG GGGamepadIDII =
{
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
 IDIIS_Button("left", "LEFT ←", 2, "right"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_ButtonCR("button1", "Button 1", 4, NULL),
 IDIIS_ButtonCR("button2", "Button 2", 5,  NULL),
 IDIIS_Button("Start", "Start", 6, NULL),
};

static const IDIISG SMSGamepadIDII =
{
 IDIIS_Button("up", "UP ↑", 0, "down"),
 IDIIS_Button("down", "DOWN ↓", 1, "up"),
 IDIIS_Button("left", "LEFT ←", 2, "right"),
 IDIIS_Button("right", "RIGHT →", 3, "left"),
 IDIIS_ButtonCR("fire1", "Fire 1/Start", 4, NULL),
 IDIIS_ButtonCR("fire2", "Fire 2", 5,  NULL),
 IDIIS_Button("pause", "Pause", 6, NULL),
};

static const std::vector<InputDeviceInfoStruct> GGInputDeviceInfo =
{
 {
  "gamepad",
  "Gamepad",
  NULL,
  GGGamepadIDII,
 }
};

static const std::vector<InputDeviceInfoStruct> SMSInputDeviceInfo =
{
 {
  "gamepad",
  "Gamepad",
  NULL,
  SMSGamepadIDII,
 }
};

static const std::vector<InputPortInfoStruct> GGPortInfo =
{
 { "builtin", "Built-In", GGInputDeviceInfo, "gamepad" },
};

static const std::vector<InputPortInfoStruct> SMSPortInfo =
{
 { "port1", "Port 1", SMSInputDeviceInfo, "gamepad" },
 { "port2", "Port 2", SMSInputDeviceInfo, "gamepad" }
};

static void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_POWER: system_reset(); break;
  case MDFN_MSC_RESET: if(IS_SMS)
			{
			 input.system |= INPUT_RESET;
			 SoftResetCount = 20;
			}
			else
			 system_reset();
			break;
 }
}

static const MDFNSetting_EnumList Territory_List[] =
{
 { "domestic", TERRITORY_DOMESTIC, gettext_noop("Domestic(Japanese)") },
 { "export", TERRITORY_EXPORT, gettext_noop("Export(World)") },
 { NULL, 0 },
};

static const MDFNSetting SMSSettings[] =
{
 { "sms.territory", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("System territory/region."), NULL, MDFNST_ENUM, "export", NULL, NULL, NULL, NULL, Territory_List },
 { "sms.fm", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable FM sound emulation when playing domestic/Japan-region games."), NULL, MDFNST_BOOL, "1" },

 { "sms.slstart", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in NTSC mode."), NULL, MDFNST_UINT, "0", "0", "239" },
 { "sms.slend", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in NTSC mode."), NULL, MDFNST_UINT, "239", "0", "239" },

 { "sms.slstartp", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in PAL mode."), NULL, MDFNST_UINT, "0", "0", "239" },
 { "sms.slendp", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in PAL mode."), NULL, MDFNST_UINT, "239", "0", "239" },

 { NULL }
};

static const MDFNSetting GGSettings[] =
{
 { NULL }
};


static const FileExtensionSpecStruct SMSKnownExtensions[] =
{
 { ".sms", gettext_noop("Sega Master System ROM Image") },
 { NULL, NULL }
};

static const FileExtensionSpecStruct GGKnownExtensions[] =
{
 { ".gg", gettext_noop("Game Gear ROM Image") },
 { NULL, NULL }
};

static const CustomPalette_Spec SMSCPInfo[] =
{
 { gettext_noop("SMS 6-bit BGR"), NULL, { 64, 0 } },

 { NULL, NULL }
};

static const CustomPalette_Spec GGCPInfo[] =
{
 { gettext_noop("GG 12-bit BGR"), NULL, { 4096, 0 } },

 { NULL, NULL }
};


MDFNGI EmulatedSMS =
{
 "sms",
 "Sega Master System",
 SMSKnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 NULL,
 SMSPortInfo,
 LoadSMS,
 TestMagicSMS,
 NULL,
 NULL,
 CloseGame,

 NULL, //ToggleLayer,
 NULL, //"Hi\0Ho\0Mo\0", //"Background Scroll\0Foreground Scroll\0Sprites\0",

 NULL,
 NULL,

 SMSCPInfo,
 1 << 0,

 CheatInfo_Empty,

 false,
 StateAction,
 Emulate,
 NULL,
 SetInput,
 NULL,
 DoSimpleCommand,
 NULL,
 SMSSettings,
 0,
 0,
 false, // Multires possible?

 256,   // lcm_width
 240,   // lcm_height
 NULL,  // Dummy

 256,	// Nominal width
 240,	// Nominal height

 256,	// Framebuffer width
 256,	// Framebuffer height

 2,     // Number of output sound channels
};

MDFNGI EmulatedGG =
{
 "gg",
 "Sega Game Gear",
 GGKnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 NULL,
 GGPortInfo,
 LoadGG,
 TestMagicGG,
 NULL,
 NULL,
 CloseGame,

 NULL, //ToggleLayer,
 NULL, //"Hi\0Ho\0Mo\0", //"Background Scroll\0Foreground Scroll\0Sprites\0",

 NULL,
 NULL,

 GGCPInfo,
 1 << 0,

 CheatInfo_Empty,

 false,
 StateAction,
 Emulate,
 NULL,
 SetInput,
 NULL,
 DoSimpleCommand,
 NULL,
 GGSettings,
 0,
 0,
 false, // Multires possible?

 160,   // lcm_width
 144,   // lcm_height           
 NULL,  // Dummy


 160,	// nominal width
 144,	// nominal height

 256,	// Framebuffer width
 256,	// Framebuffer height 

 2,     // Number of output sound channels
};

