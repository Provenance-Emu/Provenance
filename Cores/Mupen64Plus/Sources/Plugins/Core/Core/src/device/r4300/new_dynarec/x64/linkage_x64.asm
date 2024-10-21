;Mupen64plus - linkage_x86.asm
;Copyright (C) 2009-2011 Ari64
;
;This program is free software; you can redistribute it and/or modify
;it under the terms of the GNU General Public License as published by
;the Free Software Foundation; either version 2 of the License, or
;(at your option) any later version.
;
;This program is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;GNU General Public License for more details.
;
;You should have received a copy of the GNU General Public License
;along with this program; if not, write to the
;Free Software Foundation, Inc.,
;51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

%include "asm_defines_nasm.h"

%ifidn __OUTPUT_FORMAT__,elf
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
%ifidn __OUTPUT_FORMAT__,elf32
section .note.GNU-stack noalloc noexec nowrite progbits
%endif
%ifidn __OUTPUT_FORMAT__,elf64
section .note.GNU-stack noalloc noexec nowrite progbits
%endif

%ifdef LEADING_UNDERSCORE
    %macro  cglobal 1
      global  _%1
      %define %1 _%1
    %endmacro

    %macro  cextern 1
      extern  _%1
      %define %1 _%1
    %endmacro
%else
    %macro  cglobal 1
      global  %1
    %endmacro

    %macro  cextern 1
      extern  %1
    %endmacro
%endif

%ifdef WIN64
%define ARG1_REG ecx
%define ARG2_REG edx
%define ARG3_REG r8d
%define ARG4_REG r9d
%define ARG1_REG64 rcx
%define ARG2_REG64 rdx
%define ARG3_REG64 r8
%define ARG4_REG64 r9
%define CCREG esi
%else
%define ARG1_REG edi
%define ARG2_REG esi
%define ARG3_REG edx
%define ARG4_REG ecx
%define ARG1_REG64 rdi
%define ARG2_REG64 rsi
%define ARG3_REG64 rdx
%define ARG4_REG64 rcx
%define CCREG ebx
%endif

%define g_dev_r4300_new_dynarec_hot_state_stop              (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_stop)
%define g_dev_r4300_new_dynarec_hot_state_cycle_count       (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_cycle_count)
%define g_dev_r4300_new_dynarec_hot_state_pending_exception (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_pending_exception)
%define g_dev_r4300_new_dynarec_hot_state_pcaddr            (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_pcaddr)

cglobal jump_vaddr_eax
cglobal jump_vaddr_ecx
cglobal jump_vaddr_edx
cglobal jump_vaddr_ebx
cglobal jump_vaddr_ebp
cglobal jump_vaddr_esi
cglobal jump_vaddr_edi
cglobal verify_code
cglobal cc_interrupt
cglobal do_interrupt
cglobal fp_exception
cglobal jump_syscall
cglobal jump_eret
cglobal new_dyna_start
cglobal invalidate_block_eax
cglobal invalidate_block_ecx
cglobal invalidate_block_edx
cglobal invalidate_block_ebx
cglobal invalidate_block_ebp
cglobal invalidate_block_esi
cglobal invalidate_block_edi
cglobal breakpoint
cglobal dyna_linker
cglobal dyna_linker_ds

cextern base_addr
cextern new_recompile_block
cextern get_addr_ht
cextern get_addr
cextern dynarec_gen_interrupt
cextern clean_blocks
cextern invalidate_block
cextern ERET_new
cextern get_addr_32
cextern g_dev
cextern verify_dirty
cextern cop1_unusable
cextern SYSCALL_new
cextern dynamic_linker
cextern dynamic_linker_ds

section .bss
align 4

section .rodata
section .text

jump_vaddr_eax:
    mov     ARG1_REG,    eax
    jmp     jump_vaddr

jump_vaddr_edx:
    mov     ARG1_REG,    edx
    jmp     jump_vaddr

jump_vaddr_ebx:
%ifdef WIN64
    mov     ARG1_REG,    ebx
    jmp     jump_vaddr
%else
    int     3
%endif

jump_vaddr_edi:
    mov     ARG1_REG,    edi
    jmp     jump_vaddr

jump_vaddr_ebp:
    mov     ARG1_REG,    ebp
    jmp     jump_vaddr

jump_vaddr_esi:
%ifdef WIN64
    int     3
