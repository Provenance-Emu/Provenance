/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* ss.cpp - Saturn Core Emulation and Support Functions
**  Copyright (C) 2015-2017 Mednafen Team
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

// WARNING: Be careful with 32-bit access to 16-bit space, bus locking, etc. in respect to DMA and event updates(and where they can occur).

#include <mednafen/mednafen.h>
#include <mednafen/cdrom/cdromif.h>
#include <mednafen/general.h>
#include <mednafen/FileStream.h>
#include <mednafen/compress/GZFileStream.h>
#include <mednafen/mempatcher.h>
#include <mednafen/hash/sha256.h>
#include <mednafen/hash/md5.h>
#include <mednafen/Time.h>

#include <bitset>

#include <trio/trio.h>

#include <zlib.h>

extern MDFNGI EmulatedSS;

#include "ss.h"
#include "sound.h"
#include "scsp.h"	// For debug.inc
#include "smpc.h"
#include "cdb.h"
#include "vdp1.h"
#include "vdp2.h"
#include "scu.h"
#include "cart.h"
#include "db.h"

namespace MDFN_IEN_SS
{

static sscpu_timestamp_t MidSync(const sscpu_timestamp_t timestamp);

#ifdef MDFN_SS_DEV_BUILD
uint32 ss_dbg_mask;
#endif
static bool NeedEmuICache;
static const uint8 BRAM_Init_Data[0x10] = { 0x42, 0x61, 0x63, 0x6b, 0x55, 0x70, 0x52, 0x61, 0x6d, 0x20, 0x46, 0x6f, 0x72, 0x6d, 0x61, 0x74 };

static void SaveBackupRAM(void);
static void LoadBackupRAM(void);
static void SaveCartNV(void);
static void LoadCartNV(void);
static void SaveRTC(void);
static void LoadRTC(void);

static MDFN_COLD void BackupBackupRAM(void);
static MDFN_COLD void BackupCartNV(void);


#include "sh7095.h"

static uint8 SCU_MSH2VectorFetch(void);
static uint8 SCU_SSH2VectorFetch(void);

static void INLINE MDFN_HOT CheckEventsByMemTS(void);

SH7095 CPU[2]{ {"SH2-M", SS_EVENT_SH2_M_DMA, SCU_MSH2VectorFetch}, {"SH2-S", SS_EVENT_SH2_S_DMA, SCU_SSH2VectorFetch}};
static uint16 BIOSROM[524288 / sizeof(uint16)];
static uint16 WorkRAML[1024 * 1024 / sizeof(uint16)];
static uint16 WorkRAMH[1024 * 1024 / sizeof(uint16)];	// Effectively 32-bit in reality, but 16-bit here because of CPU interpreter design(regarding fastmap).
static uint8 BackupRAM[32768];
static bool BackupRAM_Dirty;
static int64 BackupRAM_SaveDelay;
static int64 CartNV_SaveDelay;

#define SH7095_EXT_MAP_GRAN_BITS 16
static uintptr_t SH7095_FastMap[1U << (32 - SH7095_EXT_MAP_GRAN_BITS)];

int32 SH7095_mem_timestamp;
uint32 SH7095_BusLock;
static uint32 SH7095_DB;
#include "scu.inc"

#include "debug.inc"

static sha256_digest BIOS_SHA256;	// SHA-256 hash of the currently-loaded BIOS; used for save state sanity checks.
static std::vector<CDIF*> *cdifs = NULL;
static std::bitset<1U << (27 - SH7095_EXT_MAP_GRAN_BITS)> FMIsWriteable;

template<typename T>
static void INLINE SH7095_BusWrite(uint32 A, T V, const bool BurstHax, int32* SH2DMAHax);

template<typename T>
static T INLINE SH7095_BusRead(uint32 A, const bool BurstHax, int32* SH2DMAHax);

/*
 SH-2 external bus address map:
  CS0: 0x00000000...0x01FFFFFF (16-bit)
	0x00000000...0x000FFFFF: BIOS ROM (R)
	0x00100000...0x0017FFFF: SMPC (R/W; 8-bit mapped as 16-bit)
	0x00180000...0x001FFFFF: Backup RAM(32KiB) (R/W; 8-bit mapped as 16-bit)
	0x00200000...0x003FFFFF: Low RAM(1MiB) (R/W)
	0x01000000...0x017FFFFF: Slave FRT Input Capture Trigger (W)
	0x01800000...0x01FFFFFF: Master FRT Input Capture Trigger (W)

  CS1: 0x02000000...0x03FFFFFF (SCU managed)
	0x02000000...0x03FFFFFF: A-bus CS0 (R/W)

  CS2: 0x04000000...0x05FFFFFF (SCU managed)
	0x04000000...0x04FFFFFF: A-bus CS1 (R/W)
	0x05000000...0x057FFFFF: A-bus Dummy
	0x05800000...0x058FFFFF: A-bus CS2 (R/W)
	0x05A00000...0x05AFFFFF: SCSP RAM (R/W)
	0x05B00000...0x05BFFFFF: SCSP Registers (R/W)
	0x05C00000...0x05C7FFFF: VDP1 VRAM (R/W)
	0x05C80000...0x05CFFFFF: VDP1 FB RAM (R/W; swappable between two framebuffers, but may be temporarily unreadable at swap time)
	0x05D00000...0x05D7FFFF: VDP1 Registers (R/W)
	0x05E00000...0x05EFFFFF: VDP2 VRAM (R/W)
	0x05F00000...0x05F7FFFF: VDP2 CRAM (R/W; 8-bit writes are illegal)
	0x05F80000...0x05FBFFFF: VDP2 Registers (R/W; 8-bit writes are illegal)
	0x05FE0000...0x05FEFFFF: SCU Registers (R/W)
	0x05FF0000...0x05FFFFFF: SCU Debug/Test Registers (R/W)

  CS3: 0x06000000...0x07FFFFFF
	0x06000000...0x07FFFFFF: High RAM/SDRAM(1MiB) (R/W)
*/
//
// Never add anything to SH7095_mem_timestamp when DMAHax is true.
//
// When BurstHax is true and we're accessing high work RAM, don't add anything.
//
template<typename T, bool IsWrite>
static INLINE void BusRW_DB_CS0(const uint32 A, uint32& DB, const bool BurstHax, int32* SH2DMAHax)
{
 //
 // Low(and kinda slow) work RAM 
 //
 if(A >= 0x00200000 && A <= 0x003FFFFF)
 {
  if(IsWrite)
   ne16_wbo_be<T>(WorkRAML, A & 0xFFFFF, DB >> (((A & 1) ^ (2 - sizeof(T))) << 3));
  else
   DB = (DB & 0xFFFF0000) | ne16_rbo_be<uint16>(WorkRAML, A & 0xFFFFE);

  if(!SH2DMAHax)
   SH7095_mem_timestamp += 7;
  else
   *SH2DMAHax -= 7;

  return;
 }

 //
 // BIOS ROM
 //
 if(A >= 0x00000000 && A <= 0x000FFFFF)
 {
  if(!SH2DMAHax)
   SH7095_mem_timestamp += 8;
  else
   *SH2DMAHax -= 8;

  if(!IsWrite) 
   DB = (DB & 0xFFFF0000) | ne16_rbo_be<uint16>(BIOSROM, A & 0x7FFFE);

  return;
 }

 //
 // SMPC
 //
 if(A >= 0x00100000 && A <= 0x0017FFFF)
 {
  const uint32 SMPC_A = (A & 0x7F) >> 1;

  if(!SH2DMAHax)
  {
   // SH7095_mem_timestamp += 2;
   CheckEventsByMemTS();
  }

  if(IsWrite)
  {
   if(sizeof(T) == 2 || (A & 1))
    SMPC_Write(SH7095_mem_timestamp, SMPC_A, DB);
  }
  else
   DB = (DB & 0xFFFF0000) | 0xFF00 | SMPC_Read(SH7095_mem_timestamp, SMPC_A);

  return;
 }

 //
 // Backup RAM
 //
 if(A >= 0x00180000 && A <= 0x001FFFFF)
 {
  if(!SH2DMAHax)
   SH7095_mem_timestamp += 8;
  else
   *SH2DMAHax -= 8;

  if(IsWrite)
  {
   if(sizeof(T) != 1 || (A & 1))
   {
    BackupRAM[(A >> 1) & 0x7FFF] = DB;
    BackupRAM_Dirty = true;
   }
  }
  else
   DB = (DB & 0xFFFF0000) | 0xFF00 | BackupRAM[(A >> 1) & 0x7FFF];

  return;
 }

 //
 // FRT trigger region
 //
 if(A >= 0x01000000 && A <= 0x01FFFFFF)
 {
  if(!SH2DMAHax)
   SH7095_mem_timestamp += 8;
  else
   *SH2DMAHax -= 8;

  //printf("FT FRT%08x %zu %08x %04x %d %d\n", A, sizeof(T), A, V, SMPC_IsSlaveOn(), SH7095_mem_timestamp);
  if(IsWrite)
  {
   if(sizeof(T) != 1)
   {
    const unsigned c = ((A >> 23) & 1) ^ 1;

    if(!c || SMPC_IsSlaveOn())
    {
     CPU[c].SetFTI(true);
     CPU[c].SetFTI(false);
    }
   }
  }
  return;
 }

 //
 //
 //
 if(!SH2DMAHax)
  SH7095_mem_timestamp += 4;
 else
  *SH2DMAHax -= 4;

 if(IsWrite)
  SS_DBG(SS_DBG_WARNING, "[SH2 BUS] Unknown %zu-byte write of 0x%08x to 0x%08x\n", sizeof(T), DB >> (((A & 1) ^ (2 - sizeof(T))) << 3), A);
 else
  SS_DBG(SS_DBG_WARNING, "[SH2 BUS] Unknown %zu-byte read from 0x%08x\n", sizeof(T), A);
}

template<typename T, bool IsWrite>
static INLINE void BusRW_DB_CS123(const uint32 A, uint32& DB, const bool BurstHax, int32* SH2DMAHax)
{
 //
 // CS3: High work RAM/SDRAM, 0x06000000 ... 0x07FFFFFF
 //
 if(A >= 0x06000000)
 {
  if(!IsWrite || sizeof(T) == 4)
   ne16_rwbo_be<uint32, IsWrite>(WorkRAMH, A & 0xFFFFC, &DB);
  else
   ne16_wbo_be<T>(WorkRAMH, A & 0xFFFFF, DB >> (((A & 3) ^ (4 - sizeof(T))) << 3));

  if(!BurstHax)
  {
   if(!SH2DMAHax)
   {
    if(IsWrite)
    {
     SH7095_mem_timestamp = (SH7095_mem_timestamp + 4) &~ 3;
    }
    else
    {
     SH7095_mem_timestamp += 7;
    }
   }
   else
    *SH2DMAHax -= IsWrite ? 3 : 6;
  }
  return;
 }

 //
 // CS1 and CS2: SCU
 //
 if(!IsWrite)
  DB = 0;

 SCU_FromSH2_BusRW_DB<T, IsWrite>(A, &DB, SH2DMAHax);
}

template<typename T>
static void INLINE SH7095_BusWrite(uint32 A, T V, const bool BurstHax, int32* SH2DMAHax)
{
 uint32 DB = SH7095_DB;

 if(A < 0x02000000)	// CS0, configured as 16-bit
 {
  if(sizeof(T) == 4)
  {
   // TODO/FIXME: Don't allow DMA transfers to occur between the two 16-bit accesses.
   //if(!SH2DMAHax)
   // SH7095_BusLock++;

   DB = (DB & 0xFFFF0000) | (V >> 16);
   BusRW_DB_CS0<uint16, true>(A, DB, BurstHax, SH2DMAHax);

   DB = (DB & 0xFFFF0000) | (uint16)V;
   BusRW_DB_CS0<uint16, true>(A | 2, DB, BurstHax, SH2DMAHax);

   //if(!SH2DMAHax)
   // SH7095_BusLock--;
  }
  else
  {
   const uint32 shift = ((A & 1) ^ (2 - sizeof(T))) << 3;
   const uint32 mask = (0xFFFF >> ((2 - sizeof(T)) * 8)) << shift;

   DB = (DB & ~mask) | (V << shift);
   BusRW_DB_CS0<T, true>(A, DB, BurstHax, SH2DMAHax);
  }
 }
 else	// CS1, CS2, CS3; 32-bit
 {
  const uint32 shift = ((A & 3) ^ (4 - sizeof(T))) << 3;
  const uint32 mask = (0xFFFFFFFF >> ((4 - sizeof(T)) * 8)) << shift;

  DB = (DB & ~mask) | (V << shift); // //ne32_wbo_be<T>(&DB, A & 0x3, V);
  BusRW_DB_CS123<T, true>(A, DB, BurstHax, SH2DMAHax);
 }

 SH7095_DB = DB;
}

template<typename T>
static T INLINE SH7095_BusRead(uint32 A, const bool BurstHax, int32* SH2DMAHax)
{
 uint32 DB = SH7095_DB;
 T ret;

 if(A < 0x02000000)	// CS0, configured as 16-bit
 {
  if(sizeof(T) == 4)
  {
   // TODO/FIXME: Don't allow DMA transfers to occur between the two 16-bit accesses.
   //if(!SH2DMAHax)
   // SH7095_BusLock++;

   BusRW_DB_CS0<uint16, false>(A, DB, BurstHax, SH2DMAHax);
   ret = DB << 16;

   BusRW_DB_CS0<uint16, false>(A | 2, DB, BurstHax, SH2DMAHax);
   ret |= (uint16)DB;

   //if(!SH2DMAHax)
   // SH7095_BusLock--;
  }
  else
  {
   BusRW_DB_CS0<T, false>(A, DB, BurstHax, SH2DMAHax);
   ret = DB >> (((A & 1) ^ (2 - sizeof(T))) << 3);
  }
 }
 else	// CS1, CS2, CS3; 32-bit
 {
  BusRW_DB_CS123<T, false>(A, DB, BurstHax, SH2DMAHax);
  ret = DB >> (((A & 3) ^ (4 - sizeof(T))) << 3);

  // SDRAM leaves data bus in a weird state after read...
  //if(A >= 0x06000000)
  // DB = 0;
 }

 SH7095_DB = DB;
 return ret;
}

//
//
//
static MDFN_COLD uint8 CheatMemRead(uint32 A)
{
 A &= (1U << 27) - 1;

 return ne16_rbo_be<uint8>(SH7095_FastMap[A >> SH7095_EXT_MAP_GRAN_BITS], A);
}

static MDFN_COLD void CheatMemWrite(uint32 A, uint8 V)
{
 A &= (1U << 27) - 1;

 if(FMIsWriteable[A >> SH7095_EXT_MAP_GRAN_BITS])
 {
  ne16_wbo_be<uint8>(SH7095_FastMap[A >> SH7095_EXT_MAP_GRAN_BITS], A, V);

  for(unsigned c = 0; c < 2; c++)
  {
   if(CPU[c].CCR & SH7095::CCR_CE)
   {
    for(uint32 Abase = 0x00000000; Abase < 0x20000000; Abase += 0x08000000)
    {
     CPU[c].Write_UpdateCache<uint8>(Abase + A, V);
    }
   }
  }
 }
}
//
//
//
static void SetFastMemMap(uint32 Astart, uint32 Aend, uint16* ptr, uint32 length, bool is_writeable)
{
 const uint64 Abound = (uint64)Aend + 1;
 assert((Astart & ((1U << SH7095_EXT_MAP_GRAN_BITS) - 1)) == 0);
 assert((Abound & ((1U << SH7095_EXT_MAP_GRAN_BITS) - 1)) == 0);
 assert((length & ((1U << SH7095_EXT_MAP_GRAN_BITS) - 1)) == 0);
 assert(length > 0);
 assert(length <= (Abound - Astart));

 for(uint64 A = Astart; A < Abound; A += (1U << SH7095_EXT_MAP_GRAN_BITS))
 {
  uintptr_t tmp = (uintptr_t)ptr + ((A - Astart) % length);

  if(A < (1U << 27))
   FMIsWriteable[A >> SH7095_EXT_MAP_GRAN_BITS] = is_writeable;

  SH7095_FastMap[A >> SH7095_EXT_MAP_GRAN_BITS] = tmp - A;
 }
}

static uint16 fmap_dummy[(1U << SH7095_EXT_MAP_GRAN_BITS) / sizeof(uint16)];

static MDFN_COLD void InitFastMemMap(void)
{
 for(unsigned i = 0; i < sizeof(fmap_dummy) / sizeof(fmap_dummy[0]); i++)
 {
  fmap_dummy[i] = 0;
 }

 FMIsWriteable.reset();
 MDFNMP_Init(1ULL << SH7095_EXT_MAP_GRAN_BITS, (1ULL << 27) / (1ULL << SH7095_EXT_MAP_GRAN_BITS));

 for(uint64 A = 0; A < 1ULL << 32; A += (1U << SH7095_EXT_MAP_GRAN_BITS))
 {
  SH7095_FastMap[A >> SH7095_EXT_MAP_GRAN_BITS] = (uintptr_t)fmap_dummy - A;
 }
}

void SS_SetPhysMemMap(uint32 Astart, uint32 Aend, uint16* ptr, uint32 length, bool is_writeable)
{
 assert(Astart < 0x20000000);
 assert(Aend < 0x20000000);

 if(!ptr)
 {
  ptr = fmap_dummy;
  length = sizeof(fmap_dummy);
 }

 for(uint32 Abase = 0; Abase < 0x40000000; Abase += 0x20000000)
  SetFastMemMap(Astart + Abase, Aend + Abase, ptr, length, is_writeable);
}

#include "sh7095.inc"

static bool Running;
event_list_entry events[SS_EVENT__COUNT];
static sscpu_timestamp_t next_event_ts;

template<unsigned c>
static sscpu_timestamp_t SH_DMA_EventHandler(sscpu_timestamp_t et)
{
 if(et < SH7095_mem_timestamp)
 {
  //printf("SH-2 DMA %d reschedule %d->%d\n", c, et, SH7095_mem_timestamp);
  return SH7095_mem_timestamp;
 }

 // Must come after the (et < SH7095_mem_timestamp) check.
 if(MDFN_UNLIKELY(SH7095_BusLock))
  return et + 1;

 return CPU[c].DMA_Update(et);
}

//
//
//

static MDFN_COLD void InitEvents(void)
{
 for(unsigned i = 0; i < SS_EVENT__COUNT; i++)
 {
  if(i == SS_EVENT__SYNFIRST)
   events[i].event_time = 0;
  else if(i == SS_EVENT__SYNLAST)
   events[i].event_time = 0x7FFFFFFF;
  else
   events[i].event_time = 0; //SS_EVENT_DISABLED_TS;

  events[i].prev = (i > 0) ? &events[i - 1] : NULL;
  events[i].next = (i < (SS_EVENT__COUNT - 1)) ? &events[i + 1] : NULL;
 }

 events[SS_EVENT_SH2_M_DMA].event_handler = &SH_DMA_EventHandler<0>;
 events[SS_EVENT_SH2_S_DMA].event_handler = &SH_DMA_EventHandler<1>;

 events[SS_EVENT_SCU_DMA].event_handler = SCU_UpdateDMA;
 events[SS_EVENT_SCU_DSP].event_handler = SCU_UpdateDSP;

 events[SS_EVENT_SMPC].event_handler = SMPC_Update;

 events[SS_EVENT_VDP1].event_handler = VDP1::Update;
 events[SS_EVENT_VDP2].event_handler = VDP2::Update;

 events[SS_EVENT_CDB].event_handler = CDB_Update;

 events[SS_EVENT_SOUND].event_handler = SOUND_Update;

 events[SS_EVENT_CART].event_handler = CART_GetEventHandler();

 events[SS_EVENT_MIDSYNC].event_handler = MidSync;
 events[SS_EVENT_MIDSYNC].event_time = SS_EVENT_DISABLED_TS;
}

static void RebaseTS(const sscpu_timestamp_t timestamp)
{
 for(unsigned i = 0; i < SS_EVENT__COUNT; i++)
 {
  if(i == SS_EVENT__SYNFIRST || i == SS_EVENT__SYNLAST)
   continue;

  assert(events[i].event_time > timestamp);

  if(events[i].event_time != SS_EVENT_DISABLED_TS)
   events[i].event_time -= timestamp;
 }

 next_event_ts = events[SS_EVENT__SYNFIRST].next->event_time;
}

void SS_SetEventNT(event_list_entry* e, const sscpu_timestamp_t next_timestamp)
{
 if(next_timestamp < e->event_time)
 {
  event_list_entry *fe = e;

  do
  {
   fe = fe->prev;
  } while(next_timestamp < fe->event_time);

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

 next_event_ts = (Running ? events[SS_EVENT__SYNFIRST].next->event_time : 0);
}

// Called from debug.cpp too.
void ForceEventUpdates(const sscpu_timestamp_t timestamp)
{
 CPU[0].ForceInternalEventUpdates();

 if(SMPC_IsSlaveOn())
  CPU[1].ForceInternalEventUpdates();

 for(unsigned evnum = SS_EVENT__SYNFIRST + 1; evnum < SS_EVENT__SYNLAST; evnum++)
 {
  if(events[evnum].event_time != SS_EVENT_DISABLED_TS)
   SS_SetEventNT(&events[evnum], events[evnum].event_handler(timestamp));
 }

 next_event_ts = (Running ? events[SS_EVENT__SYNFIRST].next->event_time : 0);
}

static INLINE bool EventHandler(const sscpu_timestamp_t timestamp)
{
 event_list_entry *e;

 while(timestamp >= (e = events[SS_EVENT__SYNFIRST].next)->event_time)	// If Running = 0, EventHandler() may be called even if there isn't an event per-se, so while() instead of do { ... } while
 {
#ifdef MDFN_SS_DEV_BUILD
  const sscpu_timestamp_t etime = e->event_time;
#endif
  sscpu_timestamp_t nt;

  nt = e->event_handler(e->event_time);

#ifdef MDFN_SS_DEV_BUILD
  if(MDFN_UNLIKELY(nt <= etime))
  {
   fprintf(stderr, "which=%d event_time=%d nt=%d timestamp=%d\n", (int)(e - events), etime, nt, timestamp);
   assert(nt > etime);
  }
#endif

  SS_SetEventNT(e, nt);
 }

 return(Running);
}

static void NO_INLINE MDFN_HOT CheckEventsByMemTS_Sub(void)
{
 EventHandler(SH7095_mem_timestamp);
}

static void INLINE CheckEventsByMemTS(void)
{
 if(MDFN_UNLIKELY(SH7095_mem_timestamp >= next_event_ts))
 {
  //puts("Woot");
  CheckEventsByMemTS_Sub();
 }
}

void SS_RequestMLExit(void)
{
 Running = 0;
 next_event_ts = 0;
}

#pragma GCC push_options
#if !defined(__clang__) && defined(__GNUC__) && __GNUC__ < 5
 // gcc 5.3.0 and 6.1.0 produce some braindead code for the big switch() statement at -Os.
 #pragma GCC optimize("Os,no-unroll-loops,no-peel-loops,no-crossjumping")
#else
 #pragma GCC optimize("O2,no-unroll-loops,no-peel-loops,no-crossjumping")
#endif
template<bool EmulateICache, bool DebugMode>
static int32 NO_INLINE MDFN_HOT RunLoop(EmulateSpecStruct* espec)
{
 sscpu_timestamp_t eff_ts = 0;

 //printf("%d %d\n", SH7095_mem_timestamp, CPU[0].timestamp);

 do
 {
  do
  {
   if(DebugMode)
    DBG_CPUHandler<0>(eff_ts);

   CPU[0].Step<0, EmulateICache, DebugMode>();
   CPU[0].DMA_BusTimingKludge();

   while(MDFN_LIKELY(CPU[0].timestamp > CPU[1].timestamp))
   {
    if(DebugMode)
     DBG_CPUHandler<1>(eff_ts);

    CPU[1].Step<1, EmulateICache, DebugMode>();
   }

   eff_ts = CPU[0].timestamp;
   if(SH7095_mem_timestamp > eff_ts)
    eff_ts = SH7095_mem_timestamp;
   else
    SH7095_mem_timestamp = eff_ts;
  } while(MDFN_LIKELY(eff_ts < next_event_ts));
 } while(MDFN_LIKELY(EventHandler(eff_ts)));

 //printf(" End: %d %d -- %d\n", SH7095_mem_timestamp, CPU[0].timestamp, eff_ts);
 return eff_ts;
}
#pragma GCC pop_options

// Must not be called within an event or read/write handler.
void SS_Reset(bool powering_up)
{
 SH7095_BusLock = 0;

 if(powering_up)
 {
  memset(WorkRAML, 0x00, sizeof(WorkRAML));	// TODO: Check
  memset(WorkRAMH, 0x00, sizeof(WorkRAMH));	// TODO: Check
 }

 if(powering_up)
 {
  CPU[0].TruePowerOn();
  CPU[1].TruePowerOn();
 }

 SCU_Reset(powering_up);
 CPU[0].Reset(powering_up);

 SMPC_Reset(powering_up);

 VDP1::Reset(powering_up);
 VDP2::Reset(powering_up);

 CDB_Reset(powering_up);

 SOUND_Reset(powering_up);

 CART_Reset(powering_up);
}

static EmulateSpecStruct* espec;
static bool AllowMidSync;
static int32 cur_clock_div;

static int64 UpdateInputLastBigTS;
static INLINE void UpdateSMPCInput(const sscpu_timestamp_t timestamp)
{
 int32 elapsed_time = (((int64)timestamp * cur_clock_div * 1000 * 1000) - UpdateInputLastBigTS) / (EmulatedSS.MasterClock / MDFN_MASTERCLOCK_FIXED(1));

 UpdateInputLastBigTS += (int64)elapsed_time * (EmulatedSS.MasterClock / MDFN_MASTERCLOCK_FIXED(1));

 SMPC_UpdateInput(elapsed_time);
}

static sscpu_timestamp_t MidSync(const sscpu_timestamp_t timestamp)
{
 if(AllowMidSync)
 {
  //
  // Don't call SOUND_Update() here, it's not necessary and will subtly alter emulation behavior from the perspective of the emulated program
  // (which is not a problem in and of itself, but it's preferable to keep settings from altering emulation behavior when they don't need to).
  //
  //printf("MidSync: %d\n", VDP2::PeekLine());
  if(!espec->NeedSoundReverse)
  {
   espec->SoundBufSize += SOUND_FlushOutput(espec->SoundBuf + (espec->SoundBufSize * 2), espec->SoundBufMaxSize - espec->SoundBufSize, espec->NeedSoundReverse);
   espec->MasterCycles = timestamp * cur_clock_div;
  }
  //printf("%d\n", espec->SoundBufSize);

  SMPC_UpdateOutput();
  //
  //
  MDFN_MidSync(espec);
  //
  //
  UpdateSMPCInput(timestamp);

  AllowMidSync = false;
 }

 return SS_EVENT_DISABLED_TS;
}

static void Emulate(EmulateSpecStruct* espec_arg)
{
 int32 end_ts;

 espec = espec_arg;
 AllowMidSync = MDFN_GetSettingB("ss.midsync");
 MDFNGameInfo->mouse_sensitivity = MDFN_GetSettingF("ss.input.mouse_sensitivity");

 cur_clock_div = SMPC_StartFrame(espec);
 UpdateSMPCInput(0);
 VDP2::StartFrame(espec, cur_clock_div == 61);
 SOUND_StartFrame(espec->SoundRate / espec->soundmultiplier, MDFN_GetSettingUI("ss.scsp.resamp_quality"));
 CART_SetCPUClock(EmulatedSS.MasterClock / MDFN_MASTERCLOCK_FIXED(1), cur_clock_div);
 espec->SoundBufSize = 0;
 espec->MasterCycles = 0;
 espec->soundmultiplier = 1;
 //
 //
 //
 Running = true;	// Set before ForceEventUpdates()
 ForceEventUpdates(0);

#ifdef WANT_DEBUGGER
 #define RLTDAT true
#else
 #define RLTDAT false
#endif
 static int32 (*const rltab[2][2])(EmulateSpecStruct*) =
 {
  //     DebugMode=false        DebugMode=true
  { RunLoop<false, false>, RunLoop<false, RLTDAT> },	// EmulateICache=false
  { RunLoop<true,  false>, RunLoop<true,  RLTDAT> },	// EmulateICache=true
 };
#undef RLTDAT
 end_ts = rltab[NeedEmuICache][DBG_NeedCPUHooks()](espec);

 ForceEventUpdates(end_ts);
 //
 SMPC_EndFrame(espec, end_ts);
 //
 //
 //
 RebaseTS(end_ts);

 CDB_ResetTS();
 SOUND_ResetTS();
 VDP1::AdjustTS(-end_ts);
 VDP2::AdjustTS(-end_ts);
 SMPC_ResetTS();
 SCU_AdjustTS(-end_ts);
 CART_AdjustTS(-end_ts);

 UpdateInputLastBigTS -= (int64)end_ts * cur_clock_div * 1000 * 1000;

 if(!(SH7095_mem_timestamp & 0x40000000))	// or maybe >= 0 instead?
  SH7095_mem_timestamp -= end_ts;

 CPU[0].AdjustTS(-end_ts);

 if(SMPC_IsSlaveOn())
  CPU[1].AdjustTS(-end_ts);
 //
 //
 //
 espec->MasterCycles = end_ts * cur_clock_div;
 espec->SoundBufSize += SOUND_FlushOutput(espec->SoundBuf + (espec->SoundBufSize * 2), espec->SoundBufMaxSize - espec->SoundBufSize, espec->NeedSoundReverse);
 espec->NeedSoundReverse = false;
 //
 //
 //
 SMPC_UpdateOutput();
 //
 //
 //
 if(BackupRAM_Dirty)
 {
  BackupRAM_SaveDelay = (int64)3 * (EmulatedSS.MasterClock / MDFN_MASTERCLOCK_FIXED(1));	// 3 second delay
  BackupRAM_Dirty = false;
 }
 else if(BackupRAM_SaveDelay > 0)
 {
  BackupRAM_SaveDelay -= espec->MasterCycles;

  if(BackupRAM_SaveDelay <= 0)
  {
   try
   {
    SaveBackupRAM();
   }
   catch(std::exception& e)
   {
    MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
    BackupRAM_SaveDelay = (int64)60 * (EmulatedSS.MasterClock / MDFN_MASTERCLOCK_FIXED(1));	// 60 second retry delay.
   }
  }
 }

 if(CART_GetClearNVDirty())
  CartNV_SaveDelay = (int64)3 * (EmulatedSS.MasterClock / MDFN_MASTERCLOCK_FIXED(1));	// 3 second delay
 else if(CartNV_SaveDelay > 0)
 {
  CartNV_SaveDelay -= espec->MasterCycles;

  if(CartNV_SaveDelay <= 0)
  {
   try
   {
    SaveCartNV();
   }
   catch(std::exception& e)
   {
    MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
    CartNV_SaveDelay = (int64)60 * (EmulatedSS.MasterClock / MDFN_MASTERCLOCK_FIXED(1));	// 60 second retry delay.
   }
  }
 }
}

//
//
//

static MDFN_COLD void Cleanup(void)
{
 CART_Kill();

 DBG_Kill();
 VDP1::Kill();
 VDP2::Kill();
 SOUND_Kill();
 CDB_Kill();

 cdifs = NULL;
}

static MDFN_COLD bool IsSaturnDisc(const uint8* sa32k)
{
 if(sha256(&sa32k[0x100], 0xD00) != "96b8ea48819cfa589f24c40aa149c224c420dccf38b730f00156efe25c9bbc8f"_sha256)
  return false;

 if(memcmp(&sa32k[0], "SEGA SEGASATURN ", 16))
  return false;

 return true;
}

static INLINE void CalcGameID(uint8* id_out16, uint8* fd_id_out16, char* sgid)
{
 std::unique_ptr<uint8[]> buf(new uint8[2048]);
 md5_context mctx;

 mctx.starts();

 for(size_t x = 0; x < cdifs->size(); x++)
 {
  auto* c = (*cdifs)[x];
  CDUtility::TOC toc;

  c->ReadTOC(&toc);

  mctx.update_u32_as_lsb(toc.first_track);
  mctx.update_u32_as_lsb(toc.last_track);
  mctx.update_u32_as_lsb(toc.disc_type);

  for(unsigned i = 1; i <= 100; i++)
  {
   const auto& t = toc.tracks[i];

   mctx.update_u32_as_lsb(t.adr);
   mctx.update_u32_as_lsb(t.control);
   mctx.update_u32_as_lsb(t.lba);
   mctx.update_u32_as_lsb(t.valid);
  }

  for(unsigned i = 0; i < 512; i++)
  {
   if(c->ReadSector(&buf[0], i, 1) >= 0x1)
   {
    if(i == 0)
    {
     char* tmp;
     memcpy(sgid, &buf[0x20], 16);
     sgid[16] = 0;
     if((tmp = strrchr(sgid, 'V')))
     {
      do
      {
       *tmp = 0;
      } while(tmp-- != sgid && (signed char)*tmp <= 0x20);
     }
    }

    mctx.update(&buf[0], 2048);
   }
  }

  if(x == 0)
  {
   md5_context fd_mctx = mctx;
   fd_mctx.finish(fd_id_out16);
  }
 }

 mctx.finish(id_out16);
}

//
// Remember to rebuild region database in db.cpp if changing the order of entries in this table(and be careful about game id collisions, e.g. with some Korean games).
//
static const struct
{
 const char c;
 const char* str;	// Community-defined region string that may appear in filename.
 unsigned region;
} region_strings[] =
{
 // Listed in order of preference for multi-region games.
 { 'U', "USA", SMPC_AREA_NA },
 { 'J', "Japan", SMPC_AREA_JP },
 { 'K', "Korea", SMPC_AREA_KR },

 { 'E', "Europe", SMPC_AREA_EU_PAL },
 { 'E', "Germany", SMPC_AREA_EU_PAL },
 { 'E', "France", SMPC_AREA_EU_PAL },
 { 'E', "Spain", SMPC_AREA_EU_PAL },

 { 'B', "Brazil", SMPC_AREA_CSA_NTSC },

 { 'T', nullptr, SMPC_AREA_ASIA_NTSC },
 { 'A', nullptr, SMPC_AREA_ASIA_PAL },
 { 'L', nullptr, SMPC_AREA_CSA_PAL },
};

static INLINE bool DetectRegion(unsigned* const region)
{
 std::unique_ptr<uint8[]> buf(new uint8[2048 * 16]);
 uint64 possible_regions = 0;

 for(auto& c : *cdifs)
 {
  if(c->ReadSector(&buf[0], 0, 16) != 0x1)
   continue;

  if(!IsSaturnDisc(&buf[0]))
   continue;

  for(unsigned i = 0; i < 16; i++)
  {
   for(auto const& rs : region_strings)
   {
    if(rs.c == buf[0x40 + i])
    {
     possible_regions |= (uint64)1 << rs.region;
     break;
    }
   }
  }
  break;
 }

 for(auto const& rs : region_strings)
 {
  if(possible_regions & ((uint64)1 << rs.region))
  {
   *region = rs.region;
   return true;
  }
 }

 return false;
}

static MDFN_COLD bool DetectRegionByFN(const std::string& fn, unsigned* const region)
{
 std::string ss = fn;
 size_t cp_pos;
 uint64 possible_regions = 0;

 while((cp_pos = ss.rfind(')')) != std::string::npos && cp_pos > 0)
 {
  ss.resize(cp_pos);
  //
  size_t op_pos = ss.rfind('(');

  if(op_pos != std::string::npos)
  {
   for(auto const& rs : region_strings)
   {
    if(!rs.str)
     continue;

    size_t rs_pos = ss.find(rs.str, op_pos + 1);

    if(rs_pos != std::string::npos)
    {
     bool leading_ok = true;
     bool trailing_ok = true;

     for(size_t i = rs_pos - 1; i > op_pos; i--)
     {
      if(ss[i] == ',')
       break;
      else if(ss[i] != ' ')
      {
       leading_ok = false;
       break;
      }
     }

     for(size_t i = rs_pos + strlen(rs.str); i < ss.size(); i++)
     {
      if(ss[i] == ',')
       break;
      else if(ss[i] != ' ')
      {
       trailing_ok = false;
       break;
      }
     }

     if(leading_ok && trailing_ok)
      possible_regions |= (uint64)1 << rs.region;
    }
   }
  }
 }

 for(auto const& rs : region_strings)
 {
  if(possible_regions & ((uint64)1 << rs.region))
  {
   *region = rs.region;
   return true;
  }
 }

 return false;
}

static void MDFN_COLD InitCommon(const unsigned cpucache_emumode, const unsigned cart_type, const unsigned smpc_area)
{
#ifdef MDFN_SS_DEV_BUILD
 ss_dbg_mask = SS_DBG_ERROR;
 {
  std::vector<uint64> dms = MDFN_GetSettingMultiUI("ss.dbg_mask");

  for(uint64 dmse : dms)
   ss_dbg_mask |= dmse;
 }
#endif
 //
 {
  const struct
  {
   unsigned mode;
   const char* name;
  } CPUCacheEmuModes[] =
  {
   { CPUCACHE_EMUMODE_DATA_CB,	_("Data only, with high-level bypass") },
   { CPUCACHE_EMUMODE_DATA,	_("Data only") },
   { CPUCACHE_EMUMODE_FULL,	_("Full") },
  };
  const char* cem = _("Unknown");

  for(auto const& ceme : CPUCacheEmuModes)
  {
   if(ceme.mode == cpucache_emumode)
   {
    cem = ceme.name;
    break;
   }
  }
  MDFN_printf(_("CPU Cache Emulation Mode: %s\n"), cem);
 }
 //
 {
  MDFN_printf(_("Region: 0x%01x\n"), smpc_area);
  const struct
  {
   const unsigned type;
   const char* name;
  } CartNames[] =
  {
   { CART_NONE, _("None") },
   { CART_BACKUP_MEM, _("Backup Memory") },
   { CART_EXTRAM_1M, _("1MiB Extended RAM") },
   { CART_EXTRAM_4M, _("4MiB Extended RAM") },
   { CART_KOF95, _("King of Fighters '95 ROM") },
   { CART_ULTRAMAN, _("Ultraman ROM") },
   { CART_CS1RAM_16M, _("16MiB CS1 RAM") },
   { CART_NLMODEM, _("Netlink Modem") },
   { CART_MDFN_DEBUG, _("Mednafen Debug") }, 
  };
  const char* cn = _("Unknown");

  for(auto const& cne : CartNames)
  {
   if(cne.type == cart_type)
   {
    cn = cne.name;
    break;
   }
  }
  MDFN_printf(_("Cart: %s\n"), cn);
 }
 //
 NeedEmuICache = (cpucache_emumode == CPUCACHE_EMUMODE_FULL);
 for(unsigned c = 0; c < 2; c++)
 {
  CPU[c].Init(cpucache_emumode == CPUCACHE_EMUMODE_DATA_CB);
  CPU[c].SetMD5((bool)c);
 }

 //
 // Initialize backup memory.
 // 
 memset(BackupRAM, 0x00, sizeof(BackupRAM));
 for(unsigned i = 0; i < 0x40; i++)
  BackupRAM[i] = BRAM_Init_Data[i & 0x0F];

 // Call InitFastMemMap() before functions like SOUND_Init()
 InitFastMemMap();
 SS_SetPhysMemMap(0x00000000, 0x000FFFFF, BIOSROM, sizeof(BIOSROM));
 SS_SetPhysMemMap(0x00200000, 0x003FFFFF, WorkRAML, sizeof(WorkRAML), true);
 SS_SetPhysMemMap(0x06000000, 0x07FFFFFF, WorkRAMH, sizeof(WorkRAMH), true);
 MDFNMP_RegSearchable(0x00200000, sizeof(WorkRAML));
 MDFNMP_RegSearchable(0x06000000, sizeof(WorkRAMH));

 CART_Init(cart_type);
 //
 //
 //
 const bool PAL = (smpc_area & SMPC_AREA__PAL_MASK);
 const int32 MasterClock = PAL ? 1734687500 : 1746818182;	// NTSC: 1746818181.8181818181, PAL: 1734687500-ish
 const char* biospath_sname;
 int sls = MDFN_GetSettingI(PAL ? "ss.slstartp" : "ss.slstart");
 int sle = MDFN_GetSettingI(PAL ? "ss.slendp" : "ss.slend");

 if(PAL)
 {
  sls += 16;
  sle += 16;
 }

 if(sls > sle)
  std::swap(sls, sle);

 if(smpc_area == SMPC_AREA_JP || smpc_area == SMPC_AREA_ASIA_NTSC)
  biospath_sname = "ss.bios_jp";
 else
  biospath_sname = "ss.bios_na_eu";

 {
  const std::string biospath = MDFN_MakeFName(MDFNMKF_FIRMWARE, 0, MDFN_GetSettingS(biospath_sname));
  FileStream BIOSFile(biospath, FileStream::MODE_READ);

  if(BIOSFile.size() != 524288)
   throw MDFN_Error(0, _("BIOS file \"%s\" is of an incorrect size."), biospath.c_str());

  BIOSFile.read(BIOSROM, 512 * 1024);
  BIOS_SHA256 = sha256(BIOSROM, 512 * 1024);

  if(MDFN_GetSettingB("ss.bios_sanity"))
  {
   static const struct
   {
    const char* fn;
    sha256_digest hash;
    const uint32 areas;
   } BIOSDB[] =
   {
    { "sega1003.bin",  "cc1e1b7f88f1c6e6fc35994bae2c2292e06fdae258c79eb26a1f1391e72914a8"_sha256, (1U << SMPC_AREA_JP) | (1U << SMPC_AREA_ASIA_NTSC),  },
    { "sega_100.bin",  "ae4058627bb5db9be6d8d83c6be95a4aa981acc8a89042e517e73317886c8bc2"_sha256, (1U << SMPC_AREA_JP) | (1U << SMPC_AREA_ASIA_NTSC),  },
    { "sega_101.bin",  "dcfef4b99605f872b6c3b6d05c045385cdea3d1b702906a0ed930df7bcb7deac"_sha256, (1U << SMPC_AREA_JP) | (1U << SMPC_AREA_ASIA_NTSC),  },
    { "sega_100a.bin", "87293093fad802fcff31fcab427a16caff1acbc5184899b8383b360fd58efb73"_sha256, (~0U) & ~((1U << SMPC_AREA_JP) | (1U << SMPC_AREA_ASIA_NTSC)) },
    { "mpr-17933.bin", "96e106f740ab448cf89f0dd49dfbac7fe5391cb6bd6e14ad5e3061c13330266f"_sha256, (~0U) & ~((1U << SMPC_AREA_JP) | (1U << SMPC_AREA_ASIA_NTSC)) },
   };
   std::string fnbase, fnext;
   std::string fn;

   MDFN_GetFilePathComponents(biospath, nullptr, &fnbase, &fnext);
   fn = fnbase + fnext;

   // Discourage people from renaming files instead of changing settings.
   for(auto const& dbe : BIOSDB)
   {
    if(fn == dbe.fn && BIOS_SHA256 != dbe.hash)
     throw MDFN_Error(0, _("The BIOS ROM data loaded from \"%s\" does not match what is expected by its filename(possibly due to erroneous file renaming by the user)."), biospath.c_str());
   }

   for(auto const& dbe : BIOSDB)
   {
    if(BIOS_SHA256 == dbe.hash && !(dbe.areas & (1U << smpc_area)))
     throw MDFN_Error(0, _("The BIOS loaded from \"%s\" is the wrong BIOS for the region being emulated(possibly due to changing setting \"%s\" to point to the wrong file)."), biospath.c_str(), biospath_sname);
   }
  }
  //
  //
  for(unsigned i = 0; i < 262144; i++)
   BIOSROM[i] = MDFN_de16msb(&BIOSROM[i]);
 }

 EmulatedSS.MasterClock = MDFN_MASTERCLOCK_FIXED(MasterClock);

 SCU_Init();
 SMPC_Init(smpc_area, MasterClock);
 VDP1::Init();
 VDP2::Init(PAL);
 CDB_Init();
 SOUND_Init();

 InitEvents();
 UpdateInputLastBigTS = 0;

 DBG_Init();
 //
 //
 //
 MDFN_printf("\n");
 {
  const bool correct_aspect = MDFN_GetSettingB("ss.correct_aspect");
  const bool h_overscan = MDFN_GetSettingB("ss.h_overscan");
  const bool h_blend = MDFN_GetSettingB("ss.h_blend");

  MDFN_printf(_("Displayed scanlines: [%u,%u]\n"), sls, sle);
  MDFN_printf(_("Correct Aspect Ratio: %s\n"), correct_aspect ? _("Enabled") : _("Disabled"));
  MDFN_printf(_("Show H Overscan: %s\n"), h_overscan ? _("Enabled") : _("Disabled"));
  MDFN_printf(_("H Blend: %s\n"), h_blend ? _("Enabled") : _("Disabled"));

  VDP2::SetGetVideoParams(&EmulatedSS, correct_aspect, sls, sle, h_overscan, h_blend);
 }

 MDFN_printf("\n");
 for(unsigned sp = 0; sp < 2; sp++)
 {
  char buf[64];
  bool sv;

  trio_snprintf(buf, sizeof(buf), "ss.input.sport%u.multitap", sp + 1);
  sv = MDFN_GetSettingB(buf);
  SMPC_SetMultitap(sp, sv);

  MDFN_printf(_("Multitap on Saturn Port %u: %s\n"), sp + 1, sv ? _("Enabled") : _("Disabled"));
 }

 for(unsigned vp = 0; vp < 12; vp++)
 {
  char buf[64];
  uint32 sv;

  trio_snprintf(buf, sizeof(buf), "ss.input.port%u.gun_chairs", vp + 1);
  sv = MDFN_GetSettingUI(buf);
  SMPC_SetCrosshairsColor(vp, sv);  
 }

 //
 //
 //
 try { LoadRTC();       } catch(MDFN_Error& e) { if(e.GetErrno() != ENOENT) throw; }
 try { LoadBackupRAM(); } catch(MDFN_Error& e) { if(e.GetErrno() != ENOENT) throw; }
 try { LoadCartNV();    } catch(MDFN_Error& e) { if(e.GetErrno() != ENOENT) throw; }

 BackupBackupRAM();
 BackupCartNV();

 BackupRAM_Dirty = false;
 BackupRAM_SaveDelay = 0;

 CART_GetClearNVDirty();
 CartNV_SaveDelay = 0;
 //
 if(MDFN_GetSettingB("ss.smpc.autortc"))
 {
  struct tm ht = Time::LocalTime();

  SMPC_SetRTC(&ht, MDFN_GetSettingUI("ss.smpc.autortc.lang"));
 }
 //
 SS_Reset(true);
}

#ifdef MDFN_SS_DEV_BUILD
static MDFN_COLD bool TestMagic(MDFNFILE* fp)
{
 return false;
}

static MDFN_COLD void Load(MDFNFILE* fp)
{
#if 0
 // cat regiondb.inc | sort | uniq --all-repeated=separate -w 102 
 {
  FileStream rdbfp("/tmp/regiondb.inc", FileStream::MODE_WRITE);
  Stream* s = fp->stream();
  std::string linebuf;
  static std::vector<CDIF *> CDInterfaces;

  cdifs = &CDInterfaces;

  while(s->get_line(linebuf) >= 0)
  {
   static uint8 sbuf[2048 * 16];
   CDIF* iface = CDIF_Open(linebuf, false);
   int m = iface->ReadSector(sbuf, 0, 16);
   std::string fb;

   assert(m == 0x1); 
   assert(IsSaturnDisc(&sbuf[0]) == true);
   //
   uint8 dummytmp[16] = { 0 };
   uint8 tmp[16] = { 0 };
   const char* regstr;
   unsigned region = ~0U;

   MDFN_GetFilePathComponents(linebuf, nullptr, &fb);

   if(!DetectRegionByFN(fb, &region))
    abort();

   switch(region)
   {
    default: abort(); break;
    case SMPC_AREA_NA: regstr = "SMPC_AREA_NA"; break;
    case SMPC_AREA_JP: regstr = "SMPC_AREA_JP"; break;
    case SMPC_AREA_EU_PAL: regstr = "SMPC_AREA_EU_PAL"; break;
    case SMPC_AREA_KR: regstr = "SMPC_AREA_KR"; break;
    case SMPC_AREA_CSA_NTSC: regstr = "SMPC_AREA_CSA_NTSC"; break;
   }

   CDInterfaces.clear();
   CDInterfaces.push_back(iface);

   CalcGameID(dummytmp, tmp);

   unsigned tmpreg;
   if(!DetectRegion(&tmpreg) || tmpreg != region)
   {
    rdbfp.print_format("{ { ");
    for(unsigned i = 0; i < 16; i++)
     rdbfp.print_format("0x%02x, ", tmp[i]);
    rdbfp.print_format("}, %s }, // %s\n", regstr, fb.c_str());
   }

   delete iface;
  }
 }

 return;
#endif
 //uint8 elf_header[

 cdifs = NULL;

 try
 {
  if(MDFN_GetSettingS("ss.dbg_exe_cdpath") != "")
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
   CDInterfaces.push_back(CDIF_Open(MDFN_GetSettingS("ss.dbg_exe_cdpath").c_str(), false));
   cdifs = &CDInterfaces;
  }

  InitCommon(CPUCACHE_EMUMODE_DATA, CART_MDFN_DEBUG, MDFN_GetSettingUI("ss.region_default"));

  // 0x25FE00C4 = 0x1;
  for(unsigned i = 0; i < fp->size(); i += 2)
  {
   uint8 tmp[2];

   fp->read(tmp, 2);

   *(uint16*)((uint8*)WorkRAMH + 0x4000 + i) = (tmp[0] << 8) | (tmp[1] << 0);
  }
  BIOSROM[0] = 0x0600;
  BIOSROM[1] = 0x4000; //0x4130; //0x4060;

  BIOSROM[2] = 0x0600;
  BIOSROM[3] = 0x4000; //0x4130; //0x4060;

  BIOSROM[4] = 0xDEAD;
  BIOSROM[5] = 0xBEEF;
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}
#endif

static MDFN_COLD bool TestMagicCD(std::vector<CDIF *> *CDInterfaces)
{
 std::unique_ptr<uint8[]> buf(new uint8[2048 * 16]);

 if((*CDInterfaces)[0]->ReadSector(&buf[0], 0, 16) != 0x1)
  return false;

 return IsSaturnDisc(&buf[0]);
}

static MDFN_COLD void DiscSanityChecks(void)
{
 for(size_t i = 0; i < cdifs->size(); i++)
 {
  CDUtility::TOC toc;

  (*cdifs)[i]->ReadTOC(&toc);

  for(int32 track = 1; track <= 99; track++)
  {
   if(!toc.tracks[track].valid)
    continue;

   if(toc.tracks[track].control & CDUtility::SUBQ_CTRLF_DATA)
    continue;
   //
   //
   //
   const int32 start_lba = toc.tracks[track].lba;
   const int32 end_lba = start_lba + 32 - 1;
   bool any_subq_curpos = false;

   for(int32 lba = start_lba; lba <= end_lba; lba++)
   {
    uint8 pwbuf[96];
    uint8 qbuf[12];

    if(!(*cdifs)[i]->ReadRawSectorPWOnly(pwbuf, lba, false))
     throw MDFN_Error(0, _("Disc %zu of %zu: Error reading sector at lba=%d in DiscSanityChecks()."), i + 1, cdifs->size(), lba);

    CDUtility::subq_deinterleave(pwbuf, qbuf);
    if(CDUtility::subq_check_checksum(qbuf) && (qbuf[0] & 0xF) == CDUtility::ADR_CURPOS)
    {
     const uint8 qm = qbuf[7];
     const uint8 qs = qbuf[8];
     const uint8 qf = qbuf[9];
     uint8 lm, ls, lf;

     any_subq_curpos = true;

     CDUtility::LBA_to_AMSF(lba, &lm, &ls, &lf);
     lm = CDUtility::U8_to_BCD(lm);
     ls = CDUtility::U8_to_BCD(ls);
     lf = CDUtility::U8_to_BCD(lf);

     if(lm != qm || ls != qs || lf != qf)
     {
      throw MDFN_Error(0, _("Disc %zu of %zu: Time mismatch at lba=%d(%02x:%02x:%02x); Q subchannel: %02x:%02x:%02x"),
		i + 1, cdifs->size(),
		lba,
		lm, ls, lf,
		qm, qs, qf);
     }
    }
   }

   if(!any_subq_curpos)
   {
    throw MDFN_Error(0, _("Disc %zu of %zu: No valid Q subchannel ADR_CURPOS data present at lba %d-%d?!"), i + 1, cdifs->size(), start_lba, end_lba);
   }

   break;
  }
 }
}

static MDFN_COLD void LoadCD(std::vector<CDIF *>* CDInterfaces)
{
 try
 {
  const int ss_cart_setting = MDFN_GetSettingI("ss.cart");
  const unsigned region_default = MDFN_GetSettingI("ss.region_default");
  unsigned region;
  int cart_type;
  unsigned cpucache_emumode;
  uint8 fd_id[16];
  char sgid[16 + 1] = { 0 };
  cdifs = CDInterfaces;
  CalcGameID(MDFNGameInfo->MD5, fd_id, sgid);

  MDFN_printf("SGID: %s\n", sgid);

  region = region_default;
  cart_type = CART_BACKUP_MEM;
  cpucache_emumode = CPUCACHE_EMUMODE_DATA;

  DetectRegion(&region);
  DB_Lookup(nullptr, sgid, fd_id, &region, &cart_type, &cpucache_emumode);
  //
  if(!MDFN_GetSettingB("ss.region_autodetect"))
   region = region_default;

  if(ss_cart_setting != CART__RESERVED)
   cart_type = ss_cart_setting;
  //
  if(MDFN_GetSettingB("ss.cd_sanity"))
   DiscSanityChecks();
  else
   MDFN_printf(_("WARNING: CD (image) sanity checks disabled."));

   // TODO: auth ID calc

  InitCommon(cpucache_emumode, cart_type, region);
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}

static MDFN_COLD void CloseGame(void)
{
#ifdef MDFN_SS_DEV_BUILD
 VDP1::MakeDump("/tmp/vdp1_dump.h");
 VDP2::MakeDump("/tmp/vdp2_dump.h");
#endif
 //
 //

 try { SaveBackupRAM(); } catch(std::exception& e) { MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what()); }
 try { SaveCartNV();    } catch(std::exception& e) { MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what()); }
 try { SaveRTC();	} catch(std::exception& e) { MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what()); }

