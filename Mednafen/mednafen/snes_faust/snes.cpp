/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#include "snes.h"
#include "input.h"
#include "cart.h"
#include "apu.h"
#include "ppu.h"

#include <mednafen/mednafen.h>
#include <mednafen/mempatcher.h>
#include <mednafen/SNSFLoader.h>
#include <mednafen/player.h>
#include <mednafen/hash/sha1.h>

#include <bitset>

extern MDFNGI EmulatedSNES_Faust;

namespace MDFN_IEN_SNES_FAUST
{
static bool SpecEx, SpecExSoundToo;
static MemoryStream* SpecExSS = NULL;
static int32 SpecExAudioExpected;

static void EventReset(void);


template<bool b_bus>
static void SetHandlers(uint32 A1, uint32 A2, readfunc read_handler, writefunc write_handler)
{
 unsigned index = 0;

 assert(read_handler && write_handler);

 while(index < 256 && CPUM.ReadFuncs[index] && CPUM.WriteFuncs[index] && (CPUM.ReadFuncs[index] != read_handler || CPUM.WriteFuncs[index] != write_handler))
  index++;

 assert(index < 256);

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

bool MemSelect;

template<signed cyc>
static INLINE DEFREAD(OBRead)
{
 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += MemSelect ? MEMCYC_FAST : MEMCYC_SLOW;

 SNES_DBG("[SNES] Unknown Read: $%02x:%04x\n", A >> 16, A & 0xFFFF);
 return CPUM.mdr;
}

template<signed cyc>
static INLINE DEFWRITE(OBWrite)
{
 if(cyc >= 0)
  CPUM.timestamp += cyc;
 else
  CPUM.timestamp += MemSelect ? MEMCYC_FAST : MEMCYC_SLOW;

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
static std::bitset<0x20000> WRAMWritten;	// for debugging

template<uint32 mask>
static DEFREAD(WRAMRead)
{
 CPUM.timestamp += MEMCYC_SLOW;

 if(!WRAMWritten[A & mask])
  SNES_DBG("[SNES] Read from uninitialized WRAM at 0x%08x!\n", A & mask);

 return WRAM[A & mask];
}

template<uint32 mask>
static DEFWRITE(WRAMWrite)
{
 CPUM.timestamp += MEMCYC_SLOW;

 WRAM[A & mask] = V;

 WRAMWritten[A & mask] = true;
}

static uint8 WRIO;

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
  WRIO = 0xFF;
  Multiplicand = 0xFF;
  MultProduct = 0xFFFF;

  Dividend = 0xFFFF;
  DivQuotient = 0xFFFF;
 }

 WMAddress = 0;

 MemSelect = 0;
}

static DEFWRITE(ICRegsWrite)
{
 CPUM.timestamp += MEMCYC_FAST;

 A &= 0xFFFF;

 switch(A & 0xFFFF)
 {
  case 0x4201:	WRIO = V;
		SNES_DBG("[SNES] Write WRIO: %02x\n", V);
		break;

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

  case 0x420D:  MemSelect = V & 1;
		break;
 }
}


static DEFREAD(Read_4214)
{
 CPUM.timestamp += MEMCYC_FAST;

 return DivQuotient >> 0;
}

static DEFREAD(Read_4215)
{
 CPUM.timestamp += MEMCYC_FAST;

 return DivQuotient >> 8;
}

static DEFREAD(Read_4216)
{
 CPUM.timestamp += MEMCYC_FAST;

 return MultProduct >> 0;
}

static DEFREAD(Read_4217)
{
 CPUM.timestamp += MEMCYC_FAST;

 return MultProduct >> 8;
}

//
//
//
static DEFWRITE(Write_2180)
{
 CPUM.timestamp += MEMCYC_FAST;

 WRAMWritten[WMAddress] = true;

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
 uint8 ret;

 CPUM.timestamp += MEMCYC_FAST;

 ret = WRAM[WMAddress];
 WMAddress = (WMAddress + 1) & 0x1FFFF;

 return ret;
}

//
//
//
static SNSFLoader* snsf_loader = NULL;
static SPCReader* spc_reader = NULL;

static void Reset(bool powering_up)
{
 if(powering_up)
 {
  for(unsigned i = 0, p = 0xCAFEBEEF; i < sizeof(WRAM); i++, p = (p << 1) | (((p >> 31) ^ (p >> 21) ^ (p >> 1) ^ p) & 1))
   WRAM[i] = ((p + i * 3) % 192) + 32;

  //memset(WRAM, 0x02, sizeof(WRAM));
  //WRAM[0x1D0FF] = 0x0;	// lufia 2...

  WRAMWritten.reset();
 }

 ICRegsReset(powering_up);
 DMA_Reset(powering_up);
 APU_Reset(powering_up);
 PPU_Reset(powering_up);
 CART_Reset(powering_up);
 INPUT_Reset(powering_up);

 if(spc_reader)
  APU_SetSPC(spc_reader);

 //
 CPU_Reset(powering_up);

 EventReset();
 ForceEventUpdates(0);
}

//
//
//

static bool TestMagic(MDFNFILE *fp)
{
 if(!strcasecmp(fp->ext, "sfc") || !strcasecmp(fp->ext, "smc"))
  return true;

 if(SNSFLoader::TestMagic(fp->stream()))
  return true;

 if(SPCReader::TestMagic(fp->stream()))
  return true;

 return false;
}

static void Cleanup(void)
{
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

 if(spc_reader)
 {
  delete spc_reader;
  spc_reader = NULL;
 }

 APU_Kill();
 PPU_Kill();
 INPUT_Kill();
 CART_Kill();
}

static void Load(MDFNFILE *fp)
{
 SpecEx = MDFN_GetSettingB("snes_faust.spex");
 SpecExSoundToo = MDFN_GetSettingB("snes_faust.spex.sound");
 SpecExAudioExpected = -1;

 CPU_Init();

 memset(CPUM.ReadFuncs, 0, sizeof(CPUM.ReadFuncs));
 memset(CPUM.WriteFuncs, 0, sizeof(CPUM.WriteFuncs));

 memset(CPUM.ReadFuncsA, 0, sizeof(CPUM.ReadFuncsA));
 memset(CPUM.WriteFuncsA, 0, sizeof(CPUM.WriteFuncsA));

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

   Set_A_Handlers((bank << 16) | 0x4201, (bank << 16) | 0x4206, OBRead_FAST, ICRegsWrite);
   Set_A_Handlers((bank << 16) | 0x420D, OBRead_FAST, ICRegsWrite);

   Set_A_Handlers((bank << 16) | 0x4214, Read_4214, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4215, Read_4215, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4216, Read_4216, OBWrite_FAST);
   Set_A_Handlers((bank << 16) | 0x4217, Read_4217, OBWrite_FAST);
  }
 }

 if(SPCReader::TestMagic(fp->stream()))
 {
  spc_reader = new SPCReader(fp->stream());
  Player_Init(1, spc_reader->GameName(), spc_reader->ArtistName(), "", std::vector<std::string>({ spc_reader->SongName() }));
 }
 else
 {
  if(SNSFLoader::TestMagic(fp->stream()))
  {
   snsf_loader = new SNSFLoader(fp->stream());
   Player_Init(1, snsf_loader->tags.GetTag("game"), snsf_loader->tags.GetTag("artist"), snsf_loader->tags.GetTag("copyright"), std::vector<std::string>({ snsf_loader->tags.GetTag("title") }));
  }

  CART_Init(snsf_loader ? &snsf_loader->ROM_Data : fp->stream(), EmulatedSNES_Faust.MD5);
  CART_LoadNV();
 }

 DMA_Init();
 INPUT_Init();
 PPU_Init();
 APU_Init();

 if(spc_reader)
  EmulatedSNES_Faust.fps = (1U << 24) * 75;

 Reset(true);
}

