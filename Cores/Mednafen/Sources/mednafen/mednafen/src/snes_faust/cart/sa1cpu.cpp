/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* sa1.cpp:
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

#include "common.h"
#include "sa1.h"
#include "sa1cpu.h"

namespace MDFN_IEN_SNES_FAUST
{
namespace SA1CPU
{
//
//
#ifdef SNES_DBG_ENABLE
static INLINE void DBG_CPUHook(uint32 PCPBR, uint8 P)
{

}
#endif

#include "../Core65816.h"

template<typename T>
INLINE void Core65816::MemWrite(uint32 addr, T val)
{
 cpum->CPU_Write(addr, val);

 if(sizeof(T) == 2)
 {
  addr++;
  cpum->CPU_Write(addr, val >> 8);
 }
}

template<typename T>
INLINE T Core65816::MemRead(uint32 addr)
{
 T ret;

 ret = cpum->CPU_Read(addr);

 if(sizeof(T) == 2)
 {
  addr++;
  ret |= cpum->CPU_Read(addr) << 8;
 }

 return ret;
}

INLINE uint16 Core65816::VecRead(uint32 addr)
{
 uint16 ret;

 cpum->VectorPull = true;
 ret = MemRead<uint16>(addr);
 cpum->VectorPull = false;

 return ret;
}

INLINE uint8 Core65816::OpRead(uint32 addr)
{
 uint8 ret = MemRead<uint8>(addr);

 return ret;
}

static Core65816 core;
#include "../cpu_hlif.inc"
}
}
