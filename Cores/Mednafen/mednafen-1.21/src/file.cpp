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

#include "mednafen.h"
#include <mednafen/FileStream.h>
#include <mednafen/compress/GZFileStream.h>
#include <mednafen/compress/ZIPReader.h>
#include <mednafen/MemoryStream.h>
#include <mednafen/IPSPatcher.h>
#include <mednafen/string/string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <trio/trio.h>

#include "file.h"
#include "general.h"

static const uint64 MaxROMImageSize = (int64)1 << 26; // 2 ^ 26 = 64MiB

void MDFNFILE::ApplyIPS(Stream *ips)
{
 //
 // If the stream is not a MemoryStream, turn it into one.
 //
 //if(!(str->attributes() & Stream::ATTRIBUTE_WRITEABLE))
 if(dynamic_cast<MemoryStream*>(str.get()) == nullptr)
 {
  str.reset(new MemoryStream(str.release(), MaxROMImageSize));
 }  

 {
  MDFN_AutoIndent aind(1);
  uint32 count;

  count = IPSPatcher::Apply(ips, str.get());

  MDFN_printf(_("IPS EOF:  Did %u patches\n\n"), count);

  if(ips->tell() < ips->size())
  {
   MDFN_AutoIndent aindw(1);

   MDFN_printf(_("Warning:  trailing unused data in IPS file.\n"));
  }
 }
}

MDFNFILE::MDFNFILE(const char *path, const FileExtensionSpecStruct *known_ext, const char *purpose) : ext((const std::string&)f_ext), fbase((const std::string&)f_fbase)
{
 Open(path, known_ext, purpose);
}

MDFNFILE::~MDFNFILE()
{
 Close();
}


void MDFNFILE::Open(const char *path, const FileExtensionSpecStruct *known_ext, const char *purpose)
{
 try
 {
  const size_t path_len = strlen(path);

  //
  // ZIP file
  //
  if(path_len >= 4 && !MDFN_strazicmp(path + (path_len - 4), ".zip"))
  {
   ZIPReader zr(std::unique_ptr<FileStream>(new FileStream(path, FileStream::MODE_READ)));
   const size_t num_files = zr.num_files();
   size_t which_to_use = SIZE_MAX;
   bool which_to_use_lpext = true;
   size_t fallback = SIZE_MAX;

   for(size_t i = 0; i < num_files; i++)
   {
    const size_t zf_size = zr.get_file_size(i);

    if(!zf_size)
     continue;

    if(fallback == SIZE_MAX)
     fallback = i;

    if(zf_size > MaxROMImageSize)
     continue;

    const char* zf_path = zr.get_file_path(i);
    const size_t zf_path_len = strlen(zf_path);

    for(const FileExtensionSpecStruct* ex = known_ext; ex->extension; ex++)
    {
     const size_t ex_ext_len = strlen(ex->extension);

     if(zf_path_len >= ex_ext_len)
     {
      if(!MDFN_strazicmp(zf_path + (zf_path_len - ex_ext_len), ex->extension))
      {
       const bool new_which_to_use_lpext = !MDFN_strazicmp(ex->extension, ".bin");

       if(which_to_use == SIZE_MAX || (which_to_use_lpext && !new_which_to_use_lpext))
       {
        which_to_use = i;
        which_to_use_lpext = new_which_to_use_lpext;
        if(!which_to_use_lpext)
         goto Found;
       }
      }
     }
    }
   }
   if(which_to_use == SIZE_MAX)
   {
    if(fallback == SIZE_MAX)
     throw MDFN_Error(0, _("No usable files in ZIP."));
    else
     which_to_use = fallback;
   }
   //
   Found:;

   //
   {
    std::unique_ptr<Stream> tmpfp(zr.open(which_to_use));
    const size_t zf_size = tmpfp->size();

    if(zf_size > MaxROMImageSize)
     throw MDFN_Error(0, _("ROM image is too large; maximum size allowed is %llu bytes."), (unsigned long long)MaxROMImageSize);

    str.reset(new MemoryStream(zf_size, true));

    tmpfp->read(str->map(), str->size());
    tmpfp->close();
   }

   // Don't use MDFN_GetFilePathComponents() here.
   {
    const char* zf_path = zr.get_file_path(which_to_use);
    const char* ls = strrchr(zf_path, '/');
    const char* zf_fname = ls ? ls + 1 : zf_path;
    const char* ld = strrchr(zf_fname, '.');

    f_ext = std::string(ld ? ld : "");
    f_fbase = std::string(zf_fname, ld ? (ld - zf_fname) : strlen(zf_fname));

    //printf("f_ext=%s, f_fbase=%s\n", f_ext.c_str(), f_fbase.c_str());
   }
  }
  else // If it's not a zip file, handle it as...another type of file!
  {
   std::unique_ptr<Stream> tfp(new FileStream(path, FileStream::MODE_READ));

   // We'll clean up f_ext to remove the leading period, and convert to lowercase, after
   // the plain vs gzip file handling code below(since gzip handling path will want to strip off an extra extension).
   MDFN_GetFilePathComponents(path, NULL, &f_fbase, &f_ext);

   uint8 gzmagic[3] = { 0 };

   if(tfp->read(gzmagic, 3, false) != 3 || gzmagic[0] != 0x1F || gzmagic[1] != 0x8b || gzmagic[2] != 0x08)
   {
    tfp->seek(0, SEEK_SET);

    if(tfp->size() > MaxROMImageSize)
    {
     const char* hint = "";

     if(!MDFN_strazicmp(f_ext.c_str(), ".bin") || !MDFN_strazicmp(f_ext.c_str(), ".iso") || !MDFN_strazicmp(f_ext.c_str(), ".img"))
      hint = _("  If you are trying to load a CD image, load it via CUE/CCD/TOC/M3U instead of BIN/ISO/IMG.");

     throw MDFN_Error(0, _("ROM image is too large; maximum size allowed is %llu bytes.%s"), (unsigned long long)MaxROMImageSize, hint);
    }

    str = std::move(tfp);
   }
   else                  /* Probably gzip */
   {
    delete tfp.release();

    str.reset(new MemoryStream(new GZFileStream(path, GZFileStream::MODE::READ), MaxROMImageSize));

    MDFN_GetFilePathComponents(f_fbase, NULL, &f_fbase, &f_ext);
   } // End gzip handling
  } // End normal and gzip file handling else to zip

  // Remove leading period in file extension.
  if(f_ext.size() > 0 && f_ext[0] == '.')
   f_ext = f_ext.substr(1);

  MDFN_strazlower(f_ext);

  //printf("|%s| --- |%s|\n", f_fbase.c_str(), f_ext.c_str());
 }
 catch(...)
 {
  Close();
  throw;
 }
}