 Cleanup();
}

static MDFN_COLD void SaveBackupRAM(void)
{
 FileStream brs(MDFN_MakeFName(MDFNMKF_SAV, 0, "bkr"), FileStream::MODE_WRITE_INPLACE);

 brs.write(BackupRAM, sizeof(BackupRAM));

 brs.close();
}

static MDFN_COLD void LoadBackupRAM(void)
{
 FileStream brs(MDFN_MakeFName(MDFNMKF_SAV, 0, "bkr"), FileStream::MODE_READ);

 brs.read(BackupRAM, sizeof(BackupRAM));
}

static MDFN_COLD void BackupBackupRAM(void)
{
 MDFN_BackupSavFile(10, "bkr");
}

static MDFN_COLD void BackupCartNV(void)
{
 const char* ext = nullptr;
 void* nv_ptr = nullptr;
 bool nv16 = false;
 uint64 nv_size = 0;

 CART_GetNVInfo(&ext, &nv_ptr, &nv16, &nv_size);

 if(ext)
  MDFN_BackupSavFile(10, ext);
}

static MDFN_COLD void LoadCartNV(void)
{
 const char* ext = nullptr;
 void* nv_ptr = nullptr;
 bool nv16 = false;
 uint64 nv_size = 0;

 CART_GetNVInfo(&ext, &nv_ptr, &nv16, &nv_size);

 if(ext)
 {
  //FileStream nvs(MDFN_MakeFName(MDFNMKF_SAV, 0, ext), FileStream::MODE_READ);
  GZFileStream nvs(MDFN_MakeFName(MDFNMKF_SAV, 0, ext), GZFileStream::MODE::READ);

  nvs.read(nv_ptr, nv_size);

  if(nv16)
  {  
   for(uint64 i = 0; i < nv_size; i += 2)
   {
    void* p = (uint8*)nv_ptr + i;

    MDFN_ennsb<uint16>(p, MDFN_de16msb(p));
   }
  }
 }
}

