/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <mednafen/types.h>
#include "FileStream.h"
#include <mednafen/mednafen.h>

#include <trio/trio.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>

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

FileStream::FileStream(const std::string& path, const int mode) : OpenedMode(mode), mapping(NULL), mapping_size(0)
{
 path_save = path;

 if(mode == MODE_READ)
  fp = fopen(path.c_str(), "rb");
 else if(mode == MODE_WRITE)
  fp = fopen(path.c_str(), "wb");
 else if(mode == MODE_WRITE_SAFE || mode == MODE_WRITE_INPLACE)	// SO ANNOYING
 {
  int open_flags = O_WRONLY | O_CREAT;

  if(mode == MODE_WRITE_SAFE)
   open_flags |= O_EXCL;

  #ifdef O_BINARY
   open_flags |= O_BINARY;
  #elif defined(_O_BINARY)
   open_flags |= _O_BINARY;
  #endif

  #if defined(S_IRGRP) && defined(S_IROTH) 
  int tmpfd = open(path.c_str(), open_flags, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
  #else
  int tmpfd = open(path.c_str(), open_flags, S_IRUSR | S_IWUSR);
  #endif
  if(tmpfd == -1)
  {
   ErrnoHolder ene(errno);

   throw(MDFN_Error(ene.Errno(), _("Error opening file \"%s\": %s"), path_save.c_str(), ene.StrError()));
  }
  fp = fdopen(tmpfd, "wb");
 }
 else
  abort();

 if(!fp)
 {
  ErrnoHolder ene(errno);

  throw(MDFN_Error(ene.Errno(), _("Error opening file \"%s\": %s"), path_save.c_str(), ene.StrError()));
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
  MDFND_PrintError(e.what());
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

 return(read_count);
}

void FileStream::write(const void *data, uint64 count)
{
 if(fwrite(data, 1, count, fp) != count)
 {
  ErrnoHolder ene(errno);

  throw(MDFN_Error(ene.Errno(), _("Error writing to opened file \"%s\": %s"), path_save.c_str(), ene.StrError()));
 }
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

void FileStream::close(void)
{
 if(fp)
 {
  FILE *tmp = fp;

  unmap();
  fp = NULL;

  if(fclose(tmp) == EOF)
  {
   ErrnoHolder ene(errno);

   throw(MDFN_Error(ene.Errno(), _("Error closing opened file \"%s\": %s"), path_save.c_str(), ene.StrError()));
  }
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

