.section .text
.intel_syntax noprefix


.extern rdv_LinkBlock
.globl p_sh4rcb
.globl gas_offs
.globl rdv_FailedToFindBlock
.globl cycle_counter
.globl loop_no_update
.globl intc_sched
.globl bm_GetCode
.globl cycle_counter
.globl UpdateSystem
.globl rdv_DoInterrupts
.globl rdv_BlockCheckFail

###########################################

.globl ngen_LinkBlock_Shared_stub
.type ngen_LinkBlock_Shared_stub, @function

ngen_LinkBlock_Shared_stub:
	pop ecx
	sub ecx,5
	call rdv_LinkBlock
	jmp eax



###########################################

.globl ngen_LinkBlock_cond_Next_stub
.type ngen_LinkBlock_cond_Next_stub, @function

ngen_LinkBlock_cond_Next_stub:
	mov edx,0
	jmp ngen_LinkBlock_Shared_stub
	


###########################################

.globl ngen_LinkBlock_cond_Branch_stub
.type ngen_LinkBlock_cond_Branch_stub, @function

ngen_LinkBlock_cond_Branch_stub:
	mov edx,1
	jmp ngen_LinkBlock_Shared_stub


###########################################

.globl ngen_LinkBlock_Generic_stub
.type ngen_LinkBlock_Generic_stub, @function

# u32 gas_offs=offsetof(Sh4RCB,cntx.jdyn);
ngen_LinkBlock_Generic_stub:
	mov edx,p_sh4rcb
	add edx,gas_offs
	mov edx,[edx]
	jmp ngen_LinkBlock_Shared_stub




###########################################

.globl ngen_FailedToFindBlock_
.type ngen_FailedToFindBlock_, @function

ngen_FailedToFindBlock_:
	mov ecx,esi
	call rdv_FailedToFindBlock
	jmp eax



###########################################
#define SH4_TIMESLICE 448

.globl ngen_mainloop
.type ngen_mainloop, @function

ngen_mainloop:
	# quick hack to maintain 16-byte alignment
	push esi
	push esi
	push esi

	push esi
	push edi
	push ebp
	push ebx

	mov ecx,[eax-184] # PC - was 0xA0000000
	mov dword ptr cycle_counter, 448 #SH4_TIMESLICE

    lea eax, no_update
	mov dword ptr loop_no_update, eax
	lea eax, intc_sched_offs
	mov dword ptr intc_sched, eax
	
	mov eax,0
		
#	next_pc _MUST_ be on ecx
no_update:
	mov esi,ecx
	call _Z10bm_GetCodej #bm_GetCode
	jmp eax

intc_sched_offs:
	add dword ptr cycle_counter, 448 #SH4_TIMESLICE
	call UpdateSystem
	cmp eax,0
	jnz do_iter
	ret

do_iter:
	pop ecx
	call rdv_DoInterrupts
	mov ecx,eax
	mov edx,[p_sh4rcb];
	add edx,[cpurun_offset];
	cmp dword ptr [edx],0;
	jz cleanup;
	jmp no_update

cleanup:
	pop ebx
	pop ebp
	pop edi
	pop esi
	
	# quick hack to maintain 16-byte alignment
	pop esi
	pop esi
	pop esi

	ret



###########################################

.globl ngen_blockcheckfail
.type ngen_blockcheckfail, @function

ngen_blockcheckfail:
	call rdv_BlockCheckFail
	jmp eax


###########################################

.globl ngen_blockcheckfail2
.type ngen_blockcheckfail2, @function

ngen_blockcheckfail2:
	int 3
	call rdv_BlockCheckFail
	jmp eax
