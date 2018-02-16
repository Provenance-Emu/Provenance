/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cached_interp.c                                         *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
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

#include <stdint.h>
#include <stdlib.h>

#define __STDC_FORMAT_MACROS
#include <inttypes.h>
#include <string.h>

#include "api/callbacks.h"
#include "api/debugger.h"
#include "api/m64p_types.h"
#include "cached_interp.h"
#include "cp0_private.h"
#include "cp1_private.h"
#include "exception.h"
#include "interupt.h"
#include "macros.h"
#include "main/main.h"
#include "memory/memory.h"
#include "ops.h"
#include "r4300.h"
#include "recomp.h"
#include "tlb.h"

#ifdef DBG
#include "debugger/dbg_debugger.h"
#include "debugger/dbg_types.h"
#endif

/* global variables */
char invalid_code[0x100000];
precomp_block *blocks[0x100000];
precomp_block *actual;
unsigned int jump_to_address;

// -----------------------------------------------------------
// Cached interpreter functions (and fallback for dynarec).
// -----------------------------------------------------------
#ifdef DBG
#define UPDATE_DEBUGGER() if (g_DebuggerActive) update_debugger(PC->addr)
#else
#define UPDATE_DEBUGGER() do { } while(0)
#endif

#define PCADDR PC->addr
#define ADD_TO_PC(x) PC += x;
#define DECLARE_INSTRUCTION(name) static void name(void)

#define DECLARE_JUMP(name, destination, condition, link, likely, cop1) \
   static void name(void) \
   { \
      const int take_jump = (condition); \
      const uint32_t jump_target = (destination); \
      int64_t *link_register = (link); \
      if (cop1 && check_cop1_unusable()) return; \
      if (link_register != &reg[0]) \
      { \
         *link_register = SE32(PC->addr + 8); \
      } \
      if (!likely || take_jump) \
      { \
         PC++; \
         delay_slot=1; \
         UPDATE_DEBUGGER(); \
         PC->ops(); \
         update_count(); \
         delay_slot=0; \
         if (take_jump && !skip_jump) \
         { \
            PC=actual->block+((jump_target-actual->start)>>2); \
         } \
      } \
      else \
      { \
         PC += 2; \
         update_count(); \
      } \
      last_addr = PC->addr; \
      if (next_interupt <= g_cp0_regs[CP0_COUNT_REG]) gen_interupt(); \
   } \
   static void name##_OUT(void) \
   { \
      const int take_jump = (condition); \
      const uint32_t jump_target = (destination); \
      int64_t *link_register = (link); \
      if (cop1 && check_cop1_unusable()) return; \
      if (link_register != &reg[0]) \
      { \
         *link_register = SE32(PC->addr + 8); \
      } \
      if (!likely || take_jump) \
      { \
         PC++; \
         delay_slot=1; \
         UPDATE_DEBUGGER(); \
         PC->ops(); \
         update_count(); \
         delay_slot=0; \
         if (take_jump && !skip_jump) \
         { \
            jump_to(jump_target); \
         } \
      } \
      else \
      { \
         PC += 2; \
         update_count(); \
      } \
      last_addr = PC->addr; \
      if (next_interupt <= g_cp0_regs[CP0_COUNT_REG]) gen_interupt(); \
   } \
   static void name##_IDLE(void) \
   { \
      const int take_jump = (condition); \
      int skip; \
      if (cop1 && check_cop1_unusable()) return; \
      if (take_jump) \
      { \
         update_count(); \
         skip = next_interupt - g_cp0_regs[CP0_COUNT_REG]; \
         if (skip > 3) g_cp0_regs[CP0_COUNT_REG] += (skip & UINT32_C(0xFFFFFFFC)); \
         else name(); \
      } \
      else name(); \
   }

#define CHECK_MEMORY() \
   if (!invalid_code[address>>12]) \
      if (blocks[address>>12]->block[(address&0xFFF)/4].ops != \
          current_instruction_table.NOTCOMPILED) \
         invalid_code[address>>12] = 1;

// two functions are defined from the macros above but never used
// these prototype declarations will prevent a warning
#if defined(__GNUC__)
  static void JR_IDLE(void) __attribute__((used));
  static void JALR_IDLE(void) __attribute__((used));
#endif

#include "interpreter.def"

// -----------------------------------------------------------
// Flow control 'fake' instructions
// -----------------------------------------------------------
static void FIN_BLOCK(void)
{
   if (!delay_slot)
     {
    jump_to((PC-1)->addr+4);
/*#ifdef DBG
            if (g_DebuggerActive) update_debugger(PC->addr);
#endif
Used by dynarec only, check should be unnecessary
*/
    PC->ops();
    if (r4300emu == CORE_DYNAREC) dyna_jump();
     }
   else
     {
    precomp_block *blk = actual;
    precomp_instr *inst = PC;
    jump_to((PC-1)->addr+4);
    
/*#ifdef DBG
            if (g_DebuggerActive) update_debugger(PC->addr);
#endif
Used by dynarec only, check should be unnecessary
*/
    if (!skip_jump)
      {
         PC->ops();
         actual = blk;
         PC = inst+1;
      }
    else
      PC->ops();
    
    if (r4300emu == CORE_DYNAREC) dyna_jump();
     }
}

