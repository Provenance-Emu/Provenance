/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* snes.cpp:
**  Copyright (C) 2015-2021 Mednafen Team
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

#include "snes.h"
#include "input.h"
#include "cart.h"
#include "msu1.h"
#include "apu.h"
#include "ppu.h"

#include <mednafen/mednafen.h>
#include <mednafen/mempatcher.h>
#include <mednafen/SNSFLoader.h>
#include <mednafen/player.h>
#include <mednafen/hash/sha1.h>
#include <mednafen/cheat_formats/snes.h>

#include <bitset>

namespace MDFN_IEN_SNES_FAUST
{
static bool SpecEx, SpecExSoundToo;
static MemoryStream* SpecExSS = NULL;
static int32 SpecExAudioExpected;

struct ReadPatchInfoStruct
{
 bool operator<(const ReadPatchInfoStruct& o) const
 {
  return address < o.address;
 }
 ReadPatchInfoStruct() { }
 ReadPatchInfoStruct(const uint32 a) : address(a) { }

 uint32 address;
 uint8 value;
 int compare;
 uint8 prev_mapping;
};
static std::vector<ReadPatchInfoStruct> ReadPatchInfo;

static void InitEvents(void) MDFN_COLD;


template<bool b_bus>
static void SetHandlers(uint32 A1, uint32 A2, readfunc read_handler, writefunc write_handler)
{
 // entry 0xFF is reserved for game genie cheats handler
 unsigned index = 0;

 if(A1 != A2 || b_bus)
 {
  assert(read_handler && write_handler);
 }
 else
 {
  if(!read_handler)
   read_handler = CPUM.ReadFuncs[CPUM.RWIndex[A1]];

  if(!write_handler)
   write_handler = CPUM.WriteFuncs[CPUM.RWIndex[A1]];
 }

 while(index < 255 && CPUM.ReadFuncs[index] && CPUM.WriteFuncs[index] && (CPUM.ReadFuncs[index] != read_handler || CPUM.WriteFuncs[index] != write_handler))
  index++;

 assert(index < 255);

 CPUM.ReadFuncs[index] = read_handler;
 CPUM.WriteFuncs[index] = write_handler;
 CPUM.ReadFuncsA[index] = b_bus ? OBRead_FAST : read_handler;
 CPUM.WriteFuncsA[index] = b_bus ? OBWrite_FAST : write_handler;

 if(b_bus)
 {
  assert(A1 < 256 && A2 < 256);

  for(unsigned bank = 0x00; bank < 0x100; bank++)
  {
   if(bank <= 0x3F || (bank >= 0x80 && bank <= 0xBF))
   {
    for(uint32 baddr = A1; baddr <= A2; baddr++)
    {
     CPUM.DM_ReadFuncsB[baddr] = read_handler;
     CPUM.DM_WriteFuncsB[baddr] = write_handler;

     CPUM.RWIndex[(bank << 16) + 0x2100 + baddr] = index;
    }
   }
  }
 }
 else
 {
  for(uint32 addr = A1; addr <= A2; addr++)
  {
   CPUM.RWIndex[addr] = index;
  }
 }

 CPUM.RWIndex[256 * 65536] = CPUM.RWIndex[0];
}

void Set_A_Handlers(uint32 A1, uint32 A2, readfunc read_handler, writefunc write_handler)
{
 SetHandlers<false>(A1, A2, read_handler, write_handler);
}

void Set_B_Handlers(uint8 A1, uint8 A2, readfunc read_handler, writefunc write_handler)
{
 SetHandlers<true>(A1, A2, read_handler, write_handler);
}

template<signed cyc>
static INLINE DEFREAD(OBRead)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return CPUM.mdr;
 }

 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += CPUM.MemSelectCycles;

 // TODO: tentative fix for "Speedy Gonzales", but should it be per-game or restricted to specific addresses?
 //if(MDFN_UNLIKELY(CPUM.timestamp >= events[SNES_EVENT_PPU].event_time) && !CPUM.InDMABusAccess)
 // CPUM.EventHandler();

 SNES_DBG("[SNES] Unknown Read: $%02x:%04x\n", A >> 16, A & 0xFFFF);
 return CPUM.mdr;
}

template<signed cyc>
static INLINE DEFWRITE(OBWrite)
{
 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += CPUM.MemSelectCycles;

 SNES_DBG("[SNES] Unknown Write: $%02x:%04x $%02x\n", A >> 16, A & 0xFFFF, V);
}

DEFREAD(OBRead_XSLOW) { return OBRead<MEMCYC_XSLOW>(A); }
DEFREAD(OBRead_SLOW)  { return OBRead<MEMCYC_SLOW>(A); }
DEFREAD(OBRead_FAST)  { return OBRead<MEMCYC_FAST>(A); }
DEFREAD(OBRead_VAR)   { return OBRead<-1>(A); }

DEFWRITE(OBWrite_XSLOW) { OBWrite<MEMCYC_XSLOW>(A, V); }
DEFWRITE(OBWrite_SLOW) { OBWrite<MEMCYC_SLOW>(A, V); }
DEFWRITE(OBWrite_FAST) { OBWrite<MEMCYC_FAST>(A, V); }
DEFWRITE(OBWrite_VAR) { OBWrite<-1>(A, V); }


static uint8 WRAM[0x20000];
#ifdef SNES_DBG_ENABLE
static std::bitset<0x20000> WRAMWritten;	// for debugging
#endif

template<uint32 mask>
static DEFREAD(WRAMRead)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return WRAM[A & mask];
 }

 CPUM.timestamp += MEMCYC_SLOW;

#ifdef SNES_DBG_ENABLE
 //if(!WRAMWritten[A & mask])
 // SNES_DBG("[SNES] Read from uninitialized WRAM at 0x%08x!\n", A & mask);
#endif

 return WRAM[A & mask];
}

template<uint32 mask>
static DEFWRITE(WRAMWrite)
{
 CPUM.timestamp += MEMCYC_SLOW;

 WRAM[A & mask] = V;

#ifdef SNES_DBG_ENABLE
 WRAMWritten[A & mask] = true;
#endif
}

