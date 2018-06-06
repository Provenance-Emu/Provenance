/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* scu.inc - SCU Emulation
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

// TODO: Investigate different instruction dispatch mechanisms for DSP to take advantage of modern branch
//	 prediction, to improve performance and reduce instruction cache footprint.
// TODO: Test slave SH-2 IRQ handling.
// TODO: Open bus, and correct propagation of open bus from one bus to another.
// TODO: Consider logging DMA status register reads.
// TODO: Test indirect DMA table alignment requirements.
// TODO: Indirect same-bus DMA has kind of weird effects that might actually be useful(and hence used), so test!

/*
 Notes(assuming NTSC, HRES=0, VRES=0, LSMD=0):
   Timer0 notes:
	Counter is effectively forced to 0 while timer enable bit is 0, but it won't generate an IRQ if T0C is also 0(unless timer enable bit is set
	to 1 again)...

	Hrm...T0C of 0-263 causes interrupts.  In interlace mode though, 263 causes an interrupt at half the rate...
   Timer1 notes:
	T1S of 1-426(HRES=0x00) causes interrupt for each line, 0 and 427+ causes it every other line?


 The effect of writes to MCIEB on the interrupt output signal(as examined indirectly via IST) from the SCSP appears to be delayed somewhat;
 is the SCU buffering writes, or is the SCSP, or is it something else entirely?

 Reads from A-bus and B-bus are treated by the SCU as always 32-bit, regardless of the actual size(writes are handled properly, though).

 SCU DMA read from VRAM is reportedly unreliable?

 DMA speed for accesses to A-/B-bus, with the exceptions of A-bus CS2, should be best-case in this code
 (writes often take longer on the Saturn if the DMA write address doesn't increment).
*/

static const char* IntNames[0x20] =
{
 "VBIN",
 "VBOUT",
 "HBIN",
 "TIMER0",
 "TIMER1",
 "DSP",
 "SCSP",
 "SMPC",
 "PAD",
 "L2DMA",
 "L1DMA",
 "L0DMA",
 "DMA_ILL",
 "VDP1",
 nullptr,
 nullptr,

 "EXT0", "EXT1", "EXT2", "EXT3", "EXT4", "EXT5", "EXT6", "EXT7", "EXT8", "EXT9", "EXTA", "EXTB", "EXTC", "EXTD", "EXTE", "EXTF"
};

#include "scu_dsp_common.inc"

static void DSP_Reset(bool powering_up);

enum { DMA_UpdateTimingGran = 127 };

enum { DSP_UpdateTimingGran = 64 };	// Probably should keep it a multiple of 2.

struct DMAWriteTabS
{
 int16 write_addr_delta;
 uint8 write_size;
 uint8 compare;
};

static const struct
{
 const DMAWriteTabS acb[2/*bus*/][8/*add setting*/][4/*write align*/][12/*count*/][5];
 const DMAWriteTabS aciv1[4][24][8];
} dma_write_tab =
{
 //
 {
  {
   #include "scu_actab.inc"
  },
  {
   #include "scu_btab.inc"
  }
 },

 //
 {
  #include "scu_aciv1tab.inc"
 }
};

static struct DMALevelS
{
 uint32 StartReadAddr;
 uint32 StartWriteAddr;
 uint32 StartByteCount;

 bool ReadAdd;
 uint8 WriteAdd;

 bool Enable;
 int8 Active; // -1, 0, 1
 bool GoGoGadget;

 bool Indirect;
 bool ReadUpdate;
 bool WriteUpdate;
 uint8 SF;

 sscpu_timestamp_t FinishTime;

 //
 //
 //
 uint32 (*ReadFunc)(uint32 offset);
 uint32 WriteBus;
 //
 uint32 CurReadBase;
 uint32 CurReadSub;

 uint32 CurWriteAddr;
 uint32 CurByteCount;

 uint64 Buffer;
 //
 const DMAWriteTabS* WATable;
 //
 uint32 (*TableReadFunc)(uint32 offset);	// Also serves as a kind of "CurIndirect" cache of "Indirect" variable.
 uint32 CurTableAddr;
 bool FinalTransfer;
} DMALevel[3];

static sscpu_timestamp_t SCU_DMA_TimeCounter;
static sscpu_timestamp_t SCU_DMA_RunUntil;
static int32 SCU_DMA_ReadOverhead;	// range -whatever to 0.

static uint32 SCU_DMA_VDP1WriteIgnoreKludge;

static void RecalcDMAHalt(void);
static void CheckDMAStart(DMALevelS* d);
static void CheckDMASFByInt(unsigned int_which);
static INLINE void CheckForceDMAFinish(void);

static uint32 IAsserted;
static uint32 IPending;
static uint32 IMask;

static uint32 ABusIProhibit;
static bool RSEL;

static uint8 ILevel, IVec;

static INLINE void RecalcMasterIntOut(void)
{
 if(ILevel == 0)
 {
  static const uint8 internal_tab[16 + 1] =
  {
   0xF, 0xE, 0xD, 0xC, 0xB, 0xA, 0x9, 0x8,
   0x8, 0x6, 0x6, 0x5, 0x3, 0x2, 0x0, 0x0,
   0x0
  };

  static const uint8 external_tab[16 + 1]
  {
   0x7, 0x7, 0x7, 0x7, 0x4, 0x4, 0x4, 0x4,
   0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1,
   0x0
  };
  const uint32 ipmd = IPending &~ (int16)IMask;
  unsigned wi = MDFN_tzcount16(ipmd & 0xFFFF);
  unsigned we = MDFN_tzcount16(ipmd >> 16);
  unsigned olev, ovec, bpos;

  olev = internal_tab[wi];
  ovec = 0x40 + wi;
  bpos = wi;

  if(external_tab[we] > internal_tab[wi])
  {
   olev = external_tab[we];
   ovec = 0x50 + we;
   bpos = 16 + we;
  }

  if(olev != 0)
  {
   ILevel = olev;
   IVec = ovec;
   IPending &= ~(1U << bpos);
   SS_DBGTI(SS_DBG_SCU_INT, "[SCU] Interrupt %d/%s(level=0x%02x, vector=0x%02x) --- IPending=0x%04x", bpos, IntNames[bpos], ILevel, IVec, IPending);
  }
 }

 CPU[0].SetIRL(ILevel);
}

static int32 Timer0_Counter;
static int32 Timer0_Compare;
static bool Timer0_Met;

static int32 Timer1_Reload;
static int32 Timer1_Counter;
static bool Timer1_Mode;
static bool Timer1_Met;

static bool Timer_Enable;

static bool HB_FromVDP2, VB_FromVDP2;

//
//
//

static uint8 SCU_MSH2VectorFetch(void)
{
 uint8 ret = IVec;

 if(MDFN_UNLIKELY(ILevel == 0))
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] [MSH2] [BUG] SCU_MSH2VectorFetch() called when ILevel == 0\n");
 }
 else
 {
  SS_DBGTI(SS_DBG_SCU_INT, "[SCU] Interrupt level=0x%02x cleared via vector fetch.", ILevel);
 }

 if(MDFN_UNLIKELY(IVec == 0x40 /* || IVec == 0x41 */))	// VB In, apply cheats.
  MDFNMP_ApplyPeriodicCheats();

 IMask = 0xBFFF;

 ILevel = 0;
 RecalcMasterIntOut();

 return ret;
}

static uint8 SCU_SSH2VectorFetch(void)
{
 if(VB_FromVDP2)
  return 0x43;

 return 0x41;
// return 0xFF;	// FIXME?
}

static INLINE void ABusIRQCheck(void)
{
 const uint32 tt = (ABusIProhibit ^ IAsserted) & (IAsserted & ~0xFFFF);

 IPending |= tt;
 ABusIProhibit |= IAsserted & ~0xFFFF;

 if(tt)
  RecalcMasterIntOut();
}

static INLINE void SetInt(unsigned which, bool active)
{
 const uint32 old_IAsserted = IAsserted;

 IAsserted &= ~(1U << which);
 IAsserted |= (unsigned)active << which;

 if(which >= 16)
  ABusIRQCheck();
 else
 {
  if((old_IAsserted ^ IAsserted) & IAsserted)
  {
   if(!(IPending & (1U << which)))
    SS_DBGTI(SS_DBG_SCU_INT, "[SCU] Interrupt %d/%s pending.", which, IntNames[which]);

   IPending |= 1U << which;
   CheckDMASFByInt(which);
   RecalcMasterIntOut();
  }
 }
}

void SCU_SetInt(unsigned which, bool active)
{
 SetInt(which, active);
}

static INLINE void Timer0_Check(void)
{
 if(Timer_Enable)
 {
  Timer0_Met = (Timer0_Counter == Timer0_Compare);
  SetInt(SCU_INT_TIMER0, Timer0_Met);
 }
}

static INLINE void Timer1_Check(void)
{
 if(Timer_Enable)
 {
  Timer1_Met |= (Timer1_Counter == 0 && (!Timer1_Mode || Timer0_Met));
  SetInt(SCU_INT_TIMER1, Timer1_Met);
 }
}

