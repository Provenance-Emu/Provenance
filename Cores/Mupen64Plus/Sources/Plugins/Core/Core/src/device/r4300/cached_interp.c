/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cached_interp.c                                         *
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

#include "cached_interp.h"

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>

#define __STDC_FORMAT_MACROS
#include <inttypes.h>
#include <string.h>

#include "api/callbacks.h"
#include "api/debugger.h"
#include "api/m64p_types.h"
#include "device/r4300/r4300_core.h"
#include "device/r4300/idec.h"
#include "main/main.h"
#include "osal/preproc.h"

#ifdef DBG
#include "debugger/dbg_debugger.h"
#endif

// -----------------------------------------------------------
// Cached interpreter functions (and fallback for dynarec).
// -----------------------------------------------------------
#ifdef DBG
#define UPDATE_DEBUGGER() if (g_DebuggerActive) update_debugger(*r4300_pc(r4300))
#else
#define UPDATE_DEBUGGER() do { } while(0)
#endif

#define DECLARE_R4300 struct r4300_core* r4300 = &g_dev.r4300;
#define PCADDR *r4300_pc(r4300)
#define ADD_TO_PC(x) (*r4300_pc_struct(r4300)) += x;
#define DECLARE_INSTRUCTION(name) void cached_interp_##name(void)

#define DECLARE_JUMP(name, destination, condition, link, likely, cop1) \
void cached_interp_##name(void) \
{ \
    DECLARE_R4300 \
    const int take_jump = (condition); \
    const uint32_t jump_target = (destination); \
    int64_t *link_register = (link); \
    if (cop1 && check_cop1_unusable(r4300)) return; \
    if (link_register != &r4300_regs(r4300)[0]) \
    { \
        *link_register = SE32(*r4300_pc(r4300) + 8); \
    } \
    if (!likely || take_jump) \
    { \
        (*r4300_pc_struct(r4300))++; \
        r4300->delay_slot=1; \
        UPDATE_DEBUGGER(); \
        (*r4300_pc_struct(r4300))->ops(); \
        cp0_update_count(r4300); \
        r4300->delay_slot=0; \
        if (take_jump && !r4300->skip_jump) \
        { \
            (*r4300_pc_struct(r4300))=r4300->cached_interp.actual->block+((jump_target-r4300->cached_interp.actual->start)>>2); \
        } \
    } \
    else \
    { \
        (*r4300_pc_struct(r4300)) += 2; \
        cp0_update_count(r4300); \
    } \
    r4300->cp0.last_addr = *r4300_pc(r4300); \
    if (*r4300_cp0_next_interrupt(&r4300->cp0) <= r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]) gen_interrupt(r4300); \
} \
 \
void cached_interp_##name##_OUT(void) \
{ \
    DECLARE_R4300 \
    const int take_jump = (condition); \
    const uint32_t jump_target = (destination); \
    int64_t *link_register = (link); \
    if (cop1 && check_cop1_unusable(r4300)) return; \
    if (link_register != &r4300_regs(r4300)[0]) \
    { \
        *link_register = SE32(*r4300_pc(r4300) + 8); \
    } \
    if (!likely || take_jump) \
    { \
        (*r4300_pc_struct(r4300))++; \
        r4300->delay_slot=1; \
        UPDATE_DEBUGGER(); \
        (*r4300_pc_struct(r4300))->ops(); \
        cp0_update_count(r4300); \
        r4300->delay_slot=0; \
        if (take_jump && !r4300->skip_jump) \
        { \
            generic_jump_to(r4300, jump_target); \
        } \
    } \
    else \
    { \
        (*r4300_pc_struct(r4300)) += 2; \
        cp0_update_count(r4300); \
    } \
    r4300->cp0.last_addr = *r4300_pc(r4300); \
    if (*r4300_cp0_next_interrupt(&r4300->cp0) <= r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]) gen_interrupt(r4300); \
} \
  \
void cached_interp_##name##_IDLE(void) \
{ \
    DECLARE_R4300 \
    uint32_t* cp0_regs = r4300_cp0_regs(&r4300->cp0); \
    const int take_jump = (condition); \
    int skip; \
    if (cop1 && check_cop1_unusable(r4300)) return; \
    if (take_jump) \
    { \
        cp0_update_count(r4300); \
        skip = *r4300_cp0_next_interrupt(&r4300->cp0) - cp0_regs[CP0_COUNT_REG]; \
        if (skip > 3) cp0_regs[CP0_COUNT_REG] += (skip & UINT32_C(0xFFFFFFFC)); \
        else cached_interp_##name(); \
    } \
    else cached_interp_##name(); \
}

