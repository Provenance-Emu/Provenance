#pragma once
#include "types.h"
#include "../sh4/sh4_if.h"

//For mem mapping
void map_area7_init();
void map_area7(u32 base);
void map_p4();

#define OnChipRAM_SIZE (0x2000)
#define OnChipRAM_MASK (OnChipRAM_SIZE-1)

#define sq_both ((u8*)sh4rcb.sq_buffer)

extern Array<RegisterStruct> CCN;  //CCN  : 14 registers
extern Array<RegisterStruct> UBC;  //UBC  : 9 registers
extern Array<RegisterStruct> BSC;  //BSC  : 18 registers
extern Array<RegisterStruct> DMAC; //DMAC : 17 registers
extern Array<RegisterStruct> CPG;  //CPG  : 5 registers
extern Array<RegisterStruct> RTC;  //RTC  : 16 registers
extern Array<RegisterStruct> INTC; //INTC : 4 registers
extern Array<RegisterStruct> TMU;  //TMU  : 12 registers
extern Array<RegisterStruct> SCI;  //SCI  : 8 registers
extern Array<RegisterStruct> SCIF; //SCIF : 10 registers

/*
//Region P4
u32 ReadMem_P4(u32 addr,u32 sz);
void WriteMem_P4(u32 addr,u32 data,u32 sz);

//Area7
u32 ReadMem_area7(u32 addr,u32 sz);
void WriteMem_area7(u32 addr,u32 data,u32 sz);
void DYNACALL WriteMem_sq_32(u32 address,u32 data);*/

//Init/Res/Term
void sh4_mmr_init();
void sh4_mmr_reset();
void sh4_mmr_term();

void sh4_rio_reg(Array<RegisterStruct>& arr, u32 addr, RegIO flags, u32 sz, RegReadAddrFP* rp=0, RegWriteAddrFP* wp=0);

#define A7_REG_HASH(addr) ((addr>>16)&0x1FFF)

#define SH4IO_REGN(mod,addr,size) (mod[(addr&255)/4].data##size)
#define SH4IO_REG(mod,name,size) SH4IO_REGN(mod,mod##_##name##_addr,size)
#define SH4IO_REG_T(mod,name,size) ((mod##_##name##_type&)SH4IO_REG(mod,name,size))

#define SH4IO_REG_OFS(mod,name,o,s,size) SH4IO_REGN(mod,mod##_##name##0_addr+o*s,size)
#define SH4IO_REG_T_OFS(mod,name,o,s,size) ((mod##_##name##_type&)SH4IO_REG_OFS(mod,name,o,s,size))

//CCN module registers base
#define CCN_BASE_addr 0x1F000000

//CCN PTEH 0xFF000000 0x1F000000 32 Undefined Undefined Held Held Iclk
#define CCN_PTEH_addr 0x1F000000

//CCN PTEL 0xFF000004 0x1F000004 32 Undefined Undefined Held Held Iclk
#define CCN_PTEL_addr 0x1F000004

//CCN TTB 0xFF000008 0x1F000008 32 Undefined Undefined Held Held Iclk
#define CCN_TTB_addr 0x1F000008

//CCN TEA 0xFF00000C 0x1F00000C 32 Undefined Held Held Held Iclk
#define CCN_TEA_addr 0x1F00000C

//CCN MMUCR 0xFF000010 0x1F000010 32 0x00000000 0x00000000 Held Held Iclk
#define CCN_MMUCR_addr 0x1F000010

//CCN BASRA 0xFF000014 0x1F000014 8 Undefined Held Held Held Iclk
#define CCN_BASRA_addr 0x1F000014

//CCN BASRB 0xFF000018 0x1F000018 8 Undefined Held Held Held Iclk
#define CCN_BASRB_addr 0x1F000018

//CCN CCR 0xFF00001C 0x1F00001C 32 0x00000000 0x00000000 Held Held Iclk
#define CCN_CCR_addr 0x1F00001C

//CCN TRA 0xFF000020 0x1F000020 32 Undefined Undefined Held Held Iclk
#define CCN_TRA_addr 0x1F000020

//CCN EXPEVT 0xFF000024 0x1F000024 32 0x00000000 0x00000020 Held Held Iclk
#define CCN_EXPEVT_addr 0x1F000024

//CCN INTEVT 0xFF000028 0x1F000028 32 Undefined Undefined Held Held Iclk
#define CCN_INTEVT_addr 0x1F000028

//CCN PTEA 0xFF000034 0x1F000034 32 Undefined Undefined Held Held Iclk
#define CCN_PTEA_addr 0x1F000034

//CCN QACR0 0xFF000038 0x1F000038 32 Undefined Undefined Held Held Iclk
#define CCN_QACR0_addr 0x1F000038

//CCN QACR1 0xFF00003C 0x1F00003C 32 Undefined Undefined Held Held Iclk
#define CCN_QACR1_addr 0x1F00003C

//UBC module registers base
#define UBC_BASE_addr 0x1F200000

//UBC BARA 0xFF200000 0x1F200000 32 Undefined Held Held Held Iclk
#define UBC_BARA_addr 0x1F200000

//UBC BAMRA 0xFF200004 0x1F200004 8 Undefined Held Held Held Iclk
#define UBC_BAMRA_addr 0x1F200004

//UBC BBRA 0xFF200008 0x1F200008 16 0x0000 Held Held Held Iclk
#define UBC_BBRA_addr 0x1F200008

//UBC BARB 0xFF20000C 0x1F20000C 32 Undefined Held Held Held Iclk
#define UBC_BARB_addr 0x1F20000C

//UBC BAMRB 0xFF200010 0x1F200010 8 Undefined Held Held Held Iclk
#define UBC_BAMRB_addr 0x1F200010

//UBC BBRB 0xFF200014 0x1F200014 16 0x0000 Held Held Held Iclk
#define UBC_BBRB_addr 0x1F200014

//UBC BDRB 0xFF200018 0x1F200018 32 Undefined Held Held Held Iclk
#define UBC_BDRB_addr 0x1F200018

//UBC BDMRB 0xFF20001C 0x1F20001C 32 Undefined Held Held Held Iclk
#define UBC_BDMRB_addr 0x1F20001C

//UBC BRCR 0xFF200020 0x1F200020 16 0x0000 Held Held Held Iclk
#define UBC_BRCR_addr 0x1F200020

//BSC module registers base
#define BSC_BASE_addr 0x1F800000

//BSC BCR1 0xFF800000 0x1F800000 32 0x00000000 Held Held Held Bclk
#define BSC_BCR1_addr 0x1F800000

//BSC BCR2 0xFF800004 0x1F800004 16 0x3FFC Held Held Held Bclk
#define BSC_BCR2_addr 0x1F800004

//BSC WCR1 0xFF800008 0x1F800008 32 0x77777777 Held Held Held Bclk
#define BSC_WCR1_addr 0x1F800008

