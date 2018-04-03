/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* scu_dsp_misc.cpp - SCU DSP Miscellaneous Instructions Emulation
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

namespace MDFN_IEN_SS
{
#include "scu_dsp_common.inc"

template<bool looped, unsigned op>
static NO_INLINE NO_CLONE void MiscInstr(void)
{
 DSP_InstrPre<looped>();

 //
 // END/ENDI
 //
 if(op == 2 || op == 3)
 {
  if(op & 0x1)
  {
   DSP.FlagEnd = true;
   SCU_SetInt(SCU_INT_DSP, true);
  }
  DSP.NextInstr = DSP_DecodeInstruction(0);
  DSP.State &= ~DSPS::STATE_MASK_EXECUTE;
  DSP.CycleCounter -= DSP_EndCCSubVal;	// Break out of execution loop(also remember to handle this case for manual stepping via port writes).
 }
 else if(op == 0)	// BTM
 {
  if(DSP.LOP)
  {
   DSP.LOP--;
   DSP.PC = DSP.TOP;
  }
 }
 else if(op == 1)	// LPS
 {
  DSP.NextInstr = DSP_DecodeInstruction<true>(DSP.NextInstr >> 32);
 }
}

extern void (*const DSP_MiscFuncTable[2][4])(void) =
{
 #include "scu_dsp_misctab.inc"
};

}
