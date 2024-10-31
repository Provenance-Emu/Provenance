/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* hdd.h:
**  Copyright (C) 2023 Mednafen Team
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

namespace MDFN_IEN_APPLE2
{
namespace HDD
{

uint32 Init(unsigned slot, Stream* sp, const std::string& ext, sha256_hasher* h, const bool write_protect);
void Kill(void);

void Power(void);
void StateAction(StateMem* sm, const unsigned load, const bool data_only);

void LoadDelta(Stream* sp);
void SaveDelta(Stream* sp);

bool GetEverModified(void);

//
//
}
}
