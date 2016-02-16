/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - savestates.c                                            *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
 *   Copyright (C) 2012 CasualJames                                        *
 *   Copyright (C) 2009 Olejl Tillin9                                      *
 *   Copyright (C) 2008 Richard42 Tillin9                                  *
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

#include <SDL.h>
#include <SDL_thread.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <zlib.h>

#define M64P_CORE_PROTOTYPES 1
#include "ai/ai_controller.h"
#include "api/callbacks.h"
#include "api/config.h"
#include "api/m64p_config.h"
#include "api/m64p_types.h"
#include "main.h"
#include "main/list.h"
#include "memory/memory.h"
#include "osal/preproc.h"
#include "osd/osd.h"
#include "pi/pi_controller.h"
#include "plugin/plugin.h"
#include "r4300/r4300_core.h"
#include "rdp/rdp_core.h"
#include "ri/ri_controller.h"
#include "rom.h"
#include "rsp/rsp_core.h"
#include "savestates.h"
#include "si/si_controller.h"
#include "util.h"
#include "vi/vi_controller.h"
#include "workqueue.h"

#ifdef LIBMINIZIP
    #include <unzip.h>
    #include <zip.h>
#else
    #include "main/zip/unzip.h"
    #include "main/zip/zip.h"
#endif

static const char* savestate_magic = "M64+SAVE";
static const int savestate_latest_version = 0x00010000;  /* 1.0 */
static const unsigned char pj64_magic[4] = { 0xC8, 0xA6, 0xD8, 0x23 };

static savestates_job job = savestates_job_nothing;
static savestates_type type = savestates_type_unknown;
static char *fname = NULL;

static unsigned int slot = 0;
static int autoinc_save_slot = 0;

static SDL_mutex *savestates_lock;

struct savestate_work {
    char *filepath;
    char *data;
    size_t size;
    struct work_struct work;
};

/* Returns the malloc'd full path of the currently selected savestate. */
static char *savestates_generate_path(savestates_type type)
{
    if(fname != NULL) /* A specific path was given. */
    {
        return strdup(fname);
    }
    else /* Use the selected savestate slot */
    {
        char *filename;
        switch (type)
        {
            case savestates_type_m64p:
                filename = formatstr("%s.st%d", ROM_SETTINGS.goodname, slot);
                break;
            case savestates_type_pj64_zip:
                filename = formatstr("%s.pj%d.zip", ROM_PARAMS.headername, slot);
                break;
            case savestates_type_pj64_unc:
                filename = formatstr("%s.pj%d", ROM_PARAMS.headername, slot);
                break;
            default:
                filename = NULL;
                break;
        }

        if (filename != NULL)
        {
            char *filepath = formatstr("%s%s", get_savestatepath(), filename);
            free(filename);
            return filepath;
        }
        else
            return NULL;
    }
}

void savestates_select_slot(unsigned int s)
{
    if(s>9||s==slot)
        return;
    slot = s;
    ConfigSetParameter(g_CoreConfig, "CurrentStateSlot", M64TYPE_INT, &s);
    StateChanged(M64CORE_SAVESTATE_SLOT, slot);

    main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Selected state slot: %d", slot);
}

/* Returns the currently selected save slot. */
unsigned int savestates_get_slot(void)
{
    return slot;
}

/* Sets save state slot autoincrement on or off. */
void savestates_set_autoinc_slot(int b)
{
    autoinc_save_slot = b;
}

void savestates_inc_slot(void)
{
    if(++slot>9)
        slot = 0;
    StateChanged(M64CORE_SAVESTATE_SLOT, slot);
}

savestates_job savestates_get_job(void)
{
    return job;
}

void savestates_set_job(savestates_job j, savestates_type t, const char *fn)
{
    if (fname != NULL)
    {
        free(fname);
        fname = NULL;
    }

    job = j;
    type = t;
    if (fn != NULL)
        fname = strdup(fn);
}

static void savestates_clear_job(void)
{
    savestates_set_job(savestates_job_nothing, savestates_type_unknown, NULL);
}

#define GETARRAY(buff, type, count) \
    (to_little_endian_buffer(buff, sizeof(type),count), \
     buff += count*sizeof(type), \
     (type *)(buff-count*sizeof(type)))
#define COPYARRAY(dst, buff, type, count) \
    memcpy(dst, GETARRAY(buff, type, count), sizeof(type)*count)
#define GETDATA(buff, type) *GETARRAY(buff, type, 1)

#define PUTARRAY(src, buff, type, count) \
    memcpy(buff, src, sizeof(type)*count); \
    to_little_endian_buffer(buff, sizeof(type), count); \
    buff += count*sizeof(type);

#define PUTDATA(buff, type, value) \
    do { type x = value; PUTARRAY(&x, buff, type, 1); } while(0)

