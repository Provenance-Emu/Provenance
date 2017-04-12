#ifndef __MDFN_SNES_FAUST_PPU_H
#define __MDFN_SNES_FAUST_PPU_H

namespace MDFN_IEN_SNES_FAUST
{

void PPU_Init(void);
void PPU_Kill(void);
void PPU_Reset(bool powering_up);
void PPU_ResetTS(void);

void PPU_StateAction(StateMem* sm, const unsigned load, const bool data_only);

void PPU_StartFrame(EmulateSpecStruct* espec);

uint32 PPU_Update(uint32 timestamp);

}

#endif
