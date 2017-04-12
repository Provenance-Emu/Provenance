#ifndef __MDFN_NES_FDSSOUND_H
#define __MDFN_NES_FDSSOUND_H

namespace MDFN_IEN_NES
{
bool FDSSound_Init(void);
void FDSSound_Power(void);
void FDSSound_StateAction(StateMem *sm, const unsigned load, const bool data_only);
}

#endif
