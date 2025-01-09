/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ZIPReader.cpp:
**  Copyright (C) 2018-2024 Mednafen Team
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

#include "ZIPReader.h"
#include "ZLInflateFilter.h"
#include "ZstdDecompressFilter.h"

namespace Mednafen
{

//
//
//
enum : bool { EnableZstandardCRC32Check = false };
//
//
//
class StreamViewFilter : public Stream
{
 public:

 StreamViewFilter(Stream* source_stream, const std::string& vfc, uint64 sp, uint64 bp, uint64 expcrc32 = (uint64)-1);
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

 const std::string vfcontext;
};

StreamViewFilter::StreamViewFilter(Stream* source_stream, const std::string& vfc, uint64 sp, uint64 bp, uint64 expcrc32) : ss(source_stream), ss_start_pos(sp), ss_bound_pos(bp), pos(0), running_crc32(0), running_crc32_posreached(0), expected_crc32(expcrc32), vfcontext(vfc)
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
 const uint64 size_ = ss_bound_pos - ss_start_pos;
 uint64 cc = count;
 uint64 ret;

 cc = std::min<uint64>(cc, size_ - std::min<uint64>(size_, pos));

 if(cc < count && error_on_eos)
  throw MDFN_Error(0, _("Error reading from %s: %s"), vfcontext.c_str(), _("Unexpected EOF"));

 if(ss->tell() != (ss_start_pos + pos))
  ss->seek(ss_start_pos + pos, SEEK_SET);

 ret = ss->read(data, cc, error_on_eos);
 pos += ret;

