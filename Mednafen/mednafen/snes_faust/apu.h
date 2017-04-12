#ifndef __MDFN_SNES_FAUST_APU_H
#define __MDFN_SNES_FAUST_APU_H

#include <mednafen/SPCReader.h>

namespace MDFN_IEN_SNES_FAUST
{

void APU_Init(void);
void APU_Kill(void);
void APU_Reset(bool powering_up);
int32 APU_EndFrame(int16* SoundBuf);
void APU_StartFrame(double rate);
void APU_SetSPC(SPCReader* s);	// Call after APU_Reset()

void APU_StateAction(StateMem* sm, const unsigned load, const bool data_only);

}

#endif
