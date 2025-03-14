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

#include "pce.h"
#include "vdc.h"
#include "psg.h"
#include "input.h"
#include "huc.h"
#include "pcecd.h"
#include "pcecd_drive.h"
#include "hes.h"
#include <mednafen/hw_misc/arcade_card/arcade_card.h>
#include <mednafen/mempatcher.h>
#include <mednafen/cdrom/CDInterface.h>

namespace MDFN_IEN_PCE_FAST
{

static std::vector<CDInterface*> *cdifs = NULL;
static PCEFast_PSG *psg = NULL;
extern ArcadeCard *arcade_card; // Bah, lousy globals.

static Blip_Buffer* sbuf = NULL; //[2];

bool PCE_ACEnabled;

static bool IsSGX;
static bool IsHES;
int pce_overclocked;

// Statically allocated for speed...or something.
uint8 ROMSpace[0x88 * 8192 + 8192];	// + 8192 for PC-as-pointer safety padding

uint8 BaseRAM[32768 + 8192]; // 8KB for PCE, 32KB for Super Grafx // + 8192 for PC-as-pointer safety padding

uint8 PCEIODataBuffer;

static DECLFR(PCEBusRead)
{
 //printf("BUS Read: %02x %04x\n", A >> 13, A);
 return(0xFF);
}

static DECLFW(PCENullWrite)
{
 //printf("Null Write: %02x, %08x %02x\n", A >> 13, A, V);
}

static DECLFR(BaseRAMReadSGX)
{
 return BaseRAM[(size_t)A - (0xF8 * 8192)];
}

static DECLFW(BaseRAMWriteSGX)
{
 BaseRAM[(size_t)A - (0xF8 * 8192)] = V;
}

static DECLFR(BaseRAMRead)
{
 return BaseRAM[(size_t)A - (0xF8 * 8192)];
}

static DECLFR(BaseRAMRead_Mirrored)
{
 return(BaseRAM[A & 0x1FFF]);
}

static DECLFW(BaseRAMWrite)
{
 BaseRAM[(size_t)A - (0xF8 * 8192)] = V;
}

static DECLFW(BaseRAMWrite_Mirrored)
{
 BaseRAM[A & 0x1FFF] = V;
}

static DECLFR(IORead)
{
 #define IOREAD_SGX 0
 #include "ioread.inc"
 #undef IOREAD_SGX
}

static DECLFR(IOReadSGX)
{
 #define IOREAD_SGX 1
 #include "ioread.inc"
 #undef IOREAD_SGX
}

static DECLFW(IOWrite)
{
 A &= 0x1FFF;
  
 switch(A >> 10)
 {
  case 0: HuC6280_StealCycle();
	       VDC_Write(A, V);
	       break;

  case 1: HuC6280_StealCycle();
	       VCE_Write(A, V);
	       break;

  case 2: PCEIODataBuffer = V;
	       psg->Write(HuCPU.timestamp / pce_overclocked, A, V);
	       break;

  case 3: PCEIODataBuffer = V;
	       HuC6280_TimerWrite(A, V);
	       break;

  case 4: PCEIODataBuffer = V; INPUT_Write(A, V); break;
  case 5: PCEIODataBuffer = V; HuC6280_IRQStatusWrite(A, V); break;
  case 6: 
	  if(!PCE_IsCD)
	   break;

	  if((A & 0x1E00) == 0x1A00)
	  {
	   if(arcade_card)
	    arcade_card->Write(A & 0x1FFF, V);
	  }
	  else
	  {
	   PCECD_Write(HuCPU.timestamp * 3, A, V);
	  }
	  break;

  case 7: break;	// Expansion.
 }
}

static void PCECDIRQCB(bool asserted)
{
 if(asserted)
  HuC6280_IRQBegin(MDFN_IQIRQ2);
 else
  HuC6280_IRQEnd(MDFN_IQIRQ2);
}

void PCE_InitCD(void)
{
 PCECD_Settings cd_settings;
 memset(&cd_settings, 0, sizeof(PCECD_Settings));

 cd_settings.CDDA_Volume = (double)MDFN_GetSettingUI("pce_fast.cddavolume") / 100;
 cd_settings.CD_Speed = MDFN_GetSettingUI("pce_fast.cdspeed");

 cd_settings.ADPCM_Volume = (double)MDFN_GetSettingUI("pce_fast.adpcmvolume") / 100;
 cd_settings.ADPCM_LPF = MDFN_GetSettingB("pce_fast.adpcmlp");

 if(cd_settings.CDDA_Volume != 1.0)
  MDFN_printf(_("CD-DA Volume: %d%%\n"), (int)(100 * cd_settings.CDDA_Volume));

 if(cd_settings.ADPCM_Volume != 1.0)
  MDFN_printf(_("ADPCM Volume: %d%%\n"), (int)(100 * cd_settings.ADPCM_Volume));

 PCECD_Init(&cd_settings, PCECDIRQCB, PCE_MASTER_CLOCK, pce_overclocked, sbuf);
}


static void LoadCommon(void) MDFN_COLD;
static void LoadCommonPre(void) MDFN_COLD;

static MDFN_COLD bool TestMagic(GameFile* gf)
{
 if(gf->ext != "hes" && gf->ext != "pce" && gf->ext != "sgx")
  return false;

 return true;
}

static MDFN_COLD void Cleanup(void)
{
 if(IsHES)
  HES_Close();
 else
 {
  HuC_Kill();
 }

 VDC_Close();

 if(psg)
 {
  delete psg;
  psg = NULL;
 }

 if(sbuf)
 {
  delete[] sbuf;
  sbuf = NULL;
 }

 cdifs = NULL;
}

static const struct
{
 uint32 crc;
 const char* name;
} sgx_table[] = 
{
	{ 0xbebfe042, "Darius Plus", },
	{ 0x4c2126b0, "Aldynes" },
	{ 0x8c4588e2, "1941 - Counter Attack" },
	{ 0x1f041166, "Madouou Granzort" },
	{ 0xb486a8ed, "Daimakaimura" },
	{ 0x3b13af61, "Battle Ace" },
};

static MDFN_COLD void Load(GameFile* gf)
{
 try
 {
  uint8 hes_header[4];

  IsHES = false;
  IsSGX = false;

  gf->stream->read(hes_header, 4);
  gf->stream->seek(0, SEEK_SET);

  if(!memcmp(hes_header, "HESM", 4))
   IsHES = true;

  LoadCommonPre();

  for(int x = 0; x < 0x100; x++)
  {
   HuCPU.PCERead[x] = PCEBusRead;
   HuCPU.PCEWrite[x] = PCENullWrite;
  }

  if(IsHES)
   HES_Load(gf->stream);
  else
  {
   uint32 crc;

   crc = HuC_Load(gf->stream);

   if(gf->ext == "sgx")
    IsSGX = true;
   else
   {
    for(auto const& e : sgx_table)
    {
     if(e.crc == crc)
     {
      IsSGX = true;
      MDFN_printf(_("SuperGrafx: %s\n"), e.name);
      break;
     }
    }
   }
  }

  LoadCommon();
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

static void LoadCommonPre(void)
{
 HuC6280_Init();

 // FIXME:  Make these globals less global!
 pce_overclocked = MDFN_GetSettingUI("pce_fast.ocmultiplier");
 PCE_ACEnabled = MDFN_GetSettingB("pce_fast.arcadecard");

 if(pce_overclocked > 1)
  MDFN_printf(_("CPU overclock: %dx\n"), pce_overclocked);

 if(MDFN_GetSettingUI("pce_fast.cdspeed") > 1)
  MDFN_printf(_("CD-ROM speed:  %ux\n"), (unsigned int)MDFN_GetSettingUI("pce_fast.cdspeed"));

 for(int x = 0; x < 0x100; x++)
 {
  HuCPU.PCERead[x] = PCEBusRead;
  HuCPU.PCEWrite[x] = PCENullWrite;
 }

 MDFNMP_Init(1024, (1 << 21) / 1024);

 sbuf = new Blip_Buffer[2];
}

static void LoadCommon(void)
{ 
 IsSGX |= MDFN_GetSettingB("pce_fast.forcesgx") ? 1 : 0;

 if(IsHES)
  IsSGX = 1;
 // Don't modify IsSGX past this point.
 
 VDC_Init(IsSGX);
 VDC_SetSettings(MDFN_GetSettingB("pce_fast.nospritelimit"), MDFN_GetSettingB("pce_fast.correct_aspect"));

 if(IsSGX)
 {
  MDFN_printf("SuperGrafx Emulation Enabled.\n");
  HuCPU.PCERead[0xF8] = HuCPU.PCERead[0xF9] = HuCPU.PCERead[0xFA] = HuCPU.PCERead[0xFB] = BaseRAMReadSGX;
  HuCPU.PCEWrite[0xF8] = HuCPU.PCEWrite[0xF9] = HuCPU.PCEWrite[0xFA] = HuCPU.PCEWrite[0xFB] = BaseRAMWriteSGX;

  for(int x = 0xf8; x < 0xfb; x++)
   HuCPU.FastMap[x] = &BaseRAM[(x & 0x3) * 8192];

  HuCPU.PCERead[0xFF] = IOReadSGX;
 }
 else
 {
  HuCPU.PCERead[0xF8] = BaseRAMRead;
  HuCPU.PCERead[0xF9] = HuCPU.PCERead[0xFA] = HuCPU.PCERead[0xFB] = BaseRAMRead_Mirrored;

  HuCPU.PCEWrite[0xF8] = BaseRAMWrite;
  HuCPU.PCEWrite[0xF9] = HuCPU.PCEWrite[0xFA] = HuCPU.PCEWrite[0xFB] = BaseRAMWrite_Mirrored;

  for(int x = 0xf8; x < 0xfb; x++)
   HuCPU.FastMap[x] = &BaseRAM[0];

  HuCPU.PCERead[0xFF] = IORead;
 }

 MDFNMP_AddRAM(IsSGX ? 32768 : 8192, 0xf8 * 8192, BaseRAM);

 HuCPU.PCEWrite[0xFF] = IOWrite;

 psg = new PCEFast_PSG(sbuf);

 psg->SetVolume(1.0);

 if(PCE_IsCD)
 {
  unsigned int cdpsgvolume = MDFN_GetSettingUI("pce_fast.cdpsgvolume");

  if(cdpsgvolume != 100)
  {
   MDFN_printf(_("CD PSG Volume: %d%%\n"), cdpsgvolume);
  }

  psg->SetVolume(0.678 * cdpsgvolume / 100);

 }

 PCEINPUT_Init();

 PCE_Power();

 MDFNGameInfo->LayerNames = IsSGX ? "BG0\0SPR0\0BG1\0SPR1\0" : "Background\0Sprites\0";
 MDFNGameInfo->fps = (uint32)((double)7159090.90909090 / 455 / 263 * 65536 * 256);

 if(!IsHES)
 {
  // Clean this up:
  if(!MDFN_GetSettingB("pce_fast.correct_aspect"))
   MDFNGameInfo->fb_width = 682;

  MDFNGameInfo->nominal_width = MDFN_GetSettingB("pce_fast.correct_aspect") ? 288 : 341;
  MDFNGameInfo->nominal_height = MDFN_GetSettingUI("pce_fast.slend") - MDFN_GetSettingUI("pce_fast.slstart") + 1;

  MDFNGameInfo->lcm_width = MDFN_GetSettingB("pce_fast.correct_aspect") ? 1024 : 341;
  MDFNGameInfo->lcm_height = MDFNGameInfo->nominal_height;
 }
}

static MDFN_COLD bool TestMagicCD(std::vector<CDInterface*> *CDInterfaces)
{
 static const uint8 magic_test[0x20] = { 0x82, 0xB1, 0x82, 0xCC, 0x83, 0x76, 0x83, 0x8D, 0x83, 0x4F, 0x83, 0x89, 0x83, 0x80, 0x82, 0xCC,
                                         0x92, 0x98, 0x8D, 0xEC, 0x8C, 0xA0, 0x82, 0xCD, 0x8A, 0x94, 0x8E, 0xAE, 0x89, 0xEF, 0x8E, 0xD0
                                       };
 uint8 sector_buffer[2048];
 CDInterface* cdiface = (*CDInterfaces)[0];
 CDUtility::TOC toc;
 bool ret = false;

 memset(sector_buffer, 0, sizeof(sector_buffer));

 cdiface->ReadTOC(&toc);

 for(int32 track = toc.first_track; track <= toc.last_track; track++)
 {
  if(toc.tracks[track].control & 0x4)
  {
   if(cdiface->ReadSectors(sector_buffer, toc.tracks[track].lba, 1) != 0x1)
    break;

   if(!memcmp((char*)sector_buffer, (char *)magic_test, 0x20))
    ret = true;

   // PCE CD BIOS apparently only looks at the first data track.
   break;
  }
 }

 // If it's a PC-FX CD(Battle Heat), return false.
 // This is very kludgy.
 for(int32 track = toc.first_track; track <= toc.last_track; track++)
 {
  if(toc.tracks[track].control & 0x4)
  {
   if(cdiface->ReadSectors(sector_buffer, toc.tracks[track].lba, 1) == 0x1)
   {
    if(!strncmp("PC-FX:Hu_CD-ROM", (char*)sector_buffer, strlen("PC-FX:Hu_CD-ROM")))
    {
     return false;
    }
   }
  }
 }

 // Now, test for the Games Express CD games.  The GE BIOS seems to always look at sector 0x10, but only if the first track is a
 // data track.
 if(toc.first_track == 1 && (toc.tracks[1].control & 0x4))
 {
  if(cdiface->ReadSectors(sector_buffer, 0x10, 1) == 0x1)
  {
   if(!memcmp((char *)sector_buffer + 0x8, "HACKER CD ROM SYSTEM", 0x14))
   {
    ret = true;
   }
  }
 }

 return(ret);
}

static MDFN_COLD bool DetectSGXCD(CDInterface* cdiface)
{
 CDUtility::TOC toc;
 uint8 sector_buffer[2048];
 bool ret = false;

 memset(sector_buffer, 0, sizeof(sector_buffer));

 cdiface->ReadTOC(&toc);

 // Check all data tracks for the 16-byte magic(4D 65 64 6E 61 66 65 6E 74 AB 90 19 42 62 7D E6) at offset 0x86A(assuming mode 1 sectors).
 for(int32 track = toc.first_track; track <= toc.last_track; track++)
 {
  if(toc.tracks[track].control & 0x4)
  {
   if(cdiface->ReadSectors(sector_buffer, toc.tracks[track].lba + 1, 1) != 0x1)
    continue;

   if(MDFN_de64msb(&sector_buffer[0x6A]) == 0x4D65646E6166656EULL && MDFN_de64msb(&sector_buffer[0x6A + 8]) == 0x74AB901942627DE6ULL)
    ret = true;
  }
 }

 return ret;
}

static MDFN_COLD void LoadCD(std::vector<CDInterface*> *CDInterfaces)
{
 try
 {
  std::string bios_path = MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, MDFN_GetSettingS("pce_fast.cdbios"));

  IsHES = 0;
  IsSGX = CDInterfaces->size() && DetectSGXCD((*CDInterfaces)[0]);

  LoadCommonPre();

  HuC_LoadCD(bios_path.c_str());

  cdifs = CDInterfaces;
  PCECD_Drive_SetDisc(true, NULL, true);

  LoadCommon();
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}


static MDFN_COLD void CloseGame(void)
{
 HuC_SaveNV();
 Cleanup();
}

static void Emulate(EmulateSpecStruct *espec)
{
 INPUT_Frame();

 MDFNMP_ApplyPeriodicCheats();

 if(espec->VideoFormatChanged)
  VDC_SetPixelFormat(espec->surface->format, espec->CustomPalette, espec->CustomPaletteNumEntries);

 if(espec->SoundFormatChanged)
 {
  for(int y = 0; y < 2; y++)
  {
   sbuf[y].set_sample_rate(espec->SoundRate ? espec->SoundRate : 44100, 50);
   sbuf[y].clock_rate((long)(PCE_MASTER_CLOCK / 3));
   sbuf[y].bass_freq(10);
  }
 }
 VDC_RunFrame(espec, IsHES);

 if(PCE_IsCD)
 {
  PCECD_Run(HuCPU.timestamp * 3);
 }

 psg->EndFrame(HuCPU.timestamp / pce_overclocked);

 if(espec->SoundBuf)
 {
  for(int y = 0; y < 2; y++)
  {
   sbuf[y].end_frame(HuCPU.timestamp / pce_overclocked);
   espec->SoundBufSize = sbuf[y].read_samples(espec->SoundBuf + y, espec->SoundBufMaxSize, 1);
  }
 }

 espec->MasterCycles = HuCPU.timestamp * 3;

 INPUT_FixTS();

 HuC6280_ResetTS();

 if(PCE_IsCD)
  PCECD_ResetTS();

 if(IsHES && !espec->skip)
  HES_Draw(espec->surface, &espec->DisplayRect, espec->SoundBuf, espec->SoundBufSize);
}

static void StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFPTR8(BaseRAM, IsSGX? 32768 : 8192),
  SFVAR(PCEIODataBuffer),
  SFEND
 };

 //for(int i = 8192; i < 32768; i++)
 // if(BaseRAM[i] != 0xFF)
 //  printf("%d %02x\n", i, BaseRAM[i]);

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAIN");

 HuC6280_StateAction(sm, load, data_only);
 VDC_StateAction(sm, load, data_only);
 psg->StateAction(sm, load, data_only);
 INPUT_StateAction(sm, load, data_only);
 HuC_StateAction(sm, load, data_only);

 if(load)
 {

 }
}

void PCE_Power(void)
{
 memset(BaseRAM, 0x00, sizeof(BaseRAM));

 if(!IsSGX)
  for(int i = 8192; i < 32768; i++)
   BaseRAM[i] = 0xFF;

 PCEIODataBuffer = 0xFF;

 if(IsHES)
  HES_Reset();

 HuC6280_Power();
 VDC_Power();
 psg->Power(HuCPU.timestamp / pce_overclocked);
 HuC_Power();

 if(PCE_IsCD)
 {
  PCECD_Power(HuCPU.timestamp * 3);
 }
}

static MDFN_COLD void SetMedia(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{
 const RMD_Layout* rmd = MDFNGameInfo->RMD;
 const RMD_Drive* rd = &rmd->Drives[drive_idx];
 const RMD_State* rs = &rd->PossibleStates[state_idx];

 if(rs->MediaPresent && rs->MediaUsable)
 {
  PCECD_Drive_SetDisc(false, (*cdifs)[media_idx]);
 }
 else
 {
  PCECD_Drive_SetDisc(rs->MediaCanChange, NULL);
 }
}


static MDFN_COLD void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_RESET: PCE_Power(); break;
  case MDFN_MSC_POWER: PCE_Power(); break;
 }
}

