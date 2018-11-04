/* Code originally from Sega Saturn DeBuGgEr Written by TyRaNiD. 
   Released under Public Domain.   
*/

/*! \file sh2iasm.c
    \brief SH2 inline assembler.
*/

#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <stdlib.h>

#include "sh-opc.h"

#ifdef  __cplusplus
extern "C" {
#endif


sh_opcode_info sh_table[] = {

/* 0111nnnni8*1.... add #<imm>,<REG_N>  */{"add",{A_IMM,A_REG_N},{HEX_7,REG_N,IMM_8}},

/* 0011nnnnmmmm1100 add <REG_M>,<REG_N> */{"add",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_C}},

/* 0011nnnnmmmm1110 addc <REG_M>,<REG_N>*/{"addc",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_E}},

/* 0011nnnnmmmm1111 addv <REG_M>,<REG_N>*/{"addv",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_F}},

/* 11001001i8*1.... and #<imm>,R0       */{"and",{A_IMM,A_R0},{HEX_C,HEX_9,IMM_8}},

/* 0010nnnnmmmm1001 and <REG_M>,<REG_N> */{"and",{ A_REG_M,A_REG_N},{HEX_2,REG_N,REG_M,HEX_9}},

/* 11001101i8*1.... and.b #<imm>,@(R0,GBR)*/{"and.b",{A_IMM,A_R0_GBR},{HEX_C,HEX_D,IMM_8}},

/* 1010i12......... bra <bdisp12>       */{"bra",{A_BDISP12},{HEX_A,BRANCH_12}},

/* 1011i12......... bsr <bdisp12>       */{"bsr",{A_BDISP12},{HEX_B,BRANCH_12}},

/* 10001001i8p1.... bt <bdisp8>         */{"bt",{A_BDISP8},{HEX_8,HEX_9,BRANCH_8}},

/* 10001011i8p1.... bf <bdisp8>         */{"bf",{A_BDISP8},{HEX_8,HEX_B,BRANCH_8}},

/* 10001101i8p1.... bt.s <bdisp8>       */{"bt.s",{A_BDISP8},{HEX_8,HEX_D,BRANCH_8}},

/* 10001101i8p1.... bt/s <bdisp8>       */{"bt/s",{A_BDISP8},{HEX_8,HEX_D,BRANCH_8}},

/* 10001111i8p1.... bf.s <bdisp8>       */{"bf.s",{A_BDISP8},{HEX_8,HEX_F,BRANCH_8}},

/* 10001111i8p1.... bf/s <bdisp8>       */{"bf/s",{A_BDISP8},{HEX_8,HEX_F,BRANCH_8}},

/* 0000000000101000 clrmac              */{"clrmac",{0},{HEX_0,HEX_0,HEX_2,HEX_8}},

/* 0000000001001000 clrs                */{"clrs",{0},{HEX_0,HEX_0,HEX_4,HEX_8}},

/* 0000000000001000 clrt                */{"clrt",{0},{HEX_0,HEX_0,HEX_0,HEX_8}},

/* 10001000i8*1.... cmp/eq #<imm>,R0    */{"cmp/eq",{A_IMM,A_R0},{HEX_8,HEX_8,IMM_8}},

/* 0011nnnnmmmm0000 cmp/eq <REG_M>,<REG_N>*/{"cmp/eq",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_0}},

/* 0011nnnnmmmm0011 cmp/ge <REG_M>,<REG_N>*/{"cmp/ge",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_3}},

/* 0011nnnnmmmm0111 cmp/gt <REG_M>,<REG_N>*/{"cmp/gt",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_7}},

/* 0011nnnnmmmm0110 cmp/hi <REG_M>,<REG_N>*/{"cmp/hi",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_6}},

/* 0011nnnnmmmm0010 cmp/hs <REG_M>,<REG_N>*/{"cmp/hs",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_2}},

/* 0100nnnn00010101 cmp/pl <REG_N>      */{"cmp/pl",{A_REG_N},{HEX_4,REG_N,HEX_1,HEX_5}},

/* 0100nnnn00010001 cmp/pz <REG_N>      */{"cmp/pz",{A_REG_N},{HEX_4,REG_N,HEX_1,HEX_1}},

/* 0010nnnnmmmm1100 cmp/str <REG_M>,<REG_N>*/{"cmp/str",{ A_REG_M,A_REG_N},{HEX_2,REG_N,REG_M,HEX_C}},

/* 0010nnnnmmmm0111 div0s <REG_M>,<REG_N>*/{"div0s",{ A_REG_M,A_REG_N},{HEX_2,REG_N,REG_M,HEX_7}},

/* 0000000000011001 div0u               */{"div0u",{0},{HEX_0,HEX_0,HEX_1,HEX_9}},

/* 0011nnnnmmmm0100 div1 <REG_M>,<REG_N>*/{"div1",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_4}},

/* 0110nnnnmmmm1110 exts.b <REG_M>,<REG_N>*/{"exts.b",{ A_REG_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_E}},

/* 0110nnnnmmmm1111 exts.w <REG_M>,<REG_N>*/{"exts.w",{ A_REG_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_F}},

/* 0110nnnnmmmm1100 extu.b <REG_M>,<REG_N>*/{"extu.b",{ A_REG_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_C}},

/* 0110nnnnmmmm1101 extu.w <REG_M>,<REG_N>*/{"extu.w",{ A_REG_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_D}},

/* 0100nnnn00101011 jmp @<REG_N>        */{"jmp",{A_IND_N},{HEX_4,REG_N,HEX_2,HEX_B}},

/* 0100nnnn00001011 jsr @<REG_N>        */{"jsr",{A_IND_N},{HEX_4,REG_N,HEX_0,HEX_B}},

/* 0100nnnn00001110 ldc <REG_N>,SR      */{"ldc",{A_REG_N,A_SR},{HEX_4,REG_N,HEX_0,HEX_E}},

/* 0100nnnn00011110 ldc <REG_N>,GBR     */{"ldc",{A_REG_N,A_GBR},{HEX_4,REG_N,HEX_1,HEX_E}},

/* 0100nnnn00101110 ldc <REG_N>,VBR     */{"ldc",{A_REG_N,A_VBR},{HEX_4,REG_N,HEX_2,HEX_E}},

/* 0100nnnn00111110 ldc <REG_N>,SSR     */{"ldc",{A_REG_N,A_SSR},{HEX_4,REG_N,HEX_3,HEX_E}},

/* 0100nnnn01001110 ldc <REG_N>,SPC     */{"ldc",{A_REG_N,A_SPC},{HEX_4,REG_N,HEX_4,HEX_E}},

/* 0100nnnn01111110 ldc <REG_N>,DBR     */{"ldc",{A_REG_N,A_DBR},{HEX_4,REG_N,HEX_7,HEX_E}},

/* 0100nnnn1xxx1110 ldc <REG_N>,Rn_BANK */{"ldc",{A_REG_N,A_REG_B},{HEX_4,REG_N,REG_B,HEX_E}},

/* 0100nnnn00000111 ldc.l @<REG_N>+,SR  */{"ldc.l",{A_INC_N,A_SR},{HEX_4,REG_N,HEX_0,HEX_7}},

/* 0100nnnn00010111 ldc.l @<REG_N>+,GBR */{"ldc.l",{A_INC_N,A_GBR},{HEX_4,REG_N,HEX_1,HEX_7}},