static uint8 Multiplicand;
static uint16 MultProduct;	// Also division remainder.

static uint16 Dividend;
static uint16 DivQuotient;

static uint32 WMAddress;

#include "dma.inc"

static void ICRegsReset(bool powering_up)
{
 if(powering_up)
 {
  Multiplicand = 0xFF;
  MultProduct = 0xFFFF;

  Dividend = 0xFFFF;
  DivQuotient = 0xFFFF;
 }

 WMAddress = 0;

 CPUM.MemSelectCycles = MEMCYC_SLOW;
}

static DEFWRITE(ICRegsWrite)
{
 CPUM.timestamp += MEMCYC_FAST;

 A &= 0xFFFF;

 switch(A & 0xFFFF)
 {
  case 0x4202:	Multiplicand = V;
		break;

  case 0x4203:	MultProduct = Multiplicand * V;
		break;

  case 0x4204:	Dividend = (Dividend & 0xFF00) | (V << 0);
		break;

  case 0x4205:  Dividend = (Dividend & 0x00FF) | (V << 8);
		break;

  case 0x4206:	//printf("Divide: 0x%04x / 0x%02x\n", Dividend, V);

		if(!V)
		{
		 DivQuotient = 0xFFFF;
		 MultProduct = Dividend;
		}
		else
		{
		 DivQuotient = Dividend / V;
		 MultProduct = Dividend % V;
		}
		break;

  case 0x420D:  CPUM.MemSelectCycles = (V & 1) ? MEMCYC_FAST : MEMCYC_SLOW;;
		break;
 }
}


static DEFREAD(Read_4214)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DivQuotient >> 0;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DivQuotient >> 0;
}

static DEFREAD(Read_4215)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return DivQuotient >> 8;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return DivQuotient >> 8;
}

static DEFREAD(Read_4216)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return MultProduct >> 0;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return MultProduct >> 0;
}

static DEFREAD(Read_4217)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return MultProduct >> 8;
 }

 CPUM.timestamp += MEMCYC_FAST;

 return MultProduct >> 8;
}

//
//
//
static DEFWRITE(Write_2180)
{
 CPUM.timestamp += MEMCYC_FAST;

#ifdef SNES_DBG_ENABLE
 WRAMWritten[WMAddress] = true;
#endif

 WRAM[WMAddress] = V;
 WMAddress = (WMAddress + 1) & 0x1FFFF;
}

static DEFWRITE(Write_2181)
{
 CPUM.timestamp += MEMCYC_FAST;

 WMAddress &= 0xFFFF00;
 WMAddress |= V << 0;
}

static DEFWRITE(Write_2182)
{
 CPUM.timestamp += MEMCYC_FAST;

 WMAddress &= 0xFF00FF;
 WMAddress |= V << 8;
}

static DEFWRITE(Write_2183)
{
 CPUM.timestamp += MEMCYC_FAST;

 WMAddress &= 0x00FFFF;
 WMAddress |= (V & 1) << 16;
}

static DEFREAD(Read_2180)
{
 if(MDFN_UNLIKELY(DBG_InHLRead))
 {
  return WRAM[WMAddress];
 }

 uint8 ret;

 CPUM.timestamp += MEMCYC_FAST;

 ret = WRAM[WMAddress];
 WMAddress = (WMAddress + 1) & 0x1FFFF;

 return ret;
}

static INLINE ReadPatchInfoStruct FindRPie(uint32 A)
{
 A &= 0xFFFFFF;
 //
 std::vector<ReadPatchInfoStruct>::const_iterator it = std::lower_bound(ReadPatchInfo.begin(), ReadPatchInfo.end(), A);

 assert(it != ReadPatchInfo.end() && it->address == A);

 return *it;
}

template<bool ForceA>
static DEFREAD_NOHOT(Read_CheatHook)
{
 ReadPatchInfoStruct rpie = FindRPie(A);
 uint8 ret = (ForceA ? CPUM.ReadFuncsA : CPUM.ReadFuncs)[rpie.prev_mapping](A);

 if(rpie.compare < 0 || ret == rpie.compare)
  ret = rpie.value;

 return ret;
}

template<bool ForceA>
static DEFWRITE_NOHOT(Write_CheatHook)
{
 ReadPatchInfoStruct rpie = FindRPie(A);
 (ForceA ? CPUM.WriteFuncsA : CPUM.WriteFuncs)[rpie.prev_mapping](A, V);
}

//
//
//
static SNSFLoader* snsf_loader = NULL;
static SPCReader* spc_reader = NULL;

static MDFN_COLD void Reset(bool powering_up)
{
 if(spc_reader)
 {
  APU_Reset(powering_up);
  APU_SetSPC(spc_reader);

  return;
 }

 if(powering_up)
 {
  for(unsigned i = 0, p = 0xCAFEBEEF; i < sizeof(WRAM); i++, p = (p << 1) | (((p >> 31) ^ (p >> 21) ^ (p >> 1) ^ p) & 1))
   WRAM[i] = ((p + i * 3) % 192) + 32;

  //memset(WRAM, 0x02, sizeof(WRAM));
  //WRAM[0x1D0FF] = 0x0;	// lufia 2...

#ifdef SNES_DBG_ENABLE
  WRAMWritten.reset();
#endif
 }

 ICRegsReset(powering_up);
 DMA_Reset(powering_up);
 APU_Reset(powering_up);
 PPU_Reset(powering_up);
 CART_Reset(powering_up);
 MSU1_Reset(powering_up);
 INPUT_Reset(powering_up);

 //
 CPU_Reset(powering_up);

 InitEvents();
 ForceEventUpdates(0);
}

//
//
//

static MDFN_COLD bool TestMagic(GameFile* gf)
{
 if(gf->ext == "sfc" || gf->ext == "smc" || gf->ext == "swc" || gf->ext == "fig")
  return true;

 if(SNSFLoader::TestMagic(gf->stream))
  return true;

 if(SPCReader::TestMagic(gf->stream))
  return true;

 return false;
}

