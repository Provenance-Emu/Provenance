/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - game_controller.c                                       *
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

#include "game_controller.h"

#include "api/callbacks.h"
#include "api/m64p_types.h"
#include "backends/api/controller_input_backend.h"
#include "backends/api/joybus.h"

#ifdef COMPARE_CORE
#include "api/debugger.h"
#endif

#include <stdint.h>
#include <string.h>

enum { PAK_CHUNK_SIZE = 0x20 };

enum controller_status
{
    CONT_STATUS_PAK_PRESENT      = 0x01,
    CONT_STATUS_PAK_CHANGED      = 0x02,
    CONT_STATUS_PAK_ADDR_CRC_ERR = 0x04
};

/* Standard controller */
static void standard_controller_reset(struct game_controller* cont)
{
    /* reset controller status */
    cont->status = 0x00;

    /* if pak is connected */
    if (cont->ipak != NULL) {
        cont->status |= CONT_STATUS_PAK_PRESENT;
    }
    else {
        cont->status |= CONT_STATUS_PAK_CHANGED;
    }

    /* XXX: recalibrate joysticks  */
}

const struct game_controller_flavor g_standard_controller_flavor =
{
    "Standard controller",
    JDT_JOY_ABS_COUNTERS | JDT_JOY_PORT,
    standard_controller_reset
};

/* Pak handling functions */
void change_pak(struct game_controller* cont,
                void* pak, const struct pak_interface* ipak)
{
    cont->status &= ~(CONT_STATUS_PAK_PRESENT | CONT_STATUS_PAK_CHANGED);

    /* unplug previous pak (if any) */
    if (cont->ipak != NULL) {
        cont->ipak->unplug(cont->pak);
        cont->status |= CONT_STATUS_PAK_CHANGED;
    }

    /* plug new one (if any) */
    if (ipak != NULL) {
        ipak->plug(pak);
        cont->status |= CONT_STATUS_PAK_PRESENT;
    }

    /* set new pak */
    cont->pak = pak;
    cont->ipak = ipak;
}

static uint8_t pak_data_crc(const uint8_t* data, size_t size)
{
    size_t i;
    uint8_t crc = 0;

    for(i = 0; i <= size; ++i)
    {
        int mask;
        for (mask = 0x80; mask >= 1; mask >>= 1)
        {
            uint8_t xor_tap = (crc & 0x80) ? 0x85 : 0x00;
            crc <<= 1;
            if (i != size && (data[i] & mask)) crc |= 1;
            crc ^= xor_tap;
        }
    }
    return crc;
}

static void pak_read_block(struct game_controller* cont,
    const uint8_t* addr_acrc, uint8_t* data, uint8_t* dcrc)
{
    uint16_t address = (addr_acrc[0] << 8) | (addr_acrc[1] & 0xe0);
#if 0
    uint8_t  acrc = addr_acrc[1] & 0x1f;
#endif

    if (cont->ipak != NULL) {
        cont->ipak->read(cont->pak, address, data, PAK_CHUNK_SIZE);
    }

    *dcrc = pak_data_crc(data, PAK_CHUNK_SIZE);
}

static void pak_write_block(struct game_controller* cont,
    const uint8_t* addr_acrc, const uint8_t* data, uint8_t* dcrc)
{
    uint16_t address = (addr_acrc[0] << 8) | (addr_acrc[1] & 0xe0);
#if 0
    uint8_t  acrc = addr_acrc[1] & 0x1f;
#endif

    if (cont->ipak != NULL) {
        cont->ipak->write(cont->pak, address, data, PAK_CHUNK_SIZE);
    }

    *dcrc = pak_data_crc(data, PAK_CHUNK_SIZE);
}


/* Mouse controller */
static void mouse_controller_reset(struct game_controller* cont)
{
    cont->status = 0x00;
}

const struct game_controller_flavor g_mouse_controller_flavor =
{
    "Mouse controller",
    JDT_JOY_REL_COUNTERS,
    mouse_controller_reset
};


void init_game_controller(struct game_controller* cont,
    const struct game_controller_flavor* flavor,
    void* cin, const struct controller_input_backend_interface* icin,
    void* pak, const struct pak_interface* ipak)
{
    cont->flavor = flavor;
    cont->cin = cin;
    cont->icin = icin;
    cont->pak = pak;
    cont->ipak = ipak;
}

static void poweron_game_controller(void* jbd)
{
    struct game_controller* cont = (struct game_controller*)jbd;

    cont->flavor->reset(cont);

    if (cont->flavor == &g_standard_controller_flavor && cont->ipak != NULL) {
        cont->ipak->plug(cont->pak);
    }
}

static void process_controller_command(void* jbd,
    const uint8_t* tx, const uint8_t* tx_buf,
    uint8_t* rx, uint8_t* rx_buf)
{
    struct game_controller* cont = (struct game_controller*)jbd;
    uint32_t input_ = 0;
    uint8_t cmd = tx_buf[0];

    /* if controller can't successfully be polled, consider it to be absent */
    if (cont->icin->get_input(cont->cin, &input_) != M64ERR_SUCCESS) {
        *rx |= 0x80;
        return;
    }

    switch (cmd)
    {
    case JCMD_RESET:
        cont->flavor->reset(cont);
        /* fall through */
    case JCMD_STATUS: {
        JOYBUS_CHECK_COMMAND_FORMAT(1, 3)

        rx_buf[0] = (uint8_t)(cont->flavor->type >> 0);
        rx_buf[1] = (uint8_t)(cont->flavor->type >> 8);
        rx_buf[2] = cont->status;
    } break;

    case JCMD_CONTROLLER_READ: {
        JOYBUS_CHECK_COMMAND_FORMAT(1, 4)

        *((uint32_t*)(rx_buf)) = input_;
#ifdef COMPARE_CORE
        CoreCompareDataSync(4, rx_buf);
#endif
    } break;

    case JCMD_PAK_READ: {
        JOYBUS_CHECK_COMMAND_FORMAT(3, 33)
        pak_read_block(cont, &tx_buf[1], &rx_buf[0], &rx_buf[32]);
    } break;

    case JCMD_PAK_WRITE: {
        JOYBUS_CHECK_COMMAND_FORMAT(35, 1)
        pak_write_block(cont, &tx_buf[1], &tx_buf[3], &rx_buf[0]);
    } break;

    default:
        DebugMessage(M64MSG_WARNING, "cont: Unknown command %02x %02x %02x",
            *tx, *rx, cmd);
    }
}

const struct joybus_device_interface g_ijoybus_device_controller =
{
    poweron_game_controller,
    process_controller_command,
    NULL
};
