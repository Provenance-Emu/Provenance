/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - recomp.c                                                *
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

#include "recomp.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

#if defined(__GNUC__)
#include <unistd.h>
#ifndef __MINGW32__
#include <sys/mman.h>
#endif
#endif

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "device/r4300/cached_interp.h"
#include "device/r4300/cp0.h"
#include "device/r4300/idec.h"
#include "device/r4300/recomp_types.h"
#include "device/r4300/tlb.h"
#include "main/main.h"
#if defined(PROFILE)
#include "main/profile.h"
#endif

#if defined(__x86_64__)
  #include "x86_64/regcache.h"
#else
  #include "x86/regcache.h"
#endif

static void *malloc_exec(size_t size);
static void free_exec(void *ptr, size_t length);

/* defined in <arch>/assemble.c */
void init_assembler(struct r4300_core* r4300, void *block_jumps_table, int block_jumps_number, void *block_riprel_table, int block_riprel_number);
void free_assembler(struct r4300_core* r4300, void **block_jumps_table, int *block_jumps_number, void **block_riprel_table, int *block_riprel_number);
void passe2(struct r4300_core* r4300, struct precomp_instr *dest, int start, int end, struct precomp_block* block);

/* defined in <arch>/dynarec.c */
void genlink_subblock(struct r4300_core* r4300);
void genni(struct r4300_core* r4300);
void gennotcompiled(struct r4300_core* r4300);
void genfin_block(struct r4300_core* r4300);
#ifdef COMPARE_CORE
void gendebug(struct r4300_core* r4300);
#endif

void gen_RESERVED(struct r4300_core* r4300);

