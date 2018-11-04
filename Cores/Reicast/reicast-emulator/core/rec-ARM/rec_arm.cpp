#include <unistd.h>
#include <sys/mman.h>
#include "types.h"

#if FEAT_SHREC == DYNAREC_JIT
#include "hw/sh4/sh4_opcode_list.h"

#include "hw/sh4/sh4_mmr.h"
#include "hw/sh4/sh4_rom.h"
#include "hw/sh4/sh4_interrupts.h"
#include "hw/sh4/sh4_core.h"
#include "hw/sh4/dyna/ngen.h"
#include "hw/sh4/sh4_mem.h"

/*

	ARM ABI
		r0~r1: scratch, params, return
		r2~r3: scratch, params
		8 regs, v6 is platform dependent
			r4~r11
		r12 is "The Intra-Procedure-call scratch register"
		r13 stack
		r14 link
		r15 pc

		Registers f0-s15 (d0-d7, q0-q3) do not need to be preserved (and can be used for passing arguments or returning results in standard procedure-call variants).
		Registers s16-s31 (d8-d15, q4-q7) must be preserved across subroutine calls;
		Registers d16-d31 (q8-q15), if present, do not need to be preserved.

	Block linking
	Reg alloc
		r0~r4: scratch
		r5,r6,r7,r10,r11: allocated
		r8: sh4 cntx
		r9: cycle counter

	Callstack cache

	fpu reg alloc
	d8:d15, single storage

*/

struct DynaRBI: RuntimeBlockInfo
{
	virtual u32 Relink();
	virtual void Relocate(void* dst)
	{

	}
};


#ifdef _ANDROID
#include <sys/syscall.h>  // for cache flushing.
#endif

#if HOST_OS == OS_DARWIN
#include <libkern/OSCacheControl.h>
void CacheFlush(void* code, void* pEnd)
{
    sys_dcache_flush(code, (u8*)pEnd - (u8*)code + 1);
    sys_icache_invalidate(code, (u8*)pEnd - (u8*)code + 1);
}
#elif !defined(ARMCC)
void CacheFlush(void* code, void* pEnd)
{
#if !defined(_ANDROID) && HOST_OS!=OS_DARWIN
	__clear_cache((void*)code, pEnd);
#else
	void* start=code;
	size_t size=(u8*)pEnd-(u8*)start+4;

  // Ideally, we would call
  //   syscall(__ARM_NR_cacheflush, start,
  //           reinterpret_cast<intptr_t>(start) + size, 0);
  // however, syscall(int, ...) is not supported on all platforms, especially
  // not when using EABI, so we call the __ARM_NR_cacheflush syscall directly.

  register uint32_t beg asm("a1") = reinterpret_cast<uint32_t>(start);
  register uint32_t end asm("a2") = reinterpret_cast<uint32_t>(start) + size;
  register uint32_t flg asm("a3") = 0;

  #ifdef __ARM_EABI__
    #if defined (__arm__) && !defined(__thumb__)
      // __arm__ may be defined in thumb mode.
      register uint32_t scno asm("r7") = __ARM_NR_cacheflush;
      asm volatile(
          "svc 0x0"
          : "=r" (beg)
          : "0" (beg), "r" (end), "r" (flg), "r" (scno));
    #else
      // r7 is reserved by the EABI in thumb mode.
      asm volatile(
      "@   Enter ARM Mode  \n\t"
          "adr r3, 1f      \n\t"
          "bx  r3          \n\t"
          ".ALIGN 4        \n\t"
          ".ARM            \n"
      "1:  push {r7}       \n\t"
          "mov r7, %4      \n\t"
          "svc 0x0         \n\t"
          "pop {r7}        \n\t"
      "@   Enter THUMB Mode\n\t"
          "adr r3, 2f+1    \n\t"
          "bx  r3          \n\t"
          ".THUMB          \n"
      "2:                  \n\t"
          : "=r" (beg)
          : "0" (beg), "r" (end), "r" (flg), "r" (__ARM_NR_cacheflush)
          : "r3");
    #endif
  #else
    #if defined (__arm__) && !defined(__thumb__)
      // __arm__ may be defined in thumb mode.
      asm volatile(
          "svc %1"
          : "=r" (beg)
          : "i" (__ARM_NR_cacheflush), "0" (beg), "r" (end), "r" (flg));
    #else
      // Do not use the value of __ARM_NR_cacheflush in the inline assembly
      // below, because the thumb mode value would be used, which would be
      // wrong, since we switch to ARM mode before executing the svc instruction
      asm volatile(
      "@   Enter ARM Mode  \n\t"
          "adr r3, 1f      \n\t"
          "bx  r3          \n\t"
          ".ALIGN 4        \n\t"
          ".ARM            \n"
      "1:  svc 0x9f0002    \n"
      "@   Enter THUMB Mode\n\t"
          "adr r3, 2f+1    \n\t"
          "bx  r3          \n\t"
          ".THUMB          \n"
      "2:                  \n\t"
          : "=r" (beg)
          : "0" (beg), "r" (end), "r" (flg)
          : "r3");
    #endif
  #endif
	#if 0
		const int syscall = 0xf0002;
		__asm __volatile (
			"mov     r0, %0\n"
			"mov     r1, %1\n"
			"mov     r7, %2\n"
			"mov     r2, #0x0\n"
			"svc     0x00000000\n"
			:
			:   "r" (code), "r" (pEnd), "r" (syscall)
			:   "r0", "r1", "r7"
			);
	#endif
#endif
}
#else
asm void CacheFlush(void* code, void* pEnd)
{
	ARM
	push {r7}
	//add r1, r1, r0
	mov r7, #0xf0000
	add r7, r7, #0x2
	mov r2, #0x0
	svc #0x0
	pop {r7}
	bx lr
}
#endif

#define _DEVEL 1

#include "arm_emitter/arm_emitter.h"
using namespace ARM;


// These have to be declared somewhere or linker dies
u8* ARM::emit_opt=0;
eReg ARM::reg_addr;
eReg ARM::reg_dst;
s32 ARM::imma;


typedef ConditionCode eCC;

#define EmitAPI		\
	inline static void

#define lr_r14 r14
#define rfp_r9 r9


typedef void FPBinOP        (eFSReg Sd, eFSReg Sn, eFSReg Sm, ConditionCode CC);
typedef void FPUnOP         (eFSReg Sd, eFSReg Sm,            ConditionCode CC);
typedef void BinaryOP       (eReg Rd, eReg Rn, eReg Rm,       ConditionCode CC);
typedef void BinaryOPImm    (eReg Rd, eReg Rn, s32 sImm8,     ConditionCode CC);
typedef void UnaryOP        (eReg Rd, eReg Rs);


u32* GetRegPtr(u32 reg)
{
	return Sh4_int_GetRegisterPtr((Sh4RegType)reg);
}


// you pick reg, loads Base with reg addr, no reg. mapping yet !
void LoadSh4Reg_mem(eReg Rt, u32 Sh4_Reg, eCC CC=CC_AL)
{
	const u32 shRegOffs = (u8*)GetRegPtr(Sh4_Reg)-sh4_dyna_rcb ;

	LDR(Rt, r8, shRegOffs, Offset, CC);
}


// you pick regs, loads Base with reg addr, no reg. mapping yet !
// data should already exist for Rt !
void StoreSh4Reg_mem(eReg Rt,u32 Sh4_Reg, eCC CC=CC_AL)
{
	const u32 shRegOffs = (u8*)GetRegPtr(Sh4_Reg)-sh4_dyna_rcb ;

	STR(Rt, r8, shRegOffs, Offset, CC);
}


EmitAPI LoadSh4Reg_mem(eReg Rt, shil_param Sh4_Reg, eCC CC=CC_AL)
{
	if (!Sh4_Reg.is_r32())
		printf("REG FAIL: %d\n",Sh4_Reg._reg);
	verify(Sh4_Reg.is_r32());
	LoadSh4Reg_mem(Rt,Sh4_Reg._reg,CC);
}

EmitAPI StoreSh4Reg_mem(eReg Rt, shil_param Sh4_Reg, eCC CC=CC_AL)
{
	verify(Sh4_Reg.is_r32());
	StoreSh4Reg_mem(Rt,Sh4_Reg._reg,CC);
}


EmitAPI LoadSh4Reg64(eReg Rt, shil_param Sh4_Reg, eCC CC=CC_AL)
{
	verify(Sh4_Reg.is_r64());
	//possibly use ldm/ldrd ?
	LoadSh4Reg_mem(Rt,Sh4_Reg._reg,CC);
	LoadSh4Reg_mem((eReg)(Rt+1),Sh4_Reg._reg+1,CC);
}

EmitAPI StoreSh4Reg64(eReg Rt, shil_param Sh4_Reg, eCC CC=CC_AL)
{
	verify(Sh4_Reg.is_r64());
	//possibly use stm/strd ?
	StoreSh4Reg_mem(Rt,Sh4_Reg._reg,CC);
	StoreSh4Reg_mem((eReg)(Rt+1),Sh4_Reg._reg+1,CC);
}


#include "hw/sh4/dyna/regalloc.h"

#if HOST_OS == OS_DARWIN
eReg alloc_regs[]={r5,r6,r7,r10,(eReg)-1};
#else
eReg alloc_regs[]={r5,r6,r7,r10,r11,(eReg)-1};
#endif
eFSReg alloc_fpu[]={f16,f17,f18,f19,f20,f21,f22,f23,
					f24,f25,f26,f27,f28,f29,f30,f31,(eFSReg)-1};

