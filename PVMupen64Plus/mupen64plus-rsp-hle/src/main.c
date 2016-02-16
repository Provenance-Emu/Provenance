/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-rsp-hle - main.c                                          *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
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

#include <stdarg.h>
#include <string.h>
#include <stdio.h>

#define M64P_PLUGIN_PROTOTYPES 1
#include "m64p_types.h"
#include "m64p_common.h"
#include "m64p_plugin.h"
#include "hle.h"
#include "alist.h"
#include "cicx105.h"
#include "jpeg.h"

#define min(a,b) (((a) < (b)) ? (a) : (b))

/* some rsp status flags */
#define RSP_STATUS_HALT             0x1
#define RSP_STATUS_BROKE            0x2
#define RSP_STATUS_INTR_ON_BREAK    0x40
#define RSP_STATUS_TASKDONE         0x200

/* some rdp status flags */
#define DP_STATUS_FREEZE            0x2

/* some mips interface interrupt flags */
#define MI_INTR_SP                  0x1


/* helper functions prototypes */
static unsigned int sum_bytes(const unsigned char *bytes, unsigned int size);
static void dump_binary(const char * const filename, const unsigned char * const bytes,
                        unsigned int size);
static void dump_task(const char * const filename, const OSTask_t * const task);

static void handle_unknown_task(unsigned int sum);
static void handle_unknown_non_task(unsigned int sum);

/* global variables */
RSP_INFO rsp;

/* local variables */
static const int FORWARD_AUDIO = 0, FORWARD_GFX = 1;
static void (*l_DebugCallback)(void *, int, const char *) = NULL;
static void *l_DebugCallContext = NULL;
static int l_PluginInit = 0;

/* local functions */


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
static int is_task()
{
    return (get_task()->ucode_boot_size <= 0x1000);
}

static void rsp_break(unsigned int setbits)
{
    *rsp.SP_STATUS_REG |= setbits | RSP_STATUS_BROKE | RSP_STATUS_HALT;

    if ((*rsp.SP_STATUS_REG & RSP_STATUS_INTR_ON_BREAK))
    {
        *rsp.MI_INTR_REG |= MI_INTR_SP;
        rsp.CheckInterrupts();
    }
}

static void forward_gfx_task()
{
    if (rsp.ProcessDlistList != NULL)
    {
        rsp.ProcessDlistList();
        *rsp.DPC_STATUS_REG &= ~DP_STATUS_FREEZE;
    }
}

static void forward_audio_task()
{
    if (rsp.ProcessAlistList != NULL)
    {
        rsp.ProcessAlistList();
    }
}

static void show_cfb()
{
    if (rsp.ShowCFB != NULL)
    {
        rsp.ShowCFB();
    }
}

static int try_fast_audio_dispatching()
{
    /* identify audio ucode by using the content of ucode_data */
    const OSTask_t * const task = get_task();
    const unsigned char * const udata_ptr = rsp.RDRAM + task->ucode_data;

    if (*(unsigned int*)(udata_ptr + 0) == 0x00000001)
    {
        if (*(unsigned int*)(udata_ptr + 0x30) == 0xf0000f00)
        {
            /**
            * Many games including:
            * Super Mario 64, Diddy Kong Racing, BlastCorp, GoldenEye, ... (most common)
            **/
            alist_process_ABI1(); return 1;
        }
        else
        {
            /**
            * Mario Kart / Wave Race,
            * LylatWars,
            * FZeroX,
            * Yoshi Story,
            * 1080 Snowboarding,
            * Zelda Ocarina of Time,
            * Zelda Majoras Mask / Pokemon Stadium 2,
            * Animal Crossing
            *
            * FIXME: in fact, all these games do not share the same ABI.
            * That's the reason of the workaround in ucode2.cpp with isZeldaABI and isMKABI
            **/
            alist_process_ABI2(); return 1;
        }
    }
    else
    {
        if (*(unsigned int*)(udata_ptr + 0x10) == 0x00000001)
        {
            /**
             * Musyx ucode found in following games:
             * RogueSquadron, ResidentEvil2, SnowCrossPolaris, TheWorldIsNotEnough,
             * RugratsInParis, NBAShowTime, HydroThunder, Tarzan,
             * GauntletLegend, Rush2049, IndianaJones, BattleForNaboo
             * TODO: implement ucode
             **/
            DebugMessage(M64MSG_WARNING, "MusyX ucode not implemented.");
            /* return 1; */
        }
        else
        {
            /**
             * Many games including:
             * Pokemon Stadium, Banjo Kazooie, Donkey Kong, Banjo Tooie, Jet Force Gemini,
             * Mickey SpeedWay USA, Perfect Dark, Conker Bad Fur Day ...
             **/
            alist_process_ABI3(); return 1;
        }
    }
    
    return 0;
}

