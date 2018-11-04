#include "types.h"
#include "hw/sh4/sh4_mmr.h"


/*
u16 CPG_FRQCR;
u8 CPG_STBCR;
u16 CPG_WTCNT;
u16 CPG_WTCSR;
u8 CPG_STBCR2;
*/

//Init term res
void cpg_init()
{
	//CPG FRQCR H'FFC0 0000 H'1FC0 0000 16 *2 Held Held Held Pclk
	sh4_rio_reg(CPG,CPG_FRQCR_addr,RIO_DATA,16);

	//CPG STBCR H'FFC0 0004 H'1FC0 0004 8 H'00 Held Held Held Pclk
	sh4_rio_reg(CPG,CPG_STBCR_addr,RIO_DATA,8);

	//CPG WTCNT H'FFC0 0008 H'1FC0 0008 8/16*3 H'00 Held Held Held Pclk
	sh4_rio_reg(CPG,CPG_WTCNT_addr,RIO_DATA,16);

	//CPG WTCSR H'FFC0 000C H'1FC0 000C 8/16*3 H'00 Held Held Held Pclk
	sh4_rio_reg(CPG,CPG_WTCSR_addr,RIO_DATA,16);

	//CPG STBCR2 H'FFC0 0010 H'1FC0 0010 8 H'00 Held Held Held Pclk
	sh4_rio_reg(CPG,CPG_STBCR2_addr,RIO_DATA,8);
}
void cpg_reset()
{
	/*
	CPG FRQCR H'FFC0 0000 H'1FC0 0000 16 *2 Held Held Held Pclk
	CPG STBCR H'FFC0 0004 H'1FC0 0004 8 H'00 Held Held Held Pclk
	CPG WTCNT H'FFC0 0008 H'1FC0 0008 8/16*3 H'00 Held Held Held Pclk
	CPG WTCSR H'FFC0 000C H'1FC0 000C 8/16*3 H'00 Held Held Held Pclk
	CPG STBCR2 H'FFC0 0010 H'1FC0 0010 8 H'00 Held Held Held Pclk
	*/
	CPG_FRQCR = 0;
	CPG_STBCR = 0;
	CPG_WTCNT = 0;
	CPG_WTCSR = 0;
	CPG_STBCR2 = 0;
}

void cpg_term()
{
}