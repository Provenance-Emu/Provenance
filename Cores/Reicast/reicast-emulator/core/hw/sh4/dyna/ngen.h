/*
	Header file for native generator interface
	Needs some cleanup


	SH4 -> Code gen -> Ram

	Ram -> link/relocate -> Staging buffer
	Ram -> link/relocate -> Steady-state buffer

	Staging      : scratch, relatively small, circular code buffer
	Steady state : 'final' code buffer. When blocks reach a steady-state, they get copied here

	When the Staging buffer is full, a reset is done on the dynarec.
	If the stating buffer is full, but re-locating everything will free enough space, it will be relocated (GC'd)

	If the stating buffer is full, then blocks in it are put into "hibernation"

	Block can be
	in Ram, only ('hibernated')
	in Ram + steady state buffer
	in Ram + staging buffer

	Changes required on the ngen/dynarecs for this to work

	- Support relocation
	- Support re-linking
	- Support hibernated blocks, or block removal

	Changes on BM

	- Block graph
	- Block removal
	- Relocation driving logic


	This will enable

	- Extensive block specialisation (Further mem opts, other things that might gain)
	- Possibility of superblock chains
*/

#pragma once
#include "rec_config.h"
#include "decoder.h"
#include "blockmanager.h"


#define CODE_SIZE   (6*1024*1024)


//alternative emit ptr, set to 0 to use the main buffer
extern u32* emit_ptr;
extern u8* CodeCache;

#if HOST_OS==OS_LINUX || HOST_OS==OS_DARWIN
extern "C" {
#endif

void emit_Write32(u32 data);
void emit_Skip(u32 sz);
u32 emit_FreeSpace();
void* emit_GetCCPtr();
void emit_SetBaseAddr();

//Called from ngen_FailedToFindBlock
DynarecCodeEntryPtr DYNACALL rdv_FailedToFindBlock(u32 pc);
//Called when a block check failed, and the block needs to be invalidated
DynarecCodeEntryPtr DYNACALL rdv_BlockCheckFail(u32 pc);
//Called to compile code @pc
DynarecCodeEntryPtr rdv_CompilePC();
//Returns 0 if there is no code @pc, code ptr otherwise
DynarecCodeEntryPtr rdv_FindCode();
//Finds or compiles code @pc
DynarecCodeEntryPtr rdv_FindOrCompile();

//code -> pointer to code of block, dpc -> if dynamic block, pc. if cond, 0 for next, 1 for branch
void* DYNACALL rdv_LinkBlock(u8* code,u32 dpc);

u32 DYNACALL rdv_DoInterrupts(void* block_cpde);
u32 DYNACALL rdv_DoInterrupts_pc(u32 pc);

//Stuff to be implemented per dynarec core

void ngen_init();

//Called to compile a block
void ngen_Compile(RuntimeBlockInfo* block,bool force_checks, bool reset, bool staging,bool optimise);

//Called when blocks are reseted
void ngen_ResetBlocks();
//Value to be returned when the block manager failed to find a block,
//should call rdv_FailedToFindBlock and then jump to the return value
extern void (*ngen_FailedToFindBlock)();
//the dynarec mainloop
void ngen_mainloop(void* cntx);
//ngen features
struct ngen_features
{
	bool OnlyDynamicEnds;     //if set the block endings aren't handled natively and only Dynamic block end type is used
	bool InterpreterFallback; //if set all the non-branch opcodes are handled with the ifb opcode
};

void ngen_GetFeatures(ngen_features* dst);

//Canonical callback interface
enum CanonicalParamType
{
	CPT_u32,
	CPT_u32rv,
	CPT_u64rvL,
	CPT_u64rvH,
	CPT_f32,
	CPT_f32rv,
	CPT_ptr,
};

void ngen_CC_Start(shil_opcode* op);
void ngen_CC_Param(shil_opcode* op,shil_param* par,CanonicalParamType tp);
void ngen_CC_Call(shil_opcode* op,void* function);
void ngen_CC_Finish(shil_opcode* op);

RuntimeBlockInfo* ngen_AllocateBlock();

#if HOST_OS==OS_LINUX || HOST_OS==OS_DARWIN
}
#endif