static MDFN_COLD void SaveCartNV(void)
{
 const char* ext = nullptr;
 void* nv_ptr = nullptr;
 bool nv16 = false;
 uint64 nv_size = 0;

 CART_GetNVInfo(&ext, &nv_ptr, &nv16, &nv_size);

 if(ext)
 {
  //FileStream nvs(MDFN_MakeFName(MDFNMKF_SAV, 0, ext), FileStream::MODE_WRITE_INPLACE);
  GZFileStream nvs(MDFN_MakeFName(MDFNMKF_SAV, 0, ext), GZFileStream::MODE::WRITE);

  if(nv16)
  {
   // Slow...
   for(uint64 i = 0; i < nv_size; i += 2)
    nvs.put_BE<uint16>(MDFN_densb<uint16>((uint8*)nv_ptr + i));
  }
  else
   nvs.write(nv_ptr, nv_size);

  nvs.close();
 }
}

static MDFN_COLD void SaveRTC(void)
{
 FileStream sds(MDFN_MakeFName(MDFNMKF_SAV, 0, "smpc"), FileStream::MODE_WRITE_INPLACE);

 SMPC_SaveNV(&sds);

 sds.close();
}

static MDFN_COLD void LoadRTC(void)
{
 FileStream sds(MDFN_MakeFName(MDFNMKF_SAV, 0, "smpc"), FileStream::MODE_READ);

 SMPC_LoadNV(&sds);
}

