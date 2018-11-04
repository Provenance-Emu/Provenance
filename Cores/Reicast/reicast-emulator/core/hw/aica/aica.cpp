#include "aica.h"
#include "sgc_if.h"
#include "aica_mem.h"
#include <math.h>
#include "hw/holly/holly_intc.h"
#include "hw/holly/sb.h"

#define SH4_IRQ_BIT (1<<(holly_SPU_IRQ&255))

CommonData_struct* CommonData;
DSPData_struct* DSPData;
InterruptInfo* MCIEB;
InterruptInfo* MCIPD;
InterruptInfo* MCIRE;
InterruptInfo* SCIEB;
InterruptInfo* SCIPD;
InterruptInfo* SCIRE;

//Interrupts
//arm side
u32 GetL(u32 witch)
{
	if (witch>7)
		witch=7; //higher bits share bit 7

	u32 bit=1<<witch;
	u32 rv=0;

	if (CommonData->SCILV0 & bit)
		rv=1;

	if (CommonData->SCILV1 & bit)
		rv|=2;
	
	if (CommonData->SCILV2 & bit)
		rv|=4;

	return rv;
}
void update_arm_interrupts()
{
	u32 p_ints=SCIEB->full & SCIPD->full;

	u32 Lval=0;
	if (p_ints)
	{
		u32 bit_value=1;//first bit
		//scan all interrupts , lo to hi bit.I assume low bit ints have higher priority over others
		for (u32 i=0;i<11;i++)
		{
			if (p_ints & bit_value)
			{
				//for the first one , Set the L reg & exit
				Lval=GetL(i);
				break;
			}
			bit_value<<=1; //next bit
		}
	}

	libARM_InterruptChange(p_ints,Lval);
}

//sh4 side
void UpdateSh4Ints()
{
	u32 p_ints = MCIEB->full & MCIPD->full;
	if (p_ints)
	{
		if ((SB_ISTEXT & SH4_IRQ_BIT )==0)
		{
			//if no interrupt is already pending then raise one :)
			asic_RaiseInterrupt(holly_SPU_IRQ);
		}
	}
	else
	{
		if (SB_ISTEXT&SH4_IRQ_BIT)
		{
			asic_CancelInterrupt(holly_SPU_IRQ);
		}
	}

}

////
//Timers :)
struct AicaTimerData
{
	union
	{
		struct 
		{
			u32 count:8;
			u32 md:3;
			u32 nil:5;
			u32 pad:16;
		};
		u32 data;
	};
};
class AicaTimer
{
public:
	AicaTimerData* data;
	s32 c_step;
	u32 m_step;
	u32 id;
	void Init(u8* regbase,u32 timer)
	{
		data=(AicaTimerData*)&regbase[0x2890 + timer*4];
		id=timer;
		m_step=1<<(data->md);
		c_step=m_step;
	}
	void StepTimer(u32 samples)
	{
		do
		{
			c_step--;
			if (c_step==0)
			{
				c_step=m_step;
				data->count++;
				if (data->count==0)
				{
					if (id==0)
					{
						SCIPD->TimerA=1;
						MCIPD->TimerA=1;
					}
					else if (id==1)
					{
						SCIPD->TimerB=1;
						MCIPD->TimerB=1;
					}
					else
					{
						SCIPD->TimerC=1;
						MCIPD->TimerC=1;
					}
				}
			}
		} while(--samples);
	}

	void RegisterWrite()
	{
		u32 n_step=1<<(data->md);
		if (n_step!=m_step)
		{
			m_step=n_step;
			c_step=m_step;
		}
	}
};

AicaTimer timers[3];
//Mainloop
void libAICA_Update(u32 Samples)
{
	AICA_Sample32();
}

void libAICA_TimeStep()
{
	for (int i=0;i<3;i++)
		timers[i].StepTimer(1);

	SCIPD->SAMPLE_DONE=1;

	if (settings.aica.NoBatch)
		AICA_Sample();

	//Make sure sh4/arm interrupt system is up to date :)
	update_arm_interrupts();
	UpdateSh4Ints();	
}

//Memory i/o
template<u32 sz>
void WriteAicaReg(u32 reg,u32 data)
{
	switch (reg)
	{
	case SCIPD_addr:
		verify(sz!=1);
		if (data & (1<<5))
		{
			SCIPD->SCPU=1;
			update_arm_interrupts();
		}
		//Read only
		return;

	case SCIRE_addr:
		{
			verify(sz!=1);
			SCIPD->full&=~(data /*& SCIEB->full*/ );	//is the & SCIEB->full needed ? doesn't seem like it
			data=0;//Write only
			update_arm_interrupts();
		}
		break;

	case MCIPD_addr:
		if (data & (1<<5))
		{
			verify(sz!=1);
			MCIPD->SCPU=1;
			UpdateSh4Ints();
		}
		//Read only
		return;

	case MCIRE_addr:
		{
			verify(sz!=1);
			MCIPD->full&=~data;
			UpdateSh4Ints();
			//Write only
		}
		break;

	case TIMER_A:
		WriteMemArr(aica_reg,reg,data,sz);
		timers[0].RegisterWrite();
		break;

	case TIMER_B:
		WriteMemArr(aica_reg,reg,data,sz);
		timers[1].RegisterWrite();
		break;

	case TIMER_C:
		WriteMemArr(aica_reg,reg,data,sz);
		timers[2].RegisterWrite();
		break;

	default:
		WriteMemArr(aica_reg,reg,data,sz);
		break;
	}
}



template void WriteAicaReg<1>(u32 reg,u32 data);
template void WriteAicaReg<2>(u32 reg,u32 data);

//misc :p
s32 libAICA_Init()
{
	init_mem();

	verify(sizeof(*CommonData)==0x508);
	verify(sizeof(*DSPData)==0x15C8);

	CommonData=(CommonData_struct*)&aica_reg[0x2800];
	DSPData=(DSPData_struct*)&aica_reg[0x3000];
	//slave cpu (arm7)

	SCIEB=(InterruptInfo*)&aica_reg[0x289C];
	SCIPD=(InterruptInfo*)&aica_reg[0x289C+4];
	SCIRE=(InterruptInfo*)&aica_reg[0x289C+8];
	//Main cpu (sh4)
	MCIEB=(InterruptInfo*)&aica_reg[0x28B4];
	MCIPD=(InterruptInfo*)&aica_reg[0x28B4+4];
	MCIRE=(InterruptInfo*)&aica_reg[0x28B4+8];

	sgc_Init();
	for (int i=0;i<3;i++)
		timers[i].Init(aica_reg,i);

	return rv_ok;
}

void libAICA_Reset(bool m)
{
}

void libAICA_Term()
{
	sgc_Term();
}
