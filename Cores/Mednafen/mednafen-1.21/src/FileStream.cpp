/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* FileStream.cpp:
**  Copyright (C) 2010-2017 Mednafen Team
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

// Note: use seek(0, SEEK_CUR) instead of flush() for synchronization when mixing reads and writes,
// as fseek() is guaranteed to be safe for this purpose, while fflush() is a bit undefined/implementation-defined
// in this regard.

#include <mednafen/types.h>
#include "FileStream.h"
#include <mednafen/mednafen.h>

#include <trio/trio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#ifdef WIN32
#include <windows.h>
#else
#include <sys/file.h>
#endif

#ifdef HAVE_MMAP
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#endif

// Some really bad preprocessor abuse follows to handle platforms that don't have fseeko and ftello...and of course
// for largefile support on Windows:

#ifndef HAVE_FSEEKO
 #define fseeko fseek
#endif

#ifndef HAVE_FTELLO
 #define ftello ftell
#endif

#define STRUCT_STAT struct stat

#if SIZEOF_OFF_T == 4

 #ifdef HAVE_FOPEN64
  #define fopen fopen64
 #endif

 #ifdef HAVE_FTELLO64
  #undef ftello
  #define ftello ftello64
 #endif

 #ifdef HAVE_FSEEKO64
  #undef fseeko
  #define fseeko fseeko64
 #endif

 #ifdef HAVE_FSTAT64
  #define fstat fstat64
  #define stat stat64
  #undef STRUCT_STAT
  #define STRUCT_STAT struct stat64
 #endif

 #ifdef HAVE_FTRUNCATE64
  #define ftruncate ftruncate64
 #endif
#endif

FileStream::FileStream(const std::string& path, const int mode, const int do_lock) : OpenedMode(mode), mapping(NULL), mapping_size(0), locked(false), prev_was_write(-1)
{
 const char* fpom;
 int open_flags;

 path_save = path;

 switch(mode)
 {
  default:
	throw MDFN_Error(0, _("Unknown FileStream mode."));

  case MODE_READ:
	fpom = "rb";
	open_flags = O_RDONLY;
	break;

  case MODE_READ_WRITE:
	fpom = "r+b";
	open_flags = O_RDWR | O_CREAT;
	break;

  case MODE_WRITE:	// Truncation is handled near the end of the constructor.
  case MODE_WRITE_INPLACE:
	fpom = "wb";
	open_flags = O_WRONLY | O_CREAT;
	break;

  case MODE_WRITE_SAFE:
	fpom = "wb";
	open_flags = O_WRONLY | O_CREAT | O_EXCL;
	break;
 }

 #ifdef O_BINARY
  open_flags |= O_BINARY;
 #elif defined(_O_BINARY)
  open_flags |= _O_BINARY;
 #endif

 auto perm_mode = S_IRUSR | S_IWUSR;

 #if defined(S_IRGRP)
 perm_mode |= S_IRGRP;
 #endif

 #if defined(S_IROTH) 
 perm_mode |= S_IROTH;
 #endif

 int tmpfd;
 #ifdef WIN32
 {
  bool invalid_utf8;
  std::u16string u16path = UTF8_to_UTF16(path, &invalid_utf8, true);

  if(invalid_utf8)
   throw MDFN_Error(EINVAL, _("Error opening file \"%s\": %s"), path_save.c_str(), _("Invalid UTF-8 in path."));

  tmpfd = ::_wopen((const wchar_t*)u16path.c_str(), open_flags, perm_mode);
 }
 #else
 tmpfd = ::open(path.c_str(), open_flags, perm_mode);
 #endif

 if(tmpfd == -1)
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Error opening file \"%s\": %s"), path_save.c_str(), ene.StrError());
 }

 fp = ::fdopen(tmpfd, fpom);
 if(!fp)
 {
  ErrnoHolder ene(errno);

  ::close(tmpfd);

  throw MDFN_Error(ene.Errno(), _("Error opening file \"%s\": %s"), path_save.c_str(), ene.StrError());
 }
 //
 if(do_lock) // Lock before truncation
 {
  try 
  {
   lock(do_lock < 0);
  }
  catch(...)
  {
   try { close(); } catch(...) { }
   throw;
  }
 }

 if(mode == MODE_WRITE)
 {
  try
  {
   truncate(0);
  }
  catch(...)
  {
   try { close(); } catch(...) { }
   throw;
  }
 }
}

