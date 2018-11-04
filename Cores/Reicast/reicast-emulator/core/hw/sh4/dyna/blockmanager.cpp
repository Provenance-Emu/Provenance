/*
	Tiny cute block manager. Doesn't keep block graphs or anything fancy ...
	Its based on a simple hashed-lists idea
*/

#include <algorithm>
#include "blockmanager.h"
#include "ngen.h"

#include "../sh4_interpreter.h"
#include "../sh4_opcode_list.h"
#include "../sh4_core.h"
#include "../sh4_if.h"
#include "hw/pvr/pvr_mem.h"
#include "hw/aica/aica_if.h"
//#include "../dmac.h"
#include "hw/gdrom/gdrom_if.h"
//#include "../intc.h"
//#include "../tmu.h"
#include "hw/sh4/sh4_mem.h"


#if HOST_OS==OS_LINUX && defined(DYNA_OPROF)
#include <opagent.h>
op_agent_t          oprofHandle;
#endif

#if FEAT_SHREC != DYNAREC_NONE


typedef vector<RuntimeBlockInfo*> bm_List;

#define BLOCKS_IN_PAGE_LIST_COUNT (RAM_SIZE/4096)
bm_List blocks_page[BLOCKS_IN_PAGE_LIST_COUNT];

bm_List all_blocks;
bm_List del_blocks;
#include <set>

struct BlockMapCMP
{
	static bool is_code(RuntimeBlockInfo* blk)
	{
		if ((unat)((u8*)blk-CodeCache)<CODE_SIZE)
			return true;
		else
			return false;
	}

	static unat get_blkstart(RuntimeBlockInfo* blk)
	{
		if (is_code(blk)) 
			return (unat)blk; 
		else 
			return (unat)blk->code;
	}

	static unat get_blkend(RuntimeBlockInfo* blk)
	{
		if (is_code(blk)) 
			return (unat)blk; 
		else 
			return (unat)blk->code+blk->host_code_size-1;
	}

	//return true if blkl > blkr
	bool operator()(RuntimeBlockInfo* blkl, RuntimeBlockInfo* blkr) const
	{
		if (!is_code(blkl) && !is_code(blkr))
			return (unat)blkl->code<(unat)blkr->code;

		unat blkr_start=get_blkstart(blkr),blkl_end=get_blkend(blkl);

		if (blkl_end<blkr_start)
		{
			return true;
		}
		else
		{
			return false;
		}
	}
};

typedef std::set<RuntimeBlockInfo*,BlockMapCMP> blkmap_t;
blkmap_t blkmap;
u32 bm_gc_luc,bm_gcf_luc;


#define FPCA(x) ((DynarecCodeEntryPtr&)sh4rcb.fpcb[(x>>1)&FPCB_MASK])

DynarecCodeEntryPtr DYNACALL bm_GetCode(u32 addr)
{
	//rdv_FailedToFindBlock_pc=addr;
	DynarecCodeEntryPtr rv=(DynarecCodeEntryPtr)FPCA(addr);

	return (DynarecCodeEntryPtr)rv;
}

DynarecCodeEntryPtr DYNACALL bm_GetCode2(u32 addr)
{
	return (DynarecCodeEntryPtr)bm_GetCode(addr);
}

RuntimeBlockInfo* DYNACALL bm_GetBlock(u32 addr)
{
	DynarecCodeEntryPtr cde=bm_GetCode(addr);

	if (cde==ngen_FailedToFindBlock)
		return 0;
	else
		return bm_GetBlock((void*)cde);
}

RuntimeBlockInfo* bm_GetBlock(void* dynarec_code)
{
	blkmap_t::iterator iter=blkmap.find((RuntimeBlockInfo*)dynarec_code);
	if (iter!=blkmap.end())
	{
		verify((*iter)->contains_code((u8*)dynarec_code));
		return *iter;
	}
	else
	{
		printf("bm_GetBlock(%8s) failed ..\n",dynarec_code);
		return 0;
	}
}

RuntimeBlockInfo* bm_GetStaleBlock(void* dynarec_code)
{
	for(u32 i=0;i<del_blocks.size();i++)
	{
		if (del_blocks[i]->contains_code((u8*)dynarec_code))
			return del_blocks[i];
	}

	return 0;
}

