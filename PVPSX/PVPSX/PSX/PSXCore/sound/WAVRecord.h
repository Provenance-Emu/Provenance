#ifndef __MDFN_WAVRECORD_H
#define __MDFN_WAVRECORD_H

#include "../mednafen.h"
#include "../FileStream.h"

class WAVRecord
{
 public:

 WAVRecord(const char *path, double SoundRate, uint32 SoundChan);

 void WriteSound(const int16 *SoundBuf, uint32 NumSoundFrames);

 void Finish();

 ~WAVRecord();

 private:

 FileStream wavfile;
 bool Finished;

 uint8 raw_headers[0x2C];
 int64 PCMBytesWritten;
 uint32 SoundRate;
 uint32 SoundChan;
};


#endif
