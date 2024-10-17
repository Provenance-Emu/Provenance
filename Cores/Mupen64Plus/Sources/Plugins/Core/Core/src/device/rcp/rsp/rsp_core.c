/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rsp_core.c                                              *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2014 Bobby Smiles                                       *
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

#include "rsp_core.h"

#include <string.h>

#include "device/memory/memory.h"
#include "device/r4300/r4300_core.h"
#include "device/rcp/mi/mi_controller.h"
#include "device/rcp/rdp/rdp_core.h"
#include "device/rcp/ri/ri_controller.h"
#include "device/rdram/rdram.h"
#include "main/main.h"
#if defined(PROFILE)
#include "main/profile.h"
#endif
#include "plugin/plugin.h"

static void dma_sp_write(struct rsp_core* sp)
{
    unsigned int i,j;

    unsigned int l = sp->regs[SP_RD_LEN_REG];

    unsigned int length = ((l & 0xfff) | 7) + 1;
    unsigned int count = ((l >> 12) & 0xff) + 1;
    unsigned int skip = ((l >> 20) & 0xfff);

    unsigned int memaddr = sp->regs[SP_MEM_ADDR_REG] & 0xfff;
    unsigned int dramaddr = sp->regs[SP_DRAM_ADDR_REG] & 0xffffff;

    unsigned char *spmem = (unsigned char*)sp->mem + (sp->regs[SP_MEM_ADDR_REG] & 0x1000);
    unsigned char *dram = (unsigned char*)sp->ri->rdram->dram;

    for(j=0; j<count; j++) {
        pre_framebuffer_read(&sp->dp->fb, dramaddr);

        for(i=0; i<length; i++) {
            spmem[memaddr^S8] = dram[dramaddr^S8];
            memaddr++;
            dramaddr++;
        }
        dramaddr+=skip;
    }
}

static void dma_sp_read(struct rsp_core* sp)
{
    unsigned int i,j;

    unsigned int l = sp->regs[SP_WR_LEN_REG];

    unsigned int length = ((l & 0xfff) | 7) + 1;
    unsigned int count = ((l >> 12) & 0xff) + 1;
    unsigned int skip = ((l >> 20) & 0xfff);

    unsigned int memaddr = sp->regs[SP_MEM_ADDR_REG] & 0xfff;
    unsigned int dramaddr = sp->regs[SP_DRAM_ADDR_REG] & 0xffffff;

    unsigned char *spmem = (unsigned char*)sp->mem + (sp->regs[SP_MEM_ADDR_REG] & 0x1000);
    unsigned char *dram = (unsigned char*)sp->ri->rdram->dram;

    for(j=0; j<count; j++) {
        for(i=0; i<length; i++) {
            dram[dramaddr^S8] = spmem[memaddr^S8];
            memaddr++;
            dramaddr++;
        }

        post_framebuffer_write(&sp->dp->fb, dramaddr - length, length);
        dramaddr+=skip;
    }
}

