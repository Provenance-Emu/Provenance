/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* apple2.cpp:
**  Copyright (C) 2018-2023 Mednafen Team
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

//#define MDFN_APPLE2_PARTIALBIOS_HLE 1
/*
 TODO:	Check keyboard and disk II bus conflicts for the case of very small memory configurations where the video
	circuitry would be reading open bus for hires mode?
*/

#include <mednafen/mednafen.h>
#include <mednafen/general.h>
#include <mednafen/FileStream.h>
#include <mednafen/MemoryStream.h>
#include <mednafen/compress/ArchiveReader.h>
#include <mednafen/compress/GZFileStream.h>
#include <mednafen/mempatcher.h>
#include <mednafen/hash/sha256.h>
#include <mednafen/SimpleBitset.h>
#include <mednafen/Time.h>

#include <trio/trio.h>

#include <bitset>
#include <map>
#include <set>

#ifdef MDFN_ENABLE_DEV_BUILD
 #include "../nes/dis6502.h"
#endif

#include "apple2.h"
#include "disk2.h"
#include "hdd.h"
#include "kbio.h"
#include "gameio.h"
#include "video.h"
#include "sound.h"

// Standardized signature byte @ $FBB3(Apple IIe = 06, autostart(II+) = EA)

// Reset active low for about 240ms after power on.

// TODO: Check open bus, 0x0000-0xC00F versus other address

// TODO: 65C02 not reliable if put in Apple II/II+ due to bus timing differences?

// TODO: Check CTRL+RESET style reset, on II vs IIe.

namespace MDFN_IEN_APPLE2
{
#include <mednafen/hw_cpu/6502/Core6502.h>

#ifdef MDFN_ENABLE_DEV_BUILD
static std::bitset<65536 + 0x80 * 65536> RAM_Initialized;
static uint32 Tick1Counter;
static unsigned CPUTick1Called;

bool InHLPeek = false;
bool junkread;
uint32 apple2_dbg_mask;
#endif
//
//
static std::vector<std::unique_ptr<Disk2::FloppyDisk>> Disks;
//
//
//
static readfunc_t ReadFuncs[0x10000];
static writefunc_t WriteFuncs[0x10000];
static readfunc_t SlotROMReadFuncs[0x1000];
static writefunc_t SlotROMWriteFuncs[0x1000];

static uint8 ROM12K[2][0x3000];
static uint8 (&ROM_IIE)[0x4000] = (uint8(&)[0x4000])ROM12K;

A2Globals A2G;

static auto& RAM = A2G.RAM;
static auto& RAMSize = A2G.RAMSize;
static auto& RAMMask = A2G.RAMMask;
static auto& SoftSwitch = A2G.SoftSwitch;
static auto& V7RGBMode = A2G.V7RGBMode;
static auto& EnableFullAuxRAM = A2G.EnableFullAuxRAM;
static auto& RAMPresent = A2G.RAMPresent; 
static auto& FrameDone = A2G.FrameDone;
static auto& FramePartialDone = A2G.FramePartialDone;
//
//
//
static Core6502 CPU;
static bool ResetPending;
static bool Jammed;
static bool EnableLangCard;
static bool EnableDisk2;
static uint8 EnableHDD;
static bool EnableCMOS6502;
static bool EnableROMCard;
static bool EnableIIE;
//
//
static uint8 AuxBank;
static uint32 RAMCPUOffs[2];	// IIe, RamWorks
static writefunc_t AuxBankChainWF;
//
//
// 0 = rom card, 1 = motherboard
static bool ROMSelect;
static bool ROMPresent[2][0x6]; // 2KiB * 6 = 12KiB

static bool LangRAMReadEnable, LangRAMWriteEnable, LangRAMPrevA1, LangBank2Select;

static bool PrevResetHeld;
static bool VideoSettingChanged;


void SetReadHandler(uint16 A, readfunc_t rf)
{
 ReadFuncs[A] = rf;
}

void SetWriteHandler(uint16 A, writefunc_t wf)
{
 WriteFuncs[A] = wf;
}

void SetRWHandlers(uint16 A, readfunc_t rf, writefunc_t wf)
{
 ReadFuncs[A] = rf;
 WriteFuncs[A] = wf;
}

MDFN_WARN_UNUSED_RESULT writefunc_t ChainWriteHandler(uint16 A, writefunc_t wf)
{
 writefunc_t old_wf = WriteFuncs[A];

 assert(wf != nullptr);

 WriteFuncs[A] = wf;

 return old_wf;
}

#ifdef MDFN_ENABLE_DEV_BUILD
static uint8 PeekMem(uint16 A)
{
 const uint8 DB_save = DB;
 uint8 ret;

 InHLPeek = true;
 ReadFuncs[A](A);
 ret = DB;
 DB = DB_save;
 InHLPeek = false;

 return ret;
}

static uint16 PeekMem16(uint16 A)
{
 uint16 ret;

 ret = PeekMem(A);
 A++;
 ret |= PeekMem(A) << 8;

 return ret;
}
#endif

#include "debug.inc"

static DEFREAD(ReadUnhandled)
{
 if(!junkread && !InHLPeek)
  APPLE2_DBG(APPLE2_DBG_UNK_READ, "[UNK] Unhandled read: %04x, PC=0x%04x\n", A, CPU.PC);
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteUnhandled)
{
 APPLE2_DBG(APPLE2_DBG_UNK_WRITE, "[UNK] Unhandled write: %04x %02x, PC=0x%04x\n", A, DB, CPU.PC);
 //
 CPUTick1();
}

template<bool TA_IsWrite>
static INLINE void TrackRAMUninit(uint16 A, size_t offs)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 if(TA_IsWrite)
 {
  RAM_Initialized[offs] = true;
 }
 else if(!junkread && !InHLPeek)
 {
  if(!RAM_Initialized[offs])
   APPLE2_DBG(APPLE2_DBG_UNINITIALIZED_READ, "[UNINIT] Read from uninitialized RAM address 0x%05zx(@=0x%02x).\n", offs, RAM[offs]);

  if(A >= 0x9D00 && A <= 0xBFFF && (CPU.PC < 0x9D00 || CPU.PC >= 0xC000))
   APPLE2_DBG(APPLE2_DBG_DOS, "[DOS] Read from DOS area of RAM at address 0x%04x, PC=0x%04x\n", A, CPU.PC);
 }
#endif
}

static INLINE void LogROMReads(uint16 A)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 uint16 pc = CPU.PC;
 bool pc_in_rom = true;

 if(pc < 0xC000)
  pc_in_rom = false;

 if(EnableLangCard && LangRAMReadEnable && pc >= 0xD000)
  pc_in_rom = false;

 if(!pc_in_rom && !junkread && !InHLPeek)
  APPLE2_DBG(APPLE2_DBG_BIOS, "[BIOS] Read from ROM at 0x%04x, PC=0x%04x\n", A, pc);
#endif
}

static DEFREAD(ReadRAM48K)
{
 TrackRAMUninit<false>(A, A);
 DB = RAM[A];
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteRAM48K)
{
 RAM[A] = DB;
 TrackRAMUninit<true>(A, A);
 //
 CPUTick1();
}

static DEFRW(RWROMCardControl)
{
 if(!InHLPeek)
 {
  ROMSelect = A & 1;
  //
  CPUTick1();
 }
}

static DEFREAD(ReadROM)
{
 if(ROMPresent[ROMSelect][((size_t)A >> 11) - (0xD000 >> 11)])
 {
  DB = ROM12K[ROMSelect][(size_t)A - 0xD000];

  LogROMReads(A);
 }
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFREAD(ReadLangBSArea)
{
 if(LangRAMReadEnable)
  DB = RAM[(size_t)0xC000 + A - 0xD000 + (LangBank2Select << 12)];
 else if(MDFN_LIKELY(ROMPresent[1][((size_t)A >> 11) - (0xD000 >> 11)]))
 {
  DB = ROM12K[1][(size_t)A - 0xD000];

  LogROMReads(A);
 }
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteLangBSArea)
{
 if(LangRAMWriteEnable)
  RAM[(size_t)0xC000 + A - 0xD000 + (LangBank2Select << 12)] = DB;
 //
 CPUTick1();
}

static DEFREAD(ReadLangStaticArea)
{
 if(LangRAMReadEnable)
  DB = RAM[(size_t)0xC000 + A - 0xE000 + 0x2000];
 else if(MDFN_LIKELY(ROMPresent[1][((size_t)A >> 11) - (0xD000 >> 11)]))
 {
  DB = ROM12K[1][(size_t)A - 0xD000];

  LogROMReads(A);
 }
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteLangStaticArea)
{
 if(LangRAMWriteEnable)
  RAM[(size_t)0xC000 + A - 0xE000 + 0x2000] = DB;
 //else
 // printf("BARF %04x %02x\n", A, DB);
 //
 CPUTick1();
}

template<bool isread>
static DEFRW(RWLangCardControl)
{
 //printf("Lang card control: %d %08x\n", isread, A);
 if(!InHLPeek)
 {
  LangBank2Select = !(A & 8);
  LangRAMReadEnable = !((bool)(A & 1) ^ (bool)(A & 2));
  LangRAMWriteEnable = ((LangRAMPrevA1 & isread) | LangRAMWriteEnable) & (bool)(A & 1);
  LangRAMPrevA1 = (bool)(A & 1) & isread;
  //
  CPUTick1();
 }
}

static DEFRW(RWSoftSwitch)
{
 if(!InHLPeek)
 {
  const unsigned w = (A & 0xF) >> 1;

  SoftSwitch &= ~(1U << w);
  SoftSwitch |= (A & 1) << w;
  //
  CPUTick1();
 }
}

//
//
//
static INLINE void RecalcAuxBankOffs(void)
{
 uint8 bank = AuxBank;

 //printf("Woot: %04x %02x\n", A, bank);
 // Good:
 //  0x00 ... 0x17
 //  0x30 ... 0x37
 //  0x50 ... 0x57
 //  0x70 ... 0x77
 // - 0x00, - 0x18, - 0x30, - 0x48
 if(bank >= 0x18)
 {
  if(((bank & 0x08) || !(bank & 0x10)))
   bank = 0xFF;
  else
   bank -= 0x18 * ((bank & 0x60) >> 5);
 }

 RAMCPUOffs[0] = 0;
 RAMCPUOffs[1] = (1 + bank) << 16;
}

// IIe, RamWorks
static DEFWRITE(WriteSelectAuxBank_IIE)
{
 AuxBank = (DB & 0x7F);
 //
 RecalcAuxBankOffs();
 //
 //
 AuxBankChainWF(A);
}

template<bool TA_IsWrite>
static INLINE size_t GetRAMOffs_IIE(uint16 A)
{
 const bool store80 = (bool)(SoftSwitch & SOFTSWITCH_80STORE);
 bool aux;
 size_t ret;

 aux = (bool)(SoftSwitch & (TA_IsWrite ? SOFTSWITCH_RAMWRT : SOFTSWITCH_RAMRD));

 if(A < 0x0200)
  aux = (bool)(SoftSwitch & SOFTSWITCH_ALTZP);

 if(store80 & (((A & 0xFC00) == 0x0400) | (((A & 0xE000) == 0x2000) & (bool)(SoftSwitch & SOFTSWITCH_HIRES_MODE))))
  aux = (bool)(SoftSwitch & SOFTSWITCH_PAGE2);

 ret = (RAMCPUOffs[aux] + A) & RAMMask[aux];

 return ret;
}

static DEFREAD(ReadRAM48K_IIE)
{
 const size_t offs = GetRAMOffs_IIE<false>(A);

 if(MDFN_LIKELY(offs < RAMSize))
 {
  TrackRAMUninit<false>(A, offs);
  DB = RAM[offs];
 }
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteRAM48K_IIE)
{
 const size_t offs = GetRAMOffs_IIE<true>(A);

 if(MDFN_LIKELY(offs < RAMSize))
 {
  RAM[offs] = DB;
  TrackRAMUninit<true>(A, offs);
 }
 //
 CPUTick1();
}

// 0xC100 ... 0xCFFF
static DEFREAD(ReadROMLow_IIE)
{
 const bool c3ra = (!(SoftSwitch & SOFTSWITCH_SLOTC3ROM) && (A & 0xFF00) == 0xC300);
 const bool c8ra = ((SoftSwitch & SOFTSWITCH_INTC8ROM) && (A & 0xF800) == 0xC800);

 SoftSwitch |= c3ra ? SOFTSWITCH_INTC8ROM : 0;
 SoftSwitch &= ((A == 0xCFFF) ? ~SOFTSWITCH_INTC8ROM : (uint32)-1);
 //
 //
 if((SoftSwitch & SOFTSWITCH_INTCXROM) | c3ra | c8ra)
 {
  DB = ROM_IIE[(size_t)A - 0xC000];
  LogROMReads(A);
  //
  if(!InHLPeek)
   CPUTick1();

  return;
 }

 SlotROMReadFuncs[A & 0xFFF](A);
}

static DEFREAD(WriteROMLow_IIE)
{
 const bool c3ra = (!(SoftSwitch & SOFTSWITCH_SLOTC3ROM) && (A & 0xFF00) == 0xC300);

 SoftSwitch |= c3ra ? SOFTSWITCH_INTC8ROM : 0;
 SoftSwitch &= ((A == 0xCFFF) ? ~SOFTSWITCH_INTC8ROM : (uint32)-1);

 SlotROMWriteFuncs[A & 0xFFF](A);
}

static DEFREAD(ReadLangBSArea_IIE)
{
 if(LangRAMReadEnable)
 {
  const bool aux = (bool)(SoftSwitch & SOFTSWITCH_ALTZP);
  const uint32 offs = (RAMCPUOffs[aux] + 0xC000 + (A - 0xD000) + (LangBank2Select << 12)) & RAMMask[aux];

  if(MDFN_LIKELY(offs < RAMSize))
   DB = RAM[offs];
 }
 else
 {
  DB = ROM_IIE[(size_t)A - 0xC000];
  LogROMReads(A);
 }
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteLangBSArea_IIE)
{
 if(LangRAMWriteEnable)
 {
  const bool aux = (bool)(SoftSwitch & SOFTSWITCH_ALTZP);
  const uint32 offs = (RAMCPUOffs[aux] + 0xC000 + (A - 0xD000) + (LangBank2Select << 12)) & RAMMask[aux];

  if(MDFN_LIKELY(offs < RAMSize))
   RAM[offs] = DB;
 }
 //
 CPUTick1();
}

static DEFREAD(ReadLangStaticArea_IIE)
{
 if(LangRAMReadEnable)
 {
  const bool aux = (bool)(SoftSwitch & SOFTSWITCH_ALTZP);
  const uint32 offs = (RAMCPUOffs[aux] + 0xC000 + (A - 0xE000) + 0x2000) & RAMMask[aux];

  if(MDFN_LIKELY(offs < RAMSize))
   DB = RAM[offs];
 }
 else
 {
  DB = ROM_IIE[(size_t)A - 0xC000];
  LogROMReads(A);
 }
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteLangStaticArea_IIE)
{
 if(LangRAMWriteEnable)
 {
  const bool aux = (bool)(SoftSwitch & SOFTSWITCH_ALTZP);
  const uint32 offs = (RAMCPUOffs[aux] + 0xC000 + (A - 0xE000) + 0x2000) & RAMMask[aux];

  if(MDFN_LIKELY(offs < RAMSize))
   RAM[offs] = DB;
 }
 //else
 // printf("BARF %04x %02x\n", A, DB);
 //
 CPUTick1();
}

template<bool isread>
static DEFRW(RWLangCardControl_IIE)
{
 //printf("Lang card control: %d %08x\n", isread, A);
 if(!InHLPeek)
 {
  LangBank2Select = !(A & 8);
  LangRAMReadEnable = !((bool)(A & 1) ^ (bool)(A & 2));
  LangRAMWriteEnable = ((LangRAMPrevA1 & isread) | LangRAMWriteEnable) & (bool)(A & 1);
  LangRAMPrevA1 = (bool)(A & 1) & isread;
  //
  CPUTick1();
 }
}

static DEFRW(RWSoftSwitch_AN3_IIE)
{
 if(!InHLPeek)
 {
  const unsigned w = 0x7;

  if(((SoftSwitch >> 0x7) ^ A) & A & 1)
   V7RGBMode = ((V7RGBMode << 1) | (bool)(~SoftSwitch & SOFTSWITCH_80COL)) & 0x3;

  SoftSwitch &= ~(1U << w);
  SoftSwitch |= (A & 1) << w;
  //
  CPUTick1();
 }
}

static DEFRW(WriteSoftSwitch_IIE)
{
 if(!InHLPeek)
 {
  const unsigned w = 0x8 + ((A & 0xF) >> 1);

  SoftSwitch &= ~(1U << w);
  SoftSwitch |= (A & 1) << w;
  //
  CPUTick1();
 }
}

static DEFREAD(ReadSoftSwitchStatus_IIE)
{
 static const uint32 masks[0x10] =
 {
  0,
  0,
  0,
  SOFTSWITCH_RAMRD,
  SOFTSWITCH_RAMWRT,
  SOFTSWITCH_INTCXROM,
  SOFTSWITCH_ALTZP,
  SOFTSWITCH_SLOTC3ROM,
  SOFTSWITCH_80STORE,
  SOFTSWITCH_VERTBLANK,
  SOFTSWITCH_TEXT_MODE,
  SOFTSWITCH_MIX_MODE,
  SOFTSWITCH_PAGE2,
  SOFTSWITCH_HIRES_MODE,
  SOFTSWITCH_ALTCHARSET,
  SOFTSWITCH_80COL
 };
 const uint32 m = masks[A & 0xF];
 assert(m);

 //printf("Read: 0x%04x 0x%02x, PC=0x%04x\n", A, DB, CPU.PC);
 //
 KBIO::Read_C011_C01F_IIE();
 //
 DB = (DB & 0x7F) | ((bool)(SoftSwitch & m) << 7);
}

// 0xC011 and 0xC012
static DEFREAD(ReadBSRStatus_IIE)
{
 static bool* map[2] = { &LangRAMReadEnable, &LangBank2Select };

 //printf("Read: 0x%04x 0x%02x, PC=0x%04x\n", A, DB, CPU.PC);
 //
 KBIO::Read_C011_C01F_IIE();
 //
 DB = (DB & 0x7F) | (*map[A & 0x1] << 7);
}

static INLINE void CPUTick0(void)
{
 timestamp += 7;
 Video::Tick(); // Note: adds time to timestamp occasionally
 //
 if(EnableDisk2)
  Disk2::Tick2M();	// Call after increasing timestamp
}

void CPUTick1(void)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 assert(!InHLPeek);
#endif
 //
 timestamp += 7;
 //
 if(EnableDisk2)
  Disk2::Tick2M();	// Call after increasing timestamp
#ifdef MDFN_ENABLE_DEV_BUILD
 CPUTick1Called++;
 Tick1Counter++;
#endif
}

