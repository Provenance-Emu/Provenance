#ifndef N64_H
#define N64_H

#include "Types.h"

#define MI_INTR_DP		0x20		// Bit 5: DP intr

struct N64Regs
{
	u32 *MI_INTR;

	u32 *DPC_START;
	u32 *DPC_END;
	u32 *DPC_CURRENT;
	u32 *DPC_STATUS;
	u32 *DPC_CLOCK;
	u32 *DPC_BUFBUSY;
	u32 *DPC_PIPEBUSY;
	u32 *DPC_TMEM;

	u32 *VI_STATUS;
	u32 *VI_ORIGIN;
	u32 *VI_WIDTH;
	u32 *VI_INTR;
	u32 *VI_V_CURRENT_LINE;
	u32 *VI_TIMING;
	u32 *VI_V_SYNC;
	u32 *VI_H_SYNC;
	u32 *VI_LEAP;
	u32 *VI_H_START;
	u32 *VI_V_START;
	u32 *VI_V_BURST;
	u32 *VI_X_SCALE;
	u32 *VI_Y_SCALE;

	u32 *SP_STATUS;
};

extern N64Regs REG;
extern u8 *HEADER;
extern u8 *DMEM;
extern u8 *IMEM;
extern u8 *RDRAM;
extern u64 TMEM[512];
extern u32 RDRAMSize;
extern bool ConfigOpen;

#endif

