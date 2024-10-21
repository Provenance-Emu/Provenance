/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* SNSFLoader.cpp:
**  Copyright (C) 2012-2016 Mednafen Team
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
#include <mednafen/SNSFLoader.h>

namespace Mednafen
{

bool SNSFLoader::TestMagic(Stream* fp)
{
 return PSFLoader::TestMagic(0x23, fp);
}

SNSFLoader::SNSFLoader(VirtualFS* vfs, const std::string& dir_path, Stream* fp)
{
 tags = Load(0x23, 8 + 1024 * 8192, vfs, dir_path, fp);

 assert(ROM_Data.size() <= 8192 * 1024);
}

SNSFLoader::~SNSFLoader()
{

}

void SNSFLoader::HandleReserved(Stream* fp, uint32 len)
{
 uint64 bound_pos = fp->tell() + len;

 if(len < 9)
  return;

 while(fp->tell() < bound_pos)
 {
  uint8 raw_header[8];
  uint32 header_type;
  uint32 header_size;

  fp->read(raw_header, sizeof(raw_header));

  header_type = MDFN_de32lsb(&raw_header[0]);
  header_size = MDFN_de32lsb(&raw_header[4]);

  switch(header_type)
  {
   case 0xFFFFFFFF:	// EOR
	goto Breakout;

   default:
	throw MDFN_Error(0, _("SNSF Reserved Section Unknown/Unsupported Data Type 0x%08x"), header_type);
	break;

   case 0:	// SRAM
	{
	 uint8 raw_subheader[4];
	 uint32 srd_offset, srd_size;

	 fp->read(raw_subheader, sizeof(raw_subheader));

	 srd_offset = MDFN_de32lsb(&raw_subheader[0]);
	 srd_size = header_size - 4;

	 if(srd_size > 0x20000)
	 {
	  throw MDFN_Error(0, _("SNSF Reserved Section SRAM block size(=%u) is too large."), srd_size);
	 }

	 if(((uint64)srd_offset + srd_size) > 0x20000)
	 {
	  throw MDFN_Error(0, _("SNSF Reserved Section SRAM block combined offset+size(=%llu) is too large."), (unsigned long long)srd_offset + srd_size);
	 }

	 MDFN_printf("SNSF SRAM Data: Offset=0x%08x, Size=0x%08x\n", srd_offset, srd_size);

	 if((srd_offset + srd_size) > SRAM_Data.size())
	 {
	  const size_t old_size = SRAM_Data.size();

	  SRAM_Data.truncate(srd_offset + srd_size);

	  if(srd_offset > old_size)
	   memset(SRAM_Data.map() + old_size, 0xFF, srd_offset - old_size);
	 }

	 fp->read(&SRAM_Data.map()[srd_offset], srd_size);
	}
	break;
  }
 }

 Breakout:;

 if(fp->tell() != bound_pos)
  throw MDFN_Error(0, _("Malformed SNSF reserved section."));
}


void SNSFLoader::HandleEXE(Stream* fp, bool ignore_pcsp)
{
 uint8 raw_header[8];

 fp->read(raw_header, sizeof(raw_header));

 const uint32 header_size = MDFN_de32lsb(&raw_header[4]);
 uint32 adj_offset;
 {
  const uint32 header_offset = MDFN_de32lsb(&raw_header[0]);

  if(ROM_BaseOffset < 0)
  {
   ROM_BaseOffset = header_offset;
   adj_offset = ROM_BaseOffset;
  }
  else
   adj_offset = ROM_BaseOffset + header_offset;

  MDFN_printf("SNSF ROM Data: SNSF_Offset=0x%08x(adjusted: 0x%08x) Size=0x%08x\n", header_offset, adj_offset, header_size);
 }

 if(adj_offset > (1024 * 8192))
 {
  throw MDFN_Error(0, _("SNSF Adjusted Offset(=%u) is too large."), adj_offset);
 }

 if(header_size > (1024 * 8192))
 {
  throw MDFN_Error(0, _("SNSF Header Field Size(=%u) is too large."), header_size);
 }

 if(((uint64)adj_offset + header_size) > (1024 * 8192))
 {
  throw MDFN_Error(0, _("SNSF Combined Adjusted Offset(=%u) + Size(=%u) is too large."), adj_offset, header_size);
 }

 if((adj_offset + header_size) > ROM_Data.size())
  ROM_Data.truncate(adj_offset + header_size);

 fp->read(&ROM_Data.map()[adj_offset], header_size);
}

}
