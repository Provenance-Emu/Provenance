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

class ZIPReader
{
 public:
 ZIPReader(std::unique_ptr<Stream> s);

 INLINE size_t num_files(void) { return entries.size(); }
 INLINE const char* get_file_path(size_t which) { return entries[which].name.c_str(); }
 INLINE size_t get_file_size(size_t which) { return entries[which].uncomp_size; }

 Stream* open(size_t which);

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

 std::unique_ptr<Stream> zs;
 std::vector<FileDesc> entries;
};


#endif
