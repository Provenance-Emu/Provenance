/*
	SH4/mod/intc

	Implements the register interface of the sh4 interrupt controller.
	For the actual implementation of interrupt caching/handling logic, look at sh4_interrupts.cpp

	--
*/

#include "types.h"
#include "../sh4_interrupts.h"
#include "../sh4_mmr.h"


//Register writes need interrupt re-testing !

void write_INTC_IPRA(u32 addr, u32 data)
{
	if (INTC_IPRA.reg_data!=(u16)data)
	{
		INTC_IPRA.reg_data=(u16)data;
		SIIDRebuild();	//we need to rebuild the table
	}
}
void write_INTC_IPRB(u32 addr, u32 data)
{
	if (INTC_IPRB.reg_data!=(u16)data)
	{
		INTC_IPRB.reg_data=(u16)data;
		SIIDRebuild(); //we need to rebuild the table
	}
}
void write_INTC_IPRC(u32 addr, u32 data)
{
	if (INTC_IPRC.reg_data!=(u16)data)
	{
		INTC_IPRC.reg_data=(u16)data;
		SIIDRebuild(); //we need to rebuild the table
	}
}

//Init/Res/Term
void intc_init()
{
	//INTC ICR 0xFFD00000 0x1FD00000 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(INTC,INTC_ICR_addr,RIO_DATA,16);

	//INTC IPRA 0xFFD00004 0x1FD00004 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(INTC,INTC_IPRA_addr,RIO_WF,16,0,&write_INTC_IPRA);

	//INTC IPRB 0xFFD00008 0x1FD00008 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(INTC,INTC_IPRB_addr,RIO_WF,16,0,&write_INTC_IPRB);

	//INTC IPRC 0xFFD0000C 0x1FD0000C 16 0x0000 0x0000 Held Held Pclk
	sh4_rio_reg(INTC,INTC_IPRC_addr,RIO_WF,16,0,&write_INTC_IPRC);

	interrupts_init();
}

void intc_reset()
{
	INTC_ICR.reg_data = 0x0;
	INTC_IPRA.reg_data = 0x0;
	INTC_IPRB.reg_data = 0x0;
	INTC_IPRC.reg_data = 0x0;

	SIIDRebuild(); //rebuild the interrupts table

	interrupts_reset();
}

void intc_term()
{
	interrupts_term();
}

