/*
	The rtc isn't working on dreamcast I'm told
*/
#include "types.h"
#include "hw/sh4/sh4_mmr.h"

//Init term res
void rtc_init()
{
	// NAOMI reads from at least RTC_R64CNT

	//RTC R64CNT 0xFFC80000 0x1FC80000 8 Held Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_R64CNT_addr,RIO_DATA,8);

	//RTC RSECCNT H'FFC8 0004 H'1FC8 0004 8 Held Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RSECCNT_addr,RIO_DATA,8);

	//RTC RMINCNT H'FFC8 0008 H'1FC8 0008 8 Held Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RMINCNT_addr,RIO_DATA,8);

	//RTC RHRCNT H'FFC8 000C H'1FC8 000C 8 Held Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RHRCNT_addr,RIO_DATA,8);

	//RTC RWKCNT H'FFC8 0010 H'1FC8 0010 8 Held Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RWKCNT_addr,RIO_DATA,8);

	//RTC RDAYCNT H'FFC8 0014 H'1FC8 0014 8 Held Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RDAYCNT_addr,RIO_DATA,8);

	//RTC RMONCNT H'FFC8 0018 H'1FC8 0018 8 Held Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RMONCNT_addr,RIO_DATA,8);

	//RTC RYRCNT H'FFC8 001C H'1FC8 001C 16 Held Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RYRCNT_addr,RIO_DATA,16);
	
	//RTC RSECAR H'FFC8 0020 H'1FC8 0020 8 Held *2 Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RSECAR_addr,RIO_DATA,8);
	
	//RTC RMINAR H'FFC8 0024 H'1FC8 0024 8 Held *2 Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RMINAR_addr,RIO_DATA,8);

	//RTC RHRAR H'FFC8 0028 H'1FC8 0028 8 Held *2 Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RHRAR_addr,RIO_DATA,8);

	//RTC RWKAR H'FFC8 002C H'1FC8 002C 8 Held *2 Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RWKAR_addr,RIO_DATA,8);

	//RTC RDAYAR H'FFC8 0030 H'1FC8 0030 8 Held *2 Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RDAYAR_addr,RIO_DATA,8);

	//RTC RMONAR H'FFC8 0034 H'1FC8 0034 8 Held *2 Held Held Held Pclk
	sh4_rio_reg(RTC,RTC_RMONAR_addr,RIO_DATA,8);

	//RTC RCR1 H'FFC8 0038 H'1FC8 0038 8 H'00*2 H'00*2 Held Held Pclk
	sh4_rio_reg(RTC,RTC_RCR1_addr,RIO_DATA,8);

	//RTC RCR2 H'FFC8 003C H'1FC8 003C 8 H'09*2 H'00*2 Held Held Pclk
	sh4_rio_reg(RTC,RTC_RCR2_addr,RIO_DATA,8);
}

void rtc_reset()
{
	/*
	RTC R64CNT H'FFC8 0000 H'1FC8 0000 8 Held Held Held Held Pclk
	RTC RSECCNT H'FFC8 0004 H'1FC8 0004 8 Held Held Held Held Pclk
	RTC RMINCNT H'FFC8 0008 H'1FC8 0008 8 Held Held Held Held Pclk
	RTC RHRCNT H'FFC8 000C H'1FC8 000C 8 Held Held Held Held Pclk
	RTC RWKCNT H'FFC8 0010 H'1FC8 0010 8 Held Held Held Held Pclk
	RTC RDAYCNT H'FFC8 0014 H'1FC8 0014 8 Held Held Held Held Pclk
	RTC RMONCNT H'FFC8 0018 H'1FC8 0018 8 Held Held Held Held Pclk
	RTC RYRCNT H'FFC8 001C H'1FC8 001C 16 Held Held Held Held Pclk
	RTC RSECAR H'FFC8 0020 H'1FC8 0020 8 Held *2 Held Held Held Pclk
	RTC RMINAR H'FFC8 0024 H'1FC8 0024 8 Held *2 Held Held Held Pclk
	RTC RHRAR H'FFC8 0028 H'1FC8 0028 8 Held *2 Held Held Held Pclk
	RTC RWKAR H'FFC8 002C H'1FC8 002C 8 Held *2 Held Held Held Pclk
	RTC RDAYAR H'FFC8 0030 H'1FC8 0030 8 Held *2 Held Held Held Pclk
	RTC RMONAR H'FFC8 0034 H'1FC8 0034 8 Held *2 Held Held Held Pclk
	RTC RCR1 H'FFC8 0038 H'1FC8 0038 8 H'00*2 H'00*2 Held Held Pclk
	RTC RCR2 H'FFC8 003C H'1FC8 003C 8 H'09*2 H'00*2 Held Held Pclk
	*/
	RTC_RCR1=0x00;
	RTC_RCR2=0x09;
}

void rtc_term()
{
}