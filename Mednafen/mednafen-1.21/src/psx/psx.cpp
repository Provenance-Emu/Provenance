/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* psx.cpp:
**  Copyright (C) 2011-2017 Mednafen Team
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

#include "psx.h"
#include "mdec.h"
#include "frontio.h"
#include "timer.h"
#include "sio.h"
#include "cdc.h"
#include "spu.h"
#include <mednafen/FileStream.h>
#include <mednafen/mempatcher.h>
#include <mednafen/PSFLoader.h>
#include <mednafen/player.h>
#include <mednafen/hash/sha256.h>
#include <mednafen/cheat_formats/psx.h>

#include <zlib.h>

extern MDFNGI EmulatedPSX;

namespace MDFN_IEN_PSX
{

#if PSX_DBGPRINT_ENABLE
static unsigned psx_dbg_level = 0;

void PSX_DBG_BIOS_PUTC(uint8 c) noexcept
{
 if(psx_dbg_level >= PSX_DBG_BIOS_PRINT)
 {
  if(c == 0x1B)
   return;

  fputc(c, stdout);

  //if(c == '\n')
  //{
  // fputc('%', stdout);
  // fputc(' ', stdout);
  //}
  fflush(stdout);
 }
}

void PSX_DBG(unsigned level, const char *format, ...) noexcept
{
 if(psx_dbg_level >= level)
 {
  va_list ap;

  va_start(ap, format);

  trio_vprintf(format, ap);

  va_end(ap);
 }
}
#else
static unsigned const psx_dbg_level = 0;
#endif


struct MDFN_PseudoRNG	// Based off(but not the same as) public-domain "JKISS" PRNG.
{
 MDFN_COLD MDFN_PseudoRNG()
 {
  ResetState();
 }

 uint32 RandU32(void)
 {
  uint64 t;

  x = 314527869 * x + 1234567;
  y ^= y << 5; y ^= y >> 7; y ^= y << 22;
  t = 4294584393ULL * z + c; c = t >> 32; z = t;
  lcgo = (19073486328125ULL * lcgo) + 1;

  return (x + y + z) ^ (lcgo >> 16);
 }

 uint32 RandU32(uint32 mina, uint32 maxa)
 {
  const uint32 range_m1 = maxa - mina;
  uint32 range_mask;
  uint32 tmp;

  range_mask = range_m1;
  range_mask |= range_mask >> 1;
  range_mask |= range_mask >> 2;
  range_mask |= range_mask >> 4;
  range_mask |= range_mask >> 8;
  range_mask |= range_mask >> 16;

  do
  {
   tmp = RandU32() & range_mask;
  } while(tmp > range_m1);
 
  return(mina + tmp);
 }

 MDFN_COLD void ResetState(void)	// Must always reset to the same state.
 {
  x = 123456789;
  y = 987654321;
  z = 43219876;
  c = 6543217;
  lcgo = 0xDEADBEEFCAFEBABEULL;
 }

 uint32 x,y,z,c;
 uint64 lcgo;
};

static MDFN_PseudoRNG PSX_PRNG;

uint32 PSX_GetRandU32(uint32 mina, uint32 maxa)
{
 return PSX_PRNG.RandU32(mina, maxa);
}


class PSF1Loader : public PSFLoader
{
 public:

 PSF1Loader(Stream *fp) MDFN_COLD;
 virtual ~PSF1Loader() override MDFN_COLD;

 virtual void HandleEXE(Stream* fp, bool ignore_pcsp = false) override MDFN_COLD;

 PSFTags tags;
};

enum
{
 REGION_JP = 0,
 REGION_NA = 1,
 REGION_EU = 2,
};

static const MDFNSetting_EnumList Region_List[] =
{
 { "jp", REGION_JP, gettext_noop("Japan") },
 { "na", REGION_NA, gettext_noop("North America") },
 { "eu", REGION_EU, gettext_noop("Europe") },
 { NULL, 0 },
};

static const struct
{
 const char* version;
 char hwrev;		// Ostensibly, not sure where this information originally came from or if it has any use(considering it doesn't reflect all hardware changes).
 unsigned region;
 bool bad;
 sha256_digest sd;
} BIOS_DB[] =
{
 // 1.0J, 2.2D, 4.1A(W):
 //  Tolerant with regards to ISO-9660 system-area contents
 //

 { "1.0J", 'A', REGION_JP, false, "cfc1fc38eb442f6f80781452119e931bcae28100c1c97e7e6c5f2725bbb0f8bb"_sha256 },

 { "1.1J", 'B', REGION_JP, false, "5eb3aee495937558312b83b54323d76a4a015190decd4051214f1b6df06ac34b"_sha256 },

 { "2.0A", 'X', REGION_NA, false, "42e4124be7623e2e28b1db0d8d426539646faee49d74b71166d8ba5bd7c472ed"_sha256 },	// DTL
 { "2.0E", 'B', REGION_EU, false, "0af2be3468d30b6018b3c3b0d98b8b64347e255e16d874d55f0363648973dbf0"_sha256 },

 { "2.1J", 'B', REGION_JP, false, "6f71ca1e716da761dc53187bd39e00c213f566e55090708fd3e2b4b425c8c989"_sha256 },
 { "2.1A", 'X', REGION_NA, false, "6ad5521d105a6b86741f1af8da2e6ea1c732d34459940618c70305a105e8ec10"_sha256 },	// DTL
 { "2.1E", 'B', REGION_EU, false, "1efb0cfc5db8a8751a884c5312e9c6265ca1bc580dc0c2663eb2dea3bde9fcf7"_sha256 },

 { "2.2J", 'B', REGION_JP, false, "0c8359870cbac0ea091f1c87f188cd332dcc709753b91cafd9fd44a4a6188197"_sha256 },
 { "2.2J", 'B', REGION_JP, true,  "8e0383171e67b33e60d5df6394c58843f3b11c7a0b97f3bfcc4319ac2d1f9d18"_sha256 },	// BAD! ! ! !
 { "2.2A", 'B', REGION_NA, false, "71af94d1e47a68c11e8fdb9f8368040601514a42a5a399cda48c7d3bff1e99d3"_sha256 },
 { "2.2E", 'B', REGION_EU, false, "3d06d2c469313c2a2128d24fe2e0c71ff99bc2032be89a829a62337187f500b7"_sha256 },
 { "2.2D", 'X', REGION_JP, false, "4018749b3698b8694387beebcbabfb48470513066840f9441459ee4c9f0f39bc"_sha256 },	// DTL

 { "3.0J", 'C', REGION_JP, false, "9c0421858e217805f4abe18698afea8d5aa36ff0727eb8484944e00eb5e7eadb"_sha256 },
 { "3.0A", 'C', REGION_NA, false, "11052b6499e466bbf0a709b1f9cb6834a9418e66680387912451e971cf8a1fef"_sha256 },
 { "3.0E", 'C', REGION_EU, false, "1faaa18fa820a0225e488d9f086296b8e6c46df739666093987ff7d8fd352c09"_sha256 },
 { "3.0E", 'C', REGION_EU, true,  "9e1f8fb4fa356a5ac29d7c7209626dcc1b3038c0e5a85b0e99d1db96926647ca"_sha256 },	// BAD! ! ! !

 { "4.0J", 'C', REGION_JP, false, "e900504d1755f021f861b82c8258c5e6658c7b592f800cccd91f5d32ea380d28"_sha256 },

 { "4.1A(W)",'C',REGION_JP,false, "b3aa63cf30c81e0a40641740f4a43e25fda0b21b792fa9aaef60ce1675761479"_sha256 },	// Weird
 { "4.1A", 'C', REGION_NA, false, "39dcc1a0717036c9b6ac52fefd1ee7a57d3808e8cfbc755879fa685a0a738278"_sha256 },
 { "4.1E", 'C', REGION_EU, false, "5e84a94818cf5282f4217591fefd88be36b9b174b3cc7cb0bcd75199beb450f1"_sha256 },

 { "4.3J", 'C', REGION_JP, false, "b29b4b5fcddef369bd6640acacda0865e0366fcf7ea54e40b2f1a8178004f89a"_sha256},

 { "4.4E", 'C', REGION_EU, false, "5c0166da24e27deaa82246de8ff0108267fe4bb59f6df0fdec50e05e62448ca4"_sha256 },
 
 { "4.5A", 'C', REGION_NA, false, "aca9cbfa974b933646baad6556a867eca9b81ce65d8af343a7843f7775b9ffc8"_sha256 },
 { "4.5E", 'C', REGION_EU, false, "42244b0c650821519751b7e77ad1d3222a0125e75586df2b4e84ba693b9809dc"_sha256 },
};

static sha256_digest BIOS_SHA256;	// SHA-256 hash of the currently-loaded BIOS; used for save state sanity checks.
static PSF1Loader *psf_loader = NULL;
static std::vector<CDIF*> *cdifs = NULL;
static std::vector<const char *> cdifs_scex_ids;

static uint64 Memcard_PrevDC[8];
static int64 Memcard_SaveDelay[8];

PS_CPU *CPU = NULL;
PS_SPU *SPU = NULL;
PS_CDC *CDC = NULL;
FrontIO *FIO = NULL;

static MultiAccessSizeMem<512 * 1024, false> *BIOSROM = NULL;
static MultiAccessSizeMem<65536, false> *PIOMem = NULL;

MultiAccessSizeMem<2048 * 1024, false> MainRAM;

static uint32 TextMem_Start;
static std::vector<uint8> TextMem;

static const uint32 SysControl_Mask[9] = { 0x00ffffff, 0x00ffffff, 0xffffffff, 0x2f1fffff,
					   0xffffffff, 0x2f1fffff, 0x2f1fffff, 0xffffffff,
					   0x0003ffff };

static const uint32 SysControl_OR[9] = { 0x1f000000, 0x1f000000, 0x00000000, 0x00000000,
					 0x00000000, 0x00000000, 0x00000000, 0x00000000,
					 0x00000000 };

static struct
{
 union
 {
  struct
  {
   uint32 PIO_Base;	// 0x1f801000	// BIOS Init: 0x1f000000, Writeable bits: 0x00ffffff(assumed, verify), FixedOR = 0x1f000000
   uint32 Unknown0;	// 0x1f801004	// BIOS Init: 0x1f802000, Writeable bits: 0x00ffffff, FixedOR = 0x1f000000
   uint32 Unknown1;	// 0x1f801008	// BIOS Init: 0x0013243f, ????
   uint32 Unknown2;	// 0x1f80100c	// BIOS Init: 0x00003022, Writeable bits: 0x2f1fffff, FixedOR = 0x00000000
   
