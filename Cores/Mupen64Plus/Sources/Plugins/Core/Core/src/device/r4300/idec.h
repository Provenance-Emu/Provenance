/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - idec.h                                                  *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2018 Bobby Smiles                                       *
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

#ifndef M64P_DEVICE_R4300_IDEC_H
#define M64P_DEVICE_R4300_IDEC_H

#include "osal/preproc.h"

#include <stddef.h>
#include <stdint.h>

#define X(op) R4300_OP_##op
enum r4300_opcode
{
    #include "opcodes.md"
    , R4300_OPCODES_COUNT
};
#undef X

enum r4300_register_type
{
    IDEC_REGTYPE_NONE,
    IDEC_REGTYPE_GPR,
    IDEC_REGTYPE_CPR0,  // cp0 regs
    IDEC_REGTYPE_FPR,   // cp1: depends on format field
    IDEC_REGTYPE_FPR32, // cp1: simple, word
    IDEC_REGTYPE_FPR64, // cp1: double, long
    IDEC_REGTYPE_FCR    // cp1: control reg
    /* carefull: needs to fit within 3bits in u53 */
};

#define U53(t,s)     (((s) << 3)|((t) & 0x7))
#define U53_SHIFT(u) (((u) >> 3) & 0x1f)
#define U53_TYPE(u)  ((enum r4300_register_type)((u) & 0x7))

/* instruction decode parameters */
struct r4300_idec
{
    enum r4300_opcode opcode;
    uint32_t i_mask;
    uint16_t i_smask;
    uint8_t i_lshift;
    /* d, t, s, non-reg (5 highest bit encode right shift, 3 lowest bits encode reg type) */
    uint8_t u53[4];
    /* FIXME?: pad up to 16-bytes for better perf */
};

static osal_inline int64_t sign_extend(uint32_t x, uint16_t m)
{
	/* assume that bits of x above the m are already zeros */
	return (int64_t)(x ^ m) - (int64_t)m;
}

static osal_inline int64_t idec_imm(uint32_t iw, const struct r4300_idec* idec)
{
    return sign_extend((iw & idec->i_mask), idec->i_smask) << idec->i_lshift;
}

/* Get instruction decoder */
const struct r4300_idec* r4300_get_idec(uint32_t iw);

/* decode register */
size_t idec_u53(uint32_t iw, uint8_t u53, uint8_t* u5);

#define IDEC_U53(r4300, iw, u53, u5) (void*)(((char*)(r4300)) + idec_u53((iw), (u53), (u5)))

const char* g_r4300_opcodes[R4300_OPCODES_COUNT];

#endif