/* These macros allow direct access to parsed opcode fields. */
#define rrt *(*r4300_pc_struct(r4300))->f.r.rt
#define rrd *(*r4300_pc_struct(r4300))->f.r.rd
#define rfs (*r4300_pc_struct(r4300))->f.r.nrd
#define rrs *(*r4300_pc_struct(r4300))->f.r.rs
#define rsa (*r4300_pc_struct(r4300))->f.r.sa
#define irt *(*r4300_pc_struct(r4300))->f.i.rt
#define ioffset (*r4300_pc_struct(r4300))->f.i.immediate
#define iimmediate (*r4300_pc_struct(r4300))->f.i.immediate
#define irs *(*r4300_pc_struct(r4300))->f.i.rs
#define ibase *(*r4300_pc_struct(r4300))->f.i.rs
#define jinst_index (*r4300_pc_struct(r4300))->f.j.inst_index
#define lfbase (*r4300_pc_struct(r4300))->f.lf.base
#define lfft (*r4300_pc_struct(r4300))->f.lf.ft
#define lfoffset (*r4300_pc_struct(r4300))->f.lf.offset
#define cfft (*r4300_pc_struct(r4300))->f.cf.ft
#define cffs (*r4300_pc_struct(r4300))->f.cf.fs
#define cffd (*r4300_pc_struct(r4300))->f.cf.fd

/* 32 bits macros */
#ifndef M64P_BIG_ENDIAN
#define rrt32 *((int32_t*) (*r4300_pc_struct(r4300))->f.r.rt)
#define rrd32 *((int32_t*) (*r4300_pc_struct(r4300))->f.r.rd)
#define rrs32 *((int32_t*) (*r4300_pc_struct(r4300))->f.r.rs)
#define irs32 *((int32_t*) (*r4300_pc_struct(r4300))->f.i.rs)
#define irt32 *((int32_t*) (*r4300_pc_struct(r4300))->f.i.rt)
#else
#define rrt32 *((int32_t*) (*r4300_pc_struct(r4300))->f.r.rt + 1)
#define rrd32 *((int32_t*) (*r4300_pc_struct(r4300))->f.r.rd + 1)
#define rrs32 *((int32_t*) (*r4300_pc_struct(r4300))->f.r.rs + 1)
#define irs32 *((int32_t*) (*r4300_pc_struct(r4300))->f.i.rs + 1)
#define irt32 *((int32_t*) (*r4300_pc_struct(r4300))->f.i.rt + 1)
#endif

#include "mips_instructions.def"

// -----------------------------------------------------------
// Flow control 'fake' instructions
// -----------------------------------------------------------
void cached_interp_FIN_BLOCK(void)
{
    DECLARE_R4300
    if (!r4300->delay_slot)
    {
        generic_jump_to(r4300, ((*r4300_pc_struct(r4300))-1)->addr+4);
/*
#ifdef DBG
      if (g_DebuggerActive) update_debugger(*r4300_pc(r4300));
#endif
Used by dynarec only, check should be unnecessary
*/
        (*r4300_pc_struct(r4300))->ops();
    }
    else
    {
        struct precomp_block *blk = r4300->cached_interp.actual;
        struct precomp_instr *inst = (*r4300_pc_struct(r4300));
        generic_jump_to(r4300, ((*r4300_pc_struct(r4300))-1)->addr+4);

/*
#ifdef DBG
          if (g_DebuggerActive) update_debugger(*r4300_pc(r4300));
#endif
Used by dynarec only, check should be unnecessary
*/
        if (!r4300->skip_jump)
        {
            (*r4300_pc_struct(r4300))->ops();
            r4300->cached_interp.actual = blk;
            (*r4300_pc_struct(r4300)) = inst+1;
        }
        else
            (*r4300_pc_struct(r4300))->ops();
    }
}

void cached_interp_NOTCOMPILED(void)
{
    DECLARE_R4300
    uint32_t *mem = fast_mem_access(r4300, r4300->cached_interp.blocks[*r4300_pc(r4300)>>12]->start);
#ifdef DBG
    DebugMessage(M64MSG_INFO, "NOTCOMPILED: addr = %x ops = %lx", *r4300_pc(r4300), (long) (*r4300_pc_struct(r4300))->ops);
#endif

    if (mem == NULL) {
        DebugMessage(M64MSG_ERROR, "not compiled exception");
    }
    else {
        r4300->cached_interp.recompile_block(r4300, mem, r4300->cached_interp.blocks[*r4300_pc(r4300) >> 12], *r4300_pc(r4300));
    }

/*
#ifdef DBG
      if (g_DebuggerActive) update_debugger(*r4300_pc(r4300));
#endif
The preceeding update_debugger SHOULD be unnecessary since it should have been
called before NOTCOMPILED would have been executed
*/
    (*r4300_pc_struct(r4300))->ops();
}

void cached_interp_NOTCOMPILED2(void)
{
    cached_interp_NOTCOMPILED();
}

