/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* debug.h:
**  Copyright (C) 2019 Mednafen Team
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

#ifndef __MDFN_SNES_FAUST_DEBUG_H
#define __MDFN_SNES_FAUST_DEBUG_H

namespace MDFN_IEN_SNES_FAUST
{

#ifdef SNES_DBG_ENABLE
void DBG_AddBranchTrace(uint32 to, unsigned iseq);
void DBG_Init(void);
MDFN_HIDE extern DebuggerInfoStruct DBG_DBGInfo;

MDFN_HIDE extern bool DBG_InHLRead;
#else
static INLINE void DBG_AddBranchTrace(uint32 to, unsigned iseq) { }
static INLINE void DBG_Init(void) { }

enum : bool { DBG_InHLRead = false };
#endif
}

#endif
