/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - memory.c                                                *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
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

#include "memory.h"

#include "ai/ai_controller.h"
#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "main/main.h"
#include "main/rom.h"
#include "pi/pi_controller.h"
#include "r4300/new_dynarec/new_dynarec.h"
#include "r4300/r4300_core.h"
#include "rdp/rdp_core.h"
#include "ri/ri_controller.h"
#include "rsp/rsp_core.h"
#include "si/si_controller.h"
#include "vi/vi_controller.h"

#ifdef DBG
#include <string.h>

#include "debugger/dbg_breakpoints.h"
#include "debugger/dbg_memory.h"
#include "debugger/dbg_types.h"
#endif

#include <stddef.h>
#include <stdint.h>

extern int fast_memory;

#if NEW_DYNAREC != NEW_DYNAREC_ARM
// address : address of the read/write operation being done
uint32_t address = 0;
#endif

// values that are being written are stored in these variables
#if NEW_DYNAREC != NEW_DYNAREC_ARM
uint32_t cpu_word;
uint8_t cpu_byte;
uint16_t cpu_hword;
uint64_t cpu_dword;
#endif

// addresse where the read value will be stored
uint64_t* rdword;

// hash tables of read functions
void (*readmem[0x10000])(void);
void (*readmemb[0x10000])(void);
void (*readmemh[0x10000])(void);
void (*readmemd[0x10000])(void);

// hash tables of write functions
void (*writemem[0x10000])(void);
void (*writememb[0x10000])(void);
void (*writememd[0x10000])(void);
void (*writememh[0x10000])(void);

typedef int (*readfn)(void*,uint32_t,uint32_t*);
typedef int (*writefn)(void*,uint32_t,uint32_t,uint32_t);

static unsigned int bshift(uint32_t address)
{
    return ((address & 3) ^ 3) << 3;
}

static unsigned int hshift(uint32_t address)
{
    return ((address & 2) ^ 2) << 3;
}

static int readb(readfn read_word, void* opaque, uint32_t address, uint64_t* value)
{
    uint32_t w;
    unsigned shift = bshift(address);
    int result = read_word(opaque, address, &w);
    *value = (w >> shift) & 0xff;

    return result;
}

static int readh(readfn read_word, void* opaque, uint32_t address, uint64_t* value)
{
    uint32_t w;
    unsigned shift = hshift(address);
    int result = read_word(opaque, address, &w);
    *value = (w >> shift) & 0xffff;

    return result;
}

static int readw(readfn read_word, void* opaque, uint32_t address, uint64_t* value)
{
    uint32_t w;
    int result = read_word(opaque, address, &w);
    *value = w;

    return result;
}

static int readd(readfn read_word, void* opaque, uint32_t address, uint64_t* value)
{
    uint32_t w[2];
    int result =
    read_word(opaque, address    , &w[0]);
    read_word(opaque, address + 4, &w[1]);
    *value = ((uint64_t)w[0] << 32) | w[1];

    return result;
}

static int writeb(writefn write_word, void* opaque, uint32_t address, uint8_t value)
{
    unsigned int shift = bshift(address);
    uint32_t w = (uint32_t)value << shift;
    uint32_t mask = (uint32_t)0xff << shift;

    return write_word(opaque, address, w, mask);
}

static int writeh(writefn write_word, void* opaque, uint32_t address, uint16_t value)
{
    unsigned int shift = hshift(address);
    uint32_t w = (uint32_t)value << shift;
    uint32_t mask = (uint32_t)0xffff << shift;

    return write_word(opaque, address, w, mask);
}

static int writew(writefn write_word, void* opaque, uint32_t address, uint32_t value)
{
    return write_word(opaque, address, value, ~0U);
}

static int writed(writefn write_word, void* opaque, uint32_t address, uint64_t value)
{
    int result =
    write_word(opaque, address    , (uint32_t) (value >> 32), ~0U);
    write_word(opaque, address + 4, (uint32_t) (value      ), ~0U);

    return result;
}


static void read_nothing(void)
{
    *rdword = 0;
}

static void read_nothingb(void)
{
    *rdword = 0;
}

static void read_nothingh(void)
{
    *rdword = 0;
}

static void read_nothingd(void)
{
    *rdword = 0;
}

static void write_nothing(void)
{
}

static void write_nothingb(void)
{
}

static void write_nothingh(void)
{
}

static void write_nothingd(void)
{
}

static void read_nomem(void)
{
    address = virtual_to_physical_address(address,0);
    if (address == 0x00000000) return;
    read_word_in_memory();
}

