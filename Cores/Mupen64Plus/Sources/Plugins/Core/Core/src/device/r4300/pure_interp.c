/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - pure_interp.c                                           *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2015 Nebuleon <nebuleon.fumika@gmail.com>               *
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

#include "pure_interp.h"

#include <stdint.h>

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

#include "api/callbacks.h"
#include "api/debugger.h"
#include "api/m64p_types.h"
#include "device/r4300/r4300_core.h"
#include "osal/preproc.h"

#ifdef DBG
#include "debugger/dbg_debugger.h"
#endif


static void InterpretOpcode(struct r4300_core* r4300);

#define DECLARE_R4300
#define PCADDR r4300->interp_PC.addr
#define ADD_TO_PC(x) r4300->interp_PC.addr += x*4;
#define DECLARE_INSTRUCTION(name) static void name(struct r4300_core* r4300, uint32_t op)
#define DECLARE_JUMP(name, destination, condition, link, likely, cop1) \
   static void name(struct r4300_core* r4300, uint32_t op) \
   { \
      const int take_jump = (condition); \
      const uint32_t jump_target = (destination); \
      int64_t *link_register = (link); \
      if (cop1 && check_cop1_unusable(r4300)) return; \
      if (link_register != &r4300_regs(r4300)[0]) \
      { \
          *link_register = SE32(r4300->interp_PC.addr + 8); \
      } \
      if (!likely || take_jump) \
      { \
        r4300->interp_PC.addr += 4; \
        r4300->delay_slot=1; \
        InterpretOpcode(r4300); \
        cp0_update_count(r4300); \
        r4300->delay_slot=0; \
        if (take_jump && !r4300->skip_jump) \
        { \
          r4300->interp_PC.addr = jump_target; \
        } \
      } \
      else \
      { \
         r4300->interp_PC.addr += 8; \
         cp0_update_count(r4300); \
      } \
      r4300->cp0.last_addr = r4300->interp_PC.addr; \
      if (*r4300_cp0_next_interrupt(&r4300->cp0) <= r4300_cp0_regs(&r4300->cp0)[CP0_COUNT_REG]) gen_interrupt(r4300); \
   } \
   static void name##_IDLE(struct r4300_core* r4300, uint32_t op) \
   { \
      uint32_t* cp0_regs = r4300_cp0_regs(&r4300->cp0); \
      const int take_jump = (condition); \
      int skip; \
      if (cop1 && check_cop1_unusable(r4300)) return; \
      if (take_jump) \
      { \
         cp0_update_count(r4300); \
         skip = *r4300_cp0_next_interrupt(&r4300->cp0) - cp0_regs[CP0_COUNT_REG]; \
         if (skip > 3) cp0_regs[CP0_COUNT_REG] += (skip & UINT32_C(0xFFFFFFFC)); \
         else name(r4300, op); \
      } \
      else name(r4300, op); \
   }

#define RD_OF(op)      (((op) >> 11) & 0x1F)
#define RS_OF(op)      (((op) >> 21) & 0x1F)
#define RT_OF(op)      (((op) >> 16) & 0x1F)
#define SA_OF(op)      (((op) >>  6) & 0x1F)
#define IMM16S_OF(op)  ((int16_t) (op))
#define IMM16U_OF(op)  ((uint16_t) (op))
#define FD_OF(op)      (((op) >>  6) & 0x1F)
#define FS_OF(op)      (((op) >> 11) & 0x1F)
#define FT_OF(op)      (((op) >> 16) & 0x1F)
#define JUMP_OF(op)    ((op) & UINT32_C(0x3FFFFFF))

/* Determines whether a relative jump in a 16-bit immediate goes back to the
 * same instruction without doing any work in its delay slot. The jump is
 * relative to the instruction in the delay slot, so 1 instruction backwards
 * (-1) goes back to the jump. */
#define IS_RELATIVE_IDLE_LOOP(r4300, op, addr) \
	(IMM16S_OF(op) == -1 && *fast_mem_access((r4300), (addr) + 4) == 0)

