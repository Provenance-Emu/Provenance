/*
 * assembly optimized versions of most funtions from draw.c
 * (C) notaz, 2006-2010,2017
 * (C) irixxxx, 2020-2024
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 *
 * this is highly specialized, be careful if changing related C code!
 *
 * NB only does RGB565 output, BGR isn't supported
 */

#include "pico_int_offs.h"

.extern DrawStripInterlace

.equ PDRAW_WND_DIFF_PRIO, (1<<1)
.equ PDRAW_PLANE_HI_PRIO, (1<<6)
.equ PDRAW_SHHI_DONE,     (1<<7)
.equ PDRAW_BORDER_32,     (1<<9)
.equ PDRAW_32X_SCALE,     (1<<12)
.equ PDRAW_BGC_DMA,       (1<<14)
.equ PDRAW_SOFTSCALE,     (1<<15)

@ helpers
.macro add_c24 d s c
    add     \d, \s, #(\c & 0x00ff00)
.if \c & 0x0000ff
    add     \d, \d, #(\c & 0x0000ff)
.endif
.if \c & 0xff0000
    add     \d, \d, #(\c & 0xff0000)
.endif
.endm

.macro TilePixel pat lsrr offs
.if !\lsrr
    ands    r4, \pat, r2
.else
    ands    r4, \pat, r2, lsr #\lsrr
