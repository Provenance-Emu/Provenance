#include "types.h"

#if FEAT_SHREC == DYNAREC_JIT && HOST_CPU == CPU_X86
#include "rec_x86_ngen.h"



struct DynaRBI: RuntimeBlockInfo
{
	x86_block_externs* reloc_info;

	virtual ~DynaRBI() { if (reloc_info) reloc_info->Free(); }

	virtual u32 Relink();
	virtual void Relocate(void* dst)
	{
		reloc_info->Apply(dst);
	}
};

x86_block* x86e;

u32 cycle_counter;

void* loop_no_update;
void* intc_sched;

bool sse_1=true;
bool sse_2=true;
bool sse_3=true;
bool ssse_3=true;
bool mmx=true;

void DetectCpuFeatures()
{
	static bool detected=false;
	if (detected) return;
	detected=true;

#if HOST_OS==OS_WINDOWS
	__try
	{
		__asm addps xmm0,xmm0
	}
	__except(1) 
	{
		sse_1=false;
	}

	__try
	{
		__asm addpd xmm0,xmm0
	}
	__except(1) 
	{
		sse_2=false;
	}

	__try
	{
		__asm addsubpd xmm0,xmm0
	}
	__except(1) 
	{
		sse_3=false;
	}

	__try
	{
		__asm phaddw xmm0,xmm0
	}
	__except(1) 
	{
		ssse_3=false;
	}

	
	__try
	{
		__asm paddd mm0,mm1
		__asm emms;
	}
	__except(1) 
	{
		mmx=false;
	}
	#endif
}


#define CSC_SIZE 64
struct csc_et
{
	u32 pc;
	void* code;
};
csc_et csc[CSC_SIZE<32?32:CSC_SIZE];


#define CSC_SHIFT 1
u32 csc_hash(u32 addr)
{
	return (addr>>CSC_SHIFT)&(CSC_SIZE-1);
}

u32 csc_mode=0;

u32 csc_sidx=1;

x86_reg alloc_regs[]={EBX,EBP,ESI,EDI,NO_REG};
x86_reg xmm_alloc_regs[]={XMM7,XMM6,XMM5,XMM4,NO_REG};
f32 DECL_ALIGN(16) thaw_regs[4];


void x86_reg_alloc::Preload(u32 reg,x86_reg nreg)
{
	x86e->Emit(op_mov32,nreg,GetRegPtr(reg));
}
void x86_reg_alloc::Writeback(u32 reg,x86_reg nreg)
{
	x86e->Emit(op_mov32,GetRegPtr(reg),nreg);
}

void x86_reg_alloc::Preload_FPU(u32 reg,x86_reg nreg)
{
	x86e->Emit(op_movss,nreg,GetRegPtr(reg));
}
void x86_reg_alloc::Writeback_FPU(u32 reg,x86_reg nreg)
{
	x86e->Emit(op_movss,GetRegPtr(reg),nreg);
}
#ifdef PROF2
extern u32 flsh;
#endif

void x86_reg_alloc::FreezeXMM()
{
	x86_reg* fpreg=xmm_alloc_regs;
	f32* slpc=thaw_regs;
	while(*fpreg!=-1)
	{
		if (SpanNRegfIntr(current_opid,*fpreg))	
			x86e->Emit(op_movss,slpc++,*fpreg);
		fpreg++;
	}
#ifdef PROF2
	x86e->Emit(op_add32,&flsh,1);
#endif
}

void x86_reg_alloc::ThawXMM()
{
	x86_reg* fpreg=xmm_alloc_regs;
	f32* slpc=thaw_regs;
	while(*fpreg!=-1)
	{
		if (SpanNRegfIntr(current_opid,*fpreg))	
			x86e->Emit(op_movss,*fpreg,slpc++);
		fpreg++;
	}
}


x86_reg_alloc reg;

u32 ret_hit,ret_all,ret_stc;

void csc_push(RuntimeBlockInfo* block)
{
	if (csc_mode==0)
	{
		x86e->Emit(op_mov32,&csc[csc_hash(block->NextBlock)].pc,block->NextBlock);
	}
	else if (csc_mode==1)
	{
		//x86e->Emit(op_int3);
		x86e->Emit(op_ror32,&csc_sidx,1);
		x86e->Emit(op_bsr32,EAX,&csc_sidx);
		x86e->Emit(op_mov32,x86_mrm(EAX,sib_scale_8,x86_ptr(csc)),block->NextBlock);
	}
}

