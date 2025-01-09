/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* NativeVFS.cpp:
**  Copyright (C) 2018-2023 Mednafen Team
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
#include <mednafen/Time.h>

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

NativeVFS::NativeVFS() : VirtualFS(MDFN_PS, (MDFN_PSS_STYLE == 2) ? "\\/" : MDFN_PSS)
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

int NativeVFS::mkdir(const std::string& path, const bool throw_on_exist, const bool throw_on_noent)
{
 if(path.find('\0') != std::string::npos)
  throw MDFN_Error(EINVAL, _("Error creating directory \"%s\": %s"), MDFN_strhumesc(path).c_str(), _("Null character in path."));

 #ifdef WIN32
 bool invalid_utf8;
 auto tpath = Win32Common::UTF8_to_T(path, &invalid_utf8, true);

 if(invalid_utf8)
  throw MDFN_Error(EINVAL, _("Error creating directory \"%s\": %s"), MDFN_strhumesc(path).c_str(), _("Invalid UTF-8"));

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

  if(ene.Errno() == EEXIST && !throw_on_exist)
   return -1;
  else if(ene.Errno() == ENOENT && !throw_on_noent)
   return 0;
  else
   throw MDFN_Error(ene.Errno(), _("Error creating directory \"%s\": %s"), MDFN_strhumesc(path).c_str(), ene.StrError());
 }

 return true;
}


bool NativeVFS::unlink(const std::string& path, const bool throw_on_noent, const CanaryType canary)
{
 if(canary != CanaryType::unlink)
  _exit(-1);

 if(path.find('\0') != std::string::npos)
  throw MDFN_Error(EINVAL, _("Error unlinking \"%s\": %s"), MDFN_strhumesc(path).c_str(), _("Null character in path."));

 #ifdef WIN32
 bool invalid_utf8;
 auto tpath = Win32Common::UTF8_to_T(path, &invalid_utf8, true);

 if(invalid_utf8)
  throw MDFN_Error(EINVAL, _("Error unlinking \"%s\": %s"), MDFN_strhumesc(path).c_str(), _("Invalid UTF-8"));

 if(::_tunlink((const TCHAR*)tpath.c_str()))
 #else
 if(::unlink(path.c_str()))
 #endif
 {
  ErrnoHolder ene(errno);

  if(ene.Errno() == ENOENT && !throw_on_noent)
   return false;
  else
   throw MDFN_Error(ene.Errno(), _("Error unlinking \"%s\": %s"), MDFN_strhumesc(path).c_str(), ene.StrError());
 }

 return true;
}

void NativeVFS::rename(const std::string& oldpath, const std::string& newpath, const CanaryType canary)
{
 if(canary != CanaryType::rename)
  _exit(-1);

 if(oldpath.find('\0') != std::string::npos || newpath.find('\0') != std::string::npos)
  throw MDFN_Error(EINVAL, _("Error renaming \"%s\" to \"%s\": %s"), MDFN_strhumesc(oldpath).c_str(), MDFN_strhumesc(newpath).c_str(), _("Null character in path."));

 #ifdef WIN32
 bool invalid_utf8_old;
 bool invalid_utf8_new;
 auto toldpath = Win32Common::UTF8_to_T(oldpath, &invalid_utf8_old, true);
 auto tnewpath = Win32Common::UTF8_to_T(newpath, &invalid_utf8_new, true);

 if(invalid_utf8_old || invalid_utf8_new)
  throw MDFN_Error(EINVAL, _("Error renaming \"%s\" to \"%s\": %s"), MDFN_strhumesc(oldpath).c_str(), MDFN_strhumesc(newpath).c_str(), _("Invalid UTF-8"));

 if(::_trename((const TCHAR*)toldpath.c_str(), (const TCHAR*)tnewpath.c_str()))
 {
  ErrnoHolder ene(errno);

  // TODO/FIXME: Ensure oldpath and newpath don't refer to the same file via symbolic link.
  if(oldpath != newpath && (ene.Errno() == EACCES || ene.Errno() == EEXIST))
  {
   if(::_tunlink((const TCHAR*)tnewpath.c_str()) || ::_trename((const TCHAR*)toldpath.c_str(), (const TCHAR*)tnewpath.c_str()))
    throw MDFN_Error(ene.Errno(), _("Error renaming \"%s\" to \"%s\": %s"), MDFN_strhumesc(oldpath).c_str(), MDFN_strhumesc(newpath).c_str(), ene.StrError());
  }
  else
   throw MDFN_Error(ene.Errno(), _("Error renaming \"%s\" to \"%s\": %s"), MDFN_strhumesc(oldpath).c_str(), MDFN_strhumesc(newpath).c_str(), ene.StrError());
 }
 #else

 if(::rename(oldpath.c_str(), newpath.c_str()))
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Error renaming \"%s\" to \"%s\": %s"), MDFN_strhumesc(oldpath).c_str(), MDFN_strhumesc(newpath).c_str(), ene.StrError());
 }

 #endif
}

