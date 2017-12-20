#ifndef __PCFX_INTERRUPT_H
#define __PCFX_INTERRUPT_H

#define PCFXIRQ_SOURCE_TIMER	1
#define PCFXIRQ_SOURCE_EX	2
#define PCFXIRQ_SOURCE_INPUT	3
#define PCFXIRQ_SOURCE_VDCA	4
#define PCFXIRQ_SOURCE_KING	5
#define PCFXIRQ_SOURCE_VDCB	6
#define PCFXIRQ_SOURCE_HUC6273  7

void PCFXIRQ_Assert(int source, bool assert);
void PCFXIRQ_Write16(uint32 A, uint16 V);
uint16 PCFXIRQ_Read16(uint32 A);
uint8 PCFXIRQ_Read8(uint32 A);
void PCFXIRQ_StateAction(StateMem *sm, const unsigned load, const bool data_only);

void PCFXIRQ_Reset(void);

enum
{
 PCFXIRQ_GSREG_IMASK = 0,
 PCFXIRQ_GSREG_IPRIO0,
 PCFXIRQ_GSREG_IPRIO1,
 PCFXIRQ_GSREG_IPEND
};

uint32 PCFXIRQ_GetRegister(const unsigned int id, char *special, const uint32 special_len);
void PCFXIRQ_SetRegister(const unsigned int id, uint32 value);

#endif
