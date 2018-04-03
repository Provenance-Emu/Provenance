/******************************************************************************/
/* Mednafen Virtual Boy Emulation Module                                      */
/******************************************************************************/
/* debug.h:
**  Copyright (C) 2010-2016 Mednafen Team
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

#ifndef __VB_DEBUG_H
#define __VB_DEBUG_H

namespace MDFN_IEN_VB
{

void VBDBG_FlushBreakPoints(int type);
void VBDBG_AddBreakPoint(int type, unsigned int A1, unsigned int A2, bool logical);
void VBDBG_Disassemble(uint32 &a, uint32 SpecialA, char *);

uint32 VBDBG_MemPeek(uint32 A, unsigned int bsize, bool hl, bool logical);

void VBDBG_SetCPUCallback(void (*callb)(uint32 PC, bool bpoint), bool continuous);

void VBDBG_EnableBranchTrace(bool enable);
std::vector<BranchTraceResult> VBDBG_GetBranchTrace(void);

void VBDBG_CheckBP(int type, uint32 address, uint32 value, unsigned int len);

void VBDBG_SetLogFunc(void (*func)(const char *, const char *));

void VBDBG_DoLog(const char *type, const char *format, ...);


extern bool VB_LoggingOn;

bool VBDBG_Init(void) MDFN_COLD;

};

#endif