bool NativeVFS::finfo(const std::string& path, FileInfo* fi, const bool throw_on_noent)
{
 if(path.find('\0') != std::string::npos)
  throw MDFN_Error(EINVAL, _("Error getting file information for \"%s\": %s"), MDFN_strhumesc(path).c_str(), _("Null character in path."));
 //
 //
 #ifdef WIN32
 HANDLE hand;
 bool invalid_utf8;
 auto tpath = Win32Common::UTF8_to_T(path, &invalid_utf8, true);
 BY_HANDLE_FILE_INFORMATION buf;

 if(invalid_utf8)
  throw MDFN_Error(EINVAL, _("Error getting file information for \"%s\": %s"), MDFN_strhumesc(path).c_str(), _("Invalid UTF-8"));

 hand = CreateFile((const TCHAR*)tpath.c_str(), 0, FILE_SHARE_DELETE | FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
 if(hand == INVALID_HANDLE_VALUE)
 {
  const uint32 ec = GetLastError();
  uint32 en = 0;

  //
  // Begin Win9x fallback
  //
  if(ec == ERROR_INVALID_PARAMETER && (GetVersion() & 0x80000000))
  {
   WIN32_FILE_ATTRIBUTE_DATA fad;
   FileInfo new_fi;
   uint64 mus;

   if(path.size() > 0 && (path.back() == '/' || path.back() == '\\'))
    tpath.push_back('.');

   memset(&fad, 0, sizeof(fad));

   if(!GetFileAttributesEx((const TCHAR*)tpath.c_str(), GetFileExInfoStandard, &fad))
   {
    const uint32 nec = GetLastError();
    int nen = 0;

    if(nec == ERROR_FILE_NOT_FOUND || nec == ERROR_PATH_NOT_FOUND)
    {
     nen = ENOENT;

     if(!throw_on_noent)
      return false;
    }
    else if(nec == ERROR_ACCESS_DENIED)
     nen = EPERM;

    throw MDFN_Error(nen, _("Error getting file information for \"%s\": %s"), MDFN_strhumesc(path).c_str(), Win32Common::ErrCodeToString(nec).c_str());
   }

   //MDFN_printf("%016llx %016llx\n", ((uint64)fad.ftLastWriteTime.dwHighDateTime << 32) | fad.ftLastWriteTime.dwLowDateTime, ((uint64)fad.ftCreationTime.dwHighDateTime << 32) | fad.ftCreationTime.dwLowDateTime);

   mus = ((uint64)fad.ftLastWriteTime.dwHighDateTime << 32) | fad.ftLastWriteTime.dwLowDateTime;
   if(!mus)
    mus = ((uint64)fad.ftCreationTime.dwHighDateTime << 32) | fad.ftCreationTime.dwLowDateTime;

   new_fi.size = ((uint64)fad.nFileSizeHigh << 32) | fad.nFileSizeLow;
   new_fi.mtime_us = (int64)(mus / 10) - 11644473600000000LL;

   new_fi.is_directory = (bool)(fad.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY);
   new_fi.is_regular = !(fad.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_DEVICE | FILE_ATTRIBUTE_REPARSE_POINT));

#if 0
   MDFN_printf("finfo(\"%s\", [], %s):\n", path.c_str(), throw_on_noent ? "true" : "false");
   {
    MDFN_AutoIndent aind(1);

    MDFN_printf("size: %llu\n", (unsigned long long)new_fi.size);
    MDFN_printf("mtime_us: %llu - %s\n", (unsigned long long)new_fi.mtime_us, Time::StrTime(Time::LocalTime(new_fi.mtime_us / 1000 / 1000)).c_str());
    MDFN_printf("is_regular: %d\n", new_fi.is_regular);
    MDFN_printf("is_directory: %d\n", new_fi.is_directory);
   }
#endif

   if(fi)
    *fi = new_fi;
   //
   //
   //
   return true;
  }
  //
  // End Win9x fallback
  //

  if(ec == ERROR_FILE_NOT_FOUND || ec == ERROR_PATH_NOT_FOUND)
  {
   en = ENOENT;

   if(!throw_on_noent)
    return false;
  }
  else if(ec == ERROR_ACCESS_DENIED)
   en = EPERM;

  throw MDFN_Error(en, _("Error getting file information for \"%s\": %s"), MDFN_strhumesc(path).c_str(), Win32Common::ErrCodeToString(ec).c_str());
 }

 //MDFN_printf("0x%016llx\n", (unsigned long long)hand);

 memset(&buf, 0, sizeof(buf));
 if(!GetFileInformationByHandle(hand, &buf))
 {
  uint32 ec = GetLastError();
  uint32 en = 0;

  CloseHandle(hand);

  if(ec == ERROR_ACCESS_DENIED)
   en = EPERM;

  throw MDFN_Error(en, _("Error getting file information for \"%s\": %s"), MDFN_strhumesc(path).c_str(), Win32Common::ErrCodeToString(ec).c_str());
 } 
 CloseHandle(hand);
 //
 //
 //
 {
  FileInfo new_fi;
  uint64 mus;

  mus = ((uint64)buf.ftLastWriteTime.dwHighDateTime << 32) | buf.ftLastWriteTime.dwLowDateTime;
  if(!mus)
   mus = ((uint64)buf.ftCreationTime.dwHighDateTime << 32) | buf.ftCreationTime.dwLowDateTime;

  new_fi.size = ((uint64)buf.nFileSizeHigh << 32) | buf.nFileSizeLow;
  new_fi.mtime_us = (int64)(mus / 10) - 11644473600000000LL;

  new_fi.is_directory = (bool)(buf.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY);
  new_fi.is_regular = !(buf.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_DEVICE | FILE_ATTRIBUTE_REPARSE_POINT));

#if 0
  MDFN_printf("finfo(\"%s\", [], %s):\n", path.c_str(), throw_on_noent ? "true" : "false");
  {
   MDFN_AutoIndent aind(1);

   MDFN_printf("size: %llu\n", (unsigned long long)new_fi.size);
   MDFN_printf("mtime_us: %llu - %s\n", (unsigned long long)new_fi.mtime_us, Time::StrTime(Time::LocalTime(new_fi.mtime_us / 1000 / 1000)).c_str());
   MDFN_printf("is_regular: %d\n", new_fi.is_regular);
   MDFN_printf("is_directory: %d\n", new_fi.is_directory);
  }
#endif

  if(fi)
   *fi = new_fi;
 }
 #else
 struct stat buf;
 if(::stat(path.c_str(), &buf))
 {
  ErrnoHolder ene(errno);

  if(ene.Errno() == ENOENT && !throw_on_noent)
   return false;

  throw MDFN_Error(ene.Errno(), _("Error getting file information for \"%s\": %s"), MDFN_strhumesc(path).c_str(), ene.StrError());
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
 #endif

 return true;
}