FileStream::~FileStream()
{
 try
 {
  close();
 }
 catch(std::exception &e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
 }
}

uint64 FileStream::attributes(void)
{
 uint64 ret = ATTRIBUTE_SEEKABLE;

 switch(OpenedMode)
 {
  case MODE_READ:
	ret |= ATTRIBUTE_READABLE;
	break;

  case MODE_READ_WRITE:
	ret |= ATTRIBUTE_READABLE | ATTRIBUTE_WRITEABLE;
	break;

  case MODE_WRITE_INPLACE:
  case MODE_WRITE_SAFE:
  case MODE_WRITE:
	ret |= ATTRIBUTE_WRITEABLE;
	break;
 }

 return ret;
}

uint8 *FileStream::map(void) noexcept
{
 if(!mapping)
 {
#ifdef HAVE_MMAP
  uint64 length = size();
  int prot = 0;
  int flags = 0;
  void* tptr;

  if(OpenedMode == MODE_READ)
  {
   prot |= PROT_READ; // | PROT_EXEC;
   flags |= MAP_PRIVATE;
  }
  else
  {
   prot |= PROT_WRITE;
   prot |= MAP_SHARED;
  }

  if(length > SIZE_MAX)
   return(NULL);

  tptr = mmap(NULL, length, prot, flags, fileno(fp), 0);
  if(tptr != (void*)-1)
  {
   mapping = tptr;
   mapping_size = length;

   #ifdef HAVE_MADVISE
   // Should probably make this controllable via flag or somesuch.
   madvise(mapping, mapping_size, MADV_SEQUENTIAL | MADV_WILLNEED);
   #endif
  }
#endif
 }

 return((uint8*)mapping);
}

uint64 FileStream::map_size(void) noexcept
{
 return mapping_size;
}

void FileStream::unmap(void) noexcept
{
 if(mapping)
 {
#ifdef HAVE_MMAP
  munmap(mapping, mapping_size);
#endif
  mapping = NULL;
  mapping_size = 0;
 }
}


uint64 FileStream::read(void *data, uint64 count, bool error_on_eos)
{
 uint64 read_count;

 if(prev_was_write == 1)
  seek(0, SEEK_CUR);

 clearerr(fp);

 read_count = fread(data, 1, count, fp);

 if(read_count != count)
 {
  ErrnoHolder ene(errno);

  if(ferror(fp))
   throw(MDFN_Error(ene.Errno(), _("Error reading from opened file \"%s\": %s"), path_save.c_str(), ene.StrError()));

  if(error_on_eos)
   throw(MDFN_Error(0, _("Error reading from opened file \"%s\": %s"), path_save.c_str(), _("Unexpected EOF")));
 }

 prev_was_write = 0;

 return(read_count);
}

void FileStream::write(const void *data, uint64 count)
{
 if(prev_was_write == 0)
  seek(0, SEEK_CUR);

 if(fwrite(data, 1, count, fp) != count)
 {
  ErrnoHolder ene(errno);

  throw(MDFN_Error(ene.Errno(), _("Error writing to opened file \"%s\": %s"), path_save.c_str(), ene.StrError()));
 }

 prev_was_write = 1;
}

void FileStream::truncate(uint64 length)
{
 if(fflush(fp) == EOF || ftruncate(fileno(fp), length) != 0)
 {
  ErrnoHolder ene(errno);

  throw(MDFN_Error(ene.Errno(), _("Error truncating opened file \"%s\": %s"), path_save.c_str(), ene.StrError()));
 }
}

void FileStream::seek(int64 offset, int whence)
{
 if(fseeko(fp, offset, whence) == -1)
 {
  ErrnoHolder ene(errno);

  throw(MDFN_Error(ene.Errno(), _("Error seeking in opened file \"%s\": %s"), path_save.c_str(), ene.StrError()));
 }
 prev_was_write = -1;
}

