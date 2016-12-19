#ifndef __MDFN_SNESFAST_SNES_H
#define __MDFN_SNESFAST_SNES_H

#include <mednafen/mednafen.h>

#define DEFREAD(x) uint8 MDFN_FASTCALL x (uint32 A)
#define DEFWRITE(x) void MDFN_FASTCALL x (uint32 A, uint8 V)

#define MEMCYC_FAST   6
#define MEMCYC_SLOW   8
#define MEMCYC_XSLOW 12

#if 0
 #define SNES_DBG(s, ...) printf(s, ## __VA_ARGS__)
#else
 static INLINE void SNES_DBG(const char* format, ...) { }
#endif

#include "cpu.h"

namespace MDFN_IEN_SNES_FAUST
{
extern bool MemSelect;

DEFREAD(OBRead_XSLOW);
DEFREAD(OBRead_SLOW);
DEFREAD(OBRead_FAST);
DEFREAD(OBRead_VAR);

DEFWRITE(OBWrite_XSLOW);
DEFWRITE(OBWrite_SLOW);
DEFWRITE(OBWrite_FAST);
DEFWRITE(OBWrite_VAR);

//
// Caution: B bus read/write handlers should ignore the upper 24 bits of the passed-in address
// variable.
//
void Set_B_Handlers(uint8 A1, uint8 A2, readfunc read_handler, writefunc write_handler);
static INLINE void Set_B_Handlers(uint8 A1, readfunc read_handler, writefunc write_handler)
{
 Set_B_Handlers(A1, A1, read_handler, write_handler);
}

void Set_A_Handlers(uint32 A1, uint32 A2, readfunc read_handler, writefunc write_handler);
static INLINE void Set_A_Handlers(uint32 A1, readfunc read_handler, writefunc write_handler)
{
 Set_A_Handlers(A1, A1, read_handler, write_handler);
}

void DMA_InitHDMA(void);
void DMA_RunHDMA(void);

void ForceEventUpdates(const uint32 timestamp);

enum
{
 SNES_EVENT__SYNFIRST = 0,
 SNES_EVENT_PPU,
 SNES_EVENT_DMA_DUMMY,
 SNES_EVENT__SYNLAST,
 SNES_EVENT__COUNT,
};

#define SNES_EVENT_MAXTS       		0x20000000
void SNES_SetEventNT(const int type, const uint32 next_timestamp);


}

#endif
