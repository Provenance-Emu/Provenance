#ifndef M64P_DEVICE_R4300_NEW_DYNAREC_X64_ASSEM_X64_H
#define M64P_DEVICE_R4300_NEW_DYNAREC_X64_ASSEM_X64_H

#define EAX 0
#define ECX 1
#define EDX 2
#define EBX 3
#define ESP 4
#define EBP 5
#define ESI 6
#define EDI 7

#define RAX 0
#define RCX 1
#define RDX 2
#define RBX 3
#define RSP 4
#define RBP 5
#define RSI 6
#define RDI 7
#define R8  8
#define R9  9
#define R10 10
#define R11 11
#define R12 12
#define R13 13
#define R14 14
#define R15 15

#define HOST_REGS 8
#define HOST_BTREG EBP
#define EXCLUDE_REG ESP
#define HOST_TEMPREG R15

//#define IMM_PREFETCH 1
#define NATIVE_64 1
#define RAM_OFFSET 1
#define NEED_INVC_PTR 1
#define INVERTED_CARRY 1
//#define DESTRUCTIVE_WRITEBACK 1
#define DESTRUCTIVE_SHIFT 1
#define USE_MINI_HT 1

#define TARGET_SIZE_2 25 // 2^25 = 32 megabytes
#define JUMP_TABLE_SIZE 0 // Not needed for x86

#ifdef _WIN32
/* Microsoft x64 calling convention:
   func(rcx, rdx, r8, r9) {return rax;}
   callee-save: %rbx %rbp %rdi %rsi %rsp %r12-%r15

The registers RAX, RCX, RDX, R8, R9, R10, R11 are considered volatile (caller-saved).
The registers RBX, RBP, RDI, RSI, RSP, R12, R13, R14, and R15 are considered nonvolatile (callee-saved).*/

#define ARG1_REG ECX
#define ARG2_REG EDX
#define ARG3_REG R8
#define ARG4_REG R9
#define CALLER_SAVED_REGS 0xF07
#define HOST_CCREG ESI
#else
/* amd64 calling convention:
   func(rdi, rsi, rdx, rcx, r8, r9) {return rax;}
   callee-save: %rbp %rbx %r12-%r15

The registers RAX, RCX, RDX, RSI, RDI, R8, R9, R10, R11 are considered volatile (caller-saved).
The registers RBX, RBP, RSP, R12, R13, R14, and R15 are considered nonvolatile (callee-saved).*/

#define ARG1_REG EDI
#define ARG2_REG ESI
#define ARG3_REG EDX
#define ARG4_REG ECX
#define CALLER_SAVED_REGS 0xFC7
#define HOST_CCREG EBX
#endif

#endif /* M64P_DEVICE_R4300_NEW_DYNAREC_X64_ASSEM_X64_H */
