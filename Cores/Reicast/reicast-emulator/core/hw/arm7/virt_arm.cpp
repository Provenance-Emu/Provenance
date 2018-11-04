#include "virt_arm.h"

#if HOST_CPU==CPU_X86 && FEAT_AREC != DYNAREC_NONE

#define C_CORE

namespace VARM
{
	//#define CPUReadHalfWordQuick(addr) arm_ReadMem16(addr & 0x7FFFFF)
//#define CPUReadMemoryQuick(addr) (*(u32*)(addr))
#define CPUReadByte(addr) (*(u8*)(addr))
#define CPUReadMemory(addr) (*(u32*)(addr))
#define CPUReadHalfWord(addr) (*(u16*)(addr))
#define CPUReadHalfWordSigned(addr) (*(s16*)(addr))

#define CPUWriteMemory(addr,data) (*(u32*)addr=data)
#define CPUWriteHalfWord(addr,data) (*(u16*)addr=data)
#define CPUWriteByte(addr,data) (*(u8*)addr=data)


#define reg arm_Reg
#define armNextPC arm_ArmNextPC


#define CPUUpdateTicksAccesint(a) 1
#define CPUUpdateTicksAccessSeq32(a) 1
#define CPUUpdateTicksAccesshort(a) 1
#define CPUUpdateTicksAccess32(a) 1
#define CPUUpdateTicksAccess16(a) 1



	typedef union
	{
		struct
		{
			u8 B0;
			u8 B1;
			u8 B2;
			u8 B3;
		} B;

		struct
		{
			u16 W0;
			u16 W1;
		} W;

		u32 I;
	} reg_pair;

	u32 arm_ArmNextPC;

	reg_pair arm_Reg[45];

	void CPUSwap(u32 *a, u32 *b)
	{
		u32 c = *b;
		*b = *a;
		*a = c;
	}


	bool N_FLAG;
	bool Z_FLAG;
	bool C_FLAG;
	bool V_FLAG;
	bool armIrqEnable;
	bool armFiqEnable;

	int armMode;

	u8 cpuBitsSet[256];

	void CPUSwitchMode(int mode, bool saveState, bool breakLoop=true);
	void CPUFiq();
	void CPUUpdateCPSR();
	void CPUUpdateFlags();
	void CPUSoftwareInterrupt(int comment);
	void CPUUndefinedException();


	void CPUInterrupt();

	u32 virt_arm_op(u32 opcode)
	{
		u32 clockTicks=0;

		armNextPC=reg[15].I=0;

#include "arm-new.h"

		verify(reg[15].I==0);
		verify(arm_ArmNextPC==0);

		return clockTicks;
	}
	
	void CPUSwitchMode(int mode, bool saveState, bool breakLoop)
	{
		verify(mode==0x10);
		/*
		CPUUpdateCPSR();

		switch(armMode) {
		case 0x10:
		case 0x1F:
		reg[R13_USR].I = reg[13].I;
		reg[R14_USR].I = reg[14].I;
		reg[17].I = reg[16].I;
		break;
		case 0x11:
		CPUSwap(&reg[R8_FIQ].I, &reg[8].I);
		CPUSwap(&reg[R9_FIQ].I, &reg[9].I);
		CPUSwap(&reg[R10_FIQ].I, &reg[10].I);
		CPUSwap(&reg[R11_FIQ].I, &reg[11].I);
		CPUSwap(&reg[R12_FIQ].I, &reg[12].I);
		reg[R13_FIQ].I = reg[13].I;
		reg[R14_FIQ].I = reg[14].I;
		reg[SPSR_FIQ].I = reg[17].I;
		break;
		case 0x12:
		reg[R13_IRQ].I  = reg[13].I;
		reg[R14_IRQ].I  = reg[14].I;
		reg[SPSR_IRQ].I =  reg[17].I;
		break;
		case 0x13:
		reg[R13_SVC].I  = reg[13].I;
		reg[R14_SVC].I  = reg[14].I;
		reg[SPSR_SVC].I =  reg[17].I;
		break;
		case 0x17:
		reg[R13_ABT].I  = reg[13].I;
		reg[R14_ABT].I  = reg[14].I;
		reg[SPSR_ABT].I =  reg[17].I;
		break;
		case 0x1b:
		reg[R13_UND].I  = reg[13].I;
		reg[R14_UND].I  = reg[14].I;
		reg[SPSR_UND].I =  reg[17].I;
		break;
		}

		u32 CPSR = reg[16].I;
		u32 SPSR = reg[17].I;

		switch(mode) {
		case 0x10:
		case 0x1F:
		reg[13].I = reg[R13_USR].I;
		reg[14].I = reg[R14_USR].I;
		reg[16].I = SPSR;
		break;
		case 0x11:
		CPUSwap(&reg[8].I, &reg[R8_FIQ].I);
		CPUSwap(&reg[9].I, &reg[R9_FIQ].I);
		CPUSwap(&reg[10].I, &reg[R10_FIQ].I);
		CPUSwap(&reg[11].I, &reg[R11_FIQ].I);
		CPUSwap(&reg[12].I, &reg[R12_FIQ].I);
		reg[13].I = reg[R13_FIQ].I;
		reg[14].I = reg[R14_FIQ].I;
		if(saveState)
		reg[17].I = CPSR;
		else
		reg[17].I = reg[SPSR_FIQ].I;
		break;
		case 0x12:
		reg[13].I = reg[R13_IRQ].I;
		reg[14].I = reg[R14_IRQ].I;
		reg[16].I = SPSR;
		if(saveState)
		reg[17].I = CPSR;
		else
		reg[17].I = reg[SPSR_IRQ].I;
		break;
		case 0x13:
		reg[13].I = reg[R13_SVC].I;
		reg[14].I = reg[R14_SVC].I;
		reg[16].I = SPSR;
		if(saveState)
		reg[17].I = CPSR;
		else
		reg[17].I = reg[SPSR_SVC].I;
		break;
		case 0x17:
		reg[13].I = reg[R13_ABT].I;
		reg[14].I = reg[R14_ABT].I;
		reg[16].I = SPSR;
		if(saveState)
		reg[17].I = CPSR;
		else
		reg[17].I = reg[SPSR_ABT].I;
		break;    
		case 0x1b:
		reg[13].I = reg[R13_UND].I;
		reg[14].I = reg[R14_UND].I;
		reg[16].I = SPSR;
		if(saveState)
		reg[17].I = CPSR;
		else
		reg[17].I = reg[SPSR_UND].I;
		break;    
		default:
		printf("Unsupported ARM mode %02x\n", mode);
		die("Arm error..");
		break;
		}
		armMode = mode;
		CPUUpdateFlags();
		CPUUpdateCPSR();*/
	}