void gen_ADD(struct r4300_core* r4300);
void gen_ADDI(struct r4300_core* r4300);
void gen_ADDIU(struct r4300_core* r4300);
void gen_ADDU(struct r4300_core* r4300);
void gen_AND(struct r4300_core* r4300);
void gen_ANDI(struct r4300_core* r4300);
void gen_BC1F(struct r4300_core* r4300);
void gen_BC1F_IDLE(struct r4300_core* r4300);
void gen_BC1F_OUT(struct r4300_core* r4300);
void gen_BC1FL(struct r4300_core* r4300);
void gen_BC1FL_IDLE(struct r4300_core* r4300);
void gen_BC1FL_OUT(struct r4300_core* r4300);
void gen_BC1T(struct r4300_core* r4300);
void gen_BC1T_IDLE(struct r4300_core* r4300);
void gen_BC1T_OUT(struct r4300_core* r4300);
void gen_BC1TL(struct r4300_core* r4300);
void gen_BC1TL_IDLE(struct r4300_core* r4300);
void gen_BC1TL_OUT(struct r4300_core* r4300);
void gen_BEQ(struct r4300_core* r4300);
void gen_BEQ_IDLE(struct r4300_core* r4300);
void gen_BEQ_OUT(struct r4300_core* r4300);
void gen_BEQL(struct r4300_core* r4300);
void gen_BEQL_IDLE(struct r4300_core* r4300);
void gen_BEQL_OUT(struct r4300_core* r4300);
void gen_BGEZ(struct r4300_core* r4300);
void gen_BGEZ_IDLE(struct r4300_core* r4300);
void gen_BGEZ_OUT(struct r4300_core* r4300);
void gen_BGEZAL(struct r4300_core* r4300);
void gen_BGEZAL_IDLE(struct r4300_core* r4300);
void gen_BGEZAL_OUT(struct r4300_core* r4300);
void gen_BGEZALL(struct r4300_core* r4300);
void gen_BGEZALL_IDLE(struct r4300_core* r4300);
void gen_BGEZALL_OUT(struct r4300_core* r4300);
void gen_BGEZL(struct r4300_core* r4300);
void gen_BGEZL_IDLE(struct r4300_core* r4300);
void gen_BGEZL_OUT(struct r4300_core* r4300);
void gen_BGTZ(struct r4300_core* r4300);
void gen_BGTZ_IDLE(struct r4300_core* r4300);
void gen_BGTZ_OUT(struct r4300_core* r4300);
void gen_BGTZL(struct r4300_core* r4300);
void gen_BGTZL_IDLE(struct r4300_core* r4300);
void gen_BGTZL_OUT(struct r4300_core* r4300);
void gen_BLEZ(struct r4300_core* r4300);
void gen_BLEZ_IDLE(struct r4300_core* r4300);
void gen_BLEZ_OUT(struct r4300_core* r4300);
void gen_BLEZL(struct r4300_core* r4300);
void gen_BLEZL_IDLE(struct r4300_core* r4300);
void gen_BLEZL_OUT(struct r4300_core* r4300);
void gen_BLTZAL(struct r4300_core* r4300);
void gen_BLTZAL_IDLE(struct r4300_core* r4300);
void gen_BLTZAL_OUT(struct r4300_core* r4300);
void gen_BLTZALL(struct r4300_core* r4300);
void gen_BLTZALL_IDLE(struct r4300_core* r4300);
void gen_BLTZALL_OUT(struct r4300_core* r4300);
void gen_BLTZ(struct r4300_core* r4300);
void gen_BLTZ_IDLE(struct r4300_core* r4300);
void gen_BLTZ_OUT(struct r4300_core* r4300);
void gen_BLTZL(struct r4300_core* r4300);
void gen_BLTZL_IDLE(struct r4300_core* r4300);
void gen_BLTZL_OUT(struct r4300_core* r4300);
void gen_BNE(struct r4300_core* r4300);
void gen_BNE_IDLE(struct r4300_core* r4300);
void gen_BNE_OUT(struct r4300_core* r4300);
void gen_BNEL(struct r4300_core* r4300);
void gen_BNEL_IDLE(struct r4300_core* r4300);
void gen_BNEL_OUT(struct r4300_core* r4300);
void gen_CACHE(struct r4300_core* r4300);
void gen_CFC1(struct r4300_core* r4300);
void gen_CP1_ABS_D(struct r4300_core* r4300);
void gen_CP1_ABS_S(struct r4300_core* r4300);
void gen_CP1_ADD_D(struct r4300_core* r4300);
void gen_CP1_ADD_S(struct r4300_core* r4300);
void gen_CP1_CEIL_L_D(struct r4300_core* r4300);
void gen_CP1_CEIL_L_S(struct r4300_core* r4300);
void gen_CP1_CEIL_W_D(struct r4300_core* r4300);
void gen_CP1_CEIL_W_S(struct r4300_core* r4300);
void gen_CP1_C_EQ_D(struct r4300_core* r4300);
void gen_CP1_C_EQ_S(struct r4300_core* r4300);
void gen_CP1_C_F_D(struct r4300_core* r4300);
void gen_CP1_C_F_S(struct r4300_core* r4300);
void gen_CP1_C_LE_D(struct r4300_core* r4300);
void gen_CP1_C_LE_S(struct r4300_core* r4300);
void gen_CP1_C_LT_D(struct r4300_core* r4300);
void gen_CP1_C_LT_S(struct r4300_core* r4300);
void gen_CP1_C_NGE_D(struct r4300_core* r4300);
void gen_CP1_C_NGE_S(struct r4300_core* r4300);
void gen_CP1_C_NGL_D(struct r4300_core* r4300);
void gen_CP1_C_NGLE_D(struct r4300_core* r4300);
void gen_CP1_C_NGLE_S(struct r4300_core* r4300);
void gen_CP1_C_NGL_S(struct r4300_core* r4300);
void gen_CP1_C_NGT_D(struct r4300_core* r4300);
void gen_CP1_C_NGT_S(struct r4300_core* r4300);
void gen_CP1_C_OLE_D(struct r4300_core* r4300);
void gen_CP1_C_OLE_S(struct r4300_core* r4300);
void gen_CP1_C_OLT_D(struct r4300_core* r4300);
void gen_CP1_C_OLT_S(struct r4300_core* r4300);
void gen_CP1_C_SEQ_D(struct r4300_core* r4300);
void gen_CP1_C_SEQ_S(struct r4300_core* r4300);
void gen_CP1_C_SF_D(struct r4300_core* r4300);
void gen_CP1_C_SF_S(struct r4300_core* r4300);
void gen_CP1_C_UEQ_D(struct r4300_core* r4300);
void gen_CP1_C_UEQ_S(struct r4300_core* r4300);
void gen_CP1_C_ULE_D(struct r4300_core* r4300);
void gen_CP1_C_ULE_S(struct r4300_core* r4300);
void gen_CP1_C_ULT_D(struct r4300_core* r4300);
void gen_CP1_C_ULT_S(struct r4300_core* r4300);
void gen_CP1_C_UN_D(struct r4300_core* r4300);
void gen_CP1_C_UN_S(struct r4300_core* r4300);
void gen_CP1_CVT_D_L(struct r4300_core* r4300);
void gen_CP1_CVT_D_S(struct r4300_core* r4300);
void gen_CP1_CVT_D_W(struct r4300_core* r4300);
void gen_CP1_CVT_L_D(struct r4300_core* r4300);
void gen_CP1_CVT_L_S(struct r4300_core* r4300);
void gen_CP1_CVT_S_D(struct r4300_core* r4300);
void gen_CP1_CVT_S_L(struct r4300_core* r4300);
void gen_CP1_CVT_S_W(struct r4300_core* r4300);
void gen_CP1_CVT_W_D(struct r4300_core* r4300);
void gen_CP1_CVT_W_S(struct r4300_core* r4300);
void gen_CP1_DIV_D(struct r4300_core* r4300);
void gen_CP1_DIV_S(struct r4300_core* r4300);
void gen_CP1_FLOOR_L_D(struct r4300_core* r4300);
void gen_CP1_FLOOR_L_S(struct r4300_core* r4300);
void gen_CP1_FLOOR_W_D(struct r4300_core* r4300);
void gen_CP1_FLOOR_W_S(struct r4300_core* r4300);
void gen_CP1_MOV_D(struct r4300_core* r4300);
void gen_CP1_MOV_S(struct r4300_core* r4300);
void gen_CP1_MUL_D(struct r4300_core* r4300);
void gen_CP1_MUL_S(struct r4300_core* r4300);
void gen_CP1_NEG_D(struct r4300_core* r4300);
void gen_CP1_NEG_S(struct r4300_core* r4300);
void gen_CP1_ROUND_L_D(struct r4300_core* r4300);
void gen_CP1_ROUND_L_S(struct r4300_core* r4300);
void gen_CP1_ROUND_W_D(struct r4300_core* r4300);
void gen_CP1_ROUND_W_S(struct r4300_core* r4300);
void gen_CP1_SQRT_D(struct r4300_core* r4300);
void gen_CP1_SQRT_S(struct r4300_core* r4300);
void gen_CP1_SUB_D(struct r4300_core* r4300);
void gen_CP1_SUB_S(struct r4300_core* r4300);
void gen_CP1_TRUNC_L_D(struct r4300_core* r4300);
void gen_CP1_TRUNC_L_S(struct r4300_core* r4300);
void gen_CP1_TRUNC_W_D(struct r4300_core* r4300);
void gen_CP1_TRUNC_W_S(struct r4300_core* r4300);
void gen_CTC1(struct r4300_core* r4300);
void gen_DADD(struct r4300_core* r4300);
void gen_DADDI(struct r4300_core* r4300);
void gen_DADDIU(struct r4300_core* r4300);
void gen_DADDU(struct r4300_core* r4300);
void gen_DDIV(struct r4300_core* r4300);
void gen_DDIVU(struct r4300_core* r4300);
void gen_DIV(struct r4300_core* r4300);
void gen_DIVU(struct r4300_core* r4300);
void gen_DMFC1(struct r4300_core* r4300);
void gen_DMTC1(struct r4300_core* r4300);
void gen_DMULT(struct r4300_core* r4300);
void gen_DMULTU(struct r4300_core* r4300);
void gen_DSLL32(struct r4300_core* r4300);
void gen_DSLL(struct r4300_core* r4300);
void gen_DSLLV(struct r4300_core* r4300);
void gen_DSRA32(struct r4300_core* r4300);
void gen_DSRA(struct r4300_core* r4300);
void gen_DSRAV(struct r4300_core* r4300);
void gen_DSRL32(struct r4300_core* r4300);
void gen_DSRL(struct r4300_core* r4300);
void gen_DSRLV(struct r4300_core* r4300);
void gen_DSUB(struct r4300_core* r4300);
void gen_DSUBU(struct r4300_core* r4300);
void gen_ERET(struct r4300_core* r4300);
void gen_J(struct r4300_core* r4300);
void gen_J_IDLE(struct r4300_core* r4300);
void gen_J_OUT(struct r4300_core* r4300);
void gen_JAL(struct r4300_core* r4300);
void gen_JAL_IDLE(struct r4300_core* r4300);
void gen_JAL_OUT(struct r4300_core* r4300);
void gen_JALR(struct r4300_core* r4300);
void gen_JR(struct r4300_core* r4300);
void gen_LB(struct r4300_core* r4300);
void gen_LBU(struct r4300_core* r4300);
void gen_LDC1(struct r4300_core* r4300);
void gen_LDL(struct r4300_core* r4300);
void gen_LDR(struct r4300_core* r4300);
void gen_LD(struct r4300_core* r4300);
void gen_LH(struct r4300_core* r4300);
void gen_LHU(struct r4300_core* r4300);
void gen_LL(struct r4300_core* r4300);
void gen_LUI(struct r4300_core* r4300);
void gen_LWC1(struct r4300_core* r4300);
void gen_LWL(struct r4300_core* r4300);
void gen_LWR(struct r4300_core* r4300);
void gen_LW(struct r4300_core* r4300);
void gen_LWU(struct r4300_core* r4300);
void gen_MFC0(struct r4300_core* r4300);
void gen_MFC1(struct r4300_core* r4300);
void gen_MFHI(struct r4300_core* r4300);
void gen_MFLO(struct r4300_core* r4300);
void gen_MTC0(struct r4300_core* r4300);
void gen_MTC1(struct r4300_core* r4300);
void gen_MTHI(struct r4300_core* r4300);
void gen_MTLO(struct r4300_core* r4300);
void gen_MULT(struct r4300_core* r4300);
void gen_MULTU(struct r4300_core* r4300);
void gen_NOP(struct r4300_core* r4300);
void gen_NOR(struct r4300_core* r4300);
void gen_ORI(struct r4300_core* r4300);
void gen_OR(struct r4300_core* r4300);
void gen_SB(struct r4300_core* r4300);
void gen_SC(struct r4300_core* r4300);
void gen_SDC1(struct r4300_core* r4300);
void gen_SDL(struct r4300_core* r4300);
void gen_SDR(struct r4300_core* r4300);
void gen_SD(struct r4300_core* r4300);
void gen_SH(struct r4300_core* r4300);
void gen_SLL(struct r4300_core* r4300);
void gen_SLLV(struct r4300_core* r4300);
void gen_SLTI(struct r4300_core* r4300);
void gen_SLTIU(struct r4300_core* r4300);
void gen_SLT(struct r4300_core* r4300);
void gen_SLTU(struct r4300_core* r4300);
void gen_SRA(struct r4300_core* r4300);
void gen_SRAV(struct r4300_core* r4300);
void gen_SRL(struct r4300_core* r4300);
void gen_SRLV(struct r4300_core* r4300);
void gen_SUB(struct r4300_core* r4300);
void gen_SUBU(struct r4300_core* r4300);
void gen_SWC1(struct r4300_core* r4300);
void gen_SWL(struct r4300_core* r4300);
void gen_SWR(struct r4300_core* r4300);
void gen_SW(struct r4300_core* r4300);
void gen_SYNC(struct r4300_core* r4300);
void gen_SYSCALL(struct r4300_core* r4300);
void gen_TEQ(struct r4300_core* r4300);
void gen_TLBP(struct r4300_core* r4300);
void gen_TLBR(struct r4300_core* r4300);
void gen_TLBWI(struct r4300_core* r4300);
void gen_TLBWR(struct r4300_core* r4300);
void gen_XORI(struct r4300_core* r4300);
void gen_XOR(struct r4300_core* r4300);

