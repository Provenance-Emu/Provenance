/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* NativeVFS.cpp:
**  Copyright (C) 2018-2019 Mednafen Team
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
#include <mednafen/NativeVFS.h>
#include <mednafen/FileStream.h>

#ifdef WIN32
 #include <mednafen/win32-common.h>
#else
 #include <unistd.h>
 #include <dirent.h>
#endif

#include <sys/types.h>
#include <sys/stat.h>

namespace Mednafen
{

NativeVFS::NativeVFS() : VirtualFS(MDFN_PS, (PSS_STYLE == 2) ? "\\/" : PSS)
{


}

NativeVFS::~NativeVFS()
{


}

Stream* NativeVFS::open(const std::string& path, const uint32 mode, const int do_lock, const bool throw_on_noent, const CanaryType canary)
{
 if(canary != CanaryType::open)
  _exit(-1);

 try
 {
  return new FileStream(path, mode, do_lock);
 }
 catch(MDFN_Error& e)
 {
  if(e.GetErrno() != ENOENT || throw_on_noent)
   throw;

  return nullptr;
 }
}

bool NativeVFS::mkdir(const std::string& path, const bool throw_on_exist)
{
 if(path.find('\0') != std::string::npos)
  throw MDFN_Error(EINVAL, _("Error creating directory \"%s\": %s"), path.c_str(), _("Null character in path."));

 #ifdef WIN32
 bool invalid_utf8;
 auto tpath = Win32Common::UTF8_to_T(path, &invalid_utf8, true);

 if(invalid_utf8)
  throw MDFN_Error(EINVAL, _("Error creating directory \"%s\": %s"), path.c_str(), _("Invalid UTF-8"));

 if(::_tmkdir((const TCHAR*)tpath.c_str()))
 #elif defined HAVE_MKDIR
  #if MKDIR_TAKES_ONE_ARG
   if(::mkdir(path.c_str()))
  #else
   if(::mkdir(path.c_str(), S_IRWXU))
  #endif
 #else
  #error "mkdir() missing?!"
 #endif
 {
  ErrnoHolder ene(errno);

  if(ene.Errno() != EEXIST || throw_on_exist)
   throw MDFN_Error(ene.Errno(), _("Error creating directory \"%s\": %s"), path.c_str(), ene.StrError());

  return false;
 }

 return true;
}


bool NativeVFS::unlink(const std::string& path, const bool throw_on_noent, const CanaryType canary)
{
 if(canary != CanaryType::unlink)
  _exit(-1);

 if(path.find('\0') != std::string::npos)
  throw MDFN_Error(EINVAL, _("Error unlinking \"%s\": %s"), path.c_str(), _("Null character in path."));

 #ifdef WIN32
 bool invalid_utf8;
 auto tpath = Win32Common::UTF8_to_T(path, &invalid_utf8, true);

 if(invalid_utf8)
  throw MDFN_Error(EINVAL, _("Error unlinking \"%s\": %s"), path.c_str(), _("Invalid UTF-8"));

 if(::_tunlink((const TCHAR*)tpath.c_str()))
 #else
 if(::unlink(path.c_str()))
 #endif
 {
  ErrnoHolder ene(errno);

  if(ene.Errno() == ENOENT && !throw_on_noent)
   return false;
  else
   throw MDFN_Error(ene.Errno(), _("Error unlinking \"%s\": %s"), path.c_str(), ene.StrError());
 }

 return true;
}

void NativeVFS::rename(const std::string& oldpath, const std::string& newpath, const CanaryType canary)
{
 if(canary != CanaryType::rename)
  _exit(-1);

 if(oldpath.find('\0') != std::string::npos || newpath.find('\0') != std::string::npos)
  throw MDFN_Error(EINVAL, _("Error renaming \"%s\" to \"%s\": %s"), oldpath.c_str(), newpath.c_str(), _("Null character in path."));

 #ifdef WIN32
 bool invalid_utf8_old;
 bool invalid_utf8_new;
 auto toldpath = Win32Common::UTF8_to_T(oldpath, &invalid_utf8_old, true);
 auto tnewpath = Win32Common::UTF8_to_T(newpath, &invalid_utf8_new, true);

 if(invalid_utf8_old || invalid_utf8_new)
  throw MDFN_Error(EINVAL, _("Error renaming \"%s\" to \"%s\": %s"), oldpath.c_str(), newpath.c_str(), _("Invalid UTF-8"));

 if(::_trename((const TCHAR*)toldpath.c_str(), (const TCHAR*)tnewpath.c_str()))
 {
  ErrnoHolder ene(errno);

  // TODO/FIXME: Ensure oldpath and newpath don't refer to the same file via symbolic link.
  if(oldpath != newpath && (ene.Errno() == EACCES || ene.Errno() == EEXIST))
  {
   if(::_tunlink((const TCHAR*)tnewpath.c_str()) || ::_trename((const TCHAR*)toldpath.c_str(), (const TCHAR*)tnewpath.c_str()))
    throw MDFN_Error(ene.Errno(), _("Error renaming \"%s\" to \"%s\": %s"), oldpath.c_str(), newpath.c_str(), ene.StrError());
  }
  else
   throw MDFN_Error(ene.Errno(), _("Error renaming \"%s\" to \"%s\": %s"), oldpath.c_str(), newpath.c_str(), ene.StrError());
 }
 #else

 if(::rename(oldpath.c_str(), newpath.c_str()))
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Error renaming \"%s\" to \"%s\": %s"), oldpath.c_str(), newpath.c_str(), ene.StrError());
 }

 #endif
}

