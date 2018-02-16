/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - hle.c                                           *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2012 Bobby Smiles                                       *
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

#ifdef ENABLE_TASK_DUMP
#include <stdio.h>
#endif

#include "hle_external.h"
#include "hle_internal.h"
#include "memory.h"
#include "ucodes.h"

#define min(a,b) (((a) < (b)) ? (a) : (b))

/* some rdp status flags */
#define DP_STATUS_FREEZE            0x2



/* helper functions prototypes */
static unsigned int sum_bytes(const unsigned char *bytes, unsigned int size);
static bool is_task(struct hle_t* hle);
static void send_dlist_to_gfx_plugin(struct hle_t* hle);
static bool try_fast_audio_dispatching(struct hle_t* hle);
static bool try_fast_task_dispatching(struct hle_t* hle);
static void normal_task_dispatching(struct hle_t* hle);
static void non_task_dispatching(struct hle_t* hle);
static bool try_re2_task_dispatching(struct hle_t* hle);

#ifdef ENABLE_TASK_DUMP
static void dump_binary(struct hle_t* hle, const char *const filename,
                        const unsigned char *const bytes, unsigned int size);
static void dump_task(struct hle_t* hle, const char *const filename);
static void dump_unknown_task(struct hle_t* hle, unsigned int sum);
static void dump_unknown_non_task(struct hle_t* hle, unsigned int sum);
#endif

/* Global functions */
void hle_init(struct hle_t* hle,
    unsigned char* dram,
    unsigned char* dmem,
    unsigned char* imem,
    unsigned int* mi_intr,
    unsigned int* sp_mem_addr,
    unsigned int* sp_dram_addr,
    unsigned int* sp_rd_length,
    unsigned int* sp_wr_length,
    unsigned int* sp_status,
    unsigned int* sp_dma_full,
    unsigned int* sp_dma_busy,
    unsigned int* sp_pc,
    unsigned int* sp_semaphore,
    unsigned int* dpc_start,
    unsigned int* dpc_end,
    unsigned int* dpc_current,
    unsigned int* dpc_status,
    unsigned int* dpc_clock,
    unsigned int* dpc_bufbusy,
    unsigned int* dpc_pipebusy,
    unsigned int* dpc_tmem,
    void* user_defined)
{
    hle->dram         = dram;
    hle->dmem         = dmem;
    hle->imem         = imem;
    hle->mi_intr      = mi_intr;
    hle->sp_mem_addr  = sp_mem_addr;
    hle->sp_dram_addr = sp_dram_addr;
    hle->sp_rd_length = sp_rd_length;
    hle->sp_wr_length = sp_wr_length;
    hle->sp_status    = sp_status;
    hle->sp_dma_full  = sp_dma_full;
    hle->sp_dma_busy  = sp_dma_busy;
    hle->sp_pc        = sp_pc;
    hle->sp_semaphore = sp_semaphore;
    hle->dpc_start    = dpc_start;
    hle->dpc_end      = dpc_end;
    hle->dpc_current  = dpc_current;
    hle->dpc_status   = dpc_status;
    hle->dpc_clock    = dpc_clock;
    hle->dpc_bufbusy  = dpc_bufbusy;
    hle->dpc_pipebusy = dpc_pipebusy;
    hle->dpc_tmem     = dpc_tmem;
    hle->user_defined = user_defined;
}

void hle_execute(struct hle_t* hle)
{
    if (is_task(hle)) {
        if (!try_fast_task_dispatching(hle))
            normal_task_dispatching(hle);
    } else {
        non_task_dispatching(hle);
    }
}

/* local functions */
static unsigned int sum_bytes(const unsigned char *bytes, unsigned int size)
{
    unsigned int sum = 0;
    const unsigned char *const bytes_end = bytes + size;

    while (bytes != bytes_end)
        sum += *bytes++;

    return sum;
}

/**
 * Try to figure if the RSP was launched using osSpTask* functions
 * and not run directly (in which case DMEM[0xfc0-0xfff] is meaningless).
 *
 * Previously, the ucode_size field was used to determine this,
 * but it is not robust enough (hi Pokemon Stadium !) because games could write anything
 * in this field : most ucode_boot discard the value and just use 0xf7f anyway.
 *
 * Using ucode_boot_size should be more robust in this regard.
 **/
static bool is_task(struct hle_t* hle)
{
    return (*dmem_u32(hle, TASK_UCODE_BOOT_SIZE) <= 0x1000);
}

