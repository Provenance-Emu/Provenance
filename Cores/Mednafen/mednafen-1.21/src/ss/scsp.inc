/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* scsp.inc - SCSP Emulation
**  Copyright (C) 2015-2017 Mednafen Team
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

/*
 TODO:
	Open bus emulation and cycle timing granularity instead of sample(someday?); be careful with DSP input/output buffering
	with respect to dry/direct output path delay, and the mapping of the buffers to the address space.

	Finish MIDI interface emulation.

	Proper reset/power-on state.

	Mem4Mb
*/

SS_SCSP::SS_SCSP()
{
 memset(&RAM[0x40000], 0x00, 0x80000);	// Zero out dummy part.

 Reset(true);
}

SS_SCSP::~SS_SCSP()
{


}

void SS_SCSP::RecalcSoundInt(void)	// Sound CPU interrupts
{
 unsigned mask_test;
 unsigned lvmasked[3];
 unsigned out_level = 0;

 mask_test = SCIPD & SCIEB;
 if(mask_test &~ 0xFF)
  mask_test = (mask_test & 0xFF) | 0x80;

 lvmasked[0] = (SCILV[0] & mask_test) << 0;
 lvmasked[1] = (SCILV[1] & mask_test) << 1;
 lvmasked[2] = (SCILV[2] & mask_test) << 2;

 for(unsigned i = 0; i < 8; i++)
 {
  unsigned l = (lvmasked[0] & 0x1) | (lvmasked[1] & 0x2) | (lvmasked[2] & 0x4);

  if(l > out_level)
   out_level = l;

  lvmasked[0] >>= 1;
  lvmasked[1] >>= 1;
  lvmasked[2] >>= 1;
 }

 SCSP_SoundIntChanged(out_level);
#if 0
 if(mask_test)
 {
  const unsigned shift = std::min<unsigned>(7, MDFN_tzcount32(mask_test));
  unsigned level;

  level = (((SCILV[0] >> which) & 0x1) << 0) |
	  (((SCILV[1] >> which) & 0x1) << 1) |
	  (((SCILV[2] >> which) & 0x1) << 2);
 }
#endif
}

void SS_SCSP::RecalcMainInt(void)	// Main CPU interrupts
{
 SCSP_MainIntChanged((bool)(MCIPD & MCIEB));
}

void SS_SCSP::Reset(bool powering_up)
{
 //
 // May need to add a DecodeSlotReg() function or something similar if we implement 
 // more aggressive slot register value optimizations on writes in the future.
 //
 memset(SlotRegs, 0, sizeof(SlotRegs));
 memset(Slots, 0, sizeof(Slots));

 for(unsigned i = 0; i < 32; i++)
 {
  // Some SSFs require this; TODO: test to see if this is correct for a reset,
  // and if not, move it into special SSF loading code.
  Slots[i].EnvLevel = 0x3FF;
  Slots[i].EnvPhase = ENV_PHASE_RELEASE;

  Slots[i].LFOTimeCounter = 1;
 }

 memset(SoundStack, 0, sizeof(SoundStack));
 memset(SoundStackDelayer, 0, sizeof(SoundStackDelayer));

 if(powering_up)
 {
  memset(RAM, 0x00, 0x80000);	// or something else?
 }

 //
 //
 MVOL = 0;
 MasterVolume = 0;

 SlotMonitorWhich = 0;
 SlotMonitorData = 0;

 DAC18bit = false;
 Mem4Mb = false;

 KeyExecute = false;
 LFSR = 1;
 GlobalCounter = 0;

 MIDI.Reset();
 //
 //
 DMEA = 0;
 DRGA = 0;
 DTLG = 0;

 DMA_Execute = false;
 DMA_Direction = false;
 DMA_Gate = false;
 //
 //
 for(unsigned i = 0; i < 3; i++)
 {
  Timers[i].Control = 0;
  Timers[i].Counter = 0;
  Timers[i].PrevClockIn = false;
 }

 //
 //
 RBP = 0;
 RBL = 0;

 memset(&DSP, 0, sizeof(DSP));
 DSP.MDEC_CT = 0;
 //
 //
 SCIEB = 0;
 SCIPD = 0;

 MCIEB = 0;
 MCIPD = 0;

 for(unsigned i = 0; i < 3; i++)
  SCILV[i] = 0;

 RecalcSoundInt();
 RecalcMainInt();
}

static INLINE void SDL_PAN_ToVolume(int16* outvol, const unsigned level, const unsigned pan)
{
 const bool pan_which = (bool)(pan & 0x10);
 unsigned basev;
 unsigned panv;

 basev = (0x80 << level);

 if(!level)
  basev = 0;

 panv = basev >> ((pan & 0x0F) >> 1);
 if(pan & 0x01)
  panv -= (panv >> 2);

 if((pan & 0x0F) == 0x0F)
  panv = 0;

 outvol[ pan_which] = panv;
 outvol[!pan_which] = basev;
}

