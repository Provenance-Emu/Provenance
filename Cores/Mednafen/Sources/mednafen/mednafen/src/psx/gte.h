/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* gte.h:
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

#ifndef __MDFN_PSX_GTE_H
#define __MDFN_PSX_GTE_H

namespace MDFN_IEN_PSX
{

void GTE_Init(void) MDFN_COLD;
void GTE_Power(void) MDFN_COLD;
void GTE_StateAction(StateMem *sm, const unsigned load, const bool data_only);

int32 GTE_Instruction(uint32 instr);

void GTE_WriteCR(unsigned int which, uint32 value);
void GTE_WriteDR(unsigned int which, uint32 value);

uint32 GTE_ReadCR(unsigned int which);
uint32 GTE_ReadDR(unsigned int which);


}

#endif
