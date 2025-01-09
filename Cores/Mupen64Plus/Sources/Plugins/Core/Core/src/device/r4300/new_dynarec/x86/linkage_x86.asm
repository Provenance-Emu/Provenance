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

%macro get_GOT 0
      call  %%getgot
  %%getgot:
      pop  ebx
      add  ebx,_GLOBAL_OFFSET_TABLE_+$$-%%getgot wrt ..gotpc
%endmacro

%ifdef PIC
    %define get_got_address get_GOT
    %define find_local_data(a) ebx + a wrt ..gotoff
    %define find_external_data(a) ebx + a wrt ..got
%else
    %define get_got_address
    %define find_local_data(a) a
    %define find_extern_data(a) a
%endif

%define g_dev_r4300_stop                                    (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_stop)
%define g_dev_r4300_regs                                    (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_regs)
%define g_dev_r4300_hi                                      (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_hi)
%define g_dev_r4300_lo                                      (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_lo)
%define g_dev_r4300_cp0_regs                                (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_cp0 + offsetof_struct_cp0_regs)
%define g_dev_r4300_cp0_next_interrupt                      (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_cp0 + offsetof_struct_cp0_next_interrupt)
%define g_dev_r4300_cached_interp_invalid_code              (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_cached_interp + offsetof_struct_cached_interp_invalid_code)
%define g_dev_r4300_new_dynarec_hot_state_cycle_count       (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_cycle_count)
%define g_dev_r4300_new_dynarec_hot_state_last_count        (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_last_count)
%define g_dev_r4300_new_dynarec_hot_state_pending_exception (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_pending_exception)
%define g_dev_r4300_new_dynarec_hot_state_pcaddr            (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_pcaddr)
%define g_dev_r4300_new_dynarec_hot_state_branch_target     (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_branch_target)
%define g_dev_r4300_new_dynarec_hot_state_restore_candidate (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_restore_candidate)
%define g_dev_r4300_new_dynarec_hot_state_memory_map        (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_new_dynarec_hot_state + offsetof_struct_new_dynarec_hot_state_memory_map)

cglobal jump_vaddr_eax
cglobal jump_vaddr_ecx
cglobal jump_vaddr_edx
cglobal jump_vaddr_ebx
cglobal jump_vaddr_ebp
cglobal jump_vaddr_edi
cglobal verify_code_ds
cglobal verify_code_vm
cglobal verify_code
cglobal cc_interrupt
cglobal do_interrupt
cglobal fp_exception
cglobal fp_exception_ds
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

cextern base_addr
cextern new_recompile_block
cextern get_addr_ht
cextern get_addr
cextern dynarec_gen_interrupt
cextern clean_blocks
cextern invalidate_block
cextern new_dynarec_check_interrupt
cextern get_addr_32
cextern g_dev

%ifdef PIC
cextern _GLOBAL_OFFSET_TABLE_
%endif

section .bss
align 4

section .rodata
section .text

jump_vaddr_eax:
    mov     edi,    eax
    jmp     jump_vaddr_edi

jump_vaddr_ecx:
    mov     edi,    ecx
    jmp     jump_vaddr_edi

jump_vaddr_edx:
    mov     edi,    edx
    jmp     jump_vaddr_edi

jump_vaddr_ebx:
    mov     edi,    ebx
    jmp     jump_vaddr_edi

jump_vaddr_ebp:
    mov     edi,    ebp

jump_vaddr_edi:
    mov     eax,    edi

jump_vaddr:
    get_got_address
    add     esp,    -12
    push    edi
    mov     [find_local_data(g_dev_r4300_new_dynarec_hot_state_cycle_count)],    esi    ;CCREG
    add     esi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_last_count)]
    mov     [find_local_data(g_dev_r4300_cp0_regs+36)],    esi    ;Count
    call    get_addr_ht
    mov     esi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_cycle_count)]
    add     esp,    16
    jmp     eax

verify_code_ds:
    ;eax = source (virtual address)
    ;edx = target
    ;ecx = length
    get_got_address
    mov     [find_local_data(g_dev_r4300_new_dynarec_hot_state_branch_target)],    ebp

verify_code_vm:
    ;eax = source (virtual address)
    ;edx = target
    ;ecx = length
    get_got_address
    cmp     eax,    0C0000000h
    jl      verify_code
    mov     [find_local_data(g_dev_r4300_new_dynarec_hot_state_cycle_count)],    esi
    mov     esi,    eax
    lea     ebp,    [-1+eax+ecx*1]
    shr     esi,    12
    shr     ebp,    12
    mov     edi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_memory_map+esi*4)]
    test    edi,    edi
    js      _D4
    lea     eax,    [eax+edi*4]