#define GENCP1_S_D(func) \
static void gen_CP1_##func(struct r4300_core* r4300) \
{ \
    unsigned fmt = (r4300->recomp.src >> 21) & 0x1f; \
    switch(fmt) \
    { \
    case 0x10: gen_CP1_##func##_S(r4300); break; \
    case 0x11: gen_CP1_##func##_D(r4300); break; \
    default: gen_RESERVED(r4300); \
    } \
}

GENCP1_S_D(ABS)
GENCP1_S_D(ADD)
GENCP1_S_D(CEIL_L)
GENCP1_S_D(CEIL_W)
GENCP1_S_D(C_EQ)
GENCP1_S_D(C_F)
GENCP1_S_D(C_LE)
GENCP1_S_D(C_LT)
GENCP1_S_D(C_NGE)
GENCP1_S_D(C_NGL)
GENCP1_S_D(C_NGLE)
GENCP1_S_D(C_NGT)
GENCP1_S_D(C_OLE)
GENCP1_S_D(C_OLT)
GENCP1_S_D(C_SEQ)
GENCP1_S_D(C_SF)
GENCP1_S_D(C_UEQ)
GENCP1_S_D(C_ULE)
GENCP1_S_D(C_ULT)
GENCP1_S_D(C_UN)
GENCP1_S_D(CVT_L)
GENCP1_S_D(CVT_W)
GENCP1_S_D(DIV)
GENCP1_S_D(FLOOR_L)
GENCP1_S_D(FLOOR_W)
GENCP1_S_D(MOV)
GENCP1_S_D(MUL)
GENCP1_S_D(NEG)
GENCP1_S_D(ROUND_L)
GENCP1_S_D(ROUND_W)
GENCP1_S_D(SQRT)
GENCP1_S_D(SUB)
GENCP1_S_D(TRUNC_L)
GENCP1_S_D(TRUNC_W)

