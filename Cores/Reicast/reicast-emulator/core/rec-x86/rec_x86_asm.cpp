#include "types.h"

#if FEAT_SHREC == DYNAREC_JIT && HOST_CPU == CPU_X86

#include "rec_x86_ngen.h"

#if HOST_OS == OS_WINDOWS

naked void ngen_LinkBlock_Shared_stub()
{
	__asm
	{
		pop ecx;
		sub ecx,5;
		call rdv_LinkBlock;
		jmp eax;
	}
}

naked void ngen_LinkBlock_cond_Next_stub()
{
	__asm
	{
		mov edx,0
		jmp ngen_LinkBlock_Shared_stub;
	}
}
naked void ngen_LinkBlock_cond_Branch_stub()
{
	__asm
	{
		mov edx,1
		jmp ngen_LinkBlock_Shared_stub;
	}
}

const u32 offs=offsetof(Sh4RCB,cntx.jdyn);
naked void ngen_LinkBlock_Generic_stub()
{
	__asm
	{
		mov edx,[p_sh4rcb];
		add edx,[offs];
		mov edx,[edx];
		jmp ngen_LinkBlock_Shared_stub;
	}
}




naked void ngen_FailedToFindBlock_()
{
	__asm
	{
		mov ecx,esi;
		call rdv_FailedToFindBlock;
		jmp eax;
	}
}

const u32 cpurun_offset=offsetof(Sh4RCB,cntx.CpuRunning);

void (*ngen_FailedToFindBlock)()=&ngen_FailedToFindBlock_;
naked void ngen_mainloop(void* cntx)
{
	__asm
	{
		push esi;
		push edi;
		push ebp;
		push ebx;

		mov ecx,[eax-184]; //# PC - was #0xA0000000
		mov [cycle_counter],SH4_TIMESLICE;

		mov [loop_no_update],offset no_update;
		mov [intc_sched],offset intc_sched_offs;
		
		mov eax,0;
		//next_pc _MUST_ be on ecx
no_update:
		mov esi,ecx;
		call bm_GetCode
		jmp eax;

intc_sched_offs:
		add [cycle_counter],SH4_TIMESLICE;
		call UpdateSystem;
		cmp eax,0;
		jnz do_iter;
		ret;

do_iter:
		pop ecx;
		call rdv_DoInterrupts;
		mov ecx,eax;
		mov edx,[p_sh4rcb];
		add edx,[cpurun_offset];
		cmp dword ptr [edx],0;
		jz cleanup;
		jmp no_update;

cleanup:
		pop ebx;
		pop ebp;
		pop edi;
		pop esi;

		ret;
	}
}


naked void DYNACALL ngen_blockcheckfail(u32 addr)
{
	__asm
	{
		call rdv_BlockCheckFail;
		jmp eax;
	}
}

naked void DYNACALL ngen_blockcheckfail2(u32 addr)
{
	__asm
	{
		int 3;
		call rdv_BlockCheckFail;
		jmp eax;
	}
}
#else
	u32 gas_offs=offsetof(Sh4RCB,cntx.jdyn);
	u32 cpurun_offset=offsetof(Sh4RCB,cntx.CpuRunning);
	void (*ngen_FailedToFindBlock)()=&ngen_FailedToFindBlock_;
#endif
#endif