INLINE bool Core6502::NeedMidExit(void)
{
 return false;
}

INLINE uint8 Core6502::MemRead(uint16 addr, bool junk)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 CPUTick1Called = 0;
#endif
 CPUTick0();
 //
 //
#ifdef MDFN_ENABLE_DEV_BUILD
 assert(CPUTick1Called == 0);
 junkread = junk;
#endif

 ReadFuncs[addr](addr);

#ifdef MDFN_ENABLE_DEV_BUILD
 if(CPUTick1Called != 1)
 {
  fprintf(stderr, "r %04x", addr);
  assert(0);
 }
#endif

 return DB;
}

INLINE uint8 Core6502::OpRead(uint16 addr, bool junk)
{
 //printf("OpRead: %04x %02x\n", addr, RAM48K[SSIIE.RAMRD][addr]);
 return MemRead(addr, junk);
}

INLINE void Core6502::MemWrite(uint16 addr, uint8 value)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 CPUTick1Called = 0;
#endif
 CPUTick0();
 //
 //
#ifdef MDFN_ENABLE_DEV_BUILD
 assert(CPUTick1Called == 0);
#endif

 DB = value;
 WriteFuncs[addr](addr);

#ifdef MDFN_ENABLE_DEV_BUILD
 if(CPUTick1Called != 1)
 {
  fprintf(stderr, "w %04x", addr);
  assert(0);
 }
#endif
}

INLINE bool Core6502::GetIRQ(void)
{
 return false;
}

INLINE bool Core6502::GetNMI(void)
{
 return false;
}

INLINE void Core6502::BranchTrace(uint16 vector)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 DBG::AddBranchTrace(PC, vector);
#endif
}

static const bool Core6502_EnableDecimalOps = true;
static const bool Core6502_EnableMidExit = false;
#include <mednafen/hw_cpu/6502/Core6502.inc>

#if 0
static void AnalyzeBIOSWaitRoutine(void)
{
 for(unsigned d = 0; d < 2; d++)
 {
  for(unsigned A = 0x00; A < 0x100; A++)
  {
   const uint8 P = Core6502::FLAG_I | (d ? Core6502::FLAG_D : 0);
   CPU.A = A;
   CPU.PC = 0xFCA8;
   CPU.P = P;

   CPU.SP = 0xFE;
   RAM48K[0x1FE] = 0x00;
   RAM48K[0x1FF] = 0x00;

   Tick1Counter = 0;

   while(CPU.PC >= 0xF800)
   {
    CPU.Step();
    //printf("Post: %04x\n", CPU.PC);
   }
   {
    unsigned adj_A = A ? A : 256;

    if(d)
     adj_A = (adj_A & 0xF) + ((adj_A & 0xF0) >> 4) * 10 + ((adj_A & 0xF00) >> 8) * 100;

    const unsigned estimated = (14 + 27 * adj_A + 5 * adj_A * adj_A) / 2 - (A ? 0 : 10);
    printf("A=0x%02x P=0x%02x ---> A=0x%02x P=0x%02x --- time=%u --- estimated_delta=%d\n", A, P, CPU.A, CPU.P, Tick1Counter, estimated - Tick1Counter);
    assert((estimated - Tick1Counter) == 0);
   }
  }
 }
 abort();
}
#endif

#ifdef MDFN_ENABLE_DEV_BUILD
static void LogBIOSCalls(void)
{
 static uint32 prev_PC = ~0U;
 static uint32 prev_t1counter = 0x80000000;

 if(prev_PC != CPU.PC)
 {
  //if(CPU.PC != 0xFCA8 && CPU.PC != 0xFB1E && CPU.PC != 0xFC58 && CPU.PC != 0xFDED && CPU.PC != 0xFDF0 && CPU.PC != 0xFE2C)
  if((!LangRAMReadEnable && prev_PC < 0xD000 && CPU.PC >= 0xD000)) // || (prev_PC < 0xF800 && CPU.PC >= 0xF800))
  {
/*
   static const struct
   {
    uint16 address;
    const char* name;
   } biosnames[] =
   {
    { 0xFCA8, "WAIT" };
   };
*/
   APPLE2_DBG(APPLE2_DBG_BIOS, "[BIOS] ROM call to 0x%04x from 0x%04x; A=0x%02x, X=0x%02x, Y=0x%02x, P=0x%02x\n", CPU.PC, prev_PC, CPU.A, CPU.X, CPU.Y, CPU.P);
   prev_t1counter = Tick1Counter;
  }

  if((!LangRAMReadEnable && CPU.PC < 0xD000 && prev_PC >= 0xD000)) // || (CPU.PC < 0xF800 && prev_PC >= 0xF800))
  {
   APPLE2_DBG(APPLE2_DBG_BIOS, "[BIOS]   ROM return; 0x%04x->0x%04x; A=0x%02x, X=0x%02x, Y=0x%02x, P=0x%02x, time=%5u\n", prev_PC, CPU.PC, CPU.A, CPU.X, CPU.Y, CPU.P, Tick1Counter - prev_t1counter);
   prev_t1counter = 0x80000000;
  }

  //if((prev_PC >= 0x9D00 && prev_PC <= 0xBFFF) && !(CPU.PC >= 0x9D00 && CPU.PC <= 0xBFFF))
  // printf("FromDOS?: 0x%04x->0x%04x; A=0x%02x, X=0x%02x, Y=0x%02x, P=0x%02x --- %c\n", prev_PC, CPU.PC, CPU.A, CPU.X, CPU.Y, CPU.P, CPU.A & 0x7F);
  const bool aux = (bool)(SoftSwitch & SOFTSWITCH_RAMRD);

  if((CPU.PC >= 0x9D00 && CPU.PC <= 0xBFFF) && !(prev_PC >= 0x9D00 && prev_PC <= 0xBFFF))
   APPLE2_DBG(APPLE2_DBG_DOS, "[DOS] Call to 0x%04x from 0x%04x; A=0x%02x, X=0x%02x, Y=0x%02x, P=0x%02x --- %c\n", CPU.PC, prev_PC, CPU.A, CPU.X, CPU.Y, CPU.P, CPU.A & 0x7F);
  else if(CPU.PC == 0x3D6 || CPU.PC == MDFN_de16lsb(&RAM[RAMCPUOffs[aux] + 0x3D7]))
   APPLE2_DBG(APPLE2_DBG_DOS, "[DOS] File manager(0x%04x) from 0x%04x\n", CPU.PC, prev_PC);
  else if(CPU.PC == 0x3D9 || CPU.PC == MDFN_de16lsb(&RAM[RAMCPUOffs[aux] + 0x3DA]))
  {
/*
   const uint16 iob_addr = CPU.Y | (CPU.A << 8);
   assert(iob_addr <= (0xC000 - 1));
   uint8* iob = &RAM48K[iob_addr];
   APPLE2_DBG(APPLE2_DBG_DOS, "[DOS] RWTS from 0x%04x: iob_addr=0x%04x; command=0x%02x, slot=0x%02x, drive=0x%02x, volume=0x%02x, track=0x%02x, sector=0x%02x\n", prev_PC,
	iob_addr,
	iob[0xC],
	iob[0x1],
	iob[0x2],
	iob[0x3],
	iob[0x4],
	iob[0x5]);
*/
  }
  else if(CPU.PC == 0x3DC || CPU.PC == MDFN_de16lsb(&RAM[RAMCPUOffs[aux] + 0x3DD]))
   APPLE2_DBG(APPLE2_DBG_DOS, "[DOS] File manager locate parameter list from 0x%04x\n", prev_PC);
  else switch(CPU.PC)
  {
   case 0x3D4: APPLE2_DBG(APPLE2_DBG_DOS, "[DOS] Hm: %04x\n", prev_PC); break;

   case 0x3E3: APPLE2_DBG(APPLE2_DBG_DOS, "[DOS] RWTS locate IOB from 0x%04x\n", prev_PC); break;
   //
   case 0xC600: APPLE2_DBG(APPLE2_DBG_BIOS, "[D2-BIOS] Disk II; Init; from 0x%04x\n", prev_PC); break;
   case 0xC620: APPLE2_DBG(APPLE2_DBG_BIOS, "[D2-BIOS] Disk II; Init2; from 0x%04x\n", prev_PC); break;
   case 0xC65C: APPLE2_DBG(APPLE2_DBG_BIOS, "[D2-BIOS] Disk II; Read Sector; from 0x%04x\n", prev_PC); break;
   case 0xC683: APPLE2_DBG(APPLE2_DBG_BIOS, "[D2-BIOS] Disk II; Handle Sector Addr; from 0x%04x\n", prev_PC); break;
   case 0xC6A6: APPLE2_DBG(APPLE2_DBG_BIOS, "[D2-BIOS] Disk II; Handle Sector Data; from 0x%04x\n", prev_PC); break;
  }
  //

  if(apple2_dbg_mask & APPLE2_DBG_PRODOS)
  {
   const uint16 PC = CPU.PC;

   if(PC == 0xBF00)
   {
    uint16 ret_addr;

    ret_addr  = PeekMem(0x100 + (uint8)(1 + CPU.SP));
    ret_addr |= PeekMem(0x100 + (uint8)(2 + CPU.SP)) << 8;
    ret_addr++;
    //
    const uint8 code = PeekMem(ret_addr);
    const uint16 paddr = PeekMem16(ret_addr + 1);
    const uint8 param_count = PeekMem(paddr + 0);

    if(code == 0x80 && param_count == 0x3)
    {
     const uint8 unit = PeekMem(paddr + 1);
     const uint16 dbaddr = PeekMem16(paddr + 2);
     const uint16 blknum = PeekMem16(paddr + 4);

     APPLE2_DBG(APPLE2_DBG_PRODOS, "[ProDOS] READ_BLOCK from 0x%04x; unit=0x%02x, dbaddr=0x%04x, blknum=0x%04x\n", prev_PC, unit, dbaddr, blknum);
    }
    else
     APPLE2_DBG(APPLE2_DBG_PRODOS, "[ProDOS] MLI from 0x%04x; code=0x%02x, param_count=%u\n", prev_PC, code, param_count);
   }

   if(EnableHDD && !(SoftSwitch & SOFTSWITCH_INTCXROM))
   {
    const bool prev_in_hddrom = (prev_PC & 0xFF00) == 0xC700;
    const bool cur_in_hddrom = (PC & 0xFF00) == 0xC700;
    if(!prev_in_hddrom && cur_in_hddrom)
    {
     if(PC == (0xC700 | PeekMem(0xC7FF)))
     {
      const uint8 cmd = PeekMem(0x42);
      const uint8 unit = PeekMem(0x43);
      const uint16 iobuf = PeekMem16(0x44);
      const uint16 blknum = PeekMem16(0x46);
     
      APPLE2_DBG(APPLE2_DBG_PRODOS, "[ProDOS] HDD ROM driver entry from 0x%04x; cmd=0x%02x, unit=0x%02x, iobuf=0x%04x, blknum=0x%04x\n", prev_PC, cmd, unit, iobuf, blknum);
     }
     else if(PC == 0xC700)
      APPLE2_DBG(APPLE2_DBG_PRODOS, "[ProDOS] HDD ROM boot entry from 0x%04x\n", prev_PC);
     else if(PC >= (0xC700 | PeekMem(0xC7FF)))
      APPLE2_DBG(APPLE2_DBG_PRODOS, "[ProDOS] Illegal HDD ROM driver entry from 0x%04x to 0x%04x!  A=0x%02x, X=0x%02x, Y=0x%02x\n", prev_PC, PC, CPU.A, CPU.X, CPU.Y);
    }
    else if(prev_in_hddrom && !cur_in_hddrom)
    {
     if(prev_PC >= (0xC700 | PeekMem(0xC7FF)) && PeekMem(prev_PC) == 0x60)
      APPLE2_DBG(APPLE2_DBG_PRODOS, "[ProDOS]   HDD ROM driver return; error=%d, error_code=0x%02x\n", (bool)(CPU.P & Core6502::FLAG_C), CPU.A);
    }
   }
  }
  //
  prev_PC = CPU.PC;
 }
}
#endif