static int savestates_load_m64p(char *filepath)
{
    unsigned char header[44];
    gzFile f;
    int version;
    int i;
    uint32_t FCR31;

    size_t savestateSize;
    unsigned char *savestateData, *curr;
    char queue[1024];

    uint32_t* cp0_regs = r4300_cp0_regs();

    SDL_LockMutex(savestates_lock);

    f = gzopen(filepath, "rb");
    if(f==NULL)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Could not open state file: %s", filepath);
        SDL_UnlockMutex(savestates_lock);
        return 0;
    }

    /* Read and check Mupen64Plus magic number. */
    if (gzread(f, header, 44) != 44)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Could not read header from state file %s", filepath);
        gzclose(f);
        SDL_UnlockMutex(savestates_lock);
        return 0;
    }
    curr = header;

    if(strncmp((char *)curr, savestate_magic, 8)!=0)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "State file: %s is not a valid Mupen64plus savestate.", filepath);
        gzclose(f);
        SDL_UnlockMutex(savestates_lock);
        return 0;
    }
    curr += 8;

    version = *curr++;
    version = (version << 8) | *curr++;
    version = (version << 8) | *curr++;
    version = (version << 8) | *curr++;
    if(version != 0x00010000)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "State version (%08x) isn't compatible. Please update Mupen64Plus.", version);
        gzclose(f);
        SDL_UnlockMutex(savestates_lock);
        return 0;
    }

    if(memcmp((char *)curr, ROM_SETTINGS.MD5, 32))
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "State ROM MD5 does not match current ROM.");
        gzclose(f);
        SDL_UnlockMutex(savestates_lock);
        return 0;
    }
    curr += 32;

    /* Read the rest of the savestate */
    savestateSize = 16788244;
    savestateData = curr = (unsigned char *)malloc(savestateSize);
    if (savestateData == NULL)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Insufficient memory to load state.");
        gzclose(f);
        SDL_UnlockMutex(savestates_lock);
        return 0;
    }
    if (gzread(f, savestateData, savestateSize) != savestateSize ||
        (gzread(f, queue, sizeof(queue)) % 4) != 0)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Could not read Mupen64Plus savestate data from %s", filepath);
        free(savestateData);
        gzclose(f);
        SDL_UnlockMutex(savestates_lock);
        return 0;
    }

    gzclose(f);
    SDL_UnlockMutex(savestates_lock);

    // Parse savestate
    g_ri.rdram.regs[RDRAM_CONFIG_REG]       = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_DEVICE_ID_REG]    = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_DELAY_REG]        = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_MODE_REG]         = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_REF_INTERVAL_REG] = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_REF_ROW_REG]      = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_RAS_INTERVAL_REG] = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_MIN_INTERVAL_REG] = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_ADDR_SELECT_REG]  = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_DEVICE_MANUF_REG] = GETDATA(curr, uint32_t);

    curr += 4; /* Padding from old implementation */
    g_r4300.mi.regs[MI_INIT_MODE_REG] = GETDATA(curr, uint32_t);
    curr += 4; // Duplicate MI init mode flags from old implementation
    g_r4300.mi.regs[MI_VERSION_REG]   = GETDATA(curr, uint32_t);
    g_r4300.mi.regs[MI_INTR_REG]      = GETDATA(curr, uint32_t);
    g_r4300.mi.regs[MI_INTR_MASK_REG] = GETDATA(curr, uint32_t);
    curr += 4; /* Padding from old implementation */
    curr += 8; // Duplicated MI intr flags and padding from old implementation

    g_pi.regs[PI_DRAM_ADDR_REG]    = GETDATA(curr, uint32_t);
    g_pi.regs[PI_CART_ADDR_REG]    = GETDATA(curr, uint32_t);
    g_pi.regs[PI_RD_LEN_REG]       = GETDATA(curr, uint32_t);
    g_pi.regs[PI_WR_LEN_REG]       = GETDATA(curr, uint32_t);
    g_pi.regs[PI_STATUS_REG]       = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM1_LAT_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM1_PWD_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM1_PGS_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM1_RLS_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM2_LAT_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM2_PWD_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM2_PGS_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM2_RLS_REG] = GETDATA(curr, uint32_t);

    g_sp.regs[SP_MEM_ADDR_REG]  = GETDATA(curr, uint32_t);
    g_sp.regs[SP_DRAM_ADDR_REG] = GETDATA(curr, uint32_t);
    g_sp.regs[SP_RD_LEN_REG]    = GETDATA(curr, uint32_t);
    g_sp.regs[SP_WR_LEN_REG]    = GETDATA(curr, uint32_t);
    curr += 4; /* Padding from old implementation */
    g_sp.regs[SP_STATUS_REG]    = GETDATA(curr, uint32_t);
    curr += 16; // Duplicated SP flags and padding from old implementation
    g_sp.regs[SP_DMA_FULL_REG]  = GETDATA(curr, uint32_t);
    g_sp.regs[SP_DMA_BUSY_REG]  = GETDATA(curr, uint32_t);
    g_sp.regs[SP_SEMAPHORE_REG] = GETDATA(curr, uint32_t);

    g_sp.regs2[SP_PC_REG]    = GETDATA(curr, uint32_t);
    g_sp.regs2[SP_IBIST_REG] = GETDATA(curr, uint32_t);

    g_si.regs[SI_DRAM_ADDR_REG]      = GETDATA(curr, uint32_t);
    g_si.regs[SI_PIF_ADDR_RD64B_REG] = GETDATA(curr, uint32_t);
    g_si.regs[SI_PIF_ADDR_WR64B_REG] = GETDATA(curr, uint32_t);
    g_si.regs[SI_STATUS_REG]         = GETDATA(curr, uint32_t);

    g_vi.regs[VI_STATUS_REG]  = GETDATA(curr, uint32_t);
    g_vi.regs[VI_ORIGIN_REG]  = GETDATA(curr, uint32_t);
    g_vi.regs[VI_WIDTH_REG]   = GETDATA(curr, uint32_t);
    g_vi.regs[VI_V_INTR_REG]  = GETDATA(curr, uint32_t);
    g_vi.regs[VI_CURRENT_REG] = GETDATA(curr, uint32_t);
    g_vi.regs[VI_BURST_REG]   = GETDATA(curr, uint32_t);
    g_vi.regs[VI_V_SYNC_REG]  = GETDATA(curr, uint32_t);
    g_vi.regs[VI_H_SYNC_REG]  = GETDATA(curr, uint32_t);
    g_vi.regs[VI_LEAP_REG]    = GETDATA(curr, uint32_t);
    g_vi.regs[VI_H_START_REG] = GETDATA(curr, uint32_t);
    g_vi.regs[VI_V_START_REG] = GETDATA(curr, uint32_t);
    g_vi.regs[VI_V_BURST_REG] = GETDATA(curr, uint32_t);
    g_vi.regs[VI_X_SCALE_REG] = GETDATA(curr, uint32_t);
    g_vi.regs[VI_Y_SCALE_REG] = GETDATA(curr, uint32_t);
    g_vi.delay = GETDATA(curr, unsigned int);
    gfx.viStatusChanged();
    gfx.viWidthChanged();

    g_ri.regs[RI_MODE_REG]         = GETDATA(curr, uint32_t);
    g_ri.regs[RI_CONFIG_REG]       = GETDATA(curr, uint32_t);
    g_ri.regs[RI_CURRENT_LOAD_REG] = GETDATA(curr, uint32_t);
    g_ri.regs[RI_SELECT_REG]       = GETDATA(curr, uint32_t);
    g_ri.regs[RI_REFRESH_REG]      = GETDATA(curr, uint32_t);
    g_ri.regs[RI_LATENCY_REG]      = GETDATA(curr, uint32_t);
    g_ri.regs[RI_ERROR_REG]        = GETDATA(curr, uint32_t);
    g_ri.regs[RI_WERROR_REG]       = GETDATA(curr, uint32_t);

    g_ai.regs[AI_DRAM_ADDR_REG] = GETDATA(curr, uint32_t);
    g_ai.regs[AI_LEN_REG]       = GETDATA(curr, uint32_t);
    g_ai.regs[AI_CONTROL_REG]   = GETDATA(curr, uint32_t);
    g_ai.regs[AI_STATUS_REG]    = GETDATA(curr, uint32_t);
    g_ai.regs[AI_DACRATE_REG]   = GETDATA(curr, uint32_t);
    g_ai.regs[AI_BITRATE_REG]   = GETDATA(curr, uint32_t);
    g_ai.fifo[1].duration  = GETDATA(curr, unsigned int);
    g_ai.fifo[1].length = GETDATA(curr, uint32_t);
    g_ai.fifo[0].duration  = GETDATA(curr, unsigned int);
    g_ai.fifo[0].length = GETDATA(curr, uint32_t);
    /* best effort initialization of fifo addresses...
     * You might get a small sound "pop" because address might be wrong.
     * Proper initialization requires changes to savestate format
     */
    g_ai.fifo[0].address = g_ai.regs[AI_DRAM_ADDR_REG];
    g_ai.fifo[1].address = g_ai.regs[AI_DRAM_ADDR_REG];
    g_ai.samples_format_changed = 1;

    g_dp.dpc_regs[DPC_START_REG]    = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_END_REG]      = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_CURRENT_REG]  = GETDATA(curr, uint32_t);
    curr += 4; // Padding from old implementation
    g_dp.dpc_regs[DPC_STATUS_REG]   = GETDATA(curr, uint32_t);
    curr += 12; // Duplicated DPC flags and padding from old implementation
    g_dp.dpc_regs[DPC_CLOCK_REG]    = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_BUFBUSY_REG]  = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_PIPEBUSY_REG] = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_TMEM_REG]     = GETDATA(curr, uint32_t);

    g_dp.dps_regs[DPS_TBIST_REG]        = GETDATA(curr, uint32_t);
    g_dp.dps_regs[DPS_TEST_MODE_REG]    = GETDATA(curr, uint32_t);
    g_dp.dps_regs[DPS_BUFTEST_ADDR_REG] = GETDATA(curr, uint32_t);
    g_dp.dps_regs[DPS_BUFTEST_DATA_REG] = GETDATA(curr, uint32_t);

    COPYARRAY(g_rdram, curr, uint32_t, RDRAM_MAX_SIZE/4);
    COPYARRAY(g_sp.mem, curr, uint32_t, SP_MEM_SIZE/4);
    COPYARRAY(g_si.pif.ram, curr, uint8_t, PIF_RAM_SIZE);

    g_pi.use_flashram = GETDATA(curr, int);
    g_pi.flashram.mode = GETDATA(curr, int);
    g_pi.flashram.status = GETDATA(curr, unsigned long long);
    g_pi.flashram.erase_offset = GETDATA(curr, unsigned int);
    g_pi.flashram.write_pointer = GETDATA(curr, unsigned int);

    COPYARRAY(tlb_LUT_r, curr, unsigned int, 0x100000);
    COPYARRAY(tlb_LUT_w, curr, unsigned int, 0x100000);

    *r4300_llbit() = GETDATA(curr, unsigned int);
    COPYARRAY(r4300_regs(), curr, int64_t, 32);
    COPYARRAY(cp0_regs, curr, uint32_t, CP0_REGS_COUNT);
    set_fpr_pointers(cp0_regs[CP0_STATUS_REG]);
    *r4300_mult_lo() = GETDATA(curr, int64_t);
    *r4300_mult_hi() = GETDATA(curr, int64_t);
    COPYARRAY(r4300_cp1_regs(), curr, int64_t, 32);
    if ((cp0_regs[CP0_STATUS_REG] & UINT32_C(0x04000000)) == 0)  // 32-bit FPR mode requires data shuffling because 64-bit layout is always stored in savestate file
        shuffle_fpr_data(UINT32_C(0x04000000), 0);
    *r4300_cp1_fcr0()  = GETDATA(curr, uint32_t);
    FCR31 = GETDATA(curr, uint32_t);
    *r4300_cp1_fcr31() = FCR31;
    update_x86_rounding_mode(FCR31);

    for (i = 0; i < 32; i++)
    {
        tlb_e[i].mask = GETDATA(curr, short);
        curr += 2;
        tlb_e[i].vpn2 = GETDATA(curr, int);
        tlb_e[i].g = GETDATA(curr, char);
        tlb_e[i].asid = GETDATA(curr, unsigned char);
        curr += 2;
        tlb_e[i].pfn_even = GETDATA(curr, int);
        tlb_e[i].c_even = GETDATA(curr, char);
        tlb_e[i].d_even = GETDATA(curr, char);
        tlb_e[i].v_even = GETDATA(curr, char);
        curr++;
        tlb_e[i].pfn_odd = GETDATA(curr, int);
        tlb_e[i].c_odd = GETDATA(curr, char);
        tlb_e[i].d_odd = GETDATA(curr, char);
        tlb_e[i].v_odd = GETDATA(curr, char);
        tlb_e[i].r = GETDATA(curr, char);
   
        tlb_e[i].start_even = GETDATA(curr, unsigned int);
        tlb_e[i].end_even = GETDATA(curr, unsigned int);
        tlb_e[i].phys_even = GETDATA(curr, unsigned int);
        tlb_e[i].start_odd = GETDATA(curr, unsigned int);
        tlb_e[i].end_odd = GETDATA(curr, unsigned int);
        tlb_e[i].phys_odd = GETDATA(curr, unsigned int);
    }

    savestates_load_set_pc(GETDATA(curr, uint32_t));

    *r4300_next_interrupt() = GETDATA(curr, unsigned int);
    g_vi.next_vi = GETDATA(curr, unsigned int);
    g_vi.field = GETDATA(curr, unsigned int);

    // assert(savestateData+savestateSize == curr)

    to_little_endian_buffer(queue, 4, 256);
    load_eventqueue_infos(queue);

    *r4300_last_addr() = *r4300_pc();

    free(savestateData);
    main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "State loaded from: %s", namefrompath(filepath));
    return 1;
}

