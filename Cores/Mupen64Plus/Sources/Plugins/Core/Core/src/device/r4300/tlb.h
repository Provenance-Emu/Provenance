/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - tlb.h                                                   *
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

#ifndef M64P_DEVICE_R4300_TLB_H
#define M64P_DEVICE_R4300_TLB_H

#include <stddef.h>
#include <stdint.h>

struct r4300_core;

struct tlb_entry
{
   short mask;
   unsigned int vpn2;
   char g;
   unsigned char asid;
   unsigned int pfn_even;
   char c_even;
   char d_even;
   char v_even;
   unsigned int pfn_odd;
   char c_odd;
   char d_odd;
   char v_odd;
   char r;
   //int check_parity_mask;

   unsigned int start_even;
   unsigned int end_even;
   unsigned int phys_even;
   unsigned int start_odd;
   unsigned int end_odd;
   unsigned int phys_odd;
};

struct tlb
{
    struct tlb_entry entries[32];
    uint32_t LUT_r[0x100000];
    uint32_t LUT_w[0x100000];
};

void poweron_tlb(struct tlb* tlb);

void tlb_unmap(struct tlb* tlb, size_t entry);
void tlb_map(struct tlb* tlb, size_t entry);

uint32_t virtual_to_physical_address(struct r4300_core* r4300, uint32_t address, int w);

#endif /* M64P_DEVICE_R4300_TLB_H */