//BSC WCR2 0xFF80000C 0x1F80000C 32 0xFFFEEFFF Held Held Held Bclk
#define BSC_WCR2_addr 0x1F80000C

//BSC WCR3 0xFF800010 0x1F800010 32 0x07777777 Held Held Held Bclk
#define BSC_WCR3_addr 0x1F800010

//BSC MCR 0xFF800014 0x1F800014 32 0x00000000 Held Held Held Bclk
#define BSC_MCR_addr 0x1F800014

//BSC PCR 0xFF800018 0x1F800018 16 0x0000 Held Held Held Bclk
#define BSC_PCR_addr 0x1F800018

//BSC RTCSR 0xFF80001C 0x1F80001C 16 0x0000 Held Held Held Bclk
#define BSC_RTCSR_addr 0x1F80001C

//BSC RTCNT 0xFF800020 0x1F800020 16 0x0000 Held Held Held Bclk
#define BSC_RTCNT_addr 0x1F800020

//BSC RTCOR 0xFF800024 0x1F800024 16 0x0000 Held Held Held Bclk
#define BSC_RTCOR_addr 0x1F800024

//BSC RFCR 0xFF800028 0x1F800028 16 0x0000 Held Held Held Bclk
#define BSC_RFCR_addr 0x1F800028

//BSC PCTRA 0xFF80002C 0x1F80002C 32 0x00000000 Held Held Held Bclk
#define BSC_PCTRA_addr 0x1F80002C

//BSC PDTRA 0xFF800030 0x1F800030 16 Undefined Held Held Held Bclk
#define BSC_PDTRA_addr 0x1F800030

//BSC PCTRB 0xFF800040 0x1F800040 32 0x00000000 Held Held Held Bclk
#define BSC_PCTRB_addr 0x1F800040

//BSC PDTRB 0xFF800044 0x1F800044 16 Undefined Held Held Held Bclk
#define BSC_PDTRB_addr 0x1F800044

//BSC GPIOIC 0xFF800048 0x1F800048 16 0x00000000 Held Held Held Bclk
#define BSC_GPIOIC_addr 0x1F800048

//BSC SDMR2 0xFF90xxxx 0x1F90xxxx 8 Write-only Bclk
#define BSC_SDMR2_addr 0x1F900000

//BSC SDMR3 0xFF94xxxx 0x1F94xxxx 8 Bclk
#define BSC_SDMR3_addr 0x1F940000

//DMAC module registers base
#define DMAC_BASE_addr 0x1FA00000

//DMAC SAR0 0xFFA00000 0x1FA00000 32 Undefined Undefined Held Held Bclk
#define DMAC_SAR0_addr 0x1FA00000

//DMAC DAR0 0xFFA00004 0x1FA00004 32 Undefined Undefined Held Held Bclk
#define DMAC_DAR0_addr 0x1FA00004

//DMAC DMATCR0 0xFFA00008 0x1FA00008 32 Undefined Undefined Held Held Bclk
#define DMAC_DMATCR0_addr 0x1FA00008

//DMAC CHCR0 0xFFA0000C 0x1FA0000C 32 0x00000000 0x00000000 Held Held Bclk
#define DMAC_CHCR0_addr 0x1FA0000C

//DMAC SAR1 0xFFA00010 0x1FA00010 32 Undefined Undefined Held Held Bclk
#define DMAC_SAR1_addr 0x1FA00010

//DMAC DAR1 0xFFA00014 0x1FA00014 32 Undefined Undefined Held Held Bclk
#define DMAC_DAR1_addr 0x1FA00014

//DMAC DMATCR1 0xFFA00018 0x1FA00018 32 Undefined Undefined Held Held Bclk
#define DMAC_DMATCR1_addr 0x1FA00018

//DMAC CHCR1 0xFFA0001C 0x1FA0001C 32 0x00000000 0x00000000 Held Held Bclk
#define DMAC_CHCR1_addr 0x1FA0001C

//DMAC SAR2 0xFFA00020 0x1FA00020 32 Undefined Undefined Held Held Bclk
#define DMAC_SAR2_addr 0x1FA00020

//DMAC DAR2 0xFFA00024 0x1FA00024 32 Undefined Undefined Held Held Bclk
#define DMAC_DAR2_addr 0x1FA00024

//DMAC DMATCR2 0xFFA00028 0x1FA00028 32 Undefined Undefined Held Held Bclk
#define DMAC_DMATCR2_addr 0x1FA00028

//DMAC CHCR2 0xFFA0002C 0x1FA0002C 32 0x00000000 0x00000000 Held Held Bclk
#define DMAC_CHCR2_addr 0x1FA0002C

//DMAC SAR3 0xFFA00030 0x1FA00030 32 Undefined Undefined Held Held Bclk
#define DMAC_SAR3_addr 0x1FA00030

//DMAC DAR3 0xFFA00034 0x1FA00034 32 Undefined Undefined Held Held Bclk
#define DMAC_DAR3_addr 0x1FA00034

//DMAC DMATCR3 0xFFA00038 0x1FA00038 32 Undefined Undefined Held Held Bclk
#define DMAC_DMATCR3_addr 0x1FA00038

//DMAC CHCR3 0xFFA0003C 0x1FA0003C 32 0x00000000 0x00000000 Held Held Bclk
#define DMAC_CHCR3_addr 0x1FA0003C

//DMAC DMAOR 0xFFA00040 0x1FA00040 32 0x00000000 0x00000000 Held Held Bclk
#define DMAC_DMAOR_addr 0x1FA00040

//CPG module registers base
#define CPG_BASE_addr 0x1FC00000

//CPG FRQCR 0xFFC00000 0x1FC00000 16  Held Held Held Pclk
#define CPG_FRQCR_addr 0x1FC00000

//CPG STBCR 0xFFC00004 0x1FC00004 8 0x00 Held Held Held Pclk
#define CPG_STBCR_addr 0x1FC00004

//CPG WTCNT 0xFFC00008 0x1FC00008 8/16 0x00 Held Held Held Pclk
#define CPG_WTCNT_addr 0x1FC00008

//CPG WTCSR 0xFFC0000C 0x1FC0000C 8/16 0x00 Held Held Held Pclk
#define CPG_WTCSR_addr 0x1FC0000C

//CPG STBCR2 0xFFC00010 0x1FC00010 8 0x00 Held Held Held Pclk
#define CPG_STBCR2_addr 0x1FC00010

//RTC module registers base
#define RTC_BASE_addr 0x1FC80000

//RTC R64CNT 0xFFC80000 0x1FC80000 8 Held Held Held Held Pclk
#define RTC_R64CNT_addr 0x1FC80000

//RTC RSECCNT 0xFFC80004 0x1FC80004 8 Held Held Held Held Pclk
#define RTC_RSECCNT_addr 0x1FC80004

//RTC RMINCNT 0xFFC80008 0x1FC80008 8 Held Held Held Held Pclk
#define RTC_RMINCNT_addr 0x1FC80008

