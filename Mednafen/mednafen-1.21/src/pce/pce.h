#ifndef __MDFN_PCE_PCE_H
#define __MDFN_PCE_PCE_H

#include <mednafen/mednafen.h>
#include <mednafen/state.h>
#include <mednafen/general.h>

namespace MDFN_IEN_PCE
{

#define PCE_MASTER_CLOCK	21477272.727273

#define DECLFR(x) MDFN_FASTCALL uint8 x (uint32 A)
#define DECLFW(x) MDFN_FASTCALL void x (uint32 A, uint8 V)

};

#include "huc6280.h"

namespace MDFN_IEN_PCE
{
extern HuC6280 HuCPU;

extern uint32 PCE_InDebug;
extern bool PCE_ACEnabled; // Arcade Card emulation enabled?
void PCE_Power(void);

uint8 PCE_PeekMainRAM(uint32 A);
void PCE_PokeMainRAM(uint32 A, uint8 V);

};

#endif
