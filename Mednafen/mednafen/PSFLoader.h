#ifndef __MDFN_PSFLOADER_H
#define __MDFN_PSFLOADER_H

#include <mednafen/Stream.h>

#include <map>
#include <string.h>
#include <vector>
#include <string>

class PSFTags
{
 public:

 PSFTags();
 ~PSFTags();

 int64 GetTagI(const char *name);
 std::string GetTag(const char *name);
 bool TagExists(const char *name);

 void LoadTags(Stream* fp);
 void EraseTag(const char *name);


 private:

 void AddTag(char *tag_line);
 std::map<std::string, std::string> tags;
};

class PSFLoader
{
 public:
 PSFLoader();
 virtual ~PSFLoader();

 static bool TestMagic(uint8 version, Stream *fp);

 PSFTags Load(uint8 version, uint32 max_exe_size, Stream *fp);

 virtual void HandleReserved(Stream* fp, uint32 len);
 virtual void HandleEXE(Stream* fp, bool ignore_pcsp = false);

 private:

 PSFTags LoadInternal(uint8 version, uint32 max_exe_size, Stream *fp, uint32 level, bool force_ignore_pcsp = false);
};


#endif
