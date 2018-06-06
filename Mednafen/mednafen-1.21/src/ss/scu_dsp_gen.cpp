/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* scu_dsp_gen.cpp - SCU DSP General Instructions Emulation
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

#include "ss.h"
#include "scu.h"

#pragma GCC optimize("Os")
  // Is first DSP instruction cached on PC load, or when execution starts?

  // MOV [s],[d] s=0x8 = 0xFFFFFFFF?

  // MOV [s],[d] when moving from/to the same data RAM bank seems to be treated like a NOP...

namespace MDFN_IEN_SS
{
#include "scu_dsp_common.inc"

static INLINE void SetC(bool value)
{
 DSP.FlagC = value;
}

static INLINE void CalcZS32(uint32 val)
{
 DSP.FlagS = (int32)val < 0;
 DSP.FlagZ = !val;
}

static INLINE void CalcZS48(uint64 val)
{
 val <<= 16;

 DSP.FlagS = (int64)val < 0;
 DSP.FlagZ = !val;
}


template<const bool looped, const unsigned alu_op, const unsigned x_op, const unsigned y_op, const unsigned d1_op>
static NO_INLINE NO_CLONE void GeneralInstr(void)
{
 const uint32 instr = DSP_InstrPre<looped>();
 //
 DSPR48 ALU = DSP.AC;
 unsigned dr_read = 0;
 unsigned ct_inc = 0;

 switch(alu_op)
 {
  //
  // NOP
  //
  default:
  {

  }
  break;

  //
  // AND
  //
  case 0x01:
  {
   ALU.L &= DSP.P.L;
   SetC(false);
   CalcZS32(ALU.L);
  }
  break;

  //
  // OR
  //
  case 0x02:
  {
   ALU.L |= DSP.P.L;
   SetC(false);
   CalcZS32(ALU.L);
  }
  break;

  //
  // XOR
  //
  case 0x03:
  {
   ALU.L ^= DSP.P.L;
   SetC(false);
   CalcZS32(ALU.L);
  }
  break;

  //
  // ADD
  //
  case 0x04:
  {
   const uint64 tmp = (uint64)ALU.L + DSP.P.L;

   DSP.FlagV |= (((~(ALU.L ^ DSP.P.L)) & (ALU.L ^ tmp)) >> 31) & 1;
   SetC((tmp >> 32) & 0x1);
   CalcZS32(tmp);
   ALU.L = tmp;
  }
  break;

  //
  // SUB
  //
  case 0x05:
  {
   const uint64 tmp = (uint64)ALU.L - DSP.P.L;

   DSP.FlagV |= ((((ALU.L ^ DSP.P.L)) & (ALU.L ^ tmp)) >> 31) & 1;
   SetC((tmp >> 32) & 0x1);
   CalcZS32(tmp);
   ALU.L = tmp;
  }
  break;

  //
  // AD2
  //
  case 0x06:
  {
   const uint64 tmp = (ALU.T & 0xFFFFFFFFFFFFULL) + (DSP.P.T & 0xFFFFFFFFFFFFULL);

   DSP.FlagV |= (((~(ALU.T ^ DSP.P.T)) & (ALU.T ^ tmp)) >> 47) & 1;
   SetC((tmp >> 48) & 0x1);
   CalcZS48(tmp);
   ALU.T = tmp;
  }
  break;

  //
  // SR
  //
  case 0x08:
  {
   const bool new_C = ALU.L & 0x1;

   SetC(new_C);
   ALU.L = (int32)ALU.L >> 1;
   CalcZS32(ALU.L);
  }
  break;

  //
  // RR
  //
  case 0x09:
  {
   const bool new_C = ALU.L & 0x1;

   SetC(new_C);
   ALU.L = (ALU.L >> 1) | (new_C << 31);
   CalcZS32(ALU.L);
  }
  break;

  //
  // SL
  //
  case 0x0A:
  {
   const bool new_C = ALU.L >> 31;

   SetC(new_C);
   ALU.L <<= 1;
   CalcZS32(ALU.L);
  }
  break;

  //
  // RL
  //
  case 0x0B:
  {
   const bool new_C = ALU.L >> 31;

   SetC(new_C);
   ALU.L = (ALU.L << 1) | new_C;
   CalcZS32(ALU.L);
  }
  break;

  //
  // RL8
  //
  case 0x0F:
  {
   const bool new_C = (ALU.L >> 24) & 1;

   SetC(new_C);
   ALU.L = (ALU.L << 8) | (ALU.L >> 24);
   CalcZS32(ALU.L);
  }
  break;
 }

 //
 // X Op
 //
 if((x_op & 0x3) == 0x2)
  DSP.P.T = (int64)(int32)DSP.RX * (int32)DSP.RY;

 if(x_op >= 0x3)
 {
  const unsigned s = (instr >> 20) & 0x7;
  const size_t drw = s & 0x3;
  uint32 src_data;

  src_data = DSP.DataRAM[drw][DSP.CT[drw]];
  dr_read |= 1U << drw;
  ct_inc |= (bool)(s & 0x4) << (drw << 3);

  if((x_op & 0x3) == 0x3)
   DSP.P.T = (int32)src_data;

  if(x_op & 0x4)
   DSP.RX = src_data;
 }

 //
 // Y Op
 //
 if((y_op & 0x3) == 0x1)
  DSP.AC.T = 0;
 else if((y_op & 0x3) == 0x2)
  DSP.AC.T = ALU.T;

 if(y_op >= 0x3)
 {
  const unsigned s = (instr >> 14) & 0x7;
  const size_t drw = s & 0x3;
  uint32 src_data;

  src_data = DSP.DataRAM[drw][DSP.CT[drw]];
  dr_read |= 1U << drw;
  ct_inc |= (bool)(s & 0x4) << (drw << 3);

  if((y_op & 0x3) == 0x3)
   DSP.AC.T = (int32)src_data;

  if(y_op & 0x4)
   DSP.RY = src_data;
 }

 //
 // D1 Op (TODO: Test illegal bit patterns)
 //
 if(d1_op & 0x1)
 {
  const unsigned d = (instr >> 8) & 0xF;
  uint32 src_data = (int8)instr;

  if(d1_op & 0x2)
  {
   switch(instr & 0xF)
   {
    case 0x8:
    case 0xB:
    case 0xC:
    case 0xD:
    case 0xE:
    case 0xF: src_data = 0xFFFFFFFF; break;

    case 0x0: src_data = DSP.DataRAM[0][DSP.CT[0]]; dr_read |= 0x01; break;
    case 0x1: src_data = DSP.DataRAM[1][DSP.CT[1]]; dr_read |= 0x02; break;
    case 0x2: src_data = DSP.DataRAM[2][DSP.CT[2]]; dr_read |= 0x04; break;
    case 0x3: src_data = DSP.DataRAM[3][DSP.CT[3]]; dr_read |= 0x08; break;

    case 0x4: src_data = DSP.DataRAM[0][DSP.CT[0]]; if(d != 0) { ct_inc |= 1 <<  0; } dr_read |= 0x01; break;
    case 0x5: src_data = DSP.DataRAM[1][DSP.CT[1]]; if(d != 1) { ct_inc |= 1 <<  8; } dr_read |= 0x02; break;
    case 0x6: src_data = DSP.DataRAM[2][DSP.CT[2]]; if(d != 2) { ct_inc |= 1 << 16; } dr_read |= 0x04; break;
    case 0x7: src_data = DSP.DataRAM[3][DSP.CT[3]]; if(d != 3) { ct_inc |= 1 << 24; } dr_read |= 0x08; break;

    case 0x9: src_data = ALU.T; break;
    case 0xA: src_data = ALU.T >> 16; break;
   }
  }

  switch(d)
  {
   case 0x0: if(!(dr_read & 0x01)) { DSP.DataRAM[0][DSP.CT[0]] = src_data; ct_inc |= 1 <<  0; } break;
   case 0x1: if(!(dr_read & 0x02)) { DSP.DataRAM[1][DSP.CT[1]] = src_data; ct_inc |= 1 <<  8; } break;
   case 0x2: if(!(dr_read & 0x04)) { DSP.DataRAM[2][DSP.CT[2]] = src_data; ct_inc |= 1 << 16; } break;
   case 0x3: if(!(dr_read & 0x08)) { DSP.DataRAM[3][DSP.CT[3]] = src_data; ct_inc |= 1 << 24; } break;
   case 0x4: DSP.RX = src_data; break;
   case 0x5: DSP.P.T = (int32)src_data; break;
   case 0x6: DSP.RAO = src_data; break;
   case 0x7: DSP.WAO = src_data; break;
   case 0x8:
   case 0x9: break;
   case 0xA: DSP.LOP = src_data & 0x0FFF; break;
   case 0xB: DSP.TOP = src_data & 0xFF; break;

   //
   // Don't bother masking with 0x3F here, since the & 0x3F3F3F3F mask down below will cover it(and no chance of overflowing into an adjacent byte
   // since we're masking out the corresponding byte in ct_inc, too).
   //
   case 0xC: DSP.CT[0] = src_data; ct_inc &= ~0x000000FF; break;
   case 0xD: DSP.CT[1] = src_data; ct_inc &= ~0x0000FF00; break;
   case 0xE: DSP.CT[2] = src_data; ct_inc &= ~0x00FF0000; break;
   case 0xF: DSP.CT[3] = src_data; ct_inc &= ~0xFF000000; break;
  }
 }

 //
 //
 //
 #ifdef MSB_FIRST
 ct_inc = MDFN_bswap32(ct_inc);
 #endif

 if(x_op >= 0x3 || y_op >= 0x3 || (d1_op & 0x1))
  DSP.CT32 = (DSP.CT32 + ct_inc) & 0x3F3F3F3F;
}

extern void (*const DSP_GenFuncTable[2][16][8][8][4])(void) =
{
 #include "scu_dsp_gentab.inc"
};

}
