//@@

#include "build.h"

//.arm64
//.align 8
//
//.equ SH4_TIMESLICE, 448
//.equ BM_BLOCKLIST_MASK, 65532 @FFFC
//.equ CPU_RATIO, 5

#if HOST_OS == OS_DARWIN
#define CSYM(n) _##n
#define HIDDEN(n)
#else
#define CSYM(n) n
#define HIDDEN(n) .hidden CSYM(n)
#endif

//CSYM(intc_sched):        // next_pc _MUST_ be on ram
//#if HOST_OS == OS_DARWIN
//add w11,w11,448
//#else
//add w9,w9,448
//#endif
//mov w4,lr
//bl CSYM(UpdateSystem)
//mov lr,w4
//cmp w0,#0
//B.eq r30            // faster than bxeq r4 (as it should, call stack cache)

//ngen_blockcheckfail:
//    bl CSYM(rdv_BlockCheckFail)
//    bx r0 // Branch and exchange instruction set (switch to thumb)

//@@@@@@@@@@ some helpers @@@@@@@@@@
//
//.global CSYM(do_sqw_nommu_area_3)
//HIDDEN(do_sqw_nommu_area_3)
//@r0: addr
//@r1: sq_both
//CSYM(do_sqw_nommu_area_3):
//add r3,r1,#0x0C000000    @ get ram ptr from r1, part 1
//and r2,r0,#0x20            @ SQ# selection, isolate
//ubfx r0,r0,#5,#19        @ get ram offset
//add r1,r2                @ SQ# selection, add to SQ ptr
//add r3,#512                @ get ram ptr from r1, part 2
//add r3,r0,lsl #5        @ ram + offset
//vldm r1,{d0-d3}
//vstm r3,{d0-d3}
//bx lr
//
//.global CSYM(TAWriteSQ)
//HIDDEN(TAWriteSQ)
//@r0: addr
//@r1: sq_both
//CSYM(TAWriteSQ):
//BIC     R3, R0, #0xFE000000        @clear unused bits
//AND     R0, R0, #0x20            @SQ#, isolate
//CMP     R3, #0x800000            @TA write?
//ADD     R0, R1, R0                @SQ#, add to SQ ptr
//BCC     CSYM(_Z13ta_vtx_data32Pv)    @TA write?
//
//CSYM(TAWriteSQ_yuv):
//CMP     R3, #0x1000000    @Yuv write ?
//BCS     CSYM(TAWriteSQ_vram)
//MOV     R1, #1
//B       CSYM(_Z8YUV_dataPjj)
//
//CSYM(TAWriteSQ_vram):                @vram write ..
//#ifdef TARGET_IPHONE
//bkpt #0
//#else
//bkpt
//#endif
//ubfx r0,r3,#5,#18        @ get vram offset
//add r3,r1,#0x04000000    @ get vram ptr from r1, part 1
//add r3,#512                @ get ram ptr from r1, part 2
//add r3,r0,lsl #5        @ ram + offset
//vldm r1,{d0-d3}
//vstm r3,{d0-d3}
//bx lr
//
//
//#if FEAT_SHREC != DYNAREC_NONE
//
//@@@@@@@@@@ ngen_LinkBlock_*****_stub @@@@@@@@@@
//
//.global CSYM(ngen_LinkBlock_Generic_stub)
//HIDDEN(ngen_LinkBlock_Generic_stub)
//CSYM(ngen_LinkBlock_Generic_stub):
//
//    mov r1,r4    @ djump/pc -> in case we need it ..
//    b CSYM(ngen_LinkBlock_Shared_stub)
//
//
//.global CSYM(ngen_LinkBlock_cond_Branch_stub)
//HIDDEN(ngen_LinkBlock_cond_Branch_stub)
//CSYM(ngen_LinkBlock_cond_Branch_stub):
//
//    mov r1,#1
//    b CSYM(ngen_LinkBlock_Shared_stub)
//
//.global CSYM(ngen_LinkBlock_cond_Next_stub)
//HIDDEN(ngen_LinkBlock_cond_Next_stub)
//CSYM(ngen_LinkBlock_cond_Next_stub):
//
//    mov r1,#0
//    b CSYM(ngen_LinkBlock_Shared_stub)
//
//
//.global CSYM(ngen_LinkBlock_Shared_stub)
//HIDDEN(ngen_LinkBlock_Shared_stub)
//CSYM(ngen_LinkBlock_Shared_stub):
//
//    mov r0,lr
//    sub r0,#4                  @go before the call
//    bl CSYM(rdv_LinkBlock)
//    bx r0
//
//@@@@@@@@@@ ngen_FailedToFindBlock_ @@@@@@@@@@
//
//
//.global CSYM(ngen_FailedToFindBlock_)
//HIDDEN(ngen_FailedToFindBlock_)
//CSYM(ngen_FailedToFindBlock_):
//    mov r0,r4
//    bl CSYM(rdv_FailedToFindBlock)
//    bx r0
//
//@@@@@@@@@@ ngen_blockcheckfail @@@@@@@@@@
//
//.global CSYM(ngen_blockcheckfail)
//HIDDEN(ngen_blockcheckfail)
//CSYM(ngen_blockcheckfail):
//    bl CSYM(rdv_BlockCheckFail)
//    bx r0
//
//
//@@@@@@@@@@ ngen_mainloop @@@@@@@@@@
//
//@ you can load the address of the sh4 reg struct on the mainloop init
//@ using (u8*)regptr-(u8*)Sh4cntx
//@ all registers are < 1024 bytes from that
//@ so you can use reg+imm forms for it
//
//
//
//.global CSYM(ngen_mainloop)
//HIDDEN(ngen_mainloop)
//CSYM(ngen_mainloop):
//
//push { r4-r12,lr }
//
//
//#if HOST_OS == OS_DARWIN
//    mov r11, #SH4_TIMESLICE @ load cycle counter
//#else
//    mov r9, #SH4_TIMESLICE @ load cycle counter
//#endif
//
//    mov r8, r0            @Load context
//    ldr r4, [r8,#-184]    @load pc
//
//    b CSYM(no_update)            @Go to mainloop !
//
//
//    @this code is here for fall-through behavior of do_iter
//    .global CSYM(intc_sched)
//    HIDDEN(intc_sched)
//CSYM(intc_sched):        @ next_pc _MUST_ be on ram
//#if HOST_OS == OS_DARWIN
//    add r11,r11,#SH4_TIMESLICE
//#else
//    add r9,r9,#SH4_TIMESLICE
//#endif
//    mov r4,lr
//    bl CSYM(UpdateSystem)
//    mov lr,r4
//    cmp r0,#0
//    bxeq lr            @faster than bxeq r4 (as it should, call stack cache)
//
//do_iter:
//    mov r0,r4
//    bl CSYM(rdv_DoInterrupts)
//    mov r4,r0
//
//.global CSYM(no_update)
//HIDDEN(no_update)
//CSYM(no_update):              @ next_pc _MUST_ be on r4 *R4 NOT R0 anymore*
//
//#if DC_PLATFORM == DC_PLATFORM_NAOMI
//    sub r2,r8,#0x4100000
//    ubfx r1,r4,#1,#24
//#else
//    sub r2,r8,#0x2100000
//    ubfx r1,r4,#1,#23
//#endif
//    ldr pc,[r2,r1,lsl #2]
//
//    @bic r1,r4,#0xFF000000
//    @ldr pc,[r2,r1,lsl #1]
//
//
//pop {r4-r12,lr}
//bx lr
//
//end_ngen_mainloop:
//@@@@@@@@@@ ngen_mainloop @@@@@@@@@@
//
//.global CSYM(arm_compilecode)
//HIDDEN(arm_compilecode)
//CSYM(arm_compilecode):
//bl CSYM(CompileCode)
//b CSYM(arm_dispatch)
//
//#ifdef TARGET_IPHONE
//Xarm_Reg: .word CSYM(arm_Reg)
//XEntryPoints: .word CSYM(EntryPoints)
//#endif
//
//.global CSYM(arm_mainloop)
//HIDDEN(arm_mainloop)
//CSYM(arm_mainloop): @(cntx,lookup_base,cycles)
//
//#if HOST_OS == OS_DARWIN
//push {r4,r5,r8,r11,lr}
//#else
//push {r4,r5,r8,r9,lr}
//#endif
//
//    #ifdef TARGET_IPHONE
//    ldr r8,Xarm_Reg            @load cntx
//    ldr r4,XEntryPoints        @load lookup base
//    #else
//    ldr r8,=arm_Reg            @load cntx
//    ldr r4,=EntryPoints        @load lookup base
//    #endif
//
//    ldr r5,[r8,#192]    @load cycle count
//    add r5,r0            @add cycles for this timeslice
//
//    b CSYM(arm_dispatch)
//
//.global CSYM(arm_dispatch)
//HIDDEN(arm_dispatch)
//CSYM(arm_dispatch):
//    #ifdef TARGET_IPHONE
//    ldrd r0,r1,[r8,#184]        @load: Next PC, interrupt
//    #else
//    ldrd r0,[r8,#184]        @load: Next PC, interrupt
//    #endif
//
//    ubfx r2,r0,#2,#19
//    cmp r1,#0
//    bne arm_dofiq
//
//    ldr pc,[r4,r2,lsl #2]
//
//arm_dofiq:
//    bl CSYM(CPUFiq)
//    b CSYM(arm_dispatch)
//
//.global CSYM(arm_exit)
//HIDDEN(arm_exit)
//CSYM(arm_exit):
//    str r5,[r8,#192]        @if timeslice is over, save remaining cycles
//#if HOST_OS == OS_DARWIN
//    pop {r4,r5,r8,r11,pc}
//#else
//    pop {r4,r5,r8,r9,pc}
//#endif
//
//@@@@@@
//@matrix mul
//#ifndef _ANDROID
//.global CSYM(ftrv_asm)
//HIDDEN(ftrv_asm)
//CSYM(ftrv_asm):
//
//@r0=dst,r1=vec,r2=mtx
//
//@3x vld1.32 might be faster
//vldm r2,{d16-d24}
//vldm r1, {d0-d1}
//
//VMUL.F32 Q2,Q8,d0[0]
//VMLA.F32 Q2,Q9,d0[1]
//VMLA.F32 Q2,Q10,d1[0]
//VMLA.F32 Q2,Q11,d1[1]
//
//vstm r0,{d4,d5}
//
//bx lr
//
//.global CSYM(fipr_asm)
//HIDDEN(fipr_asm)
//CSYM(fipr_asm):
//
//@ vdot
//@        idp=fr[n+0]*fr[m+0];
//@        idp+=fr[n+1]*fr[m+1];
//@        idp+=fr[n+2]*fr[m+2];
//@        idp+=fr[n+3]*fr[m+3];
//
//
//vldm r0, {d0,d1}
//vldm r1, {d2,d3}
//
//vmul.f32 q0,q1
//@NEON is quite nice actually ! if only its performance was good enough ...
//vpadd.f32 d0,d0,d1 @d0={d0[0]+d0[1], d1[0]+d1[1]}
//vpadd.f32 d0,d0,d0 @d0={d0[0]+d0[1]+d1[0]+d1[1], d0[0]+d0[1]+d1[0]+d1[1]}
//
//@store to ret ..
//vmov r0,s0
//bx lr
//
//#endif
//
//#endif

