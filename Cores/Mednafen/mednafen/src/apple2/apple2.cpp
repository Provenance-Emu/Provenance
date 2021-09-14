/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* apple2.cpp:
**  Copyright (C) 2018-2019 Mednafen Team
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
#include <mednafen/compress/GZFileStream.h>
#include <mednafen/compress/ZLInflateFilter.h>
#include <mednafen/mempatcher.h>
#include <mednafen/hash/sha256.h>
#include <mednafen/SimpleBitset.h>
#include <mednafen/Time.h>
#include <mednafen/sound/DSPUtility.h>
#include <mednafen/sound/SwiftResampler.h>

#include <trio/trio.h>

#include <bitset>
#include <map>

#ifdef MDFN_ENABLE_DEV_BUILD
 #include "../nes/dis6502.h"
#endif

using namespace Mednafen;

#ifdef MDFN_ENABLE_DEV_BUILD
 static uint32 apple2_dbg_mask;
#else
 enum { apple2_dbg_mask = 0 };
#endif

enum
{
 APPLE2_DBG_ERROR	=	(1U << 0),
 APPLE2_DBG_WARNING	=	(1U << 1),
 APPLE2_DBG_UNK_READ	=	(1U << 2),
 APPLE2_DBG_UNK_WRITE	=	(1U << 3),
 APPLE2_DBG_UNINITIALIZED_READ= (1U << 4),

 APPLE2_DBG_DISK2	=	(1U << 16),
 APPLE2_DBG_BIOS	=	(1U << 24),
 APPLE2_DBG_DOS		=	(1U << 25),
};

static INLINE void APPLE2_DBG(const char* format, ...) { }
static INLINE void APPLE2_DBG_Dummy(const char* format, ...) { }
#define APPLE2_DBG(which, ...) ((MDFN_UNLIKELY(apple2_dbg_mask & (which))) ? (void)trio_printf(__VA_ARGS__) : APPLE2_DBG_Dummy(__VA_ARGS__))

// Standardized signature byte @ $FBB3(Apple IIe = 06, autostart(II+) = EA)

// Reset active low for about 240ms after power on.

// TODO: Check open bus, 0x0000-0xC00F versus other address

// TODO: 65C02 not reliable if put in Apple II/II+ due to bus timing differences?

// TODO: Check CTRL+RESET style reset, on II vs IIe.

namespace MDFN_IEN_APPLE2
{
#include <mednafen/hw_cpu/6502/Core6502.h>

#define APPLE2_MASTER_CLOCK 14318181.81818

static bool EnableLangCard;
static bool EnableDisk2;

static bool RAMPresent[0xC];	// 4KiB * 12 = 48KiB
static uint8 RAM48K[0xC000];

static bool EnableROMCard;
// 0 = rom card, 1 = motherboard
static bool ROMSelect;
static bool ROMPresent[2][0x6]; // 2KiB * 6 = 12KiB
static uint8 ROM12K[2][0x3000];

static uint8 LangRAM[0x4000];
static bool LangRAMReadEnable, LangRAMWriteEnable, LangRAMPrevA1, LangBank2Select;

#ifdef MDFN_ENABLE_DEV_BUILD
static bool junkread;
static std::bitset<sizeof(RAM48K)> RAM48K_Initialized;
#endif

enum
{
 SOFTSWITCH_TEXT_MODE  = 0x01,	// When on, ignore mix mode, page 2, and hires mode bits in video handling.
 SOFTSWITCH_MIX_MODE   = 0x02,
 SOFTSWITCH_PAGE2      = 0x04,	// Page 1 if off, Page 2 if on.
 SOFTSWITCH_HIRES_MODE = 0x08,

