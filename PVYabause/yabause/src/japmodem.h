/*  Copyright 2013 Theo Berkau

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

#ifndef JAPMODEM_H
#define JAPMODEM_H

typedef struct
{
   unsigned char flash[0x20000];
} JapModem;

u8 FASTCALL JapModemCs0ReadByte(u32 addr);
u16 FASTCALL JapModemCs0ReadWord(UNUSED u32 addr);
u32 FASTCALL JapModemCs0ReadLong(UNUSED u32 addr);
u8 FASTCALL JapModemCs1ReadByte(UNUSED u32 addr);
u16 FASTCALL JapModemCs1ReadWord(UNUSED u32 addr);
u32 FASTCALL JapModemCs1ReadLong(UNUSED u32 addr);
void FASTCALL JapModemCs1WriteByte(u32 addr, u8 val);
void FASTCALL JapModemCs1WriteWord(u32 addr, u16 val);
void FASTCALL JapModemCs1WriteLong(u32 addr, u32 val);
u8 FASTCALL JapModemCs2ReadByte(u32 addr);
void FASTCALL JapModemCs2WriteByte(u32 addr, u8 val);
int JapModemInit(const char *ip, const char *port);
void JapModemDeInit(void);
void JapModemExec(u32 timing);

#endif
