#pragma once
#include "types.h"
#include "hw/sh4/sh4_mmr.h"

struct TLB_Entry
{
	CCN_PTEH_type Address;
	CCN_PTEL_type Data;
};

extern TLB_Entry UTLB[64];
extern TLB_Entry ITLB[4];
extern u32 sq_remap[64];

//These are working only for SQ remaps on ndce
bool UTLB_Sync(u32 entry);
void ITLB_Sync(u32 entry);

bool mmu_match(u32 va, CCN_PTEH_type Address, CCN_PTEL_type Data);

#if defined(NO_MMU)
	bool inline mmu_TranslateSQW(u32 addr, u32* mapped) {
		*mapped = sq_remap[(addr>>20)&0x3F] | (addr & 0xFFFE0);
		return true;
	}
#else
	u8 DYNACALL mmu_ReadMem8(u32 addr);
	u16 DYNACALL mmu_ReadMem16(u32 addr);
	u16 DYNACALL mmu_IReadMem16(u32 addr);
	u32 DYNACALL mmu_ReadMem32(u32 addr);
	u64 DYNACALL mmu_ReadMem64(u32 addr);

	void DYNACALL mmu_WriteMem8(u32 addr, u8 data);
	void DYNACALL mmu_WriteMem16(u32 addr, u16 data);
	void DYNACALL mmu_WriteMem32(u32 addr, u32 data);
	void DYNACALL mmu_WriteMem64(u32 addr, u64 data);
	
	bool mmu_TranslateSQW(u32 addr, u32* mapped);
#endif