template<bool cmos6502>
MDFN_HOT NO_INLINE void EmulateLoop(bool ResetHeld, bool NeedSoundReverse)
{
 do
 {
  FramePartialDone = false;
  try
  {
   if(ResetPending)
   {
    ROMSelect = 1;

    LangBank2Select = true;
    LangRAMReadEnable = false;
    LangRAMWriteEnable = true;
    LangRAMPrevA1 = false;

    Disk2::Reset();

    if(EnableIIE)
    {
     SoftSwitch &= (SOFTSWITCH_TEXT_MODE | SOFTSWITCH_MIX_MODE | SOFTSWITCH_VERTBLANK);
     //
     AuxBank = 0;
     RecalcAuxBankOffs();
    }
    V7RGBMode = 0x3;
    //
    ResetPending = false;
    Jammed = false;
    CPU.RESETStep<cmos6502>();
   }
   //
   if(MDFN_UNLIKELY(ResetHeld || Jammed))
   {
    while(MDFN_LIKELY(!FramePartialDone))
    {
     CPUTick0();
     CPUTick1();
    }
   }
   else
   {
    while(MDFN_LIKELY(!FramePartialDone))
    {
#ifdef MDFN_ENABLE_DEV_BUILD
     DBG::CPUHandler();

     if(ResetPending || ResetHeld || Jammed)	// Imperfect, FIXME
      break;
     //
     LogBIOSCalls();
#endif

     CPU.Step<cmos6502>();
    }
   }
  }
  catch(int dummy)
  {
   Jammed = true;
  }
 } while(NeedSoundReverse && !FrameDone);
}

static void Emulate(EmulateSpecStruct* espec)
{
 MDFN_Surface* surface = espec->surface;

 if(espec->VideoFormatChanged || VideoSettingChanged)
 {
  Video::Settings s;

  s.hue = MDFN_GetSettingF("apple2.video.hue");
  s.saturation = MDFN_GetSettingF("apple2.video.saturation");
  s.contrast = MDFN_GetSettingF("apple2.video.contrast");
  s.brightness = MDFN_GetSettingF("apple2.video.brightness");
  s.color_smooth = MDFN_GetSettingUI("apple2.video.color_smooth");
  s.force_mono = MDFN_GetSettingUI("apple2.video.force_mono");
  s.mixed_text_mono = MDFN_GetSettingB("apple2.video.mixed_text_mono");
  s.postsharp = MDFN_GetSettingF("apple2.video.postsharp");
  s.mono_lumafilter = MDFN_GetSettingI("apple2.video.mono_lumafilter");
  s.color_lumafilter = MDFN_GetSettingI("apple2.video.color_lumafilter");

  s.mode = MDFN_GetSettingUI("apple2.video.mode");

  s.matrix = MDFN_GetSettingUI("apple2.video.matrix");

  for(unsigned cc_i = 0; cc_i < 3; cc_i++) 
  {
   static const char* cc[3] = { "red", "green", "blue" };
   static const char* axis[2] = { "i", "q" };

   for(unsigned axis_i = 0; axis_i < 2; axis_i++)
   {
    char tmp[64];

    snprintf(tmp, sizeof(tmp), "apple2.video.matrix.%s.%s", cc[cc_i], axis[axis_i]);

    s.custom_matrix[cc_i][axis_i] = MDFN_GetSettingF(tmp);
   }
  }
  //
  //
  //
  Video::SetFormat(surface->format, s, espec->CustomPalette, espec->CustomPaletteNumEntries);
  //
  VideoSettingChanged = false;
 }

 if(espec->SoundFormatChanged)
  Sound::SetParams(espec->SoundRate, 0.00004, 3);
 //
 espec->DisplayRect = Video::StartFrame(espec->surface, espec->LineWidths);
 //
 MDFNMP_ApplyPeriodicCheats();
 //
 //
 FrameDone = false;
 //
 while(!FrameDone)
 {
  Sound::StartTimePeriod();

  uint8 kb_pb;
  const bool ResetHeld = KBIO::UpdateInput(&kb_pb);

  if(!ResetHeld && PrevResetHeld)
   ResetPending = true;
  PrevResetHeld = ResetHeld;

  GameIO::UpdateInput(kb_pb);
  //
  //
  if(EnableCMOS6502)
   EmulateLoop<true>(ResetHeld, espec->NeedSoundReverse);
  else
   EmulateLoop<false>(ResetHeld, espec->NeedSoundReverse);
  //
  //
  KBIO::EndTimePeriod();
  GameIO::EndTimePeriod();
  if(EnableDisk2)
   Disk2::EndTimePeriod();
  espec->SoundBufSize += Sound::EndTimePeriod(espec->SoundBuf + espec->SoundBufSize, espec->SoundBufMaxSize - espec->SoundBufSize, espec->NeedSoundReverse);
  espec->MasterCycles += timestamp;
  timestamp = 0;
  //printf("%d %d %d -- %u\n", FrameDone, espec->SoundBufSize, espec->SoundBufMaxSize, espec->MasterCycles);
  //
  //
  //
  if(!FrameDone)
   MDFN_MidSync(espec);
  //
  //
 }

 espec->NeedSoundReverse = false;
}

#ifdef MDFN_APPLE2_PARTIALBIOS_HLE
static int32 HLEPhase;
static uint32 HLESuckCounter;
static uint32 HLETemp[8];

enum : int { HLEPhaseBias = __COUNTER__ + 1 };

#define HLE_YIELD()     { HLEPhase = __COUNTER__ - HLEPhaseBias + 1; goto Breakout; case __COUNTER__: ; }
#define HLE_SUCK(n)     { for(HLESuckCounter = (n); HLESuckCounter; HLESuckCounter--) { HLE_YIELD(); } }

void Core6502::JamHandler(uint8 opcode)
{
 PC--;
 switch(HLEPhase + HLEPhaseBias)
 {
  for(;;)
  {
   default:
   case __COUNTER__:

   if(PC == 0xFCA8)
   {
    //
    // WAIT
    //
    HLETemp[0] = A ? A : 256;

    if(P & FLAG_D)
     HLETemp[0] = (HLETemp[0] & 0xF) + ((HLETemp[0] & 0xF0) >> 4) * 10 + ((HLETemp[0] & 0xF00) >> 8) * 100;

    HLETemp[0] = ((27 * HLETemp[0] + 5 * HLETemp[0] * HLETemp[0]) >> 1) - (A ? 0 : 10);
    HLE_SUCK(HLETemp[0]);

    A = 0x00;
    P |= FLAG_Z | FLAG_C;
    PC++;
   }
   else if(PC == 0xFB1E)
   {
    //
    // PREAD
    //
    // Minimum CPU cycles:   23 (Y: 0x00)
    // Medium  CPU cycles: 1431 (Y: 0x80)
    // Maximum CPU cycles: 2833 (Y: 0xFF)
    //
    // Inputs:
    //  X: which paddle(0 or 1)
    // Outputs:
    //  A: (undefined; seems to be last value read from 0xC06n though)
    //  Y: paddle position(0x00 through 0xFF)
    //
    Y = 0;
    HLE_SUCK(3)
    MemRead(0xC070);
    for(;;)
    {
     HLE_SUCK(10)
     if(Y == 0xFF)
     {
      HLE_SUCK(6)
      break;
     }
     if((int8)(A = MemRead(0xC064 + X)) >= 0)
      break;
     Y++;
    }
    HLE_SUCK(1)
    CalcZN(A);
    PC++;
   }
   else if(PC == 0xFC58)
   {
    //
    // HOME
    //
    PC++;
   }
   else if(PC == 0xFDED)
   {
    //
    // COUT
    //
   }
   else if(PC == 0xFDF0)
   {
    //
    // COUT1
    //
   }
   else if(PC == 0xFE2C)
   {
    //
    // MOVE
    //
    HLETemp[0]  = MemRead((uint8)(0x3C + Y));
    HLETemp[0] |= MemRead((uint8)(0x3D + Y)) << 8;
    HLETemp[1]  = MemRead((uint8)(0x3E + Y));
    HLETemp[1] |= MemRead((uint8)(0x3F + Y)) << 8;
    HLETemp[2]  = MemRead((uint8)(0x42 + Y));
    HLETemp[2] |= MemRead((uint8)(0x43 + Y)) << 8;
    HLE_YIELD();

    //printf("source=%04x source_end=%04x dest=%04x\n", HLETemp[0], HLETemp[1], HLETemp[2]);

    for(;;)
    {
     MemWrite((uint16)HLETemp[2], MemRead((uint16)HLETemp[0]));

     if(HLETemp[0] == HLETemp[1])
      break;

     HLETemp[0] = (uint16)(HLETemp[0] + 1);
     HLETemp[2] = (uint16)(HLETemp[2] + 1);
     HLE_YIELD();
    }

    MemWrite((uint8)(0x3C + Y), HLETemp[0]);
    MemWrite((uint8)(0x3D + Y), HLETemp[0] >> 8);
    MemWrite((uint8)(0x42 + Y), HLETemp[2]);
    MemWrite((uint8)(0x43 + Y), HLETemp[2] >> 8);
    
    PC++;
   }
   else
   {
    HLE_YIELD();
   }
  }
 }

 Breakout:;
}
#else
void Core6502::JamHandler(uint8 opcode)
{
 PC--;
 if(!Jammed)
 {
#if 0
  printf("JAAAAM: %02x %u\n", opcode, timestamp);
#endif
  throw 0;
 }
}
#endif

static void Power(void)
{
 // Eh, whatever.
 for(unsigned i = 0, j = 1, k = 3; i < RAMSize; i++, j = j * 123456789 + 987654321, k = k * 987654321 + 123456789)
 {
  uint8 v = ((i & 2) ? 0xC6 : 0xBD) ^ (j & (j >> 8) & (j >> 16) & (j >> 24) & k & (k >> 8) & (k >> 16));

  if(EnableIIE)
   v = ((i & 1) || !(i & 0x1FF) || (i & 0x1FF) == 0x40) ? 0xFF : 0x00;

  RAM[i] = v;
 }

#ifdef MDFN_ENABLE_DEV_BUILD
 RAM_Initialized.reset();
#endif

 SoftSwitch = 0;

 ROMSelect = 1;

 LangRAMReadEnable = false;
 LangRAMWriteEnable = true;
 LangRAMPrevA1 = false;
 LangBank2Select = false;

 AuxBank = 0;
 RecalcAuxBankOffs();

 Video::Power();
 Sound::Power();
 KBIO::Power();
 GameIO::Power();
 if(EnableDisk2)
  Disk2::Power();
 if(EnableHDD)
  HDD::Power();

 CPU.Power();
 ResetPending = true;

#ifdef MDFN_APPLE2_PARTIALBIOS_HLE
 HLEPhase = 0;
 HLESuckCounter = 0;
 memset(HLETemp, 0, sizeof(HLETemp));
#endif
}

static bool TestMagic(GameFile* gf)
{
 const uint64 stream_size = gf->stream->size();

 if(gf->ext == "mai")
 {
#if 0
  // FIXME: UTF-8 bom skipping, CR/LF check?
  static const char magic[] = "*MEDNAFEN_SYSTEM_APPLE2*";
  uint8 buf[sizeof(magic) - 1];

  if(gf->stream->read(buf, sizeof(buf), false) == sizeof(buf) && !memcmp(buf, magic, sizeof(buf)))
#endif
   return true;
 }

 if(gf->ext == "afd")
  return true;

 if((gf->ext == "dsk" || gf->ext == "do" || gf->ext == "po") && stream_size == 143360)
  return true;

 if(gf->ext == "d13" && stream_size == 116480)
  return true;

 if(gf->ext == "woz")
  return true;

 if(gf->ext == "hdv")
  return true;

 return false;
}

static void Cleanup(void)
{
 Video::Kill();
 KBIO::Kill();
 GameIO::Kill();
 Sound::Kill();
 if(EnableDisk2)
  Disk2::Kill();
 if(EnableHDD)
  HDD::Kill();

 if(RAM)
 {
  delete[] RAM;
  RAM = nullptr;
 }
 //
 Disks.clear();
}

static void LoadROM_IIE(void)
{
 FileStream biosfp(MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, "apple2e.rom"), FileStream::MODE_READ);

 biosfp.read(ROM_IIE, 0x4000);
}

static void LoadROM_IIE_Enhanced(void)
{
 FileStream biosfp(MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, "apple2e-enh.rom"), FileStream::MODE_READ);

 biosfp.read(ROM_IIE, 0x4000);
}

static void LoadROM_Custom_IIE(VirtualFS* vfs, const std::string& dir_path, const std::string& relpath)
{
 const std::string biospath = vfs->eval_fip(dir_path, relpath);
 std::unique_ptr<Stream> biosfp(vfs->open(biospath, VirtualFS::MODE_READ));

 biosfp->read(ROM_IIE, 0x4000);
}