static MDFN_COLD void Cleanup(void)
{
 ReadPatchInfo.clear();

 if(SpecExSS)
 {
  delete SpecExSS;
  SpecExSS = NULL;
 }

 if(snsf_loader)
 {
  delete snsf_loader;
  snsf_loader = NULL;
 }

 APU_Kill();

 if(spc_reader)
 {
  delete spc_reader;
  spc_reader = NULL;
 }
 else
 {
  PPU_Kill();
  INPUT_Kill();
  CART_Kill();
  MSU1_Kill();
 }
}

enum
{
 REGION_AUTO = 0,
 REGION_NTSC,
 REGION_PAL,
 REGION_NTSC_LIE_AUTO,
 REGION_PAL_LIE_AUTO,
 REGION_NTSC_LIE_PAL,
 REGION_PAL_LIE_NTSC
};

static MDFN_COLD void LoadReal(GameFile* gf)
{
 if(SPCReader::TestMagic(gf->stream))
 {
  spc_reader = new SPCReader(gf->stream);
  Player_Init(1, spc_reader->GameName(), spc_reader->ArtistName(), "", std::vector<std::string>({ spc_reader->SongName() }));
  MDFNGameInfo->fps = (1U << 24) * 75;
  MDFNGameInfo->MasterClock = MDFN_MASTERCLOCK_FIXED(21477272.7);

  MDFNGameInfo->IdealSoundRate = APU_Init(false, (double)MDFNGameInfo->MasterClock / MDFN_MASTERCLOCK_FIXED(1));
  Reset(true);

  return;
 }

 SpecEx = MDFN_GetSettingB("snes_faust.spex");
 SpecExSoundToo = MDFN_GetSettingB("snes_faust.spex.sound");
 SpecExAudioExpected = -1;

 MDFN_printf("SpecEx: %u\n", SpecEx);
 MDFN_printf("SpecExSoundToo: %u\n", SpecExSoundToo);

 MDFNMP_Init(8192, (1U << 24) / 8192);
 MDFNMP_RegSearchable(0x7E0000, 0x20000);

 DBG_Init();

 CPU_Init(&CPUM);

 memset(CPUM.ReadFuncs, 0, sizeof(CPUM.ReadFuncs));
 memset(CPUM.WriteFuncs, 0, sizeof(CPUM.WriteFuncs));

 memset(CPUM.ReadFuncsA, 0, sizeof(CPUM.ReadFuncsA));
 memset(CPUM.WriteFuncsA, 0, sizeof(CPUM.WriteFuncsA));

 CPUM.ReadFuncs[0xFF] = Read_CheatHook<false>;
 CPUM.WriteFuncs[0xFF] = Write_CheatHook<false>;

 CPUM.ReadFuncsA[0xFF] = Read_CheatHook<true>;
 CPUM.WriteFuncsA[0xFF] = Write_CheatHook<true>;

 //
 // Map in open bus.
 //
 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  readfunc ob_cart_r = OBRead_SLOW;
  writefunc ob_cart_w = OBWrite_SLOW;

  if(bank >= 0x80)
  {
   ob_cart_r = OBRead_VAR;
   ob_cart_w = OBWrite_VAR;
  }

  if(bank <= 0x3F || (bank >= 0x80 && bank <= 0xBF))
  {
   Set_A_Handlers((bank << 16) | 0x2000, (bank << 16) | 0x3FFF, OBRead_FAST, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4000, (bank << 16) | 0x41FF, OBRead_XSLOW, OBWrite_XSLOW);
   Set_A_Handlers((bank << 16) | 0x4200, (bank << 16) | 0x5FFF, OBRead_FAST, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x6000, (bank << 16) | 0x7FFF, OBRead_SLOW, OBWrite_SLOW);

   Set_A_Handlers((bank << 16) | 0x8000, (bank << 16) | 0xFFFF, ob_cart_r, ob_cart_w);
  }
  else if(bank != 0x7E && bank != 0x7F)
   Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0xFFFF, ob_cart_r, ob_cart_w);
 }
 Set_B_Handlers(0x00, 0xFF, OBRead_FAST, OBWrite_FAST);

 //
 // Map WRAM and CPU registers.
 //
 Set_A_Handlers(0x7E0000, 0x7FFFFF, WRAMRead<0x1FFFF>, WRAMWrite<0x1FFFF>);

 Set_B_Handlers(0x80, Read_2180, Write_2180);
 Set_B_Handlers(0x81, OBRead_FAST, Write_2181);
 Set_B_Handlers(0x82, OBRead_FAST, Write_2182);
 Set_B_Handlers(0x83, OBRead_FAST, Write_2183);

 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(bank <= 0x3F || (bank >= 0x80 && bank <= 0xBF))
  {
   Set_A_Handlers((bank << 16) | 0x0000, (bank << 16) | 0x1FFF, WRAMRead<0x1FFF>, WRAMWrite<0x1FFF>);

   Set_A_Handlers((bank << 16) | 0x4202, (bank << 16) | 0x4206, OBRead_FAST, ICRegsWrite);
   Set_A_Handlers((bank << 16) | 0x420D, OBRead_FAST, ICRegsWrite);

   Set_A_Handlers((bank << 16) | 0x4214, Read_4214, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4215, Read_4215, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4216, Read_4216, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4217, Read_4217, OBWrite_FAST);
  }
 }

 DMA_Init();
 //
 //
 if(SNSFLoader::TestMagic(gf->stream))
  snsf_loader = new SNSFLoader(gf->vfs, gf->dir, gf->stream);

 const int32 cx4_ocmultiplier = ((MDFN_GetSettingUI("snes_faust.cx4.clock_rate") << 16) + 50) / 100;
 const int32 superfx_ocmultiplier = ((MDFN_GetSettingUI("snes_faust.superfx.clock_rate") << 16) + 50) / 100;
 const bool superfx_enable_icache = MDFN_GetSettingB("snes_faust.superfx.icache");
 const bool CartIsPAL = CART_Init(snsf_loader ? &snsf_loader->ROM_Data : gf->stream, MDFNGameInfo->MD5, cx4_ocmultiplier, superfx_ocmultiplier, superfx_enable_icache);
 const unsigned region = MDFN_GetSettingUI("snes_faust.region");
 bool IsPAL, IsPALPPUBit;

 if(snsf_loader)
 {
  uint8* const cart_ram = CART_GetRAMPointer();

  if(cart_ram)
  {
   const size_t cart_ram_size = CART_GetRAMSize();
   const size_t read_size = std::min<size_t>(cart_ram_size, snsf_loader->SRAM_Data.size());

   memset(cart_ram, 0xFF, cart_ram_size);
   snsf_loader->SRAM_Data.read(cart_ram, read_size);
  }
 }
 else
  CART_LoadNV();

 switch(region)
 {
  default:
	assert(0);
  case REGION_AUTO:
	IsPAL = IsPALPPUBit = CartIsPAL;
	break;

  case REGION_NTSC:
	IsPAL = IsPALPPUBit = false;
	break;

  case REGION_PAL:
	IsPAL = IsPALPPUBit = true;
	break;

  case REGION_NTSC_LIE_AUTO:
	IsPAL = false;
	IsPALPPUBit = CartIsPAL;
	break;

  case REGION_PAL_LIE_AUTO:
	IsPAL = true;
	IsPALPPUBit = CartIsPAL;
	break;

  case REGION_NTSC_LIE_PAL:
	IsPAL = false;
	IsPALPPUBit = true;
	break;

  case REGION_PAL_LIE_NTSC:
	IsPAL = true;
	IsPALPPUBit = false;
	break;
 }
 //
 //
 INPUT_Init();
 {
  const bool mte[2] = { MDFN_GetSettingB("snes_faust.input.sport1.multitap"), MDFN_GetSettingB("snes_faust.input.sport2.multitap") };
  INPUT_SetMultitap(mte);
 }

 MDFNGameInfo->MasterClock = IsPAL ? MDFN_MASTERCLOCK_FIXED(21281370.0) : MDFN_MASTERCLOCK_FIXED(21477272.7);
 MDFNGameInfo->VideoSystem = IsPAL ? VIDSYS_PAL : VIDSYS_NTSC;

 PPU_Init(MDFN_GetSettingUI("snes_faust.renderer"), IsPAL, IsPALPPUBit, MDFN_GetSettingB("snes_faust.frame_begin_vblank"), MDFN_GetSettingUI("snes_faust.affinity.ppu"));
 //
 unsigned sls = MDFN_GetSettingUI(IsPAL ? "snes_faust.slstartp" : "snes_faust.slstart");
 unsigned sle = MDFN_GetSettingUI(IsPAL ? "snes_faust.slendp" : "snes_faust.slend");

 if(sle < sls)
  std::swap(sls, sle);

 PPU_SetGetVideoParams(MDFNGameInfo, MDFN_GetSettingUI("snes_faust.correct_aspect"), MDFN_GetSettingUI("snes_faust.h_filter"), sls, sle);

 MDFNGameInfo->IdealSoundRate = APU_Init(IsPAL, (double)MDFNGameInfo->MasterClock / MDFN_MASTERCLOCK_FIXED(1));
 MSU1_Init(gf, &MDFNGameInfo->IdealSoundRate, MDFN_GetSettingUI("snes_faust.affinity.msu1.audio"), MDFN_GetSettingUI("snes_faust.affinity.msu1.data"));
 //
 if(snsf_loader)
  Player_Init(1, snsf_loader->tags.GetTag("game"), snsf_loader->tags.GetTag("artist"), snsf_loader->tags.GetTag("copyright"), std::vector<std::string>({ snsf_loader->tags.GetTag("title") }));
 //
 //
 //
 Reset(true);
}