//RTC RHRCNT 0xFFC8000C 0x1FC8000C 8 Held Held Held Held Pclk
#define RTC_RHRCNT_addr 0x1FC8000C

//RTC RWKCNT 0xFFC80010 0x1FC80010 8 Held Held Held Held Pclk
#define RTC_RWKCNT_addr 0x1FC80010

//RTC RDAYCNT 0xFFC80014 0x1FC80014 8 Held Held Held Held Pclk
#define RTC_RDAYCNT_addr 0x1FC80014

//RTC RMONCNT 0xFFC80018 0x1FC80018 8 Held Held Held Held Pclk
#define RTC_RMONCNT_addr 0x1FC80018

//RTC RYRCNT 0xFFC8001C 0x1FC8001C 16 Held Held Held Held Pclk
#define RTC_RYRCNT_addr 0x1FC8001C

//RTC RSECAR 0xFFC80020 0x1FC80020 8 Held  Held Held Held Pclk
#define RTC_RSECAR_addr 0x1FC80020

//RTC RMINAR 0xFFC80024 0x1FC80024 8 Held  Held Held Held Pclk
#define RTC_RMINAR_addr 0x1FC80024

//RTC RHRAR 0xFFC80028 0x1FC80028 8 Held  Held Held Held Pclk
#define RTC_RHRAR_addr 0x1FC80028

//RTC RWKAR 0xFFC8002C 0x1FC8002C 8 Held  Held Held Held Pclk
#define RTC_RWKAR_addr 0x1FC8002C

//RTC RDAYAR 0xFFC80030 0x1FC80030 8 Held  Held Held Held Pclk
#define RTC_RDAYAR_addr 0x1FC80030

//RTC RMONAR 0xFFC80034 0x1FC80034 8 Held  Held Held Held Pclk
#define RTC_RMONAR_addr 0x1FC80034

//RTC RCR1 0xFFC80038 0x1FC80038 8 0x00 0x00 Held Held Pclk
#define RTC_RCR1_addr 0x1FC80038

//RTC RCR2 0xFFC8003C 0x1FC8003C 8 0x09 0x00 Held Held Pclk
#define RTC_RCR2_addr 0x1FC8003C

//INTC module registers base
#define INTC_BASE_addr 0x1FD00000

//INTC ICR 0xFFD00000 0x1FD00000 16 0x0000 0x0000 Held Held Pclk
#define INTC_ICR_addr 0x1FD00000

//INTC IPRA 0xFFD00004 0x1FD00004 16 0x0000 0x0000 Held Held Pclk
#define INTC_IPRA_addr 0x1FD00004

//INTC IPRB 0xFFD00008 0x1FD00008 16 0x0000 0x0000 Held Held Pclk
#define INTC_IPRB_addr 0x1FD00008

//INTC IPRC 0xFFD0000C 0x1FD0000C 16 0x0000 0x0000 Held Held Pclk
#define INTC_IPRC_addr 0x1FD0000C

//TMU module registers base
#define TMU_BASE_addr 0x1FD80000

//TMU TOCR 0xFFD80000 0x1FD80000 8 0x00 0x00 Held Held Pclk
#define TMU_TOCR_addr 0x1FD80000

//TMU TSTR 0xFFD80004 0x1FD80004 8 0x00 0x00 Held 0x00 Pclk
#define TMU_TSTR_addr 0x1FD80004

//TMU TCOR0 0xFFD80008 0x1FD80008 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
#define TMU_TCOR0_addr 0x1FD80008

//TMU TCNT0 0xFFD8000C 0x1FD8000C 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
#define TMU_TCNT0_addr 0x1FD8000C

//TMU TCR0 0xFFD80010 0x1FD80010 16 0x0000 0x0000 Held Held Pclk
#define TMU_TCR0_addr 0x1FD80010

//TMU TCOR1 0xFFD80014 0x1FD80014 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
#define TMU_TCOR1_addr 0x1FD80014

//TMU TCNT1 0xFFD80018 0x1FD80018 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
#define TMU_TCNT1_addr 0x1FD80018

//TMU TCR1 0xFFD8001C 0x1FD8001C 16 0x0000 0x0000 Held Held Pclk
#define TMU_TCR1_addr 0x1FD8001C

//TMU TCOR2 0xFFD80020 0x1FD80020 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
#define TMU_TCOR2_addr 0x1FD80020

//TMU TCNT2 0xFFD80024 0x1FD80024 32 0xFFFFFFFF 0xFFFFFFFF Held Held Pclk
#define TMU_TCNT2_addr 0x1FD80024

//TMU TCR2 0xFFD80028 0x1FD80028 16 0x0000 0x0000 Held Held Pclk
#define TMU_TCR2_addr 0x1FD80028

//TMU TCPR2 0xFFD8002C 0x1FD8002C 32 Held Held Held Held Pclk
#define TMU_TCPR2_addr 0x1FD8002C

//SCI module registers base
#define SCI_BASE_addr 0x1FE00000

//SCI SCSMR1 0xFFE00000 0x1FE00000 8 0x00 0x00 Held 0x00 Pclk
#define SCI_SCSMR1_addr 0x1FE00000

//SCI SCBRR1 0xFFE00004 0x1FE00004 8 0xFF 0xFF Held 0xFF Pclk
#define SCI_SCBRR1_addr 0x1FE00004

//SCI SCSCR1 0xFFE00008 0x1FE00008 8 0x00 0x00 Held 0x00 Pclk
#define SCI_SCSCR1_addr 0x1FE00008

//SCI SCTDR1 0xFFE0000C 0x1FE0000C 8 0xFF 0xFF Held 0xFF Pclk
#define SCI_SCTDR1_addr 0x1FE0000C

//SCI SCSSR1 0xFFE00010 0x1FE00010 8 0x84 0x84 Held 0x84 Pclk
#define SCI_SCSSR1_addr 0x1FE00010

//SCI SCRDR1 0xFFE00014 0x1FE00014 8 0x00 0x00 Held 0x00 Pclk
#define SCI_SCRDR1_addr 0x1FE00014

//SCI SCSCMR1 0xFFE00018 0x1FE00018 8 0x00 0x00 Held 0x00 Pclk
#define SCI_SCSCMR1_addr 0x1FE00018

//SCI SCSPTR1 0xFFE0001C 0x1FE0001C 8 0x00 0x00 Held 0x00*2Pclk
#define SCI_SCSPTR1_addr 0x1FE0001C

//SCIF module registers base
#define SCIF_BASE_addr 0x1FE80000

//SCIF SCSMR2 0xFFE80000 0x1FE80000 16 0x0000 0x0000 Held Held Pclk
#define SCIF_SCSMR2_addr 0x1FE80000

//SCIF SCBRR2 0xFFE80004 0x1FE80004 8 0xFF 0xFF Held Held Pclk
#define SCIF_SCBRR2_addr 0x1FE80004

//SCIF SCSCR2 0xFFE80008 0x1FE80008 16 0x0000 0x0000 Held Held Pclk
#define SCIF_SCSCR2_addr 0x1FE80008

