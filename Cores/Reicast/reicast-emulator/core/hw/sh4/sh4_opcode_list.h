#pragma once
#include "types.h"
#include "sh4_interpreter.h"
//#include "dc\sh4\rec_v1\BasicBlock.h"

//class BasicBlock;
//typedef void (FASTCALL RecOpCallFP) (u32 op,u32 pc,BasicBlock* bb);

extern OpCallFP* OpPtr[0x10000];

typedef void OpDissasmFP(char* out,const char* const FormatString,u32 pc,u16 opcode);

enum sh4_eu
{
	MT,
	EX,
	BR,
	LS,
	FE,
	CO,
	MA,
	sh4_eu_max
};

//exception fixup needed , added it to fix exception on opcodes that modify before exept :)
enum sh4_exept_fixup
{
	fix_none,
	rn_opt_1,    //1 if n!=m
	rn_opt_2,    //2 if n!=m
	rn_opt_4,    //4 if n!=m
	rn_4,        //Always 4 from rn
	rn_fpu_4,    //4 or 8, according to FPU size
};
typedef void ( RecOpCallFP) (u32 op);
struct sh4_opcodelistentry
{
	RecOpCallFP* rec_oph;
	OpCallFP* oph;
	u32 mask;
	u32 rez;
	u32 type;
	const char* diss;
	u8 IssueCycles;
	u8 LatencyCycles;
	sh4_eu unit;
	sh4_exept_fixup ex_fixup;
	u64 decode;
	u64 fallbacks;
	void Dissasemble(char* strout,u32 pc , u16 params) const
	{
		sprintf(strout,"%s:%08X:%04X",diss,pc,params);
	}

	INLINE bool SetPC() const
	{
		return (type & WritesPC)!=0;
	}

	INLINE bool NeedPC() const
	{
		return (type & ReadsPC)!=0;
	}

	INLINE bool SetSR() const
	{
		return (type & WritesSR)!=0;
	}

	INLINE bool SetFPSCR() const
	{
		return (type & WritesFPSCR)!=0;
	}

};

extern sh4_opcodelistentry* OpDesc[0x10000];
extern sh4_opcodelistentry opcodes[];
#define ExecuteOpcode(op) {OpPtr[op](op);}

void DissasembleOpcode(u16 opcode,u32 pc,char* Dissasm);
enum DecParam
{
	// Constants
	PRM_PC_D8_x2,
	PRM_PC_D8_x4,
	PRM_ZERO,
	PRM_ONE,
	PRM_TWO,
	PRM_TWO_INV,
	PRM_ONE_F32,
	
	// imms
	PRM_SIMM8,
	PRM_UIMM8,

	// Direct registers
	PRM_R0,
	PRM_RN,
	PRM_RM,
	PRM_FRN,
	PRM_FRN_SZ, //single/double, selected bank
	PRM_FRM,
	PRM_FRM_SZ,
	PRM_FPN,    //float pair, 3 bits
	PRM_FVN,    //float quad, 2 bits
	PRM_FVM,    //float quad, 2 bits
	PRM_XMTRX,  //float matrix, 0 bits
	PRM_FRM_FR0,
	PRM_FPUL,
	PRM_SR_T,
	PRM_SR_STATUS,

	PRM_SREG,   //FPUL/FPSCR/MACH/MACL/PR/DBR/SGR
	PRM_CREG,   //SR/GBR/VBR/SSR/SPC/<RM_BANK>
	
	//reg/imm reg/reg
	PRM_RN_D4_x1,
	PRM_RN_D4_x2,
	PRM_RN_D4_x4,
	PRM_RN_R0,

	PRM_RM_R0,
	PRM_RM_D4_x1,
	PRM_RM_D4_x2,
	PRM_RM_D4_x4,

	PRM_GBR_D8_x1,
	PRM_GBR_D8_x2,
	PRM_GBR_D8_x4,
};

enum DecMode
{
	DM_ReadSRF,
	DM_BinaryOp,    //d=d op s
	DM_UnaryOp,     //d= op s
	DM_ReadM,       //d=readm(s);s+=e
	DM_WriteM,      //s-=e;writem(s,d);
	DM_fiprOp,
	DM_WriteTOp,    //T=d op s
	DM_DT,          //special case for dt
	DM_Shift,
	DM_Rot,
	DM_EXTOP,
	DM_MUL,
	DM_DIV0,
	DM_ADC,
};