struct EventsPacker
{
 enum : size_t { eventcopy_first = SS_EVENT__SYNFIRST + 1 };
 enum : size_t { eventcopy_bound = SS_EVENT__SYNLAST };

 bool Restore(void);
 void Save(void);

 int32 event_times[eventcopy_bound - eventcopy_first];
 uint8 event_order[eventcopy_bound - eventcopy_first];
};

INLINE void EventsPacker::Save(void)
{
 event_list_entry* evt = events[SS_EVENT__SYNFIRST].next;

 for(size_t i = eventcopy_first; i < eventcopy_bound; i++)
 {
  event_times[i - eventcopy_first] = events[i].event_time;
  event_order[i - eventcopy_first] = evt - events;
  assert(event_order[i - eventcopy_first] >= eventcopy_first && event_order[i - eventcopy_first] < eventcopy_bound);
  evt = evt->next;
 }
}

INLINE bool EventsPacker::Restore(void)
{
 bool used[SS_EVENT__COUNT] = { 0 };
 event_list_entry* evt = &events[SS_EVENT__SYNFIRST];
 for(size_t i = eventcopy_first; i < eventcopy_bound; i++)
 {
  int32 et = event_times[i - eventcopy_first];
  uint8 eo = event_order[i - eventcopy_first];

  if(eo < eventcopy_first || eo >= eventcopy_bound)
   return false;

  if(used[eo])
   return false;

  used[eo] = true;

  if(et < events[SS_EVENT__SYNFIRST].event_time)
   return false;

  events[i].event_time = et;

  evt->next = &events[eo];
  evt->next->prev = evt;
  evt = evt->next;
 }
 evt->next = &events[SS_EVENT__SYNLAST];
 evt->next->prev = evt;

 for(size_t i = 0; i < SS_EVENT__COUNT; i++)
 {
  if(i == SS_EVENT__SYNLAST)
  {
   if(events[i].next != NULL)
    return false;
  }
  else
  {
   if(events[i].next->prev != &events[i])
    return false;

   if(events[i].next->event_time < events[i].event_time)
    return false;
  }

  if(i == SS_EVENT__SYNFIRST)
  {
   if(events[i].prev != NULL)
    return false;
  }
  else
  {
   if(events[i].prev->next != &events[i])
    return false;

   if(events[i].prev->event_time > events[i].event_time)
    return false;
  }
 }

 return true;
}