static void update_sp_status(struct rsp_core* sp, uint32_t w)
{
    /* clear / set halt */
    if (w & 0x1) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_HALT;
    if (w & 0x2) sp->regs[SP_STATUS_REG] |= SP_STATUS_HALT;

    /* clear broke */
    if (w & 0x4) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_BROKE;

    /* clear SP interrupt */
    if (w & 0x8)
    {
        clear_rcp_interrupt(sp->mi, MI_INTR_SP);
    }
    /* set SP interrupt */
    if (w & 0x10)
    {
        signal_rcp_interrupt(sp->mi, MI_INTR_SP);
    }

    /* clear / set single step */
    if (w & 0x20) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_SSTEP;
    if (w & 0x40) sp->regs[SP_STATUS_REG] |= SP_STATUS_SSTEP;

    /* clear / set interrupt on break */
    if (w & 0x80) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_INTR_BREAK;
    if (w & 0x100) sp->regs[SP_STATUS_REG] |= SP_STATUS_INTR_BREAK;

    /* clear / set signal 0 */
    if (w & 0x200) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_SIG0;
    if (w & 0x400) sp->regs[SP_STATUS_REG] |= SP_STATUS_SIG0;

    /* clear / set signal 1 */
    if (w & 0x800) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_SIG1;
    if (w & 0x1000) sp->regs[SP_STATUS_REG] |= SP_STATUS_SIG1;

    /* clear / set signal 2 */
    if (w & 0x2000) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_SIG2;
    if (w & 0x4000) sp->regs[SP_STATUS_REG] |= SP_STATUS_SIG2;

    /* clear / set signal 3 */
    if (w & 0x8000) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_SIG3;
    if (w & 0x10000) sp->regs[SP_STATUS_REG] |= SP_STATUS_SIG3;

    /* clear / set signal 4 */
    if (w & 0x20000) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_SIG4;
    if (w & 0x40000) sp->regs[SP_STATUS_REG] |= SP_STATUS_SIG4;

    /* clear / set signal 5 */
    if (w & 0x80000) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_SIG5;
    if (w & 0x100000) sp->regs[SP_STATUS_REG] |= SP_STATUS_SIG5;

    /* clear / set signal 6 */
    if (w & 0x200000) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_SIG6;
    if (w & 0x400000) sp->regs[SP_STATUS_REG] |= SP_STATUS_SIG6;

    /* clear / set signal 7 */
    if (w & 0x800000) sp->regs[SP_STATUS_REG] &= ~SP_STATUS_SIG7;
    if (w & 0x1000000) sp->regs[SP_STATUS_REG] |= SP_STATUS_SIG7;

    if (sp->rsp_task_locked && (get_event(&sp->mi->r4300->cp0.q, SP_INT))) return;
    if (!(w & 0x1) && !(w & 0x4) && !sp->rsp_task_locked)
        return;

    if (!(sp->regs[SP_STATUS_REG] & (SP_STATUS_HALT | SP_STATUS_BROKE)))
        do_SP_Task(sp);
}

void init_rsp(struct rsp_core* sp,
              uint32_t* sp_mem,
              struct mi_controller* mi,
              struct rdp_core* dp,
              struct ri_controller* ri)
{
    sp->mem = sp_mem;
    sp->mi = mi;
    sp->dp = dp;
    sp->ri = ri;
}

void poweron_rsp(struct rsp_core* sp)
{
    memset(sp->mem, 0, SP_MEM_SIZE);
    memset(sp->regs, 0, SP_REGS_COUNT*sizeof(uint32_t));
    memset(sp->regs2, 0, SP_REGS2_COUNT*sizeof(uint32_t));

    sp->rsp_task_locked = 0;
    sp->mi->r4300->cp0.interrupt_unsafe_state &= ~INTR_UNSAFE_RSP;
    sp->regs[SP_STATUS_REG] = 1;
}


void read_rsp_mem(void* opaque, uint32_t address, uint32_t* value)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t addr = rsp_mem_address(address);

    *value = sp->mem[addr];
}

void write_rsp_mem(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t addr = rsp_mem_address(address);

    masked_write(&sp->mem[addr], value, mask);
}


void read_rsp_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t reg = rsp_reg(address);

    *value = sp->regs[reg];

    if (reg == SP_SEMAPHORE_REG)
    {
        sp->regs[SP_SEMAPHORE_REG] = 1;
    }
}

void write_rsp_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t reg = rsp_reg(address);

    switch(reg)
    {
    case SP_STATUS_REG:
        update_sp_status(sp, value & mask);
    case SP_DMA_FULL_REG:
    case SP_DMA_BUSY_REG:
        return;
    }

    masked_write(&sp->regs[reg], value, mask);

    switch(reg)
    {
    case SP_RD_LEN_REG:
        dma_sp_write(sp);
        break;
    case SP_WR_LEN_REG:
        dma_sp_read(sp);
        break;
    case SP_SEMAPHORE_REG:
        sp->regs[SP_SEMAPHORE_REG] = 0;
        break;
    }
}


