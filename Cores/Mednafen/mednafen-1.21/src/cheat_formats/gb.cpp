/******************************************************************************/
/* Mednafen, Cheat Formats Decoding                                           */
/******************************************************************************/
/* gb.cpp:
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

#include <mednafen/mednafen.h>
#include <mednafen/mempatcher.h>

#include <trio/trio.h>

#include "gb.h"

static uint8 CharToNibble(char thechar)
{
 const char lut[16] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };

 thechar = MDFN_azupper(thechar);

 for(int x = 0; x < 16; x++)
  if(lut[x] == thechar)
   return(x);

 return(0xFF);
}

static bool DecodeGG(const std::string& cheat_string, MemoryPatch* patch)
{
 char str[10];
 unsigned len;

 memset(str, 0, sizeof(str));

 switch(cheat_string.size())
 {
  default:
 	throw(MDFN_Error(0, _("Game Genie code is of an incorrect length.")));
	break;

  case 6:
  case 9:
	strcpy(str, cheat_string.c_str());
	break;

  case 11:
	if(cheat_string[7] != '-' && cheat_string[7] != '_' && cheat_string[7] != ' ')
	 throw(MDFN_Error(0, _("Game Genie code is malformed.")));

	str[6] = cheat_string[8];
	str[7] = cheat_string[9];
	str[8] = cheat_string[10];

  case 7:
	if(cheat_string[3] != '-' && cheat_string[3] != '_' && cheat_string[3] != ' ')
	 throw(MDFN_Error(0, _("Game Genie code is malformed.")));

 	str[0] = cheat_string[0];
	str[1] = cheat_string[1];
	str[2] = cheat_string[2];

	str[3] = cheat_string[4];
	str[4] = cheat_string[5];
	str[5] = cheat_string[6];
	break;
 }

 len = strlen(str);

 for(unsigned x = 0; x < len; x++)
 {
  if(CharToNibble(str[x]) == 0xFF)
  {
   if(str[x] & 0x80)
    throw MDFN_Error(0, _("Invalid character in Game Genie code."));
   else
    throw MDFN_Error(0, _("Invalid character in Game Genie code: %c"), str[x]);
  }
 }

 uint32 tmp_address;
 uint8 tmp_value;
 uint8 tmp_compare = 0;

 tmp_address =  (CharToNibble(str[5]) << 12) | (CharToNibble(str[2]) << 8) | (CharToNibble(str[3]) << 4) | (CharToNibble(str[4]) << 0);
 tmp_address ^= 0xF000;
 tmp_value = (CharToNibble(str[0]) << 4) | (CharToNibble(str[1]) << 0);

 if(len == 9)
 {
  tmp_compare = (CharToNibble(str[6]) << 4) | (CharToNibble(str[8]) << 0);
  tmp_compare = (tmp_compare >> 2) | ((tmp_compare << 6) & 0xC0);
  tmp_compare ^= 0xBA;
 }

 patch->addr = tmp_address;
 patch->val = tmp_value;

 if(len == 9)
 {
  patch->compare = tmp_compare;
  patch->type = 'C';
 }
 else
 {
  patch->compare = 0;
  patch->type = 'S';
 }

 patch->length = 1;

 return(false);
}

static bool DecodeGS(const std::string& cheat_string, MemoryPatch* patch)
{
 if(cheat_string.size() != 8)
  throw MDFN_Error(0, _("GameShark code is of an incorrect length."));

 for(unsigned x = 0; x < 8; x++)
 {
  if(CharToNibble(cheat_string[x]) == 0xFF)
  {
   if(cheat_string[x] & 0x80)
    throw MDFN_Error(0, _("Invalid character in GameShark code."));
   else
    throw MDFN_Error(0, _("Invalid character in GameShark code: %c"), cheat_string[x]);
  }
 }
 uint8 bank = 0;
 uint16 la = 0;


 bank = (CharToNibble(cheat_string[0]) << 4) | (CharToNibble(cheat_string[1]) << 0);
 for(unsigned x = 0; x < 4; x++)
  la |= CharToNibble(cheat_string[4 + x]) << ((x ^ 1) * 4);

 if(la >= 0xD000 && la <= 0xDFFF)
  patch->addr = 0x10000 | ((bank & 0x7) << 12) | (la & 0xFFF);
 else
  patch->addr = la;

 patch->val = (CharToNibble(cheat_string[2]) << 4) | (CharToNibble(cheat_string[3]) << 0);

 patch->compare = 0;
 patch->type = 'R';
 patch->length = 1;

 return(false);
}

const std::vector<CheatFormatStruct> CheatFormats_GB =
{
 { "Game Genie", gettext_noop("Genies will eat your goats."), DecodeGG },
 { "GameShark", gettext_noop("Sharks in your soup."), DecodeGS },
};