template<typename T, bool IsWrite>
INLINE void SS_SCSP::RW(uint32 A, T& DBV)
{
 if(A < 0x100000)
 {
  if(MDFN_UNLIKELY(A >= 0x80000))
  {
   if(IsWrite)
    SS_DBG(SS_DBG_WARNING | SS_DBG_SCSP, "[SCSP] %zu-byte write of value 0x%08x to unmapped SCSP RAM address 0x%06x\n", sizeof(T), DBV, A);
   else
   {
    SS_DBG(SS_DBG_WARNING | SS_DBG_SCSP, "[SCSP] %zu-byte read from unmapped SCSP RAM address 0x%06x\n", sizeof(T), A);
    DBV = 0;
   }
  }
  else
  {
   ne16_rwbo_be<T, IsWrite>(RAM, A, &DBV);
  }
  return;
 }

 if(A < 0x100400)
 {
  //if(IsWrite)
  // SS_DBG(SS_DBG_SCSP_REGW, "[SCSP] %zu-byte write to slot 0x%02x register offset 0x%02x: 0x%0*x\n", sizeof(T), (A >> 5) & 0x1F, A & 0x1F, (int)(2 * sizeof(T)), DBV);
  //
  // Slot regs
  //
  const unsigned slotnum = (A >> 5) & 0x1F;

  ne16_rwbo_be<T, IsWrite>(SlotRegs[slotnum], A & 0x1F, &DBV);

  if(IsWrite)
  {
   auto* s = &Slots[slotnum];
   uint16& SRV = SlotRegs[slotnum][(A >> 1) & 0xF];

   switch((A >> 1) & 0xF)
   {
    case 0x00:
	KeyExecute |= (bool)(SRV & 0x1000);
	SRV &= 0x0FFF;

	s->KeyBit = (SRV >> 11) & 0x1;
	s->SBControl = (SRV >> 9) & 0x3;
	s->SourceControl = (SRV >> 7) & 0x3;
	s->LoopMode = (SRV >> 5) & 0x3;
	s->WF8Bit = (SRV >> 4) & 0x1;
	s->StartAddr = (s->StartAddr & 0xFFFF) | ((SRV & 0xF) << 16);
	break;

    case 0x01:
	s->StartAddr = (s->StartAddr &~ 0xFFFF) | SRV;
	break;

    case 0x02:
	s->LoopStart = SRV;
	break;

    case 0x03:
	s->LoopEnd = SRV;
	break;

    case 0x04:
	s->EnvRates[ENV_PHASE_ATTACK] = SRV & 0x1F;
	s->AttackHold = (SRV >> 5) & 0x1;
	s->EnvRates[ENV_PHASE_DECAY1] = (SRV >> 6) & 0x1F;
	s->EnvRates[ENV_PHASE_DECAY2] = (SRV >> 11) & 0x1F;
	break;

    case 0x05:
	if(SRV & 0x8000)
	{
	 //SS_DBG(SS_DBG_WARNING | SS_DBG_SCSP, "[SCSP] Unknown bits non-zero in slot %u, register %u\n", slotnum, (A >> 1) & 0xF);
	}

	s->EnvRates[ENV_PHASE_RELEASE] = SRV & 0x1F;
	s->DecayLevel = (SRV >> 5) & 0x1F;
	s->KRS = (SRV >> 10) & 0xF;
	s->AttackLoopLink = (SRV >> 14) & 0x1;
	break;

    case 0x06:
	SRV &= 0x0FFF;
	if(SRV & 0x0C00)
	{
	 //SS_DBG(SS_DBG_WARNING | SS_DBG_SCSP, "[SCSP] Unknown bits non-zero in slot %u, register %u\n", slotnum, (A >> 1) & 0xF);
	}

	s->TotalLevel = SRV & 0xFF;
	s->SoundDirect = (SRV >> 8) & 0x1;
	s->StackWriteInhibit = (SRV >> 9) & 0x1;
	break;

    case 0x07:
        s->ModInputY = SRV & 0x3F;
	s->ModInputX = (SRV >> 6) & 0x3F;
	s->ModLevel = (SRV >> 12) & 0xF;
	break;

    case 0x08:
	if(SRV & 0x8400)
	{
	 //SS_DBG(SS_DBG_WARNING | SS_DBG_SCSP, "[SCSP] Unknown bits non-zero in slot %u, register %u\n", slotnum, (A >> 1) & 0xF);
	}

	s->FreqNum = SRV & 0x7FF;
	s->Octave = (SRV >> 11) & 0xF;
	break;

    case 0x09:
	s->ALFOModLevel = SRV & 0x7;
	s->ALFOWaveform = (SRV >> 3) & 0x3;
	s->PLFOModLevel = (SRV >> 5) & 0x7;
	s->PLFOWaveform = (SRV >> 8) & 0x3;
	s->LFOFreq = (SRV >> 10) & 0x1F;
	s->LFOReset = (SRV >> 15) & 0x1;
	break;

    case 0x0A:
	SRV &= 0x00FF;
	if(SRV & 0x0080)
	{
	 //SS_DBG(SS_DBG_WARNING | SS_DBG_SCSP, "[SCSP] Unknown bits non-zero in slot %u, register %u\n", slotnum, (A >> 1) & 0xF);
	}
	s->ToDSPLevel = SRV & 0x7;
	s->ToDSPSelect = (SRV >> 3) & 0xF;
	break;

    case 0x0B:
	SDL_PAN_ToVolume(s->DirectVolume, (SRV >> 13) & 0x7, (SRV >> 8) & 0x1F);
	SDL_PAN_ToVolume(s->EffectVolume, (SRV >>  5) & 0x7, (SRV >> 0) & 0x1F);
	break;

    case 0x0C: case 0x0D: case 0x0E: case 0x0F:
	SRV = 0;
	break;
   }
  }

  return;
 }

 if(A < 0x100430)
 {
  // OldReg = (OldReg &~ mask) | ((DBV << shift) & mask & whatever);
  unsigned mask = 0xFFFF;
  unsigned shift = 0;

  if(sizeof(T) == 1)
  {
   shift = ((A & 1) ^ 1) << 3;
   mask = 0xFF << shift;
  }

  //
  // Common regs
  //
  switch((A >> 1) & 0x1F)
  {
   case 0x00:	// MVOL (W), DB (W), M4 (W)
	if(IsWrite)
	{
	 uint16 tmp = MVOL | (DAC18bit << 8) | (Mem4Mb << 9);

	 tmp = (tmp &~ mask) | ((DBV << shift) & mask);

	 MVOL = (tmp & 0xF);
	 DAC18bit = (tmp >> 8) & 1;
	 Mem4Mb = (tmp >> 9) & 1;

         //
	 {
	  unsigned mv;

	  mv = 0x2 << (MVOL >> 1);
	  if(!(MVOL & 1))
	   mv -= (mv >> 2);

	  if(!MVOL)
	   mv = 0;

	  MasterVolume = mv;
         }
	}
	else
	 DBV = 0;
	break;

   case 0x01:	// RBP (W), RBL (W)
	if(IsWrite)
	{
	 uint16 tmp = RBP | (RBL << 7);
	 tmp = (tmp &~ mask) | ((DBV << shift) & mask);
	 RBP = tmp & 0x7F;
	 RBL = (tmp >> 7) & 0x3;
	}
	else
	 DBV = 0;
	break;

   case 0x02:	// MIDI input buffer, Input Empty, Input Full, Input Overflow, Output Empty, Output Full (all R)
	if(!IsWrite)
	{
	 if(!shift)
	 {
	  // TODO: Test correct order of flags latching returning versus input fetching/latching(also maybe take into consideration
	  // 16-bit access from SCU being split into 2x 8-bit accesses on the real thing...).
	  unsigned tmp = MIDI.Flags << 8;
	  tmp |= MIDI.ReadInput();
	  DBV = tmp & mask;
	 }
	 else
	  DBV = MIDI.Flags;
	}
	break;

   case 0x03:	// MOBUF (W)
	if(IsWrite)
	{

	}
	else
	 DBV = 0;
	break;

   case 0x04:	// CA/SGC/EG (R), MSLC (W)
	if(IsWrite)
	{
	 uint16 tmp = (SlotMonitorWhich << 11);
	 tmp = (tmp &~ mask) | ((DBV << shift) & mask);
	 SlotMonitorWhich = (tmp >> 11) & 0x1F;
	}
	else
	{
	 DBV = (SlotMonitorData & mask) >> shift;
	}
	break;

   case 0x05:
   case 0x06:
   case 0x07:
   case 0x08:
	if(!IsWrite)
	 DBV = 0;
	break;

   case 0x09:	// DMEA(low) (W)
	if(IsWrite)
	{
	 uint16 tmp = DMEA << 1;
	 tmp = (tmp &~ mask) | ((DBV << shift) & mask);
	 DMEA = tmp >> 1;
	}
	else
	 DBV = 0;
	break;

   case 0x0A:	// DRGA (W), DMEA(high) (W)
	if(IsWrite)
	{
	 uint16 tmp = ((DMEA >> 3) & 0xF000) | (DRGA << 1);
	 tmp = (tmp &~ mask) | ((DBV << shift) & mask);
	 DMEA = (DMEA & 0x7FFF) | ((tmp & 0xF000) << 3);
	 DRGA = (tmp >> 1) & 0x7FF;
	}
	else
	 DBV = 0;
	break;

   case 0x0B: 	// DTLG(W), EX(R/W), DI(R/W), GA(R/W)
	if(IsWrite)
	{
	 //const bool prev_execute = DMA_Execute;
	 uint16 tmp = (DTLG << 1) | (DMA_Execute << 12) | (DMA_Direction << 13) | (DMA_Gate << 14);

	 tmp = (tmp &~ mask) | ((DBV << shift) & mask);

	 DTLG = (tmp >> 1) & 0x7FF;
	 DMA_Execute |= (tmp >> 12) & 0x1;
	 DMA_Direction = (tmp >> 13) & 0x1;
	 DMA_Gate = (tmp >> 14) & 0x1;

#if 0
	 if(!prev_execute && DMA_Execute)
	 {
	  printf("[SCSP] DMA Started; Memory Address: 0x%06x, Register Address: 0x%03x, Length: 0x%03x Direction: %u, Gate: %u\n",
		DMEA << 1, DRGA << 1, DTLG << 1, DMA_Direction, DMA_Gate);
	 }
#endif
	 RunDMA();
	}
	else
	{
	 uint16 tmp = (DMA_Execute << 12) | (DMA_Direction << 13) | (DMA_Gate << 14);

	 DBV = (tmp & mask) >> shift;
	}
	break;

   case 0x0C:	// TIMA(W), TACTL(W)
   case 0x0D:	// TIMB(W), TBCTL(W)
   case 0x0E:	// TIMC(W), TCCTL(W)
	if(IsWrite)
	{
	 auto* t = &Timers[((A >> 1) & 0x1F) - 0x0C];
	 uint16 tmp = (t->Control << 8);
	 tmp = (tmp &~ mask) | ((DBV << shift) & mask);
	 t->Control = (tmp >> 8) & 0x7;

	 if(!shift)
	  t->Reload = DBV & 0xFF;

	 //printf("Timer(%zu-byte) %u: %04x\n", sizeof(T), ((A >> 1) & 0x1F) - 0x0C, DBV);
	}
	else
	 DBV = 0;
	break;

   case 0x0F:	// SCIEB (R/W)
	if(IsWrite)
	{
	 SCIEB = (SCIEB &~ mask) | ((DBV << shift) & mask & 0x7FF);
	 RecalcSoundInt();
	}
	else
	 DBV = (SCIEB & mask) >> shift;
	break;

   case 0x10:	// SCIPD (R) (b5 can be written, like MCIPD)
	if(IsWrite)
	{
	 SCIPD |= ((DBV << shift) & mask & 0x020);
	 RecalcSoundInt();
	}
	else
	 DBV = (SCIPD & mask) >> shift;
	break;

   case 0x11: 	// SCIRE (W)
	if(IsWrite)
	{
	 SCIPD &= ~((DBV << shift) & mask);
	 RecalcSoundInt();
	}
	else
	 DBV = 0;
	break;

   case 0x12:	// SCILV0 (W)
   case 0x13:	// SCILV1 (W)
   case 0x14:	// SCILV2 (W)
	if(IsWrite)
	{
	 const unsigned index = ((A >> 1) & 0x1F) - 0x12;

	 SCILV[index] = (SCILV[index] &~ mask) | ((DBV << shift) & mask & 0x00FF);
	 RecalcSoundInt();
	}
	else
	 DBV = 0;
	break;

   case 0x15:	// MCIEB (W)
	if(IsWrite)
	{
	 MCIEB = (MCIEB &~ mask) | ((DBV << shift) & mask & 0x7FF);
	 RecalcMainInt();
	}
	else
	 DBV = 0;
	break;

   case 0x16:	// MCIPD (R) (when b5=1 is written, set corresponding bit to 1; writing 0 has no apparent effect)
	if(IsWrite)
	{
	 MCIPD |= ((DBV << shift) & mask & 0x020);
	 RecalcMainInt();
	}
	else
	 DBV = (MCIPD & mask) >> shift;
	break;

   case 0x17:	// MCIRE (W)
	if(IsWrite)
	{
	 MCIPD &= ~((DBV << shift) & mask);
	 RecalcMainInt();
	}
	else
	 DBV = 0;
	break;

   case 0x18:
   case 0x19:
   case 0x1A:
   case 0x1B:
   case 0x1C:
   case 0x1D:
   case 0x1E:
   case 0x1F:
	if(IsWrite)
	{
	}
	else
	 DBV = 0;
	break;
  }

  return;
 }

 if(A >= 0x100600 && A <= 0x10067F)
 {
  //
  // Sound stack data
  //
  if(IsWrite)
   *(T*)((uint8*)SoundStack + ((A & 0x7F &~(sizeof(T) - 1)) ^ (2 - sizeof(T)))) = DBV;
  else
   DBV = *(T*)((uint8*)SoundStack + ((A & 0x7F & ~(sizeof(T) - 1)) ^ (2 - sizeof(T))));

  return;
 }

 if(A >= 0x100700 && A <= 0x10077F)
 {
  //
  // DSP coefficients
  //
  const unsigned index = (A & 0x7F) >> 1;
  unsigned mask = 0xFFFF;
  unsigned shift = 0;

  if(sizeof(T) == 1)
  {
   shift = ((A & 1) ^ 1) << 3;
   mask = 0xFF << shift;
  }

  if(IsWrite)
   DSP.COEF[index] = (((DSP.COEF[index] << 3) &~ mask) | ((DBV << shift) & mask)) >> 3;
  else
   DBV = ((DSP.COEF[index] << 3) & mask) >> shift;

  return;
 }

 if(A >= 0x100780 && A <= 0x1007BF)
 {
  //
  // DSP memory addresses
  //
  ne16_rwbo_be<T, IsWrite>(DSP.MADRS, A & 0x3F, &DBV);

  return;
 }

 if(A >= 0x100800 && A <= 0x100BFF)
 {
  //
  // DSP microprogram
  //
  ne64_rwbo_be<T, IsWrite>(DSP.MPROG, A & 0x3FF, &DBV);

  return;
 }

 //
 // DSP work buffer
 //
 if(A >= 0x100C00 && A <= 0x100DFF)
 {
  const unsigned index = (A & 0x1FF) >> 2;
  unsigned mask;
  unsigned shift = (A & 2) ? 8 : 0;

  if(sizeof(T) == 1)
  {
   shift += ((A & 1) ^ 1) << 3;
   mask = 0xFF << shift;
  }
  else
   mask = 0xFFFF << shift;

  if(!(A & 2))
   mask &= 0xFF;

  if(IsWrite)
   DSP.TEMP[index] = (DSP.TEMP[index] &~ mask) | ((DBV << shift) & mask & 0xFFFFFF);
  else
   DBV = (DSP.TEMP[index] & mask) >> shift;

  return;
 }

 //
 // DSP memory read stack
 //
 if(A >= 0x100E00 && A <= 0x100E7F)
 {
  const unsigned index = (A & 0x7F) >> 2;
  unsigned mask;
  unsigned shift = (A & 2) ? 8 : 0;

  if(sizeof(T) == 1)
  {
   shift += ((A & 1) ^ 1) << 3;
   mask = 0xFF << shift;
  }
  else
   mask = 0xFFFF << shift;

  if(!(A & 2))
   mask &= 0xFF;

  if(IsWrite)
   DSP.MEMS[index] = (DSP.MEMS[index] &~ mask) | ((DBV << shift) & mask & 0xFFFFFF);
  else
   DBV = (DSP.MEMS[index] & mask) >> shift;

  return;
 }

 //
 // DSP mix stack
 //
 if(A >= 0x100E80 && A <= 0x100EBF)
 {
  const unsigned index = (A & 0x3F) >> 2;
  unsigned mask;
  unsigned shift = (A & 2) ? 4 : 0;

  if(sizeof(T) == 1)
  {
   shift += ((A & 1) ^ 1) << 3;
   mask = 0xFF << shift;
  }
  else
   mask = 0xFFFF << shift;

  if(!(A & 2))
   mask &= 0x0F;

  if(IsWrite)
   DSP.MIXS[index] = (DSP.MIXS[index] &~ mask) | ((DBV << shift) & mask & 0xFFFFFF);
  else
   DBV = (DSP.MIXS[index] & mask) >> shift;

  return;
 }

 //
 //
 //
 if(A >= 0x100EC0 && A <= 0x100EDF)
 {
  ne16_rwbo_be<T, IsWrite>(DSP.EFREG, A & 0x1F, &DBV);

  return;
 }

 if(A >= 0x100EE0 && A <= 0x100EE3)
 {
  if(!IsWrite)
   DBV = ne16_rbo_be<T>(EXTS, A & 0x3);

  return;
 }

 if(IsWrite)
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCSP, "[SCSP] Unknown %zu-byte write of value 0x%08x to address 0x%08x\n", sizeof(T), DBV, A);
 else
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCSP, "[SCSP] Unknown %zu-byte read from address 0x%08x\n", sizeof(T), A);
  DBV = 0;
 }
}


