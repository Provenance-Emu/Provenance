/* Mednafen - Multi-system Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2003 Xodnizel
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

#include	"nes.h"
#include        <stdarg.h>

#include	"x6502.h"
#include	"ppu/ppu.h"
#include	"ppu/palette.h"
#include	"sound.h"

#include	"cart.h"
#include	"nsf.h"
#include	"fds.h"
#include	"ines.h"
#include	"unif.h"
#include        <mednafen/mempatcher.h>
#include	"input.h"
#include	"vsuni.h"
#include	"debug.h"

#include	<trio/trio.h>

extern MDFNGI EmulatedNES;

namespace MDFN_IEN_NES
{
uint64 timestampbase;

// Accessed in debug.cpp
NESGameType *GameInterface = NULL;

static readfunc NonCheatARead[0x10000 + 0x100];
readfunc ARead[0x10000 + 0x100];
writefunc BWrite[0x10000 + 0x100];

bool NESIsVSUni;

//static
DECLFW(BNull)
{
 //printf("Null Write: %04x %02x\n", A, V);
}

//static 
DECLFR(ANull)
{
 //printf("Null Read: %04x\n", A);
 return(X.DB);
}

readfunc GetReadHandler(int32 a)
{
	return ARead[a];
}

void SetReadHandler(int32 start, int32 end, readfunc func, bool snc)
{
  int32 x;

  //printf("%08x %08x %lld %d\n", start, end, func, snc);

  if(!func)
   func=ANull;

  for(x=end;x>=start;x--)
  {
   ARead[x]=func;
   if(snc)
    NonCheatARead[x] = func;
  }
}

writefunc GetWriteHandler(int32 a)
{
	return BWrite[a];
}

void SetWriteHandler(int32 start, int32 end, writefunc func)
{
  int32 x;

  if(!func)
   func=BNull;

  for(x=end;x>=start;x--)
   BWrite[x]=func;
}

uint8 RAM[0x800];
uint8 PAL=0;

static DECLFW(BRAML)
{  
        RAM[A]=V;
}

static DECLFW(BRAMH)
{
        RAM[A&0x7FF]=V;
}

static DECLFR(ARAML)
{
        return RAM[A];
}

static DECLFR(ARAMH)
{
        return RAM[A&0x7FF];
}

// We need to look up the correct function in the ARead[] and BWrite[] tables
// for these overflow functions, because the RAM access handlers might be hooked
// for cheats or other things.

static DECLFR(AOverflow)
{
	A &= 0xFFFF;
	X.PC &= 0xFFFF;
	return(ARead[A](A));
}

static DECLFW(BOverflow)
{
	A &= 0xFFFF;
	return(BWrite[A](A, V));
}

static void Cleanup(void)
{
 for(std::vector<EXPSOUND>::iterator ep = GameExpSound.begin(); ep != GameExpSound.end(); ep++)
 {
  if(ep->Kill)
   ep->Kill();
 }

 GameExpSound.clear();

 if(GameInterface)
 {
  if(GameInterface->Kill)
   GameInterface->Kill();
  free(GameInterface);
  GameInterface = NULL;
 }

 Genie_Kill();
 MDFNSND_Close();
 MDFNPPU_Close();
}

static void CloseGame(void)
{
 if(GameInterface && GameInterface->SaveNV)
  GameInterface->SaveNV();

 Cleanup();
}

static void InitCommon(const char *fbase)
{
        NESIsVSUni = FALSE;
        PPU_hook = 0;
        GameHBIRQHook = 0;

        MapIRQHook = 0;
        MMC5Hack = 0;
        PAL &= 1;

        MDFNGameInfo->VideoSystem = VIDSYS_NONE;

        MDFNGameInfo->cspecial = NULL;
        MDFNGameInfo->GameSetMD5Valid = FALSE;


        if(MDFN_GetSettingB("nes.fnscan"))
        {
         if(strstr(fbase, "(U)") || strstr(fbase, "(USA)"))
          MDFNGameInfo->VideoSystem = VIDSYS_NTSC;
         else if(strstr(fbase, "(J)") || strstr(fbase, "(Japan)"))
          MDFNGameInfo->VideoSystem = VIDSYS_NTSC;
         else if(strstr(fbase, "(E)") || strstr(fbase, "(G)") || strstr(fbase, "(Europe)") || strstr(fbase, "(Germany)") )
          MDFNGameInfo->VideoSystem = VIDSYS_PAL;
        }

        GameInterface = (NESGameType *)calloc(1, sizeof(NESGameType));

        SetReadHandler(0x0000, 0xFFFF, ANull);
        SetWriteHandler(0x0000, 0xFFFF, BNull);

        SetReadHandler(0x10000,0x10000 + 0xFF, AOverflow);
        SetWriteHandler(0x10000,0x10000 + 0xFF, BOverflow);

        SetReadHandler(0,0x7FF,ARAML);
        SetWriteHandler(0,0x7FF,BRAML);

        SetReadHandler(0x800,0x1FFF,ARAMH);  /* Part of a little */
        SetWriteHandler(0x800,0x1FFF,BRAMH); /* hack for a small speed boost. */

        MDFNMP_Init(1024, 65536 / 1024);


	#ifdef WANT_DEBUGGER
	NESDBG_Init();

	ASpace_Add(NESDBG_GetAddressSpaceBytes, NESDBG_PutAddressSpaceBytes, "cpu", "CPU", 16);
	ASpace_Add(NESPPU_GetAddressSpaceBytes, NESPPU_PutAddressSpaceBytes, "ppu", "PPU", 14);
	ASpace_Add(NESPPU_GetAddressSpaceBytes, NESPPU_PutAddressSpaceBytes, "spram", "Sprite RAM", 8);
        #endif
}