	void CPUUpdateCPSR()
	{
		u32 CPSR = reg[16].I & 0x40;
		if(N_FLAG)
			CPSR |= 0x80000000;
		if(Z_FLAG)
			CPSR |= 0x40000000;
		if(C_FLAG)
			CPSR |= 0x20000000;
		if(V_FLAG)
			CPSR |= 0x10000000;
		/*if(!armState)
		CPSR |= 0x00000020;*/
		if (!armFiqEnable)
			CPSR |= 0x40;
		if(!armIrqEnable)
			CPSR |= 0x80;
		CPSR |= (armMode & 0x1F);
		reg[16].I = CPSR;

		verify(armMode==0);
		verify(armFiqEnable==false);
		verify(armIrqEnable==false);
	}

	void CPUUpdateFlags()
	{
		u32 CPSR = reg[16].I;

		N_FLAG = (CPSR & 0x80000000) ? true: false;
		Z_FLAG = (CPSR & 0x40000000) ? true: false;
		C_FLAG = (CPSR & 0x20000000) ? true: false;
		V_FLAG = (CPSR & 0x10000000) ? true: false;
		//armState = (CPSR & 0x20) ? false : true;
		armIrqEnable = (CPSR & 0x80) ? false : true;
		armFiqEnable = (CPSR & 0x40) ? false : true;

		verify(armMode==0);
		verify(armFiqEnable==false);
		verify(armIrqEnable==false);
	}

	void CPUSoftwareInterrupt(int comment)
	{
		die("Can't happen");
	}

	void CPUUndefinedException()
	{
		die("Can't happen");
	}

	void virt_arm_reset()
	{
		// clean registers
		memset(&arm_Reg[0], 0, sizeof(arm_Reg));

		armMode = 0x0;

		reg[13].I = 0x03007F00;
		reg[15].I = 0x0000000;
		reg[16].I = 0x00000000;

		// disable FIQ
		reg[16].I |= 0x40;

		CPUUpdateCPSR();

		armNextPC = reg[15].I;
		reg[15].I += 4;

		//arm_FiqPending = false; 
	}

	void virt_arm_init()
	{
		virt_arm_reset();

		for (int i = 0; i < 256; i++)
		{
			int count = 0;
			for (int j = 0; j < 8; j++)
				if (i & (1 << j))
					count++;

			cpuBitsSet[i] = count;
		}
	}
}


void virt_arm_reset()
{
	VARM::virt_arm_reset();
}

void virt_arm_init()
{
	VARM::virt_arm_init();
}

u32 DYNACALL virt_arm_op(u32 opcode)
{
	return VARM::virt_arm_op(opcode);
}

u32& virt_arm_reg(u32 id)
{
	return VARM::arm_Reg[id].I;
}

#endif
