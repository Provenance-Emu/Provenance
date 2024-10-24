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
#include <mednafen/compress/ZstdDecompressFilter.h>
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

MDFNFILE::MDFNFILE(VirtualFS* vfs, const std::string& path, const std::vector<FileExtensionSpecStruct>& known_ext, const char *purpose, int* monocomp_double_ext)
{
 std::string archive_vfs_path;
 archive_vfs.reset(MDFN_OpenArchive(vfs, path, known_ext, &archive_vfs_path));

 if(archive_vfs)
  Open(archive_vfs.get(), archive_vfs_path, purpose, monocomp_double_ext);
 else
  Open(vfs, path, purpose, monocomp_double_ext);
}

MDFNFILE::MDFNFILE(VirtualFS* vfs, const std::string& path, const char *purpose, int* monocomp_double_ext)
{
 Open(vfs, path, purpose, monocomp_double_ext);
}

MDFNFILE::~MDFNFILE()
{
 Close();
}

VirtualFS* MDFN_OpenArchive(VirtualFS* vfs, const std::string& path, const std::vector<FileExtensionSpecStruct>& known_ext, std::string* path_out)
{
 std::unique_ptr<ArchiveReader> zr(ArchiveReader::Open(vfs, path));

 // Is archive.
 if(zr)
 {
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

   const std::string* zf_path = zr->get_file_path(i);
   std::string zf_ext, zf_fname;

   zr->get_file_path_components(*zf_path, nullptr, &zf_fname, &zf_ext);
   zf_fname = zf_fname + zf_ext;

   for(FileExtensionSpecStruct const& ex : known_ext)
   {
    bool match = false;

    if(ex.extension[0] == '.')
     match = zr->test_ext(*zf_path, ex.extension);
    else
     match = !MDFN_strazicmp(zf_fname, ex.extension);

    if(match)
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

  if(which_to_use == SIZE_MAX)
  {
   if(fallback == SIZE_MAX)
    throw MDFN_Error(0, _("No usable file found in ZIP archive %s."), vfs->get_human_path(path).c_str());
   else
    which_to_use = fallback;
  }
  //
  *path_out = *zr->get_file_path(which_to_use);

  return zr.release();
 }

 return nullptr;
}

void MDFNFILE::Open(VirtualFS* vfs, const std::string& path, const char *purpose, int* monocomp_double_ext)
{
 if(monocomp_double_ext)
  *monocomp_double_ext = false;

 try
 {
  {
   std::unique_ptr<Stream> tfp(vfs->open(path, VirtualFS::MODE_READ));
   const bool is_gzip_ext = vfs->test_ext(path, ".gz");
   const bool is_zst_ext = vfs->test_ext(path, ".zst");

   if(is_gzip_ext || is_zst_ext)
   {
    const std::string cts = MDFN_sprintf(_("opened file %s"), vfs->get_human_path(path).c_str());
    const uint64 tfp_size = tfp->size();

    if(is_gzip_ext) // gzip
     str.reset(new ZLInflateFilter(std::move(tfp), cts, ZLInflateFilter::FORMAT::GZIP, tfp_size));
    else // Zstandard
     str.reset(new ZstdDecompressFilter(std::move(tfp), cts, tfp_size));

    if(monocomp_double_ext)
     *monocomp_double_ext = is_gzip_ext ? -1 : true;
   }
   else // Plain
    str = std::move(tfp);
  }
  //
  //
  //
  const uint64 str_attr = str->attributes();

  if(!(str_attr & Stream::ATTRIBUTE_SLOW_SIZE) && str->size() > MaxROMImageSize)
  {
   const char* hint = "";

   if(vfs->test_ext(path, ".bin") || vfs->test_ext(path, ".iso") || vfs->test_ext(path, ".img"))
    hint = _("  If you are trying to load a CD image, load it via CUE/CCD/TOC/M3U instead of BIN/ISO/IMG.");

   throw MDFN_Error(0, _("Error loading %s: maximum allowed size of %llu bytes exceeded.%s"), vfs->get_human_path(path).c_str(), (unsigned long long)MaxROMImageSize, hint);
  }

  if((str_attr & (Stream::ATTRIBUTE_SEEKABLE | Stream::ATTRIBUTE_SLOW_SEEK | Stream::ATTRIBUTE_SLOW_SIZE)) != Stream::ATTRIBUTE_SEEKABLE)
  {
   //  if(zf_size > MaxROMImageSize)
   //   throw MDFN_Error(0, _("ROM image is too large; maximum size allowed is %llu bytes."), (unsigned long long)MaxROMImageSize);
   std::unique_ptr<Stream> new_str(new MemoryStream(str.release(), MaxROMImageSize));
   str = std::move(new_str);
  }
 }
 catch(...)
 {
  Close();
  throw;
 }
}

void MDFNFILE::Close(void) noexcept
{
 str.reset(nullptr);
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
