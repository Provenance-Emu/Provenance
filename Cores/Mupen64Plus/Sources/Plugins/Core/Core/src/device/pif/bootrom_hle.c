/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - bootrom_hle.c                                           *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2016 Bobby Smiles                                       *
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

#include "bootrom_hle.h"

#include <stdint.h>
#include <string.h>

#include "api/m64p_types.h"
#include "device/device.h"
#include "device/r4300/r4300_core.h"
#include "device/rcp/ai/ai_controller.h"
#include "device/rcp/pi/pi_controller.h"
#include "device/rcp/rsp/rsp_core.h"
#include "device/rcp/si/si_controller.h"
#include "device/rcp/vi/vi_controller.h"
#include "main/rom.h"

static unsigned int get_tv_type(void)
{
    switch(ROM_PARAMS.systemtype)
    {
    default:
    case SYSTEM_NTSC: return 1;
    case SYSTEM_PAL: return 0;
    case SYSTEM_MPAL: return 2;
    }
}

void pif_bootrom_hle_execute(struct r4300_core* r4300)
{
    uint32_t pif24;
    unsigned int seed;       /* seed (depends on CIC version) */
    unsigned int rom_type;   /* 0:Cart, 1:DD */
    unsigned int reset_type; /* 0:ColdReset, 1:NMI */
    unsigned int s7;         /* ??? */
    uint32_t bsd_dom1_config;
    unsigned int tv_type = get_tv_type();   /* 0:PAL, 1:NTSC, 2:MPAL */

    int64_t* r4300_gpregs = r4300_regs(r4300);
    uint32_t* cp0_regs = r4300_cp0_regs(&r4300->cp0);

    /* setup CP0 registers */
    cp0_regs[CP0_STATUS_REG] = 0x34000000;
    cp0_regs[CP0_CONFIG_REG] = 0x0006e463;

    /* XXX: wait for SP to finish last operation (poll halt) */

    /* stop RSP (halt + clear interrupts) */
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_RSP_REGS + 4*SP_STATUS_REG, 0x0a, ~UINT32_C(0));

    /* XXX: wait for SP DMA to finish (poll busy) */

    /* stop PI (reset, clear interrupt) */
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_PI_REGS + 4*PI_STATUS_REG, 0x3, ~UINT32_C(0));

    /* blank screen */
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_VI_REGS + 4*VI_V_INTR_REG, 1023, ~UINT32_C(0));
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_VI_REGS + 4*VI_CURRENT_REG,   0, ~UINT32_C(0));
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_VI_REGS + 4*VI_H_START_REG,   0, ~UINT32_C(0));

    /* mute sound */
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_AI_REGS + 4*AI_DRAM_ADDR_REG, 0, ~UINT32_C(0));
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_AI_REGS + 4*AI_LEN_REG,       0, ~UINT32_C(0));

    /* XXX: wait for SP DMA to finish (poll busy) */

    /* XXX: copy IPL2 to IMEM (partialy done later as required by CIC x105)
     * and transfer execution to IPL2 */

    /* XXX: wait for PIF_3c[7] to be cleared */

    /* read and parse pif24 */
    r4300_read_aligned_word(r4300, R4300_KSEG1 + MM_PIF_MEM + PIF_ROM_SIZE + 0x24, &pif24);
    rom_type   = (pif24 >> 19) & 0x01;
    s7         = (pif24 >> 18) & 0x01;
    reset_type = (pif24 >> 17) & 0x01;
    seed       = (pif24 >>  8) & 0xff;
    /* setup s3-s7 registers (needed by OS) */
    r4300_gpregs[19] = rom_type;    /* s3 */
    r4300_gpregs[20] = tv_type;     /* s4 */
    r4300_gpregs[21] = reset_type;  /* s5 */
    r4300_gpregs[22] = seed;        /* s6 */
    r4300_gpregs[23] = s7;          /* s7 */


    /* XXX: wait for SI_RD_BUSY to be cleared, set PIF_3c[4] */

    /* configure ROM access
     * XXX: we skip the first temporary configuration */
    uint32_t rom_base = (rom_type == 0) ? MM_CART_ROM : MM_DD_ROM;
    r4300_read_aligned_word(r4300, R4300_KSEG1 + rom_base, &bsd_dom1_config);
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_PI_REGS + 4*PI_BSD_DOM1_LAT_REG, (bsd_dom1_config      ) & 0xff, ~UINT32_C(0));
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_PI_REGS + 4*PI_BSD_DOM1_PWD_REG, (bsd_dom1_config >>  8) & 0xff, ~UINT32_C(0));
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_PI_REGS + 4*PI_BSD_DOM1_PGS_REG, (bsd_dom1_config >> 16) & 0x0f, ~UINT32_C(0));
    r4300_write_aligned_word(r4300, R4300_KSEG1 + MM_PI_REGS + 4*PI_BSD_DOM1_RLS_REG, (bsd_dom1_config >> 20) & 0x03, ~UINT32_C(0));

    /* XXX: if XBus is used, wait until DPC_pipe_busy is cleared */

    /* copy IPL3 to dmem */
    memcpy((unsigned char*)mem_base_u32(r4300->mem->base, MM_RSP_MEM + 0x40),
           (unsigned char*)mem_base_u32(r4300->mem->base, rom_base + 0x40),
           0xfc0);

    /* XXX: compute IPL3 checksum */
    /* XXX: wait for SI_RD_BUSY to be cleared, set PIF_30 */
    /* XXX: wait for SI_RD_BUSY to be cleared, set PIF_34 */
    /* XXX: wait for SI_RD_BUSY to be cleared, set PIF_3c[5] */
    /* XXX: wait for PIF_3c[7] to be set */
    /* XXX: wait for SI_RD_BUSY to be cleared, set PIF_3c[6] */

    /* required by CIC x105 */
    uint32_t* imem = mem_base_u32(r4300->mem->base, MM_RSP_MEM + 0x1000);
    imem[0x0000/4] = 0x3c0dbfc0;
    imem[0x0004/4] = 0x8da807fc;
    imem[0x0008/4] = 0x25ad07c0;
    imem[0x000c/4] = 0x31080080;
    imem[0x0010/4] = 0x5500fffc;
    imem[0x0014/4] = 0x3c0dbfc0;
    imem[0x0018/4] = 0x8da80024;
    imem[0x001c/4] = 0x3c0bb000;

    /* required by CIC x105 */
    r4300_gpregs[11] = INT64_C(0xffffffffa4000040); /* t3 */
    r4300_gpregs[29] = INT64_C(0xffffffffa4001ff0); /* sp */
    r4300_gpregs[31] = INT64_C(0xffffffffa4001550); /* ra */

    /* XXX: should prepare execution of IPL3 in DMEM here :
     * e.g. jump to 0xa4000040 */
    *r4300_cp0_last_addr(&r4300->cp0) = 0xa4000040;
}
