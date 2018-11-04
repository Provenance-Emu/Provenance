/*
 * assembly optimized versions of most funtions from draw2.c
 * (C) notaz, 2006-2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 *
 * this is highly specialized, be careful if changing related C code!
 */
#ifdef __arm__
.extern Pico
.extern PicoDraw2FB

@ define these constants in your include file:
@ .equiv START_ROW, 		1
@ .equiv END_ROW, 		27
@ one row means 8 pixels. If above example was used, (27-1)*8=208 lines would be rendered.
#ifndef START_ROW
#define START_ROW 0
#endif
#ifndef END_ROW
#define END_ROW 28
#endif

.text
.align 2

.global BackFillFull @ int reg7

BackFillFull:
    stmfd   sp!, {r4-r9,lr}

    ldr     lr, =PicoDraw2FB      @ lr=PicoDraw2FB
    mov     r0, r0, lsl #26
    ldr     lr, [lr]
    mov     r0, r0, lsr #26
    add     lr, lr, #328*8

    orr     r0, r0, r0, lsl #8
    orr     r0, r0, r0, lsl #16

    mov     r1, r0 @ 25 opcodes wasted?
    mov     r2, r0
    mov     r3, r0
    mov     r4, r0
    mov     r5, r0
    mov     r6, r0
    mov     r7, r0
    mov     r8, r0
    mov     r9, r0

    mov     r12, #(END_ROW-START_ROW)*8

    @ go go go!
.bff_loop:
    add     lr, lr, #8
    subs    r12, r12, #1

    stmia   lr!, {r0-r9} @ 10*4*8
    stmia   lr!, {r0-r9}
    stmia   lr!, {r0-r9}
    stmia   lr!, {r0-r9}
    stmia   lr!, {r0-r9}
    stmia   lr!, {r0-r9}
    stmia   lr!, {r0-r9}
    stmia   lr!, {r0-r9}

    bne     .bff_loop

    ldmfd   sp!, {r4-r9,r12}
    bx      r12

.pool

@ -------- some macros --------


