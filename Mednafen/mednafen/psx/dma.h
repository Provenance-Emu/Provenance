#ifndef __MDFN_PSX_DMA_H
#define __MDFN_PSX_DMA_H

namespace MDFN_IEN_PSX
{

pscpu_timestamp_t DMA_Update(const pscpu_timestamp_t timestamp);
void DMA_Write(const pscpu_timestamp_t timestamp, uint32 A, uint32 V);
uint32 DMA_Read(const pscpu_timestamp_t timestamp, uint32 A);

void DMA_ResetTS(void);

void DMA_Power(void) MDFN_COLD;

void DMA_Init(void) MDFN_COLD;
void DMA_Kill(void) MDFN_COLD;

void DMA_StateAction(StateMem *sm, const unsigned load, const bool data_only);

}

#endif