static void CloseGame(void)
{
 if(!snsf_loader)
 {
  try
  {
   CART_SaveNV();
  }
  catch(std::exception &e)
  {
   MDFN_PrintError("%s", e.what());
  }
 }
 Cleanup();
}

struct event_list_entry
{
 uint32 which;
 uint32 event_time;
 event_list_entry *prev;
 event_list_entry *next;
};

static event_list_entry events[SNES_EVENT__COUNT];

static void EventReset(void)
{
 for(unsigned i = 0; i < SNES_EVENT__COUNT; i++)
 {
  events[i].which = i;

  if(i == SNES_EVENT__SYNFIRST)
   events[i].event_time = 0;
  else if(i == SNES_EVENT__SYNLAST)
   events[i].event_time = 0x7FFFFFFF;
  else
   events[i].event_time = SNES_EVENT_MAXTS;

  events[i].prev = (i > 0) ? &events[i - 1] : NULL;
  events[i].next = (i < (SNES_EVENT__COUNT - 1)) ? &events[i + 1] : NULL;
 }
}

//static void RemoveEvent(event_list_entry *e)
//{
// e->prev->next = e->next;
// e->next->prev = e->prev;
//}

static void RebaseTS(const uint32 timestamp)
{
 for(unsigned i = 0; i < SNES_EVENT__COUNT; i++)
 {
  if(i == SNES_EVENT__SYNFIRST || i == SNES_EVENT__SYNLAST)
   continue;

  assert(events[i].event_time > timestamp);
  events[i].event_time -= timestamp;
 }

 CPUM.next_event_ts = events[SNES_EVENT__SYNFIRST].next->event_time;
}

