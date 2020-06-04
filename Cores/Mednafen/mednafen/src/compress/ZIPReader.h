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

namespace Mednafen
{

class ZIPReader : public VirtualFS
{
 public:
 ZIPReader(std::unique_ptr<Stream> s);
 virtual ~ZIPReader();

 INLINE size_t num_files(void) { return entries.size(); }
 INLINE const char* get_file_path(size_t which) { return entries[which].name.c_str(); }
 INLINE size_t get_file_size(size_t which) { return entries[which].uncomp_size; }

 Stream* open(size_t which);

 virtual Stream* open(const std::string& path, const uint32 mode, const int do_lock = false, const bool throw_on_noent = true, const CanaryType canary = CanaryType::open) override;
 virtual bool mkdir(const std::string& path, const bool throw_on_exist = false) override;
 virtual bool unlink(const std::string& path, const bool throw_on_noent = false, const CanaryType canary = CanaryType::unlink) override;
 virtual void rename(const std::string& oldpath, const std::string& newpath, const CanaryType canary = CanaryType::rename) override;
 virtual bool finfo(const std::string& path, FileInfo*, const bool throw_on_noent = true) override;
 virtual void readdirentries(const std::string& path, std::function<bool(const std::string&)> callb) override;

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
  uint32 comp_size;
  uint32 uncomp_size;
  uint16 name_len;
  uint16 extra_len;
  uint16 comment_len;
  uint16 disk_start;
  uint16 int_attr;
  uint32 ext_attr;
  uint32 lh_reloffs;

  std::string name;
 };

 size_t find_by_path(const std::string& path);

 std::unique_ptr<Stream> zs;
 std::vector<FileDesc> entries;
};

}
#endif
