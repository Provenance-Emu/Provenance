#ifdef __arm__
;@ Reesy's Z80 Emulator Version 0.001

;@ (c) Copyright 2004 Reesy, All rights reserved
;@ DrZ80 is free for non-commercial use.

;@ For commercial use, separate licencing terms must be obtained.

      .data
      .align 4

      .global DrZ80Run
      .global DrZ80Ver

      .equiv INTERRUPT_MODE,         0	;@0 = Use internal int handler, 1 = Use Mames int handler
      .equiv FAST_Z80SP,             1	;@0 = Use mem functions for stack pointer, 1 = Use direct mem pointer
      .equiv UPDATE_CONTEXT,         0
      .equiv DRZ80_XMAP,             1
      .equiv DRZ80_XMAP_MORE_INLINE, 1

.if DRZ80_XMAP
      .equ Z80_MEM_SHIFT, 13
.endif

.if INTERRUPT_MODE
      .extern Interrupt
.endif

DrZ80Ver: .long 0x0001

;@ --------------------------- Defines ----------------------------
;@ Make sure that regs/pointers for z80pc to z80sp match up!

	z80_icount .req r3
	opcodes    .req r4
	cpucontext .req r5
	z80pc      .req r6
	z80a       .req r7
	z80f       .req r8
	z80bc      .req r9
	z80de      .req r10
	z80hl      .req r11
	z80sp      .req r12	
	z80xx      .req lr

	.equ z80pc_pointer,           0                  ;@  0
	.equ z80a_pointer,            z80pc_pointer+4    ;@  4
	.equ z80f_pointer,            z80a_pointer+4     ;@  8
	.equ z80bc_pointer,           z80f_pointer+4     ;@  
	.equ z80de_pointer,           z80bc_pointer+4
	.equ z80hl_pointer,           z80de_pointer+4
	.equ z80sp_pointer,           z80hl_pointer+4
	.equ z80pc_base,              z80sp_pointer+4
	.equ z80sp_base,              z80pc_base+4
	.equ z80ix,                   z80sp_base+4
	.equ z80iy,                   z80ix+4
	.equ z80i,                    z80iy+4
	.equ z80a2,                   z80i+4
	.equ z80f2,                   z80a2+4
	.equ z80bc2,                  z80f2+4
	.equ z80de2,                  z80bc2+4
	.equ z80hl2,                  z80de2+4
	.equ cycles_pointer,          z80hl2+4     
	.equ previouspc,              cycles_pointer+4     
	.equ z80irq,                  previouspc+4
	.equ z80if,                   z80irq+1
	.equ z80im,                   z80if+1
	.equ z80r,                    z80im+1
	.equ z80irqvector,            z80r+1
	.equ z80irqcallback,          z80irqvector+4
	.equ z80_write8,              z80irqcallback+4
	.equ z80_write16,             z80_write8+4
	.equ z80_in,                  z80_write16+4
	.equ z80_out,                 z80_in+4
	.equ z80_read8,               z80_out+4
	.equ z80_read16,              z80_read8+4
	.equ z80_rebaseSP,            z80_read16+4
	.equ z80_rebasePC,            z80_rebaseSP+4

	.equ VFlag, 0
	.equ CFlag, 1
	.equ ZFlag, 2
	.equ SFlag, 3
	.equ HFlag, 4
	.equ NFlag, 5
	.equ Flag3, 6
	.equ Flag5, 7

	.equ Z80_CFlag, 0
	.equ Z80_NFlag, 1
	.equ Z80_VFlag, 2
	.equ Z80_Flag3, 3
	.equ Z80_HFlag, 4
	.equ Z80_Flag5, 5
	.equ Z80_ZFlag, 6
	.equ Z80_SFlag, 7

	.equ Z80_IF1, 1<<0
	.equ Z80_IF2, 1<<1
	.equ Z80_HALT, 1<<2
	.equ Z80_NMI, 1<<3

;@---------------------------------------

.text

.if DRZ80_XMAP

