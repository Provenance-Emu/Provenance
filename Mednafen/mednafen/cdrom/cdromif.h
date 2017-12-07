/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef __MDFN_CDROM_CDROMIF_H
#define __MDFN_CDROM_CDROMIF_H

#include "CDUtility.h"
#include <mednafen/Stream.h>

#include <queue>

typedef CDUtility::TOC CD_TOC;

class CDIF
{
 public:

 CDIF();
 virtual ~CDIF();

 static const int32 LBA_Read_Minimum = -150;
 static const int32 LBA_Read_Maximum = 449849;	// 100 * 75 * 60 - 150 - 1

 inline void ReadTOC(CDUtility::TOC *read_target)
 {
  *read_target = disc_toc;
 }

 virtual void HintReadSector(int32 lba) = 0;
 virtual bool ReadRawSector(uint8 *buf, int32 lba) = 0;		// Reads 2352+96 bytes of data into buf.
 virtual bool ReadRawSectorPWOnly(uint8* pwbuf, int32 lba, bool hint_fullread) = 0;	// Reads 96 bytes(of raw subchannel PW data) into pwbuf.

 // Call for mode 1 or mode 2 form 1 only.
 bool ValidateRawSector(uint8 *buf);

 // Utility/Wrapped functions
 // Reads mode 1 and mode2 form 1 sectors(2048 bytes per sector returned)
 // Will return the type(1, 2) of the first sector read to the buffer supplied, 0 on error
 int ReadSector(uint8* buf, int32 lba, uint32 sector_count, bool suppress_uncorrectable_message = false);

 // For Mode 1, or Mode 2 Form 1.
 // No reference counting or whatever is done, so if you destroy the CDIF object before you destroy the returned Stream, things will go BOOM.
 Stream *MakeStream(int32 lba, uint32 sector_count);

 protected:
 bool UnrecoverableError;
 CDUtility::TOC disc_toc;
};

CDIF *CDIF_Open(const std::string& path, bool image_memcache);

#endif
