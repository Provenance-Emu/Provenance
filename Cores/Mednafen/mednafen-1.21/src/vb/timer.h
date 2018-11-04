/******************************************************************************/
/* Mednafen Virtual Boy Emulation Module                                      */
/******************************************************************************/
/* timer.h:
**  Copyright (C) 2010-2016 Mednafen Team
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

#ifndef __MDFN_VB_TIMER_H
#define __MDFN_VB_TIMER_H

namespace MDFN_IEN_VB
{

v810_timestamp_t TIMER_Update(v810_timestamp_t timestamp);
void TIMER_ResetTS(void);
uint8 TIMER_Read(const v810_timestamp_t &timestamp, uint32 A);
void TIMER_Write(const v810_timestamp_t &timestamp, uint32 A, uint8 V);

void TIMER_Power(void) MDFN_COLD;

void TIMER_StateAction(StateMem *sm, const unsigned load, const bool data_only);


enum
{
 TIMER_GSREG_TCR,
 TIMER_GSREG_DIVCOUNTER,
 TIMER_GSREG_RELOAD_VALUE,
 TIMER_GSREG_COUNTER,
};

uint32 TIMER_GetRegister(const unsigned int id, char *special, const uint32 special_len);
void TIMER_SetRegister(const unsigned int id, const uint32 value);

}

#endif