/* 0100nnnn00100111 ldc.l @<REG_N>+,VBR */{"ldc.l",{A_INC_N,A_VBR},{HEX_4,REG_N,HEX_2,HEX_7}},

/* 0100nnnn00110111 ldc.l @<REG_N>+,SSR */{"ldc.l",{A_INC_N,A_SSR},{HEX_4,REG_N,HEX_3,HEX_7}},

/* 0100nnnn01000111 ldc.l @<REG_N>+,SPC */{"ldc.l",{A_INC_N,A_SPC},{HEX_4,REG_N,HEX_4,HEX_7}},

/* 0100nnnn01110111 ldc.l @<REG_N>+,DBR */{"ldc.l",{A_INC_N,A_DBR},{HEX_4,REG_N,HEX_7,HEX_7}},

/* 0100nnnn1xxx0111 ldc.l <REG_N>,Rn_BANK */{"ldc.l",{A_INC_N,A_REG_B},{HEX_4,REG_N,REG_B,HEX_7}},

/* 0100nnnn00001010 lds <REG_N>,MACH    */{"lds",{A_REG_N,A_MACH},{HEX_4,REG_N,HEX_0,HEX_A}},

/* 0100nnnn00011010 lds <REG_N>,MACL    */{"lds",{A_REG_N,A_MACL},{HEX_4,REG_N,HEX_1,HEX_A}},

/* 0100nnnn00101010 lds <REG_N>,PR      */{"lds",{A_REG_N,A_PR},{HEX_4,REG_N,HEX_2,HEX_A}},

/* 0100nnnn01011010 lds <REG_N>,FPUL    */{"lds",{A_REG_M,FPUL_N},{HEX_4,REG_M,HEX_5,HEX_A}},

/* 0100nnnn01101010 lds <REG_M>,FPSCR   */{"lds",{A_REG_M,FPSCR_N},{HEX_4,REG_M,HEX_6,HEX_A}},

/* 0100nnnn00000110 lds.l @<REG_N>+,MACH*/{"lds.l",{A_INC_N,A_MACH},{HEX_4,REG_N,HEX_0,HEX_6}},

/* 0100nnnn00010110 lds.l @<REG_N>+,MACL*/{"lds.l",{A_INC_N,A_MACL},{HEX_4,REG_N,HEX_1,HEX_6}},

/* 0100nnnn00100110 lds.l @<REG_N>+,PR  */{"lds.l",{A_INC_N,A_PR},{HEX_4,REG_N,HEX_2,HEX_6}},

/* 0100nnnn01010110 lds.l @<REG_M>+,FPUL*/{"lds.l",{A_INC_M,FPUL_N},{HEX_4,REG_M,HEX_5,HEX_6}},

/* 0100nnnn01100110 lds.l @<REG_M>+,FPSCR*/{"lds.l",{A_INC_M,FPSCR_N},{HEX_4,REG_M,HEX_6,HEX_6}},

/* 0000000000111000 ldtlb               */{"ldtlb",{0},{HEX_0,HEX_0,HEX_3,HEX_8}},

/* 0100nnnnmmmm1111 mac.w @<REG_M>+,@<REG_N>+*/{"mac.w",{A_INC_M,A_INC_N},{HEX_4,REG_N,REG_M,HEX_F}},

/* 1110nnnni8*1.... mov #<imm>,<REG_N>  */{"mov",{A_IMM,A_REG_N},{HEX_E,REG_N,IMM_8}},

/* 0110nnnnmmmm0011 mov <REG_M>,<REG_N> */{"mov",{ A_REG_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_3}},

/* 0000nnnnmmmm0100 mov.b <REG_M>,@(R0,<REG_N>)*/{"mov.b",{ A_REG_M,A_IND_R0_REG_N},{HEX_0,REG_N,REG_M,HEX_4}},

/* 0010nnnnmmmm0100 mov.b <REG_M>,@-<REG_N>*/{"mov.b",{ A_REG_M,A_DEC_N},{HEX_2,REG_N,REG_M,HEX_4}},

/* 0010nnnnmmmm0000 mov.b <REG_M>,@<REG_N>*/{"mov.b",{ A_REG_M,A_IND_N},{HEX_2,REG_N,REG_M,HEX_0}},

/* 10000100mmmmi4*1 mov.b @(<disp>,<REG_M>),R0*/{"mov.b",{A_DISP_REG_M,A_R0},{HEX_8,HEX_4,REG_M,IMM_4}},

/* 11000100i8*1.... mov.b @(<disp>,GBR),R0*/{"mov.b",{A_DISP_GBR,A_R0},{HEX_C,HEX_4,IMM_8}},

/* 0000nnnnmmmm1100 mov.b @(R0,<REG_M>),<REG_N>*/{"mov.b",{A_IND_R0_REG_M,A_REG_N},{HEX_0,REG_N,REG_M,HEX_C}},

/* 0110nnnnmmmm0100 mov.b @<REG_M>+,<REG_N>*/{"mov.b",{A_INC_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_4}},

/* 0110nnnnmmmm0000 mov.b @<REG_M>,<REG_N>*/{"mov.b",{A_IND_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_0}},

/* 10000000mmmmi4*1 mov.b R0,@(<disp>,<REG_M>)*/{"mov.b",{A_R0,A_DISP_REG_M},{HEX_8,HEX_0,REG_M,IMM_4}},

/* 11000000i8*1.... mov.b R0,@(<disp>,GBR)*/{"mov.b",{A_R0,A_DISP_GBR},{HEX_C,HEX_0,IMM_8}},

/* 0001nnnnmmmmi4*4 mov.l <REG_M>,@(<disp>,<REG_N>)*/{"mov.l",{ A_REG_M,A_DISP_REG_N},{HEX_1,REG_N,REG_M,IMM_4BY4}},

/* 0000nnnnmmmm0110 mov.l <REG_M>,@(R0,<REG_N>)*/{"mov.l",{ A_REG_M,A_IND_R0_REG_N},{HEX_0,REG_N,REG_M,HEX_6}},

/* 0010nnnnmmmm0110 mov.l <REG_M>,@-<REG_N>*/{"mov.l",{ A_REG_M,A_DEC_N},{HEX_2,REG_N,REG_M,HEX_6}},

/* 0010nnnnmmmm0010 mov.l <REG_M>,@<REG_N>*/{"mov.l",{ A_REG_M,A_IND_N},{HEX_2,REG_N,REG_M,HEX_2}},

/* 0101nnnnmmmmi4*4 mov.l @(<disp>,<REG_M>),<REG_N>*/{"mov.l",{A_DISP_REG_M,A_REG_N},{HEX_5,REG_N,REG_M,IMM_4BY4}},

/* 11000110i8*4.... mov.l @(<disp>,GBR),R0*/{"mov.l",{A_DISP_GBR,A_R0},{HEX_C,HEX_6,IMM_8BY4}},

/* 1101nnnni8p4.... mov.l @(<disp>,PC),<REG_N>*/{"mov.l",{A_DISP_PC,A_REG_N},{HEX_D,REG_N,PCRELIMM_8BY4}},

/* 0000nnnnmmmm1110 mov.l @(R0,<REG_M>),<REG_N>*/{"mov.l",{A_IND_R0_REG_M,A_REG_N},{HEX_0,REG_N,REG_M,HEX_E}},