static void gen_CP1_CVT_D(struct r4300_core* r4300)
{
    unsigned fmt = (r4300->recomp.src >> 21) & 0x1f;
    switch(fmt)
    {
    case 0x10: gen_CP1_CVT_D_S(r4300); break;
    case 0x14: gen_CP1_CVT_D_W(r4300); break;
    case 0x15: gen_CP1_CVT_D_L(r4300); break;
    default: gen_RESERVED(r4300);
    }
}

static void gen_CP1_CVT_S(struct r4300_core* r4300)
{
    unsigned fmt = (r4300->recomp.src >> 21) & 0x1f;
    switch(fmt)
    {
    case 0x11: gen_CP1_CVT_S_D(r4300); break;
    case 0x14: gen_CP1_CVT_S_W(r4300); break;
    case 0x15: gen_CP1_CVT_S_L(r4300); break;
    default: gen_RESERVED(r4300);
    }
}

/* TODO: implement them properly */
#define gen_BC0F       genni
#define gen_BC0F_IDLE  genni
#define gen_BC0F_OUT   genni
#define gen_BC0FL      genni
#define gen_BC0FL_IDLE genni
#define gen_BC0FL_OUT  genni
#define gen_BC0T       genni
#define gen_BC0T_IDLE  genni
#define gen_BC0T_OUT   genni
#define gen_BC0TL      genni
#define gen_BC0TL_IDLE genni
#define gen_BC0TL_OUT  genni
#define gen_BC2F       genni
#define gen_BC2F_IDLE  genni
#define gen_BC2F_OUT   genni
#define gen_BC2FL      genni
#define gen_BC2FL_IDLE genni
#define gen_BC2FL_OUT  genni
#define gen_BC2T       genni
#define gen_BC2T_IDLE  genni
#define gen_BC2T_OUT   genni
#define gen_BC2TL      genni
#define gen_BC2TL_IDLE genni
#define gen_BC2TL_OUT  genni
#define gen_BREAK      genni
#define gen_CFC0       genni
#define gen_CFC2       genni
#define gen_CTC0       genni
#define gen_CTC2       genni
#define gen_DMFC0      genni
#define gen_DMFC2      genni
#define gen_DMTC0      genni
#define gen_DMTC2      genni
#define gen_JR_IDLE    genni
#define gen_JR_OUT     gen_JR
#define gen_JALR_IDLE  genni
#define gen_JALR_OUT   gen_JALR
#define gen_LDC2       genni
#define gen_LWC2       genni
#define gen_LLD        genni
#define gen_MFC2       genni
#define gen_MTC2       genni
#define gen_SCD        genni
#define gen_SDC2       genni
#define gen_SWC2       genni
#define gen_TEQI       genni
#define gen_TGE        genni
#define gen_TGEI       genni
#define gen_TGEIU      genni
#define gen_TGEU       genni
#define gen_TLT        genni
#define gen_TLTI       genni
#define gen_TLTIU      genni
#define gen_TLTU       genni
#define gen_TNE        genni
#define gen_TNEI       genni

#define X(op) gen_##op
static void (*const recomp_funcs[R4300_OPCODES_COUNT])(struct r4300_core* r4300) =
{
#include "opcodes.md"
};
#undef X

/**********************************************************************
 ******************** initialize an empty block ***********************
 **********************************************************************/
