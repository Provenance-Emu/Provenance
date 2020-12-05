/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* huc6273.h:
**  Copyright (C) 2007-2016 Mednafen Team
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

#ifndef __PCFX_HUC6273_H
#define __PCFX_HUC6273_H

namespace MDFN_IEN_PCFX
{

bool HuC6273_Init(void) MDFN_COLD;

uint8 HuC6273_Read8(uint32 A);
uint16 HuC6273_Read16(uint32 A);
void HuC6273_Write16(uint32 A, uint16 V);
void HuC6273_Write8(uint32 A, uint8 V);
void HuC6273_Reset(void) MDFN_COLD;

}

#endif