void rsp_break(struct hle_t* hle, unsigned int setbits)
{
    *hle->sp_status |= setbits | SP_STATUS_BROKE | SP_STATUS_HALT;

    if ((*hle->sp_status & SP_STATUS_INTR_ON_BREAK)) {
        *hle->mi_intr |= MI_INTR_SP;
        HleCheckInterrupts(hle->user_defined);
    }
}

static void send_alist_to_audio_plugin(struct hle_t* hle)
{
    HleProcessAlistList(hle->user_defined);
    rsp_break(hle, SP_STATUS_TASKDONE);
}

static void send_dlist_to_gfx_plugin(struct hle_t* hle)
{
    /* Since GFX_INFO version 2, these bits are set before calling the ProcessDlistList function.
     * And the GFX plugin is responsible to unset them if needed.
     * For GFX_INFO version < 2, the GFX plugin didn't have access to sp_status so
     * it doesn't matter if we set these bits before calling ProcessDlistList function.
     */
    *hle->sp_status |= SP_STATUS_TASKDONE | SP_STATUS_BROKE | SP_STATUS_HALT;

    HleProcessDlistList(hle->user_defined);

    if ((*hle->sp_status & SP_STATUS_INTR_ON_BREAK) && (*hle->sp_status & (SP_STATUS_TASKDONE | SP_STATUS_BROKE | SP_STATUS_HALT))) {
        *hle->mi_intr |= MI_INTR_SP;
        HleCheckInterrupts(hle->user_defined);
    }
}

static bool try_fast_audio_dispatching(struct hle_t* hle)
{
    /* identify audio ucode by using the content of ucode_data */
    uint32_t ucode_data = *dmem_u32(hle, TASK_UCODE_DATA);
    uint32_t v;

    if (*dram_u32(hle, ucode_data) == 0x00000001) {
        if (*dram_u32(hle, ucode_data + 0x30) == 0xf0000f00) {
            v = *dram_u32(hle, ucode_data + 0x28);
            switch(v)
            {
            case 0x1e24138c: /* audio ABI (most common) */
                alist_process_audio(hle); return true;
            case 0x1dc8138c: /* GoldenEye */
                alist_process_audio_ge(hle); return true;
            case 0x1e3c1390: /* BlastCorp, DiddyKongRacing */
                alist_process_audio_bc(hle); return true;
            default:
                HleWarnMessage(hle->user_defined, "ABI1 identification regression: v=%08x", v);
            }
        } else {
            v = *dram_u32(hle, ucode_data + 0x10);
            switch(v)
            {
            case 0x11181350: /* MarioKart, WaveRace (E) */
                alist_process_nead_mk(hle); return true;
            case 0x111812e0: /* StarFox (J) */
                alist_process_nead_sfj(hle); return true;
            case 0x110412ac: /* WaveRace (J RevB) */
                alist_process_nead_wrjb(hle); return true;
            case 0x110412cc: /* StarFox/LylatWars (except J) */
                alist_process_nead_sf(hle); return true;
            case 0x1cd01250: /* FZeroX */
                alist_process_nead_fz(hle); return true;
            case 0x1f08122c: /* YoshisStory */
                alist_process_nead_ys(hle); return true;
            case 0x1f38122c: /* 1080° Snowboarding */
                alist_process_nead_1080(hle); return true;
            case 0x1f681230: /* Zelda OoT / Zelda MM (J, J RevA) */
                alist_process_nead_oot(hle); return true;
            case 0x1f801250: /* Zelda MM (except J, J RevA, E Beta), PokemonStadium 2 */
                alist_process_nead_mm(hle); return true;
            case 0x109411f8: /* Zelda MM (E Beta) */
                alist_process_nead_mmb(hle); return true;
            case 0x1eac11b8: /* AnimalCrossing */
                alist_process_nead_ac(hle); return true;
            case 0x00010010: /* MusyX v2 (IndianaJones, BattleForNaboo) */
                musyx_v2_task(hle); return true;
            case 0x1f701238: /* Mario Artist Talent Studio */
                alist_process_nead_mats(hle); return true;
            case 0x1f4c1230: /* FZeroX Expansion */
                alist_process_nead_efz(hle); return true;
            default:
                HleWarnMessage(hle->user_defined, "ABI2 identification regression: v=%08x", v);
            }
        }
    } else {
        v = *dram_u32(hle, ucode_data + 0x10);
        switch(v)
        {
        case 0x00000001: /* MusyX v1
            RogueSquadron, ResidentEvil2, PolarisSnoCross,
            TheWorldIsNotEnough, RugratsInParis, NBAShowTime,
            HydroThunder, Tarzan, GauntletLegend, Rush2049 */
            musyx_v1_task(hle); return true;
        case 0x0000127c: /* naudio (many games) */
            alist_process_naudio(hle); return true;
        case 0x00001280: /* BanjoKazooie */
            alist_process_naudio_bk(hle); return true;
        case 0x1c58126c: /* DonkeyKong */
            alist_process_naudio_dk(hle); return true;
        case 0x1ae8143c: /* BanjoTooie, JetForceGemini, MickeySpeedWayUSA, PerfectDark */
            alist_process_naudio_mp3(hle); return true;
        case 0x1ab0140c: /* ConkerBadFurDay */
            alist_process_naudio_cbfd(hle); return true;

        default:
            HleWarnMessage(hle->user_defined, "ABI3 identification regression: v=%08x", v);
        }
    }

    return false;
}