void dynarec_init_block(struct r4300_core* r4300, uint32_t address)
{
    int i, length, already_exist = 1;
#if defined(PROFILE)
    timed_section_start(TIMED_SECTION_COMPILER);
#endif

    struct precomp_block** block = &r4300->cached_interp.blocks[address >> 12];

    /* allocate block */
    if (*block == NULL) {
        *block = malloc(sizeof(struct precomp_block));
        (*block)->block = NULL;
        (*block)->start = address & ~UINT32_C(0xfff);
        (*block)->end = (address & ~UINT32_C(0xfff)) + 0x1000;
        (*block)->code = NULL;
        (*block)->jumps_table = NULL;
        (*block)->riprel_table = NULL;
    }

    struct precomp_block* b = *block;

    length = get_block_length(b);

#ifdef DBG
    DebugMessage(M64MSG_INFO, "init block %" PRIX32 " - %" PRIX32, b->start, b->end);
#endif

    /* allocate block instructions */
    if (!b->block)
    {
        size_t memsize = get_block_memsize(b);
        b->block = (struct precomp_instr *) malloc_exec(memsize);
        if (!b->block) {
            DebugMessage(M64MSG_ERROR, "Memory error: couldn't allocate executable memory for dynamic recompiler. Try to use an interpreter mode.");
            return;
        }

        memset(b->block, 0, memsize);
        already_exist = 0;
    }

    if (!b->code)
    {
#if defined(PROFILE_R4300)
        r4300->recomp.max_code_length = 524288; /* allocate so much code space that we'll never have to realloc(), because this may */
        /* cause instruction locations to move, and break our profiling data                */
#else
        r4300->recomp.max_code_length = 32768;
#endif
        b->code = (unsigned char *) malloc_exec(r4300->recomp.max_code_length);
    }
    else
    {
        r4300->recomp.max_code_length = b->max_code_length;
    }

    r4300->recomp.code_length = 0;
    r4300->recomp.inst_pointer = &b->code;

    if (b->jumps_table)
    {
        free(b->jumps_table);
        b->jumps_table = NULL;
    }
    if (b->riprel_table)
    {
        free(b->riprel_table);
        b->riprel_table = NULL;
    }
    init_assembler(r4300, NULL, 0, NULL, 0);
    init_cache(r4300, b->block);

    if (!already_exist)
    {
#if defined(PROFILE_R4300)
        r4300->recomp.pfProfile = fopen("instructionaddrs.dat", "ab");
        long x86addr = (long) b->code;
        int mipsop = -2; /* -2 == NOTCOMPILED block at beginning of x86 code */
        if (fwrite(&mipsop, 1, 4, r4300->recomp.pfProfile) != 4 || // write 4-byte MIPS opcode
                fwrite(&x86addr, 1, sizeof(char *), r4300->recomp.pfProfile) != sizeof(char *)) // write pointer to dynamically generated x86 code for this MIPS instruction
            DebugMessage(M64MSG_ERROR, "Error writing R4300 instruction address profiling data");
#endif
        for (i=0; i<length; i++)
        {
            r4300->recomp.dst = b->block + i;
            r4300->recomp.dst->addr = b->start + i*4;
            r4300->recomp.dst->reg_cache_infos.need_map = 0;
            r4300->recomp.dst->local_addr = r4300->recomp.code_length;
#ifdef COMPARE_CORE
            gendebug(r4300);
#endif
            r4300->recomp.dst->ops = dynarec_notcompiled;
            gennotcompiled(r4300);
        }
#if defined(PROFILE_R4300)
        fclose(r4300->recomp.pfProfile);
        r4300->recomp.pfProfile = NULL;
#endif
        r4300->recomp.init_length = r4300->recomp.code_length;
    }
    else
    {
#if defined(PROFILE_R4300)
        r4300->recomp.code_length = b->code_length; /* leave old instructions in their place */
#else
        r4300->recomp.code_length = r4300->recomp.init_length; /* recompile everything, overwrite old recompiled instructions */
#endif
        for (i=0; i<length; i++)
        {
            r4300->recomp.dst = b->block + i;
            r4300->recomp.dst->reg_cache_infos.need_map = 0;
            r4300->recomp.dst->local_addr = i * (r4300->recomp.init_length / length);
            r4300->recomp.dst->ops = r4300->cached_interp.not_compiled;
        }
    }

    free_all_registers(r4300);
    /* calling pass2 of the assembler is not necessary here because all of the code emitted by
       gennotcompiled() and gendebug() is position-independent and contains no jumps . */
    b->code_length = r4300->recomp.code_length;
    b->max_code_length = r4300->recomp.max_code_length;
    free_assembler(r4300, &b->jumps_table, &b->jumps_number, &b->riprel_table, &b->riprel_number);

    /* here we're marking the block as a valid code even if it's not compiled
     * yet as the game should have already set up the code correctly.
     */
    r4300->cached_interp.invalid_code[b->start>>12] = 0;
    if (b->end < UINT32_C(0x80000000) || b->start >= UINT32_C(0xc0000000))
    {
        uint32_t paddr = virtual_to_physical_address(r4300, b->start, 2);
        r4300->cached_interp.invalid_code[paddr>>12] = 0;
        dynarec_init_block(r4300, paddr);

        paddr += b->end - b->start - 4;
        r4300->cached_interp.invalid_code[paddr>>12] = 0;
        dynarec_init_block(r4300, paddr);

    }
    else
    {
        uint32_t alt_addr = b->start ^ UINT32_C(0x20000000);

        if (r4300->cached_interp.invalid_code[alt_addr>>12])
        {
            dynarec_init_block(r4300, alt_addr);
        }
    }
#if defined(PROFILE)
    timed_section_end(TIMED_SECTION_COMPILER);
#endif
}

