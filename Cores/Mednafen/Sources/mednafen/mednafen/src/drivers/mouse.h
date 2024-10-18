/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* mouse.h:
**  Copyright (C) 2017 Mednafen Team
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

#ifndef __MDFN_DRIVERS_MOUSE_H
#define __MDFN_DRIVERS_MOUSE_H

namespace MouseMan
{

enum
{
 MOUSE_BN_INDEX_MASK	= 0x0FFF,

 MOUSE_BN_TYPE_SHIFT	= 12,
 MOUSE_BN_TYPE_MASK	= 0x3 << MOUSE_BN_TYPE_SHIFT,
 MOUSE_BN_TYPE_BUTTON	= 0U << MOUSE_BN_TYPE_SHIFT,
 MOUSE_BN_TYPE_CURSOR	= 1U << MOUSE_BN_TYPE_SHIFT,
 MOUSE_BN_TYPE_REL	= 2U << MOUSE_BN_TYPE_SHIFT,

 MOUSE_BN_HALFAXIS	= 1U << 14,
 MOUSE_BN_NEGATE	= 1U << 15
};

void Init(void) MDFN_COLD;
std::string BNToString(const uint32 bn);
bool StringToBN(const char* s, uint16* bn);
bool Translate09xBN(unsigned bn09x, uint16* bn);

void UpdateMice(void);
void Reset_BC_ChangeCheck(void);
bool Do_BC_ChangeCheck(ButtConfig *bc);

bool TestButton(const ButtConfig& bc);
int32 TestAnalogButton(const ButtConfig& bc);
float TestPointer(const ButtConfig& bc);
int64 TestAxisRel(const ButtConfig& bc);

void Event(const SDL_Event* event);

}
#endif