/* 0110nnnnmmmm0110 mov.l @<REG_M>+,<REG_N>*/{"mov.l",{A_INC_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_6}},

/* 0110nnnnmmmm0010 mov.l @<REG_M>,<REG_N>*/{"mov.l",{A_IND_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_2}},

/* 11000010i8*4.... mov.l R0,@(<disp>,GBR)*/{"mov.l",{A_R0,A_DISP_GBR},{HEX_C,HEX_2,IMM_8BY4}},

/* 0000nnnnmmmm0101 mov.w <REG_M>,@(R0,<REG_N>)*/{"mov.w",{ A_REG_M,A_IND_R0_REG_N},{HEX_0,REG_N,REG_M,HEX_5}},

/* 0010nnnnmmmm0101 mov.w <REG_M>,@-<REG_N>*/{"mov.w",{ A_REG_M,A_DEC_N},{HEX_2,REG_N,REG_M,HEX_5}},

/* 0010nnnnmmmm0001 mov.w <REG_M>,@<REG_N>*/{"mov.w",{ A_REG_M,A_IND_N},{HEX_2,REG_N,REG_M,HEX_1}},

/* 10000101mmmmi4*2 mov.w @(<disp>,<REG_M>),R0*/{"mov.w",{A_DISP_REG_M,A_R0},{HEX_8,HEX_5,REG_M,IMM_4BY2}},

/* 11000101i8*2.... mov.w @(<disp>,GBR),R0*/{"mov.w",{A_DISP_GBR,A_R0},{HEX_C,HEX_5,IMM_8BY2}},

/* 1001nnnni8p2.... mov.w @(<disp>,PC),<REG_N>*/{"mov.w",{A_DISP_PC,A_REG_N},{HEX_9,REG_N,PCRELIMM_8BY2}},

/* 0000nnnnmmmm1101 mov.w @(R0,<REG_M>),<REG_N>*/{"mov.w",{A_IND_R0_REG_M,A_REG_N},{HEX_0,REG_N,REG_M,HEX_D}},

/* 0110nnnnmmmm0101 mov.w @<REG_M>+,<REG_N>*/{"mov.w",{A_INC_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_5}},

/* 0110nnnnmmmm0001 mov.w @<REG_M>,<REG_N>*/{"mov.w",{A_IND_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_1}},

/* 10000001mmmmi4*2 mov.w R0,@(<disp>,<REG_M>)*/{"mov.w",{A_R0,A_DISP_REG_M},{HEX_8,HEX_1,REG_M,IMM_4BY2}},

/* 11000001i8*2.... mov.w R0,@(<disp>,GBR)*/{"mov.w",{A_R0,A_DISP_GBR},{HEX_C,HEX_1,IMM_8BY2}},

/* 11000111i8p4.... mova @(<disp>,PC),R0*/{"mova",{A_DISP_PC,A_R0},{HEX_C,HEX_7,PCRELIMM_8BY4}},
/* 0000nnnn11000011 movca.l R0,@<REG_N> */{"movca.l",{A_R0,A_IND_N},{HEX_0,REG_N,HEX_C,HEX_3}},


/* 0000nnnn00101001 movt <REG_N>        */{"movt",{A_REG_N},{HEX_0,REG_N,HEX_2,HEX_9}},

/* 0010nnnnmmmm1111 muls <REG_M>,<REG_N>*/{"muls",{ A_REG_M,A_REG_N},{HEX_2,REG_N,REG_M,HEX_F}},

/* 0000nnnnmmmm0111 mul.l <REG_M>,<REG_N>*/{"mul.l",{ A_REG_M,A_REG_N},{HEX_0,REG_N,REG_M,HEX_7}},

/* 0010nnnnmmmm1110 mulu <REG_M>,<REG_N>*/{"mulu",{ A_REG_M,A_REG_N},{HEX_2,REG_N,REG_M,HEX_E}},

/* 0110nnnnmmmm1011 neg <REG_M>,<REG_N> */{"neg",{ A_REG_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_B}},

/* 0110nnnnmmmm1010 negc <REG_M>,<REG_N>*/{"negc",{ A_REG_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_A}},

/* 0000000000001001 nop                 */{"nop",{0},{HEX_0,HEX_0,HEX_0,HEX_9}},

/* 0110nnnnmmmm0111 not <REG_M>,<REG_N> */{"not",{ A_REG_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_7}},
/* 0000nnnn10010011 ocbi @<REG_N>       */{"ocbi",{A_IND_N},{HEX_0,REG_N,HEX_9,HEX_3}},

/* 0000nnnn10100011 ocbp @<REG_N>       */{"ocbp",{A_IND_N},{HEX_0,REG_N,HEX_A,HEX_3}},

/* 0000nnnn10110011 ocbwb @<REG_N>      */{"ocbwb",{A_IND_N},{HEX_0,REG_N,HEX_B,HEX_3}},


/* 11001011i8*1.... or #<imm>,R0        */{"or",{A_IMM,A_R0},{HEX_C,HEX_B,IMM_8}},

/* 0010nnnnmmmm1011 or <REG_M>,<REG_N>  */{"or",{ A_REG_M,A_REG_N},{HEX_2,REG_N,REG_M,HEX_B}},

/* 11001111i8*1.... or.b #<imm>,@(R0,GBR)*/{"or.b",{A_IMM,A_R0_GBR},{HEX_C,HEX_F,IMM_8}},

/* 0000nnnn10000011 pref @<REG_N>       */{"pref",{A_IND_N},{HEX_0,REG_N,HEX_8,HEX_3}},

/* 0100nnnn00100100 rotcl <REG_N>       */{"rotcl",{A_REG_N},{HEX_4,REG_N,HEX_2,HEX_4}},

/* 0100nnnn00100101 rotcr <REG_N>       */{"rotcr",{A_REG_N},{HEX_4,REG_N,HEX_2,HEX_5}},

/* 0100nnnn00000100 rotl <REG_N>        */{"rotl",{A_REG_N},{HEX_4,REG_N,HEX_0,HEX_4}},

/* 0100nnnn00000101 rotr <REG_N>        */{"rotr",{A_REG_N},{HEX_4,REG_N,HEX_0,HEX_5}},

/* 0000000000101011 rte                 */{"rte",{0},{HEX_0,HEX_0,HEX_2,HEX_B}},

/* 0000000000001011 rts                 */{"rts",{0},{HEX_0,HEX_0,HEX_0,HEX_B}},

/* 0000000001011000 sets                */{"sets",{0},{HEX_0,HEX_0,HEX_5,HEX_8}},
/* 0000000000011000 sett                */{"sett",{0},{HEX_0,HEX_0,HEX_1,HEX_8}},

/* 0100nnnnmmmm1100 shad <REG_M>,<REG_N>*/{"shad",{ A_REG_M,A_REG_N},{HEX_4,REG_N,REG_M,HEX_C}},

/* 0100nnnnmmmm1101 shld <REG_M>,<REG_N>*/{"shld",{ A_REG_M,A_REG_N},{HEX_4,REG_N,REG_M,HEX_D}},

/* 0100nnnn00100000 shal <REG_N>        */{"shal",{A_REG_N},{HEX_4,REG_N,HEX_2,HEX_0}},