int32 SCU_SetHBVB(int32 pclocks, bool new_HB_FromVDP2, bool new_VB_FromVDP2)
{
 const bool HB_Start = (HB_FromVDP2 ^ new_HB_FromVDP2) & new_HB_FromVDP2;
 const bool VB_End   = (VB_FromVDP2 ^ new_VB_FromVDP2) & VB_FromVDP2;

 if(Timer_Enable)
 {
  if(VB_End)
   Timer0_Counter = 0;

  if(HB_Start)
   Timer0_Counter = (Timer0_Counter + 1) & 0x1FF;

  Timer0_Check();

  if(pclocks > 0)
  {
   Timer1_Counter = (Timer1_Counter - pclocks) & 0x1FF;
   Timer1_Check();
  }

  if(Timer1_Met && HB_Start)
  {
   Timer1_Met = false;
   Timer1_Counter = Timer1_Reload;

   SetInt(SCU_INT_TIMER1, Timer1_Met);
  }
 }

 SetInt(SCU_INT_HBIN, new_HB_FromVDP2);
 SetInt(SCU_INT_VBIN, new_VB_FromVDP2);
 SetInt(SCU_INT_VBOUT, !new_VB_FromVDP2);

 //
 //
 CPU[1].SetIRL(((new_VB_FromVDP2 | new_HB_FromVDP2) << 1) | (new_VB_FromVDP2 << 2));
 //
 //
 //
 HB_FromVDP2 = new_HB_FromVDP2;
 VB_FromVDP2 = new_VB_FromVDP2;

 return Timer1_Counter ? Timer1_Counter : 0x200;
}

static void SCU_AdjustTS(const int32 delta)
{
 SCU_DMA_TimeCounter += delta;
 SCU_DMA_RunUntil += delta;
 for(auto& d : DMALevel)
 {
  if(d.Active < 0)
   d.FinishTime += delta;
 }

 //
 //
 //
 if(DSP.T0_Until > 0x10000000)
  DSP.T0_Until = 0x10000000;

 DSP.LastTS += delta;
 if(DSP.LastTS < 0)
 {
  // TODO: Fix properly.
  //printf("%d\n", DSP.LastTS);
  DSP.LastTS = 0;
 }
}

//
// TODO: Test to see if the entire data bus or only parts are asserted for uint8 and uint16 reads
//
template<typename T, bool IsWrite>
static INLINE void SCU_RegRW_DB(uint32 A, uint32* DB)
{
 unsigned mask;

 switch(sizeof(T))
 {
  case 1: mask = 0xFF << (((A & 3) ^ 3) << 3); break;
  case 2: mask = 0xFFFF << (((A & 2) ^ 2) << 3); break;
  case 4: mask = 0xFFFFFFFF; break;
 }

 if(IsWrite)
 {
  SS_DBGTI(SS_DBG_SCU_REGW, "[SCU] %zu-byte write to 0x%02x, DB=0x%08x", sizeof(T), A & 0xFC, *DB);

  switch(A & 0xFC)
  {
   default:
	SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Unknown %zu-byte write to 0x%08x(DB=0x%08x).\n", sizeof(T), A, *DB);
	break;

   case 0x90:	// Timer 0 Compare
	{
	 VDP2::Update(SH7095_mem_timestamp);
	 Timer0_Compare = (Timer0_Compare &~ mask) | (*DB & mask & 0x3FF);
	 SS_SetEventNT(&events[SS_EVENT_VDP2], VDP2::Update(SH7095_mem_timestamp));
	}
	break;

   case 0x94:	// Timer 1 Reload Value
	{
	 VDP2::Update(SH7095_mem_timestamp);
	 Timer1_Reload = (Timer1_Reload &~ mask) | (*DB & mask & 0x1FF);
	 SS_SetEventNT(&events[SS_EVENT_VDP2], VDP2::Update(SH7095_mem_timestamp));
	}
	break;

   case 0x98:	// Timer Control
	{
	 VDP2::Update(SH7095_mem_timestamp);
	 uint32 tmp = (Timer1_Mode << 8) | (Timer_Enable << 0);
	 tmp = (tmp &~ mask) | (*DB & mask);
	 Timer1_Mode = (tmp >> 8) & 1;
	 Timer_Enable = (tmp >> 0) & 1;

	 if(!Timer_Enable)
	 {
	  Timer0_Counter = 0;
	 }

	 SS_SetEventNT(&events[SS_EVENT_VDP2], VDP2::Update(SH7095_mem_timestamp));
	}
	break;

   case 0xA0:
	SS_DBGTI(SS_DBG_SCU_INT, "[SCU] Write to IMS: 0x%04x --- ILevel=0x%02x, vector=0x%02x IPending=0x%04x", *DB, ILevel, IVec, IPending);
	IMask = (IMask &~ mask) | (*DB & mask & 0xBFFF);
	RecalcMasterIntOut();
	break;

   case 0xA4:
	SS_DBGTI(SS_DBG_SCU_INT, "[SCU] Write to IST: 0x%04x --- ILevel=0x%02x, vector=0x%02x IPending=0x%04x", *DB, ILevel, IVec, IPending);
	IPending &= *DB | ~mask;
	RecalcMasterIntOut();
	break;

   case 0xA8:
	if(*DB & mask & 0x0001)
	{
	 ABusIProhibit = 0; //&= ~IAsserted;
	 ABusIRQCheck();
	}
	break;

   case 0xC4:
	RSEL = (RSEL &~ mask) | (*DB & mask & 0x1);
	if(MDFN_UNLIKELY(!RSEL))
	{
	 SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Write to RSEL, RSEL=0\n");
	}
	break;

   case 0x00:
   case 0x20:
   case 0x40:
	{
	 auto& d = DMALevel[(A >> 5) & 0x3];

	 d.StartReadAddr = (d.StartReadAddr &~ mask) | (*DB & mask & 0x07FFFFFF);
	}
	break;

   case 0x04:
   case 0x24:
   case 0x44:
	{
	 auto& d = DMALevel[(A >> 5) & 0x3];

	 d.StartWriteAddr = (d.StartWriteAddr &~ mask) | (*DB & mask & 0x07FFFFFF);
	}
	break;

   case 0x08:
   case 0x28:
   case 0x48:
	{
	 const unsigned level = (A >> 5) & 0x3;
	 auto& d = DMALevel[level];

	 d.StartByteCount = (d.StartByteCount &~ mask) | (*DB & mask & (level ? 0x00000FFF : 0x000FFFFF));
        }
	break;

   case 0x0C:
   case 0x2C:
   case 0x4C:
	{
	 auto& d = DMALevel[(A >> 5) & 0x3];
	 uint32 tmp = (d.ReadAdd << 8) | (d.WriteAdd << 0);

	 tmp = (tmp &~ mask) | (*DB & mask);

	 d.ReadAdd = (tmp >> 8) & 0x1;
	 d.WriteAdd = (tmp >> 0) & 0x7;
	}
	break;

   case 0x10:
   case 0x30:
   case 0x50:
	{
	 const unsigned level = (A >> 5) & 0x3;
	 auto& d = DMALevel[level];
	 uint32 tmp = (d.Enable << 8);

	 tmp = (tmp &~ mask) | (*DB & mask);	 
	 d.Enable = (tmp >> 8) & 0x1;

	 if((tmp & 0x1) && d.Enable && d.SF == 0x7)
	 {
	  SCU_UpdateDMA(SH7095_mem_timestamp);

	  d.GoGoGadget = true;
	  CheckDMAStart(&d);

	  SS_SetEventNT(&events[SS_EVENT_SCU_DMA], SCU_UpdateDMA(SH7095_mem_timestamp));
	 }
	}
	break;

   case 0x14:
   case 0x34:
   case 0x54:
	{
	 auto& d = DMALevel[(A >> 5) & 0x3];
	 uint32 tmp = (d.Indirect << 24) | (d.ReadUpdate << 16) | (d.WriteUpdate << 8) | (d.SF << 0);

	 tmp = (tmp &~ mask) | (*DB & mask);

	 d.Indirect = (tmp >> 24) & 0x1;
	 d.ReadUpdate = (tmp >> 16) & 0x1;
	 d.WriteUpdate = (tmp >> 8) & 0x1;
	 d.SF = (tmp >> 0) & 0x7;
	}
	break;

   case 0x60:
	// TODO: Test
	if(*DB & mask & 0x1)
	{
	 SCU_DMA_ReadOverhead = 0;
	 for(unsigned level = 0; level < 3; level++)
	 {
	  auto& d = DMALevel[level];

	  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Forced stop of DMA level %u\n", level);

	  d.Active = false;
	  d.GoGoGadget = false;
	 }
	 RecalcDMAHalt();
	}
	break;

   case 0x80:
	SCU_UpdateDSP(SH7095_mem_timestamp);

	if(*DB & (1U << 25))	// Pause start
	 DSP.State |= DSPS::STATE_MASK_PAUSE;
	else if(*DB & (1U << 26))	// Pause stop
	 DSP.State &= ~DSPS::STATE_MASK_PAUSE;
	else
	{
	 if(*DB & (1U << 16))	// Execute
	  DSP.State |= DSPS::STATE_MASK_EXECUTE;
	 else if(!(*DB & (1U << 16)))	// Execute stop
	 {
	  if(DSP.State & DSPS::STATE_MASK_EXECUTE)
	  {
	   DSP.NextInstr = DSP_DecodeInstruction(0);
	   DSP.State &= ~DSPS::STATE_MASK_EXECUTE;

	   if(DSP.CycleCounter < 0)
	    DSP.CycleCounter = 0;

	   if(DSP.T0_Until < 0)
	    DSP.T0_Until = 0;
	  }
	 }

	 if(MDFN_UNLIKELY(*DB & (1U << 17)))	// Step
	 {
	  if(DSP.State == 0)
	  {
	   ((void (*)(void))(DSP_INSTR_BASE_UIPT + (uintptr_t)(DSP_INSTR_RECOVER_TCAST)DSP.NextInstr))();
	   if(DSP.CycleCounter < -(DSP_EndCCSubVal / 2))	// Ugh
	    DSP.CycleCounter += DSP_EndCCSubVal;
	  }
	 }
        }

	if(*DB & (1U << 15))	// PC load
	 DSP.PC = *DB;

	SS_SetEventNT(&events[SS_EVENT_SCU_DSP], (DSP.IsRunning() ? SH7095_mem_timestamp + (DSP_UpdateTimingGran / 2) : SS_EVENT_DISABLED_TS));
	break;

   case 0x84:
	if(!DSP.IsRunning())
	 DSP.ProgRAM[DSP.PC++] = DSP_DecodeInstruction(*DB);
	break;

   case 0x88:
	DSP.RA = *DB;
	break;

   case 0x8C:
	if(!DSP.IsRunning())
	 MDAP(DSP.DataRAM)[DSP.RA++] = *DB;
	break;
  }
 }
 else
 {
  switch(A & 0xFC)
  {
   default:
	SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Unknown %zu-byte read from 0x%08x.\n", sizeof(T), A);
	*DB = 0;
	break;

   case 0xA4:
	*DB = IPending;
	break;

   case 0xA8:
	*DB = 0; //ABusIAck;
	break;

   case 0xC4:
	*DB = RSEL;
	break;

   case 0xC8:
	*DB = 0x4;
	break;
   //
   //
   //
   case 0x00:
   case 0x20:
   case 0x40:
	{
	 auto const& d = DMALevel[(A >> 5) & 0x3];

	 *DB = d.StartReadAddr;
	}
	break;

   case 0x04:
   case 0x24:
   case 0x44:
	{
	 auto const& d = DMALevel[(A >> 5) & 0x3];

	 *DB = d.StartWriteAddr;
	}
	break;

   case 0x7C:
	{
	 uint32 tmp = 0;

	 for(unsigned level = 0; level < 3; level++)
	 {
	  auto& d = DMALevel[level];

	  if(d.Active)
	  {
	   tmp |= 0x10 << (level << 2);
	  }
	 }

	 if(DMALevel[0].Active && (DMALevel[1].Active || DMALevel[2].Active))
	  tmp |= 1U << 16;

	 if(DMALevel[1].Active && DMALevel[2].Active)
	  tmp |= 1U << 17;

	 *DB = tmp;
	}
	break;

   case 0x80:
	SS_SetEventNT(&events[SS_EVENT_SCU_DSP], SCU_UpdateDSP(SH7095_mem_timestamp));	// TODO: Remove?
	{
	 uint32 tmp;

	 tmp = DSP.PC;
	 tmp |= (DSP.T0_Until < DSP.CycleCounter) << 23;
	 tmp |= DSP.FlagS << 22;
	 tmp |= DSP.FlagZ << 21;
	 tmp |= DSP.FlagC << 20;
	 tmp |= DSP.FlagV << 19;
	 tmp |= DSP.FlagEnd << 18;
	 tmp |= DSP.IsRunning() << 16;
	 *DB = tmp;
	 //
	 DSP.FlagV = false;
	 DSP.FlagEnd = false;
	 SCU_SetInt(SCU_INT_DSP, false);
	}
	break;

   case 0x8C:
	if(!DSP.IsRunning())
	 *DB = MDAP(DSP.DataRAM)[DSP.RA++];
	else
	 *DB = 0xFFFFFFFF;
	break;
  }
 }
}