 SOFTSWITCH_AN0        = 0x10,
 SOFTSWITCH_AN1        = 0x20,
 SOFTSWITCH_AN2        = 0x40,
 SOFTSWITCH_AN3        = 0x80
};
static uint8 SoftSwitch;	// C050-C05F, xxx0 for off(0), xxx1 for on(1)

static Core6502 CPU;
static uint8 DB;
static int32 timestamp;
static bool ResetPending;
static bool Jammed;

static bool PrevResetHeld;
static bool FrameDone, FramePartialDone;
static bool VideoSettingChanged;

static INLINE void CPUTick1(void);

#include "video.inc"

#define DEFRW(x) void MDFN_FASTCALL MDFN_HOT x (uint16 A)
#define DEFREAD(x) DEFRW(x)
#define DEFWRITE(x) DEFRW(x)

typedef MDFN_FASTCALL void (*readfunc_t)(uint16);
typedef MDFN_FASTCALL void (*writefunc_t)(uint16);

static readfunc_t ReadFuncs[0x10000];
static writefunc_t WriteFuncs[0x10000];

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

#include "debug.inc"
#include "disk2.inc"

static DEFREAD(ReadUnhandled)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 if(!junkread && !InHLPeek)
  APPLE2_DBG(APPLE2_DBG_UNK_READ, "[UNK] Unhandled read: %04x\n", A);
#endif
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteUnhandled)
{
 APPLE2_DBG(APPLE2_DBG_UNK_WRITE, "[UNK] Unhandled write: %04x %02x\n", A, DB);
 //
 CPUTick1();
}

static DEFREAD(ReadRAM48K)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 if(!junkread && !InHLPeek)
 {
  if(!RAM48K_Initialized[A])
   APPLE2_DBG(APPLE2_DBG_UNINITIALIZED_READ, "[UNINIT] Read from uninitialized RAM address 0x%04x(@=0x%02x).\n", A, RAM48K[A]);

  if(A >= 0x9D00 && A <= 0xBFFF && (CPU.PC < 0x9D00 || CPU.PC >= 0xC000))
   APPLE2_DBG(APPLE2_DBG_DOS, "[DOS] Read from DOS area of RAM at address 0x%04x, PC=0x%04x\n", A, CPU.PC);
 }
