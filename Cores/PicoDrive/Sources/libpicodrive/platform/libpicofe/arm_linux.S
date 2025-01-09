@ vim:filetype=armasm
#include <sys/syscall.h>


.global cache_flush_d_inval_i @ void *start_addr, void *end_addr

cache_flush_d_inval_i:
    mov     r2, #0
#ifdef __ARM_EABI__
    /* EABI version */
    str     r7, [sp, #-4]!
    mov     r7, #(__ARM_NR_cacheflush & 0xff)
#if (__ARM_NR_cacheflush & 0x00ff00)
    orr     r7, r7, #(__ARM_NR_cacheflush & 0x00ff00)
#endif
#if (__ARM_NR_cacheflush & 0xff0000)
    orr     r7, r7, #(__ARM_NR_cacheflush & 0xff0000)
#endif
    swi     0
    ldr     r7, [sp], #4
#else
    /* OABI */
    swi     __ARM_NR_cacheflush
#endif
    bx      lr

