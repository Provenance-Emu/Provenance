/******************************************************************************/
/* Mednafen, Cheat Formats Decoding                                           */
/******************************************************************************/
/* snes.cpp:
**  Copyright (C) 2013-2016 Mednafen Team
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

#include <mednafen/mednafen.h>
#include <mednafen/mempatcher.h>

#include <trio/trio.h>

#include "snes.h"

static bool DecodeGG(const std::string& cheat_string, MemoryPatch* patch)
{
 if(cheat_string.size() != 8 && cheat_string.size() != 9)
  throw MDFN_Error(0, _("Game Genie code is of an incorrect length."));

 if(cheat_string.size() == 9 && (cheat_string[4] != '-' && cheat_string[4] != '_' && cheat_string[4] != ' '))
  throw MDFN_Error(0, _("Game Genie code is malformed."));

 uint32 ev = 0;

 for(unsigned i = 0; i < 8; i++)
 {
  int c = cheat_string[(i >= 4 && cheat_string.size() == 9) ? (i + 1) : i];
  static const uint8 subst_table[16] = { 0x4, 0x6, 0xD, 0xE, 0x2, 0x7, 0x8, 0x3,
				  	 0xB, 0x5, 0xC, 0x9, 0xA, 0x0, 0xF, 0x1 };
  ev <<= 4;

  if(c >= '0' && c <= '9')
   ev |= subst_table[c - '0'];
  else if(c >= 'a' && c <= 'f')
   ev |= subst_table[c - 'a' + 0xA];
  else if(c >= 'A' && c <= 'F')
   ev |= subst_table[c - 'A' + 0xA];
  else
  {
   if(c & 0x80)
    throw MDFN_Error(0, _("Invalid character in Game Genie code."));
   else
    throw MDFN_Error(0, _("Invalid character in Game Genie code: %c"), c);
  }
 }

 uint32 addr = 0;
 uint8 val = 0;
 static const uint8 bm[24] = 
 {
  0x06, 0x07, 0x08, 0x09, 0x10, 0x11, 0x12, 0x13, 0x0e, 0x0f, 0x00, 0x01, 0x14, 0x15, 0x16, 0x17, 0x02, 0x03, 0x04, 0x05, 0x0a, 0x0b, 0x0c, 0x0d
 };


 val = ev >> 24;
 for(unsigned i = 0; i < 24; i++)
  addr |= ((ev >> bm[i]) & 1) << i;

 patch->addr = addr;
 patch->val = val;
 patch->length = 1;
 patch->type = 'S';

 //printf("%08x %02x\n", addr, val);

 return(false);
}

static bool DecodePAR(const std::string& cheat_string, MemoryPatch* patch)
{
 if(cheat_string.size() != 8 && cheat_string.size() != 9)
  throw MDFN_Error(0, _("Pro Action Replay code is of an incorrect length."));

 if(cheat_string.size() == 9 && (cheat_string[6] != ':' && cheat_string[6] != ';' && cheat_string[6] != ' '))
  throw MDFN_Error(0, _("Pro Action Replay code is malformed."));


 uint32 ev = 0;

 for(unsigned i = 0; i < 8; i++)
 {
  int c = cheat_string[(i >= 6 && cheat_string.size() == 9) ? (i + 1) : i];

  ev <<= 4;

  if(c >= '0' && c <= '9')
   ev |= c - '0';
  else if(c >= 'a' && c <= 'f')
   ev |= c - 'a' + 0xA;
  else if(c >= 'A' && c <= 'F')
   ev |= c - 'A' + 0xA;
  else
  {
   if(c & 0x80)
    throw MDFN_Error(0, _("Invalid character in Pro Action Replay code."));
   else
    throw MDFN_Error(0, _("Invalid character in Pro Action Replay code: %c"), c);
  }
 }

 patch->addr = ev >> 8;
 patch->val = ev & 0xFF;
 patch->length = 1;
 patch->type = 'R';

 return(false);
}

const std::vector<CheatFormatStruct> CheatFormats_SNES =
{
 { "Game Genie", "", DecodeGG },
 { "Pro Action Replay", "", DecodePAR },
};