static MDFN_COLD void Load(GameFile* gf)
{
 try
 {
  LoadReal(gf);
 }
 catch(...)
 {
  Cleanup();

  throw;
 }
}

static MDFN_COLD void CloseGame(void)
{
 if(!snsf_loader && !spc_reader)
 {
  try
  {
   CART_SaveNV();
  }
  catch(std::exception &e)
  {
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
  }
 }
 Cleanup();
}

static MDFN_COLD uint8* CheatMemGetPointer(uint32 A)
{
 A &= (1U << 24) - 1;

 const uint8 bank = A >> 16;
 const uint16 offset = A & 0xFFFF;

 if(bank == 0x7E || bank == 0x7F)
  return &WRAM[A & 0x1FFFF];
 else if(bank <= 0x3F || (bank >= 0x80 && bank <= 0xBF))
 {
  if(offset >= 0x0000 && offset <= 0x1FFF)
   return &WRAM[A & 0x1FFF];
 }

 return nullptr;
}

static MDFN_COLD uint8 CheatMemRead(uint32 A)
{
 const uint8* p = CheatMemGetPointer(A);

 if(p)
  return *p;

 return 0x00;
}

static MDFN_COLD void CheatMemWrite(uint32 A, uint8 V)
{
 uint8* p = CheatMemGetPointer(A);

 if(p)
  *p = V;
}

static MDFN_COLD void CheatInstallReadPatch(uint32 address, uint8 value, int compare)
{
 //printf("ReadPatch: %08x %d %d\n", address, value, compare);
 address &= 0xFFFFFF;
 //
 {
  std::vector<ReadPatchInfoStruct>::iterator it = std::lower_bound(ReadPatchInfo.begin(), ReadPatchInfo.end(), address);

  if(it != ReadPatchInfo.end() && it->address == address)
  {
   it->value = value;
   it->compare = compare;
  }
  else
  {
   assert(it == ReadPatchInfo.end() || it->address > address);
   //
   ReadPatchInfoStruct rpi;

   rpi.address = address;
   rpi.value = value;
   rpi.compare = compare;
   rpi.prev_mapping = CPUM.RWIndex[address];
   assert(rpi.prev_mapping != 0xFF);

   ReadPatchInfo.insert(it, rpi);
  }
 }
 //
 CPUM.RWIndex[address] = 0xFF;
}