static void LoadROM_Applesoft(bool w)
{
 FileStream biosfp(MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, "apple2-asoft-auto.rom"), FileStream::MODE_READ);

 biosfp.read(ROM12K[w], 0x3000);
 //
 for(size_t i = 0; i < 6; i++)
  ROMPresent[w][i] = true;
}

static void LoadROM_Integer(bool w)
{
 FileStream biosfp(MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, "apple2-int-auto.rom"), FileStream::MODE_READ);

 memset(ROM12K[w], 0xFF, 0x1000);
 biosfp.read(ROM12K[w] + 0x1000, 0x2000);
 //
 ROMPresent[w][0] = false;
 ROMPresent[w][1] = false;
 for(size_t i = 2; i < 6; i++)
  ROMPresent[w][i] = true;
}

static void LoadROM_Custom(bool w, VirtualFS* vfs, const std::string& dir_path, const std::string& relpath)
{
 const std::string biospath = vfs->eval_fip(dir_path, relpath);
 std::unique_ptr<Stream> biosfp(vfs->open(biospath, VirtualFS::MODE_READ));

 biosfp->read(ROM12K[w], 0x3000);
 //
 for(size_t i = 0; i < 6; i++)
  ROMPresent[w][i] = true;
}

static bool GetBoolean(const std::string& s, const std::string& key)
{
 unsigned ret;

 if(sscanf(s.c_str(), "%u", &ret) != 1 || (ret != 0 && ret != 1))
  throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), key.c_str());

 return ret;
}

static bool GetBoolean(std::map<std::string, std::vector<std::string>>& mai_cfg, const std::string& key)
{
 bool ret;
 auto const& b_cfg = mai_cfg[key];

 if(b_cfg.size() < 2)
  throw MDFN_Error(0, _("Too few arguments for \"%s\" setting in MAI file."), key.c_str());
 else if(b_cfg.size() > 2)
  throw MDFN_Error(0, _("Too many arguments for \"%s\" setting in MAI file."), key.c_str());
 else 
  ret = GetBoolean(b_cfg[1], key);

 return ret;
}

static unsigned GetUnsigned(const std::string& s, const std::string& key)
{
 unsigned ret;

 if(sscanf(s.c_str(), "%u", &ret) != 1)
  throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), key.c_str());

 return ret;
}

static unsigned GetUnsigned(std::map<std::string, std::vector<std::string>>& mai_cfg, const std::string& key)
{
 unsigned ret;

 auto const& b_cfg = mai_cfg[key];

 if(b_cfg.size() < 2)
  throw MDFN_Error(0, _("Too few arguments for \"%s\" setting in MAI file."), key.c_str());
 else if(b_cfg.size() > 2)
  throw MDFN_Error(0, _("Too many arguments for \"%s\" setting in MAI file."), key.c_str());
 else 
  ret = GetUnsigned(b_cfg[1], key);

 return ret;
}

enum
{
 APPLE2_MODEL_II_IIP = 0,
 APPLE2_MODEL_IIE,
 APPLE2_MODEL_IIE_ENH,
 //
 //
 APPLE2_CFG_MODEL_II,
 APPLE2_CFG_MODEL_IIP,
};

static const char* ModelHS[] =
{
 "Apple II/II+",
 "Apple IIe",
 "Enhanced Apple IIe"
};

enum
{
 ROMDB_TYPE_SYSROM = 0,
 ROMDB_TYPE_VIDEO,
 ROMDB_TYPE_KEYBOARD,

 ROMDB_TYPE_DISK2_BOOT,
 ROMDB_TYPE_DISK2_SEQ,
};

struct ROMDB_Entry
{
 uint32 type;
 uint32 size;
 uint32 model;
 const char* part[8];
 const char* part_alt[8];
 const char* desc;
 sha256_digest hash;
};

static const ROMDB_Entry ROMDB[] =
{
 { ROMDB_TYPE_SYSROM, 0x2000, APPLE2_MODEL_II_IIP,
	{ "341-0001", "341-0002", "341-0003", "341-0020" },
	{ nullptr },
	"Integer BASIC and Autostart", "cb52b212a62f808c2f59600b2823491ee12bd91cab8e0260fe34b5f14c47552f"_sha256 },

 { ROMDB_TYPE_SYSROM, 0x3000, APPLE2_MODEL_II_IIP,
	{ "341-0011", "341-0011", "341-0012", "341-0013", "341-0014", "341-0015", "341-0020"},
	{ nullptr },
	"AppleSoft BASIC and Autostart", "fc3e9d41e9428534a883df5aa10eb55b73ea53d2fcbb3ee4f39bed1b07a82905"_sha256},

 { ROMDB_TYPE_SYSROM, 0x4000, APPLE2_MODEL_IIE,
	{ "342-0135-A", "342-0134-A" },
	{ nullptr },
	nullptr, "1fb812584c6633fa16b77b20915986ed1178d1e6fc07a647f7ee8d4e6ab9d40b"_sha256 },

 { ROMDB_TYPE_SYSROM, 0x4000, APPLE2_MODEL_IIE_ENH,
	{ "342-0304-A", "342-0303-A" },
	{ "342-0349-B" },
	nullptr, "aab38a03ca8deabbb2f868733148c2efd6f655a59cd9c5d058ef3e0b7aa86a1a"_sha256 },

 { ROMDB_TYPE_VIDEO, 0x1000, APPLE2_MODEL_IIE,
	{ "342-0133-A" },
	{ nullptr },
	"US", "ed5bdd4afa509134e85f1d020685af7ff50e279226eb869a17825b471cc1634c"_sha256 },

 { ROMDB_TYPE_VIDEO, 0x1000, APPLE2_MODEL_IIE_ENH,
	{ "342-0265-A" },
	{ nullptr },
	"US", "52c3b87900ac939f6525402cab1ccfd8f8259290fc6df54da48fb4c98ae3ed0f"_sha256 },

 { ROMDB_TYPE_KEYBOARD, 0x0800, APPLE2_MODEL_IIE,
	{ "342-0132-B" },
	{ nullptr },
	"US + Dvorak", "68198ae95923926b0307893d03ec286f00822c93a0b6dabfca565f6718dd5a56"_sha256 },

 { ROMDB_TYPE_KEYBOARD, 0x0800, APPLE2_MODEL_IIE,
	{ "342-0132-C" },
	{ nullptr },
	"US + Dvorak (revised IIe)", "fbb9620e01f4f728e5a8ba86544900978d7803f6a7d577d384e288dfed9a4907"_sha256 },

 { ROMDB_TYPE_KEYBOARD, 0x0800, APPLE2_MODEL_IIE_ENH,
	{ "341-0132-D" },
	{ nullptr },
	"US + Dvorak", "a1989da84ea4381d309e7e08783771f884e913236b9bcc71c3d649aacf76537a"_sha256 },
 //
 //
 //
 { ROMDB_TYPE_DISK2_BOOT, 0x0100, (uint32)-1,
	{ "341-0009" },
	{ nullptr },
	"13-sector", "2d2599521fc5763d4e8c308c2ee7c5c4d5c93785b8fb9a4f7d0381dfd5eb60b6"_sha256 },

 { ROMDB_TYPE_DISK2_SEQ, 0x0100, (uint32)-1,
	{ "341-0010" },
	{ nullptr },
	"13-sector", "4234aed053c622b266014c4e06ab1ce9e0e085d94a28512aa4030462be0a3cb9"_sha256 },

 { ROMDB_TYPE_DISK2_BOOT, 0x0100, (uint32)-1,
	{ "341-0027" },
	{ nullptr },
	"16-sector", "de1e3e035878bab43d0af8fe38f5839c527e9548647036598ee6fe7ec74d2a7d"_sha256 },

 { ROMDB_TYPE_DISK2_SEQ, 0x0100, (uint32)-1,
	{ "341-0028" },
	{ nullptr },
	"16-sector", "e5e30615040567c1e7a2d21599681f8dac820edbdcda177b816a64d74b3a12f2"_sha256 },
};

static const ROMDB_Entry* LookupROM(const sha256_digest& hash)
{
 for(auto const& dbe : ROMDB)
 {
  if(dbe.hash == hash)
   return &dbe;
 }

 return nullptr;
}

static std::string GetROMHS(const sha256_digest& hash)
{
 std::string ret = _("Unknown");
 const ROMDB_Entry* rdbe = LookupROM(hash);

 if(rdbe)
 {
  std::string part_hs;

  for(auto const& s : rdbe->part)
  {
   if(s)
   {
    if(part_hs.size())
     part_hs += " + ";
    part_hs += s;
   }
  }

  ret = "";

  if(rdbe->model != (uint32)-1)
   ret += std::string(ModelHS[rdbe->model]) + "; ";
 
  if(rdbe->desc)
   ret += part_hs + " (" + (rdbe->desc ? rdbe->desc : "") + ")";
  else
   ret += part_hs + " " + (rdbe->desc ? rdbe->desc : "");
 }

 return ret;
}


