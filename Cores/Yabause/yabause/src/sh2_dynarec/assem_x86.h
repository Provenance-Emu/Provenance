#define HOST_REGS 8
#define HOST_CCREG 6
#define EXCLUDE_REG 4
#define SLAVERA_REG 5

//#define IMM_PREFETCH 1
#define HOST_IMM_ADDR32 1
#define INVERTED_CARRY 1
#define DESTRUCTIVE_WRITEBACK 1
#define DESTRUCTIVE_SHIFT 1

#define USE_MINI_HT 1

#define BASE_ADDR 0x70000000 // Code generator target address
#define TARGET_SIZE_2 25 // 2^25 = 32 megabytes
#define JUMP_TABLE_SIZE 0 // Not needed for 32-bit x86

/* x86 calling convention:
   caller-save: %eax %ecx %edx
   callee-save: %ebp %ebx %esi %edi */

#define EAX 0
#define ECX 1
#define EDX 2
#define EBX 3
#define ESP 4
#define EBP 5
#define ESI 6
#define EDI 7

extern u32 memory_map[1048576]; // 32-bit
