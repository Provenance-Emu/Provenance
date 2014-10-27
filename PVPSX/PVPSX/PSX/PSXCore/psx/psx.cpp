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

#include "psx.h"
#include "mdec.h"
#include "frontio.h"
#include "timer.h"
#include "sio.h"
#include "cdc.h"
#include "spu.h"
#include <mednafen/mempatcher.h>
#include <mednafen/PSFLoader.h>
#include <mednafen/player.h>

#include <stdarg.h>
#include <ctype.h>

extern MDFNGI EmulatedPSX;

namespace MDFN_IEN_PSX
{

#if PSX_DBGPRINT_ENABLE
static unsigned psx_dbg_level = 0;

void PSX_DBG(unsigned level, const char *format, ...) throw()
{
 if(psx_dbg_level >= level)
 {
  va_list ap;

  va_start(ap, format);

  trio_vprintf(format, ap);

  va_end(ap);
 }
}
#endif


struct MDFN_PseudoRNG	// Based off(but not the same as) public-domain "JKISS" PRNG.
{
 MDFN_PseudoRNG()
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

 void ResetState(void)	// Must always reset to the same state.
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

 PSF1Loader(MDFNFILE *fp);
 virtual ~PSF1Loader();

 virtual void HandleEXE(const uint8 *data, uint32 len, bool ignore_pcsp = false);

 PSFTags tags;
};

enum
{
 REGION_JP = 0,
 REGION_NA = 1,
 REGION_EU = 2,
};

static PSF1Loader *psf_loader = NULL;
static std::vector<CDIF*> *cdifs = NULL;
static std::vector<const char *> cdifs_scex_ids;
static bool CD_TrayOpen;
static int CD_SelectedDisc;     // -1 for no disc

static uint64 Memcard_PrevDC[8];
static int64 Memcard_SaveDelay[8];

PS_CPU *CPU = NULL;
PS_SPU *SPU = NULL;
PS_GPU *GPU = NULL;
PS_CDC *CDC = NULL;
FrontIO *FIO = NULL;

static MultiAccessSizeMem<512 * 1024, uint32, false> *BIOSROM = NULL;
static MultiAccessSizeMem<65536, uint32, false> *PIOMem = NULL;

MultiAccessSizeMem<2048 * 1024, uint32, false> MainRAM;

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
   events[i].event_time = 0;
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
 assert(type > PSX_EVENT__SYNFIRST && type < PSX_EVENT__SYNLAST);
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
 PSX_SetEventNT(PSX_EVENT_GPU, GPU->Update(timestamp));
 PSX_SetEventNT(PSX_EVENT_CDC, CDC->Update(timestamp));

 PSX_SetEventNT(PSX_EVENT_TIMER, TIMER_Update(timestamp));

 PSX_SetEventNT(PSX_EVENT_DMA, DMA_Update(timestamp));

 PSX_SetEventNT(PSX_EVENT_FIO, FIO->Update(timestamp));

 CPU->SetEventNT(events[PSX_EVENT__SYNFIRST].next->event_time);
}