void dynarec_free_block(struct precomp_block* block)
{
    size_t memsize = get_block_memsize(block);

    if (block->block) { free_exec(block->block, memsize); block->block = NULL; }
    if (block->code) { free_exec(block->code, block->max_code_length); block->code = NULL; }
    if (block->jumps_table) { free(block->jumps_table); block->jumps_table = NULL; }
    if (block->riprel_table) { free(block->riprel_table); block->riprel_table = NULL; }
}

/**********************************************************************
 ********************* recompile a block of code **********************
 **********************************************************************/
void dynarec_recompile_block(struct r4300_core* r4300, const uint32_t* iw, struct precomp_block* block, uint32_t func)
{
    int i, length, length2, finished;
    enum r4300_opcode opcode;

    /* ??? not sure why we need these 2 different tests */
    int block_start_in_tlb = ((block->start & UINT32_C(0xc0000000)) != UINT32_C(0x80000000));
    int block_not_in_tlb = (block->start >= UINT32_C(0xc0000000) || block->end < UINT32_C(0x80000000));

#if defined(PROFILE)
    timed_section_start(TIMED_SECTION_COMPILER);
#endif

    length = get_block_length(block);
    length2 = length - 2 + (length >> 2);

    /* reset xxhash */
    block->xxhash = 0;

    r4300->recomp.dst_block = block;
    r4300->recomp.code_length = block->code_length;
    r4300->recomp.max_code_length = block->max_code_length;
    r4300->recomp.inst_pointer = &block->code;
    init_assembler(r4300, block->jumps_table, block->jumps_number, block->riprel_table, block->riprel_number);
    init_cache(r4300, block->block + (func & 0xFFF) / 4);

#if defined(PROFILE_R4300)
    r4300->recomp.pfProfile = fopen("instructionaddrs.dat", "ab");
#endif

    for (i = (func & 0xFFF) / 4, finished = 0; finished != 2; ++i)
    {
        r4300->recomp.SRC = iw + i;
        r4300->recomp.src = iw[i];
        r4300->recomp.dst = block->block + i;
        r4300->recomp.dst->addr = block->start + i*4;
        r4300->recomp.dst->reg_cache_infos.need_map = 0;
        r4300->recomp.dst->local_addr = r4300->recomp.code_length;

        if (block_start_in_tlb)
        {
            uint32_t address2 = virtual_to_physical_address(r4300, r4300->recomp.dst->addr, 0);
            if (r4300->cached_interp.blocks[address2>>12]->block[(address2&UINT32_C(0xFFF))/4].ops == r4300->cached_interp.not_compiled) {
                r4300->cached_interp.blocks[address2>>12]->block[(address2&UINT32_C(0xFFF))/4].ops = r4300->cached_interp.not_compiled2;
            }
        }

#ifdef COMPARE_CORE
        gendebug(r4300);
#endif
#if defined(PROFILE_R4300)
        long x86addr = (long) (block->code + block->block[i].local_addr);

        /* write 4-byte MIPS opcode, followed by a pointer to dynamically generated x86 code for
         * this MIPS instruction. */
        if (fwrite(iw + i, 1, 4, r4300->recomp.pfProfile) != 4
        || fwrite(&x86addr, 1, sizeof(char *), r4300->recomp.pfProfile) != sizeof(char *)) {
            DebugMessage(M64MSG_ERROR, "Error writing R4300 instruction address profiling data");
        }
#endif

        /* decode instruction */
        opcode = r4300_decode(r4300->recomp.dst, r4300, r4300_get_idec(iw[i]), iw[i], iw[i+1], block);
        recomp_funcs[opcode](r4300);

        if (r4300->recomp.delay_slot_compiled)
        {
            r4300->recomp.delay_slot_compiled--;
            free_all_registers(r4300);
        }

        /* decode ending conditions */
        if (i >= length2) { finished = 2; }
        if (i >= (length-1)
        && (block->start == UINT32_C(0xa4000000) || block_not_in_tlb)) { finished = 2; }
        if (opcode == R4300_OP_ERET || finished == 1) { finished = 2; }
        if (/*i >= length && */
                (opcode == R4300_OP_J ||
                 opcode == R4300_OP_J_OUT ||
                 opcode == R4300_OP_JR ||
                 opcode == R4300_OP_JR_OUT) &&
                !(i >= (length-1) && block_not_in_tlb)) {
            finished = 1;
        }
    }

#if defined(PROFILE_R4300)
    long x86addr = (long) (block->code + r4300->recomp.code_length);
    int mipsop = -3; /* -3 == block-postfix */
    /* write 4-byte MIPS opcode, followed by a pointer to dynamically generated x86 code for
     * this MIPS instruction. */
    if (fwrite(&mipsop, 1, 4, r4300->recomp.pfProfile) != 4
    || fwrite(&x86addr, 1, sizeof(char *), r4300->recomp.pfProfile) != sizeof(char *)) {
        DebugMessage(M64MSG_ERROR, "Error writing R4300 instruction address profiling data");
    }
#endif

    if (i >= length)
    {
        r4300->recomp.dst = block->block + i;
        r4300->recomp.dst->addr = block->start + i*4;
        r4300->recomp.dst->reg_cache_infos.need_map = 0;
        r4300->recomp.dst->local_addr = r4300->recomp.code_length;
#ifdef COMPARE_CORE
        gendebug(r4300);
#endif
        r4300->recomp.dst->ops = dynarec_fin_block;
        genfin_block(r4300);
        ++i;
        if (i <= length2) // useful when last opcode is a jump
        {
            r4300->recomp.dst = block->block + i;
            r4300->recomp.dst->addr = block->start + i*4;
            r4300->recomp.dst->reg_cache_infos.need_map = 0;
            r4300->recomp.dst->local_addr = r4300->recomp.code_length;
#ifdef COMPARE_CORE
            gendebug(r4300);
#endif
            r4300->recomp.dst->ops = dynarec_fin_block;
            genfin_block(r4300);
            ++i;
        }
    }
    else { genlink_subblock(r4300); }

    free_all_registers(r4300);
    passe2(r4300, block->block, (func&0xFFF)/4, i, block);
    block->code_length = r4300->recomp.code_length;
    block->max_code_length = r4300->recomp.max_code_length;
    free_assembler(r4300, &block->jumps_table, &block->jumps_number, &block->riprel_table, &block->riprel_number);

#ifdef DBG
    DebugMessage(M64MSG_INFO, "block recompiled (%" PRIX32 "-%" PRIX32 ")", func, block->start+i*4);
#endif
#if defined(PROFILE_R4300)
    fclose(r4300->recomp.pfProfile);
    r4300->recomp.pfProfile = NULL;
#endif

#if defined(PROFILE)
    timed_section_end(TIMED_SECTION_COMPILER);
#endif
}