template<typename T, bool IsWrite, bool SH32 = false>
static INLINE void BBusRW_DB(uint32 A, uint16* DB, int32* time_thing, int32* dma_time_thing = NULL, int32* sh2_dma_time_thing = NULL)	// add to time_thing, subtract from dma_time_thing
{
 static_assert(IsWrite || sizeof(T) == 2, "Wrong type.");

 //
 // VDP1
 //
 if(A >= 0x05C00000 && A <= 0x05D7FFFF)
 {
  if(sh2_dma_time_thing != NULL)
   *sh2_dma_time_thing -= IsWrite ? (SH32 ? 0 : 6) : 10;

  if(dma_time_thing != NULL)
  {
   *dma_time_thing -= 1;

   if(IsWrite)
   {
    if(MDFN_UNLIKELY(A >= 0x05D00000))
    {
     const bool ignore_write = (A >= 0x5D00004 && SCU_DMA_VDP1WriteIgnoreKludge > 0) | (SCU_DMA_VDP1WriteIgnoreKludge & 0x1);

     SCU_DMA_VDP1WriteIgnoreKludge++;
     if(ignore_write)
      return;
     //printf("%08x %04x\n", A, *DB);
    }
    else
     SCU_DMA_VDP1WriteIgnoreKludge = 0;
   }
  }

  if(time_thing != NULL)
  {
   if(IsWrite)
    *time_thing += SH32 ? 0 : 11;
   else
    *time_thing += 14;

   CheckEventsByMemTS();
  }

  if(IsWrite)
  {
   if(sizeof(T) == 1)
    VDP1::Write8_DB(A, *DB);
   else
    VDP1::Write16_DB(A, *DB);
  }
  else
  {
   *DB = VDP1::Read16_DB(A);
  }

  return;
 }

 //
 // VDP2
 //
 if(A >= 0x05E00000 && A <= 0x05FBFFFF)
 {
  if(sh2_dma_time_thing != NULL)
   *sh2_dma_time_thing -= IsWrite ? (SH32 ? 0 : 5) : 10;

  if(dma_time_thing != NULL)
  {
   *dma_time_thing -= 1;
  }

  if(time_thing != NULL)
  {
   if(IsWrite)
    *time_thing += SH32 ? 0 : 5;
   else
    *time_thing += 20;

   CheckEventsByMemTS();
  }

  if(IsWrite)
  {
   uint32 expenalty;

   if(sizeof(T) == 1)
    expenalty = VDP2::Write8_DB(A, *DB);
   else
    expenalty = VDP2::Write16_DB(A, *DB);

   if(dma_time_thing != NULL)
   {
    //if(expenalty)
    // printf("%u\n", expenalty);

    *dma_time_thing -= expenalty;
   }
  }
  else
  {
   *DB = VDP2::Read16_DB(A);
  }

  return;
 }

 //
 // SCSP
 // 
 if(A >= 0x05A00000 && A <= 0x05BFFFFF)
 {
  if(sh2_dma_time_thing != NULL)
   *sh2_dma_time_thing -= 13;

  if(dma_time_thing != NULL)
  {
   *dma_time_thing -= 13;
  }

  if(time_thing != NULL)
  {
   if(IsWrite)
    *time_thing += SH32 ? 13 : 19;
   else
    *time_thing += 24;
  }

  if(IsWrite)
  {
   if(sizeof(T) == 1)
    SOUND_Write8(A & 0x1FFFFF, *DB >> (((A & 1) ^ 1) << 3));
   else
    SOUND_Write16(A & 0x1FFFFF, *DB);
  }
  else
   *DB = SOUND_Read16(A & 0x1FFFFF); 

  return;
 }
 //
 //
 //
 if(sh2_dma_time_thing != NULL)
  *sh2_dma_time_thing -= 1;

 if(dma_time_thing != NULL)
  *dma_time_thing -= 1;

 if(IsWrite)
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[B-Bus] Unknown %zu-byte write of 0x%08x(DB=0x%04x)\n", sizeof(T), A, *DB);
 else
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[B-Bus] Unknown %zu-byte read from 0x%08x\n", sizeof(T), A);

  *DB = 0;
 }
}