bool MDFN_FASTCALL PSX_EventHandler(const pscpu_timestamp_t timestamp)
{
 event_list_entry *e = events[PSX_EVENT__SYNFIRST].next;
#if PSX_EVENT_SYSTEM_CHECKS
 pscpu_timestamp_t prev_event_time = 0;
#endif
#if 0
 {
   printf("EventHandler - timestamp=%8d\n", timestamp);
   event_list_entry *moo = &events[PSX_EVENT__SYNFIRST];
   while(moo)
   {
    printf("%u: %8d\n", moo->which, moo->event_time);
    moo = moo->next;
   }
 }
#endif

#if PSX_EVENT_SYSTEM_CHECKS
 assert(Running == 0 || timestamp >= e->event_time);	// If Running == 0, our EventHandler 
#endif

 while(timestamp >= e->event_time)	// If Running = 0, PSX_EventHandler() may be called even if there isn't an event per-se, so while() instead of do { ... } while
 {
  event_list_entry *prev = e->prev;
  pscpu_timestamp_t nt;

#if PSX_EVENT_SYSTEM_CHECKS
 // Sanity test to make sure events are being evaluated in temporal order.
  if(e->event_time < prev_event_time)
   abort();
  prev_event_time = e->event_time;
#endif

  //printf("Event: %u %8d\n", e->which, e->event_time);
#if PSX_EVENT_SYSTEM_CHECKS
  if((timestamp - e->event_time) > 50)
   printf("Late: %u %d --- %8d\n", e->which, timestamp - e->event_time, timestamp);
#endif

  switch(e->which)
  {
   default: abort();

   case PSX_EVENT_GPU:
	nt = GPU->Update(e->event_time);
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

#if PSX_EVENT_SYSTEM_CHECKS
 for(int i = PSX_EVENT__SYNFIRST + 1; i < PSX_EVENT__SYNLAST; i++)
 {
  if(timestamp >= events[i].event_time)
  {
   printf("BUG: %u\n", i);

   event_list_entry *moo = &events[PSX_EVENT__SYNFIRST];

   while(moo)
   {
    printf("%u: %8d\n", moo->which, moo->event_time);
    moo = moo->next;
   }

   abort();
  }
 }
#endif

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

void DMA_CheckReadDebug(uint32 A);

static unsigned sucksuck = 0;
void PSX_SetDMASuckSuck(unsigned suckage)
{
 sucksuck = suckage;
}


// Remember to update MemPeek<>() when we change address decoding in MemRW()
template<typename T, bool IsWrite, bool Access24> static INLINE void MemRW(pscpu_timestamp_t &timestamp, uint32 A, uint32 &V)
{
 #if 0
 if(IsWrite)
  printf("Write%d: %08x(orig=%08x), %08x\n", (int)(sizeof(T) * 8), A & mask[A >> 29], A, V);
 else
  printf("Read%d: %08x(orig=%08x)\n", (int)(sizeof(T) * 8), A & mask[A >> 29], A);
 #endif

 if(!IsWrite)
  timestamp += sucksuck;

 //if(A == 0xa0 && IsWrite)
 // DBG_Break();

 if(A < 0x00800000)
 //if(A <= 0x1FFFFF)
 {
  if(IsWrite)
  {
   //timestamp++;	// Best-case timing.
  }
  else
  {
   timestamp += 3;
  }

  //DMA_CheckReadDebug(A);
  //assert(A <= 0x1FFFFF);
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
    GPU->Write(timestamp, A, V);
   else
    V = GPU->Read(timestamp, A);

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
 //assert(0);
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

// FIXME: Add PSX_Reset() and FrontIO::Reset() so that emulated input devices don't get power-reset on reset-button reset.
static void PSX_Power(void)
{
 PSX_PRNG.ResetState();	// Should occur first!

#if 0
 const uint32 counterer = 262144;
 uint64 averageizer = 0;
 uint32 maximizer = 0;
 uint32 minimizer = ~0U;
 for(int i = 0; i < counterer; i++)
 {
  uint32 tmp = PSX_GetRandU32(0, 20000);
  if(tmp < minimizer)
   minimizer = tmp;

  if(tmp > maximizer)
   maximizer = tmp;

  averageizer += tmp;
  printf("%8u\n", tmp);
 }
 printf("Average: %f\nMinimum: %u\nMaximum: %u\n", (double)averageizer / counterer, minimizer, maximizer);
 exit(1);
#endif

 memset(MainRAM.data32, 0, 2048 * 1024);

 for(unsigned i = 0; i < 9; i++)
  SysControl.Regs[i] = 0;

 CPU->Power();

 EventReset();

 TIMER_Power();

 DMA_Power();

 FIO->Power();
 SIO_Power();

 MDEC_Power();
 CDC->Power();
 GPU->Power();
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
 GPU->StartFrame(psf_loader ? NULL : espec);
 SPU->StartFrame(espec->SoundRate, MDFN_GetSettingUI("psx.spu.resamp_quality"));

 Running = -1;
 timestamp = CPU->Run(timestamp, psf_loader != NULL);

 assert(timestamp);

 ForceEventUpdates(timestamp);
 if(GPU->GetScanlineNum() < 100)
  PSX_DBG(PSX_DBG_ERROR, "[BUUUUUUUG] Frame timing end glitch; scanline=%u, st=%u\n", GPU->GetScanlineNum(), timestamp);

 //printf("scanline=%u, st=%u\n", GPU->GetScanlineNum(), timestamp);

 espec->SoundBufSize = SPU->EndFrame(espec->SoundBuf);

 CDC->ResetTS();
 TIMER_ResetTS();
 DMA_ResetTS();
 GPU->ResetTS();
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
     FIO->SaveMemcard(i, MDFN_MakeFName(MDFNMKF_SAV, 0, ext).c_str());
     Memcard_SaveDelay[i] = -1;
     Memcard_PrevDC[i] = 0;
    }
    catch(std::exception &e)
    {
     MDFN_PrintError("Memcard %d save error: %s", i, e.what());
     MDFN_DispMessage("Memcard %d save error: %s", i, e.what());
    }
    //MDFN_DispMessage("Memcard %d saved.", i);
   }
  }
 }
}

static bool TestMagic(MDFNFILE *fp)
{
 if(PSFLoader::TestMagic(0x01, fp))
  return(true);

 if(fp->size < 0x800)
  return(false);

 if(memcmp(fp->data, "PS-X EXE", 8))
  return(false);

 return(true);
}

static bool TestMagicCD(std::vector<CDIF *> *CDInterfaces)
{
 uint8 buf[2048];
 CDUtility::TOC toc;
 int dt;

 (*CDInterfaces)[0]->ReadTOC(&toc);

 dt = toc.FindTrackByLBA(4);
 if(dt > 0 && !(toc.tracks[dt].control & 0x4))
  return(false);

 if((*CDInterfaces)[0]->ReadSector(buf, 4, 1) != 0x2)
  return(false);

 if(strncmp((char *)buf + 10, "Licensed  by", strlen("Licensed  by")))
  return(false);

 //if(strncmp((char *)buf + 32, "Sony", 4))
 // return(false);

 //for(int i = 0; i < 2048; i++)
 // printf("%d, %02x %c\n", i, buf[i], buf[i]);
 //exit(1);

#if 0
 {
  uint8 buf[2048 * 7];

  if((*cdifs)[0]->ReadSector(buf, 5, 7) == 0x2)
  {
   printf("CRC32: 0x%08x\n", (uint32)crc32(0, &buf[0], 0x3278));
  }
 }
#endif

 return(true);
}

static const char *CalcDiscSCEx_BySYSTEMCNF(CDIF *c, unsigned *rr)
{
 const char *ret = NULL;
 Stream *fp = NULL;
 CDUtility::TOC toc;

 //(*CDInterfaces)[disc]->ReadTOC(&toc);

 //if(toc.first_track > 1 || toc.

 try
 {
  uint8 pvd[2048];
  unsigned pvd_search_count = 0;

  fp = c->MakeStream(0, ~0U);
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
  while(fp->tell() < (((int64)rdel * 2048) + rdel_len))
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
     if(!strncasecmp(bootpos, "cdrom:\\", 7))
     { 
      bootpos += 7;
      char *tmp;

      if((tmp = strchr(bootpos, '_'))) *tmp = 0;
      if((tmp = strchr(bootpos, '.'))) *tmp = 0;
      if((tmp = strchr(bootpos, ';'))) *tmp = 0;
      //puts(bootpos);

      if(strlen(bootpos) == 4 && bootpos[0] == 'S' && (bootpos[1] == 'C' || bootpos[1] == 'L' || bootpos[1] == 'I'))
      {
       switch(bootpos[2])
       {
	case 'E': if(rr)
		   *rr = REGION_EU;
		  ret = "SCEE";
		  goto Breakout;

	case 'U': if(rr)
		   *rr = REGION_NA;
		  ret = "SCEA";
		  goto Breakout;

	case 'K':	// Korea?
	case 'B':
	case 'P': if(rr)
		   *rr = REGION_JP;
		  ret = "SCEI";
		  goto Breakout;
       }
      }
     }
    }
  
    //puts((char*)fb);
    //puts("ASOFKOASDFKO");
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

 Breakout:
 if(fp != NULL)
 {
  delete fp;
  fp = NULL;
 }

 return(ret);
}

static unsigned CalcDiscSCEx(void)
{
 const char *prev_valid_id = NULL;
 unsigned ret_region = MDFN_GetSettingI("psx.region_default");

 cdifs_scex_ids.clear();

if(cdifs)
 for(unsigned i = 0; i < cdifs->size(); i++)
 {
  const char *id = NULL;
  uint8 buf[2048];
  uint8 fbuf[2048 + 1];
  unsigned ipos, opos;


  id = CalcDiscSCEx_BySYSTEMCNF((*cdifs)[i], (i == 0) ? &ret_region : NULL);

  memset(fbuf, 0, sizeof(fbuf));

  if(id == NULL && (*cdifs)[i]->ReadSector(buf, 4, 1) == 0x2)
  {
   for(ipos = 0, opos = 0; ipos < 0x48; ipos++)
   {
    if(buf[ipos] > 0x20 && buf[ipos] < 0x80)
    {
     fbuf[opos++] = tolower(buf[ipos]);
    }
   }

   fbuf[opos++] = 0;

   PSX_DBG(PSX_DBG_SPARSE, "License string: %s", (char *)fbuf);

   if(strstr((char *)fbuf, "licensedby") != NULL)
   {
    if(strstr((char *)fbuf, "america") != NULL)
    {
     id = "SCEA";
     if(!i)
      ret_region = REGION_NA;
    }
    else if(strstr((char *)fbuf, "europe") != NULL)
    {
     id = "SCEE";
     if(!i)
      ret_region = REGION_EU;
    }
    else if(strstr((char *)fbuf, "japan") != NULL)
    {
     id = "SCEI";	// ?
     if(!i)
      ret_region = REGION_JP;
    }
    else if(strstr((char *)fbuf, "sonycomputerentertainmentinc.") != NULL)
    {
     id = "SCEI";
     if(!i)
      ret_region = REGION_JP;
    }
    else	// Failure case
    {
     if(prev_valid_id != NULL)
      id = prev_valid_id;
     else
     {
      switch(ret_region)	// Less than correct, but meh, what can we do.
      {
       case REGION_JP:
	id = "SCEI";
	break;

       case REGION_NA:
	id = "SCEA";
	break;

       case REGION_EU:
	id = "SCEE";
	break;
      }
     }
    }
   }
  }

  if(id != NULL)
   prev_valid_id = id;

  cdifs_scex_ids.push_back(id);
 }

 return ret_region;
}

static void InitCommon(std::vector<CDIF *> *CDInterfaces, const bool EmulateMemcards = true, const bool WantPIOMem = false)
{
 unsigned region;
 bool emulate_memcard[8];
 bool emulate_multitap[2];
 int sls, sle;

#if PSX_DBGPRINT_ENABLE
 psx_dbg_level = MDFN_GetSettingUI("psx.dbg_level");
#endif

 for(unsigned i = 0; i < 8; i++)
 {
  char buf[64];
  trio_snprintf(buf, sizeof(buf), "psx.input.port%u.memcard", i + 1);
  emulate_memcard[i] = EmulateMemcards && MDFN_GetSettingB(buf);
 }

 for(unsigned i = 0; i < 2; i++)
 {
  char buf[64];
  trio_snprintf(buf, sizeof(buf), "psx.input.pport%u.multitap", i + 1);
  emulate_multitap[i] = MDFN_GetSettingB(buf);
 }


 cdifs = CDInterfaces;
 region = CalcDiscSCEx();

 if(!MDFN_GetSettingB("psx.region_autodetect"))
  region = MDFN_GetSettingI("psx.region_default");

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
 GPU = new PS_GPU(region == REGION_EU, sls, sle);
 CDC = new PS_CDC();
 FIO = new FrontIO(emulate_memcard, emulate_multitap);
 FIO->SetAMCT(MDFN_GetSettingB("psx.input.analog_mode_ct"));
 for(unsigned i = 0; i < 8; i++)
 {
  char buf[64];
  trio_snprintf(buf, sizeof(buf), "psx.input.port%u.gun_chairs", i + 1);
  FIO->SetCrosshairsColor(i, MDFN_GetSettingUI(buf));
 }

 DMA_Init();

 GPU->FillVideoParams(&EmulatedPSX);

 if(cdifs)
 {
  CD_TrayOpen = false;
  CD_SelectedDisc = 0;
 }
 else
 {
  CD_TrayOpen = true;
  CD_SelectedDisc = -1;
 }

 CDC->SetDisc(true, NULL, NULL);
 CDC->SetDisc(CD_TrayOpen, (CD_SelectedDisc >= 0 && !CD_TrayOpen) ? (*cdifs)[CD_SelectedDisc] : NULL,
	(CD_SelectedDisc >= 0 && !CD_TrayOpen) ? cdifs_scex_ids[CD_SelectedDisc] : NULL);


 BIOSROM = new MultiAccessSizeMem<512 * 1024, uint32, false>();

 if(WantPIOMem)
  PIOMem = new MultiAccessSizeMem<65536, uint32, false>();
 else
  PIOMem = NULL;

 for(uint32 ma = 0x00000000; ma < 0x00800000; ma += 2048 * 1024)
 {
  CPU->SetFastMap(MainRAM.data32, 0x00000000 + ma, 2048 * 1024);
  CPU->SetFastMap(MainRAM.data32, 0x80000000 + ma, 2048 * 1024);
  CPU->SetFastMap(MainRAM.data32, 0xA0000000 + ma, 2048 * 1024);
 }

 CPU->SetFastMap(BIOSROM->data32, 0x1FC00000, 512 * 1024);
 CPU->SetFastMap(BIOSROM->data32, 0x9FC00000, 512 * 1024);
 CPU->SetFastMap(BIOSROM->data32, 0xBFC00000, 512 * 1024);

 if(PIOMem)
 {
  CPU->SetFastMap(PIOMem->data32, 0x1F000000, 65536);
  CPU->SetFastMap(PIOMem->data32, 0x9F000000, 65536);
  CPU->SetFastMap(PIOMem->data32, 0xBF000000, 65536);
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
  std::string biospath = MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, MDFN_GetSettingS(biospath_sname).c_str());
  FileStream BIOSFile(biospath.c_str(), FileStream::MODE_READ);

  BIOSFile.read(BIOSROM->data8, 512 * 1024);
 }

 for(int i = 0; i < 8; i++)
 {
  char ext[64];
  trio_snprintf(ext, sizeof(ext), "%d.mcr", i);
  FIO->LoadMemcard(i, MDFN_MakeFName(MDFNMKF_SAV, 0, ext).c_str());
 }

 for(int i = 0; i < 8; i++)
 {
  Memcard_PrevDC[i] = FIO->GetMemcardDirtyCount(i);
  Memcard_SaveDelay[i] = -1;
 }


 #ifdef WANT_DEBUGGER
 DBG_Init();
 #endif

 PSX_Power();
}

