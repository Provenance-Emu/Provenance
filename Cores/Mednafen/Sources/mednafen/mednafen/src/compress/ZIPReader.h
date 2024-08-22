/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ZIPReader.h:
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

#ifndef __MDFN_COMPRESS_ZIPREADER_H
#define __MDFN_COMPRESS_ZIPREADER_H

#include "ArchiveReader.h"

namespace Mednafen
{

class ZIPReader : public ArchiveReader
{
 public:
 ZIPReader(std::unique_ptr<Stream> s);
 virtual ~ZIPReader();

 virtual size_t num_files(void) override;
 virtual const std::string* get_file_path(size_t which) override;
 virtual uint64 get_file_size(size_t which) override;
 virtual Stream* open(size_t which) override;
 virtual size_t find_by_path(const std::string& path) override;

 virtual bool finfo(const std::string& path, FileInfo*, const bool throw_on_noent = true) override;
 virtual void readdirentries(const std::string& path, std::function<bool(const std::string&)> callb) override;
 virtual std::string get_human_path(const std::string& path) override;

 virtual bool is_absolute_path(const std::string& path) override;
 virtual void check_firop_safe(const std::string& path) override;

 private:

 struct FileDesc
 {
  uint32 sig;
  uint16 version_made;
  uint16 version_need;
  uint16 gpflags;
  uint16 method;
  uint16 mod_time;
  uint16 mod_date;
  uint32 crc32;
  uint64 comp_size;
  uint64 uncomp_size;
  uint16 name_len;
  uint16 extra_len;
  uint16 comment_len;
  uint32 disk_start;
  uint16 int_attr;
  uint32 ext_attr;
  uint64 lh_reloffs;

  std::string name;
 };

 void read_central_directory(Stream* s, const uint64 zip_size, const uint64 total_cde_count);
 Stream* make_stream(Stream* s, std::string vfcontext, const uint16 method, const uint64 comp_size, const uint64 uncomp_size, const uint32 crc);

 struct FileEntry
 {
  std::string name;
  uint64 counter;	// Internal use for duplicate management in read_central_directory().
  uint64 comp_size;
  uint64 uncomp_size;
  uint64 lh_reloffs;
  uint32 crc32;
  uint16 mod_time;
  uint16 mod_date;
  uint16 method;
 };

 std::unique_ptr<Stream> zs;
 std::vector<FileEntry> entries;
 std::map<std::string, size_t > entries_map;

/*
 struct FEMapCompare
 {
  bool operator()(const std::string* a, const std::string* b) const
  {
   return *a < *b;
  }
 };
 std::map<std::string*, size_t, FEMapCompare > entries_map;
*/
};

}
#endif