static void NOTCOMPILED(void)
{
   uint32_t *mem = fast_mem_access(blocks[PC->addr>>12]->start);
#ifdef CORE_DBG
   DebugMessage(M64MSG_INFO, "NOTCOMPILED: addr = %x ops = %lx", PC->addr, (long) PC->ops);
#endif

   if (mem != NULL)
      recompile_block(mem, blocks[PC->addr >> 12], PC->addr);
   else
      DebugMessage(M64MSG_ERROR, "not compiled exception");

/*#ifdef DBG
            if (g_DebuggerActive) update_debugger(PC->addr);
#endif
The preceeding update_debugger SHOULD be unnecessary since it should have been
called before NOTCOMPILED would have been executed
*/
   PC->ops();
   if (r4300emu == CORE_DYNAREC)
     dyna_jump();
}

static void NOTCOMPILED2(void)
{
   NOTCOMPILED();
}

// -----------------------------------------------------------
// Cached interpreter instruction table
// -----------------------------------------------------------
const cpu_instruction_table cached_interpreter_table = {
   LB,
   LBU,
   LH,
   LHU,
   LW,
   LWL,
   LWR,
   SB,
   SH,
   SW,
   SWL,
   SWR,

   LD,
   LDL,
   LDR,
   LL,
   LWU,
   SC,
   SD,
   SDL,
   SDR,
   SYNC,

   ADDI,
   ADDIU,
   SLTI,
   SLTIU,
   ANDI,
   ORI,
   XORI,
   LUI,

   DADDI,
   DADDIU,

   ADD,
   ADDU,
   SUB,
   SUBU,
   SLT,
   SLTU,
   AND,
   OR,
   XOR,
   NOR,

   DADD,
   DADDU,
   DSUB,
   DSUBU,

   MULT,
   MULTU,
   DIV,
   DIVU,
   MFHI,
   MTHI,
   MFLO,
   MTLO,

   DMULT,
   DMULTU,
   DDIV,
   DDIVU,

   J,
   J_OUT,
   J_IDLE,
   JAL,
   JAL_OUT,
   JAL_IDLE,
   // Use the _OUT versions of JR and JALR, since we don't know
   // until runtime if they're going to jump inside or outside the block
   JR_OUT,
   JALR_OUT,
   BEQ,
   BEQ_OUT,
   BEQ_IDLE,
   BNE,
   BNE_OUT,
   BNE_IDLE,
   BLEZ,
   BLEZ_OUT,
   BLEZ_IDLE,
   BGTZ,
   BGTZ_OUT,
   BGTZ_IDLE,
   BLTZ,
   BLTZ_OUT,
   BLTZ_IDLE,
   BGEZ,
   BGEZ_OUT,
   BGEZ_IDLE,
   BLTZAL,
   BLTZAL_OUT,
   BLTZAL_IDLE,
   BGEZAL,
   BGEZAL_OUT,
   BGEZAL_IDLE,

   BEQL,
   BEQL_OUT,
   BEQL_IDLE,
   BNEL,
   BNEL_OUT,
   BNEL_IDLE,
   BLEZL,
   BLEZL_OUT,
   BLEZL_IDLE,
   BGTZL,
   BGTZL_OUT,
   BGTZL_IDLE,
   BLTZL,
   BLTZL_OUT,
   BLTZL_IDLE,
   BGEZL,
   BGEZL_OUT,
   BGEZL_IDLE,
   BLTZALL,
   BLTZALL_OUT,
   BLTZALL_IDLE,
   BGEZALL,
   BGEZALL_OUT,
   BGEZALL_IDLE,
   BC1TL,
   BC1TL_OUT,
   BC1TL_IDLE,
   BC1FL,
   BC1FL_OUT,
   BC1FL_IDLE,

   SLL,
   SRL,
   SRA,
   SLLV,
   SRLV,
   SRAV,

   DSLL,
   DSRL,
   DSRA,
   DSLLV,
   DSRLV,
   DSRAV,
   DSLL32,
   DSRL32,
   DSRA32,

   MTC0,
   MFC0,

   TLBR,
   TLBWI,
   TLBWR,
   TLBP,
   CACHE,
   ERET,

   LWC1,
   SWC1,
   MTC1,
   MFC1,
   CTC1,
   CFC1,
   BC1T,
   BC1T_OUT,
   BC1T_IDLE,
   BC1F,
   BC1F_OUT,
   BC1F_IDLE,

   DMFC1,
   DMTC1,
   LDC1,
   SDC1,

   CVT_S_D,
   CVT_S_W,
   CVT_S_L,
   CVT_D_S,
   CVT_D_W,
   CVT_D_L,
   CVT_W_S,
   CVT_W_D,
   CVT_L_S,
   CVT_L_D,

   ROUND_W_S,
   ROUND_W_D,
   ROUND_L_S,
   ROUND_L_D,

   TRUNC_W_S,
   TRUNC_W_D,
   TRUNC_L_S,
   TRUNC_L_D,

   CEIL_W_S,
   CEIL_W_D,
   CEIL_L_S,
   CEIL_L_D,

   FLOOR_W_S,
   FLOOR_W_D,
   FLOOR_L_S,
   FLOOR_L_D,

   ADD_S,
   ADD_D,

   SUB_S,
   SUB_D,

   MUL_S,
   MUL_D,

   DIV_S,
   DIV_D,
   
   ABS_S,
   ABS_D,

   MOV_S,
   MOV_D,

   NEG_S,
   NEG_D,

   SQRT_S,
   SQRT_D,

   C_F_S,
   C_F_D,
   C_UN_S,
   C_UN_D,
   C_EQ_S,
   C_EQ_D,
   C_UEQ_S,
   C_UEQ_D,
   C_OLT_S,
   C_OLT_D,
   C_ULT_S,
   C_ULT_D,
   C_OLE_S,
   C_OLE_D,
   C_ULE_S,
   C_ULE_D,
   C_SF_S,
   C_SF_D,
   C_NGLE_S,
   C_NGLE_D,
   C_SEQ_S,
   C_SEQ_D,
   C_NGL_S,
   C_NGL_D,
   C_LT_S,
   C_LT_D,
   C_NGE_S,
   C_NGE_D,
   C_LE_S,
   C_LE_D,
   C_NGT_S,
   C_NGT_D,

   SYSCALL,

   TEQ,

   NOP,
   RESERVED,
   NI,

   FIN_BLOCK,
   NOTCOMPILED,
   NOTCOMPILED2
};