/* 0100nnnn00100001 shar <REG_N>        */{"shar",{A_REG_N},{HEX_4,REG_N,HEX_2,HEX_1}},

/* 0100nnnn00000000 shll <REG_N>        */{"shll",{A_REG_N},{HEX_4,REG_N,HEX_0,HEX_0}},

/* 0100nnnn00101000 shll16 <REG_N>      */{"shll16",{A_REG_N},{HEX_4,REG_N,HEX_2,HEX_8}},

/* 0100nnnn00001000 shll2 <REG_N>       */{"shll2",{A_REG_N},{HEX_4,REG_N,HEX_0,HEX_8}},

/* 0100nnnn00011000 shll8 <REG_N>       */{"shll8",{A_REG_N},{HEX_4,REG_N,HEX_1,HEX_8}},

/* 0100nnnn00000001 shlr <REG_N>        */{"shlr",{A_REG_N},{HEX_4,REG_N,HEX_0,HEX_1}},

/* 0100nnnn00101001 shlr16 <REG_N>      */{"shlr16",{A_REG_N},{HEX_4,REG_N,HEX_2,HEX_9}},

/* 0100nnnn00001001 shlr2 <REG_N>       */{"shlr2",{A_REG_N},{HEX_4,REG_N,HEX_0,HEX_9}},

/* 0100nnnn00011001 shlr8 <REG_N>       */{"shlr8",{A_REG_N},{HEX_4,REG_N,HEX_1,HEX_9}},

/* 0000000000011011 sleep               */{"sleep",{0},{HEX_0,HEX_0,HEX_1,HEX_B}},

/* 0000nnnn00000010 stc SR,<REG_N>      */{"stc",{A_SR,A_REG_N},{HEX_0,REG_N,HEX_0,HEX_2}},

/* 0000nnnn00010010 stc GBR,<REG_N>     */{"stc",{A_GBR,A_REG_N},{HEX_0,REG_N,HEX_1,HEX_2}},

/* 0000nnnn00100010 stc VBR,<REG_N>     */{"stc",{A_VBR,A_REG_N},{HEX_0,REG_N,HEX_2,HEX_2}},

/* 0000nnnn00110010 stc SSR,<REG_N>     */{"stc",{A_SSR,A_REG_N},{HEX_0,REG_N,HEX_3,HEX_2}},

/* 0000nnnn01000010 stc SPC,<REG_N>     */{"stc",{A_SPC,A_REG_N},{HEX_0,REG_N,HEX_4,HEX_2}},

/* 0000nnnn01100010 stc SGR,<REG_N>     */{"stc",{A_SGR,A_REG_N},{HEX_0,REG_N,HEX_6,HEX_2}},

/* 0000nnnn01110010 stc DBR,<REG_N>     */{"stc",{A_DBR,A_REG_N},{HEX_0,REG_N,HEX_7,HEX_2}},

/* 0000nnnn1xxx0012 stc Rn_BANK,<REG_N> */{"stc",{A_REG_B,A_REG_N},{HEX_0,REG_N,REG_B,HEX_2}},

/* 0100nnnn00000011 stc.l SR,@-<REG_N>  */{"stc.l",{A_SR,A_DEC_N},{HEX_4,REG_N,HEX_0,HEX_3}},

/* 0100nnnn00010011 stc.l GBR,@-<REG_N> */{"stc.l",{A_GBR,A_DEC_N},{HEX_4,REG_N,HEX_1,HEX_3}},

/* 0100nnnn00100011 stc.l VBR,@-<REG_N> */{"stc.l",{A_VBR,A_DEC_N},{HEX_4,REG_N,HEX_2,HEX_3}},

/* 0100nnnn00110011 stc.l SSR,@-<REG_N> */{"stc.l",{A_SSR,A_DEC_N},{HEX_4,REG_N,HEX_3,HEX_3}},

/* 0100nnnn01000011 stc.l SPC,@-<REG_N> */{"stc.l",{A_SPC,A_DEC_N},{HEX_4,REG_N,HEX_4,HEX_3}},

/* 0100nnnn01100011 stc.l SGR,@-<REG_N> */{"stc.l",{A_SGR,A_DEC_N},{HEX_4,REG_N,HEX_6,HEX_3}},

/* 0100nnnn01110011 stc.l DBR,@-<REG_N> */{"stc.l",{A_DBR,A_DEC_N},{HEX_4,REG_N,HEX_7,HEX_3}},

/* 0100nnnn1xxx0012 stc.l Rn_BANK,@-<REG_N> */{"stc.l",{A_REG_B,A_DEC_N},{HEX_4,REG_N,REG_B,HEX_3}},

/* 0000nnnn00001010 sts MACH,<REG_N>    */{"sts",{A_MACH,A_REG_N},{HEX_0,REG_N,HEX_0,HEX_A}},

/* 0000nnnn00011010 sts MACL,<REG_N>    */{"sts",{A_MACL,A_REG_N},{HEX_0,REG_N,HEX_1,HEX_A}},

/* 0000nnnn00101010 sts PR,<REG_N>      */{"sts",{A_PR,A_REG_N},{HEX_0,REG_N,HEX_2,HEX_A}},

/* 0000nnnn01011010 sts FPUL,<REG_N>    */{"sts",{FPUL_M,A_REG_N},{HEX_0,REG_N,HEX_5,HEX_A}},

/* 0000nnnn01101010 sts FPSCR,<REG_N>   */{"sts",{FPSCR_M,A_REG_N},{HEX_0,REG_N,HEX_6,HEX_A}},

/* 0100nnnn00000010 sts.l MACH,@-<REG_N>*/{"sts.l",{A_MACH,A_DEC_N},{HEX_4,REG_N,HEX_0,HEX_2}},

/* 0100nnnn00010010 sts.l MACL,@-<REG_N>*/{"sts.l",{A_MACL,A_DEC_N},{HEX_4,REG_N,HEX_1,HEX_2}},

/* 0100nnnn00100010 sts.l PR,@-<REG_N>  */{"sts.l",{A_PR,A_DEC_N},{HEX_4,REG_N,HEX_2,HEX_2}},

/* 0100nnnn01010010 sts.l FPUL,@-<REG_N>*/{"sts.l",{FPUL_M,A_DEC_N},{HEX_4,REG_N,HEX_5,HEX_2}},

/* 0100nnnn01100010 sts.l FPSCR,@-<REG_N>*/{"sts.l",{FPSCR_M,A_DEC_N},{HEX_4,REG_N,HEX_6,HEX_2}},

/* 0011nnnnmmmm1000 sub <REG_M>,<REG_N> */{"sub",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_8}},

/* 0011nnnnmmmm1010 subc <REG_M>,<REG_N>*/{"subc",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_A}},

/* 0011nnnnmmmm1011 subv <REG_M>,<REG_N>*/{"subv",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_B}},

/* 0110nnnnmmmm1000 swap.b <REG_M>,<REG_N>*/{"swap.b",{ A_REG_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_8}},

/* 0110nnnnmmmm1001 swap.w <REG_M>,<REG_N>*/{"swap.w",{ A_REG_M,A_REG_N},{HEX_6,REG_N,REG_M,HEX_9}},

/* 0100nnnn00011011 tas.b @<REG_N>      */{"tas.b",{A_IND_N},{HEX_4,REG_N,HEX_1,HEX_B}},