   uint32 BIOS_Mapping;	// 0x1f801010	// BIOS Init: 0x0013243f, ????
   uint32 SPU_Delay;	// 0x1f801014	// BIOS Init: 0x200931e1, Writeable bits: 0x2f1fffff, FixedOR = 0x00000000 - Affects bus timing on access to SPU
   uint32 CDC_Delay;	// 0x1f801018	// BIOS Init: 0x00020843, Writeable bits: 0x2f1fffff, FixedOR = 0x00000000
   uint32 Unknown4;	// 0x1f80101c	// BIOS Init: 0x00070777, ????
   uint32 Unknown5;	// 0x1f801020	// BIOS Init: 0x00031125(but rewritten with other values often), Writeable bits: 0x0003ffff, FixedOR = 0x00000000 -- Possibly CDC related
  };
  uint32 Regs[9];
 };
} SysControl;

static unsigned DMACycleSteal = 0;	// Doesn't need to be saved in save states, since it's recalculated in the ForceEventUpdates() call chain.

void PSX_SetDMACycleSteal(unsigned stealage)
{
 if(stealage > 200)	// Due to 8-bit limitations in the CPU core.
  stealage = 200;

 DMACycleSteal = stealage;
}


//
// Event stuff
//

static pscpu_timestamp_t Running;	// Set to -1 when not desiring exit, and 0 when we are.

struct event_list_entry
{
 uint32 which;
 pscpu_timestamp_t event_time;
 event_list_entry *prev;
 event_list_entry *next;
};

static event_list_entry events[PSX_EVENT__COUNT];

static void EventReset(void)
{
 for(unsigned i = 0; i < PSX_EVENT__COUNT; i++)
 {
  events[i].which = i;

  if(i == PSX_EVENT__SYNFIRST)
   events[i].event_time = (int32)0x80000000;
  else if(i == PSX_EVENT__SYNLAST)
   events[i].event_time = 0x7FFFFFFF;
  else
   events[i].event_time = PSX_EVENT_MAXTS;

  events[i].prev = (i > 0) ? &events[i - 1] : NULL;
  events[i].next = (i < (PSX_EVENT__COUNT - 1)) ? &events[i + 1] : NULL;
 }
}

//static void RemoveEvent(event_list_entry *e)
//{
// e->prev->next = e->next;
// e->next->prev = e->prev;
//}

static void RebaseTS(const pscpu_timestamp_t timestamp)
{
 for(unsigned i = 0; i < PSX_EVENT__COUNT; i++)
 {
  if(i == PSX_EVENT__SYNFIRST || i == PSX_EVENT__SYNLAST)
   continue;

  assert(events[i].event_time > timestamp);
  events[i].event_time -= timestamp;
 }

 CPU->SetEventNT(events[PSX_EVENT__SYNFIRST].next->event_time);
}

void PSX_SetEventNT(const int type, const pscpu_timestamp_t next_timestamp)
{
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

 CPU->SetEventNT(events[PSX_EVENT__SYNFIRST].next->event_time & Running);
}

// Called from debug.cpp too.
void ForceEventUpdates(const pscpu_timestamp_t timestamp)
{
 PSX_SetEventNT(PSX_EVENT_GPU, GPU_Update(timestamp));
 PSX_SetEventNT(PSX_EVENT_CDC, CDC->Update(timestamp));

 PSX_SetEventNT(PSX_EVENT_TIMER, TIMER_Update(timestamp));

 PSX_SetEventNT(PSX_EVENT_DMA, DMA_Update(timestamp));

 PSX_SetEventNT(PSX_EVENT_FIO, FIO->Update(timestamp));

 CPU->SetEventNT(events[PSX_EVENT__SYNFIRST].next->event_time);
}

bool MDFN_FASTCALL PSX_EventHandler(const pscpu_timestamp_t timestamp)
{
 event_list_entry *e = events[PSX_EVENT__SYNFIRST].next;

 while(timestamp >= e->event_time)	// If Running = 0, PSX_EventHandler() may be called even if there isn't an event per-se, so while() instead of do { ... } while
 {
  event_list_entry *prev = e->prev;
  pscpu_timestamp_t nt;

  switch(e->which)
  {
   default: abort();

   case PSX_EVENT_GPU:
	nt = GPU_Update(e->event_time);
	break;

   case PSX_EVENT_CDC:
	nt = CDC->Update(e->event_time);
	break;

   case PSX_EVENT_TIMER:
	nt = TIMER_Update(e->event_time);
	break;

   case PSX_EVENT_DMA:
	nt = DMA_Update(e->event_time);
	break;

   case PSX_EVENT_FIO:
	nt = FIO->Update(e->event_time);
	break;
  }
#if PSX_EVENT_SYSTEM_CHECKS
  assert(nt > e->event_time);
#endif

  PSX_SetEventNT(e->which, nt);

  // Order of events can change due to calling PSX_SetEventNT(), this prev business ensures we don't miss an event due to reordering.
  e = prev->next;
 }

 return(Running);
}


void PSX_RequestMLExit(void)
{
 Running = 0;
 CPU->SetEventNT(0);
}


//
// End event stuff
//

// Remember to update MemPeek<>() and MemPoke<>() when we change address decoding in MemRW()
template<typename T, bool IsWrite, bool Access24> static INLINE void MemRW(pscpu_timestamp_t &timestamp, uint32 A, uint32 &V)
{
 #if 0
 if(IsWrite)
  printf("Write%d: %08x(orig=%08x), %08x\n", (int)(sizeof(T) * 8), A & mask[A >> 29], A, V);
 else
  printf("Read%d: %08x(orig=%08x)\n", (int)(sizeof(T) * 8), A & mask[A >> 29], A);
 #endif

 if(!IsWrite)
  timestamp += DMACycleSteal;

 if(A < 0x00800000)
 {
  if(IsWrite)
  {
   //timestamp++;	// Best-case timing.
  }
  else
  {
   timestamp += 3;
  }

  if(Access24)
  {
   if(IsWrite)
    MainRAM.WriteU24(A & 0x1FFFFF, V);
   else
    V = MainRAM.ReadU24(A & 0x1FFFFF);
  }
  else
  {
   if(IsWrite)
    MainRAM.Write<T>(A & 0x1FFFFF, V);
   else
    V = MainRAM.Read<T>(A & 0x1FFFFF);
  }

  return;
 }

 if(A >= 0x1FC00000 && A <= 0x1FC7FFFF)
 {
  if(!IsWrite)
  {
   if(Access24)
    V = BIOSROM->ReadU24(A & 0x7FFFF);
   else
    V = BIOSROM->Read<T>(A & 0x7FFFF);
  }

  return;
 }

 if(timestamp >= events[PSX_EVENT__SYNFIRST].next->event_time)
  PSX_EventHandler(timestamp);

 if(A >= 0x1F801000 && A <= 0x1F802FFF)
 {
  //if(IsWrite)
  // printf("HW Write%d: %08x %08x\n", (unsigned int)(sizeof(T)*8), (unsigned int)A, (unsigned int)V);
  //else
  // printf("HW Read%d: %08x\n", (unsigned int)(sizeof(T)*8), (unsigned int)A);

  if(A >= 0x1F801C00 && A <= 0x1F801FFF) // SPU
  {
   if(sizeof(T) == 4 && !Access24)
   {
    if(IsWrite)
    {
     //timestamp += 15;

     //if(timestamp >= events[PSX_EVENT__SYNFIRST].next->event_time)
     // PSX_EventHandler(timestamp);

     SPU->Write(timestamp, A | 0, V);
     SPU->Write(timestamp, A | 2, V >> 16);
    }
    else
    {
     timestamp += 36;

     if(timestamp >= events[PSX_EVENT__SYNFIRST].next->event_time)
      PSX_EventHandler(timestamp);

     V = SPU->Read(timestamp, A);
     V |= SPU->Read(timestamp, A | 2) << 16;
    }
   }
   else
   {
    if(IsWrite)
    {
     //timestamp += 8;

     //if(timestamp >= events[PSX_EVENT__SYNFIRST].next->event_time)
     // PSX_EventHandler(timestamp);

     SPU->Write(timestamp, A & ~1, V);
    }
    else
    {
     timestamp += 16; // Just a guess, need to test.

     if(timestamp >= events[PSX_EVENT__SYNFIRST].next->event_time)
      PSX_EventHandler(timestamp);

     V = SPU->Read(timestamp, A & ~1);
    }
   }
   return;
  }		// End SPU


  // CDC: TODO - 8-bit access.
  if(A >= 0x1f801800 && A <= 0x1f80180F)
  {
   if(!IsWrite) 
   {
    timestamp += 6 * sizeof(T); //24;
   }

   if(IsWrite)
    CDC->Write(timestamp, A & 0x3, V);
   else
    V = CDC->Read(timestamp, A & 0x3);

   return;
  }

  if(A >= 0x1F801810 && A <= 0x1F801817)
  {
   if(!IsWrite)
    timestamp++;

   if(IsWrite)
    GPU_Write(timestamp, A, V);
   else
    V = GPU_Read(timestamp, A);

   return;
  }

  if(A >= 0x1F801820 && A <= 0x1F801827)
  {
   if(!IsWrite)
    timestamp++;

   if(IsWrite)
    MDEC_Write(timestamp, A, V);
   else
    V = MDEC_Read(timestamp, A);

   return;
  }

  if(A >= 0x1F801000 && A <= 0x1F801023)
  {
   unsigned index = (A & 0x1F) >> 2;

   if(!IsWrite)
    timestamp++;

   //if(A == 0x1F801014 && IsWrite)
   // fprintf(stderr, "%08x %08x\n",A,V);

   if(IsWrite)
   {
    V <<= (A & 3) * 8;
    SysControl.Regs[index] = V & SysControl_Mask[index];
   }
   else
   {
    V = SysControl.Regs[index] | SysControl_OR[index];
    V >>= (A & 3) * 8;
   }
   return;
  }

  if(A >= 0x1F801040 && A <= 0x1F80104F)
  {
   if(!IsWrite)
    timestamp++;

   if(IsWrite)
    FIO->Write(timestamp, A, V);
   else
    V = FIO->Read(timestamp, A);
   return;
  }

  if(A >= 0x1F801050 && A <= 0x1F80105F)
  {
   if(!IsWrite)
    timestamp++;

#if 0
   if(IsWrite)
   {
    PSX_WARNING("[SIO] Write: 0x%08x 0x%08x %u", A, V, (unsigned)sizeof(T));
   }
   else
   {
    PSX_WARNING("[SIO] Read: 0x%08x", A);
   }
#endif

   if(IsWrite)
    SIO_Write(timestamp, A, V);
   else
    V = SIO_Read(timestamp, A);
   return;
  }

#if 0
  if(A >= 0x1F801060 && A <= 0x1F801063)
  {
   if(IsWrite)
   {

   }
   else
   {

   }

   return;
  }
#endif

  if(A >= 0x1F801070 && A <= 0x1F801077)	// IRQ
  {
   if(!IsWrite)
    timestamp++;

   if(IsWrite)
    IRQ_Write(A, V);
   else
    V = IRQ_Read(A);
   return;
  }

  if(A >= 0x1F801080 && A <= 0x1F8010FF) 	// DMA
  {
   if(!IsWrite)
    timestamp++;

   if(IsWrite)
    DMA_Write(timestamp, A, V);
   else
    V = DMA_Read(timestamp, A);

   return;
  }

  if(A >= 0x1F801100 && A <= 0x1F80113F)	// Root counters
  {
   if(!IsWrite)
    timestamp++;

   if(IsWrite)
    TIMER_Write(timestamp, A, V);
   else
    V = TIMER_Read(timestamp, A);

   return;
  }
 }


 if(A >= 0x1F000000 && A <= 0x1F7FFFFF)
 {
  if(!IsWrite)
  {
   //if((A & 0x7FFFFF) <= 0x84)
   //PSX_WARNING("[PIO] Read%d from 0x%08x at time %d", (int)(sizeof(T) * 8), A, timestamp);

   V = ~0U;	// A game this affects:  Tetris with Cardcaptor Sakura

   if(PIOMem)
   {
    if((A & 0x7FFFFF) < 65536)
    {
     if(Access24)
      V = PIOMem->ReadU24(A & 0x7FFFFF);
     else
      V = PIOMem->Read<T>(A & 0x7FFFFF);
    }
    else if((A & 0x7FFFFF) < (65536 + TextMem.size()))
    {
     if(Access24)
      V = MDFN_de24lsb(&TextMem[(A & 0x7FFFFF) - 65536]);
     else switch(sizeof(T))
     {
      case 1: V = TextMem[(A & 0x7FFFFF) - 65536]; break;
      case 2: V = MDFN_de16lsb(&TextMem[(A & 0x7FFFFF) - 65536]); break;
      case 4: V = MDFN_de32lsb(&TextMem[(A & 0x7FFFFF) - 65536]); break;
     }
    }
   }
  }
  return;
 }

 if(A == 0xFFFE0130) // Per tests on PS1, ignores the access(sort of, on reads the value is forced to 0 if not aligned) if not aligned to 4-bytes.
 {
  if(!IsWrite)
   V = CPU->GetBIU();
  else
   CPU->SetBIU(V);

  return;
 }

 if(IsWrite)
 {
  PSX_WARNING("[MEM] Unknown write%d to %08x at time %d, =%08x(%d)", (int)(sizeof(T) * 8), A, timestamp, V, V);
 }
 else
 {
  V = 0;
  PSX_WARNING("[MEM] Unknown read%d from %08x at time %d", (int)(sizeof(T) * 8), A, timestamp);
 }
}

void MDFN_FASTCALL PSX_MemWrite8(pscpu_timestamp_t timestamp, uint32 A, uint32 V)
{
 MemRW<uint8, true, false>(timestamp, A, V);
}

void MDFN_FASTCALL PSX_MemWrite16(pscpu_timestamp_t timestamp, uint32 A, uint32 V)
{
 MemRW<uint16, true, false>(timestamp, A, V);
}

void MDFN_FASTCALL PSX_MemWrite24(pscpu_timestamp_t timestamp, uint32 A, uint32 V)
{
 MemRW<uint32, true, true>(timestamp, A, V);
}

void MDFN_FASTCALL PSX_MemWrite32(pscpu_timestamp_t timestamp, uint32 A, uint32 V)
{
 MemRW<uint32, true, false>(timestamp, A, V);
}

uint8 MDFN_FASTCALL PSX_MemRead8(pscpu_timestamp_t &timestamp, uint32 A)
{
 uint32 V;

 MemRW<uint8, false, false>(timestamp, A, V);

 return(V);
}

uint16 MDFN_FASTCALL PSX_MemRead16(pscpu_timestamp_t &timestamp, uint32 A)
{
 uint32 V;

 MemRW<uint16, false, false>(timestamp, A, V);

 return(V);
}

uint32 MDFN_FASTCALL PSX_MemRead24(pscpu_timestamp_t &timestamp, uint32 A)
{
 uint32 V;

 MemRW<uint32, false, true>(timestamp, A, V);

 return(V);
}

uint32 MDFN_FASTCALL PSX_MemRead32(pscpu_timestamp_t &timestamp, uint32 A)
{
 uint32 V;

 MemRW<uint32, false, false>(timestamp, A, V);

 return(V);
}

template<typename T, bool Access24> static INLINE uint32 MemPeek(pscpu_timestamp_t timestamp, uint32 A)
{
 if(A < 0x00800000)
 {
  if(Access24)
   return(MainRAM.ReadU24(A & 0x1FFFFF));
  else
   return(MainRAM.Read<T>(A & 0x1FFFFF));
 }

 if(A >= 0x1FC00000 && A <= 0x1FC7FFFF)
 {
  if(Access24)
   return(BIOSROM->ReadU24(A & 0x7FFFF));
  else
   return(BIOSROM->Read<T>(A & 0x7FFFF));
 }

 if(A >= 0x1F801000 && A <= 0x1F802FFF)
 {
  if(A >= 0x1F801C00 && A <= 0x1F801FFF) // SPU
  {
   // TODO

  }		// End SPU


  // CDC: TODO - 8-bit access.
  if(A >= 0x1f801800 && A <= 0x1f80180F)
  {
   // TODO

  }

  if(A >= 0x1F801810 && A <= 0x1F801817)
  {
   // TODO

  }

  if(A >= 0x1F801820 && A <= 0x1F801827)
  {
   // TODO

  }

  if(A >= 0x1F801000 && A <= 0x1F801023)
  {
   unsigned index = (A & 0x1F) >> 2;
   return((SysControl.Regs[index] | SysControl_OR[index]) >> ((A & 3) * 8));
  }

  if(A >= 0x1F801040 && A <= 0x1F80104F)
  {
   // TODO

  }

  if(A >= 0x1F801050 && A <= 0x1F80105F)
  {
   // TODO

  }


  if(A >= 0x1F801070 && A <= 0x1F801077)	// IRQ
  {
   // TODO

  }

  if(A >= 0x1F801080 && A <= 0x1F8010FF) 	// DMA
  {
   // TODO

  }

  if(A >= 0x1F801100 && A <= 0x1F80113F)	// Root counters
  {
   // TODO

  }
 }


 if(A >= 0x1F000000 && A <= 0x1F7FFFFF)
 {
  if(PIOMem)
  {
   if((A & 0x7FFFFF) < 65536)
   {
    if(Access24)
     return(PIOMem->ReadU24(A & 0x7FFFFF));
    else
     return(PIOMem->Read<T>(A & 0x7FFFFF));
   }
   else if((A & 0x7FFFFF) < (65536 + TextMem.size()))
   {
    if(Access24)
     return(MDFN_de24lsb(&TextMem[(A & 0x7FFFFF) - 65536]));
    else switch(sizeof(T))
    {
     case 1: return(TextMem[(A & 0x7FFFFF) - 65536]); break;
     case 2: return(MDFN_de16lsb(&TextMem[(A & 0x7FFFFF) - 65536])); break;
     case 4: return(MDFN_de32lsb(&TextMem[(A & 0x7FFFFF) - 65536])); break;
    }
   }
  }
  return(~0U);
 }

 if(A == 0xFFFE0130)
  return CPU->GetBIU();

 return(0);
}

uint8 PSX_MemPeek8(uint32 A)
{
 return MemPeek<uint8, false>(0, A);
}

uint16 PSX_MemPeek16(uint32 A)
{
 return MemPeek<uint16, false>(0, A);
}

uint32 PSX_MemPeek32(uint32 A)
{
 return MemPeek<uint32, false>(0, A);
}

template<typename T, bool Access24> static INLINE void MemPoke(pscpu_timestamp_t timestamp, uint32 A, T V)
{
 if(A < 0x00800000)
 {
  if(Access24)
   MainRAM.WriteU24(A & 0x1FFFFF, V);
  else
   MainRAM.Write<T>(A & 0x1FFFFF, V);

  return;
 }

 if(A >= 0x1FC00000 && A <= 0x1FC7FFFF)
 {
  if(Access24)
   BIOSROM->WriteU24(A & 0x7FFFF, V);
  else
   BIOSROM->Write<T>(A & 0x7FFFF, V);

  return;
 }

 if(A >= 0x1F801000 && A <= 0x1F802FFF)
 {
  if(A >= 0x1F801000 && A <= 0x1F801023)
  {
   unsigned index = (A & 0x1F) >> 2;
   SysControl.Regs[index] = (V << ((A & 3) * 8)) & SysControl_Mask[index];
   return;
  }
 }

 if(A == 0xFFFE0130)
 {
  CPU->SetBIU(V);
  return;
 }
}

void PSX_MemPoke8(uint32 A, uint8 V)
{
 MemPoke<uint8, false>(0, A, V);
}

void PSX_MemPoke16(uint32 A, uint16 V)
{
 MemPoke<uint16, false>(0, A, V);
}

void PSX_MemPoke32(uint32 A, uint32 V)
{
 MemPoke<uint32, false>(0, A, V);
}


static void PSX_Reset(bool powering_up)
{
 PSX_PRNG.ResetState();	// Should occur first!

 memset(MainRAM.data8, 0, 2048 * 1024);

 for(unsigned i = 0; i < 9; i++)
  SysControl.Regs[i] = 0;

 CPU->Power();

 EventReset();

 TIMER_Power();

 DMA_Power();

 FIO->Reset(powering_up);
 SIO_Power();

 MDEC_Power();
 CDC->Power();
 GPU_Power();
 //SPU->Power();	// Called from CDC->Power()
 IRQ_Power();

 ForceEventUpdates(0);
}


void PSX_GPULineHook(const pscpu_timestamp_t timestamp, const pscpu_timestamp_t line_timestamp, bool vsync, uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock_offset, const unsigned pix_clock, const unsigned pix_clock_divider)
{
 FIO->GPULineHook(timestamp, line_timestamp, vsync, pixels, format, width, pix_clock_offset, pix_clock, pix_clock_divider);
}

}

