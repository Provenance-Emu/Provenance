/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ArchiveReader.h:
**  Copyright (C) 2021 Mednafen Team
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

#ifndef __MDFN_COMPRESS_ARCHIVEREADER_H
#define __MDFN_COMPRESS_ARCHIVEREADER_H

namespace Mednafen
{

class ArchiveReader : public VirtualFS
{
 public:

 ArchiveReader();
 virtual ~ArchiveReader();

 // Returns nullptr if not a supported archive format(determined by path file extension).
 static ArchiveReader* Open(VirtualFS* vfs, const std::string& path);
 static bool TestExt(VirtualFS* vfs, const std::string& path);

 virtual size_t num_files(void) = 0;
 virtual const std::string* get_file_path(size_t which) = 0;
 virtual uint64 get_file_size(size_t which) = 0;
 virtual Stream* open(size_t which) = 0;
 virtual size_t find_by_path(const std::string& path) = 0;

 virtual Stream* open(const std::string& path, const uint32 mode, const int do_lock = false, const bool throw_on_noent = true, const CanaryType canary = CanaryType::open) override;
 virtual int mkdir(const std::string& path, const bool throw_on_exist = false, const bool throw_on_noent = true) override;
 virtual bool unlink(const std::string& path, const bool throw_on_noent = false, const CanaryType canary = CanaryType::unlink) override;
 virtual void rename(const std::string& oldpath, const std::string& newpath, const CanaryType canary = CanaryType::rename) override;

 virtual bool is_absolute_path(const std::string& path) override;
 virtual void check_firop_safe(const std::string& path) override;

 private:
};

}
#endif
