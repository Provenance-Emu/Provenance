//ubc is disabled on dreamcast and can't be used ... but kos-debug uses it !...

#include "types.h"
#include "hw/sh4/sh4_mmr.h"


//Init term res
void ubc_init()
{
	//UBC BARA 0xFF200000 0x1F200000 32 Undefined Held Held Held Iclk
	sh4_rio_reg(UBC,UBC_BARA_addr,RIO_DATA,32);

	//UBC BAMRA 0xFF200004 0x1F200004 8 Undefined Held Held Held Iclk
	sh4_rio_reg(UBC,UBC_BAMRA_addr,RIO_DATA,8);

	//UBC BBRA 0xFF200008 0x1F200008 16 0x0000 Held Held Held Iclk
	sh4_rio_reg(UBC,UBC_BBRA_addr,RIO_DATA,16);

	//UBC BARB 0xFF20000C 0x1F20000C 32 Undefined Held Held Held Iclk
	sh4_rio_reg(UBC,UBC_BARB_addr,RIO_DATA,32);

	//UBC BAMRB 0xFF200010 0x1F200010 8 Undefined Held Held Held Iclk
	sh4_rio_reg(UBC,UBC_BAMRB_addr,RIO_DATA,8);

	//UBC BBRB 0xFF200014 0x1F200014 16 0x0000 Held Held Held Iclk
	sh4_rio_reg(UBC,UBC_BBRB_addr,RIO_DATA,16);

	//UBC BDRB 0xFF200018 0x1F200018 32 Undefined Held Held Held Iclk
	sh4_rio_reg(UBC,UBC_BDRB_addr,RIO_DATA,32);

	//UBC BDMRB 0xFF20001C 0x1F20001C 32 Undefined Held Held Held Iclk
	sh4_rio_reg(UBC,UBC_BDMRB_addr,RIO_DATA,32);

	//UBC BRCR 0xFF200020 0x1F200020 16 0x0000 Held Held Held Iclk
	sh4_rio_reg(UBC,UBC_BRCR_addr,RIO_DATA,16);
}
void ubc_reset()
{
	/*
	BARA H'FF20 0000 H'1F20 0000 32 Undefined Held Held Held Iclk
	UBC BAMRA H'FF20 0004 H'1F20 0004 8 Undefined Held Held Held Iclk
	UBC BBRA H'FF20 0008 H'1F20 0008 16 H'0000 Held Held Held Iclk
	UBC BARB H'FF20 000C H'1F20 000C 32 Undefined Held Held Held Iclk
	UBC BAMRB H'FF20 0010 H'1F20 0010 8 Undefined Held Held Held Iclk
	UBC BBRB H'FF20 0014 H'1F20 0014 16 H'0000 Held Held Held Iclk
	UBC BDRB H'FF20 0018 H'1F20 0018 32 Undefined Held Held Held Iclk
	UBC BDMRB H'FF20 001C H'1F20 001C 32 Undefined Held Held Held Iclk
	UBC BRCR H'FF20 0020 H'1F20 0020 16 H'0000*2 Held Held Held Iclk
	*/
	UBC_BBRA = 0x0;
	UBC_BBRB = 0x0;
	UBC_BRCR = 0x0;
}

void ubc_term()
{
}