//
// Gate bit only forces the value to 0, the read still seems to occur(or at the very least timing side effects occur for the case of reg->mem).
//
void NO_INLINE SS_SCSP::RunDMA(void)
{
 if(!DMA_Execute)
  return;

 uint32 length = DTLG;
 uint32 mem_addr = DMEA;
 uint32 reg_addr = DRGA;
 bool dir = DMA_Direction;
 bool gate = DMA_Gate;

 while(length)
 {
  if(dir)
  {
   uint16 tmp;

   RW<uint16, false>(0x100000 | (reg_addr << 1), tmp);

   if(gate)
    tmp = 0;

   if(MDFN_LIKELY(mem_addr < 0x40000))
    RAM[mem_addr] = tmp;
  }
  else
  {
   uint16 tmp = RAM[mem_addr];

   if(gate)
    tmp = 0;

   RW<uint16, true>(0x100000 | (reg_addr << 1), tmp);
  }

  reg_addr = (reg_addr + 1) & 0x000007FF;
  mem_addr = (mem_addr + 1) & 0x0007FFFF;
  length = length - 1;
 }

 DMA_Execute = false;
 SCIPD |= 0x10;
 MCIPD |= 0x10;
 RecalcSoundInt();
 RecalcMainInt();
}


INLINE void SS_SCSP::RunEG(Slot* s, const unsigned key_eg_scale)
{
 if(s->EnvPhase == ENV_PHASE_DECAY1 && (s->EnvLevel >> 5) == s->DecayLevel)
  s->EnvPhase = ENV_PHASE_DECAY2;

 //
 //
 //
 bool ClockEG;
 const unsigned ERateNoScale = s->EnvRates[s->EnvPhase];
 const unsigned ERate = std::min<unsigned>(0x1F, key_eg_scale + ERateNoScale);
 const unsigned ERateWBT = (0x22 - std::min<unsigned>(0x18, ERate)) >> 1;
 const bool EGCBT = (GlobalCounter >> ERateWBT) & 1;

 ClockEG = !s->EnvGCBTPrev && EGCBT;

 if((ERate < 0x18) && (ERate & 1))
  ClockEG &= (bool)((GlobalCounter >> (ERateWBT + 1)) & 0x3);

 ClockEG &= (bool)ERateNoScale;

 s->EnvGCBTPrev = EGCBT;

 if(ClockEG)
 {
  const int32 inc_base = (s->EnvPhase == ENV_PHASE_ATTACK) ? ~s->EnvLevel : 16;
  const unsigned ermaxo = std::max<unsigned>(0x18, std::min<unsigned>(0x1E, ERate));
  const uint32 srac = ((0x20 - ermaxo) >> 1) + (ermaxo & 1 & (GlobalCounter >> (ERateWBT + 1)));

  //if(s == &Slots[0] && s->EnvLevel)
  // printf("EP: %u, EL: 0x%04x, AR: 0x%02x, %d, %u --- %02x\n", s->EnvPhase, s->EnvLevel, s->EnvRates[ENV_PHASE_ATTACK], inc_base, srac, ERate);

  s->EnvLevel += inc_base >> srac;

  if((int32)s->EnvLevel >= 0x3FF)
  {
   s->WFAllowAccess = false;
   s->EnvLevel = 0x3FF;
  }

  if((int32)s->EnvLevel < 0)
   s->EnvLevel = 0;
 }
 //
 //
 //

 if(s->EnvPhase == ENV_PHASE_ATTACK)
 {
  if((s->AttackLoopLink && s->InLoop) || (!s->AttackLoopLink && s->EnvLevel == 0))
   s->EnvPhase = ENV_PHASE_DECAY1;
 }
}

