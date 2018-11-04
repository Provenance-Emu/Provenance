#pragma once
#include "types.h"
#include "../sh4_interpreter.h"

/* Opcodes :) */

//stc SR,<REG_N>
sh4op(i0000_nnnn_0000_0010);
//stc GBR,<REG_N>
sh4op(i0000_nnnn_0001_0010);
//stc VBR,<REG_N>
sh4op(i0000_nnnn_0010_0010);
//stc SSR,<REG_N>
sh4op(i0000_nnnn_0011_0010);
 //stc SGR,<REG_N>
sh4op(i0000_nnnn_0011_1010);
//stc SPC,<REG_N>
sh4op(i0000_nnnn_0100_0010);
//stc R0_BANK,<REG_N>
sh4op(i0000_nnnn_1mmm_0010);
//braf <REG_N>
sh4op(i0000_nnnn_0010_0011);
//bsrf <REG_N>
sh4op(i0000_nnnn_0000_0011);
//movca.l R0, @<REG_N>
sh4op(i0000_nnnn_1100_0011);
//ocbi @<REG_N>
sh4op(i0000_nnnn_1001_0011);
//ocbp @<REG_N>
sh4op(i0000_nnnn_1010_0011);
//ocbwb @<REG_N>
sh4op(i0000_nnnn_1011_0011);
//pref @<REG_N>
sh4op(i0000_nnnn_1000_0011);
//mov.b <REG_M>,@(R0,<REG_N>)
sh4op(i0000_nnnn_mmmm_0100);
//mov.w <REG_M>,@(R0,<REG_N>)
sh4op(i0000_nnnn_mmmm_0101);
//mov.l <REG_M>,@(R0,<REG_N>)
sh4op(i0000_nnnn_mmmm_0110);
//mul.l <REG_M>,<REG_N>
sh4op(i0000_nnnn_mmmm_0111);
//clrmac
sh4op(i0000_0000_0010_1000);
//clrs
sh4op(i0000_0000_0100_1000);
//clrt
sh4op(i0000_0000_0000_1000);
//ldtlb
sh4op(i0000_0000_0011_1000);
//sets
sh4op(i0000_0000_0101_1000);
//sett
sh4op(i0000_0000_0001_1000);
//div0u
sh4op(i0000_0000_0001_1001);
//movt <REG_N>
sh4op(i0000_nnnn_0010_1001);
//nop
sh4op(i0000_0000_0000_1001);
//sts FPUL,<REG_N>
sh4op(i0000_nnnn_0101_1010);
//sts FPSCR,<REG_N>
sh4op(i0000_nnnn_0110_1010);
//stc GBR,<REG_N>
sh4op(i0000_nnnn_1111_1010);
//sts MACH,<REG_N>
sh4op(i0000_nnnn_0000_1010);
//sts MACL,<REG_N>
sh4op(i0000_nnnn_0001_1010);
//sts PR,<REG_N>
sh4op(i0000_nnnn_0010_1010);
//rte
sh4op(i0000_0000_0010_1011);
//rts
sh4op(i0000_0000_0000_1011);
//sleep
sh4op(i0000_0000_0001_1011);
//mov.b @(R0,<REG_M>),<REG_N>
sh4op(i0000_nnnn_mmmm_1100);
//mov.w @(R0,<REG_M>),<REG_N>
sh4op(i0000_nnnn_mmmm_1101);
//mov.l @(R0,<REG_M>),<REG_N>
sh4op(i0000_nnnn_mmmm_1110);
//mac.l @<REG_M>+,@<REG_N>+
sh4op(i0000_nnnn_mmmm_1111);
//
// 1xxx

//mov.l <REG_M>,@(<disp>,<REG_N>)
sh4op(i0001_nnnn_mmmm_iiii);
//
//	2xxx

//mov.b <REG_M>,@<REG_N>
sh4op(i0010_nnnn_mmmm_0000);
// mov.w <REG_M>,@<REG_N>
sh4op(i0010_nnnn_mmmm_0001);
// mov.l <REG_M>,@<REG_N>
sh4op(i0010_nnnn_mmmm_0010);
// mov.b <REG_M>,@-<REG_N>
sh4op(i0010_nnnn_mmmm_0100);
//mov.w <REG_M>,@-<REG_N>
sh4op(i0010_nnnn_mmmm_0101);
//mov.l <REG_M>,@-<REG_N>
sh4op(i0010_nnnn_mmmm_0110);
// div0s <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_0111);
// tst <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1000);
//and <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1001);
//xor <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1010);
//or <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1011);
//cmp/str <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1100);
//xtrct <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1101);
//mulu <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1110);
//muls <REG_M>,<REG_N>
sh4op(i0010_nnnn_mmmm_1111);