static int savestates_load_pj64(char *filepath, void *handle,
                                int (*read_func)(void *, void *, size_t))
{
    char buffer[1024];
    unsigned int vi_timer, SaveRDRAMSize;
    int i;
    uint32_t FCR31;

    unsigned char header[8];
    unsigned char RomHeader[0x40];

    size_t savestateSize;
    unsigned char *savestateData, *curr;

    uint32_t* cp0_regs = r4300_cp0_regs();

    /* Read and check Project64 magic number. */
    if (!read_func(handle, header, 8))
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Could not read header from Project64 savestate %s", filepath);
        return 0;
    }

    curr = header;
    if (memcmp(curr, pj64_magic, 4) != 0)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "State file: %s is not a valid Project64 savestate. Unrecognized file format.", filepath);
        return 0;
    }
    curr += 4;

    SaveRDRAMSize = GETDATA(curr, unsigned int);

    /* Read the rest of the savestate into memory. */
    savestateSize = SaveRDRAMSize + 0x2754;
    savestateData = curr = (unsigned char *)malloc(savestateSize);
    if (savestateData == NULL)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Insufficient memory to load state.");
        return 0;
    }
    if (!read_func(handle, savestateData, savestateSize))
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Could not read savestate data from Project64 savestate %s", filepath);
        free(savestateData);
        return 0;
    }

    // check ROM header
    COPYARRAY(RomHeader, curr, unsigned int, 0x40/4);
    if(memcmp(RomHeader, g_rom, 0x40) != 0)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "State ROM header does not match current ROM.");
        free(savestateData);
        return 0;
    }

    // vi_timer
    vi_timer = GETDATA(curr, unsigned int);

    // Program Counter
    *r4300_last_addr() = GETDATA(curr, uint32_t);

    // GPR
    COPYARRAY(r4300_regs(), curr, int64_t, 32);

    // FPR
    COPYARRAY(r4300_cp1_regs(), curr, int64_t, 32);

    // CP0
    COPYARRAY(cp0_regs, curr, uint32_t, CP0_REGS_COUNT);

    set_fpr_pointers(cp0_regs[CP0_STATUS_REG]);
    if ((cp0_regs[CP0_STATUS_REG] & UINT32_C(0x04000000)) == 0) // TODO not sure how pj64 handles this
        shuffle_fpr_data(UINT32_C(0x04000000), 0);

    // Initialze the interupts
    vi_timer += cp0_regs[CP0_COUNT_REG];
    *r4300_next_interrupt() = (cp0_regs[CP0_COMPARE_REG] < vi_timer)
                  ? cp0_regs[CP0_COMPARE_REG]
                  : vi_timer;
    g_vi.next_vi = vi_timer;
    g_vi.field = 0;
    *((unsigned int*)&buffer[0]) = VI_INT;
    *((unsigned int*)&buffer[4]) = vi_timer;
    *((unsigned int*)&buffer[8]) = COMPARE_INT;
    *((unsigned int*)&buffer[12]) = cp0_regs[CP0_COMPARE_REG];
    *((unsigned int*)&buffer[16]) = 0xFFFFFFFF;

    load_eventqueue_infos(buffer);

    // FPCR
    *r4300_cp1_fcr0() = GETDATA(curr, uint32_t);
    curr += 30 * 4; // FCR1...FCR30 not supported
    FCR31 = GETDATA(curr, uint32_t);
    *r4300_cp1_fcr31() = FCR31;
    update_x86_rounding_mode(FCR31);

    // hi / lo
    *r4300_mult_hi() = GETDATA(curr, int64_t);
    *r4300_mult_lo() = GETDATA(curr, int64_t);

    // rdram register
    g_ri.rdram.regs[RDRAM_CONFIG_REG]       = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_DEVICE_ID_REG]    = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_DELAY_REG]        = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_MODE_REG]         = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_REF_INTERVAL_REG] = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_REF_ROW_REG]      = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_RAS_INTERVAL_REG] = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_MIN_INTERVAL_REG] = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_ADDR_SELECT_REG]  = GETDATA(curr, uint32_t);
    g_ri.rdram.regs[RDRAM_DEVICE_MANUF_REG] = GETDATA(curr, uint32_t);

    // sp_register
    g_sp.regs[SP_MEM_ADDR_REG]  = GETDATA(curr, uint32_t);
    g_sp.regs[SP_DRAM_ADDR_REG] = GETDATA(curr, uint32_t);
    g_sp.regs[SP_RD_LEN_REG]    = GETDATA(curr, uint32_t);
    g_sp.regs[SP_WR_LEN_REG]    = GETDATA(curr, uint32_t);
    g_sp.regs[SP_STATUS_REG]    = GETDATA(curr, uint32_t);
    g_sp.regs[SP_DMA_FULL_REG]  = GETDATA(curr, uint32_t);
    g_sp.regs[SP_DMA_BUSY_REG]  = GETDATA(curr, uint32_t);
    g_sp.regs[SP_SEMAPHORE_REG] = GETDATA(curr, uint32_t);
    g_sp.regs2[SP_PC_REG]    = GETDATA(curr, uint32_t);
    g_sp.regs2[SP_IBIST_REG] = GETDATA(curr, uint32_t);

    // dpc_register
    g_dp.dpc_regs[DPC_START_REG]    = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_END_REG]      = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_CURRENT_REG]  = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_STATUS_REG]   = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_CLOCK_REG]    = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_BUFBUSY_REG]  = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_PIPEBUSY_REG] = GETDATA(curr, uint32_t);
    g_dp.dpc_regs[DPC_TMEM_REG]     = GETDATA(curr, uint32_t);
    (void)GETDATA(curr, unsigned int); // Dummy read
    (void)GETDATA(curr, unsigned int); // Dummy read

    // mi_register
    g_r4300.mi.regs[MI_INIT_MODE_REG] = GETDATA(curr, uint32_t);
    g_r4300.mi.regs[MI_VERSION_REG]   = GETDATA(curr, uint32_t);
    g_r4300.mi.regs[MI_INTR_REG]      = GETDATA(curr, uint32_t);
    g_r4300.mi.regs[MI_INTR_MASK_REG] = GETDATA(curr, uint32_t);

    // vi_register
    g_vi.regs[VI_STATUS_REG]  = GETDATA(curr, uint32_t);
    g_vi.regs[VI_ORIGIN_REG]  = GETDATA(curr, uint32_t);
    g_vi.regs[VI_WIDTH_REG]   = GETDATA(curr, uint32_t);
    g_vi.regs[VI_V_INTR_REG]  = GETDATA(curr, uint32_t);
    g_vi.regs[VI_CURRENT_REG] = GETDATA(curr, uint32_t);
    g_vi.regs[VI_BURST_REG]   = GETDATA(curr, uint32_t);
    g_vi.regs[VI_V_SYNC_REG]  = GETDATA(curr, uint32_t);
    g_vi.regs[VI_H_SYNC_REG]  = GETDATA(curr, uint32_t);
    g_vi.regs[VI_LEAP_REG]    = GETDATA(curr, uint32_t);
    g_vi.regs[VI_H_START_REG] = GETDATA(curr, uint32_t);
    g_vi.regs[VI_V_START_REG] = GETDATA(curr, uint32_t);
    g_vi.regs[VI_V_BURST_REG] = GETDATA(curr, uint32_t);
    g_vi.regs[VI_X_SCALE_REG] = GETDATA(curr, uint32_t);
    g_vi.regs[VI_Y_SCALE_REG] = GETDATA(curr, uint32_t);
    // TODO vi delay?
    gfx.viStatusChanged();
    gfx.viWidthChanged();

    // ai_register
    g_ai.regs[AI_DRAM_ADDR_REG] = GETDATA(curr, uint32_t);
    g_ai.regs[AI_LEN_REG]       = GETDATA(curr, uint32_t);
    g_ai.regs[AI_CONTROL_REG]   = GETDATA(curr, uint32_t);
    g_ai.regs[AI_STATUS_REG]    = GETDATA(curr, uint32_t);
    g_ai.regs[AI_DACRATE_REG]   = GETDATA(curr, uint32_t);
    g_ai.regs[AI_BITRATE_REG]   = GETDATA(curr, uint32_t);
    g_ai.samples_format_changed = 1;

    // pi_register
    g_pi.regs[PI_DRAM_ADDR_REG]    = GETDATA(curr, uint32_t);
    g_pi.regs[PI_CART_ADDR_REG]    = GETDATA(curr, uint32_t);
    g_pi.regs[PI_RD_LEN_REG]       = GETDATA(curr, uint32_t);
    g_pi.regs[PI_WR_LEN_REG]       = GETDATA(curr, uint32_t);
    g_pi.regs[PI_STATUS_REG]       = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM1_LAT_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM1_PWD_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM1_PGS_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM1_RLS_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM2_LAT_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM2_PWD_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM2_PGS_REG] = GETDATA(curr, uint32_t);
    g_pi.regs[PI_BSD_DOM2_RLS_REG] = GETDATA(curr, uint32_t);
    read_func(handle, g_pi.regs, PI_REGS_COUNT*sizeof(g_pi.regs[0]));

    // ri_register
    g_ri.regs[RI_MODE_REG]         = GETDATA(curr, uint32_t);
    g_ri.regs[RI_CONFIG_REG]       = GETDATA(curr, uint32_t);
    g_ri.regs[RI_CURRENT_LOAD_REG] = GETDATA(curr, uint32_t);
    g_ri.regs[RI_SELECT_REG]       = GETDATA(curr, uint32_t);
    g_ri.regs[RI_REFRESH_REG]      = GETDATA(curr, uint32_t);
    g_ri.regs[RI_LATENCY_REG]      = GETDATA(curr, uint32_t);
    g_ri.regs[RI_ERROR_REG]        = GETDATA(curr, uint32_t);
    g_ri.regs[RI_WERROR_REG]       = GETDATA(curr, uint32_t);

    // si_register
    g_si.regs[SI_DRAM_ADDR_REG]      = GETDATA(curr, uint32_t);
    g_si.regs[SI_PIF_ADDR_RD64B_REG] = GETDATA(curr, uint32_t);
    g_si.regs[SI_PIF_ADDR_WR64B_REG] = GETDATA(curr, uint32_t);
    g_si.regs[SI_STATUS_REG]         = GETDATA(curr, uint32_t);

    // tlb
    memset(tlb_LUT_r, 0, 0x400000);
    memset(tlb_LUT_w, 0, 0x400000);
    for (i=0; i < 32; i++)
    {
        unsigned int MyPageMask, MyEntryHi, MyEntryLo0, MyEntryLo1;

        (void)GETDATA(curr, unsigned int); // Dummy read - EntryDefined
        MyPageMask = GETDATA(curr, unsigned int);
        MyEntryHi = GETDATA(curr, unsigned int);
        MyEntryLo0 = GETDATA(curr, unsigned int);
        MyEntryLo1 = GETDATA(curr, unsigned int);

        // This is copied from TLBWI instruction
        tlb_e[i].g = (MyEntryLo0 & MyEntryLo1 & 1);
        tlb_e[i].pfn_even = (MyEntryLo0 & 0x3FFFFFC0) >> 6;
        tlb_e[i].pfn_odd = (MyEntryLo1 & 0x3FFFFFC0) >> 6;
        tlb_e[i].c_even = (MyEntryLo0 & 0x38) >> 3;
        tlb_e[i].c_odd = (MyEntryLo1 & 0x38) >> 3;
        tlb_e[i].d_even = (MyEntryLo0 & 0x4) >> 2;
        tlb_e[i].d_odd = (MyEntryLo1 & 0x4) >> 2;
        tlb_e[i].v_even = (MyEntryLo0 & 0x2) >> 1;
        tlb_e[i].v_odd = (MyEntryLo1 & 0x2) >> 1;
        tlb_e[i].asid = (MyEntryHi & 0xFF);
        tlb_e[i].vpn2 = (MyEntryHi & 0xFFFFE000) >> 13;
        //tlb_e[i].r = (MyEntryHi & 0xC000000000000000LL) >> 62;
        tlb_e[i].mask = (MyPageMask & 0x1FFE000) >> 13;
           
        tlb_e[i].start_even = tlb_e[i].vpn2 << 13;
        tlb_e[i].end_even = tlb_e[i].start_even+
          (tlb_e[i].mask << 12) + 0xFFF;
        tlb_e[i].phys_even = tlb_e[i].pfn_even << 12;
           
        tlb_e[i].start_odd = tlb_e[i].end_even+1;
        tlb_e[i].end_odd = tlb_e[i].start_odd+
          (tlb_e[i].mask << 12) + 0xFFF;
        tlb_e[i].phys_odd = tlb_e[i].pfn_odd << 12;

        tlb_map(&tlb_e[i]);
    }

    // pif ram
    COPYARRAY(g_si.pif.ram, curr, uint8_t, PIF_RAM_SIZE);

    // RDRAM
    memset(g_rdram, 0, RDRAM_MAX_SIZE);
    COPYARRAY(g_rdram, curr, uint32_t, SaveRDRAMSize/4);

    // DMEM + IMEM
    COPYARRAY(g_sp.mem, curr, uint32_t, SP_MEM_SIZE/4);

    // The following values should not matter because we don't have any AI interrupt
    // g_ai.fifo[1].delay = 0; g_ai.fifo[1].length = 0;
    // g_ai.fifo[0].delay = 0; g_ai.fifo[0].length = 0;

    // The following is not available in PJ64 savestate. Keep the values as is.
    // g_dp.dps_regs[DPS_TBIST_REG] = 0; g_dp.dps_regs[DPS_TEST_MODE_REG] = 0;
    // g_dp.dps_regs[DPS_BUFTEST_ADDR_REG] = 0; g_dp.dps_regs[DPS_BUFTEST_DATA_REG] = 0; *r4300_llbit() = 0;

    // No flashram info in pj64 savestate.
    init_flashram(&g_pi.flashram);

    savestates_load_set_pc(*r4300_last_addr());

    // assert(savestateData+savestateSize == curr)

    free(savestateData);
    return 1;
}