static MDFN_COLD void StateAction(StateMem* sm, const unsigned load, const bool data_only)
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

 EventsPacker ep;
 ep.Save();

 SFORMAT StateRegs[] = 
 {
  // cur_clock_div
  SFVAR(UpdateInputLastBigTS),

  SFVAR(next_event_ts),
  SFVARN(ep.event_times, "event_times"),
  SFVARN(ep.event_order, "event_order"),

  SFVAR(SH7095_mem_timestamp),
  SFVAR(SH7095_BusLock),
  SFVAR(SH7095_DB),

  SFVAR(WorkRAML),
  SFVAR(WorkRAMH),
  SFVAR(BackupRAM),

  SFEND
 };

 CPU[0].StateAction(sm, load, data_only, "SH2-M");
 CPU[1].StateAction(sm, load, data_only, "SH2-S");
 SCU_StateAction(sm, load, data_only);
 SMPC_StateAction(sm, load, data_only);

 CDB_StateAction(sm, load, data_only);
 VDP1::StateAction(sm, load, data_only);
 VDP2::StateAction(sm, load, data_only);

 SOUND_StateAction(sm, load, data_only);
 CART_StateAction(sm, load, data_only);
 //
 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAIN");

 if(load)
 {
  BackupRAM_Dirty = true;

  if(!ep.Restore())
  {
   printf("Bad state events data.");
   InitEvents();
  }
 }
}

