#ifndef __MDFN_NES_DEBUG_H
#define __MDFN_NES_DEBUG_H

#ifdef WANT_DEBUGGER

namespace MDFN_IEN_NES
{
#include "x6502struct.h"

uint32 NESDBG_MemPeek(uint32 A, unsigned int bsize, bool hl, bool logical);
void NESDBG_MemPoke(uint32 A, uint32 V, unsigned int bsize, bool, bool logical);
void NESDBG_IRQ(int level);
uint32 NESDBG_GetVector(int level);
void NESDBG_Disassemble(uint32 &a, uint32 SpecialA, char *);

void NESDBG_AddBranchTrace(uint32 from, uint32 to, uint32 vector);

void NESDBG_GetAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint8 *Buffer);
void NESDBG_PutAddressSpaceBytes(const char *name, uint32 Address, uint32 Length, uint32 Granularity, bool hl, const uint8 *Buffer);

bool NESDBG_Init(void) MDFN_COLD;

extern DebuggerInfoStruct NESDBGInfo;
}

#endif

#endif
