#ifndef _FCEU_FILE_H_
#define _FCEU_FILE_H_

#define MAX_MOVIEFILENAME_LEN 80

#include "types.h"
#include "emufile.h"

#include <string>
#include <iostream>

extern bool bindSavestate;

struct FCEUFILE {
	//the stream you can use to access the data
	//std::iostream *stream;
	EMUFILE *stream;

	//the name of the file, or the logical name of the file within the archive
	std::string filename;

	//a weirdly derived value.. maybe a path to a file, or maybe a path to a file which doesnt exist but which is in an archive in the same directory
	std::string logicalPath;

	//the filename of the archive (maybe "" if it is not in an archive)
	std::string archiveFilename;

	//a the path to the filename, possibly using | to get into the archive
	std::string fullFilename;

	//the number of files that were in the archive
	int archiveCount;

	//the index of the file within the archive
	int archiveIndex;

	//the size of the file
	int size;

	//whether the file is contained in an archive
	bool isArchive() { return archiveCount > 0; }

	FCEUFILE()
		: stream(0)
		, archiveCount(-1)
	{}

	~FCEUFILE()
	{
		if(stream) delete stream;
	}

	enum {
		READ, WRITE, READWRITE
	} mode;

	//guarantees that the file contains a memorystream, and returns it for your convenience
	EMUFILE_MEMORY* EnsureMemorystream() {

		EMUFILE_MEMORY* ret = dynamic_cast<EMUFILE_MEMORY*>(stream);
		if(ret) return ret;

		//nope, we need to create it: copy the contents
		ret = new EMUFILE_MEMORY(size);
		stream->fread(ret->buf(),size);
		delete stream;
		stream = ret;
		return ret;
	}

	void SetStream(EMUFILE *newstream) {
		if(stream) delete stream;
		stream = newstream;
		//get the size of the stream
		stream->fseek(0,SEEK_SET);
		size = stream->size();
	}
};

struct FCEUARCHIVEFILEINFO_ITEM {
	std::string name;
	uint32 size, index;
};

class FCEUARCHIVEFILEINFO : public std::vector<FCEUARCHIVEFILEINFO_ITEM> {
public:
	void FilterByExtension(const char** ext);
};

struct FileBaseInfo {
	std::string filebase, filebasedirectory, ext;
	FileBaseInfo() {}
	FileBaseInfo(std::string fbd, std::string fb, std::string ex)
	{
		filebasedirectory = fbd;
		filebase = fb;
		ext = ex;
	}

};

struct ArchiveScanRecord
{
	ArchiveScanRecord()
		: type(-1)
		, numFilesInArchive(0)
	{}
	ArchiveScanRecord(int _type, int _numFiles)
	{
		type = _type;
		numFilesInArchive = _numFiles;
	}
	int type;

	//be careful: this is the number of files in the archive.
	//the size of the files variable might be different.
	int numFilesInArchive;

	FCEUARCHIVEFILEINFO files;

	bool isArchive() { return type != -1; }
};


FCEUFILE *FCEU_fopen(const char *path, const char *ipsfn, char *mode, char *ext, int index=-1, const char** extensions = 0);
bool FCEU_isFileInArchive(const char *path);
int FCEU_fclose(FCEUFILE*);
uint64 FCEU_fread(void *ptr, size_t size, size_t nmemb, FCEUFILE*);
uint64 FCEU_fwrite(void *ptr, size_t size, size_t nmemb, FCEUFILE*);
int FCEU_fseek(FCEUFILE*, long offset, int whence);
uint64 FCEU_ftell(FCEUFILE*);
int FCEU_read32le(uint32 *Bufo, FCEUFILE*);
int FCEU_read16le(uint16 *Bufo, FCEUFILE*);
int FCEU_fgetc(FCEUFILE*);
uint64 FCEU_fgetsize(FCEUFILE*);
int FCEU_fisarchive(FCEUFILE*);



void GetFileBase(const char *f);
std::string FCEU_GetPath(int type);
std::string FCEU_MakePath(int type, const char* filebase);
std::string FCEU_MakeFName(int type, int id1, const char *cd1);
std::string GetMfn();
void FCEU_SplitArchiveFilename(std::string src, std::string& archive, std::string& file, std::string& fileToOpen);

#define FCEUMKF_STATE        1
#define FCEUMKF_SNAP         2
#define FCEUMKF_SAV          3
#define FCEUMKF_CHEAT        4
#define FCEUMKF_FDSROM       5
#define FCEUMKF_PALETTE      6
#define FCEUMKF_GGROM        7
#define FCEUMKF_IPS          8
#define FCEUMKF_FDS          9
#define FCEUMKF_MOVIE        10
//#define FCEUMKF_NPTEMP       11 //mbg 6/21/08 - who needs this..?
#define FCEUMKF_MOVIEGLOB    12
#define FCEUMKF_STATEGLOB    13
#define FCEUMKF_MOVIEGLOB2   14
#define FCEUMKF_AUTOSTATE	 15
#define FCEUMKF_MEMW         16
#define FCEUMKF_BBOT         17
#define FCEUMKF_ROMS         18
#define FCEUMKF_INPUT        19
#define FCEUMKF_LUA          20
#define FCEUMKF_AVI			 21
#define FCEUMKF_TASEDITOR    22
#define FCEUMKF_RESUMESTATE  23
#endif