static int read_data_from_zip(void *zip, void *buffer, size_t length)
{
    return unzReadCurrentFile((unzFile)zip, buffer, (unsigned)length) == length;
}

static int savestates_load_pj64_zip(char *filepath)
{
    char szFileName[256], szExtraField[256], szComment[256];
    unzFile zipstatefile = NULL;
    unz_file_info fileinfo;
    int ret = 0;

    /* Open the .zip file. */
    zipstatefile = unzOpen(filepath);
    if (zipstatefile == NULL ||
        unzGoToFirstFile(zipstatefile) != UNZ_OK ||
        unzGetCurrentFileInfo(zipstatefile, &fileinfo, szFileName, 255, szExtraField, 255, szComment, 255) != UNZ_OK ||
        unzOpenCurrentFile(zipstatefile) != UNZ_OK)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Zip error. Could not open state file: %s", filepath);
        goto clean_and_exit;
    }

    if (!savestates_load_pj64(filepath, zipstatefile, read_data_from_zip))
        goto clean_and_exit;

    main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "State loaded from: %s", namefrompath(filepath));
    ret = 1;

    clean_and_exit:
        if (zipstatefile != NULL)
            unzClose(zipstatefile);
        return ret;
}

static int read_data_from_file(void *file, void *buffer, size_t length)
{
    return fread(buffer, 1, length, file) == length;
}