template<typename T, bool IsWrite, bool SH32 = false>
static INLINE void ABusRW_DB(uint32 A, uint16* DB, int32* time_thing, int32* dma_time_thing = NULL, int32* sh2_dma_time_thing = NULL)	// add to time_thing, subtract from dma_time_thing
{
 //
 // A-Bus CS0 and CS1
 //
 if(A >= 0x02000000 && A <= 0x04FFFFFF)
 {
  // [(bool)(A & 0x04000000)]

  if(sh2_dma_time_thing != NULL)
   *sh2_dma_time_thing -= 1;	// TODO

  if(dma_time_thing != NULL)
   *dma_time_thing -= 1;	// TODO

  if(IsWrite)
  {
   if(sizeof(T) == 1)
    CART_CS01_Write8_DB(A, DB);
   else
    CART_CS01_Write16_DB(A, DB);
  }
  else
   CART_CS01_Read16_DB(A, DB);

  return;
 }

 //
 // A-bus Dummy
 //
 if(MDFN_UNLIKELY(A >= 0x05000000 && A <= 0x057FFFFF))
 {
  if(sh2_dma_time_thing != NULL)
   *sh2_dma_time_thing -= 16;

  if(dma_time_thing != NULL)
  {
   *dma_time_thing -= 16;
  }

  if(IsWrite)
   SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[A-Bus CSD] Unknown %zu-byte write to 0x%08x(DB=0x%04x)\n", sizeof(T), A, *DB);
  else
   SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[A-Bus CSD] Unknown %zu-byte read from 0x%08x\n", sizeof(T), A);

  return;
 }


 //
 // A-Bus CS2
 //
 if(A >= 0x05800000 && A <= 0x058FFFFF)
 {
  if(sh2_dma_time_thing != NULL)
   *sh2_dma_time_thing -= 8;

  if(dma_time_thing != NULL)
  {
   *dma_time_thing -= 8;
  }

  if(time_thing)
  {
   if(IsWrite)
    *time_thing += 8;
   else
    *time_thing += 8;
  }

  if((A & 0x7FFF) < 0x1000)
  {
   const uint32 offset = (A & 0x3F) >> 2;
   const uint32 mask = (sizeof(T) == 2) ? 0xFFFF : (0xFF << (((A & 1) ^ 1) << 3));

   if(IsWrite)
   {
    CDB_Write_DBM(offset, *DB, mask);
   }
   else
   {
    if(!SH32 || !(A & 0x80000)) // CD block seems to effectively ignore second read access in 32-bit reads somehow, tested to occur HIRQ and the FIFO at least...
     *DB = CDB_Read(offset);
   }
   return;
  }

  if(IsWrite)
  {
   if(sizeof(T) == 1)
    CART_CS2_Write8_DB(A, DB);
   else
    CART_CS2_Write16_DB(A, DB);
  }
  else
   CART_CS2_Read16_DB(A, DB);

  return;
 }

 if(sh2_dma_time_thing != NULL)
  *sh2_dma_time_thing -= 1;

 if(dma_time_thing != NULL)
  *dma_time_thing -= 1;

 if(IsWrite)
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[A-Bus] Unknown %zu-byte write to 0x%08x(DB=0x%04x)\n", sizeof(T), A, *DB);
 else
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[A-Bus] Unknown %zu-byte read from 0x%08x\n", sizeof(T), A);
}

template<typename T>
static INLINE void ABus_Write_DB32(uint32 A, uint32 DB32, int32* time_thing, int32* dma_time_thing = NULL, int32* sh2_dma_time_thing = NULL)
{
 if(sizeof(T) == 4)
 {
  uint16 tmp;

  tmp = DB32 >> 16;
  ABusRW_DB<uint16, true>(A, &tmp, time_thing, dma_time_thing, sh2_dma_time_thing);

  tmp = DB32 >> 0;
  ABusRW_DB<uint16, true, true>(A | 2, &tmp, time_thing, dma_time_thing, sh2_dma_time_thing);
 }
 else
 {
  uint16 tmp = DB32 >> (((A & 2) ^ 2) << 3);

  ABusRW_DB<T, true>(A, &tmp, time_thing, dma_time_thing, sh2_dma_time_thing);
 }
}

// Lower 2 bits of A should be 0
static INLINE uint32 ABus_Read(uint32 A, int32* time_thing, int32* dma_time_thing = NULL, int32* sh2_dma_time_thing = NULL)
{
 uint32 ret;
 uint16 tmp = 0xFFFF;

 ABusRW_DB<uint16, false>(A, &tmp, time_thing, dma_time_thing, sh2_dma_time_thing);
 ret = tmp << 16;

 ABusRW_DB<uint16, false, true>(A | 2, &tmp, time_thing, dma_time_thing, sh2_dma_time_thing);
 ret |= tmp << 0;

 return ret;
}

template<typename T, bool IsWrite>
static INLINE void SCU_FromSH2_BusRW_DB(uint32 A, uint32* DB, int32* SH2DMAHax)
{
 //
 // A bus
 //
 if(A >= 0x02000000 && A <= 0x058FFFFF)
 {
  CheckForceDMAFinish();

  if(IsWrite)
   ABus_Write_DB32<T>(A, *DB, SH2DMAHax ? NULL : &SH7095_mem_timestamp, NULL, SH2DMAHax);
  else // A-bus reads are always 32-bit(divided into two 16-bit accesses internally)
   *DB = ABus_Read(A &~ 0x3, SH2DMAHax ? NULL : &SH7095_mem_timestamp, NULL, SH2DMAHax);

  return;
 }


 //
 // B bus
 //
 if(A >= 0x05A00000 && A <= 0x05FBFFFF)
 {
  CheckForceDMAFinish();

  if(IsWrite)
  {
   if(sizeof(T) == 4)
   {
    uint16 tmp;

    tmp = *DB >> 16;
    BBusRW_DB<uint16, true>(A, &tmp, SH2DMAHax ? NULL : &SH7095_mem_timestamp, NULL, SH2DMAHax);

    tmp = *DB >> 0;
    BBusRW_DB<uint16, true, true>(A | 2, &tmp, SH2DMAHax ? NULL : &SH7095_mem_timestamp, NULL, SH2DMAHax);
   }
   else
   {
    uint16 tmp = *DB >> (((A & 2) ^ 2) << 3);

    BBusRW_DB<T, true>(A, &tmp, SH2DMAHax ? NULL : &SH7095_mem_timestamp, NULL, SH2DMAHax);
   }
  }
  else // B-bus reads are always 32-bit(divided into two 16-bit accesses internally)
  {
   uint16 tmp = 0;

   BBusRW_DB<uint16, false>(A, &tmp, SH2DMAHax ? NULL : &SH7095_mem_timestamp, NULL, SH2DMAHax);
   *DB = tmp << 16;

   BBusRW_DB<uint16, false, true>(A | 2, &tmp, SH2DMAHax ? NULL : &SH7095_mem_timestamp, NULL, SH2DMAHax);
   *DB |= tmp << 0;
  }
  return;
 }


 //
 // SCU registers
 //
 if(A >= 0x05FE0000 && A <= 0x05FEFFFF)
 {
  if(!SH2DMAHax)
  {
   SH7095_mem_timestamp += IsWrite ? 4 : 8;
   CheckEventsByMemTS();
  }
  else
   *SH2DMAHax -= IsWrite ? 4 : 8;

  SCU_RegRW_DB<T, IsWrite>(A, DB);
  return;
 }

 // TODO: (investigate 0x5A80000-0x5AFFFFF open bus region)
 //
 //if(A >= 0x05A00000 && A <= 0x05BFFFFF)
 //{
 // return 0;
 //}

 if(IsWrite)
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SH2->SCU BUS] Unknown %zu-byte write to 0x%08x(DB=0x%08x)\n", sizeof(T), A, *DB);
 else
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SH2->SCU BUS] Unknown %zu-byte read from 0x%08x\n", sizeof(T), A);

 if(!SH2DMAHax)
  SH7095_mem_timestamp += IsWrite ? 4 : 7;
 else
  *SH2DMAHax -= IsWrite ? 4 : 7;
}





//
// Offset should have lower 2 bits as 0.
//
static uint32 DMA_ReadABus(uint32 offset)
{
 return ABus_Read(offset, NULL, &SCU_DMA_ReadOverhead);
}

static uint32 DMA_ReadBBus(uint32 offset)
{
 uint32 ret;
 uint16 tmp = 0;

 BBusRW_DB<uint16, false>(offset | 0, &tmp, NULL, &SCU_DMA_ReadOverhead);
 ret = tmp << 16;

 BBusRW_DB<uint16, false, true>(offset | 2, &tmp, NULL, &SCU_DMA_ReadOverhead);
 ret |= tmp << 0;

 return ret;
}

static uint32 DMA_ReadCBus(uint32 offset)
{
 return ne16_rbo_be<uint32>(WorkRAMH, offset & 0xFFFFC);
}

static INLINE int AddressToBus(uint32 A)
{
 int ret = -1;

 if(A >= 0x02000000 && A <= 0x058FFFFF)
  ret = 0;
 else if(A >= 0x05A00000 && A <= 0x05FBFFFF)
  ret = 1;
 else if(A >= 0x06000000)
  ret = 2;

 return ret;
}

static uint32 (*const rftab[3])(uint32) = { DMA_ReadABus, DMA_ReadBBus, DMA_ReadCBus };