#endif

 DB = RAM48K[A];
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteRAM48K)
{
 RAM48K[A] = DB;
#ifdef MDFN_ENABLE_DEV_BUILD
 RAM48K_Initialized[A] = true;
#endif
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
  DB = ROM12K[ROMSelect][(size_t)A - 0xD000];
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFREAD(ReadLangBSArea)
{
 if(LangRAMReadEnable)
  DB = LangRAM[(size_t)A - 0xD000 + (LangBank2Select << 12)];
 else if(MDFN_LIKELY(ROMPresent[1][((size_t)A >> 11) - (0xD000 >> 11)]))
  DB = ROM12K[1][(size_t)A - 0xD000];
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteLangBSArea)
{
 if(LangRAMWriteEnable)
  LangRAM[(size_t)A - 0xD000 + (LangBank2Select << 12)] = DB;
 //
 CPUTick1();
}

static DEFREAD(ReadLangStaticArea)
{
 if(LangRAMReadEnable)
  DB = LangRAM[(size_t)A - 0xE000 + 0x2000];
 else if(MDFN_LIKELY(ROMPresent[1][((size_t)A >> 11) - (0xD000 >> 11)]))
  DB = ROM12K[1][(size_t)A - 0xD000];
 //
 if(!InHLPeek)
  CPUTick1();
}

static DEFWRITE(WriteLangStaticArea)
{
 if(LangRAMWriteEnable)
  LangRAM[(size_t)A - 0xE000 + 0x2000] = DB;
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


static INLINE void CPUTick0(void)
{
 timestamp += 7;
 Video::Tick(); // Note: adds time to timestamp occasionally
 //
 if(EnableDisk2)
  Disk2::Tick2M();	// Call after increasing timestamp
}

#ifdef MDFN_ENABLE_DEV_BUILD
static uint32 Tick1Counter;
static unsigned CPUTick1Called;
#endif

static INLINE void CPUTick1(void)
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

INLINE uint8 Core6502::MemRead(uint16 addr, bool junk)
{
#if 0
 if(RWLogger)
 {
  uint8 tmp[4];
  tmp[0] = 0x00;
  tmp[1] = 0;
  MDFN_en16lsb(&tmp[2], addr);
  RWLogger->write(tmp, sizeof(tmp));
 }
#endif
 //
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
 //printf("OpRead: %04x %02x\n", addr, RAM48K[addr]);
 return MemRead(addr, junk);
}

INLINE void Core6502::MemWrite(uint16 addr, uint8 value)
{
#if 0
 if(RWLogger)
 {
  uint8 tmp[4];
  tmp[0] = 0x01;
  tmp[1] = value;
  MDFN_en16lsb(&tmp[2], addr);
  RWLogger->write(tmp, sizeof(tmp));
 }
#endif
 //
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
#include <mednafen/hw_cpu/6502/Core6502.inc>

#include "sound.inc"
#include "gameio.inc"
#include "kbio.inc"

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
  if((/*!LangRAMReadEnable &&*/ prev_PC < 0xD000 && CPU.PC >= 0xD000) || (prev_PC < 0xF800 && CPU.PC >= 0xF800))
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

  if((/*!LangRAMReadEnable &&*/ CPU.PC < 0xD000 && prev_PC >= 0xD000) || (CPU.PC < 0xF800 && prev_PC >= 0xF800))
  {
   APPLE2_DBG(APPLE2_DBG_BIOS, "[BIOS]   ROM return; 0x%04x->0x%04x; A=0x%02x, X=0x%02x, Y=0x%02x, P=0x%02x, time=%5u\n", prev_PC, CPU.PC, CPU.A, CPU.X, CPU.Y, CPU.P, Tick1Counter - prev_t1counter);
   prev_t1counter = 0x80000000;
  }

  //if((prev_PC >= 0x9D00 && prev_PC <= 0xBFFF) && !(CPU.PC >= 0x9D00 && CPU.PC <= 0xBFFF))
  // printf("FromDOS?: 0x%04x->0x%04x; A=0x%02x, X=0x%02x, Y=0x%02x, P=0x%02x --- %c\n", prev_PC, CPU.PC, CPU.A, CPU.X, CPU.Y, CPU.P, CPU.A & 0x7F);

  if((CPU.PC >= 0x9D00 && CPU.PC <= 0xBFFF) && !(prev_PC >= 0x9D00 && prev_PC <= 0xBFFF))
   APPLE2_DBG(APPLE2_DBG_DOS, "[DOS] Call to 0x%04x from 0x%04x; A=0x%02x, X=0x%02x, Y=0x%02x, P=0x%02x --- %c\n", CPU.PC, prev_PC, CPU.A, CPU.X, CPU.Y, CPU.P, CPU.A & 0x7F);
  else if(CPU.PC == 0x3D6 || CPU.PC == MDFN_de16lsb(&RAM48K[0x3D7]))
   APPLE2_DBG(APPLE2_DBG_DOS, "[DOS] File manager(0x%04x) from 0x%04x\n", CPU.PC, prev_PC);
  else if(CPU.PC == 0x3D9 || CPU.PC == MDFN_de16lsb(&RAM48K[0x3DA]))
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
  else if(CPU.PC == 0x3DC || CPU.PC == MDFN_de16lsb(&RAM48K[0x3DD]))
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
  prev_PC = CPU.PC;
 }
}
#endif


static std::vector<Disk2::FloppyDisk> Disks;

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
  s.color_smooth = MDFN_GetSettingB("apple2.video.color_smooth");
  s.force_mono = MDFN_GetSettingUI("apple2.video.force_mono");
  s.mixed_text_mono = MDFN_GetSettingB("apple2.video.mixed_text_mono");
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
 Video::surface = espec->surface;
 espec->DisplayRect = Video::surface_dr;

 MDFNMP_ApplyPeriodicCheats();

 FrameDone = false;
 //
 while(!FrameDone)
 {
  Sound::StartTimePeriod();

  const bool ResetHeld = KBIO::UpdateInput();

  if(!ResetHeld && PrevResetHeld)
   ResetPending = true;
  PrevResetHeld = ResetHeld;

  GameIO::UpdateInput();
  do
  {
   FramePartialDone = false;
   try
   {
    //
    if(ResetPending)
    {
     ResetPending = false;
     Jammed = false;
     CPU.RESETStep();
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

      CPU.Step();
     }
    }
   }
   catch(int dummy)
   {
    Jammed = true;
   }
  } while(espec->NeedSoundReverse && !FrameDone);

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
 for(unsigned i = 0, j = 1, k = 3; i < 0xC000; i++, j = j * 123456789 + 987654321, k = k * 987654321 + 123456789)
  RAM48K[i] = ((i & 2) ? 0xC6 : 0xBD) ^ (j & (j >> 8) & (j >> 16) & (j >> 24) & k & (k >> 8) & (k >> 16));

#ifdef MDFN_ENABLE_DEV_BUILD
 RAM48K_Initialized.reset();
#endif

 SoftSwitch = 0;

 ROMSelect = 1;

 memset(LangRAM, 0x00, sizeof(LangRAM));
 LangRAMReadEnable = false;
 LangRAMWriteEnable = true;
 LangRAMPrevA1 = false;
 LangBank2Select = false;

 Video::Power();
 Sound::Power();
 KBIO::Power();
 GameIO::Power();
 if(EnableDisk2)
  Disk2::Power();

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
 //
 Disks.clear();
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

static unsigned GetUnsigned(std::map<std::string, std::vector<std::string>>& mai_cfg, const std::string& key)
{
 unsigned ret;

 auto const& b_cfg = mai_cfg[key];

 if(b_cfg.size() < 2)
  throw MDFN_Error(0, _("Too few arguments for \"%s\" setting in MAI file."), key.c_str());
 else if(b_cfg.size() > 2)
  throw MDFN_Error(0, _("Too many arguments for \"%s\" setting in MAI file."), key.c_str());
 else if(sscanf(b_cfg[1].c_str(), "%u", &ret) != 1)
  throw MDFN_Error(0, _("Invalid value for \"%s\" setting in MAI file."), key.c_str());

 return ret;
}

static void Load(GameFile* gf)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 apple2_dbg_mask = APPLE2_DBG_ERROR;
 {
  std::vector<uint64> dms = MDFN_GetSettingMultiUI("apple2.dbg_mask");

  for(uint64 dmse : dms)
   apple2_dbg_mask |= dmse;
 }
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

  for(size_t i = 0; i < 6; i++)
  {
   ROMPresent[0][i] = ROMPresent[1][i] = false;
  }

  std::map<std::string, std::vector<std::string>> mai_cfg =
  {
   #define MAICFGE(a, ...) { a, { a, __VA_ARGS__ } }
   MAICFGE("ram", "64"),
   MAICFGE("firmware", "applesoft"),
   MAICFGE("romcard", "integer"),
   MAICFGE("gameio", "joystick", "2"),
   MAICFGE("gameio.resistance", "93551", "125615", "149425", "164980"),
   MAICFGE("disk2.enable", "1"),
   MAICFGE("disk2.drive1.enable", "1"),
   MAICFGE("disk2.drive2.enable", "1"),
   MAICFGE("disk2.firmware", "16sec"),
   #undef MAICFGE
  };

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
   mai_cfg["disk2.disks.disk1"] = { "disk2.disks.disk1", gf->fbase, "DUMMY" };
   mai_cfg["disk2.drive1.disks"] = { "disk2.drive1.disks", "*disk1" };
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

  if(mai_load)
  {
   MDFNGameInfo->DesiredInput.clear();
   MDFNGameInfo->DesiredInput.resize(3);
   MDFNGameInfo->DesiredInput[0].device_name = "none";
   MDFNGameInfo->DesiredInput[1].device_name = "paddle";
   MDFNGameInfo->DesiredInput[2].device_name = "twopiece";
  }

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
        throw MDFN_Error(0, _("Disk \"%s\" not defined."), ds);
       else if(disk_cfg.size() < 3)
        throw MDFN_Error(0, _("Disk \"%s\" definition is incomplete."), ds);
       //
       const std::string disk_label = disk_cfg[1];
       const std::string disk_relpath = disk_cfg[2];
       int write_protect = (disk_cfg.size() >= 4) ? GetBoolean(disk_cfg[3], disk_cfg[0]) : -1;

       Disks.emplace_back();
       //
       Disk2::FloppyDisk& disk = Disks.back();

       if(mai_load)
       {
        std::string disk_path = gf->vfs->eval_fip(gf->dir, disk_relpath);
        std::string ext;
	std::unique_ptr<Stream> diskfp(gf->vfs->open(disk_path, VirtualFS::MODE_READ));

        gf->vfs->get_file_path_components(disk_path, nullptr, nullptr, &ext);

        if(ext.size() > 1)
         ext = ext.substr(1);

        Disk2::LoadDisk(diskfp.get(), ext, &disk);
       }
       else
       {
        Disk2::LoadDisk(gf->stream, gf->ext, &disk);

        if(Disk2::DetectDOS32(&disk))
        {
         mai_cfg["ram"] = { "ram", "48" };
         mai_cfg["disk2.firmware"] = { "disk2.firmware", "13sec" };
        }
       }
       //
       Disk2::HashDisk(&gameid_hasher, &disk);
       //
       if(write_protect >= 0)
        disk.write_protect = write_protect;

       MDFNGameInfo->RMD->Media.push_back(RMD_Media({disk_label, drive}));
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
        Disk2::SetSeqROM(buf);
       else
        Disk2::SetBootROM(buf);

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
        throw MDFN_Error(0, _("Firmware data for \"%s\" in file \"%s\" is corrupt or otherwise wrong."), fwinf.purpose, path.c_str());

       if(i)
        Disk2::SetSeqROM(buf);
       else
        Disk2::SetBootROM(buf);

       gameid_hasher.process(buf, 256);
      }
     }
    }
   }
  }
  //
  //
  //
  MDFNMP_Init(1024, 64 + 16);

  //
  // RAM
  //
  {
   unsigned NeedRAMAmount = GetUnsigned(mai_cfg, "ram");

   if(NeedRAMAmount & 3)
    throw MDFN_Error(0, _("Specified RAM size is not a multiple of 4."));
   else if(NeedRAMAmount < 4)
    throw MDFN_Error(0, _("Specified RAM size is too small."));
   else if(NeedRAMAmount > 48 && NeedRAMAmount < 64)
    throw MDFN_Error(0, _("Specified RAM size between 48KiB and 64KiB is unsupported."));
   else if(NeedRAMAmount > 64)
    throw MDFN_Error(0, _("Specified RAM size is too large."));

   gameid_hasher.process_scalar<uint32>(NeedRAMAmount);

   for(unsigned i = 0; i < 0xC; i++)
    RAMPresent[i] = (i * 4) < NeedRAMAmount;

   EnableLangCard = (NeedRAMAmount == 64);

   MDFNMP_RegSearchable(0x0000, 1024 * std::min<unsigned>(48, NeedRAMAmount));
   if(EnableLangCard)
    MDFNMP_RegSearchable(0x10000, 16384);
  }

  //
  // Firmware
  //
  {
   auto const& fwov_cfg = mai_cfg["firmware.override"];

   if(fwov_cfg.size() > 1)
    LoadROM_Custom(1, gf->vfs, gf->dir, fwov_cfg[1]);
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

   gameid_hasher.process(ROM12K[1], 0x3000);
  }

  //
  // ROM card
  //
  EnableROMCard = false;
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
  assert(MDFNGameInfo->DesiredInput.size() == 0 || mai_load);
  //
  //
  //
  for(unsigned A = 0; A < 0xC000; A++)
  {
   if(RAMPresent[A >> 12])
    SetRWHandlers(A, ReadRAM48K, WriteRAM48K);
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
  if(EnableLangCard)
  {
   for(unsigned A = 0xC080; A < 0xC08F; A++)
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
    for(unsigned A = 0xC080; A < 0xC08F; A++)
     SetRWHandlers(A, RWROMCardControl, RWROMCardControl);
   }

   for(unsigned A = 0xD000; A < 0x10000; A++)
   {
    SetReadHandler(A, ReadROM);
   }
  }

  PrevResetHeld = false;

  Video::Init();
  KBIO::Init();
  GameIO::Init(gio_resistance);
  Sound::Init();

  DBG::Init();
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
   Disk2::FloppyDisk* disk = &Disks[i];
   const bool wp_save = disk->write_protect;
   char ext[64];
   snprintf(ext, sizeof(ext), "%u.afd.gz", (unsigned)i);

   try
   {
    GZFileStream gfp(MDFN_MakeFName(MDFNMKF_SAV, 0, ext), GZFileStream::MODE::READ);

    *disk = Disk2::FloppyDisk();
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
  if(Disk2::GetEverModified(&Disks[i]))
  {
   char ext[64];
   snprintf(ext, sizeof(ext), "%u.afd.gz", (unsigned)i);
   //
   try
   {
    GZFileStream gfp(MDFN_MakeFName(MDFNMKF_SAV, 0, ext), GZFileStream::MODE::WRITE);

    Disk2::SaveDisk(&gfp, &Disks[i]);

    gfp.close();
   }
   catch(std::exception& e)
   {
    MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
   }
  }
 }
 //Disk2::AnalyzeDisk(&Disks[0]);
 //abort();

 //
 //
 //
 Cleanup();
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] = 
 {
  SFVAR(RAM48K),

  SFVAR(ROMSelect),

  SFVAR(LangRAM),
  SFVAR(LangRAMReadEnable),
  SFVAR(LangRAMWriteEnable),
  SFVAR(LangRAMPrevA1),
  SFVAR(LangBank2Select),

  SFVAR(SoftSwitch),

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

   Disk2::StateAction_Disk(sm, load, data_only, &Disks[i], disk_sname);
  }
 }
}

