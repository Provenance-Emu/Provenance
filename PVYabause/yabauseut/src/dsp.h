/*  Copyright 2013 Theo Berkau

    This file is part of YabauseUT

    YabauseUT is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    YabauseUT is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with YabauseUT; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef DSPH
#define DSPH
void scu_dsp_test();
void test_dsp();
void test_mvi_imm_d();
void dsp_test_alu();
void test_dsp_timing();

#define NOP()           0x00000000

#define AND()           (1 << 26)
#define OR()            (2 << 26)
#define XOR()           (3 << 26)
#define ADD()           (4 << 26)
#define SUB()           (5 << 26)
#define AD2()           (6 << 26)
#define SR()            (8 << 26)
#define RR()            (9 << 26)
#define SL()            (10 << 26)
#define RL()            (11 << 26)
#define RL8()           (15 << 26)

#define MOVSRC_MC0      0x0 
#define MOVSRC_MC1      0x1
#define MOVSRC_MC2      0x2
#define MOVSRC_MC3      0x3
#define MOVSRC_MC0P     0x4
#define MOVSRC_MC1P     0x5
#define MOVSRC_MC2P     0x6
#define MOVSRC_MC3P     0x7
#define MOVSRC_ALUL     0x9
#define MOVSRC_ALUH     0xA

#define MOV_s_X(s) (0x02000000 | (s << 20))
#define MOV_MUL_P() (0x01000000)
#define MOV_s_P(s) (0x01800000 | (s << 20))

#define MOV_s_Y(s) (0x00080000 | (s << 14))
#define CLR_A() (0x00020000)
#define MOV_ALU_A() (0x00040000)
#define MOV_s_A(s) (0x00060000 | (s << 14))

#define MOVDEST_MC0     0x0
#define MOVDEST_MC1     0x1
#define MOVDEST_MC2     0x2
#define MOVDEST_MC3     0x3
#define MOVDEST_RX      0x4
#define MOVDEST_PL      0x5
#define MOVDEST_RA0     0x6
#define MOVDEST_WA0     0x7
#define MOVDEST_LOP     0xA
#define MOVDEST_TOP     0xB
#define MOVDEST_CT0     0xC
#define MOVDEST_CT1     0xD
#define MOVDEST_CT2     0xE
#define MOVDEST_CT3     0xF

#define MOV_Imm_d(imm, d) (0x00001000 | (d << 8) | ((imm) & 0xFF))
#define MOV_s_d(s, d) (0x00003000 | (d << 8) | (s))

#define MVIDEST_MC0     0x0
#define MVIDEST_MC1     0x1
#define MVIDEST_MC2     0x2
#define MVIDEST_MC3     0x3
#define MVIDEST_RX      0x4
#define MVIDEST_PL      0x5
#define MVIDEST_RA0     0x6
#define MVIDEST_WA0     0x7
#define MVIDEST_LOP     0xA
#define MVIDEST_PC      0xC

#define MVI_Imm_d(imm, d) (0x80000000 | ((imm) & 0x1FFFFFF) | (d << 26))
#define MVI_Imm_d_Z(imm, d) (0x82000000 | (0x21 << 19) | ((imm) & 0x7FFFF) | (d << 26))
#define MVI_Imm_d_NZ(imm, d) (0x82000000 | (0x1 << 19) | ((imm) & 0x7FFFF) | (d << 26))
#define MVI_Imm_d_S(imm, d) (0x82000000 | (0x22 << 19) | ((imm) & 0x7FFFF) | (d << 26))
#define MVI_Imm_d_NS(imm, d) (0x82000000 | (0x2 << 19) | ((imm) & 0x7FFFF) | (d << 26))
#define MVI_Imm_d_C(imm, d) (0x82000000 | (0x24 << 19) | ((imm) & 0x7FFFF) | (d << 26))
#define MVI_Imm_d_NC(imm, d) (0x82000000 | (0x4 << 19) | ((imm) & 0x7FFFF) | (d << 26))
#define MVI_Imm_d_T0(imm, d) (0x82000000 | (0x28 << 19) | ((imm) & 0x7FFFF) | (d << 26))
#define MVI_Imm_d_NT0(imm, d) (0x82000000 | (0x8 << 19) | ((imm) & 0x7FFFF) | (d << 26))
#define MVI_Imm_d_ZS(imm, d) (0x82000000 | (0x23 << 19) | ((imm) & 0x7FFFF) | (d << 26))
#define MVI_Imm_d_NZS(imm, d) (0x82000000 | (0x3 << 19) | ((imm) & 0x7FFFF) | (d << 26))

#define DMAADD_0        0x0
#define DMAADD_1        0x1
#define DMAADD_2        0x2
#define DMAADD_4        0x3
#define DMAADD_8        0x4
#define DMAADD_16       0x5
#define DMAADD_32       0x6
#define DMAADD_64       0x7

#define DMARAM_0        0x0
#define DMARAM_1        0x1
#define DMARAM_2        0x2
#define DMARAM_3        0x3
#define DMARAM_PROG     0x4

#define DMA_D0_RAM_Imm(add, ram, imm) (0xC0000000 | (add << 15) | (ram << 8) | (imm & 0xFF))
#define DMA_RAM_D0_Imm(add, ram, imm) (0xC0001000 | (add << 15) | (ram << 8) | (imm & 0xFF))

#define DMA_D0_RAM_s(add, ram, s) (0xC0002000 | (add << 15) | (ram << 8) | s)
#define DMA_RAM_D0_s(add, ram, s) (0xC0003000 | (add << 15) | (ram << 8) | s)

//#define DMAH_D0_RAM_Imm(add, ram, imm) (0xC??????? | (add << 15) | (ram << 8) | (imm & 0xFF))
//#define DMAH_RAM_D0_Imm(add, ram, imm) (0xC??????? | (add << 15) | (ram << 8) | (imm & 0xFF))

//#define DMA_D0_RAM_s(add, ram, s) (0xC??????? | (add << 15) | (ram << 8) | s)
//#define DMA_RAM_D0_s(add, ram, s) (0xC??????? | (add << 15) | (ram << 8) | s)

#define JMP_Imm(imm) (0xD0000000 | (imm & 0xFF))
#define JMP_Z_Imm(imm) ()
#define JMP_NZ_Imm(imm) ()
#define JMP_S_Imm(imm) ()
#define JMP_NS_Imm(imm) ()
#define JMP_C_Imm(imm) ()
#define JMP_NC_Imm(imm) ()
#define JMP_T0_Imm(imm) ()
#define JMP_NT0_Imm(imm) ()
#define JMP_ZS_Imm(imm) ()
#define JMP_NZS_Imm(imm) ()

#define BTM() (0xE0000000)
#define LPS() (0xE8000000)

#define END() (0xF0000000)
#define ENDI() (0xF8000000)
#endif
