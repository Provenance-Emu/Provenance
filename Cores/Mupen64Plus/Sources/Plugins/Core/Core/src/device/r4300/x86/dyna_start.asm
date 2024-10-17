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
    %macro cglobal 1
      global  _%1
      %define %1 _%1
    %endmacro

    %macro cextern 1
      extern  _%1
      %define %1 _%1
    %endmacro
%else
    %macro cglobal 1
      global  %1
    %endmacro
    
    %macro cextern 1
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
    %define store_ebx
    %define load_ebx
    %define find_local_data(a) ebx + a wrt ..gotoff
    %define find_external_data(a) ebx + a wrt ..got
%else
    %define get_got_address
    %define store_ebx mov  [g_dev_r4300_recomp_save_ebx], ebx
    %define load_ebx  mov  ebx, [g_dev_r4300_recomp_save_ebx]
    %define find_local_data(a) a
    %define find_extern_data(a) a
%endif

%define g_dev_r4300_recomp_save_ebp        (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_recomp + offsetof_struct_recomp_save_ebp)
%define g_dev_r4300_recomp_save_esp        (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_recomp + offsetof_struct_recomp_save_esp)
%define g_dev_r4300_recomp_save_ebx        (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_recomp + offsetof_struct_recomp_save_ebx)
%define g_dev_r4300_recomp_save_esi        (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_recomp + offsetof_struct_recomp_save_esi)
%define g_dev_r4300_recomp_save_edi        (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_recomp + offsetof_struct_recomp_save_edi)
%define g_dev_r4300_recomp_save_eip        (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_recomp + offsetof_struct_recomp_save_eip)
%define g_dev_r4300_recomp_return_address  (g_dev + offsetof_struct_device_r4300 + offsetof_struct_r4300_core_recomp + offsetof_struct_recomp_return_address)

cglobal dyna_start

cextern g_dev

%ifdef PIC
cextern _GLOBAL_OFFSET_TABLE_
%endif

section .bss
align 4

section .rodata
section .text

dyna_start:
    get_got_address
    store_ebx
    mov  [find_local_data(g_dev_r4300_recomp_save_ebp)], ebp
    mov  [find_local_data(g_dev_r4300_recomp_save_esp)], esp
    mov  [find_local_data(g_dev_r4300_recomp_save_esi)], esi
    mov  [find_local_data(g_dev_r4300_recomp_save_edi)], edi
    call point1
    jmp  point2
point1:
    pop  eax
    mov  [find_local_data(g_dev_r4300_recomp_save_eip)], eax
    mov  eax, [esp+4]
    sub  esp, 0x10
    and  esp, 0xfffffff0
    mov  [find_local_data(g_dev_r4300_recomp_return_address)], esp
    sub  DWORD [find_local_data(g_dev_r4300_recomp_return_address)], 4
    call eax
point2:
    get_got_address
    load_ebx
    mov  ebp, [find_local_data(g_dev_r4300_recomp_save_ebp)]
    mov  esp, [find_local_data(g_dev_r4300_recomp_save_esp)]
    mov  esi, [find_local_data(g_dev_r4300_recomp_save_esi)]
    mov  edi, [find_local_data(g_dev_r4300_recomp_save_edi)]

    mov  DWORD [find_local_data(g_dev_r4300_recomp_save_ebx)], 0
    mov  DWORD [find_local_data(g_dev_r4300_recomp_save_ebp)], 0
    mov  DWORD [find_local_data(g_dev_r4300_recomp_save_esp)], 0
    mov  DWORD [find_local_data(g_dev_r4300_recomp_save_esi)], 0
    mov  DWORD [find_local_data(g_dev_r4300_recomp_save_edi)], 0
    mov  DWORD [find_local_data(g_dev_r4300_recomp_save_eip)], 0
    ret
