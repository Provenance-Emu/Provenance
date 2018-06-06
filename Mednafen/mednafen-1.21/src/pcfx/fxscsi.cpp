/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* fxscsi.cpp:
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

#include "pcfx.h"
#include "fxscsi.h"

namespace MDFN_IEN_PCFX
{

bool FXSCSI_Init(void)
{

 return true;
}

uint8 FXSCSI_CtrlRead(uint32 A)
{
 uint8 ret = 0; //rand();
 //printf("FXSCSI: %08x(ret=%02x)\n", A, ret);
 return(ret);
}


void FXSCSI_CtrlWrite(uint32 A, uint8 V)
{
 printf("FXSCSI Write: %08x %02x\n", A, V);
}

}