using namespace MDFN_IEN_PSX;


static void Emulate(EmulateSpecStruct *espec)
{
 pscpu_timestamp_t timestamp = 0;

 if(FIO->RequireNoFrameskip())
 {
  //puts("MEOW");
  espec->skip = false;	//TODO: Save here, and restore at end of Emulate() ?
 }

 MDFNGameInfo->mouse_sensitivity = MDFN_GetSettingF("psx.input.mouse_sensitivity");

 MDFNMP_ApplyPeriodicCheats();


 espec->MasterCycles = 0;
 espec->SoundBufSize = 0;

 FIO->UpdateInput();
 GPU_StartFrame(psf_loader ? NULL : espec);
 SPU->StartFrame(espec->SoundRate, MDFN_GetSettingUI("psx.spu.resamp_quality"));

 Running = -1;
 timestamp = CPU->Run(timestamp, psf_loader == NULL && psx_dbg_level >= PSX_DBG_BIOS_PRINT, psf_loader != NULL);

 assert(timestamp);

 ForceEventUpdates(timestamp);
 if(GPU_GetScanlineNum() < 100)
  PSX_DBG(PSX_DBG_ERROR, "[BUUUUUUUG] Frame timing end glitch; scanline=%u, st=%u\n", GPU_GetScanlineNum(), timestamp);

 //printf("scanline=%u, st=%u\n", GPU_GetScanlineNum(), timestamp);

 espec->SoundBufSize = SPU->EndFrame(espec->SoundBuf, espec->NeedSoundReverse);
 espec->NeedSoundReverse = false;

 CDC->ResetTS();
 TIMER_ResetTS();
 DMA_ResetTS();
 GPU_ResetTS();
 FIO->ResetTS();

 RebaseTS(timestamp);

 espec->MasterCycles = timestamp;

 if(psf_loader)
 {
  if(!espec->skip)
  {
   espec->LineWidths[0] = ~0;
   Player_Draw(espec->surface, &espec->DisplayRect, 0, espec->SoundBuf, espec->SoundBufSize);
  }
 }

 FIO->UpdateOutput();

 // Save memcards if dirty.
 for(int i = 0; i < 8; i++)
 {
  uint64 new_dc = FIO->GetMemcardDirtyCount(i);

  if(new_dc > Memcard_PrevDC[i])
  {
   Memcard_PrevDC[i] = new_dc;
   Memcard_SaveDelay[i] = 0;
  }

  if(Memcard_SaveDelay[i] >= 0)
  {
   Memcard_SaveDelay[i] += timestamp;
   if(Memcard_SaveDelay[i] >= (33868800 * 2))	// Wait until about 2 seconds of no new writes.
   {
    PSX_DBG(PSX_DBG_SPARSE, "Saving memcard %d...\n", i);
    try
    {
     char ext[64];
     trio_snprintf(ext, sizeof(ext), "%d.mcr", i);
     FIO->SaveMemcard(i, MDFN_MakeFName(MDFNMKF_SAV, 0, ext));
     Memcard_SaveDelay[i] = -1;
     Memcard_PrevDC[i] = 0;
    }
    catch(std::exception &e)
    {
     MDFN_Notify(MDFN_NOTICE_ERROR, _("Memcard %d save error: %s"), i, e.what());
     Memcard_SaveDelay[i] = 0; // Delay before trying to save again
    }
   }
  }
 }
}

