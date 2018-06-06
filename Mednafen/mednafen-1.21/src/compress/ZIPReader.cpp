/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ZIPReader.cpp:
**  Copyright (C) 2018 Mednafen Team
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

// TODO: 64-bit ZIP support(limit sizes to 2**63 - 2?)
// TODO: Stream::clone()

#include <mednafen/mednafen.h>
#include "ZIPReader.h"
#include "ZLInflateFilter.h"

class StreamViewFilter : public Stream
{
 public:

 StreamViewFilter(Stream* source_stream, const std::string& vfp, uint64 sp, uint64 bp, uint64 expcrc32 = ~(uint64)0);
 virtual ~StreamViewFilter() override;
 virtual uint64 read(void *data, uint64 count, bool error_on_eos = true) override;
 virtual void write(const void *data, uint64 count) override;
 virtual void seek(int64 offset, int whence) override;
 virtual uint64 tell(void) override;
 virtual uint64 size(void) override;
 virtual void close(void) override;
 virtual uint64 attributes(void) override;
 virtual void truncate(uint64 length) override;
 virtual void flush(void) override;

 private:
 Stream* ss;
 uint64 ss_start_pos;
 uint64 ss_bound_pos;

 uint64 pos;
 uint32 running_crc32;
 uint64 running_crc32_posreached;
 uint64 expected_crc32;

 const std::string vfpath;
};

StreamViewFilter::StreamViewFilter(Stream* source_stream, const std::string& vfp, uint64 sp, uint64 bp, uint64 expcrc32) : ss(source_stream), ss_start_pos(sp), ss_bound_pos(bp), pos(0), running_crc32(0), running_crc32_posreached(0), expected_crc32(expcrc32), vfpath(vfp)
{
 if(ss_bound_pos < ss_start_pos)
  throw MDFN_Error(0, _("StreamViewFilter() bound_pos < start_pos"));

 if((ss_bound_pos - ss_start_pos) > INT64_MAX)
  throw MDFN_Error(0, _("StreamViewFilter() size too large"));
}

StreamViewFilter::~StreamViewFilter()
{

}


uint64 StreamViewFilter::read(void *data, uint64 count, bool error_on_eos)
{
 uint64 cc = count;
 uint64 ret;

 cc = std::min<uint64>(cc, ss_bound_pos - ss_start_pos);
 cc = std::min<uint64>(cc, ss_bound_pos - std::min<uint64>(ss_bound_pos, pos));

 if(cc < count && error_on_eos)
  throw MDFN_Error(0, _("Error reading from virtual file \"%s\": %s"), vfpath.c_str(), _("Unexpected EOF"));

 if(ss->tell() != (ss_start_pos + pos))
  ss->seek(ss_start_pos + pos, SEEK_SET);

 ret = ss->read(data, cc, error_on_eos);
 pos += ret;

 if(running_crc32 != ~(uint64)0)
 {
  if(pos > running_crc32_posreached && (pos - ret) <= running_crc32_posreached)
  {
   running_crc32 = crc32(running_crc32, (Bytef*)data + (running_crc32_posreached - (pos - ret)), pos - running_crc32_posreached);
   running_crc32_posreached = pos;

   if(running_crc32_posreached == (ss_bound_pos - ss_start_pos))
   {
    if(running_crc32 != expected_crc32)
     throw MDFN_Error(0, _("Error reading from virtual file \"%s\": %s"), vfpath.c_str(), _("Data fails CRC32 check."));
   }
  }
 }

 return ret;
}

void StreamViewFilter::write(const void *data, uint64 count)
{
#if 0
 uint64 cc = count;
 uint64 ret;

 cc = std::min<uint64>(cc, ss_bound_pos - ss_start_pos);
 cc = std::min<uint64>(cc, ss_bound_pos - std::min<uint64>(ss_bound_pos, pos));

 if(cc < count)
  throw MDFN_Error(0, _("ASDF"));

 if(ss->tell() != (ss_start_pos + pos))
  ss->seek(ss_start_pos + pos, SEEK_SET);

 ss->write(data, cc);
 pos += cc;
#endif
 throw MDFN_Error(ErrnoHolder(EINVAL));
}

