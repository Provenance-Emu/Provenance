#include "types.h"

#if HOST_OS==OS_WINDOWS
#include <windows.h>
#elif HOST_OS==OS_LINUX
#include <unistd.h>
#include <sys/mman.h>
#endif

#include "../sh4_interpreter.h"
#include "../sh4_opcode_list.h"
#include "../sh4_core.h"
#include "../sh4_if.h"
#include "hw/sh4/sh4_interrupts.h"

#include "hw/sh4/sh4_mem.h"
#include "hw/pvr/pvr_mem.h"
#include "hw/aica/aica_if.h"
#include "hw/gdrom/gdrom_if.h"

#include <time.h>
#include <float.h>

#include "blockmanager.h"
#include "ngen.h"
#include "decoder.h"

#if FEAT_SHREC != DYNAREC_NONE
//uh uh

#if !defined(_WIN64)
u8 SH4_TCB[CODE_SIZE+4096]
#if HOST_OS == OS_WINDOWS || FEAT_SHREC != DYNAREC_JIT
	;
#elif HOST_OS == OS_LINUX
	__attribute__((section(".text")));
#elif HOST_OS==OS_DARWIN
	__attribute__((section("__TEXT,.text")));
#else
	#error SH4_TCB ALLOC
#endif
#endif

u8* CodeCache;


u32 LastAddr;
u32 LastAddr_min;
u32* emit_ptr=0;

void* emit_GetCCPtr() { return emit_ptr==0?(void*)&CodeCache[LastAddr]:(void*)emit_ptr; }
void emit_SetBaseAddr() { LastAddr_min = LastAddr; }
void emit_WriteCodeCache()
{
	wchar path[512];
	sprintf(path,"/code_cache_%8p.bin",CodeCache);
	string pt2=get_writable_data_path(path);
	printf("Writing code cache to %s\n",pt2.c_str());
	FILE*f=fopen(pt2.c_str(),"wb");
	if (f)
	{
		fwrite(CodeCache,LastAddr,1,f);
		fclose(f);
		printf("Written!\n");
	}

	bm_WriteBlockMap(pt2+".map");
}

void RASDASD()
{
	LastAddr=LastAddr_min;
	memset(emit_GetCCPtr(),0xCC,emit_FreeSpace());
}
void recSh4_ClearCache()
{
	LastAddr=LastAddr_min;
	bm_Reset();

	printf("recSh4:Dynarec Cache clear at %08X\n",curr_pc);
}

void recSh4_Run()
{
	sh4_int_bCpuRun=true;

	sh4_dyna_rcb=(u8*)&Sh4cntx + sizeof(Sh4cntx);
	printf("cntx // fpcb offset: %d // pc offset: %d // pc %08X\n",(u8*)&sh4rcb.fpcb-sh4_dyna_rcb,(u8*)&sh4rcb.cntx.pc-sh4_dyna_rcb,sh4rcb.cntx.pc);
	
	verify(rcb_noffs(&next_pc)==-184);
	ngen_mainloop(sh4_dyna_rcb);

#if !defined(TARGET_BOUNDED_EXECUTION)
	sh4_int_bCpuRun=false;
#endif
}

void emit_Write32(u32 data)
{
	if (emit_ptr)
	{
		*emit_ptr=data;
		emit_ptr++;
	}
	else
	{
		*(u32*)&CodeCache[LastAddr]=data;
		LastAddr+=4;
	}
}

void emit_Skip(u32 sz)
{
	LastAddr+=sz;
}
u32 emit_FreeSpace()
{
	return CODE_SIZE-LastAddr;
}


bool DoCheck(u32 pc)
{
	if (IsOnRam(pc))
	{
		if (!settings.dynarec.unstable_opt)
			return true;

		pc&=0xFFFFFF;
		switch(pc)
		{
			//DOA2LE
			case 0x3DAFC6:
			case 0x3C83F8:

			//Shenmue 2
			case 0x348000:
				
			//Shenmue
			case 0x41860e:
			

				return true;

			default:
				return false;
		}
	}
	return false;
}

void AnalyseBlock(RuntimeBlockInfo* blk);

char block_hash[1024];

#include "deps/crypto/sha1.h"

