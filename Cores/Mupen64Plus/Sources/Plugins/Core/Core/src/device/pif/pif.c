/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - pif.c                                                   *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
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

#include "pif.h"
#include "n64_cic_nus_6105.h"

#include <assert.h>
#include <stdint.h>
#include <string.h>

#include "api/callbacks.h"
#include "api/m64p_plugin.h"
#include "api/m64p_types.h"
#include "backends/api/joybus.h"
#include "device/memory/memory.h"
#include "device/r4300/r4300_core.h"
#include "plugin/plugin.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

//#define DEBUG_PIF
#ifdef DEBUG_PIF
void print_pif(struct pif* pif)
{
    int i;
    for (i=0; i<(64/8); i++) {
        DebugMessage(M64MSG_INFO, "%02" PRIX8 " %02" PRIX8 " %02" PRIX8 " %02" PRIX8 " | %02" PRIX8 " %02" PRIX8 " %02" PRIX8 " %02" PRIX8,
                     pif->ram[i*8+0], pif->ram[i*8+1],pif->ram[i*8+2], pif->ram[i*8+3],
                     pif->ram[i*8+4], pif->ram[i*8+5],pif->ram[i*8+6], pif->ram[i*8+7]);
    }

    for(i = 0; i < PIF_CHANNELS_COUNT; ++i) {
        if (pif->channels[i].tx != NULL) {
            DebugMessage(M64MSG_INFO, "Channel %u, tx=%02x rx=%02x cmd=%02x",
                i,
                *(pif->channels[i].tx),
                *(pif->channels[i].rx),
                pif->channels[i].tx_buf[0]);
        }
    }
}
#endif

static void process_channel(struct pif_channel* channel)
{
    /* don't process channel if it has been disabled */
    if (channel->tx == NULL) {
        return;
    }

    /* reset Tx/Rx just in case */
    *channel->tx &= 0x3f;
    *channel->rx &= 0x3f;

    /* set NoResponse if no device is connected */
    if (channel->ijbd == NULL) {
        *channel->rx |= 0x80;
        return;
    }

    /* do device processing */
    channel->ijbd->process(channel->jbd,
        channel->tx, channel->tx_buf,
        channel->rx, channel->rx_buf);
}

static void post_setup_channel(struct pif_channel* channel)
{
    if ((channel->ijbd == NULL)
    || (channel->ijbd->post_setup == NULL)) {
        return;
    }

    channel->ijbd->post_setup(channel->jbd,
        channel->tx, channel->tx_buf,
        channel->rx, channel->rx_buf);
}

void disable_pif_channel(struct pif_channel* channel)
{
    channel->tx = NULL;
    channel->rx = NULL;
    channel->tx_buf = NULL;
    channel->rx_buf = NULL;
}

size_t setup_pif_channel(struct pif_channel* channel, uint8_t* buf)
{
    uint8_t tx = buf[0] & 0x3f;
    uint8_t rx = buf[1] & 0x3f;

    /* XXX: check out of bounds accesses */

    channel->tx = buf;
    channel->rx = buf + 1;
    channel->tx_buf = buf + 2;
    channel->rx_buf = buf + 2 + tx;

    post_setup_channel(channel);

    return 2 + tx + rx;
}

void init_pif(struct pif* pif,
    uint8_t* pif_base,
    void* jbds[PIF_CHANNELS_COUNT],
    const struct joybus_device_interface* ijbds[PIF_CHANNELS_COUNT],
    const uint8_t* ipl3,
    struct r4300_core* r4300)
{
    size_t i;

    pif->ram = pif_base + 0x7c0;

    for (i = 0; i < PIF_CHANNELS_COUNT; ++i) {
        pif->channels[i].jbd = jbds[i];
        pif->channels[i].ijbd = ijbds[i];
    }

    init_cic_using_ipl3(&pif->cic, ipl3);

    pif->r4300 = r4300;
}

void reset_pif(struct pif* pif, unsigned int reset_type)
{
    size_t i;

    /* HACK: for allowing pifbootrom execution */
    unsigned int rom_type = 0;
    unsigned int s7 = 0;

    /* 0:ColdReset, 1:NMI */
    assert((reset_type & ~0x1) == 0);

    /* disable channel processing */
    for (i = 0; i < PIF_CHANNELS_COUNT; ++i) {
        disable_pif_channel(&pif->channels[i]);
    }

    /* set PIF_24 with reset informations */
    uint32_t* pif24 = (uint32_t*)(pif->ram + 0x24);
    *pif24 = (uint32_t)
         (((rom_type      & 0x1) << 19)
        | ((s7            & 0x1) << 18)
        | ((reset_type    & 0x1) << 17)
        | ((pif->cic.seed & 0xff) << 8)
        | 0x3f);
    *pif24 = fromhl(*pif24);

    /* clear PIF flags */
    pif->ram[0x3f] = 0x00;
}