%else
    mov     ARG1_REG,    esi
    jmp     jump_vaddr
%endif

jump_vaddr_ecx:
    mov     ARG1_REG,    ecx

jump_vaddr:
    call    get_addr_ht
    jmp     rax

verify_code:
    ;ARG1_REG64 = head
    add     rsp,    -8
    call    verify_dirty
    test    eax,eax
    jne     _D1
    add     rsp,    8
    ret
_D1:
    mov     ARG1_REG,    eax
    call    get_addr
    add     rsp,    16
    jmp     rax

cc_interrupt:
    mov     DWORD[rel g_dev_r4300_new_dynarec_hot_state_cycle_count],    CCREG
    add     rsp,    -56 ;Align stack
    mov     DWORD [rel g_dev_r4300_new_dynarec_hot_state_pending_exception],    0
    call    dynarec_gen_interrupt
    mov     CCREG,    DWORD[rel g_dev_r4300_new_dynarec_hot_state_cycle_count]
    mov     ecx,    DWORD[rel g_dev_r4300_new_dynarec_hot_state_pending_exception]
    mov     edx,    DWORD[rel g_dev_r4300_new_dynarec_hot_state_stop]
    add     rsp,    56
    test    edx,    edx
    jne     _E2
    test    ecx,    ecx
    jne     _E1
    ret
_E1:
    add     rsp,    -8
    mov     ARG1_REG,    DWORD[rel g_dev_r4300_new_dynarec_hot_state_pcaddr]
    call    get_addr_ht
    add     rsp,    16
    jmp     rax
_E2:
    add     rsp,    8    ;pop return address

new_dyna_stop:
    add     rsp,    56
    ;restore callee-save registers
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
%ifdef WIN64
    pop     rsi
    pop     rdi
%endif
    ret             ;exit dynarec

do_interrupt:
    mov     edx,    DWORD[rel g_dev_r4300_new_dynarec_hot_state_stop]
    test    edx,    edx
    jne     new_dyna_stop
    mov     ARG1_REG,    [rel g_dev_r4300_new_dynarec_hot_state_pcaddr]
    call    get_addr_ht
    mov     CCREG,    [rel g_dev_r4300_new_dynarec_hot_state_cycle_count]
    jmp     rax

fp_exception:
    mov     DWORD[rel g_dev_r4300_new_dynarec_hot_state_pcaddr],    eax
    call    cop1_unusable
    jmp     rax

jump_syscall:
    mov     DWORD[rel g_dev_r4300_new_dynarec_hot_state_pcaddr],    eax
    call    SYSCALL_new
    jmp     rax

jump_eret:
    mov     DWORD[rel g_dev_r4300_new_dynarec_hot_state_cycle_count],    CCREG
    call    ERET_new
    mov     CCREG,    DWORD[rel g_dev_r4300_new_dynarec_hot_state_cycle_count]
    test    rax,    rax
    je      new_dyna_stop
    jmp     rax

dyna_linker:
    call    dynamic_linker
    jmp     rax

dyna_linker_ds:
    call    dynamic_linker_ds
    jmp     rax

new_dyna_start:
    ;we must push an even # of registers to keep stack 16-byte aligned
%ifdef WIN64
    push rdi
    push rsi
%endif
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    add     rsp,    -56
    mov     ARG1_REG,    0a4000040h
    call    new_recompile_block
    mov     CCREG,    DWORD [rel g_dev_r4300_new_dynarec_hot_state_cycle_count]
    mov     rax,    QWORD[rel base_addr]
    jmp     rax

invalidate_block_eax:
    mov     ARG1_REG,    eax
    jmp     invalidate_block_call

invalidate_block_edi:
    mov     ARG1_REG,    edi
    jmp     invalidate_block_call

invalidate_block_edx:
    mov     ARG1_REG,    edx
    jmp     invalidate_block_call

invalidate_block_ebx:
    mov     ARG1_REG,    ebx
    jmp     invalidate_block_call

invalidate_block_ebp:
    mov     ARG1_REG,    ebp
    jmp     invalidate_block_call

invalidate_block_esi:
    mov     ARG1_REG,    esi
    jmp     invalidate_block_call

invalidate_block_ecx:
    mov     ARG1_REG,    ecx

invalidate_block_call:
    add     rsp,    -56
    call    invalidate_block
    add     rsp,    56
    ret

breakpoint:
    int    3
    ret