static void read_nomemb(void)
{
    address = virtual_to_physical_address(address,0);
    if (address == 0x00000000) return;
    read_byte_in_memory();
}

static void read_nomemh(void)
{
    address = virtual_to_physical_address(address,0);
    if (address == 0x00000000) return;
    read_hword_in_memory();
}

static void read_nomemd(void)
{
    address = virtual_to_physical_address(address,0);
    if (address == 0x00000000) return;
    read_dword_in_memory();
}

static void write_nomem(void)
{
    invalidate_r4300_cached_code(address, 4);
    address = virtual_to_physical_address(address,1);
    if (address == 0x00000000) return;
    write_word_in_memory();
}

static void write_nomemb(void)
{
    invalidate_r4300_cached_code(address, 1);
    address = virtual_to_physical_address(address,1);
    if (address == 0x00000000) return;
    write_byte_in_memory();
}

static void write_nomemh(void)
{
    invalidate_r4300_cached_code(address, 2);
    address = virtual_to_physical_address(address,1);
    if (address == 0x00000000) return;
    write_hword_in_memory();
}

static void write_nomemd(void)
{
    invalidate_r4300_cached_code(address, 8);
    address = virtual_to_physical_address(address,1);
    if (address == 0x00000000) return;
    write_dword_in_memory();
}


void read_rdram(void)
{
    readw(read_rdram_dram, &g_ri, address, rdword);
}

void read_rdramb(void)
{
    readb(read_rdram_dram, &g_ri, address, rdword);
}

void read_rdramh(void)
{
    readh(read_rdram_dram, &g_ri, address, rdword);
}

void read_rdramd(void)
{
    readd(read_rdram_dram, &g_ri, address, rdword);
}

void write_rdram(void)
{
    writew(write_rdram_dram, &g_ri, address, cpu_word);
}

void write_rdramb(void)
{
    writeb(write_rdram_dram, &g_ri, address, cpu_byte);
}

void write_rdramh(void)
{
    writeh(write_rdram_dram, &g_ri, address, cpu_hword);
}

void write_rdramd(void)
{
    writed(write_rdram_dram, &g_ri, address, cpu_dword);
}


void read_rdramFB(void)
{
    readw(read_rdram_fb, &g_dp, address, rdword);
}

void read_rdramFBb(void)
{
    readb(read_rdram_fb, &g_dp, address, rdword);
}

void read_rdramFBh(void)
{
    readh(read_rdram_fb, &g_dp, address, rdword);
}

void read_rdramFBd(void)
{
    readd(read_rdram_fb, &g_dp, address, rdword);
}

void write_rdramFB(void)
{
    writew(write_rdram_fb, &g_dp, address, cpu_word);
}

void write_rdramFBb(void)
{
    writeb(write_rdram_fb, &g_dp, address, cpu_byte);
}

void write_rdramFBh(void)
{
    writeh(write_rdram_fb, &g_dp, address, cpu_hword);
}

void write_rdramFBd(void)
{
    writed(write_rdram_fb, &g_dp, address, cpu_dword);
}


static void read_rdramreg(void)
{
    readw(read_rdram_regs, &g_ri, address, rdword);
}

static void read_rdramregb(void)
{
    readb(read_rdram_regs, &g_ri, address, rdword);
}

static void read_rdramregh(void)
{
    readh(read_rdram_regs, &g_ri, address, rdword);
}

static void read_rdramregd(void)
{
    readd(read_rdram_regs, &g_ri, address, rdword);
}

static void write_rdramreg(void)
{
    writew(write_rdram_regs, &g_ri, address, cpu_word);
}

static void write_rdramregb(void)
{
    writeb(write_rdram_regs, &g_ri, address, cpu_byte);
}

static void write_rdramregh(void)
{
    writeh(write_rdram_regs, &g_ri, address, cpu_hword);
}

static void write_rdramregd(void)
{
    writed(write_rdram_regs, &g_ri, address, cpu_dword);
}


static void read_rspmem(void)
{
    readw(read_rsp_mem, &g_sp, address, rdword);
}

static void read_rspmemb(void)
{
    readb(read_rsp_mem, &g_sp, address, rdword);
}

static void read_rspmemh(void)
{
    readh(read_rsp_mem, &g_sp, address, rdword);
}

static void read_rspmemd(void)
{
    readd(read_rsp_mem, &g_sp, address, rdword);
}

static void write_rspmem(void)
{
    writew(write_rsp_mem, &g_sp, address, cpu_word);
}

