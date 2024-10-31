/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - af_rtc.h                                                *
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

#ifndef M64P_DEVICE_SI_AF_RTC_H
#define M64P_DEVICE_SI_AF_RTC_H

#include <stdint.h>
#include <time.h>

struct clock_backend_interface;

struct af_rtc
{
    /* block 0 */
    uint16_t control;
    /* block 2 */
    time_t now;

    time_t last_update_rtc;
    void* clock;
    const struct clock_backend_interface* iclock;
};

void init_af_rtc(struct af_rtc* rtc,
                 void* clock,
                 const struct clock_backend_interface* iclock);

void poweron_af_rtc(struct af_rtc* rtc);

void af_rtc_read_block(struct af_rtc* rtc,
    uint8_t block, uint8_t* data, uint8_t* status);

void af_rtc_write_block(struct af_rtc* rtc,
    uint8_t block, const uint8_t* data, uint8_t* status);

#endif
