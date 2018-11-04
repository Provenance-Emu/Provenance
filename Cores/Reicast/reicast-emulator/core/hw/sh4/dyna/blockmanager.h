/*
	In case you wonder, the extern "C" stuff are for the assembly code on beagleboard/pandora
*/
#include "types.h"
#include "decoder.h"
#pragma once

typedef void (*DynarecCodeEntryPtr)();

struct RuntimeBlockInfo_Core
{
	u32 addr;
	DynarecCodeEntryPtr code;
	u32 lookups;
};

struct RuntimeBlockInfo: RuntimeBlockInfo_Core
{
	void Setup(u32 pc,fpscr_t fpu_cfg);
	const char* hash(bool full=true, bool reloc=false);

	u32 host_code_size;	//in bytes
	u32 sh4_code_size; //in bytes

	u32 runs;
	s32 staging_runs;

	/*
		
	*/
	fpscr_t fpu_cfg;
	u32 guest_cycles;
	u32 guest_opcodes;
	u32 host_opcodes;


	u32 BranchBlock; //if not 0xFFFFFFFF then jump target
	u32 NextBlock;   //if not 0xFFFFFFFF then next block (by position)

	//0 if not available
	RuntimeBlockInfo* pBranchBlock;
	RuntimeBlockInfo* pNextBlock; 

	u32 relink_offset;
	u32 relink_data;
	u32 csc_RetCache; //only for stats for now

	BlockEndType BlockType;
	bool has_jcond;

	vector<shil_opcode> oplist;

	bool contains_code(u8* ptr)
	{
		return ((unat)(ptr-(u8*)code))<host_code_size;
	}

	virtual ~RuntimeBlockInfo();

	virtual u32 Relink()=0;
	virtual void Relocate(void* dst)=0;
	
	//predecessors references
	vector<RuntimeBlockInfo*> pre_refs;

	void AddRef(RuntimeBlockInfo* other);
	void RemRef(RuntimeBlockInfo* other);

	void Discard();
	void UpdateRefs();

	u32 memops;
	u32 linkedmemops;
};

struct CachedBlockInfo: RuntimeBlockInfo_Core
{
	RuntimeBlockInfo* block;
};

void bm_WriteBlockMap(const string& file);


DynarecCodeEntryPtr DYNACALL bm_GetCode(u32 addr);


#if HOST_OS==OS_LINUX
extern "C" {
#endif
DynarecCodeEntryPtr DYNACALL bm_GetCode2(u32 addr);
#if HOST_OS==OS_LINUX
}
#endif

RuntimeBlockInfo* bm_GetBlock(void* dynarec_code);
RuntimeBlockInfo* bm_GetStaleBlock(void* dynarec_code);
RuntimeBlockInfo* DYNACALL bm_GetBlock(u32 addr);

void bm_AddBlock(RuntimeBlockInfo* blk);
void bm_Reset();
void bm_Periodical_1s();
void bm_Periodical_14k();
void bm_Sort();

void bm_Init();
void bm_Term();

void bm_vmem_pagefill(void** ptr,u32 PAGE_SZ);