static void write_rspmemb(void)
{
    writeb(write_rsp_mem, &g_sp, address, cpu_byte);
}

static void write_rspmemh(void)
{
    writeh(write_rsp_mem, &g_sp, address, cpu_hword);
}

static void write_rspmemd(void)
{
    writed(write_rsp_mem, &g_sp, address, cpu_dword);
}


static void read_rspreg(void)
{
    readw(read_rsp_regs, &g_sp, address, rdword);
}

static void read_rspregb(void)
{
    readb(read_rsp_regs, &g_sp, address, rdword);
}

static void read_rspregh(void)
{
    readh(read_rsp_regs, &g_sp, address, rdword);
}

static void read_rspregd(void)
{
    readd(read_rsp_regs, &g_sp, address, rdword);
}

static void write_rspreg(void)
{
    writew(write_rsp_regs, &g_sp, address, cpu_word);
}

static void write_rspregb(void)
{
    writeb(write_rsp_regs, &g_sp, address, cpu_byte);
}

static void write_rspregh(void)
{
    writeh(write_rsp_regs, &g_sp, address, cpu_hword);
}

static void write_rspregd(void)
{
    writed(write_rsp_regs, &g_sp, address, cpu_dword);
}


static void read_rspreg2(void)
{
    readw(read_rsp_regs2, &g_sp, address, rdword);
}

static void read_rspreg2b(void)
{
    readb(read_rsp_regs2, &g_sp, address, rdword);
}

static void read_rspreg2h(void)
{
    readh(read_rsp_regs2, &g_sp, address, rdword);
}

static void read_rspreg2d(void)
{
    readd(read_rsp_regs2, &g_sp, address, rdword);
}

static void write_rspreg2(void)
{
    writew(write_rsp_regs2, &g_sp, address, cpu_word);
}

static void write_rspreg2b(void)
{
    writeb(write_rsp_regs2, &g_sp, address, cpu_byte);
}

static void write_rspreg2h(void)
{
    writeh(write_rsp_regs2, &g_sp, address, cpu_hword);
}

static void write_rspreg2d(void)
{
    writed(write_rsp_regs2, &g_sp, address, cpu_dword);
}


static void read_dp(void)
{
    readw(read_dpc_regs, &g_dp, address, rdword);
}

static void read_dpb(void)
{
    readb(read_dpc_regs, &g_dp, address, rdword);
}

static void read_dph(void)
{
    readh(read_dpc_regs, &g_dp, address, rdword);
}

static void read_dpd(void)
{
    readd(read_dpc_regs, &g_dp, address, rdword);
}

static void write_dp(void)
{
    writew(write_dpc_regs, &g_dp, address, cpu_word);
}

static void write_dpb(void)
{
    writeb(write_dpc_regs, &g_dp, address, cpu_byte);
}

static void write_dph(void)
{
    writeh(write_dpc_regs, &g_dp, address, cpu_hword);
}

static void write_dpd(void)
{
    writed(write_dpc_regs, &g_dp, address, cpu_dword);
}


static void read_dps(void)
{
    readw(read_dps_regs, &g_dp, address, rdword);
}

static void read_dpsb(void)
{
    readb(read_dps_regs, &g_dp, address, rdword);
}

static void read_dpsh(void)
{
    readh(read_dps_regs, &g_dp, address, rdword);
}

static void read_dpsd(void)
{
    readd(read_dps_regs, &g_dp, address, rdword);
}

static void write_dps(void)
{
    writew(write_dps_regs, &g_dp, address, cpu_word);
}

static void write_dpsb(void)
{
    writeb(write_dps_regs, &g_dp, address, cpu_byte);
}

static void write_dpsh(void)
{
    writeh(write_dps_regs, &g_dp, address, cpu_hword);
}

static void write_dpsd(void)
{
    writed(write_dps_regs, &g_dp, address, cpu_dword);
}


static void read_mi(void)
{
    readw(read_mi_regs, &g_r4300, address, rdword);
}

static void read_mib(void)
{
    readb(read_mi_regs, &g_r4300, address, rdword);
}

static void read_mih(void)
{
    readh(read_mi_regs, &g_r4300, address, rdword);
}

static void read_mid(void)
{
    readd(read_mi_regs, &g_r4300, address, rdword);
}

static void write_mi(void)
{
    writew(write_mi_regs, &g_r4300, address, cpu_word);
}

static void write_mib(void)
{
    writeb(write_mi_regs, &g_r4300, address, cpu_byte);
}