/* Determines whether an absolute jump in a 26-bit immediate goes back to the
 * same instruction without doing any work in its delay slot. The jump is
 * in the same 256 MiB segment as the delay slot, so if the jump instruction
 * is at the last address in its segment, it does not jump back to itself. */
#define IS_ABSOLUTE_IDLE_LOOP(r4300, op, addr) \
	(JUMP_OF(op) == ((addr) & UINT32_C(0x0FFFFFFF)) >> 2 \
	 && ((addr) & UINT32_C(0x0FFFFFFF)) != UINT32_C(0x0FFFFFFC) \
	 && *fast_mem_access((r4300), (addr) + 4) == 0)

/* These macros parse opcode fields. */
#define rrt r4300_regs(r4300)[RT_OF(op)]
#define rrd r4300_regs(r4300)[RD_OF(op)]
#define rfs FS_OF(op)
#define rrs r4300_regs(r4300)[RS_OF(op)]
#define rsa SA_OF(op)
#define irt r4300_regs(r4300)[RT_OF(op)]
#define ioffset IMM16S_OF(op)
#define iimmediate IMM16S_OF(op)
#define irs r4300_regs(r4300)[RS_OF(op)]
#define ibase r4300_regs(r4300)[RS_OF(op)]
#define jinst_index JUMP_OF(op)
#define lfbase RS_OF(op)
#define lfft FT_OF(op)
#define lfoffset IMM16S_OF(op)
#define cfft FT_OF(op)
#define cffs FS_OF(op)
#define cffd FD_OF(op)

// 32 bits macros
#ifndef M64P_BIG_ENDIAN
#define rrt32 *((int32_t*) &r4300_regs(r4300)[RT_OF(op)])
#define rrd32 *((int32_t*) &r4300_regs(r4300)[RD_OF(op)])
#define rrs32 *((int32_t*) &r4300_regs(r4300)[RS_OF(op)])
#define irs32 *((int32_t*) &r4300_regs(r4300)[RS_OF(op)])
#define irt32 *((int32_t*) &r4300_regs(r4300)[RT_OF(op)])
#else
#define rrt32 *((int32_t*) &r4300_regs(r4300)[RT_OF(op)] + 1)
#define rrd32 *((int32_t*) &r4300_regs(r4300)[RD_OF(op)] + 1)
#define rrs32 *((int32_t*) &r4300_regs(r4300)[RS_OF(op)] + 1)
#define irs32 *((int32_t*) &r4300_regs(r4300)[RS_OF(op)] + 1)
#define irt32 *((int32_t*) &r4300_regs(r4300)[RT_OF(op)] + 1)
#endif

// two functions are defined from the macros above but never used
// these prototype declarations will prevent a warning
#if defined(__GNUC__)
  static void JR_IDLE(struct r4300_core*, uint32_t) __attribute__((used));
  static void JALR_IDLE(struct r4300_core*, uint32_t) __attribute__((used));
#endif

#include "mips_instructions.def"