//
// 3xxx
// cmp/eq <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0000);
// cmp/hs <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0010);
//cmp/ge <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0011);
//div1 <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0100);
//dmulu.l <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0101);
// cmp/hi <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0110);
//cmp/gt <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_0111);
// sub <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1000);
//subc <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1010);
//subv <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1011);
//add <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1100);
//dmuls.l <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1101);
//addc <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1110);
// addv <REG_M>,<REG_N>
sh4op(i0011_nnnn_mmmm_1111);

//
// 4xxx
//sts.l FPUL,@-<REG_N>
sh4op(i0100_nnnn_0101_0010);
//sts.l FPSCR,@-<REG_N>
sh4op(i0100_nnnn_0110_0010);
//sts.l MACH,@-<REG_N>
sh4op(i0100_nnnn_0000_0010);
//sts.l MACL,@-<REG_N>
sh4op(i0100_nnnn_0001_0010);
//sts.l PR,@-<REG_N>
sh4op(i0100_nnnn_0010_0010);
 //sts.l DBR,@-<REG_N>
sh4op(i0100_nnnn_1111_0010);
//stc.l SR,@-<REG_N>
sh4op(i0100_nnnn_0000_0011);
//stc.l GBR,@-<REG_N>
sh4op(i0100_nnnn_0001_0011);
//stc.l VBR,@-<REG_N>
sh4op(i0100_nnnn_0010_0011);
//stc.l SSR,@-<REG_N>
sh4op(i0100_nnnn_0011_0011);
 //stc.l SGR,@-<REG_N>
sh4op(i0100_nnnn_0011_0010);
//stc.l SPC,@-<REG_N>
sh4op(i0100_nnnn_0100_0011);
//stc Rm_BANK,@-<REG_N>
sh4op(i0100_nnnn_1mmm_0011);
//lds.l @<REG_N>+,MACH
sh4op(i0100_nnnn_0000_0110);
//lds.l @<REG_N>+,MACL
sh4op(i0100_nnnn_0001_0110);
//lds.l @<REG_N>+,PR
sh4op(i0100_nnnn_0010_0110);
//lds.l @<REG_N>+,FPUL
sh4op(i0100_nnnn_0101_0110);
//lds.l @<REG_N>+,FPSCR
sh4op(i0100_nnnn_0110_0110);
//ldc.l @<REG_N>+,DBR
sh4op(i0100_nnnn_1111_0110);
//ldc.l @<REG_N>+,SR
sh4op(i0100_nnnn_0000_0111);
//ldc.l @<REG_N>+,GBR
sh4op(i0100_nnnn_0001_0111);
//ldc.l @<REG_N>+,VBR
sh4op(i0100_nnnn_0010_0111);
//ldc.l @<REG_N>+,SSR
sh4op(i0100_nnnn_0011_0111);
  //ldc.l @<REG_N>+,SGR
sh4op(i0100_nnnn_0011_0110);
//ldc.l @<REG_N>+,SPC
sh4op(i0100_nnnn_0100_0111);
//ldc.l @<REG_N>+,R0_BANK
sh4op(i0100_nnnn_1mmm_0111);
//lds <REG_N>,MACH
sh4op(i0100_nnnn_0000_1010);
//lds <REG_N>,MACL
sh4op(i0100_nnnn_0001_1010);
//lds <REG_N>,PR
sh4op(i0100_nnnn_0010_1010);
//lds <REG_N>,FPUL
sh4op(i0100_nnnn_0101_1010);
//lds <REG_N>,FPSCR
sh4op(i0100_nnnn_0110_1010);
//ldc <REG_N>,GBR
sh4op(i0100_nnnn_1111_1010);
//ldc <REG_N>,SR
sh4op(i0100_nnnn_0000_1110);
//ldc <REG_N>,GBR
sh4op(i0100_nnnn_0001_1110);
//ldc <REG_N>,VBR
sh4op(i0100_nnnn_0010_1110);
//ldc <REG_N>,SSR
sh4op(i0100_nnnn_0011_1110);
 //ldc <REG_N>,SGR