const char* RuntimeBlockInfo::hash(bool full, bool relocable)
{
	sha1_ctx ctx;
	sha1_init(&ctx);

	u8* ptr = GetMemPtr(this->addr,this->guest_opcodes*2);

	if (ptr)
	{
		if (relocable)
		{
			for (u32 i=0; i<this->guest_opcodes; i++)
			{
				u16 data=ptr[i];
				//Do not count PC relative loads (relocated code)
				if ((ptr[i]>>12)==0xD)
					data=0xD000;

				sha1_update(&ctx,2,(u8*)&data);
			}
		}
		else
		{
			sha1_update(&ctx,this->guest_opcodes*2,ptr);
		}
	}

	sha1_final(&ctx);

	if (full)
		sprintf(block_hash,">:%d:%08X:%02X:%08X:%08X:%08X:%08X:%08X",relocable,this->addr,this->guest_opcodes,ctx.digest[0],ctx.digest[1],ctx.digest[2],ctx.digest[3],ctx.digest[4]);
	else
		sprintf(block_hash,">:%d:%02X:%08X:%08X:%08X:%08X:%08X",relocable,this->guest_opcodes,ctx.digest[0],ctx.digest[1],ctx.digest[2],ctx.digest[3],ctx.digest[4]);

	//return ctx
	return block_hash;
}

void RuntimeBlockInfo::Setup(u32 rpc,fpscr_t rfpu_cfg)
{
	staging_runs=addr=lookups=runs=host_code_size=0;
	guest_cycles=guest_opcodes=host_opcodes=0;
	pBranchBlock=pNextBlock=0;
	code=0;
	has_jcond=false;
	BranchBlock=NextBlock=csc_RetCache=0xFFFFFFFF;
	BlockType=BET_SCL_Intr;
	
	addr=rpc;
	fpu_cfg=rfpu_cfg;
	
	oplist.clear();

	dec_DecodeBlock(this,SH4_TIMESLICE/2);
	AnalyseBlock(this);
}

DynarecCodeEntryPtr rdv_CompilePC()
{
	u32 pc=next_pc;

	if (emit_FreeSpace()<16*1024 || pc==0x8c0000e0 || pc==0xac010000 || pc==0xac008300)
		recSh4_ClearCache();

	RuntimeBlockInfo* rv=0;
	do
	{
		RuntimeBlockInfo* rbi = ngen_AllocateBlock();
		if (rv==0) rv=rbi;

		rbi->Setup(pc,fpscr);

		
		bool do_opts=((rbi->addr&0x3FFFFFFF)>0x0C010100);
		rbi->staging_runs=do_opts?100:-100;
		ngen_Compile(rbi,DoCheck(rbi->addr),(pc&0xFFFFFF)==0x08300 || (pc&0xFFFFFF)==0x10000,false,do_opts);
		verify(rbi->code!=0);

		bm_AddBlock(rbi);

		if (rbi->BlockType==BET_Cond_0 || rbi->BlockType==BET_Cond_1)
			pc=rbi->NextBlock;
		else
			pc=0;
	} while(false && pc);

	return rv->code;
}

DynarecCodeEntryPtr DYNACALL rdv_FailedToFindBlock(u32 pc)
{
	//printf("rdv_FailedToFindBlock ~ %08X\n",pc);
	next_pc=pc;

	return rdv_CompilePC();
}

extern u32 rebuild_counter;


u32 DYNACALL rdv_DoInterrupts_pc(u32 pc) {
	next_pc = pc;
	UpdateINTC();

	//We can only safely relocate/etc stuff here, as in other generic update cases
	//There's a RET, meaning the code can't move around
	//Interrupts happen at least 50 times/second, so its not a problem ..
	if (rebuild_counter == 0)
	{
		// TODO: Why is this commented, etc.
		//bm_Rebuild();
	}

	return next_pc;
}

void bm_Rebuild();
u32 DYNACALL rdv_DoInterrupts(void* block_cpde)
{
	RuntimeBlockInfo* rbi = bm_GetBlock(block_cpde);
	return rdv_DoInterrupts_pc(rbi->addr);
}

DynarecCodeEntryPtr DYNACALL rdv_BlockCheckFail(u32 pc)
{
	next_pc=pc;
	recSh4_ClearCache();
	return rdv_CompilePC();
}

DynarecCodeEntryPtr rdv_FindCode()
{
	DynarecCodeEntryPtr rv=bm_GetCode(next_pc);
	if (rv==ngen_FailedToFindBlock)
		return 0;
	
	return rv;
}