void UNIFLoad(Stream *fp, NESGameType *);
void iNESLoad(Stream *fp, NESGameType *);
void FDSLoad(Stream *fp, NESGameType *);

bool iNES_TestMagic(MDFNFILE *fp);
bool UNIF_TestMagic(MDFNFILE *fp);
bool FDS_TestMagic(MDFNFILE *fp);

typedef void (*LoadFunction_t)(Stream *fp, NESGameType *);

static LoadFunction_t GetLoadFunctionByMagic(MDFNFILE *fp)
{
 bool (*MagicFunctions[4])(MDFNFILE *fp) = { iNES_TestMagic, UNIF_TestMagic, NSF_TestMagic, FDS_TestMagic };
 LoadFunction_t LoadFunctions[4] = { iNESLoad, UNIFLoad, NSFLoad, FDSLoad };
 LoadFunction_t ret = NULL;

 for(int x = 0; x < 4; x++)
 {
  fp->rewind();
  if(MagicFunctions[x](fp))
  {
   fp->rewind();
   ret = LoadFunctions[x];
   break;
  }
 }
 return(ret);
}

static bool TestMagic(MDFNFILE *fp)
{
 return(GetLoadFunctionByMagic(fp) != NULL);
}

static void Load(MDFNFILE *fp)
{
 try
 {
	LoadFunction_t LoadFunction = NULL;

	LoadFunction = GetLoadFunctionByMagic(fp);

	// If the file type isn't recognized, return -1!
	if(!LoadFunction)
	 throw MDFN_Error(0, _("File format is unknown to module \"%s\"."), MDFNGameInfo->shortname);

	InitCommon(fp->fbase);

	LoadFunction(fp->stream(), GameInterface);

	{
	 int w;

	 if(MDFNGameInfo->VideoSystem == VIDSYS_NTSC)
	  w = 0;
	 else if(MDFNGameInfo->VideoSystem == VIDSYS_PAL)
	  w = 1;
	 else
	 {
	  w = MDFN_GetSettingB("nes.pal");
	  MDFNGameInfo->VideoSystem = w ? VIDSYS_PAL : VIDSYS_NTSC;
	 }
	 PAL=w?1:0;
	 MDFNGameInfo->fps = PAL? 838977920 : 1008307711;
	 MDFNGameInfo->MasterClock = MDFN_MASTERCLOCK_FIXED(PAL ? PAL_CPU : NTSC_CPU);
	}

	X6502_Init();
	MDFNPPU_Init();
        MDFNSND_Init(PAL);
	NESINPUT_Init();

	if(NESIsVSUni)
	 MDFN_VSUniInstallRWHooks();

	if(MDFNGameInfo->GameType != GMT_PLAYER)
         if(MDFN_GetSettingB("nes.gg"))
	  Genie_Init();

        PowerNES();

        MDFN_InitPalette(NESIsVSUni ? MDFN_VSUniGetPaletteNum() : (bool)PAL, NULL, 0);

	if(MDFNGameInfo->GameType != GMT_PLAYER)
	 MDFNGameInfo->CPInfoActiveBF = 1 << (NESIsVSUni ? MDFN_VSUniGetPaletteNum() : (bool)PAL);
	else
	 MDFNGameInfo->CPInfoActiveBF = 0;

 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

static void Emulate(EmulateSpecStruct *espec)
{
 int ssize;

#if 0
 static bool firstcat = true;

 MDFN_PixelFormat tmp_pf;

 tmp_pf.Rshift = 0;
 tmp_pf.Gshift = 0;
 tmp_pf.Bshift = 0;
 tmp_pf.Ashift = 8;

 tmp_pf.Rprec = 6;
 tmp_pf.Gprec = 6;
 tmp_pf.Bprec = 6;
 tmp_pf.Aprec = 0;

 tmp_pf.bpp = 8;
 tmp_pf.colorspace = MDFN_COLORSPACE_RGB;

 espec->surface->SetFormat(tmp_pf, false);
 espec->VideoFormatChanged = firstcat;
 firstcat = false;
#endif


 if(espec->VideoFormatChanged)
 {
  MDFN_InitPalette(NESIsVSUni ? MDFN_VSUniGetPaletteNum() : (bool)PAL, espec->CustomPalette, espec->CustomPaletteNumEntries);
  MDFNNES_SetPixelFormat(espec->surface->format);
 }

 if(espec->SoundFormatChanged)
  MDFNNES_SetSoundRate(espec->SoundRate);

 NESPPU_GetDisplayRect(&espec->DisplayRect);

 MDFN_UpdateInput();

 if(!Genie_BIOSInstalled())
  MDFNMP_ApplyPeriodicCheats();

 MDFNPPU_Loop(espec);

 ssize = FlushEmulateSound(espec->NeedSoundReverse, espec->SoundBuf, espec->SoundBufMaxSize);
 espec->NeedSoundReverse = 0;

 timestampbase += timestamp;
 espec->MasterCycles = timestamp;

 timestamp = 0;

 if(MDFNGameInfo->GameType == GMT_PLAYER)
  MDFNNES_DrawNSF(espec->surface, &espec->DisplayRect, espec->SoundBuf, ssize);

 espec->SoundBufSize = ssize;


 if(MDFNGameInfo->GameType != GMT_PLAYER)
 {
  if(NESIsVSUni)
   MDFN_VSUniDraw(espec->surface);
 }
}

void ResetNES(void)
{
	if(GameInterface->Reset)
         GameInterface->Reset();
        MDFNSND_Reset();
        MDFNPPU_Reset();
        X6502_Reset();
}

void PowerNES(void) 
{
        if(!MDFNGameInfo)
	 return;

	if(!Genie_BIOSInstalled())
 	 MDFNMP_RemoveReadPatches();

	MDFNMP_AddRAM(0x0800, 0x0000, RAM);

	// Genie_Power() will remove any cheat read patches, and then install the BIOS(and its read hooks)
        Genie_Power();

	// http://wiki.nesdev.com/w/index.php/CPU_power_up_state
	memset(RAM, 0xFF, 0x800);
	RAM[0x008] = 0xF7;
	RAM[0x009] = 0xEF;
	RAM[0x00A] = 0xDF;
	RAM[0x00F] = 0xBF;

        NESINPUT_Power();
        MDFNSND_Power();
        MDFNPPU_Power();

	/* Have the external game hardware "powered" after the internal NES stuff.  
	   Needed for the NSF code and VS System code.
	*/
	if(GameInterface->Power)
	 GameInterface->Power();

	if(NESIsVSUni)
         MDFN_VSUniPower();

	timestampbase = 0;
	X6502_Power();

        if(!Genie_BIOSInstalled())
         MDFNMP_InstallReadPatches();
}

static void StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 Genie_StateAction(sm, load, data_only);

 X6502_StateAction(sm, load, data_only);
 MDFNPPU_StateAction(sm, load, data_only);
 MDFNSND_StateAction(sm, load, data_only);
 NESINPUT_StateAction(sm, load, data_only);

 if(GameInterface->StateAction)
 {
  GameInterface->StateAction(sm, load, data_only);
 }
}

// TODO: Actual enum vals
static const MDFNSetting_EnumList NTSCPresetList[] =
{
 { "disabled",	-1, gettext_noop("Disabled") },
 { "none",	-1 }, // Old setting value

 { "composite", -1, gettext_noop("Composite Video") },
 { "svideo", 	-1, gettext_noop("S-Video") },
 { "rgb", 	-1, gettext_noop("RGB") },
 { "monochrome", -1, gettext_noop("Monochrome") },

 { NULL, 0 },
};

static MDFNSetting NESSettings[] =
{
  { "nes.nofs", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Disable four-score emulation."), NULL, MDFNST_BOOL, "0" },

  { "nes.no8lim", MDFNSF_NOFLAGS, gettext_noop("Remove 8-sprites-per-scanline hardware limit."), 
	gettext_noop("WARNING: Enabling this option will cause graphical glitches in some games, including \"Solstice\"."), MDFNST_BOOL, "0", NULL, NULL, NULL, NESPPU_SettingChanged },

  { "nes.soundq", MDFNSF_NOFLAGS, gettext_noop("Sound quality."), gettext_noop("Higher values correspond to better SNR and better preservation of higher frequencies(\"brightness\"), at the cost of increased computational complexity and a negligible(<0.5ms) increase in latency."), MDFNST_INT, "0", "-2", "3" },
  { "nes.sound_rate_error", MDFNSF_NOFLAGS, gettext_noop("Output rate tolerance."), gettext_noop("Lower values correspond to better matching of the output rate of the resampler to the actual desired output rate, at the expense of increased RAM usage and poorer CPU cache utilization.  DO NOT INCREASE THIS VALUE, OR SOUND WILL LIKELY BE OFF-KEY AND THE WRONG TEMPO, AMONG OTHER PROBLEMS."), MDFNST_FLOAT, "0.00004", "0.0000001", "0.01" },
  { "nes.n106bs", MDFNSF_NOFLAGS, gettext_noop("Enable less-accurate, but better sounding, Namco 106(mapper 19) sound emulation."), NULL, MDFNST_BOOL, "0" },
  { "nes.fnscan", MDFNSF_EMU_STATE, gettext_noop("Scan filename for (U),(J),(E),etc. strings to en/dis-able PAL emulation."), 
	gettext_noop("Warning: This option may break NES network play when enabled IF the players are using ROM images with different filenames."), MDFNST_BOOL, "1" },

  { "nes.pal", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable PAL(50Hz) NES emulation."), NULL, MDFNST_BOOL, "0" },
  { "nes.gg", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable Game Genie emulation."), NULL, MDFNST_BOOL, "0" },
  { "nes.ggrom", MDFNSF_EMU_STATE, gettext_noop("Path to Game Genie ROM image."), NULL, MDFNST_STRING, "gg.rom" },
  { "nes.clipsides", MDFNSF_NOFLAGS, gettext_noop("Clip left+right 8 pixel columns."), NULL, MDFNST_BOOL, "0" },
  { "nes.slstart", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in NTSC mode."), NULL, MDFNST_UINT, "8", "0", "239" },
  { "nes.slend", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in NTSC mode."), NULL, MDFNST_UINT, "231", "0", "239" },
  { "nes.slstartp", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in PAL mode."), NULL, MDFNST_UINT, "0", "0", "239" },
  { "nes.slendp", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in PAL mode."), NULL, MDFNST_UINT, "239", "0", "239" },

  { "nes.correct_aspect", MDFNSF_CAT_VIDEO, gettext_noop("Correct the aspect ratio."), NULL, MDFNST_BOOL, "0" },
  { "nes.ntscblitter", MDFNSF_NOFLAGS, gettext_noop("Enable NTSC color generation and blitter."), 
	gettext_noop("NOTE: If your refresh rate isn't very close to 60.1Hz(+-0.1), you will need to set the nes.ntsc.mergefields setting to \"1\" to avoid excessive flickering."), MDFNST_BOOL, "0" },


  { "nes.ntsc.preset", MDFNSF_NOFLAGS, gettext_noop("Video quality/type preset."), NULL, MDFNST_ENUM, "none", NULL, NULL, NULL, NULL, NTSCPresetList },
  { "nes.ntsc.mergefields", MDFNSF_NOFLAGS, gettext_noop("Merge fields to partially work around !=60.1Hz refresh rates."), NULL, MDFNST_BOOL, "0" },
  { "nes.ntsc.saturation", MDFNSF_NOFLAGS, gettext_noop("NTSC composite blitter saturation."), NULL, MDFNST_FLOAT, "0", "-1", "1" },
  { "nes.ntsc.hue", MDFNSF_NOFLAGS, gettext_noop("NTSC composite blitter hue."), NULL, MDFNST_FLOAT, "0", "-1", "1" },
  { "nes.ntsc.sharpness", MDFNSF_NOFLAGS, gettext_noop("NTSC composite blitter sharpness."), NULL, MDFNST_FLOAT, "0", "-1", "1" },
  { "nes.ntsc.brightness", MDFNSF_NOFLAGS, gettext_noop("NTSC composite blitter brightness."), NULL, MDFNST_FLOAT, "0", "-1", "1" },
  { "nes.ntsc.contrast", MDFNSF_NOFLAGS, gettext_noop("NTSC composite blitter contrast."), NULL, MDFNST_FLOAT, "0", "-1", "1" },

  { "nes.ntsc.matrix", MDFNSF_NOFLAGS, gettext_noop("Enable NTSC custom decoder matrix."), NULL, MDFNST_BOOL, "0" },

  /* Default custom decoder matrix(not plain default matrix) is from Sony */
  { "nes.ntsc.matrix.0", MDFNSF_NOFLAGS, gettext_noop("NTSC custom decoder matrix element 0(red, value * V)."), NULL, MDFNST_FLOAT, "1.539", "-2.000", "2.000", NULL, NESPPU_SettingChanged },
  { "nes.ntsc.matrix.1", MDFNSF_NOFLAGS, gettext_noop("NTSC custom decoder matrix element 1(red, value * U)."), NULL, MDFNST_FLOAT, "-0.622", "-2.000", "2.000", NULL, NESPPU_SettingChanged },
  { "nes.ntsc.matrix.2", MDFNSF_NOFLAGS, gettext_noop("NTSC custom decoder matrix element 2(green, value * V)."), NULL, MDFNST_FLOAT, "-0.571", "-2.000", "2.000", NULL, NESPPU_SettingChanged },
  { "nes.ntsc.matrix.3", MDFNSF_NOFLAGS, gettext_noop("NTSC custom decoder matrix element 3(green, value * U)."), NULL, MDFNST_FLOAT, "-0.185", "-2.000", "2.000", NULL, NESPPU_SettingChanged },
  { "nes.ntsc.matrix.4", MDFNSF_NOFLAGS, gettext_noop("NTSC custom decoder matrix element 4(blue, value * V)."), NULL, MDFNST_FLOAT, "0.000", "-2.000", "2.000", NULL, NESPPU_SettingChanged },
  { "nes.ntsc.matrix.5", MDFNSF_NOFLAGS, gettext_noop("NTSC custom decoder matrix element 5(blue, value * U."), NULL, MDFNST_FLOAT, "2.000", "-2.000", "2.000", NULL, NESPPU_SettingChanged },
  { NULL }
};

static uint8 MemRead(uint32 addr)
{
 addr &= 0xFFFF;

 return(NonCheatARead[addr](addr));
}

static DECLFR(CheatReadFunc)
{
  std::vector<SUBCHEAT>::iterator chit;
  //printf("%08x, %d\n", A, NonCheatARead[A]);
  uint8 retval = NonCheatARead[A](A);

  for(chit = SubCheats[A & 0x7].begin(); chit != SubCheats[A & 0x7].end(); chit++)
  {
   if(A == chit->addr)
   {
    if(chit->compare == -1 || chit->compare == retval)
    {
     retval = chit->value;
     break;
    }
   }
  }
 return(retval);
}

static void InstallReadPatch(uint32 address, uint8 value, int compare)
{
 if(Genie_BIOSInstalled())
  return;

 address &= 0xFFFF;

 SetReadHandler(address, address, CheatReadFunc, 0);
}

static void RemoveReadPatches(void)
{
 if(Genie_BIOSInstalled())
  return;

 for(uint32 A = 0; A <= 0xFFFF; A++)
 {
  SetReadHandler(A, A, NonCheatARead[A], 0);
 }
}


static int GGtobin(char c)
{
 static char lets[16]={'A','P','Z','L','G','I','T','Y','E','O','X','U','K','S','V','N'};

 for(int x = 0; x < 16; x++)
  if(lets[x] == toupper(c))
   return(x);

 if(c & 0x80)
  throw MDFN_Error(0, _("Invalid character in Game Genie code."));
 else
  throw MDFN_Error(0, _("Invalid character in Game Genie code: %c"), c);
}

static bool DecodeGG(const std::string& cheat_string, MemoryPatch* patch)
{
 uint16 A;
 uint8 V,C;
 uint8 t;
 const unsigned s = cheat_string.size();
 const char *str = cheat_string.c_str();

 if(s != 6 && s != 8)
  throw(MDFN_Error(0, _("Game Genie code is of an incorrect length.")));

 A = 0x8000;
 V = 0;
 C = 0;

 t = GGtobin(*str++);
 V |= (t&0x07);
 V |= (t&0x08)<<4;

 t = GGtobin(*str++);
 V |= (t&0x07)<<4;
 A |= (t&0x08)<<4;

 t = GGtobin(*str++);
 A |= (t&0x07)<<4;
 //if(t&0x08) return(0);	/* 8-character code?! */

 t = GGtobin(*str++);
 A |= (t&0x07)<<12;
 A |= (t&0x08);

 t = GGtobin(*str++);
 A |= (t&0x07);
 A |= (t&0x08)<<8;

 if(s == 6)
 {
  t = GGtobin(*str++);
  A |= (t&0x07)<<8;
  V |= (t&0x08);

  patch->addr = A;
  patch->val = V;
  patch->compare = 0;
  patch->type = 'S';
  patch->length = 1;
 }
 else
 {
  t = GGtobin(*str++);
  A |= (t&0x07)<<8;
  C |= (t&0x08);

  t = GGtobin(*str++);
  C |= (t&0x07);
  C |= (t&0x08)<<4;
  
  t = GGtobin(*str++);
  C |= (t&0x07)<<4;
  V |= (t&0x08);

  patch->addr = A;
  patch->val = V;
  patch->compare = C;
  patch->type = 'C';
  patch->length = 1;
 }
 return(false);
}


static bool DecodePAR(const std::string& cheat_string, MemoryPatch* patch)
{
 int boo[4];

 if(cheat_string.size() != 8)
  throw MDFN_Error(0, _("Pro Action Replay code is of an incorrect length."));

 if(trio_sscanf(cheat_string.c_str(), "%02x%02x%02x%02x", boo, boo + 1, boo + 2, boo + 3) != 4)
  throw MDFN_Error(0, _("Malformed Pro Action Replay code."));

 if(boo[0])
 {
  patch->addr = (boo[3] << 8) | ((boo[2] + 0x7F) & 0xFF);
  patch->val = boo[1];
  patch->compare = 0;
  patch->type = 'S';
 }
 else
 {
  patch->addr = ((boo[1] & 0x07) << 8) | (boo[2] << 0);
  patch->val = boo[3];
  patch->compare = 0;
  patch->type = 'R';
 }

 patch->length = 1;

 return(false);
}

static bool DecodeRocky(const std::string& cheat_string, MemoryPatch* patch)
{
 if(cheat_string.size() != 8)
  throw MDFN_Error(0, _("Pro Action Rocky code is of an incorrect length."));

 uint32 ev = 0;

 for(unsigned i = 0; i < 8; i++)
 {
  int c = cheat_string[i];

  ev <<= 4;

  if(c >= '0' && c <= '9')
   ev |= c - '0';
  else if(c >= 'a' && c <= 'f')
   ev |= c - 'a' + 0xA;
  else if(c >= 'A' && c <= 'F')
   ev |= c - 'A' + 0xA;
  else
  {
   if(c & 0x80)
    throw MDFN_Error(0, _("Invalid character in Pro Action Rocky code."));
   else
    throw MDFN_Error(0, _("Invalid character in Pro Action Rocky code: %c"), c);
  }
 }

 uint32 accum = 0xfcbdd275;
 uint32 result = 0;

 for(signed int b = 30; b >= 0; b--)
 {
  const unsigned tmp = (accum ^ ev) >> 31;
  static const uint8 lut[31] =
  {
   3, 13, 14, 1, 6, 9, 5, 0, 12, 7, 2, 8, 10, 11, 4,
   19, 21, 23, 22, 20, 17, 16, 18,
   29, 31, 24, 26, 25, 30, 27, 28
  };
  result |= tmp << lut[b];

  if(tmp)
   accum ^= 0xb8309722;
  accum <<= 1;
  ev <<= 1;
 }

 patch->addr = (result & 0x7FFF) | 0x8000;
 patch->val = (result >> 24) & 0xFF;
 patch->compare = (result >> 16) & 0xFF;
 patch->length = 1;
 patch->type = 'C';

 return(false);
}


static CheatFormatStruct CheatFormats[] =
{
 { "Game Genie", gettext_noop("Genies will eat your cheeses."), DecodeGG },
 { "Pro Action Replay (Incomplete)", gettext_noop("Prooooooooooooooooocom."), DecodePAR },
 { "Pro Action Rocky", gettext_noop("No pie."), DecodeRocky },
};

static CheatFormatInfoStruct CheatFormatInfo =
{
 3,
 CheatFormats
};

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".nes", "iNES Format ROM Image" },
 { ".nez", "iNES Format ROM Image" }, // Odd naming variant
 { ".fds", "Famicom Disk System Disk Image" },
 { ".nsf", "Nintendo Sound Format" },
 { ".nsfe", "Extended Nintendo Sound Format" },
 { ".unf", "UNIF Format ROM Image" }, // Sexy 8.3 variant
 { ".unif", "UNIF Format ROM Image" },
 { NULL, NULL }
};
}

MDFNGI EmulatedNES =
{
 "nes",
 "Nintendo Entertainment System/Famicom",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 #ifdef WANT_DEBUGGER
 &NESDBGInfo,
 #else
 NULL,
 #endif
 NESPortInfo,
 Load,
 TestMagic,
 NULL,
 NULL,
 CloseGame,
 MDFNNES_SetLayerEnableMask,
 "Background\0Sprites\0",
 NULL,
 NULL,

 NES_CPInfo,
 0,

 InstallReadPatch,
 RemoveReadPatches,
 MemRead,
 &CheatFormatInfo,
 false,
 StateAction,
 Emulate,
 NULL,
 MDFNNES_SetInput,
 FDS_SetMedia,
 MDFNNES_DoSimpleCommand,
 NESSettings,
 0,
 0,
 FALSE,	// Multires

 0,   // lcm_width		(replaced in game load)
 0,   // lcm_height           	(replaced in game load)
 NULL,  // Dummy

 256,	// Nominal width
 240,	// Nominal height
 256,	// Framebuffer width(altered if NTSC blitter is enabled)
 240,	// Framebuffer height

 1,     // Number of output sound channels
};
