/******************************************************************************/
/* Mednafen, Cheat Formats Decoding                                           */
/******************************************************************************/
/* psx.cpp:
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

#include "psx.h"

static void GSCondCode(MemoryPatch* patch, const char* cc, const unsigned len, const uint32 addr, const uint16 val)
{
 char tmp[256];

 if(patch->conditions.size() > 0)
  patch->conditions.append(", ");

 if(len == 2)
  trio_snprintf(tmp, 256, "%u L 0x%08x %s 0x%04x", len, addr, cc, val & 0xFFFFU);
 else
  trio_snprintf(tmp, 256, "%u L 0x%08x %s 0x%02x", len, addr, cc, val & 0xFFU);

 patch->conditions.append(tmp);
}

static bool DecodeGS(const std::string& cheat_string, MemoryPatch* patch)
{
 uint64 code = 0;
 unsigned nybble_count = 0;

 for(unsigned i = 0; i < cheat_string.size(); i++)
 {
  if(cheat_string[i] == ' ' || cheat_string[i] == '-' || cheat_string[i] == ':')
   continue;

  nybble_count++;
  code <<= 4;

  if(cheat_string[i] >= '0' && cheat_string[i] <= '9')
   code |= cheat_string[i] - '0';
  else if(cheat_string[i] >= 'a' && cheat_string[i] <= 'f')
   code |= cheat_string[i] - 'a' + 0xA;
  else if(cheat_string[i] >= 'A' && cheat_string[i] <= 'F')
   code |= cheat_string[i] - 'A' + 0xA;  
  else
  {
   if(cheat_string[i] & 0x80)
    throw MDFN_Error(0, _("Invalid character in GameShark code."));
   else
    throw MDFN_Error(0, _("Invalid character in GameShark code: %c"), cheat_string[i]);
  }
 }

 if(nybble_count != 12)
  throw MDFN_Error(0, _("GameShark code is of an incorrect length."));

 const uint8 code_type = code >> 40;
 const uint64 cl = code & 0xFFFFFFFFFFULL;

 patch->bigendian = false;
 patch->compare = 0;

 if(patch->type == 'T')
 {
  if(code_type != 0x80)
   throw MDFN_Error(0, _("Unrecognized GameShark code type for second part to copy bytes code."));

  patch->addr = cl >> 16;
  return(false);
 }

 switch(code_type)
 {
  default:
	throw MDFN_Error(0, _("GameShark code type 0x%02X is currently not supported."), code_type);

	return(false);

  //
  //
  // TODO:
  case 0x10:	// 16-bit increment
	patch->length = 2;
	patch->type = 'A';
	patch->addr = cl >> 16;
	patch->val = cl & 0xFFFF;
	return(false);

  case 0x11:	// 16-bit decrement
	patch->length = 2;
	patch->type = 'A';
	patch->addr = cl >> 16;
	patch->val = (0 - cl) & 0xFFFF;
	return(false);

  case 0x20:	// 8-bit increment
	patch->length = 1;
	patch->type = 'A';
	patch->addr = cl >> 16;
	patch->val = cl & 0xFF;
	return(false);

  case 0x21:	// 8-bit decrement
	patch->length = 1;
	patch->type = 'A';
	patch->addr = cl >> 16;
	patch->val = (0 - cl) & 0xFF;
	return(false);
  //
  //
  //

  case 0x30:	// 8-bit constant
	patch->length = 1;
	patch->type = 'R';
	patch->addr = cl >> 16;
	patch->val = cl & 0xFF;
	return(false);

  case 0x80:	// 16-bit constant
	patch->length = 2;
	patch->type = 'R';
	patch->addr = cl >> 16;
	patch->val = cl & 0xFFFF;
	return(false);

  case 0x50:	// Repeat thingy
	{
	 const uint8 wcount = (cl >> 24) & 0xFF;
	 const uint8 addr_inc = (cl >> 16) & 0xFF;
	 const uint8 val_inc = (cl >> 0) & 0xFF;

	 patch->mltpl_count = wcount;
	 patch->mltpl_addr_inc = addr_inc;
	 patch->mltpl_val_inc = val_inc;
	}
	return(true);

  case 0xC2:	// Copy
	{
	 const uint16 ccount = cl & 0xFFFF;

	 patch->type = 'T';
	 patch->val = 0;
	 patch->length = 1;

	 patch->copy_src_addr = cl >> 16;
	 patch->copy_src_addr_inc = 1;

	 patch->mltpl_count = ccount;
	 patch->mltpl_addr_inc = 1;
	 patch->mltpl_val_inc = 0;
	}
	return(true);

  case 0xD0:	// 16-bit == condition
	GSCondCode(patch, "==", 2, cl >> 16, cl);
	return(true);

  case 0xD1:	// 16-bit != condition
	GSCondCode(patch, "!=", 2, cl >> 16, cl);
	return(true);

  case 0xD2:	// 16-bit < condition
	GSCondCode(patch, "<", 2, cl >> 16, cl);
	return(true);

  case 0xD3:	// 16-bit > condition
	GSCondCode(patch, ">", 2, cl >> 16, cl);
	return(true);



  case 0xE0:	// 8-bit == condition
	GSCondCode(patch, "==", 1, cl >> 16, cl);
	return(true);

  case 0xE1:	// 8-bit != condition
	GSCondCode(patch, "!=", 1, cl >> 16, cl);
	return(true);

  case 0xE2:	// 8-bit < condition
	GSCondCode(patch, "<", 1, cl >> 16, cl);
	return(true);

  case 0xE3:	// 8-bit > condition
	GSCondCode(patch, ">", 1, cl >> 16, cl);
	return(true);

 }
}

const std::vector<CheatFormatStruct> CheatFormats_PSX =
{
 { "GameShark", gettext_noop("Sharks with lamprey eels for eyes."), DecodeGS },
};