static bool StartDMATransfer(DMALevelS* d, const uint32 ra, const uint32 wa, const uint32 bc)
{
 int rb, wb;

 SCU_DMA_VDP1WriteIgnoreKludge = 0;

 rb = AddressToBus(ra);
 wb = AddressToBus(wa);

 SS_DBGTI(SS_DBG_SCU, "[SCU] Starting DMA level %d transfer; ra=0x%08x wa=0x%08x bc=0x%08x - read_inc=%d write_inc=0x%01x - indirect=%d %d", (int)(d - DMALevel), ra, wa, bc, d->ReadAdd, d->WriteAdd, d->Indirect, d->SF);

 if(MDFN_UNLIKELY(rb == -1))
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Attempted DMA from illegal address 0x%08x\n", ra);
  return false;
 }

 if(MDFN_UNLIKELY(wb == -1))
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Attempted DMA to illegal address 0x%08x\n", wa);
  return false;
 }

 if(MDFN_UNLIKELY(rb == wb))
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Attempted illegal same-bus DMA from 0x%08x to 0x%08x\n", ra, wa);
  return false;
 }

 //
 //
 //
 if((wa & 0x1) && wb == 1 && d->WriteAdd != 0x1)
 {
  //
  // This sort of DMA is buggy on real hardware in weird ways(like the bus state controller is getting seriously confused), which we don't emulate.
  //
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Sketchy DMA of 0x%08x bytes from 0x%08x to unaligned B-bus address 0x%08x with write add value 0x%02x\n", bc, ra, wa, d->WriteAdd);
 }

 if(wb == 0)
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Possibly sketchy DMA of 0x%08x bytes from 0x%08x to A-bus address 0x%08x\n", bc, ra, wa);
 }

 d->CurReadBase = ra &~ 0x3;
 d->CurReadSub = ra & 0x3;

 d->CurWriteAddr = wa;

 d->CurByteCount = bc;

 d->ReadFunc = rftab[rb];
 d->WriteBus = wb;

 d->Buffer = d->ReadFunc(d->CurReadBase);

 if(wb != 0x1 && d->WriteAdd == 0x1)
  d->WATable = &dma_write_tab.aciv1[wa & 0x3][(bc < 16) ? bc : (16 | (bc & 0x7))][0];
 else
  d->WATable = &dma_write_tab.acb[wb == 1][d->WriteAdd][wa & 0x3][(bc < 12) ? bc : (8 | (bc & 0x3))][0];

 return true;
}

static bool NextIndirect(DMALevelS* d)
{
 // count, dest, src
 uint32 tmp[3];

 SS_DBG(SS_DBG_SCU, "[SCU] DMA level %d reading indirect table entries @ 0x%08x\n", (int)(d - DMALevel), d->CurTableAddr);

 for(unsigned i = 0; i < 3; i++)
 {
  tmp[i] = d->TableReadFunc(d->CurTableAddr);
  d->CurTableAddr += (d->ReadAdd ? 4 : 0);
 }

 d->FinalTransfer = (bool)(tmp[2] & 0x80000000);

 tmp[0] &= 0xFFFFF;

 if(!tmp[0])
  tmp[0] = 0x100000;

 return StartDMATransfer(d, tmp[2] & 0x07FFFFFF, tmp[1] & 0x07FFFFFF, tmp[0]);
}

bool SCU_CheckVDP1HaltKludge(void)
{
 bool ret = false;

 for(int level = 2; level >= 0; level--)
 {
  DMALevelS* d = &DMALevel[level];

  if(d->Active > 0)
  {
   if(d->WriteBus == 1 && d->ReadFunc == DMA_ReadCBus && d->CurWriteAddr >= 0x5C00000 && d->CurWriteAddr <= 0x5DFFFFF)
    ret = true;
   //else if(d->WriteBus == 2 && d->ReadFunc == DMA_ReadBBus && d->CurReadBase >= 0x5C00000 && d->CurReadBase <= 0x5C7FFFF)
   // ret = true;

   break;
  }
 }

 return ret;
}

static void RecalcDMAHalt(void)
{
 bool Halted = false;

 for(int level = 2; level >= 0; level--)
 {
  DMALevelS* d = &DMALevel[level];

  if(d->Active > 0)
  {
   if(d->WriteBus == 2 || d->ReadFunc == DMA_ReadCBus)
    Halted = true;
#if 1
   //
   // TODO: See how halting works when a higher-priority DMA A-bus<->B-bus is running at the same time as a lower priority A/B-bus<->C-bus DMA.
   //	    For now, just print a warning message if such a situation occurs.
   else
   {
    for(int sl = level - 1; sl >= 0; sl--)
    {
     DMALevelS* sld = &DMALevel[sl];
     if(sld->Active && (sld->WriteBus == 2 || sld->ReadFunc == DMA_ReadCBus))
     {
      SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Higher priority A-bus<->B-bus DMA(level %d) running while lower-priority A-/B-bus<->C-bus DMA(level %d) is pending.\n", level, sl);
     }
    }
   }
#endif
   break;
  }
 }

 //fprintf(stderr, "SCU: %d --- %d %d %d\n", Halted, DMALevel[0].Active, DMALevel[1].Active, DMALevel[2].Active);

 CPU[0].SetExtHalt(Halted);
 CPU[1].SetExtHalt(Halted);
}

// TODO: Alter write tables to use -1, 0, 1 for 1, 2, 4

static void CheckDMAStart(DMALevelS* d)
{
 if(!d->Active && d->GoGoGadget)
 {
  d->GoGoGadget = false;
  d->FinalTransfer = true;
  d->TableReadFunc = NULL;

  if(d->Indirect)
  {
   int tb;

   d->CurTableAddr = d->StartWriteAddr & 0x07FFFFFC;	// Tested, lower 2 bits are 0 on DMA end when write address update enabled.
   tb = AddressToBus(d->CurTableAddr);

   if(tb < 0)
    SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Invalid DMA indirect mode table address 0x%08x\n", d->CurTableAddr);
   else
   {
    d->TableReadFunc = rftab[tb];

    if(NextIndirect(d))
    {
     d->Active = true;
     RecalcDMAHalt();
    }
   }
  }
  else
  {
   if(!StartDMATransfer(d, d->StartReadAddr, d->StartWriteAddr, (!d->StartByteCount) ? ((d - DMALevel) ? 0x1000 : 0x100000) : d->StartByteCount))
   {
    SCU_SetInt(SCU_INT_DMA_ILL, true);
    SCU_SetInt(SCU_INT_DMA_ILL, false);
   }
   else
   {
    d->Active = true;
    RecalcDMAHalt();
   }
  }
 }
}

static void CheckDMASFByInt(unsigned int_which)
{
 static const uint8 sf_to_int_tab[7] =
 {
  SCU_INT_VBIN,	SCU_INT_VBOUT, SCU_INT_HBIN, SCU_INT_TIMER0,
  SCU_INT_TIMER1, SCU_INT_SCSP, SCU_INT_VDP1
 };

 for(unsigned level = 0; level < 3; level++)
 {
  auto& d = DMALevel[level];

  if(d.Enable && d.SF < 0x7 && sf_to_int_tab[d.SF] == int_which)
  {
   d.GoGoGadget = true;
   CheckDMAStart(&d);
  }
 }
}

template<unsigned count>
static INLINE uint32 DMA_Read(DMALevelS* d)
{
 int shift = ((0x3 ^ (d->CurReadSub & 0x3)) - (0x3 ^ (d->CurWriteAddr & 0x3 & (4 - count)))) * 8;

 //printf("Read: CurReadSub=0x%02x, CurWriteAddr=0x%08x, count=%zu --- ", d->CurReadSub, d->CurWriteAddr, count);

 d->CurReadSub += count;
 if(d->CurReadSub > 4)
 {
  if((d->CurReadSub - count) < 4)
   shift += 32;

  d->CurReadSub -= 4; //&= 0x3;
  d->CurReadBase += (d->ReadAdd ? 4 : 0);
  //
  SCU_DMA_TimeCounter -= SCU_DMA_ReadOverhead;
  SCU_DMA_ReadOverhead = 0;
  uint32 tmp = d->ReadFunc(d->CurReadBase);
  d->Buffer <<= 32;
  d->Buffer |= tmp;
 }

 //printf("buffer=%016llx, shift=%d\n", (uint64)d->Buffer, shift);

 if(shift > 0)
  return d->Buffer >> shift;
 else
  return d->Buffer << -shift;
}

template<unsigned WriteBus, typename T>
static INLINE void DMA_Write(DMALevelS* d, uint32 DB)
{
 const uint32 A = d->CurWriteAddr &~ (sizeof(T) - 1);
 int32 WriteOverhead = 0;

 //printf("Write: %zu %08x %08x\n", sizeof(T), A, DB);
 if(WriteBus == 0)
 {
  ABus_Write_DB32<T>(A, DB, NULL, &WriteOverhead);
 }
 else if(WriteBus == 1)
 {
  uint16 DB16;

  DB16 = DB >> (((A & 0x2) ^ 0x2) * 8);
  BBusRW_DB<T, true>(A, &DB16, NULL, &WriteOverhead);
 }
 else
 {
  ne16_wbo_be<T>(WorkRAMH, A & 0xFFFFF, DB >> (((A & 3) ^ (4 - sizeof(T))) << 3));
 }

 SCU_DMA_TimeCounter -= WriteOverhead;
 SCU_DMA_ReadOverhead = std::min<int32>(0, SCU_DMA_ReadOverhead - WriteOverhead);
 d->CurByteCount -= sizeof(T);
}