/* 11000011i8*1.... trapa #<imm>        */{"trapa",{A_IMM},{HEX_C,HEX_3,IMM_8}},

/* 11001000i8*1.... tst #<imm>,R0       */{"tst",{A_IMM,A_R0},{HEX_C,HEX_8,IMM_8}},

/* 0010nnnnmmmm1000 tst <REG_M>,<REG_N> */{"tst",{ A_REG_M,A_REG_N},{HEX_2,REG_N,REG_M,HEX_8}},

/* 11001100i8*1.... tst.b #<imm>,@(R0,GBR)*/{"tst.b",{A_IMM,A_R0_GBR},{HEX_C,HEX_C,IMM_8}},

/* 11001010i8*1.... xor #<imm>,R0       */{"xor",{A_IMM,A_R0},{HEX_C,HEX_A,IMM_8}},

/* 0010nnnnmmmm1010 xor <REG_M>,<REG_N> */{"xor",{ A_REG_M,A_REG_N},{HEX_2,REG_N,REG_M,HEX_A}},

/* 11001110i8*1.... xor.b #<imm>,@(R0,GBR)*/{"xor.b",{A_IMM,A_R0_GBR},{HEX_C,HEX_E,IMM_8}},

/* 0010nnnnmmmm1101 xtrct <REG_M>,<REG_N>*/{"xtrct",{ A_REG_M,A_REG_N},{HEX_2,REG_N,REG_M,HEX_D}},

/* 0000nnnnmmmm0111 mul.l <REG_M>,<REG_N>*/{"mul.l",{ A_REG_M,A_REG_N},{HEX_0,REG_N,REG_M,HEX_7}},

/* 0100nnnn00010000 dt <REG_N>          */{"dt",{A_REG_N},{HEX_4,REG_N,HEX_1,HEX_0}},

/* 0011nnnnmmmm1101 dmuls.l <REG_M>,<REG_N>*/{"dmuls.l",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_D}},

/* 0011nnnnmmmm0101 dmulu.l <REG_M>,<REG_N>*/{"dmulu.l",{ A_REG_M,A_REG_N},{HEX_3,REG_N,REG_M,HEX_5}},

/* 0000nnnnmmmm1111 mac.l @<REG_M>+,@<REG_N>+*/{"mac.l",{A_INC_M,A_INC_N},{HEX_0,REG_N,REG_M,HEX_F}},

/* 0000nnnn00100011 braf <REG_N>       */{"braf",{A_REG_N},{HEX_0,REG_N,HEX_2,HEX_3}},

/* 0000nnnn00000011 bsrf <REG_N>       */{"bsrf",{A_REG_N},{HEX_0,REG_N,HEX_0,HEX_3}},

/* 1111nnnn01011101 fabs <F_REG_N>     */{"fabs",{FD_REG_N},{HEX_F,REG_N,HEX_5,HEX_D}},

/* 1111nnnnmmmm0000 fadd <F_REG_M>,<F_REG_N>*/{"fadd",{F_REG_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_0}},
/* 1111nnn0mmm00000 fadd <D_REG_M>,<D_REG_N>*/{"fadd",{D_REG_M,D_REG_N},{HEX_F,REG_N,REG_M,HEX_0}},

/* 1111nnnnmmmm0100 fcmp/eq <F_REG_M>,<F_REG_N>*/{"fcmp/eq",{F_REG_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_4}},
/* 1111nnn0mmm00100 fcmp/eq <D_REG_M>,<D_REG_N>*/{"fcmp/eq",{D_REG_M,D_REG_N},{HEX_F,REG_N,REG_M,HEX_4}},

/* 1111nnnnmmmm0101 fcmp/gt <F_REG_M>,<F_REG_N>*/{"fcmp/gt",{F_REG_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_5}},
/* 1111nnn0mmm00101 fcmp/gt <D_REG_M>,<D_REG_N>*/{"fcmp/gt",{D_REG_M,D_REG_N},{HEX_F,REG_N,REG_M,HEX_5}},

/* 1111nnn010111101 fcnvds <D_REG_N>,FPUL*/{"fcnvds",{D_REG_N,FPUL_M},{HEX_F,REG_N,HEX_B,HEX_D}},

/* 1111nnn010101101 fcnvsd FPUL,<D_REG_N>*/{"fcnvsd",{FPUL_M,D_REG_N},{HEX_F,REG_N,HEX_A,HEX_D}},

/* 1111nnnnmmmm0011 fdiv <F_REG_M>,<F_REG_N>*/{"fdiv",{F_REG_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_3}},
/* 1111nnn0mmm00011 fdiv <D_REG_M>,<D_REG_N>*/{"fdiv",{D_REG_M,D_REG_N},{HEX_F,REG_N,REG_M,HEX_3}},

/* 1111nnmm11101101 fipr <V_REG_M>,<V_REG_N>*/{"fipr",{V_REG_M,V_REG_N},{HEX_F,REG_NM,HEX_E,HEX_D}},

/* 1111nnnn10001101 fldi0 <F_REG_N>    */{"fldi0",{F_REG_N},{HEX_F,REG_N,HEX_8,HEX_D}},

/* 1111nnnn10011101 fldi1 <F_REG_N>    */{"fldi1",{F_REG_N},{HEX_F,REG_N,HEX_9,HEX_D}},

/* 1111nnnn00011101 flds <F_REG_N>,FPUL*/{"flds",{F_REG_N,FPUL_M},{HEX_F,REG_N,HEX_1,HEX_D}},

/* 1111nnnn00101101 float FPUL,<FD_REG_N>*/{"float",{FPUL_M,FD_REG_N},{HEX_F,REG_N,HEX_2,HEX_D}},

/* 1111nnnnmmmm1110 fmac FR0,<F_REG_M>,<F_REG_N>*/{"fmac",{F_FR0,F_REG_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_E}},

/* 1111nnnnmmmm1100 fmov <F_REG_M>,<F_REG_N>*/{"fmov",{F_REG_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_C}},
/* 1111nnnnmmmm1100 fmov <DX_REG_M>,<DX_REG_N>*/{"fmov",{DX_REG_M,DX_REG_N},{HEX_F,REG_N,REG_M,HEX_C}},

/* 1111nnnnmmmm1000 fmov @<REG_M>,<F_REG_N>*/{"fmov",{A_IND_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_8}},
/* 1111nnnnmmmm1000 fmov @<REG_M>,<DX_REG_N>*/{"fmov",{A_IND_M,DX_REG_N},{HEX_F,REG_N,REG_M,HEX_8}},

/* 1111nnnnmmmm1010 fmov <F_REG_M>,@<REG_N>*/{"fmov",{F_REG_M,A_IND_N},{HEX_F,REG_N,REG_M,HEX_A}},
/* 1111nnnnmmmm1010 fmov <DX_REG_M>,@<REG_N>*/{"fmov",{DX_REG_M,A_IND_N},{HEX_F,REG_N,REG_M,HEX_A}},

/* 1111nnnnmmmm1001 fmov @<REG_M>+,<F_REG_N>*/{"fmov",{A_INC_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_9}},
/* 1111nnnnmmmm1001 fmov @<REG_M>+,<DX_REG_N>*/{"fmov",{A_INC_M,DX_REG_N},{HEX_F,REG_N,REG_M,HEX_9}},

