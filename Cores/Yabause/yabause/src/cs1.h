/*  Copyright 2003-2005 Guillaume Duhamel
    Copyright 2005 Theo Berkau

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#ifndef CS1_H
#define CS1_H

#include "cs0.h"
#include "memory.h"

u8 FASTCALL 	Cs1ReadByte(u32);
u16 FASTCALL 	Cs1ReadWord(u32);
u32 FASTCALL 	Cs1ReadLong(u32);
void FASTCALL 	Cs1WriteByte(u32, u8);
void FASTCALL 	Cs1WriteWord(u32, u16);
void FASTCALL 	Cs1WriteLong(u32, u32);

#endif
