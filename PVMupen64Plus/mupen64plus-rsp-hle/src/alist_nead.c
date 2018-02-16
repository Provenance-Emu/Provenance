/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - alist_nead.c                                    *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2014 Bobby Smiles                                       *
 *   Copyright (C) 2009 Richard Goedeken                                   *
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

#include <stdbool.h>
#include <stdint.h>

#include "alist.h"
#include "common.h"
#include "hle_external.h"
#include "hle_internal.h"
#include "memory.h"
#include "ucodes.h"

/* remove windows define to 0x06 */
#ifdef DUPLICATE
#undef DUPLICATE
#endif

/* audio commands definition */
static void UNKNOWN(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint8_t acmd = (w1 >> 24);

    HleWarnMessage(hle->user_defined,
                   "Unknown audio command %d: %08x %08x",
                   acmd, w1, w2);
}


static void SPNOOP(struct hle_t* UNUSED(hle), uint32_t UNUSED(w1), uint32_t UNUSED(w2))
{
}

static void LOADADPCM(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint16_t count   = w1;
    uint32_t address = (w2 & 0xffffff);

    dram_load_u16(hle, (uint16_t*)hle->alist_nead.table, address, count >> 1);
}

static void SETLOOP(struct hle_t* hle, uint32_t UNUSED(w1), uint32_t w2)
{
    hle->alist_nead.loop = w2 & 0xffffff;
}

static void SETBUFF(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    hle->alist_nead.in    = w1;
    hle->alist_nead.out   = (w2 >> 16);
    hle->alist_nead.count = w2;
}

static void ADPCM(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint8_t  flags   = (w1 >> 16);
    uint32_t address = (w2 & 0xffffff);

    alist_adpcm(
            hle,
            flags & 0x1,
            flags & 0x2,
            flags & 0x4,
            hle->alist_nead.out,
            hle->alist_nead.in,
            (hle->alist_nead.count + 0x1f) & ~0x1f,
            hle->alist_nead.table,
            hle->alist_nead.loop,
            address);
}

static void CLEARBUFF(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint16_t dmem  = w1;
    uint16_t count = w2 & 0xfff;

    if (count == 0)
        return;

    alist_clear(hle, dmem, count);
}

static void LOADBUFF(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint16_t count   = (w1 >> 12) & 0xfff;
    uint16_t dmem    = (w1 & 0xfff);
    uint32_t address = (w2 & 0xffffff);

    alist_load(hle, dmem, address, count);
}

static void SAVEBUFF(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint16_t count   = (w1 >> 12) & 0xfff;
    uint16_t dmem    = (w1 & 0xfff);
    uint32_t address = (w2 & 0xffffff);

    alist_save(hle, dmem, address, count);
}

static void MIXER(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint16_t count = (w1 >> 12) & 0xff0;
    int16_t  gain  = w1;
    uint16_t dmemi = (w2 >> 16);
    uint16_t dmemo = w2;

    alist_mix(hle, dmemo, dmemi, count, gain);
}


static void RESAMPLE(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint8_t  flags   = (w1 >> 16);
    uint16_t pitch   = w1;
    uint32_t address = (w2 & 0xffffff);

    alist_resample(
            hle,
            flags & 0x1,
            false,          /* TODO: check which ABI supports it */
            hle->alist_nead.out,
            hle->alist_nead.in,
            (hle->alist_nead.count + 0xf) & ~0xf,
            pitch << 1,
            address);
}

static void RESAMPLE_ZOH(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint16_t pitch      = w1;
    uint16_t pitch_accu = w2;

    alist_resample_zoh(
            hle,
            hle->alist_nead.out,
            hle->alist_nead.in,
            hle->alist_nead.count,
            pitch << 1,
            pitch_accu);
}

static void DMEMMOVE(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint16_t dmemi = w1;
    uint16_t dmemo = (w2 >> 16);
    uint16_t count = w2;

    if (count == 0)
        return;

    alist_move(hle, dmemo, dmemi, (count + 3) & ~3);
}