.endif
    orrne   r4, r3, r4
    strneb  r4, [r1,#\offs]
.endm

@ TileNorm (r1=pdest, r2=pixels8, r3=pal) r4: scratch, pat: register with helper pattern 0xf
.macro TileNorm pat
    TilePixel \pat, 12, 0         @ #0x0000f000
    TilePixel \pat,  8, 1         @ #0x00000f00
    TilePixel \pat,  4, 2         @ #0x000000f0
    TilePixel \pat,  0, 3         @ #0x0000000f
    TilePixel \pat, 28, 4         @ #0xf0000000
    TilePixel \pat, 24, 5         @ #0x0f000000
    TilePixel \pat, 20, 6         @ #0x00f00000
    TilePixel \pat, 16, 7         @ #0x000f0000
.endm

@ TileFlip (r1=pdest, r2=pixels8, r3=pal) r4: scratch, pat: register with helper pattern 0xf
.macro TileFlip pat
    TilePixel \pat, 16, 0         @ #0x000f0000
    TilePixel \pat, 20, 1         @ #0x00f00000
    TilePixel \pat, 24, 2         @ #0x0f000000
    TilePixel \pat, 28, 3         @ #0xf0000000
    TilePixel \pat,  0, 4         @ #0x0000000f
    TilePixel \pat,  4, 5         @ #0x000000f0
    TilePixel \pat,  8, 6         @ #0x00000f00
    TilePixel \pat, 12, 7         @ #0x0000f000
.endm

@ shadow/hilight mode

@ 
.macro TilePixelNonSH pat lsrr offs
.if !\lsrr
    ands    r4, \pat, r2
.else
    ands    r4, \pat, r2, lsr #\lsrr
.endif
    beq     0f
    cmp     r4, #0xe
    orr     r4, r3, r4
    biceq   r4, r4, #0x80
    strb    r4, [r1,#\offs]
0:
.endm

@ TileNormNonSH (r1=pdest, r2=pixels8, r3=pal) r4: scratch, pat: register with helper pattern 0xf
.macro TileNormNonSH pat
    TilePixelNonSH \pat, 12, 0    @ #0x0000f000
    TilePixelNonSH \pat,  8, 1    @ #0x00000f00
    TilePixelNonSH \pat,  4, 2    @ #0x000000f0
    TilePixelNonSH \pat,  0, 3    @ #0x0000000f
    TilePixelNonSH \pat, 28, 4    @ #0xf0000000
    TilePixelNonSH \pat, 24, 5    @ #0x0f000000
    TilePixelNonSH \pat, 20, 6    @ #0x00f00000
    TilePixelNonSH \pat, 16, 7    @ #0x000f0000
.endm

@ TileFlipNonSH (r1=pdest, r2=pixels8, r3=pal) r4: scratch, pat: register with helper pattern 0xf
.macro TileFlipNonSH pat
    TilePixelNonSH \pat, 16, 0    @ #0x000f0000
    TilePixelNonSH \pat, 20, 1    @ #0x00f00000
    TilePixelNonSH \pat, 24, 2    @ #0x0f000000
    TilePixelNonSH \pat, 28, 3    @ #0xf0000000
    TilePixelNonSH \pat,  0, 4    @ #0x0000000f
    TilePixelNonSH \pat,  4, 5    @ #0x000000f0
    TilePixelNonSH \pat,  8, 6    @ #0x00000f00
    TilePixelNonSH \pat, 12, 7    @ #0x0000f000
.endm

@ this one is for hi priority layer
.macro TilePixelShHP lsrr offs
.if !\lsrr
    ands    r4, r12, r2
.else
    ands    r4, r12, r2, lsr #\lsrr
.endif
    ldreqb  r4, [r1,#\offs]
    orrne   r4, r3, r4
    andeq   r4, r4, #0x7f
    strb    r4, [r1,#\offs]
.endm

@ TileNormShHP (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r12: register with helper pattern 0xf, touches r3 high bits
.macro TileNormShHP
    TilePixelShHP 12, 0         @ #0x0000f000
    TilePixelShHP  8, 1         @ #0x00000f00
    TilePixelShHP  4, 2         @ #0x000000f0
    TilePixelShHP  0, 3         @ #0x0000000f
    TilePixelShHP 28, 4         @ #0xf0000000
    TilePixelShHP 24, 5         @ #0x0f000000
    TilePixelShHP 20, 6         @ #0x00f00000
    TilePixelShHP 16, 7         @ #0x000f0000
.endm

@ TileFlipShHP (r1=pdest, r2=pixels8, r3=pal) r4: scratch, pat: register with helper pattern 0xf
.macro TileFlipShHP
    TilePixelShHP 16, 0         @ #0x000f0000
    TilePixelShHP 20, 1         @ #0x00f00000
    TilePixelShHP 24, 2         @ #0x0f000000
    TilePixelShHP 28, 3         @ #0xf0000000
    TilePixelShHP  0, 4         @ #0x0000000f
    TilePixelShHP  4, 5         @ #0x000000f0
    TilePixelShHP  8, 6         @ #0x00000f00
    TilePixelShHP 12, 7         @ #0x0000f000
.endm


@ TileSingleSh (r1=pdest, r2=pixels8, r3=pal) r4,r7: scratch, r0=sx; r12: helper pattern 0xf
.macro TileSingleSh
    tst     r0, #1              @ not aligned?
    mov     r7, #0x008000
    orr     r7, r7, #0x80
    ldrneb  r4,  [r1], #1
    ldreqh  r4,  [r1], #2        @ 1ci
    ldrh    r12, [r1], #2
    orr     r4,  r4,  r7
    strneb  r4,  [r1, #-3]
    streqh  r4,  [r1, #-4]
    ldrh    r4,  [r1], #2
    orr     r12, r12, r7
    strh    r12, [r1, #-4]
    ldrh    r12, [r1], #2
    orr     r4,  r4,  r7
    strh    r4,  [r1, #-4]
    ldrneb  r4,  [r1]
    orr     r12, r12, r7
    strh    r12, [r1, #-2]
    orrne   r4,  r4,  r7
    strneb  r4,  [r1], #1
    mov     r12, #0xf
.endm

@ TileSingleHi (r1=pdest, r2=pixels8, r3=pal) r4,r7: scratch, r0=sx, r12: register with helper pattern 0xf
.macro TileSingleHi
    tst     r1,  #1              @ not aligned?
    mov     r7,  #0x004000
    orr     r7,  r7, #0x40
    ldrneb  r4,  [r1], #1
    ldreqh  r4,  [r1], #2        @ 1ci
    ldrh    r12, [r1], #2
    orr     r4,  r4,  r7
    strneb  r4,  [r1, #-3]
    streqh  r4,  [r1, #-4]
    ldrh    r4,  [r1], #2
    orr     r12, r12, r7
    strh    r12, [r1, #-4]
    ldrh    r12, [r1], #2
    orr     r4,  r4,  r7
    strh    r4,  [r1, #-4]
    ldrneb  r4,  [r1]
    orr     r12, r12, r7
    strh    r12, [r1, #-2]
    orrne   r4,  r4,  r7
    strneb  r4,  [r1], #1
    mov     r12, #0xf
.endm

.macro TileDoShGenPixel shift ofs
.if \shift
    ands    r4, r12, r2, lsr #\shift
.else
    ands    r4, r12, r2
.endif
    beq     0f
    cmp     r4, #0xe
    ldrgeb  r7, [r1,#\ofs]
    orrlt   r7, r3, r4            @ normal

    subge   r4, r4, #1
    orrge   r7, r7, r4, lsl #6
    strb    r7, [r1,#\ofs]
0:
.endm

@ TileFlipSh (r1=pdest, r2=pixels8, r3=pal) r4,r7: scratch, r0=sx, r12: register with helper pattern 0xf
.macro TileFlipSh
    TileDoShGenPixel 16,  0 @ #0x000f0000
    TileDoShGenPixel 20,  1 @ #0x00f00000
    TileDoShGenPixel 24,  2 @ #0x0f000000
    TileDoShGenPixel 28,  3 @ #0xf0000000
    TileDoShGenPixel  0,  4 @ #0x0000000f
    TileDoShGenPixel  4,  5 @ #0x000000f0
    TileDoShGenPixel  8,  6 @ #0x00000f00
    TileDoShGenPixel 12,  7 @ #0x0000f000
.endm

@ TileNormSh (r1=pdest, r2=pixels8, r3=pal) r4,r7: scratch, r0=sx, r12: register with helper pattern 0xf
.macro TileNormSh
    TileDoShGenPixel 12,  0 @ #0x0000f000
    TileDoShGenPixel  8,  1 @ #0x00000f00
    TileDoShGenPixel  4,  2 @ #0x000000f0
    TileDoShGenPixel  0,  3 @ #0x0000000f
    TileDoShGenPixel 28,  4 @ #0xf0000000
    TileDoShGenPixel 24,  5 @ #0x0f000000
    TileDoShGenPixel 20,  6 @ #0x00f00000
    TileDoShGenPixel 16,  7 @ #0x000f0000
.endm

.macro TileDoShGenPixel_markop shift ofs
.if \shift
    ands    r4, r12, r2, lsr #\shift
.else
    ands    r4, r12, r2
.endif
    beq     0f
    cmp     r4, #0xe
    ldrgeb  r4, [r1,#\ofs]
    orrlt   r4, r3, r4
    orrge   r4, r4, #0x40
    strb    r4, [r1,#\ofs]
0:
.endm

.macro TileFlipSh_markop
    TileDoShGenPixel_markop 16,  0 @ #0x000f0000
    TileDoShGenPixel_markop 20,  1 @ #0x00f00000
    TileDoShGenPixel_markop 24,  2 @ #0x0f000000
    TileDoShGenPixel_markop 28,  3 @ #0xf0000000
    TileDoShGenPixel_markop  0,  4 @ #0x0000000f
    TileDoShGenPixel_markop  4,  5 @ #0x000000f0
    TileDoShGenPixel_markop  8,  6 @ #0x00000f00
    TileDoShGenPixel_markop 12,  7 @ #0x0000f000
.endm

.macro TileNormSh_markop
    TileDoShGenPixel_markop 12,  0 @ #0x0000f000
    TileDoShGenPixel_markop  8,  1 @ #0x00000f00
    TileDoShGenPixel_markop  4,  2 @ #0x000000f0
    TileDoShGenPixel_markop  0,  3 @ #0x0000000f
    TileDoShGenPixel_markop 28,  4 @ #0xf0000000
    TileDoShGenPixel_markop 24,  5 @ #0x0f000000
    TileDoShGenPixel_markop 20,  6 @ #0x00f00000
    TileDoShGenPixel_markop 16,  7 @ #0x000f0000
.endm

.macro TileDoShGenPixel_onlyop_lp shift ofs
.if \shift
    ands    r7, r12, r2, lsr #\shift
.else
    ands    r7, r12, r2
.endif
    ldrneb  r4, [r1,#\ofs]
    cmp     r7, #0xe
    blt     0f

    tst     r4, #0x40
    bicne   r4, r4, #0x40
    subne   r7, r7, #1
    orrne   r4, r4, r7, lsl #6
    strneb  r4, [r1,#\ofs]
0:
.endm

.macro TileFlipSh_onlyop_lp
    TileDoShGenPixel_onlyop_lp 16,  0 @ #0x000f0000
    TileDoShGenPixel_onlyop_lp 20,  1 @ #0x00f00000
    TileDoShGenPixel_onlyop_lp 24,  2 @ #0x0f000000
    TileDoShGenPixel_onlyop_lp 28,  3 @ #0xf0000000
    TileDoShGenPixel_onlyop_lp  0,  4 @ #0x0000000f
    TileDoShGenPixel_onlyop_lp  4,  5 @ #0x000000f0
    TileDoShGenPixel_onlyop_lp  8,  6 @ #0x00000f00
    TileDoShGenPixel_onlyop_lp 12,  7 @ #0x0000f000
.endm

.macro TileNormSh_onlyop_lp
    TileDoShGenPixel_onlyop_lp 12,  0 @ #0x0000f000
    TileDoShGenPixel_onlyop_lp  8,  1 @ #0x00000f00
    TileDoShGenPixel_onlyop_lp  4,  2 @ #0x000000f0
    TileDoShGenPixel_onlyop_lp  0,  3 @ #0x0000000f
    TileDoShGenPixel_onlyop_lp 28,  4 @ #0xf0000000
    TileDoShGenPixel_onlyop_lp 24,  5 @ #0x0f000000
    TileDoShGenPixel_onlyop_lp 20,  6 @ #0x00f00000
    TileDoShGenPixel_onlyop_lp 16,  7 @ #0x000f0000
.endm


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

@ struct TileStrip
@ {
@   int nametab; // 0x00
@   int line;    // 0x04
@   int hscroll; // 0x08
@   int xmask;   // 0x0C
@   int *hc;     // 0x10 (pointer to cache buffer)
@   int cells;   // 0x14
@ };

@ void DrawLayer(int lflags, int *hcache, int cellskip, int maxcells,
@                struct PicoEState *est)

.global DrawLayer

DrawLayer:
    ldr     r12, [sp]             @ est
    stmfd   sp!, {r4-r11,lr}

    ldr     r11, [r12, #OFS_EST_Pico]
    mov     r8, #1

    ldrb    r7, [r11, #OFS_Pico_video_reg+16] @ ??vv??hh

    mov     r6, r1                @ hcache
    orr     r9, r3, r0, lsl #29   @ r9=force[31]|sh[30]|plane[29]
    orr     r9, r9, r2, lsl #8    @    |cellskip[15:8]|maxcells[7:0]  (tmp)

    mov     r1, r7, lsl #4
    orr     r1, r1, #0x00ff

    and     r10, r7,  #3
    cmp     r10, #1
    biclt   r1,  r1, #0xfc00
    biceq   r1,  r1, #0xfe00
    cmp     r10, #2
    moveq   r1,      #0x0007
    movgt   r1,      #0x00ff      @ r1=ymask=(height<<8)|0xff; ...; // Y Mask in pixels

    cmp     r10, #2
    addlt   r10, r10, #5
    moveq   r10, #5
    movgt   r10, #7               @ r10=shift[width] (5,6,5,7)

    ldr     r2, [r12, #OFS_EST_DrawScanline]
    ldr     lr, [r12, #OFS_EST_PicoMem_vram]

    @ Find name table:
    ands    r0,  r0, #1
    ldreqb  r12, [r11, #OFS_Pico_video_reg+2]
    ldrneb  r12, [r11, #OFS_Pico_video_reg+4]

    @ calculate xmask:
    mov     r5, r8, lsl r10
    sub     r5, r5, #1            @ r5=xmask

    moveq   r12, r12, lsl #10
    movne   r12, r12, lsl #13
    and     r12, r12, #(7<<13)    @ r12=(ts->nametab<<1) (halfword compliant)

    ldrh    r8, [r11, #OFS_Pico_video_reg+12]
    ldrb    r7, [r11, #OFS_Pico_video_reg+11]

    mov     r4, r8, lsr #8        @ pvid->reg[13]
    mov     r4, r4, lsl #10       @ htab=pvid->reg[13]<<9; (halfwords)

    ands    r3, r7, #0x03
    beq     0f
    cmp     r3, #2
    mov     r3, r2, lsl #2        @ htab+=DrawScanline<<1; // Offset by line
    biceq   r3, r3, #0x1f         @ htab&=~0xf; // Offset by tile
    andlt   r3, r3, #0x1f
    add     r4, r4, r3
0:  add     r4, r4, r0, lsl #1    @ htab+=plane
    bic     r4, r4, #0x00ff0000   @ just in case
    ldrh    r3, [lr, r4]          @ r3=hscroll

    tst     r7, #4
    bne     .DrawStrip_vsscroll

    @ Get vertical scroll value:
    add_c24 r7, lr, (OFS_PMEM_vsram-OFS_PMEM_vram)
    ldr     r7, [r7]

    tst     r8, #2
    tstne   r8, #4
    bne     .DrawStrip_interlace

    tst     r0, r0
    moveq   r7, r7, lsl #16
    mov     r7, r7, lsr #16

    @ Find the line in the name table
    add     r2, r2, r7
    and     r2, r2, r1
    mov     r4, r2, lsr #3
    add     r10, r10, #1           @ shift[width]++
    add     r12, r12, r4, lsl r10  @ nametab+=(ts.line>>3)<<shift[width];

    @ ldmia   r0, {r1,r2,r3,r5,r6,r9} @ r2=line, r3=ts->hscroll, r5=ts->xmask, r6=ts->hc, r9=ts->cells

    and     r10,r2,  #7
    mov     r10,r10, lsl #1 @ r10=ty=(ts->line&7)<<1;
    orr     r10,r10, r9, lsl #24

    rsb     r8, r3, #0
    mov     r8, r8, lsr #3  @ r8=tilex=(-ts->hscroll)>>3

    sub     r1, r3, #1
    and     r1, r1, #7
    add     r7, r1, #1      @ r7=dx=((ts->hscroll-1)&7)+1

    movs    r3, r9, lsl #1  @ (force[31]|sh[30]) << 1
    mov     r3, #0
    orrmi   r10,r10, #1<<23 @ r10=cells[31:24]|sh[23]|hi_not_empty[22]
@    orrcc   r10,r10, #1<<20 @   |had_output[21]|!force[20]|hscroll[18:16]|ty[15:0]
    movmi   r3, #0x80       @ default to shadowed pal on sh mode

    and     r4, r7, #7
    orr     r10,r10, r4, lsl #16 @ we will process cells+1 if there is scroll

    and     r9, r9, #0xff00
    add     r8, r8, r9, lsr #8   @ tilex+=cellskip
    add     r7, r7, r9, lsr #5   @ dx+=cellskip<<3;
    sub     r10,r10,r9, lsl #16  @ cells-=cellskip

    @ cache some stuff to avoid mem access
    ldr     r11,[sp, #9*4]       @ est
    mov     r0, #0xf
    ldr     r11,[r11, #OFS_EST_HighCol]

    mvn     r9, #0               @ r9=prevcode=-1
    add     r1, r11, r7          @ r1=pdest

    @ r10=cells[31:24]|sh[23]|hi_not_empty[22]|had_output[21]|!force[20]|hscroll[18:16]|ty[15:0]
    @ r1=pd+dx r2=pack r3=pal r5=xmask r6=hc r8=tilex r9=prevcode r11=HighCol r12=nametab lr=vram
    @ r4 & r7 are scratch in this loop

    ands    r4, r10, #7<<16  @ hscroll?
    beq     .dsloop_subr1
    subs    r10,r10, #0x01000000
    bmi     .dsloop_exit

    and     r7, r5, r8         @ do first cut tile
    add     r7, lr, r7, lsl #1 @ Pico.vram+((tilex&ts->xmask) as halfwords)
    ldrh    r9, [r7, r12]      @ r7=code (int, but from unsigned, no sign extend)

    add     r8, r8, #1

    tst     r9, #0x1000     @ if (code&0x1000)
    mov     r2, r9, lsl #21
    add     r2, r2, r10, lsl #17
    eorne   r2, r2, #0xe<<17 @ if (code&0x1000) addr^=0xe;

    ldr     r2, [lr, r2, lsr #16] @ pack=*(unsigned int *)(Pico.vram+addr); // Get 8 pixels

    mvn     r7, #0
    mov     r4, r4, lsr #16-2  @ (dx&7)*4
    tst     r9, #0x0800
    moveq   r7, r7, lsl r4     @ mask = ~0 [shift] (dx&7)*4
    movne   r7, r7, lsr r4
    bic     r2, r2, r7, ror #16 @ pack&~mask

    orr     r9, r9, #0x80000000 @ invalidate oldcode since pack is masked
    b       .DrawStrip_samecode

.dsloop_subr1:
    sub     r1, r1, #8
.dsloop: @ 40-41 times
    subs    r10,r10, #0x01000000
    bmi     .dsloop_exit

    and     r7, r5, r8
    add     r7, lr, r7, lsl #1 @ Pico.vram+((tilex&ts->xmask) as halfwords)
    ldrh    r7, [r7, r12]      @ r7=code (int, but from unsigned, no sign extend)

    add     r1, r1, #8
    add     r8, r8, #1

    cmp     r7, r9
    beq     .DrawStrip_samecode @ we know stuff about this tile already

    mov     r9, r7          @ remember code

    tst     r9, #0x1000     @ if (code&0x1000)
    mov     r2, r9, lsl #21
    add     r2, r2, r10, lsl #17
    eorne   r2, r2, #0x0e<<17 @ if (code&0x1000) addr^=0xe;

    ldr     r2, [lr, r2, lsr #16] @ pack=*(unsigned int *)(Pico.vram+addr); // Get 8 pixels
.DrawStrip_samecode:
    tst     r9, #0x8000
@    tstne   r10, #1<<20     @ !force[20]
    bne     .DrawStrip_hiprio

    orr     r10, r10, #1<<21 @ seen non hi-prio tile
    tst     r2, r2
    beq     .dsloop              @ tileline blank

    bic     r7, r3, #0x7f
    and     r3, r9, #0x6000
    add     r3, r7, r3, lsr #9 @ r3=pal=((code&0x6000)>>9);

    cmp     r2, r2, ror #4
    beq     .DrawStrip_SingleColor @ tileline singlecolor 

    tst     r9, #0x0800
    bne     .DrawStrip_TileFlip

    @ (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r0: helper pattern
.DrawStrip_TileNorm:
    TileNorm r0
    b       .dsloop

.DrawStrip_TileFlip:
    TileFlip r0
    b       .dsloop

.DrawStrip_SingleColor:
    and     r4, r2, #0xf
    orr     r4, r3, r4
    orr     r4, r4, r4, lsl #8
    tst     r1, #1             @ not aligned?
    strneb  r4, [r1], #1
    streqh  r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strneb  r4, [r1], #1       @ have a remaining unaligned pixel?
    b       .dsloop_subr1

.DrawStrip_hiprio:
    tst     r10, #(1<<23)   @ sh[23]
    tsteq   r2, r2          @ if (!sh[23] && code==blank) continue
    beq     .dsloop

@    orr     r10, r10, #1<<22 @ hi_not_empty[22]
    sub     r7, r1, r11
    orr     r7, r9, r7,  lsl #16
    orr     r7, r7, r10, lsl #25 @ (ty<<25)
    tst     r9, #0x1000
    eorne   r7, r7, #0xe<<25 @ if(code&0x1000) cval^=0xe<<25;
    str     r7, [r6], #4    @ cache hi priority tile code
    str     r2, [r6], #4    @ cache hi priority tile data
    b       .dsloop

.dsloop_exit:
    ands    r4,r10, #7<<16        @ hscroll?
    beq     .DrawStrip_noscroll

    and     r7, r5, r8         @ do one more cut tile
    add     r7, lr, r7, lsl #1 @ Pico.vram+((tilex&ts->xmask) as halfwords)
    ldrh    r9, [r7, r12]      @ r7=code (int, but from unsigned, no sign extend)

    add     r1, r1, #8

    tst     r9, #0x1000     @ if (code&0x1000)
    mov     r2, r9, lsl #21
    add     r2, r2, r10, lsl #17
    eorne   r2, r2, #0x0e<<17 @ if (code&0x1000) addr^=0xe;

    ldr     r2, [lr, r2, lsr #16] @ pack=*(unsigned int *)(Pico.vram+addr); // Get 8 pixels

    mvn     r7, #0
    mov     r4, r4, lsr #16-2  @ (dx&7)*4
    tst     r9, #0x0800
    moveq   r7, r7, lsl r4     @ mask = ~0 [shift] (dx&7)*4
    movne   r7, r7, lsr r4
    and     r2, r2, r7, ror #16 @ pack&mask

    bic     r10,r10, #7<<16
    b       .DrawStrip_samecode @ one last time, with last tile now masked

.DrawStrip_noscroll:
    tst     r10, #1<<21 @ seen non hi-prio tile
    ldr     r1, [sp, #9*4]  @ est
    mov     r0, #0
    ldreq   r2, [r1, #OFS_EST_rendstatus]
    str     r0, [r6]    @ terminate the cache list
    orreq   r2, r2, #PDRAW_PLANE_HI_PRIO @ had a layer with all hi-prio tiles
    streq   r2, [r1, #OFS_EST_rendstatus]

    ldmfd   sp!, {r4-r11,pc}

@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

.DrawStrip_vsscroll:
    tst     r8, #1                @ if h40: lflags |= 0x10000
    orrne   r0, r0, #0x10000

    rsb     r8, r3, #0
    mov     r8, r8, lsr #3        @ r8=tilex=(-ts->hscroll)>>3
    bic     r8, r8, #0x3fc00000
    orr     r8, r8, r5, lsl #25   @ r8=(xmask[31:25]|had_output[24]|!force[23]|tilex[21:0])

    ldr     r11, [sp, #9*4]       @ est
    orr     r5, r1, r10, lsl #24
    ldr     r4, [r11, #OFS_EST_DrawScanline]
    sub     r1, r3, #1
    orr     r5, r5, r4, lsl #16   @ r5=(shift_width[31:24]|scanline[23:16]|ymask[15:0])
    and     r1, r1, #7
    add     r7, r1, #1            @ r7=dx=((ts->hscroll-1)&7)+1

    mov     r10,r9, lsl #16
    orr     r10,r10, #0xff000000  @ will be adjusted on entering loop
    tst     r0, #1
    orrne   r10,r10, #0x8000
    tst     r3, #0x0f             @ hscroll & 0x0f?
    beq     0f
    eor     r3, r3, r7
    sub     r10,r10, #1<<24       @ cell--  // start from negative for hscroll
    tst     r3, #0x08
    subne   r10,r10, #1<<16       @ cells--
    subne   r10,r10, #1<<24       @ cell--  // even more negative

    add_c24 r1, lr, (OFS_PMEM_vsram-OFS_PMEM_vram)
    tst     r0, #0x10000          @ h40?
    ldrne   r3, [r1, #0x00]       @ r3=vsram[0x00..0x01]
    ldreq   r3, [r1, #0x40]       @ r3=vsram[0x20..0x21]
    str     r3, [r1, #0x7c]       @ vsram[0x3e..0x3f]=r3
0:
    tst     r9, #1<<30
    mov     r3, #0
    orrne   r10,r10, #1<<23 @ r10=(cell[31:24]|sh[23]|hi_not_empty[22]|cells_max[21:16]|plane[15]|ty[14:0])
    movne   r3, #0x80       @ default to shadowed pal on sh mode
@    tst     r9, #1<<31
@    orreq   r8, r8, #1<<23

    and     r9, r9, #0xff00
    add     r8, r8, r9, lsr #8   @ tilex+=cellskip
    add     r7, r7, r9, lsr #5   @ dx+=cellskip<<3;
    add     r10,r10,r9, lsl #16  @ cell+=cellskip

    @ cache some stuff to avoid mem access
    ldr     r11,[sp, #9*4]       @ est
    mov     r0, #0xf
    ldr     r11,[r11, #OFS_EST_HighCol]

    mvn     r9, #0               @ r9=prevcode=-1
    add     r1, r11, r7          @ r1=pdest

    @ r10=cells[31:24]|sh[23]|hi_not_empty[22]|cells_max[21:16]|plane[15]|ty[14:0]
    @ r8=xmask[31:25]|had_output[24]|!force[23]|tilex[21:0]
    @ r5=shift_width[31:24]|scanline[23:16]|ymask[15:0]
    @ r3=nametabadd[31:16]|must_be_0[15:8]|pal[7:0]
    @ r1=pd+dx r2=pack r6=hc r9=prevcode r11=HighCol r12=nametab lr=vram
    @ r4 & r7 are scratch in this loop

    @ need to calc new ty?
    movs    r7, r10, lsl #7       @ (cell&1)?
    bmi     .dsloop_vs_subr1

    @ calc offset and read tileline code to r7, also calc ty
    add_c24 r7, lr, (OFS_PMEM_vsram-OFS_PMEM_vram)
    and     r4, r10, #0x3e000000
    add     r7, r7, r4, asr #23   @ vsram + ((cell&0x3e)<<1)
    tst     r10,#0x8000           @ plane1?
    addne   r7, r7, #2
    ldrh    r7, [r7]              @ r7=vscroll

    bic     r10,r10,#0xff         @ clear old ty
    and     r4, r5, #0xff0000     @ scanline
    add     r4, r4, r7, lsl #16   @ ... += vscroll
    and     r4, r4, r5, lsl #16   @ ... &= ymask
    and     r7, r4, #0x70000
    orr     r10,r10,r7, lsr #15   @ new ty

    mov     r4, r4, lsr #19
    mov     r7, r5, lsr #24
    mov     r4, r4, lsl r7        @ nametabadd
    and     r3, r3, #0xff
    orr     r3, r3, r4, lsl #16   @ r3=(nametabadd[31:16],pal[15:0])

.dsloop_vs_subr1:
    sub     r1, r1, #8
.dsloop_vs: @ 40-41 times
    add     r10,r10, #0x01000000
    and     r4, r10, #0x003f0000
    cmp     r4, r10, asr #8
    ble     .dsloop_vs_exit

    @ need to calc new ty?
    movs    r7, r10, lsl #7       @ (cell&1)?
    bmi     0f

    @ calc offset and read tileline code to r7, also calc ty
    add_c24 r7, lr, (OFS_PMEM_vsram-OFS_PMEM_vram)
    and     r4, r10, #0x3e000000
    add     r7, r7, r4, asr #23   @ vsram + ((cell&0x3e)<<1)
    tst     r10,#0x8000           @ plane1?
    addne   r7, r7, #2
    ldrh    r7, [r7]              @ r7=vscroll

    bic     r10,r10,#0xff         @ clear old ty
    and     r4, r5, #0xff0000     @ scanline
    add     r4, r4, r7, lsl #16   @ ... += vscroll
    and     r4, r4, r5, lsl #16   @ ... &= ymask
    and     r7, r4, #0x70000
    orr     r10,r10,r7, lsr #15   @ new ty

    mov     r4, r4, lsr #19
    mov     r7, r5, lsr #24
    mov     r4, r4, lsl r7        @ nametabadd
    and     r3, r3, #0xff
    orr     r3, r3, r4, lsl #16   @ r3=(nametabadd[31:16],pal[15:0])
0:
    and     r7, r8, r8, lsr #25
    add     r7, lr, r7, lsl #1    @ PicoMem.vram+((tilex&ts->xmask) as halfwords)
    add     r7, r7, r3, lsr #15
    ldrh    r7, [r7, r12]         @ r7=code (int, but from unsigned, no sign extend)

    add     r1, r1, #8
    add     r8, r8, #1

    orr     r7, r7, r10, lsl #24  @ code | (ty << 24)
    cmp     r7, r9
    beq     .DrawStrip_vs_samecode @ we know stuff about this tile already

    mov     r9, r7          @ remember code

    tst     r9, #0x1000     @ if (code&0x1000)
    mov     r2, r9, lsl #21
    add     r2, r2, r10, lsl #17
    eorne   r2, r2, #0x0e<<17 @ if (code&0x1000) addr^=0xe;

    ldr     r2, [lr, r2, lsr #16] @ pack=*(unsigned int *)(Pico.vram+addr); // Get 8 pixels

.DrawStrip_vs_samecode:
    tst     r9, #0x8000
@    tstne   r8, #1<<23     @ !force[23]
    bne     .DrawStrip_vs_hiprio

    orr     r8, r8, #(1<<24)@ seen non hi-prio tile
    tst     r2, r2
    beq     .dsloop_vs              @ tileline blank

    bic     r7, r3, #0x7f
    and     r3, r9, #0x6000
    add     r3, r7, r3, lsr #9 @ r3=pal=((code&0x6000)>>9);

    cmp     r2, r2, ror #4
    beq     .DrawStrip_vs_SingleColor @ tileline singlecolor 

    tst     r9, #0x0800
    bne     .DrawStrip_vs_TileFlip

    @ (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r0: helper pattern
.DrawStrip_vs_TileNorm:
    TileNorm r0
    b       .dsloop_vs

.DrawStrip_vs_TileFlip:
    TileFlip r0
    b       .dsloop_vs

.DrawStrip_vs_SingleColor:
    and     r4, r2, #0xf
    orr     r4, r3, r4
    orr     r4, r4, r4, lsl #8
    tst     r1, #1             @ not aligned?
    strneb  r4, [r1], #1
    streqh  r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strneb  r4, [r1], #1       @ have a remaining unaligned pixel?
    b       .dsloop_vs_subr1

.DrawStrip_vs_hiprio:
    tst     r10, #(1<<23)   @ sh[23]
    tsteq   r2, r2          @ if (!sh[23] && code==blank) continue
    beq     .dsloop_vs

@    orr     r10, r10, #1<<22 @ hi_not_empty[22]
    sub     r7, r1, r11
    orr     r7, r9, r7,  lsl #16
    orr     r7, r7, r10, lsl #25 @ (ty<<25)
    tst     r9, #0x1000
    eorne   r7, r7, #7<<26  @ if(code&0x1000) cval^=7<<26;
    str     r7, [r6], #4    @ cache hi priority tile code
    str     r2, [r6], #4    @ cache hi priority tile data
    b       .dsloop_vs

.dsloop_vs_exit:
    tst     r8, #(1<<24) @ seen non hi-prio tile
    ldr     r1, [sp, #9*4]  @ est
    mov     r0, #0
    ldreq   r2, [r1, #OFS_EST_rendstatus]
    str     r0, [r6]    @ terminate the cache list
    orreq   r2, r2, #PDRAW_PLANE_HI_PRIO @ had a layer with all hi-prio tiles
    streq   r2, [r1, #OFS_EST_rendstatus]

    ldmfd   sp!, {r4-r11,pc}


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

@ interlace mode 2? Sonic 2?
.DrawStrip_interlace:
    tst     r0, r0
    movne   r7, r7, lsr #16
    mov     r7, r7, lsl #21

    @ Find the line in the name table
    add     r2, r7, r2, lsl #22    @ r2=(vscroll+(DrawScanline<<1))<<21 (11 bits);
    orr     r1, r1, #0x80000000
    and     r2, r2, r1, ror #10    @ &((ymask<<1)|1)<<21;
    mov     r2, r2, lsr #21
    mov     r4, r2, lsr #4
    mov     r12, r12, lsr #1       @ halfwords
    add     r0, r12, r4, lsl r10   @ nametab+=(ts.line>>4)<<shift[width];
    and     r9, r9, #0xff

    sub     sp, sp, #6*4
    stmia   sp, {r0,r2,r3,r5,r6,r9}

    mov     r0, sp
    mov     r1, r9, lsr #29
    bl      DrawStripInterlace @ struct TileStrip *ts, int plane_sh

    add     sp, sp, #6*4
    ldmfd   sp!, {r4-r11,pc}

.pool

@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

@ void BackFill(int reg7, int sh, struct PicoEState *est)

.global BackFill

BackFill:
    stmfd   sp!, {r4-r9,lr}

    ldr     lr, [r2, #OFS_EST_HighCol]
    orr     r0, r0, r1, lsl #7
    orr     r0, r0, r0, lsl #8
    orr     r0, r0, r0, lsl #16

    mov     r1, r0
    mov     r2, r0
    mov     r3, r0
    mov     r4, r0
    mov     r5, r0
    mov     r6, r0
    mov     r7, r0

    @ go go go!
    add     lr, lr, #8
    stmia   lr!, {r0-r7} @ 10*8*4
    stmia   lr!, {r0-r7}
    stmia   lr!, {r0-r7}
    stmia   lr!, {r0-r7}
    stmia   lr!, {r0-r7}
    stmia   lr!, {r0-r7}
    stmia   lr!, {r0-r7}
    stmia   lr!, {r0-r7}
    stmia   lr!, {r0-r7}
    stmia   lr!, {r0-r7}

    ldmfd   sp!, {r4-r9,pc}


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

@ void DrawTilesFromCache(int *hc, int sh, int rlim, struct PicoEState *est)

.global DrawTilesFromCache

DrawTilesFromCache:
    stmfd   sp!, {r4-r9,r11,lr}

    @ cache some stuff to avoid mem access
    ldr     r11,[r3, #OFS_EST_HighCol]
    mov     r12,#0xf
    ldr     lr, [r3, #OFS_EST_PicoMem_vram]
    mov     r9, r3         @ est

    ands    r8, r1, #1
    orr     r8, r8, r2, lsl #1
    bne     .dtfc_check_rendflags

    @ scratch: r4, r7
.dtfc_loop:
    ldr     r6, [r0], #4    @ read code
    movs    r1, r6, lsr #16 @ r1=dx;
    ldmeqfd sp!, {r4-r9,r11,pc} @ dx is never zero, this must be a terminator, return
    bic     r4, r1, #0xfe00
    add     r1, r11, r4     @ r1=pdest

    ldr     r2, [r0], #4    @ read pixel data

    and     r3, r6, #0x6000
    mov     r3, r3, lsr #9  @ r3=pal=((code&0x6000)>>9);

    rsbs    r4, r4, r8, lsr #1
    bmi     .dtfc_cut_tile

    tst     r8, #1
    bne     .dtfc_shadow

    tst     r2, r2
    beq     .dtfc_loop

    cmp     r2, r2, ror #4
    beq     .dtfc_SingleColor @ tileline singlecolor 

    tst     r6, #0x0800
    bne     .dtfc_TileFlip

    @ (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r12: helper pattern
.dtfc_TileNorm:
    TileNorm r12
    b       .dtfc_loop

.dtfc_TileFlip:
    TileFlip r12
    b       .dtfc_loop

.dtfc_SingleColor:
    and     r4, r2, #0xf
    orr     r4, r3, r4
    orr     r4, r4, r4, lsl #8
    tst     r1, #1              @ not aligned?
    strneb  r4, [r1], #1
    streqh  r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strneb  r4, [r1], #1        @ have a remaining unaligned pixel?
    b       .dtfc_loop

.dtfc_shadow:
    tst     r2, r2
    beq     .dtfc_shadow_blank

    cmp     r2, r2, ror #4
    beq     .dtfc_SingleColor @ tileline singlecolor 

    tst     r6, #0x0800
    bne     .dtfc_TileFlipShHP

    @ (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r12: helper pattern
.dtfc_TileNormShHP:
    TileNormShHP
    b       .dtfc_loop

.dtfc_TileFlipShHP:
    TileFlipShHP
    b       .dtfc_loop

.dtfc_shadow_blank:
    tst     r1, #1
    ldrneb  r4, [r1]
    mov     r6, #0x7f
    and     r4, r4, r6
    strneb  r4, [r1], #1
    ldrh    r4, [r1]
    orr     r6, r6, r6, lsl #8
    and     r4, r4, r6
    strh    r4, [r1], #2
    ldrh    r4, [r1]
    and     r4, r4, r6
    strh    r4, [r1], #2
    ldrh    r4, [r1]
    and     r4, r4, r6
    strh    r4, [r1], #2
    ldrh    r4, [r1]
    and     r4, r4, r6
    streqh  r4, [r1]
    strneb  r4, [r1]
    b       .dtfc_loop

.dtfc_cut_tile:
    cmn     r4, #8
    ble     .dtfc_loop      @ off limits

    rsb     r4, r4, #0      @ 1-7
    mov     r4, r4, lsl #2
    mvn     r12,#0
    tst     r6, #0x0800     @ flipped?
    moveq   r12,r12, lsl r4
    movne   r12,r12, lsr r4
    and     r2, r2, r12, ror #16
    mov     r12,#0xf
    tst     r8, #1
    bne     .dtfc_shadow
    tst     r2, r2
    beq     .dtfc_loop
    tst     r6, #0x0800
    beq     .dtfc_TileNorm
    b       .dtfc_TileFlip

@ check if we have detected layer covered with hi-prio tiles:
.dtfc_check_rendflags:
    ldr     r2, [r9, #OFS_EST_rendstatus]
    tst     r2, #(PDRAW_PLANE_HI_PRIO|PDRAW_SHHI_DONE)
    beq     .dtfc_loop
    bic     r8, r8, #1      @ sh/hi mode off
    tst     r2, #PDRAW_SHHI_DONE
    bne     .dtfc_loop      @ already processed
    orr     r2, r2, #PDRAW_SHHI_DONE
    str     r2, [r9, #OFS_EST_rendstatus]

    add     r1, r11,#8
    mov     r3, #320/4/4
    mov     r6, #0x7f
    orr     r6, r6, r6, lsl #8
    orr     r6, r6, r6, lsl #16
.dtfc_loop_shprep:
    ldmia   r1, {r2,r4,r5,r7}
    subs    r3, r3, #1
    and     r2, r2, r6
    and     r4, r4, r6
    and     r5, r5, r6
    and     r7, r7, r6
    stmia   r1!,{r2,r4,r5,r7}
    bne     .dtfc_loop_shprep

    b       .dtfc_loop

.pool

@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


@ void DrawSpritesSHi(unsigned char *sprited, struct PicoEState *est)

.global DrawSpritesSHi

DrawSpritesSHi:
    ldrb    r3, [r0]
    mov     r12,#0xff
    ands    r3, r3, #0x7f
    bxeq    lr

    stmfd   sp!, {r1,r3-r11,lr} @ +est
    strb    r12,[r0,#3]     @ set end marker
    ldrb    r12,[r0,#1]
    add     r10,r0, #4      @ r10=HighLnSpr end
    mvn     r12,r12
    tst     r12,#0x6        @ masking in slot 1 and tile ovfl?
    ldmeqfd sp!, {r1,r3-r11,pc}
    add     r10,r10,r3      @ r10=HighLnSpr end

    ldrb    r12,[r10,#0]    @ width of last sprite
    ldr     r11,[r1, #OFS_EST_HighCol]
    str     r12,[sp, #4]
    mov     r12,#0xf
    ldr     lr, [r1, #OFS_EST_PicoMem_vram]


DrawSpriteSHi:
    @ draw next sprite
    ldr     r7, [sp]        @ est
    ldrb    r0, [r10,#-1]!
    ldr     r1, [r7, #OFS_EST_HighPreSpr]
    cmp     r0, #0xff
    ldmeqfd sp!, {r1,r3-r11,pc} @ end of list
    and     r0, r0, #0x7f
    add     r0, r1, r0, lsl #3

    ldr     r9, [r0, #4]    @ sprite[1]
    mov     r2, r9, asr #16 @ r2=sx

    mov     r9, r9, lsl #16
    mov     r3, r9, lsr #31 @ priority
    mov     r9, r9, lsr #16
@    orr     r9, r9, r8, lsl #31 @ r9=code|sh[31]   @@ sh is always on here now
    and     r4, r9, #0x6000
    orr     r9, r9, r4, lsl #16
    orr     r9, r9, #0x90000000 @ r9=scc1 ???? ... <code> (s=shadow/hilight, cc=pal)
    cmp     r12,r9, lsr #28 @ sh/hi with pal3?
    cmpne   r3, #1          @ if not, is it hi prio?
    strne   r3, [sp, #4]    @ reset last sprite width
    bne     DrawSpriteSHi   @ non-operator low sprite, already drawn

    ldr     r3, [r0]        @ sprite[0]
    mov     r6, r3, lsr #28
    sub     r6, r6, #1      @ r6=width-1 (inc later)
    mov     r5, r3, lsr #24
    and     r5, r5, #7      @ r5=height

    ldr     r7, [r7, #OFS_EST_DrawScanline]
    mov     r0, r3, lsl #16 @ r4=sy<<16 (tmp)

    sub     r7, r7, r0, asr #16 @ r7=row=DrawScanline-sy

    tst     r9, #0x1000
    movne   r0, r5, lsl #3
    subne   r0, r0, #1
    subne   r7, r0, r7      @ if (code&0x1000) row=(height<<3)-1-row; // Flip Y

    add     r8, r9, r7, lsr #3 @ tile+=row>>3; // Tile number increases going down
    tst     r9, #0x0800
    mlane   r8, r5, r6, r8  @ if (code&0x0800) { tile+=delta*(width-1);
    rsbne   r5, r5, #0      @ delta=-delta; } // r5=delta now

    mov     r8, r8, lsl #21
    mov     r8, r8, lsr #17
    and     r7, r7, #7
    add     r8, r8, r7, lsl #1 @ tile+=(row&7)<<1; // Tile address

    ldr     r0, [sp, #4]
    add     r6, r6, #1         @ inc now
    cmp     r0, #0             @ check width of last sprite
    movne   r6, r0
    movne   r0, #0
    strne   r0, [sp, #4]

    mov     r5, r5, lsl #4     @ delta<<=4; // Delta of address
    mov     r3, r4, lsr #9     @ r3=pal=((code>>9)&0x30);

    adds    r0, r2, #0         @ mov sx to r0 and set ZV flags
    b       .dsprShi_loop_enter

.dsprShi_loop:
    subs    r6, r6, #1         @ width--
    beq     DrawSpriteSHi
    adds    r0, r0, #8         @ sx+=8
    add     r8, r8, r5         @ tile+=delta

.dsprShi_loop_enter:
    ble     .dsprShi_loop     @ sx <= 0
    cmp     r0, #328
    bge     DrawSpriteSHi

    bic     r8, r8, #0xf8000   @ tile&=0x7fff; // Clip tile address
    ldr     r2, [lr, r8, lsl #1] @ pack=*(unsigned int *)(PicoMem.vram+addr); // Get 8 pixels
    add     r1, r11, r0        @ r1=pdest
    tst     r2, r2
    beq     .dsprShi_loop

    cmp     r12, r9, lsr #28
    beq     .dsprShi_shadow

    cmp     r2, r2, ror #4
    beq     .dsprShi_SingleColor @ tileline singlecolor 

    tst     r9, #0x0800
    bne     .dsprShi_TileFlip

    @ (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r12: helper pattern
@ scratch: r4, r7
.dsprShi_TileNorm:
    TileNorm r12
    b       .dsprShi_loop

.dsprShi_TileFlip:
    TileFlip r12
    b       .dsprShi_loop

.dsprShi_SingleColor:
    and     r4, r2, #0xf
    orr     r4, r3, r4
    orr     r4, r4, r4, lsl #8
    tst     r0, #1              @ not aligned?
    strneb  r4, [r1], #1
    streqh  r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strneb  r4, [r1], #1
    b       .dsprShi_loop

.dsprShi_shadow:
    tst     r9, #0x8000
    beq     .dsprShi_shadow_lowpri

    cmp     r2, r2, ror #4
    beq     .dsprShi_singlec_sh

    tst     r9, #0x0800
    bne     .dsprShi_TileFlip_sh

    @ (r1=pdest, r2=pixels8, r3=pal) r4, r7: scratch, r12: helper pattern
.dsprShi_TileNorm_sh:
    TileNormSh
    b       .dsprShi_loop

.dsprShi_TileFlip_sh:
    TileFlipSh
    b       .dsprShi_loop

.dsprShi_singlec_sh:
    cmp     r2, #0xe0000000
    bcc     .dsprShi_SingleColor   @ normal singlecolor tileline (carry inverted in ARM)
    tst     r2, #0x10000000
    bne     .dsprShi_sh_sh
    TileSingleHi
    b       .dsprShi_loop

.dsprShi_sh_sh:
    TileSingleSh
    b       .dsprShi_loop

.dsprShi_shadow_lowpri:
    tst     r9, #0x800
    bne     .dsprShi_TileFlip_sh_lp

.dsprShi_TileNorm_sh_lp:
    TileNormSh_onlyop_lp
    b       .dsprShi_loop

.dsprShi_TileFlip_sh_lp:
    TileFlipSh_onlyop_lp
    b       .dsprShi_loop

.pool

@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

@ void DrawAllSprites(unsigned char *sprited, int prio, int sh,
@                     struct PicoEState *est)

.global DrawAllSprites

DrawAllSprites:
    orr     r1, r2, r1, lsl #1
    ldr     r2, [r0]
    ands    r2, r2, #0x7f
    bxeq    lr

    @ time to do some real work
    stmfd   sp!, {r1,r3-r11,lr} @ +sh|prio<<1 +est
    mov     r12,#0xff
    strb    r12,[r0,#3]     @ set end marker
    ldrb    r12,[r0,#1]
    add     r10,r0 ,#4
    mvn     r12,r12
    tst     r12,#0x6        @ masking in slot 1 and tile ovfl?
    ldmeqfd sp!, {r1,r3-r11,pc}
    add     r10,r10,r2      @ r10=HighLnSpr end

    ldrb    r12,[r10,#0]    @ width of last sprite
    ldr     r11,[r3, #OFS_EST_HighCol]
    orr     r1 ,r1 ,r12,lsl #24
    str     r1, [sp]
    mov     r12,#0xf
    ldr     lr, [r3, #OFS_EST_PicoMem_vram]

@ + 0  :    hhhhvvvv ----hhvv yyyyyyyy yyyyyyyy // v, h: horiz. size
@ + 4  :    xxxxxxxx xxxxxxxx pccvhnnn nnnnnnnn // x: x coord + 8

DrawSprite:
    @ draw next sprite
    ldrb    r0, [r10,#-1]!
    ldr     r4, [sp]        @ sh|prio<<1|lastw<<24
    ldr     r7, [sp, #4]    @ est
    mov     r2, r0, lsl #24
    cmp     r0, #0xff
    ldmeqfd sp!, {r1,r3-r11,pc} @ end of list
    eors    r2, r2, r4, lsl #30
    bic     r2, r4, #0xff000000
    str     r2, [sp]
    bmi     DrawSprite      @ wrong priority
    ldr     r1, [r7, #OFS_EST_HighPreSpr]
    and     r0, r0, #0x7f
    add     r0, r1, r0, lsl #3

    ldr     r3, [r0]        @ sprite[0]
    ldr     r7, [r7, #OFS_EST_DrawScanline]
    mov     r6, r3, lsr #28
    sub     r6, r6, #1      @ r6=width-1 (inc later)
    mov     r5, r3, lsr #24
    and     r5, r5, #7      @ r5=height

    mov     r8, r3, lsl #16 @ r8=sy<<16 (tmp)

    ldr     r9, [r0, #4]
    sub     r7, r7, r8, asr #16 @ r7=row=DrawScanline-sy

    mov     r2, r9, asr #16 @ r2=sx
    mov     r9, r9, lsl #16
    mov     r9, r9, lsr #16
    orr     r9, r9, r4, lsl #31 @ r9=code|sh[31]

    tst     r9, #0x1000
    movne   r8, r5, lsl #3
    subne   r8, r8, #1
    subne   r7, r8, r7      @ if (code&0x1000) row=(height<<3)-1-row; // Flip Y

    add     r8, r9, r7, lsr #3 @ tile+=row>>3; // Tile number increases going down
    tst     r9, #0x0800
    mlane   r8, r5, r6, r8  @ if (code&0x0800) { tile+=delta*(width-1);
    rsbne   r5, r5, #0      @ delta=-delta; } // r5=delta now

    mov     r8, r8, lsl #21
    mov     r8, r8, lsr #17
    and     r7, r7, #7
    add     r8, r8, r7, lsl #1 @ tile+=(row&7)<<1; // Tile address

    add     r6, r6, #1         @ inc now
    cmp     r4, #0x1000000     @ check width of last sprite
    movhs   r6, r4, lsr #24

    @ cache some stuff to avoid mem access
    mov     r5, r5, lsl #4     @ delta<<=4; // Delta of address
    and     r4, r9, #0x6000
    orr     r9, r9, r4, lsl #16
    orrs    r9, r9, #0x10000000 @ r9=scc1 ???? ... <code> (s=shadow/hilight, cc=pal)

    mov     r3, r4, lsr #9     @ r3=pal=((code>>9)&0x30);
    orrmi   r3, r3, #0x80      @ for sh/hi

    adds    r0, r2, #0         @ mov sx to r0 and set ZV flags
    b       .dspr_loop_enter

.dspr_loop:
    subs    r6, r6, #1         @ width--
    beq     DrawSprite
    adds    r0, r0, #8         @ sx+=8
    add     r8, r8, r5         @ tile+=delta

.dspr_loop_enter:
    ble     .dspr_loop         @ sx <= 0
    cmp     r0, #328
    bge     DrawSprite

    bic     r8, r8, #0xf8000   @ tile&=0x7fff; // Clip tile address
    ldr     r2, [lr, r8, lsl #1] @ pack=*(unsigned int *)(PicoMem.vram+addr); // Get 8 pixels
    add     r1, r11, r0        @ r1=pdest
    tst     r2, r2
    beq     .dspr_loop

    cmp     r12, r9, lsr #28
    beq     .dspr_shadow

    tst     r9, #0x80000000
    bne     .dspr_shnonsh

    cmp     r2, r2, ror #4
    beq     .dspr_SingleColor @ tileline singlecolor 

    tst     r9, #0x0800
    bne     .dspr_TileFlip

    @ (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r12: helper pattern
@ scratch: r4, r7
.dspr_TileNorm:
    TileNorm r12
    b       .dspr_loop

.dspr_TileFlip:
    TileFlip r12
    b       .dspr_loop

.dspr_singlec_sh:
    cmp     r2, #0xe0000000
    bcs     .dspr_TileNorm_sh   @ op. tileline, markop. XXX: maybe add a spec. handler?

.dspr_SingleColor:
    and     r4, r2, #0xf
    orr     r4, r3, r4
    orr     r4, r4, r4, lsl #8
    tst     r0, #1              @ not aligned?
    strneb  r4, [r1], #1
    streqh  r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strh    r4, [r1], #2
    strneb  r4, [r1], #1
    b       .dspr_loop

.dspr_shnonsh:
    tst     r9, #0x0800
    bne     .dspr_TileFlipNonSH

    @ (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r12: helper pattern
@ scratch: r4, r7
.dspr_TileNormNonSH:
    TileNormNonSH r12
    b       .dspr_loop

.dspr_TileFlipNonSH:
    TileFlipNonSH r12
    b       .dspr_loop

.dspr_shadow:
    cmp     r2, r2, ror #4
    beq     .dspr_singlec_sh

    tst     r9, #0x0800
    bne     .dspr_TileFlip_sh

    @ (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r12: helper pattern
.dspr_TileNorm_sh:
    TileNormSh_markop
    b       .dspr_loop

.dspr_TileFlip_sh:
    TileFlipSh_markop
    b       .dspr_loop


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

@ void DrawWindow(int tstart, int tend, int prio, int sh
@                 struct PicoEState *est)

.global DrawWindow

DrawWindow:
    ldr     r12, [sp]             @ est
    stmfd   sp!, {r4-r11,lr}

    ldr     r6,  [r12, #OFS_EST_Pico]
    ldr     r10, [r12, #OFS_EST_DrawScanline]
    mov     r11, r12              @ est
    ldrb    r12, [r6, #OFS_Pico_video_reg+3] @ pvid->reg[3]

    ldr     r4,  [r6, #OFS_Pico_video_reg+12]
    mov     r5,  r10, lsr #3
    and     r10, r10, #7
    mov     r10, r10, lsl #1      @ r10=ty

    ldr     r6, [r11, #OFS_EST_rendstatus]
    ldr     lr, [r11, #OFS_EST_PicoMem_vram]

    mov     r12, r12, lsl #10

    tst     r4, #1                @ 40 cell mode?
    andne   r12, r12, #0xf000     @ 0x3c<<10
    andeq   r12, r12, #0xf800
    addne   r12, r12, r5, lsl #7
    addeq   r12, r12, r5, lsl #6  @ nametab
    add     r12, r12, r0, lsl #2  @ +starttile

    ands    r6, r6, #PDRAW_WND_DIFF_PRIO
    cmpeq   r2, #1                @ prio && !(rendstatus & WND_DIFF_PRIO)?
    ldmeqfd sp!, {r4-r11,pc}      @ yes, assume that whole window uses same priority

    orr     r6, r6, r2
    orr     r6, r6, r3, lsl #8    @ shadow mode

    sub     r8, r1, r0

    @ cache some stuff to avoid mem access
    ldr     r11, [r11, #OFS_EST_HighCol]
    mov     r8, r8, lsl #1        @ cells
    mvn     r9, #0                @ r9=prevcode=-1
    add     r1, r11, r0, lsl #4   @ r1=pdest=HighCol+starttile (+8 added in loop)
    mov     r0, #0xf

    @ r4,r5 are scratch in this loop
.dwloop:
    add     r1, r1, #8
.dwloop_nor1:
    ldrh    r7, [lr, r12]   @ r7=code (int, but from unsigned, no sign extend)
    add     r12, r12, #2    @ halfwords
    subs    r8, r8, #1
    bmi     .dwloop_end     @ done

    eor     r5, r6, r7, lsr #15
    tst     r5, #1
    orrne   r6, r6, #PDRAW_WND_DIFF_PRIO @ wrong pri
    bne     .dwloop

    cmp     r7, r9
    beq     .dw_samecode    @ we know stuff about this tile already

    mov     r9, r7          @ remember code

    tst     r9, #0x1000     @ if (code&0x1000)
    mov     r2, r9, lsl #21
    add     r2, r2, r10, lsl #17
    eorne   r2, r2, #0xe<<17 @ if (code&0x1000) addr^=0xe;

    ldr     r2, [lr, r2, lsr #16] @ pack=*(unsigned int *)(Pico.vram+addr); // Get 8 pixels

    and     r3, r9, #0x6000
    mov     r3, r3, lsr #9  @ r3=pal=((code&0x6000)>>9);

.dw_samecode:
    tst     r6, #0x100
    bne     .dw_shadow
.dw_shadow_done:
    tst     r2, r2
    beq     .dwloop              @ tileline blank

    cmp     r2, r2, ror #4
    beq     .dw_SingleColor @ tileline singlecolor 

    tst     r9, #0x0800
    bne     .dw_TileFlip

    @ (r1=pdest, r2=pixels8, r3=pal) r4: scratch, r0: helper pattern
.dw_TileNorm:
    TileNorm r0
    b       .dwloop

.dw_TileFlip:
    TileFlip r0
    b       .dwloop

.dw_SingleColor:
    and     r4, r0, r2         @ #0x0000000f
    orr     r4, r3, r4
    orr     r4, r4, r4, lsl #8
    orr     r4, r4, r4, lsl #16
    mov     r5, r4
    stmia   r1!, {r4,r5}
    b       .dwloop_nor1       @ we incremeted r1 ourselves

.dw_shadow:
    tst     r6, #1             @ hi pri?
    orreq   r3, r3, #0x80
    beq     .dw_shadow_done
    ldr     r4, [r1]
    mov     r5, #0x7f
    orr     r5, r5, r5, lsl #8
    orr     r5, r5, r5, lsl #16
    and     r4, r4, r5
    str     r4, [r1]
    ldr     r4, [r1,#4]
    and     r4, r4, r5
    str     r4, [r1,#4]
    b       .dw_shadow_done

.dwloop_end:
    and     r2, r6, #PDRAW_WND_DIFF_PRIO
    ldmfd   sp!, {r4-r11,lr}
    ldr     r0, [sp]
    ldr     r1, [r0, #OFS_EST_rendstatus]
    orr     r1, r1, r2
    str     r1, [r0, #OFS_EST_rendstatus]

    bx      lr


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


@ Convert 0000bbb0 ggg0rrr0
@ to      rrrrrggg gggbbbbb

@ r2,r3 - scratch, lr = 0x001c001c, r8 = 0x08610861
.macro convRGB565 reg
    and     r2,   lr,   \reg,lsr #7  @ b
    and     r3,   lr,   \reg,lsr #3  @ g
    and     \reg, lr,   \reg,lsl #1  @ r
    orr     r2,   r2,   r3,  lsl #6
    orr     \reg, r2,   \reg,lsl #11

    and     r2,   r8,   \reg,lsr #4
    orr     \reg, \reg, r2
.endm

@ trashes: r2-r8,r12,lr; r8 = 0x08610861; r0,r1 are advanced
.macro vidConvCpyRGB565_local
    mov     r12, r2, lsr #3  @ repeats
    mov     lr, #0x001c0000
    orr     lr, lr,  #0x01c  @ lr == pattern 0x001c001c

0:
    ldmia   r1!, {r4-r7}
    subs    r12, r12, #1
    convRGB565 r4
    str     r4, [r0], #4
    convRGB565 r5
    str     r5, [r0], #4
    convRGB565 r6
    str     r6, [r0], #4
    convRGB565 r7
    str     r7, [r0], #4

    bgt     0b
.endm


.global vidConvCpyRGB565

vidConvCpyRGB565: @ void *to, void *from, int pixels
    stmfd   sp!, {r4-r9,lr}
    mov     r8,     #0x0061
    orr     r8, r8, #0x0800
    orr     r8, r8, r8, lsl #16
    vidConvCpyRGB565_local
    ldmfd   sp!, {r4-r9,pc}


@ void PicoDoHighPal555(int sh, int line, struct PicoEState *est)

.global PicoDoHighPal555

PicoDoHighPal555:
    stmfd   sp!, {r4-r10,lr}
    mov     r10,r2               @ est
    ldr     r8, [r10, #OFS_EST_Pico]

    mov     r9, r0

    add     r0, r10, #OFS_EST_HighPal

    mov     r1, #0
    strb    r1, [r8, #OFS_Pico_m_dirtyPal]

    ldr     r1, [r10, #OFS_EST_PicoMem_cram]
    mov     r2, #0x40
    mov     r8,     #0x0061
    orr     r8, r8, #0x0800
    orr     r8, r8, r8, lsl #16

    vidConvCpyRGB565_local

    cmp     r9, #0
    beq     PicoDoHighPal555_end

    add     r3, r10, #OFS_EST_HighPal
    add     r4, r3, #0x40*2

    @ hilighted pixels (0x40-0x7f):
    @  t = ((dpal[i] >> 1) & 0x738e738e) + 0x738e738e;
    @  t |= (t >> 4) & 0x08610861;
    @ r8=0x08610861
    mov     r12,    #0x008e
    orr     r12,r12,#0x7300
    orr     r12,r12,r12,lsl #16
    mov     lr, #0x40/4
.fl_loopcpRGB555_hi:
    ldmia   r3!, {r1,r6}
    and     r1, r12, r1, lsr #1
    and     r6, r12, r6, lsr #1
    add     r1, r12, r1
    add     r6, r12, r6
    and     r5, r8, r1, lsr #4
    and     r7, r8, r6, lsr #4
    orr     r1, r1, r5
    orr     r6, r6, r7
    stmia   r4!, {r1,r6}
    subs    lr, lr, #1
    bne     .fl_loopcpRGB555_hi

    sub     r3, r3, #0x40*2
    @ shadowed (0x80-0xbf), shadow|hilight (aka normal, 0xc0-0xff) pixels:
    add     r5, r3, #0xc0*2
    mov     lr, #0x40/4
.fl_loopcpRGB555_sh:
    ldmia   r3!, {r1,r6}
    subs    lr, lr, #1
    stmia   r5!, {r1,r6} @ 0xc0, normal
    and     r1, r12, r1, lsr #1
    and     r6, r12, r6, lsr #1
    stmia   r4!, {r1,r6}
    bne     .fl_loopcpRGB555_sh

    mov     r0, #1
PicoDoHighPal555_end:
    ldmfd   sp!, {r4-r10,pc}


@ void FinalizeLine555(int sh, int line, struct PicoEState *est)

.global FinalizeLine555

FinalizeLine555:
    ldr     r3, [r2, #OFS_EST_rendstatus]
    mov     r0, r2
    tst     r3, #PDRAW_BGC_DMA
    bne     BgcDMA

    stmfd   sp!, {r4-r11,lr}
    mov     r11,r2               @ est
    mov     r4, r3

    bl      PicoDrawUpdateHighPal

    ldr     r8, [r11, #OFS_EST_Pico]
    add     r3, r11, #OFS_EST_HighPal

    mov     lr, #0xff
    mov     lr, lr, lsl #1

    ldr     r5, [r11, #OFS_EST_PicoOpt]
    ldr     r1, [r11, #OFS_EST_HighCol]
    ldr     r0, [r11, #OFS_EST_DrawLineDest]
    ldr     r7, [r5, #OFS_PicoIn_AHW-OFS_PicoIn_opt]
    ldrb    r12,[r8, #OFS_Pico_video_reg+12]
    ldrb    r6, [r8, #OFS_Pico_video_reg+0]
    ldr     r2, [r8, #OFS_Pico_m_hardware]
    add     r1, r1, #8

    tst     r7, #0x20   	@ GG ?
    tstne   r2, #0x2		@ LCD ?
    bne     .fl_gg20col

    tst     r7, #0x10   	@ SMS ?
    beq     .fl_noSMS

    tst     r6, #0x20
    movne   r2, #248/8  	@ len = 248
    addne   r1, r1, #8  	@ ps += 8
    moveq   r2, #256/8		@ len = 256
    b       .fl_check32scaling

.fl_gg20col:
    mov     r2, #160/8		@ len = 160
    tst     r4, #PDRAW_SOFTSCALE
    bne     .fl_20scale_RGB555	@ scale 160->320
    b       .fl_checkborder

.fl_noSMS:
    tst     r12, #1		@ h32?
    movne   r2, #320/8          @ len = 320
    bne     .fl_40colRGB555
    mov     r2, #256/8		@ len = 256

.fl_check32scaling:
    tst     r4, #PDRAW_SOFTSCALE
    rsbne   r7, r2, #256/8
    addne   r0, r0, r7, lsl #3	@ pd += (256-len)>>1
    bne     .fl_32scale_RGB555	@ scale 256->320

.fl_checkborder:
    tst     r4, #PDRAW_BORDER_32
    rsbne   r7, r2, #320/8	@ pd += (320-len)/2
    addne   r0, r0, r7, lsl #3

.fl_40colRGB555:
#ifdef UNALIGNED_DRAWLINEDEST
    @ this is basically for Gizmondo, which has unaligned odd lines in the framebuffer
    tst     r0, #2
    bne     .fl_RGB555u
#endif

.fl_loopRGB555:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r4, lr, r12, lsl #1
    ldrh    r4, [r3, r4]
    and     r5, lr, r12, lsr #7
    ldrh    r5, [r3, r5]
    and     r6, lr, r12, lsr #15
    ldrh    r6, [r3, r6]
    orr     r4, r4, r5, lsl #16

    and     r5, lr, r12, lsr #23
    ldrh    r5, [r3, r5]
    and     r8, lr, r7, lsl #1
    ldrh    r8, [r3, r8]
    orr     r5, r6, r5, lsl #16

    and     r6, lr, r7, lsr #7
    ldrh    r6, [r3, r6]
    and     r12,lr, r7, lsr #15
    ldrh    r12,[r3, r12]
    and     r7, lr, r7, lsr #23
    ldrh    r7, [r3, r7]
    orr     r8, r8, r6, lsl #16

    subs    r2, r2, #1
    orr     r12,r12, r7, lsl #16

    stmia   r0!, {r4,r5,r8,r12}
    bne     .fl_loopRGB555

    ldmfd   sp!, {r4-r11,pc}


.fl_32scale_RGB555:
    ldr     r5, [r5, #OFS_PicoIn_filter-OFS_PicoIn_opt]

    mov     r9, #0xf700 @ f800 07e0 001f | e000 0780 001c | 3800 01e0 0007
    orr     r9, r9, #0x00de

#ifdef UNALIGNED_DRAWLINEDEST
    tst     r0, #2
    bne     .fl_32scale_RGB555u
#endif

    and     r5, r5, #0x3
    add     pc, pc, r5, lsl #2
    nop
    b       .fl_32scale_nn
    b       .fl_32scale_snn
    b       .fl_32scale_bl2
    b       .fl_32scale_bl4

.fl_32scale_nn:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r4, lr, r12, lsl #1
    ldrh    r4, [r3, r4]
    and     r5, lr, r12, lsr #7
    ldrh    r5, [r3, r5]
    and     r6, lr, r12, lsr #15
    ldrh    r6, [r3, r6]
    and     r10,lr, r12, lsr #23
    ldrh    r10,[r3, r10]

    orr     r4, r4, r5, lsl #16
    orr     r5, r6, r6, lsl #16

    and     r6, lr, r7, lsl #1
    ldrh    r6, [r3, r6]
    and     r8, lr, r7, lsr #7
    ldrh    r8, [r3, r8]
    and     r12,lr, r7, lsr #15
    ldrh    r12,[r3, r12]
    and     r7, lr, r7, lsr #23
    ldrh    r7, [r3, r7]

    orr     r6, r10,r6, lsl  #16
    orr     r8, r8,r12, lsl #16

    subs    r2, r2, #1

    orr     r10,r12,r7, lsl #16

    stmia   r0!, {r4,r5,r6,r8,r10}
    bne     .fl_32scale_nn

    b       .fl_32scale_8bit

.fl_32scale_snn:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r4, lr, r12, lsl #1
    ldrh    r4, [r3, r4]
    and     r5, lr, r12, lsr #7
    ldrh    r5, [r3, r5]
    and     r6, lr, r12, lsr #15
    ldrh    r6, [r3, r6]
    and     r10,lr, r12, lsr #23
    ldrh    r10,[r3, r10]

    and     r4, r4, r9
    and     r5, r5, r9
    orr     r4, r4, r5, lsl #16
    and     r6, r6, r9
    add     r5, r5, r6
    mov     r5, r5, lsr #1
    orr     r5, r5, r6, lsl #16

    and     r6, lr, r7, lsl #1
    ldrh    r6, [r3, r6]
    and     r8, lr, r7, lsr #7
    ldrh    r8, [r3, r8]
    and     r12,lr, r7, lsr #15
    ldrh    r12,[r3, r12]
    and     r7, lr, r7, lsr #23
    ldrh    r7, [r3, r7]

    and     r6, r6, r9
    and     r10,r10,r9
    orr     r6, r10,r6, lsl  #16
    and     r12,r12,r9
    and     r7, r7, r9
    orr     r10,r12,r7, lsl #16

    and     r8, r8, r9
    add     r12,r12,r8
    mov     r12,r12,lsr #1
    orr     r8, r8,r12, lsl #16

    subs    r2, r2, #1

    stmia   r0!, {r4,r5,r6,r8,r10}
    bne     .fl_32scale_snn

    b       .fl_32scale_8bit

.fl_32scale_bl2:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r4, lr, r12, lsl #1
    ldrh    r4, [r3, r4]
    and     r5, lr, r12, lsr #7
    ldrh    r5, [r3, r5]
    and     r6, lr, r12, lsr #15
    ldrh    r6, [r3, r6]

    and     r4, r4, r9
    and     r5, r5, r9
    add     r10,r4, r5
    mov     r10,r10,lsr #1
    orr     r4, r4, r10,lsl #16		@ px0 | (px0+px1)/2

    and     r6, r6, r9
    add     r5, r5, r6
    mov     r5, r5, lsr #1
    orr     r5, r5, r6, lsl #16		@ (px1+px2)/2 | px2

    and     r10,lr, r12, lsr #23
    ldrh    r10,[r3, r10]
    and     r8, lr, r7, lsl #1
    ldrh    r8, [r3, r8]

    and     r10,r10,r9
    and     r8, r8, r9
    orr     r6, r10,r8, lsl  #16	@ px3 | px4

    and     r12,lr, r7, lsr #15
    ldrh    r12,[r3, r12]
    and     r10, lr, r7, lsr #23
    ldrh    r10, [r3, r10]
    and     r7, lr, r7, lsr #7
    ldrh    r7, [r3, r7]

    and     r12,r12,r9
    and     r10,r10,r9
    orr     r10,r12,r10, lsl #16	@ px6 | px7

    and     r7, r7, r9
    add     r12,r12,r7
    add     r8, r8, r7
    mov     r8, r8, lsr #1
    mov     r12,r12,lsr #1
    orr     r8, r8,r12, lsl #16		@ (px4+px5)/2 | (px5+px6)/2

    subs    r2, r2, #1

    stmia   r0!, {r4,r5,r6,r8,r10}
    bne     .fl_32scale_bl2

    b       .fl_32scale_8bit

.fl_32scale_bl4:
    // TODO this should reflect the bl4 C algorithm, but it doesn't, it's bln.
    and     r9, r9, r9, lsl #1        @ nuke 2 LSBs to avoid spilling for n/4
.fl_32loop_bl4:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r4, lr, r12,lsl #1
    ldrh    r4, [r3, r4]
    and     r5, lr, r12,lsr #7
    ldrh    r5, [r3, r5]

    @ r4 = 1/4px0+3/4px1 : px0
    and     r4, r4, r9
    orr     r4, r4, r4, lsl #14       @ r4[31:16] = 1/4 pix_s 0
    and     r5, r5, r9
    sub     r6, r5, r5, lsr #2        @ r6 = 3/4 pix_s 1
    add     r4, r4, r6, lsl #16       @ pix_d 0, 1

    and     r6, lr, r12,lsr #15
    ldrh    r6, [r3, r6]
    and     r12,lr, r12,lsr #23
    ldrh    r12,[r3, r12]

    @ r5 = 3/4px2+1/4px3 : (px1+px2)/2
    and     r6, r6, r9
    add     r5, r5, r6
    mov     r5, r5, lsr #1
    sub     r6, r6, r6, lsr #2        @ r6 = 3/4 pix_s 2
    orr     r5, r5, r6, lsl #16

    and     r6, lr, r7, lsl #1
    ldrh    r6, [r3, r6]
    and     r12,r12,r9
    add     r5, r5, r12,lsl #14       @ pix_d 2, 3

    @ r6 = px4 : px3
    and     r6, r6, r9
    orr     r6, r12,r6, lsl #16       @ pix_d 4, 5

    @ r8 = (px5+px6)/2 : 1/4px4+3/4px5
    and     r12,lr, r7, lsr #7
    ldrh    r12,[r3, r12]
    and     r10,lr, r7, lsr #15
    ldrh    r10,[r3, r10]
    and     r12,r12,r9
    sub     r8, r12,r12,lsr #2        @ r8 = 3/4 pix_s 1
    add     r8, r8, r6, lsr #18

    and     r7, lr, r7, lsr #23
    ldrh    r7, [r3, r7]
    and     r10,r10,r9
    orr     r8, r8, r10,lsl #15
    add     r8, r8, r12,lsl #15       @ pix_d 6, 7

    @ r10 = px7 : 3/4px6+1/4px7
    sub     r10,r10,r10,lsr #2        @ r10= 3/4 pix_s 2
    and     r7, r7, r9
    add     r10,r10,r7, lsr #2        @ += 1/4 pix_s 3
    orr     r10,r10,r7, lsl #16       @ pix_d 8, 9

    subs    r2, r2, #1

    stmia   r0!, {r4,r5,r6,r8,r10}
    bne     .fl_32loop_bl4

.fl_32scale_8bit:
    ldr     r4, [r11, #OFS_EST_rendstatus]
    add     r0, r1, #320-256
    mov     r2, #256/8
    tst     r4, #PDRAW_32X_SCALE
    ldmeqfd sp!, {r4-r11,pc}
    mov     lr, #0xff

.fl_32scale_8bit_nn:
    ldr     r7,  [r1, #-4]!
    ldr     r12, [r1, #-4]!

    and     r4, lr, r12, lsl #0
    and     r5, lr, r12, lsr #8
    and     r6, lr, r12, lsr #16
    and     r10,lr, r12, lsr #24
    
    orr     r4, r4, r5, lsl #8
    orr     r5, r6, r6, lsl #8

    and     r6, lr, r7, lsl #0
    and     r8, lr, r7, lsr #8
    and     r12,lr, r7, lsr #16
    and     r7, lr, r7, lsr #24

    orr     r6, r10,r6, lsl  #8
    orr     r8, r8,r12, lsl #8

    subs    r2, r2, #1

    orr     r10,r12,r7, lsl #8

    strh    r10, [r0, #-2]!
    strh    r8, [r0, #-2]!
    strh    r6, [r0, #-2]!
    strh    r5, [r0, #-2]!
    strh    r4, [r0, #-2]!

    bne     .fl_32scale_8bit_nn

    ldmfd   sp!, {r4-r11,pc}


.fl_20scale_RGB555:
    ldr     r5, [r5, #OFS_PicoIn_filter-OFS_PicoIn_opt]

    mov     r9, #0xf700 @ f800 07e0 001f | e000 0780 001c | 3800 01e0 0007
    orr     r9, r9, #0x00de

#ifdef UNALIGNED_DRAWLINEDEST
    tst     r0, #2
    bne     .fl_20scale_RGB555u
#endif

    and     r5, r5, #0x2
    add     pc, pc, r5, lsl #1
    nop
    b       .fl_20scale_nn
    b       .fl_20scale_bl2

.fl_20scale_nn:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r4, lr, r12, lsl #1
    ldrh    r4, [r3, r4]
    and     r5, lr, r12, lsr #7
    ldrh    r5, [r3, r5]
    and     r6, lr, r12, lsr #15
    ldrh    r6, [r3, r6]
    and     r8 ,lr, r12, lsr #23
    ldrh    r8 ,[r3, r8]

    orr     r4, r4, r4, lsl #16
    orr     r5, r5, r5, lsl #16
    orr     r6, r6, r6, lsl #16
    orr     r8, r8, r8, lsl #16
    stmia   r0!, {r4,r5,r6,r8}

    and     r4, lr, r7, lsl #1
    ldrh    r4, [r3, r4]
    and     r5, lr, r7, lsr #7
    ldrh    r5, [r3, r5]
    and     r6 ,lr, r7, lsr #15
    ldrh    r6 ,[r3, r6]
    and     r8, lr, r7, lsr #23
    ldrh    r8, [r3, r8]

    orr     r4, r4, r4, lsl #16
    orr     r5, r5, r5, lsl #16
    orr     r6, r6, r6, lsl #16
    orr     r8, r8, r8, lsl #16
    stmia   r0!, {r4,r5,r6,r8}

    subs    r2, r2, #1
    bne     .fl_20scale_nn

    ldmfd   sp!, {r4-r11,pc}


.fl_20scale_bl2:
    ldr     r8,  [r1]
    and     r8, lr, r8, lsl #1
    ldrh    r8, [r3, r8]
    and     r8, r8, r9
    mov     r8, r8, lsl #16

.fl_20loop_bl2:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r4, lr, r12, lsl #1
    ldrh    r4, [r3, r4]
    and     r5, lr, r12, lsr #7
    ldrh    r5, [r3, r5]
    and     r6, lr, r12, lsr #15
    ldrh    r6, [r3, r6]

    and     r4, r4, r9
    add     r10,r4, r8, lsr #16
    mov     r10,r10,lsr #1
    orr     r4, r10,r4, lsl #16		@ (px-1+px0)/2 | px0

    and     r8 ,lr, r12, lsr #23
    ldrh    r8 ,[r3, r8]

    and     r5, r5, r9
    add     r10,r5, r4, lsr #16
    mov     r10,r10,lsr #1
    orr     r5, r10,r5, lsl #16		@ (px0 +px1)/2 | px1

    and     r6, r6, r9
    add     r10,r6, r5, lsr #16
    mov     r10,r10,lsr #1
    orr     r6, r10,r6, lsl #16		@ (px1 +px2)/2 | px2

    and     r8, r8, r9
    add     r10,r8, r6, lsr #16
    mov     r10,r10,lsr #1
    orr     r8, r10,r8, lsl #16		@ (px2 +px3)/2 | px3

    stmia   r0!, {r4,r5,r6,r8}

    and     r4, lr, r7, lsl #1
    ldrh    r4, [r3, r4]
    and     r5, lr, r7, lsr #7
    ldrh    r5, [r3, r5]
    and     r6, lr, r7, lsr #15
    ldrh    r6, [r3, r6]

    and     r4, r4, r9
    add     r10,r4, r8, lsr #16
    mov     r10,r10,lsr #1
    orr     r4, r10,r4, lsl #16		@ (px-1+px0)/2 | px0

    and     r8 ,lr, r7, lsr #23
    ldrh    r8 ,[r3, r8]

    and     r5, r5, r9
    add     r10,r5, r4, lsr #16
    mov     r10,r10,lsr #1
    orr     r5, r10,r5, lsl #16		@ (px0 +px1)/2 | px1

    and     r6, r6, r9
    add     r10,r6, r5, lsr #16
    mov     r10,r10,lsr #1
    orr     r6, r10,r6, lsl #16		@ (px1 +px2)/2 | px2

    and     r8, r8, r9
    add     r10,r8, r6, lsr #16
    mov     r10,r10,lsr #1
    orr     r8, r10,r8, lsl #16		@ (px2 +px3)/2 | px3

    subs    r2, r2, #1
    stmia   r0!, {r4,r5,r6,r8}
    bne     .fl_20loop_bl2

    ldmfd   sp!, {r4-r11,pc}


#ifdef UNALIGNED_DRAWLINEDEST
    @ unaligned versions of loops
    @ warning: starts drawing 2bytes before dst

.fl_RGB555u:
    sub     r0, r0, #2              @ initial adjustment
    mov     r8, #0

.fl_loopRGB555u:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r6, lr, r12,lsl #1
    ldrh    r6, [r3, r6]
    and     r5, lr, r12,lsr #7
    ldrh    r5, [r3, r5]
    orr     r4, r8, r6, lsl #16

    and     r6, lr, r12,lsr #15
    ldrh    r6, [r3, r6]
    and     r8, lr, r12,lsr #23
    ldrh    r8, [r3, r8]
    orr     r5, r5, r6, lsl #16

    and     r6, lr, r7, lsl #1
    ldrh    r6, [r3, r6]
    and     r12,lr, r7, lsr #7
    ldrh    r12,[r3, r12]
    orr     r6, r8, r6, lsl #16

    and     r8, lr, r7, lsr #15
    ldrh    r8, [r3, r8]
    and     r7, lr, r7, lsr #23

    subs    r2, r2, #1
    orr     r12,r12,r8, lsl #16
    ldrh    r8, [r3, r7]

    stmia   r0!, {r4,r5,r6,r12}
    bne     .fl_loopRGB555u

    strh    r8, [r0], #2

    ldmfd   sp!, {r4-r11,pc}


.fl_32scale_RGB555u:
    sub     r0, r0, #2              @ initial adjustment
    mov     r4, #0

    @ r9  f800 07e0 001f | e000 0780 001c | 3800 01e0 0007
.fl_loop32scale_RGB555u:
    ldr     r12, [r1], #4
    ldr     r7,  [r1], #4

    and     r6, lr, r12,lsl #1
    ldrh    r6, [r3, r6]
    and     r5, lr, r12,lsr #7
    ldrh    r5, [r3, r5]
    and     r6, r6, r9
    orr     r4, r4, r6, lsl #16       @ r4 = pix_d -1, 0

    and     r5, r5, r9
    sub     r8, r5, r5, lsr #2        @ r8 = 3/4 pix_s 1
    add     r6, r8, r6, lsr #2        @ r6 = (1/4 pix_s 0) + (3/4 pix_s 1)
    orr     r5, r6, r5, lsl #15

    and     r6, lr, r12,lsr #15
    ldrh    r6, [r3, r6]
    and     r12,lr, r12,lsr #23
    ldrh    r12,[r3, r12]
    and     r6, r6, r9
    add     r5, r5, r6, lsl #15       @ r5 = pix_d 1, 2

    and     r8, lr, r7, lsl #1
    ldrh    r8, [r3, r8]
    and     r10,lr, r7, lsr #7
    ldrh    r10,[r3, r10]
    and     r12,r12,r9
    sub     r6, r6, r6, lsr #2        @ r6 = 3/4 pix_s 2
    add     r6, r6, r12,lsr #2
    orr     r6, r6, r12,lsl #16       @ r6 = pix_d 3, 4

    and     r8, r8, r9
    and     r10,r10,r9
    sub     r12,r10,r10,lsr #2        @ r12 = 3/4 pix_s 5
    orr     r8, r8, r8, lsl #14
    add     r8, r8, r12,lsl #16       @ r8 = pix_d 5, 6
    and     r12,lr, r7, lsr #15
    ldrh    r12,[r3, r12]
    and     r7, lr, r7, lsr #23
    ldrh    r7, [r3, r7]
    and     r12,r12,r9
    add     r10,r10,r12
    mov     r10,r10,    lsr #1
    sub     r12,r12,r12,lsr #2        @ r12 = 3/4 pix_s 6
    orr     r10,r10,r12,lsl #16
    and     r7, r7, r9
    add     r10,r10,r7, lsl #14       @ r10 = pix_d 7, 8

    subs    r2, r2, #1

    stmia   r0!, {r4,r5,r6,r8,r10}
    mov     r4, r7
    bne     .fl_loop32scale_RGB555u

    strh    r4, [r0], #2

    ldmfd   sp!, {r4-r11,pc}

#endif /* UNALIGNED_DRAWLINEDEST */


@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

@ utility
.global blockcpy @ void *dst, void *src, size_t n

blockcpy:
    stmfd   sp!, {r4,r5}
    cmp     r0, r1
    bhs     blockcpyhi

    subs    r2, r2, #16
    blt     blockcpy2
blockcpy_loop:
    ldmia   r1!, {r3-r5,r12}
    subs    r2, r2, #16
    stmia   r0!, {r3-r5,r12}
    bge     blockcpy_loop

blockcpy2:
    adds    r2, r2, #16-4
    ldmltfd sp!, {r4,r5}
    bxlt    lr

blockcpy_loop2:
    ldr     r3, [r1], #4
    subs    r2, r2, #4
    str     r3, [r0], #4
    bge     blockcpy_loop2

    ldmfd   sp!, {r4,r5}
    bx      lr

blockcpyhi:
    add     r0, r0, r2
    add     r1, r1, r2

    subs    r2, r2, #16
    blt     blockcpyhi2
blockcpyhi_loop:
    ldmdb   r1!, {r3-r5,r12}
    subs    r2, r2, #16
    stmdb   r0!, {r3-r5,r12}
    bge     blockcpyhi_loop

blockcpyhi2:
    adds    r2, r2, #16-4
    ldmltfd sp!, {r4,r5}
    bxlt    lr

blockcpyhi_loop2:
    ldr     r3, [r1, #-4]!
    subs    r2, r2, #4
    str     r3, [r0, #-4]!
    bge     blockcpyhi_loop2

    ldmfd   sp!, {r4,r5}
    bx      lr


.global blockcpy_or @ void *dst, void *src, size_t n, int pat

blockcpy_or:
    stmfd   sp!, {r4-r6}
    orr     r3, r3, r3, lsl #8
    orr     r3, r3, r3, lsl #16
    cmp     r0, r1
    bhs     blockcpyhi_or

    subs    r2, r2, #16
    blt     blockcpy_or2
blockcpy_loop_or:
    ldmia   r1!, {r4-r6,r12}
    subs    r2, r2, #16
    orr     r4, r4, r3
    orr     r5, r5, r3
    orr     r6, r6, r3
    orr     r12,r12,r3
    stmia   r0!, {r4-r6,r12}
    bge     blockcpy_loop_or

blockcpy_or2:
    adds    r2, r2, #16-4
    ldmltfd sp!, {r4-r6}
    bxlt    lr

blockcpy_loop_or2:
    ldr     r4, [r1], #4
    subs    r2, r2, #4
    orr     r4, r4, r3
    str     r4, [r0], #4
    bge     blockcpy_loop_or2

    ldmfd   sp!, {r4-r6}
    bx      lr

blockcpyhi_or:
    add     r0, r0, r2
    add     r1, r1, r2

    subs    r2, r2, #16
    blt     blockcpyhi_or2
blockcpyhi_loop_or:
    ldmdb   r1!, {r4-r6,r12}
    subs    r2, r2, #16
    orr     r4, r4, r3
    orr     r5, r5, r3
    orr     r6, r6, r3
    orr     r12,r12,r3
    stmdb   r0!, {r4-r6,r12}
    bge     blockcpyhi_loop_or

blockcpyhi_or2:
    adds    r2, r2, #16-4
    ldmltfd sp!, {r4-r6}
    bxlt    lr

blockcpyhi_loop_or2:
    ldr     r4, [r1, #-4]!
    subs    r2, r2, #4
    orr     r4, r4, r3
    str     r4, [r0, #-4]!
    bge     blockcpyhi_loop_or2

    ldmfd   sp!, {r4-r6}
    bx      lr

@ vim:filetype=armasm