static MDFN_COLD bool SetMedia(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{
 const RMD_Layout* rmd = EmulatedSS.RMD;
 const RMD_Drive* rd = &rmd->Drives[drive_idx];
 const RMD_State* rs = &rd->PossibleStates[state_idx];

 //printf("%d %d %d\n", rs->MediaPresent, rs->MediaUsable, rs->MediaCanChange);

 if(rs->MediaPresent && rs->MediaUsable)
  CDB_SetDisc(false, (*cdifs)[media_idx]);
 else
  CDB_SetDisc(rs->MediaCanChange, NULL);

 return(true);
}

static void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_POWER: SS_Reset(true); break;
  // MDFN_MSC_RESET is not handled here; special reset button handling in smpc.cpp.
 }
}

static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".elf", gettext_noop("SS Homebrew ELF Executable") },

 { NULL, NULL }
};

static const MDFNSetting_EnumList Region_List[] =
{
 { "jp", SMPC_AREA_JP, gettext_noop("Japan") },
 { "na", SMPC_AREA_NA, gettext_noop("North America") },
 { "eu", SMPC_AREA_EU_PAL, gettext_noop("Europe") },
 { "kr", SMPC_AREA_KR, gettext_noop("South Korea") },

 { "tw", SMPC_AREA_ASIA_NTSC, gettext_noop("Taiwan") },	// Taiwan, Philippines
 { "as", SMPC_AREA_ASIA_PAL, gettext_noop("China") },	// China, Middle East

 { "br", SMPC_AREA_CSA_NTSC, gettext_noop("Brazil") },
 { "la", SMPC_AREA_CSA_PAL, gettext_noop("Latin America") },

 { NULL, 0 },
};

