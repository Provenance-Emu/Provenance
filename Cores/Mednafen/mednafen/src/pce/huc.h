#ifndef __MDFN_PCE_HUC_H
#define __MDFN_PCE_HUC_H

namespace MDFN_IEN_PCE
{

typedef enum
{
 SYSCARD_NONE = 0,
 SYSCARD_1,
 SYSCARD_2,
 SYSCARD_3,
 SYSCARD_ARCADE		// 3.0 + extras
} SysCardType;

uint32 HuC_Load(Stream* s, bool DisableBRAM = false, SysCardType syscard = SYSCARD_NONE) MDFN_COLD;
void HuC_SaveNV(void);
void HuC_Kill(void) MDFN_COLD;

void HuC_Update(int32 timestamp);
void HuC_ResetTS(int32 ts_base);

void HuC_StateAction(StateMem *sm, const unsigned load, const bool data_only);

void HuC_Power(void);

DECLFR(PCE_ACRead);
DECLFW(PCE_ACWrite);

MDFN_HIDE extern bool PCE_IsCD;
MDFN_HIDE extern bool IsTsushin;

// Debugger support functions.
bool HuC_IsBRAMAvailable(void);
uint8 HuC_PeekBRAM(uint32 A);
void HuC_PokeBRAM(uint32 A, uint8 V);
};

#endif
