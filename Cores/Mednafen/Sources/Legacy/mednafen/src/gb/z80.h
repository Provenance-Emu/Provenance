#ifndef __GB_Z80_H
#define __GB_Z80_H

namespace MDFN_IEN_GB
{

int GBZ80_RunOp(void);
void GBZ80_Reset(void);
void GBZ80_Interrupt(int which);
void GBZ80_StateAction(StateMem *sm, int load, int data_only);

}
#endif