static const MDFNSetting_EnumList RTCLang_List[] =
{
 { "english", SMPC_RTC_LANG_ENGLISH, gettext_noop("English") },
 { "german", SMPC_RTC_LANG_GERMAN, gettext_noop("Deutsch") },
 { "french", SMPC_RTC_LANG_FRENCH, gettext_noop("Français") },
 { "spanish", SMPC_RTC_LANG_SPANISH, gettext_noop("Español") },
 { "italian", SMPC_RTC_LANG_ITALIAN, gettext_noop("Italiano") },
 { "japanese", SMPC_RTC_LANG_JAPANESE, gettext_noop("日本語") },

 { "deutsch", SMPC_RTC_LANG_GERMAN, NULL },
 { "français", SMPC_RTC_LANG_FRENCH, NULL },
 { "español", SMPC_RTC_LANG_SPANISH, NULL },
 { "italiano", SMPC_RTC_LANG_ITALIAN, NULL },
 { "日本語", SMPC_RTC_LANG_JAPANESE, NULL},

 { NULL, 0 },
};

static const MDFNSetting_EnumList Cart_List[] =
{
 { "auto", CART__RESERVED, gettext_noop("Automatic") },
 { "none", CART_NONE, gettext_noop("None") },
 { "backup", CART_BACKUP_MEM, gettext_noop("Backup Memory(512KiB)") },
 { "extram1", CART_EXTRAM_1M, gettext_noop("1MiB Extended RAM") },
 { "extram4", CART_EXTRAM_4M, gettext_noop("4MiB Extended RAM") },
 { "cs1ram16", CART_CS1RAM_16M, gettext_noop("16MiB RAM mapped in A-bus CS1") },
 { "ar4mp", CART_AR4MP, NULL }, // Undocumented, unfinished. gettext_noop("Action Replay 4M Plus") },
// { "nlmodem", CART_NLMODEM, gettext_noop("NetLink Modem") },

 { NULL, 0 },
};

#ifdef MDFN_SS_DEV_BUILD
static const MDFNSetting_EnumList DBGMask_List[] =
{
 { "0",		0								},
 { "none",	0,			gettext_noop("None")			},

 { "all",	~0,			gettext_noop("All")			},

 { "warning",	SS_DBG_WARNING,		gettext_noop("Warnings")		},

 { "m68k",	SS_DBG_M68K,		gettext_noop("M68K") 			},

 { "sh2",	SS_DBG_SH2,		gettext_noop("SH-2") 			},
 { "sh2_regw",	SS_DBG_SH2_REGW,	gettext_noop("SH-2 (peripherals) register writes") },
 { "sh2_cache",	SS_DBG_SH2_CACHE,	gettext_noop("SH-2 cache")		},

 { "scu",	SS_DBG_SCU,		gettext_noop("SCU") 			},
 { "scu_regw",	SS_DBG_SCU_REGW,	gettext_noop("SCU register writes") 	},
 { "scu_int",	SS_DBG_SCU_INT,		gettext_noop("SCU interrupt") 		},
 { "scu_dsp",	SS_DBG_SCU_DSP,		gettext_noop("SCU DSP")			},

 { "smpc",	SS_DBG_SMPC,		gettext_noop("SMPC")			},
 { "smpc_regw",	SS_DBG_SMPC_REGW,	gettext_noop("SMPC register writes")	},

 { "cdb",	SS_DBG_CDB,		gettext_noop("CDB")			},
 { "cdb_regw",	SS_DBG_CDB_REGW,	gettext_noop("CDB register writes")	},

 { "vdp1",	SS_DBG_VDP1,		gettext_noop("VDP1") 			},
 { "vdp1_regw", SS_DBG_VDP1_REGW,	gettext_noop("VDP1 register writes")	},
 { "vdp1_vramw",SS_DBG_VDP1_VRAMW,	gettext_noop("VDP1 VRAM writes")	},
 { "vdp1_fbw",	SS_DBG_VDP1_FBW,	gettext_noop("VDP1 FB writes")		},

 { "vdp2",	SS_DBG_VDP2,		gettext_noop("VDP2")			},
 { "vdp2_regw", SS_DBG_VDP2_REGW,	gettext_noop("VDP2 register writes")	},

 { "scsp",	SS_DBG_SCSP,		gettext_noop("SCSP")			},
 { "scsp_regw", SS_DBG_SCSP_REGW,	gettext_noop("SCSP register writes")	},

 { NULL, 0 },
};
#endif

