/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* fxscsi.h:
**  Copyright (C) 2009-2016 Mednafen Team
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

#ifndef __MDFN_FXSCSI_H
#define __MDFN_FXSCSI_H

namespace MDFN_IEN_PCFX
{

bool FXSCSI_Init(void) MDFN_COLD;
uint8 FXSCSI_CtrlRead(uint32 A);
void FXSCSI_CtrlWrite(uint32 A, uint8 V);

}
#endif
