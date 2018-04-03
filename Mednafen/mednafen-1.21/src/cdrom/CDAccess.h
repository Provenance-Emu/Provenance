/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDAccess.h:
**  Copyright (C) 2011-2017 Mednafen Team
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

#ifndef __MDFN_CDROM_CDACCESS_H
#define __MDFN_CDROM_CDACCESS_H

#include "CDUtility.h"

class CDAccess
{
 public:

 CDAccess();
 virtual ~CDAccess();

 virtual void Read_Raw_Sector(uint8 *buf, int32 lba) = 0;

 // Returns false if the read wouldn't be "fast"(i.e. reading from a disk),
 // or if the read can't be done in a thread-safe re-entrant manner.
 //
 // Writes 96 bytes into pwbuf, and returns 'true' otherwise.
 virtual bool Fast_Read_Raw_PW_TSRE(uint8* pwbuf, int32 lba) const noexcept = 0;

 virtual void Read_TOC(CDUtility::TOC *toc) = 0;

 private:
 CDAccess(const CDAccess&);	// No copy constructor.
 CDAccess& operator=(const CDAccess&); // No assignment operator.
};

CDAccess* CDAccess_Open(const std::string& path, bool image_memcache);

#endif