//
// Take care in handling LFSR, or else the volume of noise-ALFO-modulated noise will
// be quite off, or have a DC bias.
//
INLINE uint8 SS_SCSP::GetALFO(Slot* s)
{
 uint8 ret;

 switch(s->ALFOWaveform)
 {
  default:
  case 0:	// Saw
	ret = s->LFOCounter &~ 1;
	break;

  case 1:	// Square
	ret = ((int8)s->LFOCounter >> 7) &~ 1;
	break;

  case 2:	// Triangle
	ret = (unsigned)(s->LFOCounter ^ ((int8)s->LFOCounter >> 7)) << 1;
	break;

  case 3:	// Noise
	ret = LFSR &~ 1;
	break;
 }

 ret >>= (7 - s->ALFOModLevel);

 if(!s->ALFOModLevel)
  ret = 0;

 return ret;
}

INLINE int SS_SCSP::GetPLFO(Slot* s)
{
 int ret;

 switch(s->PLFOWaveform)
 {
  default:
  case 0:	// Saw
	ret = (int8)(s->LFOCounter &~ 1);
	break;

  case 1:	// Square
	ret = (int8)((s->LFOCounter & 0x80) ? 0x80 : 0x7E);
	break;

  case 2:	// Triangle
	ret = (int8)(((s->LFOCounter & 0x3F) ^ ((s->LFOCounter & 0x40) ? 0x3F : 0x00) ^ ((s->LFOCounter & 0x80) ? 0x7F : 0x00)) << 1);
	break;

  case 3:	// Noise
	ret = (int8)(LFSR &~ 1);
	break;
 }

 ret >>= (7 - s->PLFOModLevel);

 if(!s->PLFOModLevel)
  ret = 0;

 ret = ((0x40 ^ (s->FreqNum >> 4)) * ret) >> 6;

 return ret;
}

