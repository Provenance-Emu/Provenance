/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* SPCReader.h:
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

#ifndef __MDFN_SPCREADER_H
#define __MDFN_SPCREADER_H

#include <mednafen/Stream.h>

class SPCReader
{
 public:

 static bool TestMagic(Stream* fp);

 SPCReader(Stream* fp);
 ~SPCReader();

 INLINE const uint8* APURAM(void) { return apuram; }
 INLINE const uint8* DSPRegs(void) { return dspregs; }

 INLINE uint16 PC(void) { return reg_pc; }
 INLINE uint8 A(void) { return reg_a; }
 INLINE uint8 X(void) { return reg_x; }
 INLINE uint8 Y(void) { return reg_y; }
 INLINE uint8 PSW(void) { return reg_psw; }
 INLINE uint8 SP(void) { return reg_sp; }

 INLINE std::string GameName(void) { return game_name; }
 INLINE std::string ArtistName(void) { return artist_name; }
 INLINE std::string SongName(void) { return song_name; }

 private:
 uint8 apuram[65536];
 uint8 dspregs[128];

 uint16 reg_pc;
 uint8 reg_a, reg_x, reg_y;
 uint8 reg_psw;
 uint8 reg_sp;

 std::string game_name;
 std::string artist_name;
 std::string song_name;
};


#endif