static unsigned int update_invalid_addr(unsigned int addr)
{
   if (addr >= 0x80000000 && addr < 0xc0000000)
     {
    if (invalid_code[addr>>12]) invalid_code[(addr^0x20000000)>>12] = 1;
    if (invalid_code[(addr^0x20000000)>>12]) invalid_code[addr>>12] = 1;
    return addr;
     }
   else
     {
    unsigned int paddr = virtual_to_physical_address(addr, 2);
    if (paddr)
      {
         unsigned int beg_paddr = paddr - (addr - (addr&~0xFFF));
         update_invalid_addr(paddr);
         if (invalid_code[(beg_paddr+0x000)>>12]) invalid_code[addr>>12] = 1;
         if (invalid_code[(beg_paddr+0xFFC)>>12]) invalid_code[addr>>12] = 1;
         if (invalid_code[addr>>12]) invalid_code[(beg_paddr+0x000)>>12] = 1;
         if (invalid_code[addr>>12]) invalid_code[(beg_paddr+0xFFC)>>12] = 1;
      }
    return paddr;
     }
}

#define addr jump_to_address
void jump_to_func(void)
{
   unsigned int paddr;
   if (skip_jump) return;
   paddr = update_invalid_addr(addr);
   if (!paddr) return;
   actual = blocks[addr>>12];
   if (invalid_code[addr>>12])
     {
    if (!blocks[addr>>12])
      {
         blocks[addr>>12] = (precomp_block *) malloc(sizeof(precomp_block));
         actual = blocks[addr>>12];
         blocks[addr>>12]->code = NULL;
         blocks[addr>>12]->block = NULL;
         blocks[addr>>12]->jumps_table = NULL;
         blocks[addr>>12]->riprel_table = NULL;
      }
    blocks[addr>>12]->start = addr & ~0xFFF;
    blocks[addr>>12]->end = (addr & ~0xFFF) + 0x1000;
    init_block(blocks[addr>>12]);
     }
   PC=actual->block+((addr-actual->start)>>2);
   
   if (r4300emu == CORE_DYNAREC) dyna_jump();
}
#undef addr

void init_blocks(void)
{
   int i;
   for (i=0; i<0x100000; i++)
   {
      invalid_code[i] = 1;
      blocks[i] = NULL;
   }
}

void free_blocks(void)
{
   int i;
   for (i=0; i<0x100000; i++)
   {
        if (blocks[i])
        {
            free_block(blocks[i]);
            free(blocks[i]);
            blocks[i] = NULL;
        }
    }
}

void invalidate_cached_code_hacktarux(uint32_t address, size_t size)
{
    size_t i;
    uint32_t addr;
    uint32_t addr_max;

    if (size == 0)
    {
        /* invalidate everthing */
        memset(invalid_code, 1, 0x100000);
    }
    else
    {
        /* invalidate blocks (if necessary) */
        addr_max = address+size;

        for(addr = address; addr < addr_max; addr += 4)
        {
            i = (addr >> 12);

            if (invalid_code[i] == 0)
            {
                if (blocks[i] == NULL
                || blocks[i]->block[(addr & 0xfff) / 4].ops != current_instruction_table.NOTCOMPILED)
                {
                    invalid_code[i] = 1;
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

