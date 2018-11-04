#include "deps/xbyak/xbyak.h"

#include "types.h"

#if FEAT_SHREC == DYNAREC_JIT // && HOST_CPU == CPU_X64
#include "hw/sh4/sh4_opcode_list.h"
#include "hw/sh4/modules/ccn.h"
#include "hw/sh4/sh4_interrupts.h"

#include "hw/sh4/sh4_core.h"
#include "hw/sh4/dyna/ngen.h"
#include "hw/sh4/sh4_mem.h"
#include "hw/sh4/dyna/regalloc.h"
//#include "arm_emitter/arm_emitter.h"
#include "emitter/x86_emitter.h"
#include "profiler/profiler.h"
#include "oslib/oslib.h"


struct DynaRBI : RuntimeBlockInfo
{
	virtual u32 Relink() {
		//verify(false);
		return 0;
	}

	virtual void Relocate(void* dst) {
		verify(false);
	}
};



int cycle_counter;

void ngen_FailedToFindBlock_internal() {
	rdv_FailedToFindBlock(Sh4cntx.pc);
}

void(*ngen_FailedToFindBlock)() = &ngen_FailedToFindBlock_internal;

void ngen_mainloop(void* v_cntx)
{
	Sh4RCB* ctx = (Sh4RCB*)((u8*)v_cntx - sizeof(Sh4RCB));

	cycle_counter = 0;

	while (sh4_int_bCpuRun) {
		cycle_counter = SH4_TIMESLICE;
		do {
			DynarecCodeEntryPtr rcb = bm_GetCode(ctx->cntx.pc);
			rcb();
		} while (cycle_counter > 0);

		if (UpdateSystem()) {
			rdv_DoInterrupts_pc(ctx->cntx.pc);
		}
	}
}

void ngen_init()
{
}

void ngen_ResetBlocks()
{
}

void ngen_GetFeatures(ngen_features* dst)
{
	dst->InterpreterFallback = false;
	dst->OnlyDynamicEnds = false;
}

RuntimeBlockInfo* ngen_AllocateBlock()
{
	return new DynaRBI();
}

u32* GetRegPtr(u32 reg)
{
	return Sh4_int_GetRegisterPtr((Sh4RegType)reg);
}

void ngen_blockcheckfail(u32 pc) {
	printf("X64 JIT: SMC invalidation at %08X\n", pc);
	rdv_BlockCheckFail(pc);
}

class BlockCompiler : public Xbyak::CodeGenerator{
public:

	vector<Xbyak::Reg32> call_regs;
	vector<Xbyak::Reg64> call_regs64;
	vector<Xbyak::Xmm> call_regsxmm;

	BlockCompiler() : Xbyak::CodeGenerator(64 * 1024, emit_GetCCPtr()) {
		#if HOST_OS == OS_WINDOWS
			call_regs.push_back(ecx);
			call_regs.push_back(edx);
			call_regs.push_back(r8d);
			call_regs.push_back(r9d);

			call_regs64.push_back(rcx);
			call_regs64.push_back(rdx);
			call_regs64.push_back(r8);
			call_regs64.push_back(r9);
		#else
			call_regs.push_back(edi);
			call_regs.push_back(esi);
			call_regs.push_back(edx);
			call_regs.push_back(ecx);

			call_regs64.push_back(rdi);
			call_regs64.push_back(rsi);
			call_regs64.push_back(rdx);
			call_regs64.push_back(rcx);
		#endif

		call_regsxmm.push_back(xmm0);
		call_regsxmm.push_back(xmm1);
		call_regsxmm.push_back(xmm2);
		call_regsxmm.push_back(xmm3);
	}

#define sh_to_reg(prm, op, rd) \
		do {							\
			if (prm.is_imm()) {				\
				op(rd, prm._imm);	\
			}								\
			else if (prm.is_reg()) {							\
				mov(rax, (size_t)prm.reg_ptr());	\
				op(rd, dword[rax]);				\
			}										\
			else { \
				verify(prm.is_null()); \
			} \
		} while (0)

#define sh_to_reg_noimm(prm, op, rd) \
		do {							\
			if (prm.is_reg()) {							\
				mov(rax, (size_t)prm.reg_ptr());	\
				op(rd, dword[rax]);				\
				}										\
						else { \
				verify(prm.is_null()); \
				} \
				} while (0)




#define reg_to_sh(prm, rs) \
		 do {	\
				 mov(rax, (size_t)prm.reg_ptr());	\
				 mov(dword[rax], rs);				\
		 } while (0)

#define reg_to_sh_ss(prm, rs) \
		 do {	\
				 mov(rax, (size_t)prm.reg_ptr());	\
				 movss(dword[rax], rs);				\
		 		 } while (0)

