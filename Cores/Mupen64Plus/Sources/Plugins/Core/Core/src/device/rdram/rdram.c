/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - rdram.c                                                 *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2014 Bobby Smiles                                       *
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

#include "rdram.h"

#include "api/m64p_types.h"
#include "api/callbacks.h"
#include "device/device.h"
#include "device/memory/memory.h"
#include "device/r4300/r4300_core.h"
#include "device/rcp/ri/ri_controller.h"

#include <string.h>

#define RDRAM_BCAST_ADDRESS_MASK UINT32_C(0x00080000)


/* XXX: deduce # of RDRAM modules from it's total size
 * Assume only 2Mo RDRAM modules.
 * Proper way of doing it would be to declare in init_rdram
 * what kind of modules we insert and deduce dram_size from
 * that configuration.
 */
static size_t get_modules_count(const struct rdram* rdram)
{
    return (rdram->dram_size) / 0x200000;
}

static uint8_t cc_value(uint32_t mode_reg)
{
    return ((mode_reg & 0x00000040) >>  6)
        |  ((mode_reg & 0x00004000) >> 13)
        |  ((mode_reg & 0x00400000) >> 20)
        |  ((mode_reg & 0x00000080) >>  4)
        |  ((mode_reg & 0x00008000) >> 11)
        |  ((mode_reg & 0x00800000) >> 18);
}


static osal_inline uint16_t idfield_value(uint32_t device_id)
{
    return ((((device_id >> 26) & 0x3f) <<  0)
          | (((device_id >> 23) & 0x01) <<  6)
          | (((device_id >> 16) & 0xff) <<  7)
          | (((device_id >>  7) & 0x01) << 15));
}

static size_t get_module(const struct rdram* rdram, uint32_t address)
{
    size_t module;
    size_t modules = get_modules_count(rdram);
    uint16_t id_field = ri_address_to_id_field(address);


    for (module = 0; module < modules; ++module) {
        if (id_field == idfield_value(rdram->regs[module][RDRAM_DEVICE_ID_REG])) {
            return module;
        }
    }

    /* can happen during memory detection because
     * it probes potentialy non present RDRAM */
    return RDRAM_MAX_MODULES_COUNT;
}

static void read_rdram_dram_corrupted(void* opaque, uint32_t address, uint32_t* value)
{
    struct rdram* rdram = (struct rdram*)opaque;
    uint32_t addr = rdram_dram_address(address);
    size_t module;

    *value = rdram->dram[addr];

    module = get_module(rdram, address);
    if (module == RDRAM_MAX_MODULES_COUNT) {
        *value = 0;
        return;
    }

    /* corrupt read value if CC value is not calibrated */
    uint32_t mode = rdram->regs[module][RDRAM_MODE_REG] ^ UINT32_C(0xc0c0c0c0);
    if ((mode & 0x80000000) && (cc_value(mode) == 0)) {
        *value = 0;
    }
}

static void map_corrupt_rdram(struct rdram* rdram, int corrupt)
{
    struct mem_mapping mapping;

    mapping.begin = MM_RDRAM_DRAM;
    mapping.end = MM_RDRAM_DRAM + rdram->dram_size - 1;
    mapping.type = M64P_MEM_RDRAM;
    mapping.handler.opaque = rdram;
    mapping.handler.read32 = (corrupt)
        ? read_rdram_dram_corrupted
        : read_rdram_dram;
    mapping.handler.write32 = write_rdram_dram;

    apply_mem_mapping(rdram->r4300->mem, &mapping);
#ifndef NEW_DYNAREC
    rdram->r4300->recomp.fast_memory = (corrupt) ? 0 : 1;
    invalidate_r4300_cached_code(rdram->r4300, 0, 0);
#endif
}


void init_rdram(struct rdram* rdram,
                uint32_t* dram,
                size_t dram_size,
                struct r4300_core* r4300)
{
    rdram->dram = dram;
    rdram->dram_size = dram_size;
    rdram->r4300 = r4300;
}