void DYNACALL csc_fail(u32 addr,u32 addy)
{
	if (csc_mode==0)
	{
		//too bad ?
	}
	else if (csc_mode==1)
	{
		u32 fail_idx=(csc_sidx>>1)|(csc_sidx<<31);

		printf("Ret Mismatch: %08X instead of %08X!\n",addr,addy);
	}
}
void csc_pop(RuntimeBlockInfo* block)
{
	x86_Label* end=x86e->CreateLabel(false,8);
	x86_Label* try_dyn=x86e->CreateLabel(false,8);
	
	//static guess
	x86_Label* stc_hit=x86e->CreateLabel(false,8);
	x86e->Emit(op_cmp32,ECX,&block->csc_RetCache);
	x86e->Emit(op_je,stc_hit);
	//if !eq
	{
		//if (cached) goto dyn
		x86e->Emit(op_cmp32,&block->csc_RetCache,-1);
		x86e->Emit(op_jne,try_dyn);
		//else, do cache
		x86e->Emit(op_mov32,&block->csc_RetCache,ECX);
	}
	
	x86e->MarkLabel(stc_hit);
	x86e->Emit(op_add32,&ret_stc,1);
	if (csc_mode==1)
		x86e->Emit(op_rol32,&csc_sidx,1);
	x86e->Emit(op_jmp,end);

	x86e->MarkLabel(try_dyn);
	
	if (csc_mode==0)
	{
		//csc !
		//x86e->Emit(op_int3);
		x86e->Emit(op_mov32,ECX,GetRegPtr(reg_pc_dyn));
		x86e->Emit(op_mov32,EAX,ECX);
		x86e->Emit(op_shr32,EAX,CSC_SHIFT);
		x86e->Emit(op_and32,EAX,CSC_SIZE-1);
		x86e->Emit(op_cmp32,x86_mrm(EAX,sib_scale_8,x86_ptr(csc)),ECX);
	}
	else if (csc_mode==1)
	{
		//x86e->Emit(op_int3);
		x86e->Emit(op_mov32,ECX,GetRegPtr(reg_pc_dyn));
		x86e->Emit(op_bsr32,EAX,&csc_sidx);
		x86e->Emit(op_rol32,&csc_sidx,1);
		x86e->Emit(op_mov32,EDX,x86_mrm(EAX,sib_scale_8,x86_ptr(csc)));
		x86e->Emit(op_cmp32,EDX,ECX);
	}

	
	x86e->Emit(op_jne,end);
	x86e->Emit(op_add32,&ret_hit,1);
	//x86e->Emit(op_jmp,end);

	x86e->MarkLabel(end);
	x86e->Emit(op_add32,&ret_all,1);

}

void DYNACALL PrintBlock(u32 pc)
{
	printf("block: 0x%08X\n",pc);
	for (int i=0;i<16;i++)
		printf("%08X ",r[i]);
	printf("\n");
}

u32* GetRegPtr(u32 reg)
{
	return Sh4_int_GetRegisterPtr((Sh4RegType)reg);
}

u32 cvld;
u32 rdmt[6];
extern u32 memops_t,memops_l;
extern int mips_counter;

void CheckBlock(RuntimeBlockInfo* block,x86_ptr_imm place)
{
	s32 sz=block->sh4_code_size;
	u32 sa=block->addr;
	while(sz>0)
	{
		void* ptr=(void*)GetMemPtr(sa,4);
		if (ptr)
		{
			if (sz==2)
				x86e->Emit(op_cmp16,ptr,*(u16*)ptr);
			else
				x86e->Emit(op_cmp32,ptr,*(u32*)ptr);
			x86e->Emit(op_jne,place);
		}
		sz-=4;
		sa+=4;
	}
	
}