static MDFN_COLD void CheatRemoveReadPatches(void)
{
 for(auto const& rpie : ReadPatchInfo)
 {
  assert(CPUM.RWIndex[rpie.address] == 0xFF);
  assert(rpie.prev_mapping != 0xFF);
  CPUM.RWIndex[rpie.address] = rpie.prev_mapping;
 }

 ReadPatchInfo.clear();
}

event_list_entry events[SNES_EVENT__COUNT];

static MDFN_COLD void InitEvents(void)
{
 for(unsigned i = 0; i < SNES_EVENT__COUNT; i++)
 {
  if(i == SNES_EVENT__SYNFIRST)
   events[i].event_time = 0;
  else if(i == SNES_EVENT__SYNLAST)
   events[i].event_time = 0xFFFFFFFF;
  else
   events[i].event_time = SNES_EVENT_MAXTS;

  events[i].prev = (i > 0) ? &events[i - 1] : NULL;
  events[i].next = (i < (SNES_EVENT__COUNT - 1)) ? &events[i + 1] : NULL;
 }

 events[SNES_EVENT_PPU].event_handler = PPU_GetEventHandler();
 events[SNES_EVENT_PPU_LINEIRQ].event_handler = PPU_GetLineIRQEventHandler();
 events[SNES_EVENT_DMA_DUMMY].event_handler = DMA_Update;
 events[SNES_EVENT_CART].event_handler = CART_GetEventHandler();
 events[SNES_EVENT_MSU1].event_handler = MSU1_GetEventHandler();
}

static void RebaseTS(const uint32 timestamp)
{
 for(unsigned i = SNES_EVENT__SYNFIRST + 1; i < SNES_EVENT__SYNLAST; i++)
 {
  assert(events[i].event_time > timestamp);
  events[i].event_time -= timestamp;
 }

 CART_AdjustTS(-timestamp);
 MSU1_AdjustTS(-timestamp);

 CPUM.next_event_ts = events[SNES_EVENT__SYNFIRST].next->event_time;
}

void SNES_SetEventNT(const int type, const uint32 next_timestamp)
{
#ifdef SNES_DBG_ENABLE
 assert(type > SNES_EVENT__SYNFIRST && type < SNES_EVENT__SYNLAST);
#endif
 event_list_entry *e = &events[type];

 if(next_timestamp < e->event_time)
 {
  event_list_entry *fe = e;

  do
  {
   fe = fe->prev;
  }
  while(next_timestamp < fe->event_time);

  // Remove this event from the list, temporarily of course.
  e->prev->next = e->next;
  e->next->prev = e->prev;

  // Insert into the list, just after "fe".
  e->prev = fe;
  e->next = fe->next;
  fe->next->prev = e;
  fe->next = e;

  e->event_time = next_timestamp;
 }
 else if(next_timestamp > e->event_time)
 {
  event_list_entry *fe = e;

  do
  {
   fe = fe->next;
  } while(next_timestamp > fe->event_time);

  // Remove this event from the list, temporarily of course
  e->prev->next = e->next;
  e->next->prev = e->prev;

  // Insert into the list, just BEFORE "fe".
  e->prev = fe->prev;
  e->next = fe;
  fe->prev->next = e;
  fe->prev = e;

  e->event_time = next_timestamp;
 }

 CPUM.next_event_ts = events[SNES_EVENT__SYNFIRST].next->event_time & CPUM.running_mask;
}

// Called from debug.cpp too.
void ForceEventUpdates(const uint32 timestamp)
{
 for(unsigned i = SNES_EVENT__SYNFIRST + 1; i < SNES_EVENT__SYNLAST; i++)
 {
  SNES_SetEventNT(i, events[i].event_handler(timestamp));
 }
 //
 CPUM.next_event_ts = events[SNES_EVENT__SYNFIRST].next->event_time;
}

void CPU_Misc::EventHandler(void)
{
#ifdef SNES_DBG_ENABLE
 assert(!CPUM.InDMABusAccess);
#endif

 event_list_entry *e = events[SNES_EVENT__SYNFIRST].next;

 while(timestamp >= e->event_time)	// If Running = 0, SNES_EventHandler() may be called even if there isn't an event per-se, so while() instead of do { ... } while
 {
  event_list_entry *prev = e->prev;
  uint32 nt;

  nt = e->event_handler(e->event_time);
//#if SNES_EVENT_SYSTEM_CHECKS
  assert(nt > e->event_time);
//#endif

  SNES_SetEventNT(/*e->which*/e - events, nt);

  // Order of events can change due to calling SNES_SetEventNT(), this prev business ensures we don't miss an event due to reordering.
  e = prev->next;
 }

 //return(Running);
}