 if(expected_crc32 != (uint64)-1)
 {
  if(pos > running_crc32_posreached && (pos - ret) <= running_crc32_posreached)
  {
   running_crc32 = crc32(running_crc32, (Bytef*)data + (running_crc32_posreached - (pos - ret)), pos - running_crc32_posreached);
   running_crc32_posreached = pos;

   if(running_crc32_posreached == (ss_bound_pos - ss_start_pos))
   {
    if(running_crc32 != expected_crc32)
     throw MDFN_Error(0, _("Error reading from %s: %s"), vfcontext.c_str(), _("Data fails CRC32 check."));
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
  throw MDFN_Error(EINVAL, _("Error seeking in %s: %s"), vfcontext.c_str(), _("Attempted to seek before start of stream."));

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
 ss = nullptr;
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


size_t ZIPReader::num_files(void)
{
 return entries.size();
}

const std::string* ZIPReader::get_file_path(size_t which)
{
 return &entries[which].name;
}

uint64 ZIPReader::get_file_size(size_t which)
{
 return entries[which].uncomp_size;
}

Stream* ZIPReader::open(size_t which)
{
 const auto& e = entries[which];

 //
 //
 {
  // Must be (2**63) - 1 or smaller.
  const uint64 sanity_limit = ((uint64)1 << 48) - 1;

  if(e.comp_size > sanity_limit)
   throw MDFN_Error(0, _("Compressed size of %llu bytes exceeds sanity limit of %llu bytes."), (unsigned long long)e.comp_size, (unsigned long long)sanity_limit);

  if(e.uncomp_size > sanity_limit)
   throw MDFN_Error(0, _("Uncompressed size of %llu bytes exceeds sanity limit of %llu bytes."), (unsigned long long)e.uncomp_size, (unsigned long long)sanity_limit);
 }
 //
 //
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

 zs->seek(lfh.name_len + lfh.extra_len, SEEK_CUR);

 const std::string vfcontext = MDFN_sprintf(_("opened file %s"), this->get_human_path(e.name).c_str());

 return make_stream(zs.get(), vfcontext, e.method, e.comp_size, e.uncomp_size, e.crc32);
}

Stream* ZIPReader::make_stream(Stream* s, std::string vfcontext, const uint16 method, const uint64 comp_size, const uint64 uncomp_size, const uint32 crc)
{
 if(method == 0)
 {
  uint64 start_pos = s->tell();
  uint64 bound_pos = start_pos + uncomp_size;

  return new StreamViewFilter(s, vfcontext, start_pos, bound_pos, crc);
 }
 else if(method == 8)
  return new ZLInflateFilter(s, vfcontext, ZLInflateFilter::FORMAT::RAW, comp_size, uncomp_size, crc);
 else if(method == 93 || method == 20)
  return new ZstdDecompressFilter(s, vfcontext, comp_size, uncomp_size, EnableZstandardCRC32Check ? crc : (uint64)-1);
 //else if(method == 97) // TODO, maybe?
 // return new WAVPackDecodeFilter(s, vfcontext, comp_size, uncomp_size, crc);
 else
 {
  static struct
  {
   uint16 id;
   const char* name;
  } umt[] =
  {
   { 1, "Shrunk" },
   { 2, "Reduce" },
   { 3, "Reduce" },
   { 4, "Reduce" },
   { 5, "Reduce" },
   { 6, "Implode" },
   { 9, "Deflate64" },
   { 12, "bzip2" },
   { 14, "LZMA" },
   { 94, "MP3" },
   { 95, "xz" },
   { 97, "WavPack" },
  };

  for(auto const& umte : umt)
  {
   if(umte.id == method)
    throw MDFN_Error(0, _("ZIP compression method %u(\"%s\") not implemented."), method, umte.name);
  }

  throw MDFN_Error(0, _("ZIP compression method %u not implemented."), method);
 }
}

ZIPReader::~ZIPReader()
{

}

ZIPReader::ZIPReader(std::unique_ptr<Stream> s)
{
 if((s->attributes() & (Stream::ATTRIBUTE_SEEKABLE | Stream::ATTRIBUTE_SLOW_SEEK | Stream::ATTRIBUTE_SLOW_SIZE)) != Stream::ATTRIBUTE_SEEKABLE)
  throw MDFN_Error(0, _("ZIPReader requires a performant, seekable source stream."));
 //
 //
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
 const uint64 eocdr_offs = (size - scan_size) + (eocdrp - buf.get());

 struct
 {
  uint32 sig;
  uint64 size;
  uint16 version_made;
  uint16 version_need;
  uint32 disk;
  uint32 cd_start_disk;
  uint64 disk_cde_count;
  uint64 total_cde_count;
  uint64 cd_size;
  uint64 cd_offs;
  uint16 comment_size;
 } eocdr;

 memset(&eocdr, 0, sizeof(eocdr));

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
 //
 //
 if(eocdr_offs >= 20 && (eocdr.cd_size == 0xFFFFFFFF || eocdr.cd_offs == 0xFFFFFFFF || eocdr.total_cde_count == 0xFFFF))
 {
  uint8 eocdl_raw[20];
  struct
  {
   uint32 sig;
   uint32 eocd_start_disk;
   uint64 eocd_offs;
   uint32 disk_count;
  } eocdl;

  s->seek(eocdr_offs - 20, SEEK_SET);
  s->read(eocdl_raw, sizeof(eocdl_raw));

  eocdl.sig = MDFN_de32lsb(&eocdl_raw[0x00]);
  eocdl.eocd_start_disk = MDFN_de32lsb(&eocdl_raw[0x04]);
  eocdl.eocd_offs = MDFN_de64lsb(&eocdl_raw[0x08]);
  eocdl.disk_count = MDFN_de32lsb(&eocdl_raw[0x10]);

  if(eocdl.sig != 0x07064B50)
   throw MDFN_Error(0, _("Bad signature(0x%08x) in ZIP64 End of Central Directory Locator"), eocdl.sig);

  if(eocdl.eocd_start_disk != 0 || eocdl.disk_count != 1)
   throw MDFN_Error(0, _("ZIP split archive support not implemented."));

  if(eocdl.eocd_offs >= size)
   throw MDFN_Error(0, _("ZIP64 End of Central Directory start offset is bad."));

  uint8 eocdr64_raw[0x38];

  s->seek(eocdl.eocd_offs, SEEK_SET);
  s->read(eocdr64_raw, sizeof(eocdr64_raw));

  eocdr.sig = MDFN_de32lsb(&eocdr64_raw[0x00]);
  eocdr.size = MDFN_de64lsb(&eocdr64_raw[0x04]);
  eocdr.version_made = MDFN_de16lsb(&eocdr64_raw[0x0C]);
  eocdr.version_need = MDFN_de16lsb(&eocdr64_raw[0x0E]);
  eocdr.disk = MDFN_de32lsb(&eocdr64_raw[0x10]);
  eocdr.cd_start_disk = MDFN_de32lsb(&eocdr64_raw[0x14]);
  eocdr.disk_cde_count = MDFN_de64lsb(&eocdr64_raw[0x18]);
  eocdr.total_cde_count = MDFN_de64lsb(&eocdr64_raw[0x20]);
  eocdr.cd_size = MDFN_de64lsb(&eocdr64_raw[0x28]);
  eocdr.cd_offs = MDFN_de64lsb(&eocdr64_raw[0x30]);

  if(eocdr.sig != 0x06064b50)
   throw MDFN_Error(0, _("Bad signature(0x%08x) in ZIP64 End of Central Directory Record"), eocdr.sig);

  if((eocdr.disk != eocdr.cd_start_disk) || eocdr.disk != 0 || (eocdr.disk_cde_count != eocdr.total_cde_count))
   throw MDFN_Error(0, _("ZIP split archive support not implemented."));

  if(eocdr.cd_offs >= size)
   throw MDFN_Error(0, _("ZIP64 Central Directory start offset is bad."));
 }
 //
 //
 const uint64 cde_count_limit = 65535;

 if(eocdr.total_cde_count > cde_count_limit)
  throw MDFN_Error(0, _("Number of Central Directory entries exceeds this implementation's limit of %llu."), (unsigned long long)cde_count_limit);

 if(eocdr.total_cde_count > SIZE_MAX)
  throw MDFN_Error(0, _("Number of Central Directory entries exceeds SIZE_MAX."));
 //
 //
 s->seek(eocdr.cd_offs, SEEK_SET);

 read_central_directory(s.get(), size, eocdr.total_cde_count);

 zs = std::move(s);
}

static std::string canonicalize_zip_path(const std::string& name)
{
 //
 // Collapse multiple sequential '/' into one '/'.
 // Turn /./ into /
 // Turn (...)a/b/../c(...) into (...)a/c(...)
 //
 // Leave trailing /. and /.. unaltered.
 //
 std::string ret;
 const char* const ncs = name.c_str(); // So we don't have to keep checking name.size() in the if() statements

 ret.reserve(name.size());

 for(size_t i = 0; i < name.size(); i++)
 {
  while(ncs[i] == '/' && ncs[i + 1] == '/')
   i++;

  if(ncs[i] == '/' && ncs[i + 1] == '.' && ncs[i + 2] == '/')
   i += 1;
  else if(ncs[i] == '/' && ncs[i + 1] == '.' && ncs[i + 2] == '.' && ncs[i + 3] == '/')
  {
   i += 2;

   while(ret.size())
   {
    const char c = ret.back();

    ret.pop_back();

    if(c == '/')
     break;
   }
  }
  else
   ret.push_back(ncs[i]);
 }

 return ret;
}

void ZIPReader::read_central_directory(Stream* s, const uint64 zip_size, const uint64 total_cde_count)
{
/*
 {
  static const char* test_strings[] =
  {
   "/../meow",
   "/../../meow",
   "/./.././meow",
   "/woof/./../meow",
   "////bow//wow//..//.//meow",
   "/how/now/brown/cow/../../meow/../bark/././///./crow",
   "/toot/.."
  };

  for(const char* const ts : test_strings)
   printf("%s -> %s\n", ts, canonicalize_zip_path(ts).c_str());
 }
*/
 entries.reserve(total_cde_count);

 for(uint64 i = 0; i < total_cde_count; i++)
 {
  uint8 cdr_raw[46];
  FileDesc d;

  if(s->read(cdr_raw, sizeof(cdr_raw), false) != sizeof(cdr_raw))
   throw MDFN_Error(0, _("ZIP Central Directory entry %llu: Unexpected EOF"), (unsigned long long)i);

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
   throw MDFN_Error(0, _("ZIP Central Directory entry %llu: Bad signature(0x%08x)."), (unsigned long long)i, d.sig);

  if(d.disk_start != 0)
   throw MDFN_Error(0, _("ZIP split archive support not implemented."));

  if(d.lh_reloffs >= zip_size)
   throw MDFN_Error(0, _("ZIP Central Directory entry %llu: Bad local header relative offset."), (unsigned long long)i);

  d.name = '/';
  if(s->get_string_append(&d.name, d.name_len, false) != d.name_len)
   throw MDFN_Error(0, _("ZIP Central Directory entry %llu: Unexpected EOF"), (unsigned long long)i);

  d.name = canonicalize_zip_path(d.name);

  const uint64 extra_end_offs = s->tell() + d.extra_len;
  for(uint32 efi = 0; s->tell() < extra_end_offs; efi++)
  {
   uint8 header_raw[4];
   uint16 header_id;
   uint16 data_size;

   if(s->read(header_raw, sizeof(header_raw), false) != sizeof(header_raw))
    throw MDFN_Error(0, _("ZIP Central Directory entry %llu: Extra field entry %u: Unexpected EOF"), (unsigned long long)i, efi);

   header_id = MDFN_de16lsb(&header_raw[0x0]);
   data_size = MDFN_de16lsb(&header_raw[0x2]);

   //printf("%u: %04x %04x\n", efi, header_id, data_size);
   //
   const bool want64_uncomp_size = (d.uncomp_size == 0xFFFFFFFF); 
   const bool want64_comp_size = (d.comp_size == 0xFFFFFFFF);
   const bool want64_lh_reloffs = (d.lh_reloffs == 0xFFFFFFFF);
   const bool want32_disk_start = (d.disk_start == 0xFFFF);

   if(header_id == 0x0001) // ZIP64 extended info
   {
    uint8 ei_raw[28];
    const uint32 expected_size = (want64_uncomp_size + want64_comp_size + want64_lh_reloffs) * 8 + want32_disk_start * 4;

    assert(expected_size <= sizeof(ei_raw));

    if(data_size != expected_size)
     throw MDFN_Error(0, _("ZIP Central Directory entry %llu: Extra field entry %u: ZIP64 extended info data size of %u is invalid(expected %u)."), (unsigned long long)i, efi, data_size, expected_size);

    if(s->read(ei_raw, expected_size, false) != expected_size)
     throw MDFN_Error(0, _("ZIP Central Directory entry %llu: Extra field entry %u: Unexpected EOF"), (unsigned long long)i, efi);
    //
    uint8* rp = ei_raw;

    if(want64_uncomp_size)
    {
     d.uncomp_size = MDFN_de64lsb(rp);
     rp += 8;
    }

    if(want64_comp_size)
    {
     d.comp_size = MDFN_de64lsb(rp);
     rp += 8;
    }

    if(want64_lh_reloffs)
    {
     d.lh_reloffs = MDFN_de64lsb(rp);
     rp += 8;

     if(d.lh_reloffs >= zip_size)
      throw MDFN_Error(0, _("ZIP Central Directory entry %llu: Extra field entry %u: Bad ZIP64 local header relative offset."), (unsigned long long)i, efi);
    }

    if(want32_disk_start)
    {
     d.disk_start = MDFN_de32lsb(rp);
     rp += 4;

     if(d.disk_start != 0)
      throw MDFN_Error(0, _("ZIP split archive support not implemented."));
    }
   }
   else
    s->seek(data_size, SEEK_CUR);
  }

  if(s->tell() != extra_end_offs)
   throw MDFN_Error(0, _("ZIP Central Directory entry %llu: Malformed extra field."), (unsigned long long)i);
  //
  //
  s->seek(d.comment_len, SEEK_CUR);

  //printf("name=%s, comp_size=%llu, uncomp_size=%llu, lh_reloffs=%llu\n", d.name.c_str(), (unsigned long long)d.comp_size, (unsigned long long)d.uncomp_size, (unsigned long long)d.lh_reloffs);

  //
  //
  FileEntry fe;
  std::map<std::string, size_t>::iterator it;

  fe.name = d.name;
  fe.mod_time = d.mod_time;
  fe.mod_date = d.mod_date;
  fe.crc32 = d.crc32;
  fe.comp_size = d.comp_size;
  fe.uncomp_size = d.uncomp_size;
  fe.lh_reloffs = d.lh_reloffs;
  fe.method = d.method;
  fe.counter = 0;

  entries.push_back(fe);
  if(!entries_map.count(fe.name))
   entries_map[fe.name] = entries.size() - 1;
 }

 // Read in all entries first, then resolve duplicates, so we don't
 // rename files that collide with new duplicates we created.
 for(size_t i = 0; i < entries.size(); i++)
 {
  FileEntry* fe = &entries[i];
  std::map<std::string, size_t>::iterator it = entries_map.find(fe->name);

  assert(it != entries_map.end());

  if(it->second != i)
  {
   uint64 counter = entries[it->second].counter;
   std::string dir_path, file_base, file_ext;

   get_file_path_components(fe->name, &dir_path, &file_base, &file_ext);

   do
   {
    counter++;
    //
    char nbuf[20 + 1];

    MDFN_sndec_u64(nbuf, sizeof(nbuf), counter);
    fe->name = dir_path + '/' + nbuf + ':' + file_base + file_ext;
   } while(entries_map.count(fe->name));

   entries_map[fe->name] = i;
   entries[it->second].counter = counter;
  }
 }

#if 0
 for(size_t i = 0; i < entries.size(); i++)
 {
  printf("%s\n", entries[i].name.c_str());
 }
#endif
}

/*
// and persistent VFS?
bool ZIPReader::is_mt_safe(void)
{
 return false;
}
*/

size_t ZIPReader::find_by_path(const std::string& path)
{
 auto it = entries_map.find(canonicalize_zip_path(path));

 if(it == entries_map.end())
  return SIZE_MAX;

 return it->second;
}

bool ZIPReader::finfo(const std::string& path, FileInfo* fi, const bool throw_on_noent)
{
 size_t which = find_by_path(path);

 if(which == SIZE_MAX)
 {
  ErrnoHolder ene(ENOENT);

  if(throw_on_noent)
   throw MDFN_Error(ene.Errno(), _("Error getting file information for %s: %s"), this->get_human_path(path).c_str(), ene.StrError());

  return false;
 }

 if(fi)
 {
  FileInfo new_fi;

  new_fi.size = entries[which].uncomp_size;
  new_fi.check = entries[which].crc32;
  new_fi.check_type = FileInfo::CHECK_TYPE_CRC32;

  // TODO/FIXME:
  new_fi.mtime_us = 0;
  new_fi.is_regular = true;
  new_fi.is_directory = false;

  *fi = new_fi;
 }

 return true;
}

void ZIPReader::readdirentries(const std::string& path, std::function<bool(const std::string&)> callb)
{
 const std::string canpath = canonicalize_zip_path(path + '/');

 //printf("Path: %s\n", MDFN_strhumesc(canpath).c_str());

 for(auto const& e : entries)
 {
  if(e.name.size() <= canpath.size())
   continue;

  if(memcmp(e.name.data(), canpath.data(), canpath.size()))
   continue;

  if(e.name.find('/', canpath.size()) != std::string::npos)
   continue;
  //
  std::string tmp = e.name.substr(canpath.size());

  //printf("File: %s\n", MDFN_strhumesc(tmp).c_str());

  if(!callb(tmp))
   break;
 }
}

std::string ZIPReader::get_human_path(const std::string& path)
{
 return MDFN_sprintf(_("\"%s\" in ZIP archive"), MDFN_strhumesc(path).c_str());
}

bool ZIPReader::is_absolute_path(const std::string& path)
{
 if(!path.size())
  return false;

 if(is_path_separator(path[0]))
  return true;

 return false;
}

void ZIPReader::check_firop_safe(const std::string& path)
{

}

}