static int savestates_load_pj64_unc(char *filepath)
{
    FILE *f;

    /* Open the file. */
    f = fopen(filepath, "rb");
    if (f == NULL)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Could not open state file: %s", filepath);
        return 0;
    }

    if (!savestates_load_pj64(filepath, f, read_data_from_file))
    {
        fclose(f);
        return 0;
    }

    main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "State loaded from: %s", namefrompath(filepath));
    fclose(f);
    return 1;
}

static savestates_type savestates_detect_type(char *filepath)
{
    unsigned char magic[4];
    FILE *f = fopen(filepath, "rb");
    if (f == NULL)
    {
        DebugMessage(M64MSG_STATUS, "Could not open state file %s\n", filepath);
        return savestates_type_unknown;
    }

    if (fread(magic, 1, 4, f) != 4)
    {
        fclose(f);
        DebugMessage(M64MSG_STATUS, "Could not read from state file %s\n", filepath);
        return savestates_type_unknown;
    }

    fclose(f);

    if (magic[0] == 0x1f && magic[1] == 0x8b) // GZIP header
        return savestates_type_m64p;
    else if (memcmp(magic, "PK\x03\x04", 4) == 0) // ZIP header
        return savestates_type_pj64_zip;
    else if (memcmp(magic, pj64_magic, 4) == 0) // PJ64 header
        return savestates_type_pj64_unc;
    else
    {
        DebugMessage(M64MSG_STATUS, "Unknown state file type %s\n", filepath);
        return savestates_type_unknown;
    }
}

int savestates_load(void)
{
    FILE *fPtr = NULL;
    char *filepath = NULL;
    int ret = 0;

    if (fname == NULL) // For slots, autodetect the savestate type
    {
        // try M64P type first
        type = savestates_type_m64p;
        filepath = savestates_generate_path(type);
        fPtr = fopen(filepath, "rb"); // can I open this?
        if (fPtr == NULL)
        {
            free(filepath);
            // try PJ64 zipped type second
            type = savestates_type_pj64_zip;
            filepath = savestates_generate_path(type);
            fPtr = fopen(filepath, "rb"); // can I open this?
            if (fPtr == NULL)
            {
                free(filepath);
                // finally, try PJ64 uncompressed
                type = savestates_type_pj64_unc;
                filepath = savestates_generate_path(type);
                fPtr = fopen(filepath, "rb"); // can I open this?
                if (fPtr == NULL)
                {
                    free(filepath);
                    filepath = NULL;
                    main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "No Mupen64Plus/PJ64 state file found for slot %i", slot);
                    type = savestates_type_unknown;
                }
            }
        }
    }
    else // filename of state file to load was set explicitly in 'fname'
    {
        // detect type if unknown
        if (type == savestates_type_unknown)
        {
            type = savestates_detect_type(fname);
        }
        filepath = savestates_generate_path(type);
        if (filepath != NULL)
            fPtr = fopen(filepath, "rb"); // can I open this?
        if (fPtr == NULL)
        {
            if (filepath != NULL)
                free(filepath);
            filepath = NULL;
            main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Failed to open savestate file %s", filepath);
        }
    }
    if (fPtr != NULL)
        fclose(fPtr);

    if (filepath != NULL)
    {
        switch (type)
        {
            case savestates_type_m64p: ret = savestates_load_m64p(filepath); break;
            case savestates_type_pj64_zip: ret = savestates_load_pj64_zip(filepath); break;
            case savestates_type_pj64_unc: ret = savestates_load_pj64_unc(filepath); break;
            default: ret = 0; break;
        }
        free(filepath);
        filepath = NULL;
    }

    // deliver callback to indicate completion of state loading operation
    StateChanged(M64CORE_STATE_LOADCOMPLETE, ret);

    savestates_clear_job();

    return ret;
}

static void savestates_save_m64p_work(struct work_struct *work)
{
    gzFile f;
    struct savestate_work *save = container_of(work, struct savestate_work, work);

    SDL_LockMutex(savestates_lock);

    // Write the state to a GZIP file
    f = gzopen(save->filepath, "wb");

    if (f==NULL)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Could not open state file: %s", save->filepath);
        free(save->data);
        return;
    }

    if (gzwrite(f, save->data, save->size) != save->size)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Could not write data to state file: %s", save->filepath);
        gzclose(f);
        free(save->data);
        return;
    }

    gzclose(f);
    StateChanged(M64CORE_STATE_SAVECOMPLETE, 1);
    main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Saved state to: %s", namefrompath(save->filepath));
    free(save->data);
    free(save->filepath);
    free(save);

    SDL_UnlockMutex(savestates_lock);
}

