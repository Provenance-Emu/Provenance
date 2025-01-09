/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* db.h:
**  Copyright (C) 2016-2020 Mednafen Team
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

#ifndef __MDFN_SS_DB_H
#define __MDFN_SS_DB_H

namespace MDFN_IEN_SS
{

enum
{
 CPUCACHE_EMUMODE_DATA_CB = 0,
 CPUCACHE_EMUMODE_DATA = 1,
 CPUCACHE_EMUMODE_FULL = 2,
 CPUCACHE_EMUMODE__COUNT = 3,
};

void DB_Lookup(const char* path, const char* sgid, const char* sgname, const char* sgarea, const uint8* fd_id, unsigned* const region, int* const cart_type, unsigned* const cpucache_emumode);
uint32 DB_LookupHH(const char* sgid, const uint8* fd_id);

struct STVROMLayout
{
 uint32 offset;
 uint32 size;
 unsigned map;
 const char* fname;
 uint32 head_crc32;
};

enum
{
 STV_CONTROL_3B = 0,
 STV_CONTROL_6B,
 STV_CONTROL_HAMMER,
 //
 STV_CONTROL_RSG
};

enum
{
 STV_MAP_BYTE = 0,
 STV_MAP_16LE,
 STV_MAP_16BE
};

enum
{
 STV_ROMTWIDDLE_NONE = 0,
 STV_ROMTWIDDLE_SANJEON
};

enum
{
 STV_EC_CHIP_NONE = 0,
 //
 STV_EC_CHIP_315_5881,
 STV_EC_CHIP_315_5838,
 //
 STV_EC_CHIP_RSG
};

/*
enum
{
 STV_REGION_JP = 0,
 STV_REGION_TW,
 STV_REGION_US,
 STV_REGION_EU
};
*/

struct STVGameInfo
{
 const char* name;
 unsigned area;
 unsigned control;
 unsigned ec_chip;
 unsigned romtwiddle;
 bool rotate;
 STVROMLayout rom_layout[16];
};

const STVGameInfo* DB_LookupSTV(const std::string& fname, Stream* s);

void DB_GetInternalDB(std::vector<GameDB_Database>* databases) MDFN_COLD;
std::string DB_GetHHDescriptions(const uint32 hhv) MDFN_COLD;

}

#endif

