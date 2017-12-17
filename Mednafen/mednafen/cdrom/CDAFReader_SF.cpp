/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <mednafen/mednafen.h>
#include "CDAFReader.h"
#include "CDAFReader_SF.h"

#include <sndfile.h>

class CDAFReader_SF final : public CDAFReader
{
 public:

 CDAFReader_SF(Stream *fp);
 ~CDAFReader_SF();

 uint64 Read_(int16 *buffer, uint64 frames) override;
 bool Seek_(uint64 frame_offset) override;
 uint64 FrameCount(void) override;

 private:
 SNDFILE *sf;
 SF_INFO sfinfo;
 SF_VIRTUAL_IO sfvf;

 Stream *fw;
};

static sf_count_t isf_get_filelen(void *user_data)
{
 Stream *fw = (Stream*)user_data;

 try
 {
  return fw->size();
 }
 catch(...)
 {
  return(-1);
 }
}

static sf_count_t isf_seek(sf_count_t offset, int whence, void *user_data)
{
 Stream *fw = (Stream*)user_data;

 try
 {
  //printf("Seek: offset=%lld, whence=%lld\n", (long long)offset, (long long)whence);

  fw->seek(offset, whence);
  return fw->tell();
 }
 catch(...)
 {
  //printf("  SEEK FAILED\n");
  return(-1);
 }
}

static sf_count_t isf_read(void *ptr, sf_count_t count, void *user_data)
{
 Stream *fw = (Stream*)user_data;

 try
 {
  sf_count_t ret = fw->read(ptr, count, false);

  //printf("Read: count=%lld, ret=%lld\n", (long long)count, (long long)ret);

  return ret;
 }
 catch(...)
 {
  //printf("  READ FAILED\n");
  return(0);
 }
}

static sf_count_t isf_write(const void *ptr, sf_count_t count, void *user_data)
{
 return(0);
}

static sf_count_t isf_tell(void *user_data)
{
 Stream *fw = (Stream*)user_data;

 try
 {
  return fw->tell();
 }
 catch(...)
 {
  return(-1);
 }
}

CDAFReader_SF::CDAFReader_SF(Stream *fp) : fw(fp)
{
 memset(&sfvf, 0, sizeof(sfvf));
 sfvf.get_filelen = isf_get_filelen;
 sfvf.seek = isf_seek;
 sfvf.read = isf_read;
 sfvf.write = isf_write;
 sfvf.tell = isf_tell;

 memset(&sfinfo, 0, sizeof(sfinfo));
 if(!(sf = sf_open_virtual(&sfvf, SFM_READ, &sfinfo, (void*)fp)))
  throw(0);
}

CDAFReader_SF::~CDAFReader_SF() 
{
 sf_close(sf);
}

uint64 CDAFReader_SF::Read_(int16 *buffer, uint64 frames)
{
 return(sf_read_short(sf, (short*)buffer, frames * 2) / 2);
}

bool CDAFReader_SF::Seek_(uint64 frame_offset)
{
 // FIXME error condition
 if((uint64)sf_seek(sf, frame_offset, SEEK_SET) != frame_offset)
  return(false);

 return(true);
}

uint64 CDAFReader_SF::FrameCount(void)
{
 return(sfinfo.frames);
}


CDAFReader* CDAFR_SF_Open(Stream* fp)
{
 return new CDAFReader_SF(fp);
}