/**********************************************************************
 ************ recompile only one opcode (use for delay slot) **********
 **********************************************************************/
void recompile_opcode(struct r4300_core* r4300)
{
    r4300->recomp.SRC++;
    r4300->recomp.src = *r4300->recomp.SRC;
    r4300->recomp.dst++;
    r4300->recomp.dst->addr = (r4300->recomp.dst-1)->addr + 4;
    r4300->recomp.dst->reg_cache_infos.need_map = 0;
    /* we disable next_iw == NOP check by passing 1, because we are already in delay slot */

    uint32_t iw = r4300->recomp.src;
    enum r4300_opcode opcode = r4300_decode(r4300->recomp.dst, r4300, r4300_get_idec(iw), iw, 1, r4300->recomp.dst_block);

    switch(opcode)
    {
    /* jumps/branches in delay slot are nopified */
#define CASE(op) case R4300_OP_##op:
#define JCASE(op) CASE(op) CASE(op##_IDLE) CASE(op##_OUT)
    JCASE(BC0F)
    JCASE(BC0FL)
    JCASE(BC0T)
    JCASE(BC0TL)
    JCASE(BC1F)
    JCASE(BC1FL)
    JCASE(BC1T)
    JCASE(BC1TL)
    JCASE(BC2F)
    JCASE(BC2FL)
    JCASE(BC2T)
    JCASE(BC2TL)
    JCASE(BEQ)
    JCASE(BEQL)
    JCASE(BGEZ)
    JCASE(BGEZAL)
    JCASE(BGEZALL)
    JCASE(BGEZL)
    JCASE(BGTZ)
    JCASE(BGTZL)
    JCASE(BLEZ)
    JCASE(BLEZL)
    JCASE(BLTZ)
    JCASE(BLTZAL)
    JCASE(BLTZALL)
    JCASE(BLTZL)
    JCASE(BNE)
    JCASE(BNEL)
    JCASE(J)
    JCASE(JAL)
    JCASE(JALR)
    JCASE(JR)
#undef JCASE
#undef CASE
        r4300->recomp.dst->ops = cached_interp_NOP;
        gen_NOP(r4300);
        break;

    default:
#if defined(PROFILE_R4300)
        long x86addr = (long) ((*r4300->recomp.inst_pointer) + r4300->recomp.code_length);

        /* write 4-byte MIPS opcode, followed by a pointer to dynamically generated x86 code for
         * this MIPS instruction. */
        if (fwrite(&r4300->recomp.src, 1, 4, r4300->recomp.pfProfile) != 4
        || fwrite(&x86addr, 1, sizeof(char *), r4300->recomp.pfProfile) != sizeof(char *)) {
            DebugMessage(M64MSG_ERROR, "Error writing R4300 instruction address profiling data");
        }
#endif
        recomp_funcs[opcode](r4300);
    }

    r4300->recomp.delay_slot_compiled = 2;
}

#if defined(PROFILE_R4300)
void profile_write_end_of_code_blocks(struct r4300_core* r4300)
{
    size_t i;

    r4300->recomp.pfProfile = fopen("instructionaddrs.dat", "ab");

    for (i = 0; i < 0x100000; ++i) {
        if (r4300->cached_interp.invalid_code[i] == 0 && r4300->cached_interp.blocks[i] != NULL && r4300->cached_interp.blocks[i]->code != NULL && r4300->cached_interp.blocks[i]->block != NULL)
        {
            unsigned char *x86addr;
            int mipsop;
            // store final code length for this block
            mipsop = -1; /* -1 == end of x86 code block */
            x86addr = r4300->cached_interp.blocks[i]->code + r4300->cached_interp.blocks[i]->code_length;
            if (fwrite(&mipsop, 1, 4, r4300->recomp.pfProfile) != 4 ||
                    fwrite(&x86addr, 1, sizeof(char *), r4300->recomp.pfProfile) != sizeof(char *))
                DebugMessage(M64MSG_ERROR, "Error writing R4300 instruction address profiling data");
        }
    }

    fclose(r4300->recomp.pfProfile);
    r4300->recomp.pfProfile = NULL;
}
#endif

