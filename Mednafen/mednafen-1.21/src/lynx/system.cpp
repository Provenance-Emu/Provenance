//
// Copyright (c) 2004 K. Wilkins
//
// This software is provided 'as-is', without any express or implied warranty.
// In no event will the authors be held liable for any damages arising from
// the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
//
// 2. Altered source versions must be plainly marked as such, and must not
//    be misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source distribution.
//

//////////////////////////////////////////////////////////////////////////////
//                       Handy - An Atari Lynx Emulator                     //
//                          Copyright (c) 1996,1997                         //
//                                 K. Wilkins                               //
//////////////////////////////////////////////////////////////////////////////
// System object class                                                      //
//////////////////////////////////////////////////////////////////////////////
//                                                                          //
// This class provides the glue to bind of of the emulation objects         //
// together via peek/poke handlers and pass thru interfaces to lower        //
// objects, all control of the emulator is done via this class. Update()    //
// does most of the work and each call emulates one CPU instruction and     //
// updates all of the relevant hardware if required. It must be remembered  //
// that if that instruction involves setting SPRGO then, it will cause a    //
// sprite painting operation and then a corresponding update of all of the  //
// hardware which will usually involve recursive calls to Update, see       //
// Mikey SPRGO code for more details.                                       //
//                                                                          //
//    K. Wilkins                                                            //
// August 1997                                                              //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////
// Revision History:                                                        //
// -----------------                                                        //
//                                                                          //
// 01Aug1997 KW Document header added & class documented.                   //
//                                                                          //
//////////////////////////////////////////////////////////////////////////////

#define SYSTEM_CPP

//#include <crtdbg.h>
//#define	TRACE_SYSTEM

#include "system.h"

#include <mednafen/general.h>
#include <mednafen/mempatcher.h>
#include <mednafen/hash/md5.h>

CSystem::CSystem(MDFNFILE* fp)
{
	mFileType = HANDY_FILETYPE_LNX;

	char clip[11];
	fp->read(clip, 11);
	fp->seek(0, SEEK_SET);
	clip[4]=0;
	clip[10]=0;

	if(!strcmp(&clip[6],"BS93"))
	 mFileType = HANDY_FILETYPE_HOMEBREW;
	else if(!strcmp(&clip[0],"LYNX"))
	 mFileType = HANDY_FILETYPE_LNX;
	else
	{
		throw MDFN_Error(0, _("File format is unknown to module \"%s\"."), MDFNGameInfo->shortname);
	}

	MDFNMP_Init(65536, 1);

	// Create the system objects that we'll use

	// Attempt to load the cartridge errors caught above here...

	mRom.reset(new CRom(MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, "lynxboot.img").c_str()));

	// An exception from this will be caught by the level above

	switch(mFileType)
	{
		default: abort();
			break;

		case HANDY_FILETYPE_LNX:
			mCart.reset(new CCart(fp->stream()));
			mRam.reset(new CRam(NULL));
			break;

		case HANDY_FILETYPE_HOMEBREW:
			{
			 mCart.reset(new CCart(NULL));
			 mRam.reset(new CRam(fp->stream()));
			}
			break;
	}

	// These can generate exceptions

	mMikie.reset(new CMikie(*this));
	mSusie.reset(new CSusie(*this));

// Instantiate the memory map handler

	mMemMap.reset(new CMemMap(*this));

// Now the handlers are set we can instantiate the CPU as is will use handlers on reset

	mCpu.reset(new C65C02(*this));

// Now init is complete do a reset, this will cause many things to be reset twice
// but what the hell, who cares, I don't.....

	Reset();
}

CSystem::~CSystem()
{

}

void CSystem::Reset(void)
{
	mMikie->startTS -= gSystemCycleCount;
	gSystemCycleCount=0;
	gNextTimerEvent=0;
	gCPUBootAddress=0;
	gSystemIRQ=false;
	gSystemNMI=false;
	gSystemCPUSleep=false;
	gSystemHalt=false;
	gSuzieDoneTime = 0;

	mMemMap->Reset();
	mCart->Reset();
	mRom->Reset();
	mRam->Reset();
	mMikie->Reset();
	mSusie->Reset();
	mCpu->Reset();

	// Homebrew hashup

	if(mFileType==HANDY_FILETYPE_HOMEBREW)
	{
		mMikie->PresetForHomebrew();

		C6502_REGS regs;
		mCpu->GetRegs(regs);
		regs.PC=(uint16)gCPUBootAddress;
		mCpu->SetRegs(regs);
	}
}

// Somewhat of a hack to make sure undrawn lines are black.
bool LynxLineDrawn[256];

static CSystem *lynxie = NULL;
extern MDFNGI EmulatedLynx;