static const MDFNSetting SSSettings[] =
{
 { "ss.bios_jp", MDFNSF_EMU_STATE | MDFNSF_CAT_PATH, gettext_noop("Path to the Japan ROM BIOS"), NULL, MDFNST_STRING, "sega_101.bin" },
 { "ss.bios_na_eu", MDFNSF_EMU_STATE | MDFNSF_CAT_PATH, gettext_noop("Path to the North America and Europe ROM BIOS"), NULL, MDFNST_STRING, "mpr-17933.bin" },

 { "ss.scsp.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("SCSP output resampler quality."),
	gettext_noop("0 is lowest quality and CPU usage, 10 is highest quality and CPU usage.  The resampler that this setting refers to is used for converting from 44.1KHz to the sampling rate of the host audio device Mednafen is using.  Changing Mednafen's output rate, via the \"sound.rate\" setting, to \"44100\" may bypass the resampler, which can decrease CPU usage by Mednafen, and can increase or decrease audio quality, depending on various operating system and hardware factors."), MDFNST_UINT, "4", "0", "10" },

 { "ss.region_autodetect", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Attempt to auto-detect region of game."), NULL, MDFNST_BOOL, "1" },
 { "ss.region_default", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Default region to use."), gettext_noop("Used if region autodetection fails or is disabled."), MDFNST_ENUM, "jp", NULL, NULL, NULL, NULL, Region_List },

 { "ss.input.mouse_sensitivity", MDFNSF_NOFLAGS, gettext_noop("Emulated mouse sensitivity."), NULL, MDFNST_FLOAT, "0.50", NULL, NULL },
 { "ss.input.sport1.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap on Saturn port 1."), NULL, MDFNST_BOOL, "0", NULL, NULL },
 { "ss.input.sport2.multitap", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Enable multitap on Saturn port 2."), NULL, MDFNST_BOOL, "0", NULL, NULL },

 { "ss.input.port1.gun_chairs",  MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 1."),  gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0xFF0000", "0x000000", "0x1000000" },
 { "ss.input.port2.gun_chairs",  MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 2."),  gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0x00FF00", "0x000000", "0x1000000" },
 { "ss.input.port3.gun_chairs",  MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 3."),  gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0xFF00FF", "0x000000", "0x1000000" },
 { "ss.input.port4.gun_chairs",  MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 4."),  gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0xFF8000", "0x000000", "0x1000000" },
 { "ss.input.port5.gun_chairs",  MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 5."),  gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0xFFFF00", "0x000000", "0x1000000" },
 { "ss.input.port6.gun_chairs",  MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 6."),  gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0x00FFFF", "0x000000", "0x1000000" },
 { "ss.input.port7.gun_chairs",  MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 7."),  gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0x0080FF", "0x000000", "0x1000000" },
 { "ss.input.port8.gun_chairs",  MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 8."),  gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0x8000FF", "0x000000", "0x1000000" },
 { "ss.input.port9.gun_chairs",  MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 9."),  gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0xFF80FF", "0x000000", "0x1000000" },
 { "ss.input.port10.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 10."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0x00FF80", "0x000000", "0x1000000" },
 { "ss.input.port11.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 11."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0x8080FF", "0x000000", "0x1000000" },
 { "ss.input.port12.gun_chairs", MDFNSF_NOFLAGS, gettext_noop("Crosshairs color for lightgun on virtual port 12."), gettext_noop("A value of 0x1000000 disables crosshair drawing."), MDFNST_UINT, "0xFF8080", "0x000000", "0x1000000" },

 { "ss.smpc.autortc", MDFNSF_NOFLAGS, gettext_noop("Automatically set RTC on game load."), gettext_noop("Automatically set the SMPC's emulated Real-Time Clock to the host system's current time and date upon game load."), MDFNST_BOOL, "1" },
 { "ss.smpc.autortc.lang", MDFNSF_NOFLAGS, gettext_noop("BIOS language."), gettext_noop("Also affects language used in some games(e.g. the European release of \"Panzer Dragoon\")."), MDFNST_ENUM, "english", NULL, NULL, NULL, NULL, RTCLang_List },

 { "ss.cart", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Expansion cart."), NULL, MDFNST_ENUM, "auto", NULL, NULL, NULL, NULL, Cart_List },
 { "ss.cart.kof95_path", MDFNSF_EMU_STATE | MDFNSF_CAT_PATH, gettext_noop("Path to KoF 95 ROM image."), NULL, MDFNST_STRING, "mpr-18811-mx.ic1" },
 { "ss.cart.ultraman_path", MDFNSF_EMU_STATE | MDFNSF_CAT_PATH, gettext_noop("Path to Ultraman ROM image."), NULL, MDFNST_STRING, "mpr-19367-mx.ic1" },
 { "ss.cart.satar4mp_path", MDFNSF_EMU_STATE | MDFNSF_CAT_PATH | MDFNSF_SUPPRESS_DOC | MDFNSF_NONPERSISTENT, gettext_noop("Path to Action Replay 4M Plus firmware image."), NULL, MDFNST_STRING, "satar4mp.bin" },
// { "ss.cart.modem_port", MDFNSF_NOFLAGS, gettext_noop("TCP/IP port to use for modem emulation."), gettext_noop("A value of \"0\" disables network access."), MDFNST_UINT, "4920", "0", "65535" },
 
 { "ss.bios_sanity", MDFNSF_NOFLAGS, gettext_noop("Enable BIOS ROM image sanity checks."), NULL, MDFNST_BOOL, "1" },

 { "ss.cd_sanity", MDFNSF_NOFLAGS, gettext_noop("Enable CD (image) sanity checks."), NULL, MDFNST_BOOL, "1" },

 { "ss.slstart", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in NTSC mode."), NULL, MDFNST_INT, "0", "0", "239" },
 { "ss.slend", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in NTSC mode."), NULL, MDFNST_INT, "239", "0", "239" },

 { "ss.h_overscan", MDFNSF_NOFLAGS, gettext_noop("Show horizontal overscan area."), NULL, MDFNST_BOOL, "1" },

 { "ss.h_blend", MDFNSF_NOFLAGS, gettext_noop("Enable horizontal blend(blur) filter."), gettext_noop("Intended for use in combination with the \"goat\" OpenGL shader, or with bilinear interpolation or linear interpolation on the X axis enabled.  Has a more noticeable effect with the Saturn's higher horizontal resolution modes(640/704)."), MDFNST_BOOL, "0" },

 { "ss.correct_aspect", MDFNSF_NOFLAGS, gettext_noop("Correct aspect ratio."), gettext_noop("Disabling aspect ratio correction with this setting should be considered a hack.\n\nIf disabling it to allow for sharper pixels by also separately disabling interpolation(though using Mednafen's \"autoipsharper\" OpenGL shader is usually a better option), remember to use scale factors that are multiples of 2, or else games that use high-resolution and interlaced modes will have distorted pixels.\n\nDisabling aspect ratio correction with this setting will allow for the QuickTime movie recording feature to produce much smaller files using much less CPU time."), MDFNST_BOOL, "1" },

 { "ss.slstartp", MDFNSF_NOFLAGS, gettext_noop("First displayed scanline in PAL mode."), NULL, MDFNST_INT, "0", "-16", "271" },
 { "ss.slendp", MDFNSF_NOFLAGS, gettext_noop("Last displayed scanline in PAL mode."), NULL, MDFNST_INT, "255", "-16", "271" },

 { "ss.midsync", MDFNSF_NOFLAGS, gettext_noop("Enable mid-frame synchronization."), gettext_noop("Mid-frame synchronization can reduce input latency, but it will increase CPU requirements."), MDFNST_BOOL, "0" },

#ifdef MDFN_SS_DEV_BUILD
 { "ss.dbg_mask", MDFNSF_SUPPRESS_DOC, gettext_noop("Debug printf mask."), NULL, MDFNST_MULTI_ENUM, "none", NULL, NULL, NULL, NULL, DBGMask_List },
 { "ss.dbg_exe_cdpath", MDFNSF_SUPPRESS_DOC | MDFNSF_CAT_PATH, gettext_noop("CD image to use with homebrew executable loading."), NULL, MDFNST_STRING, "" },
#endif

 { NULL },
};

static const CheatInfoStruct CheatInfo =
{
 NULL,
 NULL,

 CheatMemRead,
 CheatMemWrite,

 CheatFormatInfo_Empty,

 true
};

}

using namespace MDFN_IEN_SS;

MDFNGI EmulatedSS =
{
 "ss",
 "Sega Saturn",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 #ifdef WANT_DEBUGGER
 &DBGInfo,
 #else
 NULL,
 #endif
 SMPC_PortInfo,
#ifdef MDFN_SS_DEV_BUILD
 Load,
 TestMagic,
#else
 NULL,
 NULL,
#endif
 LoadCD,
 TestMagicCD,
 CloseGame,

 VDP2::SetLayerEnableMask,
 "NBG0\0NBG1\0NBG2\0NBG3\0RBG0\0RBG1\0Sprite\0",

 NULL,
 NULL,

 NULL,
 0,

 CheatInfo,

 false,
 StateAction,
 Emulate,
 SMPC_TransformInput,
 SMPC_SetInput,
 SetMedia,
 DoSimpleCommand,
 NULL,
 SSSettings,
 0,
 0,

 true, // Multires possible?

 //
 // Note: Following video settings will be overwritten during game load.
 //
 320,	// lcm_width
 240,	// lcm_height
 NULL,  // Dummy

 302,   // Nominal width
 240,   // Nominal height

 0,   // Framebuffer width
 0,   // Framebuffer height
 //
 //
 //

 2,     // Number of output sound channels
};