DynarecCodeEntryPtr rdv_FindOrCompile()
{
	DynarecCodeEntryPtr rv=bm_GetCode(next_pc);
	if (rv==ngen_FailedToFindBlock)
		rv=rdv_CompilePC();
	
	return rv;
}

void* DYNACALL rdv_LinkBlock(u8* code,u32 dpc)
{
	RuntimeBlockInfo* rbi=bm_GetBlock(code);

	if (!rbi)
	{
		printf("Stale block ..");
		rbi=bm_GetStaleBlock(code);
	}
	
	verify(rbi != NULL);

	u32 bcls=BET_GET_CLS(rbi->BlockType);

	if (bcls==BET_CLS_Static)
	{
		next_pc=rbi->BranchBlock;
	}
	else if (bcls==BET_CLS_Dynamic)
	{
		next_pc=dpc;
	}
	else if (bcls==BET_CLS_COND)
	{
		if (dpc)
			next_pc=rbi->BranchBlock;
		else
			next_pc=rbi->NextBlock;
	}

	DynarecCodeEntryPtr rv=rdv_FindOrCompile();

	bool do_link=bm_GetBlock(code)==rbi;

	if (do_link)
	{
		if (bcls==BET_CLS_Dynamic)
		{
			verify(rbi->relink_data==0 || rbi->pBranchBlock==0);

			if (rbi->pBranchBlock!=0)
			{
				rbi->pBranchBlock->RemRef(rbi);
				rbi->pBranchBlock=0;
				rbi->relink_data=1;
			}
			else if (rbi->relink_data==0)
			{
				rbi->pBranchBlock=bm_GetBlock(next_pc);
				rbi->pBranchBlock->AddRef(rbi);
			}
		}
		else
		{
			RuntimeBlockInfo* nxt=bm_GetBlock(next_pc);

			if (rbi->BranchBlock==next_pc)
				rbi->pBranchBlock=nxt;
			if (rbi->NextBlock==next_pc)
				rbi->pNextBlock=nxt;

			nxt->AddRef(rbi);
		}
		u32 ncs=rbi->relink_offset+rbi->Relink();
		verify(rbi->host_code_size>=ncs);
		rbi->host_code_size=ncs;
	}
	else
	{
		printf(" .. null RBI: %08X -- unlinked stale block\n",next_pc);
	}
	
	return (void*)rv;
}
void recSh4_Stop()
{
	Sh4_int_Stop();
}

void recSh4_Step()
{
	Sh4_int_Step();
}

void recSh4_Skip()
{
	Sh4_int_Skip();
}

void recSh4_Reset(bool Manual)
{
	Sh4_int_Reset(Manual);
}

#if HOST_OS == OS_DARWIN
#include <sys/mman.h>
#import <sys/utsname.h>
#include <unistd.h>
#import <sys/syscall.h>
#endif