struct arm_reg_alloc: RegAlloc<eReg,eFSReg,false>
{

	virtual eFSReg FpuMap(u32 reg)
	{
		if (reg>=reg_fr_0 && reg<=reg_fr_15)
		{
			return alloc_fpu[reg-reg_fr_0];
		}
		else
			return (eFSReg)-1;
	}

	virtual void Preload(u32 reg,eReg nreg)
	{
		verify(reg!=reg_pc_dyn);
		LoadSh4Reg_mem(nreg,reg);
	}
	virtual void Writeback(u32 reg,eReg nreg)
	{
		if (reg==reg_pc_dyn)
			;//MOV(r4,nreg);
		else
			StoreSh4Reg_mem(nreg,reg);
	}

	virtual void Preload_FPU(u32 reg,eFSReg nreg)
	{
		const s32 shRegOffs = (u8*)GetRegPtr(reg)-sh4_dyna_rcb ;

		VLDR((nreg),r8,shRegOffs/4);
	}
	virtual void Writeback_FPU(u32 reg,eFSReg nreg)
	{
		const s32 shRegOffs = (u8*)GetRegPtr(reg)-sh4_dyna_rcb ;

		VSTR((nreg),r8,shRegOffs/4);
	}
	/*
	eFSReg fd0_to_fs(eFDReg fd0)
	{
		eFSReg rv=(eFSReg)(fd0*2);
		verify(rv<32);
		return rv;
	}
	*/
	eFSReg mapfs(const shil_param& prm)
	{
		return mapf(prm);
	}

};


arm_reg_alloc reg;


#ifdef naked
#undef naked
#define naked __attribute__((naked))
#endif




u32 blockno=0;


//extern "C" void no_update();
//extern "C" void intc_sched();
//extern "C" void ngen_blockcheckfail();
//
//
//extern "C" void ngen_LinkBlock_Generic_stub();
//extern "C" void ngen_LinkBlock_cond_Branch_stub();
//extern "C" void ngen_LinkBlock_cond_Next_stub();
//extern "C" void ngen_FailedToFindBlock_();

#ifdef __LP64__
void ngen_FailedToFindBlock_internalARM64() {
    rdv_FailedToFindBlock(Sh4cntx.pc);
}
void(*ngen_FailedToFindBlock)() = &ngen_FailedToFindBlock_internalARM64;
#else
void (*ngen_FailedToFindBlock)()=&ngen_FailedToFindBlock_;  // in asm
#endif

#include <map>

map<shilop,ConditionCode> ccmap;
map<shilop,ConditionCode> ccnmap;

//u32 DynaRBI::Relink()
//{
//    verify(emit_ptr==0);
//    u8* code_start=(u8*)code+relink_offset;
//    emit_ptr=(u32*)code_start;
//
//    switch(BlockType)
//    {
//    case BET_Cond_0:
//    case BET_Cond_1:
//    {
//        //quick opt here:
//        //peek into reg alloc, store actuall sr_T register to relink_data
//        bool last_op_sets_flags=!has_jcond && oplist.size() > 0 &&
//            oplist[oplist.size()-1].rd._reg==reg_sr_T && ccmap.count(oplist[oplist.size()-1].op);
//
//        ConditionCode CC=CC_EQ;
//
//        if (last_op_sets_flags)
//        {
//            shilop op=oplist[oplist.size()-1].op;
//
//            verify(ccmap.count(op)>0);
//
//            if ((BlockType&1)==1)
//                CC=ccmap[op];
//            else
//                CC=ccnmap[op];
//        }
//        else
//        {
//            if (!has_jcond)
//            {
//                printf("SLOW COND PATH %d\n",oplist[oplist.size()-1].op);
//                LoadSh4Reg_mem(r4,reg_sr_T);
//            }
//
//            CMP(r4,(BlockType&1));
//        }
//
//        if (pBranchBlock)
//            JUMP((unat)pBranchBlock->code,CC);
//        else
//            CALL((unat)ngen_LinkBlock_cond_Branch_stub,CC);
//
//        if (pNextBlock)
//            JUMP((unat)pNextBlock->code);
//        else
//            CALL((unat)ngen_LinkBlock_cond_Next_stub);
//        break;
//    }
//
//
//    case BET_DynamicRet:
//    case BET_DynamicCall:
//    case BET_DynamicJump:
//    {
//#ifdef CALLSTACK
//#error offset broken
//        SUB(r2, r8, -FPCB_OFFSET);
//#if RAM_SIZE == 33554432
//        UBFX(r1, r4, 1, 24);
//#else
//        UBFX(r1, r4, 1, 23);
//#endif
//
//        if (BlockType==BET_DynamicRet)
//        {
//            LDR(r14,r2,r1,Offset,true,S_LSL,2);
//            BX(R14);    //BX LR (ret hint)
//        }
//        else if (BlockType==BET_DynamicCall)
//        {
//            LDR(r0,r2,r1,Offset,true,S_LSL,2);
//            BLX(r0);    //BLX r0 (call hint)
//        }
//        else
//        {
//            LDR(r15,r2,r1,Offset,true,S_LSL,2);
//        }
//#else
//        if (relink_data==0)
//        {
//#if 1
//            //this is faster
//            //why ? (Icache ?)
//            SUB(r2, r8, -FPCB_OFFSET);
//#if RAM_SIZE == 33554432
//            UBFX(r1, r4, 1, 24);
//#else
//            UBFX(r1, r4, 1, 23);
//#endif
//            LDR(r15,r2,r1,Offset,true,S_LSL,2);
//
//#else
//            if (pBranchBlock)
//            {
//                MOV32(r1,pBranchBlock->addr);           //2
//                CMP(r4,r1);                             //1
//                JUMP((unat)pBranchBlock->code,CC_EQ);   //1
//                CALL((unat)ngen_LinkBlock_Generic_stub);//1
//            }
//            else
//            {
//                SUB(r2, r8, -FPCB_OFFSET);
//
//#if RAM_SIZE == 33554432
//                UBFX(r1, r4, 1, 24);
//#else
//                UBFX(r1, r4, 1, 23);
//#endif
//                NOP();NOP();                            //2
//                LDR(r15,r2,r1,Offset,true,S_LSL,2);     //1
//            }
//#endif
//        }
//        else
//        {
//            verify(pBranchBlock==0);
//            SUB(r2, r8, -FPCB_OFFSET);
//
//#if RAM_SIZE == 33554432
//            UBFX(r1, r4, 1, 24);
//#else
//            UBFX(r1, r4, 1, 23);
//#endif
//            LDR(r15,r2,r1,Offset,true,S_LSL,2);
//        }
//#endif
//        break;
//    }
//
//    case BET_StaticCall:
//    case BET_StaticJump:
//    {
//        if (pBranchBlock==0)
//            CALL((unat)ngen_LinkBlock_Generic_stub);
//        else
//        {
//#ifdef CALLSTACK
//            if (BlockType==BET_StaticCall)
//                CALL((unat)pBranchBlock->code);
//            else
//#endif
//                JUMP((unat)pBranchBlock->code);
//        }
//        break;
//    }
//
//    case BET_StaticIntr:
//    case BET_DynamicIntr:
//        {
//            if (BlockType==BET_StaticIntr)
//            {
//                MOV32(r4,NextBlock);
//            }
//            //else -> already in r4 djump !
//
//            StoreSh4Reg_mem(r4,reg_nextpc);
//
//            CALL((unat)UpdateINTC);
//            LoadSh4Reg_mem(r4,reg_nextpc);
//            JUMP((unat)no_update);
//            break;
//        }
//
//    default:
//        printf("Error, Relink() Block Type: %X\n", BlockType);
//        verify(false);
//        break;
//    }
//
//    CacheFlush(code_start,emit_ptr);
//
//    u32 sz=(u8*)emit_ptr-code_start;
//
//    emit_ptr=0;
//    return sz;
//}

void ngen_Unary(shil_opcode* op, UnaryOP unop)
{
	unop(reg.mapg(op->rd),reg.mapg(op->rs1));
}

void ngen_Binary(shil_opcode* op, BinaryOP dtop,BinaryOPImm dtopimm, bool has_imm=true)
{
	verify(reg.mapg(op->rd)!=r0 && reg.mapg(op->rs1)!=r0);
	
	eReg rs2=r0;
	if (has_imm && op->rs2.is_imm())    // **FIXME** ???
	{
		if (is_i8r4(op->rs2._imm))
		{
			dtopimm(reg.mapg(op->rd), reg.mapg(op->rs1), op->rs2._imm, CC_AL);
			return;
		}
		else
		{
			MOV32(rs2,(u32)op->rs2._imm);
		}
	}
	else if (op->rs2.is_r32i())  // **FIXME** Correct?
	{
		rs2=reg.mapg(op->rs2);
	}
	else
	{
		printf("ngen_Bin ??? %d \n",op->rs2.type);
		verify(false);
	}

	dtop(reg.mapg(op->rd),reg.mapg(op->rs1), rs2, CC_AL);
}

