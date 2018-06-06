/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CDAccess.cpp:
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

#include <mednafen/mednafen.h>
#include "CDAccess.h"
#include "CDAccess_Image.h"
#include "CDAccess_CCD.h"

using namespace CDUtility;

CDAccess::CDAccess()
{

}

CDAccess::~CDAccess()
{

}

CDAccess* CDAccess_Open(const std::string& path, bool image_memcache)
{
 CDAccess *ret = NULL;

 if(path.size() >= 4 && !MDFN_strazicmp(path.c_str() + path.size() - 4, ".ccd"))
  ret = new CDAccess_CCD(path, image_memcache);
 else
  ret = new CDAccess_Image(path, image_memcache);

 return ret;
}