void MDFNFILE::Close(void) throw()
{
 f_ext.clear();
 f_fbase.clear();

 if(str.get())
 {
  delete str.release();
 }
}

static INLINE void MDFN_DumpToFileReal(const std::string& path, const std::vector<PtrLengthPair> &pearpairs)
{
 FileStream fp(path, FileStream::MODE_WRITE_INPLACE);

 for(unsigned int i = 0; i < pearpairs.size(); i++)
 {
  fp.write(pearpairs[i].GetData(), pearpairs[i].GetLength());
 }

 fp.truncate(fp.tell());
 fp.close();
}

bool MDFN_DumpToFile(const std::string& path, const std::vector<PtrLengthPair> &pearpairs, bool throw_on_error)
{
 try
 {
  MDFN_DumpToFileReal(path, pearpairs);
 }
 catch(std::exception &e)
 {
  if(throw_on_error)
   throw;
  else
  {
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
   return(false);
  }
 }
 return(true);
}

bool MDFN_DumpToFile(const std::string& path, const void *data, uint64 length, bool throw_on_error)
{
 std::vector<PtrLengthPair> tmp_pairs;

 tmp_pairs.push_back(PtrLengthPair(data, length));

 return MDFN_DumpToFile(path, tmp_pairs, throw_on_error);
}


std::unique_ptr<Stream> MDFN_AmbigGZOpenHelper(const std::string& path, std::vector<size_t> good_sizes)
{
 std::unique_ptr<Stream> fp(new FileStream(path, FileStream::MODE_READ));

 if(fp->size() >= 18)
 {
  uint8 head[10];

  fp->read(head, sizeof(head));

  if(head[0] == 0x1F && head[1] == 0x8B && head[2] == 0x08)
  {
   uint8 footer[8];
   uint32 fs;

   fp->seek(-8, SEEK_END);
   fp->read(footer, sizeof(footer));
   fs = MDFN_de32lsb(&footer[4]);

   for(auto const s : good_sizes)
   {
    if(s == fs)
    {
     fp.reset(nullptr);
     fp.reset(new GZFileStream(path, GZFileStream::MODE::READ));
     return fp;
    }
   }
  }
  fp->rewind();
 }

 return fp;
}