@ helper
@ TileLineSinglecol (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r0: pixels8_old
.macro TileLineSinglecol notsinglecol=0
    and     r2, r2, #0xf        @ #0x0000000f
.if !\notsinglecol
    cmp     r2, r0, lsr #28     @ if these don't match,
    bicne   r9, r9, #2          @ it is a sign that whole tile is not singlecolor (only it's lines may be)
.endif
    orr     r4, r3, r2
    orr     r4, r4, r4, lsl #8

    tst     r1, #1              @ not aligned?
    strneb  r4, [r1], #1
    streqh  r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strneb  r4, [r1], #1        @ have a remaining unaligned pixel?
    sub     r1, r1, #8
.if !\notsinglecol
    mov     r0, #0xf
    orr     r0, r0, r2, lsl #28 @ we will need the old palindex later
.endif
.endm

@ TileNorm (r1=pdest, r2=pixels8, r3=pal) r0,r4: scratch
.macro TileLineNorm
    ands    r4, r0, r2, lsr #12 @ #0x0000f000
    orrne   r4, r3, r4
    strneb  r4, [r1]
    ands    r4, r0, r2, lsr #8  @ #0x00000f00
    orrne   r4, r3, r4
    strneb  r4, [r1,#1]
    ands    r4, r0, r2, lsr #4  @ #0x000000f0
    orrne   r4, r3, r4
    strneb  r4, [r1,#2]
    ands    r4, r0, r2          @ #0x0000000f
    orrne   r4, r3, r4
    strneb  r4, [r1,#3]
    ands    r4, r0, r2, lsr #28 @ #0xf0000000
    orrne   r4, r3, r4
    strneb  r4, [r1,#4]
    ands    r4, r0, r2, lsr #24 @ #0x0f000000
    orrne   r4, r3, r4
    strneb  r4, [r1,#5]
    ands    r4, r0, r2, lsr #20 @ #0x00f00000
    orrne   r4, r3, r4
    strneb  r4, [r1,#6]
    ands    r4, r0, r2, lsr #16 @ #0x000f0000
    orrne   r4, r3, r4
    strneb  r4, [r1,#7]
.endm

@ TileFlip (r1=pdest, r2=pixels8, r3=pal) r0,r4: scratch
.macro TileLineFlip
    ands    r4, r0, r2, lsr #16 @ #0x000f0000
    orrne   r4, r3, r4
    strneb  r4, [r1]
    ands    r4, r0, r2, lsr #20 @ #0x00f00000
    orrne   r4, r3, r4
    strneb  r4, [r1,#1]
    ands    r4, r0, r2, lsr #24 @ #0x0f000000
    orrne   r4, r3, r4
    strneb  r4, [r1,#2]
    ands    r4, r0, r2, lsr #28 @ #0xf0000000
    orrne   r4, r3, r4
    strneb  r4, [r1,#3]
    ands    r4, r0, r2          @ #0x0000000f
    orrne   r4, r3, r4
    strneb  r4, [r1,#4]
    ands    r4, r0, r2, lsr #4  @ #0x000000f0
    orrne   r4, r3, r4
    strneb  r4, [r1,#5]
    ands    r4, r0, r2, lsr #8  @ #0x00000f00
    orrne   r4, r3, r4
    strneb  r4, [r1,#6]
    ands    r4, r0, r2, lsr #12 @ #0x0000f000
    orrne   r4, r3, r4
    strneb  r4, [r1,#7]
.endm

@ Tile (r1=pdest, r3=pal, r9=prevcode, r10=Pico.vram) r2,r4,r7: scratch, r0=0xf
.macro Tile hflip vflip
    mov     r7, r9, lsl #13       @ r9=code<<8; addr=(code&0x7ff)<<4;
    add     r7, r10, r7, lsr #16
    orr     r9, r9, #3            @ emptytile=singlecolor=1, r9 must be <code_16> 00000xxx
.if \vflip
    @ we read tilecodes in reverse order if we have vflip
    add     r7, r7, #8*4
.endif
    @ loop through 8 lines
    orr     r9, r9, #(7<<24)
    b       1f @ loop_enter

0:  @ singlecol_loop
    subs    r9, r9, #(1<<24)
    add     r1, r1, #328          @ set pointer to next line
    bmi     8f @ loop_exit with r0 restore
1:
.if \vflip
    ldr     r2, [r7, #-4]!        @ pack=*(unsigned int *)(Pico.vram+addr); // Get 8 pixels
.else
    ldr     r2, [r7], #4
.endif
    tst     r2, r2
    beq     2f                    @ empty line
    bic     r9, r9, #1
    cmp     r2, r2, ror #4
    bne     3f                    @ not singlecolor
    TileLineSinglecol
    b       0b

2:
    bic     r9, r9, #2
2:  @ empty_loop
    subs    r9, r9, #(1<<24)
    add     r1, r1, #328          @ set pointer to next line
    bmi     8f @ loop_exit with r0 restore
.if \vflip
    ldr     r2, [r7, #-4]!        @ next pack
.else
    ldr     r2, [r7], #4
.endif
    mov     r0, #0xf              @ singlecol_loop might have messed r0
    tst     r2, r2
    beq     2b

    bic     r9, r9, #3            @ if we are here, it means we have empty and not empty line
    b       5f

3:  @ not empty, not singlecol
    mov     r0, #0xf
    bic     r9, r9, #3
    b       6f

4:  @ not empty, not singlecol loop
    subs    r9, r9, #(1<<24)
    add     r1, r1, #328          @ set pointer to next line
    bmi     9f @ loop_exit
.if \vflip
    ldr     r2, [r7, #-4]!        @ next pack
.else
    ldr     r2, [r7], #4
.endif
    tst     r2, r2
    beq     4b                    @ empty line
5:
    cmp     r2, r2, ror #4
    beq     7f                    @ singlecolor line
6:
.if \hflip
    TileLineFlip
.else
    TileLineNorm
.endif
    b       4b
7:
    TileLineSinglecol 1
    b       4b

8:
    mov     r0, #0xf
9:  @ loop_exit
    add     r9, r9, #(1<<24)      @ fix r9
    sub     r1, r1, #328*8        @ restore pdest pointer
.endm


@ TileLineSinglecolAl (r1=pdest, r4,r7=color)
.macro TileLineSinglecolAl0
    stmia   r1!, {r4,r7}
    add     r1, r1, #320
.endm

.macro TileLineSinglecolAl1
    strb    r4, [r1], #1
    strh    r4, [r1], #2
    str     r4, [r1], #4
    strb    r4, [r1], #1+320
@    add     r1, r1, #320
.endm

.macro TileLineSinglecolAl2
    strh    r4, [r1], #2
    str     r4, [r1], #4
    strh    r4, [r1], #2
    add     r1, r1, #320
.endm

.macro TileLineSinglecolAl3
    strb    r4, [r1], #1
    str     r4, [r1], #4
    strh    r4, [r1], #2
    strb    r4, [r1], #1+320
@    add     r1, r1, #320
.endm

@ TileSinglecol (r1=pdest, r2=pixels8, r3=pal) r4,r7: scratch, r0=0xf
@ kaligned==1, if dest is always aligned
.macro TileSinglecol kaligned=0
    and     r4, r2, #0xf       @ we assume we have good r2 from previous time
    orr     r4, r4, r3
    orr     r4, r4, r4, lsl #8
    orr     r4, r4, r4, lsl #16
    mov     r7, r4

.if !\kaligned
    tst     r1, #2             @ not aligned?
    bne     2f
    tst     r1, #1
    bne     1f
.endif

    TileLineSinglecolAl0
    TileLineSinglecolAl0
    TileLineSinglecolAl0
    TileLineSinglecolAl0
    TileLineSinglecolAl0
    TileLineSinglecolAl0
    TileLineSinglecolAl0
    TileLineSinglecolAl0

.if !\kaligned
    b       4f
1:
    TileLineSinglecolAl1
    TileLineSinglecolAl1
    TileLineSinglecolAl1
    TileLineSinglecolAl1
    TileLineSinglecolAl1
    TileLineSinglecolAl1
    TileLineSinglecolAl1
    TileLineSinglecolAl1
    b       4f

2:
    tst     r1, #1
    bne     3f

    TileLineSinglecolAl2
    TileLineSinglecolAl2
    TileLineSinglecolAl2
    TileLineSinglecolAl2
    TileLineSinglecolAl2
    TileLineSinglecolAl2
    TileLineSinglecolAl2
    TileLineSinglecolAl2
    b       4f

3:
    TileLineSinglecolAl3
    TileLineSinglecolAl3
    TileLineSinglecolAl3
    TileLineSinglecolAl3
    TileLineSinglecolAl3
    TileLineSinglecolAl3
    TileLineSinglecolAl3
    TileLineSinglecolAl3

4:
.endif
    sub     r1, r1, #328*8        @ restore pdest pointer
.endm



@ DrawLayerTiles(*hcache, *scrpos, (cells<<24)|(nametab<<9)|(vscroll&0x3ff)<<11|(shift[width]<<8)|planeend, (ymask<<24)|(planestart<<16)|[htab||hscroll]

@static void DrawLayerFull(int plane, int *hcache, int planestart, int planeend)

.global DrawLayerFull

DrawLayerFull:
    stmfd   sp!, {r4-r11,lr}

    mov     r6, r1        @ hcache

    ldr     r11, =(Pico+0x22228)  @ Pico.video
    ldr     r10, =(Pico+0x10000)  @ r10=Pico.vram
    ldrb    r5, [r11, #13]        @ pvid->reg[13]
    ldrb    r7, [r11, #11]

    sub     lr, r3, r2
    and     lr, lr, #0x00ff0000   @ lr=cells

    mov     r5, r5, lsl #10       @ htab=pvid->reg[13]<<9; (halfwords)
    add     r5, r5, r0, lsl #1    @ htab+=plane
    bic     r5, r5, #0x00ff0000   @ just in case

    tst     r7, #3                @ full screen scroll? (if ==0)
    ldrb    r7, [r11, #16]        @ ??hh??ww
    ldreqh  r5, [r10, r5]
    biceq   r5, r5, #0x0000fc00   @ r5=hscroll (0-0x3ff)
    movne   r5, r5, lsr #1
    orrne   r5, r5, #0x8000       @ this marks that we have htab pointer, not hscroll here

    and     r8, r7, #3

    orr     r5, r5, r7, lsl #1+24
    orr     r5, r5, #0x1f000000
    cmp     r8, #1
    biclt   r5, r5, #0x80000000
    biceq   r5, r5, #0xc0000000
    bicgt   r5, r5, #0xe0000000

    mov     r9, r2, lsl #24
    orr     r5, r5, r9, lsr #8    @ r5=(ymask<<24)|(trow<<16)|[htab||hscroll]

    add     r4, r8, #5
    cmp     r4, #7
    subge   r4, r4, #1            @ r4=shift[width] (5,6,6,7)

    orr     lr, lr, r4         
    orr     lr, lr, r3, lsl #24   @ lr=(planeend<<24)|(cells<<16)|shift[width]

    @ calculate xmask:
    mov     r8, r8, lsl #24+5
    orr     r8, r8, #0x1f000000

    @ Find name table:
    tst     r0, r0
    ldreqb  r4, [r11, #2]
    moveq   r4, r4, lsr #3
    ldrneb  r4, [r11, #4]
    and     r4, r4, #7
    orr     lr, lr, r4, lsl #13   @ lr|=nametab_bits{3}<<13

    ldr     r11, =PicoDraw2FB     @ r11=PicoDraw2FB
    sub     r4, r9, #(START_ROW<<24)
    ldr     r11, [r11]
    mov     r4, r4, asr #24
    mov     r7, #328*8
    mla     r11, r4, r7, r11      @ scrpos+=8*328*(planestart-START_ROW);

    @ Get vertical scroll value:
    add     r7, r10, #0x012000
    add     r7, r7,  #0x000180    @ r7=Pico.vsram (Pico+0x22180)
    ldr     r7, [r7]
    tst     r0, r0
    moveq   r7, r7, lsl #22
    movne   r7, r7, lsl #6
    mov     r7, r7, lsr #22       @ r7=vscroll (10 bits)

    orr     lr, lr, r7, lsl #3
    mov     lr, lr, ror #24       @ packed: cccccccc nnnvvvvv vvvvvsss pppppppp: cells, nametab, vscroll, shift[width], planeend

    ands    r7, r7, #7
    addne   lr, lr, #1            @ we have vertically clipped tiles due to vscroll, so we need 1 more row

    rsb     r7, r7, #8
    str     r7, [r6], #4          @ push y-offset to tilecache
    mov     r4, #328
    mla     r11, r4, r7, r11      @ scrpos+=(8-(vscroll&7))*328;

    mov     r9, #0xff000000       @ r9=(prevcode<<8)|flags: 1~tile empty, 2~tile singlecolor

.rtrloop_outer:
    mov     r4, lr, lsl #11
    mov     r4, r4, lsr #25     @ r4=vscroll>>3 (7 bits)
    add     r4, r4, r5, lsr #16 @ +trow
    and     r4, r4, r5, lsr #24 @ &=ymask
    mov     r7, lr, lsr #8
    and     r7, r7, #7          @ shift[width]
    mov     r0, lr, lsr #9
    and     r0, r0, #0x7000     @ nametab
    add     r12,r0, r4, lsl r7  @ nametab_row = nametab + (((trow+(vscroll>>3))&ymask)<<shift[width]); 

    mov     r4, lr, lsr #24
    orr     r12,r12,r4, lsl #23
    mov     r12,r12,lsl #1      @ (nametab_row|(cells<<24)) (halfword compliant)

    @ htab?
    tst     r5, #0x8000
    moveq   r7, r5, lsl #22 @ hscroll (0-3FFh)
    moveq   r7, r7, lsr #22
    beq     .rtr_hscroll_done

    @ get hscroll from htab
    mov     r7, r5, lsl #17
    ands    r4, r5, #0x00ff0000
    add     r7, r7, r4, lsl #5  @ +=trow<<4
    andne   r4, lr, #0x3800
    subne   r7, r7, r4, lsl #7  @ if(trow) htaddr-=(vscroll&7)<<1;
    mov     r7, r7, lsr #16     @ halfwords
    ldrh    r7, [r10, r7]

.rtr_hscroll_done:
    and     r8, r8, #0xff000000
    rsb     r4, r7, #0          @ r4=tilex=(-ts->hscroll)>>3
    mov     r4, r4, asr #3
    and     r4, r4, #0xff
    orr     r8, r8, r4          @ r8=(xmask<<24)|tilex

    sub     r7, r7, #1
    and     r7, r7, #7
    add     r7, r7, #1      @ r7=dx=((ts->hscroll-1)&7)+1

    cmp     r7, #8
    subeq   r12,r12, #0x01000000 @ we will loop cells+1 times, so loop less when there is no hscroll

    add     r1, r11, r7          @ r1=pdest
    mov     r0, #0xf
    b       .rtrloop_enter

    @ r4 & r7 are scratch in this loop
.rtrloop: @ 40-41 times
    add     r1, r1, #8
    subs    r12,r12, #0x01000000
    add     r8, r8, #1
    bmi     .rtrloop_exit

.rtrloop_enter:
    and     r7, r8,  r8, lsr #24
    add     r7, r10, r7, lsl #1
    bic     r4, r12, #0xff000000 @ Pico.vram[nametab_row+(tilex&xmask)];
    ldrh    r7, [r7, r4]      @ r7=code (int, but from unsigned, no sign extend)

    tst     r7, #0x8000
    bne     .rtr_hiprio

    cmp     r7, r9, lsr #8
    bne     .rtr_notsamecode
    @ we know stuff about this tile already
    tst     r9, #1
    bne     .rtrloop         @ empty tile
    tst     r9, #2
    bne     .rtr_singlecolor @ singlecolor tile
    b       .rtr_samecode

.rtr_notsamecode:
    and     r4, r9, #0x600000
    mov     r9, r7, lsl #8      @ remember new code

    @ update cram
    and     r7, r7, #0x6000
    mov     r3, r7, asr #9      @ r3=pal=((code&0x6000)>>9);

.rtr_samecode:
    tst     r9, #0x100000       @ vflip?
    bne     .rtr_vflip

    tst     r9, #0x080000       @ hflip?
    bne     .rtr_hflip

    @ Tile (r1=pdest, r3=pal, r9=prevcode, r10=Pico.vram) r2,r4,r7: scratch, r0=0xf
    Tile 0, 0
    b       .rtrloop

.rtr_hflip:
    Tile 1, 0
    b       .rtrloop

.rtr_vflip:
    tst     r9, #0x080000       @ hflip?
    bne     .rtr_vflip_hflip

    Tile 0, 1
    b       .rtrloop

.rtr_vflip_hflip:
    Tile 1, 1
    b       .rtrloop

.rtr_singlecolor:
    TileSinglecol
    b       .rtrloop

.rtr_hiprio:
    @ *(*hcache)++ = code|(dx<<16)|(trow<<27);
    sub     r4, r1, r11
    orr     r7, r7, r4, lsl #16
    and     r4, r5, #0x00ff0000
    orr     r7, r7, r4, lsl #11 @ (trow<<27)
    str     r7, [r6], #4    @ cache hi priority tile
    b       .rtrloop

.rtrloop_exit:
    add     r5, r5, #0x00010000
    mov     r4, r5, lsl #8
    cmp     r4, lr, lsl #24
    bge     .rtrloop_outer_exit
    add     r11, r11, #328*8
    b       .rtrloop_outer

.rtrloop_outer_exit:

    @ terminate cache list
    mov     r0, #0
    str     r0, [r6]    @ save cache pointer

    ldmfd   sp!, {r4-r11,lr}
    bx      lr

.pool



.global DrawTilesFromCacheF @ int *hc

DrawTilesFromCacheF:
    stmfd   sp!, {r4-r10,lr}

    mov     r9, #0xff000000 @ r9=prevcode=-1
    mvn     r6, #0          @ r6=prevy=-1

    ldr     r4, =PicoDraw2FB  @ r4=PicoDraw2FB
    ldr     r1, [r0], #4    @ read y offset
    ldr     r4, [r4]
    mov     r7, #328
    mla     r1, r7, r1, r4
    sub     r12, r1, #(328*8*START_ROW) @ r12=scrpos

    ldr     r10, =(Pico+0x10000) @ r10=Pico.vram
    mov     r8, r0               @ hc
    mov     r0, #0xf

    @ scratch: r4, r7
	@ *hcache++ = code|(dx<<16)|(trow<<27); // cache it

.dtfcf_loop:
    ldr     r7, [r8], #4    @ read code
    movs    r1, r7, lsr #16 @ r1=dx;
    ldmeqfd sp!, {r4-r10,pc} @ dx is never zero, this must be a terminator, return

    @ row changed?
    cmp     r6, r7, lsr #27
    movne   r6, r7, lsr #27
    movne   r4, #328*8
    mlane   r5, r4, r6, r12 @ r5=pd = scrpos + prevy*328*8

    bic     r1, r1, #0xf800
    add     r1, r5, r1      @ r1=pdest (halfwords)

    mov     r7, r7, lsl #16
    mov     r7, r7, lsr #16

    cmp     r7, r9, lsr #8
    bne     .dtfcf_notsamecode
    @ we know stuff about this tile already
    tst     r9, #1
    bne     .dtfcf_loop         @ empty tile
    tst     r9, #2
    bne     .dtfcf_singlecolor  @ singlecolor tile
    b       .dtfcf_samecode

.dtfcf_notsamecode:
    and     r4, r9, #0x600000
    mov     r9, r7, lsl #8      @ remember new code

    @ update cram val
    and     r7, r7, #0x6000
    mov     r3, r7, asr #9      @ r3=pal=((code&0x6000)>>9);


.dtfcf_samecode:

    tst     r9, #0x100000       @ vflip?
    bne     .dtfcf_vflip

    tst     r9, #0x080000       @ hflip?
    bne     .dtfcf_hflip

    @ Tile (r1=pdest, r3=pal, r9=prevcode, r10=Pico.vram) r2,r4,r7: scratch, r0=0xf
    Tile 0, 0
    b       .dtfcf_loop

.dtfcf_hflip:
    Tile 1, 0
    b       .dtfcf_loop

.dtfcf_vflip:
    tst     r9, #0x080000       @ hflip?
    bne     .dtfcf_vflip_hflip

    Tile 0, 1
    b       .dtfcf_loop

.dtfcf_vflip_hflip:
    Tile 1, 1
    b       .dtfcf_loop

.dtfcf_singlecolor:
    TileSinglecol
    b       .dtfcf_loop

.pool


@ @@@@@@@@@@@@@@@

@ (tile_start<<16)|row_start
.global DrawWindowFull @ int tstart, int tend, int prio

DrawWindowFull:
    stmfd   sp!, {r4-r11,lr}

    ldr     r11, =(Pico+0x22228)  @ Pico.video
    ldrb    r12, [r11, #3]        @ pvid->reg[3]
    mov     r12, r12, lsl #10

    ldr     r4, [r11, #12]
    mov     r5, #1                @ nametab_step
    tst     r4, #1                @ 40 cell mode?
    andne   r12, r12, #0xf000     @ 0x3c<<10
    andeq   r12, r12, #0xf800
    movne   r5, r5, lsl #7
    moveq   r5, r5, lsl #6        @ nametab_step

    and     r4, r0, #0xff
    mla     r12, r5, r4, r12      @ nametab += nametab_step*start;

    mov     r4, r0, lsr #16       @ r4=start_cell_h
    add     r7, r12, r4, lsl #1

    @ fetch the first code now
    ldr     r10, =(Pico+0x10000)  @ lr=Pico.vram
    ldrh    r7, [r10, r7]
    cmp     r2, r7, lsr #15
    ldmnefd sp!, {r4-r11,pc}      @ hack: simply assume that whole window uses same priority

    rsb     r8, r4, r1, lsr #16   @ cells (h)
    orr     r8, r8, r4, lsl #8
    mov     r4, r1, lsl #24
    sub     r4, r4, r0, lsl #24
    orr     r8, r8, r4, lsr #8    @ r8=cells_h|(start_cell_h<<8)|(cells_v<<16)
    sub     r8, r8, #0x010000     @ adjust for algo

    mov     r9, #0xff000000       @ r9=prevcode=-1

    ldr     r11, =PicoDraw2FB     @ r11=scrpos
    and     r4, r0, #0xff
    ldr     r11, [r11]
    sub     r4, r4, #START_ROW
    add     r11, r11, #328*8
    add     r11, r11, #8

    mov     r7, #328*8
    mla     r11, r7, r4, r11      @ scrpos+=8*328*(start-START_ROW);
    mov     r0, #0xf

.dwfloop_outer:
    and     r6, r8, #0xff00       @ r6=tilex
    add     r1, r11, r6, lsr #5   @ r1=pdest
    add     r6, r12, r6, lsr #7
    add     r6, r10, r6           @ r6=Pico.vram+nametab+tilex
    orr     r8, r8, r8, lsl #24
    sub     r8, r8, #0x01000000   @ cell loop counter
    b       .dwfloop_enter

    @ r4 & r7 are scratch in this loop
.dwfloop:
    add     r1, r1, #8
    subs    r8, r8, #0x01000000
    bmi     .dwfloop_exit

.dwfloop_enter:
    ldrh    r7, [r6], #2      @ r7=code

    cmp     r7, r9, lsr #8
    bne     .dwf_notsamecode
    @ we know stuff about this tile already
    tst     r9, #1
    bne     .dwfloop         @ empty tile
    tst     r9, #2
    bne     .dwf_singlecolor @ singlecolor tile
    b       .dwf_samecode

.dwf_notsamecode:
    and     r4, r9, #0x600000
    mov     r9, r7, lsl #8      @ remember new code

    @ update cram val
    and     r7, r7, #0x6000
    mov     r3, r7, asr #9      @ r3=pal=((code&0x6000)>>9);

.dwf_samecode:

    tst     r9, #0x100000       @ vflip?
    bne     .dwf_vflip

    tst     r9, #0x080000       @ hflip?
    bne     .dwf_hflip

    @ Tile (r1=pdest, r3=pal, r9=prevcode, r10=Pico.vram) r2,r4,r7: scratch, r0=0xf
    Tile 0, 0
    b       .dwfloop

.dwf_hflip:
    Tile 1, 0
    b       .dwfloop

.dwf_vflip:
    tst     r9, #0x080000       @ hflip?
    bne     .dwf_vflip_hflip

    Tile 0, 1
    b       .dwfloop

.dwf_vflip_hflip:
    Tile 1, 1
    b       .dwfloop

.dwf_singlecolor:
    TileSinglecol 1
    b       .dwfloop

.dwfloop_exit:
    bic     r8, r8, #0xff000000  @ fix r8
    subs    r8, r8, #0x010000
    ldmmifd sp!, {r4-r11,pc}
    add     r11, r11, #328*8
    add     r12, r12, r5         @ nametab+=nametab_step
    b       .dwfloop_outer

.pool


@ ---------------- sprites ---------------

.macro SpriteLoop hflip vflip
.if \vflip
    mov     r1, r5, lsr #24       @ height
    mov     r0, #328*8
    mla     r11, r1, r0, r11      @ scrpos+=height*328*8;
    add     r12, r12, r1, lsl #3  @ sy+=height*8
.endif
    mov     r0, #0xf
.if \hflip
    and     r1, r5, #0xff
    add     r8, r8, r1, lsl #3    @ sx+=width*8
58:
    cmp     r8, #336
    blt     51f
    add     r9, r9, r5, lsr #16
    sub     r5, r5, #1            @ sub width
    sub     r8, r8, #8
    b       58b
.else
    cmp     r8, #0                @ skip tiles hidden on the left of screen
    bgt     51f
58:
    add     r9, r9, r5, lsr #16
    sub     r5, r5, #1
    adds    r8, r8, #8
    ble     58b
    b       51f
.endif

50: @ outer
.if !\hflip
    add     r8, r8, #8          @ sx+=8
.endif
    bic     r5, r5, #0xff000000 @ fix height
    orr     r5, r5, r5, lsl #16

51: @ outer_enter
    sub     r5, r5, #1          @ width--
    movs    r1, r5, lsl #24
    ldmmifd sp!, {r4-r11,pc}    @ end of tile
.if \hflip
    subs    r8, r8, #8          @ sx-=8
    ldmlefd sp!, {r4-r11,pc}    @ tile offscreen
.else
    cmp     r8, #328
    ldmgefd sp!, {r4-r11,pc}    @ tile offscreen
.endif
    mov     r6, r12             @ r6=sy
    add     r1, r11, r8         @ pdest=scrpos+sx
    b       53f

52: @ inner
    add     r9, r9, #1<<8       @ tile++
.if !\vflip
    add     r6, r6, #8          @ sy+=8
    add     r1, r1, #328*8
.endif

53: @ inner_enter
    @ end of sprite?
    subs    r5, r5, #0x01000000
    bmi     50b                 @ ->outer
.if \vflip
    sub     r6, r6, #8          @ sy-=8
    sub     r1, r1, #328*8
.endif

    @ offscreen?
    cmp     r6, #(START_ROW*8)
    ble     52b

    cmp     r6, #(END_ROW*8+8)
    bge     52b

    @ Tile (r1=pdest, r3=pal, r9=prevcode, r10=Pico.vram) r2,r4,r7: scratch, r0=0xf
    Tile \hflip, \vflip
    b       52b
.endm


.global DrawSpriteFull @ unsigned int *sprite

DrawSpriteFull:
    stmfd   sp!, {r4-r11,lr}

    ldr     r3, [r0]        @ sprite[0]
    mov     r5, r3, lsl #4
    mov     r6, r5, lsr #30
    add     r6, r6, #1      @ r6=width
    mov     r5, r5, lsl #2
    mov     r5, r5, lsr #30
    add     r5, r5, #1      @ r5=height

    mov     r12, r3,  lsl #23
    mov     r12, r12, lsr #23

    ldr     lr, [r0, #4]    @ lr=code
    sub     r12, r12, #0x78 @ r12=sy
    mov     r8, lr, lsl #7
    mov     r8, r8, lsr #23
    sub     r8, r8, #0x78   @ r8=sx

    mov     r9, lr, lsl #21
    mov     r9, r9, lsr #13 @ r9=tile<<8

    and     r3, lr, #0x6000
    mov     r3, r3, lsr #9  @ r3=pal=((code>>9)&0x30);

    ldr     r11, =PicoDraw2FB     @ r11=scrpos
    ldr     r10, =(Pico+0x10000)  @ r10=Pico.vram
    ldr     r11, [r11]
    sub     r1, r12, #(START_ROW*8)
    mov     r0, #328
    mla     r11, r1, r0, r11      @ scrpos+=(sy-START_ROW*8)*328;

    orr     r5, r5, r5, lsl #16   @
    orr     r5, r6, r5, lsl #8    @ r5=width|(height<<8)|(height<<24)

    tst     lr, #0x1000         @ vflip?
    bne     .dsf_vflip

    tst     lr, #0x0800         @ hflip?
    bne     .dsf_hflip

    SpriteLoop 0, 0

.dsf_hflip:
    SpriteLoop 1, 0

.dsf_vflip:
    tst     lr, #0x0800         @ hflip?
    bne     .dsf_vflip_hflip

    SpriteLoop 0, 1

.dsf_vflip_hflip:
    SpriteLoop 1, 1

.pool

@ vim:filetype=armasm
#endif