static void LoadEXE(const uint8 *data, const uint32 size, bool ignore_pcsp = false)
{
 uint32 PC;
 uint32 SP;
 uint32 TextStart;
 uint32 TextSize;

 if(size < 0x800)
  throw(MDFN_Error(0, "PS-EXE is too small."));

 PC = MDFN_de32lsb(&data[0x10]);
 SP = MDFN_de32lsb(&data[0x30]);
 TextStart = MDFN_de32lsb(&data[0x18]);
 TextSize = MDFN_de32lsb(&data[0x1C]);

 if(ignore_pcsp)
  MDFN_printf("TextStart=0x%08x\nTextSize=0x%08x\n", TextStart, TextSize);
 else
  MDFN_printf("PC=0x%08x\nSP=0x%08x\nTextStart=0x%08x\nTextSize=0x%08x\n", PC, SP, TextStart, TextSize);

 TextStart &= 0x1FFFFF;

 if(TextSize > 2048 * 1024)
 {
  throw(MDFN_Error(0, "Text section too large"));
 }

 if(TextSize > (size - 0x800))
  throw(MDFN_Error(0, "Text section recorded size is larger than data available in file.  Header=0x%08x, Available=0x%08x", TextSize, size - 0x800));

 if(TextSize < (size - 0x800))
  throw(MDFN_Error(0, "Text section recorded size is smaller than data available in file.  Header=0x%08x, Available=0x%08x", TextSize, size - 0x800));

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

 memcpy(&TextMem[TextStart - TextMem_Start], data + 0x800, TextSize);


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

PSF1Loader::PSF1Loader(MDFNFILE *fp)
{
 tags = Load(0x01, 2033664, fp);
}

PSF1Loader::~PSF1Loader()
{

}

void PSF1Loader::HandleEXE(const uint8 *data, uint32 size, bool ignore_pcsp)
{
 LoadEXE(data, size, ignore_pcsp);
}

static void Cleanup(void);
static int Load(MDFNFILE *fp)
{
 try
 {
  const bool IsPSF = PSFLoader::TestMagic(0x01, fp);

  if(!TestMagic(fp))
   throw MDFN_Error(0, _("File format is unknown to module \"%s\"."), MDFNGameInfo->shortname);

// For testing.
#if 0
  #warning "GREMLINS GREMLINS EVERYWHEREE IYEEEEEE"
  #warning "Seriously, GREMLINS!  Or peanut butter.  Or maybe...DINOSAURS."

  static std::vector<CDIF *> CDInterfaces;

  //CDInterfaces.push_back(CDIF_Open("/home/sarah-projects/psxdev/tests/cd/adpcm.cue", false, false));
  //CDInterfaces.push_back(CDIF_Open("/extra/games/PSX/Tony Hawk's Pro Skater 2 (USA)/Tony Hawk's Pro Skater 2 (USA).cue", false, false));
  //CDInterfaces.push_back(CDIF_Open("/extra/games/PSX/Jumping Flash! (USA)/Jumping Flash! (USA).cue", false, false));
  //CDInterfaces.push_back(CDIF_Open("/extra/games/PC-FX/Blue Breaker.cue", false, false));
  CDInterfaces.push_back(CDIF_Open("/dev/cdrom2", true, false));
  InitCommon(&CDInterfaces, !IsPSF, true);
#else
  InitCommon(NULL, !IsPSF, true);
#endif

  TextMem.resize(0);

  if(IsPSF)
  {
   psf_loader = new PSF1Loader(fp);

   std::vector<std::string> SongNames;

   SongNames.push_back(psf_loader->tags.GetTag("title"));

   Player_Init(1, psf_loader->tags.GetTag("game"), psf_loader->tags.GetTag("artist"), psf_loader->tags.GetTag("copyright"), SongNames);
  }
  else
   LoadEXE(fp->data, fp->size);
 }
 catch(std::exception &e)
 {
  Cleanup();
  throw;
 }

 return(1);
}

static void LoadCD(std::vector<CDIF *> *CDInterfaces)
{
 try
 {
  InitCommon(CDInterfaces);

  MDFNGameInfo->GameType = GMT_CDROM;
 }
 catch(std::exception &e)
 {
  Cleanup();
  throw;
 }
}

static void Cleanup(void)
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

 if(GPU)
 {
  delete GPU;
  GPU = NULL;
 }

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

static void CloseGame(void)
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

    FIO->SaveMemcard(i, MDFN_MakeFName(MDFNMKF_SAV, 0, ext).c_str());
   }
   catch(std::exception &e)
   {
    MDFN_PrintError("%s", e.what());
   }
  }
 }

 Cleanup();
}