sh4op(i0100_nnnn_0011_1010);
//ldc <REG_N>,SPC
sh4op(i0100_nnnn_0100_1110);
//ldc <REG_N>,R0_BANK
sh4op(i0100_nnnn_1mmm_1110);
//shll <REG_N>
sh4op(i0100_nnnn_0000_0000);
//4210
//dt <REG_N>
sh4op(i0100_nnnn_0001_0000);
//shal <REG_N>
sh4op(i0100_nnnn_0010_0000);
//shlr <REG_N>
sh4op(i0100_nnnn_0000_0001);
//cmp/pz <REG_N>
sh4op(i0100_nnnn_0001_0001);
//shar <REG_N>
sh4op(i0100_nnnn_0010_0001);
//rotcl <REG_N>
sh4op(i0100_nnnn_0010_0100);
//rotl <REG_N>
sh4op(i0100_nnnn_0000_0100);
//cmp/pl <REG_N>
sh4op(i0100_nnnn_0001_0101);
//rotcr <REG_N>
sh4op(i0100_nnnn_0010_0101);
//rotr <REG_N>
sh4op(i0100_nnnn_0000_0101);
//shll2 <REG_N>
sh4op(i0100_nnnn_0000_1000);
//shll8 <REG_N>
sh4op(i0100_nnnn_0001_1000);
//shll16 <REG_N>
sh4op(i0100_nnnn_0010_1000);
//shlr2 <REG_N>
sh4op(i0100_nnnn_0000_1001);
//shlr8 <REG_N>
sh4op(i0100_nnnn_0001_1001);
//shlr16 <REG_N>
sh4op(i0100_nnnn_0010_1001);
//jmp @<REG_N>
sh4op(i0100_nnnn_0010_1011);
//jsr @<REG_N>
sh4op(i0100_nnnn_0000_1011);
//tas.b @<REG_N>
sh4op(i0100_nnnn_0001_1011);
//shad <REG_M>,<REG_N>
sh4op(i0100_nnnn_mmmm_1100);
//shld <REG_M>,<REG_N>
sh4op(i0100_nnnn_mmmm_1101);
//mac.w @<REG_M>+,@<REG_N>+
sh4op(i0100_nnnn_mmmm_1111);

//
// 5xxx

//mov.l @(<disp>,<REG_M>),<REG_N>
sh4op(i0101_nnnn_mmmm_iiii);
//
// 6xxx
//mov.b @<REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_0000);
//mov.w @<REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_0001);
//mov.l @<REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_0010);
//mov <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_0011);
//mov.b @<REG_M>+,<REG_N>
sh4op(i0110_nnnn_mmmm_0100);
//mov.w @<REG_M>+,<REG_N>
sh4op(i0110_nnnn_mmmm_0101);
//mov.l @<REG_M>+,<REG_N>
sh4op(i0110_nnnn_mmmm_0110);
//not <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_0111);
//swap.b <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1000);
//swap.w <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1001);
//negc <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1010);
//neg <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1011);
//extu.b <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1100);
//extu.w <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1101);
//exts.b <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1110);
//exts.w <REG_M>,<REG_N>
sh4op(i0110_nnnn_mmmm_1111);
//
// 7xxx
//add #<imm>,<REG_N>
sh4op(i0111_nnnn_iiii_iiii);
//
// 8xxx

// bf <bdisp8>
sh4op(i1000_1011_iiii_iiii);
// bf.s <bdisp8>
sh4op(i1000_1111_iiii_iiii);
// bt <bdisp8>
sh4op(i1000_1001_iiii_iiii);
// bt.s <bdisp8>
sh4op(i1000_1101_iiii_iiii);
// cmp/eq #<imm>,R0
sh4op(i1000_1000_iiii_iiii);
// mov.b R0,@(<disp>,<REG_M>)
sh4op(i1000_0000_mmmm_iiii);
// mov.w R0,@(<disp>,<REG_M>)
sh4op(i1000_0001_mmmm_iiii);
// mov.b @(<disp>,<REG_M>),R0
sh4op(i1000_0100_mmmm_iiii);
// mov.w @(<disp>,<REG_M>),R0
sh4op(i1000_0101_mmmm_iiii);

//
// 9xxx

