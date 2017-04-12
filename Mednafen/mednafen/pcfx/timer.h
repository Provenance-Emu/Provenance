#ifndef __PCFX_TIMER_H
#define __PCFX_TIMER_H

void FXTIMER_Write16(uint32 A, uint16 V, const v810_timestamp_t timestamp);
uint16 FXTIMER_Read16(uint32 A, const v810_timestamp_t timestamp);
uint8 FXTIMER_Read8(uint32 A, const v810_timestamp_t timestamp);
v810_timestamp_t FXTIMER_Update(const v810_timestamp_t timestamp);
void FXTIMER_ResetTS(int32 ts_base);
void FXTIMER_Reset(void);

void FXTIMER_Init(void);

void FXTIMER_StateAction(StateMem *sm, const unsigned load, const bool data_only);


enum
{
 FXTIMER_GSREG_TCTRL = 0,
 FXTIMER_GSREG_TPRD,
 FXTIMER_GSREG_TCNTR
};

uint32 FXTIMER_GetRegister(const unsigned int id, char *special, const uint32 special_len);
void FXTIMER_SetRegister(const unsigned int id, uint32 value);

#endif