void ngen_fp_bin(shil_opcode* op, const FPBinOP fpop)
{
	verify(op->rs1.is_r32f());
	verify(op->rs2.is_r32f());

	fpop(reg.mapfs(op->rd),reg.mapfs(op->rs1),reg.mapfs(op->rs2),CC_AL);
}
void ngen_fp_una(shil_opcode* op, const FPUnOP fpop)
{
	verify(op->rd.is_r32f());
	verify(op->rs1.is_r32f());

	fpop(reg.mapfs(op->rd),reg.mapfs(op->rs1),CC_AL);
}

struct CC_PS
{
	CanonicalParamType type;
	shil_param* par;
};
vector<CC_PS> CC_pars;
void ngen_CC_Start(shil_opcode* op) 
{ 
	CC_pars.clear();
}
void ngen_CC_Param(shil_opcode* op,shil_param* par,CanonicalParamType tp) 
{ 
	switch(tp)
	{
		case CPT_f32rv:
		#ifdef ARM_HARDFP
			{
				if (reg.IsAllocg(*par))
				{
					//printf("MOV(reg.map(*par),r0); %d\n",reg.map(*par));
					VMOV(reg.mapg(*par),f0);
				}
				else if (reg.IsAllocf(*par))
				{
					//VMOV(reg.mapf(*par),0,r0); %d\n",reg.map(*par));
					VMOV(reg.mapfs(*par),f0);
				}
			}
			break;
		#endif

		case CPT_u32rv:
		case CPT_u64rvL:
			{
				if (reg.IsAllocg(*par))
				{
					//printf("MOV(reg.map(*par),r0); %d\n",reg.map(*par));
					MOV(reg.mapg(*par),r0);
				}
				else if (reg.IsAllocf(*par))
				{
					//VMOV(reg.mapf(*par),0,r0); %d\n",reg.map(*par));
					VMOV(reg.mapfs(*par),r0);
				}
			}
			break;

		case CPT_u64rvH:
			{
				verify(reg.IsAllocg(*par));

				MOV(reg.mapg(*par),r1);
			}
			break;

		case CPT_u32:
		case CPT_ptr:
		case CPT_f32:
			{
				CC_PS t={tp,par};
				CC_pars.push_back(t);
			}
			break;

		default:
			die("invalid tp");
	}
}

void ngen_CC_Call(shil_opcode* op,void* function) 
{
	u32 rd=r0;
	u32 fd=f0;

	for (int i=CC_pars.size();i-->0;)
	{
		if (CC_pars[i].type==CPT_ptr)
		{
			MOV32((eReg)rd, (unat)CC_pars[i].par->reg_ptr());
		}
		else
		{
			if (CC_pars[i].par->is_reg())
			{
				#ifdef ARM_HARDFP
				if (CC_pars[i].type == CPT_f32) 
				{
					if (reg.IsAllocg(*CC_pars[i].par))
					{
						//printf("MOV((eReg)rd,reg.map(*CC_pars[i].par)); %d %d\n",rd,reg.map(*CC_pars[i].par));
						VMOV((eFSReg)fd,reg.mapg(*CC_pars[i].par));
					}
					else if (reg.IsAllocf(*CC_pars[i].par))
					{
						//printf("LoadSh4Reg_mem((eReg)rd, *CC_pars[i].par); %d\n",rd);
						VMOV((eFSReg)fd,reg.mapfs(*CC_pars[i].par));
					}
					else
						die("Must not happen!\n");
					continue;
				}
				#endif

				if (reg.IsAllocg(*CC_pars[i].par))
				{
					//printf("MOV((eReg)rd,reg.map(*CC_pars[i].par)); %d %d\n",rd,reg.map(*CC_pars[i].par));
					MOV((eReg)rd,reg.mapg(*CC_pars[i].par));
				}
				else if (reg.IsAllocf(*CC_pars[i].par))
				{
					//printf("LoadSh4Reg_mem((eReg)rd, *CC_pars[i].par); %d\n",rd);
					VMOV((eReg)rd,reg.mapfs(*CC_pars[i].par));
				}
				else
					die("Must not happen!\n");
			}
			else
			{
				verify(CC_pars[i].type != CPT_f32);
				//printf("MOV32((eReg)rd, CC_pars[i].par->_imm); %d\n",rd);
				MOV32((eReg)rd, CC_pars[i].par->_imm);
			}
		}
		rd++;
	}
	//printf("used reg r0 to r%d, %d params, calling %08X\n",rd-1,CC_pars.size(),function);
	CALL((unat)function);
}
void ngen_CC_Finish(shil_opcode* op) 
{ 
	CC_pars.clear(); 
}

void* _vmem_read_const(u32 addr,bool& ismem,unat sz);
void* _vmem_page_info(unat addr,bool& ismem,unat sz,unat& page_sz, bool rw);


enum mem_op_type
{
	SZ_8,
	SZ_16,
	SZ_32I,
	SZ_32F,
	SZ_64F,
};

mem_op_type memop_type(shil_opcode* op)
{

	int Lsz=-1;
	int sz=op->flags&0x7f;

	bool fp32=op->rs2.is_r32f() || op->rd.is_r32f();

	if (sz==1) Lsz=SZ_8;
	if (sz==2) Lsz=SZ_16;
	if (sz==4 && !fp32) Lsz=SZ_32I;
	if (sz==4 && fp32) Lsz=SZ_32F;
	if (sz==8) Lsz=SZ_64F;

	verify(Lsz!=-1);
	
	return (mem_op_type)Lsz;
}

u32 memop_bytes(mem_op_type tp)
{
	const u32 rv[] = { 1,2,4,4,8};

	return rv[tp];
}

/*
	8/16/32 I R/W B
	ubfx r0,raddr,..
	ldr(sh/sb)/str(h/b) rd/s,[r0+r8]

	32/64 F R/W B
	ubfx r0,raddr,..
	add r0,r0,r8
	vldr/vstr rd/s,[r0] {32 or 64 bit forms}


	32 I / 32/64 F W SQ
	ubfx r0,raddr,..
	add r0,r0,r8
	str/vstr/vstr.d rs,[r0-offs]

	8/16/32 I R/W M
	mov r0,raddr
	call MEMHANDLER<rd/s>

	32/64 F R M
	mov r0,raddr
	vmov r1,rs // vmov.d r3:r2,rs
	call MEMHANDER<r1> // call MEMHANDLER64

	32/64 F W M
	mov r0,raddr
	call MEMHANDER<r1> // call MEMHANDLER64
	vmov rd,r0 // vmov.d rd,r3:r2
*/
unat _mem_hndl_SQ32[14];
unat _mem_hndl[2][3][14];
unat _mem_func[2][5]=
{
	{0,0,0,(unat)_vmem_WriteMem32,(unat)_vmem_WriteMem64},
	{0,0,0,(unat)_vmem_ReadMem32,(unat)_vmem_ReadMem64},
};

struct 
{
	u32 mask;
	u32 key;
	bool read;
	mem_op_type optp;
	u32 offs;
}
op_table[]=
{
	//LDRSB
	{0x0E500FF0,0x001000D0,true,SZ_8,1},
	//LDRSH
	{0x0E500FF0,0x001000F0,true,SZ_16,1},
	//LDR
	{0x0E500010,0x06100000,true,SZ_32I,1},
	//VLDR.32
	{0x0F300F00,0x0D100A00,true,SZ_32F,2},
	//VLDR.64
	{0x0F300F00,0x0D100B00,true,SZ_64F,2},

	//
	//STRB
	{0x0FF00010,0x07C00000,false,SZ_8,1},
	//STRH
	{0x0FF00FF0,0x018000B0,false,SZ_16,1},
	//STR
	{0x0E500010,0x06000000,false,SZ_32I,1},
	//VSTR.32
	{0x0F300F00,0x0D000A00,false,SZ_32F,2},
	//VSTR.64
	{0x0F300F00,0x0D000B00,false,SZ_64F,2},
	
	{0,0},
};

union arm_mem_op
{
	struct
	{
		unat Ra:4;
		unat pad0:8;
		unat Rt:4;
		unat Rn:4;
		unat pad1:2;
		unat D:1;
		unat pad3:1;
		unat pad4:4;
		unat cond:4;
	};

	unat full;
};

void vmem_slowpath(eReg raddr, eReg rt, eFSReg ft, eFDReg fd, mem_op_type optp, bool read)
{
	if (raddr != r0)
		MOV(r0, (eReg)raddr);

	if (!read)
	{
		if (optp <= SZ_32I) MOV(r1, rt);
		else if (optp == SZ_32F) VMOV(r1, ft);
		else if (optp == SZ_64F) VMOV(r2, r3, fd);
	}

	if (fd != d0 && optp == SZ_64F)
	{
		die("BLAH");
	}

	unat funct = 0;

	if (optp <= SZ_32I)
		funct = _mem_hndl[read][optp][raddr];
	else
		funct = _mem_func[read][optp];

	verify(funct != 0);
	CALL(funct);

	if (read)
	{
		if (optp <= SZ_32I) MOV(rt, r0);
		else if (optp == SZ_32F) VMOV(ft, r0);
		else if (optp == SZ_64F) VMOV(fd, r0, r1);
	}
}

