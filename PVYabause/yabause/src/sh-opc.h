/* Definitions for SH opcodes.
   Copyright (C) 1993, 94, 95, 96, 1997 Free Software Foundation, Inc.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  */

#ifdef  __cplusplus
extern "C" {
#endif


typedef enum {
	HEX_0,
	HEX_1,
	HEX_2,
	HEX_3,
	HEX_4,
	HEX_5,
	HEX_6,
	HEX_7,
	HEX_8,
	HEX_9,
	HEX_A,
	HEX_B,
	HEX_C,
	HEX_D,
	HEX_E,
	HEX_F,
	REG_N,
	REG_M,
	REG_NM,
        REG_B,
	BRANCH_12,
	BRANCH_8,
	DISP_8,
	DISP_4,
	IMM_4,
	IMM_4BY2,
	IMM_4BY4,
	PCRELIMM_8BY2,
	PCRELIMM_8BY4,
	IMM_8,
	IMM_8BY2,
	IMM_8BY4,
        IMM,
        PCRELIMM,
        BRANCH

} sh_nibble_type;

typedef enum {
	A_END,
	A_BDISP12,
	A_BDISP8,
	A_DEC_M,
	A_DEC_N,
	A_DISP_GBR,
	A_DISP_PC,
	A_DISP_REG_M,
	A_DISP_REG_N,
	A_GBR,
	A_IMM,
	A_INC_M,
	A_INC_N,
	A_IND_M,
	A_IND_N,
	A_IND_R0_REG_M,
	A_IND_R0_REG_N,
	A_MACH,
	A_MACL,
	A_PR,
	A_R0,
	A_R0_GBR,
	A_REG_M,
	A_REG_N,
	A_REG_B,
	A_SR,
	A_VBR,
	A_SSR,
	A_SPC,
	A_SGR,
	A_DBR,
	F_REG_N,
	F_REG_M,
	D_REG_N,
	D_REG_M,
	X_REG_N, /* Only used for argument parsing */
	X_REG_M, /* Only used for argument parsing */
	DX_REG_N,
	DX_REG_M,
	V_REG_N,
	V_REG_M,
	FD_REG_N,
	XMTRX_M4,
	F_FR0,
	FPUL_N,
	FPUL_M,
	FPSCR_N,
	FPSCR_M
} sh_arg_type;

typedef struct {
  char *name;
  sh_arg_type arg[4];
  sh_nibble_type nibbles[4];
} sh_opcode_info;



#ifdef  __cplusplus
}
#endif

