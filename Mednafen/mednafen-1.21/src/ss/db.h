/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* db.h:
**  Copyright (C) 2016-2017 Mednafen Team
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
 CPUCACHE_EMUMODE_DATA_CB,
 CPUCACHE_EMUMODE_DATA,
 CPUCACHE_EMUMODE_FULL
};

void DB_Lookup(const char* path, const char* sgid, const uint8* fd_id, unsigned* const region, int* const cart_type, unsigned* const cpucache_emumode);
}

#endif

