/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - device.h                                                *
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

#ifndef M64P_DEVICE_DEVICE_H
#define M64P_DEVICE_DEVICE_H

#include <stddef.h>
#include <stdint.h>

#include "cart/cart.h"
#include "controllers/game_controller.h"
#include "controllers/paks/mempak.h"
#include "controllers/paks/rumblepak.h"
#include "controllers/paks/transferpak.h"
#include "gb/gb_cart.h"
#include "memory/memory.h"
#include "pif/pif.h"
#include "r4300/r4300_core.h"
#include "rcp/ai/ai_controller.h"
#include "rcp/mi/mi_controller.h"
#include "rcp/pi/pi_controller.h"
#include "rcp/rdp/rdp_core.h"
#include "rcp/ri/ri_controller.h"
#include "rcp/rsp/rsp_core.h"
#include "rcp/si/si_controller.h"
#include "rcp/vi/vi_controller.h"
#include "rdram/rdram.h"

struct audio_out_backend_interface;
struct clock_backend_interface;
struct storage_backend_interface;
struct joybus_device_interface;

enum { GAME_CONTROLLERS_COUNT = 4 };

/* memory map constants */
#define MM_RDRAM_DRAM       UINT32_C(0x00000000)
#define MM_RDRAM_REGS       UINT32_C(0x03f00000)

#define MM_RSP_MEM          UINT32_C(0x04000000)
#define MM_RSP_REGS         UINT32_C(0x04040000)
#define MM_RSP_REGS2        UINT32_C(0x04080000)
#define MM_DPC_REGS         UINT32_C(0x04100000)
#define MM_DPS_REGS         UINT32_C(0x04200000)
#define MM_MI_REGS          UINT32_C(0x04300000)
#define MM_VI_REGS          UINT32_C(0x04400000)
#define MM_AI_REGS          UINT32_C(0x04500000)
#define MM_PI_REGS          UINT32_C(0x04600000)
#define MM_RI_REGS          UINT32_C(0x04700000)
#define MM_SI_REGS          UINT32_C(0x04800000)

#define MM_DOM2_ADDR1       UINT32_C(0x05000000)
#define MM_DD_ROM           UINT32_C(0x06000000)

#define MM_DOM2_ADDR2       UINT32_C(0x08000000)

#define MM_CART_ROM         UINT32_C(0x10000000) /* dom1 addr2 */
#define MM_PIF_MEM          UINT32_C(0x1fc00000)
#define MM_CART_DOM3        UINT32_C(0x1fd00000) /* dom2 addr2 */

/* Device structure is a container for the n64 submodules
 * It contains all state related to the emulated system. */
struct device
{
    struct r4300_core r4300;
    struct rdp_core dp;
    struct rsp_core sp;
    struct ai_controller ai;
    struct mi_controller mi;
    struct pi_controller pi;
    struct ri_controller ri;
    struct si_controller si;
    struct vi_controller vi;
    struct pif pif;
    struct rdram rdram;
    struct memory mem;

    struct game_controller controllers[GAME_CONTROLLERS_COUNT];
    struct mempak mempaks[GAME_CONTROLLERS_COUNT];
    struct rumblepak rumblepaks[GAME_CONTROLLERS_COUNT];
    struct transferpak transferpaks[GAME_CONTROLLERS_COUNT];
    struct gb_cart gb_carts[GAME_CONTROLLERS_COUNT];

    struct cart cart;
};

/* Setup device "static" properties.  */
void init_device(struct device* dev,
    /* memory */
    void* base,
    /* r4300 */
    unsigned int emumode,
    unsigned int count_per_op,
    int no_compiled_jump,
    int randomize_interrupt,
    /* ai */
    void* aout, const struct audio_out_backend_interface* iaout,
    /* si */
    unsigned int si_dma_duration,
    /* rdram */
    size_t dram_size,
    /* pif */
    void* jbds[PIF_CHANNELS_COUNT],
    const struct joybus_device_interface* ijbds[PIF_CHANNELS_COUNT],
    /* vi */
    unsigned int vi_clock, unsigned int expected_refresh_rate,
    /* cart */
    void* af_rtc_clock, const struct clock_backend_interface* iaf_rtc_clock,
    size_t rom_size,
    uint16_t eeprom_type,
    void* eeprom_storage, const struct storage_backend_interface* ieeprom_storage,
    uint32_t flashram_type,
    void* flashram_storage, const struct storage_backend_interface* iflashram_storage,
    void* sram_storage, const struct storage_backend_interface* isram_storage);

/* Setup device such that it's state is
 * what it should be after power on.
 */
void poweron_device(struct device* dev);

/* Let device run.
 * To return from this function, a call to stop_device has to be made.
 */
void run_device(struct device* dev);

/* Terminate execution of running device.
 */
void stop_device(struct device* dev);

/* Schedule a hard reset on running device.
 * This is what model a poweroff/poweron action on the device.
 */
void hard_reset_device(struct device* dev);

/* Schedule a soft reset on runnning device.
 * This is what model a press on the device reset button.
 */
void soft_reset_device(struct device* dev);

#endif
