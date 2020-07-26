/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDInterface.cpp:
**  Copyright (C) 2009-2018 Mednafen Team
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
#include <mednafen/cdrom/CDInterface.h>
#include "CDInterface_MT.h"
#include "CDInterface_ST.h"
#include "CDAccess.h"

namespace Mednafen
{

using namespace CDUtility;

CDInterface::CDInterface() : UnrecoverableError(false)
{


}

CDInterface::~CDInterface()
{


}

bool CDInterface::NonDeterministic_CheckSectorReady(int32 lba)
{
 return true;
}

uint8 CDInterface::ReadSectors(uint8* buf, int32 lba, uint32 sector_count)
{
 uint8 ret = 0;

 if(UnrecoverableError)
  return 0;

 while(sector_count--)
 {
  uint8 rawbuf[2352 + 96];
  uint8 mode;

  if(!ReadRawSector(rawbuf, lba))
  {
   printf("ReadRawSector() failed in CDInterface::ReadSectors() for LBA=%d.\n", lba);
   return 0;
  }

  mode = rawbuf[12 + 3];
  if(mode != 0x1 && mode != 0x2)
   return 0;

  // Error if mode 2 form 2.
  if(mode == 0x2 && (rawbuf[12 + 6] & 0x20))
   return 0;

  if(!edc_lec_check_and_correct(rawbuf, mode == 2))
   return false;

  memcpy(buf, rawbuf + ((mode == 2) ? 24 : 16), 2048);
  ret = ret ? ret : mode;

  lba++;
  buf += 2048;
 }

 return ret;
}


class CDInterface_Stream_Thing : public Stream
{
 public:

 CDInterface_Stream_Thing(CDInterface *cdintf_arg, uint32 lba_arg, uint32 sector_count_arg);
 ~CDInterface_Stream_Thing();

 virtual uint64 attributes(void) override;
  
 virtual uint64 read(void *data, uint64 count, bool error_on_eos = true) override;
 virtual void write(const void *data, uint64 count) override;
 virtual void truncate(uint64 length) override;

 virtual void seek(int64 offset, int whence) override;
 virtual uint64 tell(void) override;
 virtual uint64 size(void) override;
 virtual void flush(void) override;
 virtual void close(void) override;

 private:
 CDInterface *cdintf;
 const uint32 start_lba;
 const uint32 sector_count;
 int64 position;
};

CDInterface_Stream_Thing::CDInterface_Stream_Thing(CDInterface *cdintf_arg, uint32 start_lba_arg, uint32 sector_count_arg) : cdintf(cdintf_arg), start_lba(start_lba_arg), sector_count(sector_count_arg)
{

}

CDInterface_Stream_Thing::~CDInterface_Stream_Thing()
{

}

uint64 CDInterface_Stream_Thing::attributes(void)
{
 return(ATTRIBUTE_READABLE | ATTRIBUTE_SEEKABLE);
}
  
uint64 CDInterface_Stream_Thing::read(void *data, uint64 count, bool error_on_eos)
{
 if(count > (((uint64)sector_count * 2048) - position))
 {
  if(error_on_eos)
  {
   throw MDFN_Error(0, "EOF");
  }

  count = ((uint64)sector_count * 2048) - position;
 }

 if(!count)
  return(0);

 for(uint64 rp = position; rp < (position + count); rp = (rp &~ 2047) + 2048)
 {
  uint8 buf[2048];  

  if(!cdintf->ReadSectors(buf, start_lba + (rp / 2048), 1))
  {
   throw MDFN_Error(ErrnoHolder(EIO));
  }
  
  //::printf("Meow: %08llx -- %08llx\n", count, (rp - position) + std::min<uint64>(2048 - (rp & 2047), count - (rp - position)));
  memcpy((uint8*)data + (rp - position), buf + (rp & 2047), std::min<uint64>(2048 - (rp & 2047), count - (rp - position)));
 }

 position += count;

 return count;
}

void CDInterface_Stream_Thing::write(const void *data, uint64 count)
{
 throw MDFN_Error(ErrnoHolder(EBADF));
}

void CDInterface_Stream_Thing::truncate(uint64 length)
{
 throw MDFN_Error(ErrnoHolder(EBADF));
}

void CDInterface_Stream_Thing::seek(int64 offset, int whence)
{
 int64 new_position;

 switch(whence)
 {
  default:
	throw MDFN_Error(ErrnoHolder(EINVAL));
	break;

  case SEEK_SET:
	new_position = offset;
	break;

  case SEEK_CUR:
	new_position = position + offset;
	break;

  case SEEK_END:
	new_position = ((int64)sector_count * 2048) + offset;
	break;
 }

 if(new_position < 0 || new_position > ((int64)sector_count * 2048))
  throw MDFN_Error(ErrnoHolder(EINVAL));

 position = new_position;
}

uint64 CDInterface_Stream_Thing::tell(void)
{
 return position;
}

uint64 CDInterface_Stream_Thing::size(void)
{
 return(sector_count * 2048);
}

void CDInterface_Stream_Thing::flush(void)
{

}

void CDInterface_Stream_Thing::close(void)
{

}


Stream *CDInterface::MakeStream(int32 lba, uint32 sector_count)
{
 return new CDInterface_Stream_Thing(this, lba, sector_count);
}


CDInterface* CDInterface::Open(VirtualFS* vfs, const std::string& path, bool image_memcache, const uint64 affinity)
{
 std::unique_ptr<CDAccess> cda(CDAccess_Open(vfs, path, image_memcache));

 //
 // Don't use multithreaded reader if we're using a custom VirtualFS implementation, to avoid
 // thread safety nightmares.
 //
 if(image_memcache || (vfs != &NVFS))
  return new CDInterface_ST(std::move(cda));
 else
  return new CDInterface_MT(std::move(cda), affinity);
}

}
