/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - tlb.c                                                   *
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

#include "tlb.h"

#include "api/m64p_types.h"
#include "device/r4300/r4300_core.h"
#include "device/rdram/rdram.h"

#include <assert.h>
#include <string.h>

void poweron_tlb(struct tlb* tlb)
{
    /* clear TLB entries */
    memset(tlb->entries, 0, 32 * sizeof(tlb->entries[0]));
    memset(tlb->LUT_r, 0, 0x100000 * sizeof(tlb->LUT_r[0]));
    memset(tlb->LUT_w, 0, 0x100000 * sizeof(tlb->LUT_w[0]));
}

void tlb_unmap(struct tlb* tlb, size_t entry)
{
    unsigned int i;
    const struct tlb_entry* e;

    assert(entry < 32);
    e = &tlb->entries[entry];

    if (e->v_even)
    {
        for (i=e->start_even; i<e->end_even; i += 0x1000)
            tlb->LUT_r[i>>12] = 0;
        if (e->d_even)
            for (i=e->start_even; i<e->end_even; i += 0x1000)
                tlb->LUT_w[i>>12] = 0;
    }

    if (e->v_odd)
    {
        for (i=e->start_odd; i<e->end_odd; i += 0x1000)
            tlb->LUT_r[i>>12] = 0;
        if (e->d_odd)
            for (i=e->start_odd; i<e->end_odd; i += 0x1000)
                tlb->LUT_w[i>>12] = 0;
    }
}

void tlb_map(struct tlb* tlb, size_t entry)
{
    unsigned int i;
    const struct tlb_entry* e;

    assert(entry < 32);
    e = &tlb->entries[entry];

    if (e->v_even)
    {
        if (e->start_even < e->end_even &&
            !(e->start_even >= 0x80000000 && e->end_even < 0xC0000000) &&
            e->phys_even < 0x20000000)
        {
            for (i=e->start_even;i<e->end_even;i+=0x1000)
                tlb->LUT_r[i>>12] = UINT32_C(0x80000000) | (e->phys_even + (i - e->start_even) + 0xFFF);
            if (e->d_even)
                for (i=e->start_even;i<e->end_even;i+=0x1000)
                    tlb->LUT_w[i>>12] = UINT32_C(0x80000000) | (e->phys_even + (i - e->start_even) + 0xFFF);
        }
    }

    if (e->v_odd)
    {
        if (e->start_odd < e->end_odd &&
            !(e->start_odd >= 0x80000000 && e->end_odd < 0xC0000000) &&
            e->phys_odd < 0x20000000)
        {
            for (i=e->start_odd;i<e->end_odd;i+=0x1000)
                tlb->LUT_r[i>>12] = UINT32_C(0x80000000) | (e->phys_odd + (i - e->start_odd) + 0xFFF);
            if (e->d_odd)
                for (i=e->start_odd;i<e->end_odd;i+=0x1000)
                    tlb->LUT_w[i>>12] = UINT32_C(0x80000000) | (e->phys_odd + (i - e->start_odd) + 0xFFF);
        }
    }
}

uint32_t virtual_to_physical_address(struct r4300_core* r4300, uint32_t address, int w)
{
    const struct tlb* tlb = &r4300->cp0.tlb;
    unsigned int addr = address >> 12;

#ifdef NEW_DYNAREC
    if (r4300->emumode == EMUMODE_DYNAREC)
    {
        int map = r4300->new_dynarec_hot_state.memory_map[addr];
        if ((tlb->LUT_w[addr]) && (w == 1))
        {
            assert(map == (((tlb->LUT_w[addr] & 0xFFFFF000) - (address & 0xFFFFF000) + (unsigned int)r4300->rdram->dram - 0x80000000) >> 2));
        }
        else if ((tlb->LUT_r[addr]) && (w == 0))
        {
            assert((map&~0x40000000) == (((tlb->LUT_r[addr] & 0xFFFFF000) - (address & 0xFFFFF000) + (unsigned int)r4300->rdram->dram - 0x80000000) >> 2));
            if (map & 0x40000000)
            {
                assert(tlb->LUT_w[addr] == 0);
            }
        }
        else {
            assert(map < 0);
        }
    }
#endif

    if (w == 1)
    {
        if (tlb->LUT_w[addr])
            return (tlb->LUT_w[addr] & UINT32_C(0xFFFFF000)) | (address & UINT32_C(0xFFF));
    }
    else
    {
        if (tlb->LUT_r[addr])
            return (tlb->LUT_r[addr] & UINT32_C(0xFFFFF000)) | (address & UINT32_C(0xFFF));
    }
    //printf("tlb exception !!! @ %x, %x, add:%x\n", address, w, r4300->pc->addr);
    //getchar();

    TLB_refill_exception(r4300, address, w);

    //return 0x80000000;
    return 0x00000000;
}
