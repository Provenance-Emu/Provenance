#pragma once

#include "types.h"

//
void dmac_ddt_ch0_ddt(u32 src,u32 dst,u32 count);
void dmac_ddt_ch2_direct(u32 dst,u32 count);
void DMAC_Ch2St();

//Init/Res/Term

void UpdateDMA();



#define DMAOR_MASK	0xFFFF8201