static bool CalcRegion_By_SYSTEMCNF(CDIF *c, unsigned *rr)
{
 try
 {
  uint8 pvd[2048];
  unsigned pvd_search_count = 0;
  std::unique_ptr<Stream> fp(c->MakeStream(0, ~0U));

  fp->seek(0x8000, SEEK_SET);

  do
  {
   if((pvd_search_count++) == 32)
    throw MDFN_Error(0, "PVD search count limit met.");

   fp->read(pvd, 2048);

   if(memcmp(&pvd[1], "CD001", 5))
    throw MDFN_Error(0, "Not ISO-9660");

   if(pvd[0] == 0xFF)
    throw MDFN_Error(0, "Missing Primary Volume Descriptor");
  } while(pvd[0] != 0x01);
  //[156 ... 189], 34 bytes
  uint32 rdel = MDFN_de32lsb(&pvd[0x9E]);
  uint32 rdel_len = MDFN_de32lsb(&pvd[0xA6]);

  if(rdel_len >= (1024 * 1024 * 10))	// Arbitrary sanity check.
   throw MDFN_Error(0, "Root directory table too large");

  fp->seek((int64)rdel * 2048, SEEK_SET);
  //printf("%08x, %08x\n", rdel * 2048, rdel_len);
  while(fp->tell() < (((uint64)rdel * 2048) + rdel_len))
  {
   uint8 len_dr = fp->get_u8();
   uint8 dr[256 + 1];

   memset(dr, 0xFF, sizeof(dr));

   if(!len_dr)
    break;

   memset(dr, 0, sizeof(dr));
   dr[0] = len_dr;
   fp->read(dr + 1, len_dr - 1);

   uint8 len_fi = dr[0x20];

   if(len_fi == 12 && !memcmp(&dr[0x21], "SYSTEM.CNF;1", 12))
   {
    uint32 file_lba = MDFN_de32lsb(&dr[0x02]);
    //uint32 file_len = MDFN_de32lsb(&dr[0x0A]);
    uint8 fb[2048 + 1];
    char *bootpos;

    memset(fb, 0, sizeof(fb));
    fp->seek(file_lba * 2048, SEEK_SET);
    fp->read(fb, 2048);

    bootpos = strstr((char*)fb, "BOOT") + 4;
    while(*bootpos == ' ' || *bootpos == '\t') bootpos++;
    if(*bootpos == '=')
    {
     bootpos++;
     while(*bootpos == ' ' || *bootpos == '\t') bootpos++;
     if(!MDFN_strazicmp(bootpos, "cdrom:", 6))
     { 
      char* tmp;

      bootpos += 6;

      // strrchr() way will pick up Tekken 3, but only enable if needed due to possibility of regressions.
      //if((tmp = strrchr(bootpos, '\\')))
      // bootpos = tmp + 1;
      while(*bootpos == '\\')
       bootpos++;

      if((tmp = strchr(bootpos, '_'))) *tmp = 0;
      if((tmp = strchr(bootpos, '.'))) *tmp = 0;
      if((tmp = strchr(bootpos, ';'))) *tmp = 0;
      //puts(bootpos);

      if(strlen(bootpos) == 4 && MDFN_azupper(bootpos[0]) == 'S' && (MDFN_azupper(bootpos[1]) == 'C' || MDFN_azupper(bootpos[1]) == 'L' || MDFN_azupper(bootpos[1]) == 'I'))
      {
       switch(MDFN_azupper(bootpos[2]))
       {
	case 'E': *rr = REGION_EU;
	          return(true);

	case 'U': *rr = REGION_NA;
		  return(true);

	case 'K':	// Korea?
	case 'B':
	case 'P': *rr = REGION_JP;
		  return(true);
       }
      }
     }
    }
   }
  }
 }
 catch(std::exception &e)
 {
  //puts(e.what());
 }
 catch(...)
 {

 }

 return(false);
}