static void write_mih(void)
{
    writeh(write_mi_regs, &g_r4300, address, cpu_hword);
}

static void write_mid(void)
{
    writed(write_mi_regs, &g_r4300, address, cpu_dword);
}


static void read_vi(void)
{
    readw(read_vi_regs, &g_vi, address, rdword);
}

static void read_vib(void)
{
    readb(read_vi_regs, &g_vi, address, rdword);
}

static void read_vih(void)
{
    readh(read_vi_regs, &g_vi, address, rdword);
}

static void read_vid(void)
{
    readd(read_vi_regs, &g_vi, address, rdword);
}

static void write_vi(void)
{
    writew(write_vi_regs, &g_vi, address, cpu_word);
}

static void write_vib(void)
{
    writeb(write_vi_regs, &g_vi, address, cpu_byte);
}

static void write_vih(void)
{
    writeh(write_vi_regs, &g_vi, address, cpu_hword);
}

static void write_vid(void)
{
    writed(write_vi_regs, &g_vi, address, cpu_dword);
}


static void read_ai(void)
{
    readw(read_ai_regs, &g_ai, address, rdword);
}

static void read_aib(void)
{
    readb(read_ai_regs, &g_ai, address, rdword);
}

static void read_aih(void)
{
    readh(read_ai_regs, &g_ai, address, rdword);
}

static void read_aid(void)
{
    readd(read_ai_regs, &g_ai, address, rdword);
}

static void write_ai(void)
{
    writew(write_ai_regs, &g_ai, address, cpu_word);
}

static void write_aib(void)
{
    writeb(write_ai_regs, &g_ai, address, cpu_byte);
}

static void write_aih(void)
{
    writeh(write_ai_regs, &g_ai, address, cpu_hword);
}

static void write_aid(void)
{
    writed(write_ai_regs, &g_ai, address, cpu_dword);
}


static void read_pi(void)
{
    readw(read_pi_regs, &g_pi, address, rdword);
}

static void read_pib(void)
{
    readb(read_pi_regs, &g_pi, address, rdword);
}

static void read_pih(void)
{
    readh(read_pi_regs, &g_pi, address, rdword);
}

static void read_pid(void)
{
    readd(read_pi_regs, &g_pi, address, rdword);
}

static void write_pi(void)
{
    writew(write_pi_regs, &g_pi, address, cpu_word);
}

static void write_pib(void)
{
    writeb(write_pi_regs, &g_pi, address, cpu_byte);
}

static void write_pih(void)
{
    writeh(write_pi_regs, &g_pi, address, cpu_hword);
}

static void write_pid(void)
{
    writed(write_pi_regs, &g_pi, address, cpu_dword);
}


static void read_ri(void)
{
    readw(read_ri_regs, &g_ri, address, rdword);
}

static void read_rib(void)
{
    readb(read_ri_regs, &g_ri, address, rdword);
}

static void read_rih(void)
{
    readh(read_ri_regs, &g_ri, address, rdword);
}

static void read_rid(void)
{
    readd(read_ri_regs, &g_ri, address, rdword);
}

static void write_ri(void)
{
    writew(write_ri_regs, &g_ri, address, cpu_word);
}

static void write_rib(void)
{
    writeb(write_ri_regs, &g_ri, address, cpu_byte);
}

static void write_rih(void)
{
    writeh(write_ri_regs, &g_ri, address, cpu_hword);
}

static void write_rid(void)
{
    writed(write_ri_regs, &g_ri, address, cpu_dword);
}


static void read_si(void)
{
    readw(read_si_regs, &g_si, address, rdword);
}

static void read_sib(void)
{
    readb(read_si_regs, &g_si, address, rdword);
}

static void read_sih(void)
{
    readh(read_si_regs, &g_si, address, rdword);
}

static void read_sid(void)
{
    readd(read_si_regs, &g_si, address, rdword);
}

static void write_si(void)
{
    writew(write_si_regs, &g_si, address, cpu_word);
}

static void write_sib(void)
{
    writeb(write_si_regs, &g_si, address, cpu_byte);
}

static void write_sih(void)
{
    writeh(write_si_regs, &g_si, address, cpu_hword);
}

static void write_sid(void)
{
    writed(write_si_regs, &g_si, address, cpu_dword);
}

static void read_pi_flashram_status(void)
{
    readw(read_flashram_status, &g_pi, address, rdword);
}

static void read_pi_flashram_statusb(void)
{
    readb(read_flashram_status, &g_pi, address, rdword);
}