	void CheckBlock(RuntimeBlockInfo* block) {
		mov(call_regs[0], block->addr);

		s32 sz=block->sh4_code_size;
		u32 sa=block->addr;

		while(sz>0) {
			void* ptr=(void*)GetMemPtr(sa,4);
			if (ptr) {
				mov(rax, reinterpret_cast<uintptr_t>(ptr));

				if (sz==2) {
					mov(edx, *(u16*)ptr);
					cmp(word[rax],dx);
				}
				else {
					mov(edx, *(u32*)ptr);
					cmp(dword[rax],edx);
				}
				jne(reinterpret_cast<const void*>(&ngen_blockcheckfail));
			}
			sz-=4;
			sa+=4;
		}
		
	}

	void compile(RuntimeBlockInfo* block, bool force_checks, bool reset, bool staging, bool optimise) {
		
		if (force_checks) {
			CheckBlock(block);
		}

		mov(rax, (size_t)&cycle_counter);

		sub(dword[rax], block->guest_cycles);

		sub(rsp, 0x28);

		for (size_t i = 0; i < block->oplist.size(); i++) {
			shil_opcode& op  = block->oplist[i];
			switch (op.op) {

			case shop_ifb:
				if (op.rs1._imm)
				{
					mov(rax, (size_t)&next_pc);
					mov(dword[rax], op.rs2._imm);
				}

				mov(call_regs[0], op.rs3._imm);

				call((void*)OpDesc[op.rs3._imm]->oph);
				break;

			case shop_jcond:
			case shop_jdyn:
				{
					mov(rax, (size_t)op.rs1.reg_ptr());

					mov(ecx, dword[rax]);

					if (op.rs2.is_imm()) {
						add(ecx, op.rs2._imm);
					}

					mov(rdx, (size_t)op.rd.reg_ptr());
					mov(dword[rdx], ecx);
				}
				break;

			case shop_mov32:
			{
				verify(op.rd.is_reg());

				verify(op.rs1.is_reg() || op.rs1.is_imm());

				sh_to_reg(op.rs1, mov, ecx);

				reg_to_sh(op.rd, ecx);
			}
			break;

			case shop_mov64:
			{
				verify(op.rd.is_reg());

				verify(op.rs1.is_reg() || op.rs1.is_imm());

				sh_to_reg(op.rs1, mov, rcx);

				reg_to_sh(op.rd, rcx);
			}
			break;

			case shop_readm:
			{
				sh_to_reg(op.rs1, mov, call_regs[0]);
				sh_to_reg(op.rs3, add, call_regs[0]);

				u32 size = op.flags & 0x7f;

				if (size == 1) {
					call((void*)ReadMem8);
					movsx(rcx, al);
				}
				else if (size == 2) {
					call((void*)ReadMem16);
					movsx(rcx, ax);
				}
				else if (size == 4) {
					call((void*)ReadMem32);
					mov(rcx, rax);
				}
				else if (size == 8) {
					call((void*)ReadMem64);
					mov(rcx, rax);
				}
				else {
					die("1..8 bytes");
				}

				if (size != 8)
					reg_to_sh(op.rd, ecx);
				else
					reg_to_sh(op.rd, rcx);
			}
			break;

			case shop_writem:
			{
				u32 size = op.flags & 0x7f;
				sh_to_reg(op.rs1, mov, call_regs[0]);
				sh_to_reg(op.rs3, add, call_regs[0]);

				if (size != 8)
					sh_to_reg(op.rs2, mov, call_regs[1]);
				else
					sh_to_reg(op.rs2, mov, call_regs64[1]);

				if (size == 1)
					call((void*)WriteMem8);
				else if (size == 2)
					call((void*)WriteMem16);
				else if (size == 4)
					call((void*)WriteMem32);
				else if (size == 8)
					call((void*)WriteMem64);
				else {
					die("1..8 bytes");
				}
			}
			break;

			default:
				shil_chf[op.op](&op);
				break;
			}
		}

		mov(rax, (size_t)&next_pc);

		switch (block->BlockType) {

		case BET_StaticJump:
		case BET_StaticCall:
			//next_pc = block->BranchBlock;
			mov(dword[rax], block->BranchBlock);
			break;

		case BET_Cond_0:
		case BET_Cond_1:
			{
				//next_pc = next_pc_value;
				//if (*jdyn == 0)
				//next_pc = branch_pc_value;

				mov(dword[rax], block->NextBlock);

				if (block->has_jcond)
					mov(rdx, (size_t)&Sh4cntx.jdyn);
				else
					mov(rdx, (size_t)&sr.T);

				cmp(dword[rdx], block->BlockType & 1);
				Xbyak::Label branch_not_taken;

				jne(branch_not_taken, T_SHORT);
				mov(dword[rax], block->BranchBlock);
				L(branch_not_taken);
			}
			break;

		case BET_DynamicJump:
		case BET_DynamicCall:
		case BET_DynamicRet:
			//next_pc = *jdyn;
			mov(rdx, (size_t)&Sh4cntx.jdyn);
			mov(edx, dword[rdx]);
			mov(dword[rax], edx);
			break;

		case BET_DynamicIntr:
		case BET_StaticIntr:
			if (block->BlockType == BET_DynamicIntr) {
				//next_pc = *jdyn;
				mov(rdx, (size_t)&Sh4cntx.jdyn);
				mov(edx, dword[rdx]);
				mov(dword[rax], edx);
			}
			else {
				//next_pc = next_pc_value;
				mov(dword[rax], block->NextBlock);
			}

			call((void*)UpdateINTC);
			break;

		default:
			die("Invalid block end type");
		}


		add(rsp, 0x28);
		ret();

		ready();

		block->code = (DynarecCodeEntryPtr)getCode();

		emit_Skip(getSize());
	}