INLINE void SS_SCSP::RunLFO(Slot* s)
{
 s->LFOTimeCounter--;
 if(!s->LFOTimeCounter)
 {
  s->LFOCounter++;
  s->LFOTimeCounter = (((8 - (s->LFOFreq & 0x3)) << 7) >> (s->LFOFreq >> 2)) - 4;
 }

 if(s->LFOReset)
  s->LFOCounter = 0;
}

//
//
//
static INLINE uint32 dspfloat_to_int(const uint16 inv)
{
 const uint32 sign_xor = (int32)((inv & 0x8000) << 16) >> 1;
 const uint32 exp = (inv >> 11) & 0xF;
 uint32 ret;

 ret = inv & 0x7FF;
 if(exp < 12)
  ret |= 0x800;
 ret <<= 11 + 8;
 ret ^= sign_xor;
 ret = (int32)ret >> (8 + std::min<unsigned>(11, exp));

 return ret & 0xFFFFFF;
}

static INLINE uint32 int_to_dspfloat(const uint32 inv)
{
 const uint32 invsl8 = inv << 8;
 const uint32 sign_xor = (int)invsl8 >> 31;
 uint32 exp, shift;
 uint32 ret;

 exp = MDFN_lzcount32(((invsl8 ^ sign_xor) << 1) | (1 << 19));
 shift = exp - (bool)(exp == 12); //std::min<uint32>(11, exp);

 ret = (int32)invsl8 >> (19 - shift);
 ret &= 0x87FF;
 ret |= exp << 11;

 return ret;
}