void setup_channels_format(struct pif* pif)
{
    size_t i = 0;
    size_t k = 0;

    while (i < PIF_RAM_SIZE && k < PIF_CHANNELS_COUNT)
    {
        switch(pif->ram[i])
        {
        case 0x00: /* skip channel */
            disable_pif_channel(&pif->channels[k++]);
            ++i;
            break;

        case 0xff: /* dummy data */
            ++i;
            break;

        case 0xfe: /* end of channel setup - remaining channels are disabled */
            while (k < PIF_CHANNELS_COUNT) {
                disable_pif_channel(&pif->channels[k++]);
            }
            break;

        case 0xfd: /* channel reset - send reset command and discard the results */ {
            static uint8_t dummy_reset_buffer[PIF_CHANNELS_COUNT][6];

            /* setup reset command Tx=1, Rx=3, cmd=0xff */
            dummy_reset_buffer[k][0] = 0x01;
            dummy_reset_buffer[k][1] = 0x03;
            dummy_reset_buffer[k][2] = 0xff;

            setup_pif_channel(&pif->channels[k], dummy_reset_buffer[k]);
            ++k;
            ++i;
            }
            break;

        default: /* setup channel */

            /* HACK?: some games sends bogus PIF commands while accessing controller paks
             * Yoshi Story, Top Gear Rally 2, Indiana Jones, ...
             * When encountering such commands, we skip this bogus byte.
             */
            if ((i+1 < PIF_RAM_SIZE) && (pif->ram[i+1] == 0xfe)) {
                ++i;
                continue;
            }

            if ((i + 2) >= PIF_RAM_SIZE) {
                DebugMessage(M64MSG_WARNING, "Truncated PIF command ! Stopping PIF channel processing");
                i = PIF_RAM_SIZE;
                continue;
            }


            i += setup_pif_channel(&pif->channels[k++], &pif->ram[i]);
        }
    }

    /* Zilmar-Spec plugin expect a call with control_id = -1 when RAM processing is done */
    if (input.controllerCommand) {
        input.controllerCommand(-1, NULL);
    }

#ifdef DEBUG_PIF
    DebugMessage(M64MSG_INFO, "PIF setup channel");
    print_pif(pif);
#endif
}

static void process_cic_challenge(struct pif* pif)
{
    char challenge[30], response[30];
    size_t i;

    /* format the 'challenge' message into 30 nibbles for X-Scale's CIC code */
    for (i = 0; i < 15; ++i)
    {
        challenge[i*2]   = (pif->ram[0x30+i] >> 4) & 0x0f;
        challenge[i*2+1] =  pif->ram[0x30+i]       & 0x0f;
    }

    /* calculate the proper response for the given challenge (X-Scale's algorithm) */
    n64_cic_nus_6105(challenge, response, CHL_LEN - 2);
    pif->ram[0x2e] = 0;
    pif->ram[0x2f] = 0;

    /* re-format the 'response' into a byte stream */
    for (i = 0; i < 15; ++i)
    {
        pif->ram[0x30+i] = (response[i*2] << 4) + response[i*2+1];
    }

#ifdef DEBUG_PIF
    DebugMessage(M64MSG_INFO, "PIF cic challenge");
    print_pif(pif);
#endif
}

void poweron_pif(struct pif* pif)
{
    memset(pif->ram, 0, PIF_RAM_SIZE);

    reset_pif(pif, 0); /* cold reset */
}

void read_pif_ram(void* opaque, uint32_t address, uint32_t* value)
{
    struct pif* pif = (struct pif*)opaque;
    uint32_t addr = pif_ram_address(address);

    if (addr >= PIF_RAM_SIZE)
    {
        DebugMessage(M64MSG_ERROR, "Invalid PIF address: %08" PRIX32, address);
        *value = 0;
        return;
    }

    memcpy(value, pif->ram + addr, sizeof(*value));
    *value = tohl(*value);
}

void write_pif_ram(void* opaque, uint32_t address, uint32_t value, uint32_t mask)
{
    struct pif* pif = (struct pif*)opaque;
    uint32_t addr = pif_ram_address(address);

    if (addr >= PIF_RAM_SIZE)
    {
        DebugMessage(M64MSG_ERROR, "Invalid PIF address: %08" PRIX32, address);
        return;
    }

    masked_write((uint32_t*)(&pif->ram[addr]), fromhl(value), fromhl(mask));

    process_pif_ram(pif);
}


void process_pif_ram(struct pif* pif)
{
    uint8_t flags = pif->ram[0x3f];
    uint8_t clrmask = 0x00;
    size_t k;

    if (flags == 0) {
#ifdef DEBUG_PIF
        DebugMessage(M64MSG_INFO, "PIF process pif ram status=0x00");
        print_pif(pif);
#endif
        return;
    }

    if (flags & 0x01)
    {
        /* setup channels then clear format flag */
        setup_channels_format(pif);
        clrmask |= 0x01;
    }

    if (flags & 0x02)
    {
        /* disable channel processing when doing CIC challenge */
        for (k = 0; k < PIF_CHANNELS_COUNT; ++k) {
            disable_pif_channel(&pif->channels[k]);
        }

        /* CIC Challenge */
        process_cic_challenge(pif);
        clrmask |= 0x02;
    }

    if (flags & 0x08)
    {
        clrmask |= 0x08;
    }

    if (flags & 0xf4)
    {
        DebugMessage(M64MSG_ERROR, "error in process_pif_ram(): %" PRIX8, flags);
    }

    pif->ram[0x3f] &= ~clrmask;
}

void update_pif_ram(struct pif* pif)
{
    size_t k;

    /* perform PIF/Channel communications */
    for (k = 0; k < PIF_CHANNELS_COUNT; ++k) {
        process_channel(&pif->channels[k]);
    }

    /* Zilmar-Spec plugin expect a call with control_id = -1 when RAM processing is done */
    if (input.readController) {
        input.readController(-1, NULL);
    }

#ifdef DEBUG_PIF
    DebugMessage(M64MSG_INFO, "PIF post read");
    print_pif(pif);
#endif
}

void hw2_int_handler(void* opaque)
{
    struct pif* pif = (struct pif*)opaque;

    raise_maskable_interrupt(pif->r4300, CP0_CAUSE_IP4);
}