void StreamViewFilter::seek(int64 offset, int whence)
{
#if 0
 uint64 new_pos = pos;

 if(whence == SEEK_SET)
 {
  //if(offset < 0)
  // throw MDFN_Error(EINVAL, _("Attempted to seek before start of stream."));

  new_pos = (uint64)offset;
 }
 else if(whence == SEEK_CUR)
 {
  if(offset < 0 && (uint64)-(uint64)offset > (pos - ss_start_pos))
   throw MDFN_Error(EINVAL, _("Attempted to seek before start of stream."));
 }
 else if(whence == SEEK_END)
 {
  if(offset < 0 && (uint64)-(uint64)offset > (ss_bound_pos - ss_start_pos))
   throw MDFN_Error(EINVAL, _("Attempted to seek before start of stream."));
 }
#endif
 int64 new_pos = pos;

 if(whence == SEEK_SET)
  new_pos = offset;
 else if(whence == SEEK_CUR)
  new_pos = pos + offset;
 else if(whence == SEEK_END)
  new_pos = (ss_bound_pos - ss_start_pos) + offset;

 if(new_pos < 0)
  throw MDFN_Error(EINVAL, _("Error seeking in virtual file \"%s\": %s"), vfpath.c_str(), _("Attempted to seek before start of stream."));

 pos = new_pos;
}

uint64 StreamViewFilter::tell(void)
{
 return pos;
}

uint64 StreamViewFilter::size(void)
{
 return ss_bound_pos - ss_start_pos;
}

void StreamViewFilter::close(void)
{
 ss->close();
}

uint64 StreamViewFilter::attributes(void)
{
 return ss->attributes();
}

void StreamViewFilter::truncate(uint64 length)
{
 //ss->truncate(ss_start_pos + length);
 throw MDFN_Error(ErrnoHolder(EINVAL));
}

void StreamViewFilter::flush(void)
{
 ss->flush();
}


Stream* ZIPReader::open(size_t which)
{
 const auto& e = entries[which];

 zs->seek(e.lh_reloffs, SEEK_SET);

 struct
 {
  uint32 sig;
  uint16 version_need;
  uint16 gpflags;
  uint16 method;
  uint16 mod_time;
  uint16 mod_date;
  uint32 crc32;
  uint32 comp_size;
  uint32 uncomp_size;
  uint16 name_len;
  uint16 extra_len;
 } lfh;
 uint8 lfh_raw[0x1E];

 if(zs->read(lfh_raw, sizeof(lfh_raw), false) != sizeof(lfh_raw))
  throw MDFN_Error(0, _("Unexpected EOF when reading ZIP Local File Header."));

 lfh.sig          = MDFN_de32lsb(&lfh_raw[0x00]);
 lfh.version_need = MDFN_de16lsb(&lfh_raw[0x04]);
 lfh.gpflags      = MDFN_de16lsb(&lfh_raw[0x06]);
 lfh.method       = MDFN_de16lsb(&lfh_raw[0x08]);
 lfh.mod_time     = MDFN_de16lsb(&lfh_raw[0x0A]);
 lfh.mod_date     = MDFN_de16lsb(&lfh_raw[0x0C]);
 lfh.crc32        = MDFN_de32lsb(&lfh_raw[0x0E]);
 lfh.comp_size    = MDFN_de32lsb(&lfh_raw[0x12]);
 lfh.uncomp_size  = MDFN_de32lsb(&lfh_raw[0x16]);
 lfh.name_len     = MDFN_de16lsb(&lfh_raw[0x1A]);
 lfh.extra_len    = MDFN_de16lsb(&lfh_raw[0x1C]);

 if(lfh.sig != 0x04034B50)
  throw MDFN_Error(0, _("Bad Local File Header signature."));

 if(lfh.method != e.method)
  throw MDFN_Error(0, _("Mismatch of compression method between Central Directory(%d) and Local File Header(%d)."), e.method, lfh.method);

 if(lfh.gpflags & 0x1)
  throw MDFN_Error(0, _("ZIP decryption support not implemented."));

 if(e.method != 0 && e.method != 8 && e.method != 9)
  throw MDFN_Error(0, _("ZIP compression method %u not implemented."), e.method);

 zs->seek(lfh.name_len + lfh.extra_len, SEEK_CUR);

 if(e.method == 0)
 {
  uint64 start_pos = zs->tell();
  uint64 bound_pos = start_pos + e.uncomp_size;

  return new StreamViewFilter(zs.get(), e.name, start_pos, bound_pos, e.crc32);
 }
 else if(e.method == 8)
  return new ZLInflateFilter(zs.get(), e.name, ZLInflateFilter::FORMAT::RAW, e.comp_size, e.uncomp_size, e.crc32);
 else
  throw MDFN_Error(0, _("ZIP compression method %u not implemented."), lfh.method);
}