static int try_fast_task_dispatching()
{
    /* identify task ucode by its type */
    const OSTask_t * const task = get_task();

    switch (task->type)
    {
        case 1: if (FORWARD_GFX) { forward_gfx_task(); return 1; } break;

        case 2:
            if (FORWARD_AUDIO) { forward_audio_task(); return 1; }
            else if (try_fast_audio_dispatching()) { return 1; }
            break;

        case 7: show_cfb(); return 1;
    }

    return 0;
}

static void normal_task_dispatching()
{
    const OSTask_t * const task = get_task();
    const unsigned int sum =
        sum_bytes(rsp.RDRAM + task->ucode, min(task->ucode_size, 0xf80) >> 1);

    switch (sum)
    {
        /* StoreVe12: found in Zelda Ocarina of Time [misleading task->type == 4] */
        case 0x278: /* Nothing to emulate */ return;

        /* GFX: Twintris [misleading task->type == 0] */                                         
        case 0x212ee:
            if (FORWARD_GFX) { forward_gfx_task(); return; }
            break;

        /* JPEG: found in Pokemon Stadium J */ 
        case 0x2c85a: jpeg_decode_PS0(); return;

        /* JPEG: found in Zelda Ocarina of Time, Pokemon Stadium 1, Pokemon Stadium 2 */
        case 0x2caa6: jpeg_decode_PS(); return;

        /* JPEG: found in Ogre Battle, Bottom of the 9th */
        case 0x130de: jpeg_decode_OB(); return;
    }

    handle_unknown_task(sum);
}

static void non_task_dispatching()
{
    const unsigned int sum = sum_bytes(rsp.IMEM, 0x1000 >> 1);

    switch(sum)
    {
        /* CIC x105 ucode (used during boot of CIC x105 games) */
        case 0x9e2: /* CIC 6105 */
        case 0x9f2: /* CIC 7105 */
            cicx105_ucode(); return;
    }

    handle_unknown_non_task(sum);
}

static void handle_unknown_task(unsigned int sum)
{
    char filename[256];
    const OSTask_t * const task = get_task();

    DebugMessage(M64MSG_WARNING, "unknown OSTask: sum %x PC:%x", sum, *rsp.SP_PC_REG);

    sprintf(&filename[0], "task_%x.log", sum);
    dump_task(filename, task);
    
    // dump ucode_boot
    sprintf(&filename[0], "ucode_boot_%x.bin", sum);
    dump_binary(filename, rsp.RDRAM + (task->ucode_boot & 0x7fffff), task->ucode_boot_size);

    // dump ucode
    if (task->ucode != 0)
    {
        sprintf(&filename[0], "ucode_%x.bin", sum);
        dump_binary(filename, rsp.RDRAM + (task->ucode & 0x7fffff), 0xf80);
    }

    // dump ucode_data
    if (task->ucode_data != 0)
    {
        sprintf(&filename[0], "ucode_data_%x.bin", sum);
        dump_binary(filename, rsp.RDRAM + (task->ucode_data & 0x7fffff), task->ucode_data_size);
    }

    // dump data
    if (task->data_ptr != 0)
    {
        sprintf(&filename[0], "data_%x.bin", sum);
        dump_binary(filename, rsp.RDRAM + (task->data_ptr & 0x7fffff), task->data_size);
    }
}

static void handle_unknown_non_task(unsigned int sum)
{
    char filename[256];

    DebugMessage(M64MSG_WARNING, "unknown RSP code: sum: %x PC:%x", sum, *rsp.SP_PC_REG);

    // dump IMEM & DMEM for further analysis
    sprintf(&filename[0], "imem_%x.bin", sum);
    dump_binary(filename, rsp.IMEM, 0x1000);

    sprintf(&filename[0], "dmem_%x.bin", sum);
    dump_binary(filename, rsp.DMEM, 0x1000);
}