static int savestates_save_m64p(char *filepath)
{
    unsigned char outbuf[4];
    int i;

    char queue[1024];
    int queuelength;

    struct savestate_work *save;
    char *curr;

    uint32_t* cp0_regs = r4300_cp0_regs();

    save = malloc(sizeof(*save));
    if (!save) {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Insufficient memory to save state.");
        return 0;
    }

    save->filepath = strdup(filepath);

    if(autoinc_save_slot)
        savestates_inc_slot();

    queuelength = save_eventqueue_infos(queue);

    // Allocate memory for the save state data
    save->size = 16788288 + queuelength;
    save->data = curr = malloc(save->size);
    if (save->data == NULL)
    {
        free(save->filepath);
        free(save);
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Insufficient memory to save state.");
        return 0;
    }

    // Write the save state data to memory
    PUTARRAY(savestate_magic, curr, unsigned char, 8);

    outbuf[0] = (savestate_latest_version >> 24) & 0xff;
    outbuf[1] = (savestate_latest_version >> 16) & 0xff;
    outbuf[2] = (savestate_latest_version >>  8) & 0xff;
    outbuf[3] = (savestate_latest_version >>  0) & 0xff;
    PUTARRAY(outbuf, curr, unsigned char, 4);

    PUTARRAY(ROM_SETTINGS.MD5, curr, char, 32);

    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_CONFIG_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_DEVICE_ID_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_DELAY_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_MODE_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_REF_INTERVAL_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_REF_ROW_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_RAS_INTERVAL_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_MIN_INTERVAL_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_ADDR_SELECT_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_DEVICE_MANUF_REG]);

    PUTDATA(curr, uint32_t, 0); // Padding from old implementation
    PUTDATA(curr, uint32_t, g_r4300.mi.regs[MI_INIT_MODE_REG]);
    PUTDATA(curr, uint8_t,  g_r4300.mi.regs[MI_INIT_MODE_REG] & 0x7F);
    PUTDATA(curr, uint8_t, (g_r4300.mi.regs[MI_INIT_MODE_REG] & 0x80) != 0);
    PUTDATA(curr, uint8_t, (g_r4300.mi.regs[MI_INIT_MODE_REG] & 0x100) != 0);
    PUTDATA(curr, uint8_t, (g_r4300.mi.regs[MI_INIT_MODE_REG] & 0x200) != 0);
    PUTDATA(curr, uint32_t, g_r4300.mi.regs[MI_VERSION_REG]);
    PUTDATA(curr, uint32_t, g_r4300.mi.regs[MI_INTR_REG]);
    PUTDATA(curr, uint32_t, g_r4300.mi.regs[MI_INTR_MASK_REG]);
    PUTDATA(curr, uint32_t, 0); //Padding from old implementation
    PUTDATA(curr, uint8_t, (g_r4300.mi.regs[MI_INTR_MASK_REG] & 0x1) != 0);
    PUTDATA(curr, uint8_t, (g_r4300.mi.regs[MI_INTR_MASK_REG] & 0x2) != 0);
    PUTDATA(curr, uint8_t, (g_r4300.mi.regs[MI_INTR_MASK_REG] & 0x4) != 0);
    PUTDATA(curr, uint8_t, (g_r4300.mi.regs[MI_INTR_MASK_REG] & 0x8) != 0);
    PUTDATA(curr, uint8_t, (g_r4300.mi.regs[MI_INTR_MASK_REG] & 0x10) != 0);
    PUTDATA(curr, uint8_t, (g_r4300.mi.regs[MI_INTR_MASK_REG] & 0x20) != 0);
    PUTDATA(curr, uint16_t, 0); // Padding from old implementation

    PUTDATA(curr, uint32_t, g_pi.regs[PI_DRAM_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_CART_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_RD_LEN_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_WR_LEN_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_STATUS_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM1_LAT_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM1_PWD_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM1_PGS_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM1_RLS_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM2_LAT_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM2_PWD_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM2_PGS_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM2_RLS_REG]);

    PUTDATA(curr, uint32_t, g_sp.regs[SP_MEM_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_DRAM_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_RD_LEN_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_WR_LEN_REG]);
    PUTDATA(curr, uint32_t, 0); /* Padding from old implementation */
    PUTDATA(curr, uint32_t, g_sp.regs[SP_STATUS_REG]);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x1) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x2) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x4) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x8) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x10) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x20) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x40) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x80) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x100) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x200) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x400) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x800) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x1000) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x2000) != 0);
    PUTDATA(curr, uint8_t, (g_sp.regs[SP_STATUS_REG] & 0x4000) != 0);
    PUTDATA(curr, uint8_t, 0);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_DMA_FULL_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_DMA_BUSY_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_SEMAPHORE_REG]);

    PUTDATA(curr, uint32_t, g_sp.regs2[SP_PC_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs2[SP_IBIST_REG]);

    PUTDATA(curr, uint32_t, g_si.regs[SI_DRAM_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_si.regs[SI_PIF_ADDR_RD64B_REG]);
    PUTDATA(curr, uint32_t, g_si.regs[SI_PIF_ADDR_WR64B_REG]);
    PUTDATA(curr, uint32_t, g_si.regs[SI_STATUS_REG]);

    PUTDATA(curr, uint32_t, g_vi.regs[VI_STATUS_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_ORIGIN_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_WIDTH_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_V_INTR_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_CURRENT_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_BURST_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_V_SYNC_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_H_SYNC_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_LEAP_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_H_START_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_V_START_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_V_BURST_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_X_SCALE_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_Y_SCALE_REG]);
    PUTDATA(curr, unsigned int, g_vi.delay);

    PUTDATA(curr, uint32_t, g_ri.regs[RI_MODE_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_CONFIG_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_CURRENT_LOAD_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_SELECT_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_REFRESH_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_LATENCY_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_ERROR_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_WERROR_REG]);

    PUTDATA(curr, uint32_t, g_ai.regs[AI_DRAM_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_ai.regs[AI_LEN_REG]);
    PUTDATA(curr, uint32_t, g_ai.regs[AI_CONTROL_REG]);
    PUTDATA(curr, uint32_t, g_ai.regs[AI_STATUS_REG]);
    PUTDATA(curr, uint32_t, g_ai.regs[AI_DACRATE_REG]);
    PUTDATA(curr, uint32_t, g_ai.regs[AI_BITRATE_REG]);
    PUTDATA(curr, unsigned int, g_ai.fifo[1].duration);
    PUTDATA(curr, uint32_t    , g_ai.fifo[1].length);
    PUTDATA(curr, unsigned int, g_ai.fifo[0].duration);
    PUTDATA(curr, uint32_t    , g_ai.fifo[0].length);

    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_START_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_END_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_CURRENT_REG]);
    PUTDATA(curr, uint32_t, 0); /* Padding from old implementation */
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_STATUS_REG]);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x1) != 0);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x2) != 0);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x4) != 0);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x8) != 0);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x10) != 0);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x20) != 0);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x40) != 0);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x80) != 0);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x100) != 0);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x200) != 0);
    PUTDATA(curr, uint8_t, (g_dp.dpc_regs[DPC_STATUS_REG] & 0x400) != 0);
    PUTDATA(curr, uint8_t, 0);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_CLOCK_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_BUFBUSY_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_PIPEBUSY_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_TMEM_REG]);

    PUTDATA(curr, uint32_t, g_dp.dps_regs[DPS_TBIST_REG]);
    PUTDATA(curr, uint32_t, g_dp.dps_regs[DPS_TEST_MODE_REG]);
    PUTDATA(curr, uint32_t, g_dp.dps_regs[DPS_BUFTEST_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_dp.dps_regs[DPS_BUFTEST_DATA_REG]);

    PUTARRAY(g_rdram, curr, uint32_t, RDRAM_MAX_SIZE/4);
    PUTARRAY(g_sp.mem, curr, uint32_t, SP_MEM_SIZE/4);
    PUTARRAY(g_si.pif.ram, curr, uint8_t, PIF_RAM_SIZE);

    PUTDATA(curr, int, g_pi.use_flashram);
    PUTDATA(curr, int, g_pi.flashram.mode);
    PUTDATA(curr, unsigned long long, g_pi.flashram.status);
    PUTDATA(curr, unsigned int, g_pi.flashram.erase_offset);
    PUTDATA(curr, unsigned int, g_pi.flashram.write_pointer);

    PUTARRAY(tlb_LUT_r, curr, unsigned int, 0x100000);
    PUTARRAY(tlb_LUT_w, curr, unsigned int, 0x100000);

    PUTDATA(curr, unsigned int, *r4300_llbit());
    PUTARRAY(r4300_regs(), curr, int64_t, 32);
    PUTARRAY(cp0_regs, curr, uint32_t, CP0_REGS_COUNT);
    PUTDATA(curr, int64_t, *r4300_mult_lo());
    PUTDATA(curr, int64_t, *r4300_mult_hi());

    if ((cp0_regs[CP0_STATUS_REG] & UINT32_C(0x04000000)) == 0) // FR bit == 0 means 32-bit (MIPS I) FGR mode
        shuffle_fpr_data(0, UINT32_C(0x04000000));  // shuffle data into 64-bit register format for storage
    PUTARRAY(r4300_cp1_regs(), curr, int64_t, 32);
    if ((cp0_regs[CP0_STATUS_REG] & UINT32_C(0x04000000)) == 0)
        shuffle_fpr_data(UINT32_C(0x04000000), 0);  // put it back in 32-bit mode

    PUTDATA(curr, uint32_t, *r4300_cp1_fcr0());
    PUTDATA(curr, uint32_t, *r4300_cp1_fcr31());
    for (i = 0; i < 32; i++)
    {
        PUTDATA(curr, short, tlb_e[i].mask);
        PUTDATA(curr, short, 0);
        PUTDATA(curr, int, tlb_e[i].vpn2);
        PUTDATA(curr, char, tlb_e[i].g);
        PUTDATA(curr, unsigned char, tlb_e[i].asid);
        PUTDATA(curr, short, 0);
        PUTDATA(curr, int, tlb_e[i].pfn_even);
        PUTDATA(curr, char, tlb_e[i].c_even);
        PUTDATA(curr, char, tlb_e[i].d_even);
        PUTDATA(curr, char, tlb_e[i].v_even);
        PUTDATA(curr, char, 0);
        PUTDATA(curr, int, tlb_e[i].pfn_odd);
        PUTDATA(curr, char, tlb_e[i].c_odd);
        PUTDATA(curr, char, tlb_e[i].d_odd);
        PUTDATA(curr, char, tlb_e[i].v_odd);
        PUTDATA(curr, char, tlb_e[i].r);
   
        PUTDATA(curr, unsigned int, tlb_e[i].start_even);
        PUTDATA(curr, unsigned int, tlb_e[i].end_even);
        PUTDATA(curr, unsigned int, tlb_e[i].phys_even);
        PUTDATA(curr, unsigned int, tlb_e[i].start_odd);
        PUTDATA(curr, unsigned int, tlb_e[i].end_odd);
        PUTDATA(curr, unsigned int, tlb_e[i].phys_odd);
    }
    PUTDATA(curr, uint32_t, *r4300_pc());

    PUTDATA(curr, unsigned int, *r4300_next_interrupt());
    PUTDATA(curr, unsigned int, g_vi.next_vi);
    PUTDATA(curr, unsigned int, g_vi.field);

    to_little_endian_buffer(queue, 4, queuelength/4);
    PUTARRAY(queue, curr, char, queuelength);

    // assert(curr == save->data + save->size)

    init_work(&save->work, savestates_save_m64p_work);
    queue_work(&save->work);

    return 1;
}