void SNES_SetEventNT(const int type, const uint32 next_timestamp)
{
 assert(type > SNES_EVENT__SYNFIRST && type < SNES_EVENT__SYNLAST);
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

 CPUM.next_event_ts = events[SNES_EVENT__SYNFIRST].next->event_time; // & Running);
}

// Called from debug.cpp too.
void ForceEventUpdates(const uint32 timestamp)
{
 SNES_SetEventNT(SNES_EVENT_PPU, PPU_Update(timestamp));
 SNES_SetEventNT(SNES_EVENT_DMA_DUMMY, DMA_Update(timestamp));

 CPUM.next_event_ts = events[SNES_EVENT__SYNFIRST].next->event_time;
}

void CPU_Misc::EventHandler(void)
{
 event_list_entry *e = events[SNES_EVENT__SYNFIRST].next;

 while(timestamp >= e->event_time)	// If Running = 0, SNES_EventHandler() may be called even if there isn't an event per-se, so while() instead of do { ... } while
 {
  event_list_entry *prev = e->prev;
  uint32 nt;

  switch(e->which)
  {
   default: abort();

   case SNES_EVENT_PPU:
	nt = PPU_Update(e->event_time);
	break;

   case SNES_EVENT_DMA_DUMMY:
	nt = DMA_Update(e->event_time);
	break;

  }
//#if SNES_EVENT_SYSTEM_CHECKS
  assert(nt > e->event_time);
//#endif

  SNES_SetEventNT(e->which, nt);

  // Order of events can change due to calling SNES_SetEventNT(), this prev business ensures we don't miss an event due to reordering.
  e = prev->next;
 }

 //return(Running);
}

static void NO_INLINE EmulateReal(EmulateSpecStruct* espec)
{
 APU_StartFrame(espec->SoundRate);

 if(spc_reader)
  CPUM.timestamp = 286364;
 else
 {
  const bool skip_save = espec->skip;
  espec->skip |= snsf_loader != NULL;

  // Call before PPU_StartFrame(), as PPU_StartFrame() may call INPUT_AutoRead().
  INPUT_UpdatePhysicalState();

  PPU_StartFrame(espec);

  CPU_Run();
  uint32 prev = CPUM.timestamp;
  ForceEventUpdates(CPUM.timestamp);
  assert(CPUM.timestamp == prev);

  espec->skip = skip_save;
 }

 espec->MasterCycles = CPUM.timestamp;

 espec->SoundBufSize = APU_EndFrame(espec->SoundBuf);
 if(!spc_reader)
 {
  PPU_ResetTS();
  RebaseTS(CPUM.timestamp);
 }
 CPUM.timestamp = 0;
}

//static sha1_digest doggy;

static void Emulate(EmulateSpecStruct* espec)
{
 if(!SpecEx || spc_reader || snsf_loader)
  EmulateReal(espec);
 else
 {
  EmulateSpecStruct tmp_espec = *espec;

  if(espec->SoundFormatChanged || espec->NeedSoundReverse)
   SpecExAudioExpected = -1;

  tmp_espec.skip = true;
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

   //if(!expected_delta && doggy != sha1(tmp_espec.SoundBuf, tmp_espec.SoundBufSize * 2 * sizeof(int16)))
   // fprintf(stderr, "Oops\n");

   //if(expected_delta)
   // fprintf(stderr, "%d\n", expected_delta);

   memmove(espec->SoundBuf, espec->SoundBuf + (tmp_espec.SoundBufSize - sbo) * 2, sbo * 2 * sizeof(int16));
   espec->SoundBuf += sbo * 2;

   EmulateReal(espec);
   //doggy = sha1(espec->SoundBuf, espec->SoundBufSize * 2 * sizeof(int16));
   SpecExAudioExpected = espec->SoundBufSize;

   espec->SoundBuf -= sbo * 2;
   espec->SoundBufSize += sbo;

   if(expected_delta > 0 && espec->SoundBufSize >= expected_delta)
   {
    espec->SoundBufSize -= expected_delta;
    memmove(espec->SoundBuf, espec->SoundBuf + expected_delta * 2, espec->SoundBufSize * 2 * sizeof(int16));
   }
  }

  MDFNSS_LoadSM(SpecExSS, true);
  SpecExSS->rewind();
 } 

 if(spc_reader || snsf_loader)
 {
  espec->LineWidths[0] = ~0;
  Player_Draw(espec->surface, &espec->DisplayRect, 0, espec->SoundBuf, espec->SoundBufSize);
 }
}