static bool TestMagic(MDFNFILE *fp)
{
 uint8 data[((size_t)CCart::HEADER_RAW_SIZE > (size_t)CRam::HEADER_RAW_SIZE) ? (size_t)CCart::HEADER_RAW_SIZE : (size_t)CRam::HEADER_RAW_SIZE];
 uint64 rc;

 rc = fp->read(data, sizeof(data), false);

 if(rc >= CCart::HEADER_RAW_SIZE && CCart::TestMagic(data, sizeof(data)))
  return true;

 if(rc >= CRam::HEADER_RAW_SIZE && CRam::TestMagic(data, sizeof(data)))
  return true;

 return false;
}

static void Cleanup(void)
{
 if(lynxie)
 {
  delete lynxie;
  lynxie = NULL;
 }
}

static void Load(MDFNFILE *fp)
{
 try
 {
  lynxie = new CSystem(fp);

  switch(lynxie->CartGetRotate())
  {
   case CART_ROTATE_LEFT:
	MDFNGameInfo->rotated = MDFN_ROTATE270;
	break;

   case CART_ROTATE_RIGHT:
	MDFNGameInfo->rotated = MDFN_ROTATE90;
	break;
  }

  MDFNGameInfo->GameSetMD5Valid = false;
  if(lynxie->mRam->InfoRAMSize)
  {
   memcpy(MDFNGameInfo->MD5, lynxie->mRam->MD5, 16);
   MDFN_printf(_("RAM:       %u bytes\n"), lynxie->mRam->InfoRAMSize);
   MDFN_printf(_("RAM MD5:   0x%s\n"), md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str());
  }
  else
  {
   memcpy(MDFNGameInfo->MD5, lynxie->mCart->MD5, 16);
   MDFN_printf(_("ROM:       %dKiB\n"), (lynxie->mCart->InfoROMSize + 1023) / 1024);
   MDFN_printf(_("ROM MD5:   0x%s\n"), md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str());
  }

  MDFNGameInfo->fps = (uint32)(59.8 * 65536 * 256);

  if(MDFN_GetSettingB("lynx.lowpass"))
  {
   lynxie->mMikie->miksynth.treble_eq(-35);
  }
  else
  {
   lynxie->mMikie->miksynth.treble_eq(0);
  }
 }
 catch(std::exception &e)
 {
  Cleanup();

  throw;
 }
}

static void CloseGame(void)
{
 Cleanup();
}

static uint8 *chee;
static void Emulate(EmulateSpecStruct *espec)
{
 espec->DisplayRect.x = 0;
 espec->DisplayRect.y = 0;
 espec->DisplayRect.w = 160;
 espec->DisplayRect.h = 102;

 if(espec->VideoFormatChanged)
  lynxie->DisplaySetAttributes(espec->surface->format, espec->CustomPalette);

 if(espec->SoundFormatChanged)
 {
  lynxie->mMikie->mikbuf.set_sample_rate(espec->SoundRate ? espec->SoundRate : 44100, 60);
  lynxie->mMikie->mikbuf.clock_rate((long int)(16000000 / 4));
  lynxie->mMikie->mikbuf.bass_freq(60);
  lynxie->mMikie->miksynth.volume(0.50);
 }

 uint16 butt_data = chee[0] | (chee[1] << 8);

 lynxie->SetButtonData(butt_data);

 MDFNMP_ApplyPeriodicCheats();

 memset(LynxLineDrawn, 0, sizeof(LynxLineDrawn[0]) * 102);

 lynxie->mMikie->mpSkipFrame = espec->skip;
 lynxie->mMikie->mpDisplayCurrent = espec->surface;
 lynxie->mMikie->mpDisplayCurrentLine = 0;
 lynxie->mMikie->startTS = gSystemCycleCount;

 while(lynxie->mMikie->mpDisplayCurrent && (gSystemCycleCount - lynxie->mMikie->startTS) < 700000)
 {
  lynxie->Update();
//  printf("%d ", gSystemCycleCount - lynxie->mMikie->startTS);
 }

 {
  // FIXME, we should integrate this into mikie.*
  uint32 color_black = espec->CustomPalette ? espec->surface->MakeColor(espec->CustomPalette[0], espec->CustomPalette[1], espec->CustomPalette[2]) : espec->surface->MakeColor(30, 30, 30);

  for(int y = 0; y < 102; y++)
  {
   if(espec->surface->format.bpp == 16)
   {
    uint16 *row = espec->surface->pixels16 + y * espec->surface->pitchinpix;

    if(!LynxLineDrawn[y])
    {
     for(int x = 0; x < 160; x++)
      row[x] = color_black;
    }
   }
   else
   {
    uint32 *row = espec->surface->pixels + y * espec->surface->pitchinpix;

    if(!LynxLineDrawn[y])
    {
     for(int x = 0; x < 160; x++)
      row[x] = color_black;
    }
   }
  }
 }

 espec->MasterCycles = gSystemCycleCount - lynxie->mMikie->startTS;

 if(espec->SoundBuf)
 {
  lynxie->mMikie->mikbuf.end_frame((gSystemCycleCount - lynxie->mMikie->startTS) >> 2);
  espec->SoundBufSize = lynxie->mMikie->mikbuf.read_samples(espec->SoundBuf, espec->SoundBufMaxSize) / 2; // divide by nr audio chn
 }
 else
  espec->SoundBufSize = 0;
}