//SCIF SCFTDR2 0xFFE8000C 0x1FE8000C 8 Undefined Undefined Held Held Pclk
#define SCIF_SCFTDR2_addr 0x1FE8000C

//SCIF SCFSR2 0xFFE80010 0x1FE80010 16 0x0060 0x0060 Held Held Pclk
#define SCIF_SCFSR2_addr 0x1FE80010

//SCIF SCFRDR2 0xFFE80014 0x1FE80014 8 Undefined Undefined Held Held Pclk
#define SCIF_SCFRDR2_addr 0x1FE80014

//SCIF SCFCR2 0xFFE80018 0x1FE80018 16 0x0000 0x0000 Held Held Pclk
#define SCIF_SCFCR2_addr 0x1FE80018

//SCIF SCFDR2 0xFFE8001C 0x1FE8001C 16 0x0000 0x0000 Held Held Pclk
#define SCIF_SCFDR2_addr 0x1FE8001C

//SCIF SCSPTR2 0xFFE80020 0x1FE80020 16 0x0000 0x0000 Held Held Pclk
#define SCIF_SCSPTR2_addr 0x1FE80020

//SCIF SCLSR2 0xFFE80024 0x1FE80024 16 0x0000 0x0000 Held Held Pclk
#define SCIF_SCLSR2_addr 0x1FE80024

//UDI module registers base
#define UDI_BASE_addr 0x1FF00000

//UDI SDIR 0xFFF00000 0x1FF00000 16 0xFFFF Held Held Held Pclk
#define UDI_SDIR_addr 0x1FF00000

//UDI SDDR 0xFFF00008 0x1FF00008 32 Held Held Held Held Pclk
#define UDI_SDDR_addr 0x1FF00008






//32 bits
//All bits exept A0MPX,MASTER,ENDIAN are editable and reseted to 0
union BSC_BCR1_type
{
	struct
	{
		u32 A56PCM  : 1;
		u32 res_0   : 1;
		u32 DRAMTP0 : 1;
		u32 DRAMTP1 : 1;
		u32 DRAMTP2 : 1;
		u32 A6BST0  : 1;
		u32 A6BST1  : 1;
		u32 A6BST2  : 1;
		//8
		u32 A5BST0 : 1;
		u32 A5BST1 : 1;
		u32 A5BST2 : 1;
		u32 A0BST0 : 1;
		u32 A0BST1 : 1;
		u32 A0BST2 : 1;
		u32 HIZCNT : 1;
		u32 HIZMEM : 1;
		//16
		u32 res_1  : 1;
		u32 MEMMPX : 1;
		u32 PSHR   : 1;
		u32 BREQEN : 1;
		u32 A4MBC  : 1;
		u32 A1MBC  : 1;
		u32 res_2  : 1;
		u32 res_3  : 1;
		//24
		u32 OPUP   : 1;
		u32 IPUP   : 1;
		u32 res_4  : 1;
		u32 res_5  : 1;
		u32 res_6  : 1;
		u32 A0MPX  : 1;  // Set to 1 (area 0 is mpx)
		u32 MASTER : 1; // What is it on the Dreamcast ?
		u32 ENDIAN : 1; // This is 1 on the Dreamcast
	};

	u32 full;
};


#define BSC_BCR1 SH4IO_REG_T(BSC,BCR1,32)
//extern BCR1_type BSC_BCR1;

//16 bit
//A0SZ0,A0SZ1 are read only , others are are editable and reseted to 0
union BSC_BCR2_type
{
	struct
	{
		u32 PORTEN    : 1;
		u32 res_0     : 1;
		u32 A0SZ0     : 1;
		u32 A1SZ1     : 1;
		u32 A2SZ0     : 1;
		u32 A2SZ1     : 1;
		u32 A3SZ0     : 1;
		u32 A3SZ1     : 1;
		//8
		u32 A4SZ0     : 1;
		u32 A4SZ1     : 1;
		u32 A5SZ0     : 1;
		u32 A5SZ1     : 1;
		u32 A6SZ0     : 1;
		u32 A6SZ1     : 1;
		u32 A0SZ0_inp : 1; //read only - what value on the Dreamcast?
		u32 A0SZ1_inp : 1; //read only - what value on the Dreamcast?
		//16
	};

	u16 full;
};
#define BSC_BCR2 SH4IO_REG_T(BSC,BCR2,16)

//32 bits
union BSC_WCR1_type
{
	struct
	{
		u32 A0IW0  : 1;
		u32 A0IW1  : 1;
		u32 A0IW2  : 1;
		u32 res_0  : 1;
		u32 A1IW0  : 1;
		u32 A1IW1  : 1;
		u32 A1IW2  : 1;
		u32 res_1  : 1;
		//8
		u32 A2IW0  : 1;
		u32 A2IW1  : 1;
		u32 A2IW2  : 1;
		u32 res_2  : 1;
		u32 A3IW0  : 1;
		u32 A3IW1  : 1;
		u32 A3IW2  : 1;
		u32 res_3  : 1;
		//16
		u32 A4IW0  : 1;
		u32 A4IW1  : 1;
		u32 A4IW2  : 1;
		u32 res_4  : 1;
		u32 A5IW0  : 1;
		u32 A5IW1  : 1;
		u32 A5IW2  : 1;
		u32 res_5  : 1;
		//24
		u32 A6IW0  : 1;
		u32 A6IW1  : 1;
		u32 A6IW2  : 1;
		u32 res_6  : 1;
		u32 DMAIW0 : 1;
		u32 DMAIW1 : 1;
		u32 DMAIW2 : 1;
		u32 res_7  : 1;
	};

	u32 full;
};
#define BSC_WCR1 SH4IO_REG_T(BSC,WCR1,32)

//32 bits
union BSC_WCR2_type
{
	struct
	{
		u32 A0B0  : 1;
		u32 A0B1  : 1;
		u32 A0B2  : 1;
		u32 A0W0  : 1;
		u32 A0W1  : 1;
		u32 A0W2  : 1;
		u32 A1W0  : 1;
		u32 A1W1  : 1;
		//8
		u32 A1W2  : 1;
		u32 A2W0  : 1;
		u32 A2W1  : 1;
		u32 A2W2  : 1;
		u32 res_0 : 1;
		u32 A3W0  : 1;
		u32 A3W1  : 1;
		u32 A3W2  : 1;
		//16
		u32 res_1 : 1;
		u32 A4W0  : 1;
		u32 A4W1  : 1;
		u32 A4W2  : 1;
		u32 A5B0  : 1;
		u32 A5B1  : 1;
		u32 A5B2  : 1;
		u32 A5W0  : 1;
		//24
		u32 A5W1  : 1;
		u32 A5W2  : 1;
		u32 A6B0  : 1;
		u32 A6B1  : 1;
		u32 A6B2  : 1;
		u32 A6W0  : 1;
		u32 A6W1  : 1;
		u32 A6W2  : 1;
	};