static void DoSimpleCommand(int cmd)
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

 SFORMAT StateRegs[] =
 {
  SFVAR(MemSelect),
  SFARRAY(WRAM, 0x20000),
  SFVAR(WRIO),

  SFVAR(Multiplicand),
  SFVAR(MultProduct),

  SFVAR(Dividend),
  SFVAR(DivQuotient),
  SFVAR(WMAddress),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SNES");

 CPU_StateAction(sm, load, data_only);
 DMA_StateAction(sm, load, data_only);
 APU_StateAction(sm, load, data_only);
 PPU_StateAction(sm, load, data_only);
 CART_StateAction(sm, load, data_only);
 INPUT_StateAction(sm, load, data_only);


 if(load)
 {
  ForceEventUpdates(CPUM.timestamp);
 }
}

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".smc", "Super Magicom ROM Image" },
 { ".swc", "Super Wildcard ROM Image" },
 { ".sfc", "SNES/SFC ROM Image" },

 { NULL, NULL }
};

static const MDFNSetting Settings[] =
{
 { "snes_faust.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("Sound quality."), gettext_noop("Higher values correspond to better SNR and better preservation of higher frequencies(\"brightness\"), at the cost of increased computational complexity and a negligible increase in latency.\n\nHigher values will also slightly increase the probability of sample clipping(relevant if Mednafen's volume control settings are set too high), due to increased (time-domain) ringing."), MDFNST_INT, "3", "0", "5" },
 { "snes_faust.resamp_rate_error", MDFNSF_NOFLAGS, gettext_noop("Sound output rate tolerance."), gettext_noop("Lower values correspond to better matching of the output rate of the resampler to the actual desired output rate, at the expense of increased RAM usage and poorer CPU cache utilization."), MDFNST_FLOAT, "0.000035", "0.0000001", "0.0015" },

 { "snes_faust.spex", MDFNSF_NOFLAGS, gettext_noop("Enable 1-frame speculative execution for video output."), gettext_noop("Hack to reduce input->output video latency by 1 frame.  Enabling will increase CPU usage, and may cause video glitches(such as \"jerkiness\") in some oddball games, but most commercially-released games should be fine."), MDFNST_BOOL, "0" },
 { "snes_faust.spex.sound", MDFNSF_NOFLAGS, gettext_noop("Enable speculative execution for sound output too."), gettext_noop("Only has an effect when speculative-execution for video output is enabled.  Will cause minor sound glitches in some games."), MDFNST_BOOL, "1" },
 { NULL }
};


}

using namespace MDFN_IEN_SNES_FAUST;

MDFNGI EmulatedSNES_Faust =
{
 "snes_faust",
 "SNES Faust",
 KnownExtensions,
 MODPRIO_INTERNAL_LOW,
 //#ifdef WANT_DEBUGGER
 //&SNES_DBGInfo,
 //#else
 NULL,
 //#endif
 INPUT_PortInfo,
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

 NULL,
 NULL,
 NULL,
 NULL,
 false,
 StateAction,
 Emulate,
 NULL,
 INPUT_Set,
 NULL,
 DoSimpleCommand,
 Settings,
 MDFN_MASTERCLOCK_FIXED(21477272.7),
 0,

 true, // Multires possible?

 //
 // Note: Following video settings may be overwritten during game load.
 //
 512,	// lcm_width
 448,	// lcm_height
 NULL,  // Dummy

 292,   // Nominal width
 224,   // Nominal height

 512,   // Framebuffer width
 480,   // Framebuffer height
 //
 //
 //

 2,     // Number of output sound channels
};