static int savestates_save_pj64(char *filepath, void *handle,
                                int (*write_func)(void *, const void *, size_t))
{
    unsigned int i;
    unsigned int SaveRDRAMSize = RDRAM_MAX_SIZE;

    size_t savestateSize;
    unsigned char *savestateData, *curr;

    uint32_t* cp0_regs = r4300_cp0_regs();

    // Allocate memory for the save state data
    savestateSize = 8 + SaveRDRAMSize + 0x2754;
    savestateData = curr = (unsigned char *)malloc(savestateSize);
    if (savestateData == NULL)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Insufficient memory to save state.");
        return 0;
    }

    // Write the save state data in memory
    PUTARRAY(pj64_magic, curr, unsigned char, 4);
    PUTDATA(curr, unsigned int, SaveRDRAMSize);
    PUTARRAY(g_rom, curr, unsigned int, 0x40/4);
    PUTDATA(curr, uint32_t, get_event(VI_INT) - cp0_regs[CP0_COUNT_REG]); // vi_timer
    PUTDATA(curr, uint32_t, *r4300_pc());
    PUTARRAY(r4300_regs(), curr, int64_t, 32);
    if ((cp0_regs[CP0_STATUS_REG] & UINT32_C(0x04000000)) == 0) // TODO not sure how pj64 handles this
        shuffle_fpr_data(UINT32_C(0x04000000), 0);
    PUTARRAY(r4300_cp1_regs(), curr, int64_t, 32);
    if ((cp0_regs[CP0_STATUS_REG] & UINT32_C(0x04000000)) == 0) // TODO not sure how pj64 handles this
        shuffle_fpr_data(UINT32_C(0x04000000), 0);
    PUTARRAY(cp0_regs, curr, uint32_t, CP0_REGS_COUNT);
    PUTDATA(curr, uint32_t, *r4300_cp1_fcr0());
    for (i = 0; i < 30; i++)
        PUTDATA(curr, int, 0); // FCR1-30 not implemented
    PUTDATA(curr, uint32_t, *r4300_cp1_fcr31());
    PUTDATA(curr, int64_t, *r4300_mult_hi());
    PUTDATA(curr, int64_t, *r4300_mult_lo());

    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_CONFIG_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_DEVICE_ID_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_DELAY_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_MODE_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_REF_INTERVAL_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_REF_ROW_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_RAS_INTERVAL_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_MIN_INTERVAL_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_ADDR_SELECT_REG]);
    PUTDATA(curr, uint32_t, g_ri.rdram.regs[RDRAM_DEVICE_MANUF_REG]);

    PUTDATA(curr, uint32_t, g_sp.regs[SP_MEM_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_DRAM_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_RD_LEN_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_WR_LEN_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_STATUS_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_DMA_FULL_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_DMA_BUSY_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs[SP_SEMAPHORE_REG]);

    PUTDATA(curr, uint32_t, g_sp.regs2[SP_PC_REG]);
    PUTDATA(curr, uint32_t, g_sp.regs2[SP_IBIST_REG]);

    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_START_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_END_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_CURRENT_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_STATUS_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_CLOCK_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_BUFBUSY_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_PIPEBUSY_REG]);
    PUTDATA(curr, uint32_t, g_dp.dpc_regs[DPC_TMEM_REG]);
    PUTDATA(curr, unsigned int, 0); // ?
    PUTDATA(curr, unsigned int, 0); // ?

    PUTDATA(curr, uint32_t, g_r4300.mi.regs[MI_INIT_MODE_REG]); //TODO Secial handling in pj64
    PUTDATA(curr, uint32_t, g_r4300.mi.regs[MI_VERSION_REG]);
    PUTDATA(curr, uint32_t, g_r4300.mi.regs[MI_INTR_REG]);
    PUTDATA(curr, uint32_t, g_r4300.mi.regs[MI_INTR_MASK_REG]);

    PUTDATA(curr, uint32_t, g_vi.regs[VI_STATUS_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_ORIGIN_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_WIDTH_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_V_INTR_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_CURRENT_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_BURST_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_V_SYNC_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_H_SYNC_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_LEAP_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_H_START_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_V_START_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_V_BURST_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_X_SCALE_REG]);
    PUTDATA(curr, uint32_t, g_vi.regs[VI_Y_SCALE_REG]);

    PUTDATA(curr, uint32_t, g_ai.regs[AI_DRAM_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_ai.regs[AI_LEN_REG]);
    PUTDATA(curr, uint32_t, g_ai.regs[AI_CONTROL_REG]);
    PUTDATA(curr, uint32_t, g_ai.regs[AI_STATUS_REG]);
    PUTDATA(curr, uint32_t, g_ai.regs[AI_DACRATE_REG]);
    PUTDATA(curr, uint32_t, g_ai.regs[AI_BITRATE_REG]);

    PUTDATA(curr, uint32_t, g_pi.regs[PI_DRAM_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_CART_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_RD_LEN_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_WR_LEN_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_STATUS_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM1_LAT_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM1_PWD_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM1_PGS_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM1_RLS_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM2_LAT_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM2_PWD_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM2_PGS_REG]);
    PUTDATA(curr, uint32_t, g_pi.regs[PI_BSD_DOM2_RLS_REG]);

    PUTDATA(curr, uint32_t, g_ri.regs[RI_MODE_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_CONFIG_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_CURRENT_LOAD_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_SELECT_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_REFRESH_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_LATENCY_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_ERROR_REG]);
    PUTDATA(curr, uint32_t, g_ri.regs[RI_WERROR_REG]);

    PUTDATA(curr, uint32_t, g_si.regs[SI_DRAM_ADDR_REG]);
    PUTDATA(curr, uint32_t, g_si.regs[SI_PIF_ADDR_RD64B_REG]);
    PUTDATA(curr, uint32_t, g_si.regs[SI_PIF_ADDR_WR64B_REG]);
    PUTDATA(curr, uint32_t, g_si.regs[SI_STATUS_REG]);

    for (i=0; i < 32;i++)
    {
        // From TLBR
        unsigned int EntryDefined, MyPageMask, MyEntryHi, MyEntryLo0, MyEntryLo1;
        EntryDefined = tlb_e[i].v_even || tlb_e[i].v_odd;
        MyPageMask = tlb_e[i].mask << 13;
        MyEntryHi = ((tlb_e[i].vpn2 << 13) | tlb_e[i].asid);
        MyEntryLo0 = (tlb_e[i].pfn_even << 6) | (tlb_e[i].c_even << 3)
         | (tlb_e[i].d_even << 2) | (tlb_e[i].v_even << 1)
           | tlb_e[i].g;
        MyEntryLo1 = (tlb_e[i].pfn_odd << 6) | (tlb_e[i].c_odd << 3)
         | (tlb_e[i].d_odd << 2) | (tlb_e[i].v_odd << 1)
           | tlb_e[i].g;

        PUTDATA(curr, unsigned int, EntryDefined);
        PUTDATA(curr, unsigned int, MyPageMask);
        PUTDATA(curr, unsigned int, MyEntryHi);
        PUTDATA(curr, unsigned int, MyEntryLo0);
        PUTDATA(curr, unsigned int, MyEntryLo1);
    }

    PUTARRAY(g_si.pif.ram, curr, uint8_t, PIF_RAM_SIZE);

    PUTARRAY(g_rdram, curr, uint32_t, SaveRDRAMSize/4);
    PUTARRAY(g_sp.mem, curr, uint32_t, SP_MEM_SIZE/4);

    // Write the save state data to the output
    if (!write_func(handle, savestateData, savestateSize))
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Couldn't write data to Project64 state file %s.", filepath);
        free(savestateData);
        return 0;
    }

    // assert(savestateData+savestateSize == curr)
    free(savestateData);
    return 1;
}