unat* ngen_readm_fail_v2(unat* ptrv,unat* regs,unat fault_addr)
{
	arm_mem_op* ptr=(arm_mem_op*)ptrv;

	verify(sizeof(*ptr)==4);

	mem_op_type optp;
	unat read=0;
	s32 offs=-1;

	unat fop=ptr[0].full;

	for (int i=0;op_table[i].mask;i++)
	{
		if ((fop&op_table[i].mask)==op_table[i].key)
		{
			optp=op_table[i].optp;
			read=op_table[i].read;
			offs=op_table[i].offs;
		}
	}

	if (offs==-1)
	{
		printf("%08X : invalid size\n",ptr[0]);
		die("can't decode opcode\n");
	}

	ptr -= offs;

	eReg raddr,rt;
	eFSReg ft;
	eFDReg fd;

	//Get used regs from opcodes ..
	
	if ((ptr[0].full & 0x0FE00070)==0x07E00050)
	{
		//from ubfx !
		raddr=(eReg)(ptr[0].Ra);
	}
	else if ((ptr[0].full & 0x0FE00000)==0x03C00000)
	{
		raddr=(eReg)(ptr[0].Rn);
	}
	else
	{
		printf("fail raddr %08X {@%08X}:(\n",ptr[0].full,regs[1]);
		die("Invalid opcode: vmem fixup\n");
	}
	//from mem op
	rt=(eReg)(ptr[offs].Rt);
	ft=(eFSReg)(ptr[offs].Rt*2 + ptr[offs].D);
	fd=(eFDReg)(ptr[offs].D*16 + ptr[offs].Rt);

	//get some other relevant data
	unat sh4_addr=regs[raddr];
	unat fault_offs=fault_addr-regs[8];
	u8* sh4_ctr=(u8*)regs[8];
	bool is_sq=(sh4_addr>>26)==0x38;

	verify(emit_ptr==0);
	emit_ptr=(u32*)ptr;


	/*
			mov r0,raddr

		8/16/32I:
			call _mem_hdlp[read][optp][rt]
		32F/64F:
	32F,r:	vmov r1,ft
	64F,r:	vmov [r3:r2],fd
			call _mem_hdlp[read][optp][0]
	32F,w:	vmov ft,r0
	64F,w:	vmov fd,[r1:r0]
	*/
	
	
	//printf("Failed %08X:%08X (%d,%d,%d,r%d, r%d,f%d,d%d) code %08X, addr %08X, native %08X (%08X), fixing via %s\n",ptr->full,fop,optp,read,offs,raddr,rt,ft,fd,ptr,sh4_addr,fault_addr,fault_offs,is_sq?"SQ":"MR");

	//fault offset must always be the addr from ubfx (sanity check)
	verify((fault_offs==0) || fault_offs==(0x1FFFFFFF&sh4_addr));

	if (settings.dynarec.unstable_opt && is_sq) //THPS2 uses cross area SZ_32F so this is disabled for now
	{
		//SQ !
		s32 sq_offs=sq_both-sh4_ctr;
		verify(sq_offs==rcb_noffs(sq_both));
		
		verify(!read && optp>=SZ_32I);

		if (optp==SZ_32I)
		{
			MOV(r1,rt);

			CALL((unat)_mem_hndl_SQ32[raddr]);
		}
		else
		{
			//UBFX(r1,raddr,0,6);
			AND(r1,raddr,0x3F);
			ADD(r1,r1,r8);

			if (optp==SZ_32I) STR(rt,r1,sq_offs); // cross writes are possible, so this can't be assumed
			else if (optp==SZ_32F) VSTR(ft,r1,sq_offs/4);
			else if (optp==SZ_64F) VSTR(fd,r1,sq_offs/4);
		}
	}
	else
	{
		//Fallback to function !

		if (offs==2)
		{
			if (raddr!=r0)
				MOV(r0,(eReg)raddr);
			else
				NOP();
		}

		if (!read)
		{
			if (optp<=SZ_32I) MOV(r1,rt);
			else if (optp==SZ_32F) VMOV(r1,ft);
			else if (optp==SZ_64F) VMOV(r2,r3,fd);
		}

		if (fd!=d0 && optp==SZ_64F)
		{
			die("BLAH");
		}

		unat funct=0;

		if (offs==1)
			funct=_mem_hndl[read][optp][raddr];
		else if (offs==2)
			funct=_mem_func[read][optp];

		verify(funct!=0);
		CALL(funct);

		if (read)
		{
			if (optp<=SZ_32I) MOV(rt,r0);
			else if (optp==SZ_32F) VMOV(ft,r0);
			else if (optp==SZ_64F) VMOV(fd,r0,r1);
		}
	}


	CacheFlush((void*)ptr, (void*)emit_ptr);
	emit_ptr=0;

	return (unat*)ptr;
}

extern u8* virt_ram_base;

EAPI NEG(eReg Rd,eReg Rs)
{
	RSB(Rd,Rs,0);
}

EAPI NEG(eReg Rd,eReg Rs, bool S, ConditionCode cond = CC_AL)
{
	RSB(Rd,Rs,0, S, cond);
}

eReg GenMemAddr(shil_opcode* op,eReg raddr=r0)
{
	if (op->rs3.is_imm())
	{
		if(is_i8r4(op->rs3._imm))
		{
			ADD(raddr,reg.mapg(op->rs1),op->rs3._imm);
		}
		else 
		{
			MOV32(r1,op->rs3._imm);
			ADD(raddr,reg.mapg(op->rs1),r1);
		}
	}
	else if (op->rs3.is_r32i())
	{
		ADD(raddr,reg.mapg(op->rs1),reg.mapg(op->rs3));
	}
	else if (!op->rs3.is_null())
	{
		printf("rs3: %08X\n",op->rs3.type);
		die("invalid rs3");
	}
	else
	{
		raddr = reg.mapg(op->rs1);
	}

	return raddr;
}

