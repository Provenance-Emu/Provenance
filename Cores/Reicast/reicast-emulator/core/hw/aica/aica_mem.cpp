#include "aica_mem.h"
#include "dsp.h"
#include "sgc_if.h"
#include "hw/aica/aica_if.h"

u8 aica_reg[0x8000];

//00000000~007FFFFF @DRAM_AREA* 
//00800000~008027FF @CHANNEL_DATA 
//00802800~00802FFF @COMMON_DATA 
//00803000~00807FFF @DSP_DATA 
template<u32 sz>
u32 ReadReg(u32 addr)
{
	if (addr<0x2800)
	{
		ReadMemArrRet(aica_reg,addr,sz);
	}
	if (addr < 0x2818)
	{
		if (sz==1)
		{
			ReadCommonReg(addr,true);
			ReadMemArrRet(aica_reg,addr,1);
		}
		else
		{
			ReadCommonReg(addr,false);
			//ReadCommonReg8(addr+1);
			ReadMemArrRet(aica_reg,addr,2);
		}
	}

	ReadMemArrRet(aica_reg,addr,sz);
}
template<u32 sz>
void WriteReg(u32 addr,u32 data)
{
	if (addr < 0x2000)
	{
		//Channel data
		u32 chan=addr>>7;
		u32 reg=addr&0x7F;
		if (sz==1)
		{
			WriteMemArr(aica_reg,addr,data,1);
			WriteChannelReg8(chan,reg);
		}
		else
		{
			WriteMemArr(aica_reg,addr,data,2);
			WriteChannelReg8(chan,reg);
			WriteChannelReg8(chan,reg+1);
		}
		return;
	}

	if (addr<0x2800)
	{
		if (sz==1)
		{
			WriteMemArr(aica_reg,addr,data,1);
		}
		else 
		{
			WriteMemArr(aica_reg,addr,data,2);
		}
		return;
	}

	if (addr < 0x2818)
	{
		if (sz==1)
		{
			WriteCommonReg8(addr,data);
		}
		else
		{
			WriteCommonReg8(addr,data&0xFF);
			WriteCommonReg8(addr+1,data>>8);
		}
		return;
	}

	if (addr>=0x3000)
	{
		if (sz==1)
		{
			WriteMemArr(aica_reg,addr,data,1);
			dsp_writenmem(addr);
		}
		else
		{
			WriteMemArr(aica_reg,addr,data,2);
			dsp_writenmem(addr);
			dsp_writenmem(addr+1);
		}
	}
	if (sz==1)
		WriteAicaReg<1>(addr,data);
	else
		WriteAicaReg<2>(addr,data);
}
//Aica reads (both sh4&arm)
u32 libAICA_ReadReg(u32 addr,u32 size)
{
	if (size==1)
		return ReadReg<1>(addr & 0x7FFF);
	else
		return ReadReg<2>(addr & 0x7FFF);

	//must never come here
	return 0;
}

void libAICA_WriteReg(u32 addr,u32 data,u32 size)
{
	if (size==1)
		WriteReg<1>(addr & 0x7FFF,data);
	else
		WriteReg<2>(addr & 0x7FFF,data);
}

//Map using _vmem .. yay
void init_mem()
{
	memset(aica_reg,0,sizeof(aica_reg));
	aica_ram.data[ARAM_SIZE-1]=1;
	aica_ram.Zero();
}
//kill mem map & free used mem ;)
void term_mem()
{

}

