/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* SSFLoader.cpp:
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
#include <mednafen/SSFLoader.h>

bool SSFLoader::TestMagic(Stream* fp)
{
 return PSFLoader::TestMagic(0x11, fp);
}

SSFLoader::SSFLoader(Stream *fp)
{
 tags = Load(0x11, 4 + 524288, fp);
 assert(RAM_Data.size() <= 524288);
}

SSFLoader::~SSFLoader()
{

}

void SSFLoader::HandleEXE(Stream* fp, bool ignore_pcsp)
{
 uint8 raw_load_addr[4];
 uint32 load_addr;
 uint32 load_size;

 fp->read(raw_load_addr, sizeof(raw_load_addr));
 load_addr = MDFN_de32lsb(raw_load_addr);

 if(load_addr >= 524288)
  throw MDFN_Error(0, _("SSF Load Address(=0x%08x) is too high."), load_addr);

 load_size = 524288 - load_addr;

 if((load_addr + load_size) > RAM_Data.size())
  RAM_Data.truncate(load_addr + load_size);

 fp->read(&RAM_Data.map()[load_addr], load_size, false);
}

