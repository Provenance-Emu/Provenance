/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - m64282fp.c                                              *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2017 Bobby Smiles                                       *
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

/* Most of the mappers information comes from
 * "Game Boy Camera Technical Information v1.1.1" by AntonioND
 */

#include "m64282fp.h"

#include "api/m64p_types.h"
#include "api/callbacks.h"
#include <string.h>


void init_m64282fp(struct m64282fp* cam)
{
}

void poweron_m64282fp(struct m64282fp* cam)
{
    memset(cam->regs, 0, M64282FP_REGS_COUNT*sizeof(cam->regs[0]));
}

uint8_t read_m64282fp_regs(struct m64282fp* cam, unsigned int reg)
{
    /* All registers except reg 0 are write only and therefore return 0x00 */
    return (reg == 0)
        ? cam->regs[0]
        : 0x00;
}

void write_m64282fp_regs(struct m64282fp* cam, unsigned int reg, uint8_t value)
{
    if (reg >= M64282FP_REGS_COUNT) {
        DebugMessage(M64MSG_WARNING, "Out of range camera register write %02x = %02x",
            reg, value);
        return;
    }

    cam->regs[reg] = value;

    if (reg == 0) {
        cam->regs[reg] &= 0x7;

        if (cam->regs[reg] & 0x1) {
            /* TODO */
            DebugMessage(M64MSG_INFO, "Starting m64282fp frame capture");

            /* End of capture */
            cam->regs[reg] &= ~0x01;
        }
    }
}