static void read_pi_flashram_statush(void)
{
    readh(read_flashram_status, &g_pi, address, rdword);
}

static void read_pi_flashram_statusd(void)
{
    readd(read_flashram_status, &g_pi, address, rdword);
}

static void write_pi_flashram_command(void)
{
    writew(write_flashram_command, &g_pi, address, cpu_word);
}

static void write_pi_flashram_commandb(void)
{
    writeb(write_flashram_command, &g_pi, address, cpu_byte);
}

static void write_pi_flashram_commandh(void)
{
    writeh(write_flashram_command, &g_pi, address, cpu_hword);
}

static void write_pi_flashram_commandd(void)
{
    writed(write_flashram_command, &g_pi, address, cpu_dword);
}


static void read_rom(void)
{
    readw(read_cart_rom, &g_pi, address, rdword);
}

static void read_romb(void)
{
    readb(read_cart_rom, &g_pi, address, rdword);
}

static void read_romh(void)
{
    readh(read_cart_rom, &g_pi, address, rdword);
}

static void read_romd(void)
{
    readd(read_cart_rom, &g_pi, address, rdword);
}

static void write_rom(void)
{
    writew(write_cart_rom, &g_pi, address, cpu_word);
}


static void read_pif(void)
{
    readw(read_pif_ram, &g_si, address, rdword);
}

static void read_pifb(void)
{
    readb(read_pif_ram, &g_si, address, rdword);
}

static void read_pifh(void)
{
    readh(read_pif_ram, &g_si, address, rdword);
}

static void read_pifd(void)
{
    readd(read_pif_ram, &g_si, address, rdword);
}

static void write_pif(void)
{
    writew(write_pif_ram, &g_si, address, cpu_word);
}

static void write_pifb(void)
{
    writeb(write_pif_ram, &g_si, address, cpu_byte);
}

static void write_pifh(void)
{
    writeh(write_pif_ram, &g_si, address, cpu_hword);
}

static void write_pifd(void)
{
    writed(write_pif_ram, &g_si, address, cpu_dword);
}

/* HACK: just to get F-Zero to boot
 * TODO: implement a real DD module
 */
static int read_dd_regs(void* opaque, uint32_t address, uint32_t* value)
{
    *value = (address == 0xa5000508)
           ? 0xffffffff
           : 0x00000000;

    return 0;
}

static int write_dd_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    return 0;
}

static void read_dd(void)
{
    readw(read_dd_regs, NULL, address, rdword);
}

static void read_ddb(void)
{
    readb(read_dd_regs, NULL, address, rdword);
}

static void read_ddh(void)
{
    readh(read_dd_regs, NULL, address, rdword);
}

static void read_ddd(void)
{
    readd(read_dd_regs, NULL, address, rdword);
}

static void write_dd(void)
{
    writew(write_dd_regs, NULL, address, cpu_word);
}

static void write_ddb(void)
{
    writeb(write_dd_regs, NULL, address, cpu_byte);
}

static void write_ddh(void)
{
    writeh(write_dd_regs, NULL, address, cpu_hword);
}

static void write_ddd(void)
{
    writed(write_dd_regs, NULL, address, cpu_dword);
}

#ifdef DBG
static int memtype[0x10000];
static void (*saved_readmemb[0x10000])(void);
static void (*saved_readmemh[0x10000])(void);
static void (*saved_readmem [0x10000])(void);
static void (*saved_readmemd[0x10000])(void);
static void (*saved_writememb[0x10000])(void);
static void (*saved_writememh[0x10000])(void);
static void (*saved_writemem [0x10000])(void);
static void (*saved_writememd[0x10000])(void);

static void readmemb_with_bp_checks(void)
{
    check_breakpoints_on_mem_access(*r4300_pc()-0x4, address, 1,
            M64P_BKP_FLAG_ENABLED | M64P_BKP_FLAG_READ);

    saved_readmemb[address>>16]();
}

static void readmemh_with_bp_checks(void)
{
    check_breakpoints_on_mem_access(*r4300_pc()-0x4, address, 2,
            M64P_BKP_FLAG_ENABLED | M64P_BKP_FLAG_READ);

    saved_readmemh[address>>16]();
}

static void readmem_with_bp_checks(void)
{
    check_breakpoints_on_mem_access(*r4300_pc()-0x4, address, 4,
            M64P_BKP_FLAG_ENABLED | M64P_BKP_FLAG_READ);

    saved_readmem[address>>16]();
}