bool NativeVFS::finfo(const std::string& path, FileInfo* fi, const bool throw_on_noent)
{
 if(path.find('\0') != std::string::npos)
  throw MDFN_Error(EINVAL, _("Error getting file information for \"%s\": %s"), path.c_str(), _("Null character in path."));
 //
 //
 #ifdef WIN32
 bool invalid_utf8;
 auto tpath = Win32Common::UTF8_to_T(path, &invalid_utf8, true);
 struct _stati64 buf;

 if(invalid_utf8)
  throw MDFN_Error(EINVAL, _("Error getting file information for \"%s\": %s"), path.c_str(), _("Invalid UTF-8"));

 if(::_tstati64((const TCHAR*)tpath.c_str(), &buf))
 #else
 struct stat buf;
 if(::stat(path.c_str(), &buf))
 #endif
 {
  ErrnoHolder ene(errno);

  if(ene.Errno() == ENOENT && !throw_on_noent)
   return false;

  throw MDFN_Error(ene.Errno(), _("Error getting file information for \"%s\": %s"), path.c_str(), ene.StrError());
 }

 if(fi)
 {
  FileInfo new_fi;

  new_fi.size = buf.st_size;
  new_fi.mtime_us = (int64)buf.st_mtime * 1000 * 1000;

  new_fi.is_regular = S_ISREG(buf.st_mode);
  new_fi.is_directory = S_ISDIR(buf.st_mode);

  *fi = new_fi;
 }

 return true;
}

void NativeVFS::readdirentries(const std::string& path, std::function<bool(const std::string&)> callb)
{
 if(path.find('\0') != std::string::npos)
  throw MDFN_Error(EINVAL, _("Error reading directory entries from \"%s\": %s"), path.c_str(), _("Null character in path."));
 //
 //
#ifdef WIN32
 //
 // TODO: drive-relative?  probably would need to change how we represent and compose paths in Mednafen...
 //
 HANDLE dp = nullptr;
 bool invalid_utf8;
 auto tpath = Win32Common::UTF8_to_T(path + preferred_path_separator + '*', &invalid_utf8, true);
 WIN32_FIND_DATA ded;

 if(invalid_utf8)
  throw MDFN_Error(EINVAL, _("Error reading directory entries from \"%s\": %s"), path.c_str(), _("Invalid UTF-8"));

 try
 {
  if(!(dp = FindFirstFile((const TCHAR*)tpath.c_str(), &ded)))
  {
   const uint32 ec = GetLastError();

   throw MDFN_Error(0, _("Error reading directory entries from \"%s\": %s"), path.c_str(), Win32Common::ErrCodeToString(ec).c_str());
  }

  for(;;)
  {
   //printf("%s\n", UTF16_to_UTF8((const char16_t*)ded.cFileName, nullptr, true).c_str());
   if(!callb(Win32Common::T_to_UTF8(ded.cFileName, nullptr, true)))
    break;
   //
   if(!FindNextFile(dp, &ded))
   {
    const uint32 ec = GetLastError();

    if(ec == ERROR_NO_MORE_FILES)
     break;
    else
     throw MDFN_Error(0, _("Error reading directory entries from \"%s\": %s"), path.c_str(), Win32Common::ErrCodeToString(ec).c_str());
   }
  }
  //
  FindClose(dp);
  dp = nullptr;
 }
 catch(...)
 {
  if(dp)
  {
   FindClose(dp);
   dp = nullptr;
  }
  throw;
 }
#else
 DIR* dp = nullptr;
 std::string fname;

 fname.reserve(512);

 try
 {
  if(!(dp = opendir(path.c_str())))
  {
   ErrnoHolder ene(errno);

   throw MDFN_Error(ene.Errno(), _("Error reading directory entries from \"%s\": %s"), path.c_str(), ene.StrError());
  }
  //
  for(;;)
  {
   struct dirent* de;

   errno = 0;
   if(!(de = readdir(dp)))
   {
    if(errno)
    {
     ErrnoHolder ene(errno);

     throw MDFN_Error(ene.Errno(), _("Error reading directory entries from \"%s\": %s"), path.c_str(), ene.StrError());     
    }    
    break;
   }
   //
   fname.clear();
   fname += de->d_name;
   //
   if(!callb(fname))
    break;
  }
  //
  closedir(dp);
  dp = nullptr;
 }
 catch(...)
 {
  if(dp)
  {
   closedir(dp);
   dp = nullptr;
  }
  throw;
 }
#endif
}