void bm_AddBlock(RuntimeBlockInfo* blk)
{
	/*
	if (IsOnRam(blk->addr) && PageIsConst(blk->addr))
	{
		blocks_page[(blk->addr&RAM_MASK)/PAGE_SIZE].push_back(blk);
	}
	*/
	all_blocks.push_back(blk);
	if (blkmap.find(blk)!=blkmap.end())
	{
		printf("DUP: %08X %08X %08X %08X\n", (*blkmap.find(blk))->addr,(*blkmap.find(blk))->code,blk->addr,blk->code);
		verify(false);
	}
	blkmap.insert(blk);


	verify((void*)bm_GetCode(blk->addr)==(void*)ngen_FailedToFindBlock);
	FPCA(blk->addr)=blk->code;

#ifdef DYNA_OPROF
	if (oprofHandle)
	{
		char fname[512];

		sprintf(fname,"sh4:%08X,c:%d,s:%d,h:%d",blk->addr,blk->guest_cycles,blk->guest_opcodes,blk->host_opcodes);

		if (op_write_native_code(oprofHandle, fname, (uint64_t)blk->code, (void*)blk->code, blk->host_code_size) != 0) 
		{
			printf("op_write_native_code error\n");
		}
	}
#endif

}

u32 PAGE_STATE[RAM_SIZE/32];

bool PageIsConst(u32 addr)
{
	if (IsOnRam(addr))
	{
		addr&=RAM_MASK;
		if (addr>0x0010100)
		{
			return PAGE_STATE[addr/32]&(1<<addr);
		}
	}

	return false;
}

bool UDgreaterX ( RuntimeBlockInfo* elem1, RuntimeBlockInfo* elem2 )
{	
	return elem1->runs > elem2->runs;
}

bool UDgreaterLOC ( RuntimeBlockInfo* elem1, RuntimeBlockInfo* elem2 )
{	
	return elem1->addr < elem2->addr;
}

u32 FindPath(RuntimeBlockInfo* rbi, u32 sa,s32 mc,u32& plc)
{
	if (mc < 0 || rbi==0)
		return 0;

	plc++;
	if (rbi->BlockType==BET_Cond_0 || rbi->BlockType==BET_Cond_1)
	{
		u32 plc1=plc,plc2=plc,v1=0,v2=0;
		if (rbi->BranchBlock>sa)
		{
			v1=FindPath(bm_GetBlock(rbi->BranchBlock),rbi->addr,mc-rbi->guest_cycles,plc1);
		}
		v2=FindPath(bm_GetBlock(rbi->NextBlock),rbi->addr,mc-rbi->guest_cycles,plc2);
		if (plc1>plc2)
		{
			plc=plc1;
			return rbi->guest_cycles+v1;
		}
		else
		{
			plc=plc2;
			return rbi->guest_cycles+v2;
		}
		
	}
	else if (rbi->BlockType==BET_StaticJump)
	{
		if (rbi->BranchBlock>sa)
			return rbi->guest_cycles+FindPath(bm_GetBlock(rbi->BranchBlock),rbi->addr,mc-rbi->guest_cycles,plc);
		else
		{
			return rbi->guest_cycles;
		}
	}
	else
	{
		if (plc!=1)
			printf("Chain lost due to %d\n",rbi->BlockType);
		else
			printf("Chain fail due to %d\n",rbi->BlockType);
		return rbi->guest_cycles;
	}
}
u32 total_saved;
void FindPath(u32 start)
{
	RuntimeBlockInfo* rbi=bm_GetBlock(start);

	if (!rbi || !rbi->runs)
		return;

	u32 plen=0;
	u32 pclc=FindPath(rbi,start,SH4_TIMESLICE,plen);
	if (plen>1)
	{
		total_saved+=(plen-1)*2*rbi->runs;
		printf("%08X: %d, %d, %.2f, %.2f\n",start,pclc,plen,pclc/(float)plen,plen*2*rbi->runs/1000.f);
	}
	rbi->runs=0;
}