/* TODO: implement them properly */
#define cached_interp_BC0F        cached_interp_NI
#define cached_interp_BC0F_IDLE   cached_interp_NI
#define cached_interp_BC0F_OUT    cached_interp_NI
#define cached_interp_BC0FL       cached_interp_NI
#define cached_interp_BC0FL_IDLE  cached_interp_NI
#define cached_interp_BC0FL_OUT   cached_interp_NI
#define cached_interp_BC0T        cached_interp_NI
#define cached_interp_BC0T_IDLE   cached_interp_NI
#define cached_interp_BC0T_OUT    cached_interp_NI
#define cached_interp_BC0TL       cached_interp_NI
#define cached_interp_BC0TL_IDLE  cached_interp_NI
#define cached_interp_BC0TL_OUT   cached_interp_NI
#define cached_interp_BC2F        cached_interp_NI
#define cached_interp_BC2F_IDLE   cached_interp_NI
#define cached_interp_BC2F_OUT    cached_interp_NI
#define cached_interp_BC2FL       cached_interp_NI
#define cached_interp_BC2FL_IDLE  cached_interp_NI
#define cached_interp_BC2FL_OUT   cached_interp_NI
#define cached_interp_BC2T        cached_interp_NI
#define cached_interp_BC2T_IDLE   cached_interp_NI
#define cached_interp_BC2T_OUT    cached_interp_NI
#define cached_interp_BC2TL       cached_interp_NI
#define cached_interp_BC2TL_IDLE  cached_interp_NI
#define cached_interp_BC2TL_OUT   cached_interp_NI
#define cached_interp_BREAK       cached_interp_NI
#define cached_interp_CFC0        cached_interp_NI
#define cached_interp_CFC2        cached_interp_NI
#define cached_interp_CTC0        cached_interp_NI
#define cached_interp_CTC2        cached_interp_NI
#define cached_interp_DMFC0       cached_interp_NI
#define cached_interp_DMFC2       cached_interp_NI
#define cached_interp_DMTC0       cached_interp_NI
#define cached_interp_DMTC2       cached_interp_NI
#define cached_interp_LDC2        cached_interp_NI
#define cached_interp_LWC2        cached_interp_NI
#define cached_interp_LLD         cached_interp_NI
#define cached_interp_MFC2        cached_interp_NI
#define cached_interp_MTC2        cached_interp_NI
#define cached_interp_SCD         cached_interp_NI
#define cached_interp_SDC2        cached_interp_NI
#define cached_interp_SWC2        cached_interp_NI
#define cached_interp_TEQI        cached_interp_NI
#define cached_interp_TGE         cached_interp_NI
#define cached_interp_TGEI        cached_interp_NI
#define cached_interp_TGEIU       cached_interp_NI
#define cached_interp_TGEU        cached_interp_NI
#define cached_interp_TLT         cached_interp_NI
#define cached_interp_TLTI        cached_interp_NI
#define cached_interp_TLTIU       cached_interp_NI
#define cached_interp_TLTU        cached_interp_NI
#define cached_interp_TNE         cached_interp_NI
#define cached_interp_TNEI        cached_interp_NI
#define cached_interp_JR_IDLE     cached_interp_NI
#define cached_interp_JALR_IDLE   cached_interp_NI
#define cached_interp_CP1_ABS     cached_interp_RESERVED
#define cached_interp_CP1_ADD     cached_interp_RESERVED
#define cached_interp_CP1_CEIL_L  cached_interp_RESERVED
#define cached_interp_CP1_CEIL_W  cached_interp_RESERVED
#define cached_interp_CP1_C_EQ    cached_interp_RESERVED
#define cached_interp_CP1_C_F     cached_interp_RESERVED
#define cached_interp_CP1_C_LE    cached_interp_RESERVED
#define cached_interp_CP1_C_LT    cached_interp_RESERVED
#define cached_interp_CP1_C_NGE   cached_interp_RESERVED
#define cached_interp_CP1_C_NGL   cached_interp_RESERVED
#define cached_interp_CP1_C_NGLE  cached_interp_RESERVED
#define cached_interp_CP1_C_NGT   cached_interp_RESERVED
#define cached_interp_CP1_C_OLE   cached_interp_RESERVED
#define cached_interp_CP1_C_OLT   cached_interp_RESERVED
#define cached_interp_CP1_C_SEQ   cached_interp_RESERVED
#define cached_interp_CP1_C_SF    cached_interp_RESERVED
#define cached_interp_CP1_C_UEQ   cached_interp_RESERVED
#define cached_interp_CP1_C_ULE   cached_interp_RESERVED
#define cached_interp_CP1_C_ULT   cached_interp_RESERVED
#define cached_interp_CP1_C_UN    cached_interp_RESERVED
#define cached_interp_CP1_CVT_D   cached_interp_RESERVED
#define cached_interp_CP1_CVT_L   cached_interp_RESERVED
#define cached_interp_CP1_CVT_S   cached_interp_RESERVED
#define cached_interp_CP1_CVT_W   cached_interp_RESERVED
#define cached_interp_CP1_DIV     cached_interp_RESERVED
#define cached_interp_CP1_FLOOR_L cached_interp_RESERVED
#define cached_interp_CP1_FLOOR_W cached_interp_RESERVED
#define cached_interp_CP1_MOV     cached_interp_RESERVED
#define cached_interp_CP1_MUL     cached_interp_RESERVED
#define cached_interp_CP1_NEG     cached_interp_RESERVED
#define cached_interp_CP1_ROUND_L cached_interp_RESERVED
#define cached_interp_CP1_ROUND_W cached_interp_RESERVED
#define cached_interp_CP1_SQRT    cached_interp_RESERVED
#define cached_interp_CP1_SUB     cached_interp_RESERVED
#define cached_interp_CP1_TRUNC_L cached_interp_RESERVED
#define cached_interp_CP1_TRUNC_W cached_interp_RESERVED