//mov.w @(<disp>,PC),<REG_N>
sh4op(i1001_nnnn_iiii_iiii);
//
// Axxx
// bra <bdisp12>
sh4op(i1010_iiii_iiii_iiii);
//
// Bxxx
// bsr <bdisp12>
sh4op(i1011_iiii_iiii_iiii);
//
// Cxxx
// mov.b R0,@(<disp>,GBR)
sh4op(i1100_0000_iiii_iiii);
// mov.w R0,@(<disp>,GBR)
sh4op(i1100_0001_iiii_iiii);
// mov.l R0,@(<disp>,GBR)
sh4op(i1100_0010_iiii_iiii);
// trapa #<imm>
sh4op(i1100_0011_iiii_iiii);
// mov.b @(<disp>,GBR),R0
sh4op(i1100_0100_iiii_iiii);
// mov.w @(<disp>,GBR),R0
sh4op(i1100_0101_iiii_iiii);
// mov.l @(<disp>,GBR),R0
sh4op(i1100_0110_iiii_iiii);
// mova @(<disp>,PC),R0
sh4op(i1100_0111_iiii_iiii);
// tst #<imm>,R0
sh4op(i1100_1000_iiii_iiii);
// and #<imm>,R0
sh4op(i1100_1001_iiii_iiii);
// xor #<imm>,R0
sh4op(i1100_1010_iiii_iiii);
// or #<imm>,R0
sh4op(i1100_1011_iiii_iiii);
// tst.b #<imm>,@(R0,GBR)
sh4op(i1100_1100_iiii_iiii);
// and.b #<imm>,@(R0,GBR)
sh4op(i1100_1101_iiii_iiii);
// xor.b #<imm>,@(R0,GBR)
sh4op(i1100_1110_iiii_iiii);
// or.b #<imm>,@(R0,GBR)
sh4op(i1100_1111_iiii_iiii);
//
// Dxxx

// mov.l @(<disp>,PC),<REG_N>
sh4op(i1101_nnnn_iiii_iiii);
//
// Exxx

// mov #<imm>,<REG_N>
sh4op(i1110_nnnn_iiii_iiii);

// Fxxx

//fadd <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0000);
//fsub <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0001);
//fmul <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0010);
//fdiv <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0011);
//fcmp/eq <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0100);
//fcmp/gt <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_0101);
//fmov.s @(R0,<REG_M>),<FREG_N>
sh4op(i1111_nnnn_mmmm_0110);
//fmov.s <FREG_M>,@(R0,<REG_N>)
sh4op(i1111_nnnn_mmmm_0111);
//fmov.s @<REG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_1000);
//fmov.s @<REG_M>+,<FREG_N>
sh4op(i1111_nnnn_mmmm_1001);
//fmov.s <FREG_M>,@<REG_N>
sh4op(i1111_nnnn_mmmm_1010);
//fmov.s <FREG_M>,@-<REG_N>
sh4op(i1111_nnnn_mmmm_1011);
//fmov <FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_1100);
//fabs <FREG_N>
sh4op(i1111_nnnn_0101_1101);
// FSCA FPUL, DRn//F0FD//1111_nnnn_1111_1101
sh4op(i1111_nnn0_1111_1101);
//fcnvds <DR_N>,FPUL
sh4op(i1111_nnnn_1011_1101);
//fcnvsd FPUL,<DR_N>
sh4op(i1111_nnnn_1010_1101);
//fipr <FV_M>,<FV_N>
sh4op(i1111_nnmm_1110_1101);
//fldi0 <FREG_N>
sh4op(i1111_nnnn_1000_1101);
//fldi1 <FREG_N>
sh4op(i1111_nnnn_1001_1101);
//flds <FREG_N>,FPUL
sh4op(i1111_nnnn_0001_1101);
//float FPUL,<FREG_N>
sh4op(i1111_nnnn_0010_1101);
//fneg <FREG_N>
sh4op(i1111_nnnn_0100_1101);
//frchg
sh4op(i1111_1011_1111_1101);
//fschg
sh4op(i1111_0011_1111_1101);
//fsqrt <FREG_N>
sh4op(i1111_nnnn_0110_1101);
//ftrc <FREG_N>, FPUL
sh4op(i1111_nnnn_0011_1101);
//fsts FPUL,<FREG_N>
sh4op(i1111_nnnn_0000_1101);
//fmac <FREG_0>,<FREG_M>,<FREG_N>
sh4op(i1111_nnnn_mmmm_1110);
//ftrv xmtrx,<FV_N>
sh4op(i1111_nn01_1111_1101);
//FSRRA
sh4op(i1111_nnnn_0111_1101);

sh4op(iNotImplemented);
