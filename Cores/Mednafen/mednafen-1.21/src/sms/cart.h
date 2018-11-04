#ifndef __SMS_CART_H
#define __SMS_CART_H

namespace MDFN_IEN_SMS
{

void Cart_Init(MDFNFILE *fp) MDFN_COLD;
void Cart_Close(void) MDFN_COLD;

void Cart_Reset(void);

void Cart_LoadNV(void);
void Cart_SaveNV(void);

void Cart_Write(uint16 A, uint8 V);
uint8 Cart_Read(uint16 A);

void Cart_StateAction(StateMem *sm, int load, int data_only);

}
#endif