#define X(op) cached_interp_##op
static void (*const ci_table[R4300_OPCODES_COUNT])(void) =
{
    #include "opcodes.md"
};
#undef X

/* return 0:normal, 1:idle, 2:out */
static int infer_jump_sub_type(uint32_t target, uint32_t pc, uint32_t next_iw, const struct precomp_block* block)
{
    /* test if jumping to same location with empty delay slot */
    if (target == pc) {
        if (next_iw == 0) {
            return 1;
        }
    }
    else {
        /* test if target is outside of block, or if we're at the end of block */
        if (target < block->start || target >= block->end || (pc == (block->end - 4))) {
            return 2;
        }
    }

    /* regular jump */
    return 0;
}

enum r4300_opcode r4300_decode(struct precomp_instr* inst, struct r4300_core* r4300, const struct r4300_idec* idec, uint32_t iw, uint32_t next_iw, const struct precomp_block* block)
{
    /* assume instr->addr is already setup */
    uint8_t dummy;
    enum r4300_opcode opcode = idec->opcode;

    switch(idec->opcode)
    {
    case R4300_OP_JALR:
        /* use the OUT version since we don't know until runtime
         * if we're going to jump inside or outside of block */
        opcode += 2;
        inst->f.r.rs = IDEC_U53(r4300, iw, idec->u53[2], &dummy);
        inst->f.r.rt = IDEC_U53(r4300, iw, idec->u53[1], &dummy);
        inst->f.r.rd = IDEC_U53(r4300, iw, idec->u53[0], &inst->f.r.nrd);
        idec_u53(iw, idec->u53[3], &inst->f.r.sa);
        break;

    case R4300_OP_JR:
        /* use the OUT version since we don't know until runtime
         * if we're going to jump inside or outside of block */
        opcode += 2;

        /* XXX: mips_instruction.def expects i-type */
        inst->f.i.rs = IDEC_U53(r4300, iw, idec->u53[2], &dummy);
        inst->f.i.rt = IDEC_U53(r4300, iw, idec->u53[1], &dummy);
        inst->f.i.immediate  = (int16_t)iw;
        break;

    case R4300_OP_J:
    case R4300_OP_JAL:
        inst->f.j.inst_index  = (iw & UINT32_C(0x3ffffff));
        /* select normal, idle or out jump type */
        opcode += infer_jump_sub_type((inst->addr & ~0xfffffff) | (idec_imm(iw, idec) & 0xfffffff), inst->addr, next_iw, block);
        break;

    case R4300_OP_BC0F:
    case R4300_OP_BC0FL:
    case R4300_OP_BC0T:
    case R4300_OP_BC0TL:
    case R4300_OP_BC1F:
    case R4300_OP_BC1FL:
    case R4300_OP_BC1T:
    case R4300_OP_BC1TL:
    case R4300_OP_BC2F:
    case R4300_OP_BC2FL:
    case R4300_OP_BC2T:
    case R4300_OP_BC2TL:
    case R4300_OP_BEQ:
    case R4300_OP_BEQL:
    case R4300_OP_BGEZ:
    case R4300_OP_BGEZAL:
    case R4300_OP_BGEZALL:
    case R4300_OP_BGEZL:
    case R4300_OP_BGTZ:
    case R4300_OP_BGTZL:
    case R4300_OP_BLEZ:
    case R4300_OP_BLEZL:
    case R4300_OP_BLTZ:
    case R4300_OP_BLTZAL:
    case R4300_OP_BLTZALL:
    case R4300_OP_BLTZL:
    case R4300_OP_BNE:
    case R4300_OP_BNEL:
        inst->f.i.rs = IDEC_U53(r4300, iw, idec->u53[2], &dummy);
        inst->f.i.rt = IDEC_U53(r4300, iw, idec->u53[1], &dummy);
        inst->f.i.immediate  = (int16_t)iw;

        /* select normal, idle or out branch type */
        opcode += infer_jump_sub_type(inst->addr + inst->f.i.immediate*4 + 4, inst->addr, next_iw, block);
        break;

    case R4300_OP_ADD:
    case R4300_OP_ADDU:
    case R4300_OP_AND:
    case R4300_OP_DADD:
    case R4300_OP_DADDU:
    case R4300_OP_DSLL:
    case R4300_OP_DSLL32:
    case R4300_OP_DSLLV:
    case R4300_OP_DSRA:
    case R4300_OP_DSRA32:
    case R4300_OP_DSRAV:
    case R4300_OP_DSRL:
    case R4300_OP_DSRL32:
    case R4300_OP_DSRLV:
    case R4300_OP_DSUB:
    case R4300_OP_DSUBU:
    case R4300_OP_MFHI:
    case R4300_OP_MFLO:
    case R4300_OP_NOR:
    case R4300_OP_OR:
    case R4300_OP_SLL:
    case R4300_OP_SLLV:
    case R4300_OP_SLT:
    case R4300_OP_SLTU:
    case R4300_OP_SRA:
    case R4300_OP_SRAV:
    case R4300_OP_SRL:
    case R4300_OP_SRLV:
    case R4300_OP_SUB:
    case R4300_OP_SUBU:
    case R4300_OP_XOR:
        inst->f.r.rs = IDEC_U53(r4300, iw, idec->u53[2], &dummy);
        inst->f.r.rt = IDEC_U53(r4300, iw, idec->u53[1], &dummy);
        inst->f.r.rd = IDEC_U53(r4300, iw, idec->u53[0], &inst->f.r.nrd);
        idec_u53(iw, idec->u53[3], &inst->f.r.sa);

        /* optimization: nopify instruction when r0 is the destination register (rd) */
        if (inst->f.r.nrd == 0) { opcode = R4300_OP_NOP; }
        break;

    case R4300_OP_ADDI:
    case R4300_OP_ADDIU:
    case R4300_OP_ANDI:
    case R4300_OP_DADDI:
    case R4300_OP_DADDIU:
    case R4300_OP_LB:
    case R4300_OP_LBU:
    case R4300_OP_LD:
    case R4300_OP_LDL:
    case R4300_OP_LDR:
    case R4300_OP_LH:
    case R4300_OP_LHU:
    case R4300_OP_LL:
    case R4300_OP_LLD:
    case R4300_OP_LUI:
    case R4300_OP_LW:
    case R4300_OP_LWL:
    case R4300_OP_LWR:
    case R4300_OP_LWU:
    case R4300_OP_ORI:
    case R4300_OP_SC:
    case R4300_OP_SLTI:
    case R4300_OP_SLTIU:
    case R4300_OP_XORI:
        inst->f.i.rs = IDEC_U53(r4300, iw, idec->u53[2], &dummy);
        inst->f.i.rt = IDEC_U53(r4300, iw, idec->u53[1], &dummy);
        inst->f.i.immediate  = (int16_t)iw;

        /* optimization: nopify instruction when r0 is the destination register (rt) */
        if (dummy == 0) { opcode = R4300_OP_NOP; }
        break;

    case R4300_OP_LDC1:
    case R4300_OP_LWC1:
    case R4300_OP_SDC1:
    case R4300_OP_SWC1:
        idec_u53(iw, idec->u53[2], &inst->f.lf.base);
        idec_u53(iw, idec->u53[1], &inst->f.lf.ft);
        inst->f.lf.offset  = (uint16_t)iw;
        break;

    case R4300_OP_CFC0:
    case R4300_OP_CFC1:
    case R4300_OP_CFC2:
    case R4300_OP_DMFC0:
    case R4300_OP_DMFC1:
    case R4300_OP_DMFC2:
    case R4300_OP_MFC0:
    case R4300_OP_MFC1:
    case R4300_OP_MFC2:
        inst->f.r.rs = IDEC_U53(r4300, iw, idec->u53[2], &dummy);
        inst->f.r.rt = IDEC_U53(r4300, iw, idec->u53[1], &dummy);
        inst->f.r.rd = IDEC_U53(r4300, iw, idec->u53[0], &inst->f.r.nrd);
        idec_u53(iw, idec->u53[3], &inst->f.r.sa);

        /* optimization: nopify instruction when r0 is the destination register (rt) */
        if (dummy == 0) { opcode = R4300_OP_NOP; }
        break;

#define CP1_S_D(op) \
    case R4300_OP_CP1_##op: \
        idec_u53(iw, idec->u53[3], &dummy); \
        idec_u53(iw, idec->u53[2], &inst->f.cf.fs); \
        idec_u53(iw, idec->u53[1], &inst->f.cf.ft); \
        idec_u53(iw, idec->u53[0], &inst->f.cf.fd); \
        switch(dummy) \
        { \
        case 0x10: inst->ops = cached_interp_##op##_S; return idec->opcode; \
        case 0x11: inst->ops = cached_interp_##op##_D; return idec->opcode; \
        default: opcode = R4300_OP_RESERVED; \
        } \
        break;

    CP1_S_D(ABS)
    CP1_S_D(ADD)
    CP1_S_D(CEIL_L)
    CP1_S_D(CEIL_W)
    CP1_S_D(C_EQ)
    CP1_S_D(C_F)
    CP1_S_D(C_LE)
    CP1_S_D(C_LT)
    CP1_S_D(C_NGE)
    CP1_S_D(C_NGL)
    CP1_S_D(C_NGLE)
    CP1_S_D(C_NGT)
    CP1_S_D(C_OLE)
    CP1_S_D(C_OLT)
    CP1_S_D(C_SEQ)
    CP1_S_D(C_SF)
    CP1_S_D(C_UEQ)
    CP1_S_D(C_ULE)
    CP1_S_D(C_ULT)
    CP1_S_D(C_UN)
    CP1_S_D(CVT_L)
    CP1_S_D(CVT_W)
    CP1_S_D(DIV)
    CP1_S_D(FLOOR_L)
    CP1_S_D(FLOOR_W)
    CP1_S_D(MOV)
    CP1_S_D(MUL)
    CP1_S_D(NEG)
    CP1_S_D(ROUND_L)
    CP1_S_D(ROUND_W)
    CP1_S_D(SQRT)
    CP1_S_D(SUB)
    CP1_S_D(TRUNC_L)
    CP1_S_D(TRUNC_W)
#undef CP1_S_D

    case R4300_OP_CP1_CVT_D:
        idec_u53(iw, idec->u53[3], &dummy);
        idec_u53(iw, idec->u53[2], &inst->f.cf.fs);
        idec_u53(iw, idec->u53[1], &inst->f.cf.ft);
        idec_u53(iw, idec->u53[0], &inst->f.cf.fd);
        switch(dummy)
        {
        case 0x10: inst->ops = cached_interp_CVT_D_S; return idec->opcode;
        case 0x14: inst->ops = cached_interp_CVT_D_W; return idec->opcode;
        case 0x15: inst->ops = cached_interp_CVT_D_L; return idec->opcode;
        default: opcode = R4300_OP_RESERVED;
        }
        break;

    case R4300_OP_CP1_CVT_S:
        idec_u53(iw, idec->u53[3], &dummy);
        idec_u53(iw, idec->u53[2], &inst->f.cf.fs);
        idec_u53(iw, idec->u53[1], &inst->f.cf.ft);
        idec_u53(iw, idec->u53[0], &inst->f.cf.fd);
        switch(dummy)
        {
        case 0x11: inst->ops = cached_interp_CVT_S_D; return idec->opcode;
        case 0x14: inst->ops = cached_interp_CVT_S_W; return idec->opcode;
        case 0x15: inst->ops = cached_interp_CVT_S_L; return idec->opcode;
        default: opcode = R4300_OP_RESERVED;
        }
        break;

    case R4300_OP_CTC0:
    case R4300_OP_CTC1:
    case R4300_OP_CTC2:
    case R4300_OP_DDIV:
    case R4300_OP_DDIVU:
    case R4300_OP_DIV:
    case R4300_OP_DIVU:
    case R4300_OP_DMTC0:
    case R4300_OP_DMTC1:
    case R4300_OP_DMTC2:
    case R4300_OP_DMULT:
    case R4300_OP_DMULTU:
    case R4300_OP_MTC0:
    case R4300_OP_MTC1:
    case R4300_OP_MTC2:
    case R4300_OP_MTHI:
    case R4300_OP_MTLO:
    case R4300_OP_MULT:
    case R4300_OP_MULTU:
    case R4300_OP_NOP:
    case R4300_OP_TEQ:
    case R4300_OP_TGE:
    case R4300_OP_TGEU:
    case R4300_OP_TLT:
    case R4300_OP_TLTU:
    case R4300_OP_TNE:
        inst->f.r.rs = IDEC_U53(r4300, iw, idec->u53[2], &dummy);
        inst->f.r.rt = IDEC_U53(r4300, iw, idec->u53[1], &dummy);
        inst->f.r.rd = IDEC_U53(r4300, iw, idec->u53[0], &inst->f.r.nrd);
        idec_u53(iw, idec->u53[3], &inst->f.r.sa);
        break;

    case R4300_OP_LDC2:
    case R4300_OP_LWC2:
    case R4300_OP_SB:
    case R4300_OP_SCD:
    case R4300_OP_SD:
    case R4300_OP_SDC2:
    case R4300_OP_SDL:
    case R4300_OP_SDR:
    case R4300_OP_SH:
    case R4300_OP_SW:
    case R4300_OP_SWC2:
    case R4300_OP_SWL:
    case R4300_OP_SWR:
    case R4300_OP_TEQI:
    case R4300_OP_TGEI:
    case R4300_OP_TGEIU:
    case R4300_OP_TLTI:
    case R4300_OP_TLTIU:
    case R4300_OP_TNEI:
        inst->f.i.rs = IDEC_U53(r4300, iw, idec->u53[2], &dummy);
        inst->f.i.rt = IDEC_U53(r4300, iw, idec->u53[1], &dummy);
        inst->f.i.immediate  = (int16_t)iw;
        break;

    case R4300_OP_BREAK:
    case R4300_OP_CACHE:
    case R4300_OP_ERET:
    case R4300_OP_SYNC:
    case R4300_OP_SYSCALL:
    case R4300_OP_TLBP:
    case R4300_OP_TLBR:
    case R4300_OP_TLBWI:
    case R4300_OP_TLBWR:
    case R4300_OP_RESERVED:
        /* no need for additonal instruction parsing */
        break;

    default:
        DebugMessage(M64MSG_ERROR, "invalid instruction: %08x", iw);
        assert(0);
        break;
    }

