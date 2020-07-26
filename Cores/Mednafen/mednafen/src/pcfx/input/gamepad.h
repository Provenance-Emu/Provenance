/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* gamepad.h:
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

#ifndef __PCFX_INPUT_GAMEPAD_H
#define __PCFX_INPUT_GAMEPAD_H

namespace MDFN_IEN_PCFX
{

extern const IDIISG PCFX_GamepadIDII;
extern const IDIISG PCFX_GamepadIDII_DSR;

PCFX_Input_Device *PCFXINPUT_MakeGamepad(void);

}

#endif