void ngen_Compile(RuntimeBlockInfo* block,bool force_checks, bool reset, bool staging,bool optimise)
{
	//initialise stuff
	DetectCpuFeatures();

	((DynaRBI*)block)->reloc_info=0;

	
	//Setup emitter
	x86e = new x86_block();
	x86e->Init(0,0);
	x86e->x86_buff=(u8*)emit_GetCCPtr();
	x86e->x86_size=emit_FreeSpace();
	x86e->do_realloc=false;

	block->code=(DynarecCodeEntryPtr)emit_GetCCPtr();

	x86e->Emit(op_add32,&memops_t,block->memops);
	x86e->Emit(op_add32,&memops_l,block->linkedmemops);

#ifdef MIPS_COUNTER
	x86e->Emit(op_add32, &mips_counter, block->oplist.size());
#endif

	//run register allocator
	reg.DoAlloc(block,alloc_regs,xmm_alloc_regs);
	
	//block header//

	//block invl. checks
	x86e->Emit(op_mov32,ECX,block->addr);

	CheckBlock(block,force_checks?x86_ptr_imm(ngen_blockcheckfail):x86_ptr_imm(ngen_blockcheckfail2));

	//Scheduler
	x86_Label* no_up=x86e->CreateLabel(false,8);

	x86e->Emit(op_sub32,&cycle_counter,block->guest_cycles);

	x86e->Emit(op_jns,no_up);
	{
		x86e->Emit(op_call,x86_ptr_imm(intc_sched));
	}

	x86e->MarkLabel(no_up);

	//stating counter
	if (staging) x86e->Emit(op_sub32,&block->staging_runs,1);

	//profiler
	if (prof.enable || 1)
		x86e->Emit(op_add32,&block->runs,1);

	if (prof.enable)
	{
		if (force_checks)
		x86e->Emit(op_add32,&prof.counters.blkrun.force_check,1);

		x86e->Emit(op_add32,&prof.counters.blkrun.cycles[block->guest_cycles],1);
	}

	for (size_t i=0;i<block->oplist.size();i++)
	{
		shil_opcode* op=&block->oplist[i];

		u32 opcd_start=x86e->opcode_count;
		if (prof.enable) 
		{
			x86e->Emit(op_add32,&prof.counters.shil.executed[op->op],1);
		}

		op->host_offs=x86e->x86_indx;
		
		if (prof.enable)
		{
			set<int> reg_wt;
			set<int> reg_rd;

			for (int z=0;op->rd.is_reg() && z<op->rd.count();z++)
				reg_wt.insert(op->rd._reg+z);

			for (int z=0;op->rd2.is_reg() && z<op->rd2.count();z++)
				reg_wt.insert(op->rd2._reg+z);

			for (int z=0;op->rs1.is_reg() && z<op->rs1.count();z++)
				reg_rd.insert(op->rs1._reg+z);

			for (int z=0;op->rs2.is_reg() && z<op->rs2.count();z++)
				reg_rd.insert(op->rs2._reg+z);

			for (int z=0;op->rs3.is_reg() && z<op->rs3.count();z++)
				reg_rd.insert(op->rs3._reg+z);

			set<int>::iterator iter=reg_wt.begin();
			while( iter != reg_wt.end() ) 
			{
				if (reg_rd.count(*iter))
				{
					reg_rd.erase(*iter);
					x86e->Emit(op_add32, &prof.counters.ralloc.reg_rw[*iter], 1);
				}
				else
				{
					x86e->Emit(op_add32, &prof.counters.ralloc.reg_w[*iter], 1);
				}

				++iter;
			}

			iter=reg_rd.begin();
			while( iter != reg_rd.end() ) 
			{
				x86e->Emit(op_add32,&prof.counters.ralloc.reg_r[*iter],1);
				++iter;
			}
		}
		
		reg.OpBegin(op,i);
			
		ngen_opcode(block,op,x86e,staging,optimise);

		if (prof.enable) x86e->Emit(op_add32,&prof.counters.shil.host_ops[op->op],x86e->opcode_count-opcd_start);

		reg.OpEnd(op);
	}

	block->relink_offset=x86e->x86_indx;
	block->relink_data=0;

	x86e->x86_indx+=block->Relink();

	x86e->Generate();
	block->host_code_size=x86e->x86_indx;
	block->host_opcodes=x86e->opcode_count;

	emit_Skip(block->host_code_size);

	delete x86e;
	x86e=0;
}