z80_xmap_read8: @ addr
    ldr r1,[cpucontext,#z80_read8]
    mov r2,r0,lsr #Z80_MEM_SHIFT
    ldr r1,[r1,r2,lsl #2]
    movs r1,r1,lsl #1
    ldrccb r0,[r1,r0]
    bxcc lr

z80_xmap_read8_handler: @ addr, func
    str z80_icount,[cpucontext,#cycles_pointer]
    stmfd sp!,{r12,lr}
    mov lr,pc
    bx r1
    ldr z80_icount,[cpucontext,#cycles_pointer]
    ldmfd sp!,{r12,pc}

z80_xmap_write8: @ data, addr
    ldr r2,[cpucontext,#z80_write8]
    add r2,r2,r1,lsr #Z80_MEM_SHIFT-2
    bic r2,r2,#3
    ldr r2,[r2]
    movs r2,r2,lsl #1
    strccb r0,[r2,r1]
    bxcc lr

z80_xmap_write8_handler: @ data, addr, func
    str z80_icount,[cpucontext,#cycles_pointer]
    mov r3,r0
    mov r0,r1
    mov r1,r3
    stmfd sp!,{r12,lr}
    mov lr,pc
    bx r2
    ldr z80_icount,[cpucontext,#cycles_pointer]
    ldmfd sp!,{r12,pc}

z80_xmap_read16: @ addr
    @ check if we cross bank boundary
    add r1,r0,#1
    eor r1,r1,r0
    tst r1,#1<<Z80_MEM_SHIFT
    bne 0f

    ldr r1,[cpucontext,#z80_read8]
    mov r2,r0,lsr #Z80_MEM_SHIFT
    ldr r1,[r1,r2,lsl #2]
    movs r1,r1,lsl #1
    bcs 0f
    ldrb r0,[r1,r0]!
    ldrb r1,[r1,#1]
    orr r0,r0,r1,lsl #8
    bx lr

0:
    @ z80_xmap_read8 will save r3 and r12 for us
    stmfd sp!,{r8,r9,lr}
    mov r8,r0
    bl z80_xmap_read8
    mov r9,r0
    add r0,r8,#1
    bl z80_xmap_read8
    orr r0,r9,r0,lsl #8
    ldmfd sp!,{r8,r9,pc}

z80_xmap_write16: @ data, addr
    add r2,r1,#1
    eor r2,r2,r1
    tst r2,#1<<Z80_MEM_SHIFT
    bne 0f

    ldr r2,[cpucontext,#z80_write8]
    add r2,r2,r1,lsr #Z80_MEM_SHIFT-2
    bic r2,r2,#3
    ldr r2,[r2]
    movs r2,r2,lsl #1
    bcs 0f
    strb r0,[r2,r1]!
    mov r0,r0,lsr #8
    strb r0,[r2,#1]
    bx lr

0:
    stmfd sp!,{r8,r9,lr}
    mov r8,r0
    mov r9,r1
    bl z80_xmap_write8
    mov r0,r8,lsr #8
    add r1,r9,#1
    bl z80_xmap_write8
    ldmfd sp!,{r8,r9,pc}

z80_xmap_rebase_pc:
    ldr r1,[cpucontext,#z80_read8]
    mov r2,r0,lsr #Z80_MEM_SHIFT
    ldr r1,[r1,r2,lsl #2]
    movs r1,r1,lsl #1
    strcc r1,[cpucontext,#z80pc_base]
    addcc z80pc,r1,r0
    bxcc lr

z80_bad_jump:
    stmfd sp!,{r3,r12,lr}
    mov lr,pc
    ldr pc,[cpucontext,#z80_rebasePC]
    mov z80pc,r0
    ldmfd sp!,{r3,r12,pc}

z80_xmap_rebase_sp:
    ldr r1,[cpucontext,#z80_read8]
    sub r2,r0,#1
    mov r2,r2,lsl #16
    mov r2,r2,lsr #(Z80_MEM_SHIFT+16)
    ldr r1,[r1,r2,lsl #2]
    movs r1,r1,lsl #1
    strcc r1,[cpucontext,#z80sp_base]
    addcc z80sp,r1,r0
    bxcc lr

    stmfd sp!,{r3,r12,lr}
    mov lr,pc
    ldr pc,[cpucontext,#z80_rebaseSP]
    mov z80sp,r0
    ldmfd sp!,{r3,r12,pc}
 
.endif @ DRZ80_XMAP


.macro fetch cycs
	subs z80_icount,z80_icount,#\cycs
.if UPDATE_CONTEXT
    str z80pc,[cpucontext,#z80pc_pointer]
	str z80_icount,[cpucontext,#cycles_pointer]
	ldr r1,[cpucontext,#z80pc_base]
	sub r2,z80pc,r1
	str r2,[cpucontext,#previouspc]
.endif
	ldrplb r0,[z80pc],#1
	ldrpl pc,[opcodes,r0, lsl #2]
	bmi z80_execute_end
.endm

.macro eatcycles cycs
	sub z80_icount,z80_icount,#\cycs
.if UPDATE_CONTEXT
	str z80_icount,[cpucontext,#cycles_pointer]
.endif
.endm

.macro readmem8
.if UPDATE_CONTEXT
    str z80pc,[cpucontext,#z80pc_pointer]
.endif
.if DRZ80_XMAP
.if !DRZ80_XMAP_MORE_INLINE
    ldr r1,[cpucontext,#z80_read8]
    mov r2,r0,lsr #Z80_MEM_SHIFT
    ldr r1,[r1,r2,lsl #2]
    movs r1,r1,lsl #1
    ldrccb r0,[r1,r0]
    blcs z80_xmap_read8_handler
.else
    bl z80_xmap_read8
.endif
.else ;@ if !DRZ80_XMAP
    stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_read8]			;@ r0 = addr - data returned in r0
	ldmfd sp!,{r3,r12}
.endif
.endm

.macro readmem8HL
	mov r0,z80hl, lsr #16
	readmem8
.endm

.macro readmem16
.if UPDATE_CONTEXT
     str z80pc,[cpucontext,#z80pc_pointer]
.endif
.if DRZ80_XMAP
    bl z80_xmap_read16
.else
	stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_read16]
	ldmfd sp!,{r3,r12}
.endif
.endm

.macro writemem8
.if UPDATE_CONTEXT
     str z80pc,[cpucontext,#z80pc_pointer]
.endif
.if DRZ80_XMAP
.if DRZ80_XMAP_MORE_INLINE
    ldr r2,[cpucontext,#z80_write8]
    mov lr,r1,lsr #Z80_MEM_SHIFT
    ldr r2,[r2,lr,lsl #2]
    movs r2,r2,lsl #1
    strccb r0,[r2,r1]
    blcs z80_xmap_write8_handler
.else
    bl z80_xmap_write8
.endif
.else ;@ if !DRZ80_XMAP
	stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_write8]			;@ r0=data r1=addr
	ldmfd sp!,{r3,r12}
.endif
.endm

.macro writemem8DE
	mov r1,z80de, lsr #16
	writemem8
.endm

.macro writemem8HL
	mov r1,z80hl, lsr #16
	writemem8
.endm

.macro writemem16
.if UPDATE_CONTEXT
     str z80pc,[cpucontext,#z80pc_pointer]
.endif
.if DRZ80_XMAP
    bl z80_xmap_write16
.else
	stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_write16]		;@ r0=data r1=addr
	ldmfd sp!,{r3,r12}
.endif
.endm

.macro copymem8HL_DE
.if UPDATE_CONTEXT
     str z80pc,[cpucontext,#z80pc_pointer]
.endif
	mov r0,z80hl, lsr #16
.if DRZ80_XMAP
    bl z80_xmap_read8
.else
    stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_read8]			;@ r0 = addr - data returned in r0
.endif
	mov r1,z80de, lsr #16
.if DRZ80_XMAP
    bl z80_xmap_write8
.else
	mov lr,pc
	ldr pc,[cpucontext,#z80_write8]			;@ r0=data r1=addr
	ldmfd sp!,{r3,r12}
.endif
.endm
;@---------------------------------------

.macro rebasepc
.if UPDATE_CONTEXT
     str z80pc,[cpucontext,#z80pc_pointer]
.endif
.if DRZ80_XMAP
    bl z80_xmap_rebase_pc
.else
    stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_rebasePC]		;@ r0=new pc - external function sets z80pc_base and returns new z80pc in r0
	ldmfd sp!,{r3,r12}
	mov z80pc,r0
.endif
.endm

.macro rebasesp
.if UPDATE_CONTEXT
     str z80pc,[cpucontext,#z80pc_pointer]
.endif
.if DRZ80_XMAP
    bl z80_xmap_rebase_sp
.else
	stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_rebaseSP]		;@ external function must rebase sp
	ldmfd sp!,{r3,r12}
	mov z80sp,r0
.endif
.endm
;@----------------------------------------------------------------------------

.macro opADC
	movs z80f,z80f,lsr#2					;@ get C
	subcs r0,r0,#0x100
	eor z80f,r0,z80a,lsr#24					;@ prepare for check of half carry
	adcs z80a,z80a,r0,ror#8
	mrs r0,cpsr								;@ S,Z,V&C
	eor z80f,z80f,z80a,lsr#24
	and z80f,z80f,#1<<HFlag					;@ H, correct
	orr z80f,z80f,r0,lsr#28
.endm

.macro opADCA
	movs z80f,z80f,lsr#2					;@ get C
	orrcs z80a,z80a,#0x00800000
	adds z80a,z80a,z80a
	mrs z80f,cpsr							;@ S,Z,V&C
	mov z80f,z80f,lsr#28
	tst z80a,#0x10000000					;@ H, correct
	orrne z80f,z80f,#1<<HFlag
	fetch 4
.endm

.macro opADCH reg
	mov r0,\reg,lsr#24
	opADC
	fetch 4
.endm

.macro opADCL reg
	movs z80f,z80f,lsr#2					;@ get C
	adc r0,\reg,\reg,lsr#15
	orrcs z80a,z80a,#0x00800000
	mov r1,z80a,lsl#4						;@ Prepare for check of half carry
	adds z80a,z80a,r0,lsl#23
	mrs z80f,cpsr							;@ S,Z,V&C
	mov z80f,z80f,lsr#28
	cmn r1,r0,lsl#27
	orrcs z80f,z80f,#1<<HFlag				;@ H, correct
	fetch 4
.endm

.macro opADCb
	opADC
.endm
;@---------------------------------------

.macro opADD reg shift
	mov r1,z80a,lsl#4						;@ Prepare for check of half carry
	adds z80a,z80a,\reg,lsl#\shift
	mrs z80f,cpsr							;@ S,Z,V&C
	mov z80f,z80f,lsr#28
	cmn r1,\reg,lsl#\shift+4
	orrcs z80f,z80f,#1<<HFlag
.endm

.macro opADDA
	adds z80a,z80a,z80a
	mrs z80f,cpsr							;@ S,Z,V&C
	mov z80f,z80f,lsr#28
	tst z80a,#0x10000000					;@ H, correct
	orrne z80f,z80f,#1<<HFlag
	fetch 4
.endm

.macro opADDH reg
	and r0,\reg,#0xFF000000
	opADD r0 0
	fetch 4
.endm

.macro opADDL reg
	opADD \reg 8
	fetch 4
.endm

.macro opADDb 
	opADD r0 24
.endm
;@---------------------------------------

.macro opADC16 reg
	movs z80f,z80f,lsr#2					;@ get C
	adc r0,z80a,\reg,lsr#15
	orrcs z80hl,z80hl,#0x00008000
	mov r1,z80hl,lsl#4
	adds z80hl,z80hl,r0,lsl#15
	mrs z80f,cpsr							;@ S, Z, V & C
	mov z80f,z80f,lsr#28
	cmn r1,r0,lsl#19
	orrcs z80f,z80f,#1<<HFlag
	fetch 15
.endm

.macro opADC16HL
	movs z80f,z80f,lsr#2					;@ get C
	orrcs z80hl,z80hl,#0x00008000
	adds z80hl,z80hl,z80hl
	mrs z80f,cpsr							;@ S, Z, V & C
	mov z80f,z80f,lsr#28
	tst z80hl,#0x10000000					;@ H, correct.
	orrne z80f,z80f,#1<<HFlag
	fetch 15
.endm

.macro opADD16 reg1 reg2
	mov r1,\reg1,lsl#4						;@ Prepare for check of half carry
	adds \reg1,\reg1,\reg2
	bic z80f,z80f,#(1<<CFlag)|(1<<HFlag)|(1<<NFlag)
	orrcs z80f,z80f,#1<<CFlag
	cmn r1,\reg2,lsl#4
	orrcs z80f,z80f,#1<<HFlag
.endm

.macro opADD16s reg1 reg2 shift
	mov r1,\reg1,lsl#4						;@ Prepare for check of half carry
	adds \reg1,\reg1,\reg2,lsl#\shift
	bic z80f,z80f,#(1<<CFlag)|(1<<HFlag)|(1<<NFlag)
	orrcs z80f,z80f,#1<<CFlag
	cmn r1,\reg2,lsl#4+\shift
	orrcs z80f,z80f,#1<<HFlag
.endm

.macro opADD16_2 reg
	adds \reg,\reg,\reg
	bic z80f,z80f,#(1<<CFlag)|(1<<HFlag)|(1<<NFlag)
	orrcs z80f,z80f,#1<<CFlag
	tst \reg,#0x10000000					;@ H, correct.
	orrne z80f,z80f,#1<<HFlag
.endm
;@---------------------------------------

.macro opAND reg shift
	and z80a,z80a,\reg,lsl#\shift
	sub r0,opcodes,#0x100
	ldrb z80f,[r0,z80a, lsr #24]
	orr z80f,z80f,#1<<HFlag
.endm

.macro opANDA
	sub r0,opcodes,#0x100
	ldrb z80f,[r0,z80a, lsr #24]
	orr z80f,z80f,#1<<HFlag
	fetch 4
.endm

.macro opANDH reg
	opAND \reg 0
	fetch 4
.endm

.macro opANDL reg
	opAND \reg 8
	fetch 4
.endm

.macro opANDb
	opAND r0 24
.endm
;@---------------------------------------

.macro opBITH reg bit
	and z80f,z80f,#1<<CFlag
	tst \reg,#1<<(24+\bit)
	orreq z80f,z80f,#(1<<HFlag)|(1<<ZFlag)|(1<<VFlag)
	orrne z80f,z80f,#(1<<HFlag)
	fetch 8
.endm

.macro opBIT7H reg
	and z80f,z80f,#1<<CFlag
	tst \reg,#1<<(24+7)
	orreq z80f,z80f,#(1<<HFlag)|(1<<ZFlag)|(1<<VFlag)
	orrne z80f,z80f,#(1<<HFlag)|(1<<SFlag)
	fetch 8
.endm

.macro opBITL reg bit
	and z80f,z80f,#1<<CFlag
	tst \reg,#1<<(16+\bit)
	orreq z80f,z80f,#(1<<HFlag)|(1<<ZFlag)|(1<<VFlag)
	orrne z80f,z80f,#(1<<HFlag)
	fetch 8
.endm

.macro opBIT7L reg
	and z80f,z80f,#1<<CFlag
	tst \reg,#1<<(16+7)
	orreq z80f,z80f,#(1<<HFlag)|(1<<ZFlag)|(1<<VFlag)
	orrne z80f,z80f,#(1<<HFlag)|(1<<SFlag)
	fetch 8
.endm

.macro opBITb bit
	and z80f,z80f,#1<<CFlag
	tst r0,#1<<\bit
	orreq z80f,z80f,#(1<<HFlag)|(1<<ZFlag)|(1<<VFlag)
	orrne z80f,z80f,#(1<<HFlag)
.endm

.macro opBIT7b
	and z80f,z80f,#1<<CFlag
	tst r0,#1<<7
	orreq z80f,z80f,#(1<<HFlag)|(1<<ZFlag)|(1<<VFlag)
	orrne z80f,z80f,#(1<<HFlag)|(1<<SFlag)
.endm
;@---------------------------------------

.macro opCP reg shift
	mov r1,z80a,lsl#4						;@ prepare for check of half carry
	cmp z80a,\reg,lsl#\shift
	mrs z80f,cpsr
	mov z80f,z80f,lsr#28					;@ S,Z,V&C
	eor z80f,z80f,#(1<<CFlag)|(1<<NFlag)	;@ invert C and set n
	cmp r1,\reg,lsl#\shift+4
	orrcc z80f,z80f,#1<<HFlag
.endm

.macro opCPA
	mov z80f,#(1<<ZFlag)|(1<<NFlag)			;@ set Z & n
	fetch 4
.endm

.macro opCPH reg
	and r0,\reg,#0xFF000000
	opCP r0 0
	fetch 4
.endm

.macro opCPL reg
	opCP \reg 8
	fetch 4
.endm

.macro opCPb
	opCP r0 24
.endm
;@---------------------------------------

.macro opDEC8 reg							;@for A and memory
	and z80f,z80f,#1<<CFlag					;@save carry
	orr z80f,z80f,#1<<NFlag					;@set n
	tst \reg,#0x0f000000
	orreq z80f,z80f,#1<<HFlag
	subs \reg,\reg,#0x01000000
	orrmi z80f,z80f,#1<<SFlag
	orrvs z80f,z80f,#1<<VFlag
	orreq z80f,z80f,#1<<ZFlag
.endm

.macro opDEC8H reg							;@for B, D & H
	and z80f,z80f,#1<<CFlag					;@save carry
	orr z80f,z80f,#1<<NFlag					;@set n
	tst \reg,#0x0f000000
	orreq z80f,z80f,#1<<HFlag
	subs \reg,\reg,#0x01000000
	orrmi z80f,z80f,#1<<SFlag
	orrvs z80f,z80f,#1<<VFlag
	tst \reg,#0xff000000					;@Z
	orreq z80f,z80f,#1<<ZFlag
.endm

.macro opDEC8L reg							;@for C, E & L
	mov \reg,\reg,ror#24
	opDEC8H \reg
	mov \reg,\reg,ror#8
.endm

.macro opDEC8b								;@for memory
	mov r0,r0,lsl#24
	opDEC8 r0
	mov r0,r0,lsr#24
.endm
;@---------------------------------------

.macro opIN
	stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_in]				;@ r0=port - data returned in r0
	ldmfd sp!,{r3,r12}
.endm

.macro opIN_C
	mov r0,z80bc, lsr #16
	opIN
.endm
;@---------------------------------------

.macro opINC8 reg							;@for A and memory
	and z80f,z80f,#1<<CFlag					;@save carry, clear n
	adds \reg,\reg,#0x01000000
	orrmi z80f,z80f,#1<<SFlag
	orrvs z80f,z80f,#1<<VFlag
	orrcs z80f,z80f,#1<<ZFlag				;@cs when going from 0xFF to 0x00
	tst \reg,#0x0f000000
	orreq z80f,z80f,#1<<HFlag
.endm

.macro opINC8H reg							;@for B, D & H
	opINC8 \reg
.endm

.macro opINC8L reg							;@for C, E & L
	mov \reg,\reg,ror#24
	opINC8 \reg
	mov \reg,\reg,ror#8
.endm

.macro opINC8b								;@for memory
	mov r0,r0,lsl#24
	opINC8 r0
	mov r0,r0,lsr#24
.endm
;@---------------------------------------

.macro opOR reg shift
	orr z80a,z80a,\reg,lsl#\shift
	sub r0,opcodes,#0x100
	ldrb z80f,[r0,z80a, lsr #24]
.endm

.macro opORA
	sub r0,opcodes,#0x100
	ldrb z80f,[r0,z80a, lsr #24]
	fetch 4
.endm

.macro opORH reg
	and r0,\reg,#0xFF000000
	opOR r0 0
	fetch 4
.endm

.macro opORL reg
	opOR \reg 8
	fetch 4
.endm

.macro opORb
	opOR r0 24
.endm
;@---------------------------------------

.macro opOUT
	stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_out]			;@ r0=port r1=data
	ldmfd sp!,{r3,r12}
.endm

.macro opOUT_C
	mov r0,z80bc, lsr #16
	opOUT
.endm
;@---------------------------------------

.macro opPOP
.if FAST_Z80SP
	ldrb r0,[z80sp],#1
	ldrb r1,[z80sp],#1
	orr r0,r0,r1, lsl #8
.else
	mov r0,z80sp
	readmem16
	add z80sp,z80sp,#2
.endif
.endm

.macro opPOPreg reg
	opPOP
	mov \reg,r0, lsl #16
	fetch 10
.endm
;@---------------------------------------

.macro stack_check
    @ try to protect against stack overflows, lock into current bank
    ldr r1,[cpucontext,#z80sp_base]
    sub r1,z80sp,r1
    cmp r1,#2
    addlt z80sp,z80sp,#1<<Z80_MEM_SHIFT
.endm

.macro opPUSHareg reg @ reg > r1
.if FAST_Z80SP
.if DRZ80_XMAP
	stack_check
.endif
	mov r1,\reg, lsr #8
	strb r1,[z80sp,#-1]!
	strb \reg,[z80sp,#-1]!
.else
    mov r0,\reg
	sub z80sp,z80sp,#2
	mov r1,z80sp
	writemem16
.endif
.endm

.macro opPUSHreg reg
.if FAST_Z80SP
.if DRZ80_XMAP
	stack_check
.endif
    mov r1,\reg, lsr #24
	strb r1,[z80sp,#-1]!
	mov r1,\reg, lsr #16
	strb r1,[z80sp,#-1]!
.else
	mov r0,\reg,lsr #16
	sub z80sp,z80sp,#2
	mov r1,z80sp
	writemem16
.endif
.endm
;@---------------------------------------

.macro opRESmemHL bit
	mov r0,z80hl, lsr #16
.if DRZ80_XMAP
	bl z80_xmap_read8
	bic r0,r0,#1<<\bit
	mov r1,z80hl, lsr #16
	bl z80_xmap_write8
.else
	stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_read8]			;@ r0 = addr - data returned in r0
	bic r0,r0,#1<<\bit
	mov r1,z80hl, lsr #16
	mov lr,pc
	ldr pc,[cpucontext,#z80_write8]			;@ r0=data r1=addr
	ldmfd sp!,{r3,r12}
.endif
    fetch 15
.endm
;@---------------------------------------

.macro opRESmem bit
.if DRZ80_XMAP
	stmfd sp!,{r0}							;@ save addr as well
	bl z80_xmap_read8
	bic r0,r0,#1<<\bit
	ldmfd sp!,{r1}							;@ restore addr into r1
	bl z80_xmap_write8
.else
	stmfd sp!,{r3,r12}
	stmfd sp!,{r0}							;@ save addr as well
	mov lr,pc
	ldr pc,[cpucontext,#z80_read8]			;@ r0=addr - data returned in r0
	bic r0,r0,#1<<\bit
	ldmfd sp!,{r1}							;@ restore addr into r1
	mov lr,pc
	ldr pc,[cpucontext,#z80_write8]			;@ r0=data r1=addr
	ldmfd sp!,{r3,r12}
.endif
	fetch 23
.endm
;@---------------------------------------

.macro opRL reg1 reg2 shift
	movs \reg1,\reg2,lsl \shift
	tst z80f,#1<<CFlag						;@doesn't affect ARM carry, as long as the imidiate value is < 0x100. Watch out!
	orrne \reg1,\reg1,#0x01000000
;@	and r2,z80f,#1<<CFlag
;@	orr $x,$x,r2,lsl#23
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg1,lsr#24]				;@get PZS
	orrcs z80f,z80f,#1<<CFlag
.endm

.macro opRLA
	opRL z80a, z80a, #1
	fetch 8
.endm

.macro opRLH reg
	and r0,\reg,#0xFF000000					;@mask high to r0
	adds \reg,\reg,r0
	tst z80f,#1<<CFlag						;@doesn't affect ARM carry, as long as the imidiate value is < 0x100. Watch out!
	orrne \reg,\reg,#0x01000000
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg,lsr#24]				;@get PZS
	orrcs z80f,z80f,#1<<CFlag
	fetch 8
.endm

.macro opRLL reg
	opRL r0, \reg, #9
	and \reg,\reg,#0xFF000000				;@mask out high
	orr \reg,\reg,r0,lsr#8
	fetch 8
.endm

.macro opRLb
	opRL r0, r0, #25
	mov r0,r0,lsr#24
.endm
;@---------------------------------------

.macro opRLC reg1 reg2 shift
	movs \reg1,\reg2,lsl#\shift
	orrcs \reg1,\reg1,#0x01000000
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg1,lsr#24]
	orrcs z80f,z80f,#1<<CFlag
.endm

.macro opRLCA
	opRLC z80a, z80a, 1
	fetch 8
.endm

.macro opRLCH reg
	and r0,\reg,#0xFF000000					;@mask high to r0
	adds \reg,\reg,r0
	orrcs \reg,\reg,#0x01000000
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg,lsr#24]
	orrcs z80f,z80f,#1<<CFlag
	fetch 8
.endm

.macro opRLCL reg
	opRLC r0, \reg, 9
	and \reg,\reg,#0xFF000000				;@mask out high
	orr \reg,\reg,r0,lsr#8
	fetch 8
.endm

.macro opRLCb
	opRLC r0, r0, 25
	mov r0,r0,lsr#24
.endm
;@---------------------------------------

.macro opRR reg1 reg2 shift
	movs \reg1,\reg2,lsr#\shift
	tst z80f,#1<<CFlag						;@doesn't affect ARM carry, as long as the imidiate value is < 0x100. Watch out!
	orrne \reg1,\reg1,#0x00000080
;@	and r2,z80_f,#PSR_C
;@	orr \reg1,\reg1,r2,lsl#6
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg1]
	orrcs z80f,z80f,#1<<CFlag
.endm

.macro opRRA
	orr z80a,z80a,z80f,lsr#1				;@get C
	movs z80a,z80a,ror#25
	mov z80a,z80a,lsl#24
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,z80a,lsr#24]
	orrcs z80f,z80f,#1<<CFlag
	fetch 8
.endm

.macro opRRH reg
	orr r0,\reg,z80f,lsr#1					;@get C
	movs r0,r0,ror#25
	and \reg,\reg,#0x00FF0000				;@mask out low
	orr \reg,\reg,r0,lsl#24
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg,lsr#24]
	orrcs z80f,z80f,#1<<CFlag
	fetch 8
.endm

.macro opRRL reg
	and r0,\reg,#0x00FF0000					;@mask out low to r0
	opRR r0 r0 17
	and \reg,\reg,#0xFF000000				;@mask out high
	orr \reg,\reg,r0,lsl#16
	fetch 8
.endm

.macro opRRb
	opRR r0 r0 1
.endm
;@---------------------------------------

.macro opRRC reg1 reg2 shift
	movs \reg1,\reg2,lsr#\shift
	orrcs \reg1,\reg1,#0x00000080
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg1]
	orrcs z80f,z80f,#1<<CFlag
.endm

.macro opRRCA
	opRRC z80a, z80a, 25
	mov z80a,z80a,lsl#24
	fetch 8
.endm

.macro opRRCH reg
	opRRC r0, \reg, 25
	and \reg,\reg,#0x00FF0000				;@mask out low
	orr \reg,\reg,r0,lsl#24
	fetch 8
.endm

.macro opRRCL reg
	and r0,\reg,#0x00FF0000					;@mask low to r0
	opRRC r0, r0, 17
	and \reg,\reg,#0xFF000000				;@mask out high
	orr \reg,\reg,r0,lsl#16
	fetch 8
.endm

.macro opRRCb
	opRRC r0, r0, 1
.endm
;@---------------------------------------

.macro opRST addr
	ldr r0,[cpucontext,#z80pc_base]
	sub r2,z80pc,r0
    opPUSHareg r2
	mov r0,#\addr
	rebasepc
	fetch 11
.endm
;@---------------------------------------

.macro opSBC
	eor z80f,z80f,#1<<CFlag					;@ invert C
	movs z80f,z80f,lsr#2					;@ get C
	subcc r0,r0,#0x100
	eor z80f,r0,z80a,lsr#24					;@ prepare for check of H
	sbcs z80a,z80a,r0,ror#8
	mrs r0,cpsr
	eor z80f,z80f,z80a,lsr#24
	and z80f,z80f,#1<<HFlag					;@ H, correct
	orr z80f,z80f,r0,lsr#28					;@ S,Z,V&C
	eor z80f,z80f,#(1<<CFlag)|(1<<NFlag)	;@ invert C and set n.
.endm

.macro opSBCA
	movs z80f,z80f,lsr#2					;@ get C
	movcc z80a,#0x00000000
	movcs z80a,#0xFF000000
	movcc z80f,#(1<<NFlag)|(1<<ZFlag)
	movcs z80f,#(1<<NFlag)|(1<<SFlag)|(1<<CFlag)|(1<<HFlag)
	fetch 4
.endm

.macro opSBCH reg
	mov r0,\reg,lsr#24
	opSBC
	fetch 4
.endm

.macro opSBCL reg
	mov r0,\reg,lsl#8
	eor z80f,z80f,#1<<CFlag					;@ invert C
	movs z80f,z80f,lsr#2					;@ get C
	sbccc r0,r0,#0xFF000000
	mov r1,z80a,lsl#4						;@ prepare for check of H
	sbcs z80a,z80a,r0
	mrs z80f,cpsr
	mov z80f,z80f,lsr#28					;@ S,Z,V&C
	eor z80f,z80f,#(1<<CFlag)|(1<<NFlag)	;@ invert C and set n.
	cmp r1,r0,lsl#4
	orrcc z80f,z80f,#1<<HFlag				;@ H, correct
	fetch 4
.endm

.macro opSBCb
	opSBC
.endm
;@---------------------------------------

.macro opSBC16 reg
	eor z80f,z80f,#1<<CFlag					;@ invert C
	movs z80f,z80f,lsr#2					;@ get C
	sbc r1,r1,r1							;@ set r1 to -1 or 0.
	orr r0,\reg,r1,lsr#16
	mov r1,z80hl,lsl#4						;@ prepare for check of H
	sbcs z80hl,z80hl,r0
	mrs z80f,cpsr
	mov z80f,z80f,lsr#28					;@ S,Z,V&C
	eor z80f,z80f,#(1<<CFlag)|(1<<NFlag)	;@ invert C and set n.
	cmp r1,r0,lsl#4
	orrcc z80f,z80f,#1<<HFlag				;@ H, correct
	fetch 15
.endm

.macro opSBC16HL
	movs z80f,z80f,lsr#2					;@ get C
	mov z80hl,#0x00000000
	subcs z80hl,z80hl,#0x00010000
	movcc z80f,#(1<<NFlag)|(1<<ZFlag)
	movcs z80f,#(1<<NFlag)|(1<<SFlag)|(1<<CFlag)|(1<<HFlag)
	fetch 15
.endm
;@---------------------------------------

.macro opSETmemHL bit
	mov r0,z80hl, lsr #16
.if DRZ80_XMAP
	bl z80_xmap_read8
	orr r0,r0,#1<<\bit
	mov r1,z80hl, lsr #16
	bl z80_xmap_write8
.else
	stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_read8]			;@ r0 = addr - data returned in r0
	orr r0,r0,#1<<\bit
	mov r1,z80hl, lsr #16
	mov lr,pc
	ldr pc,[cpucontext,#z80_write8]			;@ r0=data r1=addr
	ldmfd sp!,{r3,r12}
.endif
    fetch 15
.endm
;@---------------------------------------

.macro opSETmem bit
.if DRZ80_XMAP
	stmfd sp!,{r0}	;@ save addr as well
	bl z80_xmap_read8
	orr r0,r0,#1<<\bit
	ldmfd sp!,{r1}	;@ restore addr into r1
	bl z80_xmap_write8
.else
	stmfd sp!,{r3,r12}
	stmfd sp!,{r0}	;@ save addr as well
	mov lr,pc
	ldr pc,[cpucontext,#z80_read8]			;@ r0=addr - data returned in r0
	orr r0,r0,#1<<\bit
	ldmfd sp!,{r1}	;@ restore addr into r1
	mov lr,pc
	ldr pc,[cpucontext,#z80_write8]			;@ r0=data r1=addr
	ldmfd sp!,{r3,r12}
.endif
	fetch 23
.endm
;@---------------------------------------

.macro opSLA reg1 reg2 shift
	movs \reg1,\reg2,lsl#\shift
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg1,lsr#24]
	orrcs z80f,z80f,#1<<CFlag
.endm

.macro opSLAA
	opSLA z80a, z80a, 1
	fetch 8
.endm

.macro opSLAH reg
	and r0,\reg,#0xFF000000					;@mask high to r0
	adds \reg,\reg,r0
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg,lsr#24]
	orrcs z80f,z80f,#1<<CFlag
	fetch 8
.endm

.macro opSLAL reg
	opSLA r0, \reg, 9
	and \reg,\reg,#0xFF000000				;@mask out high
	orr \reg,\reg,r0,lsr#8
	fetch 8
.endm

.macro opSLAb
	opSLA r0, r0, 25
	mov r0,r0,lsr#24
.endm
;@---------------------------------------

.macro opSLL reg1 reg2 shift
	movs \reg1,\reg2,lsl#\shift
	orr \reg1,\reg1,#0x01000000
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg1,lsr#24]
	orrcs z80f,z80f,#1<<CFlag
.endm

.macro opSLLA
	opSLL z80a, z80a, 1
	fetch 8
.endm

.macro opSLLH reg
	and r0,\reg,#0xFF000000					;@mask high to r0
	adds \reg,\reg,r0
	orr \reg,\reg,#0x01000000
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg,lsr#24]
	orrcs z80f,z80f,#1<<CFlag
	fetch 8
.endm

.macro opSLLL reg
	opSLL r0, \reg, 9
	and \reg,\reg,#0xFF000000				;@mask out high
	orr \reg,\reg,r0,lsr#8
	fetch 8
.endm

.macro opSLLb
	opSLL r0, r0, 25
	mov r0,r0,lsr#24
.endm
;@---------------------------------------

.macro opSRA reg1 reg2
	movs \reg1,\reg2,asr#25
	and \reg1,\reg1,#0xFF
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg1]
	orrcs z80f,z80f,#1<<CFlag
.endm

.macro opSRAA
	movs r0,z80a,asr#25
	mov z80a,r0,lsl#24
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,z80a,lsr#24]
	orrcs z80f,z80f,#1<<CFlag
	fetch 8
.endm

.macro opSRAH reg
	movs r0,\reg,asr#25
	and \reg,\reg,#0x00FF0000				;@mask out low
	orr \reg,\reg,r0,lsl#24
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg,lsr#24]
	orrcs z80f,z80f,#1<<CFlag
	fetch 8
.endm

.macro opSRAL reg
	mov r0,\reg,lsl#8
	opSRA r0, r0
	and \reg,\reg,#0xFF000000				;@mask out high
	orr \reg,\reg,r0,lsl#16
	fetch 8
.endm

.macro opSRAb
	mov r0,r0,lsl#24
	opSRA r0, r0
.endm
;@---------------------------------------

.macro opSRL reg1 reg2 shift
	movs \reg1,\reg2,lsr#\shift
	sub r1,opcodes,#0x100
	ldrb z80f,[r1,\reg1]
	orrcs z80f,z80f,#1<<CFlag
.endm

.macro opSRLA
	opSRL z80a, z80a, 25
	mov z80a,z80a,lsl#24
	fetch 8
.endm

.macro opSRLH reg
	opSRL r0, \reg, 25
	and \reg,\reg,#0x00FF0000				;@mask out low
	orr \reg,\reg,r0,lsl#24
	fetch 8
.endm

.macro opSRLL reg
	mov r0,\reg,lsl#8
	opSRL r0, r0, 25
	and \reg,\reg,#0xFF000000				;@mask out high
	orr \reg,\reg,r0,lsl#16
	fetch 8
.endm

.macro opSRLb
	opSRL r0, r0, 1
.endm
;@---------------------------------------

.macro opSUB reg shift
	mov r1,z80a,lsl#4						;@ Prepare for check of half carry
	subs z80a,z80a,\reg,lsl#\shift
	mrs z80f,cpsr
	mov z80f,z80f,lsr#28					;@ S,Z,V&C
	eor z80f,z80f,#(1<<CFlag)|(1<<NFlag)	;@ invert C and set n
	cmp r1,\reg,lsl#\shift+4
	orrcc z80f,z80f,#1<<HFlag
.endm

.macro opSUBA
	mov z80a,#0
	mov z80f,#(1<<ZFlag)|(1<<NFlag)			;@ set Z & n
	fetch 4
.endm

.macro opSUBH reg
	and r0,\reg,#0xFF000000
	opSUB r0, 0
	fetch 4
.endm

.macro opSUBL reg
	opSUB \reg, 8
	fetch 4
.endm

.macro opSUBb
	opSUB r0, 24
.endm
;@---------------------------------------

.macro opXOR reg shift
	eor z80a,z80a,\reg,lsl#\shift
	sub r0,opcodes,#0x100
	ldrb z80f,[r0,z80a, lsr #24]
.endm

.macro opXORA
	mov z80a,#0
	mov z80f,#(1<<ZFlag)|(1<<VFlag)
	fetch 4
.endm

.macro opXORH reg
	and r0,\reg,#0xFF000000
	opXOR r0, 0
	fetch 4
.endm

.macro opXORL reg
	opXOR \reg, 8
	fetch 4
.endm

.macro opXORb
	opXOR r0, 24
.endm
;@---------------------------------------


;@ --------------------------- Framework --------------------------
    
.text

DrZ80Run:
	;@ r0 = pointer to cpu context
	;@ r1 = ISTATES to execute  
	;@#########################################   
	stmdb sp!,{r4-r12,lr}					;@ save registers on stack
	mov cpucontext,r0						;@ setup main memory pointer
	mov z80_icount,r1						;@ setup number of Tstates to execute

.if INTERRUPT_MODE == 0
	ldrh r0,[cpucontext,#z80irq] @ 0x4C, irq and IFF bits
.endif
	ldmia cpucontext,{z80pc-z80sp}			;@ load Z80 registers

.if INTERRUPT_MODE == 0
	;@ check ints
	tst r0,#(Z80_NMI<<8)
	blne DoNMI
	tst r0,#0xff
	movne r0,r0,lsr #8
	tstne r0,#Z80_IF1
	blne DoInterrupt
.endif

	ldr opcodes,MAIN_opcodes_POINTER2

	cmp z80_icount,#0     ;@ irq might have used all cycles
	ldrplb r0,[z80pc],#1
	ldrpl pc,[opcodes,r0, lsl #2]


z80_execute_end:
	;@ save registers in CPU context
	stmia cpucontext,{z80pc-z80sp}			;@ save Z80 registers
	mov r0,z80_icount
	ldmia sp!,{r4-r12,pc}					;@ restore registers from stack and return to C code

MAIN_opcodes_POINTER2: .word MAIN_opcodes
.if INTERRUPT_MODE
Interrupt_local: .word Interrupt
.endif

DoInterrupt:
.if INTERRUPT_MODE
	;@ Don't do own int handler, call mames instead

	;@ save everything back into DrZ80 context
	stmia cpucontext,{z80pc-z80sp}			;@ save Z80 registers
	stmfd sp!,{r3,r4,r5,lr}					;@ save rest of regs on stack
	mov lr,pc
	ldr pc,Interrupt_local
	ldmfd sp!,{r3,r4,r5,lr}					;@ load regs from stack
	;@ reload regs from DrZ80 context
	ldmia cpucontext,{z80pc-z80sp}			;@ load Z80 registers
	mov pc,lr ;@ return
.else

	;@ r0 == z80if
	stmfd sp!,{lr}

	tst r0,#4 ;@ check halt
	addne z80pc,z80pc,#1

	ldrb r1,[cpucontext,#z80im]

    ;@ clear halt and int flags
	eor r0,r0,r0
	strb r0,[cpucontext,#z80if]

	;@ now check int mode
	cmp r1,#1
	beq DoInterrupt_mode1
	bgt DoInterrupt_mode2

DoInterrupt_mode0:
	;@ get 3 byte vector
	ldr r2,[cpucontext, #z80irqvector]
	and r1,r2,#0xFF0000
	cmp r1,#0xCD0000  ;@ call
	bne 1f
	;@ ########
	;@ # call
	;@ ########
	;@ save current pc on stack
	ldr r0,[cpucontext,#z80pc_base]
	sub r0,z80pc,r0
.if FAST_Z80SP
	mov r1,r0, lsr #8
	strb r1,[z80sp,#-1]!
	strb r0,[z80sp,#-1]!
.else
	sub z80sp,z80sp,#2
	mov r1,z80sp
	writemem16
	ldr r2,[cpucontext, #z80irqvector]
.endif
	;@ jump to vector
	mov r2,r2,lsl#16
	mov r0,r2,lsr#16
	;@ rebase new pc
	rebasepc

	eatcycles 13
	b DoInterrupt_end

1:
	cmp r1,#0xC30000  ;@ jump
	bne DoInterrupt_mode1    ;@ rst
	;@ #######
	;@ # jump
	;@ #######
	;@ jump to vector
	mov r2,r2,lsl#16
	mov r0,r2,lsr#16
	;@ rebase new pc
	rebasepc

	eatcycles 13
	b DoInterrupt_end

DoInterrupt_mode1:
	ldr r0,[cpucontext,#z80pc_base]
	sub r2,z80pc,r0
    opPUSHareg r2
	mov r0,#0x38
	rebasepc

	eatcycles 13
	b DoInterrupt_end

DoInterrupt_mode2:
	;@ push pc on stack
	ldr r0,[cpucontext,#z80pc_base]
	sub r2,z80pc,r0
    opPUSHareg r2

	;@ get 1 byte vector address
	ldrb r0,[cpucontext, #z80irqvector]
	ldr r1,[cpucontext, #z80i]
	orr r0,r0,r1,lsr#16

	;@ read new pc from vector address
.if UPDATE_CONTEXT
     str z80pc,[cpucontext,#z80pc_pointer]
.endif
.if DRZ80_XMAP
    bl z80_xmap_read16
    rebasepc
.else
	stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_read16]

	;@ rebase new pc
	mov lr,pc
	ldr pc,[cpucontext,#z80_rebasePC] ;@ r0=new pc - external function sets z80pc_base and returns new z80pc in r0
	ldmfd sp!,{r3,r12}
	mov z80pc,r0	
.endif
	eatcycles 17

DoInterrupt_end:
	;@ interupt accepted so callback irq interface
	ldr r0,[cpucontext, #z80irqcallback]
	tst r0,r0
	streqb r0,[cpucontext,#z80irq]       ;@ default handling
	ldmeqfd sp!,{pc}
	stmfd sp!,{r3,r12}
	mov lr,pc
	mov pc,r0    ;@ call callback function
	ldmfd sp!,{r3,r12}
	ldmfd sp!,{pc} ;@ return
.endif

DoNMI:
	stmfd sp!,{lr}

	bic r0,r0,#((Z80_NMI|Z80_HALT|Z80_IF1)<<8)
	strh r0,[cpucontext,#z80irq] @ 0x4C, irq and IFF bits

	;@ push pc on stack
	ldr r0,[cpucontext,#z80pc_base]
	sub r2,z80pc,r0
	opPUSHareg r2

	;@ read new pc from vector address
.if UPDATE_CONTEXT
	str z80pc,[cpucontext,#z80pc_pointer]
.endif
	mov r0,#0x66
.if DRZ80_XMAP
	rebasepc
.else
	stmfd sp!,{r3,r12}
	mov lr,pc
	ldr pc,[cpucontext,#z80_rebasePC] ;@ r0=new pc - external function sets z80pc_base and returns new z80pc in r0
	ldmfd sp!,{r3,r12}
	mov z80pc,r0	
.endif
	ldrh r0,[cpucontext,#z80irq] @ 0x4C, irq and IFF bits
	eatcycles 11
	ldmfd sp!,{pc}


.data
.align 4

DAATable: .hword  (0x00<<8)|(1<<ZFlag)|(1<<VFlag)
         .hword  (0x01<<8)                  
         .hword  (0x02<<8)                  
         .hword  (0x03<<8)               |(1<<VFlag)
         .hword  (0x04<<8)                  
         .hword  (0x05<<8)               |(1<<VFlag)
         .hword  (0x06<<8)               |(1<<VFlag)
         .hword  (0x07<<8)                  
         .hword  (0x08<<8)               
         .hword  (0x09<<8)            |(1<<VFlag)
         .hword  (0x10<<8)         |(1<<HFlag)      
         .hword  (0x11<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x12<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x13<<8)         |(1<<HFlag)      
         .hword  (0x14<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x15<<8)         |(1<<HFlag)      
         .hword  (0x10<<8)                  
         .hword  (0x11<<8)               |(1<<VFlag)
         .hword  (0x12<<8)               |(1<<VFlag)
         .hword  (0x13<<8)                  
         .hword  (0x14<<8)               |(1<<VFlag)
         .hword  (0x15<<8)                  
         .hword  (0x16<<8)                  
         .hword  (0x17<<8)               |(1<<VFlag)
         .hword  (0x18<<8)            |(1<<VFlag)
         .hword  (0x19<<8)               
         .hword  (0x20<<8)      |(1<<HFlag)      
         .hword  (0x21<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x22<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x23<<8)      |(1<<HFlag)      
         .hword  (0x24<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x25<<8)      |(1<<HFlag)      
         .hword  (0x20<<8)               
         .hword  (0x21<<8)            |(1<<VFlag)
         .hword  (0x22<<8)            |(1<<VFlag)
         .hword  (0x23<<8)               
         .hword  (0x24<<8)            |(1<<VFlag)
         .hword  (0x25<<8)               
         .hword  (0x26<<8)               
         .hword  (0x27<<8)            |(1<<VFlag)
         .hword  (0x28<<8)         |(1<<VFlag)
         .hword  (0x29<<8)            
         .hword  (0x30<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x31<<8)      |(1<<HFlag)      
         .hword  (0x32<<8)      |(1<<HFlag)      
         .hword  (0x33<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x34<<8)      |(1<<HFlag)      
         .hword  (0x35<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x30<<8)            |(1<<VFlag)
         .hword  (0x31<<8)               
         .hword  (0x32<<8)               
         .hword  (0x33<<8)            |(1<<VFlag)
         .hword  (0x34<<8)               
         .hword  (0x35<<8)            |(1<<VFlag)
         .hword  (0x36<<8)            |(1<<VFlag)
         .hword  (0x37<<8)               
         .hword  (0x38<<8)            
         .hword  (0x39<<8)         |(1<<VFlag)
         .hword  (0x40<<8)         |(1<<HFlag)      
         .hword  (0x41<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x42<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x43<<8)         |(1<<HFlag)      
         .hword  (0x44<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x45<<8)         |(1<<HFlag)      
         .hword  (0x40<<8)                  
         .hword  (0x41<<8)               |(1<<VFlag)
         .hword  (0x42<<8)               |(1<<VFlag)
         .hword  (0x43<<8)                  
         .hword  (0x44<<8)               |(1<<VFlag)
         .hword  (0x45<<8)                  
         .hword  (0x46<<8)                  
         .hword  (0x47<<8)               |(1<<VFlag)
         .hword  (0x48<<8)            |(1<<VFlag)
         .hword  (0x49<<8)               
         .hword  (0x50<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x51<<8)         |(1<<HFlag)      
         .hword  (0x52<<8)         |(1<<HFlag)      
         .hword  (0x53<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x54<<8)         |(1<<HFlag)      
         .hword  (0x55<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x50<<8)               |(1<<VFlag)
         .hword  (0x51<<8)                  
         .hword  (0x52<<8)                  
         .hword  (0x53<<8)               |(1<<VFlag)
         .hword  (0x54<<8)                  
         .hword  (0x55<<8)               |(1<<VFlag)
         .hword  (0x56<<8)               |(1<<VFlag)
         .hword  (0x57<<8)                  
         .hword  (0x58<<8)               
         .hword  (0x59<<8)            |(1<<VFlag)
         .hword  (0x60<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x61<<8)      |(1<<HFlag)      
         .hword  (0x62<<8)      |(1<<HFlag)      
         .hword  (0x63<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x64<<8)      |(1<<HFlag)      
         .hword  (0x65<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x60<<8)            |(1<<VFlag)
         .hword  (0x61<<8)               
         .hword  (0x62<<8)               
         .hword  (0x63<<8)            |(1<<VFlag)
         .hword  (0x64<<8)               
         .hword  (0x65<<8)            |(1<<VFlag)
         .hword  (0x66<<8)            |(1<<VFlag)
         .hword  (0x67<<8)               
         .hword  (0x68<<8)            
         .hword  (0x69<<8)         |(1<<VFlag)
         .hword  (0x70<<8)      |(1<<HFlag)      
         .hword  (0x71<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x72<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x73<<8)      |(1<<HFlag)      
         .hword  (0x74<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x75<<8)      |(1<<HFlag)      
         .hword  (0x70<<8)               
         .hword  (0x71<<8)            |(1<<VFlag)
         .hword  (0x72<<8)            |(1<<VFlag)
         .hword  (0x73<<8)               
         .hword  (0x74<<8)            |(1<<VFlag)
         .hword  (0x75<<8)               
         .hword  (0x76<<8)               
         .hword  (0x77<<8)            |(1<<VFlag)
         .hword  (0x78<<8)         |(1<<VFlag)
         .hword  (0x79<<8)            
         .hword  (0x80<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x81<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x82<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x83<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x84<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x85<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x80<<8)|(1<<SFlag)               
         .hword  (0x81<<8)|(1<<SFlag)            |(1<<VFlag)
         .hword  (0x82<<8)|(1<<SFlag)            |(1<<VFlag)
         .hword  (0x83<<8)|(1<<SFlag)               
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)
         .hword  (0x85<<8)|(1<<SFlag)               
         .hword  (0x86<<8)|(1<<SFlag)               
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)
         .hword  (0x89<<8)|(1<<SFlag)            
         .hword  (0x90<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x91<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x92<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x93<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x94<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x95<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x90<<8)|(1<<SFlag)            |(1<<VFlag)
         .hword  (0x91<<8)|(1<<SFlag)               
         .hword  (0x92<<8)|(1<<SFlag)               
         .hword  (0x93<<8)|(1<<SFlag)            |(1<<VFlag)
         .hword  (0x94<<8)|(1<<SFlag)               
         .hword  (0x95<<8)|(1<<SFlag)            |(1<<VFlag)
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)
         .hword  (0x97<<8)|(1<<SFlag)               
         .hword  (0x98<<8)|(1<<SFlag)            
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)
         .hword  (0x00<<8)   |(1<<ZFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x01<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x02<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x03<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x04<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x05<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x00<<8)   |(1<<ZFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x01<<8)                     |(1<<CFlag)
         .hword  (0x02<<8)                     |(1<<CFlag)
         .hword  (0x03<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x04<<8)                     |(1<<CFlag)
         .hword  (0x05<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x06<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x07<<8)                     |(1<<CFlag)
         .hword  (0x08<<8)                  |(1<<CFlag)
         .hword  (0x09<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x10<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x11<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x12<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x13<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x14<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x15<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x10<<8)                     |(1<<CFlag)
         .hword  (0x11<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x12<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x13<<8)                     |(1<<CFlag)
         .hword  (0x14<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x15<<8)                     |(1<<CFlag)
         .hword  (0x16<<8)                     |(1<<CFlag)
         .hword  (0x17<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x18<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x19<<8)                  |(1<<CFlag)
         .hword  (0x20<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x21<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x22<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x23<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x24<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x25<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x20<<8)                  |(1<<CFlag)
         .hword  (0x21<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x22<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x23<<8)                  |(1<<CFlag)
         .hword  (0x24<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x25<<8)                  |(1<<CFlag)
         .hword  (0x26<<8)                  |(1<<CFlag)
         .hword  (0x27<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x28<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x29<<8)               |(1<<CFlag)
         .hword  (0x30<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x31<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x32<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x33<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x34<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x35<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x30<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x31<<8)                  |(1<<CFlag)
         .hword  (0x32<<8)                  |(1<<CFlag)
         .hword  (0x33<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x34<<8)                  |(1<<CFlag)
         .hword  (0x35<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x36<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x37<<8)                  |(1<<CFlag)
         .hword  (0x38<<8)               |(1<<CFlag)
         .hword  (0x39<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x40<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x41<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x42<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x43<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x44<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x45<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x40<<8)                     |(1<<CFlag)
         .hword  (0x41<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x42<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x43<<8)                     |(1<<CFlag)
         .hword  (0x44<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x45<<8)                     |(1<<CFlag)
         .hword  (0x46<<8)                     |(1<<CFlag)
         .hword  (0x47<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x48<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x49<<8)                  |(1<<CFlag)
         .hword  (0x50<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x51<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x52<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x53<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x54<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x55<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x50<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x51<<8)                     |(1<<CFlag)
         .hword  (0x52<<8)                     |(1<<CFlag)
         .hword  (0x53<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x54<<8)                     |(1<<CFlag)
         .hword  (0x55<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x56<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x57<<8)                     |(1<<CFlag)
         .hword  (0x58<<8)                  |(1<<CFlag)
         .hword  (0x59<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x60<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x61<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x62<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x63<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x64<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x65<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x60<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x61<<8)                  |(1<<CFlag)
         .hword  (0x62<<8)                  |(1<<CFlag)
         .hword  (0x63<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x64<<8)                  |(1<<CFlag)
         .hword  (0x65<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x66<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x67<<8)                  |(1<<CFlag)
         .hword  (0x68<<8)               |(1<<CFlag)
         .hword  (0x69<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x70<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x71<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x72<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x73<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x74<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x75<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x70<<8)                  |(1<<CFlag)
         .hword  (0x71<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x72<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x73<<8)                  |(1<<CFlag)
         .hword  (0x74<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x75<<8)                  |(1<<CFlag)
         .hword  (0x76<<8)                  |(1<<CFlag)
         .hword  (0x77<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x78<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x79<<8)               |(1<<CFlag)
         .hword  (0x80<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x81<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x82<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x83<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x84<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x85<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x80<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0x81<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x82<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x83<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x85<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0x86<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x89<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0x90<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x91<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x92<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x93<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x94<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x95<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x90<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x91<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0x92<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0x93<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x94<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0x95<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x97<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0x98<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA0<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA1<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xA2<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xA3<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA4<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xA5<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA0<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA1<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xA2<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xA3<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA4<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xA5<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA6<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA7<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xA8<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xA9<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB0<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xB1<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB2<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB3<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xB4<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB5<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xB0<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xB1<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB2<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB3<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xB4<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB5<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xB6<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xB7<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB8<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB9<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xC0<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC1<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xC2<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xC3<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC4<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xC5<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC0<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC1<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0xC2<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0xC3<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC4<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0xC5<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC6<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC7<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0xC8<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xC9<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD0<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xD1<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD2<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD3<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xD4<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD5<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xD0<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0xD1<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD2<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD3<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0xD4<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD5<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0xD6<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0xD7<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD8<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD9<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xE0<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xE1<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE2<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE3<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xE4<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE5<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xE0<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xE1<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE2<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE3<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xE4<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE5<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xE6<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xE7<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE8<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE9<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xF0<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF1<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xF2<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xF3<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF4<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xF5<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF0<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF1<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xF2<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xF3<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF4<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xF5<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF6<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF7<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xF8<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xF9<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x00<<8)   |(1<<ZFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x01<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x02<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x03<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x04<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x05<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x00<<8)   |(1<<ZFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x01<<8)                     |(1<<CFlag)
         .hword  (0x02<<8)                     |(1<<CFlag)
         .hword  (0x03<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x04<<8)                     |(1<<CFlag)
         .hword  (0x05<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x06<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x07<<8)                     |(1<<CFlag)
         .hword  (0x08<<8)                  |(1<<CFlag)
         .hword  (0x09<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x10<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x11<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x12<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x13<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x14<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x15<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x10<<8)                     |(1<<CFlag)
         .hword  (0x11<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x12<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x13<<8)                     |(1<<CFlag)
         .hword  (0x14<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x15<<8)                     |(1<<CFlag)
         .hword  (0x16<<8)                     |(1<<CFlag)
         .hword  (0x17<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x18<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x19<<8)                  |(1<<CFlag)
         .hword  (0x20<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x21<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x22<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x23<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x24<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x25<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x20<<8)                  |(1<<CFlag)
         .hword  (0x21<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x22<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x23<<8)                  |(1<<CFlag)
         .hword  (0x24<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x25<<8)                  |(1<<CFlag)
         .hword  (0x26<<8)                  |(1<<CFlag)
         .hword  (0x27<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x28<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x29<<8)               |(1<<CFlag)
         .hword  (0x30<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x31<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x32<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x33<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x34<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x35<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x30<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x31<<8)                  |(1<<CFlag)
         .hword  (0x32<<8)                  |(1<<CFlag)
         .hword  (0x33<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x34<<8)                  |(1<<CFlag)
         .hword  (0x35<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x36<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x37<<8)                  |(1<<CFlag)
         .hword  (0x38<<8)               |(1<<CFlag)
         .hword  (0x39<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x40<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x41<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x42<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x43<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x44<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x45<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x40<<8)                     |(1<<CFlag)
         .hword  (0x41<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x42<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x43<<8)                     |(1<<CFlag)
         .hword  (0x44<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x45<<8)                     |(1<<CFlag)
         .hword  (0x46<<8)                     |(1<<CFlag)
         .hword  (0x47<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x48<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x49<<8)                  |(1<<CFlag)
         .hword  (0x50<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x51<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x52<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x53<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x54<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x55<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x50<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x51<<8)                     |(1<<CFlag)
         .hword  (0x52<<8)                     |(1<<CFlag)
         .hword  (0x53<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x54<<8)                     |(1<<CFlag)
         .hword  (0x55<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x56<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x57<<8)                     |(1<<CFlag)
         .hword  (0x58<<8)                  |(1<<CFlag)
         .hword  (0x59<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x60<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x61<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x62<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x63<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x64<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x65<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x06<<8)               |(1<<VFlag)
         .hword  (0x07<<8)                  
         .hword  (0x08<<8)               
         .hword  (0x09<<8)            |(1<<VFlag)
         .hword  (0x0A<<8)            |(1<<VFlag)
         .hword  (0x0B<<8)               
         .hword  (0x0C<<8)            |(1<<VFlag)
         .hword  (0x0D<<8)               
         .hword  (0x0E<<8)               
         .hword  (0x0F<<8)            |(1<<VFlag)
         .hword  (0x10<<8)         |(1<<HFlag)      
         .hword  (0x11<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x12<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x13<<8)         |(1<<HFlag)      
         .hword  (0x14<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x15<<8)         |(1<<HFlag)      
         .hword  (0x16<<8)                  
         .hword  (0x17<<8)               |(1<<VFlag)
         .hword  (0x18<<8)            |(1<<VFlag)
         .hword  (0x19<<8)               
         .hword  (0x1A<<8)               
         .hword  (0x1B<<8)            |(1<<VFlag)
         .hword  (0x1C<<8)               
         .hword  (0x1D<<8)            |(1<<VFlag)
         .hword  (0x1E<<8)            |(1<<VFlag)
         .hword  (0x1F<<8)               
         .hword  (0x20<<8)      |(1<<HFlag)      
         .hword  (0x21<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x22<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x23<<8)      |(1<<HFlag)      
         .hword  (0x24<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x25<<8)      |(1<<HFlag)      
         .hword  (0x26<<8)               
         .hword  (0x27<<8)            |(1<<VFlag)
         .hword  (0x28<<8)         |(1<<VFlag)
         .hword  (0x29<<8)            
         .hword  (0x2A<<8)            
         .hword  (0x2B<<8)         |(1<<VFlag)
         .hword  (0x2C<<8)            
         .hword  (0x2D<<8)         |(1<<VFlag)
         .hword  (0x2E<<8)         |(1<<VFlag)
         .hword  (0x2F<<8)            
         .hword  (0x30<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x31<<8)      |(1<<HFlag)      
         .hword  (0x32<<8)      |(1<<HFlag)      
         .hword  (0x33<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x34<<8)      |(1<<HFlag)      
         .hword  (0x35<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x36<<8)            |(1<<VFlag)
         .hword  (0x37<<8)               
         .hword  (0x38<<8)            
         .hword  (0x39<<8)         |(1<<VFlag)
         .hword  (0x3A<<8)         |(1<<VFlag)
         .hword  (0x3B<<8)            
         .hword  (0x3C<<8)         |(1<<VFlag)
         .hword  (0x3D<<8)            
         .hword  (0x3E<<8)            
         .hword  (0x3F<<8)         |(1<<VFlag)
         .hword  (0x40<<8)         |(1<<HFlag)      
         .hword  (0x41<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x42<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x43<<8)         |(1<<HFlag)      
         .hword  (0x44<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x45<<8)         |(1<<HFlag)      
         .hword  (0x46<<8)                  
         .hword  (0x47<<8)               |(1<<VFlag)
         .hword  (0x48<<8)            |(1<<VFlag)
         .hword  (0x49<<8)               
         .hword  (0x4A<<8)               
         .hword  (0x4B<<8)            |(1<<VFlag)
         .hword  (0x4C<<8)               
         .hword  (0x4D<<8)            |(1<<VFlag)
         .hword  (0x4E<<8)            |(1<<VFlag)
         .hword  (0x4F<<8)               
         .hword  (0x50<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x51<<8)         |(1<<HFlag)      
         .hword  (0x52<<8)         |(1<<HFlag)      
         .hword  (0x53<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x54<<8)         |(1<<HFlag)      
         .hword  (0x55<<8)         |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x56<<8)               |(1<<VFlag)
         .hword  (0x57<<8)                  
         .hword  (0x58<<8)               
         .hword  (0x59<<8)            |(1<<VFlag)
         .hword  (0x5A<<8)            |(1<<VFlag)
         .hword  (0x5B<<8)               
         .hword  (0x5C<<8)            |(1<<VFlag)
         .hword  (0x5D<<8)               
         .hword  (0x5E<<8)               
         .hword  (0x5F<<8)            |(1<<VFlag)
         .hword  (0x60<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x61<<8)      |(1<<HFlag)      
         .hword  (0x62<<8)      |(1<<HFlag)      
         .hword  (0x63<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x64<<8)      |(1<<HFlag)      
         .hword  (0x65<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x66<<8)            |(1<<VFlag)
         .hword  (0x67<<8)               
         .hword  (0x68<<8)            
         .hword  (0x69<<8)         |(1<<VFlag)
         .hword  (0x6A<<8)         |(1<<VFlag)
         .hword  (0x6B<<8)            
         .hword  (0x6C<<8)         |(1<<VFlag)
         .hword  (0x6D<<8)            
         .hword  (0x6E<<8)            
         .hword  (0x6F<<8)         |(1<<VFlag)
         .hword  (0x70<<8)      |(1<<HFlag)      
         .hword  (0x71<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x72<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x73<<8)      |(1<<HFlag)      
         .hword  (0x74<<8)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x75<<8)      |(1<<HFlag)      
         .hword  (0x76<<8)               
         .hword  (0x77<<8)            |(1<<VFlag)
         .hword  (0x78<<8)         |(1<<VFlag)
         .hword  (0x79<<8)            
         .hword  (0x7A<<8)            
         .hword  (0x7B<<8)         |(1<<VFlag)
         .hword  (0x7C<<8)            
         .hword  (0x7D<<8)         |(1<<VFlag)
         .hword  (0x7E<<8)         |(1<<VFlag)
         .hword  (0x7F<<8)            
         .hword  (0x80<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x81<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x82<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x83<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x84<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x85<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x86<<8)|(1<<SFlag)               
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)
         .hword  (0x89<<8)|(1<<SFlag)            
         .hword  (0x8A<<8)|(1<<SFlag)            
         .hword  (0x8B<<8)|(1<<SFlag)         |(1<<VFlag)
         .hword  (0x8C<<8)|(1<<SFlag)            
         .hword  (0x8D<<8)|(1<<SFlag)         |(1<<VFlag)
         .hword  (0x8E<<8)|(1<<SFlag)         |(1<<VFlag)
         .hword  (0x8F<<8)|(1<<SFlag)            
         .hword  (0x90<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x91<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x92<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x93<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x94<<8)|(1<<SFlag)      |(1<<HFlag)      
         .hword  (0x95<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)
         .hword  (0x97<<8)|(1<<SFlag)               
         .hword  (0x98<<8)|(1<<SFlag)            
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)
         .hword  (0x9A<<8)|(1<<SFlag)         |(1<<VFlag)
         .hword  (0x9B<<8)|(1<<SFlag)            
         .hword  (0x9C<<8)|(1<<SFlag)         |(1<<VFlag)
         .hword  (0x9D<<8)|(1<<SFlag)            
         .hword  (0x9E<<8)|(1<<SFlag)            
         .hword  (0x9F<<8)|(1<<SFlag)         |(1<<VFlag)
         .hword  (0x00<<8)   |(1<<ZFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x01<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x02<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x03<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x04<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x05<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x06<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x07<<8)                     |(1<<CFlag)
         .hword  (0x08<<8)                  |(1<<CFlag)
         .hword  (0x09<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x0A<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x0B<<8)                  |(1<<CFlag)
         .hword  (0x0C<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x0D<<8)                  |(1<<CFlag)
         .hword  (0x0E<<8)                  |(1<<CFlag)
         .hword  (0x0F<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x10<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x11<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x12<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x13<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x14<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x15<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x16<<8)                     |(1<<CFlag)
         .hword  (0x17<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x18<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x19<<8)                  |(1<<CFlag)
         .hword  (0x1A<<8)                  |(1<<CFlag)
         .hword  (0x1B<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x1C<<8)                  |(1<<CFlag)
         .hword  (0x1D<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x1E<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x1F<<8)                  |(1<<CFlag)
         .hword  (0x20<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x21<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x22<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x23<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x24<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x25<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x26<<8)                  |(1<<CFlag)
         .hword  (0x27<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x28<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x29<<8)               |(1<<CFlag)
         .hword  (0x2A<<8)               |(1<<CFlag)
         .hword  (0x2B<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x2C<<8)               |(1<<CFlag)
         .hword  (0x2D<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x2E<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x2F<<8)               |(1<<CFlag)
         .hword  (0x30<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x31<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x32<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x33<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x34<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x35<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x36<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x37<<8)                  |(1<<CFlag)
         .hword  (0x38<<8)               |(1<<CFlag)
         .hword  (0x39<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x3A<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x3B<<8)               |(1<<CFlag)
         .hword  (0x3C<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x3D<<8)               |(1<<CFlag)
         .hword  (0x3E<<8)               |(1<<CFlag)
         .hword  (0x3F<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x40<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x41<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x42<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x43<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x44<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x45<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x46<<8)                     |(1<<CFlag)
         .hword  (0x47<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x48<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x49<<8)                  |(1<<CFlag)
         .hword  (0x4A<<8)                  |(1<<CFlag)
         .hword  (0x4B<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x4C<<8)                  |(1<<CFlag)
         .hword  (0x4D<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x4E<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x4F<<8)                  |(1<<CFlag)
         .hword  (0x50<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x51<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x52<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x53<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x54<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x55<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x56<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x57<<8)                     |(1<<CFlag)
         .hword  (0x58<<8)                  |(1<<CFlag)
         .hword  (0x59<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x5A<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x5B<<8)                  |(1<<CFlag)
         .hword  (0x5C<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x5D<<8)                  |(1<<CFlag)
         .hword  (0x5E<<8)                  |(1<<CFlag)
         .hword  (0x5F<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x60<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x61<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x62<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x63<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x64<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x65<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x66<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x67<<8)                  |(1<<CFlag)
         .hword  (0x68<<8)               |(1<<CFlag)
         .hword  (0x69<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x6A<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x6B<<8)               |(1<<CFlag)
         .hword  (0x6C<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x6D<<8)               |(1<<CFlag)
         .hword  (0x6E<<8)               |(1<<CFlag)
         .hword  (0x6F<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x70<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x71<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x72<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x73<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x74<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x75<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x76<<8)                  |(1<<CFlag)
         .hword  (0x77<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x78<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x79<<8)               |(1<<CFlag)
         .hword  (0x7A<<8)               |(1<<CFlag)
         .hword  (0x7B<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x7C<<8)               |(1<<CFlag)
         .hword  (0x7D<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x7E<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x7F<<8)               |(1<<CFlag)
         .hword  (0x80<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x81<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x82<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x83<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x84<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x85<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x86<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x89<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0x8A<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0x8B<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x8C<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0x8D<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x8E<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x8F<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0x90<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x91<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x92<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x93<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x94<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x95<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x97<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0x98<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x9A<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x9B<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0x9C<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x9D<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0x9E<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0x9F<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA0<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA1<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xA2<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xA3<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA4<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xA5<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA6<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xA7<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xA8<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xA9<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xAA<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xAB<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xAC<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xAD<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xAE<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xAF<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB0<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xB1<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB2<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB3<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xB4<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB5<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xB6<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xB7<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB8<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xB9<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xBA<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xBB<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xBC<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xBD<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xBE<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xBF<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xC0<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC1<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xC2<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xC3<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC4<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xC5<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC6<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xC7<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0xC8<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xC9<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xCA<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xCB<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xCC<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xCD<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xCE<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xCF<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD0<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xD1<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD2<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD3<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xD4<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD5<<8)|(1<<SFlag)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xD6<<8)|(1<<SFlag)                  |(1<<CFlag)
         .hword  (0xD7<<8)|(1<<SFlag)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD8<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xD9<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xDA<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xDB<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xDC<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xDD<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xDE<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xDF<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xE0<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xE1<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE2<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE3<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xE4<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE5<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xE6<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xE7<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE8<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xE9<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xEA<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xEB<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xEC<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xED<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xEE<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xEF<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xF0<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF1<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xF2<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xF3<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF4<<8)|(1<<SFlag)   |(1<<HFlag)         |(1<<CFlag)
         .hword  (0xF5<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF6<<8)|(1<<SFlag)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xF7<<8)|(1<<SFlag)               |(1<<CFlag)
         .hword  (0xF8<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xF9<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xFA<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xFB<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xFC<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0xFD<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xFE<<8)|(1<<SFlag)            |(1<<CFlag)
         .hword  (0xFF<<8)|(1<<SFlag)      |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x00<<8)   |(1<<ZFlag)   |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x01<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x02<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x03<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x04<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x05<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x06<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x07<<8)                     |(1<<CFlag)
         .hword  (0x08<<8)                  |(1<<CFlag)
         .hword  (0x09<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x0A<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x0B<<8)                  |(1<<CFlag)
         .hword  (0x0C<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x0D<<8)                  |(1<<CFlag)
         .hword  (0x0E<<8)                  |(1<<CFlag)
         .hword  (0x0F<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x10<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x11<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x12<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x13<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x14<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x15<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x16<<8)                     |(1<<CFlag)
         .hword  (0x17<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x18<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x19<<8)                  |(1<<CFlag)
         .hword  (0x1A<<8)                  |(1<<CFlag)
         .hword  (0x1B<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x1C<<8)                  |(1<<CFlag)
         .hword  (0x1D<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x1E<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x1F<<8)                  |(1<<CFlag)
         .hword  (0x20<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x21<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x22<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x23<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x24<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x25<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x26<<8)                  |(1<<CFlag)
         .hword  (0x27<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x28<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x29<<8)               |(1<<CFlag)
         .hword  (0x2A<<8)               |(1<<CFlag)
         .hword  (0x2B<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x2C<<8)               |(1<<CFlag)
         .hword  (0x2D<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x2E<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x2F<<8)               |(1<<CFlag)
         .hword  (0x30<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x31<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x32<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x33<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x34<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x35<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x36<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x37<<8)                  |(1<<CFlag)
         .hword  (0x38<<8)               |(1<<CFlag)
         .hword  (0x39<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x3A<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x3B<<8)               |(1<<CFlag)
         .hword  (0x3C<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x3D<<8)               |(1<<CFlag)
         .hword  (0x3E<<8)               |(1<<CFlag)
         .hword  (0x3F<<8)         |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x40<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x41<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x42<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x43<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x44<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x45<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x46<<8)                     |(1<<CFlag)
         .hword  (0x47<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x48<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x49<<8)                  |(1<<CFlag)
         .hword  (0x4A<<8)                  |(1<<CFlag)
         .hword  (0x4B<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x4C<<8)                  |(1<<CFlag)
         .hword  (0x4D<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x4E<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x4F<<8)                  |(1<<CFlag)
         .hword  (0x50<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x51<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x52<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x53<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x54<<8)         |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x55<<8)         |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x56<<8)               |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x57<<8)                     |(1<<CFlag)
         .hword  (0x58<<8)                  |(1<<CFlag)
         .hword  (0x59<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x5A<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x5B<<8)                  |(1<<CFlag)
         .hword  (0x5C<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x5D<<8)                  |(1<<CFlag)
         .hword  (0x5E<<8)                  |(1<<CFlag)
         .hword  (0x5F<<8)            |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x60<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x61<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x62<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x63<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x64<<8)      |(1<<HFlag)         |(1<<CFlag)
         .hword  (0x65<<8)      |(1<<HFlag)   |(1<<VFlag)   |(1<<CFlag)
         .hword  (0x00<<8)   |(1<<ZFlag)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x01<<8)                  |(1<<NFlag)   
         .hword  (0x02<<8)                  |(1<<NFlag)   
         .hword  (0x03<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x04<<8)                  |(1<<NFlag)   
         .hword  (0x05<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x06<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x07<<8)                  |(1<<NFlag)   
         .hword  (0x08<<8)               |(1<<NFlag)   
         .hword  (0x09<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x04<<8)                  |(1<<NFlag)   
         .hword  (0x05<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x06<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x07<<8)                  |(1<<NFlag)   
         .hword  (0x08<<8)               |(1<<NFlag)   
         .hword  (0x09<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x10<<8)                  |(1<<NFlag)   
         .hword  (0x11<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x12<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x13<<8)                  |(1<<NFlag)   
         .hword  (0x14<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x15<<8)                  |(1<<NFlag)   
         .hword  (0x16<<8)                  |(1<<NFlag)   
         .hword  (0x17<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x18<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x19<<8)               |(1<<NFlag)   
         .hword  (0x14<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x15<<8)                  |(1<<NFlag)   
         .hword  (0x16<<8)                  |(1<<NFlag)   
         .hword  (0x17<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x18<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x19<<8)               |(1<<NFlag)   
         .hword  (0x20<<8)               |(1<<NFlag)   
         .hword  (0x21<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x22<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x23<<8)               |(1<<NFlag)   
         .hword  (0x24<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x25<<8)               |(1<<NFlag)   
         .hword  (0x26<<8)               |(1<<NFlag)   
         .hword  (0x27<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x28<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x29<<8)            |(1<<NFlag)   
         .hword  (0x24<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x25<<8)               |(1<<NFlag)   
         .hword  (0x26<<8)               |(1<<NFlag)   
         .hword  (0x27<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x28<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x29<<8)            |(1<<NFlag)   
         .hword  (0x30<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x31<<8)               |(1<<NFlag)   
         .hword  (0x32<<8)               |(1<<NFlag)   
         .hword  (0x33<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x34<<8)               |(1<<NFlag)   
         .hword  (0x35<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x36<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x37<<8)               |(1<<NFlag)   
         .hword  (0x38<<8)            |(1<<NFlag)   
         .hword  (0x39<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x34<<8)               |(1<<NFlag)   
         .hword  (0x35<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x36<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x37<<8)               |(1<<NFlag)   
         .hword  (0x38<<8)            |(1<<NFlag)   
         .hword  (0x39<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x40<<8)                  |(1<<NFlag)   
         .hword  (0x41<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x42<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x43<<8)                  |(1<<NFlag)   
         .hword  (0x44<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x45<<8)                  |(1<<NFlag)   
         .hword  (0x46<<8)                  |(1<<NFlag)   
         .hword  (0x47<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x48<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x49<<8)               |(1<<NFlag)   
         .hword  (0x44<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x45<<8)                  |(1<<NFlag)   
         .hword  (0x46<<8)                  |(1<<NFlag)   
         .hword  (0x47<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x48<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x49<<8)               |(1<<NFlag)   
         .hword  (0x50<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x51<<8)                  |(1<<NFlag)   
         .hword  (0x52<<8)                  |(1<<NFlag)   
         .hword  (0x53<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x54<<8)                  |(1<<NFlag)   
         .hword  (0x55<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x56<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x57<<8)                  |(1<<NFlag)   
         .hword  (0x58<<8)               |(1<<NFlag)   
         .hword  (0x59<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x54<<8)                  |(1<<NFlag)   
         .hword  (0x55<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x56<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x57<<8)                  |(1<<NFlag)   
         .hword  (0x58<<8)               |(1<<NFlag)   
         .hword  (0x59<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x60<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x61<<8)               |(1<<NFlag)   
         .hword  (0x62<<8)               |(1<<NFlag)   
         .hword  (0x63<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x64<<8)               |(1<<NFlag)   
         .hword  (0x65<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x66<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x67<<8)               |(1<<NFlag)   
         .hword  (0x68<<8)            |(1<<NFlag)   
         .hword  (0x69<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x64<<8)               |(1<<NFlag)   
         .hword  (0x65<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x66<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x67<<8)               |(1<<NFlag)   
         .hword  (0x68<<8)            |(1<<NFlag)   
         .hword  (0x69<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x70<<8)               |(1<<NFlag)   
         .hword  (0x71<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x72<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x73<<8)               |(1<<NFlag)   
         .hword  (0x74<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x75<<8)               |(1<<NFlag)   
         .hword  (0x76<<8)               |(1<<NFlag)   
         .hword  (0x77<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x78<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x79<<8)            |(1<<NFlag)   
         .hword  (0x74<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x75<<8)               |(1<<NFlag)   
         .hword  (0x76<<8)               |(1<<NFlag)   
         .hword  (0x77<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x78<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x79<<8)            |(1<<NFlag)   
         .hword  (0x80<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x81<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x82<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x83<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x85<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x86<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x89<<8)|(1<<SFlag)            |(1<<NFlag)   
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x85<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x86<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x89<<8)|(1<<SFlag)            |(1<<NFlag)   
         .hword  (0x90<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x91<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x92<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x93<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x94<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x95<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x97<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x98<<8)|(1<<SFlag)            |(1<<NFlag)   
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x34<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x35<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x36<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x37<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x38<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x39<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x40<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x41<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x42<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x43<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x44<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x45<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x46<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x47<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x48<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x49<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x44<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x45<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x46<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x47<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x48<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x49<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x50<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x51<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x52<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x53<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x54<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x55<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x56<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x57<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x58<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x59<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x54<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x55<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x56<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x57<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x58<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x59<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x60<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x61<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x62<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x63<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x64<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x65<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x66<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x67<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x68<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x69<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x64<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x65<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x66<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x67<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x68<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x69<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x70<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x71<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x72<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x73<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x74<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x75<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x76<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x77<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x78<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x79<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x74<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x75<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x76<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x77<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x78<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x79<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x80<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x81<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x82<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x83<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x85<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x86<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x89<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x85<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x86<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x89<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x90<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x91<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x92<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x93<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x94<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x95<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x97<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x98<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x94<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x95<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x97<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x98<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA0<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA1<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA2<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA3<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA4<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA5<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA6<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA7<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA8<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA9<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA4<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA5<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA6<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA7<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA8<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA9<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB0<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB1<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB2<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB3<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB4<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB5<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB6<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB7<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB8<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB9<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB4<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB5<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB6<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB7<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB8<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB9<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC0<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC1<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC2<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC3<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC4<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC5<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC6<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC7<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC8<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC9<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC4<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC5<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC6<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC7<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC8<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC9<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD0<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD1<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD2<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD3<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD4<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD5<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD6<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD7<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD8<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD9<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD4<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD5<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD6<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD7<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD8<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD9<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE0<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE1<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE2<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE3<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE4<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE5<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE6<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE7<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE8<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE9<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE4<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE5<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE6<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE7<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE8<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE9<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF0<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF1<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF2<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF3<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF4<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF5<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF6<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF7<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF8<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF9<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF4<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF5<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF6<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF7<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF8<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF9<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x00<<8)   |(1<<ZFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x01<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x02<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x03<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x04<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x05<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x06<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x07<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x08<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x09<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x04<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x05<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x06<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x07<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x08<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x09<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x10<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x11<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x12<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x13<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x14<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x15<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x16<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x17<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x18<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x19<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x14<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x15<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x16<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x17<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x18<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x19<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x20<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x21<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x22<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x23<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x24<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x25<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x26<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x27<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x28<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x29<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x24<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x25<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x26<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x27<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x28<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x29<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x30<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x31<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x32<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x33<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x34<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x35<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x36<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x37<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x38<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x39<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x34<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x35<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x36<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x37<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x38<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x39<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x40<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x41<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x42<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x43<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x44<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x45<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x46<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x47<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x48<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x49<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x44<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x45<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x46<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x47<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x48<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x49<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x50<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x51<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x52<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x53<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x54<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x55<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x56<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x57<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x58<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x59<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x54<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x55<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x56<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x57<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x58<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x59<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x60<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x61<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x62<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x63<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x64<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x65<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x66<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x67<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x68<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x69<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x64<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x65<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x66<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x67<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x68<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x69<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x70<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x71<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x72<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x73<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x74<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x75<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x76<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x77<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x78<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x79<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x74<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x75<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x76<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x77<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x78<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x79<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x80<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x81<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x82<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x83<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x85<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x86<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x89<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x85<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x86<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x89<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x90<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x91<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x92<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x93<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x94<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x95<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x97<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x98<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x94<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x95<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x97<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x98<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xFA<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0xFB<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0xFC<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0xFD<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0xFE<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0xFF<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x00<<8)   |(1<<ZFlag)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x01<<8)                  |(1<<NFlag)   
         .hword  (0x02<<8)                  |(1<<NFlag)   
         .hword  (0x03<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x04<<8)                  |(1<<NFlag)   
         .hword  (0x05<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x06<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x07<<8)                  |(1<<NFlag)   
         .hword  (0x08<<8)               |(1<<NFlag)   
         .hword  (0x09<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x0A<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x0B<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x0C<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x0D<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x0E<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x0F<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x10<<8)                  |(1<<NFlag)   
         .hword  (0x11<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x12<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x13<<8)                  |(1<<NFlag)   
         .hword  (0x14<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x15<<8)                  |(1<<NFlag)   
         .hword  (0x16<<8)                  |(1<<NFlag)   
         .hword  (0x17<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x18<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x19<<8)               |(1<<NFlag)   
         .hword  (0x1A<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x1B<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x1C<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x1D<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x1E<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x1F<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x20<<8)               |(1<<NFlag)   
         .hword  (0x21<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x22<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x23<<8)               |(1<<NFlag)   
         .hword  (0x24<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x25<<8)               |(1<<NFlag)   
         .hword  (0x26<<8)               |(1<<NFlag)   
         .hword  (0x27<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x28<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x29<<8)            |(1<<NFlag)   
         .hword  (0x2A<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x2B<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x2C<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x2D<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x2E<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x2F<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x30<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x31<<8)               |(1<<NFlag)   
         .hword  (0x32<<8)               |(1<<NFlag)   
         .hword  (0x33<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x34<<8)               |(1<<NFlag)   
         .hword  (0x35<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x36<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x37<<8)               |(1<<NFlag)   
         .hword  (0x38<<8)            |(1<<NFlag)   
         .hword  (0x39<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x3A<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x3B<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x3C<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x3D<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x3E<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x3F<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x40<<8)                  |(1<<NFlag)   
         .hword  (0x41<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x42<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x43<<8)                  |(1<<NFlag)   
         .hword  (0x44<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x45<<8)                  |(1<<NFlag)   
         .hword  (0x46<<8)                  |(1<<NFlag)   
         .hword  (0x47<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x48<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x49<<8)               |(1<<NFlag)   
         .hword  (0x4A<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x4B<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x4C<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x4D<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x4E<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x4F<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x50<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x51<<8)                  |(1<<NFlag)   
         .hword  (0x52<<8)                  |(1<<NFlag)   
         .hword  (0x53<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x54<<8)                  |(1<<NFlag)   
         .hword  (0x55<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x56<<8)               |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x57<<8)                  |(1<<NFlag)   
         .hword  (0x58<<8)               |(1<<NFlag)   
         .hword  (0x59<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x5A<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x5B<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x5C<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x5D<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x5E<<8)         |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x5F<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x60<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x61<<8)               |(1<<NFlag)   
         .hword  (0x62<<8)               |(1<<NFlag)   
         .hword  (0x63<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x64<<8)               |(1<<NFlag)   
         .hword  (0x65<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x66<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x67<<8)               |(1<<NFlag)   
         .hword  (0x68<<8)            |(1<<NFlag)   
         .hword  (0x69<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x6A<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x6B<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x6C<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x6D<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x6E<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x6F<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x70<<8)               |(1<<NFlag)   
         .hword  (0x71<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x72<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x73<<8)               |(1<<NFlag)   
         .hword  (0x74<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x75<<8)               |(1<<NFlag)   
         .hword  (0x76<<8)               |(1<<NFlag)   
         .hword  (0x77<<8)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x78<<8)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x79<<8)            |(1<<NFlag)   
         .hword  (0x7A<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x7B<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x7C<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x7D<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x7E<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x7F<<8)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x80<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x81<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x82<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x83<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x85<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x86<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x89<<8)|(1<<SFlag)            |(1<<NFlag)   
         .hword  (0x8A<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x8B<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x8C<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x8D<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x8E<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)   
         .hword  (0x8F<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)   
         .hword  (0x90<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x91<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x92<<8)|(1<<SFlag)               |(1<<NFlag)   
         .hword  (0x93<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)   
         .hword  (0x34<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x35<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x36<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x37<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x38<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x39<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x3A<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x3B<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x3C<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x3D<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x3E<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x3F<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x40<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x41<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x42<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x43<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x44<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x45<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x46<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x47<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x48<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x49<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x4A<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x4B<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x4C<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x4D<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x4E<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x4F<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x50<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x51<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x52<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x53<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x54<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x55<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x56<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x57<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x58<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x59<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x5A<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x5B<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x5C<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x5D<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x5E<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x5F<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x60<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x61<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x62<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x63<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x64<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x65<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x66<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x67<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x68<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x69<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x6A<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x6B<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x6C<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x6D<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x6E<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x6F<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x70<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x71<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x72<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x73<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x74<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x75<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x76<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x77<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x78<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x79<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x7A<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x7B<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x7C<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x7D<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x7E<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x7F<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x80<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x81<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x82<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x83<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x85<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x86<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x89<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x8A<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x8B<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x8C<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x8D<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x8E<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x8F<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x90<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x91<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x92<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x93<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x94<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x95<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x97<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x98<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x9A<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x9B<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x9C<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x9D<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x9E<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x9F<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA0<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA1<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA2<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA3<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA4<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA5<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA6<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xA7<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA8<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xA9<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xAA<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xAB<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xAC<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xAD<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xAE<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xAF<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB0<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB1<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB2<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB3<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB4<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB5<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB6<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xB7<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB8<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xB9<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xBA<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xBB<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xBC<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xBD<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xBE<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xBF<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC0<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC1<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC2<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC3<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC4<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC5<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC6<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xC7<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC8<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xC9<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xCA<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xCB<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xCC<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xCD<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xCE<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xCF<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD0<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD1<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD2<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD3<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD4<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD5<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD6<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0xD7<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD8<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xD9<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xDA<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xDB<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xDC<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xDD<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xDE<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xDF<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE0<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE1<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE2<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE3<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE4<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE5<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE6<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xE7<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE8<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xE9<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xEA<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xEB<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xEC<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xED<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xEE<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xEF<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF0<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF1<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF2<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF3<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF4<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF5<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF6<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xF7<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF8<<8)|(1<<SFlag)         |(1<<NFlag)|(1<<CFlag)
         .hword  (0xF9<<8)|(1<<SFlag)      |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xFA<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xFB<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xFC<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0xFD<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xFE<<8)|(1<<SFlag)   |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0xFF<<8)|(1<<SFlag)   |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x00<<8)   |(1<<ZFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x01<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x02<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x03<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x04<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x05<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x06<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x07<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x08<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x09<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x0A<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x0B<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x0C<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x0D<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x0E<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x0F<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x10<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x11<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x12<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x13<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x14<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x15<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x16<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x17<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x18<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x19<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x1A<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x1B<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x1C<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x1D<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x1E<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x1F<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x20<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x21<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x22<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x23<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x24<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x25<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x26<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x27<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x28<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x29<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x2A<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x2B<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x2C<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x2D<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x2E<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x2F<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x30<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x31<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x32<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x33<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x34<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x35<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x36<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x37<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x38<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x39<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x3A<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x3B<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x3C<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x3D<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x3E<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x3F<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x40<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x41<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x42<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x43<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x44<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x45<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x46<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x47<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x48<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x49<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x4A<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x4B<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x4C<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x4D<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x4E<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x4F<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x50<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x51<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x52<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x53<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x54<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x55<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x56<<8)               |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x57<<8)                  |(1<<NFlag)|(1<<CFlag)
         .hword  (0x58<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x59<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x5A<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x5B<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x5C<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x5D<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x5E<<8)         |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x5F<<8)         |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x60<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x61<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x62<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x63<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x64<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x65<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x66<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x67<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x68<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x69<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x6A<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x6B<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x6C<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x6D<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x6E<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x6F<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x70<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x71<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x72<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x73<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x74<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x75<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x76<<8)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x77<<8)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x78<<8)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x79<<8)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x7A<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x7B<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x7C<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x7D<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x7E<<8)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x7F<<8)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x80<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x81<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x82<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x83<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x84<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x85<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x86<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x87<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x88<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x89<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x8A<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x8B<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x8C<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x8D<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x8E<<8)|(1<<SFlag)      |(1<<HFlag)|(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x8F<<8)|(1<<SFlag)      |(1<<HFlag)   |(1<<NFlag)|(1<<CFlag)
         .hword  (0x90<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x91<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x92<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x93<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x94<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x95<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x96<<8)|(1<<SFlag)            |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         .hword  (0x97<<8)|(1<<SFlag)               |(1<<NFlag)|(1<<CFlag)
         .hword  (0x98<<8)|(1<<SFlag)            |(1<<NFlag)|(1<<CFlag)
         .hword  (0x99<<8)|(1<<SFlag)         |(1<<VFlag)|(1<<NFlag)|(1<<CFlag)
         
.align 4

AF_Z80:  .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 0
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 1
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 2
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 3
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 4
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 5
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 6
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 7
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 8
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 9
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 10
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 11
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 12
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 13
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 14
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 15
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 16
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 17
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 18
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 19
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 20
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 21
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 22
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 23
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 24
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 25
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 26
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 27
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 28
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 29
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 30
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 31
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 32
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 33
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 34
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 35
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 36
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 37
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 38
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 39
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 40
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 41
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 42
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 43
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 44
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 45
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 46
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 47
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 48
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 49
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 50
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 51
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 52
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 53
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 54
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 55
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 56
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 57
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 58
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 59
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 60
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 61
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 62
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 63
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 64
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 65
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 66
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 67
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 68
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 69
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 70
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 71
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 72
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 73
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 74
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 75
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 76
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 77
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 78
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 79
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 80
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 81
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 82
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 83
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 84
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 85
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 86
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 87
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 88
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 89
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 90
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 91
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 92
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 93
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 94
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 95
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 96
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 97
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 98
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 99
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 100
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 101
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 102
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 103
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 104
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 105
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 106
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 107
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 108
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 109
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 110
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 111
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 112
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 113
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 114
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 115
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 116
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 117
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 118
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 119
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 120
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 121
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 122
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 123
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 124
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 125
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 126
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 127
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 128
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 129
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 130
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 131
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 132
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 133
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 134
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 135
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 136
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 137
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 138
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 139
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 140
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 141
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 142
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 143
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 144
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 145
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 146
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 147
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 148
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 149
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 150
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 151
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 152
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 153
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 154
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 155
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 156
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 157
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 158
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 159
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 160
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 161
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 162
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 163
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 164
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 165
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 166
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 167
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 168
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 169
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 170
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 171
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 172
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 173
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 174
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 175
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 176
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 177
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 178
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 179
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 180
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 181
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 182
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 183
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 184
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 185
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 186
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 187
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 188
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 189
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 190
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 191
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 192
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 193
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 194
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 195
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 196
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 197
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 198
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 199
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 200
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 201
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 202
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 203
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 204
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 205
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 206
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 207
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 208
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 209
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 210
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 211
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 212
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 213
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 214
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 215
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 216
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 217
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 218
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 219
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 220
         .byte (0<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 221
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 222
         .byte (1<<Z80_CFlag)|(0<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 223
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 224
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 225
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 226
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 227
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 228
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 229
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 230
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 231
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 232
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 233
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 234
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 235
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 236
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 237
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 238
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(0<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 239
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 240
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 241
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 242
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 243
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 244
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 245
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 246
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(0<<Z80_SFlag) ;@ 247
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 248
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 249
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 250
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(0<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 251
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 252
         .byte (0<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 253
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(0<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 254
         .byte (1<<Z80_CFlag)|(1<<Z80_NFlag)|(1<<Z80_VFlag)|(1<<Z80_HFlag)|(1<<Z80_ZFlag)|(1<<Z80_SFlag) ;@ 255

.align 4

AF_ARM:  .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 0
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 1
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 2
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 3
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 4
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 5
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 6
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 7
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 8
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 9
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 10
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 11
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 12
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 13
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 14
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 15
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 16
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 17
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 18
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 19
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 20
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 21
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 22
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 23
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 24
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 25
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 26
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 27
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 28
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 29
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 30
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 31
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 32
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 33
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 34
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 35
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 36
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 37
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 38
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 39
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 40
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 41
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 42
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 43
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 44
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 45
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 46
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 47
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 48
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 49
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 50
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 51
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 52
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 53
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 54
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 55
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 56
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 57
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 58
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 59
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 60
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 61
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 62
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(0<<SFlag)  ;@ 63
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 64
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 65
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 66
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 67
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 68
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 69
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 70
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 71
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 72
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 73
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 74
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 75
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 76
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 77
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 78
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 79
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 80
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 81
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 82
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 83
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 84
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 85
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 86
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 87
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 88
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 89
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 90
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 91
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 92
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 93
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 94
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 95
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 96
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 97
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 98
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 99
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 100
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 101
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 102
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 103
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 104
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 105
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 106
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 107
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 108
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 109
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 110
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 111
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 112
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 113
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 114
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 115
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 116
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 117
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 118
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 119
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 120
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 121
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 122
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 123
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 124
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 125
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 126
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(0<<SFlag)  ;@ 127
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 128
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 129
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 130
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 131
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 132
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 133
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 134
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 135
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 136
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 137
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 138
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 139
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 140
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 141
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 142
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 143
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 144
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 145
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 146
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 147
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 148
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 149
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 150
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 151
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 152
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 153
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 154
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 155
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 156
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 157
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 158
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 159
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 160
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 161
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 162
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 163
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 164
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 165
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 166
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 167
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 168
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 169
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 170
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 171
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 172
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 173
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 174
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 175
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 176
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 177
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 178
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 179
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 180
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 181
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 182
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 183
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 184
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 185
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 186
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 187
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 188
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 189
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 190
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(0<<ZFlag)|(1<<SFlag)  ;@ 191
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 192
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 193
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 194
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 195
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 196
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 197
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 198
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 199
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 200
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 201
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 202
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 203
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 204
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 205
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 206
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 207
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 208
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 209
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 210
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 211
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 212
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 213
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 214
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 215
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 216
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 217
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 218
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 219
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 220
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 221
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 222
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 223
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 224
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 225
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 226
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 227
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 228
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 229
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 230
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 231
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 232
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 233
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 234
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 235
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 236
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 237
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 238
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(0<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 239
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 240
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 241
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 242
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 243
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 244
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 245
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 246
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 247
         .byte (0<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 248
         .byte (1<<CFlag)|(0<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 249
         .byte (0<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 250
         .byte (1<<CFlag)|(1<<NFlag)|(0<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 251
         .byte (0<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 252
         .byte (1<<CFlag)|(0<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 253
         .byte (0<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 254
         .byte (1<<CFlag)|(1<<NFlag)|(1<<VFlag)|(1<<HFlag)|(1<<ZFlag)|(1<<SFlag)  ;@ 255

.align 4

PZSTable_data: .byte (1<<ZFlag)|(1<<VFlag),0,0,(1<<VFlag),0,(1<<VFlag),(1<<VFlag),0
	.byte  0,(1<<VFlag),(1<<VFlag),0,(1<<VFlag),0,0,(1<<VFlag)
	.byte  0,(1<<VFlag),(1<<VFlag),0,(1<<VFlag),0,0,(1<<VFlag),(1<<VFlag),0,0,(1<<VFlag),0,(1<<VFlag),(1<<VFlag),0
	.byte  0,(1<<VFlag),(1<<VFlag),0,(1<<VFlag),0,0,(1<<VFlag),(1<<VFlag),0,0,(1<<VFlag),0,(1<<VFlag),(1<<VFlag),0
	.byte  (1<<VFlag),0,0,(1<<VFlag),0,(1<<VFlag),(1<<VFlag),0,0,(1<<VFlag),(1<<VFlag),0,(1<<VFlag),0,0,(1<<VFlag)
	.byte  0,(1<<VFlag),(1<<VFlag),0,(1<<VFlag),0,0,(1<<VFlag),(1<<VFlag),0,0,(1<<VFlag),0,(1<<VFlag),(1<<VFlag),0
	.byte  (1<<VFlag),0,0,(1<<VFlag),0,(1<<VFlag),(1<<VFlag),0,0,(1<<VFlag),(1<<VFlag),0,(1<<VFlag),0,0,(1<<VFlag)
	.byte  (1<<VFlag),0,0,(1<<VFlag),0,(1<<VFlag),(1<<VFlag),0,0,(1<<VFlag),(1<<VFlag),0,(1<<VFlag),0,0,(1<<VFlag)
	.byte  0,(1<<VFlag),(1<<VFlag),0,(1<<VFlag),0,0,(1<<VFlag),(1<<VFlag),0,0,(1<<VFlag),0,(1<<VFlag),(1<<VFlag),0
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)|(1<<VFlag),(1<<SFlag)
	.byte  (1<<SFlag)|(1<<VFlag),(1<<SFlag),(1<<SFlag),(1<<SFlag)|(1<<VFlag)       

.align 4

MAIN_opcodes:	
	.word opcode_0_0,opcode_0_1,opcode_0_2,opcode_0_3,opcode_0_4,opcode_0_5,opcode_0_6,opcode_0_7
	.word opcode_0_8,opcode_0_9,opcode_0_A,opcode_0_B,opcode_0_C,opcode_0_D,opcode_0_E,opcode_0_F
	.word opcode_1_0,opcode_1_1,opcode_1_2,opcode_1_3,opcode_1_4,opcode_1_5,opcode_1_6,opcode_1_7
	.word opcode_1_8,opcode_1_9,opcode_1_A,opcode_1_B,opcode_1_C,opcode_1_D,opcode_1_E,opcode_1_F
	.word opcode_2_0,opcode_2_1,opcode_2_2,opcode_2_3,opcode_2_4,opcode_2_5,opcode_2_6,opcode_2_7
	.word opcode_2_8,opcode_2_9,opcode_2_A,opcode_2_B,opcode_2_C,opcode_2_D,opcode_2_E,opcode_2_F
	.word opcode_3_0,opcode_3_1,opcode_3_2,opcode_3_3,opcode_3_4,opcode_3_5,opcode_3_6,opcode_3_7
	.word opcode_3_8,opcode_3_9,opcode_3_A,opcode_3_B,opcode_3_C,opcode_3_D,opcode_3_E,opcode_3_F
	.word opcode_4_0,opcode_4_1,opcode_4_2,opcode_4_3,opcode_4_4,opcode_4_5,opcode_4_6,opcode_4_7
	.word opcode_4_8,opcode_4_9,opcode_4_A,opcode_4_B,opcode_4_C,opcode_4_D,opcode_4_E,opcode_4_F
	.word opcode_5_0,opcode_5_1,opcode_5_2,opcode_5_3,opcode_5_4,opcode_5_5,opcode_5_6,opcode_5_7
	.word opcode_5_8,opcode_5_9,opcode_5_A,opcode_5_B,opcode_5_C,opcode_5_D,opcode_5_E,opcode_5_F
	.word opcode_6_0,opcode_6_1,opcode_6_2,opcode_6_3,opcode_6_4,opcode_6_5,opcode_6_6,opcode_6_7
	.word opcode_6_8,opcode_6_9,opcode_6_A,opcode_6_B,opcode_6_C,opcode_6_D,opcode_6_E,opcode_6_F
	.word opcode_7_0,opcode_7_1,opcode_7_2,opcode_7_3,opcode_7_4,opcode_7_5,opcode_7_6,opcode_7_7
	.word opcode_7_8,opcode_7_9,opcode_7_A,opcode_7_B,opcode_7_C,opcode_7_D,opcode_7_E,opcode_7_F
	.word opcode_8_0,opcode_8_1,opcode_8_2,opcode_8_3,opcode_8_4,opcode_8_5,opcode_8_6,opcode_8_7
	.word opcode_8_8,opcode_8_9,opcode_8_A,opcode_8_B,opcode_8_C,opcode_8_D,opcode_8_E,opcode_8_F
	.word opcode_9_0,opcode_9_1,opcode_9_2,opcode_9_3,opcode_9_4,opcode_9_5,opcode_9_6,opcode_9_7
	.word opcode_9_8,opcode_9_9,opcode_9_A,opcode_9_B,opcode_9_C,opcode_9_D,opcode_9_E,opcode_9_F
	.word opcode_A_0,opcode_A_1,opcode_A_2,opcode_A_3,opcode_A_4,opcode_A_5,opcode_A_6,opcode_A_7
	.word opcode_A_8,opcode_A_9,opcode_A_A,opcode_A_B,opcode_A_C,opcode_A_D,opcode_A_E,opcode_A_F
	.word opcode_B_0,opcode_B_1,opcode_B_2,opcode_B_3,opcode_B_4,opcode_B_5,opcode_B_6,opcode_B_7
	.word opcode_B_8,opcode_B_9,opcode_B_A,opcode_B_B,opcode_B_C,opcode_B_D,opcode_B_E,opcode_B_F
	.word opcode_C_0,opcode_C_1,opcode_C_2,opcode_C_3,opcode_C_4,opcode_C_5,opcode_C_6,opcode_C_7
	.word opcode_C_8,opcode_C_9,opcode_C_A,opcode_C_B,opcode_C_C,opcode_C_D,opcode_C_E,opcode_C_F
	.word opcode_D_0,opcode_D_1,opcode_D_2,opcode_D_3,opcode_D_4,opcode_D_5,opcode_D_6,opcode_D_7
	.word opcode_D_8,opcode_D_9,opcode_D_A,opcode_D_B,opcode_D_C,opcode_D_D,opcode_D_E,opcode_D_F
	.word opcode_E_0,opcode_E_1,opcode_E_2,opcode_E_3,opcode_E_4,opcode_E_5,opcode_E_6,opcode_E_7
	.word opcode_E_8,opcode_E_9,opcode_E_A,opcode_E_B,opcode_E_C,opcode_E_D,opcode_E_E,opcode_E_F
	.word opcode_F_0,opcode_F_1,opcode_F_2,opcode_F_3,opcode_F_4,opcode_F_5,opcode_F_6,opcode_F_7
	.word opcode_F_8,opcode_F_9,opcode_F_A,opcode_F_B,opcode_F_C,opcode_F_D,opcode_F_E,opcode_F_F

.align 4

EI_DUMMY_opcodes:
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@0
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@0
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@1
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@1
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@2
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@2
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@3
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@3
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@4
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@4
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@5
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@5
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@6
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@6
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@7
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@7
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@8
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@8
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@9
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@9
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@A
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@A
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@B
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@B
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@C
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@C
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@D
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@D
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@E
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@E
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@F
	.word ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return,ei_return ;@F

.text
.align 4

;@NOP
opcode_0_0:
;@LD B,B
opcode_4_0:
;@LD C,C
opcode_4_9:
;@LD D,D
opcode_5_2:
;@LD E,E
opcode_5_B:
;@LD H,H
opcode_6_4:
;@LD L,L
opcode_6_D:
;@LD A,A
opcode_7_F:
	fetch 4
;@LD BC,NN
opcode_0_1:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	mov z80bc,r0, lsl #16
	fetch 10
;@LD (BC),A
opcode_0_2:
	mov r0,z80a, lsr #24
	mov r1,z80bc, lsr #16
	writemem8
	fetch 7
;@INC BC
opcode_0_3:
	add z80bc,z80bc,#1<<16
	fetch 6
;@INC B
opcode_0_4:
	opINC8H z80bc
	fetch 4
;@DEC B
opcode_0_5:
	opDEC8H z80bc
	fetch 4
;@LD B,N
opcode_0_6:
	ldrb r1,[z80pc],#1
	and z80bc,z80bc,#0xFF<<16
	orr z80bc,z80bc,r1, lsl #24
	fetch 7
;@RLCA
opcode_0_7:
	bic z80f,z80f,#(1<<NFlag)|(1<<HFlag)|(1<<CFlag)
	movs z80a,z80a, lsl #1
	orrcs z80a,z80a,#1<<24
	orrcs z80f,z80f,#1<<CFlag
	fetch 4
;@EX AF,AF'
opcode_0_8:
	ldr r0,[cpucontext,#z80a2]
	ldr r1,[cpucontext,#z80f2]
	str z80a,[cpucontext,#z80a2]
	str z80f,[cpucontext,#z80f2]
	mov z80a,r0
	mov z80f,r1
	fetch 4
;@ADD HL,BC
opcode_0_9:
	opADD16 z80hl z80bc
	fetch 11
;@LD A,(BC)
opcode_0_A:
	mov r0,z80bc, lsr #16
	readmem8
	mov z80a,r0, lsl #24
	fetch 7
;@DEC BC
opcode_0_B:
	sub z80bc,z80bc,#1<<16
	fetch 6
;@INC C
opcode_0_C:
	opINC8L z80bc
	fetch 4
;@DEC C
opcode_0_D:
	opDEC8L z80bc
	fetch 4
;@LD C,N
opcode_0_E:
	ldrb r1,[z80pc],#1
	and z80bc,z80bc,#0xFF<<24
	orr z80bc,z80bc,r1, lsl #16
	fetch 7
;@RRCA
opcode_0_F:
	bic z80f,z80f,#(1<<NFlag)|(1<<HFlag)|(1<<CFlag)
	movs z80a,z80a, lsr #25
	orrcs z80a,z80a,#1<<7
	orrcs z80f,z80f,#1<<CFlag
	mov z80a,z80a, lsl #24
	fetch 4
;@DJNZ $+2
opcode_1_0:
	sub z80bc,z80bc,#1<<24
	tst z80bc,#0xFF<<24
	ldrsb r1,[z80pc],#1
	addne z80pc,z80pc,r1
	subne z80_icount,z80_icount,#5
	fetch 8

;@LD DE,NN
opcode_1_1:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	mov z80de,r0, lsl #16
	fetch 10
;@LD (DE),A
opcode_1_2:
	mov r0,z80a, lsr #24
	writemem8DE
	fetch 7
;@INC DE
opcode_1_3:
	add z80de,z80de,#1<<16
	fetch 6
;@INC D
opcode_1_4:
	opINC8H z80de
	fetch 4
;@DEC D
opcode_1_5:
	opDEC8H z80de
	fetch 4
;@LD D,N
opcode_1_6:
	ldrb r1,[z80pc],#1
	and z80de,z80de,#0xFF<<16
	orr z80de,z80de,r1, lsl #24
	fetch 7
;@RLA
opcode_1_7:
	tst z80f,#1<<CFlag
	orrne z80a,z80a,#1<<23
	bic z80f,z80f,#(1<<NFlag)|(1<<HFlag)|(1<<CFlag)
	movs z80a,z80a, lsl #1
	orrcs z80f,z80f,#1<<CFlag
	fetch 4
;@JR $+2
opcode_1_8:
	ldrsb r1,[z80pc],#1
	add z80pc,z80pc,r1
	fetch 12
;@ADD HL,DE
opcode_1_9:
	opADD16 z80hl z80de
	fetch 11
;@LD A,(DE)
opcode_1_A:
	mov r0,z80de, lsr #16
	readmem8
	mov z80a,r0, lsl #24
	fetch 7
;@DEC DE
opcode_1_B:
	sub z80de,z80de,#1<<16
	fetch 6
;@INC E
opcode_1_C:
	opINC8L z80de
	fetch 4
;@DEC E
opcode_1_D:
	opDEC8L z80de
	fetch 4
;@LD E,N
opcode_1_E:
	ldrb r0,[z80pc],#1
	and z80de,z80de,#0xFF<<24
	orr z80de,z80de,r0, lsl #16
	fetch 7
;@RRA
opcode_1_F:
	orr z80a,z80a,z80f,lsr#1		;@get C
	bic z80f,z80f,#(1<<NFlag)|(1<<HFlag)|(1<<CFlag)
	movs z80a,z80a,ror#25
	orrcs z80f,z80f,#1<<CFlag
	mov z80a,z80a,lsl#24
	fetch 4
;@JR NZ,$+2
opcode_2_0:
	tst z80f,#1<<ZFlag
	beq opcode_1_8
	add z80pc,z80pc,#1
	fetch 7
;@LD HL,NN
opcode_2_1:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	mov z80hl,r0, lsl #16
	fetch 10
;@LD (NN),HL
opcode_ED_63:
	eatcycles 4
;@LD (NN),HL
opcode_2_2:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r1,r0,r1, lsl #8
	mov r0,z80hl, lsr #16
	writemem16
	fetch 16
;@INC HL
opcode_2_3:
	add z80hl,z80hl,#1<<16
	fetch 6
;@INC H
opcode_2_4:
	opINC8H z80hl
	fetch 4
;@DEC H
opcode_2_5:
	opDEC8H z80hl
	fetch 4
;@LD H,N
opcode_2_6:
	ldrb r1,[z80pc],#1
	and z80hl,z80hl,#0xFF<<16
	orr z80hl,z80hl,r1, lsl #24
	fetch 7
DAATABLE_LOCAL: .word DAATable
;@DAA
opcode_2_7:
	mov r1,z80a, lsr #24
	tst z80f,#1<<CFlag
	orrne r1,r1,#256
	tst z80f,#1<<HFlag
	orrne r1,r1,#512
	tst z80f,#1<<NFlag
	orrne r1,r1,#1024
	ldr r2,DAATABLE_LOCAL
	add r2,r2,r1, lsl #1
	ldrh r1,[r2]
	and z80f,r1,#0xFF
	and r2,r1,#0xFF<<8
	mov z80a,r2, lsl #16
	fetch 4
;@JR Z,$+2
opcode_2_8:
	tst z80f,#1<<ZFlag
	bne opcode_1_8
	add z80pc,z80pc,#1
	fetch 7
;@ADD HL,HL
opcode_2_9:
	opADD16_2 z80hl
	fetch 11
;@LD HL,(NN)
opcode_ED_6B:
	eatcycles 4
;@LD HL,(NN)
opcode_2_A:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	readmem16
	mov z80hl,r0, lsl #16
	fetch 16
;@DEC HL
opcode_2_B:
	sub z80hl,z80hl,#1<<16
	fetch 6
;@INC L
opcode_2_C:
	opINC8L z80hl
	fetch 4
;@DEC L
opcode_2_D:
	opDEC8L z80hl
	fetch 4
;@LD L,N
opcode_2_E:
	ldrb r0,[z80pc],#1
	and z80hl,z80hl,#0xFF<<24
	orr z80hl,z80hl,r0, lsl #16
	fetch 7
;@CPL
opcode_2_F:
	eor z80a,z80a,#0xFF<<24
	orr z80f,z80f,#(1<<NFlag)|(1<<HFlag)
	fetch 4
;@JR NC,$+2
opcode_3_0:
	tst z80f,#1<<CFlag
	beq opcode_1_8
	add z80pc,z80pc,#1
	fetch 7
;@LD SP,NN
opcode_3_1:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1

.if FAST_Z80SP
	orr r0,r0,r1, lsl #8
	rebasesp
.else
	orr z80sp,r0,r1, lsl #8
.endif
	fetch 10
;@LD (NN),A
opcode_3_2:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r1,r0,r1, lsl #8
	mov r0,z80a, lsr #24
	writemem8
	fetch 13
;@INC SP
opcode_3_3:
	add z80sp,z80sp,#1
	fetch 6
;@INC (HL)
opcode_3_4:
	readmem8HL
	opINC8b
	writemem8HL
	fetch 11
;@DEC (HL)
opcode_3_5:
	readmem8HL
	opDEC8b
	writemem8HL
	fetch 11
;@LD (HL),N
opcode_3_6:
	ldrb r0,[z80pc],#1
	writemem8HL
	fetch 10
;@SCF
opcode_3_7:
	bic z80f,z80f,#(1<<NFlag)|(1<<HFlag)
	orr z80f,z80f,#1<<CFlag
	fetch 4
;@JR C,$+2
opcode_3_8:
	tst z80f,#1<<CFlag
	bne opcode_1_8
	add z80pc,z80pc,#1
	fetch 7
;@ADD HL,SP
opcode_3_9:
.if FAST_Z80SP
	ldr r0,[cpucontext,#z80sp_base]
	sub r0,z80sp,r0
	opADD16s z80hl r0 16
.else
	opADD16s z80hl z80sp 16
.endif
	fetch 11
;@LD A,(NN)
opcode_3_A:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	readmem8
	mov z80a,r0, lsl #24
	fetch 13
;@DEC SP
opcode_3_B:
	sub z80sp,z80sp,#1
	fetch 6
;@INC A
opcode_3_C:
	opINC8 z80a
	fetch 4
;@DEC A
opcode_3_D:
	opDEC8 z80a
	fetch 4
;@LD A,N
opcode_3_E:
	ldrb r0,[z80pc],#1
	mov z80a,r0, lsl #24
	fetch 7
;@CCF
opcode_3_F:
	bic z80f,z80f,#(1<<NFlag)|(1<<HFlag)
	tst z80f,#1<<CFlag
	orrne z80f,z80f,#1<<HFlag
	eor z80f,z80f,#1<<CFlag
	fetch 4

;@LD B,C
opcode_4_1:
	and z80bc,z80bc,#0xFF<<16
	orr z80bc,z80bc,z80bc, lsl #8
	fetch 4
;@LD B,D
opcode_4_2:
	and z80bc,z80bc,#0xFF<<16
	and r1,z80de,#0xFF<<24
	orr z80bc,z80bc,r1
	fetch 4
;@LD B,E
opcode_4_3:
	and z80bc,z80bc,#0xFF<<16
	and r1,z80de,#0xFF<<16
	orr z80bc,z80bc,r1, lsl #8
	fetch 4
;@LD B,H
opcode_4_4:
	and z80bc,z80bc,#0xFF<<16
	and r1,z80hl,#0xFF<<24
	orr z80bc,z80bc,r1
	fetch 4
;@LD B,L
opcode_4_5:
	and z80bc,z80bc,#0xFF<<16
	and r1,z80hl,#0xFF<<16
	orr z80bc,z80bc,r1, lsl #8
	fetch 4
;@LD B,(HL)
opcode_4_6:
	readmem8HL
	and z80bc,z80bc,#0xFF<<16
	orr z80bc,z80bc,r0, lsl #24
	fetch 7
;@LD B,A
opcode_4_7:
	and z80bc,z80bc,#0xFF<<16
	orr z80bc,z80bc,z80a
	fetch 4
;@LD C,B
opcode_4_8:
	and z80bc,z80bc,#0xFF<<24
	orr z80bc,z80bc,z80bc, lsr #8
	fetch 4
;@LD C,D
opcode_4_A:
	and z80bc,z80bc,#0xFF<<24
	and r1,z80de,#0xFF<<24
	orr z80bc,z80bc,r1, lsr #8
	fetch 4
;@LD C,E
opcode_4_B:
	and z80bc,z80bc,#0xFF<<24
	and r1,z80de,#0xFF<<16
	orr z80bc,z80bc,r1 
	fetch 4
;@LD C,H
opcode_4_C:
	and z80bc,z80bc,#0xFF<<24
	and r1,z80hl,#0xFF<<24
	orr z80bc,z80bc,r1, lsr #8
	fetch 4
;@LD C,L
opcode_4_D:
	and z80bc,z80bc,#0xFF<<24
	and r1,z80hl,#0xFF<<16
	orr z80bc,z80bc,r1 
	fetch 4
;@LD C,(HL)
opcode_4_E:
	readmem8HL
	and z80bc,z80bc,#0xFF<<24
	orr z80bc,z80bc,r0, lsl #16
	fetch 7
;@LD C,A
opcode_4_F:
	and z80bc,z80bc,#0xFF<<24
	orr z80bc,z80bc,z80a, lsr #8
	fetch 4
;@LD D,B
opcode_5_0:
	and z80de,z80de,#0xFF<<16
	and r1,z80bc,#0xFF<<24
	orr z80de,z80de,r1
	fetch 4
;@LD D,C
opcode_5_1:
	and z80de,z80de,#0xFF<<16
	orr z80de,z80de,z80bc, lsl #8
	fetch 4
;@LD D,E
opcode_5_3:
	and z80de,z80de,#0xFF<<16
	orr z80de,z80de,z80de, lsl #8
	fetch 4
;@LD D,H
opcode_5_4:
	and z80de,z80de,#0xFF<<16
	and r1,z80hl,#0xFF<<24
	orr z80de,z80de,r1
	fetch 4
;@LD D,L
opcode_5_5:
	and z80de,z80de,#0xFF<<16
	orr z80de,z80de,z80hl, lsl #8
	fetch 4
;@LD D,(HL)
opcode_5_6:
	readmem8HL
	and z80de,z80de,#0xFF<<16
	orr z80de,z80de,r0, lsl #24
	fetch 7
;@LD D,A
opcode_5_7:
	and z80de,z80de,#0xFF<<16
	orr z80de,z80de,z80a
	fetch 4
;@LD E,B
opcode_5_8:
	and z80de,z80de,#0xFF<<24
	and r1,z80bc,#0xFF<<24
	orr z80de,z80de,r1, lsr #8
	fetch 4
;@LD E,C
opcode_5_9:
	and z80de,z80de,#0xFF<<24
	and r1,z80bc,#0xFF<<16
	orr z80de,z80de,r1 
	fetch 4
;@LD E,D
opcode_5_A:
	and z80de,z80de,#0xFF<<24
	orr z80de,z80de,z80de, lsr #8
	fetch 4
;@LD E,H
opcode_5_C:
	and z80de,z80de,#0xFF<<24
	and r1,z80hl,#0xFF<<24
	orr z80de,z80de,r1, lsr #8
	fetch 4
;@LD E,L
opcode_5_D:
	and z80de,z80de,#0xFF<<24
	and r1,z80hl,#0xFF<<16
	orr z80de,z80de,r1 
	fetch 4
;@LD E,(HL)
opcode_5_E:
	readmem8HL
	and z80de,z80de,#0xFF<<24
	orr z80de,z80de,r0, lsl #16
	fetch 7
;@LD E,A
opcode_5_F:
	and z80de,z80de,#0xFF<<24
	orr z80de,z80de,z80a, lsr #8
	fetch 4

;@LD H,B
opcode_6_0:
	and z80hl,z80hl,#0xFF<<16
	and r1,z80bc,#0xFF<<24
	orr z80hl,z80hl,r1
	fetch 4
;@LD H,C
opcode_6_1:
	and z80hl,z80hl,#0xFF<<16
	orr z80hl,z80hl,z80bc, lsl #8
	fetch 4
;@LD H,D
opcode_6_2:
	and z80hl,z80hl,#0xFF<<16
	and r1,z80de,#0xFF<<24
	orr z80hl,z80hl,r1
	fetch 4
;@LD H,E
opcode_6_3:
	and z80hl,z80hl,#0xFF<<16
	orr z80hl,z80hl,z80de, lsl #8
	fetch 4
;@LD H,L
opcode_6_5:
	and z80hl,z80hl,#0xFF<<16
	orr z80hl,z80hl,z80hl, lsl #8
	fetch 4
;@LD H,(HL)
opcode_6_6:
	readmem8HL
	and z80hl,z80hl,#0xFF<<16
	orr z80hl,z80hl,r0, lsl #24
	fetch 7
;@LD H,A
opcode_6_7:
	and z80hl,z80hl,#0xFF<<16
	orr z80hl,z80hl,z80a
	fetch 4

;@LD L,B
opcode_6_8:
	and z80hl,z80hl,#0xFF<<24
	and r1,z80bc,#0xFF<<24
	orr z80hl,z80hl,r1, lsr #8
	fetch 4
;@LD L,C
opcode_6_9:
	and z80hl,z80hl,#0xFF<<24
	and r1,z80bc,#0xFF<<16
	orr z80hl,z80hl,r1
	fetch 4
;@LD L,D
opcode_6_A:
	and z80hl,z80hl,#0xFF<<24
	and r1,z80de,#0xFF<<24
	orr z80hl,z80hl,r1, lsr #8
	fetch 4
;@LD L,E
opcode_6_B:
	and z80hl,z80hl,#0xFF<<24
	and r1,z80de,#0xFF<<16
	orr z80hl,z80hl,r1
	fetch 4
;@LD L,H
opcode_6_C:
	and z80hl,z80hl,#0xFF<<24
	orr z80hl,z80hl,z80hl, lsr #8
	fetch 4
;@LD L,(HL)
opcode_6_E:
	readmem8HL
	and z80hl,z80hl,#0xFF<<24
	orr z80hl,z80hl,r0, lsl #16
	fetch 7
;@LD L,A
opcode_6_F:
	and z80hl,z80hl,#0xFF<<24
	orr z80hl,z80hl,z80a, lsr #8
	fetch 4

;@LD (HL),B
opcode_7_0:
	mov r0,z80bc, lsr #24
	writemem8HL
	fetch 7
;@LD (HL),C
opcode_7_1:
	mov r0,z80bc, lsr #16
	and r0,r0,#0xFF
	writemem8HL
	fetch 7
;@LD (HL),D
opcode_7_2:
	mov r0,z80de, lsr #24
	writemem8HL
	fetch 7
;@LD (HL),E
opcode_7_3:
	mov r0,z80de, lsr #16
	and r0,r0,#0xFF
	writemem8HL
	fetch 7
;@LD (HL),H
opcode_7_4:
	mov r0,z80hl, lsr #24
	writemem8HL
	fetch 7
;@LD (HL),L
opcode_7_5:
	mov r1,z80hl, lsr #16
	and r0,r1,#0xFF
	writemem8
	fetch 7
;@HALT
opcode_7_6:
	sub z80pc,z80pc,#1
	ldrb r0,[cpucontext,#z80if]
	orr r0,r0,#Z80_HALT
	strb r0,[cpucontext,#z80if]
	mov z80_icount,#0
	b z80_execute_end
;@LD (HL),A
opcode_7_7:
	mov r0,z80a, lsr #24
	writemem8HL
	fetch 7

;@LD A,B
opcode_7_8:
	and z80a,z80bc,#0xFF<<24
	fetch 4
;@LD A,C
opcode_7_9:
	mov z80a,z80bc, lsl #8
	fetch 4
;@LD A,D
opcode_7_A:
	and z80a,z80de,#0xFF<<24
	fetch 4
;@LD A,E
opcode_7_B:
	mov z80a,z80de, lsl #8
	fetch 4
;@LD A,H
opcode_7_C:
	and z80a,z80hl,#0xFF<<24
	fetch 4
;@LD A,L
opcode_7_D:
	mov z80a,z80hl, lsl #8
	fetch 4
;@LD A,(HL)
opcode_7_E:
	readmem8HL
	mov z80a,r0, lsl #24
	fetch 7

;@ADD A,B
opcode_8_0:
	opADDH z80bc
;@ADD A,C
opcode_8_1:
	opADDL z80bc
;@ADD A,D
opcode_8_2:
	opADDH z80de
;@ADD A,E
opcode_8_3:
	opADDL z80de
;@ADD A,H
opcode_8_4:
	opADDH z80hl
;@ADD A,L
opcode_8_5:
	opADDL z80hl
;@ADD A,(HL)
opcode_8_6:
	readmem8HL
	opADDb
	fetch 7
;@ADD A,A
opcode_8_7:
	opADDA

;@ADC A,B
opcode_8_8:
	opADCH z80bc
;@ADC A,C
opcode_8_9:
	opADCL z80bc
;@ADC A,D
opcode_8_A:
	opADCH z80de
;@ADC A,E
opcode_8_B:
	opADCL z80de
;@ADC A,H
opcode_8_C:
	opADCH z80hl
;@ADC A,L
opcode_8_D:
	opADCL z80hl
;@ADC A,(HL)
opcode_8_E:
	readmem8HL
	opADCb
	fetch 7
;@ADC A,A
opcode_8_F:
	opADCA

;@SUB B
opcode_9_0:
	opSUBH z80bc
;@SUB C
opcode_9_1:
	opSUBL z80bc
;@SUB D
opcode_9_2:
	opSUBH z80de
;@SUB E
opcode_9_3:
	opSUBL z80de
;@SUB H
opcode_9_4:
	opSUBH z80hl
;@SUB L
opcode_9_5:
	opSUBL z80hl
;@SUB (HL)
opcode_9_6:
	readmem8HL
	opSUBb
	fetch 7
;@SUB A
opcode_9_7:
	opSUBA

;@SBC B 
opcode_9_8:
	opSBCH z80bc
;@SBC C
opcode_9_9:
	opSBCL z80bc
;@SBC D
opcode_9_A:
	opSBCH z80de
;@SBC E
opcode_9_B:
	opSBCL z80de
;@SBC H
opcode_9_C:
	opSBCH z80hl
;@SBC L
opcode_9_D:
	opSBCL z80hl
;@SBC (HL)
opcode_9_E:
	readmem8HL
	opSBCb
	fetch 7
;@SBC A
opcode_9_F:
	opSBCA

;@AND B
opcode_A_0:
	opANDH z80bc
;@AND C
opcode_A_1:
	opANDL z80bc
;@AND D
opcode_A_2:
	opANDH z80de
;@AND E
opcode_A_3:
	opANDL z80de
;@AND H
opcode_A_4:
	opANDH z80hl
;@AND L
opcode_A_5:
	opANDL z80hl
;@AND (HL)
opcode_A_6:
	readmem8HL
	opANDb
	fetch 7
;@AND A
opcode_A_7:
	opANDA

;@XOR B
opcode_A_8:
	opXORH z80bc
;@XOR C
opcode_A_9:
	opXORL z80bc
;@XOR D
opcode_A_A:
	opXORH z80de
;@XOR E
opcode_A_B:
	opXORL z80de
;@XOR H
opcode_A_C:
	opXORH z80hl
;@XOR L
opcode_A_D:
	opXORL z80hl
;@XOR (HL)
opcode_A_E:
	readmem8HL
	opXORb
	fetch 7
;@XOR A
opcode_A_F:
	opXORA

;@OR B
opcode_B_0:
	opORH z80bc
;@OR C
opcode_B_1:
	opORL z80bc
;@OR D
opcode_B_2:
	opORH z80de
;@OR E
opcode_B_3:
	opORL z80de
;@OR H
opcode_B_4:
	opORH z80hl
;@OR L
opcode_B_5:
	opORL z80hl
;@OR (HL)
opcode_B_6:
	readmem8HL
	opORb
	fetch 7
;@OR A
opcode_B_7:
	opORA

;@CP B
opcode_B_8:
	opCPH z80bc
;@CP C
opcode_B_9:
	opCPL z80bc
;@CP D
opcode_B_A:
	opCPH z80de
;@CP E
opcode_B_B:
	opCPL z80de
;@CP H
opcode_B_C:
	opCPH z80hl
;@CP L
opcode_B_D:
	opCPL z80hl
;@CP (HL)
opcode_B_E:
	readmem8HL
	opCPb
	fetch 7
;@CP A
opcode_B_F:
	opCPA

;@RET NZ
opcode_C_0:
	tst z80f,#1<<ZFlag
	beq opcode_C_9_cond		;@unconditional RET
	fetch 5

;@POP BC
opcode_C_1:
	opPOPreg z80bc

;@JP NZ,$+3
opcode_C_2:
	tst z80f,#1<<ZFlag
	beq opcode_C_3		;@unconditional JP
	add z80pc,z80pc,#2
	fetch 10
;@JP $+3
opcode_C_3:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	rebasepc
	fetch 10
;@CALL NZ,NN
opcode_C_4:
	tst z80f,#1<<ZFlag
	beq opcode_C_D		;@unconditional CALL
	add z80pc,z80pc,#2
	fetch 10

;@PUSH BC
opcode_C_5:
	opPUSHreg z80bc
	fetch 11
;@ADD A,N
opcode_C_6:
	ldrb r0,[z80pc],#1
	opADDb
	fetch 7
;@RST 0
opcode_C_7:
	opRST 0x00

;@RET Z
opcode_C_8:
	tst z80f,#1<<ZFlag
	bne opcode_C_9_cond		;@unconditional RET
	fetch 5

opcode_C_9_cond:
	eatcycles 1
;@RET
opcode_C_9:
    opPOP
	rebasepc
	fetch 10
;@JP Z,$+3
opcode_C_A:
	tst z80f,#1<<ZFlag
	bne opcode_C_3  ;@unconditional JP
	add z80pc,z80pc,#2
	fetch 10

;@This reads this opcodes_CB lookup table to find the location of
;@the CB sub for the intruction and then branches to that location
opcode_C_B:
	ldrb r0,[z80pc],#1
	ldr pc,[pc,r0, lsl #2]
opcodes_CB:	.word 0x00000000
			.word opcode_CB_00,opcode_CB_01,opcode_CB_02,opcode_CB_03,opcode_CB_04,opcode_CB_05,opcode_CB_06,opcode_CB_07
			.word opcode_CB_08,opcode_CB_09,opcode_CB_0A,opcode_CB_0B,opcode_CB_0C,opcode_CB_0D,opcode_CB_0E,opcode_CB_0F
			.word opcode_CB_10,opcode_CB_11,opcode_CB_12,opcode_CB_13,opcode_CB_14,opcode_CB_15,opcode_CB_16,opcode_CB_17
			.word opcode_CB_18,opcode_CB_19,opcode_CB_1A,opcode_CB_1B,opcode_CB_1C,opcode_CB_1D,opcode_CB_1E,opcode_CB_1F
			.word opcode_CB_20,opcode_CB_21,opcode_CB_22,opcode_CB_23,opcode_CB_24,opcode_CB_25,opcode_CB_26,opcode_CB_27
			.word opcode_CB_28,opcode_CB_29,opcode_CB_2A,opcode_CB_2B,opcode_CB_2C,opcode_CB_2D,opcode_CB_2E,opcode_CB_2F
			.word opcode_CB_30,opcode_CB_31,opcode_CB_32,opcode_CB_33,opcode_CB_34,opcode_CB_35,opcode_CB_36,opcode_CB_37
			.word opcode_CB_38,opcode_CB_39,opcode_CB_3A,opcode_CB_3B,opcode_CB_3C,opcode_CB_3D,opcode_CB_3E,opcode_CB_3F
			.word opcode_CB_40,opcode_CB_41,opcode_CB_42,opcode_CB_43,opcode_CB_44,opcode_CB_45,opcode_CB_46,opcode_CB_47
			.word opcode_CB_48,opcode_CB_49,opcode_CB_4A,opcode_CB_4B,opcode_CB_4C,opcode_CB_4D,opcode_CB_4E,opcode_CB_4F
			.word opcode_CB_50,opcode_CB_51,opcode_CB_52,opcode_CB_53,opcode_CB_54,opcode_CB_55,opcode_CB_56,opcode_CB_57
			.word opcode_CB_58,opcode_CB_59,opcode_CB_5A,opcode_CB_5B,opcode_CB_5C,opcode_CB_5D,opcode_CB_5E,opcode_CB_5F
			.word opcode_CB_60,opcode_CB_61,opcode_CB_62,opcode_CB_63,opcode_CB_64,opcode_CB_65,opcode_CB_66,opcode_CB_67
			.word opcode_CB_68,opcode_CB_69,opcode_CB_6A,opcode_CB_6B,opcode_CB_6C,opcode_CB_6D,opcode_CB_6E,opcode_CB_6F
			.word opcode_CB_70,opcode_CB_71,opcode_CB_72,opcode_CB_73,opcode_CB_74,opcode_CB_75,opcode_CB_76,opcode_CB_77
			.word opcode_CB_78,opcode_CB_79,opcode_CB_7A,opcode_CB_7B,opcode_CB_7C,opcode_CB_7D,opcode_CB_7E,opcode_CB_7F
			.word opcode_CB_80,opcode_CB_81,opcode_CB_82,opcode_CB_83,opcode_CB_84,opcode_CB_85,opcode_CB_86,opcode_CB_87
			.word opcode_CB_88,opcode_CB_89,opcode_CB_8A,opcode_CB_8B,opcode_CB_8C,opcode_CB_8D,opcode_CB_8E,opcode_CB_8F
			.word opcode_CB_90,opcode_CB_91,opcode_CB_92,opcode_CB_93,opcode_CB_94,opcode_CB_95,opcode_CB_96,opcode_CB_97
			.word opcode_CB_98,opcode_CB_99,opcode_CB_9A,opcode_CB_9B,opcode_CB_9C,opcode_CB_9D,opcode_CB_9E,opcode_CB_9F
			.word opcode_CB_A0,opcode_CB_A1,opcode_CB_A2,opcode_CB_A3,opcode_CB_A4,opcode_CB_A5,opcode_CB_A6,opcode_CB_A7
			.word opcode_CB_A8,opcode_CB_A9,opcode_CB_AA,opcode_CB_AB,opcode_CB_AC,opcode_CB_AD,opcode_CB_AE,opcode_CB_AF
			.word opcode_CB_B0,opcode_CB_B1,opcode_CB_B2,opcode_CB_B3,opcode_CB_B4,opcode_CB_B5,opcode_CB_B6,opcode_CB_B7
			.word opcode_CB_B8,opcode_CB_B9,opcode_CB_BA,opcode_CB_BB,opcode_CB_BC,opcode_CB_BD,opcode_CB_BE,opcode_CB_BF
			.word opcode_CB_C0,opcode_CB_C1,opcode_CB_C2,opcode_CB_C3,opcode_CB_C4,opcode_CB_C5,opcode_CB_C6,opcode_CB_C7
			.word opcode_CB_C8,opcode_CB_C9,opcode_CB_CA,opcode_CB_CB,opcode_CB_CC,opcode_CB_CD,opcode_CB_CE,opcode_CB_CF
			.word opcode_CB_D0,opcode_CB_D1,opcode_CB_D2,opcode_CB_D3,opcode_CB_D4,opcode_CB_D5,opcode_CB_D6,opcode_CB_D7
			.word opcode_CB_D8,opcode_CB_D9,opcode_CB_DA,opcode_CB_DB,opcode_CB_DC,opcode_CB_DD,opcode_CB_DE,opcode_CB_DF
			.word opcode_CB_E0,opcode_CB_E1,opcode_CB_E2,opcode_CB_E3,opcode_CB_E4,opcode_CB_E5,opcode_CB_E6,opcode_CB_E7
			.word opcode_CB_E8,opcode_CB_E9,opcode_CB_EA,opcode_CB_EB,opcode_CB_EC,opcode_CB_ED,opcode_CB_EE,opcode_CB_EF
			.word opcode_CB_F0,opcode_CB_F1,opcode_CB_F2,opcode_CB_F3,opcode_CB_F4,opcode_CB_F5,opcode_CB_F6,opcode_CB_F7
			.word opcode_CB_F8,opcode_CB_F9,opcode_CB_FA,opcode_CB_FB,opcode_CB_FC,opcode_CB_FD,opcode_CB_FE,opcode_CB_FF

;@CALL Z,NN
opcode_C_C:
	tst z80f,#1<<ZFlag
	bne opcode_C_D		;@unconditional CALL
	add z80pc,z80pc,#2
	fetch 10
;@CALL NN
opcode_C_D:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	ldr r2,[cpucontext,#z80pc_base]
	sub r2,z80pc,r2
	orr z80pc,r0,r1, lsl #8
    opPUSHareg r2
    mov r0,z80pc
	rebasepc
	fetch 17
;@ADC A,N
opcode_C_E:
	ldrb r0,[z80pc],#1
	opADCb
	fetch 7
;@RST 8H
opcode_C_F:
	opRST 0x08

;@RET NC
opcode_D_0:
	tst z80f,#1<<CFlag
	beq opcode_C_9_cond		;@unconditional RET
	fetch 5
;@POP DE
opcode_D_1:
	opPOPreg z80de

;@JP NC, $+3
opcode_D_2 :
	tst z80f,#1<<CFlag
	beq opcode_C_3		;@unconditional JP
	add z80pc,z80pc,#2
	fetch 10
;@OUT (N),A
opcode_D_3:
	ldrb r0,[z80pc],#1
	orr r0,r0,z80a,lsr#16
	mov r1,z80a, lsr #24
	opOUT
	fetch 11
;@CALL NC,NN
opcode_D_4:
	tst z80f,#1<<CFlag
	beq opcode_C_D		;@unconditional CALL
	add z80pc,z80pc,#2
	fetch 10
;@PUSH DE
opcode_D_5:
	opPUSHreg z80de
	fetch 11
;@SUB N
opcode_D_6:
	ldrb r0,[z80pc],#1
	opSUBb
	fetch 7

;@RST 10H
opcode_D_7:
	opRST 0x10

;@RET C
opcode_D_8:
	tst z80f,#1<<CFlag
	bne opcode_C_9_cond		;@unconditional RET
	fetch 5
;@EXX
opcode_D_9:
	ldr r0,[cpucontext,#z80bc2]
	ldr r1,[cpucontext,#z80de2]
	ldr r2,[cpucontext,#z80hl2]
	str z80bc,[cpucontext,#z80bc2]
	str z80de,[cpucontext,#z80de2]
	str z80hl,[cpucontext,#z80hl2]
	mov z80bc,r0
	mov z80de,r1
	mov z80hl,r2
	fetch 4
;@JP C,$+3
opcode_D_A:
	tst z80f,#1<<CFlag
	bne opcode_C_3		;@unconditional JP
	add z80pc,z80pc,#2
	fetch 10
;@IN A,(N)
opcode_D_B:
	ldrb r0,[z80pc],#1
	orr r0,r0,z80a,lsr#16
	opIN
	mov z80a,r0, lsl #24	;@ r0 = data read
	fetch 11
;@CALL C,NN
opcode_D_C:
	tst z80f,#1<<CFlag
	bne opcode_C_D		;@unconditional CALL
	add z80pc,z80pc,#2
	fetch 10

;@opcodes_DD
opcode_D_D:
	add z80xx,cpucontext,#z80ix
	b opcode_D_D_F_D
opcode_F_D:
	add z80xx,cpucontext,#z80iy
opcode_D_D_F_D:
	ldrb r0,[z80pc],#1
	ldr pc,[pc,r0, lsl #2]
opcodes_DD:	.word 0x00000000
			.word opcode_0_0,  opcode_0_1,  opcode_0_2,  opcode_0_3,  opcode_0_4,  opcode_0_5,  opcode_0_6,  opcode_0_7
			.word opcode_0_8,  opcode_DD_09,opcode_0_A,  opcode_0_B,  opcode_0_C,  opcode_0_D,  opcode_0_E,  opcode_0_F
			.word opcode_1_0,  opcode_1_1,  opcode_1_2,  opcode_1_3,  opcode_1_4,  opcode_1_5,  opcode_1_6,  opcode_1_7
			.word opcode_1_8,  opcode_DD_19,opcode_1_A,  opcode_1_B,  opcode_1_C,  opcode_1_D,  opcode_1_E,  opcode_1_F
			.word opcode_2_0,  opcode_DD_21,opcode_DD_22,opcode_DD_23,opcode_DD_24,opcode_DD_25,opcode_DD_26,opcode_2_7
			.word opcode_2_8,  opcode_DD_29,opcode_DD_2A,opcode_DD_2B,opcode_DD_2C,opcode_DD_2D,opcode_DD_2E,opcode_2_F
			.word opcode_3_0,  opcode_3_1,  opcode_3_2,  opcode_3_3,  opcode_DD_34,opcode_DD_35,opcode_DD_36,opcode_3_7
			.word opcode_3_8,  opcode_DD_39,opcode_3_A,  opcode_3_B,  opcode_3_C,  opcode_3_D,  opcode_3_E,  opcode_3_F
			.word opcode_4_0,  opcode_4_1,  opcode_4_2,  opcode_4_3,  opcode_DD_44,opcode_DD_45,opcode_DD_46,opcode_4_7
			.word opcode_4_8,  opcode_4_9,  opcode_4_A,  opcode_4_B,  opcode_DD_4C,opcode_DD_4D,opcode_DD_4E,opcode_4_F
			.word opcode_5_0,  opcode_5_1,  opcode_5_2,  opcode_5_3,  opcode_DD_54,opcode_DD_55,opcode_DD_56,opcode_5_7
			.word opcode_5_8,  opcode_5_9,  opcode_5_A,  opcode_5_B,  opcode_DD_5C,opcode_DD_5D,opcode_DD_5E,opcode_5_F
			.word opcode_DD_60,opcode_DD_61,opcode_DD_62,opcode_DD_63,opcode_DD_64,opcode_DD_65,opcode_DD_66,opcode_DD_67
			.word opcode_DD_68,opcode_DD_69,opcode_DD_6A,opcode_DD_6B,opcode_DD_6C,opcode_DD_6D,opcode_DD_6E,opcode_DD_6F
			.word opcode_DD_70,opcode_DD_71,opcode_DD_72,opcode_DD_73,opcode_DD_74,opcode_DD_75,opcode_7_6,  opcode_DD_77
			.word opcode_7_8,  opcode_7_9,  opcode_7_A,  opcode_7_B,  opcode_DD_7C,opcode_DD_7D,opcode_DD_7E,opcode_7_F
			.word opcode_8_0,  opcode_8_1,  opcode_8_2,  opcode_8_3,  opcode_DD_84,opcode_DD_85,opcode_DD_86,opcode_8_7
			.word opcode_8_8,  opcode_8_9,  opcode_8_A,  opcode_8_B,  opcode_DD_8C,opcode_DD_8D,opcode_DD_8E,opcode_8_F
			.word opcode_9_0,  opcode_9_1,  opcode_9_2,  opcode_9_3,  opcode_DD_94,opcode_DD_95,opcode_DD_96,opcode_9_7
			.word opcode_9_8,  opcode_9_9,  opcode_9_A,  opcode_9_B,  opcode_DD_9C,opcode_DD_9D,opcode_DD_9E,opcode_9_F
			.word opcode_A_0,  opcode_A_1,  opcode_A_2,  opcode_A_3,  opcode_DD_A4,opcode_DD_A5,opcode_DD_A6,opcode_A_7
			.word opcode_A_8,  opcode_A_9,  opcode_A_A,  opcode_A_B,  opcode_DD_AC,opcode_DD_AD,opcode_DD_AE,opcode_A_F
			.word opcode_B_0,  opcode_B_1,  opcode_B_2,  opcode_B_3,  opcode_DD_B4,opcode_DD_B5,opcode_DD_B6,opcode_B_7
			.word opcode_B_8,  opcode_B_9,  opcode_B_A,  opcode_B_B,  opcode_DD_BC,opcode_DD_BD,opcode_DD_BE,opcode_B_F
			.word opcode_C_0,  opcode_C_1,  opcode_C_2,  opcode_C_3,  opcode_C_4,  opcode_C_5,  opcode_C_6,  opcode_C_7
			.word opcode_C_8,  opcode_C_9,  opcode_C_A,  opcode_DD_CB,opcode_C_C,  opcode_C_D,  opcode_C_E,  opcode_C_F
			.word opcode_D_0,  opcode_D_1,  opcode_D_2,  opcode_D_3,  opcode_D_4,  opcode_D_5,  opcode_D_6,  opcode_D_7
			.word opcode_D_8,  opcode_D_9,  opcode_D_A,  opcode_D_B,  opcode_D_C,  opcode_D_D,  opcode_D_E,  opcode_D_F
			.word opcode_E_0,  opcode_DD_E1,opcode_E_2,  opcode_DD_E3,opcode_E_4,  opcode_DD_E5,opcode_E_6,  opcode_E_7
			.word opcode_E_8,  opcode_DD_E9,opcode_E_A,  opcode_E_B,  opcode_E_C,  opcode_E_D,  opcode_E_E,  opcode_E_F
			.word opcode_F_0,  opcode_F_1,  opcode_F_2,  opcode_F_3,  opcode_F_4,  opcode_F_5,  opcode_F_6,  opcode_F_7
			.word opcode_F_8,  opcode_DD_F9,opcode_F_A,  opcode_F_B,  opcode_F_C,  opcode_F_D,  opcode_F_E,  opcode_F_F

;@SBC A,N
opcode_D_E:
	ldrb r0,[z80pc],#1
	opSBCb
	fetch 7
;@RST 18H
opcode_D_F:
	opRST 0x18

;@RET PO
opcode_E_0:
	tst z80f,#1<<VFlag
	beq opcode_C_9_cond		;@unconditional RET
	fetch 5
;@POP HL
opcode_E_1:
	opPOPreg z80hl

;@JP PO,$+3
opcode_E_2:
	tst z80f,#1<<VFlag
	beq opcode_C_3		;@unconditional JP
	add z80pc,z80pc,#2
	fetch 10
;@EX (SP),HL
opcode_E_3:
.if FAST_Z80SP
	ldrb r0,[z80sp]
	ldrb r1,[z80sp,#1]
	orr r0,r0,r1, lsl #8
	mov r1,z80hl, lsr #24
	strb r1,[z80sp,#1]
	mov r1,z80hl, lsr #16
	strb r1,[z80sp]
	mov z80hl,r0, lsl #16
.else
	mov r0,z80sp
	readmem16
	mov r1,r0
	mov r0,z80hl,lsr#16
	mov z80hl,r1,lsl#16
	mov r1,z80sp
	writemem16
.endif
	fetch 19
;@CALL PO,NN
opcode_E_4:
	tst z80f,#1<<VFlag
	beq opcode_C_D		;@unconditional CALL
	add z80pc,z80pc,#2
	fetch 10
;@PUSH HL
opcode_E_5:
	opPUSHreg z80hl
	fetch 11
;@AND N
opcode_E_6:
	ldrb r0,[z80pc],#1
	opANDb
	fetch 7
;@RST 20H
opcode_E_7:
	opRST 0x20

;@RET PE
opcode_E_8:
	tst z80f,#1<<VFlag
	bne opcode_C_9_cond		;@unconditional RET
	fetch 5
;@JP (HL)
opcode_E_9:
	mov r0,z80hl, lsr #16
	rebasepc
	fetch 4
;@JP PE,$+3
opcode_E_A:
	tst z80f,#1<<VFlag
	bne opcode_C_3		;@unconditional JP
	add z80pc,z80pc,#2
	fetch 10
;@EX DE,HL
opcode_E_B:
	mov r1,z80de
	mov z80de,z80hl
	mov z80hl,r1
	fetch 4
;@CALL PE,NN
opcode_E_C:
	tst z80f,#1<<VFlag
	bne opcode_C_D		;@unconditional CALL
	add z80pc,z80pc,#2
	fetch 10

;@This should be caught at start
opcode_E_D:
	ldrb r1,[z80pc],#1
	ldr pc,[pc,r1, lsl #2]
opcodes_ED:	.word 0x00000000
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_40,opcode_ED_41,opcode_ED_42,opcode_ED_43,opcode_ED_44,opcode_ED_45,opcode_ED_46,opcode_ED_47
			.word opcode_ED_48,opcode_ED_49,opcode_ED_4A,opcode_ED_4B,opcode_ED_44,opcode_ED_4D,opcode_ED_46,opcode_ED_4F
			.word opcode_ED_50,opcode_ED_51,opcode_ED_52,opcode_ED_53,opcode_ED_44,opcode_ED_45,opcode_ED_56,opcode_ED_57
			.word opcode_ED_58,opcode_ED_59,opcode_ED_5A,opcode_ED_5B,opcode_ED_44,opcode_ED_45,opcode_ED_5E,opcode_ED_5F
			.word opcode_ED_60,opcode_ED_61,opcode_ED_62,opcode_ED_63,opcode_ED_44,opcode_ED_45,opcode_ED_46,opcode_ED_67
			.word opcode_ED_68,opcode_ED_69,opcode_ED_6A,opcode_ED_6B,opcode_ED_44,opcode_ED_45,opcode_ED_46,opcode_ED_6F
			.word opcode_ED_70,opcode_ED_71,opcode_ED_72,opcode_ED_73,opcode_ED_44,opcode_ED_45,opcode_ED_56,opcode_ED_NF
			.word opcode_ED_78,opcode_ED_79,opcode_ED_7A,opcode_ED_7B,opcode_ED_44,opcode_ED_45,opcode_ED_5E,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_A0,opcode_ED_A1,opcode_ED_A2,opcode_ED_A3,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_A8,opcode_ED_A9,opcode_ED_AA,opcode_ED_AB,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_B0,opcode_ED_B1,opcode_ED_B2,opcode_ED_B3,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_B8,opcode_ED_B9,opcode_ED_BA,opcode_ED_BB,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF
			.word opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF,opcode_ED_NF

;@XOR N
opcode_E_E:
	ldrb r0,[z80pc],#1
	opXORb
	fetch 7
;@RST 28H
opcode_E_F:
	opRST 0x28

;@RET P
opcode_F_0:
	tst z80f,#1<<SFlag
	beq opcode_C_9_cond		;@unconditional RET
	fetch 5
;@POP AF
opcode_F_1:
.if FAST_Z80SP
	ldrb z80f,[z80sp],#1
	sub r0,opcodes,#0x200
	ldrb z80f,[r0,z80f]
	ldrb z80a,[z80sp],#1
	mov z80a,z80a, lsl #24
.else
	mov r0,z80sp
	readmem16
	add z80sp,z80sp,#2
	and z80a,r0,#0xFF00
	mov z80a,z80a,lsl#16
	and z80f,r0,#0xFF
	sub r0,opcodes,#0x200
	ldrb z80f,[r0,z80f]
.endif
	fetch 10
;@JP P,$+3
opcode_F_2:
	tst z80f,#1<<SFlag
	beq opcode_C_3		;@unconditional JP
	add z80pc,z80pc,#2
	fetch 10
;@DI
opcode_F_3:
	ldrb r1,[cpucontext,#z80if]
	bic r1,r1,#(Z80_IF1)|(Z80_IF2)
	strb r1,[cpucontext,#z80if]
	fetch 4
;@CALL P,NN
opcode_F_4:
	tst z80f,#1<<SFlag
	beq opcode_C_D		;@unconditional CALL
	add z80pc,z80pc,#2
	fetch 10
;@PUSH AF
opcode_F_5:
	sub r0,opcodes,#0x300
	ldrb r0,[r0,z80f]
	orr r2,r0,z80a,lsr#16
    opPUSHareg r2
	fetch 11
;@OR N
opcode_F_6:
	ldrb r0,[z80pc],#1
	opORb
	fetch 7
;@RST 30H
opcode_F_7:
	opRST 0x30

;@RET M
opcode_F_8:
	tst z80f,#1<<SFlag
	bne opcode_C_9_cond		;@unconditional RET
	fetch 5
;@LD SP,HL
opcode_F_9:
.if FAST_Z80SP
	mov r0,z80hl, lsr #16
	rebasesp
.else
	mov z80sp,z80hl, lsr #16
.endif
	fetch 6
;@JP M,$+3
opcode_F_A:
	tst z80f,#1<<SFlag
	bne opcode_C_3		;@unconditional JP
	add z80pc,z80pc,#2
	fetch 10
MAIN_opcodes_POINTER: .word MAIN_opcodes
EI_DUMMY_opcodes_POINTER: .word EI_DUMMY_opcodes
;@EI
opcode_F_B:
	ldrb r1,[cpucontext,#z80if]
	mov r2,opcodes
	orr r1,r1,#(Z80_IF1)|(Z80_IF2)
	strb r1,[cpucontext,#z80if]

	ldrb r0,[z80pc],#1
	eatcycles 4
	ldr opcodes,EI_DUMMY_opcodes_POINTER
	ldr pc,[r2,r0, lsl #2]

ei_return:
	;@point that program returns from EI to check interupts
	;@an interupt can not be taken directly after a EI opcode
	;@ reset z80pc and opcode pointer
	ldrh r0,[cpucontext,#z80irq] @ 0x4C, irq and IFF bits
	sub z80pc,z80pc,#1
	ldr opcodes,MAIN_opcodes_POINTER
	;@ check ints
	tst r0,#0xff
	movne r0,r0,lsr #8
	tstne r0,#Z80_IF1
	blne DoInterrupt

	;@ continue
	fetch 0

;@CALL M,NN
opcode_F_C:
	tst z80f,#1<<SFlag
	bne opcode_C_D		;@unconditional CALL
	add z80pc,z80pc,#2
	fetch 10

;@SHOULD BE CAUGHT AT START - FD SECTION

;@CP N
opcode_F_E:
	ldrb r0,[z80pc],#1
	opCPb
	fetch 7
;@RST 38H
opcode_F_F:
	opRST 0x38


;@##################################
;@##################################
;@###  opcodes CB  #########################
;@##################################
;@##################################


;@RLC B
opcode_CB_00:
	opRLCH z80bc
;@RLC C
opcode_CB_01:
	opRLCL z80bc
;@RLC D
opcode_CB_02:
	opRLCH z80de
;@RLC E
opcode_CB_03:
	opRLCL z80de
;@RLC H
opcode_CB_04:
	opRLCH z80hl
;@RLC L
opcode_CB_05:
	opRLCL z80hl
;@RLC (HL)
opcode_CB_06:
	readmem8HL
	opRLCb
	writemem8HL
	fetch 15
;@RLC A
opcode_CB_07:
	opRLCA

;@RRC B
opcode_CB_08:
	opRRCH z80bc
;@RRC C
opcode_CB_09:
	opRRCL z80bc
;@RRC D
opcode_CB_0A:
	opRRCH z80de
;@RRC E
opcode_CB_0B:
	opRRCL z80de
;@RRC H
opcode_CB_0C:
	opRRCH z80hl
;@RRC L
opcode_CB_0D:
	opRRCL z80hl
;@RRC (HL)
opcode_CB_0E :
	readmem8HL
	opRRCb
	writemem8HL
	fetch 15
;@RRC A
opcode_CB_0F:
	opRRCA

;@RL B
opcode_CB_10:
	opRLH z80bc
;@RL C
opcode_CB_11:
	opRLL z80bc
;@RL D
opcode_CB_12:
	opRLH z80de
;@RL E
opcode_CB_13:
	opRLL z80de
;@RL H
opcode_CB_14:
	opRLH z80hl
;@RL L
opcode_CB_15:
	opRLL z80hl
;@RL (HL)
opcode_CB_16:
	readmem8HL
	opRLb
	writemem8HL
	fetch 15
;@RL A
opcode_CB_17:
	opRLA

;@RR B 
opcode_CB_18:
	opRRH z80bc
;@RR C
opcode_CB_19:
	opRRL z80bc
;@RR D
opcode_CB_1A:
	opRRH z80de
;@RR E
opcode_CB_1B:
	opRRL z80de
;@RR H
opcode_CB_1C:
	opRRH z80hl
;@RR L
opcode_CB_1D:
	opRRL z80hl
;@RR (HL)
opcode_CB_1E:
	readmem8HL
	opRRb
	writemem8HL
	fetch 15
;@RR A
opcode_CB_1F:
	opRRA

;@SLA B
opcode_CB_20:
	opSLAH z80bc
;@SLA C
opcode_CB_21:
	opSLAL z80bc
;@SLA D
opcode_CB_22:
	opSLAH z80de
;@SLA E
opcode_CB_23:
	opSLAL z80de
;@SLA H
opcode_CB_24:
	opSLAH z80hl
;@SLA L
opcode_CB_25:
	opSLAL z80hl
;@SLA (HL)
opcode_CB_26:
	readmem8HL
	opSLAb
	writemem8HL
	fetch 15
;@SLA A
opcode_CB_27:
	opSLAA

;@SRA B
opcode_CB_28:
	opSRAH z80bc
;@SRA C
opcode_CB_29:
	opSRAL z80bc
;@SRA D
opcode_CB_2A:
	opSRAH z80de
;@SRA E
opcode_CB_2B:
	opSRAL z80de
;@SRA H
opcode_CB_2C:
	opSRAH z80hl
;@SRA L
opcode_CB_2D:
	opSRAL z80hl
;@SRA (HL)
opcode_CB_2E:
	readmem8HL
	opSRAb
	writemem8HL
	fetch 15
;@SRA A
opcode_CB_2F:
	opSRAA

;@SLL B
opcode_CB_30:
	opSLLH z80bc
;@SLL C
opcode_CB_31:
	opSLLL z80bc
;@SLL D
opcode_CB_32:
	opSLLH z80de
;@SLL E
opcode_CB_33:
	opSLLL z80de
;@SLL H
opcode_CB_34:
	opSLLH z80hl
;@SLL L
opcode_CB_35:
	opSLLL z80hl
;@SLL (HL)
opcode_CB_36:
	readmem8HL
	opSLLb
	writemem8HL
	fetch 15
;@SLL A
opcode_CB_37:
	opSLLA

;@SRL B
opcode_CB_38:
	opSRLH z80bc
;@SRL C
opcode_CB_39:
	opSRLL z80bc
;@SRL D
opcode_CB_3A:
	opSRLH z80de
;@SRL E
opcode_CB_3B:
	opSRLL z80de
;@SRL H
opcode_CB_3C:
	opSRLH z80hl
;@SRL L
opcode_CB_3D:
	opSRLL z80hl
;@SRL (HL)
opcode_CB_3E:
	readmem8HL
	opSRLb
	writemem8HL
	fetch 15
;@SRL A
opcode_CB_3F:
	opSRLA


;@BIT 0,B
opcode_CB_40:
	opBITH z80bc 0
;@BIT 0,C
opcode_CB_41:
	opBITL z80bc 0
;@BIT 0,D
opcode_CB_42:
	opBITH z80de 0
;@BIT 0,E
opcode_CB_43:
	opBITL z80de 0
;@BIT 0,H
opcode_CB_44:
	opBITH z80hl 0
;@BIT 0,L
opcode_CB_45:
	opBITL z80hl 0
;@BIT 0,(HL)
opcode_CB_46:
	readmem8HL
	opBITb 0
	fetch 12
;@BIT 0,A
opcode_CB_47:
	opBITH z80a 0

;@BIT 1,B
opcode_CB_48:
	opBITH z80bc 1
;@BIT 1,C
opcode_CB_49:
	opBITL z80bc 1
;@BIT 1,D
opcode_CB_4A:
	opBITH z80de 1
;@BIT 1,E
opcode_CB_4B:
	opBITL z80de 1
;@BIT 1,H
opcode_CB_4C:
	opBITH z80hl 1
;@BIT 1,L
opcode_CB_4D:
	opBITL z80hl 1
;@BIT 1,(HL)
opcode_CB_4E:
	readmem8HL
	opBITb 1
	fetch 12
;@BIT 1,A
opcode_CB_4F:
	opBITH z80a 1

;@BIT 2,B
opcode_CB_50:
	opBITH z80bc 2
;@BIT 2,C
opcode_CB_51:
	opBITL z80bc 2
;@BIT 2,D
opcode_CB_52:
	opBITH z80de 2
;@BIT 2,E
opcode_CB_53:
	opBITL z80de 2
;@BIT 2,H
opcode_CB_54:
	opBITH z80hl 2
;@BIT 2,L
opcode_CB_55:
	opBITL z80hl 2
;@BIT 2,(HL)
opcode_CB_56:
	readmem8HL
	opBITb 2
	fetch 12
;@BIT 2,A
opcode_CB_57:
	opBITH z80a 2

;@BIT 3,B
opcode_CB_58:
	opBITH z80bc 3
;@BIT 3,C
opcode_CB_59:
	opBITL z80bc 3
;@BIT 3,D
opcode_CB_5A:
	opBITH z80de 3
;@BIT 3,E
opcode_CB_5B:
	opBITL z80de 3
;@BIT 3,H
opcode_CB_5C:
	opBITH z80hl 3
;@BIT 3,L
opcode_CB_5D:
	opBITL z80hl 3
;@BIT 3,(HL)
opcode_CB_5E:
	readmem8HL
	opBITb 3
	fetch 12
;@BIT 3,A
opcode_CB_5F:
	opBITH z80a 3

;@BIT 4,B
opcode_CB_60:
	opBITH z80bc 4
;@BIT 4,C
opcode_CB_61:
	opBITL z80bc 4
;@BIT 4,D
opcode_CB_62:
	opBITH z80de 4
;@BIT 4,E
opcode_CB_63:
	opBITL z80de 4
;@BIT 4,H
opcode_CB_64:
	opBITH z80hl 4
;@BIT 4,L
opcode_CB_65:
	opBITL z80hl 4
;@BIT 4,(HL)
opcode_CB_66:
	readmem8HL
	opBITb 4
	fetch 12
;@BIT 4,A
opcode_CB_67:
	opBITH z80a 4

;@BIT 5,B
opcode_CB_68:
	opBITH z80bc 5
;@BIT 5,C
opcode_CB_69:
	opBITL z80bc 5
;@BIT 5,D
opcode_CB_6A:
	opBITH z80de 5
;@BIT 5,E
opcode_CB_6B:
	opBITL z80de 5
;@BIT 5,H
opcode_CB_6C:
	opBITH z80hl 5
;@BIT 5,L
opcode_CB_6D:
	opBITL z80hl 5
;@BIT 5,(HL)
opcode_CB_6E:
	readmem8HL
	opBITb 5
	fetch 12
;@BIT 5,A
opcode_CB_6F:
	opBITH z80a 5

;@BIT 6,B
opcode_CB_70:
	opBITH z80bc 6
;@BIT 6,C
opcode_CB_71:
	opBITL z80bc 6
;@BIT 6,D
opcode_CB_72:
	opBITH z80de 6
;@BIT 6,E
opcode_CB_73:
	opBITL z80de 6
;@BIT 6,H
opcode_CB_74:
	opBITH z80hl 6
;@BIT 6,L
opcode_CB_75:
	opBITL z80hl 6
;@BIT 6,(HL)
opcode_CB_76:
	readmem8HL
	opBITb 6
	fetch 12
;@BIT 6,A
opcode_CB_77:
	opBITH z80a 6

;@BIT 7,B
opcode_CB_78:
	opBIT7H z80bc
;@BIT 7,C
opcode_CB_79:
	opBIT7L z80bc
;@BIT 7,D
opcode_CB_7A:
	opBIT7H z80de
;@BIT 7,E
opcode_CB_7B:
	opBIT7L z80de
;@BIT 7,H
opcode_CB_7C:
	opBIT7H z80hl
;@BIT 7,L
opcode_CB_7D:
	opBIT7L z80hl
;@BIT 7,(HL)
opcode_CB_7E:
	readmem8HL
	opBIT7b
	fetch 12
;@BIT 7,A
opcode_CB_7F:
	opBIT7H z80a

;@RES 0,B
opcode_CB_80:
	bic z80bc,z80bc,#1<<24
	fetch 8
;@RES 0,C
opcode_CB_81:
	bic z80bc,z80bc,#1<<16
	fetch 8
;@RES 0,D
opcode_CB_82:
	bic z80de,z80de,#1<<24
	fetch 8
;@RES 0,E
opcode_CB_83:
	bic z80de,z80de,#1<<16
	fetch 8
;@RES 0,H
opcode_CB_84:
	bic z80hl,z80hl,#1<<24
	fetch 8
;@RES 0,L
opcode_CB_85:
	bic z80hl,z80hl,#1<<16
	fetch 8
;@RES 0,(HL)
opcode_CB_86:
	opRESmemHL 0
;@RES 0,A
opcode_CB_87:
	bic z80a,z80a,#1<<24
	fetch 8

;@RES 1,B
opcode_CB_88:
	bic z80bc,z80bc,#1<<25
	fetch 8
;@RES 1,C
opcode_CB_89:
	bic z80bc,z80bc,#1<<17
	fetch 8
;@RES 1,D
opcode_CB_8A:
	bic z80de,z80de,#1<<25
	fetch 8
;@RES 1,E
opcode_CB_8B:
	bic z80de,z80de,#1<<17
	fetch 8
;@RES 1,H
opcode_CB_8C:
	bic z80hl,z80hl,#1<<25
	fetch 8
;@RES 1,L
opcode_CB_8D:
	bic z80hl,z80hl,#1<<17
	fetch 8
;@RES 1,(HL)
opcode_CB_8E:
	opRESmemHL 1
;@RES 1,A
opcode_CB_8F:
	bic z80a,z80a,#1<<25
	fetch 8

;@RES 2,B
opcode_CB_90:
	bic z80bc,z80bc,#1<<26
	fetch 8
;@RES 2,C
opcode_CB_91:
	bic z80bc,z80bc,#1<<18
	fetch 8
;@RES 2,D
opcode_CB_92:
	bic z80de,z80de,#1<<26
	fetch 8
;@RES 2,E
opcode_CB_93:
	bic z80de,z80de,#1<<18
	fetch 8
;@RES 2,H
opcode_CB_94:
	bic z80hl,z80hl,#1<<26
	fetch 8
;@RES 2,L
opcode_CB_95:
	bic z80hl,z80hl,#1<<18
	fetch 8
;@RES 2,(HL)
opcode_CB_96:
	opRESmemHL 2
;@RES 2,A
opcode_CB_97:
	bic z80a,z80a,#1<<26
	fetch 8

;@RES 3,B
opcode_CB_98:
	bic z80bc,z80bc,#1<<27
	fetch 8
;@RES 3,C
opcode_CB_99:
	bic z80bc,z80bc,#1<<19
	fetch 8
;@RES 3,D
opcode_CB_9A:
	bic z80de,z80de,#1<<27
	fetch 8
;@RES 3,E
opcode_CB_9B:
	bic z80de,z80de,#1<<19
	fetch 8
;@RES 3,H
opcode_CB_9C:
	bic z80hl,z80hl,#1<<27
	fetch 8
;@RES 3,L
opcode_CB_9D:
	bic z80hl,z80hl,#1<<19
	fetch 8
;@RES 3,(HL)
opcode_CB_9E:
	opRESmemHL 3
;@RES 3,A
opcode_CB_9F:
	bic z80a,z80a,#1<<27
	fetch 8

;@RES 4,B
opcode_CB_A0:
	bic z80bc,z80bc,#1<<28
	fetch 8
;@RES 4,C
opcode_CB_A1:
	bic z80bc,z80bc,#1<<20
	fetch 8
;@RES 4,D
opcode_CB_A2:
	bic z80de,z80de,#1<<28
	fetch 8
;@RES 4,E
opcode_CB_A3:
	bic z80de,z80de,#1<<20
	fetch 8
;@RES 4,H
opcode_CB_A4:
	bic z80hl,z80hl,#1<<28
	fetch 8
;@RES 4,L
opcode_CB_A5:
	bic z80hl,z80hl,#1<<20
	fetch 8
;@RES 4,(HL)
opcode_CB_A6:
	opRESmemHL 4
;@RES 4,A
opcode_CB_A7:
	bic z80a,z80a,#1<<28
	fetch 8

;@RES 5,B
opcode_CB_A8:
	bic z80bc,z80bc,#1<<29
	fetch 8
;@RES 5,C
opcode_CB_A9:
	bic z80bc,z80bc,#1<<21
	fetch 8
;@RES 5,D
opcode_CB_AA:
	bic z80de,z80de,#1<<29
	fetch 8
;@RES 5,E
opcode_CB_AB:
	bic z80de,z80de,#1<<21
	fetch 8
;@RES 5,H
opcode_CB_AC:
	bic z80hl,z80hl,#1<<29
	fetch 8
;@RES 5,L
opcode_CB_AD:
	bic z80hl,z80hl,#1<<21
	fetch 8
;@RES 5,(HL)
opcode_CB_AE:
	opRESmemHL 5
;@RES 5,A
opcode_CB_AF:
	bic z80a,z80a,#1<<29
	fetch 8

;@RES 6,B
opcode_CB_B0:
	bic z80bc,z80bc,#1<<30
	fetch 8
;@RES 6,C
opcode_CB_B1:
	bic z80bc,z80bc,#1<<22
	fetch 8
;@RES 6,D
opcode_CB_B2:
	bic z80de,z80de,#1<<30
	fetch 8
;@RES 6,E
opcode_CB_B3:
	bic z80de,z80de,#1<<22
	fetch 8
;@RES 6,H
opcode_CB_B4:
	bic z80hl,z80hl,#1<<30
	fetch 8
;@RES 6,L
opcode_CB_B5:
	bic z80hl,z80hl,#1<<22
	fetch 8
;@RES 6,(HL)
opcode_CB_B6:
	opRESmemHL 6
;@RES 6,A
opcode_CB_B7:
	bic z80a,z80a,#1<<30
	fetch 8

;@RES 7,B
opcode_CB_B8:
	bic z80bc,z80bc,#1<<31
	fetch 8
;@RES 7,C
opcode_CB_B9:
	bic z80bc,z80bc,#1<<23
	fetch 8
;@RES 7,D
opcode_CB_BA:
	bic z80de,z80de,#1<<31
	fetch 8
;@RES 7,E
opcode_CB_BB:
	bic z80de,z80de,#1<<23
	fetch 8
;@RES 7,H
opcode_CB_BC:
	bic z80hl,z80hl,#1<<31
	fetch 8
;@RES 7,L
opcode_CB_BD:
	bic z80hl,z80hl,#1<<23
	fetch 8
;@RES 7,(HL)
opcode_CB_BE:
	opRESmemHL 7
;@RES 7,A
opcode_CB_BF:
	bic z80a,z80a,#1<<31
	fetch 8

;@SET 0,B
opcode_CB_C0:
	orr z80bc,z80bc,#1<<24
	fetch 8
;@SET 0,C
opcode_CB_C1:
	orr z80bc,z80bc,#1<<16
	fetch 8
;@SET 0,D
opcode_CB_C2:
	orr z80de,z80de,#1<<24
	fetch 8
;@SET 0,E
opcode_CB_C3:
	orr z80de,z80de,#1<<16
	fetch 8
;@SET 0,H
opcode_CB_C4:
	orr z80hl,z80hl,#1<<24
	fetch 8
;@SET 0,L
opcode_CB_C5:
	orr z80hl,z80hl,#1<<16
	fetch 8
;@SET 0,(HL)
opcode_CB_C6:
	opSETmemHL 0
;@SET 0,A
opcode_CB_C7:
	orr z80a,z80a,#1<<24
	fetch 8

;@SET 1,B
opcode_CB_C8:
	orr z80bc,z80bc,#1<<25
	fetch 8
;@SET 1,C
opcode_CB_C9:
	orr z80bc,z80bc,#1<<17
	fetch 8
;@SET 1,D
opcode_CB_CA:
	orr z80de,z80de,#1<<25
	fetch 8
;@SET 1,E
opcode_CB_CB:
	orr z80de,z80de,#1<<17
	fetch 8
;@SET 1,H
opcode_CB_CC:
	orr z80hl,z80hl,#1<<25
	fetch 8
;@SET 1,L
opcode_CB_CD:
	orr z80hl,z80hl,#1<<17
	fetch 8
;@SET 1,(HL)
opcode_CB_CE:
	opSETmemHL 1
;@SET 1,A
opcode_CB_CF:
	orr z80a,z80a,#1<<25
	fetch 8

;@SET 2,B
opcode_CB_D0:
	orr z80bc,z80bc,#1<<26
	fetch 8
;@SET 2,C
opcode_CB_D1:
	orr z80bc,z80bc,#1<<18
	fetch 8
;@SET 2,D
opcode_CB_D2:
	orr z80de,z80de,#1<<26
	fetch 8
;@SET 2,E
opcode_CB_D3:
	orr z80de,z80de,#1<<18
	fetch 8
;@SET 2,H
opcode_CB_D4:
	orr z80hl,z80hl,#1<<26
	fetch 8
;@SET 2,L
opcode_CB_D5:
	orr z80hl,z80hl,#1<<18
	fetch 8
;@SET 2,(HL)
opcode_CB_D6:
	opSETmemHL 2
;@SET 2,A
opcode_CB_D7:
	orr z80a,z80a,#1<<26
	fetch 8

;@SET 3,B
opcode_CB_D8:
	orr z80bc,z80bc,#1<<27
	fetch 8
;@SET 3,C
opcode_CB_D9:
	orr z80bc,z80bc,#1<<19
	fetch 8
;@SET 3,D
opcode_CB_DA:
	orr z80de,z80de,#1<<27
	fetch 8
;@SET 3,E
opcode_CB_DB:
	orr z80de,z80de,#1<<19
	fetch 8
;@SET 3,H
opcode_CB_DC:
	orr z80hl,z80hl,#1<<27
	fetch 8
;@SET 3,L
opcode_CB_DD:
	orr z80hl,z80hl,#1<<19
	fetch 8
;@SET 3,(HL)
opcode_CB_DE:
	opSETmemHL 3
;@SET 3,A
opcode_CB_DF:
	orr z80a,z80a,#1<<27
	fetch 8

;@SET 4,B
opcode_CB_E0:
	orr z80bc,z80bc,#1<<28
	fetch 8
;@SET 4,C
opcode_CB_E1:
	orr z80bc,z80bc,#1<<20
	fetch 8
;@SET 4,D
opcode_CB_E2:
	orr z80de,z80de,#1<<28
	fetch 8
;@SET 4,E
opcode_CB_E3:
	orr z80de,z80de,#1<<20
	fetch 8
;@SET 4,H
opcode_CB_E4:
	orr z80hl,z80hl,#1<<28
	fetch 8
;@SET 4,L
opcode_CB_E5:
	orr z80hl,z80hl,#1<<20
	fetch 8
;@SET 4,(HL)
opcode_CB_E6:
	opSETmemHL 4
;@SET 4,A
opcode_CB_E7:
	orr z80a,z80a,#1<<28
	fetch 8

;@SET 5,B
opcode_CB_E8:
	orr z80bc,z80bc,#1<<29
	fetch 8
;@SET 5,C
opcode_CB_E9:
	orr z80bc,z80bc,#1<<21
	fetch 8
;@SET 5,D
opcode_CB_EA:
	orr z80de,z80de,#1<<29
	fetch 8
;@SET 5,E
opcode_CB_EB:
	orr z80de,z80de,#1<<21
	fetch 8
;@SET 5,H
opcode_CB_EC:
	orr z80hl,z80hl,#1<<29
	fetch 8
;@SET 5,L
opcode_CB_ED:
	orr z80hl,z80hl,#1<<21
	fetch 8
;@SET 5,(HL)
opcode_CB_EE:
	opSETmemHL 5
;@SET 5,A
opcode_CB_EF:
	orr z80a,z80a,#1<<29
	fetch 8

;@SET 6,B
opcode_CB_F0:
	orr z80bc,z80bc,#1<<30
	fetch 8
;@SET 6,C
opcode_CB_F1:
	orr z80bc,z80bc,#1<<22
	fetch 8
;@SET 6,D
opcode_CB_F2:
	orr z80de,z80de,#1<<30
	fetch 8
;@SET 6,E
opcode_CB_F3:
	orr z80de,z80de,#1<<22
	fetch 8
;@SET 6,H
opcode_CB_F4:
	orr z80hl,z80hl,#1<<30
	fetch 8
;@SET 6,L
opcode_CB_F5:
	orr z80hl,z80hl,#1<<22
	fetch 8
;@SET 6,(HL)
opcode_CB_F6:
	opSETmemHL 6
;@SET 6,A
opcode_CB_F7:
	orr z80a,z80a,#1<<30
	fetch 8

;@SET 7,B
opcode_CB_F8:
	orr z80bc,z80bc,#1<<31
	fetch 8
;@SET 7,C
opcode_CB_F9:
	orr z80bc,z80bc,#1<<23
	fetch 8
;@SET 7,D
opcode_CB_FA:
	orr z80de,z80de,#1<<31
	fetch 8
;@SET 7,E
opcode_CB_FB:
	orr z80de,z80de,#1<<23
	fetch 8
;@SET 7,H
opcode_CB_FC:
	orr z80hl,z80hl,#1<<31
	fetch 8
;@SET 7,L
opcode_CB_FD:
	orr z80hl,z80hl,#1<<23
	fetch 8
;@SET 7,(HL)
opcode_CB_FE:
	opSETmemHL 7
;@SET 7,A
opcode_CB_FF:
	orr z80a,z80a,#1<<31
	fetch 8



;@##################################
;@##################################
;@###  opcodes DD  #########################
;@##################################
;@##################################
;@Because the DD opcodes are not a complete range from 00-FF I have
;@created this sub routine that will catch any undocumented ops
;@halt the emulator and mov the current instruction to r0
;@at a later stage I may change to display a text message on the screen
opcode_DD_NF:
	eatcycles 4
	ldr pc,[opcodes,r0, lsl #2]
;@	mov r2,#0x10*4
;@	cmp r2,z80xx
;@	bne opcode_FD_NF
;@	mov r0,#0xDD00
;@	orr r0,r0,r1
;@	b end_loop
;@opcode_FD_NF:
;@	mov r0,#0xFD00
;@	orr r0,r0,r1
;@	b end_loop

opcode_DD_NF2:
	fetch 23
;@ notaz: we don't want to deadlock here
;@	mov r0,#0xDD0000
;@	orr r0,r0,#0xCB00
;@	orr r0,r0,r1
;@	b end_loop

;@ADD IX,BC
opcode_DD_09:
	ldr r0,[z80xx]
	opADD16 r0 z80bc
	str r0,[z80xx]
	fetch 15
;@ADD IX,DE
opcode_DD_19:
	ldr r0,[z80xx]
	opADD16 r0 z80de
	str r0,[z80xx]
	fetch 15
;@LD IX,NN
opcode_DD_21:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	strh r0,[z80xx,#2]
	fetch 14
;@LD (NN),IX
opcode_DD_22:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r1,r0,r1, lsl #8
	ldrh r0,[z80xx,#2]
	writemem16
	fetch 20
;@INC IX
opcode_DD_23:
	ldr r0,[z80xx]
	add r0,r0,#1<<16
	str r0,[z80xx]
	fetch 10
;@INC I  (IX)
opcode_DD_24:
	ldr r0,[z80xx]
	opINC8H r0
	str r0,[z80xx]
	fetch 8
;@DEC I  (IX)
opcode_DD_25:
	ldr r0,[z80xx]
	opDEC8H r0
	str r0,[z80xx]
	fetch 8
;@LD I,N  (IX)
opcode_DD_26:
	ldrb r0,[z80pc],#1
	strb r0,[z80xx,#3]
	fetch 11
;@ADD IX,IX
opcode_DD_29:
	ldr r0,[z80xx]
	opADD16_2 r0
	str r0,[z80xx]
	fetch 15
;@LD IX,(NN)
opcode_DD_2A:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	stmfd sp!,{z80xx}
	readmem16
	ldmfd sp!,{z80xx}
	strh r0,[z80xx,#2]
	fetch 20
;@DEC IX
opcode_DD_2B:
	ldr r0,[z80xx]
	sub r0,r0,#1<<16
	str r0,[z80xx]
	fetch 10
;@INC X  (IX)
opcode_DD_2C:
	ldr r0,[z80xx]
	opINC8L r0
	str r0,[z80xx]
	fetch 8
;@DEC X  (IX)
opcode_DD_2D:
	ldr r0,[z80xx]
	opDEC8L r0
	str r0,[z80xx]
	fetch 8
;@LD X,N  (IX)
opcode_DD_2E:
	ldrb r0,[z80pc],#1
	strb r0,[z80xx,#2]
	fetch 11
;@INC (IX+N)
opcode_DD_34:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	stmfd sp!,{r0}	;@ save addr
	readmem8
	opINC8b
	ldmfd sp!,{r1}	;@ restore addr into r1
	writemem8
	fetch 23
;@DEC (IX+N)
opcode_DD_35:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	stmfd sp!,{r0}	;@ save addr
	readmem8
	opDEC8b
	ldmfd sp!,{r1}	;@ restore addr into r1
	writemem8
	fetch 23
;@LD (IX+N),N
opcode_DD_36:
	ldrsb r2,[z80pc],#1
	ldrb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r1,r1,r2, lsl #16
	mov r1,r1,lsr #16
	writemem8
	fetch 19
;@ADD IX,SP
opcode_DD_39:
	ldr r0,[z80xx]
.if FAST_Z80SP
	ldr r2,[cpucontext,#z80sp_base]
	sub r2,z80sp,r2
	opADD16s r0 r2 16
.else
	opADD16s r0 z80sp 16
.endif
	str r0,[z80xx]
	fetch 15
;@LD B,I ( IX )
opcode_DD_44:
	ldrb r0,[z80xx,#3]
	and z80bc,z80bc,#0xFF<<16
	orr z80bc,z80bc,r0, lsl #24
	fetch 8
;@LD B,X ( IX )
opcode_DD_45:
	ldrb r0,[z80xx,#2]
	and z80bc,z80bc,#0xFF<<16
	orr z80bc,z80bc,r0, lsl #24
	fetch 8
;@LD B,(IX,N)
opcode_DD_46:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	and z80bc,z80bc,#0xFF<<16
	orr z80bc,z80bc,r0, lsl #24
	fetch 19
;@LD C,I  (IX)
opcode_DD_4C:
	ldrb r0,[z80xx,#3]
	and z80bc,z80bc,#0xFF<<24
	orr z80bc,z80bc,r0, lsl #16
	fetch 8
;@LD C,X  (IX)
opcode_DD_4D:
	ldrb r0,[z80xx,#2]
	and z80bc,z80bc,#0xFF<<24
	orr z80bc,z80bc,r0, lsl #16
	fetch 8
;@LD C,(IX,N)
opcode_DD_4E:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	and z80bc,z80bc,#0xFF<<24
	orr z80bc,z80bc,r0, lsl #16
	fetch 19

;@LD D,I  (IX)
opcode_DD_54:
	ldrb r0,[z80xx,#3]
	and z80de,z80de,#0xFF<<16
	orr z80de,z80de,r0, lsl #24
	fetch 8
;@LD D,X  (IX)
opcode_DD_55:
	ldrb r0,[z80xx,#2]
	and z80de,z80de,#0xFF<<16
	orr z80de,z80de,r0, lsl #24
	fetch 8
;@LD D,(IX,N)
opcode_DD_56:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	and z80de,z80de,#0xFF<<16
	orr z80de,z80de,r0, lsl #24
	fetch 19
;@LD E,I  (IX)
opcode_DD_5C:
	ldrb r0,[z80xx,#3]
	and z80de,z80de,#0xFF<<24
	orr z80de,z80de,r0, lsl #16
	fetch 8
;@LD E,X  (IX)
opcode_DD_5D:
	ldrb r0,[z80xx,#2]
	and z80de,z80de,#0xFF<<24
	orr z80de,z80de,r0, lsl #16
	fetch 8
;@LD E,(IX,N)
opcode_DD_5E:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	and z80de,z80de,#0xFF<<24
	orr z80de,z80de,r0, lsl #16
	fetch 19
;@LD I,B  (IX)
opcode_DD_60:
	mov r0,z80bc,lsr#24
	strb r0,[z80xx,#3]
	fetch 8
;@LD I,C  (IX)
opcode_DD_61:
	mov r0,z80bc,lsr#16
	strb r0,[z80xx,#3]
	fetch 8
;@LD I,D  (IX)
opcode_DD_62:
	mov r0,z80de,lsr#24
	strb r0,[z80xx,#3]
	fetch 8
;@LD I,E  (IX)
opcode_DD_63:
	mov r0,z80de,lsr#16
	strb r0,[z80xx,#3]
	fetch 8
;@LD I,I  (IX)
opcode_DD_64:
	fetch 8
;@LD I,X  (IX)
opcode_DD_65:
	ldrb r0,[z80xx,#2]
	strb r0,[z80xx,#3]
	fetch 8
;@LD H,(IX,N)
opcode_DD_66:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	and z80hl,z80hl,#0xFF<<16
	orr z80hl,z80hl,r0, lsl #24
	fetch 19
;@LD I,A  (IX)
opcode_DD_67:
	mov r0,z80a,lsr#24
	strb r0,[z80xx,#3]
	fetch 8
;@LD X,B  (IX)
opcode_DD_68:
	mov r0,z80bc,lsr#24
	strb r0,[z80xx,#2]
	fetch 8
;@LD X,C  (IX)
opcode_DD_69:
	mov r0,z80bc,lsr#16
	strb r0,[z80xx,#2]
	fetch 8
;@LD X,D  (IX)
opcode_DD_6A:
	mov r0,z80de,lsr#24
	strb r0,[z80xx,#2]
	fetch 8
;@LD X,E  (IX)
opcode_DD_6B:
	mov r0,z80de,lsr#16
	strb r0,[z80xx,#2]
	fetch 8
;@LD X,I  (IX)
opcode_DD_6C:
	ldrb r0,[z80xx,#3]
	strb r0,[z80xx,#2]
	fetch 8
;@LD X,X  (IX)
opcode_DD_6D:
	fetch 8
;@LD L,(IX,N)
opcode_DD_6E:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	and z80hl,z80hl,#0xFF<<24
	orr z80hl,z80hl,r0, lsl #16
	fetch 19
;@LD X,A  (IX)
opcode_DD_6F:
	mov r0,z80a,lsr#24
	strb r0,[z80xx,#2]
	fetch 8

;@LD (IX,N),B
opcode_DD_70:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r1,r1,r0, lsl #16
	mov r1,r1,lsr #16
	mov r0,z80bc, lsr #24
	writemem8
	fetch 19
;@LD (IX,N),C
opcode_DD_71:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r1,r1,r0, lsl #16
	mov r1,r1,lsr #16
	mov r0,z80bc, lsr #16
	and r0,r0,#0xFF
	writemem8
	fetch 19
;@LD (IX,N),D
opcode_DD_72:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r1,r1,r0, lsl #16
	mov r1,r1,lsr #16
	mov r0,z80de, lsr #24
	writemem8
	fetch 19
;@LD (IX,N),E
opcode_DD_73:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r1,r1,r0, lsl #16
	mov r1,r1,lsr #16
	mov r0,z80de, lsr #16
	and r0,r0,#0xFF
	writemem8
	fetch 19
;@LD (IX,N),H
opcode_DD_74:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r1,r1,r0, lsl #16
	mov r1,r1,lsr #16
	mov r0,z80hl, lsr #24
	writemem8
	fetch 19
;@LD (IX,N),L
opcode_DD_75:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r1,r1,r0, lsl #16
	mov r1,r1,lsr #16
	mov r0,z80hl, lsr #16
	and r0,r0,#0xFF
	writemem8
	fetch 19
;@LD (IX,N),A
opcode_DD_77:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r1,r1,r0, lsl #16
	mov r1,r1,lsr #16
	mov r0,z80a, lsr #24
	writemem8
	fetch 19

;@LD A,I  from (IX)
opcode_DD_7C:
	ldrb r0,[z80xx,#3]
	mov z80a,r0, lsl #24
	fetch 8
;@LD A,X  from (IX)
opcode_DD_7D:
	ldrb r0,[z80xx,#2]
	mov z80a,r0, lsl #24
	fetch 8
;@LD A,(IX,N)
opcode_DD_7E:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	mov z80a,r0, lsl #24
	fetch 19

;@ADD A,I  ( IX)
opcode_DD_84:
	ldrb r0,[z80xx,#3]
	opADDb
	fetch 8
;@ADD A,X  ( IX)
opcode_DD_85:
	ldrb r0,[z80xx,#2]
	opADDb
	fetch 8
;@ADD A,(IX+N)
opcode_DD_86:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	opADDb
	fetch 19

;@ADC A,I  (IX)
opcode_DD_8C:
	ldrb r0,[z80xx,#3]
	opADCb
	fetch 8
;@ADC A,X  (IX)
opcode_DD_8D:
	ldrb r0,[z80xx,#2]
	opADCb
	fetch 8
;@ADC A,(IX+N)
opcode_DD_8E:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	opADCb
	fetch 19

;@SUB A,I  (IX)
opcode_DD_94:
	ldrb r0,[z80xx,#3]
	opSUBb
	fetch 8
;@SUB A,X  (IX)
opcode_DD_95:
	ldrb r0,[z80xx,#2]
	opSUBb
	fetch 8
;@SUB A,(IX+N)
opcode_DD_96:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	opSUBb
	fetch 19

;@SBC A,I  (IX)
opcode_DD_9C:
	ldrb r0,[z80xx,#3]
	opSBCb
	fetch 8
;@SBC A,X  (IX)
opcode_DD_9D:
	ldrb r0,[z80xx,#2]
	opSBCb
	fetch 8
;@SBC A,(IX+N)
opcode_DD_9E:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	opSBCb
	fetch 19

;@AND I  (IX)
opcode_DD_A4:
	ldrb r0,[z80xx,#3]
	opANDb
	fetch 8
;@AND X  (IX)
opcode_DD_A5:
	ldrb r0,[z80xx,#2]
	opANDb
	fetch 8
;@AND (IX+N)
opcode_DD_A6:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	opANDb
	fetch 19

;@XOR I  (IX)
opcode_DD_AC:
	ldrb r0,[z80xx,#3]
	opXORb
	fetch 8
;@XOR X  (IX)
opcode_DD_AD:
	ldrb r0,[z80xx,#2]
	opXORb
	fetch 8
;@XOR (IX+N)
opcode_DD_AE:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	opXORb
	fetch 19

;@OR I  (IX)
opcode_DD_B4:
	ldrb r0,[z80xx,#3]
	opORb
	fetch 8
;@OR X  (IX)
opcode_DD_B5:
	ldrb r0,[z80xx,#2]
	opORb
	fetch 8
;@OR (IX+N)
opcode_DD_B6:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	opORb
	fetch 19

;@CP I  (IX)
opcode_DD_BC:
	ldrb r0,[z80xx,#3]
	opCPb
	fetch 8
;@CP X  (IX)
opcode_DD_BD:
	ldrb r0,[z80xx,#2]
	opCPb
	fetch 8
;@CP (IX+N)
opcode_DD_BE:
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16
	readmem8
	opCPb
	fetch 19


opcodes_DD_CB_LOCAL: .word opcodes_DD_CB
opcode_DD_CB:
;@Looks up the opcode on the opcodes_DD_CB table and then 
;@moves the PC to the location of the subroutine
	ldrsb r0,[z80pc],#1
	ldr r1,[z80xx]
	add r0,r1,r0, lsl #16
	mov r0,r0,lsr #16

	ldrb r1,[z80pc],#1
	ldr pc,[pc,r1, lsl #2]
		.word 0x00
opcodes_DD_CB:
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_06,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_0E,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_16,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_1E,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_26,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_2E,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_36,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_3E,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_46,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_4E,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_56,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_5E,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_66,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_6E,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_76,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_7E,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_86,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_8E,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_96,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_9E,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_A6,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_AE,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_B6,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_BE,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_C6,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_CE,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_D6,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_DE,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_E6,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_EE,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_F6,opcode_DD_NF2
		.word opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_NF2,opcode_DD_CB_FE,opcode_DD_NF2

;@RLC (IX+N) 
opcode_DD_CB_06:
	stmfd sp!,{r0}		;@ save addr
	readmem8
	opRLCb
	ldmfd sp!,{r1}		;@ restore addr into r1
	writemem8
	fetch 23
;@RRC (IX+N) 
opcode_DD_CB_0E:
	stmfd sp!,{r0}		;@ save addr
	readmem8
	opRRCb
	ldmfd sp!,{r1}		;@ restore addr into r1
	writemem8
	fetch 23
;@RL (IX+N) 
opcode_DD_CB_16:
	stmfd sp!,{r0}		;@ save addr
	readmem8
	opRLb
	ldmfd sp!,{r1}		;@ restore addr into r1
	writemem8
	fetch 23
;@RR (IX+N) 
opcode_DD_CB_1E:
	stmfd sp!,{r0}		;@ save addr 
	readmem8
	opRRb
	ldmfd sp!,{r1}		;@ restore addr into r1
	writemem8
	fetch 23

;@SLA (IX+N) 
opcode_DD_CB_26:
	stmfd sp!,{r0}		;@ save addr 
	readmem8
	opSLAb
	ldmfd sp!,{r1}		;@ restore addr into r1
	writemem8
	fetch 23
;@SRA (IX+N) 
opcode_DD_CB_2E:
	stmfd sp!,{r0}		;@ save addr 
	readmem8
	opSRAb
	ldmfd sp!,{r1}		;@ restore addr into r1
	writemem8
	fetch 23
;@SLL (IX+N) 
opcode_DD_CB_36:
	stmfd sp!,{r0}		;@ save addr 
	readmem8
	opSLLb
	ldmfd sp!,{r1}		;@ restore addr into r1
	writemem8
	fetch 23
;@SRL (IX+N)
opcode_DD_CB_3E:
	stmfd sp!,{r0}		;@ save addr 
	readmem8
	opSRLb
	ldmfd sp!,{r1}		;@ restore addr into r1
	writemem8
	fetch 23

;@BIT 0,(IX+N) 
opcode_DD_CB_46:
	readmem8
	opBITb 0
	fetch 20
;@BIT 1,(IX+N) 
opcode_DD_CB_4E:
	readmem8
	opBITb 1
	fetch 20
;@BIT 2,(IX+N) 
opcode_DD_CB_56:
	readmem8
	opBITb 2
	fetch 20
;@BIT 3,(IX+N) 
opcode_DD_CB_5E:
	readmem8
	opBITb 3
	fetch 20
;@BIT 4,(IX+N) 
opcode_DD_CB_66:
	readmem8
	opBITb 4
	fetch 20
;@BIT 5,(IX+N) 
opcode_DD_CB_6E:
	readmem8
	opBITb 5
	fetch 20
;@BIT 6,(IX+N) 
opcode_DD_CB_76:
	readmem8
	opBITb 6
	fetch 20
;@BIT 7,(IX+N) 
opcode_DD_CB_7E:
	readmem8
	opBIT7b
	fetch 20
;@RES 0,(IX+N) 
opcode_DD_CB_86:
	opRESmem 0
;@RES 1,(IX+N) 
opcode_DD_CB_8E:
	opRESmem 1
;@RES 2,(IX+N) 
opcode_DD_CB_96:
	opRESmem 2
;@RES 3,(IX+N) 
opcode_DD_CB_9E:
	opRESmem 3
;@RES 4,(IX+N) 
opcode_DD_CB_A6:
	opRESmem 4
;@RES 5,(IX+N) 
opcode_DD_CB_AE:
	opRESmem 5
;@RES 6,(IX+N) 
opcode_DD_CB_B6:
	opRESmem 6
;@RES 7,(IX+N) 
opcode_DD_CB_BE:
	opRESmem 7

;@SET 0,(IX+N) 
opcode_DD_CB_C6:
	opSETmem 0
;@SET 1,(IX+N) 
opcode_DD_CB_CE:
	opSETmem 1
;@SET 2,(IX+N) 
opcode_DD_CB_D6:
	opSETmem 2
;@SET 3,(IX+N) 
opcode_DD_CB_DE:
	opSETmem 3
;@SET 4,(IX+N) 
opcode_DD_CB_E6:
	opSETmem 4
;@SET 5,(IX+N) 
opcode_DD_CB_EE:
	opSETmem 5
;@SET 6,(IX+N) 
opcode_DD_CB_F6:
	opSETmem 6
;@SET 7,(IX+N) 
opcode_DD_CB_FE:
	opSETmem 7



;@POP IX
opcode_DD_E1:
.if FAST_Z80SP
	opPOP
.else
	mov r0,z80sp
	stmfd sp!,{z80xx}
	readmem16
	ldmfd sp!,{z80xx}
	add z80sp,z80sp,#2
.endif
	strh r0,[z80xx,#2]
	fetch 14
;@EX (SP),IX
opcode_DD_E3:
.if FAST_Z80SP
	ldrb r0,[z80sp]
	ldrb r1,[z80sp,#1]
	orr r2,r0,r1, lsl #8
	ldrh r1,[z80xx,#2]
	mov r0,r1, lsr #8
	strb r0,[z80sp,#1]
	strb r1,[z80sp]
	strh r2,[z80xx,#2]
.else
	mov r0,z80sp
	stmfd sp!,{z80xx}
	readmem16
	ldmfd sp!,{z80xx}
	mov r2,r0
	ldrh r0,[z80xx,#2]
	strh r2,[z80xx,#2]
	mov r1,z80sp
	writemem16
.endif
	fetch 23
;@PUSH IX
opcode_DD_E5:
	ldr r2,[z80xx]
	opPUSHreg r2
	fetch 15
;@JP (IX)
opcode_DD_E9:
	ldrh r0,[z80xx,#2]
	rebasepc
	fetch 8
;@LD SP,IX
opcode_DD_F9:
.if FAST_Z80SP
	ldrh r0,[z80xx,#2]
	rebasesp
.else
	ldrh z80sp,[z80xx,#2]
.endif
	fetch 10

;@##################################
;@##################################
;@###  opcodes ED  #########################
;@##################################
;@##################################

opcode_ED_NF:
	fetch 8
;@	ldrb r0,[z80pc],#1
;@	ldr pc,[opcodes,r0, lsl #2]
;@	mov r0,#0xED00
;@	orr r0,r0,r1
;@	b end_loop

;@IN B,(C)
opcode_ED_40:
	opIN_C
	and z80bc,z80bc,#0xFF<<16
	orr z80bc,z80bc,r0, lsl #24
	sub r1,opcodes,#0x100
	ldrb r0,[r1,r0]
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,r0
	fetch 12
;@OUT (C),B
opcode_ED_41:
	mov r1,z80bc, lsr #24
	opOUT_C
	fetch 12

;@SBC HL,BC
opcode_ED_42:
	opSBC16 z80bc

;@LD (NN),BC
opcode_ED_43:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r1,r0,r1, lsl #8
	mov r0,z80bc, lsr #16
	writemem16
	fetch 20
;@NEG
opcode_ED_44:
	rsbs z80a,z80a,#0
	mrs z80f,cpsr
	mov z80f,z80f,lsr#28					;@S,Z,V&C
	eor z80f,z80f,#(1<<CFlag)|(1<<NFlag)	;@invert C and set n.
	tst z80a,#0x0F000000					;@H, correct
	orrne z80f,z80f,#1<<HFlag
	fetch 8
 
;@RETN, moved to ED_4D
;@opcode_ED_45:

;@IM 0
opcode_ED_46:
	strb z80a,[cpucontext,#z80im]
	fetch 8
;@LD I,A
opcode_ED_47:
	str z80a,[cpucontext,#z80i]
	fetch 9
;@IN C,(C)
opcode_ED_48:
	opIN_C
	and z80bc,z80bc,#0xFF<<24
	orr z80bc,z80bc,r0, lsl #16
	sub r1,opcodes,#0x100
	ldrb r0,[r1,r0]
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,r0
	fetch 12
;@OUT (C),C
opcode_ED_49:
	mov r0,z80bc, lsr #16
	and r1,r0,#0xFF
	opOUT
	fetch 12
;@ADC HL,BC
opcode_ED_4A:
	opADC16 z80bc
;@LD BC,(NN)
opcode_ED_4B:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	readmem16
	mov z80bc,r0, lsl #16
	fetch 20

;@RETN
opcode_ED_45:
;@RETI
opcode_ED_4D:
	ldrb r0,[cpucontext,#z80if]
	tst r0,#Z80_IF2
	orrne r0,r0,#Z80_IF1
	biceq r0,r0,#Z80_IF1
	strb r0,[cpucontext,#z80if]
    opPOP
	rebasepc
	fetch 14

;@LD R,A
opcode_ED_4F:
	mov r0,z80a,lsr#24
	strb r0,[cpucontext,#z80r]
	fetch 9

;@IN D,(C)
opcode_ED_50:
	opIN_C
	and z80de,z80de,#0xFF<<16
	orr z80de,z80de,r0, lsl #24
	sub r1,opcodes,#0x100
	ldrb r0,[r1,r0]
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,r0
	fetch 12
;@OUT (C),D
opcode_ED_51:
	mov r1,z80de, lsr #24
	opOUT_C
	fetch 12
;@SBC HL,DE
opcode_ED_52:
	opSBC16 z80de
;@LD (NN),DE
opcode_ED_53:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r1,r0,r1, lsl #8
	mov r0,z80de, lsr #16
	writemem16
	fetch 20
;@IM 1
opcode_ED_56:
	mov r0,#1
	strb r0,[cpucontext,#z80im]
	fetch 8
;@LD A,I
opcode_ED_57:
	ldr z80a,[cpucontext,#z80i]
	tst z80a,#0xFF000000
	and z80f,z80f,#(1<<CFlag)
	orreq z80f,z80f,#(1<<ZFlag)
	orrmi z80f,z80f,#(1<<SFlag)
	ldrb r0,[cpucontext,#z80if]
	tst r0,#Z80_IF2
	orrne z80f,z80f,#(1<<VFlag)
	fetch 9
;@IN E,(C)
opcode_ED_58:
	opIN_C
	and z80de,z80de,#0xFF<<24
	orr z80de,z80de,r0, lsl #16
	sub r1,opcodes,#0x100
	ldrb r0,[r1,r0]
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,r0
	fetch 12
;@OUT (C),E
opcode_ED_59:
	mov r1,z80de, lsr #16
	and r1,r1,#0xFF
	opOUT_C
	fetch 12
;@ADC HL,DE
opcode_ED_5A:
	opADC16 z80de
;@LD DE,(NN)
opcode_ED_5B:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	readmem16
	mov z80de,r0, lsl #16
	fetch 20
;@IM 2
opcode_ED_5E:
	mov r0,#2
	strb r0,[cpucontext,#z80im]
	fetch 8
;@LD A,R
opcode_ED_5F:
	ldrb r0,[cpucontext,#z80r]
	and r0,r0,#0x80
	rsb r1,z80_icount,#0
	and r1,r1,#0x7F
	orr r0,r0,r1
	movs z80a,r0, lsl #24
	and z80f,z80f,#1<<CFlag
	orrmi z80f,z80f,#(1<<SFlag)
	orreq z80f,z80f,#(1<<ZFlag)
	ldrb r0,[cpucontext,#z80if]
	tst r0,#Z80_IF2
	orrne z80f,z80f,#(1<<VFlag)
	fetch 9
;@IN H,(C)
opcode_ED_60:
	opIN_C
	and z80hl,z80hl,#0xFF<<16
	orr z80hl,z80hl,r0, lsl #24
	sub r1,opcodes,#0x100
	ldrb r0,[r1,r0]
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,r0
	fetch 12
;@OUT (C),H
opcode_ED_61:
	mov r1,z80hl, lsr #24
	opOUT_C
	fetch 12
;@SBC HL,HL
opcode_ED_62:
	opSBC16HL
;@RRD
opcode_ED_67:
	readmem8HL
	mov r1,r0,ror#4
	orr r0,r1,z80a,lsr#20
	bic z80a,z80a,#0x0F000000
	orr z80a,z80a,r1,lsr#4
	writemem8HL
	sub r1,opcodes,#0x100
	ldrb r0,[r1,z80a, lsr #24]
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,r0
	fetch 18
;@IN L,(C)
opcode_ED_68:
	opIN_C
	and z80hl,z80hl,#0xFF<<24
	orr z80hl,z80hl,r0, lsl #16
	and z80f,z80f,#1<<CFlag
	sub r1,opcodes,#0x100
	ldrb r0,[r1,r0]
	orr z80f,z80f,r0
	fetch 12
;@OUT (C),L
opcode_ED_69:
	mov r1,z80hl, lsr #16
	and r1,r1,#0xFF
	opOUT_C
	fetch 12
;@ADC HL,HL
opcode_ED_6A:
	opADC16HL
;@RLD
opcode_ED_6F:
	readmem8HL
	orr r0,r0,z80a,lsl#4
	mov r0,r0,ror#28
	and z80a,z80a,#0xF0000000
	orr z80a,z80a,r0,lsl#16
	and z80a,z80a,#0xFF000000
	writemem8HL
	sub r1,opcodes,#0x100
	ldrb r0,[r1,z80a, lsr #24]
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,r0
	fetch 18
;@IN F,(C)
opcode_ED_70:
	opIN_C
	and z80f,z80f,#1<<CFlag
	sub r1,opcodes,#0x100
	ldrb r0,[r1,r0]
	orr z80f,z80f,r0
	fetch 12
;@OUT (C),0
opcode_ED_71:
	mov r1,#0
	opOUT_C
	fetch 12

;@SBC HL,SP
opcode_ED_72:
.if FAST_Z80SP
	ldr r0,[cpucontext,#z80sp_base]
	sub r0,z80sp,r0
	mov r0, r0, lsl #16
.else
	mov r0,z80sp,lsl#16
.endif
	opSBC16 r0
;@LD (NN),SP
opcode_ED_73:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r1,r0,r1, lsl #8
.if FAST_Z80SP
	ldr r0,[cpucontext,#z80sp_base]
	sub r0,z80sp,r0
.else
	mov r0,z80sp
.endif
	writemem16
	fetch 16
;@IN A,(C)
opcode_ED_78:
	opIN_C
	mov z80a,r0, lsl #24
	and z80f,z80f,#1<<CFlag
	sub r1,opcodes,#0x100
	ldrb r0,[r1,r0]
	orr z80f,z80f,r0
	fetch 12
;@OUT (C),A
opcode_ED_79:
	mov r1,z80a, lsr #24
	opOUT_C
	fetch 12
;@ADC HL,SP
opcode_ED_7A:
.if FAST_Z80SP
	ldr r0,[cpucontext,#z80sp_base]
	sub r0,z80sp,r0
	mov r0, r0, lsl #16
.else
	mov r0,z80sp,lsl#16
.endif
	opADC16 r0
;@LD SP,(NN)
opcode_ED_7B:
	ldrb r0,[z80pc],#1
	ldrb r1,[z80pc],#1
	orr r0,r0,r1, lsl #8
	readmem16
.if FAST_Z80SP
	rebasesp
.else
	mov z80sp,r0
.endif
	fetch 20
;@LDI
opcode_ED_A0:
	copymem8HL_DE
	add z80hl,z80hl,#1<<16
	add z80de,z80de,#1<<16
	subs z80bc,z80bc,#1<<16
	bic z80f,z80f,#(1<<VFlag)|(1<<NFlag)|(1<<HFlag)
	orrne z80f,z80f,#1<<VFlag
	fetch 16
;@CPI
opcode_ED_A1:
	readmem8HL
	add z80hl,z80hl,#0x00010000
	mov r1,z80a,lsl#4
	cmp z80a,r0,lsl#24
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,#1<<NFlag
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	cmp r1,r0,lsl#28
	orrcc z80f,z80f,#1<<HFlag
	subs z80bc,z80bc,#0x00010000
	orrne z80f,z80f,#1<<VFlag
	fetch 16
;@INI
opcode_ED_A2:
	opIN_C
	and z80f,r0,#0x80
	mov z80f,z80f,lsr#2						;@NFlag set by bit 7
;@	mov r1,z80bc,lsl#8
;@	add r1,r1,#0x01000000
;@	adds r1,r1,r0,lsl#24
;@	orrcs z80f,z80f,#(1<<CFlag)|(1<<HFlag)	;@ CF & HF set if (HL) + ((C+1) & 0xFF) > 0xFF
	writemem8HL
	add z80hl,z80hl,#1<<16
	sub z80bc,z80bc,#1<<24
	tst z80bc,#0xFF<<24
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	fetch 16

;@OUTI
opcode_ED_A3:
	readmem8HL
	add z80hl,z80hl,#1<<16
	and z80f,r0,#0x80
	mov z80f,z80f,lsr#2						;@NFlag set by bit 7
	mov r1,z80hl,lsl#8
	adds r1,r1,r0,lsl#24
	orrcs z80f,z80f,#(1<<CFlag)|(1<<HFlag)	;@ CF & HF set if (HL)+L > 0xFF
	sub z80bc,z80bc,#1<<24
	tst z80bc,#0xFF<<24
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	mov r1,r0
	opOUT_C
	fetch 16

;@LDD
opcode_ED_A8:
	copymem8HL_DE
	sub z80hl,z80hl,#1<<16
	sub z80de,z80de,#1<<16
	subs z80bc,z80bc,#1<<16
	bic z80f,z80f,#(1<<VFlag)|(1<<NFlag)|(1<<HFlag)
	orrne z80f,z80f,#1<<VFlag
	fetch 16

;@CPD
opcode_ED_A9:
	readmem8HL
	sub z80hl,z80hl,#1<<16
	mov r1,z80a,lsl#4
	cmp z80a,r0,lsl#24
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,#1<<NFlag
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	cmp r1,r0,lsl#28
	orrcc z80f,z80f,#1<<HFlag
	subs z80bc,z80bc,#0x00010000
	orrne z80f,z80f,#1<<VFlag
	fetch 16

;@IND
opcode_ED_AA:
	opIN_C
	and z80f,r0,#0x80
	mov z80f,z80f,lsr#2						;@NFlag set by bit 7
;@	mov r1,z80bc,lsl#8
;@	sub r1,r1,#0x01000000
;@	adds r1,r1,r0,lsl#24
;@	orrcs z80f,z80f,#(1<<CFlag)|(1<<HFlag)	;@ CF & HF set if (HL) + ((C-1) & 0xFF) > 0xFF
	writemem8HL
	sub z80hl,z80hl,#1<<16
	sub z80bc,z80bc,#1<<24
	tst z80bc,#0xFF<<24
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	fetch 16

;@OUTD
opcode_ED_AB:
	readmem8HL
	sub z80hl,z80hl,#1<<16
	and z80f,r0,#0x80
	mov z80f,z80f,lsr#2						;@NFlag set by bit 7
	mov r1,z80hl,lsl#8
	adds r1,r1,r0,lsl#24
	orrcs z80f,z80f,#(1<<CFlag)|(1<<HFlag)	;@ CF & HF set if r0+HL > 0xFF
	sub z80bc,z80bc,#1<<24
	tst z80bc,#0xFF<<24
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	mov r1,r0
	opOUT_C
	fetch 16
;@LDIR
opcode_ED_B0:
	copymem8HL_DE
	add z80hl,z80hl,#1<<16
	add z80de,z80de,#1<<16
	subs z80bc,z80bc,#1<<16
	bic z80f,z80f,#(1<<VFlag)|(1<<NFlag)|(1<<HFlag)
	orrne z80f,z80f,#1<<VFlag
	subne z80pc,z80pc,#2
	subne z80_icount,z80_icount,#5
	fetch 16

;@CPIR
opcode_ED_B1:
	readmem8HL
	add z80hl,z80hl,#1<<16    
	mov r1,z80a,lsl#4
	cmp z80a,r0,lsl#24
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,#1<<NFlag
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	cmp r1,r0,lsl#28
	orrcc z80f,z80f,#1<<HFlag
	subs z80bc,z80bc,#1<<16
	bne opcode_ED_B1_decpc
	fetch 16
opcode_ED_B1_decpc:
	orr z80f,z80f,#1<<VFlag
	tst z80f,#1<<ZFlag
	subeq z80pc,z80pc,#2
	subeq z80_icount,z80_icount,#5
	fetch 16
;@INIR
opcode_ED_B2:
	opIN_C
	and z80f,r0,#0x80
	mov z80f,z80f,lsr#2						;@NFlag set by bit 7
;@	mov r1,z80bc,lsl#8
;@	add r1,r1,#0x01000000
;@	adds r1,r1,r0,lsl#24
;@	orrcs z80f,z80f,#(1<<CFlag)|(1<<HFlag)	;@ CF & HF set if (HL) + ((C+1) & 0xFF) > 0xFF
	writemem8HL
	add z80hl,z80hl,#1<<16
	sub z80bc,z80bc,#1<<24
	tst z80bc,#0xFF<<24
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	subne z80pc,z80pc,#2
	subne z80_icount,z80_icount,#5
	fetch 16
;@OTIR
opcode_ED_B3:
	readmem8HL
	add z80hl,z80hl,#1<<16
	and z80f,r0,#0x80
	mov z80f,z80f,lsr#2						;@NFlag set by bit 7
	mov r1,z80hl,lsl#8
	adds r1,r1,r0,lsl#24
	orrcs z80f,z80f,#(1<<CFlag)|(1<<HFlag)	;@ CF & HF set if r0+HL > 0xFF
	sub z80bc,z80bc,#1<<24
	tst z80bc,#0xFF<<24
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	subne z80pc,z80pc,#2
	subne z80_icount,z80_icount,#5
	mov r1,r0
	opOUT_C
	fetch 16
;@LDDR
opcode_ED_B8:
	copymem8HL_DE
	sub z80hl,z80hl,#1<<16
	sub z80de,z80de,#1<<16
	subs z80bc,z80bc,#1<<16
	bic z80f,z80f,#(1<<VFlag)|(1<<NFlag)|(1<<HFlag)
	orrne z80f,z80f,#1<<VFlag
	subne z80pc,z80pc,#2
	subne z80_icount,z80_icount,#5
	fetch 16

;@CPDR
opcode_ED_B9:
	readmem8HL
	sub z80hl,z80hl,#1<<16
	mov r1,z80a,lsl#4
	cmp z80a,r0,lsl#24
	and z80f,z80f,#1<<CFlag
	orr z80f,z80f,#1<<NFlag
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	cmp r1,r0,lsl#28
	orrcc z80f,z80f,#1<<HFlag
	subs z80bc,z80bc,#1<<16
	bne opcode_ED_B9_decpc
	fetch 16
opcode_ED_B9_decpc:
	orr z80f,z80f,#1<<VFlag
	tst z80f,#1<<ZFlag
	subeq z80pc,z80pc,#2
	subeq z80_icount,z80_icount,#5
	fetch 16
;@INDR
opcode_ED_BA:
	opIN_C
	and z80f,r0,#0x80
	mov z80f,z80f,lsr#2						;@NFlag set by bit 7
;@	mov r1,z80bc,lsl#8
;@	sub r1,r1,#0x01000000
;@	adds r1,r1,r0,lsl#24
;@	orrcs z80f,z80f,#(1<<CFlag)|(1<<HFlag)	;@ CF & HF set if (HL) + ((C-1) & 0xFF) > 0xFF
	writemem8HL
	sub z80hl,z80hl,#1<<16
	sub z80bc,z80bc,#1<<24
	tst z80bc,#0xFF<<24
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	subne z80pc,z80pc,#2
	subne z80_icount,z80_icount,#5
	fetch 16
;@OTDR
opcode_ED_BB:
	readmem8HL
	sub z80hl,z80hl,#1<<16
	and z80f,r0,#0x80
	mov z80f,z80f,lsr#2						;@NFlag set by bit 7
	mov r1,z80hl,lsl#8
	adds r1,r1,r0,lsl#24
	orrcs z80f,z80f,#(1<<CFlag)|(1<<HFlag)	;@ CF & HF set if r0+HL > 0xFF
	sub z80bc,z80bc,#1<<24
	tst z80bc,#0xFF<<24
	orrmi z80f,z80f,#1<<SFlag
	orreq z80f,z80f,#1<<ZFlag
	subne z80pc,z80pc,#2
	subne z80_icount,z80_icount,#5
	mov r1,r0
	opOUT_C
	fetch 16
;@##################################
;@##################################
;@###  opcodes FD  #########################
;@##################################
;@##################################
;@Since DD and FD opcodes are all the same apart from the address
;@register they use.  When a FD intruction the program runs the code
;@from the DD location but the address of the IY reg is passed instead
;@of IX

;@end_loop:
;@     b end_loop

;@ vim:filetype=armasm
#endif
