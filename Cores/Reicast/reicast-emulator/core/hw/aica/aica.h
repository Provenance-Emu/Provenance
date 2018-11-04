#pragma once
#include "types.h"
#include "oslib/oslib.h"
#include "assert.h"

#define SCIEB_addr 0x289C
#define SCIPD_addr (0x289C+4)
#define SCIRE_addr (0x289C+8)

#define MCIEB_addr 0x28B4
#define MCIPD_addr (0x28B4+4)
#define MCIRE_addr (0x28B4+8)

#define TIMER_A 0x2890 
#define TIMER_B (0x2890+4) 
#define TIMER_C (0x2890+8)
#define REG_L (0x2D00)
#define REG_M (0x2D04)
#define entry(name,sz) u32 name:sz;
struct CommonData_struct
{
	//+0
	entry(MVOL,4);
	entry(VER,4);
	entry(DAC18B,1);
	entry(MEM8MB,1);
	entry(pad0_0,5);
	entry(Mono,1);
	
	u32 :16;
	//+4
	entry(RBP,12);
	entry(pad1_0,1);
	entry(RBL,2);
	entry(TESTB0,1);

	u32 :16;
	//+8
	entry(MIBUF,8);
	entry(MIEMP,1);
	entry(MIFUL ,1);
	entry(MIOVF ,1);
	entry(MOEMP ,1);
	entry(MOFUL ,1);
	entry(pad3_0,3);

	u32 :16;
	//+C
	entry(MOBUF,8);
	entry(MSLC,6);
	entry(AFSET,1);
	entry(padC_0,1);

	u32 :16;
	//+10
	entry(EG,13);
	entry(SGC,2);
	entry(LP,1);
	
	u32 :16;
	//+14
	entry(CA,16);

	u32 :16;
	
	//quite a bit padding here :)
	u8 pad_med_0[0x6C-4];

	//+80
	entry(MRWINH,4);
	entry($T,1);
	entry($TSCD,3);
	entry(pad80_0,1);
	entry(DMEA_hi,7);

	u32 :16;
	//+84
	entry(pad84_0,2);
	entry(DMEA_lo,14);

	u32 :16;
	//+88
	entry(pad88_0,2);
	entry(DRGA,13);
	entry(DGATE,1);

	u32 :16;
	//+8C
	entry(DEXE,1);
	entry(pad8C_0,1);
	entry(DLG,13);
	entry(DDIR,1);

	u32 :16;
	//+90
	entry(TIMA,8);
	entry(TACTL,3);
	entry(pad90_0,5);

	u32 :16;
	//+94
	entry(TIMB,8);
	entry(TBCTL,3);
	entry(pad94_0,5);

	u32 :16;
	//+98
	entry(TIMC,8);
	entry(TCCTL,3);
	entry(pad98_0,5);

	u32 :16;

	//+9C
	entry(SCIEB,11);
	entry(pad9C_0,5);

	u32 :16;

	//+A0
	entry(SCIPD,11);
	entry(padA0_0,5);

	u32 :16;

	//+A4
	entry(SCIRE,11);
	entry(padA4_0,5);

	u32 :16;

	//+A8
	entry(SCILV0,8);
	entry(padA8_0,8);

	u32 :16;

	//+AC
	entry(SCILV1,8);
	entry(padAC_0,8);

	u32 :16;

	//+B0
	entry(SCILV2,8);
	entry(padB0_0,8);

	u32 :16;

	//+B4
	entry(MCIEB,11);
	entry(padB4_0,5)

	u32 :16;

	//+B8
	entry(MCIPD,11);
	entry(padB8_0,5)

	u32 :16;

	//+BC
	entry(MCIRE,11);
	entry(padBC_0,5)

	u32 :16;
	
	//some other misc shit FAR away is here :p
	u8 pad_lot_0[0x344-4];

	//+400 , hopefully :p
	entry(AR,1);
	entry(pad400_0,7);
	entry(VREG,2);
	entry(pad400_1,6);