#include <map>
u32 rebuild_counter=20;
void bm_Periodical_1s()
{
	for (u32 i=0;i<del_blocks.size();i++)
		delete del_blocks[i];

	del_blocks.clear();

	if (rebuild_counter>0) rebuild_counter--;
#if HOST_OS==OS_WINDOWS && 0
	std::sort(all_blocks.begin(),all_blocks.end(),UDgreaterX);

	map<u32,u32> vmap;
	map<u32,u32> calls;

	u32 total_runs=0;
	for(int i=0;i<all_blocks.size();i++)
	{
		RuntimeBlockInfo* rbi=all_blocks[i];
		total_runs+=rbi->runs;
		if (rbi->BranchBlock!=-1 && rbi->BranchBlock < rbi->addr)
		{
			if (rbi->BlockType==BET_Cond_0 || rbi->BlockType==BET_Cond_1 || rbi->BlockType==BET_StaticJump)
			{
				RuntimeBlockInfo* bbi=bm_GetBlock(all_blocks[i]->BranchBlock);
				if (bbi && bbi->runs)
				{
					vmap[all_blocks[i]->BranchBlock]=bbi->runs;
				}
			}

			if (rbi->BlockType==BET_StaticCall)
			{
				RuntimeBlockInfo* bbi=bm_GetBlock(all_blocks[i]->BranchBlock);
				if (bbi && bbi->runs)
				{
					calls[all_blocks[i]->BranchBlock]+=rbi->runs;
				}
			}
		}
		verify(rbi->NextBlock>rbi->addr);
	}

	map<u32,u32>::iterator iter=vmap.begin();

	total_saved=0;
	u32 total_l_runs=0;
	while(iter!=vmap.end())
	{
		FindPath(iter->first);
		total_l_runs+=iter->second;
		iter++;
	}

	for(int i=0;i<all_blocks.size();i++)
		all_blocks[i]->runs=0;

	printf("Total Saved: %.2f || Total Loop Runs: %.2f  || Total Runs: %.2f\n",total_saved/1000.f,total_l_runs/1000.f,total_runs/1000.f);
#endif
}

void constprop(RuntimeBlockInfo* blk);
void bm_Rebuild()
{
	return;

	void RASDASD();
	RASDASD();

	blkmap.clear();
	
	std::sort(all_blocks.begin(),all_blocks.end(),UDgreaterLOC);
	
	for(size_t i=0; i<all_blocks.size(); i++)
	{
		bool do_opts=((all_blocks[i]->addr&0x3FFFFFFF)>0x0C010100);

		if (all_blocks[i]->staging_runs<0 && do_opts)
		{
//#if HOST_OS==OS_WINDOWS
			//constprop(all_blocks[i]);
//#endif
		}
		ngen_Compile(all_blocks[i],false,false,all_blocks[i]->staging_runs>0,do_opts);

		blkmap.insert(all_blocks[i]);
		verify(bm_GetBlock((RuntimeBlockInfo*)all_blocks[i]->code)==all_blocks[i]);

		FPCA(all_blocks[i]->addr)=all_blocks[i]->code;
	}

	for(size_t i=0; i<all_blocks.size(); i++)
	{
		all_blocks[i]->Relink();
	}

	rebuild_counter=30;
}

void bm_vmem_pagefill(void** ptr,u32 PAGE_SZ)
{
	for (size_t i=0; i<PAGE_SZ/sizeof(ptr[0]); i++)
	{
		ptr[i]=(void*)ngen_FailedToFindBlock;
	}
}

void bm_Reset()
{
	ngen_ResetBlocks();
	for (u32 i=0; i<BLOCKS_IN_PAGE_LIST_COUNT; i++)
	{
		blocks_page[i].clear();
	}

	_vmem_bm_reset();

	for (size_t i=0; i<all_blocks.size(); i++)
	{
		all_blocks[i]->relink_data=0;
		all_blocks[i]->pNextBlock=0;
		all_blocks[i]->pBranchBlock=0;
		all_blocks[i]->Relink();
	}

	del_blocks.insert(del_blocks.begin(),all_blocks.begin(),all_blocks.end());

	all_blocks.clear();
	blkmap.clear();

#ifdef DYNA_OPROF
	if (oprofHandle)
	{
		for (int i=0;i<del_blocks.size();i++)
		{
			if (op_unload_native_code(oprofHandle, (uint64_t)del_blocks[i]->code) != 0)
			{
				printf("op_unload_native_code error\n");
			}
		}
	}
#endif
}


void bm_Init()
{

#ifdef DYNA_OPROF
	oprofHandle=op_open_agent();
	if (oprofHandle==0)
		printf("bm: Failed to open oprofile\n");
	else
		printf("bm: Oprofile integration enabled !\n");
#endif
}

void bm_Term()
{
#ifdef DYNA_OPROF
	if (oprofHandle) op_close_agent(oprofHandle);
	
	oprofHandle=0;
#endif
}