    /* set appropriate handler */
    inst->ops = ci_table[opcode];

    /* propagate opcode info to allow further processing */
    return opcode;
}


static uint32_t update_invalid_addr(struct r4300_core* r4300, uint32_t addr)
{
    char* const invalid_code = r4300->cached_interp.invalid_code;

    if ((addr & UINT32_C(0xc0000000)) == UINT32_C(0x80000000))
    {
        if (invalid_code[addr>>12]) {
            invalid_code[(addr^0x20000000)>>12] = 1;
        }
        if (invalid_code[(addr^0x20000000)>>12]) {
            invalid_code[addr>>12] = 1;
        }
        return addr;
    }
    else
    {
        uint32_t paddr = virtual_to_physical_address(r4300, addr, 2);
        if (paddr)
        {
            uint32_t beg_paddr = paddr - (addr - (addr & ~0xfff));

            update_invalid_addr(r4300, paddr);

            if (invalid_code[(beg_paddr+0x000)>>12]) {
                invalid_code[addr>>12] = 1;
            }
            if (invalid_code[(beg_paddr+0xffc)>>12]) {
                invalid_code[addr>>12] = 1;
            }
            if (invalid_code[addr>>12]) {
                invalid_code[(beg_paddr+0x000)>>12] = 1;
            }
            if (invalid_code[addr>>12]) {
                invalid_code[(beg_paddr+0xffc)>>12] = 1;
            }
        }
        return paddr;
    }
}

