/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef ENDIANESS
#define ENDIANESS

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _BIG_ENDIAN
static __inline uint32_t Endian32(uint32_t val)
{
	return (val >> 24) | (val >> 8 & 0x0000FF00) | (val << 8 & 0x00FF0000) | (val << 24);
}
static __inline uint16_t Endian16(uint16_t val)
{
	return (val >> 8) | (val << 8);
}
#else
static __inline uint32_t Endian32(uint32_t val)
{
	return val;
}
static __inline uint16_t Endian16(uint16_t val)
{
	return val;
}
#endif

#ifdef __cplusplus
}
#endif

#endif