u32 DynaRBI::Relink()
{
	x86_block* x86e=new x86_block();
	x86e->Init(0,0);
	x86e->x86_buff=(u8*)code + relink_offset;
	x86e->x86_size=512;
	x86e->do_realloc=false;

//#define SIMPLELINK
#ifdef SIMPLELINK
	switch (BlockType) {

	case BET_StaticJump:
	case BET_StaticCall:
		//next_pc = block->BranchBlock;
		x86e->Emit(op_mov32, ECX, BranchBlock);
		break;

	case BET_Cond_0:
	case BET_Cond_1:
	{
		//next_pc = next_pc_value;
		//if (*jdyn == 0)
		//next_pc = branch_pc_value;

		x86e->Emit(op_mov32, ECX, NextBlock);

		u32* ptr = &sr.T;
		if (has_jcond)
			ptr = &Sh4cntx.jdyn;

		x86e->Emit(op_cmp32, ptr, BlockType & 1);

		x86_Label* lbl = x86e->CreateLabel(false, 8);
		x86e->Emit(op_jne, lbl);
		x86e->Emit(op_mov32, ECX, BranchBlock);
		x86e->MarkLabel(lbl);
	}
	break;

	case BET_DynamicJump:
	case BET_DynamicCall:
	case BET_DynamicRet:
		//next_pc = *jdyn;
		x86e->Emit(op_mov32, ECX, &Sh4cntx.jdyn);
		break;

	case BET_DynamicIntr:
	case BET_StaticIntr:
		if (BlockType == BET_StaticIntr)
		{
			x86e->Emit(op_mov32, &next_pc, NextBlock);
		}
		else
		{
			x86e->Emit(op_mov32, EAX, GetRegPtr(reg_pc_dyn));
			x86e->Emit(op_mov32, &next_pc, EAX);
		}
		x86e->Emit(op_call, x86_ptr_imm(UpdateINTC));

		x86e->Emit(op_mov32, ECX, &next_pc);

		break;

	default:
		die("Invalid block end type");
	}

	x86e->Emit(op_jmp, x86_ptr_imm(loop_no_update));

#else
	if (BlockType == BET_StaticCall || BlockType == BET_DynamicCall)
	{
		//csc_push(this);
	}
		
	switch(BlockType)
	{
	case BET_Cond_0:
	case BET_Cond_1:
		{
			x86e->Emit(op_cmp32,GetRegPtr(has_jcond?reg_pc_dyn:reg_sr_T),BlockType&1);
			
			x86_Label* noBranch=x86e->CreateLabel(0,8);

			x86e->Emit(op_jne,noBranch);
			{
				//branch block
				if (pBranchBlock)
					x86e->Emit(op_jmp,x86_ptr_imm(pBranchBlock->code));
				else
					x86e->Emit(op_call,x86_ptr_imm(ngen_LinkBlock_cond_Branch_stub));
			}
			x86e->MarkLabel(noBranch);
			{
				//no branch block
				if (pNextBlock)
					x86e->Emit(op_jmp,x86_ptr_imm(pNextBlock->code));
				else
					x86e->Emit(op_call,x86_ptr_imm(ngen_LinkBlock_cond_Next_stub));
			}
		}
		break;


	case BET_DynamicRet:
		{
			//csc_pop(this);
		}
	case BET_DynamicCall:
	case BET_DynamicJump:
		{
			if (relink_data==0)
			{
				if (pBranchBlock)
				{
					x86e->Emit(op_cmp32,GetRegPtr(reg_pc_dyn),pBranchBlock->addr);
					x86e->Emit(op_je,x86_ptr_imm(pBranchBlock->code));
					x86e->Emit(op_call,x86_ptr_imm(ngen_LinkBlock_Generic_stub));
				}
				else
				{
					x86e->Emit(op_cmp32,GetRegPtr(reg_pc_dyn),0xFABCDECF);
					x86e->Emit(op_call,x86_ptr_imm(ngen_LinkBlock_Generic_stub));
					x86e->Emit(op_je,x86_ptr_imm(ngen_LinkBlock_Generic_stub));
				}
			}
			else
			{
				verify(pBranchBlock==0);
				x86e->Emit(op_mov32,ECX,GetRegPtr(reg_pc_dyn));
				x86e->Emit(op_jmp,x86_ptr_imm(loop_no_update));
			}
		}
		break;

	case BET_StaticCall:
	case BET_StaticJump:
		{
			if (pBranchBlock)
				x86e->Emit(op_jmp,x86_ptr_imm(pBranchBlock->code));
			else
				x86e->Emit(op_call,x86_ptr_imm(ngen_LinkBlock_Generic_stub));
			break;
		}

	case BET_StaticIntr:
	case BET_DynamicIntr:
		if (BlockType==BET_StaticIntr)
		{
			x86e->Emit(op_mov32,&next_pc,NextBlock);
		}
		else
		{
			x86e->Emit(op_mov32,EAX,GetRegPtr(reg_pc_dyn));
			x86e->Emit(op_mov32,&next_pc,EAX);
		}
		x86e->Emit(op_call,x86_ptr_imm(UpdateINTC));

		x86e->Emit(op_mov32,ECX,&next_pc);

		x86e->Emit(op_jmp,x86_ptr_imm(loop_no_update));

		break;
	}
#endif



	x86e->Generate();
	return x86e->x86_indx;
}