static bool CalcRegion_By_SA(const uint8 buf[2048 * 8], unsigned* region)
{
	uint8 fbuf[2048 + 1];
	unsigned ipos, opos;

	memset(fbuf, 0, sizeof(fbuf));

	for(ipos = 0, opos = 0; ipos < 0x48; ipos++)
	{
	 if(buf[ipos] > 0x20 && buf[ipos] < 0x80)
	 {
	  fbuf[opos++] = MDFN_azlower(buf[ipos]);
	 }
	}

	fbuf[opos++] = 0;

	PSX_DBG(PSX_DBG_SPARSE, "License string: %s\n", (char *)fbuf);

	if(strstr((char *)fbuf, "licensedby") != NULL)
	{
	 if(strstr((char *)fbuf, "america") != NULL)
	 {
          *region = REGION_NA;
          return(true);
         }
         else if(strstr((char *)fbuf, "europe") != NULL)
         {
          *region = REGION_EU;
	  return(true);
         }
         else if(strstr((char *)fbuf, "japan") != NULL)
         {
          *region = REGION_JP;
          return(true);
         }
         else if(strstr((char *)fbuf, "sonycomputerentertainmentinc.") != NULL)
         {
          *region = REGION_JP;
          return(true);
         }
        }

	return(false);
}


//
// Returns true if constraint applied(*region changed), false otherwise.
//
static bool ConstrainRegion_By_SA(const uint8 buf[2048 * 8], unsigned* region)
{
  //
  // If we're going with Japanese region,
  // make sure the licensed-by string is correct(Japanese BIOS is kinda strict).
  //
  if(*region == REGION_JP)
  {
    static const char tv[2][0x41] = {
			      { 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 76, 105, 99, 101, 110, 115, 
			        101, 100, 32, 32, 98, 121, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 
			         83, 111, 110, 121, 32, 67, 111, 109, 112, 117, 116, 101, 114, 32, 69, 110, 
			        116, 101, 114, 116, 97, 105, 110, 109, 101, 110, 116, 32, 73, 110, 99, 46, 
			        0
			      },
			      { 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 76, 105, 99, 101, 110, 115, 
			        101, 100, 32, 32, 98, 121, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 
			         83, 111, 110, 121, 32, 67, 111, 109, 112, 117, 116, 101, 114, 32, 69, 110, 
			        116, 101, 114, 116, 97, 105, 110, 109, 101, 110, 116, 32, 73, 110, 99, 46, 
			        10
			      },
			    };  
    bool jp_incompatible = false;

    if(memcmp(&buf[0], &tv[0][0], 0x41) && memcmp(&buf[0], &tv[1][0], 0x41))
     jp_incompatible = true;

    if(crc32(0, &buf[0x800], 0x3278) != 0x0069c087)
     jp_incompatible = true;

    if(jp_incompatible)
    {
     //
     // Doesn't match, so default to most similar region, NA.
     //
     *region = REGION_NA;
     return(true);
    }
   }

 return(false);
}

static const char* Region_To_SCEx(const unsigned region)
{
 switch(region)
 {
       default:
	  abort();

       case REGION_JP:
	  return("SCEI");

       case REGION_NA:
	  return("SCEA");

       case REGION_EU:
	  return("SCEE");
 }
}

static bool TestMagic(MDFNFILE *fp)
{
 if(PSFLoader::TestMagic(0x01, fp->stream()))
  return(true);

 fp->rewind();

 uint8 exe_header[0x800];
 if(fp->read(exe_header, 0x800, false) == 0x800 && !memcmp(exe_header, "PS-X EXE", 8))
  return true;

 return false;
}

static bool TestMagicCD(std::vector<CDIF *> *CDInterfaces)
{
 std::unique_ptr<uint8[]> buf(new uint8[2048 * 8]);

 if((*CDInterfaces)[0]->ReadSector(&buf[0], 4, 8) != 0x2)
  return(false);

 if(strncmp((char *)&buf[10], "Licensed  by", strlen("Licensed  by")) && crc32(0, &buf[0x800], 0x3278) != 0x0069c087)
  return(false);

 return(true);
}


static unsigned CalcDiscSCEx(void)
{
 const unsigned region_default = MDFN_GetSettingI("psx.region_default");
 bool found_ps1_disc = false;
 bool did_constraint = false;
 unsigned ret_region = region_default;
 unsigned region = region_default;

 cdifs_scex_ids.clear();

 for(unsigned i = 0; i < (cdifs ? cdifs->size() : 0); i++)
 {
  std::unique_ptr<uint8[]> buf(new uint8[2048 * 8]);
  bool is_ps1_disc = true;

  //
  // Read the PS1 system area.
  //
  if((*cdifs)[i]->ReadSector(buf.get(), 4, 8) == 0x2)
  {
   if(!CalcRegion_By_SYSTEMCNF((*cdifs)[i], &region))
   {
    if(!CalcRegion_By_SA(buf.get(), &region))
    {
     if(strncmp((char *)buf.get() + 10, "Licensed  by", strlen("Licensed  by")) && crc32(0, &buf[0x800], 0x3278) != 0x0069c087)
     {
      //
      // Last-ditch effort before deciding the disc isn't a PS1 disc.
      //
      uint8 pvd[2048];

      if((*cdifs)[i]->ReadSector(pvd, 16, 1) != 0x2 || memcmp(&pvd[0], "\x01" "CD001", 6) || memcmp(&pvd[8], "PLAYSTATION", 11))
       is_ps1_disc = false;
     }
    }
   }
  }
  else
   is_ps1_disc = false;

  //
  // If PS1 disc, apply any constraints and change the region as necessary(e.g. Japanese PS1 BIOS is strict about the structure of the system area);
  // especially necessary for homebrew that failed automatic region detection above.
  //
  if(is_ps1_disc)
  {
   if(!found_ps1_disc || did_constraint)
   {
    if(ConstrainRegion_By_SA(buf.get(), &region))
     did_constraint = true;
   }
  }

  //
  // Determine what sort of PS1 to emulate based on the first PS1 disc in the set.
  // 
  if(!found_ps1_disc)
   ret_region = region;

  found_ps1_disc |= is_ps1_disc;
  cdifs_scex_ids.push_back(is_ps1_disc ? Region_To_SCEx(region) : NULL);
 }

 if(cdifs_scex_ids.size())
 {
  MDFN_printf(_("Emulated Disc SCEx IDs:\n"));
  {
   MDFN_AutoIndent aind(1);

   for(size_t x = 0; x < cdifs_scex_ids.size(); x++)
   {
    MDFN_printf(_("Disc %zu: %s\n"), x + 1, (cdifs_scex_ids[x] ? cdifs_scex_ids[x] : _("(Not recognized as a PS1 disc)")));
   }
  }
 }

 return ret_region;
}

static void DiscSanityChecks(void)
{
 if(!cdifs)
  return;

 assert(cdifs->size() == cdifs_scex_ids.size());

 for(size_t i = 0; i < cdifs_scex_ids.size(); i++)
 {
  //
  // Sanity check to ensure Q subchannel timing data relative to mode1/mode2 header timing data is as we expect it to be for a PS1 disc.
  //
  if(cdifs_scex_ids[i])
  {
   bool did_check = false;

   for(int32 lba = -8; lba < 16; lba++)
   {
    uint8 rawbuf[2352 + 96];

    if((*cdifs)[i]->ReadRawSector(rawbuf, lba))
    {
     uint8 qbuf[12];

     CDUtility::subq_deinterleave(rawbuf + 2352, qbuf);
     if(CDUtility::subq_check_checksum(qbuf) && (qbuf[0] & 0xF) == CDUtility::ADR_CURPOS)
     {
      uint8 qm = qbuf[7];
      uint8 qs = qbuf[8];
      uint8 qf = qbuf[9];

      uint8 hm = rawbuf[12];
      uint8 hs = rawbuf[13];
      uint8 hf = rawbuf[14];

      uint8 lm, ls, lf;

      CDUtility::LBA_to_AMSF(lba, &lm, &ls, &lf);
      lm = CDUtility::U8_to_BCD(lm);
      ls = CDUtility::U8_to_BCD(ls);
      lf = CDUtility::U8_to_BCD(lf);

      if(qm != hm || qs != hs || qf != hf)
      {
       throw MDFN_Error(0, _("Disc %zu of %zu: Q-subchannel versus sector header absolute time mismatch at lba=%d; Q subchannel: %02x:%02x:%02x, Sector header: %02x:%02x:%02x"),
		i + 1, cdifs->size(),
		lba,
		qm, qs, qf,
		hm, hs, hf);
      }

      if(lm != hm || ls != hs || lf != hf)
      {
       throw MDFN_Error(0, _("Disc %zu of %zu: Sector header absolute time broken at lba=%d(%02x:%02x:%02x); Sector header: %02x:%02x:%02x"),
		i + 1, cdifs->size(),
		lba,
		lm, ls, lf,
		hm, hs, hf);
      }

      if(lba >= 0)
       did_check = true;
     }
    }
   }

   if(!did_check)
   {
    throw MDFN_Error(0, _("Disc %zu of %zu: No valid Q subchannel ADR_CURPOS data present at lba 0-15?!"), i + 1, cdifs->size());
   }
  }
 }
}