int get_block_length(const struct precomp_block *block)
{
    return (block->end-block->start)/4;
}

size_t get_block_memsize(const struct precomp_block *block)
{
    int length = get_block_length(block);
    return ((length+1)+(length>>2)) * sizeof(struct precomp_instr);
}

void cached_interp_init_block(struct r4300_core* r4300, uint32_t address)
{
    int i, length;

    struct precomp_block** block = &r4300->cached_interp.blocks[address >> 12];

    /* allocate block */
    if (*block == NULL) {
        *block = malloc(sizeof(struct precomp_block));
        (*block)->block = NULL;
        (*block)->start = address & ~UINT32_C(0xfff);
        (*block)->end = (address & ~UINT32_C(0xfff)) + 0x1000;
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
        b->block = (struct precomp_instr*)malloc(memsize);
        if (!b->block) {
            DebugMessage(M64MSG_ERROR, "Memory error: couldn't allocate memory for cached interpreter.");
            return;
        }

        memset(b->block, 0, memsize);
    }

    /* reset block instructions (addr + ops) */
    for (i = 0; i < length; ++i)
    {
        b->block[i].addr = b->start + 4*i;
        b->block[i].ops = cached_interp_NOTCOMPILED;
    }

    /* here we're marking the block as a valid code even if it's not compiled
     * yet as the game should have already set up the code correctly.
     */
    r4300->cached_interp.invalid_code[b->start>>12] = 0;


    if (b->end < UINT32_C(0x80000000) || b->start >= UINT32_C(0xc0000000))
    {
        uint32_t paddr = virtual_to_physical_address(r4300, b->start, 2);

        r4300->cached_interp.invalid_code[paddr>>12] = 0;
        cached_interp_init_block(r4300, paddr);

        paddr += b->end - b->start - 4;

        r4300->cached_interp.invalid_code[paddr>>12] = 0;
        cached_interp_init_block(r4300, paddr);
    }
    else
    {
        uint32_t alt_addr = b->start ^ UINT32_C(0x20000000);

        if (r4300->cached_interp.invalid_code[alt_addr>>12])
        {
            cached_interp_init_block(r4300, alt_addr);
        }
    }
}