static void NO_INLINE EmulateReal(EmulateSpecStruct* espec)
{
 int32 apu_clock_multiplier;
 int32 resamp_num;
 int32 resamp_denom;
 const double master_clock = (double)MDFNGameInfo->MasterClock / MDFN_MASTERCLOCK_FIXED(1);
 const bool resamp_clear_buf = APU_StartFrame(master_clock, espec->SoundRate, &apu_clock_multiplier, &resamp_num, &resamp_denom);

 MSU1_StartFrame(master_clock, espec->SoundRate, apu_clock_multiplier, resamp_num, resamp_denom, resamp_clear_buf);

 if(spc_reader)
  CPUM.timestamp = 286364;
 else
 {
  const bool skip_save = espec->skip;
  espec->skip |= snsf_loader != NULL;

  PPU_StartFrame(espec);

#if 0
 for(unsigned msi = 0; msi < 2; msi++)
 {
  for(uint32 A = 0; A < (1U << 24); A++)
  {
   CPUM.timestamp = 0;
   const uint32 pts = CPUM.timestamp;

   CPUM.MemSelectCycles = msi ? MEMCYC_FAST : MEMCYC_SLOW;;
//   CPUM.ReadA(A);
   CPUM.WriteA(A, 0);
   //
   const uint32 td = CPUM.timestamp - pts;
   const uint8 bank = A >> 16;
   const uint16 offs = (uint16)A;
   uint32 reqtd = ~0U;

   if(!(bank & 0x40))
   {
    if(offs < 0x2000)
     reqtd = 8;
    else if(offs < 0x4000)
     reqtd = 6;
    else if(offs < 0x4200)
     reqtd = 12;
    else if(offs < 0x6000)
     reqtd = 6;
    else if(offs < 0x8000)
     reqtd = 8;
    else
     reqtd = ((bank & 0x80) && msi) ? 6 : 8;
   }
   else
    reqtd = ((bank & 0x80) && msi) ? 6 : 8;

   if(td != reqtd)
   {
    fprintf(stderr, "0x%06x td=%d reqtd=%d\n", A, td, reqtd);
    assert(td == reqtd);
   }
  }
 }
 exit(0);
#endif


  CPU_Run();
  uint32 prev = CPUM.timestamp;
  ForceEventUpdates(CPUM.timestamp);
  assert(CPUM.timestamp == prev);

  espec->skip = skip_save;
 }

 espec->MasterCycles = CPUM.timestamp;

 espec->SoundBufSize = APU_EndFrame(espec->SoundBuf);
 MSU1_EndFrame(espec->SoundBuf, espec->SoundBufSize);
 if(!spc_reader)
 {
  PPU_ResetTS();
  RebaseTS(CPUM.timestamp);
 }
 CPUM.timestamp = 0;
}

#ifdef SNES_DBG_ENABLE
static sha1_digest doggy;
#endif

static void Emulate(EmulateSpecStruct* espec)
{
 if(!SpecEx || spc_reader || snsf_loader)
 {
  EmulateReal(espec);
  MDFN_MidSync(espec, MIDSYNC_FLAG_NONE);
  PPU_SyncMT();
 }
 else
 {
  EmulateSpecStruct tmp_espec = *espec;

  if(espec->SoundFormatChanged || espec->NeedSoundReverse)
   SpecExAudioExpected = -1;

  tmp_espec.skip = -1;
  assert(tmp_espec.skip == -1);
  tmp_espec.NeedSoundReverse = false;
  tmp_espec.VideoFormatChanged = false;
  tmp_espec.SoundFormatChanged = false;

  if(!SpecExSS)
   SpecExSS = new MemoryStream(524288);

  EmulateReal(&tmp_espec);

  MDFNSS_SaveSM(SpecExSS, true);
  SpecExSS->rewind();

  if(!espec->SoundBuf)
   EmulateReal(espec);
  else if(!SpecExSoundToo)
  {
   espec->SoundBuf += tmp_espec.SoundBufSize * 2;
   EmulateReal(espec);
   espec->SoundBuf -= tmp_espec.SoundBufSize * 2;
   espec->SoundBufSize = tmp_espec.SoundBufSize;
  }
  else
  {
   const int expected_delta = (SpecExAudioExpected >= 0) ? SpecExAudioExpected - tmp_espec.SoundBufSize : 0;
   const int sbo = (expected_delta < 0) ? -expected_delta : 0;

#ifdef SNES_DBG_ENABLE
   if(!expected_delta && doggy != sha1(tmp_espec.SoundBuf, tmp_espec.SoundBufSize * 2 * sizeof(int16)))
    fprintf(stderr, "Oops\n");

   if(expected_delta)
    fprintf(stderr, "%d\n", expected_delta);
#endif

   memmove(espec->SoundBuf, espec->SoundBuf + (tmp_espec.SoundBufSize - sbo) * 2, sbo * 2 * sizeof(int16));
   espec->SoundBuf += sbo * 2;

   EmulateReal(espec);
#ifdef SNES_DBG_ENABLE
   doggy = sha1(espec->SoundBuf, espec->SoundBufSize * 2 * sizeof(int16));
#endif
   SpecExAudioExpected = espec->SoundBufSize;

   espec->SoundBuf -= sbo * 2;
   espec->SoundBufSize += sbo;

   if(expected_delta > 0 && espec->SoundBufSize >= expected_delta)
   {
    espec->SoundBufSize -= expected_delta;
    memmove(espec->SoundBuf, espec->SoundBuf + expected_delta * 2, espec->SoundBufSize * 2 * sizeof(int16));
   }
  }
  //
  MDFN_MidSync(espec, MIDSYNC_FLAG_NONE);
  PPU_SyncMT();
  //
  MDFNSS_LoadSM(SpecExSS, true);
  SpecExSS->rewind();
 } 

 if(MDFN_UNLIKELY(spc_reader || snsf_loader))
 {
  espec->LineWidths[0] = ~0;
  Player_Draw(espec->surface, &espec->DisplayRect, 0, espec->SoundBuf, espec->SoundBufSize);
 }
}

static MDFN_COLD void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_POWER: Reset(true); break;
  case MDFN_MSC_RESET: Reset(false); break;
 }
}

static void StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 if(spc_reader)
 {
  APU_StateAction(sm, load, data_only);
  return;
 }

 bool MemSelect = (CPUM.MemSelectCycles == MEMCYC_FAST);

 SFORMAT StateRegs[] =
 {
  SFCONDVAR(load && load <= 0x00102399, MemSelect),
  SFVAR(WRAM),

  SFVAR(Multiplicand),
  SFVAR(MultProduct),

  SFVAR(Dividend),
  SFVAR(DivQuotient),
  SFVAR(WMAddress),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SNES");

 if(load && load <= 0x00102399)
  CPUM.MemSelectCycles = (MemSelect ? MEMCYC_FAST : MEMCYC_SLOW);
 //
 //
 CPU_StateAction(sm, load, data_only, "CPU", "CPUCORE");
 DMA_StateAction(sm, load, data_only);
 APU_StateAction(sm, load, data_only);
 PPU_StateAction(sm, load, data_only);
 CART_StateAction(sm, load, data_only);
 MSU1_StateAction(sm, load, data_only);
 INPUT_StateAction(sm, load, data_only);

 if(load)
 {
  ForceEventUpdates(CPUM.timestamp);
 }
}