/*
	//10
	R S8    B,M
	R S16   B,M
	R I32   B,M
	R F32   B,M
	R F32v2 B{,M}

	//13
	W I8    B,M
	W I16   B,M
	W I32   B,S,M
	W F32   B,S,M
	W F32v2 B,S{,M}
*/

#include "hw/sh4/sh4_mmr.h"

enum mem_op_type
{
	SZ_8,
	SZ_16,
	SZ_32I,
	SZ_32F,
	SZ_64F,
};

void gen_hande(u32 w, u32 sz, u32 mode)
{
	static const x86_ptr_imm rwm[2][5]=
	{
		{x86_ptr_imm(&_vmem_ReadMem8SX32),x86_ptr_imm(&_vmem_ReadMem16SX32),x86_ptr_imm(&ReadMem32),x86_ptr_imm(&ReadMem32),x86_ptr_imm(&ReadMem64),},
		{x86_ptr_imm(&WriteMem8),x86_ptr_imm(&WriteMem16),x86_ptr_imm(&WriteMem32),x86_ptr_imm(&WriteMem32),x86_ptr_imm(&WriteMem64),}
	};

	static const x86_opcode_class opcl_i[2][3]=
	{
		{op_movsx8to32,op_movsx16to32,op_mov32},
		{op_mov8,op_mov16,op_mov32}
	};

	u32 si=x86e->x86_indx;

	if (mode==0 && _nvmem_enabled())
	{
		//Buffer
		x86e->Emit(op_mov32,EAX,ECX);
		x86e->Emit(op_and32,ECX,0x1FFFFFFF);

		x86_mrm_t buff=x86_mrm(ECX,virt_ram_base);
		x86_mrm_t buff4=x86_mrm(ECX,virt_ram_base+4);

		if (sz==SZ_8 || sz==SZ_16 || sz==SZ_32I)
		{
			if (w==0)
				x86e->Emit(opcl_i[w][sz],sz==SZ_8?AL:sz==SZ_16?AX:EAX,buff);
			else
				x86e->Emit(opcl_i[w][sz],buff,sz==SZ_8?DL:sz==SZ_16?DX:EDX);
		}
		else
		{
			if (w==0)
			{
				x86e->Emit(op_movss,XMM0,buff);
				if (sz==SZ_64F)
					x86e->Emit(op_movss,XMM1,buff4);
			}
			else
			{
				x86e->Emit(op_movss,buff,XMM0);
				if (sz==SZ_64F)
					x86e->Emit(op_movss,buff4,XMM1);
			}
		}	
	}
	else if (mode==1)
	{
		//SQ
		verify(w==1);
		x86e->Emit(op_mov32,EAX,ECX);
		x86e->Emit(op_and32,ECX,0x3f);

		x86e->Emit(op_shr32,EAX,26);
		x86e->Emit(op_cmp32,EAX,0x38);
		x86_Label* l=x86e->CreateLabel(false,8);
		x86e->Emit(op_je,l);
		x86e->Emit(op_int3);
		x86e->MarkLabel(l);

		if (sz==SZ_32I)
			x86e->Emit(op_mov32,x86_mrm(ECX,sq_both),EDX);
		else if (sz==SZ_32F || sz==SZ_64F)
		{
			x86e->Emit(op_movss,x86_mrm(ECX,sq_both),XMM0);
			if (sz==SZ_64F)
				x86e->Emit(op_movss,x86_mrm(ECX,sq_both+4),XMM1);
		}
		else
		{
			die("Can't happen\n");
		}
	}
	else
	{
		//General

		#if HOST_OS != OS_WINDOWS
			//maintain 16 byte alignment
			x86e->Emit(op_sub32, ESP, 12);
		#endif
		if ((sz==SZ_32F || sz==SZ_64F) && w==1)
		{
			if (sz==SZ_32F)
			{
				x86e->Emit(op_movd_xmm_to_r32,EDX,XMM0);
			}
			else
			{
				#if HOST_OS == OS_WINDOWS
					//on linux, we have scratch space on esp
					x86e->Emit(op_sub32,ESP,8);
				#endif
				x86e->Emit(op_movss,x86_mrm(ESP,x86_ptr::create(+4)),XMM1);
				x86e->Emit(op_movss,x86_mrm(ESP,x86_ptr::create(-0)),XMM0);
			}
		}

		x86e->Emit(op_call,rwm[w][sz]);

		if ((sz==SZ_32F || sz==SZ_64F) && w==0)
		{
			x86e->Emit(op_movd_xmm_from_r32,XMM0,EAX);
			if (sz==SZ_64F)
			{
				x86e->Emit(op_movd_xmm_from_r32,XMM1,EDX);
			}
		}
		#if HOST_OS != OS_WINDOWS
			//maintain 16 byte alignment
			if ((sz == SZ_64F) && w == 1) {
				x86e->Emit(op_add32, ESP, 4);
			}
			else {
				x86e->Emit(op_add32, ESP, 12);
			}
		#endif
	}

	x86e->Emit(op_ret);

	emit_Skip(x86e->x86_indx-si);
}

