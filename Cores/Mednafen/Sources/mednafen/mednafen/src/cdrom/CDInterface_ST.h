/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDInterface_ST.h - Single-threaded CD Reading Interface
**  Copyright (C) 2012-2018 Mednafen Team
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

#ifndef __MDFN_CDROM_CDINTERFACE_ST_H
#define __MDFN_CDROM_CDINTERFACE_ST_H

#include <mednafen/cdrom/CDInterface.h>
#include <mednafen/cdrom/CDAccess.h>

namespace Mednafen
{

// TODO: prohibit copy constructor
class CDInterface_ST : public CDInterface
{
 public:

 CDInterface_ST(std::unique_ptr<CDAccess> cda);
 virtual ~CDInterface_ST();

 virtual void HintReadSector(int32 lba) override;
 virtual bool ReadRawSector(uint8* buf, int32 lba) override;
 virtual bool ReadRawSectorPWOnly(uint8* pwbuf, int32 lba, bool hint_fullread) override;

 private:
 std::unique_ptr<CDAccess> disc_cdaccess;
};

}
#endif