	u32 :16;

	//Even more
	u8 pad_lot_1[0x100-4];

	//+500 , hopefully :p
	entry(L0_r,1);
	entry(L1_r,1);
	entry(L2_r,1);
	entry(L3_r,1);
	entry(L4_r,1);
	entry(L5_r,1);
	entry(L6_r,1);
	entry(L7_r,1);
	
	entry(pad500_0,8);

	u32 :16;

	//+504

	entry(M0_r,1);
	entry(M1_r,1);
	entry(M2_r,1);
	entry(M3_r,1);
	entry(M4_r,1);
	entry(M5_r,1);
	entry(M6_r,1);
	entry(M7_r,1);
	entry(RP,1);
	
	entry(pad504_0,7);

	u32 :16;
};

//should be 0x15C8 in size
struct DSPData_struct
{
	//+0x000
	u32 COEF[128];		//15:3

	//+0x200
	u32 MADRS[64];		//15:0
	
	//+0x300
	u8 PAD0[0x100];

	//+0x400
	u32 MPRO[128*4];	//15:0
	
	//+0xC00
	u8 PAD1[0x400];

	//+0x1000
	struct 
	{ 
		u32 l;			//7:0
		u32 h;			//15:0 (23:8)
	} 
	TEMP[128];

	//+0x1400
	struct 
	{ 
		u32 l;			//7:0
		u32 h;			//15:0 (23:8)
	} 
	MEMS[32];
	
	//+0x1500
	struct 
	{ 
		u32 l;			//3:0
		u32 h;			//15:0 (19:4)
	} 
	MIXS[16];

	//+0x1580
	u32 EFREG[16];		//15:0
	
	//+0x15C0
	u32 EXTS[2];		//15:0
};
union InterruptInfo
{
	struct
	{
		//Bit 0 (R): Requests interrupt to external interrupt input pin "INTON". (SCSI) 
		entry(INTON,1);
		//Bit 1 (R): Reserved. 
		entry(res_1,1);
		//Bit 2 (R): Reserved. 
		entry(res_3,1);
		//Bit 3 (R): MIDI input interrupt. 
		//(Interrupt request generated when input FIFO has fetched valid data. Hence, if the CPU reads FIFO data, it must read the lot once and leave the FIFO empty. When the FIFO has changed to empty status, the interrupt request is canceled automatically.) 
		entry(MIDI_IN,1);
		//Bit 4 (R): DMA end interrupt 
		entry(DMA_END,1);
		//Bit 5 (R/W): SCPU interrupt caused by data being written to the CPU, so only "1" can be written. (Writing "0" has no effect.) This flag can be set from either the MCPU or the SCPU. 
		entry(SCPU,1);
		//Bit 6 (R): Timer A interrupt 
		entry(TimerA,1);
		//Bit 7 (R): Timer B interrupt 
		entry(TimerB,1);
		//Bit 8 (R): Timer C interrupt 
		entry(TimerC,1);
		//Bit 9 (R): MIDI output interrupt. 
		//(If the output FIFO changes to empty status, an interrupt request is generated.)
		//(If the status is no longer empty because data is written to the output FIFO, the interrupt request is canceled automatically.) 
		entry(MIDI_OUT,1);
		//Bit 10 (R): Interrupt of one sample interval 
		entry(SAMPLE_DONE,1);
	};
	u32 full;
};
extern InterruptInfo* MCIEB;
extern InterruptInfo* MCIPD;
extern InterruptInfo* MCIRE;
extern InterruptInfo* SCIEB;
extern InterruptInfo* SCIPD;
extern InterruptInfo* SCIRE;

#undef entry

extern CommonData_struct* CommonData;
extern DSPData_struct*	  DSPData;

void UpdateAICA(u32 Cycles);

void AICA_Init();
void AICA_Term();

//u32 ReadAicaReg(u32 reg);
void WriteAicaReg8(u32 reg,u32 data);

template<u32 sz>
void WriteAicaReg(u32 reg,u32 data);