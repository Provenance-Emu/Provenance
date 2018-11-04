/*
	Interrupt list caching and handling

	SH4 has a very flexible interrupt controller. In order to handle it efficiently, a sorted
	interrupt bitfield is build from the set interrupt priorities. Higher priorities get allocated
	into higher bits, and a simple mask is kept. In order to check for pending interrupts a simple
	!=0 test works, and to identify the pending interrupt bsr(pend) will give the sorted id. As
	this is a single cycle operation on most platforms, the interrupt checking/identification
	is very fast !
*/

#include "types.h"
#include "sh4_interrupts.h"
#include "sh4_core.h"
#include "sh4_mmr.h"
#include "oslib/oslib.h"

/*

*/

//these are fixed
u16 IRLPriority=0x0246;
#define IRLP9 &IRLPriority,0
#define IRLP11 &IRLPriority,4
#define IRLP13 &IRLPriority,8

#define GIPA(p) &INTC_IPRA.reg_data,4*p
#define GIPB(p) &INTC_IPRB.reg_data,4*p
#define GIPC(p) &INTC_IPRC.reg_data,4*p

struct InterptSourceList_Entry
{
	u16* PrioReg;
	u32 Shift;
	u32 IntEvnCode;

	u32 GetPrLvl() const { return ((*PrioReg)>>Shift)&0xF; }
};

//Can't be statically initialised because registers are dynamically allocated
InterptSourceList_Entry InterruptSourceList[28];

//Maps siid -> EventID
DECL_ALIGN(64) u16 InterruptEnvId[32] = { 0 };
//Maps piid -> 1<<siid
DECL_ALIGN(64) u32 InterruptBit[32] = { 0 };
//Maps sh4 interrupt level to inclusive bitfield
DECL_ALIGN(64) u32 InterruptLevelBit[16] = { 0 };

bool Do_Interrupt(u32 intEvn);
bool Do_Exception(u32 epc, u32 expEvn, u32 CallVect);

u32 interrupt_vpend; // Vector of pending interrupts
u32 interrupt_vmask; // Vector of masked interrupts             (-1 inhibits all interrupts)
u32 decoded_srimask; // Vector of interrupts allowed by SR.IMSK (-1 inhibits all interrupts)

//bit 0 ~ 27 : interrupt source 27:0. 0 = lowest level, 27 = highest level.
void recalc_pending_itrs()
{
	Sh4cntx.interrupt_pend=interrupt_vpend&interrupt_vmask&decoded_srimask;
}

//Rebuild sorted interrupt id table (priorities were updated)
void SIIDRebuild()
{
	u32 cnt=0;
	u32 vpend=interrupt_vpend;
	u32 vmask=interrupt_vmask;
	interrupt_vpend=0;
	interrupt_vmask=0x00000000;
	//rebuild interrupt table
	for (u32 ilevel=0;ilevel<16;ilevel++)
	{
		for (u32 isrc=0;isrc<28;isrc++)
		{
			if (InterruptSourceList[isrc].GetPrLvl()==ilevel)
			{
				InterruptEnvId[cnt]=InterruptSourceList[isrc].IntEvnCode;
				u32 p=InterruptBit[isrc]&vpend;
				u32 m=InterruptBit[isrc]&vmask;
				InterruptBit[isrc]=1<<cnt;
				if (p)
					interrupt_vpend|=InterruptBit[isrc];
				if (m)
					interrupt_vmask|=InterruptBit[isrc];
				cnt++;
			}
		}
		InterruptLevelBit[ilevel]=(1<<cnt)-1;
	}

	SRdecode();
}

//Decode SR.IMSK into a interrupt mask, update and return the interrupt state
bool SRdecode()
{
	if (sr.BL)
		decoded_srimask=~0xFFFFFFFF;
	else
		decoded_srimask=~InterruptLevelBit[sr.IMASK];

	recalc_pending_itrs();
	return Sh4cntx.interrupt_pend;
}



int UpdateINTC()
{
	if (!Sh4cntx.interrupt_pend)
		return 0;

	return Do_Interrupt(InterruptEnvId[bitscanrev(Sh4cntx.interrupt_pend)]);
}

void SetInterruptPend(InterruptID intr)
{
	u32 piid= intr & InterruptPIIDMask;
	interrupt_vpend|=InterruptBit[piid];
	recalc_pending_itrs();
}
void ResetInterruptPend(InterruptID intr)
{
	u32 piid= intr & InterruptPIIDMask;
	interrupt_vpend&=~InterruptBit[piid];
	recalc_pending_itrs();
}

void SetInterruptMask(InterruptID intr)
{
	u32 piid= intr & InterruptPIIDMask;
	interrupt_vmask|=InterruptBit[piid];
	recalc_pending_itrs();
}
void ResetInterruptMask(InterruptID intr)
{
	u32 piid= intr & InterruptPIIDMask;
	interrupt_vmask&=~InterruptBit[piid];
	recalc_pending_itrs();
}


