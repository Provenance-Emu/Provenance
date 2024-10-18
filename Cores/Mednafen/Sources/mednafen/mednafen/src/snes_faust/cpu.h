/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* cpu.h:
**  Copyright (C) 2015-2016 Mednafen Team
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

#ifndef __MDFN_SNES_FAUST_CPU_H
#define __MDFN_SNES_FAUST_CPU_H

namespace MDFN_IEN_SNES_FAUST
{

class CPU65816;

typedef uint8 (MDFN_FASTCALL *readfunc)(uint32 A);
typedef void (MDFN_FASTCALL *writefunc)(uint32 A, uint8 V);

struct CPU_Misc
{
 uint32 timestamp;
 uint32 next_event_ts;
 uint32 running_mask;

 uint32 PIN_Delay;

 enum
 {
  HALTED_NOT = 0,
  HALTED_WAI = 1 << 0,
  HALTED_STP = 1 << 1,
  HALTED_DMA = 1 << 2
 };

 uint8 halted;
 uint8 mdr;

 uint8 CombinedNIState;
 bool NMILineState;
 bool PrevNMILineState;
 uint8 MultiIRQState;

 uint8 MemSelectCycles;

 uint8 InDMABusAccess;

 readfunc ReadFuncs[256];	// A and B bus read handlers
 writefunc WriteFuncs[256];	// A and B bus write handlers

 readfunc ReadFuncsA[256];	// A-bus only read handlers
 writefunc WriteFuncsA[256];	// A-bus only write handlers

 // Direct, not through RWIndex.
 readfunc DM_ReadFuncsB[256];
 writefunc DM_WriteFuncsB[256];

 // +1 so we can avoid a masking for 16-bit reads/writes(note that this
 // may result in the address passed to the read/write handlers being
 // 0x1000000 instead of 0x000000 in some cases, so code with that in mind.
 uint8 RWIndex[256 * 65536 + 1];

 INLINE uint8 ReadA(uint32 A)
 {
  uint8 ret = ReadFuncsA[RWIndex[A]](A);

  mdr = ret;

  return ret;
 }

 INLINE void WriteA(uint32 A, uint8 V)
 {
  mdr = V;
  WriteFuncsA[RWIndex[A]](A, V);
 }

 INLINE uint8 ReadB(uint8 A)
 {
  uint8 ret = DM_ReadFuncsB[A](A);

  mdr = ret;

  return ret;
 }

 INLINE void WriteB(uint8 A, uint8 V)
 {
  mdr = V;
  DM_WriteFuncsB[A](A, V);
 }

 //
 //
 //
 void RunDMA(void) MDFN_HOT;
 void EventHandler(void) MDFN_HOT;
 //
 //
 INLINE uint8 CPU_Read(uint32 A)
 {
  uint8 ret = ReadFuncs[RWIndex[A]](A);

  mdr = ret;

  return ret;
 }

 INLINE void CPU_Write(uint32 A, uint8 V)
 {
  mdr = V;
  WriteFuncs[RWIndex[A]](A, V);
 }

 INLINE void CPU_IO(void)
 {
  timestamp += 6;
 }
};

MDFN_HIDE extern CPU_Misc CPUM;

enum
{
 CPU_IRQSOURCE_PPU = 0,
 CPU_IRQSOURCE_CART
};

INLINE void CPU_SetIRQ(bool active, unsigned w = CPU_IRQSOURCE_PPU)
{
 CPUM.MultiIRQState &= ~(1 << w);
 CPUM.MultiIRQState |= active << w;
 CPUM.CombinedNIState &= ~0x04;
 CPUM.CombinedNIState |= CPUM.MultiIRQState ? 0x04 : 0x00;
}

INLINE void CPU_SetNMI(bool active)
{
 if((CPUM.NMILineState ^ active) & active)
  CPUM.CombinedNIState |= 0x01;

 CPUM.NMILineState = active;
}

INLINE void CPU_TriggerIRQNMIDelayKludge(void)
{
 CPUM.PIN_Delay |= 0x80;
}

void CPU_Init(CPU_Misc* cpum) MDFN_COLD;
void CPU_Reset(bool powering_up) MDFN_COLD;
void CPU_StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname, const char* sname_core);
void CPU_Run(void) MDFN_HOT;

INLINE void CPU_Exit(void)
{
 CPUM.running_mask = 0;
 CPUM.next_event_ts = 0;
}
//
//
//
/*
enum
{
 CPU_GSREG_WHATEVER = Core65816::GSREG__BOUND,
};
*/
uint32 CPU_GetRegister(const unsigned id, char* const special = nullptr, const uint32 special_len = 0) MDFN_COLD;
void CPU_SetRegister(const unsigned id, const uint32 value) MDFN_COLD;

}

#endif