static MDFN_COLD void InitCommon(std::vector<CDIF *> *CDInterfaces, const bool EmulateMemcards = true, const bool WantPIOMem = false)
{
 unsigned region;
 int sls, sle;

#if PSX_DBGPRINT_ENABLE
 psx_dbg_level = MDFN_GetSettingUI("psx.dbg_level");
#endif

 cdifs = CDInterfaces;
 region = CalcDiscSCEx();
 if(MDFN_GetSettingB("psx.cd_sanity"))
  DiscSanityChecks();
 else
  MDFN_printf(_("WARNING: CD (image) sanity checks disabled."));

 if(!MDFN_GetSettingB("psx.region_autodetect"))
  region = MDFN_GetSettingI("psx.region_default");

 MDFN_printf("\n");

 for(auto const* rle = Region_List; rle->string; rle++)
 {
  if((unsigned)rle->number == region)
  {
   MDFN_printf(_("Region: %s\n"), rle->description);
   break;
  }
 }

 sls = MDFN_GetSettingI((region == REGION_EU) ? "psx.slstartp" : "psx.slstart");
 sle = MDFN_GetSettingI((region == REGION_EU) ? "psx.slendp" : "psx.slend");

 if(sls > sle)
 {
  int tmp = sls;
  sls = sle;
  sle = tmp;
 }

 CPU = new PS_CPU();
 SPU = new PS_SPU();
 GPU_Init(region == REGION_EU);
 CDC = new PS_CDC();
 FIO = new FrontIO();

 MDFN_printf("\n");
 for(unsigned pp = 0; pp < 2; pp++)
 {
  char buf[64];
  bool sv;

  trio_snprintf(buf, sizeof(buf), "psx.input.pport%u.multitap", pp + 1);
  sv = MDFN_GetSettingB(buf);
  FIO->SetMultitap(pp, sv);

  MDFN_printf(_("Multitap on PSX Port %u: %s\n"), pp + 1, sv ? _("Enabled") : _("Disabled"));
 }

 FIO->SetAMCT(MDFN_GetSettingB("psx.input.analog_mode_ct"), MDFN_GetSettingUI("psx.input.analog_mode_ct.compare"));
 for(unsigned i = 0; i < 8; i++)
 {
  char buf[64];

  trio_snprintf(buf, sizeof(buf), "psx.input.port%u.gun_chairs", i + 1);
  FIO->SetCrosshairsColor(i, MDFN_GetSettingUI(buf));

  {
   bool mcsv;

   trio_snprintf(buf, sizeof(buf), "psx.input.port%u.memcard", i + 1);
   mcsv = EmulateMemcards && MDFN_GetSettingB(buf);
   FIO->SetMemcard(i, mcsv);

   //MDFN_printf(_("Memcard on Virtual Port %u: %s\n"), i + 1, mcsv ? _("Enabled") : _("Disabled"));
  }
 }

 DMA_Init();

 GPU_SetGetVideoParams(&EmulatedPSX, sls, sle, MDFN_GetSettingB("psx.h_overscan"));

 CDC->SetDisc(true, NULL, NULL);

 BIOSROM = new MultiAccessSizeMem<512 * 1024, false>();

 if(WantPIOMem)
  PIOMem = new MultiAccessSizeMem<65536, false>();
 else
  PIOMem = NULL;

 for(uint32 ma = 0x00000000; ma < 0x00800000; ma += 2048 * 1024)
 {
  CPU->SetFastMap(MainRAM.data8, 0x00000000 + ma, 2048 * 1024);
  CPU->SetFastMap(MainRAM.data8, 0x80000000 + ma, 2048 * 1024);
  CPU->SetFastMap(MainRAM.data8, 0xA0000000 + ma, 2048 * 1024);
 }

 CPU->SetFastMap(BIOSROM->data8, 0x1FC00000, 512 * 1024);
 CPU->SetFastMap(BIOSROM->data8, 0x9FC00000, 512 * 1024);
 CPU->SetFastMap(BIOSROM->data8, 0xBFC00000, 512 * 1024);

 if(PIOMem)
 {
  CPU->SetFastMap(PIOMem->data8, 0x1F000000, 65536);
  CPU->SetFastMap(PIOMem->data8, 0x9F000000, 65536);
  CPU->SetFastMap(PIOMem->data8, 0xBF000000, 65536);
 }


 MDFNMP_Init(1024, ((uint64)1 << 29) / 1024);
 MDFNMP_AddRAM(2048 * 1024, 0x00000000, MainRAM.data8);
 //MDFNMP_AddRAM(1024, 0x1F800000, ScratchRAM.data8);

 //
 //
 //
 const char *biospath_sname;

 if(region == REGION_JP)
  biospath_sname = "psx.bios_jp";
 else if(region == REGION_EU)
  biospath_sname = "psx.bios_eu";
 else if(region == REGION_NA)
  biospath_sname = "psx.bios_na";
 else
  abort();

 {
  std::string biospath = MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, MDFN_GetSettingS(biospath_sname));
  FileStream BIOSFile(biospath, FileStream::MODE_READ);

  if(BIOSFile.size() != 524288)
   throw MDFN_Error(0, _("BIOS file \"%s\" is of an incorrect size."), biospath.c_str());

  BIOSFile.read(BIOSROM->data8, 512 * 1024);
  BIOS_SHA256 = sha256(BIOSROM->data8, 512 * 1024);

  if(MDFN_GetSettingB("psx.bios_sanity"))
  {
   bool bios_recognized = false;

   for(auto const& dbe : BIOS_DB)
   {
    if(BIOS_SHA256 == dbe.sd)
    {
     if(dbe.bad)
      throw MDFN_Error(0, _("BIOS file \"%s\" is a known bad dump."), biospath.c_str());

     if(dbe.region != region)
      throw MDFN_Error(0, _("BIOS file \"%s\" is not the proper BIOS for the region of PS1 being emulated."), biospath.c_str());

     bios_recognized = true;
     break;
    }
   }

   if(!bios_recognized)
    MDFN_printf(_("Warning: Unrecognized BIOS.\n"));
  }
  else
   MDFN_printf(_("WARNING: BIOS ROM sanity checks disabled.\n"));
 }

 for(int i = 0; i < 8; i++)
 {
  char ext[64];
  trio_snprintf(ext, sizeof(ext), "%d.mcr", i);
  //MDFN_BackupSavFile(5, ext);
  FIO->LoadMemcard(i, MDFN_MakeFName(MDFNMKF_SAV, 0, ext));
 }

 for(int i = 0; i < 8; i++)
 {
  Memcard_PrevDC[i] = FIO->GetMemcardDirtyCount(i);
  Memcard_SaveDelay[i] = -1;
 }


 #ifdef WANT_DEBUGGER
 DBG_Init();
 #endif

 PSX_Reset(true);
}