static bool try_fast_task_dispatching(struct hle_t* hle)
{
    /* identify task ucode by its type */
    switch (*dmem_u32(hle, TASK_TYPE)) {
    case 1:
        /* Resident evil 2 */
        if (*dmem_u32(hle, TASK_DATA_PTR) == 0) {
            return try_re2_task_dispatching(hle);
        }

        if (hle->hle_gfx) {
            send_dlist_to_gfx_plugin(hle);
            return true;
        }
        break;

    case 2:
        if (hle->hle_aud) {
            send_alist_to_audio_plugin(hle);
            return true;
        } else if (try_fast_audio_dispatching(hle))
            return true;
        break;

    case 7:
        HleShowCFB(hle->user_defined);
        break;
    }

    return false;
}

static void normal_task_dispatching(struct hle_t* hle)
{
    const unsigned int sum =
        sum_bytes((void*)dram_u32(hle, *dmem_u32(hle, TASK_UCODE)), min(*dmem_u32(hle, TASK_UCODE_SIZE), 0xf80) >> 1);

    switch (sum) {
    /* StoreVe12: found in Zelda Ocarina of Time [misleading task->type == 4] */
    case 0x278:
        /* Nothing to emulate */
        rsp_break(hle, SP_STATUS_TASKDONE);
        return;

    /* GFX: Twintris [misleading task->type == 0] */
    case 0x212ee:
        if (hle->hle_gfx) {
            send_dlist_to_gfx_plugin(hle);
            return;
        }
        break;

    /* JPEG: found in Pokemon Stadium J */
    case 0x2c85a:
        jpeg_decode_PS0(hle);
        return;

    /* JPEG: found in Zelda Ocarina of Time, Pokemon Stadium 1, Pokemon Stadium 2 */
    case 0x2caa6:
        jpeg_decode_PS(hle);
        return;

    /* JPEG: found in Ogre Battle, Bottom of the 9th */
    case 0x130de:
    case 0x278b0:
        jpeg_decode_OB(hle);
        return;
    }

    /* Forward task to RSP Fallback.
     * If task is not forwarded, use the regular "unknown task" path */
    if (HleForwardTask(hle->user_defined) != 0) {

        /* Send task_done signal for unknown ucodes to allow further processings */
        rsp_break(hle, SP_STATUS_TASKDONE);

        HleWarnMessage(hle->user_defined, "unknown OSTask: sum: %x PC:%x", sum, *hle->sp_pc);
#ifdef ENABLE_TASK_DUMP
        dump_unknown_task(hle, sum);
#endif
    }
}

static void non_task_dispatching(struct hle_t* hle)
{
    const unsigned int sum = sum_bytes(hle->imem, 44);

    if (sum == 0x9e2)
    {
        /* CIC x105 ucode (used during boot of CIC x105 games) */
        cicx105_ucode(hle);
        return;
    }

    /* Forward task to RSP Fallback.
     * If task is not forwarded, use the regular "unknown ucode" path */
    if (HleForwardTask(hle->user_defined) != 0) {

        HleWarnMessage(hle->user_defined, "unknown RSP code: sum: %x PC:%x", sum, *hle->sp_pc);
#ifdef ENABLE_TASK_DUMP
        dump_unknown_non_task(hle, sum);
#endif
    }
}

/* Resident evil 2 */
static bool try_re2_task_dispatching(struct hle_t* hle)
{
    const unsigned int sum =
        sum_bytes((void*)dram_u32(hle, *dmem_u32(hle, TASK_UCODE)), 256);

    switch (sum) {

    case 0x450f:
        resize_bilinear_task(hle);
        return true;

    case 0x3b44:
        decode_video_frame_task(hle);
        return true;

    case 0x3d84:
        fill_video_double_buffer_task(hle);
        return true;
    }

    return false;
}