/* Global functions */
void DebugMessage(int level, const char *message, ...)
{
    char msgbuf[1024];
    va_list args;

    if (l_DebugCallback == NULL)
        return;

    va_start(args, message);
    vsprintf(msgbuf, message, args);

    (*l_DebugCallback)(l_DebugCallContext, level, msgbuf);

    va_end(args);
}

/* DLL-exported functions */
EXPORT m64p_error CALL PluginStartup(m64p_dynlib_handle CoreLibHandle, void *Context,
                                   void (*DebugCallback)(void *, int, const char *))
{
    if (l_PluginInit)
        return M64ERR_ALREADY_INIT;

    /* first thing is to set the callback function for debug info */
    l_DebugCallback = DebugCallback;
    l_DebugCallContext = Context;

    /* this plugin doesn't use any Core library functions (ex for Configuration), so no need to keep the CoreLibHandle */

    l_PluginInit = 1;
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL PluginShutdown(void)
{
    if (!l_PluginInit)
        return M64ERR_NOT_INIT;

    /* reset some local variable */
    l_DebugCallback = NULL;
    l_DebugCallContext = NULL;

    l_PluginInit = 0;
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL PluginGetVersion(m64p_plugin_type *PluginType, int *PluginVersion, int *APIVersion, const char **PluginNamePtr, int *Capabilities)
{
    /* set version info */
    if (PluginType != NULL)
        *PluginType = M64PLUGIN_RSP;

    if (PluginVersion != NULL)
        *PluginVersion = RSP_HLE_VERSION;

    if (APIVersion != NULL)
        *APIVersion = RSP_PLUGIN_API_VERSION;
    
    if (PluginNamePtr != NULL)
        *PluginNamePtr = "Hacktarux/Azimer High-Level Emulation RSP Plugin";

    if (Capabilities != NULL)
    {
        *Capabilities = 0;
    }
                    
    return M64ERR_SUCCESS;
}

EXPORT unsigned int CALL DoRspCycles(unsigned int Cycles)
{
    if (is_task())
    {
        if (!try_fast_task_dispatching()) { normal_task_dispatching(); }
        rsp_break(RSP_STATUS_TASKDONE);
    }
    else
    {
        non_task_dispatching();
        rsp_break(0);
    }

    return Cycles;
}

EXPORT void CALL InitiateRSP(RSP_INFO Rsp_Info, unsigned int *CycleCount)
{
    rsp = Rsp_Info;
}

EXPORT void CALL RomClosed(void)
{
    memset(rsp.DMEM, 0, 0x1000);
    memset(rsp.IMEM, 0, 0x1000);

    init_ucode2();
}


/* local helper functions */
static unsigned int sum_bytes(const unsigned char *bytes, unsigned int size)
{
    unsigned int sum = 0;
    const unsigned char * const bytes_end = bytes + size;

    while (bytes != bytes_end)
        sum += *bytes++;

    return sum;
}


static void dump_binary(const char * const filename, const unsigned char * const bytes,
                        unsigned int size)
{
    FILE *f;

    // if file already exists, do nothing
    f = fopen(filename, "r");
    if (f == NULL)
    {
        // else we write bytes to the file
        f= fopen(filename, "wb");
        if (f != NULL) {
            if (fwrite(bytes, 1, size, f) != size)
            {
                DebugMessage(M64MSG_ERROR, "Writing error on %s", filename);
            }
            fclose(f);
        }
        else
        {
            DebugMessage(M64MSG_ERROR, "Couldn't open %s for writing !", filename);
        }
    }
    else
    {
        fclose(f);
    }
}

static void dump_task(const char * const filename, const OSTask_t * const task)
{
    FILE *f;

    f = fopen(filename, "r");
    if (f == NULL)
    {
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
            task->type, task->flags,
            task->ucode_boot, task->ucode_boot_size,
            task->ucode, task->ucode_size,
            task->ucode_data, task->ucode_data_size,
            task->dram_stack, task->dram_stack_size,
            task->output_buff, task->output_buff_size,
            task->data_ptr, task->data_size,
            task->yield_data_ptr, task->yield_data_size);
        fclose(f);
    }
    else
    {
        fclose(f);
    }
}

