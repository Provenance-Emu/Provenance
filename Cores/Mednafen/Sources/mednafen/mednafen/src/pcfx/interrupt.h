/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* interrupt.h:
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

#ifndef __PCFX_INTERRUPT_H
#define __PCFX_INTERRUPT_H

namespace MDFN_IEN_PCFX
{
#define PCFXIRQ_SOURCE_TIMER	1
#define PCFXIRQ_SOURCE_EX	2
#define PCFXIRQ_SOURCE_INPUT	3
#define PCFXIRQ_SOURCE_VDCA	4
#define PCFXIRQ_SOURCE_KING	5
#define PCFXIRQ_SOURCE_VDCB	6
#define PCFXIRQ_SOURCE_HUC6273  7

void PCFXIRQ_Assert(int source, bool assert);
void PCFXIRQ_Write16(uint32 A, uint16 V);
uint16 PCFXIRQ_Read16(uint32 A);
uint8 PCFXIRQ_Read8(uint32 A);
void PCFXIRQ_StateAction(StateMem *sm, const unsigned load, const bool data_only);

void PCFXIRQ_Reset(void) MDFN_COLD;

enum
{
 PCFXIRQ_GSREG_IMASK = 0,
 PCFXIRQ_GSREG_IPRIO0,
 PCFXIRQ_GSREG_IPRIO1,
 PCFXIRQ_GSREG_IPEND
};

uint32 PCFXIRQ_GetRegister(const unsigned int id, char *special, const uint32 special_len);
void PCFXIRQ_SetRegister(const unsigned int id, uint32 value);

}

#endif