static void SetInput(int port, const char *type, void *ptr)
{
 if(psf_loader)
  FIO->SetInput(port, "none", NULL);
 else
  FIO->SetInput(port, type, ptr);
}

static int StateAction(StateMem *sm, int load, int data_only)
{
 if(!MDFN_GetSettingB("psx.clobbers_lament"))
 {
  return(0);
 }

 SFORMAT StateRegs[] =
 {
  SFVAR(CD_TrayOpen),
  SFVAR(CD_SelectedDisc),
  SFARRAY(MainRAM.data8, 1024 * 2048),
  SFARRAY32(SysControl.Regs, 9),

  SFVAR(PSX_PRNG.lcgo),
  SFVAR(PSX_PRNG.x),
  SFVAR(PSX_PRNG.y),
  SFVAR(PSX_PRNG.z),
  SFVAR(PSX_PRNG.c),

  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAIN");

 // Call SetDisc() BEFORE we load CDC state, since SetDisc() has emulation side effects.  We might want to clean this up in the future.
 if(load)
 {
  if(!cdifs || CD_SelectedDisc >= (int)cdifs->size())
   CD_SelectedDisc = -1;

  CDC->SetDisc(CD_TrayOpen, (CD_SelectedDisc >= 0 && !CD_TrayOpen) ? (*cdifs)[CD_SelectedDisc] : NULL,
	(CD_SelectedDisc >= 0 && !CD_TrayOpen) ? cdifs_scex_ids[CD_SelectedDisc] : NULL);
 }

 // TODO: Remember to increment dirty count in memory card state loading routine.

 ret &= CPU->StateAction(sm, load, data_only);
 ret &= DMA_StateAction(sm, load, data_only);
 ret &= TIMER_StateAction(sm, load, data_only);
 ret &= SIO_StateAction(sm, load, data_only);

 ret &= CDC->StateAction(sm, load, data_only);
 ret &= MDEC_StateAction(sm, load, data_only);
 ret &= GPU->StateAction(sm, load, data_only);
 ret &= SPU->StateAction(sm, load, data_only);

 ret &= FIO->StateAction(sm, load, data_only);

 ret &= IRQ_StateAction(sm, load, data_only);	// Do it last.

 if(load)
 {
  ForceEventUpdates(0);	// FIXME to work with debugger step mode.
 }

 return(ret);
}

static void CDInsertEject(void)
{
 CD_TrayOpen = !CD_TrayOpen;

 for(unsigned disc = 0; disc < cdifs->size(); disc++)
 {
  if(!(*cdifs)[disc]->Eject(CD_TrayOpen))
  {
   MDFN_DispMessage(_("Eject error."));
   CD_TrayOpen = !CD_TrayOpen;
  }
 }

 if(CD_TrayOpen)
  MDFN_DispMessage(_("Virtual CD Drive Tray Open"));
 else
  MDFN_DispMessage(_("Virtual CD Drive Tray Closed"));

 CDC->SetDisc(CD_TrayOpen, (CD_SelectedDisc >= 0 && !CD_TrayOpen) ? (*cdifs)[CD_SelectedDisc] : NULL,
	(CD_SelectedDisc >= 0 && !CD_TrayOpen) ? cdifs_scex_ids[CD_SelectedDisc] : NULL);
}

static void CDEject(void)
{
 if(!CD_TrayOpen)
  CDInsertEject();
}

static void CDSelect(void)
{
 if(cdifs && CD_TrayOpen)
 {
  CD_SelectedDisc = (CD_SelectedDisc + 1) % (cdifs->size() + 1);

  if((unsigned)CD_SelectedDisc == cdifs->size())
   CD_SelectedDisc = -1;

  if(CD_SelectedDisc == -1)
   MDFN_DispMessage(_("Disc absence selected."));
  else
   MDFN_DispMessage(_("Disc %d of %d selected."), CD_SelectedDisc + 1, (int)cdifs->size());
 }
}


static void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_RESET: PSX_Power(); break;
  case MDFN_MSC_POWER: PSX_Power(); break;

  case MDFN_MSC_INSERT_DISK:
                CDInsertEject();
                break;

  case MDFN_MSC_SELECT_DISK:
                CDSelect();
                break;

  case MDFN_MSC_EJECT_DISK:
                CDEject();
                break;
 }
}

