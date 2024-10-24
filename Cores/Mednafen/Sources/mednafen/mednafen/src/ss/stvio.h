/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* stvio.h:
**  Copyright (C) 2022 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#ifndef __MDFN_SS_STVIO_H
#define __MDFN_SS_STVIO_H

#include "smpc_iodevice.h"
#include "db.h"

namespace MDFN_IEN_SS
{

void STVIO_Init(const STVGameInfo* sgi) MDFN_COLD;
void STVIO_Reset(bool powering_up) MDFN_COLD;
void STVIO_StateAction(StateMem* sm, const unsigned load, const bool data_only) MDFN_COLD;

void STVIO_LoadNV(Stream* s) MDFN_COLD;
void STVIO_SaveNV(Stream* s) MDFN_COLD;

void STVIO_WriteIOGA(const sscpu_timestamp_t timestamp, uint8 A, uint8 V) MDFN_HOT;
uint8 STVIO_ReadIOGA(const sscpu_timestamp_t timestamp, uint8 A) MDFN_HOT;

void STVIO_TransformInput(void);
void STVIO_UpdateInput(int32 elapsed_time);
void STVIO_SetInput(unsigned port, const char* type, uint8* ptr) MDFN_COLD;
void STVIO_SetCrosshairsColor(unsigned port, uint32 color) MDFN_COLD;

void STVIO_InsertCoin(void);

IODevice* STVIO_GetSMPCDevice(bool sport) MDFN_COLD;

}
#endif