template<unsigned WriteBus>
static bool NO_INLINE DMA_Loop(DMALevelS* d)
{
 while(MDFN_LIKELY(d->Active > 0 && SCU_DMA_TimeCounter < SCU_DMA_RunUntil))
 {
  switch(d->WATable->write_size)
  {
   case 0x1: DMA_Write<WriteBus, uint8> (d, DMA_Read<1>(d)); break;
   case 0x2: DMA_Write<WriteBus, uint16>(d, DMA_Read<2>(d)); break;
   case 0x4: DMA_Write<WriteBus, uint32>(d, DMA_Read<4>(d)); break;
  }
  d->CurWriteAddr += d->WATable->write_addr_delta;

  if(d->CurByteCount <= (uint32)(int8)d->WATable->compare)
   d->WATable++;

  if(MDFN_UNLIKELY(!d->CurByteCount))
  {
   SCU_DMA_TimeCounter -= SCU_DMA_ReadOverhead;
   SCU_DMA_ReadOverhead = 0;
   return true;
  }
 }

 return false;
}

//
// TODO: Check start read/write address updating when wrapping to next bus or beyond end of SDRAM.
//
static INLINE void UpdateDMAInner(DMALevelS* d)
{
 static bool (*const LoopFuncs[3])(DMALevelS*) = { DMA_Loop<0>, DMA_Loop<1>, DMA_Loop<2> };

 if(MDFN_UNLIKELY(LoopFuncs[d->WriteBus](d)))
 {
  if(d->TableReadFunc && !d->FinalTransfer)
  {
   NextIndirect(d);
  }
  else
  {
   if(d->ReadUpdate && !d->TableReadFunc)
      d->StartReadAddr = (d->CurReadBase + d->CurReadSub) & 0x07FFFFFF;

   if(d->WriteUpdate)
   {
    if(d->TableReadFunc)
     d->StartWriteAddr = d->CurTableAddr & 0x07FFFFFF;
    else
     d->StartWriteAddr = d->CurWriteAddr & 0x07FFFFFF;
   }

   d->FinishTime = SCU_DMA_TimeCounter;
   d->Active = -1;
  }
 }
}

static void SCU_DoDMAEnd(const unsigned level)
{
 static const unsigned itab[3] = { SCU_INT_L0DMA, SCU_INT_L1DMA, SCU_INT_L2DMA };
 //printf("FIN: %08x %08x %u\n", d->CurReadBase, d->CurReadSub, d->ReadUpdate);
 DMALevel[level].Active = false;
 RecalcDMAHalt();
 SCU_SetInt(itab[level], true);
 SCU_SetInt(itab[level], false);
 CheckDMAStart(&DMALevel[level]);    
}

sscpu_timestamp_t SCU_UpdateDMA(sscpu_timestamp_t timestamp)
{
 if(timestamp < SH7095_mem_timestamp)
  return SH7095_mem_timestamp;
 //
 //
 //
 SCU_DMA_TimeCounter = std::max<int32>(std::min<int32>(SCU_DMA_RunUntil, timestamp), SCU_DMA_TimeCounter);
 SCU_DMA_RunUntil = timestamp + DMA_UpdateTimingGran;

 for(int level = 2; level >= 0; level--)
 {
  DMALevelS* d = &DMALevel[level];

  while(d->Active && SCU_DMA_TimeCounter < SCU_DMA_RunUntil)
  {
   UpdateDMAInner(d);

   if(MDFN_UNLIKELY(d->Active < 0))
   {
    if(MDFN_UNLIKELY(timestamp >= d->FinishTime))
     SCU_DoDMAEnd(level);
    else
     return d->FinishTime;
   }
  }
 }

 return SCU_DMA_RunUntil;
}

//
// Check to see if DMA is active, and if so, force the highest-priority DMA
// to finish early(kind of hacky).
//
static NO_INLINE void ForceDMAFinish(void)
{
 for(int level = 2; level >= 0; level--)
 {
  if(!DMALevel[level].Active)
   continue;

  SS_DBG(SS_DBG_WARNING | SS_DBG_SCU, "[SCU] Forcing hacky early DMA level %d completion.\n", level);

  if(DMALevel[level].Active > 0)
  {
   const sscpu_timestamp_t rus = SCU_DMA_RunUntil;
   //
   SCU_DMA_RunUntil = 0x7FFFFFFF;
   UpdateDMAInner(&DMALevel[level]);
   //
   SCU_DMA_RunUntil = rus;
  }

  if(DMALevel[level].Active < 0)
   SCU_DoDMAEnd(level);

  break;
 }

 SCU_DMA_TimeCounter = SCU_DMA_RunUntil;
}

static INLINE void CheckForceDMAFinish(void)
{
 if(MDFN_LIKELY(!(DMALevel[0].Active | DMALevel[1].Active | DMALevel[2].Active)))
  return;

 ForceDMAFinish();
}

//
//
//
DSPS DSP;

sscpu_timestamp_t SCU_UpdateDSP(sscpu_timestamp_t timestamp)
{
 int32 cycles = timestamp - DSP.LastTS;
 DSP.LastTS = timestamp;
 //
 //
 //
 DSP.T0_Until += cycles;	// Overflow prevented in SCU_ResetTS
 DSP.CycleCounter += cycles;
 if(DSP.CycleCounter > DSP_UpdateTimingGran)
  DSP.CycleCounter = DSP_UpdateTimingGran;

 if(MDFN_UNLIKELY(!DSP.IsRunning()))
  return SS_EVENT_DISABLED_TS;

 while(MDFN_LIKELY(DSP.CycleCounter > 0))
 {
  //printf("%02x %16llx\n", DSP.PC, DSP.NextInstr);
  ((void (*)(void))(DSP_INSTR_BASE_UIPT + (uintptr_t)(DSP_INSTR_RECOVER_TCAST)DSP.NextInstr))();
  DSP.CycleCounter -= 2;
 }

 if(MDFN_UNLIKELY(!DSP.IsRunning()))
 {
  DSP.CycleCounter += DSP_EndCCSubVal;
  return SS_EVENT_DISABLED_TS;
 }

 return timestamp + DSP_UpdateTimingGran;
}

static void DSP_Reset(bool powering_up)
{
 DSP.State = 0;
 DSP.T0_Until = 0x10000000;
 DSP.CycleCounter = 0;

 if(powering_up)
 {
  for(unsigned i = 0; i < 256; i++)
   DSP.ProgRAM[i] = DSP_DecodeInstruction(0);

  for(unsigned i = 0; i < 256; i++)
   MDAP(DSP.DataRAM)[i] = 0;
 }

 DSP.PC = 0;
 DSP.RA = 0;
 DSP.FlagZ = false;
 DSP.FlagS = false;
 DSP.FlagV = false;
 DSP.FlagC = false;
 DSP.FlagEnd = false;
 SCU_SetInt(SCU_INT_DSP, false);

 DSP.NextInstr = DSP_DecodeInstruction(0);

 DSP.TOP = 0;
 DSP.LOP = 0;

 DSP.AC.T = 0;
 DSP.P.T = 0;

 for(unsigned i = 0; i < 4; i++)
  DSP.CT[i] = 0;

 DSP.RX = 0;
 DSP.RY = 0;

 DSP.RAO = 0;
 DSP.WAO = 0;
}

void DSP_Init(void)
{
 DSP.LastTS = 0;

 for(auto* f : DSP_GenFuncTable)
  assert((uintptr_t)f == DSP_INSTR_BASE_UIPT + ((uintptr_t)(DSP_INSTR_RECOVER_TCAST)(uint32)((uintptr_t)f - DSP_INSTR_BASE_UIPT)));

 for(auto* f : DSP_DMAFuncTable)
  assert((uintptr_t)f == DSP_INSTR_BASE_UIPT + ((uintptr_t)(DSP_INSTR_RECOVER_TCAST)(uint32)((uintptr_t)f - DSP_INSTR_BASE_UIPT)));

 for(auto* f : DSP_MVIFuncTable)
  assert((uintptr_t)f == DSP_INSTR_BASE_UIPT + ((uintptr_t)(DSP_INSTR_RECOVER_TCAST)(uint32)((uintptr_t)f - DSP_INSTR_BASE_UIPT)));

 for(auto* f : DSP_JMPFuncTable)
  assert((uintptr_t)f == DSP_INSTR_BASE_UIPT + ((uintptr_t)(DSP_INSTR_RECOVER_TCAST)(uint32)((uintptr_t)f - DSP_INSTR_BASE_UIPT)));

 for(auto* f : DSP_MiscFuncTable)
  assert((uintptr_t)f == DSP_INSTR_BASE_UIPT + ((uintptr_t)(DSP_INSTR_RECOVER_TCAST)(uint32)((uintptr_t)f - DSP_INSTR_BASE_UIPT)));
}