INLINE void SS_SCSP::RunDSP(void)
{
 //
 //
 // Instruction field order/width RE'ing notes:
 //
 // Bit     0: NXADDR
 // Bit     1: ADRGB
 // Bit   2-6: MASA
 // Bit     8: NOFL (disables floating-point conversion when =1, instead just shifting by 8); has effect with MRT=1 or MWT=1
 // Bit  9-14: CRA (Coefficient read address, input into Y_SEL)
 // Bit    16: BSEL
 // Bit    17: ZERO
 // Bit    18: NEGB (apparently no effect when ZERO=1)
 // Bit    19: YRL
 // Bit    20: SHFT0
 // Bit    21: SHFT1
 // Bit    22: FRCL
 // Bit    23: ADRL (latches A_SEL output into ADRS_REG)
 // Bit 24-27: EWA(EFREG write address)
 // Bit    28: EWT(EFREG write enable)
 // Bit    29: MRT  (Memory read trigger; to read: [MWR=1] [whatever instruction] [IWT=1]
 // Bit    30: MWT  (Memory write trigger)
 // Bit    31: TABLE
 // Bit 32-36: IWA (MEMS write address)
 // Bit    37: IWT (MEMS write trigger)
 // Bit 38-43: IRA (0x00-0x1F MEMS, 0x20-0x2F MIXS)
 // Bit 45-46: YSEL
 // Bit    47: XSEL
 // Bit 48-54: TWA(temp write address) Seems to be an offset added to a counter changed each sample.
 // Bit    55: TWT(temp write trigger)  WARNING: Setting this to 1 for all 128 steps apparently can cause a CPU to freeze up if it tries to read/write TEMP afterward.
 // Bit 56-62: TRA(temp read address) 
 for(unsigned step = 0; step < 128; step++)
 {
  const uint64 instr = DSP.MPROG[step];

/*
  assert(!(instr & (1ULL << 7)));
  assert(!(instr & (1ULL << 15)));
  assert(!(instr & (1ULL << 44)));
  assert(!(instr & (1ULL << 63)));
*/

  const bool NXADDR = (instr >> 0) & 1;
  const bool ADRGB = (instr >> 1) & 1;
  const unsigned MASA = (instr >> 2) & 0x1F;
  const bool NOFL = (instr >> 8) & 1;
  const unsigned CRA = (instr >> 9) & 0x3F;
  const bool BSEL = (instr >> 16) & 1;
  const bool ZERO = (instr >> 17) & 1;
  const bool NEGB = (instr >> 18) & 1;
  const bool YRL = (instr >> 19) & 1;
  const bool SHFT0 = (instr >> 20) & 1;
  const bool SHFT1 = (instr >> 21) & 1;
  const bool FRCL = (instr >> 22) & 1;  
  const bool ADRL = (instr >> 23) & 1;
  const unsigned EWA = (instr >> 24) & 0x0F;
  const bool EWT = (instr >> 28) & 1;
  const bool MRT = (instr >> 29) & 1;
  const bool MWT = (instr >> 30) & 1;
  const bool TABLE = (instr >> 31) & 1;
  const unsigned IWA = (instr >> 32) & 0x1F;
  const bool IWT = (instr >> 37) & 1;
  const unsigned IRA = (instr >> 38) & 0x3F;
  const unsigned YSEL = (instr >> 45) & 0x03;
  const bool XSEL = (instr >> 47) & 1;
  const unsigned TEMPWriteAddr = ((instr >> 48) + DSP.MDEC_CT) & 0x7F;
  const bool TWT = (instr >> 55) & 1;
  const unsigned TEMPReadAddr = ((instr >> 56) + DSP.MDEC_CT) & 0x7F;

#if 0
  if(!(step & 1) && (MWT || MRT))
   SS_DBG(SS_DBG_WARNING | SS_DBG_SCSP, "[SCSP] Memory access requested at even DSP step %u; 0x%016llx\n", step, instr);

  if(MWT & MRT)
   SS_DBG(SS_DBG_WARNING | SS_DBG_SCSP, "[SCSP] MWT and MRT both 1 at DSP step %u; 0x%016llx\n", step, instr);
#endif
  //
  //
  if(IRA & 0x20)
  {
   if(IRA & 0x10)
   {
    if(!(IRA & 0xE))
     DSP.INPUTS = EXTS[IRA & 0x1] << 8;
   }
   else
   {
    DSP.INPUTS = DSP.MIXS[IRA & 0xF] << 4;
   }
  }
  else
  {
   DSP.INPUTS = DSP.MEMS[IRA & 0x1F];
  }

  const int32 INPUTS = sign_x_to_s32(24, DSP.INPUTS);
  const int32 TEMP = sign_x_to_s32(24, DSP.TEMP[TEMPReadAddr]);
  const int32 X_SEL_Inputs[2] = { TEMP, INPUTS };
  const uint16 Y_SEL_Inputs[4] = { DSP.FRC_REG, DSP.COEF[CRA], (uint16)((DSP.Y_REG >> 11) & 0x1FFF), (uint16)((DSP.Y_REG >> 4) & 0x0FFF) };
  const uint32 SGA_Inputs[2] = { (uint32)TEMP, DSP.SFT_REG };
  //
  //
  //
  if(YRL)
  {
   DSP.Y_REG = INPUTS & 0xFFFFFF;
  }
  //
  //
  //
  int32 ShifterOutput;

  ShifterOutput = (uint32)sign_x_to_s32(26, DSP.SFT_REG) << (SHFT0 ^ SHFT1);

  if(!SHFT1)
  {
   if(ShifterOutput > 0x7FFFFF)
    ShifterOutput = 0x7FFFFF;
   else if(ShifterOutput < -0x800000)
    ShifterOutput = 0x800000;
  }
  ShifterOutput &= 0xFFFFFF;

  if(EWT)
   DSP.EFREG[EWA] = (ShifterOutput >> 8);

  if(TWT)
   DSP.TEMP[TEMPWriteAddr] = ShifterOutput;

  //
  //
  if(FRCL)
  {
   const unsigned F_SEL_Inputs[2] = { (unsigned)(ShifterOutput >> 11), (unsigned)(ShifterOutput & 0xFFF) };

   DSP.FRC_REG = F_SEL_Inputs[SHFT0 & SHFT1];
   //printf("FRCL: 0x%08x\n", DSP.FRC_REG);
  }
  //
  //
  DSP.Product = ((int64)sign_x_to_s32(13, Y_SEL_Inputs[YSEL]) * X_SEL_Inputs[XSEL]) >> 12;
  // if(step < 4)
  //  printf("%u %08x %08x product=0x%08x\n", step, Y_SEL_Inputs[YSEL], X_SEL_Inputs[XSEL], DSP.Product);
  //
  //
  //if((step == 3 || step == 7) && CRA)
  // printf("Step %u: %08x %08x %08x  --- ysel=%u cra=0x%02x[0x%04x] temp=0x%08x\n", step, SGA_Inputs[BSEL], Y_SEL_Inputs[YSEL], X_SEL_Inputs[XSEL], YSEL, CRA, DSP.COEF[CRA], TEMP);

  uint32 SGAOutput;

  SGAOutput = SGA_Inputs[BSEL];

  if(NEGB)
   SGAOutput = -SGAOutput;

  if(ZERO)
   SGAOutput = 0;

  DSP.SFT_REG = (DSP.Product + SGAOutput) & 0x3FFFFFF;
  //
  //
  if(IWT)
  {
   DSP.MEMS[IWA] = DSP.ReadValue;
  }
  //
  //
  if(DSP.ReadPending)
  {
   uint16 tmp = RAM[DSP.RWAddr];
   DSP.ReadValue = (DSP.ReadPending == 2) ? (tmp << 8) : dspfloat_to_int(tmp);
   DSP.ReadPending = false;
  }
  else if(DSP.WritePending)
  {
   if(!(DSP.RWAddr & 0x40000))
    RAM[DSP.RWAddr] = DSP.WriteValue;

   DSP.WritePending = false;
  }

  {
   uint16 addr;

   addr = DSP.MADRS[MASA];
   addr += NXADDR;

   if(ADRGB)
   {
    addr += sign_x_to_s32(12, DSP.ADRS_REG);
   }

   if(!TABLE)
   {
    addr += DSP.MDEC_CT;
    addr &= (0x2000 << RBL) - 1;
   }

   DSP.RWAddr = (addr + (RBP << 12)) & 0x7FFFF;

   if(MRT)
   {
    DSP.ReadPending = 1 + NOFL;
   }
   if(MWT)
   {
    DSP.WritePending = true;
    DSP.WriteValue = NOFL ? (ShifterOutput >> 8) : int_to_dspfloat(ShifterOutput);
   }
  }
  //
  //
  if(ADRL)
  {
   const uint16 A_SEL_Inputs[2] = { /*INPUTS is sign-extended above */ (uint16)((INPUTS >> 16) & 0xFFF), (uint16)(ShifterOutput >> 12) };

   DSP.ADRS_REG = A_SEL_Inputs[SHFT0 & SHFT1];
  }
 }

 if(!DSP.MDEC_CT)
  DSP.MDEC_CT = (0x2000 << RBL);
 DSP.MDEC_CT--;
}
//
//
//
INLINE void SS_SCSP::RunSample(int16* outlr)
{
 int32 out_accum[2] = { 0, 0 };

 for(unsigned i = 0; i < 3; i++)
 {
  auto* t = &Timers[i];
  bool CCB = (GlobalCounter >> (4 + t->Control)) & 1;
  bool DoClock = (t->Control == 0) || (!t->PrevClockIn && CCB);
  t->PrevClockIn = CCB;


  if(DoClock)
  {
   if(t->Reload >= 0)
   {
    t->Counter = t->Reload;
    t->Reload = -1;
   }
   else
    t->Counter++;

   if(t->Counter == 0xFF)
   {
    SCIPD |= 0x40 << i;
    MCIPD |= 0x40 << i;
   }
  }
 }

 SCIPD |= 0x400;
 MCIPD |= 0x400;
 RecalcSoundInt();
 RecalcMainInt();

 //
 //
 //
 RunDSP();

 for(unsigned i = 0; i < 0x10; i++)
  DSP.MIXS[i] = 0;
 //
 //
 //
 for(unsigned slot = 0; slot < 32; slot++)
 {
  uint32 mdata = 0;
  auto* s = &Slots[slot];
  unsigned key_eg_scale;

  if(s->KRS == 0xF)
   key_eg_scale = 0x00;
  else
   key_eg_scale = std::max<int>(0x00, std::min<int>(0x0F, s->KRS + (s->Octave ^ 0x8) - 0x8));

  RunEG(s, key_eg_scale);

  if(KeyExecute && (s->EnvPhase == ENV_PHASE_RELEASE) == s->KeyBit)
  {
   if(s->KeyBit)
   {
    s->PhaseWhacker = 0;
    s->CurrentAddr = 0;
    s->InLoop = false;
    s->LoopSub = false;
    s->WFAllowAccess = true;
    s->EnvPhase = ENV_PHASE_ATTACK;

    if((s->EnvRates[ENV_PHASE_ATTACK] + key_eg_scale) >= 0x20)
     s->EnvLevel = 0x000;
    else
     s->EnvLevel = 0x280;
   }
   else
    s->EnvPhase = ENV_PHASE_RELEASE;
  }

  //
  //
  uint16 sample = 0;

  if(s->SourceControl == 1)
   sample = LFSR << 8;

  sample ^= SB_XOR_Table[s->SBControl];	// For zero and noise case only; waveform playback needs it to occur before linear interpolation.

  if(1) //s->WFAllowAccess)
  {
   if(!s->InLoop)
   {
    if((uint16)(s->CurrentAddr + 1) > s->LoopStart)
    {
     if(s->LoopMode == 2)
      s->LoopSub = true;

     s->InLoop = true;
    }
   }
   else
   {
    const bool cres = s->LoopSub ? ((uint16)(s->LoopEnd - s->CurrentAddr + s->LoopStart) <= s->LoopStart) : ((uint16)(s->CurrentAddr + 1) > s->LoopEnd);

    if(cres)
    {
     if(s->LoopMode == 0)
      s->WFAllowAccess = false;
    
     if(s->LoopMode == 3)
      s->LoopSub = !s->LoopSub;
 
     s->CurrentAddr += s->LoopStart - s->LoopEnd;
    }
   }
  }

  if(s->WFAllowAccess)
  {
   uint32 modalizer;
   uint32 tmppw = s->PhaseWhacker;
   uint16 tmpa = s->CurrentAddr;
   int16 s0, s1;

   //
   //
   modalizer  = (int16)SoundStack[(GlobalCounter + s->ModInputX) & 0x3F];
   modalizer += (int16)SoundStack[(GlobalCounter + s->ModInputY) & 0x3F];
   modalizer >>= 0x10 - s->ModLevel;

   if(s->ModLevel <= 0x04)
    modalizer = 0;

   modalizer = sign_x_to_s32(11, modalizer);
   //
   //

   if(s->LoopSub)
   {
    tmppw = ~tmppw;
    tmpa = s->LoopStart + s->LoopEnd + ~tmpa;
   }

   mdata |= ((tmpa >> 12) << 7);

   if(s->WF8Bit)
   {
    const uint32 addr0 = (s->StartAddr + modalizer + (uint16)(tmpa + 0)) & 0xFFFFF;
    const uint32 addr1 = (s->StartAddr + modalizer + (uint16)(tmpa + 1)) & 0xFFFFF;

    s0 = ne16_rbo_be<uint8>(RAM, addr0) << 8;
    s1 = ne16_rbo_be<uint8>(RAM, addr1) << 8;
   }
   else
   {
    s0 = RAM[((s->StartAddr >> 1) + modalizer + (uint16)(tmpa + 0)) & 0x7FFFF];
    s1 = RAM[((s->StartAddr >> 1) + modalizer + (uint16)(tmpa + 1)) & 0x7FFFF];
   }

   s0 ^= SB_XOR_Table[s->SBControl];
   s1 ^= SB_XOR_Table[s->SBControl];

   if(s->SourceControl == 0)
   {
    const unsigned sia = (tmppw >> (14 - 6)) & 0x3F;
    sample = ((s0 * (0x40 - sia)) + (s1 * sia)) >> 6;
   }

   s->PhaseWhacker += (((0x400 ^ s->FreqNum) + GetPLFO(s)) << (s->Octave ^ 0x8)) >> 4;
   s->CurrentAddr += s->PhaseWhacker >> 14;
   s->PhaseWhacker &= (1U << 14) - 1;
  }
  //
  //

  RunLFO(s);	// Run between PLFO fetching and ALFO fetching.

  // Do LFSR clocking between sample fetching and ALFO fetching.
  LFSR = (LFSR >> 1) | (((LFSR >> 5) ^ LFSR) & 1) << 16;

  
  {
   int32 vlevel;

   vlevel = (s->EnvPhase == ENV_PHASE_ATTACK && s->AttackHold) ? 0 : s->EnvLevel;
   //
   mdata |= (s->EnvPhase << 5) | (vlevel >> 5);
   //
   if(!s->SoundDirect)
   {
    vlevel += s->TotalLevel << 2;
    vlevel += GetALFO(s);

    if(vlevel > 0x3FF)
     vlevel = 0x3FF;

    sample = ((int16)sample * ((vlevel & 0x3F) ^ 0x7F)) >> ((vlevel >> 6) + 7);
   }
  }

  if(!Slots[(GlobalCounter - 4) & 0x1F].StackWriteInhibit)
  {
   SoundStack[(GlobalCounter - 4) & 0x3F] = SoundStackDelayer[3];
  }

  SoundStackDelayer[3] = SoundStackDelayer[2];
  SoundStackDelayer[2] = SoundStackDelayer[1];
  SoundStackDelayer[1] = SoundStackDelayer[0];
  SoundStackDelayer[0] = sample;
  //
  //
  if(SlotMonitorWhich == slot)
   SlotMonitorData = mdata;
  //
  //
  if(s->ToDSPLevel)
   DSP.MIXS[s->ToDSPSelect] = (DSP.MIXS[s->ToDSPSelect] + (((uint32)(int16)sample << 4) >> (7 - s->ToDSPLevel))) & 0xFFFFF;
  //
  //
  out_accum[0] += ((int16)sample * s->DirectVolume[0]) >> 14;
  out_accum[1] += ((int16)sample * s->DirectVolume[1]) >> 14;

  {
   const uint16 eff_sample = (slot & 0x10) ? ((slot & 0xE) ? 0 : EXTS[slot & 0x1]) : DSP.EFREG[slot];

   out_accum[0] += ((int16)eff_sample * s->EffectVolume[0]) >> 14;
   out_accum[1] += ((int16)eff_sample * s->EffectVolume[1]) >> 14;
  }
  //
  //
  GlobalCounter++;
 }

 KeyExecute = false;

 //
 //
 //
 out_accum[0] = (out_accum[0] * MasterVolume) >> 8;
 out_accum[1] = (out_accum[1] * MasterVolume) >> 8;

 out_accum[0] = std::min<int32>(32767, std::max<int32>(-32768, out_accum[0]));
 out_accum[1] = std::min<int32>(32767, std::max<int32>(-32768, out_accum[1]));

 if(DAC18bit)
 {
  // Doesn't seem to improve precision.  Remember
  // to extend the outlr[] types if this SCSP emulator is used
  // in a system that actually has an 18-bit DAC.
  out_accum[0] = (uint32)out_accum[0] << 2;
  out_accum[1] = (uint32)out_accum[1] << 2;
 }

 outlr[0] = out_accum[0];
 outlr[1] = out_accum[1];
}