void cached_interp_free_block(struct precomp_block* block)
{
    if (block->block) {
        free(block->block);
        block->block = NULL;
    }
}

void cached_interp_recompile_block(struct r4300_core* r4300, const uint32_t* iw, struct precomp_block* block, uint32_t func)
{
    int i, length, length2, finished;
    struct precomp_instr* inst;
    enum r4300_opcode opcode;

    /* ??? not sure why we need these 2 different tests */
    int block_start_in_tlb = ((block->start & UINT32_C(0xc0000000)) != UINT32_C(0x80000000));
    int block_not_in_tlb = (block->start >= UINT32_C(0xc0000000) || block->end < UINT32_C(0x80000000));

    length = get_block_length(block);
    length2 = length - 2 + (length >> 2);

    /* reset xxhash */
    block->xxhash = 0;


    for (i = (func & 0xFFF) / 4, finished = 0; finished != 2; ++i)
    {
        inst = block->block + i;

        /* set decoded instruction address */
        inst->addr = block->start + i * 4;

        if (block_start_in_tlb)
        {
            uint32_t address2 = virtual_to_physical_address(r4300, inst->addr, 0);
            if (r4300->cached_interp.blocks[address2>>12]->block[(address2&UINT32_C(0xFFF))/4].ops == cached_interp_NOTCOMPILED) {
                r4300->cached_interp.blocks[address2>>12]->block[(address2&UINT32_C(0xFFF))/4].ops = cached_interp_NOTCOMPILED2;
            }
        }

        /* decode instruction */
        opcode = r4300_decode(inst, r4300, r4300_get_idec(iw[i]), iw[i], iw[i+1], block);

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

    if (i >= length)
    {
        inst = block->block + i;
        inst->addr = block->start + i*4;
        inst->ops = cached_interp_FIN_BLOCK;
        ++i;
        if (i <= length2) // useful when last opcode is a jump
        {
            inst = block->block + i;
            inst->addr = block->start + i*4;
            inst->ops = cached_interp_FIN_BLOCK;
            i++;
        }
    }

#ifdef DBG
    DebugMessage(M64MSG_INFO, "block recompiled (%" PRIX32 "-%" PRIX32 ")", func, block->start+i*4);
#endif
}

void cached_interpreter_jump_to(struct r4300_core* r4300, uint32_t address)
{
    struct cached_interp* const cinterp = &r4300->cached_interp;

    if (r4300->skip_jump) {
        return;
    }

    if (!update_invalid_addr(r4300, address)) {
        return;
    }

    /* setup new block if invalid */
    if (cinterp->invalid_code[address >> 12]) {
        r4300->cached_interp.init_block(r4300, address);
    }

    /* set new PC */
    cinterp->actual = cinterp->blocks[address >> 12];
    (*r4300_pc_struct(r4300)) = cinterp->actual->block + ((address - cinterp->actual->start) >> 2);
}


void init_blocks(struct cached_interp* cinterp)
{
    size_t i;
    for (i = 0; i < 0x100000; ++i)
    {
        cinterp->invalid_code[i] = 1;
        cinterp->blocks[i] = NULL;
    }
}

void free_blocks(struct cached_interp* cinterp)
{
    size_t i;
    for (i = 0; i < 0x100000; ++i)
    {
        if (cinterp->blocks[i])
        {
            cinterp->free_block(cinterp->blocks[i]);
            free(cinterp->blocks[i]);
            cinterp->blocks[i] = NULL;
        }
    }
}

void invalidate_cached_code_hacktarux(struct r4300_core* r4300, uint32_t address, size_t size)
{
    size_t i;
    uint32_t addr;
    uint32_t addr_max;

    if (size == 0)
    {
        /* invalidate everthing */
        memset(r4300->cached_interp.invalid_code, 1, 0x100000);
    }
    else
    {
        /* invalidate blocks (if necessary) */
        addr_max = address+size;

        for(addr = address; addr < addr_max; addr += 4)
        {
            i = (addr >> 12);

            if (r4300->cached_interp.invalid_code[i] == 0)
            {
                if (r4300->cached_interp.blocks[i] == NULL
                 || r4300->cached_interp.blocks[i]->block[(addr & 0xfff) / 4].ops != r4300->cached_interp.not_compiled)
                {
                    r4300->cached_interp.invalid_code[i] = 1;
                    /* go directly to next i */
                    addr &= ~0xfff;
                    addr |= 0xffc;
                }
            }
            else
            {
                /* go directly to next i */
                addr &= ~0xfff;
                addr |= 0xffc;
            }
        }
    }
}

void run_cached_interpreter(struct r4300_core* r4300)
{
    while (!*r4300_stop(r4300))
    {
#ifdef COMPARE_CORE
        if ((*r4300_pc_struct(r4300))->ops == cached_interp_FIN_BLOCK && ((*r4300_pc_struct(r4300))->addr < 0x80000000 || (*r4300_pc_struct(r4300))->addr >= 0xc0000000))
            virtual_to_physical_address(r4300, (*r4300_pc_struct(r4300))->addr, 2);
        CoreCompareCallback();
#endif
#ifdef DBG
        if (g_DebuggerActive) update_debugger((*r4300_pc_struct(r4300))->addr);
#endif
        (*r4300_pc_struct(r4300))->ops();
    }
}