static void ENVSETUP1_MK(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    hle->alist_nead.env_values[2] = (w1 >> 8) & 0xff00;
    hle->alist_nead.env_steps[2]  = 0;
    hle->alist_nead.env_steps[0]  = (w2 >> 16);
    hle->alist_nead.env_steps[1]  = w2;
}

static void ENVSETUP1(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    hle->alist_nead.env_values[2] = (w1 >> 8) & 0xff00;
    hle->alist_nead.env_steps[2]  = w1;
    hle->alist_nead.env_steps[0]  = (w2 >> 16);
    hle->alist_nead.env_steps[1]  = w2;
}

static void ENVSETUP2(struct hle_t* hle, uint32_t UNUSED(w1), uint32_t w2)
{
    hle->alist_nead.env_values[0] = (w2 >> 16);
    hle->alist_nead.env_values[1] = w2;
}

static void ENVMIXER_MK(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    int16_t xors[4];

    uint16_t dmemi = (w1 >> 12) & 0xff0;
    uint8_t  count = (w1 >>  8) & 0xff;
    uint16_t dmem_dl = (w2 >> 20) & 0xff0;
    uint16_t dmem_dr = (w2 >> 12) & 0xff0;
    uint16_t dmem_wl = (w2 >>  4) & 0xff0;
    uint16_t dmem_wr = (w2 <<  4) & 0xff0;

    xors[2] = 0;    /* unsupported by this ucode */
    xors[3] = 0;    /* unsupported by this ucode */
    xors[0] = 0 - (int16_t)((w1 & 0x2) >> 1);
    xors[1] = 0 - (int16_t)((w1 & 0x1)     );

    alist_envmix_nead(
            hle,
            false,  /* unsupported by this ucode */
            dmem_dl, dmem_dr,
            dmem_wl, dmem_wr,
            dmemi, count,
            hle->alist_nead.env_values,
            hle->alist_nead.env_steps,
            xors);
}

static void ENVMIXER(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    int16_t xors[4];

    uint16_t dmemi = (w1 >> 12) & 0xff0;
    uint8_t  count = (w1 >>  8) & 0xff;
    bool     swap_wet_LR = (w1 >> 4) & 0x1;
    uint16_t dmem_dl = (w2 >> 20) & 0xff0;
    uint16_t dmem_dr = (w2 >> 12) & 0xff0;
    uint16_t dmem_wl = (w2 >>  4) & 0xff0;
    uint16_t dmem_wr = (w2 <<  4) & 0xff0;

    xors[2] = 0 - (int16_t)((w1 & 0x8) >> 1);
    xors[3] = 0 - (int16_t)((w1 & 0x4) >> 1);
    xors[0] = 0 - (int16_t)((w1 & 0x2) >> 1);
    xors[1] = 0 - (int16_t)((w1 & 0x1)     );

    alist_envmix_nead(
            hle,
            swap_wet_LR,
            dmem_dl, dmem_dr,
            dmem_wl, dmem_wr,
            dmemi, count,
            hle->alist_nead.env_values,
            hle->alist_nead.env_steps,
            xors);
}

static void DUPLICATE(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint8_t  count = (w1 >> 16);
    uint16_t dmemi = w1;
    uint16_t dmemo = (w2 >> 16);

    alist_repeat64(hle, dmemo, dmemi, count);
}

static void INTERL(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint16_t count = w1;
    uint16_t dmemi = (w2 >> 16);
    uint16_t dmemo = w2;

    alist_copy_every_other_sample(hle, dmemo, dmemi, count);
}

static void INTERLEAVE_MK(struct hle_t* hle, uint32_t UNUSED(w1), uint32_t w2)
{
    uint16_t left = (w2 >> 16);
    uint16_t right = w2;

    if (hle->alist_nead.count == 0)
        return;

    alist_interleave(hle, hle->alist_nead.out, left, right, hle->alist_nead.count);
}

static void INTERLEAVE(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint16_t count = ((w1 >> 12) & 0xff0);
    uint16_t dmemo = w1;
    uint16_t left = (w2 >> 16);
    uint16_t right = w2;

    alist_interleave(hle, dmemo, left, right, count);
}

