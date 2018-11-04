/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* mdec.h:
**  Copyright (C) 2011-2016 Mednafen Team
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

#ifndef __MDFN_PSX_MDEC_H
#define __MDFN_PSX_MDEC_H

namespace MDFN_IEN_PSX
{

MDFN_FASTCALL void MDEC_DMAWrite(uint32 V);

MDFN_FASTCALL uint32 MDEC_DMARead(uint32* offs);

MDFN_FASTCALL void MDEC_Write(const pscpu_timestamp_t timestamp, uint32 A, uint32 V);
MDFN_FASTCALL uint32 MDEC_Read(const pscpu_timestamp_t timestamp, uint32 A);


void MDEC_Power(void) MDFN_COLD;

bool MDEC_DMACanWrite(void);
bool MDEC_DMACanRead(void);
MDFN_FASTCALL void MDEC_Run(int32 clocks);

void MDEC_StateAction(StateMem *sm, const unsigned load, const bool data_only);
}

#endif
