/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* debug.h:
**  Copyright (C) 2006-2016 Mednafen Team
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

#ifndef __PCFX_DEBUG_H
#define __PCFX_DEBUG_H

namespace MDFN_IEN_PCFX
{

#ifdef WANT_DEBUGGER

void PCFXDBG_CheckBP(int type, uint32 address, uint32 value, unsigned int len);

void PCFXDBG_SetLogFunc(void (*func)(const char *, const char *));

void PCFXDBG_DoLog(const char *type, const char *format, ...);
char *PCFXDBG_ShiftJIS_to_UTF8(const uint16 sjc);


extern bool PCFX_LoggingOn;

void PCFXDBG_Init(void) MDFN_COLD;
extern DebuggerInfoStruct PCFXDBGInfo;

#endif

}

#endif
