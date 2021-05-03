/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDInterface.h:
**  Copyright (C) 2018 Mednafen Team
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

#ifndef __MDFN_CDROM_CDINTERFACE_H
#define __MDFN_CDROM_CDINTERFACE_H

#include <mednafen/types.h>
#include <mednafen/Stream.h>
#include <mednafen/cdrom/CDUtility.h>

namespace Mednafen
{

class CDInterface
{
 public:

 //
 // Creates a multi-threaded or single-threaded CD interface object, depending
 // on the value of "image_memcache", to read the CD image at "path".
 //
 static CDInterface* Open(VirtualFS* vfs, const std::string& path, bool image_memcache, const uint64 affinity);

 CDInterface();
 virtual ~CDInterface();

 //
 // LBA range limits for sector reading functions; MSF 00:00:00 to 99:59:74 
 //
 enum : int32 { LBA_Read_Minimum = -150 };
 enum : int32 { LBA_Read_Maximum = 449849 };

 //
 // Hint that the sector's data will be needed soon(ish); intended to be
 // called at the start of an emulated seek sequence.
 //
 virtual void HintReadSector(int32 lba) = 0;

 //
 // Reads 2352+96 bytes of data into buf.  The data for "data" sectors is 
 // currently returned descrambled(TODO: probably want to change that someday).
 //
 // May block for a while, especially for non-sequential reads, though if an
 // appropriate call was made to HintReadSector() early enough, it shouldn't
 // be too bad.
 //
 virtual bool ReadRawSector(uint8* buf, int32 lba) = 0;

 //
 // Reads 96 bytes of raw subchannel PW data into pwbuf.  Will be relatively
 // fast and nonblocking, unless the underlying CD (image) access method does
 // not permit it.
 //
 // Intended to be used for seek emulation, but can be used for other purposes
 // as appropriate.
 //
 virtual bool ReadRawSectorPWOnly(uint8* pwbuf, int32 lba, bool hint_fullread) = 0;

 // For experimental and special use cases.
 virtual bool NonDeterministic_CheckSectorReady(int32 lba);

 INLINE void ReadTOC(CDUtility::TOC* read_target)
 {
  *read_target = disc_toc;
 }

 //
 // Reads 2048 bytes per mode 1 and mode 2 form 1 sectors.
 //
 // Returns the mode(1 or 2) of the first sector read starting
 // from the LBA specified, 0 on error(or when sector_count == 0).
 //
 // Calls ReadRawSector() internally.
 //
 uint8 ReadSectors(uint8* buf, int32 lba, uint32 sector_count);

 //
 // 'Stream' wrapper for mode 1 and mode 2 form 1 sectors.
 //
 // Specify the start LBA and the number of sectors from that position
 // to be accessible by the Stream object.
 //
 // No reference counting is done, so be sure to delete the returned
 // Stream object BEFORE destroying the underlying CDInterface object.
 //
 Stream* MakeStream(int32 lba, uint32 sector_count);

 protected:
 bool UnrecoverableError;
 CDUtility::TOC disc_toc;
};

}
#endif
