/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cached_interp.h                                         *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2002 Hacktarux                                          *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef M64P_DEVICE_R4300_CACHED_INTERP_H
#define M64P_DEVICE_R4300_CACHED_INTERP_H

#include <stddef.h>
#include <stdint.h>

struct r4300_core;
struct cached_interp;
struct r4300_idec;
struct precomp_block;
struct precomp_instr;

enum r4300_opcode r4300_decode(struct precomp_instr* inst, struct r4300_core* r4300, const struct r4300_idec* idec, uint32_t iw, uint32_t next_iw, const struct precomp_block* block);

int get_block_length(const struct precomp_block *block);
size_t get_block_memsize(const struct precomp_block *block);

void cached_interp_init_block(struct r4300_core* r4300, uint32_t address);
void cached_interp_free_block(struct precomp_block* block);

void cached_interp_recompile_block(struct r4300_core* r4300, const uint32_t* iw, struct precomp_block* block, uint32_t func);

void init_blocks(struct cached_interp* cinterp);
void free_blocks(struct cached_interp* cinterp);

void invalidate_cached_code_hacktarux(struct r4300_core* r4300, uint32_t address, size_t size);

void run_cached_interpreter(struct r4300_core* r4300);

/* Jumps to the given address. This is for the cached interpreter. */
void cached_interpreter_jump_to(struct r4300_core* r4300, uint32_t address);

