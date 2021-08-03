/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* irq.h:
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

#ifndef __MDFN_PSX_IRQ_H
#define __MDFN_PSX_IRQ_H

namespace MDFN_IEN_PSX
{


enum
{
 IRQ_VBLANK = 	0,
 IRQ_GPU =	        1,
 IRQ_CD =		2,
 IRQ_DMA =		3,	// Probably
 IRQ_TIMER_0 	= 4,
 IRQ_TIMER_1 	= 5,
 IRQ_TIMER_2 	= 6,
 IRQ_SIO	      = 7,
 IRQ_SPU	      = 9,
 IRQ_PIO		= 10,	// Probably
};

void IRQ_Power(void) MDFN_COLD;
void IRQ_Assert(int which, bool asserted);

MDFN_FASTCALL void IRQ_Write(uint32 A, uint32 V);
MDFN_FASTCALL uint32 IRQ_Read(uint32 A);


enum
{
 IRQ_GSREG_ASSERTED = 0,
 IRQ_GSREG_STATUS = 1,
 IRQ_GSREG_MASK = 2
};

uint32 IRQ_GetRegister(unsigned int which, char *special, const uint32 special_len);
void IRQ_SetRegister(unsigned int which, uint32 value);

void IRQ_StateAction(StateMem *sm, const unsigned load, const bool data_only);
}


#endif
