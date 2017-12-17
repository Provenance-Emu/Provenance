#ifndef __MDFN_SNES_FAUST_CART_H
#define __MDFN_SNES_FAUST_CART_H

namespace MDFN_IEN_SNES_FAUST
{
 void CART_Init(Stream* fp, uint8 id[16]);
 void CART_Kill(void);
 void CART_Reset(bool powering_up);
 void CART_StateAction(StateMem* sm, const unsigned load, const bool data_only);

 bool CART_LoadNV(void);
 void CART_SaveNV(void);
}

#endif