#ifdef ENABLE_TASK_DUMP
static void dump_unknown_task(struct hle_t* hle, unsigned int sum)
{
    char filename[256];
    uint32_t ucode = *dmem_u32(hle, TASK_UCODE);
    uint32_t ucode_data = *dmem_u32(hle, TASK_UCODE_DATA);
    uint32_t data_ptr = *dmem_u32(hle, TASK_DATA_PTR);

    sprintf(&filename[0], "task_%x.log", sum);
    dump_task(hle, filename);

    /* dump ucode_boot */
    sprintf(&filename[0], "ucode_boot_%x.bin", sum);
    dump_binary(hle, filename, (void*)dram_u32(hle, *dmem_u32(hle, TASK_UCODE_BOOT)), *dmem_u32(hle, TASK_UCODE_BOOT_SIZE));

    /* dump ucode */
    if (ucode != 0) {
        sprintf(&filename[0], "ucode_%x.bin", sum);
        dump_binary(hle, filename, (void*)dram_u32(hle, ucode), 0xf80);
    }

    /* dump ucode_data */
    if (ucode_data != 0) {
        sprintf(&filename[0], "ucode_data_%x.bin", sum);
        dump_binary(hle, filename, (void*)dram_u32(hle, ucode_data), *dmem_u32(hle, TASK_UCODE_DATA_SIZE));
    }

    /* dump data */
    if (data_ptr != 0) {
        sprintf(&filename[0], "data_%x.bin", sum);
        dump_binary(hle, filename, (void*)dram_u32(hle, data_ptr), *dmem_u32(hle, TASK_DATA_SIZE));
    }
}

static void dump_unknown_non_task(struct hle_t* hle, unsigned int sum)
{
    char filename[256];

    /* dump IMEM & DMEM for further analysis */
    sprintf(&filename[0], "imem_%x.bin", sum);
    dump_binary(hle, filename, hle->imem, 0x1000);

    sprintf(&filename[0], "dmem_%x.bin", sum);
    dump_binary(hle, filename, hle->dmem, 0x1000);
}

static void dump_binary(struct hle_t* hle, const char *const filename,
                        const unsigned char *const bytes, unsigned int size)
{
    FILE *f;

    /* if file already exists, do nothing */
    f = fopen(filename, "r");
    if (f == NULL) {
        /* else we write bytes to the file */
        f = fopen(filename, "wb");
        if (f != NULL) {
            if (fwrite(bytes, 1, size, f) != size)
                HleErrorMessage(hle->user_defined, "Writing error on %s", filename);
            fclose(f);
        } else
            HleErrorMessage(hle->user_defined, "Couldn't open %s for writing !", filename);
    } else
        fclose(f);
}

static void dump_task(struct hle_t* hle, const char *const filename)
{
    FILE *f;

    f = fopen(filename, "r");
    if (f == NULL) {
        f = fopen(filename, "w");
        fprintf(f,
                "type = %d\n"
                "flags = %d\n"
                "ucode_boot  = %#08x size  = %#x\n"
                "ucode       = %#08x size  = %#x\n"
                "ucode_data  = %#08x size  = %#x\n"
                "dram_stack  = %#08x size  = %#x\n"
                "output_buff = %#08x *size = %#x\n"
                "data        = %#08x size  = %#x\n"
                "yield_data  = %#08x size  = %#x\n",
                *dmem_u32(hle, TASK_TYPE),
                *dmem_u32(hle, TASK_FLAGS),
                *dmem_u32(hle, TASK_UCODE_BOOT),     *dmem_u32(hle, TASK_UCODE_BOOT_SIZE),
                *dmem_u32(hle, TASK_UCODE),          *dmem_u32(hle, TASK_UCODE_SIZE),
                *dmem_u32(hle, TASK_UCODE_DATA),     *dmem_u32(hle, TASK_UCODE_DATA_SIZE),
                *dmem_u32(hle, TASK_DRAM_STACK),     *dmem_u32(hle, TASK_DRAM_STACK_SIZE),
                *dmem_u32(hle, TASK_OUTPUT_BUFF),    *dmem_u32(hle, TASK_OUTPUT_BUFF_SIZE),
                *dmem_u32(hle, TASK_DATA_PTR),       *dmem_u32(hle, TASK_DATA_SIZE),
                *dmem_u32(hle, TASK_YIELD_DATA_PTR), *dmem_u32(hle, TASK_YIELD_DATA_SIZE));
        fclose(f);
    } else
        fclose(f);
}
#endif