	u32 full;
};

#define BSC_WCR2 SH4IO_REG_T(BSC,WCR2,32)

//32 bits
union BSC_WCR3_type
{
	struct
	{
		u32 A0H0   : 1;
		u32 A0H1   : 1;
		u32 A0S0   : 1;
		u32 res_0  : 1;
		u32 A1H0   : 1; //TODO: check if this is correct, on the manual it says A1H0 .. typo in the manual ? 
		u32 A1H1   : 1;
		u32 A1S0   : 1;
		u32 res_1  : 1;
		//8
		u32 A2H0   : 1;
		u32 A2H1   : 1;
		u32 A2S0   : 1;
		u32 res_2  : 1;
		u32 A3H0   : 1;
		u32 A3H1   : 1;
		u32 A3S0   : 1;
		u32 res_3  : 1;
		//16
		u32 A4H0   : 1;
		u32 A4H1   : 1;
		u32 A4S0   : 1;
		u32 res_4  : 1;
		u32 A5H0   : 1;
		u32 A5H1   : 1;
		u32 A5S0   : 1;
		u32 res_5  : 1;
		//24
		u32 A6H0   : 1;
		u32 A6H1   : 1;
		u32 A6S0   : 1;
		u32 res_6  : 1;
		u32 res_7  : 1;
		u32 res_8  : 1;
		u32 res_9  : 1;
		u32 res_10 : 1;
	};

	u32 full;
};


#define BSC_WCR3 SH4IO_REG_T(BSC,WCR3,32)

//32 bits
union BSC_MCR_type
{
	struct
	{
		u32 EDO_MODE : 1;
		u32 RMODE    : 1;
		u32 RFSH     : 1;
		u32 AMX0     : 1;
		u32 AMX1     : 1;
		u32 AMX2     : 1;
		u32 AMXEXT   : 1;
		u32 SZ0      : 1;
		//8
		u32 SZ1      : 1;
		u32 BE       : 1;
		u32 TRAS0    : 1;
		u32 TRAS1    : 1;
		u32 TRAS2    : 1;
		u32 TRWL0    : 1;
		u32 TRWL1    : 1;
		u32 TRWL2    : 1;
		//16
		u32 RCD0     : 1;
		u32 RCD1     : 1;
		u32 res_0    : 1;
		u32 TPC0     : 1;
		u32 TPC1     : 1;
		u32 TPC2     : 1;
		u32 res_1    : 1;
		u32 TCAS     : 1;
		//24
		u32 res_2    : 1;
		u32 res_3    : 1;
		u32 res_4    : 1;
		u32 TRC0     : 1;
		u32 TRC1     : 1;
		u32 TRC2     : 1;
		u32 MRSET    : 1;
		u32 RASD     : 1;
	};

	u32 full;
};


#define BSC_MCR SH4IO_REG_T(BSC,MCR,32)

//16 bits
union BSC_PCR_type
{
	struct
	{
		u32 A6TEH0 : 1;
		u32 A6TEH1 : 1;
		u32 A6TEH2 : 1;
		u32 A5TEH0 : 1;
		u32 A5TEH1 : 1;
		u32 A5TEH2 : 1;
		u32 A6TED0 : 1;
		u32 A6TED1 : 1;
		//8
		u32 A6TED2 : 1;
		u32 A5TED0 : 1;
		u32 A5TED1 : 1;
		u32 A5TED2 : 1;
		u32 A6PCW0 : 1;
		u32 A6PCW1 : 1;
		u32 A5PCW0 : 1;
		u32 A5PCW1 : 1;
		//16
	};
	u16 full;
};

#define BSC_PCR SH4IO_REG_T(BSC,PCR,16)

//16 bits -> misstype on manual ? RTSCR vs RTCSR...
union BSC_RTCSR_type
{
	struct
	{
		u32 LMTS : 1;
		u32 OVIE : 1;
		u32 OVF  : 1;
		u32 CKS0 : 1;
		u32 CKS1 : 1;
		u32 CKS2 : 1;
		u32 CMIE : 1;
		u32 CMF  : 1;
		//8
		u32 res_0 : 1;
		u32 res_1 : 1;
		u32 res_2 : 1;
		u32 res_3 : 1;
		u32 res_4 : 1;
		u32 res_5 : 1;
		u32 res_6 : 1;
		u32 res_7 : 1;
		//16
	};
	u16 full;
};

#define BSC_RTCSR SH4IO_REG_T(BSC,RTCSR,16)

//16 bits
union BSC_RTCNT_type
{
	struct
	{
		u32 VALUE : 8;
		//8
		u32 res_0 : 1;
		u32 res_1 : 1;
		u32 res_2 : 1;
		u32 res_3 : 1;
		u32 res_4 : 1;
		u32 res_5 : 1;
		u32 res_6 : 1;
		u32 res_7 : 1;
		//16
	};
	u16 full;
};

#define BSC_RTCNT SH4IO_REG_T(BSC,RTCNT,16)

//16 bits
union BSC_RTCOR_type
{
	struct
	{
		u32 VALUE : 8;
		//8
		u32 res_0 : 1;
		u32 res_1 : 1;
		u32 res_2 : 1;
		u32 res_3 : 1;
		u32 res_4 : 1;
		u32 res_5 : 1;
		u32 res_6 : 1;
		u32 res_7 : 1;
		//16
	};
	u16 full;
};


#define BSC_RTCOR SH4IO_REG_T(BSC,RTCOR,16)

//16 bits
union BSC_RFCR_type
{
	struct
	{
		u32 VALUE : 10;
		//10
		u32 res_2 : 1;
		u32 res_3 : 1;
		u32 res_4 : 1;
		u32 res_5 : 1;
		u32 res_6 : 1;
		u32 res_7 : 1;
		//16
	};
	u16 full;
};

#define BSC_RFCR SH4IO_REG_T(BSC,RFCR,16)

//32 bits
union BSC_PCTRA_type
{
	struct
	{
		u32 PB0IO   : 1;
		u32 PB0PUP  : 1;
		u32 PB1IO   : 1;
		u32 PB1PUP  : 1;
		u32 PB2IO   : 1;
		u32 PB2PUP  : 1;
		u32 PB3IO   : 1;
		u32 PB3PUP  : 1;
		//8
		u32 PB4IO   : 1;
		u32 PB4PUP  : 1;
		u32 PB5IO   : 1;
		u32 PB5PUP  : 1;
		u32 PB6IO   : 1;
		u32 PB6PUP  : 1;
		u32 PB7IO   : 1;
		u32 PB7PUP  : 1;
		//16
		u32 PB8IO   : 1;
		u32 PB8PUP  : 1;
		u32 PB9IO   : 1;
		u32 PB9PUP  : 1;
		u32 PB10IO  : 1;
		u32 PB10PUP : 1;
		u32 PB11IO  : 1;
		u32 PB11PUP : 1;
		//24
		u32 PB12IO  : 1;
		u32 PB12PUP : 1;
		u32 PB13IO  : 1;
		u32 PB13PUP : 1;
		u32 PB14IO  : 1;
		u32 PB14PUP : 1;
		u32 PB15IO  : 1;
		u32 PB15PUP : 1;
	};

