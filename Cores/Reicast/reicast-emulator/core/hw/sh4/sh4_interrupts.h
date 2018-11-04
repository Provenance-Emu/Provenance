#pragma once

#include "types.h"

enum InterruptType
{
	sh4_int   = 0x00000000,

	/*
	sh4_exp   = 0x01000000,
	*/

	InterruptTypeMask = 0x7F000000,
	InterruptIntEVNTMask=0x00FFFF00,
	InterruptPIIDMask=0x000000FF,
};

#define KMIID(type,ID,PIID) ( (type) | ((ID)<<8) | (PIID))
enum InterruptID
{
		//internal interrupts
		//IRL*
		//sh4_IRL_0         = KMIID(sh4_int,0x200,0),-> these are not connected on the Dreamcast
		//sh4_IRL_1         = KMIID(sh4_int,0x220,1),
		//sh4_IRL_2         = KMIID(sh4_int,0x240,2),
		//sh4_IRL_3         = KMIID(sh4_int,0x260,3),
		//sh4_IRL_4         = KMIID(sh4_int,0x280,4),
		//sh4_IRL_5         = KMIID(sh4_int,0x2A0,5),
		//sh4_IRL_6         = KMIID(sh4_int,0x2C0,6),
		//sh4_IRL_7         = KMIID(sh4_int,0x2E0,7),
		//sh4_IRL_8         = KMIID(sh4_int,0x300,8),
		sh4_IRL_9           = KMIID(sh4_int,0x320,0),
		//sh4_IRL_10        = KMIID(sh4_int,0x340,10),-> these are not connected on the Dreamcast
		sh4_IRL_11          = KMIID(sh4_int,0x360,1),
		//sh4_IRL_12        = KMIID(sh4_int,0x380,12),-> these are not connected on the Dreamcast
		sh4_IRL_13          = KMIID(sh4_int,0x3A0,2),
		//sh4_IRL_14        = KMIID(sh4_int,0x3C0,14),-> these are not connected on the Dreamcast
		//sh4_IRL_15        = KMIID(sh4_int,0x340,0), -> no interrupt (masked)

		sh4_HUDI_HUDI       = KMIID(sh4_int,0x600,3),  /* H-UDI underflow */

		sh4_GPIO_GPIOI      = KMIID(sh4_int,0x620,4),

		//DMAC
		sh4_DMAC_DMTE0      = KMIID(sh4_int,0x640,5),
		sh4_DMAC_DMTE1      = KMIID(sh4_int,0x660,6),
		sh4_DMAC_DMTE2      = KMIID(sh4_int,0x680,7),
		sh4_DMAC_DMTE3      = KMIID(sh4_int,0x6A0,8),
		sh4_DMAC_DMAE       = KMIID(sh4_int,0x6C0,9),

		//TMU
		sh4_TMU0_TUNI0      =  KMIID(sh4_int,0x400,10), /* TMU0 underflow */
		sh4_TMU1_TUNI1      =  KMIID(sh4_int,0x420,11), /* TMU1 underflow */
		sh4_TMU2_TUNI2      =  KMIID(sh4_int,0x440,12), /* TMU2 underflow */
		sh4_TMU2_TICPI2     =  KMIID(sh4_int,0x460,13), /* TMU Compare (not used in the Dreamcast)*/

		//RTC
		sh4_RTC_ATI         = KMIID(sh4_int,0x480,14),
		sh4_RTC_PRI         = KMIID(sh4_int,0x4A0,15),
		sh4_RTC_CUI         = KMIID(sh4_int,0x4C0,16),

		//SCI
		sh4_SCI1_ERI        = KMIID(sh4_int,0x4E0,17),
		sh4_SCI1_RXI        = KMIID(sh4_int,0x500,18),
		sh4_SCI1_TXI        = KMIID(sh4_int,0x520,19),
		sh4_SCI1_TEI        = KMIID(sh4_int,0x540,29),

		//SCIF
		sh4_SCIF_ERI        = KMIID(sh4_int,0x700,21),
		sh4_SCIF_RXI        = KMIID(sh4_int,0x720,22),
		sh4_SCIF_BRI        = KMIID(sh4_int,0x740,23),
		sh4_SCIF_TXI        = KMIID(sh4_int,0x760,24),

		//WDT
		sh4_WDT_ITI         = KMIID(sh4_int,0x560,25),

		//REF
		sh4_REF_RCMI        = KMIID(sh4_int,0x580,26),
		sh4_REF_ROVI        = KMIID(sh4_int,0x5A0,27),

		/*
		//sh4 exceptions
		sh4_ex_USER_BREAK_BEFORE_INSTRUCTION_EXECUTION = sh4_exp | 0x1e0,
		sh4_ex_INSTRUCTION_ADDRESS_ERROR =sh4_exp | 0x0e0,
		sh4_ex_INSTRUCTION_TLB_MISS =sh4_exp | 0x040,
		sh4_ex_INSTRUCTION_TLB_PROTECTION_VIOLATION = sh4_exp |0x0a0,
		sh4_ex_GENERAL_ILLEGAL_INSTRUCTION = sh4_exp |0x180,
		sh4_ex_SLOT_ILLEGAL_INSTRUCTION = sh4_exp |0x1a0,
		sh4_ex_GENERAL_FPU_DISABLE = sh4_exp |0x800,
		sh4_ex_SLOT_FPU_DISABLE = sh4_exp |0x820,
		sh4_ex_DATA_ADDRESS_ERROR_READ =sh4_exp |0x0e0,
		sh4_ex_DATA_ADDRESS_ERROR_WRITE = sh4_exp | 0x100,
		sh4_ex_DATA_TLB_MISS_READ = sh4_exp | 0x040,
		sh4_ex_DATA_TLB_MISS_WRITE = sh4_exp | 0x060,
		sh4_ex_DATA_TLB_PROTECTION_VIOLATION_READ = sh4_exp | 0x0a0,
		sh4_ex_DATA_TLB_PROTECTION_VIOLATION_WRITE = sh4_exp | 0x0c0,
		sh4_ex_FPU = sh4_exp | 0x120,
		sh4_ex_TRAP = sh4_exp | 0x160,
		sh4_ex_INITAL_PAGE_WRITE = sh4_exp | 0x080,
		*/
};

void SetInterruptPend(InterruptID intr);
void ResetInterruptPend(InterruptID intr);
#define InterruptPend(intr,v) ((v)==0?ResetInterruptPend(intr):SetInterruptPend(intr))

void SetInterruptMask(InterruptID intr);
void ResetInterruptMask(InterruptID intr);
#define InterruptMask(intr,v) ((v)==0?ResetInterruptMask(intr):SetInterruptMask(intr))

int UpdateINTC();
//extern u32 interrupt_pend;    //nonzero if there are pending interrupts

bool Do_Exception(u32 lvl, u32 expEvn, u32 CallVect);



bool SRdecode();
void SIIDRebuild();



//Init/Res/Term
void interrupts_init();
void interrupts_reset();
void interrupts_term();