void FileStream::flush(void)
{
 if(fflush(fp) == EOF)
 {
  ErrnoHolder ene(errno);

  throw(MDFN_Error(ene.Errno(), _("Error flushing to opened file \"%s\": %s"), path_save.c_str(), ene.StrError()));
 }
}

uint64 FileStream::tell(void)
{
 auto offset = ftello(fp);

 if(offset == -1)
 {
  ErrnoHolder ene(errno);

  throw(MDFN_Error(ene.Errno(), _("Error getting position in opened file \"%s\": %s"), path_save.c_str(), ene.StrError()));
 }

 return (std::make_unsigned<decltype(offset)>::type)offset;
}

uint64 FileStream::size(void)
{
 STRUCT_STAT buf;

 if((OpenedMode != MODE_READ && fflush(fp) == EOF) || fstat(fileno(fp), &buf) == -1)
 {
  ErrnoHolder ene(errno);

  throw(MDFN_Error(ene.Errno(), _("Error getting the size of opened file \"%s\": %s"), path_save.c_str(), ene.StrError()));
 }

 return (std::make_unsigned<decltype(buf.st_size)>::type)buf.st_size;
}

void FileStream::lock(bool nb)
{
 if(locked)
  return;

 #ifdef WIN32
 OVERLAPPED olp;

 memset(&olp, 0, sizeof(OVERLAPPED));
 olp.Offset = ~(DWORD)0;
 olp.OffsetHigh = ~(DWORD)0;
 if(!LockFileEx((HANDLE)_get_osfhandle(fileno(fp)), LOCKFILE_EXCLUSIVE_LOCK | (nb ? LOCKFILE_FAIL_IMMEDIATELY : 0), 0, 1, 0, &olp))
 {
  uint32 ec = GetLastError();

  throw MDFN_Error((ec == ERROR_LOCK_VIOLATION) ? EWOULDBLOCK : 0, _("Error locking opened file \"%s\": 0x%08x"), path_save.c_str(), (unsigned)ec);
 }
 #else
 if(flock(fileno(fp), LOCK_EX | (nb ? LOCK_NB : 0)) == -1)
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Error locking opened file \"%s\": %s"), path_save.c_str(), ene.StrError());
 } 
 #endif

 locked = true;
}

void FileStream::unlock(void)
{
 if(!locked)
  return;

 #ifdef WIN32
 if(!UnlockFile((HANDLE)_get_osfhandle(fileno(fp)), ~(DWORD)0, ~(DWORD)0, 1, 0))
 {
  throw MDFN_Error(0, _("Error unlocking opened file \"%s\": 0x%08x"), path_save.c_str(), (unsigned)GetLastError());
 }
 #else
 if(flock(fileno(fp), LOCK_UN) == -1)
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Error unlocking opened file \"%s\": %s"), path_save.c_str(), ene.StrError());
 } 
 #endif

 locked = false;
}

void FileStream::close(void)
{
 if(fp)
 {
  unmap();

  if(locked)
  {
   try
   {
    if(OpenedMode != MODE_READ)
     flush();
   }
   catch(...)
   {
    try { unlock(); } catch(...) { }
    fclose(fp);
    fp = NULL;
    throw;
   }

   try
   {
    unlock();
   }
   catch(...)
   {
    fclose(fp);
    fp = NULL;
    throw;
   }
  }

  prev_was_write = -1;
  if(fclose(fp) == EOF)
  {
   ErrnoHolder ene(errno);
   fp = NULL;
   throw MDFN_Error(ene.Errno(), _("Error closing opened file \"%s\": %s"), path_save.c_str(), ene.StrError());
  }
  fp = NULL;
 }
}

int FileStream::get_line(std::string &str)
{
 int c;

 str.clear();

 while((c = get_char()) >= 0)
 {
  if(c == '\r' || c == '\n' || c == 0)
   return(c);

  str.push_back(c);
 }

 return(str.length() ? 256 : -1);
}