// Really dumb, maybe we should use boost?
bool NativeVFS::is_absolute_path(const std::string& path)
{
 if(!path.size())
  return false;

 if(is_path_separator(path[0]))
  return true;

 #if defined(WIN32) || defined(DOS)
 if(path.size() >= 2 && path[1] == ':')
 {
  if((path[0] >= 'a' && path[0] <= 'z') || (path[0] >= 'A' && path[0] <= 'Z'))
   return true;
 }
 #endif

 return false;
}

void NativeVFS::check_firop_safe(const std::string& path)
{
 //
 // First, check for any 8-bit characters, and print a warning about portability.
 //
 for(size_t x = 0; x < path.size(); x++)
 {
  if(path[x] & 0x80)
  {
   MDFN_printf(_("WARNING: Referenced path \"%s\" contains at least one 8-bit non-ASCII character; this may cause portability issues.\n"), path.c_str());
   break;
  }
 }

 if(!MDFN_GetSettingB("filesys.untrusted_fip_check"))
  return;

 // We could make this more OS-specific, but it shouldn't hurt to try to weed out usage of characters that are path
 // separators in one OS but not in another, and we'd also run more of a risk of missing a special path separator case
 // in some OS.
 std::string unsafe_reason;

#ifdef WIN32
 if(!UTF8_validate(path, true))
  unsafe_reason += _("Invalid UTF-8. ");
#endif

 if(path.find('\0') != std::string::npos)
  unsafe_reason += _("Contains null(0). ");

 if(path.find(':') != std::string::npos)
  unsafe_reason += _("Contains colon. ");

 if(path.find('\\') != std::string::npos)
  unsafe_reason += _("Contains backslash. ");

 if(path.find('/') != std::string::npos)
  unsafe_reason += _("Contains forward slash. ");

 if(path == "..")
  unsafe_reason += _("Is parent directory. ");

#if defined(DOS) || defined(WIN32)
 //
 // http://support.microsoft.com/kb/74496
 // http://googleprojectzero.blogspot.com/2016/02/the-definitive-guide-on-win32-to-nt.html
 //
 {
  static const char* dev_names[] = 
  {
   "CON", "PRN", "AUX", "CLOCK$", "NUL", "CONIN$", "CONOUT$",
   "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "COM¹", "COM²", "COM³",
   "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9", "LPT¹", "LPT²", "LPT³",
   NULL
  };
  //
  const char* pcs = path.c_str();
  for(const char** ls = dev_names; *ls != NULL; ls++)
  {
   size_t lssl = strlen(*ls);

   if(!MDFN_strazicmp(*ls, pcs, lssl))
   {
    if(pcs[lssl] == 0 || pcs[lssl] == ':' || pcs[lssl] == '.' || pcs[lssl] == ' ')
    {
     unsafe_reason += _("Is (likely) a reserved device name. ");
     break;
    }
   }
  }
 }
#endif

 if(unsafe_reason.size() > 0)
  throw MDFN_Error(0, _("Referenced path \"%s\" (escaped) is potentially unsafe.  %s Refer to the documentation about the \"filesys.untrusted_fip_check\" setting.\n"), MDFN_strescape(path).c_str(), unsafe_reason.c_str());
}

void NativeVFS::get_file_path_components(const std::string &file_path, std::string* dir_path_out, std::string* file_base_out, std::string *file_ext_out)
{
#if defined(WIN32) || defined(DOS)
 if(file_path.size() >= 3 && ((file_path[0] >= 'a' && file_path[0] <= 'z') || (file_path[0] >= 'A' && file_path[0] <= 'Z')) && file_path[1] == ':' && file_path.find_last_of(allowed_path_separators) == std::string::npos)
 {
  VirtualFS::get_file_path_components(file_path.substr(0, 2) + '.' + preferred_path_separator + file_path.substr(2), dir_path_out, file_base_out, file_ext_out);
  return;
 }
#endif

 VirtualFS::get_file_path_components(file_path, dir_path_out, file_base_out, file_ext_out);
}

}