void cached_interp_FIN_BLOCK(void);
void cached_interp_NOTCOMPILED(void);
void cached_interp_NOTCOMPILED2(void);
void cached_interp_NI(void);
void cached_interp_RESERVED(void);
void cached_interp_LB(void);
void cached_interp_LBU(void);
void cached_interp_LH(void);
void cached_interp_LHU(void);
void cached_interp_LL(void);
void cached_interp_LW(void);
void cached_interp_LWU(void);
void cached_interp_LWL(void);
void cached_interp_LWR(void);
void cached_interp_LD(void);
void cached_interp_LDL(void);
void cached_interp_LDR(void);
void cached_interp_SB(void);
void cached_interp_SH(void);
void cached_interp_SC(void);
void cached_interp_SW(void);
void cached_interp_SWL(void);
void cached_interp_SWR(void);
void cached_interp_SD(void);
void cached_interp_SDL(void);
void cached_interp_SDR(void);
void cached_interp_ADD(void);
void cached_interp_ADDU(void);
void cached_interp_ADDI(void);
void cached_interp_ADDIU(void);
void cached_interp_DADD(void);
void cached_interp_DADDU(void);
void cached_interp_DADDI(void);
void cached_interp_DADDIU(void);
void cached_interp_SUB(void);
void cached_interp_SUBU(void);
void cached_interp_DSUB(void);
void cached_interp_DSUBU(void);
void cached_interp_SLT(void);
void cached_interp_SLTU(void);
void cached_interp_SLTI(void);
void cached_interp_SLTIU(void);
void cached_interp_AND(void);
void cached_interp_ANDI(void);
void cached_interp_OR(void);
void cached_interp_ORI(void);
void cached_interp_XOR(void);
void cached_interp_XORI(void);
void cached_interp_NOR(void);
void cached_interp_LUI(void);
void cached_interp_NOP(void);
void cached_interp_SLL(void);
void cached_interp_SLLV(void);
void cached_interp_DSLL(void);
void cached_interp_DSLLV(void);
void cached_interp_DSLL32(void);
void cached_interp_SRL(void);
void cached_interp_SRLV(void);
void cached_interp_DSRL(void);
void cached_interp_DSRLV(void);
void cached_interp_DSRL32(void);
void cached_interp_SRA(void);
void cached_interp_SRAV(void);
void cached_interp_DSRA(void);
void cached_interp_DSRAV(void);
void cached_interp_DSRA32(void);
void cached_interp_MULT(void);
void cached_interp_MULTU(void);
void cached_interp_DMULT(void);
void cached_interp_DMULTU(void);
void cached_interp_DIV(void);
void cached_interp_DIVU(void);
void cached_interp_DDIV(void);
void cached_interp_DDIVU(void);
void cached_interp_MFHI(void);
void cached_interp_MTHI(void);
void cached_interp_MFLO(void);
void cached_interp_MTLO(void);
void cached_interp_J(void);
void cached_interp_J_OUT(void);
void cached_interp_J_IDLE(void);
void cached_interp_JAL(void);
void cached_interp_JAL_OUT(void);
void cached_interp_JAL_IDLE(void);
void cached_interp_JR(void);
void cached_interp_JR_OUT(void);
void cached_interp_JALR(void);
void cached_interp_JALR_OUT(void);
void cached_interp_BEQ(void);
void cached_interp_BEQ_OUT(void);
void cached_interp_BEQ_IDLE(void);
void cached_interp_BEQL(void);
void cached_interp_BEQL_OUT(void);
void cached_interp_BEQL_IDLE(void);
void cached_interp_BNE(void);
void cached_interp_BNE_OUT(void);
void cached_interp_BNE_IDLE(void);
void cached_interp_BNEL(void);
void cached_interp_BNEL_OUT(void);
void cached_interp_BNEL_IDLE(void);
void cached_interp_BLEZ(void);
void cached_interp_BLEZ_OUT(void);
void cached_interp_BLEZ_IDLE(void);
void cached_interp_BLEZL(void);
void cached_interp_BLEZL_OUT(void);
void cached_interp_BLEZL_IDLE(void);
void cached_interp_BGTZ(void);
void cached_interp_BGTZ_OUT(void);
void cached_interp_BGTZ_IDLE(void);
void cached_interp_BGTZL(void);
void cached_interp_BGTZL_OUT(void);
void cached_interp_BGTZL_IDLE(void);
void cached_interp_BLTZ(void);
void cached_interp_BLTZ_OUT(void);
void cached_interp_BLTZ_IDLE(void);
void cached_interp_BLTZAL(void);
void cached_interp_BLTZAL_OUT(void);
void cached_interp_BLTZAL_IDLE(void);
void cached_interp_BLTZL(void);
void cached_interp_BLTZL_OUT(void);
void cached_interp_BLTZL_IDLE(void);
void cached_interp_BLTZALL(void);
void cached_interp_BLTZALL_OUT(void);
void cached_interp_BLTZALL_IDLE(void);
void cached_interp_BGEZ(void);
void cached_interp_BGEZ_OUT(void);
void cached_interp_BGEZ_IDLE(void);
void cached_interp_BGEZAL(void);
void cached_interp_BGEZAL_OUT(void);
void cached_interp_BGEZAL_IDLE(void);
void cached_interp_BGEZL(void);
void cached_interp_BGEZL_OUT(void);
void cached_interp_BGEZL_IDLE(void);
void cached_interp_BGEZALL(void);
void cached_interp_BGEZALL_OUT(void);
void cached_interp_BGEZALL_IDLE(void);
void cached_interp_BC1F(void);
void cached_interp_BC1F_OUT(void);
void cached_interp_BC1F_IDLE(void);
void cached_interp_BC1FL(void);
void cached_interp_BC1FL_OUT(void);
void cached_interp_BC1FL_IDLE(void);
void cached_interp_BC1T(void);
void cached_interp_BC1T_OUT(void);
void cached_interp_BC1T_IDLE(void);
void cached_interp_BC1TL(void);
void cached_interp_BC1TL_OUT(void);
void cached_interp_BC1TL_IDLE(void);
void cached_interp_CACHE(void);
void cached_interp_ERET(void);
void cached_interp_SYNC(void);
void cached_interp_SYSCALL(void);
void cached_interp_TEQ(void);
void cached_interp_TLBP(void);
void cached_interp_TLBR(void);
void cached_interp_TLBWR(void);
void cached_interp_TLBWI(void);
void cached_interp_MFC0(void);
void cached_interp_MTC0(void);
void cached_interp_LWC1(void);
void cached_interp_LDC1(void);
void cached_interp_SWC1(void);
void cached_interp_SDC1(void);
void cached_interp_MFC1(void);
void cached_interp_DMFC1(void);
void cached_interp_CFC1(void);
void cached_interp_MTC1(void);
void cached_interp_DMTC1(void);
void cached_interp_CTC1(void);
void cached_interp_ABS_S(void);
void cached_interp_ABS_D(void);
void cached_interp_ADD_S(void);
void cached_interp_ADD_D(void);
void cached_interp_DIV_S(void);
void cached_interp_DIV_D(void);
void cached_interp_MOV_S(void);
void cached_interp_MOV_D(void);
void cached_interp_MUL_S(void);
void cached_interp_MUL_D(void);
void cached_interp_NEG_S(void);
void cached_interp_NEG_D(void);
void cached_interp_SQRT_S(void);
void cached_interp_SQRT_D(void);
void cached_interp_SUB_S(void);
void cached_interp_SUB_D(void);
void cached_interp_TRUNC_W_S(void);
void cached_interp_TRUNC_W_D(void);
void cached_interp_TRUNC_L_S(void);
void cached_interp_TRUNC_L_D(void);
void cached_interp_ROUND_W_S(void);
void cached_interp_ROUND_W_D(void);
void cached_interp_ROUND_L_S(void);
void cached_interp_ROUND_L_D(void);
void cached_interp_CEIL_W_S(void);
void cached_interp_CEIL_W_D(void);
void cached_interp_CEIL_L_S(void);
void cached_interp_CEIL_L_D(void);
void cached_interp_FLOOR_W_S(void);
void cached_interp_FLOOR_W_D(void);
void cached_interp_FLOOR_L_S(void);
void cached_interp_FLOOR_L_D(void);
void cached_interp_CVT_S_D(void);
void cached_interp_CVT_S_W(void);
void cached_interp_CVT_S_L(void);
void cached_interp_CVT_D_S(void);
void cached_interp_CVT_D_W(void);
void cached_interp_CVT_D_L(void);
void cached_interp_CVT_W_S(void);
void cached_interp_CVT_W_D(void);
void cached_interp_CVT_L_S(void);
void cached_interp_CVT_L_D(void);
void cached_interp_C_F_S(void);
void cached_interp_C_F_D(void);
void cached_interp_C_UN_S(void);
void cached_interp_C_UN_D(void);
void cached_interp_C_EQ_S(void);
void cached_interp_C_EQ_D(void);
void cached_interp_C_UEQ_S(void);
void cached_interp_C_UEQ_D(void);
void cached_interp_C_OLT_S(void);
void cached_interp_C_OLT_D(void);
void cached_interp_C_ULT_S(void);
void cached_interp_C_ULT_D(void);
void cached_interp_C_OLE_S(void);
void cached_interp_C_OLE_D(void);
void cached_interp_C_ULE_S(void);
void cached_interp_C_ULE_D(void);
void cached_interp_C_SF_S(void);
void cached_interp_C_SF_D(void);
void cached_interp_C_NGLE_S(void);
void cached_interp_C_NGLE_D(void);
void cached_interp_C_SEQ_S(void);
void cached_interp_C_SEQ_D(void);
void cached_interp_C_NGL_S(void);
void cached_interp_C_NGL_D(void);
void cached_interp_C_LT_S(void);
void cached_interp_C_LT_D(void);
void cached_interp_C_NGE_S(void);
void cached_interp_C_NGE_D(void);
void cached_interp_C_LE_S(void);
void cached_interp_C_LE_D(void);
void cached_interp_C_NGT_S(void);
void cached_interp_C_NGT_D(void);

#endif /* M64P_DEVICE_R4300_CACHED_INTERP_H */
