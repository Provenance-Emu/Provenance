/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* cart-private.h:
**  Copyright (C) 2019 Mednafen Team
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

#ifndef __MDFN_SNES_FAUST_CART_PRIVATE_H
#define __MDFN_SNES_FAUST_CART_PRIVATE_H

namespace MDFN_IEN_SNES_FAUST
{

enum
{
 ROM_LAYOUT_LOROM = 0,
 ROM_LAYOUT_HIROM,
 ROM_LAYOUT_EXLOROM,
 ROM_LAYOUT_EXHIROM,

 ROM_LAYOUT_INVALID = 0xFFFFFFFF
};

struct CartInfo
{
 void (*Reset)(bool powering_up);
 void (*Kill)(void);

 void (*StateAction)(StateMem* sm, const unsigned load, const bool data_only);

 void (*AdjustTS)(const int32 delta);

 snes_event_handler EventHandler;
 //
 //
 //
 uint8* RAM;
 size_t RAM_Mask;
 size_t RAM_Size;

 size_t ROM_Size;
 unsigned ROMLayout;
 //
 uint8 ROM[8192 * 1024];
};

 MDFN_HIDE extern CartInfo Cart;
}

#endif
