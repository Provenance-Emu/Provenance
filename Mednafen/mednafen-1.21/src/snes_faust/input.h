/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* input.h:
**  Copyright (C) 2015-2016 Mednafen Team
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

#ifndef __MDFN_SNES_FAUST_INPUT_H
#define __MDFN_SNES_FAUST_INPUT_H

namespace MDFN_IEN_SNES_FAUST
{
 void INPUT_Init(void) MDFN_COLD;
 void INPUT_Kill(void) MDFN_COLD;
 void INPUT_Reset(bool powering_up) MDFN_COLD;
 void INPUT_StateAction(StateMem* sm, const unsigned load, const bool data_only);
 void INPUT_Set(unsigned port, const char* type, uint8* ptr) MDFN_COLD;
 void INPUT_UpdatePhysicalState(void);
 void INPUT_SetMultitap(const bool (&enabled)[2]) MDFN_COLD;

 void INPUT_AutoRead(void) MDFN_HOT;

 extern const std::vector<InputPortInfoStruct> INPUT_PortInfo;
}

#endif