/* 1111nnnnmmmm1011 fmov <F_REG_M>,@-<REG_N>*/{"fmov",{F_REG_M,A_DEC_N},{HEX_F,REG_N,REG_M,HEX_B}},
/* 1111nnnnmmmm1011 fmov <DX_REG_M>,@-<REG_N>*/{"fmov",{DX_REG_M,A_DEC_N},{HEX_F,REG_N,REG_M,HEX_B}},

/* 1111nnnnmmmm0110 fmov @(R0,<REG_M>),<F_REG_N>*/{"fmov",{A_IND_R0_REG_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_6}},
/* 1111nnnnmmmm0110 fmov @(R0,<REG_M>),<DX_REG_N>*/{"fmov",{A_IND_R0_REG_M,DX_REG_N},{HEX_F,REG_N,REG_M,HEX_6}},

/* 1111nnnnmmmm0111 fmov <F_REG_M>,@(R0,<REG_N>)*/{"fmov",{F_REG_M,A_IND_R0_REG_N},{HEX_F,REG_N,REG_M,HEX_7}},
/* 1111nnnnmmmm0111 fmov <DX_REG_M>,@(R0,<REG_N>)*/{"fmov",{DX_REG_M,A_IND_R0_REG_N},{HEX_F,REG_N,REG_M,HEX_7}},

/* 1111nnnnmmmm1000 fmov.d @<REG_M>,<DX_REG_N>*/{"fmov.d",{A_IND_M,DX_REG_N},{HEX_F,REG_N,REG_M,HEX_8}},

/* 1111nnnnmmmm1010 fmov.d <DX_REG_M>,@<REG_N>*/{"fmov.d",{DX_REG_M,A_IND_N},{HEX_F,REG_N,REG_M,HEX_A}},

/* 1111nnnnmmmm1001 fmov.d @<REG_M>+,<DX_REG_N>*/{"fmov.d",{A_INC_M,DX_REG_N},{HEX_F,REG_N,REG_M,HEX_9}},

/* 1111nnnnmmmm1011 fmov.d <DX_REG_M>,@-<REG_N>*/{"fmov.d",{DX_REG_M,A_DEC_N},{HEX_F,REG_N,REG_M,HEX_B}},

/* 1111nnnnmmmm0110 fmov.d @(R0,<REG_M>),<DX_REG_N>*/{"fmov.d",{A_IND_R0_REG_M,DX_REG_N},{HEX_F,REG_N,REG_M,HEX_6}},

/* 1111nnnnmmmm0111 fmov.d <DX_REG_M>,@(R0,<REG_N>)*/{"fmov.d",{DX_REG_M,A_IND_R0_REG_N},{HEX_F,REG_N,REG_M,HEX_7}},

/* 1111nnnnmmmm1000 fmov.s @<REG_M>,<F_REG_N>*/{"fmov.s",{A_IND_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_8}},

/* 1111nnnnmmmm1010 fmov.s <F_REG_M>,@<REG_N>*/{"fmov.s",{F_REG_M,A_IND_N},{HEX_F,REG_N,REG_M,HEX_A}},

/* 1111nnnnmmmm1001 fmov.s @<REG_M>+,<F_REG_N>*/{"fmov.s",{A_INC_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_9}},

/* 1111nnnnmmmm1011 fmov.s <F_REG_M>,@-<REG_N>*/{"fmov.s",{F_REG_M,A_DEC_N},{HEX_F,REG_N,REG_M,HEX_B}},

/* 1111nnnnmmmm0110 fmov.s @(R0,<REG_M>),<F_REG_N>*/{"fmov.s",{A_IND_R0_REG_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_6}},

/* 1111nnnnmmmm0111 fmov.s <F_REG_M>,@(R0,<REG_N>)*/{"fmov.s",{F_REG_M,A_IND_R0_REG_N},{HEX_F,REG_N,REG_M,HEX_7}},

/* 1111nnnnmmmm0010 fmul <F_REG_M>,<F_REG_N>*/{"fmul",{F_REG_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_2}},
/* 1111nnn0mmm00010 fmul <D_REG_M>,<D_REG_N>*/{"fmul",{D_REG_M,D_REG_N},{HEX_F,REG_N,REG_M,HEX_2}},

/* 1111nnnn01001101 fneg <FD_REG_N>     */{"fneg",{FD_REG_N},{HEX_F,REG_N,HEX_4,HEX_D}},

/* 1111101111111101 frchg               */{"frchg",{0},{HEX_F,HEX_B,HEX_F,HEX_D}},

/* 1111001111111101 fschg               */{"fschg",{0},{HEX_F,HEX_3,HEX_F,HEX_D}},

/* 1111nnnn01101101 fsqrt <FD_REG_N>    */{"fsqrt",{FD_REG_N},{HEX_F,REG_N,HEX_6,HEX_D}},

/* 1111nnnn00001101 fsts FPUL,<F_REG_N>*/{"fsts",{FPUL_M,F_REG_N},{HEX_F,REG_N,HEX_0,HEX_D}},

/* 1111nnnnmmmm0001 fsub <F_REG_M>,<F_REG_N>*/{"fsub",{F_REG_M,F_REG_N},{HEX_F,REG_N,REG_M,HEX_1}},
/* 1111nnn0mmm00001 fsub <D_REG_M>,<D_REG_N>*/{"fsub",{D_REG_M,D_REG_N},{HEX_F,REG_N,REG_M,HEX_1}},

/* 1111nnnn00111101 ftrc <FD_REG_N>,FPUL*/{"ftrc",{FD_REG_N,FPUL_M},{HEX_F,REG_N,HEX_3,HEX_D}},

/* 1111nn0111111101 ftrv XMTRX_M4,<V_REG_n>*/{"ftrv",{XMTRX_M4,V_REG_N},{HEX_F,REG_NM,HEX_F,HEX_D}},

{ 0 } 
};




typedef struct
  {
    int type;
    int reg;
  }

sh_operand_info;  // Operand structure

void asm_bad(const char *str, char *err_msg)

// Displays an error message

{
    sprintf(err_msg, "ERROR : %s", str);
}

/* try and parse a reg name, returns number of chars consumed */
int parse_reg (const char *src, int *mode, int *reg)

// Ripped out of the gas asm

{
  /* We use !isalnum for the next character after the register name, to
     make sure that we won't accidentally recognize a symbol name such as
     'sram' as being a reference to the register 'sr'.  */

  if (src[0] == 'r')
    {
      if (src[1] == '1')
	{
	  if (src[2] >= '0' && src[2] <= '5' && ! isalnum (src[3]))
	    {
	      *mode = A_REG_N;
	      *reg = 10 + src[2] - '0';
	      return 3;
	    }
	}
      if (src[1] >= '0' && src[1] <= '9' && ! isalnum (src[2]))
	{
	  *mode = A_REG_N;
	  *reg = (src[1] - '0');
	  return 2;
	}
    }

  if (src[0] == 's' && src[1] == 'r' && ! isalnum (src[2]))
    {
      *mode = A_SR;
      return 2;
    }

  if (src[0] == 's' && src[1] == 'p' && ! isalnum (src[2]))
    {
      *mode = A_REG_N;
      *reg = 15;
      return 2;
    }

  if (src[0] == 'p' && src[1] == 'r' && ! isalnum (src[2]))
    {
      *mode = A_PR;
      return 2;
    }
  if (src[0] == 'p' && src[1] == 'c' && ! isalnum (src[2]))
    {
      *mode = A_DISP_PC;
      return 2;
    }
  if (src[0] == 'g' && src[1] == 'b' && src[2] == 'r' && ! isalnum (src[3]))
    {
      *mode = A_GBR;
      return 3;
    }
  if (src[0] == 'v' && src[1] == 'b' && src[2] == 'r' && ! isalnum (src[3]))
    {
      *mode = A_VBR;
      return 3;
    }

  if (src[0] == 'm' && src[1] == 'a' && src[2] == 'c' && ! isalnum (src[4]))
    {
      if (src[3] == 'l')
	{
	  *mode = A_MACL;
	  return 4;
	}
      if (src[3] == 'h')
	{
	  *mode = A_MACH;
	  return 4;
	}
    }

  return 0;
}