	u32 full;
};

#define BSC_PCTRA SH4IO_REG_T(BSC,PCTRA,32)

//16 bits
union BSC_PDTRA_type
{
	struct
	{
		u32 PB0DT  : 1;
		u32 PB1DT  : 1;
		u32 PB2DT  : 1;
		u32 PB3DT  : 1;
		u32 PB4DT  : 1;
		u32 PB5DT  : 1;
		u32 PB6DT  : 1;
		u32 PB7DT  : 1;
		//8
		u32 PB8DT  : 1;
		u32 PB9DT  : 1;
		u32 PB10DT : 1;
		u32 PB11DT : 1;
		u32 PB12DT : 1;
		u32 PB13DT : 1;
		u32 PB14DT : 1;
		u32 PB15DT : 1;
		//16
	};
	u16 full;
};

extern BSC_PDTRA_type BSC_PDTRA;

//32 bits
union BSC_PCTRB_type
{
	struct
	{
		u32 PB16IO  : 1;
		u32 PB16PUP : 1;
		u32 PB17IO  : 1;
		u32 PB17PUP : 1;
		u32 PB18IO  : 1;
		u32 PB18PUP : 1;
		u32 PB19IO  : 1;
		u32 PB19PUP : 1;
		//8
		u32 res_0   : 1;
		u32 res_1   : 1;
		u32 res_2   : 1;
		u32 res_3   : 1;
		u32 res_4   : 1;
		u32 res_5   : 1;
		u32 res_6   : 1;
		u32 res_7   : 1;
		//16
		u32 res_8   : 1;
		u32 res_9   : 1;
		u32 res_10  : 1;
		u32 res_11  : 1;
		u32 res_12  : 1;
		u32 res_13  : 1;
		u32 res_14  : 1;
		u32 res_15  : 1;
		//24
		u32 res_16  : 1;
		u32 res_17  : 1;
		u32 res_18  : 1;
		u32 res_19  : 1;
		u32 res_20  : 1;
		u32 res_21  : 1;
		u32 res_22  : 1;
		u32 res_23  : 1;
	};

	u32 full;
};

#define BSC_PCTRB SH4IO_REG_T(BSC,PCTRB,32)

//16 bits
union BSC_PDTRB_type
{
	struct
	{
		u32 PB16DT : 1;
		u32 PB17DT : 1;
		u32 PB18DT : 1;
		u32 PB19DT : 1;
		u32 res_0  : 1;
		u32 res_1  : 1;
		u32 res_2  : 1;
		u32 res_3  : 1;
		//8
		u32 res_4  : 1;
		u32 res_5  : 1;
		u32 res_6  : 1;
		u32 res_7  : 1;
		u32 res_8  : 1;
		u32 res_9  : 1;
		u32 res_10 : 1;
		u32 res_11 : 1;
		//16
	};
	u16 full;
};

#define BSC_PDTRB SH4IO_REG_T(BSC,PDTRB,16)

//16 bits
union BSC_GPIOIC_type
{
	struct
	{
		u32 PTIREN0  : 1;
		u32 PTIREN1  : 1;
		u32 PTIREN2  : 1;
		u32 PTIREN3  : 1;
		u32 PTIREN4  : 1;
		u32 PTIREN5  : 1;
		u32 PTIREN6  : 1;
		u32 PTIREN7  : 1;
		//8
		u32 PTIREN8  : 1;
		u32 PTIREN9  : 1;
		u32 PTIREN10 : 1;
		u32 PTIREN11 : 1;
		u32 PTIREN12 : 1;
		u32 PTIREN13 : 1;
		u32 PTIREN14 : 1;
		u32 PTIREN15 : 1;
		//16
	};
	u16 full;
};

#define BSC_GPIOIC SH4IO_REG_T(BSC,GPIOIC,16)



union CCN_PTEH_type
{
	struct
	{
		u32 ASID : 8;  //0-7 ASID
		u32 res  : 2;  //8,9 reserved
		u32 VPN  : 22; //10-31 VPN
	};
	u32 reg_data;
};

union CCN_PTEL_type
{
	struct
	{
		u32 WT    : 1;
		u32 SH    : 1;
		u32 D     : 1;
		u32 C     : 1;

		u32 SZ0   : 1;
		u32 PR    : 2;
		u32 SZ1   : 1;

		u32 V     : 1;
		u32 res_0 : 1;
		u32 PPN   : 19; //PPN 10-28
		u32 res_1 : 3;
	};
	u32 reg_data;
};

union CCN_MMUCR_type
{
	struct
	{
		u32 AT    : 1;
		u32 res   : 1;
		u32 TI    : 1;
		u32 res_2 : 5;
		u32 SV    : 1;
		u32 SQMD  : 1;
		u32 URC   : 6;
		u32 URB   : 6;
		u32 LRUI  : 6;
	};
	u32 reg_data;
};

union CCN_PTEA_type
{
	struct
	{
		u32 SA  : 3;
		u32 TC  : 1;
		u32 res : 28;
	};
	u32 reg_data;
};

union CCN_CCR_type
{
	struct
	{
		u32 OCE   : 1;
		u32 WT    : 1;
		u32 CB    : 1;
		u32 OCI   : 1;
		u32 res   : 1;
		u32 ORA   : 1;
		u32 res_1 : 1;
		u32 OIX   : 1;
		u32 ICE   : 1;
		u32 res_2 : 2;
		u32 ICI   : 1;
		u32 res_3 : 3;
		u32 IIX   : 1;
		u32 res_4 : 16;
	};
	u32 reg_data;
};

union CCN_QACR_type
{
	struct
	{
		u32 res   : 2;
		u32 Area  : 3;
		u32 res_1 : 27;
	};
	u32 reg_data;
};


//Types
#define CCN_PTEH SH4IO_REG_T(CCN,PTEH,32)
#define CCN_PTEL SH4IO_REG_T(CCN,PTEL,32)
#define CCN_TTB SH4IO_REG(CCN,TTB,32)
#define CCN_TEA SH4IO_REG(CCN,TEA,32)
#define CCN_MMUCR SH4IO_REG_T(CCN,MMUCR,32)
#define CCN_BASRA SH4IO_REG(CCN,BASRA,8)
#define CCN_BASRB SH4IO_REG(CCN,BASRB,8)
#define CCN_CCR SH4IO_REG_T(CCN,CCR,32)
#define CCN_TRA SH4IO_REG(CCN,TRA,32)
#define CCN_EXPEVT SH4IO_REG(CCN,EXPEVT,32)
#define CCN_INTEVT SH4IO_REG(CCN,INTEVT,32)
#define CCN_PTEA SH4IO_REG_T(CCN,PTEA,32)