static void SetInput(unsigned port, const char *type, uint8* data)
{
 if(spc_reader)
  return;

 INPUT_Set(port, type, data);
}

MDFN_COLD uint8* GetNV(uint32* size)
{
 *size = CART_GetRAMSize();

 return CART_GetRAMPointer();
}

uint32 SNES_GetRegister(const unsigned int id, char* special, const uint32 special_len)
{
 uint32 ret = 0xDEADBEEF;

 switch(id)
 {
  case SNES_GSREG_MEMSEL:
	ret = (CPUM.MemSelectCycles == MEMCYC_FAST);
	break;

  case SNES_GSREG_TS:
	ret = CPUM.timestamp;
	break;
 }

 return ret;
}

void SNES_SetRegister(const unsigned int id, uint32 value)
{
 switch(id)
 {
  case SNES_GSREG_MEMSEL:
	CPUM.MemSelectCycles = (value & 0x1) ? MEMCYC_FAST : MEMCYC_SLOW;
	break;
 }
}

uint8 PeekWRAM(uint32 addr)
{
 return WRAM[addr & 0x1FFFF];
}

void PokeWRAM(uint32 addr, uint8 val)
{
 WRAM[addr & 0x1FFFF] = val;
}

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".smc", 0, "Super Magicom ROM Image" },
 { ".swc", 0, "Super Wildcard ROM Image" },
 { ".sfc", 0, "SNES/SFC ROM Image" },
 { ".fig", -10, "SNES/SFC ROM Image" },

 { NULL, 0, NULL }
};

static const MDFNSetting_EnumList HFilter_List[] =
{
 { "none", PPU_HFILTER_NONE, gettext_noop("None") },
 { "512", PPU_HFILTER_512, gettext_noop("Force 512."), gettext_noop("Double width of line if it's 256.") },
 { "phr256blend", PPU_HFILTER_PHR256BLEND, gettext_noop("Pseudo-hires halve-blend."), gettext_noop("Blend line down to 256 pixels if it's pseudo-hires.") },
 { "phr256blend_auto512", PPU_HFILTER_PHR256BLEND_AUTO512, gettext_noop("Pseudo-hires halve-blend and force 512 if necessary."), gettext_noop("Blend line down to 256 pixels if it's pseudo-hires.  After, double width of line if any other lines use hires mode.") },
 { "phr256blend_512", PPU_HFILTER_PHR256BLEND_512, gettext_noop("Pseudo-hires halve-blend and force 512."), gettext_noop("Blend line down to 256 pixels if it's pseudo-hires.  After, double width of line if it's 256.") },
 { "512_blend", PPU_HFILTER_512_BLEND, gettext_noop("Force 512 and blend."), gettext_noop("Double width of line if it's 256.  After, blend line.") },

 { NULL, 0 },
};

static const MDFNSetting_EnumList Region_List[] =
{
 { "auto", REGION_AUTO, gettext_noop("Auto") },

 { "ntsc", REGION_NTSC, gettext_noop("NTSC(North America/Japan)") },
 { "pal", REGION_PAL, gettext_noop("PAL(Europe)") },

 { "ntsc_lie_auto", REGION_NTSC_LIE_AUTO, gettext_noop("NTSC, but PPU bit as if \"auto\".") },
 { "pal_lie_auto", REGION_PAL_LIE_AUTO, gettext_noop("PAL, but PPU bit as if \"auto\".") },

 { "ntsc_lie_pal", REGION_NTSC_LIE_PAL, gettext_noop("NTSC, but PPU bit as if PAL.") },
 { "pal_lie_ntsc", REGION_PAL_LIE_NTSC, gettext_noop("PAL, but PPU bit as if NTSC.") },

 { NULL, 0 }
};

static const MDFNSetting_EnumList CAspect_List[] =
{
 { "0", PPU_CASPECT_DISABLED, gettext_noop("Disabled") },
 { "1", PPU_CASPECT_ENABLED, gettext_noop("Enabled") },

 { "force_ntsc", PPU_CASPECT_FORCE_NTSC, gettext_noop("Enabled, force NTSC PAR.") },
 { "force_pal", PPU_CASPECT_FORCE_PAL, gettext_noop("Enabled, force PAL PAR.") },
 //
 //
 //
 { "disabled", PPU_CASPECT_DISABLED },
 { "enabled", PPU_CASPECT_ENABLED },

 { NULL, 0 }
};

static const MDFNSetting_EnumList Renderer_List[] =
{
 { "st", PPU_RENDERER_ST, gettext_noop("Single-threaded"), gettext_noop("PPU rendering is performed in the main emulation thread.") },
 { "mt", PPU_RENDERER_MT, gettext_noop("Multi-threaded"), gettext_noop("PPU rendering is performed in a dedicated thread.") },

 { NULL, 0 }
};

