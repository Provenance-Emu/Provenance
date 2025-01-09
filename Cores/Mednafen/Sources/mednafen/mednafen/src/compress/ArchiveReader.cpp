/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ArchiveReader.cpp:
**  Copyright (C) 2018-2021 Mednafen Team
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
#include "ArchiveReader.h"
#include "ZIPReader.h"

namespace Mednafen
{

bool ArchiveReader::TestExt(VirtualFS* vfs, const std::string& path)
{
 if(vfs->test_ext(path, ".zip") || vfs->test_ext(path, ".zipx"))
  return true;

 return false;
}

ArchiveReader* ArchiveReader::Open(VirtualFS* vfs, const std::string& path)
{
 std::unique_ptr<ArchiveReader> ret;

 if(vfs->test_ext(path, ".zip") || vfs->test_ext(path, ".zipx"))
  ret.reset(new ZIPReader(std::unique_ptr<Stream>(vfs->open(path, VirtualFS::MODE_READ))));
 //else if(vfs->test_ext(path, ".tar"))
 // ret.reset(TARReader(std::unique_ptr<Stream>(vfs->open(path, VirtualFS::MODE_READ))));
 //else if(vfs->test_ext(path, ".7z"))
 // ret.reset(SevenZipReader(std::unique_ptr<Stream>(vfs->open(path, VirtualFS::MODE_READ))));

#ifdef MDFN_ENABLE_DEV_BUILD
 assert((bool)ret == TestExt(vfs, path));
#endif

 return ret.release();
}


ArchiveReader::ArchiveReader() : VirtualFS('/', "/")
{
 //
}

ArchiveReader::~ArchiveReader()
{
 //
}

Stream* ArchiveReader::open(const std::string& path, const uint32 mode, const int do_lock, const bool throw_on_noent, const CanaryType canary)
{
 if(mode != MODE_READ)
  throw MDFN_Error(EINVAL, _("Error opening file %s %s: %s"), this->get_human_path(path).c_str(), VirtualFS::get_human_mode(mode).c_str(), _("Specified mode is unsupported"));

 if(do_lock != 0)
  throw MDFN_Error(EINVAL, _("Error opening file %s %s: %s"), this->get_human_path(path).c_str(), VirtualFS::get_human_mode(mode).c_str(), _("Locking requested but is unsupported"));

 size_t which = find_by_path(path);

 if(which == SIZE_MAX)
 {
  ErrnoHolder ene(ENOENT);

  throw MDFN_Error(ene.Errno(), _("Error opening file %s %s: %s"), this->get_human_path(path).c_str(), VirtualFS::get_human_mode(mode).c_str(), ene.StrError());
 }

 try
 {
  return open(which);
 }
 catch(const MDFN_Error& e)
 {
  throw MDFN_Error(e.GetErrno(), _("Error opening file %s %s: %s"), this->get_human_path(path).c_str(), VirtualFS::get_human_mode(mode).c_str(), e.what());
 }
}

int ArchiveReader::mkdir(const std::string& path, const bool throw_on_exist, const bool throw_on_noent)
{
 throw MDFN_Error(EINVAL, _("Error creating directory %s: %s"), this->get_human_path(path).c_str(), _("mkdir() not implemented"));
}

bool ArchiveReader::unlink(const std::string& path, const bool throw_on_noent, const CanaryType canary)
{
 throw MDFN_Error(EINVAL, _("Error unlinking %s: %s"), this->get_human_path(path).c_str(), _("unlink() not implemented"));
}

void ArchiveReader::rename(const std::string& oldpath, const std::string& newpath, const CanaryType canary)
{
 throw MDFN_Error(EINVAL, _("Error renaming %s to %s: %s"), this->get_human_path(oldpath).c_str(), this->get_human_path(newpath).c_str(), _("rename() not implemented"));
}

bool ArchiveReader::is_absolute_path(const std::string& path)
{
 if(!path.size())
  return false;

 if(is_path_separator(path[0]))
  return true;

 return false;
}

void ArchiveReader::check_firop_safe(const std::string& path)
{

}

}