_D1:
    xor     edi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_memory_map+esi*4)]
    shl     edi,    2
    jne     _D4
    mov     edi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_memory_map+esi*4)]
    inc     esi
    cmp     esi,    ebp
    jbe     _D1
    mov     esi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_cycle_count)]

verify_code:
    ;eax = source
    ;edx = target
    ;ecx = length
    get_got_address
    mov     edi,    [-4+eax+ecx*1]
    xor     edi,    [-4+edx+ecx*1]
    jne     _D5
    mov     edi,    ecx
    add     ecx,    -4
    je      _D3
    test    edi,    4
    cmove   ecx,    edi
_D2:
    mov     edi,    [-4+eax+ecx*1]
    xor     edi,    [-4+edx+ecx*1]
    jne     _D5
    mov     edi,    [-8+eax+ecx*1]
    xor     edi,    [-8+edx+ecx*1]
    jne     _D5
    add     ecx,    -8
    jne     _D2
_D3:
    mov     ebp,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_branch_target)]
    ret
_D4:
    mov     esi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_cycle_count)]
_D5:
    mov     ebp,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_branch_target)]
    push    esi           ;for stack alignment, unused
    push    DWORD [8+esp]
    call    get_addr
    add     esp,    16    ;pop stack
    jmp     eax

cc_interrupt:
    get_got_address
    add     esi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_last_count)]
    add     esp,    -28                 ;Align stack
    mov     [find_local_data(g_dev_r4300_cp0_regs+36)],    esi    ;Count
    shr     esi,    19
    mov     DWORD [find_local_data(g_dev_r4300_new_dynarec_hot_state_pending_exception)],    0
    and     esi,    01fch
    cmp     DWORD [find_local_data(g_dev_r4300_new_dynarec_hot_state_restore_candidate+esi)],    0
    jne     _E4
_E1:
    call    dynarec_gen_interrupt
    mov     esi,    [find_local_data(g_dev_r4300_cp0_regs+36)]
    mov     eax,    [find_local_data(g_dev_r4300_cp0_next_interrupt)]
    mov     edx,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_pending_exception)]
    mov     ecx,    [find_local_data(g_dev_r4300_stop)]
    add     esp,    28
    mov     [find_local_data(g_dev_r4300_new_dynarec_hot_state_last_count)],    eax
    sub     esi,    eax
    test    ecx,    ecx
    jne     _E3
    test    edx,    edx
    jne     _E2
    ret
_E2:
    add     esp,    -8
    mov     edi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_pcaddr)]
    mov     [find_local_data(g_dev_r4300_new_dynarec_hot_state_cycle_count)],    esi    ;CCREG
    push    edi
    call    get_addr_ht
    mov     esi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_cycle_count)]
    add     esp,    16
    jmp     eax
_E3:
    add     esp,    16     ;pop stack
    pop     edi            ;restore edi
    pop     esi            ;restore esi
    pop     ebx            ;restore ebx
    pop     ebp            ;restore ebp
    ret                    ;exit dynarec
_E4:
    ;Move 'dirty' blocks to the 'clean' list
    mov     edi,    DWORD [find_local_data(g_dev_r4300_new_dynarec_hot_state_restore_candidate+esi)]
    mov     DWORD [find_local_data(g_dev_r4300_new_dynarec_hot_state_restore_candidate+esi)],    0
    shl     esi,    3
    mov     ebp,    0
_E5:
    shr     edi,    1
    jnc     _E6
    mov     ecx,    esi
    add     ecx,    ebp
    push    ecx
    call    clean_blocks
    pop     ecx
_E6:
    inc     ebp
    test    ebp,    31
    jne     _E5
    jmp     _E1

do_interrupt:
    get_got_address
    mov     edi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_pcaddr)]
    add     esp,    -12
    push    edi
    call    get_addr_ht
    add     esp,    16
    mov     esi,    [find_local_data(g_dev_r4300_cp0_regs+36)]
    mov     edx,    [find_local_data(g_dev_r4300_cp0_next_interrupt)]
    mov     [find_local_data(g_dev_r4300_new_dynarec_hot_state_last_count)],    edx
    sub     esi,    edx
    jmp     eax

fp_exception:
    mov     edx,    01000002ch
_E7:
    get_got_address
    mov     ecx,    [find_local_data(g_dev_r4300_cp0_regs+48)]
    add     esp,    -12
    or      ecx,    2
    mov     [find_local_data(g_dev_r4300_cp0_regs+48)],    ecx     ;Status
    mov     [find_local_data(g_dev_r4300_cp0_regs+52)],    edx     ;Cause
    mov     [find_local_data(g_dev_r4300_cp0_regs+56)],    eax     ;EPC
    push    080000180h
    call    get_addr_ht
    add     esp,    16
    jmp     eax