void InterpretOpcode(struct r4300_core* r4300)
{
	uint32_t* op_address = fast_mem_access(r4300, *r4300_pc(r4300));
	if (op_address == NULL)
		return;
	uint32_t op = *op_address;

	switch ((op >> 26) & 0x3F) {
	case 0: /* SPECIAL prefix */
		switch (op & 0x3F) {
		case 0: /* SPECIAL opcode 0: SLL */
			if (RD_OF(op) != 0) SLL(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 2: /* SPECIAL opcode 2: SRL */
			if (RD_OF(op) != 0) SRL(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 3: /* SPECIAL opcode 3: SRA */
			if (RD_OF(op) != 0) SRA(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 4: /* SPECIAL opcode 4: SLLV */
			if (RD_OF(op) != 0) SLLV(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 6: /* SPECIAL opcode 6: SRLV */
			if (RD_OF(op) != 0) SRLV(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 7: /* SPECIAL opcode 7: SRAV */
			if (RD_OF(op) != 0) SRAV(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 8: JR(r4300, op); break;
		case 9: /* SPECIAL opcode 9: JALR */
			/* Note: This can omit the check for Rd == 0 because the JALR
			 * function checks for link_register != &r4300_regs(4300)[0]. If you're
			 * using this as a reference for a JIT, do check Rd == 0 in it. */
			JALR(r4300, op);
			break;
		case 12: SYSCALL(r4300, op); break;
		case 13: /* SPECIAL opcode 13: BREAK (Not implemented) */
			NI(r4300, op);
			break;
		case 15: SYNC(r4300, op); break;
		case 16: /* SPECIAL opcode 16: MFHI */
			if (RD_OF(op) != 0) MFHI(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 17: MTHI(r4300, op); break;
		case 18: /* SPECIAL opcode 18: MFLO */
			if (RD_OF(op) != 0) MFLO(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 19: MTLO(r4300, op); break;
		case 20: /* SPECIAL opcode 20: DSLLV */
			if (RD_OF(op) != 0) DSLLV(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 22: /* SPECIAL opcode 22: DSRLV */
			if (RD_OF(op) != 0) DSRLV(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 23: /* SPECIAL opcode 23: DSRAV */
			if (RD_OF(op) != 0) DSRAV(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 24: MULT(r4300, op); break;
		case 25: MULTU(r4300, op); break;
		case 26: DIV(r4300, op); break;
		case 27: DIVU(r4300, op); break;
		case 28: DMULT(r4300, op); break;
		case 29: DMULTU(r4300, op); break;
		case 30: DDIV(r4300, op); break;
		case 31: DDIVU(r4300, op); break;
		case 32: /* SPECIAL opcode 32: ADD */
			if (RD_OF(op) != 0) ADD(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 33: /* SPECIAL opcode 33: ADDU */
			if (RD_OF(op) != 0) ADDU(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 34: /* SPECIAL opcode 34: SUB */
			if (RD_OF(op) != 0) SUB(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 35: /* SPECIAL opcode 35: SUBU */
			if (RD_OF(op) != 0) SUBU(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 36: /* SPECIAL opcode 36: AND */
			if (RD_OF(op) != 0) AND(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 37: /* SPECIAL opcode 37: OR */
			if (RD_OF(op) != 0) OR(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 38: /* SPECIAL opcode 38: XOR */
			if (RD_OF(op) != 0) XOR(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 39: /* SPECIAL opcode 39: NOR */
			if (RD_OF(op) != 0) NOR(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 42: /* SPECIAL opcode 42: SLT */
			if (RD_OF(op) != 0) SLT(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 43: /* SPECIAL opcode 43: SLTU */
			if (RD_OF(op) != 0) SLTU(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 44: /* SPECIAL opcode 44: DADD */
			if (RD_OF(op) != 0) DADD(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 45: /* SPECIAL opcode 45: DADDU */
			if (RD_OF(op) != 0) DADDU(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 46: /* SPECIAL opcode 46: DSUB */
			if (RD_OF(op) != 0) DSUB(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 47: /* SPECIAL opcode 47: DSUBU */
			if (RD_OF(op) != 0) DSUBU(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 48: /* SPECIAL opcode 48: TGE (Not implemented) */
		case 49: /* SPECIAL opcode 49: TGEU (Not implemented) */
		case 50: /* SPECIAL opcode 50: TLT (Not implemented) */
		case 51: /* SPECIAL opcode 51: TLTU (Not implemented) */
			NI(r4300, op);
			break;
		case 52: TEQ(r4300, op); break;
		case 54: /* SPECIAL opcode 54: TNE (Not implemented) */
			NI(r4300, op);
			break;
		case 56: /* SPECIAL opcode 56: DSLL */
			if (RD_OF(op) != 0) DSLL(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 58: /* SPECIAL opcode 58: DSRL */
			if (RD_OF(op) != 0) DSRL(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 59: /* SPECIAL opcode 59: DSRA */
			if (RD_OF(op) != 0) DSRA(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 60: /* SPECIAL opcode 60: DSLL32 */
			if (RD_OF(op) != 0) DSLL32(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 62: /* SPECIAL opcode 62: DSRL32 */
			if (RD_OF(op) != 0) DSRL32(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 63: /* SPECIAL opcode 63: DSRA32 */
			if (RD_OF(op) != 0) DSRA32(r4300, op);
			else                NOP(r4300, 0);
			break;
		default: /* SPECIAL opcodes 1, 5, 10, 11, 14, 21, 40, 41, 53, 55, 57,
		            61: Reserved Instructions */
			RESERVED(r4300, op);
			break;
		} /* switch (op & 0x3F) for the SPECIAL prefix */
		break;
	case 1: /* REGIMM prefix */
		switch ((op >> 16) & 0x1F) {
		case 0: /* REGIMM opcode 0: BLTZ */
			if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BLTZ_IDLE(r4300, op);
			else                                             BLTZ(r4300, op);
			break;
		case 1: /* REGIMM opcode 1: BGEZ */
			if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BGEZ_IDLE(r4300, op);
			else                                             BGEZ(r4300, op);
			break;
		case 2: /* REGIMM opcode 2: BLTZL */
			if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BLTZL_IDLE(r4300, op);
			else                                             BLTZL(r4300, op);
			break;
		case 3: /* REGIMM opcode 3: BGEZL */
			if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BGEZL_IDLE(r4300, op);
			else                                             BGEZL(r4300, op);
			break;
		case 8: /* REGIMM opcode 8: TGEI (Not implemented) */
		case 9: /* REGIMM opcode 9: TGEIU (Not implemented) */
		case 10: /* REGIMM opcode 10: TLTI (Not implemented) */
		case 11: /* REGIMM opcode 11: TLTIU (Not implemented) */
		case 12: /* REGIMM opcode 12: TEQI (Not implemented) */
		case 14: /* REGIMM opcode 14: TNEI (Not implemented) */
			NI(r4300, op);
			break;
		case 16: /* REGIMM opcode 16: BLTZAL */
			if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BLTZAL_IDLE(r4300, op);
			else                                             BLTZAL(r4300, op);
			break;
		case 17: /* REGIMM opcode 17: BGEZAL */
			if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BGEZAL_IDLE(r4300, op);
			else                                             BGEZAL(r4300, op);
			break;
		case 18: /* REGIMM opcode 18: BLTZALL */
			if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BLTZALL_IDLE(r4300, op);
			else                                             BLTZALL(r4300, op);
			break;
		case 19: /* REGIMM opcode 19: BGEZALL */
			if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BGEZALL_IDLE(r4300, op);
			else                                             BGEZALL(r4300, op);
			break;
		default: /* REGIMM opcodes 4..7, 13, 15, 20..31:
		            Reserved Instructions */
			RESERVED(r4300, op);
			break;
		} /* switch ((op >> 16) & 0x1F) for the REGIMM prefix */
		break;
	case 2: /* Major opcode 2: J */
		if (IS_ABSOLUTE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) J_IDLE(r4300, op);
		else                                             J(r4300, op);
		break;
	case 3: /* Major opcode 3: JAL */
		if (IS_ABSOLUTE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) JAL_IDLE(r4300, op);
		else                                             JAL(r4300, op);
		break;
	case 4: /* Major opcode 4: BEQ */
		if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BEQ_IDLE(r4300, op);
		else                                             BEQ(r4300, op);
		break;
	case 5: /* Major opcode 5: BNE */
		if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BNE_IDLE(r4300, op);
		else                                             BNE(r4300, op);
		break;
	case 6: /* Major opcode 6: BLEZ */
		if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BLEZ_IDLE(r4300, op);
		else                                             BLEZ(r4300, op);
		break;
	case 7: /* Major opcode 7: BGTZ */
		if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BGTZ_IDLE(r4300, op);
		else                                             BGTZ(r4300, op);
		break;
	case 8: /* Major opcode 8: ADDI */
		if (RT_OF(op) != 0) ADDI(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 9: /* Major opcode 9: ADDIU */
		if (RT_OF(op) != 0) ADDIU(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 10: /* Major opcode 10: SLTI */
		if (RT_OF(op) != 0) SLTI(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 11: /* Major opcode 11: SLTIU */
		if (RT_OF(op) != 0) SLTIU(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 12: /* Major opcode 12: ANDI */
		if (RT_OF(op) != 0) ANDI(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 13: /* Major opcode 13: ORI */
		if (RT_OF(op) != 0) ORI(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 14: /* Major opcode 14: XORI */
		if (RT_OF(op) != 0) XORI(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 15: /* Major opcode 15: LUI */
		if (RT_OF(op) != 0) LUI(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 16: /* Coprocessor 0 prefix */
		switch ((op >> 21) & 0x1F) {
		case 0: /* Coprocessor 0 opcode 0: MFC0 */
			if (RT_OF(op) != 0) MFC0(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 4: MTC0(r4300, op); break;
		case 16: /* Coprocessor 0 opcode 16: TLB */
			switch (op & 0x3F) {
			case 1: TLBR(r4300, op); break;
			case 2: TLBWI(r4300, op); break;
			case 6: TLBWR(r4300, op); break;
			case 8: TLBP(r4300, op); break;
			case 24: ERET(r4300, op); break;
			default: /* TLB sub-opcodes 0, 3..5, 7, 9..23, 25..63:
			            Reserved Instructions */
				RESERVED(r4300, op);
				break;
			} /* switch (op & 0x3F) for Coprocessor 0 TLB opcodes */
			break;
		default: /* Coprocessor 0 opcodes 1..3, 4..15, 17..31:
		            Reserved Instructions */
			RESERVED(r4300, op);
			break;
		} /* switch ((op >> 21) & 0x1F) for the Coprocessor 0 prefix */
		break;
	case 17: /* Coprocessor 1 prefix */
		switch ((op >> 21) & 0x1F) {
		case 0: /* Coprocessor 1 opcode 0: MFC1 */
			if (RT_OF(op) != 0) MFC1(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 1: /* Coprocessor 1 opcode 1: DMFC1 */
			if (RT_OF(op) != 0) DMFC1(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 2: /* Coprocessor 1 opcode 2: CFC1 */
			if (RT_OF(op) != 0) CFC1(r4300, op);
			else                NOP(r4300, 0);
			break;
		case 4: MTC1(r4300, op); break;
		case 5: DMTC1(r4300, op); break;
		case 6: CTC1(r4300, op); break;
		case 8: /* Coprocessor 1 opcode 8: Branch on C1 condition... */
			switch ((op >> 16) & 0x3) {
			case 0: /* opcode 0: BC1F */
				if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BC1F_IDLE(r4300, op);
				else                                             BC1F(r4300, op);
				break;
			case 1: /* opcode 1: BC1T */
				if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BC1T_IDLE(r4300, op);
				else                                             BC1T(r4300, op);
				break;
			case 2: /* opcode 2: BC1FL */
				if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BC1FL_IDLE(r4300, op);
				else                                             BC1FL(r4300, op);
				break;
			case 3: /* opcode 3: BC1TL */
				if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BC1TL_IDLE(r4300, op);
				else                                             BC1TL(r4300, op);
				break;
			} /* switch ((op >> 16) & 0x3) for branches on C1 condition */
			break;
		case 16: /* Coprocessor 1 S-format opcodes */
			switch (op & 0x3F) {
			case 0: ADD_S(r4300, op); break;
			case 1: SUB_S(r4300, op); break;
			case 2: MUL_S(r4300, op); break;
			case 3: DIV_S(r4300, op); break;
			case 4: SQRT_S(r4300, op); break;
			case 5: ABS_S(r4300, op); break;
			case 6: MOV_S(r4300, op); break;
			case 7: NEG_S(r4300, op); break;
			case 8: ROUND_L_S(r4300, op); break;
			case 9: TRUNC_L_S(r4300, op); break;
			case 10: CEIL_L_S(r4300, op); break;
			case 11: FLOOR_L_S(r4300, op); break;
			case 12: ROUND_W_S(r4300, op); break;
			case 13: TRUNC_W_S(r4300, op); break;
			case 14: CEIL_W_S(r4300, op); break;
			case 15: FLOOR_W_S(r4300, op); break;
			case 33: CVT_D_S(r4300, op); break;
			case 36: CVT_W_S(r4300, op); break;
			case 37: CVT_L_S(r4300, op); break;
			case 48: C_F_S(r4300, op); break;
			case 49: C_UN_S(r4300, op); break;
			case 50: C_EQ_S(r4300, op); break;
			case 51: C_UEQ_S(r4300, op); break;
			case 52: C_OLT_S(r4300, op); break;
			case 53: C_ULT_S(r4300, op); break;
			case 54: C_OLE_S(r4300, op); break;
			case 55: C_ULE_S(r4300, op); break;
			case 56: C_SF_S(r4300, op); break;
			case 57: C_NGLE_S(r4300, op); break;
			case 58: C_SEQ_S(r4300, op); break;
			case 59: C_NGL_S(r4300, op); break;
			case 60: C_LT_S(r4300, op); break;
			case 61: C_NGE_S(r4300, op); break;
			case 62: C_LE_S(r4300, op); break;
			case 63: C_NGT_S(r4300, op); break;
			default: /* Coprocessor 1 S-format opcodes 16..32, 34..35, 38..47:
			            Reserved Instructions */
				RESERVED(r4300, op);
				break;
			} /* switch (op & 0x3F) for Coprocessor 1 S-format opcodes */
			break;
		case 17: /* Coprocessor 1 D-format opcodes */
			switch (op & 0x3F) {
			case 0: ADD_D(r4300, op); break;
			case 1: SUB_D(r4300, op); break;
			case 2: MUL_D(r4300, op); break;
			case 3: DIV_D(r4300, op); break;
			case 4: SQRT_D(r4300, op); break;
			case 5: ABS_D(r4300, op); break;
			case 6: MOV_D(r4300, op); break;
			case 7: NEG_D(r4300, op); break;
			case 8: ROUND_L_D(r4300, op); break;
			case 9: TRUNC_L_D(r4300, op); break;
			case 10: CEIL_L_D(r4300, op); break;
			case 11: FLOOR_L_D(r4300, op); break;
			case 12: ROUND_W_D(r4300, op); break;
			case 13: TRUNC_W_D(r4300, op); break;
			case 14: CEIL_W_D(r4300, op); break;
			case 15: FLOOR_W_D(r4300, op); break;
			case 32: CVT_S_D(r4300, op); break;
			case 36: CVT_W_D(r4300, op); break;
			case 37: CVT_L_D(r4300, op); break;
			case 48: C_F_D(r4300, op); break;
			case 49: C_UN_D(r4300, op); break;
			case 50: C_EQ_D(r4300, op); break;
			case 51: C_UEQ_D(r4300, op); break;
			case 52: C_OLT_D(r4300, op); break;
			case 53: C_ULT_D(r4300, op); break;
			case 54: C_OLE_D(r4300, op); break;
			case 55: C_ULE_D(r4300, op); break;
			case 56: C_SF_D(r4300, op); break;
			case 57: C_NGLE_D(r4300, op); break;
			case 58: C_SEQ_D(r4300, op); break;
			case 59: C_NGL_D(r4300, op); break;
			case 60: C_LT_D(r4300, op); break;
			case 61: C_NGE_D(r4300, op); break;
			case 62: C_LE_D(r4300, op); break;
			case 63: C_NGT_D(r4300, op); break;
			default: /* Coprocessor 1 D-format opcodes 16..31, 33..35, 38..47:
			            Reserved Instructions */
				RESERVED(r4300, op);
				break;
			} /* switch (op & 0x3F) for Coprocessor 1 D-format opcodes */
			break;
		case 20: /* Coprocessor 1 W-format opcodes */
			switch (op & 0x3F) {
			case 32: CVT_S_W(r4300, op); break;
			case 33: CVT_D_W(r4300, op); break;
			default: /* Coprocessor 1 W-format opcodes 0..31, 34..63:
			            Reserved Instructions */
				RESERVED(r4300, op);
				break;
			}
			break;
		case 21: /* Coprocessor 1 L-format opcodes */
			switch (op & 0x3F) {
			case 32: CVT_S_L(r4300, op); break;
			case 33: CVT_D_L(r4300, op); break;
			default: /* Coprocessor 1 L-format opcodes 0..31, 34..63:
			            Reserved Instructions */
				RESERVED(r4300, op);
				break;
			}
			break;
		default: /* Coprocessor 1 opcodes 3, 7, 9..15, 18..19, 22..31:
		            Reserved Instructions */
			RESERVED(r4300, op);
			break;
		} /* switch ((op >> 21) & 0x1F) for the Coprocessor 1 prefix */
		break;
	case 20: /* Major opcode 20: BEQL */
		if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BEQL_IDLE(r4300, op);
		else                                             BEQL(r4300, op);
		break;
	case 21: /* Major opcode 21: BNEL */
		if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BNEL_IDLE(r4300, op);
		else                                             BNEL(r4300, op);
		break;
	case 22: /* Major opcode 22: BLEZL */
		if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BLEZL_IDLE(r4300, op);
		else                                             BLEZL(r4300, op);
		break;
	case 23: /* Major opcode 23: BGTZL */
		if (IS_RELATIVE_IDLE_LOOP(r4300, op, *r4300_pc(r4300))) BGTZL_IDLE(r4300, op);
		else                                             BGTZL(r4300, op);
		break;
	case 24: /* Major opcode 24: DADDI */
		if (RT_OF(op) != 0) DADDI(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 25: /* Major opcode 25: DADDIU */
		if (RT_OF(op) != 0) DADDIU(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 26: /* Major opcode 26: LDL */
		if (RT_OF(op) != 0) LDL(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 27: /* Major opcode 27: LDR */
		if (RT_OF(op) != 0) LDR(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 32: /* Major opcode 32: LB */
		if (RT_OF(op) != 0) LB(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 33: /* Major opcode 33: LH */
		if (RT_OF(op) != 0) LH(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 34: /* Major opcode 34: LWL */
		if (RT_OF(op) != 0) LWL(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 35: /* Major opcode 35: LW */
		if (RT_OF(op) != 0) LW(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 36: /* Major opcode 36: LBU */
		if (RT_OF(op) != 0) LBU(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 37: /* Major opcode 37: LHU */
		if (RT_OF(op) != 0) LHU(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 38: /* Major opcode 38: LWR */
		if (RT_OF(op) != 0) LWR(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 39: /* Major opcode 39: LWU */
		if (RT_OF(op) != 0) LWU(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 40: SB(r4300, op); break;
	case 41: SH(r4300, op); break;
	case 42: SWL(r4300, op); break;
	case 43: SW(r4300, op); break;
	case 44: SDL(r4300, op); break;
	case 45: SDR(r4300, op); break;
	case 46: SWR(r4300, op); break;
	case 47: CACHE(r4300, op); break;
	case 48: /* Major opcode 48: LL */
		if (RT_OF(op) != 0) LL(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 49: LWC1(r4300, op); break;
	case 52: /* Major opcode 52: LLD (Not implemented) */
		NI(r4300, op);
		break;
	case 53: LDC1(r4300, op); break;
	case 55: /* Major opcode 55: LD */
		if (RT_OF(op) != 0) LD(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 56: /* Major opcode 56: SC */
		if (RT_OF(op) != 0) SC(r4300, op);
		else                NOP(r4300, 0);
		break;
	case 57: SWC1(r4300, op); break;
	case 60: /* Major opcode 60: SCD (Not implemented) */
		NI(r4300, op);
		break;
	case 61: SDC1(r4300, op); break;
	case 63: SD(r4300, op); break;
	default: /* Major opcodes 18..19, 28..31, 50..51, 54, 58..59, 62:
	            Reserved Instructions */
		RESERVED(r4300, op);
		break;
	} /* switch ((op >> 26) & 0x3F) */
}

void run_pure_interpreter(struct r4300_core* r4300)
{
   *r4300_stop(r4300) = 0;
   *r4300_pc_struct(r4300) = &r4300->interp_PC;
   *r4300_pc(r4300) = r4300->cp0.last_addr = 0xa4000040;

   while (!*r4300_stop(r4300))
   {
#ifdef COMPARE_CORE
     CoreCompareCallback();
#endif
#ifdef DBG
     if (g_DebuggerActive) update_debugger(*r4300_pc(r4300));
#endif
     InterpretOpcode(r4300);
   }
}