void read_rsp_regs2(void* opaque, uint32_t address, uint32_t* value)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t reg = rsp_reg2(address);

    *value = sp->regs2[reg];
}

void write_rsp_regs2(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t reg = rsp_reg2(address);

    masked_write(&sp->regs2[reg], value, mask);
}

void do_SP_Task(struct rsp_core* sp)
{
    uint32_t save_pc = sp->regs2[SP_PC_REG] & ~0xfff;

    uint32_t sp_delay_time;

    if (sp->mem[0xfc0/4] == 1)
    {
        unprotect_framebuffers(&sp->dp->fb);

        //gfx.processDList();
        sp->regs2[SP_PC_REG] &= 0xfff;
#if defined(PROFILE)
        timed_section_start(TIMED_SECTION_GFX);
#endif
        rsp.doRspCycles(0xffffffff);
#if defined(PROFILE)
        timed_section_end(TIMED_SECTION_GFX);
#endif
        sp->regs2[SP_PC_REG] |= save_pc;
        new_frame();

        if (sp->mi->regs[MI_INTR_REG] & MI_INTR_DP)
        {
            sp->mi->regs[MI_INTR_REG] &= ~MI_INTR_DP;
            if (sp->dp->dpc_regs[DPC_STATUS_REG] & DPC_STATUS_FREEZE) {
                sp->dp->do_on_unfreeze |= DELAY_DP_INT;
            } else {
                cp0_update_count(sp->mi->r4300);
                add_interrupt_event(&sp->mi->r4300->cp0, DP_INT, 4000);
            }
        }
        sp_delay_time = 1000;

        protect_framebuffers(&sp->dp->fb);
    }
    else if (sp->mem[0xfc0/4] == 2)
    {
        //audio.processAList();
        sp->regs2[SP_PC_REG] &= 0xfff;
#if defined(PROFILE)
        timed_section_start(TIMED_SECTION_AUDIO);
#endif
        rsp.doRspCycles(0xffffffff);
#if defined(PROFILE)
        timed_section_end(TIMED_SECTION_AUDIO);
#endif
        sp->regs2[SP_PC_REG] |= save_pc;

        sp_delay_time = 4000;
    }
    else
    {
        sp->regs2[SP_PC_REG] &= 0xfff;
        rsp.doRspCycles(0xffffffff);
        sp->regs2[SP_PC_REG] |= save_pc;

        sp_delay_time = 0;
    }

    sp->rsp_task_locked = 0;
    sp->mi->r4300->cp0.interrupt_unsafe_state &= ~INTR_UNSAFE_RSP;
    if ((sp->regs[SP_STATUS_REG] & (SP_STATUS_HALT | SP_STATUS_BROKE)) == 0)
    {
        sp->rsp_task_locked = 1;
        sp->mi->r4300->cp0.interrupt_unsafe_state |= INTR_UNSAFE_RSP;
        sp->mi->regs[MI_INTR_REG] |= MI_INTR_SP;
    }
    if (sp->mi->regs[MI_INTR_REG] & MI_INTR_SP)
    {
        cp0_update_count(sp->mi->r4300);
        add_interrupt_event(&sp->mi->r4300->cp0, SP_INT, sp_delay_time);
        sp->mi->regs[MI_INTR_REG] &= ~MI_INTR_SP;
    }

    sp->regs[SP_STATUS_REG] &=
        ~(SP_STATUS_TASKDONE | SP_STATUS_BROKE | SP_STATUS_HALT);
}

void rsp_interrupt_event(void* opaque)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;

    if (!sp->rsp_task_locked)
    {
        sp->regs[SP_STATUS_REG] |=
            SP_STATUS_TASKDONE | SP_STATUS_BROKE | SP_STATUS_HALT;
    }

    if ((sp->regs[SP_STATUS_REG] & SP_STATUS_INTR_BREAK) != 0)
    {
        raise_rcp_interrupt(sp->mi, MI_INTR_SP);
    }
}