static MDFN_COLD uint8 CheatMemRead(uint32 A)
{
 uint8 ret = 0;

 if(A < 0xC000)
 {
  if(RAMPresent[A >> 12])
   ret = RAM48K[A];
 }
 else if(A >= 0x10000 && A <= 0x13FFF)
 {
  if(EnableLangCard)
   ret = LangRAM[A & 0x3FFF];
 }

 return ret;
}

static MDFN_COLD void CheatMemWrite(uint32 A, uint8 V)
{
 //printf("%04x %02x\n", A, V);

 if(A < 0xC000)
 {
  if(RAMPresent[A >> 12])
   RAM48K[A] = V;
 }
 else if(A >= 0x10000 && A <= 0x13FFF)
 {
  if(EnableLangCard)
   LangRAM[A & 0x3FFF] = V;
 }
}

static MDFN_COLD void SetInput(unsigned port, const char* type, uint8* ptr)
{
 if(port == 2)
  KBIO::KBInputPtr = ptr;
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
  Disk2::SetDisk(drive_idx, &Disks[media_idx]);
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

 { "keyboard", "Keyboard", KBIO::InputDeviceInfoA2KBPort, "twopiece" },
};

#if 0
static const std::vector<InputPortInfoStruct> A2EPortInfo =
{
 { "keyboard", "Keyboard", InputDeviceInfoA2EKBPort, "standard" },
};
#endif

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
 { "rgb", Video::Settings::MODE_RGB, "RGB", gettext_noop("Internal video dimensions of 292x192; suitable for use with scalers like hq2x.") },
 { "rgb_tfr", Video::Settings::MODE_RGB_TFR, "RGB, with HGR text fringe reduction.", gettext_noop("Internal video dimensions of 292x192; suitable for use with scalers like hq2x.  Reduced brightness of colored pixels horizontally sandwiched between white pixels in HGR mode.") },

 { "rgb_alt", Video::Settings::MODE_RGB_ALT, "RGB (alternate algorithm)", gettext_noop("Internal video dimensions of 584x192.") },
 { "rgb_alt_tfr", Video::Settings::MODE_RGB_ALT_TFR, "RGB (alternate algorithm), with HGR text fringe reduction.", gettext_noop("Internal video dimensions of 584x192.    Reduced brightness of colored pixels horizontally sandwiched between white pixels in HGR mode.") },

 // Backwards compatibility:
 { "rgb_alt1", Video::Settings::MODE_RGB_ALT },
 { "rgb_alt2", Video::Settings::MODE_RGB_ALT_TFR },

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
 { "dos", APPLE2_DBG_DOS,		gettext_noop("DOS") },

 { NULL, 0 }
};
#endif