fp_exception_ds:
    mov     edx,    09000002ch    ;Set high bit if delay slot
    jmp     _E7

jump_syscall:
    get_got_address
    mov     edx,    020h
    mov     ecx,    [find_local_data(g_dev_r4300_cp0_regs+48)]
    add     esp,    -12
    or      ecx,    2
    mov     [find_local_data(g_dev_r4300_cp0_regs+48)],    ecx     ;Status
    mov     [find_local_data(g_dev_r4300_cp0_regs+52)],    edx     ;Cause
    mov     [find_local_data(g_dev_r4300_cp0_regs+56)],    eax     ;EPC
    push    080000180h
    call    get_addr_ht
    add     esp,    16
    jmp     eax

jump_eret:
    get_got_address
    mov     ecx,    [find_local_data(g_dev_r4300_cp0_regs+48)]        ;Status
    add     esi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_last_count)]
    and     ecx,    0FFFFFFFDh
    mov     [find_local_data(g_dev_r4300_cp0_regs+36)],    esi        ;Count
    mov     [find_local_data(g_dev_r4300_cp0_regs+48)],    ecx        ;Status
    call    new_dynarec_check_interrupt
    mov     eax,    [find_local_data(g_dev_r4300_cp0_next_interrupt)]
    mov     esi,    [find_local_data(g_dev_r4300_cp0_regs+36)]
    mov     [find_local_data(g_dev_r4300_new_dynarec_hot_state_last_count)],    eax
    sub     esi,    eax
    mov     [find_local_data(g_dev_r4300_new_dynarec_hot_state_cycle_count)],    esi
    mov     eax,    [find_local_data(g_dev_r4300_cp0_regs+56)]        ;EPC
    jns     _E11
_E8:
    mov     esi,    248
    xor     edi,    edi
_E9:
    mov     ecx,    [find_local_data(g_dev_r4300_regs + esi)]
    mov     edx,    [find_local_data(g_dev_r4300_regs + esi + 4)]
    sar     ecx,    31
    xor     edx,    ecx
    neg     edx
    adc     edi,    edi
    sub     esi,    8
    jne     _E9
    mov     ecx,    [find_local_data(g_dev_r4300_hi + esi)]
    mov     edx,    [find_local_data(g_dev_r4300_hi + esi + 4)]
    sar     ecx,    31
    xor     edx,    ecx
    jne     _E10
    mov     ecx,    [find_local_data(g_dev_r4300_lo + esi)]
    mov     edx,    [find_local_data(g_dev_r4300_lo + esi + 4)]
    sar     ecx,    31
    xor     edx,    ecx
_E10:
    neg     edx
    adc     edi,    edi
    add     esp,    -8
    push    edi
    push    eax
    call    get_addr_32
    mov     esi,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_cycle_count)]
    add     esp,    16
    jmp     eax
_E11:
    mov     [find_local_data(g_dev_r4300_new_dynarec_hot_state_pcaddr)],    eax
    call    cc_interrupt
    mov     eax,    [find_local_data(g_dev_r4300_new_dynarec_hot_state_pcaddr)]
    jmp     _E8

new_dyna_start:
    push    ebp
    push    ebx
    push    esi
    push    edi
    add     esp,    -8    ;align stack
    push    0a4000040h
    call    new_recompile_block
    get_got_address
    mov     edi,    DWORD [find_local_data(g_dev_r4300_cp0_next_interrupt)]
    mov     esi,    DWORD [find_local_data(g_dev_r4300_cp0_regs+36)]
    mov     DWORD [find_local_data(g_dev_r4300_new_dynarec_hot_state_last_count)],    edi
    sub     esi,    edi
    jmp     DWORD [find_local_data(base_addr)]

invalidate_block_eax:
    push    eax
    push    ecx
    push    edx
    push    eax
    jmp     invalidate_block_call

invalidate_block_ecx:
    push    eax
    push    ecx
    push    edx
    push    ecx
    jmp     invalidate_block_call

invalidate_block_edx:
    push    eax
    push    ecx
    push    edx
    push    edx
    jmp     invalidate_block_call

invalidate_block_ebx:
    push    eax
    push    ecx
    push    edx
    push    ebx
    jmp     invalidate_block_call

invalidate_block_ebp:
    push    eax
    push    ecx
    push    edx
    push    ebp
    jmp     invalidate_block_call

invalidate_block_esi:
    push    eax
    push    ecx
    push    edx
    push    esi
    jmp     invalidate_block_call

invalidate_block_edi:
    push    eax
    push    ecx
    push    edx
    push    edi

invalidate_block_call:
    call    invalidate_block
    pop     eax ;Throw away
    pop     edx
    pop     ecx
    pop     eax
    ret

breakpoint:
    int    3
    ret
