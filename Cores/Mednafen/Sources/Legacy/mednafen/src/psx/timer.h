/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* timer.h:
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

#ifndef __MDFN_PSX_TIMER_H
#define __MDFN_PSX_TIMER_H

namespace MDFN_IEN_PSX
{

enum
{
 TIMER_GSREG_COUNTER0 = 0x00,
 TIMER_GSREG_MODE0,
 TIMER_GSREG_TARGET0,

 TIMER_GSREG_COUNTER1 = 0x10,
 TIMER_GSREG_MODE1,
 TIMER_GSREG_TARGET1,

 TIMER_GSREG_COUNTER2 = 0x20,
 TIMER_GSREG_MODE2,
 TIMER_GSREG_TARGET2,
};

uint32 TIMER_GetRegister(unsigned int which, char *special, const uint32 special_len);
void TIMER_SetRegister(unsigned int which, uint32 value);

MDFN_FASTCALL void TIMER_Write(const pscpu_timestamp_t timestamp, uint32 A, uint16 V);
MDFN_FASTCALL uint16 TIMER_Read(const pscpu_timestamp_t timestamp, uint32 A);

MDFN_FASTCALL void TIMER_AddDotClocks(uint32 count);
void TIMER_ClockHRetrace(void);
MDFN_FASTCALL void TIMER_SetHRetrace(bool status);
MDFN_FASTCALL void TIMER_SetVBlank(bool status);

MDFN_FASTCALL pscpu_timestamp_t TIMER_Update(const pscpu_timestamp_t);
void TIMER_ResetTS(void);

void TIMER_Power(void) MDFN_COLD;
void TIMER_StateAction(StateMem *sm, const unsigned load, const bool data_only);

}

#endif
