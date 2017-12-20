#ifndef __MDFN_PSX_PSX_H
#define __MDFN_PSX_PSX_H

#include <mednafen/mednafen.h>
#include <mednafen/cdrom/cdromif.h>
#include <mednafen/general.h>
#include <mednafen/FileStream.h>

#include <trio/trio.h>

#include "masmem.h"

//
// Comment out these 2 defines for extra speeeeed.
//
#define PSX_DBGPRINT_ENABLE    1
#define PSX_EVENT_SYSTEM_CHECKS 1

//
// It's highly unlikely the user will want these if they're intentionally compiling without the debugger.
#ifndef WANT_DEBUGGER
 #undef PSX_DBGPRINT_ENABLE
 #undef PSX_EVENT_SYSTEM_CHECKS
#endif
//
//
//

namespace MDFN_IEN_PSX
{
 #define PSX_DBG_ERROR		0	// Emulator-level error.
 #define PSX_DBG_WARNING	1	// Warning about game doing questionable things/hitting stuff that might not be emulated correctly.
 #define PSX_DBG_BIOS_PRINT	2	// BIOS printf/putchar output.
 #define PSX_DBG_SPARSE		3	// Sparse(relatively) information debug messages(CDC commands).
 #define PSX_DBG_FLOOD		4	// Heavy informational debug messages(GPU commands; TODO).

#if PSX_DBGPRINT_ENABLE
 void PSX_DBG(unsigned level, const char *format, ...) noexcept MDFN_COLD MDFN_FORMATSTR(gnu_printf, 2, 3);
 void PSX_DBG_BIOS_PUTC(uint8 c) noexcept;

 #define PSX_WARNING(format, ...) { PSX_DBG(PSX_DBG_WARNING, format "\n", ## __VA_ARGS__); }
 #define PSX_DBGINFO(format, ...) { }
#else
 static INLINE void PSX_DBG(unsigned level, const char* format, ...) { }
 static INLINE void PSX_DBG_BIOS_PUTC(uint8 c) { }
 static INLINE void PSX_WARNING(const char* format, ...) { }
 static INLINE void PSX_DBGINFO(const char* format, ...) { }
#endif

 typedef int32 pscpu_timestamp_t;

 bool MDFN_FASTCALL PSX_EventHandler(const pscpu_timestamp_t timestamp);

 void MDFN_FASTCALL PSX_MemWrite8(pscpu_timestamp_t timestamp, uint32 A, uint32 V);
 void MDFN_FASTCALL PSX_MemWrite16(pscpu_timestamp_t timestamp, uint32 A, uint32 V);
 void MDFN_FASTCALL PSX_MemWrite24(pscpu_timestamp_t timestamp, uint32 A, uint32 V);
 void MDFN_FASTCALL PSX_MemWrite32(pscpu_timestamp_t timestamp, uint32 A, uint32 V);

 uint8 MDFN_FASTCALL PSX_MemRead8(pscpu_timestamp_t &timestamp, uint32 A);
 uint16 MDFN_FASTCALL PSX_MemRead16(pscpu_timestamp_t &timestamp, uint32 A);
 uint32 MDFN_FASTCALL PSX_MemRead24(pscpu_timestamp_t &timestamp, uint32 A);
 uint32 MDFN_FASTCALL PSX_MemRead32(pscpu_timestamp_t &timestamp, uint32 A);

 uint8 PSX_MemPeek8(uint32 A);
 uint16 PSX_MemPeek16(uint32 A);
 uint32 PSX_MemPeek32(uint32 A);

 // Should write to WO-locations if possible
 void PSX_MemPoke8(uint32 A, uint8 V);
 void PSX_MemPoke16(uint32 A, uint16 V);
 void PSX_MemPoke32(uint32 A, uint32 V);

 void PSX_RequestMLExit(void);
 void ForceEventUpdates(const pscpu_timestamp_t timestamp);

 enum
 {
  PSX_EVENT__SYNFIRST = 0,
  PSX_EVENT_GPU,
  PSX_EVENT_CDC,
  //PSX_EVENT_SPU,
  PSX_EVENT_TIMER,
  PSX_EVENT_DMA,
  PSX_EVENT_FIO,
  PSX_EVENT__SYNLAST,
  PSX_EVENT__COUNT,
 };

 #define PSX_EVENT_MAXTS       		0x20000000
 void PSX_SetEventNT(const int type, const pscpu_timestamp_t next_timestamp);

 void PSX_SetDMACycleSteal(unsigned stealage);

 void PSX_GPULineHook(const pscpu_timestamp_t timestamp, const pscpu_timestamp_t line_timestamp, bool vsync, uint32 *pixels, const MDFN_PixelFormat* const format, const unsigned width, const unsigned pix_clock_offset, const unsigned pix_clock, const unsigned pix_clock_divider);

 uint32 PSX_GetRandU32(uint32 mina, uint32 maxa);
};


#include "dis.h"
#include "cpu.h"
#include "irq.h"
#include "gpu.h"
#include "dma.h"
//#include "sio.h"
#include "debug.h"

namespace MDFN_IEN_PSX
{
 class PS_CDC;
 class PS_SPU;

 extern PS_CPU *CPU;
 extern PS_GPU *GPU;
 extern PS_CDC *CDC;
 extern PS_SPU *SPU;
 extern MultiAccessSizeMem<2048 * 1024, false> MainRAM;
};


#endif