static int write_data_to_zip(void *zip, const void *buffer, size_t length)
{
    return zipWriteInFileInZip((zipFile)zip, buffer, (unsigned)length) == ZIP_OK;
}

static int savestates_save_pj64_zip(char *filepath)
{
    int retval;
    zipFile zipfile = NULL;

    zipfile = zipOpen(filepath, APPEND_STATUS_CREATE);
    if(zipfile == NULL)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Could not create PJ64 state file: %s", filepath);
        goto clean_and_exit;
    }

    retval = zipOpenNewFileInZip(zipfile, namefrompath(filepath), NULL, NULL, 0, NULL, 0, NULL, Z_DEFLATED, Z_DEFAULT_COMPRESSION);
    if(retval != ZIP_OK)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Zip error. Could not create state file: %s", filepath);
        goto clean_and_exit;
    }

    if (!savestates_save_pj64(filepath, zipfile, write_data_to_zip))
        goto clean_and_exit;

    main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Saved state to: %s", namefrompath(filepath));

    clean_and_exit:
        if (zipfile != NULL)
        {
            zipCloseFileInZip(zipfile); // This may fail, but we don't care
            zipClose(zipfile, "");
        }
        return 1;
}

static int write_data_to_file(void *file, const void *buffer, size_t length)
{
    return fwrite(buffer, 1, length, (FILE *)file) == length;
}

static int savestates_save_pj64_unc(char *filepath)
{
    FILE *f;

    f = fopen(filepath, "wb");
    if (f == NULL)
    {
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Could not create PJ64 state file: %s", filepath);
        return 0;
    }

    if (!savestates_save_pj64(filepath, f, write_data_to_file))
    {
        fclose(f);
        return 0;
    }

    main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "Saved state to: %s", namefrompath(filepath));
    fclose(f);
    return 1;
}

int savestates_save(void)
{
    char *filepath;
    int ret = 0;

    /* Can only save PJ64 savestates on VI / COMPARE interrupt.
       Otherwise try again in a little while. */
    if ((type == savestates_type_pj64_zip ||
         type == savestates_type_pj64_unc) &&
        get_next_event_type() > COMPARE_INT)
        return 0;

    if (fname != NULL && type == savestates_type_unknown)
        type = savestates_type_m64p;
    else if (fname == NULL) // Always save slots in M64P format
        type = savestates_type_m64p;

    filepath = savestates_generate_path(type);
    if (filepath != NULL)
    {
        switch (type)
        {
            case savestates_type_m64p: ret = savestates_save_m64p(filepath); break;
            case savestates_type_pj64_zip: ret = savestates_save_pj64_zip(filepath); break;
            case savestates_type_pj64_unc: ret = savestates_save_pj64_unc(filepath); break;
            default: ret = 0; break;
        }
        free(filepath);
    }

    // deliver callback to indicate completion of state saving operation
    //StateChanged(M64CORE_STATE_SAVECOMPLETE, ret);

    savestates_clear_job();
    return ret;
}

void savestates_init(void)
{
    savestates_lock = SDL_CreateMutex();
    if (!savestates_lock) {
        DebugMessage(M64MSG_ERROR, "Could not create savestates list lock");
        return;
    }
}

void savestates_deinit(void)
{
    SDL_DestroyMutex(savestates_lock);
    savestates_clear_job();
}
