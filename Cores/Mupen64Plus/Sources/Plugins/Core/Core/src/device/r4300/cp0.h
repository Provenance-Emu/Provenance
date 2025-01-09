/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cp0.h                                                   *
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

#ifndef M64P_DEVICE_R4300_CP0_H
#define M64P_DEVICE_R4300_CP0_H

#include <stdint.h>

#include "interrupt.h"
#include "tlb.h"

#include "new_dynarec/new_dynarec.h" /* for NEW_DYNAREC_ARM */

/* Status register definitions */
#define CP0_STATUS_IE   UINT32_C(0x00000001)
#define CP0_STATUS_EXL  UINT32_C(0x00000002)
#define CP0_STATUS_ERL  UINT32_C(0x00000004)
/* Execution modes */
#define CP0_STATUS_MODE_K    (UINT32_C(0  ) << 3)
#define CP0_STATUS_MODE_S    (UINT32_C(1  ) << 3)
#define CP0_STATUS_MODE_U    (UINT32_C(2  ) << 3)
#define CP0_STATUS_MODE_MASK (UINT32_C(0x3) << 3)
#define CP0_STATUS_UX   UINT32_C(0x00000020)
#define CP0_STATUS_SX   UINT32_C(0x00000040)
#define CP0_STATUS_KX   UINT32_C(0x00000080)
#define CP0_STATUS_IM0  UINT32_C(0x00000100)
#define CP0_STATUS_IM1  UINT32_C(0x00000200)
#define CP0_STATUS_IM2  UINT32_C(0x00000400)
#define CP0_STATUS_IM3  UINT32_C(0x00000800)
#define CP0_STATUS_IM4  UINT32_C(0x00001000)
#define CP0_STATUS_IM5  UINT32_C(0x00002000)
#define CP0_STATUS_IM6  UINT32_C(0x00004000)
#define CP0_STATUS_IM7  UINT32_C(0x00008000)
/* bit 16 and 17 are left for compatibility */
#define CP0_STATUS_CH   UINT32_C(0x00040000)
/* bit 19 is zero */
#define CP0_STATUS_SR   UINT32_C(0x00100000)
#define CP0_STATUS_TS   UINT32_C(0x00200000)
#define CP0_STATUS_BEV  UINT32_C(0x00400000)
#define CP0_STATUS_RSVD UINT32_C(0x00800000)
#define CP0_STATUS_ITS  UINT32_C(0x01000000)
#define CP0_STATUS_RE   UINT32_C(0x02000000)
#define CP0_STATUS_FR   UINT32_C(0x04000000)
#define CP0_STATUS_RP   UINT32_C(0x08000000)
#define CP0_STATUS_CU0  UINT32_C(0x10000000)
#define CP0_STATUS_CU1  UINT32_C(0x20000000)
#define CP0_STATUS_CU2  UINT32_C(0x40000000)
#define CP0_STATUS_CU3  UINT32_C(0x80000000)

/* Cause register definitions */
/* Execution Codes */
#define CP0_CAUSE_EXCCODE_INT   (UINT32_C(0 )   << 2)
#define CP0_CAUSE_EXCCODE_MOD   (UINT32_C(1 )   << 2)
#define CP0_CAUSE_EXCCODE_TLBL  (UINT32_C(2 )   << 2)
#define CP0_CAUSE_EXCCODE_TLBS  (UINT32_C(3 )   << 2)
#define CP0_CAUSE_EXCCODE_ADEL  (UINT32_C(4 )   << 2)
#define CP0_CAUSE_EXCCODE_ADES  (UINT32_C(5 )   << 2)
#define CP0_CAUSE_EXCCODE_IBE   (UINT32_C(6 )   << 2)
#define CP0_CAUSE_EXCCODE_DBE   (UINT32_C(7 )   << 2)
#define CP0_CAUSE_EXCCODE_SYS   (UINT32_C(8 )   << 2)
#define CP0_CAUSE_EXCCODE_BP    (UINT32_C(9 )   << 2)
#define CP0_CAUSE_EXCCODE_RI    (UINT32_C(10)   << 2)
#define CP0_CAUSE_EXCCODE_CPU   (UINT32_C(11)   << 2)
#define CP0_CAUSE_EXCCODE_OV    (UINT32_C(12)   << 2)
#define CP0_CAUSE_EXCCODE_TR    (UINT32_C(13)   << 2)
/* 14 is reserved */
#define CP0_CAUSE_EXCCODE_FPE   (UINT32_C(15)   << 2)
/* 16-22 are reserved */
#define CP0_CAUSE_EXCCODE_WATCH (UINT32_C(23)   << 2)
/* 24-31 are reserved */
#define CP0_CAUSE_EXCCODE_MASK  (UINT32_C(0x1f) << 2)
/* Interrupt Pending */
#define CP0_CAUSE_IP0  UINT32_C(0x00000100)    /* sw0 */
#define CP0_CAUSE_IP1  UINT32_C(0x00000200)    /* sw1 */
#define CP0_CAUSE_IP2  UINT32_C(0x00000400)    /* rcp */
#define CP0_CAUSE_IP3  UINT32_C(0x00000800)    /* cart */
#define CP0_CAUSE_IP4  UINT32_C(0x00001000)    /* pif */
#define CP0_CAUSE_IP5  UINT32_C(0x00002000)
#define CP0_CAUSE_IP6  UINT32_C(0x00004000)
#define CP0_CAUSE_IP7  UINT32_C(0x00008000)    /* timer */
#define CP0_CAUSE_CE1  UINT32_C(0x10000000)
#define CP0_CAUSE_BD   UINT32_C(0x80000000)


