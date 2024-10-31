/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cp1.c                                                   *
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

#include <stdint.h>
#include <string.h>

#include "cp0.h"
#include "cp1.h"

#include "new_dynarec/new_dynarec.h" /* for NEW_DYNAREC_ARM */

void init_cp1(struct cp1* cp1, struct new_dynarec_hot_state* new_dynarec_hot_state)
{
#if NEW_DYNAREC == NEW_DYNAREC_ARM
    cp1->new_dynarec_hot_state = new_dynarec_hot_state;
#endif
}

void poweron_cp1(struct cp1* cp1)
{
    memset(cp1->regs, 0, 32 * sizeof(cp1->regs[0]));
    *r4300_cp1_fcr0(cp1) = UINT32_C(0x511);
    *r4300_cp1_fcr31(cp1) = 0;

    set_fpr_pointers(cp1, UINT32_C(0x34000000)); /* c0_status value at poweron */
    update_x86_rounding_mode(cp1);
}


cp1_reg* r4300_cp1_regs(struct cp1* cp1)
{
    return cp1->regs;
}

float** r4300_cp1_regs_simple(struct cp1* cp1)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    return cp1->regs_simple;
#else
    return cp1->new_dynarec_hot_state->cp1_regs_simple;
#endif
}

double** r4300_cp1_regs_double(struct cp1* cp1)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    return cp1->regs_double;
#else
    return cp1->new_dynarec_hot_state->cp1_regs_double;
#endif
}

uint32_t* r4300_cp1_fcr0(struct cp1* cp1)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    return &cp1->fcr0;
#else
    return &cp1->new_dynarec_hot_state->fcr0;
#endif
}

uint32_t* r4300_cp1_fcr31(struct cp1* cp1)
{
#if NEW_DYNAREC != NEW_DYNAREC_ARM
/* ARM dynarec uses a different memory layout */
    return &cp1->fcr31;
#else
    return &cp1->new_dynarec_hot_state->fcr31;
#endif
}

void set_fpr_pointers(struct cp1* cp1, uint32_t newStatus)
{
    int i;

    // update the FPR register pointers
    if ((newStatus & CP0_STATUS_FR) == 0)
    {
        for (i = 0; i < 32; i++)
        {
            (r4300_cp1_regs_simple(cp1))[i] = &cp1->regs[i & ~1].float32[i & 1];
            (r4300_cp1_regs_double(cp1))[i] = &cp1->regs[i & ~1].float64;
        }
    }
    else
    {
        for (i = 0; i < 32; i++)
        {
            (r4300_cp1_regs_simple(cp1))[i] = &cp1->regs[i].float32[0];
            (r4300_cp1_regs_double(cp1))[i] = &cp1->regs[i].float64;
        }
    }
}

/* XXX: This shouldn't really be here, but rounding_mode is used by the
 * Hacktarux JIT and updated by CTC1 and saved states. Figure out a better
 * place for this. */
void update_x86_rounding_mode(struct cp1* cp1)
{
    uint32_t fcr31 = *r4300_cp1_fcr31(cp1);

    switch (fcr31 & 3)
    {
    case 0: /* Round to nearest, or to even if equidistant */
        cp1->rounding_mode = UINT32_C(0x33F);
        break;
    case 1: /* Truncate (toward 0) */
        cp1->rounding_mode = UINT32_C(0xF3F);
        break;
    case 2: /* Round up (toward +Inf) */
        cp1->rounding_mode = UINT32_C(0xB3F);
        break;
    case 3: /* Round down (toward -Inf) */
        cp1->rounding_mode = UINT32_C(0x73F);
        break;
    }
}
