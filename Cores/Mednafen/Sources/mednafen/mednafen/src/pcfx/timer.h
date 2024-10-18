/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* timer.h:
**  Copyright (C) 2006-2016 Mednafen Team
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

#ifndef __PCFX_TIMER_H
#define __PCFX_TIMER_H

namespace MDFN_IEN_PCFX
{

void FXTIMER_Write16(uint32 A, uint16 V, const v810_timestamp_t timestamp);
uint16 FXTIMER_Read16(uint32 A, const v810_timestamp_t timestamp);
uint8 FXTIMER_Read8(uint32 A, const v810_timestamp_t timestamp);
v810_timestamp_t FXTIMER_Update(const v810_timestamp_t timestamp);
void FXTIMER_ResetTS(int32 ts_base);
void FXTIMER_Reset(void) MDFN_COLD;

void FXTIMER_Init(void) MDFN_COLD;

void FXTIMER_StateAction(StateMem *sm, const unsigned load, const bool data_only);


enum
{
 FXTIMER_GSREG_TCTRL = 0,
 FXTIMER_GSREG_TPRD,
 FXTIMER_GSREG_TCNTR
};

uint32 FXTIMER_GetRegister(const unsigned int id, char *special, const uint32 special_len);
void FXTIMER_SetRegister(const unsigned int id, uint32 value);

}

#endif