template<bool looped, bool hold, bool format, bool dir, unsigned drw>
static NO_INLINE NO_CLONE void DMAInstr(void)
{
 const uint32 instr = DSP_InstrPre<looped>();
 const unsigned add_mode = (instr >> 15) & 0x7;
 uint8 count;	// 0 = 256

 if(DSP.T0_Until < DSP.CycleCounter)
 {
  // TODO: Rework how DSP DMA is handled if this condition occurs with the same data RAM bank in any games.
  if(format)
   SS_DBG(SS_DBG_WARNING | SS_DBG_SCU_DSP, "[SCU] Executing DSP DMA instruction 0x%08x before previous DMA has finished!\n", instr);

  DSP.CycleCounter = DSP.T0_Until &~ 1;
 }

 DSP.T0_Until = DSP.CycleCounter;

 if(format)
 {
  const unsigned crw = instr & 0x3;
  const bool ctinc = instr & 0x4;

  count = DSP.DataRAM[crw][DSP.CT[crw]] & 0xFF;
  DSP.CT[crw] = (DSP.CT[crw] + ctinc) & 0x3F;
 }
 else
  count = instr & 0xFF;

 //printf("%02x %08x Count: %u\n", DSP.PC, instr, count);
 SS_DBG(SS_DBG_SCU_DSP, "[SCU] DSP DMA; looped=%u, add_mode=0x%01x, hold=%u, format=%u, dir=%u, drw=0x%02x -- count=%u, RAO<<2=0x%08x, WAO<<2=0x%08x\n", looped, add_mode, hold, format, dir, drw, count, DSP.RAO << 2, DSP.WAO << 2);

 if(dir)
 {
  const uint32 addr_add_amount = (1 << add_mode) &~ 1;
  uint32 addr = (DSP.WAO << 2) & 0x07FFFFFF;
  const int WriteBus = AddressToBus(addr);

  if(MDFN_UNLIKELY(WriteBus == -1))
  {
   SS_DBG(SS_DBG_WARNING | SS_DBG_SCU | SS_DBG_SCU_DSP, "[SCU] Bad DSP DMA to 0x%08x --- Instr=0x%08x, Next_Instr=0x%08x, PC=0x%02x\n", addr, instr, (unsigned)(DSP.NextInstr >> 32), DSP.PC);
   return;
  }

  // Read from data RAM, write to external bus
  do
  {
   uint32 DB;

   if(drw & 0x4)
    DB = 0xFFFFFFFF;
   else
   {
    DB = DSP.DataRAM[drw][DSP.CT[drw]];
    DSP.CT[drw] = (DSP.CT[drw] + 1) & 0x3F;
   }

   if(WriteBus == 2)
   {
    ne16_wbo_be<uint32>(WorkRAMH, addr & 0xFFFFC, DB);
    addr += addr_add_amount;
    DSP.T0_Until -= 2;
   }
   else if(WriteBus == 1)
   {
    uint16 DB16;

    DB16 = DB >> 16;
    BBusRW_DB<uint16, true>(addr, &DB16, NULL, &DSP.T0_Until);

    addr += addr_add_amount;

    DB16 = DB;
    BBusRW_DB<uint16, true, true>(addr, &DB16, NULL, &DSP.T0_Until);

    addr += addr_add_amount;
   }
   else if(WriteBus == 0)
   {
    ABus_Write_DB32<uint32>(addr, DB, NULL, &DSP.T0_Until);

    addr += addr_add_amount;
   }
  } while(--count);

  if(!hold)
   DSP.WAO = (addr + 2) >> 2;
 }
 else
 {
  const uint32 addr_add_amount = (1 << (add_mode & 0x2)) &~ 1;
  uint32 addr = (DSP.RAO << 2) & 0x07FFFFFF;
  const int ReadBus = AddressToBus(addr);

  if(MDFN_UNLIKELY(ReadBus == -1))
  {
   SS_DBG(SS_DBG_WARNING | SS_DBG_SCU | SS_DBG_SCU_DSP, "[SCU] Bad DSP DMA from 0x%08x --- Instr=0x%08x, Next_Instr=0x%08x, PC=0x%02x\n", addr, instr, (unsigned)(DSP.NextInstr >> 32), DSP.PC);
   return;
  }

  if(drw & 0x4)
   SS_DBG(SS_DBG_WARNING | SS_DBG_SCU | SS_DBG_SCU_DSP, "[SCU] DSP DMA from 0x%08x to %s --- Instr=0x%08x, Next_Instr=0x%08x, PC=0x%02x\n", addr, ((drw == 0x4) ? "program RAM" : "unknown"), instr, (unsigned)(DSP.NextInstr >> 32), DSP.PC);

  // Read from external bus, write to data RAM or program RAM
  do
  {
   uint32 DB = 0;

   if(ReadBus == 2)
   {
    DB = ne16_rbo_be<uint32>(WorkRAMH, addr & 0xFFFFF);
    DSP.T0_Until -= 2;

    addr += addr_add_amount;
   }
   else if(ReadBus == 1)
   {
    uint16 tmp = 0;

    BBusRW_DB<uint16, false>(addr | 0, &tmp, NULL, &DSP.T0_Until);
    DB = tmp << 16;

    BBusRW_DB<uint16, false, true>(addr | 2, &tmp, NULL, &DSP.T0_Until);
    DB |= tmp << 0;

    addr += 4;
   }
   else if(ReadBus == 0)
   {
    DB = ABus_Read(addr, NULL, &DSP.T0_Until);

    addr += addr_add_amount;
   }

   if(drw & 0x4)
   {
    if(!(drw & 0x3))
    {
     DSP.ProgRAM[DSP.PC++] = DSP_DecodeInstruction(DB);
    }
   }
   else
   {
    DSP.DataRAM[drw][DSP.CT[drw]] = DB;
    DSP.CT[drw] = (DSP.CT[drw] + 1) & 0x3F;
   }
  } while(--count);

  if(!hold)
   DSP.RAO = addr >> 2;
 }
}

extern void (*const DSP_DMAFuncTable[2][8][8])(void) =
{
 #include "scu_dsp_dmatab.inc"
};

//
//
//

static void SCU_Init(void)
{
 SCU_DMA_TimeCounter = 0;
 SCU_DMA_RunUntil = 0;
 IAsserted = 0;
 HB_FromVDP2 = false;
 VB_FromVDP2 = false;

 DSP_Init();
}

void SCU_Reset(bool powering_up)
{
 ILevel = IVec = 0;
 IMask = 0xBFFF;
 IPending = 0;
 ABusIProhibit = 0;
 RSEL = 0;

 if(powering_up)
  memset(DMALevel, 0x00, sizeof(DMALevel));

 for(auto& d : DMALevel)
 {
  d.ReadAdd = true;
  d.WriteAdd = 0x1;

  d.Enable = false;
  d.GoGoGadget = false;
  d.Active = false;

  d.Indirect = false;
  d.ReadUpdate = false;
  d.WriteUpdate = false;
  d.SF = 0;

  d.WATable = &dma_write_tab.acb[0][0][0][0][0];
  d.ReadFunc = rftab[0];
  d.TableReadFunc = NULL;
 }
 //SCU_DMA_CycleCounter = 0;
 SCU_DMA_ReadOverhead = 0;

 SCU_DMA_VDP1WriteIgnoreKludge = 0;

 RecalcDMAHalt();

 DSP_Reset(powering_up);

 RecalcMasterIntOut();
}

