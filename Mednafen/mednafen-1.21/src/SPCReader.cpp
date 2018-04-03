/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* SPCReader.cpp:
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

#include <mednafen/mednafen.h>
#include <mednafen/SPCReader.h>
#include <mednafen/string/string.h>

bool SPCReader::TestMagic(Stream* fp)
{
#if 0
 return true;
#endif
 static const char* spc_magic = "SNES-SPC700 Sound File Data";
 uint8 header[0x100];
 uint64 rc;

 if(fp->size() < 0x10200)
  return false;

 rc = fp->read(header, sizeof(header), false);
 fp->rewind();

 if(rc != sizeof(header))
  return false;

 if(memcmp(header, spc_magic, strlen(spc_magic)))
  return false;

 return true;
}

static std::string GrabString(Stream* fp, size_t len)
{
 std::string ret;
 size_t null_pos;

 ret.resize(len);
 fp->read(&ret[0], len);

 null_pos = ret.find('\0');	// ANDDYYYYYYYYY
 if(null_pos != std::string::npos)
  ret.resize(null_pos);

 MDFN_zapctrlchars(ret);
 MDFN_trim(ret);

 return ret;
}

SPCReader::SPCReader(Stream* fp)
{
#if 0
 reg_pc = 0x430;
 reg_a = 0;
 reg_x = 0;
 reg_y = 0;
 reg_psw = 0;
 reg_sp = 0xFF;

 memset(apuram, 0x00, sizeof(apuram));
 memset(dspregs, 0x00, sizeof(dspregs));
 dspregs[0x6C] = 0xE0;

 fp->read(&apuram[0x400], 0x1000);
 return;
#endif

 if(!TestMagic(fp))
  throw MDFN_Error(0, _("Not a valid SPC file!"));

 uint8 header[0x100];

 fp->rewind();
 fp->read(header, sizeof(header));

 reg_pc = MDFN_de16lsb(&header[0x25]);
 reg_a = header[0x27];
 reg_x = header[0x28];
 reg_y = header[0x29];
 reg_psw = header[0x2A];
 reg_sp = header[0x2B];

 fp->read(apuram, 65536);
 fp->read(dspregs, 0x80);
 fp->seek(0x101C0, SEEK_SET);
 fp->read(apuram + 0xFFC0, 0x40);

 if(header[0x23] == 0x1A)
 {
  bool binary_tags = true;

  if(header[0xA0] == '/' && header[0xA3] == '/')
   binary_tags = false;

  if(header[0xD2] >= '0' && header[0xD2] <= '9' && header[0xD3] == 0x00)
   binary_tags = false;

  fp->seek(0x2E, SEEK_SET);

  song_name = GrabString(fp, 32);
  game_name = GrabString(fp, 32);

  fp->seek(binary_tags ? 0xB0 : 0xB1, SEEK_SET);
  artist_name = GrabString(fp, 32);
 }

 //
 //
 //
#if 0
 fp->seek(0x10200, SEEK_SET);
 uint8 xid_header[8];

 if(fp->read(xid_header, sizeof(xid_header), false) == sizeof(xid_header) && !memcmp(xid_header, "xid6", 4))
 {
  uint8 sub_header[4];

  while(fp->read(sub_header, sizeof(sub_header), false) == sizeof(sub_header))
  {
   const uint8 id = sub_header[0];
   const uint8 type = sub_header[1];
   uint16 len = MDFN_de16lsb(&sub_header[2]);

   printf("ID: 0x%02x, Type: 0x%02x, Len: 0x%04x\n", id, type, len);

   if(type == 1 && len > 4)
    len = (len + 3) &~ 3;

   switch(id)
   {
    default:
	if(type)
	 fp->seek(len, SEEK_CUR);
	break;
 
    case 0x01: song_name = GrabString(fp, len); break;
    case 0x02: game_name = GrabString(fp, len); break;
    case 0x03: artist_name = GrabString(fp, len); break;
   }
  }
 }
#endif
}

SPCReader::~SPCReader()
{

}