void bm_WriteBlockMap(const string& file)
{
	FILE* f=fopen(file.c_str(),"wb");
	if (f)
	{
		printf("Writing block map !\n");
		for (size_t i=0; i<all_blocks.size(); i++)
		{
			fprintf(f,"block: %d:%08X:%08X:%d:%d:%d\n",all_blocks[i]->BlockType,all_blocks[i]->addr,all_blocks[i]->code,all_blocks[i]->host_code_size,all_blocks[i]->guest_cycles,all_blocks[i]->guest_opcodes);
			for(size_t j=0;j<all_blocks[i]->oplist.size();j++)
				fprintf(f,"\top: %d:%d:%s\n",j,all_blocks[i]->oplist[j].guest_offs,all_blocks[i]->oplist[j].dissasm().c_str());
		}
		fclose(f);
		printf("Finished writing block map\n");
	}
}

u32 GetLookup(RuntimeBlockInfo* elem)
{
	return elem->lookups;
}

bool UDgreater ( RuntimeBlockInfo* elem1, RuntimeBlockInfo* elem2 )
{
	return elem1->runs > elem2->runs;
}

bool UDgreater2 ( RuntimeBlockInfo* elem1, RuntimeBlockInfo* elem2 )
{
	return elem1->runs*elem1->host_opcodes > elem2->runs*elem2->host_opcodes;
}

bool UDgreater3 ( RuntimeBlockInfo* elem1, RuntimeBlockInfo* elem2 )
{
	return elem1->runs*elem1->host_opcodes/elem1->guest_cycles > elem2->runs*elem2->host_opcodes/elem2->guest_cycles;
}

void sh4_jitsym(FILE* out)
{
	for (size_t i=0; i<all_blocks.size(); i++)
	{
		fprintf(out,"%08p %d %08X\n",all_blocks[i]->code,all_blocks[i]->host_code_size,all_blocks[i]->addr);
	}
}

void bm_PrintTopBlocks()
{
	double total_lups=0;
	double total_runs=0;
	double total_cycles=0;
	double total_hops=0;
	double total_sops=0;

	for (size_t i=0;i<all_blocks.size();i++)
	{
		total_lups+=GetLookup(all_blocks[i]);
		total_cycles+=all_blocks[i]->runs*all_blocks[i]->guest_cycles;
		total_hops+=all_blocks[i]->runs*all_blocks[i]->host_opcodes;
		total_sops+=all_blocks[i]->runs*all_blocks[i]->guest_opcodes;
		total_runs+=all_blocks[i]->runs;
	}

	printf("Total lookups:  %.0fKRuns, %.0fKLuops, Total cycles: %.0fMhz, Total Hops: %.0fMips, Total Sops: %.0fMips! \n",total_runs/1000,total_lups/1000,total_cycles/1000/1000,total_hops/1000/1000,total_sops/1000/1000);
	total_hops/=100;
	total_cycles/=100;
	total_runs/=100;

	double sel_hops=0;
	for (size_t i=0;i<(all_blocks.size()/100);i++)
	{
		printf("Block %08X: %06X, r: %d (c: %d, s: %d, h: %d) (r: %.2f%%, c: %.2f%%, h: %.2f%%)\n",
			all_blocks[i]->addr, all_blocks[i]->code,all_blocks[i]->runs,
			all_blocks[i]->guest_cycles,all_blocks[i]->guest_opcodes,all_blocks[i]->host_opcodes,

			all_blocks[i]->runs/total_runs,
			all_blocks[i]->guest_cycles*all_blocks[i]->runs/total_cycles,
			all_blocks[i]->host_opcodes*all_blocks[i]->runs/total_hops);
		
		sel_hops+=all_blocks[i]->host_opcodes*all_blocks[i]->runs;
	}

	printf(" >-< %.2f%% covered in top 1%% blocks\n",sel_hops/total_hops);

	size_t i;
	for (i=all_blocks.size()/100;sel_hops/total_hops<50;i++)
	{
		printf("Block %08X: %06X, r: %d (c: %d, s: %d, h: %d) (r: %.2f%%, c: %.2f%%, h: %.2f%%)\n",
			all_blocks[i]->addr, all_blocks[i]->code,all_blocks[i]->runs,
			all_blocks[i]->guest_cycles,all_blocks[i]->guest_opcodes,all_blocks[i]->host_opcodes,

			all_blocks[i]->runs/total_runs,
			all_blocks[i]->guest_cycles*all_blocks[i]->runs/total_cycles,
			all_blocks[i]->host_opcodes*all_blocks[i]->runs/total_hops);
		
		sel_hops+=all_blocks[i]->host_opcodes*all_blocks[i]->runs;
	}

	printf(" >-< %.2f%% covered in top %.2f%% blocks\n",sel_hops/total_hops,i*100.0/all_blocks.size());

}