static MDFN_COLD void SCU_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 uint32 DSP_ProgRAM[256];
 uint32 DSP_NextInstr;
 bool DSP_NextInstrLooped;
 uint32 DMALevel_WATable[3];	
 uint8 DMALevel_ReadFunc[3];		// rftab, don't allow NULL
 uint8 DMALevel_TableReadFunc[3];	// rftab, also allow NULL

 SFORMAT StateRegs[] =
 {
  SFVAR(DSP.LastTS),
  SFVAR(DSP.CycleCounter),
  SFVAR(DSP.T0_Until),
  SFVAR(DSP.State),

  SFVAR(DSP_NextInstr),
  SFVAR(DSP_NextInstrLooped),

  SFVAR(DSP.PC),
  SFVAR(DSP.RA),

  SFVAR(DSP.FlagZ),
  SFVAR(DSP.FlagS),
  SFVAR(DSP.FlagV),
  SFVAR(DSP.FlagC),

  SFVAR(DSP.FlagEnd),

  SFVAR(DSP.TOP),
  SFVAR(DSP.LOP),

  SFVAR(DSP.AC.T),
  SFVAR(DSP.P.T),

  SFVAR(DSP.CT),

  SFVAR(DSP.RX),
  SFVAR(DSP.RY),

  SFVAR(DSP.RAO),
  SFVAR(DSP.WAO),

  SFVARN(DSP.DataRAM, "&DSP.DataRAM[0][0]"),

  SFVAR(DSP_ProgRAM),

  SFVAR(DMALevel->StartReadAddr, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->StartWriteAddr, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->StartByteCount, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->ReadAdd, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->WriteAdd, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->Enable, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->Active, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->GoGoGadget, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->Indirect, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->ReadUpdate, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->WriteUpdate, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->SF, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->FinishTime, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->WriteBus, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->CurReadBase, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->CurReadSub, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->CurWriteAddr, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->CurByteCount, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->Buffer, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel_WATable),
  SFVAR(DMALevel_ReadFunc),
  SFVAR(DMALevel_TableReadFunc),
  SFVAR(DMALevel->CurTableAddr, 3, sizeof(*DMALevel), DMALevel),
  SFVAR(DMALevel->FinalTransfer, 3, sizeof(*DMALevel), DMALevel),

  SFVAR(SCU_DMA_TimeCounter),
  SFVAR(SCU_DMA_RunUntil),
  SFVAR(SCU_DMA_ReadOverhead),

  SFVAR(SCU_DMA_VDP1WriteIgnoreKludge),

  SFVAR(IAsserted),
  SFVAR(IPending),
  SFVAR(IMask),

  SFVAR(ABusIProhibit),
  SFVAR(RSEL),

  SFVAR(ILevel),
  SFVAR(IVec),

  SFVAR(Timer0_Counter),
  SFVAR(Timer0_Compare),
  SFVAR(Timer0_Met),

  SFVAR(Timer1_Reload),
  SFVAR(Timer1_Counter),
  SFVAR(Timer1_Mode),
  SFVAR(Timer1_Met),

  SFVAR(Timer_Enable),

  SFVAR(HB_FromVDP2),
  SFVAR(VB_FromVDP2),

  SFEND
 };

 //
 // Do unconditionally, and not just if !load(in case some vars are missing from save state).
 //
 for(unsigned i = 0; i < 256; i++)
  DSP_ProgRAM[i] = DSP.ProgRAM[i] >> 32;

 DSP_NextInstr = DSP.NextInstr >> 32;
 DSP_NextInstrLooped = (DSP.NextInstr == DSP_DecodeInstruction<true>(DSP.NextInstr >> 32));
 //
 //
 const DMAWriteTabS* const dwt_ptrs[2] = { (const DMAWriteTabS*)dma_write_tab.acb, (const DMAWriteTabS*)dma_write_tab.aciv1 };
 const size_t dwt_counts[2] = { sizeof(dma_write_tab.acb) / sizeof(DMAWriteTabS), sizeof(dma_write_tab.aciv1) / sizeof(DMAWriteTabS) };

 for(unsigned level = 0; level < 3; level++)
 {
  const auto& d = DMALevel[level];

  if(d.WATable >= dwt_ptrs[0] && d.WATable < (dwt_ptrs[0] + dwt_counts[0]))
   DMALevel_WATable[level] = d.WATable - dwt_ptrs[0];
  else if(d.WATable >= dwt_ptrs[1] && d.WATable < (dwt_ptrs[1] + dwt_counts[1]))
   DMALevel_WATable[level] = 0x80000000 | (d.WATable - dwt_ptrs[1]);
  else
  {
   //printf("%016llx - %016llx %08zx, %016llx %08zx\n", (unsigned long long)d.WATable, (unsigned long long)dwt_ptrs[0], dwt_counts[0], (unsigned long long)dwt_ptrs[1], dwt_counts[1]);
   abort();	// FIXME: NULL pointer on init...
  }

  for(unsigned rb = 0; rb < 3 + 1; rb++)
  {
   if(rb >= 3)
    abort();

   if(d.ReadFunc == rftab[rb])
   {
    DMALevel_ReadFunc[level] = rb;
    break;
   }
  }

  DMALevel_TableReadFunc[level] = 0xFF;
  for(unsigned trb = 0; trb < 3; trb++)
  {
   if(d.TableReadFunc == rftab[trb])
   {
    DMALevel_ReadFunc[level] = trb;
    break;
   }
  }
 }
 //
 //
 //

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "SCU");

 if(load)
 {
  for(unsigned i = 0; i < 256; i++)
   DSP.ProgRAM[i] = DSP_DecodeInstruction(DSP_ProgRAM[i]);

  if(DSP_NextInstrLooped)
   DSP.NextInstr = DSP_DecodeInstruction<true>(DSP_NextInstr);
  else
   DSP.NextInstr = DSP_DecodeInstruction(DSP_NextInstr);

  for(unsigned i = 0; i < 4; i++)
   DSP.CT[i] &= 0x3F;

  DSP.LOP &= 0xFFF;

  //
  //
  for(unsigned level = 0; level < 3; level++)
  {
   auto& d = DMALevel[level];

   d.StartReadAddr &= 0x07FFFFFF;
   d.StartWriteAddr &= 0x07FFFFFF;
   d.StartByteCount &= level ? 0x00000FFF : 0x000FFFFF;

   d.ReadAdd &= 0x1;
   d.WriteAdd &= 0x7;
   
   //
   //
   {
    bool which = DMALevel_WATable[level] >> 31;
    uint32 index = DMALevel_WATable[level] & 0x7FFFFFFF;

    if(index >= dwt_counts[which]) // || !dwt_ptrs[which][index].write_size)
     printf("bad watable %08x %zu %08x\n", DMALevel_WATable[level], dwt_counts[which], dwt_ptrs[which][index].write_size);
    else
     d.WATable = dwt_ptrs[which] + index;
   }

   if(DMALevel_ReadFunc[level] >= 3)
    printf("bad readfunc: %02x\n", DMALevel_ReadFunc[level]);
   else
    d.ReadFunc = rftab[DMALevel_ReadFunc[level]];

   if(DMALevel_TableReadFunc[level] == 0xFF)
    d.TableReadFunc = NULL;
   else if(DMALevel_TableReadFunc[level] < 3)
    d.TableReadFunc = rftab[DMALevel_TableReadFunc[level]];
   else
    printf("bad tablereadfunc: %02x\n", DMALevel_TableReadFunc[level]);
  }
 }
}



//
//
//
//
//
//
uint32 SCU_DSP_PeekProgRAM(uint8 A)
{
 return DSP.ProgRAM[A] >> 32;
}

uint32 SCU_GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 uint32 ret = 0xDEADBEEF;

 switch(id)
 {
  case SCU_GSREG_ILEVEL:
	ret = ILevel;
	break;

  case SCU_GSREG_IVEC:
	ret = IVec;
	break;

  case SCU_GSREG_IASSERTED:
	ret = IAsserted;
	break;

  case SCU_GSREG_IPENDING:
	ret = IPending;
	break;

  case SCU_GSREG_IMASK:
	ret = IMask;
	break;

  case SCU_GSREG_T0CNT:
	ret = Timer0_Counter;
	break;

  case SCU_GSREG_T0CMP:
	ret = Timer0_Compare;
	break;

  case SCU_GSREG_T0MET:
	ret = Timer0_Met;
	break;

  case SCU_GSREG_T1RLV:
	ret = Timer1_Reload;
	break;

  case SCU_GSREG_T1CNT:
	ret = Timer1_Counter;
	break;

  case SCU_GSREG_T1MOD:
	ret = Timer1_Mode;
	break;

  case SCU_GSREG_T1MET:
	ret = Timer1_Met;
	break;

  case SCU_GSREG_TENBL:
	ret = Timer_Enable;
	break;

  case SCU_GSREG_DSP_EXEC:
	ret = (bool)(DSP.State & DSPS::STATE_MASK_EXECUTE);
	break;

  case SCU_GSREG_DSP_PAUSE:
	ret = (bool)(DSP.State & DSPS::STATE_MASK_PAUSE);
	break;

  case SCU_GSREG_DSP_PC:
	ret = DSP.PC;
	break;

  case SCU_GSREG_DSP_END:
	ret = DSP.FlagEnd;
	break;
 }
 return ret;
}

void SCU_SetRegister(const unsigned id, const uint32 value)
{
 switch(id)
 {
  case SCU_GSREG_IPENDING:
	IPending = value & 0xFFFF3FFF;
	break;

  case SCU_GSREG_IMASK:
	IMask = value & 0xBFFF;
	break;
  //
  case SCU_GSREG_T0CNT:
	//Timer0_Counter = value & 0x1FF;
	break;

  case SCU_GSREG_T0CMP:
	Timer0_Compare = value & 0x3FF;
	break;

  case SCU_GSREG_T0MET:
	//Timer0_Met = value & 0x1;
	break;

  case SCU_GSREG_T1RLV:
	Timer1_Reload = value & 0x1FF;
	break;

  case SCU_GSREG_T1CNT:
	//Timer1_Counter = value & 0x1FF;
	break;

  case SCU_GSREG_T1MOD:
	Timer1_Mode = value & 0x1;
	break;

  case SCU_GSREG_T1MET:
	//Timer1_Met = value & 0x1;
	break;

  case SCU_GSREG_TENBL:
	Timer_Enable = value & 0x1;
	break;
  //

 }

 // Not quite right:
#if 0
 Timer0_Check();
 Timer1_Check();
 SCU_SetHBVB(0, HB_FromVDP2, VB_FromVDP2);
#endif

 RecalcMasterIntOut();
}