static void Load(GameFile* gf)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 apple2_dbg_mask = MDFN_GetSettingMultiM("apple2.dbg_mask") | APPLE2_DBG_ERROR;
#endif

 /*
  When loading a MAI file, always override input settings(input device type, and switch default positions) from the Mednafen config
  file with settings in the MAI file, or defined defaults for MAI.

  When loading a bare disk image, do NOT override the Mednafen config file input settings.
 */

 try
 {
  const bool mai_load = (gf->ext == "mai");
  sha256_hasher gameid_hasher;
  bool auto_ram48k = false;

  for(size_t i = 0; i < 6; i++)
  {
   ROMPresent[0][i] = ROMPresent[1][i] = false;
  }

  #define MAICFGE(a, ...) { mai_cfg[a] = { a, __VA_ARGS__ }; }

  #define MAIDEFAULT(a, ...)			\
  {						\
   if(mai_cfg.find(a) == mai_cfg.end())		\
    mai_cfg[a] = { a, __VA_ARGS__ };		\
  }
  std::map<std::string, std::vector<std::string>> mai_cfg;

  MAICFGE("model", "ii+")
  MAICFGE("gameio", "joystick", "2")
  MAICFGE("gameio.resistance", "93551", "125615", "149425", "164980")
  MAICFGE("disk2.enable", "1")
  MAICFGE("disk2.drive1.enable", "1")
  MAICFGE("disk2.drive2.enable", "1")
  MAICFGE("disk2.firmware", "16sec")
  //
  //
  if(mai_load)
  {
   Stream* s = gf->stream;
   std::string linebuf;

   linebuf.reserve(512);

   s->read_utf8_bom();

   if(s->get_line(linebuf) < 0)
    throw MDFN_Error(0, _("Missing signature line in MAI file."));

   MDFN_rtrim(&linebuf);

   if(linebuf != "MEDNAFEN_SYSTEM_APPLE2")
    throw MDFN_Error(0, _("Wrong signature line in MAI file for Apple II/II+."));

   while(s->get_line(linebuf) >= 0)
   {
    MDFN_trim(&linebuf);
    if(linebuf.size() && linebuf[0] != '#')
    {
     std::vector<std::string> vt = MDFN_strargssplit(linebuf);

     //printf("*****\n");
     //for(size_t i = 0; i < vt.size(); i++)
     // printf("%s\n", vt[i].c_str());

     if(vt.size() > 0)
      mai_cfg[vt[0]] = vt;
    }
   }
  }
  else
  {
   if(gf->ext == "hdv")
   {
    MAICFGE("disk2.enable", "0");
    //
    MAICFGE("hdd", "7", "\"\"", "0");
   }
   else
   {
    const bool multiload = MDFN_GetSettingB("apple2.multiload");
    ArchiveReader* ar = dynamic_cast<ArchiveReader*>(gf->vfs);
    unsigned disk_count = 0;

    if(!multiload || !ar)
    {
     MAICFGE("disk2.disks.0", gf->fbase, "")
     MAICFGE("disk2.drive1.disks", "*0")
     MAICFGE("disk2.drive2.disks", "0")

     disk_count++;
    }
    else
    {
     const std::string dext = std::string(".") + gf->ext;
     std::list<std::pair<std::string, std::string>> l;

     mai_cfg["disk2.drive1.disks"] = { "disk2.drive1.disks" };
     mai_cfg["disk2.drive2.disks"] = { "disk2.drive2.disks" };

     gf->vfs->readdirentries(gf->dir,
         [&](const std::string& fname)
         {
	  if(gf->vfs->test_ext(fname, dext.c_str()))
	  {
	   std::string disk_label;

	   gf->vfs->get_file_path_components(fname, nullptr, &disk_label, nullptr);

	   l.emplace_back(disk_label, fname);
	  }

	  return true;
	 });

     assert(l.size() && l.front().second == gf->orig_fname);

     if(l.size())
     {
      size_t min_match = SIZE_MAX;

      for(auto const& le : l)
       min_match = std::min<size_t>(min_match, MDFN_strmismatch(le.first, l.front().first));

      if(min_match != SIZE_MAX)
      {
       for(; min_match != 0; min_match--)
       {
        const char c = l.front().first[min_match - 1];

        if(MDFN_isspace(c) || (!(c & 0x80) && !MDFN_isaznum(c)))
         break;
       }
      }

      if(min_match != SIZE_MAX)
      {
       std::set<std::string> dls;
       bool ok = true;

       for(auto& le : l)
       {
        //if(min_match > 3)
        // le.first = std::string("...") + MDFN_trim(le.first.substr(min_match));
        le.first = MDFN_trim(le.first.substr(min_match));
        //
        if(!le.first.size() || dls.find(le.first) != dls.end())
        {
         ok = false;
         break;
        }
        dls.emplace(le.first);
       }

       if(!ok)
       {
        for(auto& le : l)
	 gf->vfs->get_file_path_components(le.second, nullptr, &le.first, nullptr);
       }
      }

      for(auto const& le : l)
      {
       char sntmp[32];
       std::string sname;
       const std::string& disk_label = le.first;
       const std::string& fname = le.second;

       MDFN_sndec_u64(sntmp, sizeof(sntmp), disk_count);
       sname = std::string("disk2.disks.") + sntmp;

       //printf("%s\n", MDFN_strhumesc(fname).c_str());
       MAICFGE(sname, disk_label, ((gf->orig_fname == fname) ? "" : fname))
       //
       mai_cfg["disk2.drive1.disks"].emplace_back(std::string((gf->orig_fname == fname) ? "*" : "") + sntmp);
       mai_cfg["disk2.drive2.disks"].emplace_back(sntmp);
       //
       disk_count++;
      }
     }
    }
   }

   switch(MDFN_GetSettingUI("apple2.model"))
   {
    default:
	assert(0);
	break;

    case APPLE2_CFG_MODEL_II:
	MAICFGE("model", "ii")
	break;

    case APPLE2_CFG_MODEL_IIP:
	MAICFGE("model", "ii+")
	break;

    case APPLE2_MODEL_II_IIP:
	MAICFGE("model", "ii_ii+")
	break;

    case APPLE2_MODEL_IIE:
	MAICFGE("model", "iie")
	break;

    case APPLE2_MODEL_IIE_ENH:
	MAICFGE("model", "iie_enh")
	break;
   }
  }
  //
  //
  //

/*
 Model(II+,IIe,IIc)
 Keyboard(standard for model, or custom?)
 Joystick or paddles
 Language card presence for II+?
 Base RAM for II+
 64K 80 column RAM for IIe
 Disk drives, 1 or 2, and disks available, disks which start inserted
 Tapes available
 Mouse?
 Modem?
 Sound cards(Mockingboard)?
*/
  //
  //
  //
  for(unsigned A = 0; A < 0x10000; A++)
  {
   SetRWHandlers(A, ReadUnhandled, WriteUnhandled);
  }
  //
  //
  //

  MDFNGameInfo->DesiredInput.clear();
  MDFNGameInfo->DesiredInput.resize(3);

  if(mai_load)
  {
   MDFNGameInfo->DesiredInput[0].device_name = "none";
   MDFNGameInfo->DesiredInput[1].device_name = "paddle";
  }
  else
  {
   MDFNGameInfo->DesiredInput[0].device_name = nullptr;
   MDFNGameInfo->DesiredInput[1].device_name = nullptr;
  }

  //
  // Model
  //
  unsigned model;
  {
   auto const& model_cfg = mai_cfg["model"];

   if(model_cfg.size() < 2)
    throw MDFN_Error(0, _("Too few arguments for \"%s\" setting in MAI file."), "model");
   else if(model_cfg.size() > 2)
    throw MDFN_Error(0, _("Too many arguments for \"%s\" setting in MAI file."), "model");
   else
   {
    std::string model_s = model_cfg[1];

    MDFN_strazlower(&model_s);

    if(model_s == "ii")
    {
     model = APPLE2_MODEL_II_IIP;

     MAIDEFAULT("ram", "48")
     MAIDEFAULT("firmware", "integer")
     MAIDEFAULT("romcard", "applesoft")
    }
    else if(model_s == "ii+" || model_s == "ii_ii+")
    {
     model = APPLE2_MODEL_II_IIP;
     auto_ram48k = (model_s == "ii_ii+");

     MAIDEFAULT("ram", "64")
     MAIDEFAULT("firmware", "applesoft")
     MAIDEFAULT("romcard", "integer")
    }
    else if(model_s == "iie")
    {
     model = APPLE2_MODEL_IIE;

     MAIDEFAULT("ram", "128")
    }
    else if(model_s == "iie_enh")
    {
     model = APPLE2_MODEL_IIE_ENH;

     MAIDEFAULT("ram", "128")
    }
    else
     throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), "model");
   }
  }
  //
  EnableIIE = (model == APPLE2_MODEL_IIE || model == APPLE2_MODEL_IIE_ENH);
  EnableCMOS6502 = (model == APPLE2_MODEL_IIE_ENH);

  if(EnableIIE)
   MDFNGameInfo->DesiredInput[2].device_name = "iie";
  else
   MDFNGameInfo->DesiredInput[2].device_name = "iip";

  sha256_digest dig_disk2_seq_rom, dig_disk2_boot_rom, dig_video_rom, dig_kb_rom;
  uint32 hdd_size = 0;

  //
  // Disk II
  //
  EnableDisk2 = GetBoolean(mai_cfg, "disk2.enable");

  gameid_hasher.process_scalar<uint8>(EnableDisk2);

  if(EnableDisk2)
  {
   int drive_diskidx_defaults[2] = { -1, -1 };	// Default disk to have inserted at startup; -1 for ejected.

   Disk2::Init();

   // 0 = Drive 1 only
   // 1 = Drive 2 only
   // 2 = Either drive
   MDFNGameInfo->RMD->MediaTypes.push_back(RMD_MediaType({_("5.25\" Floppy Disk/Side (Drive 1)")}));
   MDFNGameInfo->RMD->MediaTypes.push_back(RMD_MediaType({_("5.25\" Floppy Disk/Side (Drive 2)")}));
   MDFNGameInfo->RMD->MediaTypes.push_back(RMD_MediaType({_("5.25\" Floppy Disk/Side (Drive 1 or 2)")}));

   std::map<std::string, size_t> disk_already_loaded;

   for(unsigned drive = 0; drive < 2; drive++)
   {
    const std::string prefix = drive ? "disk2.drive2." : "disk2.drive1.";
    const bool disk2_drive_enable = GetBoolean(mai_cfg, prefix + "enable");

    gameid_hasher.process_scalar<uint8>(disk2_drive_enable);

    if(disk2_drive_enable)
    {
     auto const& dd_cfg = mai_cfg[prefix + "disks"];

     for(size_t ddi = 1; ddi < dd_cfg.size(); ddi++)
     {
      bool default_inserted = false;  
      const char* ds = dd_cfg[ddi].c_str();

      if(ds[0] == '*')
      {
       default_inserted = true;
       ds++;
      }
      //
      //
      //
      auto dal_sit = disk_already_loaded.find(ds);

      if(dal_sit != disk_already_loaded.end())
      {
       MDFNGameInfo->RMD->Media[dal_sit->second].MediaType = 2;

       if(default_inserted)
        drive_diskidx_defaults[drive] = dal_sit->second;
      }
      else
      {
       auto const& disk_cfg = mai_cfg[std::string("disk2.disks.") + ds];

       if(disk_cfg.size() < 1)
        throw MDFN_Error(0, _("Disk \"%s\" not defined."), MDFN_strhumesc(ds).c_str());
       else if(disk_cfg.size() < 3)
        throw MDFN_Error(0, _("Disk \"%s\" definition is incomplete."), MDFN_strhumesc(ds).c_str());
       //
       const std::string disk_label = disk_cfg[1];
       const std::string disk_relpath = disk_cfg[2];
       int write_protect = (disk_cfg.size() >= 4) ? GetBoolean(disk_cfg[3], disk_cfg[0]) : -1;

       Disks.emplace_back(new Disk2::FloppyDisk());
       //
       Disk2::FloppyDisk* disk = Disks.back().get();

       if(!mai_load && disk_relpath == "")
       {
	//MDFN_printf("Loading from primary stream...\n");
	//MDFN_AutoIndent aind(1);
        Disk2::LoadDisk(gf->stream, gf->ext, disk);
       }
       else
       {
        std::string disk_path = gf->vfs->eval_fip(gf->dir, disk_relpath);
        std::string ext;
	//
	MDFN_printf("Loading %s...\n", gf->vfs->get_human_path(disk_path).c_str());
	MDFN_AutoIndent aind(1);
	//
	std::unique_ptr<Stream> diskfp(gf->vfs->open(disk_path, VirtualFS::MODE_READ));

        gf->vfs->get_file_path_components(disk_path, nullptr, nullptr, &ext);

        if(ext.size() > 1)
         ext = ext.substr(1);

        MDFN_strazlower(&ext);

        Disk2::LoadDisk(diskfp.get(), ext, disk);
       }

       if(!mai_load && disk == Disks[0].get())
       {
        if(Disk2::DetectDOS32(disk))
        {
         if(auto_ram48k)
         {
          MAICFGE("ram", "48")
         }
         MAICFGE("disk2.firmware", "13sec")
        }
       }
       //
       Disk2::HashDisk(&gameid_hasher, disk);
       //
       if(write_protect >= 0)
        disk->write_protect = write_protect;

       MDFNGameInfo->RMD->Media.push_back(RMD_Media({MDFN_strhumesc(disk_label), drive}));
       disk_already_loaded[ds] = MDFNGameInfo->RMD->Media.size() - 1;

       if(default_inserted)
        drive_diskidx_defaults[drive] = MDFNGameInfo->RMD->Media.size() - 1;
      }
     }
    }
   }

   if(drive_diskidx_defaults[0] == drive_diskidx_defaults[1] && drive_diskidx_defaults[0] != -1)
    throw MDFN_Error(0, _("Spacetime wizard chuckles at the attempt to have the same disk inserted by default into both drives at the same time."));

   for(unsigned drive = 0; drive < 2; drive++)
   {
    RMD_Drive dr;

    dr.Name = drive ? "Drive 2" : "Drive 1";
    dr.PossibleStates.push_back(RMD_State({_("Disk Ejected"), false, false, true}));
    dr.PossibleStates.push_back(RMD_State({_("Disk Inserted"), true, true, false}));

    dr.CompatibleMedia.push_back(drive);
    dr.CompatibleMedia.push_back(2);
    dr.MediaMtoPDelay = 2000;

    MDFNGameInfo->RMD->Drives.push_back(dr);

    if(drive_diskidx_defaults[drive] < 0)
     MDFNGameInfo->RMD->DrivesDefaults.push_back(RMD_DriveDefaults({0, 0, 0}));
    else
     MDFNGameInfo->RMD->DrivesDefaults.push_back(RMD_DriveDefaults({1, (uint32)drive_diskidx_defaults[drive], 0}));
   }

   //
   // Disk II Firmware (handle after loading disks)
   //
   {
    auto const& d2fwov_cfg = mai_cfg["disk2.firmware.override"];

    if(d2fwov_cfg.size() > 1)
    {
     if(d2fwov_cfg.size() < 3)
      throw MDFN_Error(0, _("Too few arguments for \"%s\" setting in MAI file."), "disk2.firmware.override");
     else
     {
      for(unsigned i = 0; i < 2; i++)
      {
       uint8 buf[256];
       const std::string relpath = d2fwov_cfg[1 + i];
       const std::string d2fwpath = gf->vfs->eval_fip(gf->dir, relpath);
       std::unique_ptr<Stream> d2fp(gf->vfs->open(d2fwpath, VirtualFS::MODE_READ));

       d2fp->read(buf, 256);

       if(i)
       {
        Disk2::SetSeqROM(buf);
        dig_disk2_seq_rom = sha256(buf, sizeof(buf));
       }
       else
       {
        Disk2::SetBootROM(buf);
        dig_disk2_boot_rom = sha256(buf, sizeof(buf));
       }

       gameid_hasher.process(buf, 256);
      }
     }
    }
    else
    {
     auto const& disk2fw_cfg = mai_cfg["disk2.firmware"];

     if(disk2fw_cfg.size() < 2)
      throw MDFN_Error(0, _("Too few arguments for \"%s\" setting in MAI file."), "disk2.enable");
     else if(disk2fw_cfg.size() > 2)
      throw MDFN_Error(0, _("Too many arguments for \"%s\" setting in MAI file."), "disk2.enable");
     else
     {
      std::string disk2fw_type = disk2fw_cfg[1];
      bool Need16SecDisk2;

      if(disk2fw_type == "13sec")
       Need16SecDisk2 = false;
      else if(disk2fw_type == "16sec")
       Need16SecDisk2 = true;
      else
       throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), "disk2.firmware");

      static const struct
      {
       const char* purpose;
       const char* fname;
       sha256_digest hash;
      }  disk2_firmware[2][2] =
      {
       /* 13-sector, DOS < 3.3 */
       {
        { "Disk II Interface 13-Sector P5 Boot ROM, 341-0009", "disk2-13boot.rom", "2d2599521fc5763d4e8c308c2ee7c5c4d5c93785b8fb9a4f7d0381dfd5eb60b6"_sha256 },
        { "Disk II Interface 13-Sector P6 Sequencer ROM, 341-0010", "disk2-13seq.rom", "4234aed053c622b266014c4e06ab1ce9e0e085d94a28512aa4030462be0a3cb9"_sha256 },
       },

       /* 16-sector, DOS >= 3.3 */
       {
        { "Disk II Interface 16-Sector P5 Boot ROM, 341-0027", "disk2-16boot.rom", "de1e3e035878bab43d0af8fe38f5839c527e9548647036598ee6fe7ec74d2a7d"_sha256 },
        { "Disk II Interface 16-Sector P6 Sequencer ROM, 341-0028", "disk2-16seq.rom", "e5e30615040567c1e7a2d21599681f8dac820edbdcda177b816a64d74b3a12f2"_sha256 },
       }
      };

      for(unsigned i = 0; i < 2; i++)
      {
       const auto& fwinf = disk2_firmware[Need16SecDisk2][i];
       const std::string path = MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, fwinf.fname);
       FileStream rfp(path, FileStream::MODE_READ);
       uint8 buf[256];
       sha256_digest calced_hash;

       rfp.read(buf, sizeof(buf));

       calced_hash = sha256(buf, 256);

       if(fwinf.hash != calced_hash)
        throw MDFN_Error(0, _("Firmware data for \"%s\" in file \"%s\" is corrupt or otherwise wrong."), fwinf.purpose, MDFN_strhumesc(path).c_str());

       if(i)
       {
        Disk2::SetSeqROM(buf);
        dig_disk2_seq_rom = calced_hash;
       }
       else
       {
        Disk2::SetBootROM(buf);
        dig_disk2_boot_rom = calced_hash;
       }

       gameid_hasher.process(buf, 256);
      }
     }
    }
   }
  }
  #undef MAICFGE
  #undef MAIDEFAULT
  //
  // HDD
  //
  EnableHDD = false;

  if(mai_cfg["hdd"].size() > 0)
  {
   auto const& hdd_cfg = mai_cfg["hdd"];

   if(hdd_cfg.size() < 4)
    throw MDFN_Error(0, _("Too few arguments for \"%s\" setting in MAI file."), "hdd");
   else if(hdd_cfg.size() > 4)
    throw MDFN_Error(0, _("Too many arguments for \"%s\" setting in MAI file."), "hdd");
   else
   {
    const unsigned slot = GetUnsigned(hdd_cfg[1], hdd_cfg[0]);
    const std::string image_relpath = hdd_cfg[2];
    const bool write_protect = GetBoolean(hdd_cfg[3], hdd_cfg[0]);

    if(slot != 1 && slot != 7)
     throw MDFN_Error(0, _("Specified slot for HDD must be 1 or 7."));
    //
    //
    assert(slot);
    EnableHDD = slot;
    gameid_hasher.process_scalar<uint8>(slot);
    //
    if(!mai_load)
     hdd_size = HDD::Init(slot, gf->stream, gf->ext, &gameid_hasher, write_protect);
    else
    {
     std::string image_path = gf->vfs->eval_fip(gf->dir, image_relpath);
     //
     MDFN_printf("Loading %s...\n", gf->vfs->get_human_path(image_path).c_str());
     MDFN_AutoIndent aind(1);
     //
     std::unique_ptr<Stream> imagefp(gf->vfs->open(image_path, VirtualFS::MODE_READ));
     std::string ext;

     gf->vfs->get_file_path_components(image_path, nullptr, nullptr, &ext);
     if(ext.size() > 1)
      ext = ext.substr(1);

     MDFN_strazlower(&ext);

     hdd_size = HDD::Init(slot, imagefp.get(), ext, &gameid_hasher, write_protect);
    }
   }
  }
  //
  // RAM
  //
  {
   unsigned NeedRAMAmount = GetUnsigned(mai_cfg, "ram");

   if(EnableIIE)
   {
    if(NeedRAMAmount != 64 && NeedRAMAmount != 65 && NeedRAMAmount != 128 && NeedRAMAmount != 320 && NeedRAMAmount != 576 && NeedRAMAmount != 1088 && NeedRAMAmount != 3136)
     throw MDFN_Error(0, _("Specified RAM size must be 64KiB, 65KiB, 128KiB, 320KiB, 576KiB, 1088KiB, or 3136KiB with Apple IIe emulation."));
   }
   else
   {
    if(NeedRAMAmount & 3)
     throw MDFN_Error(0, _("Specified RAM size is not a multiple of 4."));
    else if(NeedRAMAmount < 4)
     throw MDFN_Error(0, _("Specified RAM size is too small."));
    else if(NeedRAMAmount > 48 && NeedRAMAmount < 64)
     throw MDFN_Error(0, _("Specified RAM size between 48KiB and 64KiB is unsupported."));
    else if(NeedRAMAmount > 64)
     throw MDFN_Error(0, _("Specified RAM size is too large."));
   }

   gameid_hasher.process_scalar<uint32>(NeedRAMAmount);

   RAMSize = NeedRAMAmount * 1024;
   RAM = new uint8[std::max<uint32>(0x20000, RAMSize)];

   for(unsigned i = 0; i < 0xC; i++)
    RAMPresent[i] = (i * 4) < NeedRAMAmount;

   EnableLangCard = (NeedRAMAmount >= 64);
   EnableFullAuxRAM = (NeedRAMAmount >= 128);

   RAMMask[0] = 0xFFFF;
   RAMMask[1] = (NeedRAMAmount == 65) ? 0x103FF : (uint32)-1;
   //
   //
   //
   MDFNMP_Init(1024, (RAMSize + 1023) / 1024);
   MDFNMP_RegSearchable(0x0000, RAMSize);
  }

  //
  // Firmware
  //
  {
   auto const& fwov_cfg = mai_cfg["firmware.override"];

   if(fwov_cfg.size() > 1)
   {
    if(EnableIIE)
     LoadROM_Custom_IIE(gf->vfs, gf->dir, fwov_cfg[1]);
    else
     LoadROM_Custom(1, gf->vfs, gf->dir, fwov_cfg[1]);
   }
   else if(model == APPLE2_MODEL_IIE_ENH)
     LoadROM_IIE_Enhanced();
   else if(model == APPLE2_MODEL_IIE)
    LoadROM_IIE();
   else
   {
    auto const& fw_cfg = mai_cfg["firmware"];

    if(fw_cfg.size() < 2)
     throw MDFN_Error(0, _("Insufficient number of arguments for \"%s\" setting in MAI file."), "firmware");
    else if(fw_cfg.size() > 2)
     throw MDFN_Error(0, _("Too many arguments for \"%s\" setting in MAI file."), "firmware");
    else
    {
     std::string fwtype = fw_cfg[1];

     MDFN_strazlower(&fwtype);

     if(fwtype == "applesoft")
      LoadROM_Applesoft(1);
     else if(fwtype == "integer")
      LoadROM_Integer(1);
     else
      throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), "firmware");
    }
   }

   if(EnableIIE)
    gameid_hasher.process(ROM_IIE, 0x4000);
   else
    gameid_hasher.process(ROM12K[1], 0x3000);
  }

  //
  // Apple IIe Video ROM
  //
  if(EnableIIE)
  {
   auto const& cgov_cfg = mai_cfg["video.override"];
   std::unique_ptr<Stream> cgfp;
   uint8 tmp[0x1000];

   if(cgov_cfg.size() > 1)
    cgfp.reset(gf->vfs->open(gf->vfs->eval_fip(gf->dir, cgov_cfg[1]), VirtualFS::MODE_READ));
   else
   {
    const std::string fname = (model == APPLE2_MODEL_IIE_ENH) ? "apple2e-enh-video.rom" : "apple2e-video.rom";

    cgfp.reset(new FileStream(MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, fname.c_str()), FileStream::MODE_READ));
   }

   cgfp->read(tmp, sizeof(tmp));

   dig_video_rom = sha256(tmp, sizeof(tmp));
   if(1)
   {
    if(dig_video_rom == "0d54ff735c060c55d54b8a22d0112af78a6465ce9c9aae4a865d207e5c8ff1e7"_sha256)
     throw MDFN_Error(0, _("Bad video ROM dump detected."));
   }

   Video::SetVideoROM(tmp);
  }

  //
  // Apple IIe Keyboard Map
  //
  KBIO::SetDecodeROM(nullptr, EnableIIE);

  if(EnableIIE)
  {
   auto const& kbov_cfg = mai_cfg["kbmap.override"];
   std::unique_ptr<Stream> kbfp;
   uint8 tmp[0x800];

   if(kbov_cfg.size() > 1)
    kbfp.reset(gf->vfs->open(gf->vfs->eval_fip(gf->dir, kbov_cfg[1]), VirtualFS::MODE_READ));
   else
   {
    const std::string fname = (model == APPLE2_MODEL_IIE_ENH) ? "apple2e-enh-kb.rom" : "apple2e-kb.rom";

    kbfp.reset(new FileStream(MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, fname), FileStream::MODE_READ));
   }

   kbfp->read(tmp, sizeof(tmp));
   gameid_hasher.process(tmp, sizeof(tmp));
   dig_kb_rom = sha256(tmp, sizeof(tmp));

   KBIO::SetDecodeROM(tmp, true);
  }

  //
  // ROM card
  //
  EnableROMCard = false;

  if(model == APPLE2_MODEL_II_IIP)
  {
   memset(ROM12K[0], 0xFF, sizeof(ROM12K[0]));

   if(!EnableLangCard)
   {
    auto const& rcov_cfg = mai_cfg["romcard.override"];
    auto const& rc_cfg = mai_cfg["romcard"];
    std::string rctype;

    if(rc_cfg.size() < 2)
     throw MDFN_Error(0, _("Insufficient number of arguments for \"%s\" setting in MAI file."), "romcard");
    else if(rc_cfg.size() > 2)
     throw MDFN_Error(0, _("Too many arguments for \"%s\" setting in MAI file."), "romcard");
    else
     rctype = rc_cfg[1];

    MDFN_strazlower(&rctype);

    if(rctype == "none")
     EnableROMCard = false;
    else if(rcov_cfg.size() > 1)
    {
     EnableROMCard = true;

     LoadROM_Custom(0, gf->vfs, gf->dir, rcov_cfg[1]);
    }
    else
    {
     EnableROMCard = true;

     if(rctype == "applesoft")
      LoadROM_Applesoft(0);
     else if(rctype == "integer")
      LoadROM_Integer(0);
     else
      throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), "romcard");
    }
   }
   gameid_hasher.process(ROM12K[0], 0x3000);
  }

  //
  // Sound card, and others(TODO)
  //
  for(unsigned i = 0; i < 16; i++)
   gameid_hasher.process_scalar<uint32>(0);


  //
  // Game I/O (only hash custom resistance settings, don't hash any values based on the "gameio" setting)
  //
  uint32 gio_resistance[4];
  {
   auto const& gio_cfg = mai_cfg["gameio"];
   auto const& gioresist_cfg = mai_cfg["gameio.resistance"];

   if(mai_load)
   {
    if(gio_cfg.size() < 2)
     throw MDFN_Error(0, _("Insufficient number of arguments for \"%s\" setting in MAI file."), "gameio");
    else
    {
     const std::string& giotype = gio_cfg[1];

     if(gio_cfg.size() != (unsigned)(2 + (giotype == "gamepad" || giotype == "joystick")))
      throw MDFN_Error(0, _("Too many arguments for \"%s\" setting in MAI file."), "gameio");
     else
     {
      if(giotype == "none")
      {
       MDFNGameInfo->DesiredInput[0].device_name = "none";
      }
      else if(giotype == "paddles")
      {
       MDFNGameInfo->DesiredInput[0].device_name = "paddle";
       MDFNGameInfo->DesiredInput[1].device_name = "paddle";
      }
      else if(giotype == "joystick" || giotype == "gamepad")
      {
       unsigned rsel;

       if(sscanf(gio_cfg[2].c_str(), "%u", &rsel) != 1)
        throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), "gameio");

       if(rsel < 1)
        throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), "gameio");
       else if(rsel > 4)
        throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), "gameio");
       //
       //
       MDFNGameInfo->DesiredInput[0].device_name = (giotype == "joystick") ? "joystick" : "gamepad";
       MDFNGameInfo->DesiredInput[0].switches["resistance_select"] = rsel - 1;
      }
      else if(giotype == "atari")
      {
       MDFNGameInfo->DesiredInput[0].device_name = "atari";
       MDFNGameInfo->DesiredInput[1].device_name = "atari";
      }
      else
       throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), "gameio");
     }
    }
   }
   //
   //
   if(gioresist_cfg.size() < 5)
    throw MDFN_Error(0, _("Too few arguments for \"%s\" setting in MAI file."), "gameio.resistance");
   else if(gioresist_cfg.size() > 5)
    throw MDFN_Error(0, _("Too many arguments for \"%s\" setting in MAI file."), "gameio.resistance");
   else
   {
    for(unsigned i = 0; i < 4; i++)
    {
     const std::string& gioresist_s = gioresist_cfg[1 + i];
     unsigned gioresist;

     if(sscanf(gioresist_s.c_str(), "%u", &gioresist) != 1)
      throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), "gameio.resistance"); 

     if(gioresist > 500000)
      throw MDFN_Error(0, _("Specified game I/O device resistance \"%u\" is too large."), gioresist);

     gio_resistance[i] = gioresist;
     gameid_hasher.process_scalar<uint32>(gio_resistance[i]);
    }
   }
  }
  //
  //
  //
