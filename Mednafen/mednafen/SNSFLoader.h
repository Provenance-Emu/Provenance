#ifndef __MDFN_SNSFLOADER_H
#define __MDFN_SNSFLOADER_H

#include <mednafen/PSFLoader.h>
#include <mednafen/MemoryStream.h>

class SNSFLoader : public PSFLoader
{
 public:

 SNSFLoader(Stream *fp);
 virtual ~SNSFLoader();

 static bool TestMagic(Stream* fp);

 virtual void HandleEXE(Stream* fp, bool ignore_pcsp = false) override;
 virtual void HandleReserved(Stream* fp, uint32 len) override;

 PSFTags tags;
 
 MemoryStream ROM_Data;
};


#endif