static const MDFNSetting PCESettings[] = 
{
  { "pce_fast.correct_aspect", MDFNSF_CAT_VIDEO, gettext_noop("Correct the aspect ratio."), NULL, MDFNST_BOOL, "1" },
  { "pce_fast.slstart", MDFNSF_NOFLAGS, gettext_noop("First rendered scanline."), NULL, MDFNST_UINT, "4", "0", "239" },
  { "pce_fast.slend", MDFNSF_NOFLAGS, gettext_noop("Last rendered scanline."), NULL, MDFNST_UINT, "235", "0", "239" },
  { "pce_fast.mouse_sensitivity", MDFNSF_NOFLAGS, gettext_noop("Mouse sensitivity."), NULL, MDFNST_FLOAT, "0.50", NULL, NULL, NULL, PCEINPUT_SettingChanged },
  { "pce_fast.disable_softreset", MDFNSF_NOFLAGS, gettext_noop("If set, when RUN+SEL are pressed simultaneously, disable both buttons temporarily."), NULL, MDFNST_BOOL, "0", NULL, NULL, NULL, PCEINPUT_SettingChanged },
  { "pce_fast.forcesgx", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Force SuperGrafx emulation."), NULL, MDFNST_BOOL, "0" },
  { "pce_fast.arcadecard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable Arcade Card emulation."), NULL, MDFNST_BOOL, "1" },
  { "pce_fast.ocmultiplier", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("CPU overclock multiplier."), NULL, MDFNST_UINT, "1", "1", "100"},
  { "pce_fast.cdspeed", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("CD-ROM data transfer speed multiplier."), NULL, MDFNST_UINT, "1", "1", "100" },
  { "pce_fast.nospritelimit", MDFNSF_NOFLAGS, gettext_noop("Remove 16-sprites-per-scanline hardware limit."), NULL, MDFNST_BOOL, "0" },

  { "pce_fast.cdbios", MDFNSF_EMU_STATE | MDFNSF_CAT_PATH, gettext_noop("Path to the CD BIOS"), NULL, MDFNST_STRING, "syscard3.pce" },

  { "pce_fast.adpcmlp", MDFNSF_NOFLAGS, gettext_noop("Enable dynamic ADPCM lowpass filter."), NULL, MDFNST_BOOL, "0" },
  { "pce_fast.cdpsgvolume", MDFNSF_NOFLAGS, gettext_noop("PSG volume when playing a CD game."), NULL, MDFNST_UINT, "100", "0", "200" },
  { "pce_fast.cddavolume", MDFNSF_NOFLAGS, gettext_noop("CD-DA volume."), NULL, MDFNST_UINT, "100", "0", "200" },
  { "pce_fast.adpcmvolume", MDFNSF_NOFLAGS, gettext_noop("ADPCM volume."), NULL, MDFNST_UINT, "100", "0", "200" },
  { NULL }
};

