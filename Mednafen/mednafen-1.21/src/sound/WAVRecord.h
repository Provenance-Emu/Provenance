/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* WAVRecord.h:
**  Copyright (C) 2010-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#ifndef __MDFN_WAVRECORD_H
#define __MDFN_WAVRECORD_H

#include <mednafen/mednafen.h>
#include <mednafen/FileStream.h>

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