void poweron_rdram(struct rdram* rdram)
{
    size_t module;
    size_t modules = get_modules_count(rdram);
    memset(rdram->regs, 0, RDRAM_MAX_MODULES_COUNT*RDRAM_REGS_COUNT*sizeof(uint32_t));
    memset(rdram->dram, 0, rdram->dram_size);

    DebugMessage(M64MSG_INFO, "Initializing %u RDRAM modules for a total of %u MB",
        modules, rdram->dram_size / (1024*1024));

    for (module = 0; module < modules; ++module) {
        rdram->regs[module][RDRAM_CONFIG_REG] = UINT32_C(0xb5190010);
        rdram->regs[module][RDRAM_DEVICE_ID_REG] = UINT32_C(0x00000000);
        rdram->regs[module][RDRAM_DELAY_REG] = UINT32_C(0x230b0223);
        rdram->regs[module][RDRAM_MODE_REG] = UINT32_C(0xc4c0c0c0);
        rdram->regs[module][RDRAM_REF_ROW_REG] = UINT32_C(0x00000000);
        rdram->regs[module][RDRAM_MIN_INTERVAL_REG] = UINT32_C(0x0040c0e0);
        rdram->regs[module][RDRAM_ADDR_SELECT_REG] = UINT32_C(0x00000000);
        rdram->regs[module][RDRAM_DEVICE_MANUF_REG] = UINT32_C(0x00000500);
    }
}


void read_rdram_regs(void* opaque, uint32_t address, uint32_t* value)
{
    struct rdram* rdram = (struct rdram*)opaque;
    uint32_t reg = rdram_reg(address);
    size_t module;

    if (address & RDRAM_BCAST_ADDRESS_MASK) {
        DebugMessage(M64MSG_WARNING, "Reading from broadcast address is unsupported %08x", address);
        return;
    }

    module = get_module(rdram, address);
    if (module == RDRAM_MAX_MODULES_COUNT) {
        *value = 0;
        return;
    }

    *value = rdram->regs[module][reg];

    /* some bits are inverted when read */
    if (reg == RDRAM_MODE_REG) {
        *value ^= UINT32_C(0xc0c0c0c0);
    }
}

void write_rdram_regs(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rdram* rdram = (struct rdram*)opaque;
    uint32_t reg = rdram_reg(address);
    size_t module;
    size_t modules = get_modules_count(rdram);

    /* HACK: Detect when current Control calibration is about to start,
     * so we can set corrupted rdram_dram handler
     */
    if (address & RDRAM_BCAST_ADDRESS_MASK && reg == RDRAM_DELAY_REG) {
        map_corrupt_rdram(rdram, 1);
    }

    /* HACK: Detect when current Control calibration is over,
     * so we can restore the original rdram_dram handler
     * and let dynarec have it's fast_memory enabled.
     */
    if (address & RDRAM_BCAST_ADDRESS_MASK && reg == RDRAM_MODE_REG) {
        map_corrupt_rdram(rdram, 0);

        /* HACK: In the IPL3 procedure, at this point,
         * the amount of detected memory can be found in s4 */
        size_t ipl3_rdram_size = r4300_regs(rdram->r4300)[20] & UINT32_C(0x0fffffff);
        if (ipl3_rdram_size != rdram->dram_size) {
            DebugMessage(M64MSG_ERROR, "IPL3 detected %u MB of RDRAM != %u MB",
                ipl3_rdram_size / (1024*1024), rdram->dram_size / (1024*1024));
        }
    }


    if (address & RDRAM_BCAST_ADDRESS_MASK) {
        for (module = 0; module < modules; ++module) {
            masked_write(&rdram->regs[module][reg], value, mask);
        }
    }
    else {
        module = get_module(rdram, address);
        if (module != RDRAM_MAX_MODULES_COUNT) {
            masked_write(&rdram->regs[module][reg], value, mask);
        }
    }
}


void read_rdram_dram(void* opaque, uint32_t address, uint32_t* value)
{
    struct rdram* rdram = (struct rdram*)opaque;
    uint32_t addr = rdram_dram_address(address);

    *value = rdram->dram[addr];
}

void write_rdram_dram(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct rdram* rdram = (struct rdram*)opaque;
    uint32_t addr = rdram_dram_address(address);

    masked_write(&rdram->dram[addr], value, mask);
}