void NativeVFS::readdirentries(const std::string& path, std::function<bool(const std::string&)> callb)
{
 if(path.find('\0') != std::string::npos)
  throw MDFN_Error(EINVAL, _("Error reading directory entries from \"%s\": %s"), MDFN_strhumesc(path).c_str(), _("Null character in path."));
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
  throw MDFN_Error(EINVAL, _("Error reading directory entries from \"%s\": %s"), MDFN_strhumesc(path).c_str(), _("Invalid UTF-8"));

 try
 {
  if(!(dp = FindFirstFile((const TCHAR*)tpath.c_str(), &ded)))
  {
   const uint32 ec = GetLastError();

   throw MDFN_Error(0, _("Error reading directory entries from \"%s\": %s"), MDFN_strhumesc(path).c_str(), Win32Common::ErrCodeToString(ec).c_str());
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
     throw MDFN_Error(0, _("Error reading directory entries from \"%s\": %s"), MDFN_strhumesc(path).c_str(), Win32Common::ErrCodeToString(ec).c_str());
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

   throw MDFN_Error(ene.Errno(), _("Error reading directory entries from \"%s\": %s"), MDFN_strhumesc(path).c_str(), ene.StrError());
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

     throw MDFN_Error(ene.Errno(), _("Error reading directory entries from \"%s\": %s"), MDFN_strhumesc(path).c_str(), ene.StrError());     
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
 if(path.size() >= 2 && MDFN_isaz(path[0]) && path[1] == ':')
  return true;
 #endif

 return false;
}

bool NativeVFS::is_driverel_path(const std::string& path)
{
 #if defined(WIN32) || defined(DOS)
 if(path.size() >= 2 && MDFN_isaz(path[0]) && path[1] == ':' && (path.size() < 3 || !is_path_separator(path[2])))
  return true;
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
   MDFN_printf(_("WARNING: Referenced path \"%s\" contains at least one 8-bit non-ASCII character; this may cause portability issues.\n"), MDFN_strhumesc(path).c_str());
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
  throw MDFN_Error(0, _("Referenced path \"%s\" is potentially unsafe.  %s Refer to the documentation about the \"filesys.untrusted_fip_check\" setting.\n"), MDFN_strhumesc(path).c_str(), unsafe_reason.c_str());
}

void NativeVFS::get_file_path_components(const std::string &file_path, std::string* dir_path_out, std::string* file_base_out, std::string *file_ext_out)
{
#if defined(WIN32) || defined(DOS)
 if(file_path.size() >= 3 && MDFN_isaz(file_path[0]) && file_path[1] == ':' && file_path.find_last_of(allowed_path_separators) == std::string::npos)
 {
  VirtualFS::get_file_path_components(file_path.substr(0, 2) + '.' + preferred_path_separator + file_path.substr(2), dir_path_out, file_base_out, file_ext_out);
  return;
 }
#endif

 VirtualFS::get_file_path_components(file_path, dir_path_out, file_base_out, file_ext_out);
}

std::string NativeVFS::get_human_path(const std::string& path)
{
 return MDFN_sprintf(_("\"%s\""), MDFN_strhumesc(path).c_str());
}

}