void ngen_compile_opcode(RuntimeBlockInfo* block, shil_opcode* op, bool staging, bool optimise)
{
	switch(op->op)
	{
		case shop_readm:
		{
			mem_op_type optp=memop_type(op);
			if (op->rs1.is_imm())
			{
				bool isram=false;
				void* ptr=_vmem_read_const(op->rs1._imm,isram,memop_bytes(optp));
				
				verify(optp!=SZ_64F);

				if (isram)
				{
					switch(optp)
					{
					case SZ_8:
						{
							verify(false);
							MOV32(r0,(unat)ptr);
							LDRB(reg.mapg(op->rd),r0);
							SXTB(reg.mapg(op->rd),reg.mapg(op->rd));
						} 
						break;

					case SZ_16:
						{
							LoadImmBase16(reg.mapg(op->rd),(unat)ptr,true);    // true for sx
						} 
						break;

					case SZ_32I:
						{
							verify(reg.IsAllocg(op->rd));
							{
								if (optimise && staging && !is_s8(*(unat*)ptr) && abs((int)op->rs1._imm-(int)block->addr)<=1024)
								{
									op->flags|=0x40000000;

									MOV32(r0,(unat)ptr);
									LDR(reg.mapg(op->rd),r0);
									MOV32(r1,*(unat*)ptr);
									CMP(reg.mapg(op->rd),r1);
									//JUMP((unat)EMIT_GET_PTR()+24,CC_EQ);
									MOV32(r1,(unat)&op->flags);
									MOV32(r2,~0x40000000);
									LDR(r3,r1);
									AND(r3,r3,r2,CC_NE);
									STR(r3,r1);
								}
								else if (optimise && !staging && op->flags & 0x40000000)
								{
									MOV32(reg.mapg(op->rd),*(unat*)ptr);
								}
								else
								{
									MOV32(r0,(unat)ptr);
									LDR(reg.mapg(op->rd),r0);
								}
							}
						}
						break;

					case SZ_32F:
						{
							verify(reg.IsAllocf(op->rd));
							MOV32(r0,(unat)ptr);
							VLDR(reg.mapfs(op->rd),r0,0);

						}
						break;

					case SZ_64F:
						{
							verify(false);
							MOV32(r0,(unat)ptr);
							LDR(r1,r0,4);
							LDR(r0,r0,0);
						}
						break;
					}
				} 
				else 
				{
					MOV32(r0,op->rs1._imm);

					switch(optp)
					{
					case SZ_8: CALL((unat)ptr); SXTB(r0,r0); break;

					case SZ_16: CALL((unat)ptr); SXTH(r0,r0); break;

					case SZ_32I:
					case SZ_32F: CALL((unat)ptr); break;

					case SZ_64F:
						die("SZ_64F not supported");
						break;
					}

					if (reg.IsAllocg(op->rd))
						MOV(reg.mapg(op->rd),r0);
					else
						VMOV(reg.mapfs(op->rd),r0);
				}
			}
			else
			{
				eReg raddr=GenMemAddr(op);

				if (_nvmem_enabled()) {
					BIC(r1,raddr,0xE0000000);

					switch(optp)
					{
					case SZ_8:	
						LDRSB(reg.mapg(op->rd),r1,r8,true); 
						break;

					case SZ_16: 
						LDRSH(reg.mapg(op->rd),r1,r8,true); 
						break;

					case SZ_32I: 
						LDR(reg.mapg(op->rd),r1,r8,Offset,true); 
						break;

					case SZ_32F:
						ADD(r1,r1,r8);	//3 opcodes, there's no [REG+REG] VLDR
						VLDR(reg.mapf(op->rd),r1,0);
						break;

					case SZ_64F:
						ADD(r1,r1,r8);	//3 opcodes, there's no [REG+REG] VLDR
						VLDR(d0,r1,0);	//TODO: use reg alloc

						VSTR(d0,r8,op->rd.reg_nofs()/4);
						break;
					}
				} else {
					switch(optp)
					{
					case SZ_8:	
						vmem_slowpath(raddr, reg.mapg(op->rd), f0, d0, optp, true);
						break;

					case SZ_16: 
						vmem_slowpath(raddr, reg.mapg(op->rd), f0, d0, optp, true);
						break;

					case SZ_32I: 
						vmem_slowpath(raddr, reg.mapg(op->rd), f0, d0, optp, true);
						break;

					case SZ_32F:
						vmem_slowpath(raddr, r0, reg.mapf(op->rd), d0, optp, true);
						break;

					case SZ_64F:
						vmem_slowpath(raddr, r0, f0, d0, optp, true);
						VSTR(d0,r8,op->rd.reg_nofs()/4);
						break;
					}
				}
			}
		}
		break;


		case shop_writem:
		{
			mem_op_type optp=memop_type(op);

			eReg raddr=GenMemAddr(op);
			
			//TODO: use reg alloc
			if (optp == SZ_64F)
				VLDR(d0,r8,op->rs2.reg_nofs()/4);

			if (_nvmem_enabled()) {
				BIC(r1,raddr,0xE0000000);
				//UBFX(r1,raddr,0,29);
				//SUB(r1,raddr,raddr);
				
				s32 sq_offs=rcb_noffs(sq_both);
				switch(optp)
				{
				case SZ_8:
					STRB(reg.mapg(op->rs2),r1,r8,Offset,true);
					break;

				case SZ_16:
					STRH(reg.mapg(op->rs2),r1,r8,true);
					break;

				case SZ_32I:
					if (op->flags2!=0x1337)
						STR(reg.mapg(op->rs2),r1,r8,Offset,true); 
					else
					{
						emit_Skip(-4);
						AND(r1,raddr,0x3F);
						ADD(r1,r1,r8);
						STR(reg.mapg(op->rs2),r1,sq_offs);
					}
					break;

				case SZ_32F:
					if (op->flags2!=0x1337)
					{
						ADD(r1,r1,r8);	//3 opcodes: there's no [REG+REG] VLDR, also required for SQ
						VSTR(reg.mapf(op->rs2),r1,0);
					}
					else
					{
						emit_Skip(-4);
						AND(r1,raddr,0x3F);
						ADD(r1,r1,r8);
						VSTR(reg.mapf(op->rs2),r1,sq_offs/4);
					}
					break;

				case SZ_64F:
					if (op->flags2!=0x1337)
					{
						ADD(r1,r1,r8);	//3 opcodes: there's no [REG+REG] VLDR, also required for SQ
						VSTR(d0,r1,0);	//TODO: use reg alloc
					}
					else
					{
						emit_Skip(-4);
						AND(r1,raddr,0x3F);
						ADD(r1,r1,r8);
						VSTR(d0,r1,sq_offs/4);
					}
					break;
				}
			} else {
				switch(optp)
				{
				case SZ_8:
					vmem_slowpath(raddr, reg.mapg(op->rs2), f0, d0, optp, false);
					break;

				case SZ_16:
					vmem_slowpath(raddr, reg.mapg(op->rs2), f0, d0, optp, false);
					break;

				case SZ_32I:
					vmem_slowpath(raddr, reg.mapg(op->rs2), f0, d0, optp, false);
					break;

				case SZ_32F:
					vmem_slowpath(raddr, r0, reg.mapf(op->rs2), d0, optp, false);
					break;

				case SZ_64F:
					vmem_slowpath(raddr, r0, f0, d0, optp, false);
					break;
				}
			}
		}
		break;

		//dynamic jump, r+imm32.This will be at the end of the block, but doesn't -have- to be the last opcode
		case shop_jdyn:
		{
			//ReadReg rs1(r4,op->rs1);
			reg.writeback_gpr--;
			verify(op->rd.is_reg() && op->rd._reg==reg_pc_dyn);
			if (op->rs2.is_imm())
			{
				MOV32(r2, (unat)op->rs2._imm);
				ADD(r4,reg.mapg(op->rs1),r2);
			}
			else //if (r4!=rs1.reg)
			{
				MOV(r4, reg.mapg(op->rs1));
			}
			break;
		}

		case shop_mov32:
			{
				verify(op->rd.is_r32());

				if (op->rs1.is_imm())
				{
					if (op->rd.is_r32i())
					{
						MOV32(reg.mapg(op->rd),op->rs1._imm);
					}
					else
					{
						verify(op->rs1._imm==0 || op->rs1._imm==0x3F800000);
						if (op->rs1._imm==0)
						{
							//VEOR(reg.mapf(op->rd),reg.mapf(op->rd),reg.mapf(op->rd));
							//hum, vmov can't do 0, but can do all kind of weird small consts ... really useful ...
							//simd is slow on a9
#if 0
							MOVW(r0,0);
							VMOV(reg.mapfs(op->rd),r0);
#else
							//1-1=0 !
							//should be slightly faster ...
							//we could get rid of the imm mov, if not for infs & co ..
							VMOV(reg.mapfs(op->rd),fpu_imm_1);
							VSUB_VFP(reg.mapfs(op->rd),reg.mapfs(op->rd),reg.mapfs(op->rd));
#endif
						}
						else
							VMOV(reg.mapfs(op->rd),fpu_imm_1);
					}
				}
				else if (op->rs1.is_r32())
				{
					unat type=0;

					if (reg.IsAllocf(op->rd))
						type|=1;
					
					if (reg.IsAllocf(op->rs1))
						type|=2;

					switch(type)
					{
					case 0: //reg=reg
						if (reg.mapg(op->rd)!=reg.mapg(op->rs1))
							MOV(reg.mapg(op->rd),reg.mapg(op->rs1));
						break;

					case 1: //vfp=reg
						VMOV(reg.mapfs(op->rd),reg.mapg(op->rs1));
						break;

					case 2: //reg=vfp
						VMOV(reg.mapg(op->rd),reg.mapfs(op->rs1));
						break;

					case 3: //vfp=vfp
						VMOV(reg.mapfs(op->rd),reg.mapfs(op->rs1));
						break;
					}
				}
				else
				{
					die("Invalid mov32 size");
				}
				
			}
			break;
			
		case shop_mov64:
		{
			verify(op->rs1.is_r64() && op->rd.is_r64());
			//LoadSh4Reg64(r0,op->rs1);
			//StoreSh4Reg64(r0,op->rd);
			
			VLDR(d0,r8,op->rs1.reg_nofs()/4);
			VSTR(d0,r8,op->rd.reg_nofs()/4);
			break;
		}

		case shop_jcond:
		{
			verify(op->rd.is_reg() && op->rd._reg==reg_pc_dyn);
			//ReadReg rs1(r4,op->rs1);

			//if (r4!=rs1.reg)
				MOV(r4,reg.mapg(op->rs1));
			break;
		}

		case shop_ifb:
		{
			if (op->rs1._imm) 
			{
				MOV32(r1,op->rs2._imm);
				StoreSh4Reg_mem(r1,reg_nextpc);
				//StoreImms(r3,r2,(unat)&next_pc,(unat)op->rs2._imm);
			}

			MOV32(r0, op->rs3._imm);
			CALL((unat)(OpPtr[op->rs3._imm]));
			break;
		}

//#define CANONICALTEST
#ifndef CANONICALTEST
		case shop_neg: ngen_Unary(op,NEG);     break;
		case shop_not: ngen_Unary(op,NOT);     break;


		case shop_shl: ngen_Binary(op,LSL,LSL); break;
		case shop_shr: ngen_Binary(op,LSR,LSR); break;
		case shop_sar: ngen_Binary(op,ASR,ASR); break;

		case shop_and:  ngen_Binary(op,AND,AND);    break;
		case shop_or:   ngen_Binary(op,ORR,ORR);    break;
		case shop_xor:	ngen_Binary(op,EOR,EOR);    break;

		case shop_add:	ngen_Binary(op,ADD,ADD);    break;
		case shop_sub:	ngen_Binary(op,SUB,SUB);    break;
		case shop_ror:	ngen_Binary(op,ROR,ROR);    break;

			
		case shop_adc:
		{
			//RSBS(reg.map(op.rs3),reg.map(op.rs3),0);
			//ADCS(reg.map(op.rs1),reg.map(op.rs2),reg.map(op.rs3));
			//ADC(reg.map(op.rs3),reg.map(op.rs3),reg.map(op.rs3),LSL,31);

			//ADD(r0,reg.map(op.rs1),

#if 0
			MOVW(r1,0);
			ADD(r0,reg.mapg(op->rs1),reg.mapg(op->rs2),true);
			ADC(r1,r1,0);
			ADD(reg.mapg(op->rd),r0,reg.mapg(op->rs3),true);
			ADC(reg.mapg(op->rd2),r1,0);
#else

			LSR(r0,reg.mapg(op->rs3),1,true); //C=rs3, r0=0
			ADC(reg.mapg(op->rd),reg.mapg(op->rs1),reg.mapg(op->rs2),true); //(C,rd)=rs1+rs2+rs3(C)
			ADC(reg.mapg(op->rd2),r0,0);	//rd2=C, (or MOVCS rd2, 1)
#endif
		}
		break;

		case shop_rocr:
			{

				if (reg.mapg(op->rd2)!=reg.mapg(op->rs1)) {
					LSR(reg.mapg(op->rd2),reg.mapg(op->rs2),1,true); //C=rs2, rd2=0
					AND(reg.mapg(op->rd2),reg.mapg(op->rs1),1);      //get new carry
				} else {
					LSR(r0,reg.mapg(op->rs2),1,true); //C=rs2, rd2=0
					ADD(r0, reg.mapg(op->rs1),1);
				}
				RRX(reg.mapg(op->rd),reg.mapg(op->rs1));         //RRX w/ carry :)
				if (reg.mapg(op->rd2)==reg.mapg(op->rs1))
					MOV(reg.mapg(op->rd2), r0);
				
			}
			break;
			
		case shop_rocl:
			{
				//ADD(reg.mapg(op->rd),reg.mapg(op->rs2),reg.mapg(op->rs1),1,true); //(C,rd)= rs1<<1 + (|) rs2
				ORR(reg.mapg(op->rd),reg.mapg(op->rs2),reg.mapg(op->rs1),true, S_LSL, 1); //(C,rd)= rs1<<1 + (|) rs2
				MOVW(reg.mapg(op->rd2),0);                      //clear rd2 (for ADC/MOVCS)
				ADC(reg.mapg(op->rd2),reg.mapg(op->rd2),0);     //rd2=C (or MOVCS rd2, 1)
			}
			break;
			
		case shop_sbc:
			//printf("sbc: r%d r%d r%d r%d r%d\n",reg.mapg(op->rd),reg.mapg(op->rd2),reg.mapg(op->rs1),reg.mapg(op->rs2), reg.mapg(op->rs3));
			{
				EOR(reg.mapg(op->rd2),reg.mapg(op->rs3),1);
				LSR(reg.mapg(op->rd2),reg.mapg(op->rd2),1,true); //C=rs3, rd2=0
				SBC(reg.mapg(op->rd), reg.mapg(op->rs1), reg.mapg(op->rs2), true);
				MOV(reg.mapg(op->rd2), 1, CC_CC);
			}
			break;
		
		case shop_shld:
			//printf("shld: r%d r%d r%d\n",reg.mapg(op->rd),reg.mapg(op->rs1),reg.mapg(op->rs2));
			{
				verify(!op->rs2.is_imm());
				AND(r0, reg.mapg(op->rs2), 0x8000001F, true);
				RSB(r0, r0, 0x80000020, CC_MI);
				LSR(reg.mapg(op->rd), reg.mapg(op->rs1), r0, CC_MI);
				LSL(reg.mapg(op->rd), reg.mapg(op->rs1), r0, CC_PL);
				//MOV(reg.mapg(op->rd), reg.mapg(op->rs1), S_LSL, r0, CC_PL);
				//MOV(reg.mapg(op->rd), reg.mapg(op->rs1), S_LSR, r0, CC_MI);
			}		
			break;

		case shop_shad:
			//printf("shad: r%d r%d r%d\n",reg.mapg(op->rd),reg.mapg(op->rs1),reg.mapg(op->rs2));
			{
				verify(!op->rs2.is_imm());
				AND(r0, reg.mapg(op->rs2), 0x8000001F, true);
				RSB(r0, r0, 0x80000020, CC_MI);
				ASR(reg.mapg(op->rd), reg.mapg(op->rs1), r0, CC_MI);
				LSL(reg.mapg(op->rd), reg.mapg(op->rs1), r0, CC_PL);
				//MOV(reg.mapg(op->rd), reg.mapg(op->rs1), S_LSL, r0, CC_PL);
				//MOV(reg.mapg(op->rd), reg.mapg(op->rs1), S_ASR, r0, CC_MI);
			}		
			break;

		case shop_sync_sr:
		{
			//must flush: SRS, SRT, r0-r7, r0b-r7b
			CALL((unat)UpdateSR);
			break;
		}

		case shop_div32p2:
		{
			if (reg.mapg(op->rs1)!=reg.mapg(op->rd))
				MOV(reg.mapg(op->rd),reg.mapg(op->rs1));

			CMP(reg.mapg(op->rs3),0);
			SUB(reg.mapg(op->rd),reg.mapg(op->rd),reg.mapg(op->rs2),CC_EQ);
		}
		break;

		case shop_test:
		case shop_seteq:
		case shop_setge:
		case shop_setgt:
		case shop_setae:
		case shop_setab:
		{
			verify(op->rd._reg!=op->rs1._reg);
			verify(op->rs2.is_imm() || op->rd._reg!=op->rs2._reg);

			//rd is always NOT a source !
			MOVW(reg.mapg(op->rd),0);

			eReg rs2=r0;
			bool is_imm=false;

			if (op->rs2.is_imm())
			{
                if (!is_i8r4(op->rs2._imm))
					MOV32(rs2,(unat)op->rs2._imm);
				else
					is_imm=true;
			}
			else if (op->rs2.is_r32i())
			{
				rs2=reg.mapg(op->rs2);
			}
			else
			{
				printf("ngen_Bin ??? %d \n",op->rs2.type);
				verify(false);
			}

			if (op->op==shop_test)
			{
				if (is_imm)
					TST(reg.mapg(op->rs1),op->rs2._imm);
				else
					TST(reg.mapg(op->rs1),rs2);
			}
			else
			{
				if (is_imm)
					CMP(reg.mapg(op->rs1),op->rs2._imm);
				else
					CMP(reg.mapg(op->rs1),rs2);
			}


			eCC opcls2[]={CC_EQ,CC_EQ,CC_GE,CC_GT,CC_HS,CC_HI };

		    MOVW(reg.mapg(op->rd),1,opcls2[op->op-shop_test]);
		    break;
        }
		
		case shop_setpeq:
			{
				EOR(r1, reg.mapg(op->rs1), reg.mapg(op->rs2));
				MOVW(reg.mapg(op->rd), 0);
				
				TST(r1, 0xFF000000);
				TST(r1, 0x00FF0000, CC_NE);
				TST(r1, 0x0000FF00, CC_NE);
				TST(r1, 0x000000FF, CC_NE);
				MOVW(reg.mapg(op->rd), 1, CC_EQ);
			}
			break;
		
		//UXTH for zero extention and/or more mul forms (for 16 and 64 bits)

		case shop_mul_u16:
			{
				UXTH(r1, reg.mapg(op->rs1));
				UXTH(r2, reg.mapg(op->rs2));
				MUL(reg.mapg(op->rd),r1,r2);
			}
			break;
		case shop_mul_s16:
			{
				SXTH(r1, reg.mapg(op->rs1));
				SXTH(r2, reg.mapg(op->rs2));
				MUL(reg.mapg(op->rd),r1,r2);
			}
			break;
		case shop_mul_i32:
			{
				//x86_opcode_class opdt[]={op_movzx16to32,op_movsx16to32,op_mov32,op_mov32,op_mov32};
				//x86_opcode_class opmt[]={op_mul32,op_mul32,op_mul32,op_mul32,op_imul32};
				//only the top 32 bits are different on signed vs unsigned

				MUL(reg.mapg(op->rd),reg.mapg(op->rs1),reg.mapg(op->rs2));
			}
			break;
		case shop_mul_u64:
			{
				UMULL(reg.mapg(op->rd2), reg.mapg(op->rd), reg.mapg(op->rs1), reg.mapg(op->rs2));
			}
			break;
		case shop_mul_s64:
			{
				SMULL(reg.mapg(op->rd2), reg.mapg(op->rd), reg.mapg(op->rs1), reg.mapg(op->rs2));
			}
			break;

/*		case shop_div32u:
			// Doesn't work
			// algo from new arm dynarec from mupen64plus
			//printf("div32u: r%d r%d r%d r%d\n",reg.mapg(op->rd2),reg.mapg(op->rd),reg.mapg(op->rs1),reg.mapg(op->rs2));
			{
				// remainder = r0, quotient = r1, HOST_TEMPREG = r2, copy de rs1 = r3, copy de rs2 = r4
				MOV(r3, reg.mapg(op->rs1));
				MOV(r4, reg.mapg(op->rs2), true);
				MOV(r0, reg.mapg(op->rs1));	// dividend = d1 , divisor = d2
				MVN(r1, 0);
				B(10*4-8, CC_EQ);
				CLZ(r2, r4);
				MOV(r1, 1<<31);
				LSL(r4, r4, r2);
				LSR(r1, r1, r2);
				CMP(r0, r4);
				SUB(r0, r0, r4, CC_CS);
				ADC(r1, r1, r1, true);
				MOV(r4, r4, S_LSR, 1, CC_CC);
				B(-4*4-8, CC_CC);
				MOV(reg.mapg(op->rd), r1);
				MOV(reg.mapg(op->rd2), r0);
			}
			break;*/
/*		case shop_div32s:
			//printf("div32s r%d, r%d, r%d, r%d\n", reg.mapg(op->rd2),reg.mapg(op->rd),reg.mapg(op->rs1),reg.mapg(op->rs2));
			// algo from dynarec from pcsxrearmed
			// remainder = r0, quotient = r1, HOST_TEMPREG = r2, copy de rs1 = r3, copy de rs2 = r4
			{
				MOV(r3, reg.mapg(op->rs1));
				MOV(r4, reg.mapg(op->rs2));
				MOV(r0, reg.mapg(op->rs1), true);
				MVN(r1, 0);
				RSB(r1, r1, 0, CC_MI); // .. quotient and ..
				RSB(r0, r0, 0, CC_MI); // .. remainder for div0 case (will be negated back after jump)
				MOV(r2, reg.mapg(op->rs2), true);
				B(14*4-8, CC_EQ); // Division by zero
				RSB(r2, r2, 0, true, CC_MI);
				CLZ(r1, r2);
				LSL(r2, r2, r1);
				ORR(r1, r1, 1<<31);
				LSR(r1, r1, r1);
				CMP(r0, r2);
				SUB(r0, r0, r2, CC_CS);
				ADC(r1, r1, r1, true);
				MOV(r2, r2, S_LSR, 1);
				B(-4*4-8, CC_CC); // -4
				TEQ(r3, r4, S_LSL, CC_AL);
				RSB(r1, r1, 0, CC_MI);
				TST(r3, r3);
				RSB(r0, r0, 0, CC_MI);
				MOV(reg.mapg(op->rd2), r0);
				MOV(reg.mapg(op->rd), r1);
			}
			break;*/
	
		case shop_pref:
			{
				if (op->flags != 0x1337)
				{
					LSR(r1,reg.mapg(op->rs1),26);
					MOV(r0,reg.mapg(op->rs1));
					CMP(r1,0x38);
				}
				else
					MOV(r0,reg.mapg(op->rs1));

				if (CCN_MMUCR.AT)
				{
					CALL((unat)&do_sqw_mmu,op->flags==0x1337?CC_AL:CC_EQ);
				}
				else
				{	
					LDR(r2,r8,rcb_noffs(&do_sqw_nommu));
					SUB(r1,r8,-rcb_noffs(sq_both));
					BLX(r2,op->flags==0x1337?CC_AL:CC_EQ);
				}
			}
			break;

/*
		case shop_cvt_i2f_z:
		case shop_cvt_i2f_n:
			
			break;
*/

			//shop_cvt_f2i_t
			//shop_cvt_i2f_n
			//shop_cvt_i2f_z
		case shop_ext_s8:
		case shop_ext_s16:
			{
				verify(op->rd.is_r32i());
				verify(op->rs1.is_r32i());

				(op->op==shop_ext_s8?SXTB:SXTH)(reg.mapg(op->rd),reg.mapg(op->rs1),CC_AL);
			}
			break;
			

				//fpu
		case shop_fadd:
		case shop_fsub:
		case shop_fmul:
		case shop_fdiv:
		{
			const FPBinOP* opcds[]= { VADD_VFP,VSUB_VFP,VMUL_VFP,VDIV_VFP };
			ngen_fp_bin(op, opcds[op->op-shop_fadd]);
		}
		break;

		case shop_fabs:
		case shop_fneg:
		{
			const FPUnOP* opcds[]= { VABS_VFP,VNEG_VFP};
			ngen_fp_una(op, opcds[op->op-shop_fabs]);
		}
		break;

		case shop_fsqrt:
		{
			ngen_fp_una(op, VSQRT_F32);
		}
		break;

		
		case shop_fmac:
			{
				verify(reg.mapfs(op->rd)==reg.mapfs(op->rs1));
				VMLA_VFP(reg.mapfs(op->rs1),reg.mapfs(op->rs2),reg.mapfs(op->rs3));
			}
			break;

		case shop_fsrra:
			{
				VMOV(f1,fpu_imm_1);
				VSQRT_VFP(f0,reg.mapfs(op->rs1));

				VDIV_VFP(reg.mapfs(op->rd),f1,f0);
			}
			break;

		case shop_fsetgt:
		case shop_fseteq:
		{
			//

#if 1
			{
				//this is aparently much faster (tested on A9)
				MOVW(reg.mapg(op->rd),0);
				VCMP_F32(reg.mapfs(op->rs1),reg.mapfs(op->rs2));

				VMRS(R15);
				if (op->op==shop_fsetgt)
				{
					MOVW(reg.mapg(op->rd),1,CC_GT);
				}
				else
				{
					MOVW(reg.mapg(op->rd),1,CC_EQ);
				}
			}
#else
			{
				if (op->op==shop_fsetgt)
					VCGT_F32(d0,reg.mapf(op->rs1),reg.mapf(op->rs2));
				else
					VCEQ_F32(d0,reg.mapf(op->rs1),reg.mapf(op->rs2));

				VMOV(r0,f0);

				AND(reg.mapg(op->rd),r0,1);
			}
#endif
		}
		break;
			

		case shop_fsca:
			{
				reg.writeback_fpu+=2;

				//r1: base ptr
				MOVW(r1,((unat)sin_table)&0xFFFF);
				UXTH(r0,reg.mapg(op->rs1));
				MOVT(r1,((unat)sin_table)>>16);
				
				/*
					LDRD(r0,r1,r0,lsl,3);
					VMOV.64
					or
					ADD(r0,r1,r0,LSL,3);
					VLDR(d0,r0);
				*/

				//LSL(r0,r0,3);
				//ADD(r0,r1,r0); //EMITTER: Todo, add with shifted !
				ADD(r0,r1,r0, S_LSL, 3);
				
				VLDR(/*reg.mapf(op->rd,0)*/d0,r0,0);
				VSTR(d0,r8,op->rd.reg_nofs()/4);
			}
			break;

		case shop_fipr:
			{
				
				eFQReg _r1=q0;
				eFQReg _r2=q0;

				SUB(r0,r8,op->rs1.reg_aofs());
				if (op->rs2.reg_aofs()==op->rs1.reg_aofs())
				{
					reg.preload_fpu+=4;
					VLDM(d0,r0,2);
				}
				else
				{
					reg.preload_fpu+=8;
					SUB(r1,r8,op->rs2.reg_aofs());
					VLDM(d0,r0,2);
					VLDM(d2,r1,2);
					_r2=q1;
				}

#if 1
				//VFP
				eFSReg fs2=_r2==q0?f0:f4;

				VMUL_VFP(reg.mapfs(op->rd),f0,(eFSReg)(fs2+0));
				VMLA_VFP(reg.mapfs(op->rd),f1,(eFSReg)(fs2+1));
				VMLA_VFP(reg.mapfs(op->rd),f2,(eFSReg)(fs2+2));
				VMLA_VFP(reg.mapfs(op->rd),f3,(eFSReg)(fs2+3));
#else			
				VMUL_F32(q0,_r1,_r2);
				VPADD_F32(d0,d0,d1);
				VADD_VFP(reg.mapfs(op->rd),f0,f1);
#endif
			}
			break;

		case shop_ftrv:
			{
				reg.preload_fpu+=4;
				reg.writeback_fpu+=4;

				eReg rdp=r1;
				SUB(r2,r8,op->rs2.reg_aofs());
				SUB(r1,r8,op->rs1.reg_aofs());
				if (op->rs1.reg_aofs() != op->rd.reg_aofs())
				{
					rdp=r0;
					SUB(r0,r8,op->rd.reg_aofs());
				}
	
#if 1
				//f0,f1,f2,f3	  : vin
				//f4,f5,f6,f7     : out
				//f8,f9,f10,f11   : mtx temp
				//f12,f13,f14,f15 : mtx temp
				//(This is actually faster than using neon)

				VLDM(d4,r2,2,1);
				VLDM(d0,r1,2);

				VMUL_VFP(f4,f8,f0);
				VMUL_VFP(f5,f9,f0);
				VMUL_VFP(f6,f10,f0);
				VMUL_VFP(f7,f11,f0);
				
				VLDM(d6,r2,2,1);

				VMLA_VFP(f4,f12,f1);
				VMLA_VFP(f5,f13,f1);
				VMLA_VFP(f6,f14,f1);
				VMLA_VFP(f7,f15,f1);

				VLDM(d4,r2,2,1);

				VMLA_VFP(f4,f8,f2);
				VMLA_VFP(f5,f9,f2);
				VMLA_VFP(f6,f10,f2);
				VMLA_VFP(f7,f11,f2);

				VLDM(d6,r2,2);

				VMLA_VFP(f4,f12,f3);
				VMLA_VFP(f5,f13,f3);
				VMLA_VFP(f6,f14,f3);
				VMLA_VFP(f7,f15,f3);

				VSTM(d2,rdp,2);
#else
				//this fits really nicely to NEON !
				VLDM(d16,r2,8);
				VLDM(d0,r1,2);

				VMUL_F32(q2,q8,d0,0);
				VMLA_F32(q2,q9,d0,1);
				VMLA_F32(q2,q10,d1,0);
				VMLA_F32(q2,q11,d1,1);
				VSTM(d4,rdp,2);


				/*
					Alternative mtrx

					0 1 4 5
					2 3 6 7
					8 9 c d
					a b e f

					* ABCD

					v0= A*0 + B*4 + C*8 + D*c
					v1= A*1 + B*5 + C*9 + D*d
					v3= A*2 + B*6 + C*a + D*e
					v4= A*3 + B*7 + C*b + D*f
					D0      D1
					f0   f1     f2   f3
					0145 * AABB + 89cd*CCDD = A0+C8|A1+C9|B4+Dc|B5+Dd -> 
					
					v01=D0+D1 =  { A0+B4+C8+Dc, A1+B5+C9+Dd }

						AB, CD -> AABB CCDD


					//in-shuffle
					//4 mul
					//4 mla
					//1 add
				*/
#endif
			}
			break;


			case shop_frswap:
			{
				reg.preload_fpu+=16;
				reg.writeback_fpu+=16;

				verify(op->rd._reg==op->rs2._reg);
				verify(op->rd2._reg==op->rs1._reg);

				verify(op->rs1.count()==16 && op->rs2.count()==16);
				verify(op->rd2.count()==16 && op->rd.count()==16);

				SUB(r0,r8,op->rs1.reg_aofs());
				SUB(r1,r8,op->rd.reg_aofs());
				//Assumes no FPU reg alloc here
				//frswap touches all FPU regs, so all spans should be clear here ..
				VLDM(d0,r1,8);
				VLDM(d8,r0,8);
				VSTM(d0,r0,8);
				VSTM(d8,r1,8);
			}
			break;

			
			case shop_cvt_f2i_t:
				
				//printf("f2i: r%d f%d\n",reg.mapg(op->rd),reg.mapf(op->rs1));
				//BKPT();
				VCVT_to_S32_VFP(f0,reg.mapf(op->rs1));
				VMOV(reg.mapg(op->rd),f0);
				//shil_chf[op->op](op);
				break;
			
			case shop_cvt_i2f_n:	// may be some difference should be made ?
			case shop_cvt_i2f_z:
			
				//printf("i2f: f%d r%d\n",reg.mapf(op->rd),reg.mapg(op->rs1));
				//BKPT();
				VMOV(f0, reg.mapg(op->rs1));
				VCVT_from_S32_VFP(reg.mapfs(op->rd),f0);
				//shil_chf[op->op](op);
				break;
#endif

		default:
			//printf("CFB %d\n",op->op);
			shil_chf[op->op](op);
			break;

__default:
			printf("@@\tError, Default case (0x%X) in ngen_CompileBlock!\n", op->op);
			verify(false);
			break;
		}
}


