/*
Copyright (C) 2004 NSRT Team ( http://nsrt.edgeemu.com )

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#ifndef CRC32_H
#define CRC32_H

namespace CRC32lib
{
  unsigned int CRC32(const unsigned char *, size_t, register unsigned int crc32 = 0xFFFFFFFF);
  unsigned short SUM_CRC32(const unsigned char *, size_t, unsigned int &crc32);
}

#endif