//
//
//
void SS_SCSP::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname)
{
 SFORMAT StateRegs[] =
 {
  SFVARN(SlotRegs, "SlotRegs"),

  SFVAR(Slots->PhaseWhacker, 32, sizeof(*Slots), Slots),
  SFVAR(Slots->CurrentAddr, 32, sizeof(*Slots), Slots),
  SFVAR(Slots->InLoop, 32, sizeof(*Slots), Slots),
  SFVAR(Slots->LoopSub, 32, sizeof(*Slots), Slots),
  SFVAR(Slots->WFAllowAccess, 32, sizeof(*Slots), Slots),
  SFVAR(Slots->EnvLevel, 32, sizeof(*Slots), Slots),
  SFVAR(Slots->EnvPhase, 32, sizeof(*Slots), Slots),
  SFVAR(Slots->EnvGCBTPrev, 32, sizeof(*Slots), Slots),
  SFVAR(Slots->LFOCounter, 32, sizeof(*Slots), Slots),
  SFVAR(Slots->LFOTimeCounter, 32, sizeof(*Slots), Slots),

  SFVAR(EXTS),

  SFVAR(SoundStack),
  SFVAR(SoundStackDelayer),

  SFVAR(MasterVolume),
  SFVAR(MVOL),
  SFVAR(DAC18bit),
  SFVAR(Mem4Mb),

  SFVAR(SlotMonitorWhich),
  SFVAR(SlotMonitorData),

  SFVAR(KeyExecute),
  SFVAR(LFSR),
  SFVAR(GlobalCounter),

  SFVAR(MIDI.InputFIFO),
  SFVAR(MIDI.InputRP),
  SFVAR(MIDI.InputWP),
  SFVAR(MIDI.InputCount),
  SFVAR(MIDI.OutputFIFO),
  SFVAR(MIDI.OutputRP),
  SFVAR(MIDI.OutputWP),
  SFVAR(MIDI.OutputCount),
  SFVAR(MIDI.Flags),
 
  SFVAR(SCIEB),
  SFVAR(SCIPD),

  SFVAR(MCIEB),
  SFVAR(MCIPD),

  SFVAR(SCILV),

  SFVAR(Timers->Control, 3, sizeof(*Timers), Timers),
  SFVAR(Timers->Counter, 3, sizeof(*Timers), Timers),
  SFVAR(Timers->PrevClockIn, 3, sizeof(*Timers), Timers),
  SFVAR(Timers->Reload, 3, sizeof(*Timers), Timers),

  SFVAR(DMEA),
  SFVAR(DRGA),
  SFVAR(DTLG),

  SFVAR(DMA_Execute),
  SFVAR(DMA_Direction),
  SFVAR(DMA_Gate),

  SFVAR(RBP),
  SFVAR(RBL),

  SFVAR(DSP.MPROG),
  SFVAR(DSP.TEMP),
  SFVAR(DSP.MEMS),
  SFVAR(DSP.COEF),
  SFVAR(DSP.MADRS),
  SFVAR(DSP.MIXS),
  SFVAR(DSP.EFREG),

  SFVAR(DSP.INPUTS),

  SFVAR(DSP.Product),
  SFVAR(DSP.SFT_REG),
  SFVAR(DSP.FRC_REG),
  SFVAR(DSP.Y_REG),
  SFVAR(DSP.ADRS_REG),

  SFVAR(DSP.MDEC_CT),

  SFVAR(DSP.RWAddr),

  SFVAR(DSP.WritePending),
  SFVAR(DSP.WriteValue),

  SFVAR(DSP.ReadPending),
  SFVAR(DSP.ReadValue),
  //
  SFPTR16(RAM, 262144),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SCSP");

 if(load)
 {
  for(auto& s : Slots)
  {
   s.EnvLevel &= 0x3FF;
   s.EnvPhase &= 0x3;
  }

  SlotMonitorWhich &= 0x1F;

  MIDI.InputRP &= 0x3;
  MIDI.InputWP &= 0x3;

  MIDI.OutputRP &= 0x3;
  MIDI.OutputWP &= 0x3;

  DMEA &= 0x7FFFF;
  DRGA &= 0x7FF;
  DTLG &= 0x7FF;

  RBP &= 0x7F;
  RBL &= 0x3;

  DSP.RWAddr &= 0x7FFFF;

  for(uint32 A = 0x100000; A < 0x100400; A += 2)
  {
   RW<uint16, true>(A, *(MDAP(SlotRegs) + ((A & 0x3FE) >> 1)));
  }
  RecalcSoundInt();
  RecalcMainInt();
 }

}

//
//
//
uint32 SS_SCSP::GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 uint32 ret = 0xDEADBEEF;

 switch(id)
 {
  case GSREG_MVOL:
	ret = MVOL;
	break;

  case GSREG_DAC18B:
	ret = DAC18bit;
	break;

  case GSREG_MEM4MB:
	ret = Mem4Mb;
	break;

  case GSREG_RBP:
	ret = RBP;
	break;

  case GSREG_RBL:
	ret = RBL;
	break;

  case GSREG_MSLC:
	ret = SlotMonitorWhich;
	break;
 }

 return ret;
}

void SS_SCSP::SetRegister(const unsigned id, const uint32 value)
{
 switch(id)
 {
  //case GSREG_MVOL: MVOL = value & 0xF; // TODO cache

  case GSREG_DAC18B:
	DAC18bit = value & 1;
	break;

  case GSREG_MEM4MB:
	Mem4Mb = value & 1;
	break;

  case GSREG_RBP:
	RBP = value & 0x7F;
	break;

  case GSREG_RBL:
	RBL = value & 0x3;
	break;

  case GSREG_MSLC:
	SlotMonitorWhich = value & 0x1F;
	break;
 }
}