static void readmemd_with_bp_checks(void)
{
    check_breakpoints_on_mem_access(*r4300_pc()-0x4, address, 8,
            M64P_BKP_FLAG_ENABLED | M64P_BKP_FLAG_READ);

    saved_readmemd[address>>16]();
}

static void writememb_with_bp_checks(void)
{
    check_breakpoints_on_mem_access(*r4300_pc()-0x4, address, 1,
            M64P_BKP_FLAG_ENABLED | M64P_BKP_FLAG_WRITE);

    return saved_writememb[address>>16]();
}

static void writememh_with_bp_checks(void)
{
    check_breakpoints_on_mem_access(*r4300_pc()-0x4, address, 2,
            M64P_BKP_FLAG_ENABLED | M64P_BKP_FLAG_WRITE);

    return saved_writememh[address>>16]();
}

static void writemem_with_bp_checks(void)
{
    check_breakpoints_on_mem_access(*r4300_pc()-0x4, address, 4,
            M64P_BKP_FLAG_ENABLED | M64P_BKP_FLAG_WRITE);

    return saved_writemem[address>>16]();
}

static void writememd_with_bp_checks(void)
{
    check_breakpoints_on_mem_access(*r4300_pc()-0x4, address, 8,
            M64P_BKP_FLAG_ENABLED | M64P_BKP_FLAG_WRITE);

    return saved_writememd[address>>16]();
}

void activate_memory_break_read(uint32_t address)
{
    uint16_t region = address >> 16;

    if (saved_readmem[region] == NULL)
    {
        saved_readmemb[region] = readmemb[region];
        saved_readmemh[region] = readmemh[region];
        saved_readmem [region] = readmem [region];
        saved_readmemd[region] = readmemd[region];
        readmemb[region] = readmemb_with_bp_checks;
        readmemh[region] = readmemh_with_bp_checks;
        readmem [region] = readmem_with_bp_checks;
        readmemd[region] = readmemd_with_bp_checks;
    }
}

void deactivate_memory_break_read(uint32_t address)
{
    uint16_t region = address >> 16;

    if (saved_readmem[region] != NULL)
    {
        readmemb[region] = saved_readmemb[region];
        readmemh[region] = saved_readmemh[region];
        readmem [region] = saved_readmem [region];
        readmemd[region] = saved_readmemd[region];
        saved_readmemb[region] = NULL;
        saved_readmemh[region] = NULL;
        saved_readmem [region] = NULL;
        saved_readmemd[region] = NULL;
    }
}

void activate_memory_break_write(uint32_t address)
{
    uint16_t region = address >> 16;

    if (saved_writemem[region] == NULL)
    {
        saved_writememb[region] = writememb[region];
        saved_writememh[region] = writememh[region];
        saved_writemem [region] = writemem [region];
        saved_writememd[region] = writememd[region];
        writememb[region] = writememb_with_bp_checks;
        writememh[region] = writememh_with_bp_checks;
        writemem [region] = writemem_with_bp_checks;
        writememd[region] = writememd_with_bp_checks;
    }
}

void deactivate_memory_break_write(uint32_t address)
{
    uint16_t region = address >> 16;

    if (saved_writemem[region] != NULL)
    {
        writememb[region] = saved_writememb[region];
        writememh[region] = saved_writememh[region];
        writemem [region] = saved_writemem [region];
        writememd[region] = saved_writememd[region];
        saved_writememb[region] = NULL;
        saved_writememh[region] = NULL;
        saved_writemem [region] = NULL;
        saved_writememd[region] = NULL;
    }
}

int get_memory_type(uint32_t address)
{
    return memtype[address >> 16];
}
#endif

#define R(x) read_ ## x ## b, read_ ## x ## h, read_ ## x, read_ ## x ## d
#define W(x) write_ ## x ## b, write_ ## x ## h, write_ ## x, write_ ## x ## d
#define RW(x) R(x), W(x)