static void GSCondCode(MemoryPatch* patch, const char* cc, const unsigned len, const uint32 addr, const uint16 val)
{
 char tmp[256];

 if(patch->conditions.size() > 0)
  patch->conditions.append(", ");

 if(len == 2)
  trio_snprintf(tmp, 256, "%u L 0x%08x %s 0x%04x", len, addr, cc, val & 0xFFFFU);
 else
  trio_snprintf(tmp, 256, "%u L 0x%08x %s 0x%02x", len, addr, cc, val & 0xFFU);

 patch->conditions.append(tmp);
}

static bool DecodeGS(const std::string& cheat_string, MemoryPatch* patch)
{
 uint64 code = 0;
 unsigned nybble_count = 0;

 for(unsigned i = 0; i < cheat_string.size(); i++)
 {
  if(cheat_string[i] == ' ' || cheat_string[i] == '-' || cheat_string[i] == ':')
   continue;

  nybble_count++;
  code <<= 4;

  if(cheat_string[i] >= '0' && cheat_string[i] <= '9')
   code |= cheat_string[i] - '0';
  else if(cheat_string[i] >= 'a' && cheat_string[i] <= 'f')
   code |= cheat_string[i] - 'a' + 0xA;
  else if(cheat_string[i] >= 'A' && cheat_string[i] <= 'F')
   code |= cheat_string[i] - 'A' + 0xA;  
  else
  {
   if(cheat_string[i] & 0x80)
    throw MDFN_Error(0, _("Invalid character in GameShark code."));
   else
    throw MDFN_Error(0, _("Invalid character in GameShark code: %c"), cheat_string[i]);
  }
 }

 if(nybble_count != 12)
  throw MDFN_Error(0, _("GameShark code is of an incorrect length."));

 const uint8 code_type = code >> 40;
 const uint64 cl = code & 0xFFFFFFFFFFULL;

 patch->bigendian = false;
 patch->compare = 0;

 if(patch->type == 'T')
 {
  if(code_type != 0x80)
   throw MDFN_Error(0, _("Unrecognized GameShark code type for second part to copy bytes code."));

  patch->addr = cl >> 16;
  return(false);
 }

 switch(code_type)
 {
  default:
	throw MDFN_Error(0, _("GameShark code type 0x%02X is currently not supported."), code_type);

	return(false);

  //
  //
  // TODO:
  case 0x10:	// 16-bit increment
	patch->length = 2;
	patch->type = 'A';
	patch->addr = cl >> 16;
	patch->val = cl & 0xFFFF;
	return(false);

  case 0x11:	// 16-bit decrement
	patch->length = 2;
	patch->type = 'A';
	patch->addr = cl >> 16;
	patch->val = (0 - cl) & 0xFFFF;
	return(false);

  case 0x20:	// 8-bit increment
	patch->length = 1;
	patch->type = 'A';
	patch->addr = cl >> 16;
	patch->val = cl & 0xFF;
	return(false);

  case 0x21:	// 8-bit decrement
	patch->length = 1;
	patch->type = 'A';
	patch->addr = cl >> 16;
	patch->val = (0 - cl) & 0xFF;
	return(false);
  //
  //
  //

  case 0x30:	// 8-bit constant
	patch->length = 1;
	patch->type = 'R';
	patch->addr = cl >> 16;
	patch->val = cl & 0xFF;
	return(false);

  case 0x80:	// 16-bit constant
	patch->length = 2;
	patch->type = 'R';
	patch->addr = cl >> 16;
	patch->val = cl & 0xFFFF;
	return(false);

  case 0x50:	// Repeat thingy
	{
	 const uint8 wcount = (cl >> 24) & 0xFF;
	 const uint8 addr_inc = (cl >> 16) & 0xFF;
	 const uint8 val_inc = (cl >> 0) & 0xFF;

	 patch->mltpl_count = wcount;
	 patch->mltpl_addr_inc = addr_inc;
	 patch->mltpl_val_inc = val_inc;
	}
	return(true);

  case 0xC2:	// Copy
	{
	 const uint16 ccount = cl & 0xFFFF;

	 patch->type = 'T';
	 patch->val = 0;
	 patch->length = 1;

	 patch->copy_src_addr = cl >> 16;
	 patch->copy_src_addr_inc = 1;

	 patch->mltpl_count = ccount;
	 patch->mltpl_addr_inc = 1;
	 patch->mltpl_val_inc = 0;
	}
	return(true);

  case 0xD0:	// 16-bit == condition
	GSCondCode(patch, "==", 2, cl >> 16, cl);
	return(true);

  case 0xD1:	// 16-bit != condition
	GSCondCode(patch, "!=", 2, cl >> 16, cl);
	return(true);

  case 0xD2:	// 16-bit < condition
	GSCondCode(patch, "<", 2, cl >> 16, cl);
	return(true);

  case 0xD3:	// 16-bit > condition
	GSCondCode(patch, ">", 2, cl >> 16, cl);
	return(true);



  case 0xE0:	// 8-bit == condition
	GSCondCode(patch, "==", 1, cl >> 16, cl);
	return(true);

  case 0xE1:	// 8-bit != condition
	GSCondCode(patch, "!=", 1, cl >> 16, cl);
	return(true);

  case 0xE2:	// 8-bit < condition
	GSCondCode(patch, "<", 1, cl >> 16, cl);
	return(true);

  case 0xE3:	// 8-bit > condition
	GSCondCode(patch, ">", 1, cl >> 16, cl);
	return(true);

 }
}