bool Do_Interrupt(u32 intEvn)
{
	CCN_INTEVT = intEvn;

	ssr = sr.GetFull();
	spc = next_pc;
	sgr = r[15];
	sr.BL = 1;
	sr.MD = 1;
	sr.RB = 1;
	UpdateSR();
	next_pc = vbr + 0x600;

	return true;
}

bool Do_Exception(u32 epc, u32 expEvn, u32 CallVect)
{
	verify(sr.BL == 0);
	CCN_EXPEVT = expEvn;

	ssr = sr.GetFull();
	spc = epc;
	sgr = r[15];
	sr.BL = 1;
	sr.MD = 1;
	sr.RB = 1;
	UpdateSR();

	next_pc = vbr + CallVect;

	//printf("RaiseException: from %08X , pc errh %08X, %08X vect\n", spc, epc, next_pc);
	return true;
}


//Init/Res/Term
void interrupts_init()
{
	InterptSourceList_Entry InterruptSourceList2[]=
	{
		//IRL
		{IRLP9,0x320},//sh4_IRL_9           = KMIID(sh4_int,0x320,0),
		{IRLP11,0x360},//sh4_IRL_11         = KMIID(sh4_int,0x360,1),
		{IRLP13,0x3A0},//sh4_IRL_13         = KMIID(sh4_int,0x3A0,2),

		//HUDI
		{GIPC(0),0x600},//sh4_HUDI_HUDI     = KMIID(sh4_int,0x600,3),  /* H-UDI underflow */

		//GPIO (missing on dc ?)
		{GIPC(3),0x620},//sh4_GPIO_GPIOI    = KMIID(sh4_int,0x620,4),

		//DMAC
		{GIPC(2),0x640},//sh4_DMAC_DMTE0    = KMIID(sh4_int,0x640,5),
		{GIPC(2),0x660},//sh4_DMAC_DMTE1    = KMIID(sh4_int,0x660,6),
		{GIPC(2),0x680},//sh4_DMAC_DMTE2    = KMIID(sh4_int,0x680,7),
		{GIPC(2),0x6A0},//sh4_DMAC_DMTE3    = KMIID(sh4_int,0x6A0,8),
		{GIPC(2),0x6C0},//sh4_DMAC_DMAE     = KMIID(sh4_int,0x6C0,9),

		//TMU
		{GIPA(3),0x400},//sh4_TMU0_TUNI0    =  KMIID(sh4_int,0x400,10), /* TMU0 underflow */
		{GIPA(2),0x420},//sh4_TMU1_TUNI1    =  KMIID(sh4_int,0x420,11), /* TMU1 underflow */
		{GIPA(1),0x440},//sh4_TMU2_TUNI2    =  KMIID(sh4_int,0x440,12), /* TMU2 underflow */
		{GIPA(1),0x460},//sh4_TMU2_TICPI2   =  KMIID(sh4_int,0x460,13),

		//RTC
		{GIPA(0),0x480},//sh4_RTC_ATI       = KMIID(sh4_int,0x480,14),
		{GIPA(0),0x4A0},//sh4_RTC_PRI       = KMIID(sh4_int,0x4A0,15),
		{GIPA(0),0x4C0},//sh4_RTC_CUI       = KMIID(sh4_int,0x4C0,16),

		//SCI
		{GIPB(1),0x4E0},//sh4_SCI1_ERI      = KMIID(sh4_int,0x4E0,17),
		{GIPB(1),0x500},//sh4_SCI1_RXI      = KMIID(sh4_int,0x500,18),
		{GIPB(1),0x520},//sh4_SCI1_TXI      = KMIID(sh4_int,0x520,19),
		{GIPB(1),0x540},//sh4_SCI1_TEI      = KMIID(sh4_int,0x540,29),

		//SCIF
		{GIPC(1),0x700},//sh4_SCIF_ERI      = KMIID(sh4_int,0x700,21),
		{GIPC(1),0x720},//sh4_SCIF_RXI      = KMIID(sh4_int,0x720,22),
		{GIPC(1),0x740},//sh4_SCIF_BRI      = KMIID(sh4_int,0x740,23),
		{GIPC(1),0x760},//sh4_SCIF_TXI      = KMIID(sh4_int,0x760,24),

		//WDT
		{GIPB(3),0x560},//sh4_WDT_ITI       = KMIID(sh4_int,0x560,25),

		//REF
		{GIPB(2),0x580},//sh4_REF_RCMI      = KMIID(sh4_int,0x580,26),
		{GIPA(2),0x5A0},//sh4_REF_ROVI      = KMIID(sh4_int,0x5A0,27),
	};

	verify(sizeof(InterruptSourceList)==sizeof(InterruptSourceList2));

	memcpy(InterruptSourceList,InterruptSourceList2,sizeof(InterruptSourceList));
}

void interrupts_reset()
{
	//reset interrupts cache
	interrupt_vpend=0x00000000;
	interrupt_vmask=0xFFFFFFFF;
	decoded_srimask=0;

	for (u32 i=0;i<28;i++)
		InterruptBit[i]=1<<i;

	//rebuild the interrupts table
	SIIDRebuild();
}

void interrupts_term()
{

}