#ifdef MDFN_APPLE2_PARTIALBIOS_HLE
  {
   {
    static const unsigned rom_hook_addrs[] =
    {
     0xFB1E, 0xFC58, 0xFCA8, 0xFDED, 0xFDF0, 0xFE2C
    };

    memset(ROM12K, 0x00, sizeof(ROM12K));

    for(const unsigned ha : rom_hook_addrs)
    {
     ROM12K[0][(ha - 0xD000) + 0] = 0x02;
     ROM12K[0][(ha - 0xD000) + 1] = 0x60;
    }
    //
    //
    ROM12K[0][(0xFBB3 - 0xD000) + 0] = 0xEA;
    ROM12K[0][(0xFB2F - 0xD000) + 0] = 0x60;
    ROM12K[0][(0xFE89 - 0xD000) + 0] = 0x60;
    ROM12K[0][(0xFE93 - 0xD000) + 0] = 0x60;
    ROM12K[0][(0xFF58 - 0xD000) + 0] = 0x60;
    //
    MDFN_en16lsb(&ROM12K[0][0xFFFC - 0xD000], 0xC600);
    MDFN_en16lsb(&ROM12K[0][0xFFFE - 0xD000], 0xFA40);
    ROM12K[0][(0xFA40 - 0xD000) + 0] = 0x4C;
    ROM12K[0][(0xFA40 - 0xD000) + 1] = 0x40;
    ROM12K[0][(0xFA40 - 0xD000) + 2] = 0xFA;
    //
    //
    memcpy(ROM12K[1], ROM12K[0], sizeof(ROM12K[0]));
   }
  }
#endif
  //
  //
  //
  assert(MDFNGameInfo->DesiredInput.size() == 3);
  assert((MDFNGameInfo->DesiredInput[0].device_name == nullptr && MDFNGameInfo->DesiredInput[1].device_name == nullptr) || mai_load);
  {
   MDFN_printf("\n");
   MDFN_printf(_("Model: %s\n"), ModelHS[model]);
   MDFN_printf(_("RAM:   %u KiB\n"), RAMSize / 1024);
   {
    if(EnableIIE)
     MDFN_printf(_("ROM:   %s\n"), GetROMHS(sha256(ROM_IIE, 0x4000)).c_str());
    else
    {
     const char* r_hs = _("Unknown");

     if(sha256(ROM12K[1], 0x3000) == "fc3e9d41e9428534a883df5aa10eb55b73ea53d2fcbb3ee4f39bed1b07a82905"_sha256)
      r_hs = _("AppleSoft BASIC and Autostart");
     else if(sha256(ROM12K[1] + 0x1000, 0x2000) == "cb52b212a62f808c2f59600b2823491ee12bd91cab8e0260fe34b5f14c47552f"_sha256)
      r_hs = _("Integer BASIC and Autostart");

     MDFN_printf(_("ROM:   %s\n"), r_hs);
    }

   }

   if(!EnableROMCard)
    MDFN_printf(_("ROM Card: %s\n"), _("(disabled)"));
   else
   {
    const char* rc_hs = _("Unknown");

    if(sha256(ROM12K[0], 0x3000) == "fc3e9d41e9428534a883df5aa10eb55b73ea53d2fcbb3ee4f39bed1b07a82905"_sha256)
     rc_hs = _("AppleSoft BASIC and Autostart");
    else if(sha256(ROM12K[0] + 0x1000, 0x2000) == "cb52b212a62f808c2f59600b2823491ee12bd91cab8e0260fe34b5f14c47552f"_sha256)
     rc_hs = _("Integer BASIC and Autostart");

    MDFN_printf(_("ROM Card: %s\n"), rc_hs);
   }

   if(EnableIIE)
   {
    MDFN_printf(_("Video ROM:    %s\n"), GetROMHS(dig_video_rom).c_str());
    MDFN_printf(_("Keyboard ROM: %s\n"), GetROMHS(dig_kb_rom).c_str());
   }

   MDFN_printf(_("Disk II: %s\n"), EnableDisk2 ? MDFN_sprintf(_("Slot %u"), 6).c_str() : _("(disabled)"));
   if(EnableDisk2)
   {
    MDFN_AutoIndent aind(1);

    MDFN_printf(_("Boot ROM:      %s\n"), GetROMHS(dig_disk2_boot_rom).c_str());
    MDFN_printf(_("Sequencer ROM: %s\n"), GetROMHS(dig_disk2_seq_rom).c_str());
   }

   if(EnableHDD)
    MDFN_printf(_("HDD: %s; %u blocks\n"), MDFN_sprintf(_("Slot %u"), EnableHDD).c_str(), hdd_size);
   else
    MDFN_printf(_("HDD: %s\n"), _("(disabled)"));
  }
  //
  //
  //
  for(unsigned A = 0; A < 0xC000; A++)
  {
   if(EnableIIE)
   {
    assert(RAMPresent[A >> 12]);
    SetRWHandlers(A, ReadRAM48K_IIE, WriteRAM48K_IIE);
   }
   else
   {
    if(RAMPresent[A >> 12])
     SetRWHandlers(A, ReadRAM48K, WriteRAM48K);
   }
  }