unat mem_code_base=0;
unat mem_code_end=0;
void* mem_code[3][2][5];

void ngen_init()
{
	//Setup emitter
	x86e = new x86_block();
	x86e->Init(0,0);
	x86e->x86_buff=(u8*)emit_GetCCPtr();
	x86e->x86_size=emit_FreeSpace();
	x86e->do_realloc=false;


	mem_code_base=(unat)emit_GetCCPtr();

	for (int sz=0;sz<5;sz++)
	{
		for (int w=0;w<2;w++)
		{
			for (int m=0;m<3;m++)
			{
				if (m==1 && (sz<=SZ_16 || w==0))
					continue;

				mem_code[m][w][sz]=emit_GetCCPtr();
				gen_hande(w,sz,m);
			}
		}
	}

	mem_code_end=(unat)emit_GetCCPtr();

	x86e->Generate();

	delete x86e;

	emit_SetBaseAddr();
}

void ngen_ResetBlocks()
{
}

void ngen_GetFeatures(ngen_features* dst)
{
	dst->InterpreterFallback=false;
	dst->OnlyDynamicEnds=false;
}


RuntimeBlockInfo* ngen_AllocateBlock()
{
	return new DynaRBI();
}


bool ngen_Rewrite(unat& addr,unat retadr,unat acc)
{
	if (addr>=mem_code_base && addr<mem_code_end)
	{
		u32 ca=*(u32*)(retadr-4)+retadr;

		x86e = new x86_block();
		x86e->Init(0,0);
		x86e->x86_buff=(u8*)retadr-5;
		x86e->x86_size=emit_FreeSpace();
		x86e->do_realloc=false;

		for (int i=0;i<5;i++)
		{
			for (int w=0;w<2;w++)
			{
				if ((u32)mem_code[0][w][i]==ca)
				{
					//found !

					if ((acc >> 26) == 0x38 && !w) {
						printf("WARNING: SQ AREA READ, %08X from sh4:%08X. THIS IS UNDEFINED ON A REAL DREACMAST.\n", acc, bm_GetBlock(x86e->x86_buff)->addr);
					}

					if ((acc >> 26) == 0x38) //sq ?
					{
						verify(w == 1);
						x86e->Emit(op_call, x86_ptr_imm(mem_code[1][w][i]));
					}
					else
					{
						x86e->Emit(op_call, x86_ptr_imm(mem_code[2][w][i]));
					}

					x86e->Generate();
					delete x86e;

					addr=retadr-5;

					//printf("Patched: %08X for access @ %08X\n",addr,acc);
					return true;
				}
			}
		}
		
		die("Failed to match the code :(\n");

		return false;
	}
	else
	{
		return false;
	}
}
#endif