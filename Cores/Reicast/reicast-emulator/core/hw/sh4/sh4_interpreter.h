#pragma once
#include "types.h"
#include "sh4_if.h"

#undef sh4op
#define sh4op(str) void  DYNACALL str (u32 op)
typedef void (DYNACALL OpCallFP) (u32 op);

enum OpcodeType
{
	//basic
	Normal       = 0,   // Heh , nothing special :P
	ReadsPC      = 1,   // PC must be set upon calling it
	WritesPC     = 2,   // It will write PC (branch)
	Delayslot    = 4,   // Has a delayslot opcode , valid only when WritesPC is set

	WritesSR     = 8,   // Writes to SR , and UpdateSR needs to be called
	WritesFPSCR  = 16,  // Writes to FPSCR , and UpdateSR needs to be called
	Invalid      = 128, // Invalid

	NO_FP        = 256,
	NO_GP        = 512,
	NO_SP        = 1024,

	// Heh, not basic :P
	ReadWritePC  = ReadsPC|WritesPC,     // Read and writes pc :P
	WritesSRRWPC = WritesSR|ReadsPC|WritesPC,

	// Branches (not delay slot):
	Branch_dir   = ReadWritePC,          // Direct (eg , pc=r[xx]) -- this one is ReadWritePC b/c the delayslot may use pc ;)
	Branch_rel   = ReadWritePC,          // Relative (rg pc+=10);

	// Delay slot
	Branch_dir_d = Delayslot|Branch_dir, // Direct (eg , pc=r[xx])
	Branch_rel_d = Delayslot|Branch_rel, // Relative (rg pc+=10);
};

//interface
void Sh4_int_Run();
void Sh4_int_Stop();
void Sh4_int_Step();
void Sh4_int_Skip();
void Sh4_int_Reset(bool Manual);
void Sh4_int_Init();
void Sh4_int_Term();
bool Sh4_int_IsCpuRunning();
void sh4_int_RaiseExeption(u32 ExeptionCode,u32 VectorAddr);
u32 Sh4_int_GetRegister(Sh4RegType reg);
void Sh4_int_SetRegister(Sh4RegType reg,u32 regdata);
//Other things (mainly used by the cpu core
void ExecuteDelayslot();
void ExecuteDelayslot_RTE();


#if HOST_OS==OS_LINUX || HOST_OS==OS_DARWIN
extern "C" {
#endif

int UpdateSystem();
int UpdateSystem_INTC();

#if HOST_OS==OS_LINUX || HOST_OS==OS_DARWIN
}
#endif