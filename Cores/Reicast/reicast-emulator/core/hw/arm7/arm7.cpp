#include "arm7.h"
#include "arm_mem.h"


#include <map>


#define C_CORE

#if 0
	#define arm_printf printf
#else
	void arm_printf(...) { }
#endif

//#define CPUReadHalfWordQuick(addr) arm_ReadMem16(addr & 0x7FFFFF)
#define CPUReadMemoryQuick(addr) (*(u32*)&aica_ram[addr&ARAM_MASK])
#define CPUReadByte arm_ReadMem8
#define CPUReadMemory arm_ReadMem32
#define CPUReadHalfWord arm_ReadMem16
#define CPUReadHalfWordSigned(addr) ((s16)arm_ReadMem16(addr))

#define CPUWriteMemory arm_WriteMem32
#define CPUWriteHalfWord arm_WriteMem16
#define CPUWriteByte arm_WriteMem8


#define reg arm_Reg
#define armNextPC reg[R15_ARM_NEXT].I


#define CPUUpdateTicksAccesint(a) 1
#define CPUUpdateTicksAccessSeq32(a) 1
#define CPUUpdateTicksAccesshort(a) 1
#define CPUUpdateTicksAccess32(a) 1
#define CPUUpdateTicksAccess16(a) 1


enum
{
	RN_CPSR      = 16,
	RN_SPSR      = 17,

	R13_IRQ      = 18,
	R14_IRQ      = 19,
	SPSR_IRQ     = 20,
	R13_USR      = 26,
	R14_USR      = 27,
	R13_SVC      = 28,
	R14_SVC      = 29,
	SPSR_SVC     = 30,
	R13_ABT      = 31,
	R14_ABT      = 32,
	SPSR_ABT     = 33,
	R13_UND      = 34,
	R14_UND      = 35,
	SPSR_UND     = 36,
	R8_FIQ       = 37,
	R9_FIQ       = 38,
	R10_FIQ      = 39,
	R11_FIQ      = 40,
	R12_FIQ      = 41,
	R13_FIQ      = 42,
	R14_FIQ      = 43,
	SPSR_FIQ     = 44,
	RN_PSR_FLAGS = 45,
	R15_ARM_NEXT = 46,
	INTR_PEND    = 47,
	CYCL_CNT     = 48,

	RN_ARM_REG_COUNT,
};

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

	union
	{
		struct
		{
			u32 _pad0 : 28;
			u32 V     : 1; //Bit 28
			u32 C     : 1; //Bit 29
			u32 Z     : 1; //Bit 30
			u32 N     : 1; //Bit 31
		};

		struct
		{
			u32 _pad1 : 28;
			u32 NZCV  : 4; //Bits [31:28]
		};
	} FLG;

	struct
	{
		u32 M     : 5;  //mode, PSR[4:0]
		u32 _pad0 : 1;  //not used / zero
		u32 F     : 1;  //FIQ disable, PSR[6]
		u32 I     : 1;  //IRQ disable, PSR[7]
		u32 _pad1 : 20; //not used / zero
		u32 NZCV  : 4;  //Bits [31:28]
	} PSR;

	u32 I;
} reg_pair;

//bool arm_FiqPending; -- not used , i use the input directly :)
//bool arm_IrqPending;

DECL_ALIGN(8) reg_pair arm_Reg[RN_ARM_REG_COUNT];

void CPUSwap(u32 *a, u32 *b)
{
	u32 c = *b;
	*b = *a;
	*a = c;
}

/*
bool N_FLAG;
bool Z_FLAG;
bool C_FLAG;
bool V_FLAG;
*/
#define N_FLAG (reg[RN_PSR_FLAGS].FLG.N)
#define Z_FLAG (reg[RN_PSR_FLAGS].FLG.Z)
#define C_FLAG (reg[RN_PSR_FLAGS].FLG.C)
#define V_FLAG (reg[RN_PSR_FLAGS].FLG.V)

bool armIrqEnable;
bool armFiqEnable;
//bool armState;
int armMode;

bool Arm7Enabled=false;

u8 cpuBitsSet[256];

bool intState = false;
bool stopState = false;
bool holdState = false;



void CPUSwitchMode(int mode, bool saveState, bool breakLoop=true);
extern "C" void CPUFiq();
void CPUUpdateCPSR();
void CPUUpdateFlags();
void CPUSoftwareInterrupt(int comment);
void CPUUndefinedException();

void arm_Run_(u32 CycleCount)
{
	if (!Arm7Enabled)
		return;

	u32 clockTicks=0;
	while (clockTicks<CycleCount)
	{
		if (reg[INTR_PEND].I)
		{
			CPUFiq();
		}

		reg[15].I = armNextPC + 8;
		#include "arm-new.h"
	}
}

void CPUInterrupt();


void armt_init();
//void CreateTables();
void arm_Init()
{
#if FEAT_AREC != DYNAREC_NONE
	armt_init();
#endif
	//CreateTables();
	arm_Reset();

	for (int i = 0; i < 256; i++)
	{
		int count = 0;
		for (int j = 0; j < 8; j++)
			if (i & (1 << j))
				count++;

		cpuBitsSet[i] = count;
	}
}