#define CCN_QACR0 SH4IO_REG_T(CCN,QACR0,32)
#define CCN_QACR1 SH4IO_REG_T(CCN,QACR1,32)


#define CPG_FRQCR SH4IO_REG(CPG,FRQCR,16)
#define CPG_STBCR SH4IO_REG(CPG,STBCR,8)
#define CPG_WTCNT SH4IO_REG(CPG,WTCNT,16)
#define CPG_WTCSR SH4IO_REG(CPG,WTCSR,16)
#define CPG_STBCR2 SH4IO_REG(CPG,STBCR2,8)



union DMAC_CHCR_type
{
	struct
	{
		u32 DE    : 1; //Channel Enable
		u32 TE    : 1; //Transfer End
		u32 IE    : 1; //Interrupt Enable
		u32 res0  : 1;

		u32 TS    : 3; //Transmit Size
		//u32 TS1 :1;
		//u32 TS2 :1;
		u32 TM    : 1; //Transmit Mode

		u32 RS    : 4; //Resource Select
		//u32 RS1 :1;
		//u32 RS2 :1;
		//u32 RS3 :1;

		u32 SM    : 2; //SRC mode
		//u32 SM1 :1;
		u32 DM    : 2; //DST mode
		//u32 DM1 :1;

		u32 AL    : 1; //Acknowledge Level
		u32 AM    : 1; //Acknowledge Mode
		u32 RL    : 1; //In normal DMA mode, this bit is valid only in CHCR0 and CHCR1. In DDT mode, this bit is invalid.
		u32 DS    : 1; //In normal DMA mode, this bit is valid only in CHCR0 and CHCR1. In DDT mode, it is valid in CHCR0–CHCR3.

		u32 res1  : 4;

		u32 DTC   : 1;
		u32 DSA   : 3;
		//u32 DSA1:1;
		//u32 DSA2:1;

		u32 STC   : 1;
		u32 SSA   : 3;
		//u32 SSA1:1;
		//u32 SSA2:1;
	};
	u32 full;
};

union DMAC_DMAOR_type
{
	struct
	{
		u32 DME  : 1;
		u32 NMIF : 1;
		u32 AE   : 1;
		u32 res0 : 1;

		u32 COD  : 1;
		u32 res1 : 3;

		u32 PR0  : 1;
		u32 PR1  : 1;
		u32 res2 : 2;

		u32 res3 : 3;
		u32 DDT  : 1;

		u32 res4 : 16;
	};
	u32 full;
};

/*
extern u32 DMAC_SAR[4];
extern u32 DMAC_DAR[4];
extern u32 DMAC_DMATCR[4];//only 24 bits valid
extern DMAC_CHCR_type DMAC_CHCR[4];
*/

#define DMAC_SAR(x) SH4IO_REG_OFS(DMAC,SAR,x,0x10,32)
#define DMAC_DAR(x) SH4IO_REG_OFS(DMAC,DAR,x,0x10,32)
#define DMAC_DMATCR(x) SH4IO_REG_OFS(DMAC,DMATCR,x,0x10,32)
#define DMAC_CHCR(x) SH4IO_REG_T_OFS(DMAC,CHCR,x,0x10,32)

#define DMAC_DMAOR SH4IO_REG_T(DMAC,DMAOR,32)


//UBC BARA 0xFF200000 0x1F200000 32 Undefined Held Held Held Iclk
#define UBC_BARA SH4IO_REG(UBC,BARA,32)
//UBC BAMRA 0xFF200004 0x1F200004 8 Undefined Held Held Held Iclk
#define UBC_BAMRA SH4IO_REG(UBC,BAMRA,8)
//UBC BBRA 0xFF200008 0x1F200008 16 0x0000 Held Held Held Iclk
#define UBC_BBRA SH4IO_REG(UBC,BBRA,16)
//UBC BARB 0xFF20000C 0x1F20000C 32 Undefined Held Held Held Iclk
#define UBC_BARB SH4IO_REG(UBC,BARB,32)
//UBC BAMRB 0xFF200010 0x1F200010 8 Undefined Held Held Held Iclk
#define UBC_BAMRB SH4IO_REG(UBC,BAMRB,8)
//UBC BBRB 0xFF200014 0x1F200014 16 0x0000 Held Held Held Iclk
#define UBC_BBRB SH4IO_REG(UBC,BBRB,16)
//UBC BDRB 0xFF200018 0x1F200018 32 Undefined Held Held Held Iclk
#define UBC_BDRB SH4IO_REG(UBC,BDRB,32)
//UBC BDMRB 0xFF20001C 0x1F20001C 32 Undefined Held Held Held Iclk
#define UBC_BDMRB SH4IO_REG(UBC,BDMRB,32)
//UBC BRCR 0xFF200020 0x1F200020 16 0x0000 Held Held Held Iclk
#define UBC_BRCR SH4IO_REG(UBC,BRCR,16)

//TCNT exists only as cached state
//#define TMU_TCNT(x) SH4IO_REG_OFS(TMU,TCNT,x,12,32)

#define TMU_TCOR(x) SH4IO_REG_OFS(TMU,TCOR,x,12,32)
#define TMU_TCR(x) SH4IO_REG_OFS(TMU,TCR,x,12,16)

#define TMU_TOCR SH4IO_REG(TMU,TOCR,8)
#define TMU_TSTR SH4IO_REG(TMU,TSTR,8)



//SCIF SCSMR2 0xFFE80000 0x1FE80000 16 0x0000 0x0000 Held Held Pclk
union SCIF_SCSMR2_type
{
	struct
	{
		u32 CKS0          : 1;
		u32 CKS1          : 1;
		u32 res_0         : 1;
		u32 STOP          : 1;
		u32 OE_paritymode : 1;
		u32 PE            : 1;
		u32 CHR           : 1;
		u32 res_1         : 1;
		//8
		u32 res_2         : 1;
		u32 res_3         : 1;
		u32 res_4         : 1;
		u32 res_5         : 1;
		u32 res_6         : 1;
		u32 res_7         : 1;
		u32 res_8         : 1;
		u32 res_9         : 1;
		//16
	};
	u16 full;
};

#define SCIF_SCSMR2 SH4IO_REG_T(SCIF,SCSMR2,16)

//SCIF SCBRR2 0xFFE80004 0x1FE80004 8 0xFF 0xFF Held Held Pclk
#define SCIF_SCBRR2 SH4IO_REG(SCIF,SCBRR2,8)

//SCIF SCSCR2 0xFFE80008 0x1FE80008 16 0x0000 0x0000 Held Held Pclk
union SCIF_SCSCR2_type
{
	struct
	{
		u32 res_0 : 1;
		u32 CKE1  : 1;
		u32 res_1 : 1;
		u32 REIE  : 1;
		u32 RE    : 1;
		u32 TE    : 1;
		u32 RIE   : 1;
		u32 TIE   : 1;
		//8
		u32 res_2 : 1;
		u32 res_3 : 1;
		u32 res_4 : 1;
		u32 res_5 : 1;
		u32 res_6 : 1;
		u32 res_7 : 1;
		u32 res_8 : 1;
		u32 res_9 : 1;
		//16
	};
	u16 full;
};
#define SCIF_SCSCR2 SH4IO_REG_T(SCIF,SCSCR2,16)

