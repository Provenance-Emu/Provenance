/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* cpu_hlif.inc:
**  Copyright (C) 2015-2019 Mednafen Team
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

//static bool popread = false;

INLINE void Core65816::IO(void)
{
 cpum->CPU_IO();
}

INLINE void Core65816::Instr_STP(void)
{
 SNES_DBG("[CPU] STP\n");
 cpum->halted |= CPU_Misc::HALTED_STP;

 if(cpum->timestamp < cpum->next_event_ts)
  cpum->timestamp = cpum->next_event_ts;
}

INLINE void Core65816::Instr_WAI(void)
{
 SampleIRQ();	// Important(to match games' expectations).

 if(!cpum->CombinedNIState)
 {
  cpum->halted |= CPU_Misc::HALTED_WAI;

  if(cpum->timestamp < cpum->next_event_ts)
   cpum->timestamp = cpum->next_event_ts;
 }
}

INLINE void Core65816::SampleIRQ(void)
{
 cpum->PIN_Delay = ((P ^ I_FLAG) | 0x01) & cpum->CombinedNIState;
}

INLINE void Core65816::BranchOccurred(unsigned iseq)
{
#ifdef SNES_DBG_ENABLE
 DBG_AddBranchTrace(PCPBR, iseq);
#endif
}

#include "Core65816.inc"

void CPU_Run(void)
{
#ifdef HAVE_COMPUTED_GOTO
 const void* const LoopTable[4] =
 {
  &&Loop_0, &&Loop_1, &&Loop_2, &&Loop_3,
 };
 #define GOTO_MXLOOPTABLE() goto *LoopTable[(lc.P >> 4) & 0x3];
#else
 #define GOTO_MXLOOPTABLE() { switch((lc.P >> 4) & 0x3) { case 0: goto Loop_0; case 1: goto Loop_1; case 2: goto Loop_2; case 3: goto Loop_3; } }
#endif

 Core65816 lc = core;

 lc.cpum->running_mask = ~0U;
 GOTO_MXLOOPTABLE();

 #define CPULBMX Loop_0
 #define CPULBMTYPE	uint16
 #define CPULBXTYPE	uint16
 #include "cpu_loop_body.inc"
 #undef CPULBXTYPE
 #undef CPULBMTYPE
 #undef CPULBMX

 #define CPULBMX Loop_1
 #define CPULBMTYPE	uint16
 #define CPULBXTYPE	uint8
 #include "cpu_loop_body.inc"
 #undef CPULBXTYPE
 #undef CPULBMTYPE
 #undef CPULBMX

 #define CPULBMX Loop_2
 #define CPULBMTYPE	uint8
 #define CPULBXTYPE	uint16
 #include "cpu_loop_body.inc"
 #undef CPULBXTYPE
 #undef CPULBMTYPE
 #undef CPULBMX

 #define CPULBMX Loop_3
 #define CPULBMTYPE	uint8
 #define CPULBXTYPE	uint8
 #include "cpu_loop_body.inc"
 #undef CPULBXTYPE
 #undef CPULBMTYPE
 #undef CPULBMX


 ExitCat: ;
 core = lc;
}

void CPU_Reset(bool powering_up)
{
 CPU_Misc* const cpum = core.cpum;

 cpum->halted = 0;
 cpum->mdr = 0x00;

 cpum->CombinedNIState &= ~0x01;

 if(powering_up)
  core.Power();
 //
 cpum->PIN_Delay = 0x40; // Trigger reset
}

void CPU_Init(CPU_Misc* cpum)
{
 core.cpum = cpum;

 cpum->timestamp = 0;

 cpum->PIN_Delay = 0;
 cpum->PrevNMILineState = false;
 cpum->CombinedNIState = 0x00;
 cpum->MultiIRQState = 0x00;
 cpum->NMILineState = false;
 cpum->PrevNMILineState = false;
}

void CPU_StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname, const char* sname_core)
{
 CPU_Misc* const cpum = core.cpum;

 if(load && load < 0x00102300)
 {
  SFORMAT BWCStateRegs[] = 
  {
   SFVARN(cpum->PIN_Delay, "PIN_Delay"),
   SFEND
  };
  MDFNSS_StateAction(sm, load, data_only, BWCStateRegs, sname_core);
 }
 //
 //
 //
 SFORMAT StateRegs[] =
 {
  SFVARN(cpum->PIN_Delay, "CPUM.PIN_Delay"),
  SFVARN(cpum->mdr, "CPUM.mdr"),
  SFVARN(cpum->halted, "CPUM.halted"),
  SFVARN(cpum->CombinedNIState, "CPUM.CombinedNIState"),
  SFVARN(cpum->NMILineState, "CPUM.NMILineState"),
  SFVARN(cpum->PrevNMILineState, "CPUM.PrevNMILineState"),
  SFVARN(cpum->MultiIRQState, "CPUM.MultiIRQState"),
  SFVARN(cpum->MemSelectCycles, "CPUM.MemSelectCycles"),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, sname);

 if(load && load < 0x00102300)
 {
  uint8 new_halted = 0;

  switch(cpum->halted)
  {
   case 1: new_halted = CPU_Misc::HALTED_WAI; break;
   case 2: new_halted = CPU_Misc::HALTED_STP; break;
   case 3: new_halted = CPU_Misc::HALTED_DMA; break;
  }
  cpum->halted = new_halted;
 }

 core.StateAction(sm, load, data_only, sname_core);
}
//
//
//
uint32 CPU_GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 return core.GetRegister(id, special, special_len);
}

void CPU_SetRegister(const unsigned id, const uint32 value)
{
 core.SetRegister(id, value);
}

