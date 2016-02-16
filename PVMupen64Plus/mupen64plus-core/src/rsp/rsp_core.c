/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rsp_core.c                                              *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
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

#include "main/main.h"
#include "main/profile.h"
#include "memory/memory.h"
#include "plugin/plugin.h"
#include "r4300/r4300_core.h"
#include "rdp/rdp_core.h"
#include "ri/ri_controller.h"

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
    unsigned char *dram = (unsigned char*)sp->ri->rdram.dram;

    for(j=0; j<count; j++) {
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
    unsigned char *dram = (unsigned char*)sp->ri->rdram.dram;

    for(j=0; j<count; j++) {
        for(i=0; i<length; i++) {
            dram[dramaddr^S8] = spmem[memaddr^S8];
            memaddr++;
            dramaddr++;
        }
        dramaddr+=skip;
    }
}

static void update_sp_status(struct rsp_core* sp, uint32_t w)
{
    /* clear / set halt */
    if (w & 0x1) sp->regs[SP_STATUS_REG] &= ~0x1;
    if (w & 0x2) sp->regs[SP_STATUS_REG] |= 0x1;

    /* clear broke */
    if (w & 0x4) sp->regs[SP_STATUS_REG] &= ~0x2;

    /* clear SP interrupt */
    if (w & 0x8)
    {
        clear_rcp_interrupt(sp->r4300, MI_INTR_SP);
    }
    /* set SP interrupt */
    if (w & 0x10)
    {
        signal_rcp_interrupt(sp->r4300, MI_INTR_SP);
    }

    /* clear / set single step */
    if (w & 0x20) sp->regs[SP_STATUS_REG] &= ~0x20;
    if (w & 0x40) sp->regs[SP_STATUS_REG] |= 0x20;

    /* clear / set interrupt on break */
    if (w & 0x80) sp->regs[SP_STATUS_REG] &= ~0x40;
    if (w & 0x100) sp->regs[SP_STATUS_REG] |= 0x40;

    /* clear / set signal 0 */
    if (w & 0x200) sp->regs[SP_STATUS_REG] &= ~0x80;
    if (w & 0x400) sp->regs[SP_STATUS_REG] |= 0x80;

    /* clear / set signal 1 */
    if (w & 0x800) sp->regs[SP_STATUS_REG] &= ~0x100;
    if (w & 0x1000) sp->regs[SP_STATUS_REG] |= 0x100;

    /* clear / set signal 2 */
    if (w & 0x2000) sp->regs[SP_STATUS_REG] &= ~0x200;
    if (w & 0x4000) sp->regs[SP_STATUS_REG] |= 0x200;

    /* clear / set signal 3 */
    if (w & 0x8000) sp->regs[SP_STATUS_REG] &= ~0x400;
    if (w & 0x10000) sp->regs[SP_STATUS_REG] |= 0x400;

    /* clear / set signal 4 */
    if (w & 0x20000) sp->regs[SP_STATUS_REG] &= ~0x800;
    if (w & 0x40000) sp->regs[SP_STATUS_REG] |= 0x800;

    /* clear / set signal 5 */
    if (w & 0x80000) sp->regs[SP_STATUS_REG] &= ~0x1000;
    if (w & 0x100000) sp->regs[SP_STATUS_REG] |= 0x1000;

    /* clear / set signal 6 */
    if (w & 0x200000) sp->regs[SP_STATUS_REG] &= ~0x2000;
    if (w & 0x400000) sp->regs[SP_STATUS_REG] |= 0x2000;

    /* clear / set signal 7 */
    if (w & 0x800000) sp->regs[SP_STATUS_REG] &= ~0x4000;
    if (w & 0x1000000) sp->regs[SP_STATUS_REG] |= 0x4000;

    //if (get_event(SP_INT)) return;
    if (!(w & 0x1) && !(w & 0x4))
        return;

    if (!(sp->regs[SP_STATUS_REG] & 0x3)) // !halt && !broke
        do_SP_Task(sp);
}

void connect_rsp(struct rsp_core* sp,
                 struct r4300_core* r4300,
                 struct rdp_core* dp,
                 struct ri_controller* ri)
{
    sp->r4300 = r4300;
    sp->dp = dp;
    sp->ri = ri;
}

void init_rsp(struct rsp_core* sp)
{
    memset(sp->mem, 0, SP_MEM_SIZE);
    memset(sp->regs, 0, SP_REGS_COUNT*sizeof(uint32_t));
    memset(sp->regs2, 0, SP_REGS2_COUNT*sizeof(uint32_t));

    sp->regs[SP_STATUS_REG] = 1;
}


