/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* dsp2.cpp:
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
#include "dsp2.h"

namespace MDFN_IEN_SNES_FAUST
{

#include "dsp2chip.h"
static DSP2Chip DSP;

static uint32 last_master_timestamp;
static unsigned run_count_mod;
static unsigned clock_multiplier;

static NO_INLINE void Update(uint32 master_timestamp)
{
 int32 tmp;

 tmp = ((master_timestamp - last_master_timestamp) * clock_multiplier) + run_count_mod;
 last_master_timestamp = master_timestamp;
 run_count_mod  = (uint16)tmp;

 DSP.Run(tmp >> 16);
}

template<signed cyc>
static DEFREAD(MainCPU_ReadDR)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  CPUM.timestamp += (cyc >= 0) ? cyc : CPUM.MemSelectCycles;
 }
 //
 //
 Update(CPUM.timestamp);

 return DSP.ReadData();
}

template<signed cyc>
static DEFWRITE(MainCPU_WriteDR)
{
 CPUM.timestamp += (cyc >= 0) ? cyc : CPUM.MemSelectCycles;
 //
 //
 Update(CPUM.timestamp);

 DSP.WriteData(V);
}

template<signed cyc>
static DEFREAD(MainCPU_ReadSR)
{
 if(MDFN_LIKELY(!DBG_InHLRead))
 {
  CPUM.timestamp += (cyc >= 0) ? cyc : CPUM.MemSelectCycles;
 }
 //
 //
 //
 Update(CPUM.timestamp);

 return DSP.ReadStatus();
}

static void AdjustTS(int32 delta)
{


}

static uint32 EventHandler(uint32 timestamp)
{
 //DSP.
 return timestamp + 10000;
}

static MDFN_COLD void Reset(bool powering_up)
{
 DSP.Reset(powering_up);

 if(powering_up)
  run_count_mod = 0;
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(run_count_mod),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "DSP2");

 DSP.StateAction(sm, load, data_only);
}

void CART_DSP2_Init(const int32 master_clock)
{
 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(bank >= 0x20 && bank <= 0x3F)
  {
   Set_A_Handlers((bank << 16) | 0x8000, (bank << 16) | 0xBFFF, MainCPU_ReadDR<MEMCYC_SLOW>, MainCPU_WriteDR<MEMCYC_SLOW>);
   Set_A_Handlers((bank << 16) | 0xC000, (bank << 16) | 0xFFFF, MainCPU_ReadSR<MEMCYC_SLOW>, OBWrite_SLOW);
  }
 }
 //
 //
 //
 last_master_timestamp = 0;
 clock_multiplier = ((int64)65536 * 20000000 * 2 + master_clock) / (master_clock * 2);
 //
 //
 //
 Cart.AdjustTS = AdjustTS;
 Cart.EventHandler = EventHandler;
 Cart.Reset = Reset;
 Cart.StateAction = StateAction;
}

}
