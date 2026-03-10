@ vim:filetype=armasm:

@ ARM940 initialization.
@ Based on ogg940 code by Dzz.
@ (c) Copyright 2007, Grazvydas "notaz" Ignotas

.equ mmsp2_regs, (0xc0000000-0x02000000) @ assume we live @ 0x2000000 bank
.equ shared_ctl,  0x00200000             @ this is where shared_ctl struncture is located


@ exception table:
.global code940
code940:
    b .b_reset                    @ reset
    b .b_undef                    @ undefined instructions
    b .b_swi                      @ software interrupt
    b .b_pabort                   @ prefetch abort
    b .b_dabort                   @ data abort
    b .b_reserved                 @ reserved
    b .b_irq                      @ IRQ
    b .b_fiq                      @ FIQ

@ test
.b_reset:
    mov     r12, #0
    b       .Begin
.b_undef:
    mov     r12, #1
    b       .Begin
.b_swi:
    mov     r12, #2
    b       .Begin
.b_pabort:
    mov     r12, #3
    b       .Begin
.b_dabort:
    mov     r12, #4
    b       .Begin
.b_reserved:
    mov     r12, #5
    b       .Begin
.b_irq:
    mov     sp, #0x100000       @ reset stack
    sub     sp, sp, #4
    mov     r0, #shared_ctl     @ remember where we were when interrupt happened
    add     r0, r0, #0x20
    str     lr, [r0]
    mov     r0, #shared_ctl     @ increment exception counter (for debug)
    add     r0, r0, #(6*4)
    ldr     r1, [r0]
    add     r1, r1, #1
    str     r1, [r0]

    bl Main940

    @ we should never get here
    b .b_reserved


.b_fiq:
    mov     r12, #7
    b       .Begin

.Begin:
    mov sp, #0x100000           @ set the stack top (1M)
    sub sp, sp, #4              @ minus 4

    @ set up memory region 0 -- the whole 4GB address space
    mov r0, #(0x1f<<1)|1        @ region data
    mcr p15, 0, r0, c6, c0, 0   @ opcode2 ~ data/instr
    mcr p15, 0, r0, c6, c0, 1

    @ set up region 1 which is the first 2 megabytes.
    mov r0, #(0x14<<1)|1        @ region data
    mcr p15, 0, r0, c6, c1, 0
    mcr p15, 0, r0, c6, c1, 1

    @ set up region 2: 64k 0x200000-0x210000
    mov r0, #(0x0f<<1)|1
    orr r0, r0, #0x200000
    mcr p15, 0, r0, c6, c2, 0
    mcr p15, 0, r0, c6, c2, 1

    @ set up region 3: 64k 0xbe000000-0xbe010000 (hw control registers)
    mov r0, #(0x0f<<1)|1
    orr r0, r0, #mmsp2_regs
    mcr p15, 0, r0, c6, c3, 0
    mcr p15, 0, r0, c6, c3, 1

    @ region 4: 4K 0x00000000-0x00001000 (boot code protection region)
    mov r0, #(0x0b<<1)|1
    mcr p15, 0, r0, c6, c4, 0
    mcr p15, 0, r0, c6, c4, 1

    @ region 5: 4M 0x00400000-0x00800000 (mp3 area part1)
    mov r0, #(0x15<<1)|1
    orr r0, r0, #0x00400000
    mcr p15, 0, r0, c6, c5, 0
    mcr p15, 0, r0, c6, c5, 1

    @ region 6: 8M 0x00800000-0x01000000 (mp3 area part2)
    mov r0, #(0x16<<1)|1
    orr r0, r0, #0x00800000
    mcr p15, 0, r0, c6, c6, 0
    mcr p15, 0, r0, c6, c6, 1

    @ set regions 1, 4, 5 and 6 to be cacheable (so the first 2M and mp3 area will be cacheable)
    mov r0, #(1<<1)|(1<<4)|(1<<5)|(1<<6)
    mcr p15, 0, r0, c2, c0, 0
    mcr p15, 0, r0, c2, c0, 1

    @ set region 1 to be bufferable too (only data)
    mov r0, #(1<<1)
    mcr p15, 0, r0, c3, c0, 0

    @ set access protection
    @ data: [full, full, no, full, full, full, no access] for regions [6 5 4 3 2 1 0]
    mov r0,     #       (3<<12)|(3<<10)|(0<<8)
    orr r0, r0, #(3<<6)|(3<< 4)|(3<< 2)|(0<<0)
    mcr p15, 0, r0, c5, c0, 0
    @ instructions: [no, no, full, no, no, full, no]
    mov r0,     #       (0<<12)|(0<<10)|(3<<8)
    orr r0, r0, #(0<<6)|(0<< 4)|(3<< 2)|(0<<0)
    mcr p15, 0, r0, c5, c0, 1

    mrc p15, 0, r0, c1, c0, 0   @ fetch current control reg
    orr r0, r0, #1              @ 0x00000001: enable protection unit
    orr r0, r0, #4              @ 0x00000004: enable D cache
    orr r0, r0, #0x1000         @ 0x00001000: enable I cache