static const MDFNSetting Settings[] =
{
 { "apple2.video.hue",		MDFNSF_CAT_VIDEO, gettext_noop("Color video hue/tint."),   nullptr, MDFNST_FLOAT, "0.0", "-1.0", "1.0", nullptr, VideoChangeNotif },
 { "apple2.video.saturation",	MDFNSF_CAT_VIDEO, gettext_noop("Color video saturation."), nullptr, MDFNST_FLOAT, "0.0", "-1.0", "1.0", nullptr, VideoChangeNotif  },
 { "apple2.video.contrast",	MDFNSF_CAT_VIDEO, gettext_noop("Video contrast."), nullptr, MDFNST_FLOAT, "0.0", "-1.0", "1.0", nullptr, VideoChangeNotif  },
 { "apple2.video.brightness",	MDFNSF_CAT_VIDEO, gettext_noop("Video brightness."), nullptr, MDFNST_FLOAT, "0.0", "-1.0", "1.0", nullptr, VideoChangeNotif  },
 { "apple2.video.force_mono",   MDFNSF_CAT_VIDEO, gettext_noop("Force monochrome graphics color."), gettext_noop("Force monochrome graphics if non-zero, with the specified color."), MDFNST_UINT, "0x000000", "0x000000", "0xFFFFFF", nullptr, VideoChangeNotif  },
 { "apple2.video.mixed_text_mono",MDFNSF_CAT_VIDEO,gettext_noop("Enable hack to treat mixed-mode text as monochrome."), nullptr, MDFNST_BOOL, "0", nullptr, nullptr, nullptr, VideoChangeNotif },
 { "apple2.video.mono_lumafilter",MDFNSF_CAT_VIDEO,gettext_noop("Monochrome video luma filter."), gettext_noop("Filters numbered closer to 0 have a stronger lowpass effect.  Negative-numbered filters have ringing."), MDFNST_INT, "5", "-3", "7", nullptr, VideoChangeNotif  },
 { "apple2.video.color_lumafilter",MDFNSF_CAT_VIDEO,gettext_noop("Color video luma filter."), gettext_noop("Filters numbered closer to 0 have a stronger lowpass effect.  Negative-numbered filters have ringing."), MDFNST_INT, "-3", "-3", "3", nullptr, VideoChangeNotif  },
 { "apple2.video.color_smooth",	MDFNSF_CAT_VIDEO, gettext_noop("Enable color video smoothing."), gettext_noop("Reduces vertical stripes without making video blurrier, at the cost of some pixel irregularities.  May make small text illegible in graphics mode."), MDFNST_BOOL, "0", nullptr, nullptr, nullptr, VideoChangeNotif  },

 { "apple2.video.matrix", MDFNSF_CAT_VIDEO, gettext_noop("Color decoder matrix."), gettext_noop("The matrixes that correspond to the nominal demodulation angles and gains for various ICs are intended to get colors within the ballpark of what consumer-oriented NTSC TVs would display, and won't exactly replicate the colors these ICs would reproduce when fed an Apple II video signal."), MDFNST_ENUM, "mednafen", nullptr, nullptr, nullptr, VideoChangeNotif, Matrix_List },

 { "apple2.video.matrix.red.i", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; red, I."), gettext_noop("Only used if \"apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "0.96", "-4.00", "4.00", nullptr, VideoChangeNotif  },
 { "apple2.video.matrix.red.q", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; red, Q."), gettext_noop("Only used if \"apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "0.62", "-4.00", "4.00", nullptr, VideoChangeNotif  },

 { "apple2.video.matrix.green.i", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; green, I."), gettext_noop("Only used if \"apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "-0.28", "-4.00", "4.00", nullptr, VideoChangeNotif  },
 { "apple2.video.matrix.green.q", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; green, Q."), gettext_noop("Only used if \"apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "-0.64", "-4.00", "4.00", nullptr, VideoChangeNotif  },

 { "apple2.video.matrix.blue.i", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; blue, I."), gettext_noop("Only used if \"apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "-1.11", "-4.00", "4.00", nullptr, VideoChangeNotif  },
 { "apple2.video.matrix.blue.q", MDFNSF_CAT_VIDEO, gettext_noop("Custom color decoder matrix; blue, Q."), gettext_noop("Only used if \"apple2.video.matrix\" is set to \"custom\"."), MDFNST_FLOAT, "1.70", "-4.00", "4.00", nullptr, VideoChangeNotif  },

 { "apple2.video.mode", MDFNSF_CAT_VIDEO, gettext_noop("Video rendering mode."), gettext_noop("When an RGB mode is enabled, settings \"apple2.video.force_mono\", \"apple2.video.mixed_text_mono\", \"apple2.video.mono_lumafilter\", \"apple2.video.color_lumafilter\", and \"apple2.video.color_smooth\" are effectively ignored."), MDFNST_ENUM, "composite", nullptr, nullptr, nullptr, VideoChangeNotif, Mode_List },

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
 { gettext_noop("RGB mode 16-color(or 32-color for TFR) palette.  The presence of a custom palette will automatically enable RGB video mode if an RGB mode is not already selected via the \"apple2.video.mode\" setting.  If the palette has 32 color entries, the text fringe reduction variant of an RGB mode is enabled."), NULL, { 16, 32, 0 } },

 { NULL, NULL }
};

}

using namespace MDFN_IEN_APPLE2;

MDFN_HIDE extern const MDFNGI EmulatedApple2 =
{
 "apple2",
 "Apple II/II+",
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
 nullptr, //TransformInput,
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

