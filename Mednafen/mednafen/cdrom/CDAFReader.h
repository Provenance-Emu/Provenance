#ifndef __MDFN_CDAFREADER_H
#define __MDFN_CDAFREADER_H

#include <mednafen/Stream.h>

class CDAFReader
{
 public:
 CDAFReader();
 virtual ~CDAFReader();

 virtual uint64 FrameCount(void) = 0;
 INLINE uint64 Read(uint64 frame_offset, int16 *buffer, uint64 frames)
 {
  uint64 ret;

  if(LastReadPos != frame_offset)
  {
   //puts("SEEK");
   if(!Seek_(frame_offset))
    return(0);
   LastReadPos = frame_offset;
  }

  ret = Read_(buffer, frames);
  LastReadPos += ret;
  return(ret);
 }

 private:
 virtual uint64 Read_(int16 *buffer, uint64 frames) = 0;
 virtual bool Seek_(uint64 frame_offset) = 0;

 uint64 LastReadPos;
};

// AR_Open(), and CDAFReader, will NOT take "ownership" of the Stream object(IE it won't ever delete it).  Though it does assume it has exclusive access
// to it for as long as the CDAFReader object exists.
CDAFReader *CDAFR_Open(Stream *fp);

#endif