static uint8 MemRead(uint32 addr)
{
 return HuCPU.PCERead[(addr / 8192) & 0xFF](addr);
}

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".pce",   0, gettext_noop("PC Engine ROM Image") },
 { ".hes", -20, gettext_noop("PC Engine Music Rip") },
 { ".sgx",   0, gettext_noop("SuperGrafx ROM Image") },

 { NULL, 0, NULL }
};

static const CustomPalette_Spec CPInfo[] =
{
 { gettext_noop("PCE/TG16 9-bit GRB.  If only 512 triplets are present, the remaining 512 greyscale colors will be calculated automatically."), NULL, { 512, 1024, 0 } },

 { NULL, NULL }
};

static const CheatInfoStruct CheatInfo =
{
 NULL,
 NULL,
 MemRead,
 NULL,

 CheatFormatInfo_Empty
};

};

/*MDFN_HIDE*/ extern const MDFNGI EmulatedPCE_Fast =
{
 "pce_fast",
 "PC Engine (CD)/TurboGrafx 16 (CD)/SuperGrafx",
 KnownExtensions,
 MODPRIO_INTERNAL_LOW,
 NULL,
 PCEPortInfo,
 NULL,
 Load,
 TestMagic,
 LoadCD,
 TestMagicCD,
 CloseGame,

 VDC_SetLayerEnableMask,
 NULL,

 NULL,
 NULL,

 CPInfo,
 1 << 0,

 CheatInfo,

 false,
 StateAction,
 Emulate,
 INPUT_TransformInput,
 PCEINPUT_SetInput,
 SetMedia,
 DoSimpleCommand,
 NULL,
 PCESettings,
 MDFN_MASTERCLOCK_FIXED(PCE_MASTER_CLOCK),
 0,

 EVFSUPPORT_RGB555 | EVFSUPPORT_RGB565,

 true,  // Multires possible?

 0,   // lcm_width
 0,   // lcm_height           
 NULL,  // Dummy

 288,   // Nominal width
 232,   // Nominal height

 512,	// Framebuffer width
 242,	// Framebuffer height

 2,     // Number of output sound channels
};