static void SetInput(unsigned port, const char *type, uint8 *ptr)
{
 chee = (uint8 *)ptr;
}

static void TransformInput(void)
{
 if(MDFN_GetSettingB("lynx.rotateinput"))
 {
  static const unsigned bp[4] = { 4, 6, 5, 7 };
  const unsigned offs = MDFNGameInfo->rotated;
  uint16 butt_data = MDFN_de16lsb(chee);

  butt_data = (butt_data & 0xFF0F) |
	      (((butt_data >> bp[0]) & 1) << bp[(0 + offs) & 3]) |
	      (((butt_data >> bp[1]) & 1) << bp[(1 + offs) & 3]) |
	      (((butt_data >> bp[2]) & 1) << bp[(2 + offs) & 3]) |
	      (((butt_data >> bp[3]) & 1) << bp[(3 + offs) & 3]);
  //printf("%d, %04x\n", MDFNGameInfo->rotated, butt_data);
  MDFN_en16lsb(chee, butt_data);
 }
}

static void StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT SystemRegs[] =
 {
	SFVAR(gSuzieDoneTime),
        SFVAR(gSystemCycleCount),
        SFVAR(gNextTimerEvent),
        SFVAR(gCPUBootAddress),
        SFVAR(gSystemIRQ),
        SFVAR(gSystemNMI),
        SFVAR(gSystemCPUSleep),
        SFVAR(gSystemHalt),
	SFPTR8N(lynxie->GetRamPointer(), RAM_SIZE, "RAM"),
	SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, SystemRegs, "SYST");
 lynxie->mSusie->StateAction(sm, load, data_only);
 lynxie->mMemMap->StateAction(sm, load, data_only);
 lynxie->mCart->StateAction(sm, load, data_only);
 lynxie->mMikie->StateAction(sm, load, data_only);
 lynxie->mCpu->StateAction(sm, load, data_only);
}

static void SetLayerEnableMask(uint64 mask)
{


}

static void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_POWER:
  case MDFN_MSC_RESET: lynxie->Reset(); break;
 }
}

static const MDFNSetting LynxSettings[] =
{
 { "lynx.rotateinput", MDFNSF_NOFLAGS,	gettext_noop("Virtually rotate the D-pad when the screen is rotated."), NULL, MDFNST_BOOL, "1" },
 { "lynx.lowpass", MDFNSF_CAT_SOUND,	gettext_noop("Enable sound output lowpass filter."), NULL, MDFNST_BOOL, "1" },
 { NULL }
};

static const IDIISG IDII =
{
 IDIIS_ButtonCR("a", "A (outer)", 8),
 IDIIS_ButtonCR("b", "B (inner)", 7),
 IDIIS_ButtonCR("option_2", "Option 2 (lower)", 5),
 IDIIS_ButtonCR("option_1", "Option 1 (upper)", 4),

 IDIIS_Button("left", "LEFT ←", 	2, "right"),
 IDIIS_Button("right", "RIGHT →", 	3, "left"),
 IDIIS_Button("up", "UP ↑", 	0, "down"),
 IDIIS_Button("down", "DOWN ↓", 	1, "up"),

 IDIIS_Button("pause", "PAUSE", 6),
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfo =
{
 {
  "gamepad",
  "Gamepad",
  NULL,
  IDII,
 }
};

static const std::vector<InputPortInfoStruct> PortInfo =
{
 { "builtin", "Built-In", InputDeviceInfo }
};

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".lnx", gettext_noop("Atari Lynx ROM Image") },
 { NULL, NULL }
};

static const CustomPalette_Spec CPInfo[] =
{
 { gettext_noop("Atari Lynx 12-bit BRG"), NULL, { 4096, 0 } },

 { NULL, NULL },
};

MDFNGI EmulatedLynx =
{
 "lynx",
 "Atari Lynx",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 NULL,
 PortInfo,
 Load,
 TestMagic,
 NULL,
 NULL,
 CloseGame,

 SetLayerEnableMask,
 NULL,

 NULL,
 NULL,

 CPInfo,
 1 << 0,

 CheatInfo_Empty,

 false,
 StateAction,
 Emulate,
 TransformInput,
 SetInput,
 NULL,
 DoSimpleCommand,
 NULL,
 LynxSettings,
 MDFN_MASTERCLOCK_FIXED(16000000),
 0,

 false, // Multires possible?

 160,   // lcm_width
 102,   // lcm_height
 NULL,  // Dummy


 160,	// Nominal width
 102,	// Nominal height

 160,	// Framebuffer width
 102,	// Framebuffer height

 2,     // Number of output sound channels
};