int strip_opname(const char *str,char *name)

// Strip out the opcode name and return in *name

{
   int pos;

   pos = 0;

   while((str[pos] != 32) && (str[pos] != 0))
   {
      name[pos] = str[pos];
      pos++;
   }

   name[pos] = 0;

   return pos;
}

int strip_arg(const char *str,char *arg)

// Strip out next arg in the string

{
    int pos;

    pos = 0;
    if(str[0] == '@')
    {
      if(str[1] == '(')
      {
        if(str[2] != 0)
        {
        do
        {
           arg[pos] = str[pos];
           pos++;
        }
        while((str[pos-1] != ')') && (str[pos] != 0));

        }
      }
      else
        while((str[pos] != ',') && (str[pos] != 0))
        {
           arg[pos] = str[pos];
           pos++;
        }
    }
    else
      while((str[pos] != ',') && (str[pos] != 0))
      {
          arg[pos] = str[pos];
          pos++;
      }

    arg[pos] = 0;

    return pos;
}

int parse_at(const char *arg,sh_operand_info *op, char *err_msg)

// Parse pointer arguement and return a operand info struct

{
    int mode;
    int len;

    if(arg[0] == 0)
      return 0;

    if(*arg == '-')
    {
       arg++;
       len = parse_reg(arg,&mode,&(op->reg));
       if(len == 0)
       {
          asm_bad("Cant find arg", err_msg);
          return 0;
       }
       if(mode != A_REG_N)
       {
          asm_bad("Invalid reg after @-", err_msg);
          return 0;
       }
       else
       {
          op->type = A_DEC_N;
       }
    }
    else
     if(*arg == '(')
     {
        arg++;
        len = parse_reg(arg,&mode,&(op->reg));
        if((len > 0) && (mode == A_REG_N))
        {
           arg+=len;
           if(op->reg != 0)
           {
              asm_bad("Must be @(R0,...)", err_msg);
              return 0;
           }
           if(arg[0] == ',')
              arg++;
           len = parse_reg(arg,&mode,&(op->reg));
           arg += len;
           if(mode == A_GBR)
           {
              op->type = A_R0_GBR;
           }
           else if (mode == A_REG_N)
           {
              op->type = A_IND_R0_REG_N;
           }
           else
           {
              asm_bad("Syntax error in @(R0,...)", err_msg);
              return 0;
           }

        }
        else
        {
           while((*(arg-1) != ',') && (*arg != 0))
              arg++;
           len = parse_reg(arg,&mode,&(op->reg));
           arg+=len;
           if(len)
           {
             if(mode == A_REG_N)
             {
                op->type = A_DISP_REG_N;
             }
             else if (mode == A_GBR)
             {
                op->type = A_DISP_GBR;
             }
             else if (mode == A_DISP_PC)
             {
                op->type = A_DISP_PC;
             }
             else
             {
                asm_bad("Bad syntax in @(disp,[Rn,GBR,PC])", err_msg);
                return 0;
             }
           }
           else
           {
              asm_bad("Bad syntax in @(disp,[Rn,GBR,PC])", err_msg);
              return 0;
           }
        }
        if(*arg != ')')
        {
          asm_bad("Expected a )", err_msg);
          return 0;
        }
     }
     else
     {
        arg += parse_reg(arg,&mode,&(op->reg));
        if(mode != A_REG_N)
        {
           asm_bad("Invalid register after @", err_msg);
           return 0;
        }
        if(arg[0] == '+')
        {
           op->type = A_INC_N;
        }
        else
        {
           op->type = A_IND_N;
        }
     }

    return 1;
}

int parse_arg(const char *arg,sh_operand_info *op, char *err_msg)

// Parse arg and return a filled operand struct

{
    int len,mode;

    if(arg[0] == 0)
    {
      op->type = 0;
      op->reg = 0;
      return 1;
    }

    if(*arg == '@')
    {
       arg++;
       return parse_at(arg,op, err_msg);
    }

    if(*arg == '#')
    {
       op->type = A_IMM;
       return 1;
    }

    len = parse_reg(arg,&mode,&(op->reg));
    if(len)
    {
       op->type = mode;
       return 1;
    }
    else
    {
       op->type = A_BDISP12;
       return 1;
    }


    return 0;
}

int fix_arg(int type,sh_operand_info *arg)

// Checks the arg with the opcode type and see if its matchable
// Returns 1 if possible to match and 0 if not

{
   if((type == A_DEC_M) && (arg->type == A_DEC_N))
     return 1;
   if((type == A_DISP_REG_M) && (arg->type == A_DISP_REG_N))
     return 1;
   if((type == A_INC_M) && (arg->type == A_INC_N))
     return 1;
   if((type == A_IND_M) && (arg->type == A_IND_N))
     return 1;
   if((type == A_IND_R0_REG_M) && (arg->type == A_IND_R0_REG_N))
     return 1;
   if((type == A_REG_M) && (arg->type == A_REG_N))
     return 1;
   if((type == A_BDISP8) && (arg->type == A_BDISP12))
     return 1;
   if((type == A_R0) && (arg->type == A_REG_N) && (arg->reg == 0))
     return 1;

   return 0;
}

int search_op(const char *name,sh_operand_info *arg1,sh_operand_info *arg2,sh_opcode_info *op)

// Search for a matching opcode and fix args if necessary

{
   int loop = 0;
   sh_operand_info arg1back,arg2back;

   arg1back = *arg1;
   arg2back = *arg2;

   while(strcmp(sh_table[loop].name,"ftrv"))
   {
      if(!strcmp(sh_table[loop].name,name))
      {
         if(sh_table[loop].arg[0] != 0)
         {
            if(fix_arg(sh_table[loop].arg[0],arg1))
               arg1->type = sh_table[loop].arg[0];
         }
         if(sh_table[loop].arg[1] != 0)
         {
            if(fix_arg(sh_table[loop].arg[1],arg2))
               arg2->type = sh_table[loop].arg[1];
         }

         if((arg1->type == sh_table[loop].arg[0]) &&
            (arg2->type == sh_table[loop].arg[1]))
         {
            *op = sh_table[loop];
            return 1;
         }

      }

      *arg1 = arg1back;
      *arg2 = arg2back;
      loop++;
   }

   return 0;
}

void insert(unsigned int *opcode,int value,int pos)

// Insert a nibble into the supplied word

{
    *opcode |= ((value & 0xF) << (12 - (pos * 4)));
}

unsigned long build_bytes(sh_opcode_info op,sh_operand_info a1,
                          sh_operand_info a2,sh_operand_info disp)