//SCIF SCFTDR2 0xFFE8000C 0x1FE8000C 8 Undefined Undefined Held Held Pclk
#define SCIF_SCFTDR2 SH4IO_REG(SCIF,SCFTDR2,8)

//SCIF SCFSR2 0xFFE80010 0x1FE80010 16 0x0060 0x0060 Held Held Pclk
union SCIF_SCFSR2_type
{
	struct
	{
		u32 DR   : 1;
		u32 RDF  : 1;
		u32 PER  : 1;
		u32 FER  : 1;
		u32 BRK  : 1;
		u32 TDFE : 1;
		u32 TEND : 1;
		u32 ER   : 1;
		//8
		u32 FER0 : 1;
		u32 FER1 : 1;
		u32 FER2 : 1;
		u32 FER3 : 1;
		u32 PER0 : 1;
		u32 PER1 : 1;
		u32 PER2 : 1;
		u32 PER3 : 1;
		//16
	};
	u16 full;
};
extern SCIF_SCFSR2_type SCIF_SCFSR2;

//SCIF SCFRDR2 0xFFE80014 0x1FE80014 8 Undefined Undefined Held Held Pclk
//Read OLNY
extern u8 SCIF_SCFRDR2;

//SCIF SCFCR2 0xFFE80018 0x1FE80018 16 0x0000 0x0000 Held Held Pclk
union SCIF_SCFCR2_type
{
	struct
	{
		u32 LOOP  : 1;
		u32 RFRST : 1;
		u32 TFRST : 1;
		u32 MCE   : 1;
		u32 TTRG0 : 1;
		u32 TTRG1 : 1;
		u32 RTRG0 : 1;
		u32 RTRG1 : 1;
		//8
		u32 res_0 : 1;
		u32 res_1 : 1;
		u32 res_2 : 1;
		u32 res_3 : 1;
		u32 res_4 : 1;
		u32 res_5 : 1;
		u32 res_6 : 1;
		u32 res_7 : 1;
		//16
	};
	u16 full;
};
#define SCIF_SCFCR2 SH4IO_REG_T(SCIF,SCFCR2,16)

//Read OLNY
//SCIF SCFDR2 0xFFE8001C 0x1FE8001C 16 0x0000 0x0000 Held Held Pclk
union SCIF_SCFDR2_type
{
	struct
	{
		u32 R     : 5;
		u32 res_0 : 3;
		//8
		u32 T     : 5;
		u32 res_1 : 3;
		//16
	};
	u16 full;
};
extern SCIF_SCFDR2_type SCIF_SCFDR2;

//SCIF SCSPTR2 0xFFE80020 0x1FE80020 16 0x0000 0x0000 Held Held Pclk
union SCIF_SCSPTR2_type
{
	struct
	{
		u32 SPB2DT : 1;
		u32 SPB2IO : 1;
		u32 res_0  : 1;
		u32 res_1  : 1;
		u32 CTSDT  : 1;
		u32 CTSIO  : 1;
		u32 RTSDT  : 1;
		u32 RTSIO  : 1;
		//8
		u32 res_2  : 1;
		u32 res_3  : 1;
		u32 res_4  : 1;
		u32 res_5  : 1;
		u32 res_6  : 1;
		u32 res_7  : 1;
		u32 res_8  : 1;
		u32 res_9  : 1;
		//16
	};
	u16 full;
};
#define SCIF_SCSPTR2 SH4IO_REG_T(SCIF,SCSPTR2,16)

//SCIF SCLSR2 0xFFE80024 0x1FE80024 16 0x0000 0x0000 Held Held Pclk
union SCIF_SCLSR2_type
{
	struct
	{
		u32 ORER  : 1;
		u32 res_0 : 7;
		//8
		u32 res_1 : 8;
		//16
	};
	u16 full;
};
#define SCIF_SCLSR2 SH4IO_REG_T(SCIF,SCLSR2,16)


#define RTC_R64CNT SH4IO_REG(RTC,R64CNT,8)
#define RTC_RSECCNT SH4IO_REG(RTC,RSECCNT,8)
#define RTC_RMINCNT SH4IO_REG(RTC,RMINCNT,8)
#define RTC_RHRCNT SH4IO_REG(RTC,RHRCNT,8)
#define RTC_RWKCNT SH4IO_REG(RTC,RWKCNT,8)
#define RTC_RDAYCNT SH4IO_REG(RTC,RDAYCNT,8)
#define RTC_RMONCNT SH4IO_REG(RTC,RMONCNT,8)
#define RTC_RYRCNT SH4IO_REG(RTC,RYRCNT,16)

#define RTC_RSECAR SH4IO_REG(RTC,RSECAR,8)
#define RTC_RMINAR SH4IO_REG(RTC,RMINAR,8)
#define RTC_RHRAR SH4IO_REG(RTC,RHRAR,8)
#define RTC_RWKAR SH4IO_REG(RTC,RWKAR,8)
#define RTC_RDAYAR SH4IO_REG(RTC,RDAYAR,8)
#define RTC_RMONAR SH4IO_REG(RTC,RMONAR,8)
#define RTC_RCR1 SH4IO_REG(RTC,RCR1,8)
#define RTC_RCR2 SH4IO_REG(RTC,RCR2,8)



union INTC_ICR_type
{
	u16 reg_data;
	struct
	{
		u32 res   : 7;
		u32 IRLM  : 1;
		u32 NMIE  : 1;
		u32 NMIB  : 1;
		u32 res_2 : 4;
		u32 MAI   : 1;
		u32 NMIL  : 1;
	};
};

union INTC_IPRA_type
{
	u16 reg_data;
	struct
	{
		u32 RTC  : 4;
		u32 TMU2 : 4;
		u32 TMU1 : 4;
		u32 TMU0 : 4;
	};
};

union INTC_IPRB_type
{
	u16 reg_data;
	struct
	{
		u32 Reserved : 4;
		u32 SCI1     : 4;
		u32 REF      : 4;
		u32 WDT      : 4;
	};
};

union INTC_IPRC_type
{
	u16 reg_data;
	struct
	{
		u32 Hitachi_UDI : 4;
		u32 SCIF        : 4;
		u32 DMAC        : 4;
		u32 GPIO        : 4;
	};
};

#define INTC_ICR SH4IO_REG_T(INTC,ICR,16)

#define INTC_IPRA SH4IO_REG_T(INTC,IPRA,16)
#define INTC_IPRB SH4IO_REG_T(INTC,IPRB,16)
#define INTC_IPRC SH4IO_REG_T(INTC,IPRC,16)