enum r4300_cp0_registers
{
    CP0_INDEX_REG,
    CP0_RANDOM_REG,
    CP0_ENTRYLO0_REG,
    CP0_ENTRYLO1_REG,
    CP0_CONTEXT_REG,
    CP0_PAGEMASK_REG,
    CP0_WIRED_REG,
    /* 7 is unused */
    CP0_BADVADDR_REG = 8,
    CP0_COUNT_REG,
    CP0_ENTRYHI_REG,
    CP0_COMPARE_REG,
    CP0_STATUS_REG,
    CP0_CAUSE_REG,
    CP0_EPC_REG,
    CP0_PREVID_REG,
    CP0_CONFIG_REG,
    CP0_LLADDR_REG,
    CP0_WATCHLO_REG,
    CP0_WATCHHI_REG,
    CP0_XCONTEXT_REG,
    /* 21 - 27 are unused */
    CP0_TAGLO_REG = 28,
    CP0_TAGHI_REG,
    CP0_ERROREPC_REG,
    /* 31 is unused */
    CP0_REGS_COUNT = 32
};



enum { INTERRUPT_NODES_POOL_CAPACITY = 16 };

struct interrupt_event
{
    int type;
    unsigned int count;
};

struct node
{
    struct interrupt_event data;
    struct node *next;
};

struct pool
{
    struct node nodes [INTERRUPT_NODES_POOL_CAPACITY];
    struct node* stack[INTERRUPT_NODES_POOL_CAPACITY];
    size_t index;
};

struct interrupt_queue
{
    struct pool pool;
    struct node* first;
};

struct interrupt_handler
{
    void* opaque;
    void (*callback)(void*);
};

enum { CP0_INTERRUPT_HANDLERS_COUNT = 12 };

enum {
    INTR_UNSAFE_R4300 = 0x01,
    INTR_UNSAFE_RSP = 0x02,
};

struct cp0
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    uint32_t regs[CP0_REGS_COUNT];
#endif

    /* set to avoid savestates/reset if state may be inconsistent
     * (e.g. in the middle of an instruction) */
    unsigned int interrupt_unsafe_state;

    struct interrupt_queue q;
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    unsigned int next_interrupt;
#endif

    struct interrupt_handler interrupt_handlers[CP0_INTERRUPT_HANDLERS_COUNT];

#if NEW_DYNAREC == NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    struct new_dynarec_hot_state* new_dynarec_hot_state;
#endif

    int special_done;

    uint32_t last_addr;
    unsigned int count_per_op;

    struct tlb tlb;
};

#if NEW_DYNAREC != NEW_DYNAREC_ARM
#define R4300_CP0_REGS_OFFSET (\
    offsetof(struct r4300_core, cp0) + \
    offsetof(struct cp0, regs))
#else
#define R4300_CP0_REGS_OFFSET (\
    offsetof(struct r4300_core, new_dynarec_hot_state) + \
    offsetof(struct new_dynarec_hot_state, cp0_regs))
#endif

void init_cp0(struct cp0* cp0, unsigned int count_per_op, struct new_dynarec_hot_state* new_dynarec_hot_state, const struct interrupt_handler* interrupt_handlers);
void poweron_cp0(struct cp0* cp0);

uint32_t* r4300_cp0_regs(struct cp0* cp0);
uint32_t* r4300_cp0_last_addr(struct cp0* cp0);
unsigned int* r4300_cp0_next_interrupt(struct cp0* cp0);

int check_cop1_unusable(struct r4300_core* r4300);

void cp0_update_count(struct r4300_core* r4300);

void TLB_refill_exception(struct r4300_core* r4300, uint32_t address, int w);
void exception_general(struct r4300_core* r4300);

#endif /* M64P_DEVICE_R4300_CP0_H */

