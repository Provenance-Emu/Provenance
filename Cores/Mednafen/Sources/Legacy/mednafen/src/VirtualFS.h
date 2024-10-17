/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* VirtualFS.h:
**  Copyright (C) 2010-2018 Mednafen Team
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

#ifndef __MDFN_VIRTUALFS_H
#define __MDFN_VIRTUALFS_H

#include "Stream.h"
#include <functional>

namespace Mednafen
{

class VirtualFS
{
 public:

 VirtualFS(char preferred_path_separator_, const std::string& allowed_path_separators_);
 virtual ~VirtualFS();

 enum : uint32
 {
  MODE_READ = 0x0D46323C,

  // Will create file if it doesn't already exist.  Will not truncate existing file.
  // Any necessary synchronization when switching between read and write operations is handled internally in
  // Stream implementation.
  MODE_READ_WRITE = 0x193AAA56,

  // Will create file if it doesn't already exist, and truncate file to 0-length if it does.
  MODE_WRITE = 0xA587267C,

  // Will throw an exception if the file already exists(to prevent overwriting).
  MODE_WRITE_SAFE = 0xB8E75994,

  // Like MODE_WRITE, but won't truncate the file if it already exists.
  MODE_WRITE_INPLACE = 0xE7B2EC69,

  // Custom modes for derived classes after this.
  MODE__CUSTOM_BEGIN = 0xF0000000,
 };

 protected:

 // Probably not necessary, but virtual functions make me a little uneasy. ;)
 enum class CanaryType : uint64
 {
  open = 0xA8D4C7D433EC0BC9ULL,
  unlink = 0xCBE552428A86F001ULL,
  rename = 0x4C8642D1246B775DULL
 };

 public:
 // If throw_on_noent is true, will always return a non-null pointer or throw.
 // Otherwise, will return nullptr if the file doesn't exist/wasn't found.
 virtual Stream* open(const std::string& path, const uint32 mode, const int do_lock = false, const bool throw_on_noent = true, const CanaryType canary = CanaryType::open) = 0;

 // Returns true if directory was created, false if it already exists(unless throw_on_exist is true).
 virtual bool mkdir(const std::string& path, const bool throw_on_exist = false) = 0;

 // Returns true if the file was unlinked successfully, false if the file didn't exist(unless throw_on_noent is true), and throws on other errors.
 virtual bool unlink(const std::string& path, const bool throw_on_noent = false, const CanaryType canary = CanaryType::unlink) = 0;

 // Renames file at oldpath to newpath.  Will replace file at newpath if it already exists.  On Windows, it will not be atomic, and oldpath will end up deleted
 // if oldpath and newpath refer to the same underlying file via symlink shenanigans, so be careful in how it's used.
 //
 // Throws on error.
 virtual void rename(const std::string& oldpath, const std::string& newpath, const CanaryType canary = CanaryType::rename) = 0;

 struct FileInfo
 {
  INLINE FileInfo() : size(0), mtime_us(0), is_regular(false), is_directory(false) { }

  uint64 size;			// In bytes.
  int64 mtime_us;		// Last modification time, in microseconds(since the "Epoch").
  bool is_regular : 1;		// Is regular file.
  bool is_directory : 1;	// Is directory.
 };

 virtual bool finfo(const std::string& path, FileInfo*, const bool throw_on_noent = true) = 0;

 virtual void readdirentries(const std::string& path, std::function<bool(const std::string&)> callb) = 0;

 //
 //
 //
 virtual bool is_absolute_path(const std::string& path);
 virtual bool is_path_separator(const char c);
 //virtual bool is_driverel_path(const std::string& path) = 0;

 //
 // Note: It IS permissible for an output to point to the same string as the file_path reference.
 //
 virtual void get_file_path_components(const std::string& file_path, std::string* dir_path_out, std::string* file_base_out = nullptr, std::string *file_ext_out = nullptr);

 // File-inclusion for-read-only path, for PSF and CUE/TOC sheet usage.
 // throws exception if not safe(and/or on other error).
 virtual void check_firop_safe(const std::string& path);

 virtual std::string eval_fip(const std::string& dir_path, const std::string& rel_path, bool skip_safety_check = false);

 INLINE char get_preferred_path_separator(void) { return preferred_path_separator; }

 // Create any directories needed to create a file at file_path
 void create_missing_dirs(const std::string& file_path);

 protected:
 
 const char preferred_path_separator;
 const std::string allowed_path_separators;
};

}
#endif