ZIPReader::ZIPReader(std::unique_ptr<Stream> s)
{
 const uint64 size = s->size();

 if(size < 22)
  throw MDFN_Error(0, _("Too small to be a ZIP file."));

 const uint64 scan_size = std::min<uint64>(size, 65535 + 22);
 std::unique_ptr<uint8[]> buf(new uint8[scan_size]);
 const uint8* eocdrp = nullptr;

 s->seek(size - scan_size, SEEK_SET);
 s->read(&buf[0], scan_size);

 for(size_t scan_pos = scan_size - 22; scan_pos != ~(size_t)0; scan_pos--)
 {
  if(MDFN_de32lsb(&buf[scan_pos]) == 0x06054B50)
  {
   eocdrp = &buf[scan_pos];
   break;
  }
 }

 if(!eocdrp)
  throw MDFN_Error(0, _("ZIP End of Central Directory Record not found!"));
 //
 //
 //
 struct
 {
  uint32 sig;
  uint16 disk;
  uint16 cd_start_disk;
  uint16 disk_cde_count;
  uint16 total_cde_count;
  uint32 cd_size;
  uint32 cd_offs;
  uint16 comment_size;
 } eocdr;

 eocdr.sig  = MDFN_de32lsb(&eocdrp[0x00]);
 eocdr.disk = MDFN_de16lsb(&eocdrp[0x04]);
 eocdr.cd_start_disk = MDFN_de16lsb(&eocdrp[0x06]);
 eocdr.disk_cde_count = MDFN_de16lsb(&eocdrp[0x08]);
 eocdr.total_cde_count = MDFN_de16lsb(&eocdrp[0x0A]);
 eocdr.cd_size = MDFN_de32lsb(&eocdrp[0x0C]);
 eocdr.cd_offs = MDFN_de32lsb(&eocdrp[0x10]);
 eocdr.comment_size = MDFN_de16lsb(&eocdrp[0x14]);

 if((eocdr.disk != eocdr.cd_start_disk) || eocdr.disk != 0 || (eocdr.disk_cde_count != eocdr.total_cde_count))
  throw MDFN_Error(0, _("ZIP split archive support not implemented."));

 if(eocdr.cd_offs >= size)
  throw MDFN_Error(0, _("ZIP Central Directory start offset is bad.")); 

 s->seek(eocdr.cd_offs, SEEK_SET);

 for(uint32 i = 0; i < eocdr.total_cde_count; i++)
 {
  uint8 cdr_raw[46];
  FileDesc d;

  if(s->read(cdr_raw, sizeof(cdr_raw), false) != sizeof(cdr_raw))
   throw MDFN_Error(0, _("Unexpected EOF when reading ZIP Central Directory entry %u"), i);

  d.sig 	 = MDFN_de32lsb(&cdr_raw[0x00]);
  d.version_made = MDFN_de16lsb(&cdr_raw[0x04]);
  d.version_need = MDFN_de16lsb(&cdr_raw[0x06]);
  d.gpflags      = MDFN_de16lsb(&cdr_raw[0x08]);
  d.method       = MDFN_de16lsb(&cdr_raw[0x0A]);
  d.mod_time     = MDFN_de16lsb(&cdr_raw[0x0C]);
  d.mod_date     = MDFN_de16lsb(&cdr_raw[0x0E]);
  d.crc32        = MDFN_de32lsb(&cdr_raw[0x10]);
  d.comp_size    = MDFN_de32lsb(&cdr_raw[0x14]);
  d.uncomp_size  = MDFN_de32lsb(&cdr_raw[0x18]);
  d.name_len     = MDFN_de16lsb(&cdr_raw[0x1C]);
  d.extra_len    = MDFN_de16lsb(&cdr_raw[0x1E]);
  d.comment_len  = MDFN_de16lsb(&cdr_raw[0x20]);
  d.disk_start   = MDFN_de16lsb(&cdr_raw[0x22]);
  d.int_attr     = MDFN_de16lsb(&cdr_raw[0x24]);
  d.ext_attr     = MDFN_de32lsb(&cdr_raw[0x26]);
  d.lh_reloffs   = MDFN_de32lsb(&cdr_raw[0x2A]);

  if(d.sig != 0x02014B50)
   throw MDFN_Error(0, _("Bad signature in ZIP Central Directory entry %u"), i);

  if(d.disk_start != 0)
   throw MDFN_Error(0, _("ZIP split archive support not implemented."));

  if(d.lh_reloffs >= size)
   throw MDFN_Error(0, _("Bad local header relative offset in ZIP Central Directory entry %u"), i);

  d.name.resize(d.name_len);

  if(s->read(&d.name[0], d.name.size(), false) != d.name.size())
   throw MDFN_Error(0, _("Unexpected EOF when reading ZIP Central Directory entry %u"), i);

  MDFN_zapctrlchars(d.name);

  s->seek(d.extra_len + d.comment_len, SEEK_CUR);

  entries.push_back(d);
 }

 zs = std::move(s);
}