static CheatFormatStruct CheatFormats[] =
{
 { "GameShark", gettext_noop("Sharks with lamprey eels for eyes."), DecodeGS },
};

static CheatFormatInfoStruct CheatFormatInfo =
{
 1,
 CheatFormats
};

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".psf", gettext_noop("PSF1 Rip") },
 { ".minipsf", gettext_noop("MiniPSF1 Rip") },
 { ".psx", gettext_noop("PS-X Executable") },
 { ".exe", gettext_noop("PS-X Executable") },
 { NULL, NULL }
};

static const MDFNSetting_EnumList Region_List[] =
{
 { "jp", REGION_JP, gettext_noop("Japan") },
 { "na", REGION_NA, gettext_noop("North America") },
 { "eu", REGION_EU, gettext_noop("Europe") },
 { NULL, 0 },
};

#if 0
static const MDFNSetting_EnumList MultiTap_List[] =
{
 { "0", 0, gettext_noop("Disabled") },
 { "1", 1, gettext_noop("Enabled") },
 { "auto", 0, gettext_noop("Automatically-enable multitap."), gettext_noop("NOT IMPLEMENTED YET(currently equivalent to 0)") },
 { NULL, 0 },
};
#endif

static MDFNSetting PSXSettings[] =
{
 { "psx.input.mouse_sensitivity", MDFNSF_NOFLAGS, gettext_noop("Emulated mouse sensitivity."), NULL, MDFNST_FLOAT, "1.00", NULL, NULL },

 { "psx.input.analog_mode_ct", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable analog mode combo-button alternate toggle."), gettext_noop("When enabled, instead of the configured Analog mode toggle button for the emulated DualShock, use a combination of buttons to toggle it instead.  When Select, Start, and all four shoulder buttons are held down for about 1 second, the mode will toggle."), MDFNST_BOOL, "0", NULL, NULL },

 { "psx.input.pport1.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap on PSX port 1."), gettext_noop("Makes 3 more virtual ports available.\n\nNOTE: Enabling multitap in games that don't fully support it may cause deleterious effects."), MDFNST_BOOL, "0", NULL, NULL }, //MDFNST_ENUM, "auto", NULL, NULL, NULL, NULL, MultiTap_List },
 { "psx.input.pport2.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap on PSX port 2."), gettext_noop("Makes 3 more virtual ports available.\n\nNOTE: Enabling multitap in games that don't fully support it may cause deleterious effects."), MDFNST_BOOL, "0", NULL, NULL },

 { "psx.input.port1.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memcard on virtual port 1."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port2.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memcard on virtual port 2."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port3.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memcard on virtual port 3."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port4.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memcard on virtual port 4."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port5.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memcard on virtual port 5."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port6.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memcard on virtual port 6."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port7.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memcard on virtual port 7."), NULL, MDFNST_BOOL, "1", NULL, NULL, },
 { "psx.input.port8.memcard", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulate memcard on virtual port 8."), NULL, MDFNST_BOOL, "1", NULL, NULL, },


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

 { "psx.bios_jp", MDFNSF_EMU_STATE, gettext_noop("Path to the Japan SCPH-5500 ROM BIOS"), NULL, MDFNST_STRING, "scph5500.bin" },
 { "psx.bios_na", MDFNSF_EMU_STATE, gettext_noop("Path to the North America SCPH-5501 ROM BIOS"), gettext_noop("SHA1 0555c6fae8906f3f09baf5988f00e55f88e9f30b"), MDFNST_STRING, "scph5501.bin" },
 { "psx.bios_eu", MDFNSF_EMU_STATE, gettext_noop("Path to the Europe SCPH-5502 ROM BIOS"), NULL, MDFNST_STRING, "scph5502.bin" },

 { "psx.spu.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("SPU output resampler quality."),
	gettext_noop("0 is lowest quality and CPU usage, 10 is highest quality and CPU usage.  The resampler that this setting refers to is used for converting from 44.1KHz to the sampling rate of the host audio device Mednafen is using.  Changing Mednafen's output rate, via the \"sound.rate\" setting, to \"44100\" may bypass the resampler, which can decrease CPU usage by Mednafen, and can increase or decrease audio quality, depending on various operating system and hardware factors."), MDFNST_UINT, "5", "0", "10" },


 { "psx.slstart", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in NTSC mode."), NULL, MDFNST_INT, "0", "0", "239" },
 { "psx.slend", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in NTSC mode."), NULL, MDFNST_INT, "239", "0", "239" },

 { "psx.slstartp", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in PAL mode."), NULL, MDFNST_INT, "0", "0", "287" },
 { "psx.slendp", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in PAL mode."), NULL, MDFNST_INT, "287", "0", "287" },

#if PSX_DBGPRINT_ENABLE
 { "psx.dbg_level", MDFNSF_NOFLAGS, gettext_noop("Debug printf verbosity level."), NULL, MDFNST_UINT, "0", "0", "4" },
#endif

 { "psx.clobbers_lament", MDFNSF_NOFLAGS, gettext_noop("Enable experimental save state functionality."), gettext_noop("Save states will destroy your saved game/memory card data if you're careless, and that will make clobber sad.  Poor clobber."), MDFNST_BOOL, "0" },

 { NULL },
};

// Note for the future: If we ever support PSX emulation with non-8-bit RGB color components, or add a new linear RGB colorspace to MDFN_PixelFormat, we'll need
// to buffer the intermediate 24-bit non-linear RGB calculation into an array and pass that into the GPULineHook stuff, otherwise netplay could break when
// an emulated GunCon is used.  This IS assuming, of course, that we ever implement save state support so that netplay actually works at all...
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
 &FIO_InputInfo,
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
 NULL,
 NULL,
 &CheatFormatInfo,
 false,
 StateAction,
 Emulate,
 SetInput,
 DoSimpleCommand,
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
