/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* sa1cpu.h:
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

#ifndef __MDFN_SNES_FAUST_CART_SA1CPU_H
#define __MDFN_SNES_FAUST_CART_SA1CPU_H

namespace MDFN_IEN_SNES_FAUST
{
namespace SA1CPU
{
//
//
class CPU65816;

struct CPU_Misc
{
 readfunc ReadFuncs[512 + 256];
 //
 //
 //
 void RunDMA(void) MDFN_HOT;
 void EventHandler(void) MDFN_HOT;
 //
 //
 //
 uintptr_t ROMPtr[8];
 uint8 SA1VectorSpace[0x10];
 uint8 SA1VectorMask[0x10];
 uint8 MainVectors[4];

 uint8 SA1CPUControl;
 uint8 SA1CPUIRQEnable;
 uint8 SA1CPUIRQPending;

 uint8 MainCPUControl;
 uint8 MainCPUIRQEnable;
 uint8 MainCPUIRQPending;

 uint8 DMAControl;
 uint8 DMACharConvParam;
 uint32 DMASourceAddr;
 uint32 DMADestAddr;
 uint32 DMALength;
 uint32 DMAFinishTS;

 uint32 DMACharConvSourceXTile;
 uint32 DMACharConvSourceYTile;
 uint32 DMACharConvCCVBWRAMCounter;
 unsigned CharConvTileY;
 uint8 CharConvBMRegs[0x10];
 bool DMACharConvAutoActive;
 uint8 ROMBank[4];
 uint8 MainBWRAMBank;		// $2224
 uint8 SA1BWRAMBank;		// $2225
 bool BWRAMWriteEnable[2];	// [0]=$2226(main), [1]=$2227(SA1 CPU side)
 uint8 BWRAMWriteProtectSize;	// $2228
 uint8 IWRAMWriteEnable[2];	// [0]=$2229(main), [1]=$222A(SA1 CPU side)
 bool BWRAMBitmapFormat;		// $223F(SA1 CPU)

//
 uint8 MathControl;		// $2250(SA1 CPU)
 uint8 VarLenControl;		// $2258 (SA1 CPU)
 uint16 MathParam[2];		// $2251...$2254
 uint64 MathResult;

 uint32 VarLenAddr;
 uint32 VarLenCurAddr;
 uint32 VarLenCurBitOffs;
 uint32 VarLenBuffer;

 uint32 SA1CPUBoundTS;
 //
 //
 //
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
 enum { IRQNMISuppress = false };
 uint8 MemSelectCycles;
 uint8 VectorPull;

 writefunc WriteFuncs[512 + 256];

 uint8 IRAM[0x800];

 // +1 so we can avoid a masking for 16-bit reads/writes(note that this
 // may result in the address passed to the read/write handlers being
 // 0x1000000 instead of 0x000000 in some cases, so code with that in mind.
 uint16 RWIndex[0x8000 + 1];	// (2**24 / 512)

 INLINE uint8 CPU_Read(uint32 A)
 {
  const size_t i = RWIndex[A >> 9];
  uint8 ret = ReadFuncs[i ? i : (A & 0x1FF)](A);

  mdr = ret;

  return ret;
 }

 INLINE void CPU_Write(uint32 A, uint8 V)
 {
  const size_t i = RWIndex[A >> 9];
  mdr = V;
  WriteFuncs[i ? i : (A & 0x1FF)](A, V);
 }

 INLINE void CPU_IO(void)
 {
  timestamp += 2;
 }

};

void CPU_Init(CPU_Misc* cpum) MDFN_COLD;
void CPU_Reset(bool powering_up) MDFN_COLD;
void CPU_StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname, const char* sname_core);
void CPU_Run(void) MDFN_HOT;

//
//
}
}
#endif