	struct CC_PS
	{
		CanonicalParamType type;
		shil_param* prm;
	};
	vector<CC_PS> CC_pars;

	void ngen_CC_Start(shil_opcode* op)
	{
		CC_pars.clear();
	}

	void ngen_CC_param(shil_opcode& op, shil_param& prm, CanonicalParamType tp) {
		switch (tp)
		{

		case CPT_u32:
		case CPT_ptr:
		case CPT_f32:
		{
			CC_PS t = { tp, &prm };
			CC_pars.push_back(t);
		}
		break;


		//store from EAX
		case CPT_u64rvL:
		case CPT_u32rv:
			mov(rcx, rax);
			reg_to_sh(prm, ecx);
			break;

		case CPT_u64rvH:
			shr(rcx, 32);
			reg_to_sh(prm, ecx);
			break;

			//Store from ST(0)
		case CPT_f32rv:
			reg_to_sh_ss(prm, xmm0);
			break;
		}
	}

	void ngen_CC_Call(shil_opcode*op, void* function)
	{
		int regused = 0;
		int xmmused = 0;

		for (int i = CC_pars.size(); i-- > 0;)
		{
			verify(xmmused < 4 && regused < 4);
			shil_param& prm = *CC_pars[i].prm;
			switch (CC_pars[i].type) {
				//push the contents

			case CPT_u32:
				sh_to_reg(prm, mov, call_regs[regused++]);
				break;

			case CPT_f32:
				sh_to_reg_noimm(prm, movss, call_regsxmm[xmmused++]);
				break;

				//push the ptr itself
			case CPT_ptr:
				verify(prm.is_reg());

				mov(call_regs64[regused++], (size_t)prm.reg_ptr());

				//die("FAIL");

				break;
			}
		}
		call(function);
	}

};

BlockCompiler* compiler;

void ngen_Compile(RuntimeBlockInfo* block, bool force_checks, bool reset, bool staging, bool optimise)
{
	verify(emit_FreeSpace() >= 16 * 1024);

	compiler = new BlockCompiler();

	
	compiler->compile(block, force_checks, reset, staging, optimise);

	delete compiler;
}



void ngen_CC_Start(shil_opcode* op)
{
	compiler->ngen_CC_Start(op);
}

void ngen_CC_Param(shil_opcode* op, shil_param* par, CanonicalParamType tp)
{
	compiler->ngen_CC_param(*op, *par, tp);
}

void ngen_CC_Call(shil_opcode*op, void* function)
{
	compiler->ngen_CC_Call(op, function);
}

void ngen_CC_Finish(shil_opcode* op)
{

}
#endif