static void ADDMIXER(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint16_t count = (w1 >> 12) & 0xff0;
    uint16_t dmemi = (w2 >> 16);
    uint16_t dmemo = w2;

    alist_add(hle, dmemo, dmemi, count);
}

static void HILOGAIN(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    int8_t   gain  = (w1 >> 16); /* Q4.4 signed */
    uint16_t count = w1 & 0xfff;
    uint16_t dmem  = (w2 >> 16);

    alist_multQ44(hle, dmem, count, gain);
}

static void FILTER(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint8_t  flags   = (w1 >> 16);
    uint32_t address = (w2 & 0xffffff);

    if (flags > 1) {
        hle->alist_nead.filter_count          = w1;
        hle->alist_nead.filter_lut_address[0] = address; /* t6 */
    }
    else {
        uint16_t dmem = w1;

        hle->alist_nead.filter_lut_address[1] = address + 0x10; /* t5 */
        alist_filter(hle, dmem, hle->alist_nead.filter_count, address, hle->alist_nead.filter_lut_address);
    }
}

static void SEGMENT(struct hle_t* UNUSED(hle), uint32_t UNUSED(w1), uint32_t UNUSED(w2))
{
}

static void NEAD_16(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint8_t  count      = (w1 >> 16);
    uint16_t dmemi      = w1;
    uint16_t dmemo      = (w2 >> 16);
    uint16_t block_size = w2;

    alist_copy_blocks(hle, dmemo, dmemi, block_size, count);
}

static void POLEF(struct hle_t* hle, uint32_t w1, uint32_t w2)
{
    uint8_t  flags   = (w1 >> 16);
    uint16_t gain    = w1;
    uint32_t address = (w2 & 0xffffff);

    if (hle->alist_nead.count == 0)
        return;

    alist_polef(
            hle,
            flags & A_INIT,
            hle->alist_nead.out,
            hle->alist_nead.in,
            hle->alist_nead.count,
            gain,
            hle->alist_nead.table,
            address);
}


