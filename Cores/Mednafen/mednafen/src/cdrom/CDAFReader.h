/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDAFReader.h:
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

#ifndef __MDFN_CDAFREADER_H
#define __MDFN_CDAFREADER_H

#include <mednafen/Stream.h>

namespace Mednafen
{

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
   {
    LastReadPos = ~(uint64)0;
    return 0;
   }
   LastReadPos = frame_offset;
  }

  ret = Read_(buffer, frames);
  LastReadPos += ret;
  return ret;
 }

 private:
 virtual uint64 Read_(int16 *buffer, uint64 frames) = 0;
 virtual bool Seek_(uint64 frame_offset) = 0;

 uint64 LastReadPos;
};

// AR_Open(), and CDAFReader, will NOT take "ownership" of the Stream object(IE it won't ever delete it).  Though it does assume it has exclusive access
// to it for as long as the CDAFReader object exists.
CDAFReader *CDAFR_Open(Stream *fp);

}
#endif
