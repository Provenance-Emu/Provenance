#ifndef __MDFN_FILE_H
#define __MDFN_FILE_H

#include <mednafen/Stream.h>
#include <mednafen/endian.h>

#include <vector>
#include <string>

class MDFNFILE
{
	public:

	MDFNFILE(const char *path, const FileExtensionSpecStruct *known_ext, const char *purpose = NULL);
	~MDFNFILE();

        void ApplyIPS(Stream *);
	void Close(void) throw();

        const char * const &ext;
        const char * const &fbase;

	inline uint64 size(void)
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

	private:

        char *f_ext;
	char *f_fbase;

	std::unique_ptr<Stream> str;

	void Open(const char *path, const FileExtensionSpecStruct *known_ext, const char *purpose = NULL);
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

//
// Helper function to open a file in read mode, so we can stop gzip-compressing our save-game files and not have to worry so much about games
// that might write the gzip magic to the beginning of the save game memory area causing a problem.
//
std::unique_ptr<Stream> MDFN_AmbigGZOpenHelper(const std::string& path, std::vector<size_t> good_sizes);

void MDFN_mkdir_T(const char* path);


#endif