//extern void ngen_Compile(RuntimeBlockInfo* block, bool force_checks, bool reset, bool staging, bool optimise);
//void ngen_Compile(RuntimeBlockInfo* block,bool force_checks, bool reset, bool staging,bool optimise)
//{
//    //printf("Compile: %08X, %d, %d\n",block->addr,staging,optimise);
//    block->code=(DynarecCodeEntryPtr)EMIT_GET_PTR();
//
//    //StoreImms(r0,r1,(unat)&last_run_block,(unat)code); //useful when code jumps to random locations ...
//    ++blockno;
//
//    if (settings.profile.run_counts)
//    {
//        MOV32(r1,(unat)&block->runs);
//        LDR(r0,r1);
//        ADD(r0,r0,1);
//        STR(r0,r1);
//    }
//
//    //reg alloc
//    reg.DoAlloc(block,alloc_regs,alloc_fpu);
//
//    u8* blk_start=(u8*)EMIT_GET_PTR();
//
//    if (staging)
//    {
//        MOV32(r0,(unat)&block->staging_runs);
//        LDR(r1,r0);
//        SUB(r1,r1,1);
//        STR(r1,r0);
//    }
//    //pre-load the first reg alloc operations, for better efficiency ..
//    reg.OpBegin(&block->oplist[0],0);
//
//    //scheduler
//    if (force_checks)
//    {
//        MOV32(r0,block->addr);
//        unat* ptr=(unat*)GetMemPtr(block->addr,4);
//        MOV32(r2,(unat)ptr);
//        LDR(r2,r2,0);
//        MOV32(r1,*ptr);
//        CMP(r1,r2);
//
//#ifdef __LP64__
//        JUMP((unat)rdv_BlockCheckFail, CC_NE);
//#else
//        JUMP((unat)ngen_blockcheckfail, CC_NE);
//#endif
//    }
//
//    unat cyc=block->guest_cycles;
//    if (!is_i8r4(cyc))
//    {
//        cyc&=~3;
//    }
//
//#if HOST_OS == OS_DARWIN
//    SUB(r11,r11,cyc,true,CC_AL);
//#else
//    SUB(rfp_r9,rfp_r9,cyc,true,CC_AL);
//#endif
//    CALL((unat)intc_sched, CC_LE);
//
//    //compile the block's opcodes
//    shil_opcode* op;
//    for (size_t i=0;i<block->oplist.size();i++)
//    {
//        op=&block->oplist[i];
//        
//        op->host_offs=(u8*)EMIT_GET_PTR()-blk_start;
//
//        if (i!=0)
//            reg.OpBegin(op,i);
//
//        ngen_compile_opcode(block,op,staging,optimise);
//
//        reg.OpEnd(op);
//    }
//
//    /*
//
//    extern unat ralst[4];
//
//    MOV32(r0,(unat)&ralst[0]);
//    
//    LDR(r1,r0,0);
//    ADD(r1,r1,reg.preload_gpr);
//    STR(r1,r0,0);
//
//    LDR(r1,r0,4);
//    ADD(r1,r1,reg.preload_fpu);
//    STR(r1,r0,4);
//
//    LDR(r1,r0,8);
//    ADD(r1,r1,reg.writeback_gpr);
//    STR(r1,r0,8);
//
//    LDR(r1,r0,12);
//    ADD(r1,r1,reg.writeback_fpu);
//    STR(r1,r0,12);
//    */
//
//    /*
//        //try to early-lookup the blocks -- to avoid rewrites in case they exist ...
//        //this isn't enabled for now, as I'm not quite solid on the state of block referrals ..
//
//        block->pBranchBlock=bm_GetBlock(block->BranchBlock);
//        block->pNextBlock=bm_GetBlock(block->NextBlock);
//        if (block->pNextBlock) block->pNextBlock->AddRef(block);
//        if (block->pBranchBlock) block->pBranchBlock->AddRef(block);
//    */
//
//    
//    //Relink written bytes must be added to the count !
//
//    block->relink_offset=(u8*)EMIT_GET_PTR()-(u8*)block->code;
//    block->relink_data=0;
//
//    emit_Skip(block->Relink());
//    u8* pEnd = (u8*)EMIT_GET_PTR();
//
//    // Clear the area we've written to for cache
//    CacheFlush((void*)block->code, pEnd);
//
//    //blk_start might not be the same, due to profiling counters ..
//    block->host_opcodes=(pEnd-blk_start)/4;
//
//    //host code size needs to cover the entire range of the block
//    block->host_code_size=(pEnd-(u8*)block->code);
//
//    void emit_WriteCodeCache();
////    emit_WriteCodeCache();
//}

