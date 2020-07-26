/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDInterface_ST.cpp - Single-threaded CD Reading Interface
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

#include <mednafen/mednafen.h>
#include <mednafen/cdrom/CDInterface.h>
#include <mednafen/cdrom/CDAccess.h>
#include "CDInterface_ST.h"

namespace Mednafen
{

using namespace CDUtility;

CDInterface_ST::CDInterface_ST(std::unique_ptr<CDAccess> cda) : disc_cdaccess(std::move(cda))
{
 //puts("***WARNING USING SINGLE-THREADED CD READER***");

 UnrecoverableError = false;

 disc_cdaccess->Read_TOC(&disc_toc);

 if(disc_toc.first_track < 1 || disc_toc.last_track > 99 || disc_toc.first_track > disc_toc.last_track)
 {
  throw MDFN_Error(0, _("TOC first(%d)/last(%d) track numbers bad."), disc_toc.first_track, disc_toc.last_track);
 }
}

CDInterface_ST::~CDInterface_ST()
{

}

void CDInterface_ST::HintReadSector(int32 lba)
{
 // TODO: disc_cdaccess seek hint? (probably not, would require asynchronousitycamel)
}

bool CDInterface_ST::ReadRawSector(uint8 *buf, int32 lba)
{
 if(UnrecoverableError)
 {
  memset(buf, 0, 2352 + 96);
  return false;
 }

 if(lba < LBA_Read_Minimum || lba > LBA_Read_Maximum)
 {
  printf("Attempt to read sector out of bounds; LBA=%d\n", lba);
  memset(buf, 0, 2352 + 96);
  return false;
 }

 try
 {
  disc_cdaccess->Read_Raw_Sector(buf, lba);
 }
 catch(std::exception &e)
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, _("Sector %u read error: %s"), lba, e.what());
  memset(buf, 0, 2352 + 96);
  return false;
 }

 return true;
}

bool CDInterface_ST::ReadRawSectorPWOnly(uint8* pwbuf, int32 lba, bool hint_fullread)
{
 if(UnrecoverableError)
 {
  memset(pwbuf, 0, 96);
  return false;
 }

 if(lba < LBA_Read_Minimum || lba > LBA_Read_Maximum)
 {
  printf("Attempt to read sector out of bounds; LBA=%d\n", lba);
  memset(pwbuf, 0, 96);
  return false;
 }

 if(disc_cdaccess->Fast_Read_Raw_PW_TSRE(pwbuf, lba))
  return true;
 else
 {
  uint8 tmpbuf[2352 + 96];
  bool ret;

  ret = ReadRawSector(tmpbuf, lba);
  memcpy(pwbuf, tmpbuf + 2352, 96);

  return ret;
 }
}

}