void bm_Sort()
{
	printf("!!!!!!!!!!!!!!!!!!! BLK REPORT !!!!!!!!!!!!!!!!!!!!n");

	printf("     ---- Blocks: Sorted based on Runs ! ----     \n");
	std::sort(all_blocks.begin(),all_blocks.end(),UDgreater);
	bm_PrintTopBlocks();

	printf("<><><><><><><><><><><><><><><><><><><><><><><><><>\n");

	printf("     ---- Blocks: Sorted based on hops ! ----     \n");
	std::sort(all_blocks.begin(),all_blocks.end(),UDgreater2);
	bm_PrintTopBlocks();

	printf("<><><><><><><><><><><><><><><><><><><><><><><><><>\n");

	printf("     ---- Blocks: Sorted based on wefs ! ----     \n");
	std::sort(all_blocks.begin(),all_blocks.end(),UDgreater3);
	bm_PrintTopBlocks();

	printf("^^^^^^^^^^^^^^^^^^^ END REPORT ^^^^^^^^^^^^^^^^^^^\n");

	for (size_t i=0;i<all_blocks.size();i++)
	{
		all_blocks[i]->runs=0;
	}
}



RuntimeBlockInfo::~RuntimeBlockInfo()
{

}
#include <algorithm>

void RuntimeBlockInfo::AddRef(RuntimeBlockInfo* other) 
{ 
	pre_refs.push_back(other); 
}

void RuntimeBlockInfo::RemRef(RuntimeBlockInfo* other) 
{ 
	pre_refs.erase(find(pre_refs.begin(),pre_refs.end(),other)); 
}

bool print_stats;

void fprint_hex(FILE* d,const char* init,u8* ptr, u32& ofs, u32 limit)
{
	int base=ofs;
	int cnt=0;
	while(ofs<limit)
	{
		if (cnt==32)
		{
			fputs("\n",d);
			cnt=0;
		}

		if (cnt==0)
			fprintf(d,"%s:%d:",init,ofs-base);

		fprintf(d," %02X",ptr[ofs++]);
		cnt++;
	}
	fputs("\n",d);
}



void print_blocks()
{
	FILE* f=0;

	if (print_stats)
	{
		f=fopen(get_writable_data_path("/blkmap.lst").c_str(),"w");
		print_stats=0;

		printf("Writing blocks to %p\n",f);
	}

	for (size_t i=0;i<all_blocks.size();i++)
	{
		RuntimeBlockInfo* blk=all_blocks[i];

		if (f)
		{
			fprintf(f,"block: %08X\n",blk);
			fprintf(f,"addr: %08X\n",blk->addr);
			fprintf(f,"hash: %s\n",blk->hash());
			fprintf(f,"hash_rloc: %s\n",blk->hash(false,true));
			fprintf(f,"code: %08X\n",blk->code);
			fprintf(f,"runs: %d\n",blk->runs);
			fprintf(f,"BlockType: %d\n",blk->BlockType);
			fprintf(f,"NextBlock: %08X\n",blk->NextBlock);
			fprintf(f,"BranchBlock: %08X\n",blk->BranchBlock);
			fprintf(f,"pNextBlock: %08X\n",blk->pNextBlock);
			fprintf(f,"pBranchBlock: %08X\n",blk->pBranchBlock);
			fprintf(f,"guest_cycles: %d\n",blk->guest_cycles);
			fprintf(f,"guest_opcodes: %d\n",blk->guest_opcodes);
			fprintf(f,"host_opcodes: %d\n",blk->host_opcodes);
			fprintf(f,"il_opcodes: %d\n",blk->oplist.size());

			u32 hcode=0;
			s32 gcode=-1;
			u8* pucode=(u8*)blk->code;

			size_t j=0;
			
			fprintf(f,"{\n");
			for (;j<blk->oplist.size();j++)
			{
				shil_opcode* op=&all_blocks[i]->oplist[j];
				fprint_hex(f,"//h:",pucode,hcode,op->host_offs);

				if (gcode!=op->guest_offs)
				{
					gcode=op->guest_offs;
					u32 rpc=blk->addr+gcode;
					u16 op=ReadMem16(rpc);

					char temp[128];
					OpDesc[op]->Dissasemble(temp,rpc,op);

					fprintf(f,"//g:%s\n",temp);
				}

				string s=op->dissasm();
				fprintf(f,"//il:%d:%d:%s\n",op->guest_offs,op->host_offs,s.c_str());
			}
			
			fprint_hex(f,"//h:",pucode,hcode,blk->host_code_size);

			fprintf(f,"}\n");
		}

		all_blocks[i]->runs=0;
	}

	if (f) fclose(f);
}
#endif

