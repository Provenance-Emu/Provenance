/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* PSFLoader.h:
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

#ifndef __MDFN_PSFLOADER_H
#define __MDFN_PSFLOADER_H

#include <mednafen/Stream.h>

#include <map>

class PSFTags
{
 public:

 PSFTags();
 ~PSFTags();

 int64 GetTagI(const char *name);
 std::string GetTag(const char *name);
 bool TagExists(const char *name);

 void LoadTags(Stream* fp);
 void EraseTag(const char *name);


 private:

 void AddTag(char *tag_line);
 std::map<std::string, std::string> tags;
};

class PSFLoader
{
 public:
 PSFLoader();
 virtual ~PSFLoader();

 static bool TestMagic(uint8 version, Stream *fp);

 PSFTags Load(uint8 version, uint32 max_exe_size, Stream *fp);

 virtual void HandleReserved(Stream* fp, uint32 len);
 virtual void HandleEXE(Stream* fp, bool ignore_pcsp = false);

 private:

 PSFTags LoadInternal(uint8 version, uint32 max_exe_size, Stream *fp, uint32 level, bool force_ignore_pcsp = false);
};


#endif
