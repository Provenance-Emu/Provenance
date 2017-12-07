#ifndef __WSWAN_RTC_H
#define __WSWAN_RTC_H

namespace MDFN_IEN_WSWAN
{

void RTC_Write(uint8 A, uint8 V);
uint8 RTC_Read(uint8 A);

void RTC_Init(void);
void RTC_Reset(void);

void RTC_Clock(uint32 cycles);
void RTC_StateAction(StateMem *sm, const unsigned load, const bool data_only);

}

#endif