void recSh4_Init()
{
	printf("recSh4 Init\n");
	Sh4_int_Init();
	bm_Init();
	bm_Reset();

	verify(rcb_noffs(p_sh4rcb->fpcb) == FPCB_OFFSET);

	verify(rcb_noffs(p_sh4rcb->sq_buffer) == -512);

	verify(rcb_noffs(&p_sh4rcb->cntx.sh4_sched_next) == -152);
	verify(rcb_noffs(&p_sh4rcb->cntx.interrupt_pend) == -148);
	
	if (_nvmem_enabled()) {
		verify(mem_b.data==((u8*)p_sh4rcb->sq_buffer+512+0x0C000000));
	}
	
#if defined(_WIN64)
	for (int i = 10; i < 1300; i++) {


		//align to next page ..
		u8* ptr = (u8*)recSh4_Init - i * 1024 * 1024;

		CodeCache = (u8*)VirtualAlloc(ptr, CODE_SIZE, MEM_RESERVE | MEM_COMMIT, PAGE_EXECUTE_READWRITE);//; (u8*)(((unat)SH4_TCB+4095)& ~4095);

		if (CodeCache)
			break;
	}
#else
	CodeCache = (u8*)(((unat)SH4_TCB+4095)& ~4095);
#endif

#define JM_HACKS 1

#if HOST_OS == OS_DARWIN
//    syscall(26, 0, 0, 0, 0);
    munmap(CodeCache, CODE_SIZE);

#if JM_HACKS
    FILE *fd = tmpfile();//fopen(mktemp("test"), "rw"); //tmpfile(); //fopen(NSTemporaryDirectory(), "r");
    fseek(fd, 0, SEEK_END);
    int len = (int)ftell(fd);
    fseek( fd, 0, SEEK_SET );
    
    int fileNumber = fileno(fd);
    // Allow Code run
//    syscall(26, 0, 0, 0, 0);
    // Simulates a debugger. Makes it possible to use JIT (though only W^X)
//    syscall(SYS_ptrace, 0 /*PTRACE_TRACEME*/, 0, 0, 0);
    //     CodeCache = (u8*)mmap(NULL, CODE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
//  MAP_ANON | MAP_PRIVATE, -1, 0
    //     CodeCache = (u8*)mmap(CodeCache, CODE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_FIXED | MAP_PRIVATE | MAP_ANON, 0, 0);
    void *test = malloc(CODE_SIZE);// mmap(NULL, CODE_SIZE, PROT_READ, MAP_FIXED | MAP_PRIVATE, 0, 0);
    bzero(test, CODE_SIZE);
    CodeCache = (u8*)test;
    CodeCache = (u8*)mmap(test, CODE_SIZE, PROT_WRITE | PROT_EXEC, MAP_FIXED | MAP_PRIVATE | MAP_ANON, len, 0);
#else
    CodeCache = (u8*)mmap(CodeCache, CODE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_FIXED | MAP_PRIVATE | MAP_ANON, 0, 0);
#endif
#endif

#if HOST_OS == OS_WINDOWS
	DWORD old;
	VirtualProtect(CodeCache,CODE_SIZE,PAGE_EXECUTE_READWRITE,&old);
#elif HOST_OS == OS_LINUX || HOST_OS == OS_DARWIN
	
//	printf("\n\t CodeCache addr: %p | from: %p | addr here: %p\n", CodeCache, CodeCache, recSh4_Init);
//    syscall(26, 0, 0, 0, 0);

	#if FEAT_SHREC == DYNAREC_JIT
		if (mprotect(CodeCache, CODE_SIZE, PROT_READ|PROT_WRITE|PROT_EXEC))
		{
			perror("\n\tError,Couldn’t mprotect CodeCache!");
			die("Couldn’t mprotect CodeCache");
		}
	#endif

#if defined(TARGET_IPHONE) || defined(TARGET_IPHONE_SIMULATOR)
#if JM_HACKS
//    syscall(SYS_ptrace, 0, 0, 0, 0);
            memset((u8*)mmap(CodeCache, CODE_SIZE, PROT_WRITE | PROT_EXEC, MAP_FIXED | MAP_PRIVATE | MAP_ANON, 0, 0),0xFF,CODE_SIZE);
//    memset((u8*)mmap(CodeCache, CODE_SIZE, PROT_WRITE | PROT_EXEC, MAP_FIXED | MAP_PRIVATE | MAP_ANON, -1, 0),0xFF,CODE_SIZE);
#else
    memset((u8*)mmap(CodeCache, CODE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_FIXED | MAP_PRIVATE | MAP_ANON, 0, 0),0xFF,CODE_SIZE);
#endif
#else
	memset(CodeCache,0xFF,CODE_SIZE);
#endif

#endif
	ngen_init();
}

void recSh4_Term()
{
	printf("recSh4 Term\n");
	bm_Term();
	Sh4_int_Term();

#if HOST_OS == OS_LINUX
	//hum ?
#endif
}

bool recSh4_IsCpuRunning()
{
	return Sh4_int_IsCpuRunning();
}

void Get_Sh4Recompiler(sh4_if* rv)
{
	rv->Run = recSh4_Run;
	rv->Stop = recSh4_Stop;
	rv->Step = recSh4_Step;
	rv->Skip = recSh4_Skip;
	rv->Reset = recSh4_Reset;
	rv->Init = recSh4_Init;
	rv->Term = recSh4_Term;
	rv->IsCpuRunning = recSh4_IsCpuRunning;
	//rv->GetRegister=Sh4_int_GetRegister;
	//rv->SetRegister=Sh4_int_SetRegister;
	rv->ResetCache = recSh4_ClearCache;
}
#endif