void MDFN_BackupSavFile(const uint8 max_backup_count, const char* sav_ext)
{
 FileStream cts(MDFN_MakeFName(MDFNMKF_SAVBACK, -1, sav_ext), FileStream::MODE_READ_WRITE, true);
 std::unique_ptr<MemoryStream> tmp;
 uint8 counter = max_backup_count - 1;

 cts.read(&counter, 1, false);
 //
 //
 try
 {
  tmp.reset(new MemoryStream(new FileStream(MDFN_MakeFName(MDFNMKF_SAV, 0, sav_ext), FileStream::MODE_READ)));
 }
 catch(MDFN_Error& e)
 {
  if(e.GetErrno() == ENOENT)
   return;

  throw;
 }
 //
 //
 //
 {
  try
  {
   MemoryStream oldbks(new GZFileStream(MDFN_MakeFName(MDFNMKF_SAVBACK, counter, sav_ext), GZFileStream::MODE::READ));

   if(oldbks.size() == tmp->size() && !memcmp(oldbks.map(), tmp->map(), oldbks.size()))
   {
    //puts("Skipped backup.");
    return;
   }
  }
  catch(MDFN_Error& e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
  }
  //
  counter = (counter + 1) % max_backup_count;
  //
  GZFileStream bks(MDFN_MakeFName(MDFNMKF_SAVBACK, counter, sav_ext), GZFileStream::MODE::WRITE, 9);

  bks.write(tmp->map(), tmp->size());

  bks.close();
 }

 //
 //
 cts.rewind();
 cts.write(&counter, 1);
 cts.close();
}


//
//
//
void MDFN_mkdir_T(const char* path)
{
 #ifdef WIN32
 bool invalid_utf8;
 std::u16string u16path = UTF8_to_UTF16(path, &invalid_utf8, true);

 if(invalid_utf8)
 {
  errno = EINVAL;
  /*return -1;*/
 }
 else
  /*return*/ _wmkdir((const wchar_t*)u16path.c_str());
 #elif defined HAVE_MKDIR
  #if MKDIR_TAKES_ONE_ARG
   ::mkdir(path);
  #else
   ::mkdir(path, S_IRWXU);
  #endif
 #else
  #error "mkdir() missing?!"
 #endif
}

int MDFN_stat(const char* path, struct stat* buf)
{
 #ifdef WIN32
 bool invalid_utf8;
 std::u16string u16path = UTF8_to_UTF16(path, &invalid_utf8, true);

 if(invalid_utf8)
 {
  errno = EINVAL;
  return -1;
 }
 else
  return _wstati64((const wchar_t*)u16path.c_str(), buf);
 #else
 return stat(path, buf);
 #endif
}

void MDFN_unlink(const char* path)
{
 #ifdef WIN32
 bool invalid_utf8;
 std::u16string u16path = UTF8_to_UTF16(path, &invalid_utf8, true);

 if(invalid_utf8)
  throw MDFN_Error(ErrnoHolder(EINVAL));

 if(_wunlink((const wchar_t*)u16path.c_str()))
 #else
 if(unlink(path))
 #endif
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Error unlinking \"%s\": %s"), path, ene.StrError());
 }
}

void MDFN_rename(const char* oldpath, const char* newpath)
{
 #ifdef WIN32
 bool invalid_utf8_old;
 bool invalid_utf8_new;
 std::u16string u16oldpath = UTF8_to_UTF16(oldpath, &invalid_utf8_old, true);
 std::u16string u16newpath = UTF8_to_UTF16(newpath, &invalid_utf8_new, true);

 if(invalid_utf8_old || invalid_utf8_new)
  throw MDFN_Error(ErrnoHolder(EINVAL));

 if(_wrename((const wchar_t*)u16oldpath.c_str(), (const wchar_t*)u16newpath.c_str()))
 #else
 if(rename(oldpath, newpath))
 #endif
 {
  ErrnoHolder ene(errno);

  throw MDFN_Error(ene.Errno(), _("Error renaming \"%s\" to \"%s\": %s"), oldpath, newpath, ene.StrError());
 }
}
