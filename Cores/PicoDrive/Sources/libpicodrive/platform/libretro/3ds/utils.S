  .text
  .arm
  .balign 4

  .func ctr_clear_cache_kernel
ctr_clear_cache_kernel:
  cpsid aif
  mov r0, #0
  mcr p15, 0, r0, c7, c10, 0    @ Clean entire data cache
  mcr p15, 0, r0, c7, c10, 5    @ Data Memory Barrier
  mcr p15, 0, r0, c7, c5, 0     @ Invalidate entire instruction cache / Flush BTB
  mcr p15, 0, r0, c7, c10, 4    @ Data Sync Barrier
  bx lr
  .endfunc

  @@ Clear the entire data cache / invalidate the instruction cache. Uses
  @@ Rosalina svcCustomBackdoor to avoid svcBackdoor stack corruption
  @@ during interrupts.
  .global ctr_clear_cache
  .func ctr_clear_cache
ctr_clear_cache:
  ldr r0, =ctr_clear_cache_kernel
  svc 0x80                      @ svcCustomBackdoor
  bx lr
  .endfunc
