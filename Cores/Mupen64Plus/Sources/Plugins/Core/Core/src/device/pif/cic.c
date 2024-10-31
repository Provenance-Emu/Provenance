/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - cic.c                                                   *
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

#include "cic.h"

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "api/callbacks.h"
#include "api/m64p_types.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>


void init_cic_using_ipl3(struct cic* cic, const void* ipl3)
{
    size_t i;
    uint64_t crc = 0;

    static const struct cic cics[] =
    {
        { "5101", CIC_5101, 0xac },
        { "X101", CIC_X101, 0x3f },
        { "X102", CIC_X102, 0x3f },
        { "X103", CIC_X103, 0x78 },
        { "X105", CIC_X105, 0x91 },
        { "X106", CIC_X106, 0x85 },
        { "5167", CIC_5167, 0xdd }
    };

    for (i = 0; i < 0xfc0/4; i++)
        crc += ((uint32_t*)ipl3)[i];

    switch(crc)
    {
        default:
            DebugMessage(M64MSG_WARNING, "Unknown CIC type (%016" PRIX64 ")! using CIC 6102.", crc);
            /* fall through */
        case UINT64_C(0x000000D057C85244): i = 2; break; /* CIC_X102 */
        case UINT64_C(0x000000D0027FDF31):               /* CIC_X101 */
        case UINT64_C(0x000000CFFB631223): i = 1; break; /* CIC_X101 */
        case UINT64_C(0x000000D6497E414B): i = 3; break; /* CIC_X103 */
        case UINT64_C(0x0000011A49F60E96): i = 4; break; /* CIC_X105 */
        case UINT64_C(0x000000D6D5BE5580): i = 5; break; /* CIC_X106 */
        case UINT64_C(0x000001053BC19870): i = 6; break; /* CIC 5167 */
        case UINT64_C(0x000000A5F80BF620): i = 0; break; /* CIC 5101 */
    }

    memcpy(cic, &cics[i], sizeof(*cic));

    DebugMessage(M64MSG_INFO, "Using CIC type %s", cic->name);
}