int read_rsp_mem(void* opaque, uint32_t address, uint32_t* value)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t addr = rsp_mem_address(address);

    *value = sp->mem[addr];

    return 0;
}

int write_rsp_mem(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t addr = rsp_mem_address(address);

    masked_write(&sp->mem[addr], value, mask);

    return 0;
}


int read_rsp_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t reg = rsp_reg(address);

    *value = sp->regs[reg];

    if (reg == SP_SEMAPHORE_REG)
    {
        sp->regs[SP_SEMAPHORE_REG] = 1;
    }

    return 0;
}

int write_rsp_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t reg = rsp_reg(address);

    switch(reg)
    {
    case SP_STATUS_REG:
        update_sp_status(sp, value & mask);
    case SP_DMA_FULL_REG:
    case SP_DMA_BUSY_REG:
        return 0;
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

    return 0;
}


int read_rsp_regs2(void* opaque, uint32_t address, uint32_t* value)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t reg = rsp_reg2(address);

    *value = sp->regs2[reg];

    return 0;
}

int write_rsp_regs2(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rsp_core* sp = (struct rsp_core*)opaque;
    uint32_t reg = rsp_reg2(address);

    masked_write(&sp->regs2[reg], value, mask);

    return 0;
}

void do_SP_Task(struct rsp_core* sp)
{
    uint32_t save_pc = sp->regs2[SP_PC_REG] & ~0xfff;

    if (sp->mem[0xfc0/4] == 1)
    {
        if (sp->dp->dpc_regs[DPC_STATUS_REG] & 0x2) // DP frozen (DK64, BC)
        {
            // don't do the task now
            // the task will be done when DP is unfreezed (see update_dpc_status)
            return;
        }

        unprotect_framebuffers(sp->dp);

        //gfx.processDList();
        sp->regs2[SP_PC_REG] &= 0xfff;
        timed_section_start(TIMED_SECTION_GFX);
        rsp.doRspCycles(0xffffffff);
        timed_section_end(TIMED_SECTION_GFX);
        sp->regs2[SP_PC_REG] |= save_pc;
        new_frame();

        update_count();
        if (sp->r4300->mi.regs[MI_INTR_REG] & MI_INTR_SP)
            add_interupt_event(SP_INT, 1000);
        if (sp->r4300->mi.regs[MI_INTR_REG] & MI_INTR_DP)
            add_interupt_event(DP_INT, 1000);
        sp->r4300->mi.regs[MI_INTR_REG] &= ~(MI_INTR_SP | MI_INTR_DP);
        sp->regs[SP_STATUS_REG] &= ~0x303;

        protect_framebuffers(sp->dp);
    }
    else if (sp->mem[0xfc0/4] == 2)
    {
        //audio.processAList();
        sp->regs2[SP_PC_REG] &= 0xfff;
        timed_section_start(TIMED_SECTION_AUDIO);
        rsp.doRspCycles(0xffffffff);
        timed_section_end(TIMED_SECTION_AUDIO);
        sp->regs2[SP_PC_REG] |= save_pc;

        update_count();
        if (sp->r4300->mi.regs[MI_INTR_REG] & MI_INTR_SP)
            add_interupt_event(SP_INT, 4000/*500*/);
        sp->r4300->mi.regs[MI_INTR_REG] &= ~MI_INTR_SP;
        sp->regs[SP_STATUS_REG] &= ~0x303;
        
    }
    else
    {
        sp->regs2[SP_PC_REG] &= 0xfff;
        rsp.doRspCycles(0xffffffff);
        sp->regs2[SP_PC_REG] |= save_pc;

        update_count();
        if (sp->r4300->mi.regs[MI_INTR_REG] & MI_INTR_SP)
            add_interupt_event(SP_INT, 0/*100*/);
        sp->r4300->mi.regs[MI_INTR_REG] &= ~MI_INTR_SP;
        sp->regs[SP_STATUS_REG] &= ~0x203;
    }
}

void rsp_interrupt_event(struct rsp_core* sp)
{
    sp->regs[SP_STATUS_REG] |= 0x203;

    if ((sp->regs[SP_STATUS_REG] & 0x40) != 0)
    {
        raise_rcp_interrupt(sp->r4300, MI_INTR_SP);
    }
}