static MDFN_COLD void LoadEXE(Stream* fp, bool ignore_pcsp = false)
{
 uint8 raw_header[0x800];
 uint32 PC;
 uint32 SP;
 uint32 TextStart;
 uint32 TextSize;

 fp->read(raw_header, sizeof(raw_header));

 PC = MDFN_de32lsb(&raw_header[0x10]);
 SP = MDFN_de32lsb(&raw_header[0x30]);
 TextStart = MDFN_de32lsb(&raw_header[0x18]);
 TextSize = MDFN_de32lsb(&raw_header[0x1C]);

 if(ignore_pcsp)
  MDFN_printf("TextStart=0x%08x\nTextSize=0x%08x\n", TextStart, TextSize);
 else
  MDFN_printf("PC=0x%08x\nSP=0x%08x\nTextStart=0x%08x\nTextSize=0x%08x\n", PC, SP, TextStart, TextSize);

 TextStart &= 0x1FFFFF;

 if(TextSize > 2048 * 1024)
 {
  throw(MDFN_Error(0, "Text section too large"));
 }

 //if(TextSize > (size - 0x800))
 // throw(MDFN_Error(0, "Text section recorded size is larger than data available in file.  Header=0x%08x, Available=0x%08x", TextSize, size - 0x800));

 //if(TextSize < (size - 0x800))
 // throw(MDFN_Error(0, "Text section recorded size is smaller than data available in file.  Header=0x%08x, Available=0x%08x", TextSize, size - 0x800));

 if(!TextMem.size())
 {
  TextMem_Start = TextStart;
  TextMem.resize(TextSize);
 }

 if(TextStart < TextMem_Start)
 {
  uint32 old_size = TextMem.size();

  //printf("RESIZE: 0x%08x\n", TextMem_Start - TextStart);

  TextMem.resize(old_size + TextMem_Start - TextStart);
  memmove(&TextMem[TextMem_Start - TextStart], &TextMem[0], old_size);

  TextMem_Start = TextStart;
 }

 if(TextMem.size() < (TextStart - TextMem_Start + TextSize))
  TextMem.resize(TextStart - TextMem_Start + TextSize);

 fp->read(&TextMem[TextStart - TextMem_Start], TextSize);

 {
  uint64 extra_data = fp->read_discard();

  if(extra_data > 0)
   throw MDFN_Error(0, _("0x%08llx bytes of extra data after EXE text section."), (unsigned long long)extra_data);
 }

 //
 //
 //

 // BIOS patch
 BIOSROM->WriteU32(0x6990, (3 << 26) | ((0xBF001000 >> 2) & ((1 << 26) - 1)));
// BIOSROM->WriteU32(0x691C, (3 << 26) | ((0xBF001000 >> 2) & ((1 << 26) - 1)));

// printf("INSN: 0x%08x\n", BIOSROM->ReadU32(0x6990));
// exit(1);
 uint8 *po;

 po = &PIOMem->data8[0x0800];

 MDFN_en32lsb(po, (0x0 << 26) | (31 << 21) | (0x8 << 0));	// JR
 po += 4;
 MDFN_en32lsb(po, 0);	// NOP(kinda)
 po += 4;

 po = &PIOMem->data8[0x1000];

 // Load cacheable-region target PC into r2
 MDFN_en32lsb(po, (0xF << 26) | (0 << 21) | (1 << 16) | (0x9F001010 >> 16));      // LUI
 po += 4;
 MDFN_en32lsb(po, (0xD << 26) | (1 << 21) | (2 << 16) | (0x9F001010 & 0xFFFF));   // ORI
 po += 4;

 // Jump to r2
 MDFN_en32lsb(po, (0x0 << 26) | (2 << 21) | (0x8 << 0));	// JR
 po += 4;
 MDFN_en32lsb(po, 0);	// NOP(kinda)
 po += 4;

 //
 // 0x9F001010:
 //

 // Load source address into r8
 uint32 sa = 0x9F000000 + 65536;
 MDFN_en32lsb(po, (0xF << 26) | (0 << 21) | (1 << 16) | (sa >> 16));	// LUI
 po += 4;
 MDFN_en32lsb(po, (0xD << 26) | (1 << 21) | (8 << 16) | (sa & 0xFFFF)); 	// ORI
 po += 4;

 // Load dest address into r9
 MDFN_en32lsb(po, (0xF << 26) | (0 << 21) | (1 << 16)  | (TextMem_Start >> 16));	// LUI
 po += 4;
 MDFN_en32lsb(po, (0xD << 26) | (1 << 21) | (9 << 16) | (TextMem_Start & 0xFFFF)); 	// ORI
 po += 4;

 // Load size into r10
 MDFN_en32lsb(po, (0xF << 26) | (0 << 21) | (1 << 16)  | (TextMem.size() >> 16));	// LUI
 po += 4;
 MDFN_en32lsb(po, (0xD << 26) | (1 << 21) | (10 << 16) | (TextMem.size() & 0xFFFF)); 	// ORI
 po += 4;

 //
 // Loop begin
 //
 
 MDFN_en32lsb(po, (0x24 << 26) | (8 << 21) | (1 << 16));	// LBU to r1
 po += 4;

 MDFN_en32lsb(po, (0x08 << 26) | (10 << 21) | (10 << 16) | 0xFFFF);	// Decrement size
 po += 4;

 MDFN_en32lsb(po, (0x28 << 26) | (9 << 21) | (1 << 16));	// SB from r1
 po += 4;

 MDFN_en32lsb(po, (0x08 << 26) | (8 << 21) | (8 << 16) | 0x0001);	// Increment source addr
 po += 4;

 MDFN_en32lsb(po, (0x05 << 26) | (0 << 21) | (10 << 16) | (-5 & 0xFFFF));
 po += 4;
 MDFN_en32lsb(po, (0x08 << 26) | (9 << 21) | (9 << 16) | 0x0001);	// Increment dest addr
 po += 4;

 //
 // Loop end
 //

 // Load SP into r29
 if(ignore_pcsp)
 {
  po += 16;
 }
 else
 {
  MDFN_en32lsb(po, (0xF << 26) | (0 << 21) | (1 << 16)  | (SP >> 16));	// LUI
  po += 4;
  MDFN_en32lsb(po, (0xD << 26) | (1 << 21) | (29 << 16) | (SP & 0xFFFF)); 	// ORI
  po += 4;

  // Load PC into r2
  MDFN_en32lsb(po, (0xF << 26) | (0 << 21) | (1 << 16)  | ((PC >> 16) | 0x8000));      // LUI
  po += 4;
  MDFN_en32lsb(po, (0xD << 26) | (1 << 21) | (2 << 16) | (PC & 0xFFFF));   // ORI
  po += 4;
 }

 // Half-assed instruction cache flush. ;)
 for(unsigned i = 0; i < 1024; i++)
 {
  MDFN_en32lsb(po, 0);
  po += 4;
 }



 // Jump to r2
 MDFN_en32lsb(po, (0x0 << 26) | (2 << 21) | (0x8 << 0));	// JR
 po += 4;
 MDFN_en32lsb(po, 0);	// NOP(kinda)
 po += 4;
}

PSF1Loader::PSF1Loader(Stream *fp)
{
 tags = Load(0x01, 2033664, fp);
}

PSF1Loader::~PSF1Loader()
{

}

void PSF1Loader::HandleEXE(Stream* fp, bool ignore_pcsp)
{
 LoadEXE(fp, ignore_pcsp);
}

static void Cleanup(void);
static MDFN_COLD void Load(MDFNFILE *fp)
{
 try
 {
  const bool IsPSF = PSFLoader::TestMagic(0x01, fp->stream());

  if(!TestMagic(fp))
   throw MDFN_Error(0, _("File format is unknown to module \"%s\"."), MDFNGameInfo->shortname);

  fp->rewind();

  if(MDFN_GetSettingS("psx.dbg_exe_cdpath") != "")	// For testing/debug purposes.
  {
   RMD_Drive dr;
   RMD_DriveDefaults drdef;

   dr.Name = std::string("Virtual CD Drive");
   dr.PossibleStates.push_back(RMD_State({"Tray Open", false, false, true}));
   dr.PossibleStates.push_back(RMD_State({"Tray Closed (Empty)", false, false, false}));
   dr.PossibleStates.push_back(RMD_State({"Tray Closed", true, true, false}));
   dr.CompatibleMedia.push_back(0);
   dr.MediaMtoPDelay = 2000;

   drdef.State = 2; // Tray Closed
   drdef.Media = 0;
   drdef.Orientation = 0;

   MDFNGameInfo->RMD->Drives.push_back(dr);
   MDFNGameInfo->RMD->DrivesDefaults.push_back(drdef);
   MDFNGameInfo->RMD->MediaTypes.push_back(RMD_MediaType({"CD"}));
   MDFNGameInfo->RMD->Media.push_back(RMD_Media({"Test CD", 0}));

   static std::vector<CDIF *> CDInterfaces;
   CDInterfaces.clear();
   CDInterfaces.push_back(CDIF_Open(MDFN_GetSettingS("psx.dbg_exe_cdpath").c_str(), false));
   InitCommon(&CDInterfaces, !IsPSF, true);
  }
  else
   InitCommon(NULL, !IsPSF, true);

  TextMem.resize(0);

  if(IsPSF)
  {
   psf_loader = new PSF1Loader(fp->stream());

   std::vector<std::string> SongNames;

   SongNames.push_back(psf_loader->tags.GetTag("title"));

   Player_Init(1, psf_loader->tags.GetTag("game"), psf_loader->tags.GetTag("artist"), psf_loader->tags.GetTag("copyright"), SongNames);
  }
  else
   LoadEXE(fp->stream());
 }
 catch(std::exception &e)
 {
  Cleanup();
  throw;
 }
}

static MDFN_COLD void LoadCD(std::vector<CDIF *> *CDInterfaces)
{
 try
 {
  InitCommon(CDInterfaces);
 }
 catch(std::exception &e)
 {
  Cleanup();
  throw;
 }
}

static MDFN_COLD void Cleanup(void)
{
 TextMem.resize(0);

 if(psf_loader)
 {
  delete psf_loader;
  psf_loader = NULL;
 }

 if(CDC)
 {
  delete CDC;
  CDC = NULL;
 }

 if(SPU)
 {
  delete SPU;
  SPU = NULL;
 }

 GPU_Kill();

 if(CPU)
 {
  delete CPU;
  CPU = NULL;
 }

 if(FIO)
 {
  delete FIO;
  FIO = NULL;
 }

 DMA_Kill();

 if(BIOSROM)
 {
  delete BIOSROM;
  BIOSROM = NULL;
 }

 if(PIOMem)
 {
  delete PIOMem;
  PIOMem = NULL;
 }

 cdifs = NULL;
}

static MDFN_COLD void CloseGame(void)
{
 if(!psf_loader)
 {
  for(int i = 0; i < 8; i++)
  {
   // If there's an error saving one memcard, don't skip trying to save the other, since it might succeed and
   // we can reduce potential data loss!
   try
   {
    char ext[64];
    trio_snprintf(ext, sizeof(ext), "%d.mcr", i);

    FIO->SaveMemcard(i, MDFN_MakeFName(MDFNMKF_SAV, 0, ext));
   }
   catch(std::exception &e)
   {
    MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
   }
  }
 }

 Cleanup();
}


static void SetInput(unsigned port, const char *type, uint8 *ptr)
{
 if(psf_loader)
  FIO->SetInput(port, "none", NULL);
 else
  FIO->SetInput(port, type, ptr);
}

static void TransformInput(void)
{
 FIO->TransformInput();
}

static void StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 if(!data_only)
 {
  sha256_digest sr_dig = BIOS_SHA256;

  SFORMAT SRDStateRegs[] = 
  {
   SFPTR8(sr_dig.data(), sr_dig.size()),
   SFEND
  };

  MDFNSS_StateAction(sm, load, data_only, SRDStateRegs, "BIOS_HASH", true);

  if(load && sr_dig != BIOS_SHA256)
   throw MDFN_Error(0, _("BIOS hash mismatch(save state created under a different BIOS)!"));
 }


 SFORMAT StateRegs[] =
 {
  SFPTR8(MainRAM.data8, 1024 * 2048),
  SFPTR32(SysControl.Regs, 9),

  SFVAR(PSX_PRNG.lcgo),
  SFVAR(PSX_PRNG.x),
  SFVAR(PSX_PRNG.y),
  SFVAR(PSX_PRNG.z),
  SFVAR(PSX_PRNG.c),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAIN");

 CPU->StateAction(sm, load, data_only);
 DMA_StateAction(sm, load, data_only);
 TIMER_StateAction(sm, load, data_only);
 SIO_StateAction(sm, load, data_only);

 CDC->StateAction(sm, load, data_only);
 MDEC_StateAction(sm, load, data_only);
 GPU_StateAction(sm, load, data_only);
 SPU->StateAction(sm, load, data_only);

 FIO->StateAction(sm, load, data_only);

 IRQ_StateAction(sm, load, data_only);	// Do it last.

 if(load)
 {
  ForceEventUpdates(0);	// FIXME to work with debugger step mode.
 }
}

