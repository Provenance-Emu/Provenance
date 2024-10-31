;Mupen64plus - dyna_start.asm
;Mupen64Plus homepage: https://mupen64plus.org/
;Copyright (C) 2007 Richard Goedeken (Richard42)
;Copyright (C) 2002 Hacktarux
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

%define g_dev_r4300_recomp_save_rsp       (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_recomp + offsetof_struct_recomp_save_rsp)
%define g_dev_r4300_recomp_save_rip       (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_recomp + offsetof_struct_recomp_save_rip)
%define g_dev_r4300_recomp_return_address (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_recomp + offsetof_struct_recomp_return_address)
%define g_dev_r4300_regs                  (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_regs)

cglobal dyna_start

cextern g_dev

section .bss
align 4

section .rodata
section .text

dyna_start:
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
    mov  [rel g_dev_r4300_recomp_save_rsp], rsp
    lea  r15, [rel g_dev_r4300_regs] ;store the base location of the r4300 registers in r15 for addressing
    call _A1
    jmp  _A2
_A1:
    pop  rax
    mov  [rel g_dev_r4300_recomp_save_rip], rax
    sub  rsp, 0x20
    and  rsp, 0xFFFFFFFFFFFFFFF0 ;ensure that stack is 16-byte aligned
    mov  rax, rsp
    sub  rax, 8
    mov  [rel g_dev_r4300_recomp_return_address], rax
%ifdef WIN64
    call rcx
%else
    call rdi
%endif
_A2:
    mov  rsp, [rel g_dev_r4300_recomp_save_rsp]
    pop  rbp
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
%ifdef WIN64
    pop rsi
    pop rdi
%endif

    mov  QWORD [rel g_dev_r4300_recomp_save_rsp], 0
    mov  QWORD [rel g_dev_r4300_recomp_save_rip], 0
    ret