// Now we know the opcode then build its bytes. Returns opcode if valid
// and 0 if not.

{
    int loop;
    int i;
    unsigned int opcode;

    loop = 0;
    opcode = 0;
    while(loop < 4)
    {
       i = op.nibbles[loop];
       if(i < 16)
       {
          insert(&opcode,i,loop);
          loop++;
       }
       else
       {
          switch(i)
          {
            case REG_M   : if(a1.type == REG_M)
                             insert(&opcode,a1.reg,loop);
                           else
                             insert(&opcode,a2.reg,loop);
                           break;
            case REG_N   : if(a1.type == REG_N)
                             insert(&opcode,a1.reg,loop);
                           else
                             insert(&opcode,a2.reg,loop);
                           break;
            case DISP_4  :
            case IMM_4   : insert(&opcode,disp.reg&0xF,loop);
                           break;
            case IMM_4BY2: disp.reg >>= 1;
                           insert(&opcode,disp.reg&0xF,loop);
                           break;
            case IMM_4BY4: disp.reg >>= 2;
                           insert(&opcode,disp.reg&0xF,loop);
                           break;
            case BRANCH_12: insert(&opcode,(disp.reg >> 8) & 0xF,loop);
                            insert(&opcode,(disp.reg >> 4) & 0xF,loop+1);
                            insert(&opcode,disp.reg & 0xF,loop+2);
                            loop += 2;
                            break;
            case DISP_8   :
            case IMM_8    :
            case BRANCH_8 : insert(&opcode,(disp.reg >> 4) & 0xF,loop);
                            insert(&opcode,disp.reg & 0xF,loop+1);
                            loop += 1;
                            break;
            case PCRELIMM_8BY2:
            case IMM_8BY2 :
                            disp.reg >>= 1;
                            insert(&opcode,(disp.reg >> 4) & 0xF,loop);
                            insert(&opcode,disp.reg & 0xF,loop+1);
                            loop += 1;
                            break;
            case PCRELIMM_8BY4:
            case IMM_8BY4 :
                            disp.reg >>= 2;
                            insert(&opcode,(disp.reg >> 4) & 0xF,loop);
                            insert(&opcode,disp.reg & 0xF,loop+1);
                            loop += 1;
                            break;
          }
          loop++;
       }
    }
    return opcode;
}

int rebuild_args(const char *arg1,const char *arg2,sh_operand_info *a1,
                  sh_operand_info *a2,sh_operand_info *disp)

// Rebuild args into the maximum 3 args for building.
// Redefine type values to nibble equivalents and extract imm values.
// returns 1 on error

{
   char s1[30],s2[30];
   char *bp;

   strcpy(s1,arg1);
   strcpy(s2,arg2);
   bp = NULL;

   switch(a1->type)
   {
     case A_IND_R0_REG_M:
     case A_DEC_M:
     case A_INC_M:
     case A_IND_M:
     case A_REG_M: a1->type = REG_M;
                   break;
     case A_IND_R0_REG_N:
     case A_DEC_N:
     case A_INC_N:
     case A_IND_N:
     case A_REG_N: a1->type = REG_N;
                   break;
     case A_DISP_PC: disp->reg = strtol(&s1[2],&bp,16);
                     disp->type = PCRELIMM;
                     break;
     case A_DISP_GBR:disp->reg = strtol(&s1[2],&bp,16);
                     disp->type = IMM;
                     break;
     case A_DISP_REG_M: disp->reg = strtol(&s1[2],&bp,16);
                        disp->type = IMM;
                        a1->type = REG_M;
                        break;
     case A_DISP_REG_N: disp->reg = strtol(&s1[2],&bp,16);
                        disp->type = IMM;
                        a1->type = REG_N;
                        break;
     case A_IMM       : disp->reg = strtol(&s1[1],&bp,16);
                        disp->type = IMM;
                        break;
     case A_BDISP12   :
     case A_BDISP8    : disp->reg = strtol(s1,&bp,16);
                        disp->type = IMM;
                        break;

   }

   switch(a2->type)
   {
     case A_IND_R0_REG_M:
     case A_DEC_M:
     case A_INC_M:
     case A_IND_M:
     case A_REG_M: a2->type = REG_M;

                   break;
     case A_IND_R0_REG_N:
     case A_DEC_N:
     case A_INC_N:
     case A_IND_N:
     case A_REG_N: a2->type = REG_N;

                   break;
     case A_DISP_PC: disp->reg = strtol(&s2[2],&bp,16);
                     disp->type = PCRELIMM;
                     break;
     case A_DISP_GBR:disp->reg = strtol(&s2[2],&bp,16);
                     disp->type = IMM;
                     break;
     case A_DISP_REG_M: disp->reg = strtol(&s2[2],&bp,16);
                        disp->type = IMM;
                        a2->type = REG_M;
                        break;
     case A_DISP_REG_N: disp->reg = strtol(&s2[2],&bp,16);
                        disp->type = IMM;
                        a2->type = REG_N;
                        break;
     case A_IMM       : disp->reg = strtol(&s2[1],&bp,16);
                        disp->type = IMM;
                        break;
     case A_BDISP12   :
     case A_BDISP8    : disp->reg = strtol(s2,&bp,16);
                        disp->type = IMM;
                        break;
   }

   return 0;
}

int sh2iasm(char *str, char *err_msg)

// Function to do all the work

{
   char name[30];
   char arg1[30];
   char arg2[30];
   char *p;
   int loop;
   int oplen,arg1len,arg2len;
   sh_operand_info arg1info,arg2info,disp;
   sh_opcode_info opcode;

   arg1info.type = 0;
   arg1info.reg = 0;
   arg2info.type = 0;
   arg2info.reg = 0;
   //gets(str);
   p = str;
   while(*p == ' ')
     p++;

   if((oplen = strip_opname(p,name)) == 0)
    {
       asm_bad("No opcode", err_msg);
       return 0;
    }

   p += oplen;
   while(*p == ' ')
     p++;

   arg1len = strip_arg(p,arg1);
   p += arg1len;

   while(*p == ' ')
     p++;
   if(*p == ',')
     p++;
   while(*p == ' ')
     p++;

   arg2len = strip_arg(p,arg2);

   for(loop = 0;name[loop] != 0;loop++)
   {
       name[loop] = tolower(name[loop]);
   }
   for(loop = 0;arg1[loop] != 0;loop++)
      arg1[loop] = tolower(arg1[loop]);
   for(loop = 0;arg2[loop] != 0;loop++)
      arg2[loop] = tolower(arg2[loop]);

   if(!parse_arg(arg1,&arg1info,err_msg))
   {
      if(arg1[0] != 0)
        asm_bad("Arg 1", err_msg);
      return 0;
   }
   if(!parse_arg(arg2,&arg2info,err_msg))
   {
      if(arg2[0] != 0)
        asm_bad("Arg 2", err_msg);
      return 0;
   }

   if(!search_op(name,&arg1info,&arg2info,&opcode))
   {
     asm_bad("Invalid opcode. Likely doesn't exist or format is wrong\n", err_msg);
     return 0;
   }

   loop = 0;
   rebuild_args(arg1,arg2,&arg1info,&arg2info,&disp);
   return build_bytes(opcode,arg1info,arg2info,disp);
}



#ifdef  __cplusplus
}
#endif