int init_memory(void)
{
    int i;

#ifdef DBG
    memset(saved_readmem, 0, 0x10000*sizeof(saved_readmem[0]));
    memset(saved_writemem, 0, 0x10000*sizeof(saved_writemem[0]));
#endif

    /* clear mappings */
    for(i = 0; i < 0x10000; ++i)
    {
        map_region(i, M64P_MEM_NOMEM, RW(nomem));
    }

    /* map RDRAM */
    for(i = 0; i < /*0x40*/0x80; ++i)
    {
        map_region(0x8000+i, M64P_MEM_RDRAM, RW(rdram));
        map_region(0xa000+i, M64P_MEM_RDRAM, RW(rdram));
    }
    for(i = /*0x40*/0x80; i < 0x3f0; ++i)
    {
        map_region(0x8000+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa000+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map RDRAM registers */
    map_region(0x83f0, M64P_MEM_RDRAMREG, RW(rdramreg));
    map_region(0xa3f0, M64P_MEM_RDRAMREG, RW(rdramreg));
    for(i = 1; i < 0x10; ++i)
    {
        map_region(0x83f0+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa3f0+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map RSP memory */
    map_region(0x8400, M64P_MEM_RSPMEM, RW(rspmem));
    map_region(0xa400, M64P_MEM_RSPMEM, RW(rspmem));
    for(i = 1; i < 0x4; ++i)
    {
        map_region(0x8400+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa400+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map RSP registers (1) */
    map_region(0x8404, M64P_MEM_RSPREG, RW(rspreg));
    map_region(0xa404, M64P_MEM_RSPREG, RW(rspreg));
    for(i = 0x5; i < 0x8; ++i)
    {
        map_region(0x8400+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa400+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map RSP registers (2) */
    map_region(0x8408, M64P_MEM_RSP, RW(rspreg2));
    map_region(0xa408, M64P_MEM_RSP, RW(rspreg2));
    for(i = 0x9; i < 0x10; ++i)
    {
        map_region(0x8400+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa400+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map DPC registers */
    map_region(0x8410, M64P_MEM_DP, RW(dp));
    map_region(0xa410, M64P_MEM_DP, RW(dp));
    for(i = 1; i < 0x10; ++i)
    {
        map_region(0x8410+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa410+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map DPS registers */
    map_region(0x8420, M64P_MEM_DPS, RW(dps));
    map_region(0xa420, M64P_MEM_DPS, RW(dps));
    for(i = 1; i < 0x10; ++i)
    {
        map_region(0x8420+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa420+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map MI registers */
    map_region(0x8430, M64P_MEM_MI, RW(mi));
    map_region(0xa430, M64P_MEM_MI, RW(mi));
    for(i = 1; i < 0x10; ++i)
    {
        map_region(0x8430+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa430+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map VI registers */
    map_region(0x8440, M64P_MEM_VI, RW(vi));
    map_region(0xa440, M64P_MEM_VI, RW(vi));
    for(i = 1; i < 0x10; ++i)
    {
        map_region(0x8440+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa440+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map AI registers */
    map_region(0x8450, M64P_MEM_AI, RW(ai));
    map_region(0xa450, M64P_MEM_AI, RW(ai));
    for(i = 1; i < 0x10; ++i)
    {
        map_region(0x8450+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa450+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map PI registers */
    map_region(0x8460, M64P_MEM_PI, RW(pi));
    map_region(0xa460, M64P_MEM_PI, RW(pi));
    for(i = 1; i < 0x10; ++i)
    {
        map_region(0x8460+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa460+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map RI registers */
    map_region(0x8470, M64P_MEM_RI, RW(ri));
    map_region(0xa470, M64P_MEM_RI, RW(ri));
    for(i = 1; i < 0x10; ++i)
    {
        map_region(0x8470+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa470+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map SI registers */
    map_region(0x8480, M64P_MEM_SI, RW(si));
    map_region(0xa480, M64P_MEM_SI, RW(si));
    for(i = 0x481; i < 0x500; ++i)
    {
        map_region(0x8000+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa000+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map DD regsiters */
    map_region(0x8500, M64P_MEM_NOTHING, RW(dd));
    map_region(0xa500, M64P_MEM_NOTHING, RW(dd));
    for(i = 0x501; i < 0x800; ++i)
    {
        map_region(0x8000+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa000+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map flashram/sram */
    map_region(0x8800, M64P_MEM_FLASHRAMSTAT, R(pi_flashram_status), W(nothing));
    map_region(0xa800, M64P_MEM_FLASHRAMSTAT, R(pi_flashram_status), W(nothing));
    map_region(0x8801, M64P_MEM_NOTHING, R(nothing), W(pi_flashram_command));
    map_region(0xa801, M64P_MEM_NOTHING, R(nothing), W(pi_flashram_command));
    for(i = 0x802; i < 0x1000; ++i)
    {
        map_region(0x8000+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xa000+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map cart ROM */
    for(i = 0; i < (g_rom_size >> 16); ++i)
    {
        map_region(0x9000+i, M64P_MEM_ROM, R(rom), W(nothing));
        map_region(0xb000+i, M64P_MEM_ROM, R(rom),
                   write_nothingb, write_nothingh, write_rom, write_nothingd);
    }
    for(i = (g_rom_size >> 16); i < 0xfc0; ++i)
    {
        map_region(0x9000+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xb000+i, M64P_MEM_NOTHING, RW(nothing));
    }

    /* map PIF RAM */
    map_region(0x9fc0, M64P_MEM_PIF, RW(pif));
    map_region(0xbfc0, M64P_MEM_PIF, RW(pif));
    for(i = 0xfc1; i < 0x1000; ++i)
    {
        map_region(0x9000+i, M64P_MEM_NOTHING, RW(nothing));
        map_region(0xb000+i, M64P_MEM_NOTHING, RW(nothing));
    }

    fast_memory = 1;

    init_cic_using_ipl3(&g_si.pif.cic, g_rom + 0x40);

    init_r4300(&g_r4300);
    init_rdp(&g_dp);
    init_rsp(&g_sp);
    init_ai(&g_ai);
    init_pi(&g_pi);
    init_ri(&g_ri);
    init_si(&g_si);
    init_vi(&g_vi);

    DebugMessage(M64MSG_VERBOSE, "Memory initialized");
    return 0;
}

static void map_region_t(uint16_t region, int type)
{
#ifdef DBG
    memtype[region] = type;
#else
    (void)region;
    (void)type;
#endif
}

static void map_region_r(uint16_t region,
        void (*read8)(void),
        void (*read16)(void),
        void (*read32)(void),
        void (*read64)(void))
{
#ifdef DBG
    if (lookup_breakpoint(((uint32_t)region << 16), 0x10000,
                          M64P_BKP_FLAG_ENABLED | M64P_BKP_FLAG_READ) != -1)
    {
        saved_readmemb[region] = read8;
        saved_readmemh[region] = read16;
        saved_readmem [region] = read32;
        saved_readmemd[region] = read64;
        readmemb[region] = readmemb_with_bp_checks;
        readmemh[region] = readmemh_with_bp_checks;
        readmem [region] = readmem_with_bp_checks;
        readmemd[region] = readmemd_with_bp_checks;
    }
    else
#endif
    {
        readmemb[region] = read8;
        readmemh[region] = read16;
        readmem [region] = read32;
        readmemd[region] = read64;
    }
}

static void map_region_w(uint16_t region,
        void (*write8)(void),
        void (*write16)(void),
        void (*write32)(void),
        void (*write64)(void))
{
#ifdef DBG
    if (lookup_breakpoint(((uint32_t)region << 16), 0x10000,
                          M64P_BKP_FLAG_ENABLED | M64P_BKP_FLAG_WRITE) != -1)
    {
        saved_writememb[region] = write8;
        saved_writememh[region] = write16;
        saved_writemem [region] = write32;
        saved_writememd[region] = write64;
        writememb[region] = writememb_with_bp_checks;
        writememh[region] = writememh_with_bp_checks;
        writemem [region] = writemem_with_bp_checks;
        writememd[region] = writememd_with_bp_checks;
    }
    else
#endif
    {
        writememb[region] = write8;
        writememh[region] = write16;
        writemem [region] = write32;
        writememd[region] = write64;
    }
}

void map_region(uint16_t region,
                int type,
                void (*read8)(void),
                void (*read16)(void),
                void (*read32)(void),
                void (*read64)(void),
                void (*write8)(void),
                void (*write16)(void),
                void (*write32)(void),
                void (*write64)(void))
{
    map_region_t(region, type);
    map_region_r(region, read8, read16, read32, read64);
    map_region_w(region, write8, write16, write32, write64);
}

uint32_t *fast_mem_access(uint32_t address)
{
    /* This code is performance critical, specially on pure interpreter mode.
     * Removing error checking saves some time, but the emulator may crash. */

    if ((address & UINT32_C(0xc0000000)) != UINT32_C(0x80000000))
        address = virtual_to_physical_address(address, 2);

    address &= UINT32_C(0x1ffffffc);

    if (address < RDRAM_MAX_SIZE)
        return (uint32_t*) ((uint8_t*) g_rdram + address);
    else if (address >= UINT32_C(0x10000000))
        return (uint32_t*) ((uint8_t*) g_rom + (address - UINT32_C(0x10000000)));
    else if ((address & UINT32_C(0xffffe000)) == UINT32_C(0x04000000))
        return (uint32_t*) ((uint8_t*) g_sp.mem + (address & UINT32_C(0x1ffc)));
    else
        return NULL;
}