static const MDFNSetting Settings[] =
{
 { "snes_faust.renderer", MDFNSF_NOFLAGS, gettext_noop("PPU renderer."), gettext_noop("If you have only one CPU with one physical CPU core, select the single-threaded renderer for better performance."), MDFNST_ENUM, "st", NULL, NULL, NULL, NULL, Renderer_List },

 { "snes_faust.affinity.ppu", MDFNSF_NOFLAGS, gettext_noop("PPU rendering thread CPU affinity mask."), gettext_noop("Set to 0 to disable changing affinity."), MDFNST_UINT, "0", "0x0000000000000000", "0xFFFFFFFFFFFFFFFF" },
 { "snes_faust.affinity.msu1.audio", MDFNSF_NOFLAGS, gettext_noop("MSU1 audio read thread CPU affinity mask."), gettext_noop("Set to 0 to disable changing affinity."), MDFNST_UINT, "0", "0x0000000000000000", "0xFFFFFFFFFFFFFFFF" },
 { "snes_faust.affinity.msu1.data", MDFNSF_NOFLAGS, gettext_noop("MSU1 data read thread CPU affinity mask."), gettext_noop("Set to 0 to disable changing affinity."), MDFNST_UINT, "0", "0x0000000000000000", "0xFFFFFFFFFFFFFFFF" },

 { "snes_faust.frame_begin_vblank", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE | MDFNSF_SUPPRESS_DOC | MDFNSF_NONPERSISTENT, gettext_noop("Begin frame in emulated VBlank."), gettext_noop("Disabling will make the multithreaded PPU renderer more effective, but will also increase latency."), MDFNST_BOOL, "1" },

 { "snes_faust.msu1.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("MSU1 sound quality."), gettext_noop("Higher values correspond to better SNR and better preservation of higher frequencies(\"brightness\"), at the cost of increased computational complexity and a negligible increase in latency.\n\nHigher values will also slightly increase the probability of sample clipping(relevant if Mednafen's volume control settings are set too high), due to increased (time-domain) ringing."), MDFNST_INT, "4", "0", "5" },
 { "snes_faust.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("Sound quality."), gettext_noop("Higher values correspond to better SNR and better preservation of higher frequencies(\"brightness\"), at the cost of increased computational complexity and a negligible increase in latency.\n\nHigher values will also slightly increase the probability of sample clipping(relevant if Mednafen's volume control settings are set too high), due to increased (time-domain) ringing."), MDFNST_INT, "3", "0", "5" },
 { "snes_faust.resamp_rate_error", MDFNSF_NOFLAGS, gettext_noop("Sound output rate tolerance."), gettext_noop("Lower values correspond to better matching of the output rate of the resampler to the actual desired output rate, at the expense of increased RAM usage and poorer CPU cache utilization."), MDFNST_FLOAT, "0.000035", "0.0000001", "0.0015" },

 { "snes_faust.spex", MDFNSF_NOFLAGS, gettext_noop("Enable 1-frame speculative execution for video output."), gettext_noop("Hack to reduce input->output video latency by 1 frame.  Enabling will increase CPU usage, and may cause video glitches(such as \"jerkiness\") in some oddball games, but most commercially-released games should be fine."), MDFNST_BOOL, "0" },
 { "snes_faust.spex.sound", MDFNSF_NOFLAGS, gettext_noop("Enable speculative execution for sound output too."), gettext_noop("Only has an effect when speculative-execution for video output is enabled.  Will cause minor sound glitches in some games."), MDFNST_BOOL, "1" },

 { "snes_faust.input.sport1.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap on SNES port 1."), NULL, MDFNST_BOOL, "0" },
 { "snes_faust.input.sport2.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap on SNES port 2."), NULL, MDFNST_BOOL, "0" },

 { "snes_faust.region", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Region of SNES to emulate."), NULL, MDFNST_ENUM, "auto", NULL, NULL, NULL, NULL, Region_List },

 { "snes_faust.correct_aspect", MDFNSF_NOFLAGS, gettext_noop("Correct aspect ratio."), NULL, MDFNST_ENUM, "1", NULL, NULL, NULL, NULL, CAspect_List },

 { "snes_faust.slstart", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in NTSC mode."), NULL, MDFNST_INT, "0", "0", "223" },
 { "snes_faust.slend", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in NTSC mode."), NULL, MDFNST_INT, "223", "0", "223" },

 { "snes_faust.slstartp", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in PAL mode."), NULL, MDFNST_INT, "0", "0", "238" },
 { "snes_faust.slendp", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in PAL mode."), NULL, MDFNST_INT, "238", "0", "238" },

 { "snes_faust.h_filter", MDFNSF_NOFLAGS, gettext_noop("Horizontal blending/doubling filter."), NULL, MDFNST_ENUM, "none", NULL, NULL, NULL, NULL, HFilter_List },

 { "snes_faust.cx4.clock_rate", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("CX4 clock rate, specified in percentage of normal."), gettext_noop("Overclocking the CX4 will cause or worsen attract mode desynchronization."), MDFNST_UINT, "100", "100", "500" },
 { "snes_faust.superfx.clock_rate", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Super FX clock rate, specified in percentage of normal."), gettext_noop("Overclocking the Super FX will cause or worsen attract mode desynchronization."), MDFNST_UINT, "100", "25", "500" },
 { "snes_faust.superfx.icache", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable SuperFX instruction cache emulation."), gettext_noop("Enabling will likely increase CPU usage."), MDFNST_BOOL, "0" },

 { NULL }
};

static const CheatInfoStruct CheatInfo =
{
 CheatInstallReadPatch,
 CheatRemoveReadPatches,

 CheatMemRead,
 CheatMemWrite,

 CheatFormats_SNES,
 false
};

}

using namespace MDFN_IEN_SNES_FAUST;

MDFN_HIDE extern const MDFNGI EmulatedSNES_Faust =
{
 "snes_faust",
 "Super Nintendo Entertainment System/Super Famicom",
 KnownExtensions,
 MODPRIO_INTERNAL_LOW,
 #ifdef SNES_DBG_ENABLE
 &DBG_DBGInfo,
 #else
 NULL,
 #endif
 INPUT_PortInfo,
 NULL,
 Load,
 TestMagic,
 NULL,
 NULL,
 CloseGame,

 NULL,	//ToggleLayer,
 NULL,

 NULL,
 NULL,

 NULL,
 0,

 CheatInfo,

 false,
 StateAction,
 Emulate,
 NULL,
 SetInput,
 NULL,
 DoSimpleCommand,
/*
 Reset,
 GetNV,
*/
 NULL,
 Settings,
 0,
 0,

 EVFSUPPORT_RGB555 | EVFSUPPORT_RGB565,

 true, // Multires possible?

 //
 // Note: Following video settings may be overwritten during game load.
 //
 0,	// lcm_width
 0,	// lcm_height
 NULL,  // Dummy

 292,   // Nominal width
 224,   // Nominal height

 0,	// Framebuffer width
 0,	// Framebuffer height
 //
 //
 //

 2,     // Number of output sound channels
};