void alist_process_nead_mk(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x20] = {
        SPNOOP,         ADPCM,          CLEARBUFF,      SPNOOP,
        SPNOOP,         RESAMPLE,       SPNOOP,         SEGMENT,
        SETBUFF,        SPNOOP,         DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE_MK,  POLEF,          SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1_MK,   ENVMIXER_MK,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      SPNOOP,
        SPNOOP,         SPNOOP,         SPNOOP,         SPNOOP,
        SPNOOP,         SPNOOP,         SPNOOP,         SPNOOP
    };

    alist_process(hle, ABI, 0x20);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_sf(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x20] = {
        SPNOOP,         ADPCM,          CLEARBUFF,      SPNOOP,
        ADDMIXER,       RESAMPLE,       RESAMPLE_ZOH,   SPNOOP,
        SETBUFF,        SPNOOP,         DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE_MK,  POLEF,          SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1,      ENVMIXER,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      SPNOOP,
        HILOGAIN,       UNKNOWN,        DUPLICATE,      SPNOOP,
        SPNOOP,         SPNOOP,         SPNOOP,         SPNOOP
    };

    alist_process(hle, ABI, 0x20);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_sfj(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x20] = {
        SPNOOP,         ADPCM,          CLEARBUFF,      SPNOOP,
        ADDMIXER,       RESAMPLE,       RESAMPLE_ZOH,   SPNOOP,
        SETBUFF,        SPNOOP,         DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE_MK,  POLEF,          SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1,      ENVMIXER,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      UNKNOWN,
        HILOGAIN,       UNKNOWN,        DUPLICATE,      SPNOOP,
        SPNOOP,         SPNOOP,         SPNOOP,         SPNOOP
    };

    alist_process(hle, ABI, 0x20);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_fz(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x20] = {
        UNKNOWN,        ADPCM,          CLEARBUFF,      SPNOOP,
        ADDMIXER,       RESAMPLE,       SPNOOP,         SPNOOP,
        SETBUFF,        SPNOOP,         DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE,     SPNOOP,         SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1,      ENVMIXER,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      UNKNOWN,
        SPNOOP,         UNKNOWN,        DUPLICATE,      SPNOOP,
        SPNOOP,         SPNOOP,         SPNOOP,         SPNOOP
    };

    alist_process(hle, ABI, 0x20);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_wrjb(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x20] = {
        SPNOOP,         ADPCM,          CLEARBUFF,      UNKNOWN,
        ADDMIXER,       RESAMPLE,       RESAMPLE_ZOH,   SPNOOP,
        SETBUFF,        SPNOOP,         DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE,     SPNOOP,         SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1,      ENVMIXER,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      UNKNOWN,
        HILOGAIN,       UNKNOWN,        DUPLICATE,      FILTER,
        SPNOOP,         SPNOOP,         SPNOOP,         SPNOOP
    };

    alist_process(hle, ABI, 0x20);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_ys(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x18] = {
        UNKNOWN,        ADPCM,          CLEARBUFF,      UNKNOWN,
        ADDMIXER,       RESAMPLE,       RESAMPLE_ZOH,   FILTER,
        SETBUFF,        DUPLICATE,      DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE,     HILOGAIN,       SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1,      ENVMIXER,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      UNKNOWN
    };

    alist_process(hle, ABI, 0x18);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_1080(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x18] = {
        UNKNOWN,        ADPCM,          CLEARBUFF,      UNKNOWN,
        ADDMIXER,       RESAMPLE,       RESAMPLE_ZOH,   FILTER,
        SETBUFF,        DUPLICATE,      DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE,     HILOGAIN,       SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1,      ENVMIXER,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      UNKNOWN
    };

    alist_process(hle, ABI, 0x18);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_oot(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x18] = {
        UNKNOWN,        ADPCM,          CLEARBUFF,      UNKNOWN,
        ADDMIXER,       RESAMPLE,       RESAMPLE_ZOH,   FILTER,
        SETBUFF,        DUPLICATE,      DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE,     HILOGAIN,       SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1,      ENVMIXER,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      UNKNOWN
    };

    alist_process(hle, ABI, 0x18);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_mm(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x18] = {
        UNKNOWN,        ADPCM,          CLEARBUFF,      SPNOOP,
        ADDMIXER,       RESAMPLE,       RESAMPLE_ZOH,   FILTER,
        SETBUFF,        DUPLICATE,      DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE,     HILOGAIN,       SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1,      ENVMIXER,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      UNKNOWN
    };

    alist_process(hle, ABI, 0x18);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_mmb(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x18] = {
        SPNOOP,         ADPCM,          CLEARBUFF,      SPNOOP,
        ADDMIXER,       RESAMPLE,       RESAMPLE_ZOH,   FILTER,
        SETBUFF,        DUPLICATE,      DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE,     HILOGAIN,       SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1,      ENVMIXER,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      UNKNOWN
    };

    alist_process(hle, ABI, 0x18);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_ac(struct hle_t* hle)
{
    static const acmd_callback_t ABI[0x18] = {
        UNKNOWN,        ADPCM,          CLEARBUFF,      SPNOOP,
        ADDMIXER,       RESAMPLE,       RESAMPLE_ZOH,   FILTER,
        SETBUFF,        DUPLICATE,      DMEMMOVE,       LOADADPCM,
        MIXER,          INTERLEAVE,     HILOGAIN,       SETLOOP,
        NEAD_16,        INTERL,         ENVSETUP1,      ENVMIXER,
        LOADBUFF,       SAVEBUFF,       ENVSETUP2,      UNKNOWN
    };

    alist_process(hle, ABI, 0x18);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

void alist_process_nead_mats(struct hle_t* hle)
{
    /* FIXME: implement proper ucode
     * Forward the task if possible,
     * otherwise better to have no sound than garbage sound
     */
    if (HleForwardTask(hle->user_defined) != 0) {
        rsp_break(hle, SP_STATUS_TASKDONE);
    }
}

void alist_process_nead_efz(struct hle_t* hle)
{
    /* FIXME: implement proper ucode
     * Forward the task if possible,
     * otherwise use FZero ucode which should be very similar
     */
    if (HleForwardTask(hle->user_defined) != 0) {
        alist_process_nead_fz(hle);
    }
}