#if 0
  // Toggle tape output
  for(unsigned A = 0xC020; A < 0xC030; A++)

  // Game strobe
  for(unsigned A = 0xC040; A < 0xC050; A++)
#endif

  for(unsigned A = 0xC050; A < 0xC060; A++)
   SetRWHandlers(A, RWSoftSwitch, RWSoftSwitch);

  // Cassette input
  // 0xC070

  if(EnableIIE)
  {
   assert(EnableLangCard);
   assert(!EnableROMCard);

   for(unsigned A = 0xC05E; A < 0xC060; A++)
    SetRWHandlers(A, RWSoftSwitch_AN3_IIE, RWSoftSwitch_AN3_IIE);

   for(unsigned A = 0xC080; A < 0xC090; A++)
    SetRWHandlers(A, RWLangCardControl_IIE<true>, RWLangCardControl_IIE<false>);

   for(unsigned A = 0xD000; A < 0xE000; A++)
    SetRWHandlers(A, ReadLangBSArea_IIE, WriteLangBSArea_IIE);

   for(unsigned A = 0xE000; A < 0x10000; A++)
    SetRWHandlers(A, ReadLangStaticArea_IIE, WriteLangStaticArea_IIE);
  }
  else if(EnableLangCard)
  {
   assert(!EnableROMCard);

   for(unsigned A = 0xC080; A < 0xC090; A++)
    SetRWHandlers(A, RWLangCardControl<true>, RWLangCardControl<false>);

   for(unsigned A = 0xD000; A < 0xE000; A++)
    SetRWHandlers(A, ReadLangBSArea, WriteLangBSArea);

   for(unsigned A = 0xE000; A < 0x10000; A++)
    SetRWHandlers(A, ReadLangStaticArea, WriteLangStaticArea);
  }
  else
  {
   if(EnableROMCard)
   {
    for(unsigned A = 0xC080; A < 0xC090; A++)
     SetRWHandlers(A, RWROMCardControl, RWROMCardControl);
   }

   for(unsigned A = 0xD000; A < 0x10000; A++)
   {
    SetReadHandler(A, ReadROM);
   }
  }
  //
  //
  PrevResetHeld = false;

  if(MDFN_GetSettingB("apple2.video.correct_aspect"))
   MDFNGameInfo->nominal_width = 250;	// 292 * 12.272727 / 14.318182
  else
   MDFNGameInfo->nominal_width = 292;

  Video::Init(EnableIIE);
  KBIO::Init(EnableIIE);
  KBIO::SetKeyGhosting(MDFN_GetSettingB("apple2.input.kb.ghosting"));
  KBIO::SetAutoKeyRepeat(MDFN_GetSettingB("apple2.input.kb.auto_repeat"));
  GameIO::Init(gio_resistance);
  Sound::Init();

  DBG::Init();
  //
  //
  if(RAMSize > 0x20000)
  {
   AuxBankChainWF = ChainWriteHandler(0xC073, WriteSelectAuxBank_IIE);
  }
  //
  //
  if(EnableIIE)
  {
   for(unsigned A = 0xC000; A < 0xC010; A++)
    SetWriteHandler(A, WriteSoftSwitch_IIE);

   for(unsigned A = 0xC011; A < 0xC020; A++)
   {
    readfunc_t rf = ReadSoftSwitchStatus_IIE;

    if(A < 0xC013)
     rf = ReadBSRStatus_IIE;

    SetReadHandler(A, rf);
   }

   for(unsigned A = 0xC100; A < 0xD000; A++)
   {
    SlotROMReadFuncs[A & 0xFFF] = ReadFuncs[A]; 
    SlotROMWriteFuncs[A & 0xFFF] = WriteFuncs[A];
    //
    SetRWHandlers(A, ReadROMLow_IIE, WriteROMLow_IIE);
   }
  }
  //
  //
  //
  {
   sha256_digest d = gameid_hasher.digest();

   memcpy(MDFNGameInfo->MD5, d.data(), 16);
  }

  //
  // Load saved disk images
  //
  for(size_t i = 0; i < Disks.size(); i++)
  {
   Disk2::FloppyDisk* disk = Disks[i].get();
   const bool wp_save = disk->write_protect;
   char ext[64];
   snprintf(ext, sizeof(ext), "%u.afd.gz", (unsigned)i);

   try
   {
    GZFileStream gfp(MDFN_MakeFName(MDFNMKF_SAV, 0, ext), GZFileStream::MODE::READ);

    Disk2::GetClearDiskDirty(disk);
    Disk2::LoadDisk(&gfp, "afd", disk);
    Disk2::SetEverModified(disk);
   }
   catch(MDFN_Error& e)
   {
    if(e.GetErrno() != ENOENT)
     throw;
   }

   disk->write_protect = wp_save;
   //
   //
   MDFN_BackupSavFile(10, ext);
  }
  //
  // Load saved hard disk drive image:
  //
  if(EnableHDD)
  {
   char ext[64];

   snprintf(ext, sizeof(ext), "%u.ahd.gz", 0);

   try
   {
    GZFileStream gfp(MDFN_MakeFName(MDFNMKF_SAV, 0, ext), GZFileStream::MODE::READ);

    HDD::LoadDelta(&gfp);
   }
   catch(MDFN_Error& e)
   {
    if(e.GetErrno() != ENOENT)
     throw;
   }
   //
   //
   MDFN_BackupSavFile(5, ext);
  }
  //
  //
  Power();
 }
 catch(...)
 {
  Cleanup();

  throw;
 }
}

static void Close(void)
{
#if 0
  for(const Disk2::FloppyDisk& disk : Disks)
  {
   MemoryStream dms;
   Disk2::FloppyDisk psdisk;
   sha256_hasher h;
   sha256_digest disk_dig, psdisk_dig;

   Disk2::SaveDisk(&dms, &disk);
   dms.rewind();
   Disk2::LoadDisk(&dms, "afd", &psdisk);

   Disk2::HashDisk(&h, &disk);
   disk_dig = h.digest();
   h.reset();
   Disk2::HashDisk(&h, &psdisk);
   psdisk_dig = h.digest();


   puts("YAS");
   assert(disk_dig == psdisk_dig);
  }
#endif


 //
 // Save disk images
 //
 for(size_t i = 0; i < Disks.size(); i++)
 {
  Disk2::FloppyDisk* disk = Disks[i].get();

  if(Disk2::GetEverModified(disk))
  {
   char ext[64];
   snprintf(ext, sizeof(ext), "%u.afd.gz", (unsigned)i);
   //
   try
   {
    GZFileStream gfp(MDFN_MakeFName(MDFNMKF_SAV, 0, ext), GZFileStream::MODE::WRITE);

    Disk2::SaveDisk(&gfp, disk);

    gfp.close();
   }
   catch(std::exception& e)
   {
    MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
   }
  }
 }
 //Disk2::AnalyzeDisk(Disks[0].get());
 //abort();

 //
 // Save hard disk drive image
 //
 if(EnableHDD)
 {
  if(HDD::GetEverModified())
  {
   char ext[64];
   snprintf(ext, sizeof(ext), "%u.ahd.gz", 0);
   //
   try
   {
    GZFileStream gfp(MDFN_MakeFName(MDFNMKF_SAV, 0, ext), GZFileStream::MODE::WRITE);

    HDD::SaveDelta(&gfp);

    gfp.close();
   }
   catch(MDFN_Error& e)
   {
    MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
   }
  }
 }

 //
 //
 //
 Cleanup();
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 uint8 oldss = SoftSwitch;

 SFORMAT StateRegs[] = 
 {
  SFPTR8N(RAM, 0xC000, "RAM48K"),

  SFVAR(ROMSelect),

  SFPTR8N(RAM + 0xC000, 0x4000, "LangRAM"),

  SFPTR8N(RAM + 0x10000, std::max<uint32>(RAMSize, 0x10000) - 0x10000, "AuxRAM"),

  SFVAR(LangRAMReadEnable),
  SFVAR(LangRAMWriteEnable),
  SFVAR(LangRAMPrevA1),
  SFVAR(LangBank2Select),

  SFVAR(AuxBank),

  SFVARN(oldss, "SoftSwitch"),
  SFVARN(SoftSwitch, "SoftSwitch32"),

  SFVAR(V7RGBMode),

  SFVAR(DB),
  //int32 timestamp;
  SFVAR(ResetPending),
  SFVAR(PrevResetHeld),
  //SFVAR(FrameDone),
  SFVAR(Jammed),

#ifdef MDFN_APPLE2_PARTIALBIOS_HLE
  SFVAR(HLEPhase),
  SFVAR(HLESuckCounter),
  SFVAR(HLETemp),
#endif

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAIN");

 if(load)
 {
  if(load < 0x00103200)
  {
   SoftSwitch = oldss;
  }

  RecalcAuxBankOffs();
 }

 CPU.StateAction(sm, load, data_only, "CPU");
 Video::StateAction(sm, load, data_only);
 KBIO::StateAction(sm, load, data_only);
 GameIO::StateAction(sm, load, data_only);
 Sound::StateAction(sm, load, data_only);

 if(EnableDisk2)
 {
  Disk2::StateAction(sm, load, data_only);
  //
  //
  //
  for(size_t i = 0; i < Disks.size(); i++)
  {
   char disk_sname[32];

   snprintf(disk_sname, sizeof(disk_sname), "DISKII_DISK%u", (unsigned)i);

   Disk2::StateAction_Disk(sm, load, data_only, Disks[i].get(), disk_sname);
  }
  //
  //
  //
  if(load)
   Disk2::StateAction_PostLoad(load);
 }

 if(EnableHDD)
 {
  HDD::StateAction(sm, load, data_only);
 }
}

static uint32 GetCheatRAMOffs(uint32 A)
{
 uint32 ret = (uint32)-1;

 if(RAMSize <= 0x10000)
 {
  if(A < 0xC000)
  {
   if(RAMPresent[A >> 12])
    ret = A;
  }
  else if(EnableLangCard)
  {
   if(A < 0x10000)
    ret = A;
   else if(A < 0x14000) // for backwards-compatibility
    ret = 0xC000 + (A & 0x3FFF);
  }
 }
 else
 {
  bool aux = (A >> 16) & 1;
  uint32 offs = A & RAMMask[aux];

  if(offs < RAMSize)
   ret = offs;
 }

 return ret;
}

static MDFN_COLD uint8 CheatMemRead(uint32 A)
{
 const uint32 offs = GetCheatRAMOffs(A);

 if(offs != (uint32)-1)
  return RAM[offs];

 return 0;
}

static MDFN_COLD void CheatMemWrite(uint32 A, uint8 V)
{
 const uint32 offs = GetCheatRAMOffs(A);

 if(offs != (uint32)-1)
  RAM[offs] = V;
}

static MDFN_COLD void TransformInput(void)
{
 KBIO::TransformInput();
}

static MDFN_COLD void SetInput(unsigned port, const char* type, uint8* ptr)
{
 if(port == 2)
  KBIO::SetInput(type, ptr);
 else
  GameIO::SetInput(port, type, ptr);
}

static MDFN_COLD void SetMedia(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{
 const RMD_Layout* rmd = MDFNGameInfo->RMD;
 const RMD_Drive* rd = &rmd->Drives[drive_idx];
 const RMD_State* rs = &rd->PossibleStates[state_idx];

 //printf("Set media: %u %u %u %u\n", drive_idx, state_idx, media_idx, orientation_idx);

 if(rs->MediaPresent && rs->MediaUsable)
  Disk2::SetDisk(drive_idx, Disks[media_idx].get());
 else
  Disk2::SetDisk(drive_idx, nullptr);
}

static MDFN_COLD void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_RESET:
	// Reset button handled in the keyboard emulation stuff instead of here.
	break;	

  case MDFN_MSC_POWER:
	Power();
	break;
 }
}

static const std::vector<InputPortInfoStruct> A2PortInfo =
{
 { "port1", "Virtual Gameport 1", GameIO::InputDeviceInfoGIOVPort1, "joystick" },
 { "port2", "Virtual Gameport 2", GameIO::InputDeviceInfoGIOVPort2, "paddle" },

 { "kb", "Keyboard", KBIO::InputDeviceInfoA2KBPort, "iip", InputPortInfoStruct::FLAG_NO_USER_SELECT },
};

static void VideoChangeNotif(const char* name)
{
 VideoSettingChanged = true;
}

static const MDFNSetting_EnumList Matrix_List[] =
{
 { "custom", Video::Settings::MATRIX_CUSTOM, "Custom" },

 { "mednafen", Video::Settings::MATRIX_MEDNAFEN, "Mednafen" },

 { "la7620", Video::Settings::MATRIX_LA7620, gettext_noop("Sanyo LA7620-like.") },

 { "cxa2025as_usa", Video::Settings::MATRIX_CXA2025_USA, gettext_noop("Sony CXA2025AS-like, USA setting") },
 { "cxa2060bs_usa", Video::Settings::MATRIX_CXA2060_USA, gettext_noop("Sony CXA2060BS-like, USA setting.") },
 { "cxa2095s_usa", Video::Settings::MATRIX_CXA2095_USA, gettext_noop("Sony CXA2095S-like, USA setting.") },

 { "cxa2025as_japan", Video::Settings::MATRIX_CXA2025_JAPAN, gettext_noop("Sony CXA2025AS-like, Japan setting.") },
 { "cxa2060bs_japan", Video::Settings::MATRIX_CXA2060_JAPAN, gettext_noop("Sony CXA2060BS-like, Japan setting.") },
 { "cxa2095s_japan", Video::Settings::MATRIX_CXA2095_JAPAN, gettext_noop("Sony CXA2095S-like, Japan setting.") },

 { nullptr, 0 },
};

