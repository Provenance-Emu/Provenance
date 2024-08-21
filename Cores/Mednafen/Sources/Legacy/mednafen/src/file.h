#ifndef __MDFN_FILE_H
#define __MDFN_FILE_H

#include <mednafen/Stream.h>

namespace Mednafen
{

class MDFNFILE
{
	public:

	MDFNFILE(VirtualFS* vfs, const char* path, const std::vector<FileExtensionSpecStruct>& known_ext, const char* purpose = nullptr);
	~MDFNFILE();

        void ApplyIPS(Stream*);
	void Close(void) throw();

        const std::string &ext;		// For file-type determination.  Leading period has been removed, and A-Z chars have been converted to a-z.
        const std::string &fbase;	// For region detection heuristics.

	INLINE uint64 size(void)
	{
	 return str->size();
	}

	INLINE void seek(int64 offset, int whence = SEEK_SET)
	{
	 str->seek(offset, whence);
	}

	INLINE uint64 read(void* ptr, uint64 count, bool error_on_eos = true)
	{
	 return str->read(ptr, count, error_on_eos);
	}

	INLINE uint64 tell(void)
	{
	 return str->tell();
	}

	INLINE void rewind(void)
	{
	 str->rewind();
	}

	INLINE Stream* stream(void)
	{
	 return str.get();
	}

	INLINE VirtualFS* active_vfs(void)
	{
	 return f_vfs;
	}

	// Path of file opened from archive, in the archive.
	INLINE std::string active_dir_path(void)
	{
	 return f_dir_path;
	}

	INLINE std::string active_path(void)
	{
	 return f_path;
	}

	INLINE std::unique_ptr<VirtualFS> steal_archive_vfs(void)
	{
	 f_vfs = nullptr;

	 return std::move(archive_vfs);
	}

	private:

	std::string f_ext;
	std::string f_fbase;

	std::unique_ptr<Stream> str;
	std::unique_ptr<VirtualFS> archive_vfs;

	VirtualFS* f_vfs;
	std::string f_dir_path;
	std::string f_path;

	void Open(VirtualFS* vfs, const char* path, const std::vector<FileExtensionSpecStruct>& known_ext, const char* purpose = nullptr);

	MDFNFILE(const MDFNFILE&);
	MDFNFILE& operator=(const MDFNFILE&);
};

class PtrLengthPair
{
 public:

 inline PtrLengthPair(const void *new_data, const uint64 new_length)
 {
  data = new_data;
  length = new_length;
 }

 ~PtrLengthPair() 
 { 

 } 

 INLINE const void *GetData(void) const
 {
  return(data);
 }

 INLINE uint64 GetLength(void) const
 {
  return(length);
 }

 private:
 const void *data;
 uint64 length;
};

// These functions should be used for data like non-volatile backup memory.
bool MDFN_DumpToFile(const std::string& path, const void *data, const uint64 length, bool throw_on_error = false);
bool MDFN_DumpToFile(const std::string& path, const std::vector<PtrLengthPair> &pearpairs, bool throw_on_error = false);

void MDFN_BackupSavFile(const uint8 max_backup_count, const char* sav_ext);

//
// Helper function to open a file in read mode, so we can stop gzip-compressing our save-game files and not have to worry so much about games
// that might write the gzip magic to the beginning of the save game memory area causing a problem.
//
std::unique_ptr<Stream> MDFN_AmbigGZOpenHelper(const std::string& path, std::vector<size_t> good_sizes);

}
#endif
