#ifndef __MDFN_FILE_H
#define __MDFN_FILE_H

#include <string>

class Stream;

#define MDFNFILE_EC_NOTFOUND	1
#define MDFNFILE_EC_OTHER	2

class MDFNFILE
{
	public:

	MDFNFILE(const char *path, const FileExtensionSpecStruct *known_ext, const char *purpose = NULL);
	~MDFNFILE();

        void ApplyIPS(Stream *);
	void Close(void) throw();

	const int64 &size;
	const uint8 * const &data;
        const char * const &ext;
        const char * const &fbase;

	inline int64 Size(void)
	{
	 return(f_size);
	}

	inline const uint8 *Data(void)
	{
	 return(f_data);
	}
	
	uint64 fread(void *ptr, size_t size, size_t nmemb);
	int fseek(int64 offset, int whence);

	inline uint64 ftell(void)
	{
	 return(location);
	}

	inline void rewind(void)
	{
	 location = 0;
	}

	int read32le(uint32 *Bufo);
	int read16le(uint16 *Bufo);

	inline int fgetc(void)
	{
	 if(location < f_size)
	  return f_data[location++];

	 return EOF;
	}

	inline int fisarchive(void)
	{
	 return(0);
	}

	char *fgets(char *s, int size);

	private:

        uint8 *f_data;
        int64 f_size;
        char *f_ext;
	char *f_fbase;

        int64 location;

	#ifdef HAVE_MMAP
	bool is_mmap;
	#endif

	void Open(const char *path, const FileExtensionSpecStruct *known_ext, const char *purpose = NULL);
	void MakeMemWrap(void *tz, int type);
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

#include <vector>

// These functions should be used for data like save states and non-volatile backup memory.
// Until(if, even) we add LoadFromFile functions, for reading the files these functions generate, just use gzopen(), gzread(), etc.
// "compress" is set to the zlib compression level.  0 disables compression entirely, and dumps the file without a gzip header or footer.
// (Note: There is a setting that will force compress to 0 in the internal DumpToFile logic, for hackers who don't want to ungzip save files.)

bool MDFN_DumpToFile(const char *filename, int compress, const void *data, const uint64 length);
bool MDFN_DumpToFile(const char *filename, int compress, const std::vector<PtrLengthPair> &pearpairs);

#endif