static bool SetMedia(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{
 const RMD_Layout* rmd = EmulatedPSX.RMD;
 const RMD_Drive* rd = &rmd->Drives[drive_idx];
 const RMD_State* rs = &rd->PossibleStates[state_idx];

 //printf("%d %d %d %d\n", drive_idx, state_idx, media_idx, orientation_idx);

 if(rs->MediaPresent && rs->MediaUsable)
 {
  CDC->SetDisc(false, (*cdifs)[media_idx], cdifs_scex_ids[media_idx]);
 }
 else
 {
  CDC->SetDisc(rs->MediaCanChange, NULL, NULL);
 }

 return(true);
}

static void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_RESET: PSX_Reset(false); break;
  case MDFN_MSC_POWER: PSX_Reset(true); break;
 }
}

static const CheatInfoStruct CheatInfo =
{
 NULL,
 NULL,

 NULL,
 NULL,

 CheatFormats_PSX
};


static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".psf", gettext_noop("PSF1 Rip") },
 { ".minipsf", gettext_noop("MiniPSF1 Rip") },
 { ".psx", gettext_noop("PS-X Executable") },
 { ".exe", gettext_noop("PS-X Executable") },
 { NULL, NULL }
};

static const MDFNSetting PSXSettings[] =
{
 { "psx.input.mouse_sensitivity", MDFNSF_NOFLAGS, gettext_noop("Emulated mouse sensitivity."), NULL, MDFNST_FLOAT, "1.00", NULL, NULL },

 { "psx.input.analog_mode_ct", MDFNSF_NOFLAGS, gettext_noop("Enable analog mode combo-button alternate toggle."), gettext_noop("When enabled, instead of the configured Analog mode toggle button for the emulated DualShock, use a combination of buttons held down for one emulated second to toggle it instead.  The specific combination is controlled via the \"psx.input.analog_mode_ct.compare\" setting, which by default is Select, Start, and all four shoulder buttons."), MDFNST_BOOL, "0", NULL, NULL },
 { "psx.input.analog_mode_ct.compare", MDFNSF_NOFLAGS, gettext_noop("Compare value for analog mode combo-button alternate toggle."), gettext_noop("0x0001=SELECT\n0x0002=L3\n0x0004=R3\n0x0008=START\n0x0010=D-Pad UP\n0x0020=D-Pad Right\n0x0040=D-Pad Down\n0x0080=D-Pad Left\n0x0100=L2\n0x0200=R2\n0x0400=L1\n0x0800=R1\n0x1000=△\n0x2000=○\n0x4000=x\n0x8000=□"), MDFNST_UINT, "0x0F09", "0x0000", "0xFFFF" },

 { "psx.input.pport1.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap on PSX port 1."), gettext_noop("Makes 3 more virtual ports available.\n\nNOTE: Enabling multitap in games that don't fully support it may cause deleterious effects."), MDFNST_BOOL, "0", NULL, NULL }, //MDFNST_ENUM, "auto", NULL, NULL, NULL, NULL, MultiTap_List },
 { "psx.input.pport2.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap on PSX port 2."), gettext_noop("Makes 3 more virtual ports available.\n\nNOTE: Enabling multitap in games that don't fully support it may cause deleterious effects."), MDFNST_BOOL, "0", NULL, NULL },

 { "psx.input.port1.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memory card on virtual port 1."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port2.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memory card on virtual port 2."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port3.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memory card on virtual port 3."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port4.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memory card on virtual port 4."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port5.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memory card on virtual port 5."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port6.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memory card on virtual port 6."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port7.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memory card on virtual port 7."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port8.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memory card on virtual port 8."), NULL, MDFNST_BOOL, "1", NULL, NULL, },


 { "psx.input.port1.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 1."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0xFF0000", "0x000000", "0x1000000" },
 { "psx.input.port2.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 2."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0x00FF00", "0x000000", "0x1000000" },
 { "psx.input.port3.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 3."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0xFF00FF", "0x000000", "0x1000000" },
 { "psx.input.port4.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 4."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0xFF8000", "0x000000", "0x1000000" },
 { "psx.input.port5.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 5."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0xFFFF00", "0x000000", "0x1000000" },
 { "psx.input.port6.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 6."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0x00FFFF", "0x000000", "0x1000000" },
 { "psx.input.port7.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 7."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0x0080FF", "0x000000", "0x1000000" },
 { "psx.input.port8.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 8."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0x8000FF", "0x000000", "0x1000000" },

 { "psx.region_autodetect", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Attempt to auto-detect region of game."), NULL, MDFNST_BOOL, "1" },
 { "psx.region_default", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Default region to use."), gettext_noop("Used if region autodetection fails or is disabled."), MDFNST_ENUM, "jp", NULL, NULL, NULL, NULL, Region_List },

 { "psx.bios_jp", MDFNSF_EMU_STATE | MDFNSF_CAT_PATH, gettext_noop("Path to the Japan SCPH-5500/v3.0J ROM BIOS"), gettext_noop("SHA-256 9c0421858e217805f4abe18698afea8d5aa36ff0727eb8484944e00eb5e7eadb"), MDFNST_STRING, "scph5500.bin" },
 { "psx.bios_na", MDFNSF_EMU_STATE | MDFNSF_CAT_PATH, gettext_noop("Path to the North America SCPH-5501/v3.0A ROM BIOS"), gettext_noop("SHA-256 11052b6499e466bbf0a709b1f9cb6834a9418e66680387912451e971cf8a1fef"), MDFNST_STRING, "scph5501.bin" },
 { "psx.bios_eu", MDFNSF_EMU_STATE | MDFNSF_CAT_PATH, gettext_noop("Path to the Europe SCPH-5502/v3.0E ROM BIOS"), gettext_noop("SHA-256 1faaa18fa820a0225e488d9f086296b8e6c46df739666093987ff7d8fd352c09"), MDFNST_STRING, "scph5502.bin" },

 { "psx.bios_sanity", MDFNSF_NOFLAGS, gettext_noop("Enable BIOS ROM image sanity checks."), gettext_noop("Enables blacklisting of known bad BIOS dumps and known BIOS versions that don't match the region of the hardware being emulated.") , MDFNST_BOOL, "1" },
 { "psx.cd_sanity", MDFNSF_NOFLAGS, gettext_noop("Enable CD (image) sanity checks."), gettext_noop("Sanity checks are only performed on discs detected(via heuristics) to be PS1 discs.  The checks primarily consist of ensuring that Q subchannel data is as expected for a typical commercially-released PS1 disc."), MDFNST_BOOL, "1" },

 { "psx.spu.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("SPU output resampler quality."),
	gettext_noop("0 is lowest quality and CPU usage, 10 is highest quality and CPU usage.  The resampler that this setting refers to is used for converting from 44.1KHz to the sampling rate of the host audio device Mednafen is using.  Changing Mednafen's output rate, via the \"sound.rate\" setting, to \"44100\" may bypass the resampler, which can decrease CPU usage by Mednafen, and can increase or decrease audio quality, depending on various operating system and hardware factors."), MDFNST_UINT, "5", "0", "10" },


 { "psx.slstart", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in NTSC mode."), NULL, MDFNST_INT, "0", "0", "239" },
 { "psx.slend", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in NTSC mode."), NULL, MDFNST_INT, "239", "0", "239" },

 { "psx.slstartp", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in PAL mode."), NULL, MDFNST_INT, "0", "0", "287" },	// 14
 { "psx.slendp", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in PAL mode."), NULL, MDFNST_INT, "287", "0", "287" },	// 275

 { "psx.h_overscan", MDFNSF_NOFLAGS, gettext_noop("Show horizontal overscan area."), NULL, MDFNST_BOOL, "1" },

#if PSX_DBGPRINT_ENABLE
 { "psx.dbg_level", MDFNSF_NOFLAGS, gettext_noop("Debug printf verbosity level."), NULL, MDFNST_UINT, "0", "0", "4" },
#endif

 { "psx.dbg_exe_cdpath", MDFNSF_SUPPRESS_DOC | MDFNSF_CAT_PATH, gettext_noop("CD image to use with .PSX/.EXE loading."), NULL, MDFNST_STRING, "" },

 { NULL },
};

// Note for the future: If we ever support PSX emulation with non-8-bit RGB color components, or add a new linear RGB colorspace to MDFN_PixelFormat, we'll need
// to buffer the intermediate 24-bit non-linear RGB calculation into an array and pass that into the GPULineHook stuff, otherwise netplay could break when
// an emulated GunCon is used.
MDFNGI EmulatedPSX =
{
 "psx",
 "Sony PlayStation",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 #ifdef WANT_DEBUGGER
 &PSX_DBGInfo,
 #else
 NULL,
 #endif
 FIO_PortInfo,
 Load,
 TestMagic,
 LoadCD,
 TestMagicCD,
 CloseGame,

 NULL,	//ToggleLayer,
 "GPU\0",	//"Background Scroll\0Foreground Scroll\0Sprites\0",

 NULL,
 NULL,

 NULL,
 0,

 CheatInfo,

 false,
 StateAction,
 Emulate,
 TransformInput,
 SetInput,
 SetMedia,
 DoSimpleCommand,
 NULL,
 PSXSettings,
 MDFN_MASTERCLOCK_FIXED(33868800),
 0,

 true, // Multires possible?

 //
 // Note: Following video settings will be overwritten during game load.
 //
 0,	// lcm_width
 0,	// lcm_height
 NULL,  // Dummy

 320,   // Nominal width
 240,   // Nominal height

 0,   // Framebuffer width
 0,   // Framebuffer height
 //
 //
 //

 2,     // Number of output sound channels

};
