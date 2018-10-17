#define HOST_REGS 13
#define HOST_CCREG 10
#define EXCLUDE_REG 11
#define SLAVERA_REG 8

#define HOST_IMM8 1
#define HAVE_CMOV_IMM 1
#define CORTEX_A8_BRANCH_PREDICTION_HACK 1
#define USE_MINI_HT 1
//#define REG_PREFETCH 1

/* ARM calling convention:
   r0-r3, r12: caller-save
   r4-r11: callee-save */

#define ARG1_REG 0
#define ARG2_REG 1
#define ARG3_REG 2
#define ARG4_REG 3

/* GCC register naming convention:
   r10 = sl (base)
   r11 = fp (frame pointer)
   r12 = ip (scratch)
   r13 = sp (stack pointer)
   r14 = lr (link register)
   r15 = pc (program counter) */

#define FP 11
#define LR 14
#define HOST_TEMPREG 14

// Note: FP is set to &dynarec_local when executing generated code.
// Thus the local variables are actually global and not on the stack.

extern u8 sh2_dynarec_target[16777216];
extern u32 memory_map[1048576]; // 32-bit

//#define BASE_ADDR 0x6000000 // Code generator target address
#define BASE_ADDR ((u32)&sh2_dynarec_target) // Code generator target address
#define TARGET_SIZE_2 24 // 2^24 = 16 megabytes
//#define TARGET_SIZE_2 25 // 2^25 = 32 megabytes

#ifdef ANDROID
#define __clear_cache clear_cache
#endif