void CPUSwitchMode(int mode, bool saveState, bool breakLoop)
{
	CPUUpdateCPSR();

	switch(armMode)
	{
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

	switch(mode)
	{
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
	CPUUpdateCPSR();
}

void CPUUpdateCPSR()
{
	reg_pair CPSR;

	CPSR.I = reg[RN_CPSR].I & 0x40;

	/*
	if(N_FLAG)
		CPSR |= 0x80000000;
	if(Z_FLAG)
		CPSR |= 0x40000000;
	if(C_FLAG)
		CPSR |= 0x20000000;
	if(V_FLAG)
		CPSR |= 0x10000000;
	if(!armState)
		CPSR |= 0x00000020;
	*/

	CPSR.PSR.NZCV=reg[RN_PSR_FLAGS].FLG.NZCV;


	if (!armFiqEnable)
		CPSR.I |= 0x40;
	if(!armIrqEnable)
		CPSR.I |= 0x80;

	CPSR.PSR.M=armMode;
	
	reg[16].I = CPSR.I;
}

void CPUUpdateFlags()
{
	u32 CPSR = reg[16].I;

	reg[RN_PSR_FLAGS].FLG.NZCV=reg[16].PSR.NZCV;

	/*
	N_FLAG = (CPSR & 0x80000000) ? true: false;
	Z_FLAG = (CPSR & 0x40000000) ? true: false;
	C_FLAG = (CPSR & 0x20000000) ? true: false;
	V_FLAG = (CPSR & 0x10000000) ? true: false;
	*/
	//armState = (CPSR & 0x20) ? false : true;
	armIrqEnable = (CPSR & 0x80) ? false : true;
	armFiqEnable = (CPSR & 0x40) ? false : true;
	update_armintc();
}

void CPUSoftwareInterrupt(int comment)
{
	u32 PC = reg[R15_ARM_NEXT].I+4;
	//bool savedArmState = armState;
	CPUSwitchMode(0x13, true, false);
	reg[14].I = PC;
//	reg[15].I = 0x08;
	
	armIrqEnable = false;
	armNextPC = 0x08;
//	reg[15].I += 4;
}

void CPUUndefinedException()
{
	printf("arm7: CPUUndefinedException(). SOMETHING WENT WRONG\n");
	u32 PC = reg[R15_ARM_NEXT].I+4;
	CPUSwitchMode(0x1b, true, false);
	reg[14].I = PC;
//	reg[15].I = 0x04;
	armIrqEnable = false;
	armNextPC = 0x04;
//	reg[15].I += 4;  
}

void FlushCache();

void arm_Reset()
{
#if FEAT_AREC != DYNAREC_NONE
	FlushCache();
#endif
	Arm7Enabled = false;
	// clean registers
	memset(&arm_Reg[0], 0, sizeof(arm_Reg));

	armMode = 0x1F;

	reg[13].I = 0x03007F00;
	reg[15].I = 0x0000000;
	reg[16].I = 0x00000000;
	reg[R13_IRQ].I = 0x03007FA0;
	reg[R13_SVC].I = 0x03007FE0;
	armIrqEnable = true;      
	armFiqEnable = false;
	update_armintc();

	//armState = true;
	C_FLAG = V_FLAG = N_FLAG = Z_FLAG = false;

	// disable FIQ
	reg[16].I |= 0x40;

	CPUUpdateCPSR();

	armNextPC = reg[15].I;
	reg[15].I += 4;
}

/*

//NO IRQ on aica ..
void CPUInterrupt()
{
	u32 PC = reg[15].I;
	//bool savedState = armState;
	CPUSwitchMode(0x12, true, false);
	reg[14].I = PC;
	//if(!savedState)
	//	reg[14].I += 2;
	reg[15].I = 0x18;
	//armState = true;
	armIrqEnable = false;

	armNextPC = reg[15].I;
	reg[15].I += 4;
}

*/

extern "C"
NOINLINE
void CPUFiq()
{
	u32 PC = reg[R15_ARM_NEXT].I+4;
	//bool savedState = armState;
	CPUSwitchMode(0x11, true, false);
	reg[14].I = PC;
	//if(!savedState)
	//	reg[14].I += 2;
	//reg[15].I = 0x1c;
	//armState = true;
	armIrqEnable = false;
	armFiqEnable = false;
	update_armintc();

	armNextPC = 0x1c;
	//reg[15].I += 4;
}


/*
	--Seems like aica has 3 interrupt controllers actualy (damn lazy sega ..)
	The "normal" one (the one that exists on scsp) , one to emulate the 68k intc , and , 
	of course , the arm7 one

	The output of the sci* bits is input to the e68k , and the output of e68k is inputed into the FIQ
	pin on arm7
*/
#include "hw/sh4/sh4_core.h"


void arm_SetEnabled(bool enabled)
{
	if(!Arm7Enabled && enabled)
			arm_Reset();
	
	Arm7Enabled=enabled;
}



//Emulate a single arm op, passed in opcode
//DYNACALL for ECX passing

u32 DYNACALL arm_single_op(u32 opcode)
{
	u32 clockTicks=0;

#define NO_OPCODE_READ

	//u32 static_opcode=((opcd_hash&0xFFF0)<<16) |  ((opcd_hash&0x000F)<<4);
	//u32 static_opcode=((opcd_hash)<<28);
#include "arm-new.h"

	return clockTicks;
}

void update_armintc()
{
	reg[INTR_PEND].I=e68k_out && armFiqEnable;
}

void libAICA_TimeStep();

#if FEAT_AREC == DYNAREC_NONE
void arm_Run(u32 CycleCount) { 
	for (int i=0;i<32;i++)
	{
		arm_Run_(CycleCount/32);
		libAICA_TimeStep();
	}
}
#else
extern "C" void CompileCode();

/*

	ARM
		ALU opcodes (more or less)

			(flags,rv)=opcode(flags,in regs ..)
			rd=rv;
			if (set_flags)
				PSR=(rd==pc?CPSR:flags);
		
		(mem ops)
		Writes of R15:
			R15+12
		R15 as base:
			R15+8
		LDR
			rd=mem[addr(in regs)]
		LDM

		...
		STR/STM: pc+12


		///

		"cached" interpreter:
		Set PC+12 to PC reg
		mov opcode
		call function

		if (pc settting opcode)
			lookup again using armNextPC
			

		PC setting opcodes
			ALU with write to PC
			LDR with write to PC (SDT)
			LDM with write to PC (BDT)
			B/BL
			SWI
			<Undefined opcodes, if any>

			Indirect, via write to PSR/Mode
			MSR
*/


struct ArmDPOP
{
	u32 key;
	u32 mask;
	u32 flags;
};

vector<ArmDPOP> ops;

enum OpFlags
{
	OP_SETS_PC         = 1,
	OP_READS_PC        = 32768,
	OP_IS_COND         = 65536,
	OP_MFB             = 0x80000000,

	OP_HAS_RD_12       = 2,
	OP_HAS_RD_16       = 4,
	OP_HAS_RS_0        = 8,
	OP_HAS_RS_8        = 16,
	OP_HAS_RS_16       = 32,
	OP_HAS_FLAGS_READ  = 4096,
	OP_HAS_FLAGS_WRITE = 8192,
	OP_HAS_RD_READ     = 16384, //For conditionals

	OP_WRITE_FLAGS     = 64,
	OP_WRITE_FLAGS_S   = 128,
	OP_READ_FLAGS      = 256,
	OP_READ_FLAGS_S    = 512,
	OP_WRITE_REG       = 1024,
	OP_READ_REG_1      = 2048,
};

#define DP_R_ROFC (OP_READ_FLAGS_S|OP_READ_REG_1) //Reads reg1, op2, flags if S
#define DP_R_ROF (OP_READ_FLAGS|OP_READ_REG_1)    //Reads reg1, op2, flags (ADC & co)
#define DP_R_OFC (OP_READ_FLAGS_S)                //Reads op2, flags if S

#define DP_W_RFC (OP_WRITE_FLAGS_S|OP_WRITE_REG)  //Writes reg, and flags if S
#define DP_W_F (OP_WRITE_FLAGS)                   //Writes only flags, always (S=1)

/*
	COND | 00 0 OP1   S Rn Rd SA    ST 0  Rm -- Data opcode, PSR xfer (imm shifted reg)
	     | 00 0 OP1   S Rn Rd Rs   0 ST 1 Rm -- Data opcode, PSR xfer (reg shifted reg)
	     | 00 0 0 00A S Rd Rn Rs    1001  Rm -- Mult
		 | 00 0 1 0B0 0 Rn Rd 0000  1001  Rm -- SWP
		 | 00 1 OP1   S Rn Rd imm8r4         -- Data opcode, PSR xfer (imm8r4)

		 | 01 0 P UBW L Rn Rd Offset          -- LDR/STR (I=0)
		 | 01 1 P UBW L Rn Rd SHAM SHTP 0 Rs  -- LDR/STR (I=1)
		 | 10 0 P USW L Rn {RList}            -- LDM/STM
		 | 10 1 L {offset}                    -- B/BL
		 | 11 1 1 X*                          -- SWI

		 (undef cases)
		 | 01 1 XXXX X X*  X*  X* 1 XXXX - Undefined (LDR/STR w/ encodings that would be reg. based shift)
		 | 11 0 PUNW L Rn {undef} -- Copr. Data xfer (undef)
		 | 11 1 0 CPOP Crn Crd Cpn CP3 0 Crm -- Copr. Data Op (undef)
		 | 11 1 0 CPO3 L Crn Crd Cpn CP3 1 Crm -- Copr. Reg xf (undef)


		 Phase #1:
			-Non branches that don't touch memory (pretty much: Data processing, Not MSR, Mult)
			-Everything else is ifb

		 Phase #2:
			Move LDR/STR to templates

		 Phase #3:
			Move LDM/STM to templates
			

*/

void AddDPOP(u32 subcd, u32 rflags, u32 wflags)
{
	ArmDPOP op;

	u32 key=subcd<<21;
	u32 mask=(15<<21) | (7<<25);

	op.flags=rflags|wflags;
	
	if (wflags==DP_W_F)
	{
		//also match S bit for opcodes that must write to flags (CMP & co)
		mask|=1<<20;
		key|=1<<20;
	}

	//ISR form (bit 25=0, bit 4 = 0)
	op.key=key;
	op.mask=mask | (1<<4);
	ops.push_back(op);

	//RSR form (bit 25=0, bit 4 = 1, bit 7=0)
	op.key =  key  | (1<<4);
	op.mask = mask | (1<<4) | (1<<7);
	ops.push_back(op);

	//imm8r4 form (bit 25=1) 
	op.key =  key  | (1<<25);
	op.mask = mask;
	ops.push_back(op);
}

void InitHash()
{
	/*
		COND | 00 I OP1  S Rn Rd OPER2 -- Data opcode, PSR xfer
		Data processing opcodes
	*/
		 
	//AND   0000        Rn, OPER2, {Flags}    Rd, {Flags}
	//EOR   0001        Rn, OPER2, {Flags}    Rd, {Flags}
	//SUB   0010        Rn, OPER2, {Flags}    Rd, {Flags}
	//RSB   0011        Rn, OPER2, {Flags}    Rd, {Flags}
	//ADD   0100        Rn, OPER2, {Flags}    Rd, {Flags}
	//ORR   1100        Rn, OPER2, {Flags}    Rd, {Flags}
	//BIC   1110        Rn, OPER2, {Flags}    Rd, {Flags}
	AddDPOP(0,DP_R_ROFC, DP_W_RFC);
	AddDPOP(1,DP_R_ROFC, DP_W_RFC);
	AddDPOP(2,DP_R_ROFC, DP_W_RFC);
	AddDPOP(3,DP_R_ROFC, DP_W_RFC);
	AddDPOP(4,DP_R_ROFC, DP_W_RFC);
	AddDPOP(12,DP_R_ROFC, DP_W_RFC);
	AddDPOP(14,DP_R_ROFC, DP_W_RFC);
	
	//ADC   0101        Rn, OPER2, Flags      Rd, {Flags}
	//SBC   0110        Rn, OPER2, Flags      Rd, {Flags}
	//RSC   0111        Rn, OPER2, Flags      Rd, {Flags}
	AddDPOP(5,DP_R_ROF, DP_W_RFC);
	AddDPOP(6,DP_R_ROF, DP_W_RFC);
	AddDPOP(7,DP_R_ROF, DP_W_RFC);

	//TST   1000 S=1    Rn, OPER2, Flags      Flags
	//TEQ   1001 S=1    Rn, OPER2, Flags      Flags
	AddDPOP(8,DP_R_ROF, DP_W_F);
	AddDPOP(9,DP_R_ROF, DP_W_F);

	//CMP   1010 S=1    Rn, OPER2             Flags
	//CMN   1011 S=1    Rn, OPER2             Flags
	AddDPOP(10,DP_R_ROF, DP_W_F);
	AddDPOP(11,DP_R_ROF, DP_W_F);
	
	//MOV   1101        OPER2, {Flags}        Rd, {Flags}
	//MVN   1111        OPER2, {Flags}        Rd, {Flags}
	AddDPOP(13,DP_R_OFC, DP_W_RFC);
	AddDPOP(15,DP_R_OFC, DP_W_RFC);
}




/*
 *	
 *	X86 Compiler
 *
 */

void  armEmit32(u32 emit32);
void *armGetEmitPtr();


#define _DEVEL          (1)
#define EMIT_I          armEmit32((I))
#define EMIT_GET_PTR()  armGetEmitPtr()
u8* icPtr;
u8* ICache;

const u32 ICacheSize=1024*1024;
#if HOST_OS == OS_WINDOWS
u8 ARM7_TCB[ICacheSize+4096];
#elif HOST_OS == OS_LINUX

u8 ARM7_TCB[ICacheSize+4096] __attribute__((section(".text")));

#elif HOST_OS==OS_DARWIN
u8 ARM7_TCB[ICacheSize+4096] __attribute__((section("__TEXT, .text")));
#else
#error ARM7_TCB ALLOC
#endif

#include "arm_emitter/arm_emitter.h"
#undef I


using namespace ARM;


void* EntryPoints[ARAM_SIZE/4];

enum OpType
{
	VOT_Fallback,
	VOT_DataOp,
	VOT_B,
	VOT_BL,
	VOT_BR,     //Branch (to register)
	VOT_Read,   //Actually, this handles LDR and STR
	//VOT_LDM,  //This Isn't used anymore
	VOT_MRS,
	VOT_MSR,
};



void armv_call(void* target);
void armv_setup();
void armv_intpr(u32 opcd);
void armv_end(void* codestart, u32 cycles);
void armv_check_pc(u32 pc);
void armv_check_cache(u32 opcd, u32 pc);
void armv_imm_to_reg(u32 regn, u32 imm);
void armv_MOV32(eReg regn, u32 imm);
void armv_prof(OpType opt,u32 op,u32 flg);

extern "C" void arm_dispatch();
extern "C" void arm_exit();
extern "C" void DYNACALL arm_mainloop(u32 cycl, void* regs, void* entrypoints);
extern "C" void DYNACALL arm_compilecode();

template <bool L, bool B>
u32 DYNACALL DoMemOp(u32 addr,u32 data)
{
	u32 rv=0;

#if HOST_CPU==CPU_X86 && FEAT_AREC != DYNAREC_NONE
	addr=virt_arm_reg(0);
	data=virt_arm_reg(1);
#endif

	if (L)
	{
		if (B)
			rv=arm_ReadMem8(addr);
		else
			rv=arm_ReadMem32(addr);
	}
	else
	{
		if (B)
			arm_WriteMem8(addr,data);
		else
			arm_WriteMem32(addr,data);
	}

	#if HOST_CPU==CPU_X86 && FEAT_AREC != DYNAREC_NONE
		virt_arm_reg(0)=rv;
	#endif

	return rv;
}

//findfirstset -- used in LDM/STM handling
#if HOST_CPU==CPU_X86 && BUILD_COMPILER != COMPILER_GCC
#include <intrin.h>

u32 findfirstset(u32 v)
{
	unsigned long rv;
	_BitScanForward(&rv,v);
	return rv+1;
}
#else
#define findfirstset __builtin_ffs
#endif

#if 0
//LDM isn't perf. citrical, and as a result, not implemented fully. 
//So this code is disabled
//mask is *2
template<u32 I>
void DYNACALL DoLDM(u32 addr, u32 mask)
{

#if HOST_CPU==CPU_X86
	addr=virt_arm_reg(0);
	mask=virt_arm_reg(1);
#endif
	//addr=(addr); //force align ?

	u32 idx=-1;
	do
	{
		u32 tz=findfirstset(mask);
		mask>>=tz;
		idx+=tz;
		arm_Reg[idx].I=arm_ReadMem32(addr);
		addr+=4;
	} while(mask);
}
#endif

void* GetMemOp(bool L, bool B)
{
	if (L)
	{
		if (B)
			return (void*)(u32(DYNACALL*)(u32,u32))&DoMemOp<true,true>;
		else
			return (void*)(u32(DYNACALL*)(u32,u32))&DoMemOp<true,false>;
	}
	else
	{
		if (B)
			return (void*)(u32(DYNACALL*)(u32,u32))&DoMemOp<false,true>;
		else
			return (void*)(u32(DYNACALL*)(u32,u32))&DoMemOp<false,false>;
	}
}

//Decodes an opcode, returns type. 
//opcd might be changed (currently for LDM/STM -> LDR/STR transforms)
OpType DecodeOpcode(u32& opcd,u32& flags)
{
	//by default, PC has to be updated
	flags=OP_READS_PC;

	u32 CC=(opcd >> 28);

	if (CC!=CC_AL)
		flags|=OP_IS_COND;

	//helpers ...
	#define CHK_BTS(M,S,V) ( (M & (opcd>>S)) == (V) ) //Check bits value in opcode
	#define IS_LOAD (opcd & (1<<20))                  //Is L bit set ? (LDM/STM LDR/STR)
	#define READ_PC_CHECK(S) if (CHK_BTS(15,S,15)) flags|=OP_READS_PC;

	//Opcode sets pc ?
	bool _set_pc=
		(CHK_BTS(3,26,0) && CHK_BTS(15,12,15))             || //Data processing w/ Rd=PC
		(CHK_BTS(3,26,1) && CHK_BTS(15,12,15) && IS_LOAD ) || //LDR/STR w/ Rd=PC 
		(CHK_BTS(7,25,4) && (opcd & 32768) &&  IS_LOAD)    || //LDM/STM w/ PC in list	
		CHK_BTS(7,25,5)                                    || //B or BL
		CHK_BTS(15,24,15);                                    //SWI
	
	//NV condition means VFP on newer cores, let interpreter handle it...
	if (CC==15)
		return VOT_Fallback;

	if (_set_pc)
		flags|=OP_SETS_PC;

	//B / BL ?
	if (CHK_BTS(7,25,5))
	{
		verify(_set_pc);
		if (!(flags&OP_IS_COND))
			flags&=~OP_READS_PC;  //not COND doesn't read from pc

		flags|=OP_SETS_PC;        //Branches Set pc ..

		//branch !
		return (opcd&(1<<24))?VOT_BL:VOT_B;
	}

	//Common case: MOVCC PC,REG
	if (CHK_BTS(0xFFFFFF,4,0x1A0F00))
	{
		verify(_set_pc);
		if (CC==CC_AL)
			flags&=~OP_READS_PC;

		return VOT_BR;
	}


	//No support for COND branching opcodes apart from the forms above ..
	if (CC!=CC_AL && _set_pc)
	{
		return VOT_Fallback;
	}

	u32 RList=opcd&0xFFFF;
	u32 Rn=(opcd>>16)&15;

#define LDM_REGCNT() (cpuBitsSet[RList & 255] + cpuBitsSet[(RList >> 8) & 255])


	//Data Processing opcodes -- find using mask/key
	//This will eventually be virtualised w/ register renaming
	for( u32 i=0;i<ops.size();i++)
	{
		if (!_set_pc && ops[i].key==(opcd&ops[i].mask))
		{
			//We fill in the cases that we have to read pc
			flags &= ~OP_READS_PC;

			//Conditionals always need flags read ...
			if ((opcd >> 28)!=0xE)
			{
				flags |= OP_HAS_FLAGS_READ;
				//if (flags & OP_WRITE_REG)
					flags |= OP_HAS_RD_READ;
			}

			//DPOP !

			if ((ops[i].flags & OP_READ_FLAGS) ||
			   ((ops[i].flags & OP_READ_FLAGS_S) && (opcd & (1<<20))))
			{
				flags |= OP_HAS_FLAGS_READ;
			}

			if ((ops[i].flags & OP_WRITE_FLAGS) ||
			   ((ops[i].flags & OP_WRITE_FLAGS_S) && (opcd & (1<<20))))
			{
				flags |= OP_HAS_FLAGS_WRITE;
			}

			if(ops[i].flags & OP_WRITE_REG)
			{
				//All dpops that write, write to RD_12
				flags |= OP_HAS_RD_12;
				verify(! (CHK_BTS(15,12,15) && CC!=CC_AL));
			}

			if(ops[i].flags & OP_READ_REG_1)
			{
				//Reg 1 is RS_16
				flags |= OP_HAS_RS_16;

				//reads from pc ?
				READ_PC_CHECK(16);
			}

			//op2 is imm or reg ?
			if ( !(opcd & (1<<25)) )
			{
				//its reg (register or imm shifted)
				flags |= OP_HAS_RS_0;
				//reads from pc ?
				READ_PC_CHECK(0);

				//is it register shifted reg ?
				if (opcd & (1<<4))
				{
					verify(! (opcd & (1<<7)) );	//must be zero
					flags |= OP_HAS_RS_8;
					//can't be pc ...
					verify(!CHK_BTS(15,8,15));
				}
				else
				{
					//is it RRX ?
					if ( ((opcd>>4)&7)==6)
					{
						//RRX needs flags to be read (even if the opcode doesn't)
						flags |= OP_HAS_FLAGS_READ;
					}
				}
			}

			return VOT_DataOp;
		}
	}

	//Lets try mem opcodes since its not data processing


	
	/*
		Lets Check LDR/STR !

		CCCC 01 0 P UBW L Rn Rd Offset	-- LDR/STR (I=0)
	*/
	if ((opcd>>25)==(0xE4/2) )
	{
		/*
			I=0

			Everything else handled
		*/
		arm_printf("ARM: MEM %08X L/S:%d, AWB:%d!\n",opcd,(opcd>>20)&1,(opcd>>21)&1);

		return VOT_Read;
	}
	else if ((opcd>>25)==(0xE6/2) && CHK_BTS(0x7,4,0) )
	{
		arm_printf("ARM: MEM REG to Reg %08X\n",opcd);
		
		/*
			I=1

			Logical Left shift, only
		*/
		return VOT_Read;
	}
	//LDM common case
	else if ((opcd>>25)==(0xE8/2) /*&& CHK_BTS(32768,0,0)*/ && CHK_BTS(1,22,0) && CHK_BTS(1,20,1) && LDM_REGCNT()==1)
	{
		//P=0
		//U=1
		//L=1
		//W=1
		//S=0
		
		u32 old_opcd=opcd;

		//One register xfered
		//Can be rewriten as normal mem opcode ..
		opcd=0xE4000000;

		//Imm offset
		opcd |= 0<<25;
		//Post incr
		opcd |= old_opcd & (1<<24);
		//Up/Dn
		opcd |= old_opcd & (1<<23);
		//Word/Byte
		opcd |= 0<<22;
		//Write back (must be 0 for PI)
		opcd |= old_opcd & (1<<21);
		//Load
		opcd |= old_opcd & (1<<20);

		//Rn
		opcd |= Rn<<16;

		//Rd
		u32 Rd=findfirstset(RList)-1;
		opcd |= Rd<<12;

		//Offset
		opcd |= 4;

		arm_printf("ARM: MEM TFX R %08X\n",opcd);

		return VOT_Read;
	}
	//STM common case
	else if ((opcd>>25)==(0xE8/2) && CHK_BTS(1,22,0) && CHK_BTS(1,20,0) && LDM_REGCNT()==1)
	{
		//P=1
		//U=0
		//L=1
		//W=1
		//S=0
		
		u32 old_opcd=opcd;

		//One register xfered
		//Can be rewriten as normal mem opcode ..
		opcd=0xE4000000;

		//Imm offset
		opcd |= 0<<25;
		//Pre/Post incr
		opcd |= old_opcd & (1<<24);
		//Up/Dn
		opcd |= old_opcd & (1<<23);
		//Word/Byte
		opcd |= 0<<22;
		//Write back
		opcd |= old_opcd & (1<<21);
		//Store/Load
		opcd |= old_opcd & (1<<20);

		//Rn
		opcd |= Rn<<16;

		//Rd
		u32 Rd=findfirstset(RList)-1;
		opcd |= Rd<<12;

		//Offset
		opcd |= 4;

		arm_printf("ARM: MEM TFX W %08X\n",opcd);

		return VOT_Read;
	}
	else if (CHK_BTS(0xE10F0FFF,0,0xE10F0000))
	{
		return VOT_MRS;
	}
	else if (CHK_BTS(0xEFBFFFF0,0,0xE129F000))
	{
		return VOT_MSR;
	}
	else if ((opcd>>25)==(0xE8/2) && CHK_BTS(32768,0,0))
	{
		arm_printf("ARM: MEM FB %08X\n",opcd);
		flags|=OP_MFB; //(flag Just for the fallback counters)
	}
	else
	{
		arm_printf("ARM: FB %08X\n",opcd);
	}

	//by default fallback to interpr
	return VOT_Fallback;
}

//helpers ...
void LoadReg(eReg rd,u32 regn,ConditionCode cc=CC_AL)
{
	LDR(rd,r8,(u8*)&reg[regn].I-(u8*)&reg[0].I,Offset,cc);
}
void StoreReg(eReg rd,u32 regn,ConditionCode cc=CC_AL)
{
	STR(rd,r8,(u8*)&reg[regn].I-(u8*)&reg[0].I,Offset,cc);
}

//very quick-and-dirty register rename based virtualisation
map<u32,u32> renamed_regs;
u32 rename_reg_base;

void RenameRegReset()
{
	rename_reg_base=r1;
	renamed_regs.clear();
}

//returns new reg #. didrn is true if a rename mapping was added
u32 RenameReg(u32 reg, bool& didrn)
{
	if (renamed_regs.find(reg)==renamed_regs.end())
	{
		renamed_regs[reg]=rename_reg_base;
		rename_reg_base++;
		didrn=true;
	}
	else
	{
		didrn=false;
	}

	return renamed_regs[reg];
}

//For reg reads (they need to be loaded)
//load can be used to skip loading (for RD if not cond)
void LoadAndRename(u32& opcd, u32 bitpos, bool load,u32 pc)
{
	bool didrn;
	u32 reg=(opcd>>bitpos)&15;

	u32 nreg=RenameReg(reg,didrn);

	opcd = (opcd& ~(15<<bitpos)) | (nreg<<bitpos);

	if (load && didrn)
	{
		if (reg==15)
			armv_MOV32((eReg)nreg,pc);
		else
			LoadReg((eReg)nreg,reg);
	}
}

//For results store (they need to be stored)
void StoreAndRename(u32 opcd, u32 bitpos)
{
	bool didrn;
	u32 reg=(opcd>>bitpos)&15;

	u32 nreg=RenameReg(reg,didrn);

	verify(!didrn);

	if (reg==15)
		reg=R15_ARM_NEXT;

	StoreReg((eReg)nreg,reg);
}

//For COND
void LoadFlags()
{
	//Load flags
	LoadReg(r0,RN_PSR_FLAGS);
	//move them to flags register
	MSR(0,8,r0);
}

//Virtualise Data Processing opcode
void VirtualizeOpcode(u32 opcd,u32 flag,u32 pc)
{
	//Keep original opcode for info
	u32 orig=opcd;

	//Load arm flags, RS0/8/16, RD12/16 (as indicated by the decoder flags)

	if (flag & OP_HAS_FLAGS_READ)
	{
		LoadFlags();
	}

	if (flag & OP_HAS_RS_0)
		LoadAndRename(opcd,0,true,pc+8);
	if (flag & OP_HAS_RS_8)
		LoadAndRename(opcd,8,true,pc+8);
	if (flag & OP_HAS_RS_16)
		LoadAndRename(opcd,16,true,pc+8);

	if (flag & OP_HAS_RD_12)
		LoadAndRename(opcd,12,flag&OP_HAS_RD_READ,pc+4);

	if (flag & OP_HAS_RD_16)
	{
		verify(! (flag & OP_HAS_RS_16));
		LoadAndRename(opcd,16,flag&OP_HAS_RD_READ,pc+4);
	}

	//Opcode has been modified to use the new regs
	//Emit it ...
	arm_printf("Arm Virtual: %08X -> %08X\n",orig,opcd);
	armEmit32(opcd);

	//Store arm flags, rd12/rd16 (as indicated by the decoder flags)
	if (flag & OP_HAS_RD_12)
		StoreAndRename(orig,12);

	if (flag & OP_HAS_RD_16)
		StoreAndRename(orig,16);

	//Sanity check ..
	if (renamed_regs.find(15)!=renamed_regs.end())
	{
		verify(flag&OP_READS_PC || (flag&OP_SETS_PC && !(flag&OP_IS_COND)));
	}

	if (flag & OP_HAS_FLAGS_WRITE)
	{
		//get results from flags register
		MRS(r1,0);
		//Store flags
		StoreReg(r1,RN_PSR_FLAGS);
	}
}

u32 nfb,ffb,bfb,mfb;




#if (HOST_CPU == CPU_X86)

/* X86 backend
 * Uses a mix of
 * x86 code
 * Virtualised arm code (using the varm interpreter)
 * Emulated arm fallbacks (using the aica arm interpreter)
 *
 * The goal is to run as much code possible under the varm interpreter
 * so it will run on arm w/o changes. A few opcodes are missing from varm 
 * (MOV32 is a notable case) and as such i've added a few varm_* hooks
 *
 * This code also performs a LOT of compiletime and runtime state/value sanity checks.
 * We don't care for speed here ...
*/

#include "emitter/x86_emitter.h"
#include "virt_arm.h"

static x86_block* x86e;

void DumpRegs(const char* output)
{
	static FILE* f=fopen(output, "w");
	static int id=0;
#if 0
	if (490710==id)
	{
		__asm int 3;
	}
#endif
	verify(id!=137250);
#if 1
	fprintf(f,"%d\n",id);
	//for(int i=0;i<14;i++)
	{
		int i=R15_ARM_NEXT;
		fprintf(f,"r%d=%08X\n",i,reg[i].I);
	}
#endif
	id++;
}

void DYNACALL PrintOp(u32 opcd)
{
	printf("%08X\n",opcd);
}

void armv_imm_to_reg(u32 regn, u32 imm)
{
	x86e->Emit(op_mov32,&reg[regn].I,imm);
}

void armv_MOV32(eReg regn, u32 imm)
{
	x86e->Emit(op_mov32,&virt_arm_reg(regn),imm);
}

void armv_call(void* loc)
{
	x86e->Emit(op_call,x86_ptr_imm(loc));
}

x86_Label* end_lbl;

void armv_setup()
{
	//Setup emitter
	x86e = new x86_block();
	x86e->Init(0,0);
	x86e->x86_buff=(u8*)EMIT_GET_PTR();
	x86e->x86_size=1024*64;
	x86e->do_realloc=false;

	
	//load base reg ..
	x86e->Emit(op_mov32,&virt_arm_reg(8),(u32)&arm_Reg[0]);
	
	//the "end" label is used to exit from the block, if a code modification (expected opcode // actual opcode in ram) is detected
	end_lbl=x86e->CreateLabel(false,0);
}

void armv_intpr(u32 opcd)
{
	//Call interpreter
	x86e->Emit(op_mov32,ECX,opcd);
	x86e->Emit(op_call,x86_ptr_imm(&arm_single_op));
}

void armv_end(void* codestart, u32 cycles)
{
	//Normal block end
	//Move counter to EAX for return, pop ESI, ret
	x86e->Emit(op_sub32,ESI,cycles);
	x86e->Emit(op_jns,x86_ptr_imm(arm_dispatch));
	x86e->Emit(op_jmp,x86_ptr_imm(arm_exit));

	//Fluch cache, move counter to EAX, pop, ret
	//this should never happen (triggers a breakpoint on x86)
	x86e->MarkLabel(end_lbl);
	x86e->Emit(op_int3);
	x86e->Emit(op_call,x86_ptr_imm(FlushCache));
	x86e->Emit(op_sub32,ESI,cycles);
	x86e->Emit(op_jmp,x86_ptr_imm(arm_dispatch));

	//Generate the code & apply fixups/relocations as needed
	x86e->Generate();

	//Use space from the dynarec buffer
	icPtr+=x86e->x86_indx;

	//Delete the x86 emitter ...
	delete x86e;
}

//sanity check: non branch doesn't set pc
void armv_check_pc(u32 pc)
{
	x86e->Emit(op_cmp32,&armNextPC,pc);
	x86_Label* nof=x86e->CreateLabel(false,0);
	x86e->Emit(op_je,nof);
	x86e->Emit(op_int3);
	x86e->MarkLabel(nof);
}

//sanity check: stale cache
void armv_check_cache(u32 opcd, u32 pc)
{
	x86e->Emit(op_cmp32,&CPUReadMemoryQuick(pc),opcd);
	x86_Label* nof=x86e->CreateLabel(false,0);
	x86e->Emit(op_je,nof);
	x86e->Emit(op_int3);
	x86e->MarkLabel(nof);
}

//profiler hook
void armv_prof(OpType opt,u32 op,u32 flags)
{
	if (VOT_Fallback!=opt)
		x86e->Emit(op_add32,&nfb,1);
	else
	{
		if (flags & OP_SETS_PC)
			x86e->Emit(op_add32,&bfb,1);
		else if (flags & OP_MFB)
			x86e->Emit(op_add32,&mfb,1);
		else
			x86e->Emit(op_add32,&ffb,1);
	}
}

naked void DYNACALL arm_compilecode()
{
	__asm
	{
		call CompileCode;
		mov eax,0;
		jmp arm_dispatch;
	}
}

naked void DYNACALL arm_mainloop(u32 cycl, void* regs, void* entrypoints)
{
	__asm
	{
		push esi

		mov esi,ecx
		add esi,reg[CYCL_CNT*4].I

		mov eax,0;
		jmp arm_dispatch
	}
}

naked void arm_dispatch()
{
	__asm
	{
arm_disp:
		mov eax,reg[R15_ARM_NEXT*4].I
		and eax,0x1FFFFC
		cmp reg[INTR_PEND*4].I,0
		jne arm_dofiq
		jmp [EntryPoints+eax]

arm_dofiq:
		call CPUFiq
		jmp arm_disp
	}
}

naked void arm_exit()
{
	__asm
	{
	arm_exit:
		mov reg[CYCL_CNT*4].I,esi
		pop esi
		ret
	}
}
#elif	(HOST_CPU == CPU_ARM)

/*
 *
 *	ARMv7 Compiler
 *
 */

//mprotect and stuff ..

#include <sys/mman.h>

void  armEmit32(u32 emit32)
{
	if (icPtr >= (ICache+ICacheSize-1024))
		die("ICache is full, invalidate old entries ...");	//ifdebug

	*(u32*)icPtr = emit32;  
	icPtr+=4;
}

void *armGetEmitPtr()
{
	if (icPtr < (ICache+ICacheSize-1024))	//ifdebug
		return static_cast<void *>(icPtr);

	return NULL;
}

#if HOST_OS==OS_DARWIN
#include <libkern/OSCacheControl.h>
extern "C" void armFlushICache(void *code, void *pEnd) {
    sys_dcache_flush(code, (u8*)pEnd - (u8*)code + 1);
    sys_icache_invalidate(code, (u8*)pEnd - (u8*)code + 1);
}
#else
extern "C" void armFlushICache(void *bgn, void *end) {
	__clear_cache(bgn, end);
}
#endif


void armv_imm_to_reg(u32 regn, u32 imm)
{
	MOV32(r0,imm);
	StoreReg(r0,regn);
}

void armv_call(void* loc)
{
	CALL((u32)loc);
}

void armv_setup()
{
	//Setup emitter

	//r9: temp for mem ops (PI WB)
	//r8: base
	//Stored on arm_mainloop so no need for push/pop
}

void armv_intpr(u32 opcd)
{
	//Call interpreter
	MOV32(r0,opcd);
	CALL((u32)arm_single_op);
}

void armv_end(void* codestart, u32 cycl)
{
	//Normal block end
	//cycle counter rv

	//pop registers & return
	if (is_i8r4(cycl))
		SUB(r5,r5,cycl,true);
	else
	{
		u32 togo = cycl;
		while(ARMImmid8r4_enc(togo) == -1)
		{
			SUB(r5,r5,256);
			togo -= 256;
		}
		SUB(r5,r5,togo,true);
	}
	JUMP((u32)&arm_exit,CC_MI);	//statically predicted as not taken
	JUMP((u32)&arm_dispatch);

	armFlushICache(codestart,(void*)EMIT_GET_PTR());
}

//Hook cus varm misses this, so x86 needs special code
void armv_MOV32(eReg regn, u32 imm)
{
	MOV32(regn,imm);
}

/*
	No sanity checks on arm ..
*/

#endif	// HOST_CPU 

//Run a timeslice for ARMREC
//CycleCount is pretty much fixed to (512*32) for now (might change to a diff constant, but will be constant)
void arm_Run(u32 CycleCount)
{
	if (!Arm7Enabled)
		return;

	for (int i=0;i<32;i++)
	{
		arm_mainloop(CycleCount/32, arm_Reg, EntryPoints);
		libAICA_TimeStep();
	}

	/*
	s32 clktks=reg[CYCL_CNT].I+CycleCount;

	//While we have time to spend
	do
	{
		//Check for interrupts
		if (reg[INTR_PEND].I)
		{
			CPUFiq();
		}

		//lookup code at armNextPC, run a block & remove its cycles from the timeslice
		clktks-=EntryPoints[(armNextPC & ARAM_MASK)/4]();
		
		#if HOST_CPU==CPU_X86
			verify(armNextPC<=ARAM_MASK);
		#endif
	} while(clktks>0);

	reg[CYCL_CNT].I=clktks;
	*/
}


#undef r

/*
	TODO:
	R15 read/writing is kind of .. weird
	Gotta investigate why ..
*/

//Mem operand 2 calculation, if Reg or large imm
void MemOperand2(eReg dst,bool I, bool U,u32 offs, u32 opcd)
{
	if (I==true)
	{
		u32 Rm=(opcd>>0)&15;
		verify(CHK_BTS(7,4,0));// only SHL mode
		LoadReg(r1,Rm);
		u32 SA=31&(opcd>>7);
		//can't do shifted add for now -- EMITTER LIMIT --
		if (SA)
			LSL(r1,r1,SA);
	}
	else
	{
		armv_MOV32(r1,offs);
	}

	if (U)
		ADD(dst,r0,r1);
	else
		SUB(dst,r0,r1);
}

template<u32 Pd>
void DYNACALL MSR_do(u32 v)
{
#if HOST_CPU==CPU_X86
	v=virt_arm_reg(r0);
#endif
	if (Pd)
	{
		if(armMode > 0x10 && armMode < 0x1f) /* !=0x10 ?*/
		{
			reg[17].I = (reg[17].I & 0x00FFFF00) | (v & 0xFF0000FF);
		}
	}
	else
	{
		CPUUpdateCPSR();
	
		u32 newValue = reg[16].I;
		if(armMode > 0x10)
		{
			newValue = (newValue & 0xFFFFFF00) | (v & 0x000000FF);
		}

		newValue = (newValue & 0x00FFFFFF) | (v & 0xFF000000);
		newValue |= 0x10;
		if(armMode > 0x10)
		{
			CPUSwitchMode(newValue & 0x1f, false);
		}
		reg[16].I = newValue;
		CPUUpdateFlags();
	}
}

//Compile & run block of code, starting armNextPC
extern "C" void CompileCode()
{
	//Get the code ptr
	void* rv=EMIT_GET_PTR();

	//update the block table
	EntryPoints[(armNextPC&ARAM_MASK)/4]=rv;

	//setup local pc counter
	u32 pc=armNextPC;

	//emitter/block setup
	armv_setup();

	//the ops counter is used to terminate the block (max op count for a single block is 32 currently)
	//We don't want too long blocks for timing accuracy
	u32 ops=0;

	u32 Cycles=0;

	for(;;)
	{
		ops++;

		//Read opcode ...
		u32 opcd=CPUReadMemoryQuick(pc);

#if HOST_CPU==CPU_X86
		//Sanity check: Stale cache
		armv_check_cache(opcd,pc);
#endif

		u32 op_flags;

		//Decode & handle opcode

		OpType opt=DecodeOpcode(opcd,op_flags);

		switch(opt)
		{
		case VOT_DataOp:
			{
				//data processing opcode that can be virtualised
				RenameRegReset();

				/*
				if (op_flags & OP_READS_PC)
					armv_imm_to_reg(15,pc+8);

				else*/
					#if HOST_CPU==CPU_X86
					armv_imm_to_reg(15,rand());
#endif

				VirtualizeOpcode(opcd,op_flags,pc);

#if HOST_CPU==CPU_X86
				armv_imm_to_reg(15,rand());
#endif
			}
			break;
		
		case VOT_BR:
			{
				//Branch to reg
				ConditionCode cc=(ConditionCode)(opcd>>28);

				verify(op_flags&OP_SETS_PC);

				if (cc!=CC_AL)
				{
					LoadFlags();
					armv_imm_to_reg(R15_ARM_NEXT,pc+4);
				}

				LoadReg(r0,opcd&0xF);
				StoreReg(r0,R15_ARM_NEXT,cc);
			}
			break;

		case VOT_B:
		case VOT_BL:
			{
				//Branch to imm

				//<<2, sign extend !
				s32 offs=((s32)opcd<<8)>>6;

				if (op_flags & OP_IS_COND)
				{
					armv_imm_to_reg(R15_ARM_NEXT,pc+4);
					LoadFlags();
					ConditionCode cc=(ConditionCode)(opcd>>28);
					if (opt==VOT_BL)
					{
						armv_MOV32(r0,pc+4);
						StoreReg(r0,14,cc);
					}

					armv_MOV32(r0,pc+8+offs);
					StoreReg(r0,R15_ARM_NEXT,cc);
				}
				else
				{
					if (opt==VOT_BL)
						armv_imm_to_reg(14,pc+4);

					armv_imm_to_reg(R15_ARM_NEXT,pc+8+offs);
				}
			}
			break;

		case VOT_Read:
			{
				//LDR/STR

				u32 offs=opcd&4095;
				bool U=opcd&(1<<23);
				bool Pre=opcd&(1<<24);
				
				bool W=opcd&(1<<21);
				bool I=opcd&(1<<25);
				
				u32 Rn=(opcd>>16)&15;
				u32 Rd=(opcd>>12)&15;

				bool DoWB=W || (!Pre && Rn!=Rd);	//Write back if: W, Post update w/ Rn!=Rd
				bool DoAdd=DoWB || Pre;

				//Register not updated anyway
				if (I==false && offs==0)
				{
					DoWB=false;
					DoAdd=false;
				}

				//verify(Rd!=15);
				verify(!((Rn==15) && DoWB));

				//AGU
				if (Rn!=15)
				{
					LoadReg(r0,Rn);

					if (DoAdd)
					{
						eReg dst=Pre?r0:r9;

						if (I==false && is_i8r4(offs))
						{
							if (U)
								ADD(dst,r0,offs);
							else
								SUB(dst,r0,offs);
						}
						else
						{
							MemOperand2(dst,I,U,offs,opcd);
						}

						if (DoWB && dst==r0)
							MOV(r9,r0);
					}
				}
				else
				{
					u32 addr=pc+8;

					if (Pre && offs && I==false)
					{
						addr+=U?offs:-offs;
					}
					
					armv_MOV32(r0,addr);
					
					if (Pre && I==true)
					{
						MemOperand2(r1,I,U,offs,opcd);
						ADD(r0,r0,r1);
					}
				}

				if (CHK_BTS(1,20,0))
				{
					if (Rd==15)
					{
						armv_MOV32(r1,pc+12);
					}
					else
					{
						LoadReg(r1,Rd);
					}
				}
				//Call handler
				armv_call(GetMemOp(CHK_BTS(1,20,1),CHK_BTS(1,22,1)));

				if (CHK_BTS(1,20,1))
				{
					if (Rd==15)
					{
						verify(op_flags & OP_SETS_PC);
						StoreReg(r0,R15_ARM_NEXT);
					}
					else
					{
						StoreReg(r0,Rd);
					}
				}
				
				//Write back from AGU, if any
				if (DoWB)
				{
					StoreReg(r9,Rn);
				}
			}
			break;

		case VOT_MRS:
			{
				u32 Rd=(opcd>>12)&15;

				armv_call((void*)&CPUUpdateCPSR);

				if (opcd & (1<<22))
				{
					LoadReg(r0,17);
				}
				else
				{
					LoadReg(r0,16);
				}

				StoreReg(r0,Rd);
			}
			break;

		case VOT_MSR:
			{
				u32 Rm=(opcd>>0)&15;

				LoadReg(r0,Rm);
				if (opcd & (1<<22))
					armv_call((void*)(void (DYNACALL*)(u32))&MSR_do<1>);
				else
					armv_call((void*)(void (DYNACALL*)(u32))&MSR_do<0>);

				if (op_flags & OP_SETS_PC)
					armv_imm_to_reg(R15_ARM_NEXT,pc+4);
			}
			break;
		/*
		//LDM is disabled for now
		//Common cases of LDM/STM are converted to STR/LDR (tsz==1)
		//Other cases are very uncommon and not worth implementing
		case VOT_LDM:
			{
				//P=0, U=1, S=0, L=1, W=1
				
				u32 Rn=(opcd>>16)&15;
				u32 RList=opcd&0xFFFF;
				u32 tsz=(cpuBitsSet[RList & 255] + cpuBitsSet[(RList >> 8) & 255]);

				verify(CHK_BTS(1,24,0)); //P=0
				verify(CHK_BTS(1,23,1)); //U=1
				verify(CHK_BTS(1,22,0)); //S=0
				verify(CHK_BTS(1,21,1)); //W=1
				verify(CHK_BTS(1,20,1)); //L=0

				
				//if (tsz!=1)
				//	goto FALLBACK;

				bool _W=true; //w=1
				

				if (RList & (1<<Rn))
					_W=false;

				bool _AGU=_W; // (w=1 && p=0) || p=1 (P=0)

				LoadReg(r0,Rn);
				if (_AGU)
				{
					ADD(r9,r0,tsz*4);
				}
				armv_MOV32(r1,RList);
				armv_call((void*)(u32(DYNACALL*)(u32,u32))&DoLDM<0>);

				if (_W)
				{
					StoreReg(r9,Rn);
				}
			}
			break;
			*/
			
		case VOT_Fallback:
			{
				//interpreter fallback

				//arm_single_op needs PC+4 on r15
				//TODO: only write it if needed -> Probably not worth the code, very few fallbacks now...
				armv_imm_to_reg(15,pc+8);

				//For cond branch, MSR
				if (op_flags & OP_SETS_PC)
					armv_imm_to_reg(R15_ARM_NEXT,pc+4);

				#if HOST_CPU==CPU_X86
					if ( !(op_flags & OP_SETS_PC) )
						armv_imm_to_reg(R15_ARM_NEXT,pc+4);
				#endif

				armv_intpr(opcd);

#if HOST_CPU==CPU_X86
				if ( !(op_flags & OP_SETS_PC) )
				{
					//Sanity check: next pc
					armv_check_pc(pc+4);
#if 0
					x86e->Emit(op_mov32,ECX,opcd);
					x86e->Emit(op_call,x86_ptr_imm(PrintOp));
#endif
				}
#endif
			}
			break;

		default:
			die("can't happen\n");
		}

		//Lets say each opcode takes 9 cycles for now ..
		Cycles+=9;

#if HOST_CPU==CPU_X86
		armv_imm_to_reg(15,0xF87641FF);

		armv_prof(opt,opcd,op_flags);
#endif

		//Branch ?
		if (op_flags & OP_SETS_PC)
		{
			//x86e->Emit(op_call,x86_ptr_imm(DumpRegs)); // great debugging tool
			arm_printf("ARM: %06X: Block End %d\n",pc,ops);

#if HOST_CPU==CPU_X86 && 0
			//Great fallback finder, also spams console
			if (opt==VOT_Fallback)
			{
				x86e->Emit(op_mov32,ECX,opcd);
				x86e->Emit(op_call,x86_ptr_imm(PrintOp));
			}
#endif
			break;
		}

		//block size limit ?
		if (ops>32)
		{
			arm_printf("ARM: %06X: Block split %d\n",pc,ops);

			armv_imm_to_reg(R15_ARM_NEXT,pc+4);
			break;
		}
		
		//Goto next opcode
		pc+=4;
	}

	armv_end((void*)rv,Cycles);
}



void FlushCache()
{
	icPtr=ICache;
	for (u32 i=0;i<ARAM_SIZE/4;i++)
		EntryPoints[i]=(void*)&arm_compilecode;
}



#if HOST_CPU==CPU_X86 && HOST_OS == OS_WINDOWS

#include <Windows.h>

// These have to be declared somewhere or linker dies
u8* ARM::emit_opt=0;
eReg ARM::reg_addr;
eReg ARM::reg_dst;
s32 ARM::imma;

void armEmit32(u32 emit32)
{
	if (icPtr >= (ICache + ICacheSize - 64*1024)) {
		die("ICache is full, invalidate old entries ...");	//ifdebug
	}

	x86e->Emit(op_mov32,ECX,emit32);
	x86e->Emit(op_call,x86_ptr_imm(virt_arm_op));
}


void *armGetEmitPtr()
{
	return icPtr;
}

#endif


void armt_init()
{
	InitHash();

	//align to next page ..
	ICache = (u8*)(((unat)ARM7_TCB+4095)& ~4095);

	#if HOST_OS==OS_DARWIN
		//Can't just mprotect on iOS
		munmap(ICache, ICacheSize);
		ICache = (u8*)mmap(ICache, ICacheSize, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_FIXED | MAP_PRIVATE | MAP_ANON, 0, 0);
	#endif

#if HOST_OS == OS_WINDOWS
	DWORD old;
	VirtualProtect(ICache,ICacheSize,PAGE_EXECUTE_READWRITE,&old);
#elif HOST_OS == OS_LINUX || HOST_OS == OS_DARWIN

	printf("\n\t ARM7_TCB addr: %p | from: %p | addr here: %p\n", ICache, ARM7_TCB, armt_init);

	if (mprotect(ICache, ICacheSize, PROT_EXEC|PROT_READ|PROT_WRITE))
	{
		perror("\n\tError - Couldn’t mprotect ARM7_TCB!");
		verify(false);
	}

#if defined(TARGET_IPHONE) || defined(TARGET_IPHONE_SIMULATOR)
	memset((u8*)mmap(ICache, ICacheSize, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_FIXED | MAP_PRIVATE | MAP_ANON, 0, 0),0xFF,ICacheSize);
#else
	memset(ICache,0xFF,ICacheSize);
#endif

#endif

	icPtr=ICache;
}


#endif