/* Jumps to the given address. This is for the dynarec. */
void dynarec_jump_to(struct r4300_core* r4300, uint32_t address)
{
    cached_interpreter_jump_to(r4300, address);
    dyna_jump();
}

void dynarec_fin_block(void)
{
    cached_interp_FIN_BLOCK();
    dyna_jump();
}

void dynarec_notcompiled(void)
{
    cached_interp_NOTCOMPILED();
    dyna_jump();
}

void dynarec_notcompiled2(void)
{
    dynarec_notcompiled();
}

void dynarec_setup_code(void)
{
    struct r4300_core* r4300 = &g_dev.r4300;

    /* The dynarec jumps here after we call dyna_start and it prepares
     * Here we need to prepare the initial code block and jump to it
     */
    dynarec_jump_to(r4300, UINT32_C(0xa4000040));

    /* Prevent segfault on failed dynarec_jump_to */
    if (!r4300->cached_interp.actual->block || !r4300->cached_interp.actual->code) {
        dyna_stop(r4300);
    }
}

/* Parameterless version of dynarec_jump_to to ease usage in dynarec. */
void dynarec_jump_to_recomp_address(void)
{
    struct r4300_core* r4300 = &g_dev.r4300;

    dynarec_jump_to(r4300, r4300->recomp.jump_to_address);
}

/* Parameterless version of exception_general to ease usage in dynarec. */
void dynarec_exception_general(void)
{
    exception_general(&g_dev.r4300);
}

/* Parameterless version of check_cop1_unusable to ease usage in dynarec. */
int dynarec_check_cop1_unusable(void)
{
    return check_cop1_unusable(&g_dev.r4300);
}


/* Parameterless version of cp0_update_count to ease usage in dynarec. */
void dynarec_cp0_update_count(void)
{
    cp0_update_count(&g_dev.r4300);
}

/* Parameterless version of gen_interrupt to ease usage in dynarec. */
void dynarec_gen_interrupt(void)
{
    gen_interrupt(&g_dev.r4300);
}

/* Parameterless version of read_aligned_word to ease usage in dynarec. */
int dynarec_read_aligned_word(void)
{
    struct r4300_core* r4300 = &g_dev.r4300;
    uint32_t value;

    int result = r4300_read_aligned_word(
        r4300,
        r4300->recomp.address,
        &value);

    if (result)
        *r4300->recomp.rdword = value;

    return result;
}

/* Parameterless version of write_aligned_word to ease usage in dynarec. */
int dynarec_write_aligned_word(void)
{
    struct r4300_core* r4300 = &g_dev.r4300;

    return r4300_write_aligned_word(
        r4300,
        r4300->recomp.address,
        r4300->recomp.wword,
        r4300->recomp.wmask);
}

/* Parameterless version of read_aligned_dword to ease usage in dynarec. */
int dynarec_read_aligned_dword(void)
{
    struct r4300_core* r4300 = &g_dev.r4300;

    return r4300_read_aligned_dword(
        r4300,
        r4300->recomp.address,
        (uint64_t*)r4300->recomp.rdword);
}

/* Parameterless version of write_aligned_dword to ease usage in dynarec. */
int dynarec_write_aligned_dword(void)
{
    struct r4300_core* r4300 = &g_dev.r4300;

    return r4300_write_aligned_dword(
        r4300,
        r4300->recomp.address,
        r4300->recomp.wdword,
        ~UINT64_C(0)); /* NOTE: in dynarec, we only need all-one masks */
}


/**********************************************************************
 ************** allocate memory with executable bit set ***************
 **********************************************************************/
static void *malloc_exec(size_t size)
{
#if defined(WIN32)
    return VirtualAlloc(NULL, size, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
#elif defined(__GNUC__)

#ifndef  MAP_ANONYMOUS
#ifdef MAP_ANON
#define MAP_ANONYMOUS MAP_ANON
#endif
#endif

    void *block = mmap(NULL, size, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (block == MAP_FAILED)
    { DebugMessage(M64MSG_ERROR, "Memory error: couldn't allocate %zi byte block of aligned RWX memory.", size); return NULL; }

    return block;
#else
    return malloc(size);
#endif
}

/**********************************************************************
 ************* reallocate memory with executable bit set **************
 **********************************************************************/
void *realloc_exec(void *ptr, size_t oldsize, size_t newsize)
{
    void* block = malloc_exec(newsize);
    if (block != NULL)
    {
        size_t copysize;
        copysize = (oldsize < newsize)
            ? oldsize
            : newsize;
        memcpy(block, ptr, copysize);
    }
    free_exec(ptr, oldsize);
    return block;
}

/**********************************************************************
 **************** frees memory with executable bit set ****************
 **********************************************************************/
static void free_exec(void *ptr, size_t length)
{
#if defined(WIN32)
    VirtualFree(ptr, 0, MEM_RELEASE);
#elif defined(__GNUC__)
    munmap(ptr, length);
#else
    free(ptr);
#endif
}
