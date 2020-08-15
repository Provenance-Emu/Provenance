#ifndef _ARCHIVE_H_
#define _ARCHIVE_H_

#include <string>

#include "types.h"
//#include "git.h"
#include "file.h"

void initArchiveSystem();

//if you want to autopilot this, pass in an innerfilename to try and automatically load
FCEUFILE* FCEUD_OpenArchive(ArchiveScanRecord& asr, std::string& fname, std::string* innerFilename);

FCEUFILE* FCEUD_OpenArchiveIndex(ArchiveScanRecord& asr, std::string& fname, int innerIndex);

//scans a file to see if it is an archive you can handle
ArchiveScanRecord FCEUD_ScanArchive(std::string fname);

#endif
