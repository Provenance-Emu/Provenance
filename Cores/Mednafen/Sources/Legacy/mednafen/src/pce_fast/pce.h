#ifndef _PCE_H

#include <mednafen/mednafen.h>
#include <mednafen/state.h>
#include <mednafen/general.h>
#include <mednafen/memory.h>

using namespace Mednafen;

#define PCE_MASTER_CLOCK        21477272.727273

#define DECLFR(x) uint8 MDFN_FASTCALL x (uint32 A)
#define DECLFW(x) void MDFN_FASTCALL x (uint32 A, uint8 V)

namespace MDFN_IEN_PCE_FAST
{
MDFN_HIDE extern uint8 ROMSpace[0x88 * 8192 + 8192];

typedef void (MDFN_FASTCALL *writefunc)(uint32 A, uint8 V);
typedef uint8 (MDFN_FASTCALL *readfunc)(uint32 A);

MDFN_HIDE extern uint8 PCEIODataBuffer;

void PCE_InitCD(void) MDFN_COLD;

};

#include "huc6280.h"

namespace MDFN_IEN_PCE_FAST
{
MDFN_HIDE extern bool PCE_ACEnabled; // Arcade Card emulation enabled?
void PCE_Power(void) MDFN_COLD;

MDFN_HIDE extern int pce_overclocked;

MDFN_HIDE extern uint8 BaseRAM[32768 + 8192];

};

using namespace MDFN_IEN_PCE_FAST;

#define _PCE_H
#endif