@    bic r0, r0, #0xC0000000
@    orr r0, r0, #0x40000000     @ 0x40000000: synchronous, faster?
    orr r0, r0, #0xC0000000     @ 0xC0000000: async
    mcr p15, 0, r0, c1, c0, 0   @ set control reg

    @ flush (invalidate) the cache (just in case)
    mov r0, #0
    mcr p15, 0, r0, c7, c6, 0

    @ remember which exception vector we came from (increment counter for debug)
    mov     r0, #shared_ctl
    add     r0, r0, r12, lsl #2
    ldr     r1, [r0]
    add     r1, r1, #1
    str     r1, [r0]
    
    @ remember last lr (for debug)
    mov     r0, #shared_ctl
    add     r0, r0, #0x20
    str     lr, [r0]

    @ ready to take first job-interrupt
wait_for_irq:
    mrs     r0, cpsr
    bic     r0, r0, #0x80
    msr     cpsr_c, r0              @ enable interrupts

    mov     r0, #0
    mcr     p15, 0, r0, c7, c0, 4   @ wait for IRQ
@    mcr     p15, 0, r0, c15, c8, 2
    nop
    nop
    b       .b_reserved



@ next job getter
.global wait_get_job @ int oldjob

wait_get_job:
    mov     r3, #mmsp2_regs
    orr     r2, r3, #0x3B00
    orr     r2, r2, #0x0046         @ DUALPEND940 register
    ldrh    r12,[r2]

    tst     r0, r0
    beq     wgj_no_old
    sub     r0, r0, #1
    mov     r1, #1
    mov     r1, r1, lsl r0
    strh    r1, [r2]                @ clear finished job's pending bit
    bic     r12,r12,r1

wgj_no_old:
    tst     r12,r12
    beq     wgj_no_jobs
    mov     r0, #0
wgj_loop:
    add     r0, r0, #1
    movs    r12,r12,lsr #1
    bxcs    lr
    b       wgj_loop

wgj_no_jobs:
    mvn     r0, #0
    orr     r2, r3, #0x4500
    str     r0, [r2]            @ clear all pending interrupts in irq controller's SRCPND register
    orr     r2, r2, #0x0010
    str     r0, [r2]            @ clear all pending interrupts in irq controller's INTPND register
    b       wait_for_irq

.pool




@ some asm utils are also defined here:
.global spend_cycles @ c

spend_cycles:
    mov     r0, r0, lsr #2  @ 4 cycles/iteration
    sub     r0, r0, #2      @ entry/exit/init
.sc_loop:
    subs    r0, r0, #1
    bpl     .sc_loop

    bx      lr


@ clean-flush function from ARM940T technical reference manual
.global dcache_clean_flush

dcache_clean_flush:
    mov     r1, #0                  @ init line counter
ccf_outer_loop:
    mov     r0, #0                  @ segment counter
ccf_inner_loop:
    orr     r2, r1, r0              @ make segment and line address
    mcr     p15, 0, r2, c7, c14, 2  @ clean and flush that line
    add     r0, r0, #0x10           @ incremet segment counter
    cmp     r0, #0x40               @ complete all 4 segments?
    bne     ccf_inner_loop
    add     r1, r1, #0x04000000     @ increment line counter
    cmp     r1, #0                  @ complete all lines?
    bne     ccf_outer_loop
    bx      lr



@ clean-only version
.global dcache_clean

dcache_clean:
    mov     r1, #0                  @ init line counter
cf_outer_loop:
    mov     r0, #0                  @ segment counter
cf_inner_loop:
    orr     r2, r1, r0              @ make segment and line address
    mcr     p15, 0, r2, c7, c10, 2  @ clean that line
    add     r0, r0, #0x10           @ incremet segment counter
    cmp     r0, #0x40               @ complete all 4 segments?
    bne     cf_inner_loop
    add     r1, r1, #0x04000000     @ increment line counter
    cmp     r1, #0                  @ complete all lines?
    bne     cf_outer_loop
    bx      lr


@ drain write buffer
.global drain_wb

drain_wb:
    mov     r0, #0
    mcr     p15, 0, r0, c7, c10, 4
    bx      lr


.global set_if_not_changed @ int *val, int oldval, int newval

set_if_not_changed:
    swp    r3, r2, [r0]
    cmp    r1, r3
    bxeq   lr
    strne  r3, [r0] @ restore value which was changed there by other core
    bx     lr



@ pad the protected region.
.rept 1024
.long 0
.endr

