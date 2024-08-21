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
#include <mednafen/compress/ZLInflateFilter.h>
#include <mednafen/MemoryStream.h>
#include <mednafen/IPSPatcher.h>
#include <mednafen/string/string.h>

#include <trio/trio.h>

#include "file.h"
#include "general.h"

namespace Mednafen
{

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

MDFNFILE::MDFNFILE(VirtualFS* vfs, const char *path, const std::vector<FileExtensionSpecStruct>& known_ext, const char *purpose) : ext((const std::string&)f_ext), fbase((const std::string&)f_fbase)
{
 Open(vfs, path, known_ext, purpose);
}

MDFNFILE::~MDFNFILE()
{
 Close();
}

/*
	VirtualFS* gf_vfs;
	const std::string gf_path;
	std::string gf_dir_path;

	if((gf_vfs = mfgf.archive_vfs()))
	{
         gf_dir_path = mfgf.archive_dir_path();
	}
	else
	{
	 gf_vfs = &NVFS;
	 NVFS.get_file_path_components(path, &dir_path);
	}
*/

void MDFNFILE::Open(VirtualFS* vfs, const char *path, const std::vector<FileExtensionSpecStruct>& known_ext, const char *purpose)
{
 try
 {
  const size_t path_len = strlen(path);

  //
  // ZIP file
  //
  if(path_len >= 4 && !MDFN_strazicmp(path + (path_len - 4), ".zip"))
  {
   std::unique_ptr<ZIPReader> zr(new ZIPReader(std::unique_ptr<Stream>(vfs->open(path, VirtualFS::MODE_READ))));
   const size_t num_files = zr->num_files();
   size_t which_to_use = SIZE_MAX;
   size_t fallback = SIZE_MAX;
   int priority = INT_MIN;

   for(size_t i = 0; i < num_files; i++)
   {
    const size_t zf_size = zr->get_file_size(i);

    if(!zf_size)
     continue;

    if(fallback == SIZE_MAX)
     fallback = i;

    if(zf_size > MaxROMImageSize)
     continue;

    const char* zf_path = zr->get_file_path(i);
    const size_t zf_path_len = strlen(zf_path);

    for(FileExtensionSpecStruct const& ex : known_ext)
    {
     const size_t ex_ext_len = strlen(ex.extension);

     if(zf_path_len >= ex_ext_len)
     {
      if(!MDFN_strazicmp(zf_path + (zf_path_len - ex_ext_len), ex.extension))
      {
       //printf("%s, %s %d, %d\n", zf_path, ex.extension, ex.priority, priority);

       if(which_to_use == SIZE_MAX || ex.priority > priority)
       {
        which_to_use = i;
        priority = ex.priority;
       }

       break;
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
   {
    std::unique_ptr<Stream> tmpfp(zr->open(which_to_use));
    const size_t zf_size = tmpfp->size();

    if(zf_size > MaxROMImageSize)
     throw MDFN_Error(0, _("ROM image is too large; maximum size allowed is %llu bytes."), (unsigned long long)MaxROMImageSize);

    str.reset(new MemoryStream(zf_size, true));

    tmpfp->read(str->map(), str->size());
    tmpfp->close();
   }

   //
   // Don't use vfs->get_file_path_components() here.
   //
   const char* zf_path = zr->get_file_path(which_to_use);
   const char* ls = strrchr(zf_path, '/');
   const char* zf_fname = ls ? ls + 1 : zf_path;
   const char* ld = strrchr(zf_fname, '.');

   f_ext = std::string(ld ? ld : "");
   f_fbase = std::string(zf_fname, ld ? (ld - zf_fname) : strlen(zf_fname));

   //printf("f_ext=%s, f_fbase=%s\n", f_ext.c_str(), f_fbase.c_str());
   //
   //
   //
   archive_vfs = std::move(zr);
   //
   archive_vfs->get_file_path_components(zf_path, &f_dir_path);
   f_path = zf_path;
   f_vfs = archive_vfs.get();
   //printf("FOOO: %s\n", f_dir_path.c_str());
  }
  else
  {
   // We'll clean up f_ext to remove the leading period, and convert to lowercase, after
   // the plain vs gzip file handling code below(since gzip handling path will want to strip off an extra extension).
   vfs->get_file_path_components(path, nullptr, &f_fbase, &f_ext);

   if(path_len >= 3 && !MDFN_strazicmp(path + (path_len - 3), ".gz")) // gzip
   {
    std::unique_ptr<Stream> tfp(vfs->open(path, VirtualFS::MODE_READ));

    str.reset(new MemoryStream(new ZLInflateFilter(tfp.get(), MDFN_sprintf(_("opened file \"%s\""), path), ZLInflateFilter::FORMAT::GZIP, tfp->size()), MaxROMImageSize));

    vfs->get_file_path_components(f_fbase, nullptr, &f_fbase, &f_ext);
   }
   else // Plain
   {
    std::unique_ptr<Stream> tfp(vfs->open(path, VirtualFS::MODE_READ));

    if(tfp->size() > MaxROMImageSize)
    {
     const char* hint = "";

     if(!MDFN_strazicmp(f_ext.c_str(), ".bin") || !MDFN_strazicmp(f_ext.c_str(), ".iso") || !MDFN_strazicmp(f_ext.c_str(), ".img"))
      hint = _("  If you are trying to load a CD image, load it via CUE/CCD/TOC/M3U instead of BIN/ISO/IMG.");

     throw MDFN_Error(0, _("ROM image is too large; maximum size allowed is %llu bytes.%s"), (unsigned long long)MaxROMImageSize, hint);
    }
    str = std::move(tfp);
   }
   //
   vfs->get_file_path_components(path, &f_dir_path);
   f_path = path;
   f_vfs = vfs;
  }

  // Remove leading period in file extension.
  if(f_ext.size() > 0 && f_ext[0] == '.')
   f_ext = f_ext.substr(1);

  MDFN_strazlower(&f_ext);

  //printf("|%s| --- |%s|\n", f_fbase.c_str(), f_ext.c_str());
  //
  //
  //
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
 std::unique_ptr<MemoryStream> tmp;

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
 FileStream cts(MDFN_MakeFName(MDFNMKF_SAVBACK, -1, sav_ext), FileStream::MODE_READ_WRITE, true);
 uint8 counter = max_backup_count - 1;

 cts.read(&counter, 1, false);
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

}
