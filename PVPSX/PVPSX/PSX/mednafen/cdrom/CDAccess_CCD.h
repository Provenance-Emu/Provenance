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

#include "../FileStream.h"
#include "../MemoryStream.h"
#include "CDAccess.h"

#include <vector>

class CDAccess_CCD : public CDAccess
{
 public:

 CDAccess_CCD(const char *path, bool image_memcache);
 virtual ~CDAccess_CCD();

 virtual void Read_Raw_Sector(uint8 *buf, int32 lba);

 virtual void Read_TOC(CDUtility::TOC *toc);

 virtual bool Is_Physical(void) throw();

 virtual void Eject(bool eject_status);

 private:

 void Load(const char *path, bool image_memcache);
 void Cleanup(void);

 void CheckSubQSanity(void);

 Stream* img_stream;
 Stream* sub_stream;
 size_t img_numsectors;
 CDUtility::TOC tocd;
};
