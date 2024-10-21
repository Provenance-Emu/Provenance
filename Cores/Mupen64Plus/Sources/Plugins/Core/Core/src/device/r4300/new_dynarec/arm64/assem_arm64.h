#ifndef M64P_DEVICE_R4300_NEW_DYNAREC_ARM_ASSEM_ARM64_H
#define M64P_DEVICE_R4300_NEW_DYNAREC_ARM_ASSEM_ARM64_H

#define HOST_REGS 29
#define HOST_CCREG 20 /* callee-save */
#define HOST_BTREG 19 /* callee-save */
#define EXCLUDE_REG 29 /* FP */

#define NATIVE_64 1
#define HOST_IMM8 1
//#define HAVE_CMOV_IMM 1
//#define CORTEX_A8_BRANCH_PREDICTION_HACK 1
//#define REG_PREFETCH 1
//#define HAVE_CONDITIONAL_CALL 1
#define RAM_OFFSET 1
#define USE_MINI_HT 1

/* ARM calling convention:
   x0-x18: caller-save
   x19-x28: callee-save */

#define ARG1_REG 0
#define ARG2_REG 1
#define ARG3_REG 2
#define ARG4_REG 3

/* GCC register naming convention:
   x16 = ip0 (scratch)
   x17 = ip1 (scratch)
   x29 = fp (frame pointer)
   x30 = lr (link register)
   x31 = sp (stack pointer) */

#define FP 29
#define LR 30
#define WZR 31
#define XZR WZR
#define CALLER_SAVED_REGS 0x7ffff
#define HOST_TEMPREG 30

// Note: FP is set to &dynarec_local when executing generated code.
// Thus the local variables are actually global and not on the stack.

#define TARGET_SIZE_2 25 // 2^25 = 32 megabytes
#define JUMP_TABLE_SIZE (sizeof(jump_table_symbols)*2)

#endif /* M64P_DEVICE_R4300_NEW_DYNAREC_ARM_ASSEM_ARM64_H */