static const MDFNSetting_EnumList Mode_List[] =
{
 { "composite", Video::Settings::MODE_COMPOSITE, "Composite", gettext_noop("Internal video dimensions of 584x192.") },

 { "rgb", Video::Settings::MODE_RGB, "RGB", gettext_noop("Internal video dimensions of 292x192 for single-resolution modes, and 584x192 for double-resolution; suitable for use with scalers like hq2x.") },
 { "rgb_tfr", Video::Settings::MODE_RGB_TFR, "RGB, with (D)HGR text fringe reduction.", gettext_noop("Internal video dimensions of 292x192 for single-resolution modes, and 584x192 for double-resolution; suitable for use with scalers like hq2x.  Reduced brightness of colored pixels horizontally sandwiched between white pixels in (D)HGR mode.") },

 { "rgb_alt", Video::Settings::MODE_RGB_ALT, "RGB (alternate algorithm)", gettext_noop("Internal video dimensions of 584x192.") },
 { "rgb_alt_tfr", Video::Settings::MODE_RGB_ALT_TFR, "RGB (alternate algorithm), with (D)HGR text fringe reduction.", gettext_noop("Internal video dimensions of 584x192.  Reduced brightness of colored pixels horizontally sandwiched between white pixels in (D)HGR mode.") },

 { "rgb_qd", Video::Settings::MODE_RGB_QD, "RGB, with 1/4 resolution DHGR.", gettext_noop("Internal video dimensions of 292x192 for single-resolution modes, 584x192 for 80-column text, and 146x192 for DHGR; suitable for use with scalers like hq2x.  Enables palette generation tweak to provides two distinct grays.") },
 { "rgb_qd_tfr", Video::Settings::MODE_RGB_QD_TFR, "RGB, with HGR text fringe reduction and 1/4 resolution DHGR.", gettext_noop("Internal video dimensions of 292x192 for single-resolution modes, 584x192 for 80-column text, and 146x192 for DHGR; suitable for use with scalers like hq2x.  Reduced brightness of colored pixels horizontally sandwiched between white pixels in HGR mode.  Enables palette generation tweak to provides two distinct grays.") },

 { "rgb_video7", Video::Settings::MODE_RGB_VIDEO7, "RGB, IIe Video 7-like algorithm.", gettext_noop("Internal video dimensions of 584x192.  Enables palette generation tweak to provides two distinct grays.\n\nUseful with Sierra AGI games, like \"King's Quest\" and \"Space Quest\".") },
 //
 // Backwards compatibility:
 { "rgb_alt1", Video::Settings::MODE_RGB_ALT },
 { "rgb_alt2", Video::Settings::MODE_RGB_ALT_TFR },

 { nullptr, 0 }
};

static const MDFNSetting_EnumList Model_List[] =
{
 { "ii", APPLE2_CFG_MODEL_II, "Apple II", gettext_noop("Apple II, with 48KiB RAM, Integer BASIC, AppleSoft BASIC ROM card, and Autostart.") },
 { "ii+", APPLE2_CFG_MODEL_IIP, "Apple II+", gettext_noop("Apple II+, with 64KiB RAM, AppleSoft BASIC, and Autostart.") },
 { "ii_ii+", APPLE2_MODEL_II_IIP, "Apple II/II+", gettext_noop("Apple II/II+, with 64KiB RAM, AppleSoft BASIC, and Autostart; however, when loading a 13-sector disk image, 48KiB of RAM and an Integer BASIC ROM card are automatically selected.") },
 { "iie", APPLE2_MODEL_IIE, "Apple IIe", gettext_noop("Apple IIe with 128KiB RAM and DHGR support.") },
 { "iie_enh", APPLE2_MODEL_IIE_ENH, "Enhanced Apple IIe", gettext_noop("Enhanced Apple IIe with 128KiB RAM and DHGR support.") },
 { "iie_enhanced", APPLE2_MODEL_IIE_ENH },

 // TODO: { "iie_plat", MODEL_IIE_PLATINUM, "Platinum Apple IIe", gettext_noop("Platinum Apple IIe with 128KiB RAM.") },
 // TODO: { "iie_platinum", APPLE2_MODEL_IIE_PLATINUM },

 { nullptr, 0 }
};

#ifdef MDFN_ENABLE_DEV_BUILD
static const MDFNSetting_EnumList DBGMask_List[] =
{
 { "0",		0						},
 { "none",	0,			gettext_noop("None")	},

 { "all",	~0,			gettext_noop("All")	},

 { "warning",	APPLE2_DBG_WARNING,	gettext_noop("Warnings")	},

 { "unk_read",	APPLE2_DBG_UNK_READ,	gettext_noop("Reads from unhandled CPU addresses")	},
 { "unk_write",	APPLE2_DBG_UNK_WRITE,	gettext_noop("Writes to unhandled CPU addresses")	},
 { "uninit_read", APPLE2_DBG_UNINITIALIZED_READ,	gettext_noop("Reads from uninitialized RAM") },

 { "disk2", APPLE2_DBG_DISK2,		gettext_noop("Disk II")	},
 { "bios", APPLE2_DBG_BIOS,		gettext_noop("BIOS") },
 { "dos", APPLE2_DBG_DOS,		gettext_noop("AppleDOS") },
 { "prodos", APPLE2_DBG_PRODOS,		gettext_noop("ProDOS") },

 { nullptr, 0 }
};
#endif

static const MDFNSetting Settings[] =
{
 { "apple2.model", MDFNSF_EMU_STATE, gettext_noop("Nominal model of Apple II to emulate."), gettext_noop("This setting is ignored when using a MAI file."), MDFNST_ENUM, "ii_ii+", nullptr, nullptr, nullptr, nullptr, Model_List },

 { "apple2.input.kb.auto_repeat", MDFNSF_NOFLAGS, gettext_noop("Enable Apple IIe's auto key repeat."), gettext_noop("Only has an effect with Apple IIe/Enhanced IIe emulation."), MDFNST_BOOL, "1" },
 { "apple2.input.kb.ghosting", MDFNSF_NOFLAGS, gettext_noop("Enable key ghosting emulation."), gettext_noop("When enabled, spurious emulated keypresses will be generated when certain combinations of keys are held down simultaneously."), MDFNST_BOOL, "1" },

 { "apple2.multiload", 0, gettext_noop("Enable automatic multiload from archives."), gettext_noop("When loading a disk image from an archive(e.g. ZIP file) without a MAI file present, also automatically load all other files with the same extension in the same directory in that archive."), MDFNST_BOOL, "1" },

 { "apple2.video.correct_aspect", MDFNSF_NOFLAGS, gettext_noop("Correct aspect ratio."), nullptr, MDFNST_BOOL, "1" },

 { "apple2.video.hue",		MDFNSF_CAT_VIDEO, gettext_noop("Color video hue/tint."),   nullptr, MDFNST_FLOAT, "0.0", "-1.0", "1.0", nullptr, VideoChangeNotif },
 { "apple2.video.saturation",	MDFNSF_CAT_VIDEO, gettext_noop("Color video saturation."), nullptr, MDFNST_FLOAT, "0.0", "-1.0", "1.0", nullptr, VideoChangeNotif  },
 { "apple2.video.contrast",	MDFNSF_CAT_VIDEO, gettext_noop("Video luma contrast."), nullptr, MDFNST_FLOAT, "0.0", "-1.0", "1.0", nullptr, VideoChangeNotif  },
 { "apple2.video.brightness",	MDFNSF_CAT_VIDEO, gettext_noop("Video brightness."), nullptr, MDFNST_FLOAT, "0.0", "-1.0", "1.0", nullptr, VideoChangeNotif  },
 { "apple2.video.force_mono",   MDFNSF_CAT_VIDEO, gettext_noop("Force monochrome graphics color."), gettext_noop("Force monochrome graphics if non-zero, with the specified color."), MDFNST_UINT, "0x000000", "0x000000", "0xFFFFFF", nullptr, VideoChangeNotif  },
 { "apple2.video.mixed_text_mono",MDFNSF_CAT_VIDEO,gettext_noop("Enable hack to treat mixed-mode text as monochrome."), nullptr, MDFNST_BOOL, "0", nullptr, nullptr, nullptr, VideoChangeNotif },
 { "apple2.video.mono_lumafilter",MDFNSF_CAT_VIDEO,gettext_noop("Composite monochrome video luma filter."), gettext_noop("Filters numbered closer to 0 have a stronger lowpass effect.  Negative-numbered filters have ringing."), MDFNST_INT, "5", "-3", "7", nullptr, VideoChangeNotif  },
 { "apple2.video.color_lumafilter",MDFNSF_CAT_VIDEO,gettext_noop("Composite color video luma filter."), gettext_noop("Filters numbered closer to 0 have a stronger lowpass effect.  Negative-numbered filters have ringing."), MDFNST_INT, "-3", "-3", "3", nullptr, VideoChangeNotif  },
 { "apple2.video.color_smooth",	MDFNSF_CAT_VIDEO, gettext_noop("Composite color video smoothing level."), gettext_noop("When a non-zero value, reduces vertical stripes in composite video without increasing blurriness, at the cost of some pixel irregularities.  Larger values select more-aggressive smoothing.  May make small text illegible in graphics mode."), MDFNST_UINT, "0", "0", "2", nullptr, VideoChangeNotif  },
 { "apple2.video.postsharp",	MDFNSF_CAT_VIDEO, gettext_noop("Composite color video sharpness."), gettext_noop("Positive values will increase perceptual sharpness(and ringing), negative values will blur the image.  When a non-zero value is specified, CPU usage will increase due to the continuous extra calculations required.\n\nNote that this filter is applied after composite->RGB conversion(after the effects of the hue, saturation, brightness, contrast, color luma filter, and color smoothing settings), and in a roughly linear luminance space."), MDFNST_FLOAT, "0.0", "-1.0", "2.0", nullptr, VideoChangeNotif },

 { "apple2.video.matrix", MDFNSF_CAT_VIDEO, gettext_noop("Color decoder matrix."), gettext_noop("The matrixes that correspond to the nominal demodulation angles and gains for various ICs are intended to get colors within the ballpark of what consumer-oriented NTSC TVs would display, and won't exactly replicate the colors these ICs would reproduce when fed an Apple II video signal."), MDFNST_ENUM, "mednafen", nullptr, nullptr, nullptr, VideoChangeNotif, Matrix_List },

 { "apple2.video.matrix.red.i", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; red, I."), gettext_noop("Only used if \"\5apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "0.96", "-4.00", "4.00", nullptr, VideoChangeNotif  },
 { "apple2.video.matrix.red.q", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; red, Q."), gettext_noop("Only used if \"\5apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "0.62", "-4.00", "4.00", nullptr, VideoChangeNotif  },

 { "apple2.video.matrix.green.i", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; green, I."), gettext_noop("Only used if \"\5apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "-0.28", "-4.00", "4.00", nullptr, VideoChangeNotif  },
 { "apple2.video.matrix.green.q", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; green, Q."), gettext_noop("Only used if \"\5apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "-0.64", "-4.00", "4.00", nullptr, VideoChangeNotif  },

 { "apple2.video.matrix.blue.i", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; blue, I."), gettext_noop("Only used if \"\5apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "-1.11", "-4.00", "4.00", nullptr, VideoChangeNotif  },
 { "apple2.video.matrix.blue.q", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; blue, Q."), gettext_noop("Only used if \"\5apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "1.70", "-4.00", "4.00", nullptr, VideoChangeNotif  },

 { "apple2.video.mode", MDFNSF_CAT_VIDEO, gettext_noop("Video rendering mode."), gettext_noop("When an RGB mode is enabled, settings \"\5apple2.video.postsharp\", \"\5apple2.video.force_mono\", \"\5apple2.video.mixed_text_mono\", \"\5apple2.video.mono_lumafilter\", \"\5apple2.video.color_lumafilter\", and \"\5apple2.video.color_smooth\" are effectively ignored.\n\nWhen selecting an RGB mode, setting \"\5apple2.shader\" to \"autoipsharper\" is recommended."), MDFNST_ENUM, "composite", nullptr, nullptr, nullptr, VideoChangeNotif, Mode_List },

#ifdef MDFN_ENABLE_DEV_BUILD
 { "apple2.dbg_mask", MDFNSF_SUPPRESS_DOC, gettext_noop("Debug printf mask."), NULL, MDFNST_MULTI_ENUM, "none", NULL, NULL, NULL, NULL, DBGMask_List },
#endif

 { NULL },
};

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".mai",  10, gettext_noop("Apple II/II+ Configuration") },

 { ".woz",   0, gettext_noop("Apple II WOZ Disk Image") },

 { ".po",  -10, gettext_noop("Apple II ProDOS-order floppy disk image") },
 { ".dsk", -10, gettext_noop("Apple II DOS-order floppy disk image") },
 { ".do",  -10, gettext_noop("Apple II DOS-order floppy disk image") },

 { ".d13", -10, gettext_noop("Apple II 13-sectors/track floppy disk image") },

 { ".hdv", -15, gettext_noop("Apple II Virtual Hard Disk Drive image") },

 { NULL, 0, NULL }
};

static const CheatInfoStruct CheatInfo =
{
 NULL,
 NULL,

 CheatMemRead,
 CheatMemWrite,

 CheatFormatInfo_Empty,
 false
};

static const CustomPalette_Spec CPInfo[] =
{
 { gettext_noop("RGB mode 16-color(or 32-color for TFR) palette.  The presence of a custom palette will automatically enable RGB video mode if an RGB mode is not already selected via the \"\5apple2.video.mode\" setting.  If the palette has 32 color entries, the text fringe reduction variant of an RGB mode is enabled."), NULL, { 16, 32, 0 } },

 { NULL, NULL }
};

}

using namespace MDFN_IEN_APPLE2;

MDFN_HIDE extern const MDFNGI EmulatedApple2 =
{
 "apple2",
 "Apple II/II+/IIe/Enhanced IIe",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 #ifdef MDFN_ENABLE_DEV_BUILD
 &DBG::DBGInfo,
 #else
 NULL,
 #endif
 A2PortInfo,
 NULL,
 Load,
 TestMagic,
 nullptr,
 nullptr,
 Close,

 nullptr,
 nullptr,

 nullptr,
 nullptr,

 CPInfo,
 1,

 CheatInfo,

 false,
 StateAction,
 Emulate,
 TransformInput,
 SetInput,
 SetMedia,
 DoSimpleCommand,
 NULL,
 Settings,
 MDFN_MASTERCLOCK_FIXED(APPLE2_MASTER_CLOCK),
 1005336937,	// 65536*  256 * (14318181.81818 / ((456 * 2) * 262))

 EVFSUPPORT_RGB555 | EVFSUPPORT_RGB565,

 -1,  	// Multires possible?  Not really, but we need interpolation...

 584,   // lcm_width
 192,   // lcm_height
 NULL,  // Dummy

 250,	// Nominal width
 192,	// Nominal height
 584,	// Framebuffer width
 192,	// Framebuffer height

 1,     // Number of output sound channels
};