void ngen_ResetBlocks()
{
	printf("@@\tngen_ResetBlocks()\n");
}
/*
	SHR ..
	CMP ..
	j plc
	ext
	add
	str
*/
void ngen_init()
{
    verify(FPCB_OFFSET == -0x2100000 || FPCB_OFFSET == -0x4100000);
    verify(rcb_noffs(p_sh4rcb->fpcb) == FPCB_OFFSET);
    
	for (int s=0;s<6;s++)
	{
		void* fn=s==0?(void*)_vmem_ReadMem8SX32:
				 s==1?(void*)_vmem_ReadMem16SX32:
				 s==2?(void*)_vmem_ReadMem32:
				 s==3?(void*)_vmem_WriteMem8:
				 s==4?(void*)_vmem_WriteMem16:
				 s==5?(void*)_vmem_WriteMem32:
				 0;

		bool read=s<=2;

		//r0 to r13
		for (int i=0;i<=13;i++)
		{
			if (i==1 || i ==2 || i == 3 || i == 4 || i==12 || i==13)
				continue;

			unat v;
			if (read)
			{
				if (i==0)
					v=(unat)fn;
				else
				{
					v=(unat)EMIT_GET_PTR();
					MOV(r0,(eReg)(i));
					JUMP((unat)fn);
				}
			}
			else
			{
				if (i==0)
					v=(unat)fn;
				else
				{
					v=(unat)EMIT_GET_PTR();
					MOV(r0,(eReg)(i));
					JUMP((unat)fn);
				}
			}

			_mem_hndl[read][s%3][i]=v;
		}
	}

	for (int i=0;i<=13;i++)
	{
		if (i==1 || i ==2 || i == 3 || i == 4 || i==12 || i==13)
			continue;

		_mem_hndl_SQ32[i]=(unat)EMIT_GET_PTR();

		//UBFX(r3,(eReg)i,0,6);
		AND(r3,(eReg)i,0x3F);
		LSR(r2,(eReg)i,26);
		MOV(r0,(eReg)i);
		ADD(r3,r3,r8);
		CMP(r2,0x38);
		JUMP((unat)&WriteMem32,CC_NE);
		STR(r1,r3,rcb_noffs(sq_both));
		BX(LR);
	}

	printf("readm helpers: up to %08X\n",EMIT_GET_PTR());
	emit_SetBaseAddr();


	ccmap[shop_test]=CC_EQ;
	ccnmap[shop_test]=CC_NE;

	ccmap[shop_seteq]=CC_EQ;
	ccnmap[shop_seteq]=CC_NE;
	
	
	ccmap[shop_setge]=CC_GE;
	ccnmap[shop_setge]=CC_LT;
	
	ccmap[shop_setgt]=CC_GT;
	ccnmap[shop_setgt]=CC_LE;

	ccmap[shop_setae]=CC_HS;
	ccnmap[shop_setae]=CC_LO;

	ccmap[shop_setab]=CC_HI;
	ccnmap[shop_setab]=CC_LS;

	//ccmap[shop_fseteq]=CC_EQ;
	//ccmap[shop_fsetgt]=CC_GT;

}


void ngen_GetFeatures(ngen_features* dst)
{
	dst->InterpreterFallback=false;
	dst->OnlyDynamicEnds=false;
}

RuntimeBlockInfo* ngen_AllocateBlock()
{
	return new DynaRBI();
};

#endif
