/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* sh7095.inc - Hitachi SH7095 Emulation
**  Copyright (C) 2015-2020 Mednafen Team
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
 Emulation implementation notes/deficiencies:
	Cache multiple-way tag collisions (ostensibly an illegal condition) during reads/writes are not handled accurately.

	Overall timing is extremely approximate.

	DMA timing is very rough.  DMA burst mode probably isn't handled totally correctly, especially in
	relation to the other CPU and the SCU(is DMA burst mode even legal on the Saturn?).

	DMA channel bus priority handling is not correct(at least not for non-burst mode transfers).

	Misaligned memory accesses(that cause address errors) aren't emulated correctly(for
	future reference, there's a difference between how cache versus external bus is accessed
	for misaligned addresses, and perhaps a difference between 32-bit and 16-bit spaces as
	defined by the BSC too; and then there's misaligned OPM register access semantics...).

	Address errors occur one instruction too soon.

	SLEEP instruction, standby mode, and DMA burst stalls are handled by thoroughly (ab)using the 
	IF/ID pipeline emulation and opcode dispatch mechanism.

	Individual module clocking disabling functionality of SBYCR isn't handled.

	Interrupts are typically delayed by one instruction, but when the interrupt is handled,
	the current interrupt state is used instead of the previous interrupt state.
	This can result in the exception-handling pseudo-op code being called when there's
	no "current" exception to process, which is a quasi-error condition; there's code to log
	this condition and recover from it.  An SH-2 code sequence that can cause this condition
	if there's currently a pending/unacked interrupt:
		<interrupt-enabling instruction>
		<interrupt-acknowledging instruction>
	This cooouuuld turn out to be a problem, and if it does, it can be fixed by having two interrupt-pending variables,
	with one being copied to the other in DoIDIF().

	Emulation of SH-2 master/slave bus sharing is very approximate.  On a real SH-2, internal bus cycles may affect
	bus grant timing, need to run tests(though emulating that behavior would probably be unrealistic performance-wise).

	The SCU C-bus DMA ExtHalt kludge doesn't work totally as intended when full cache emulation is enabled(and the
	interruptible/resumable slave CPU code is used), but it proooobably won't be a problem in practice because on
	a real Saturn, after the write that triggers the SCU DMA, a few CPU bus accesses can get in before the SCU hogs the bus.

	SCI, UBC, and BSC are mostly unemulated.
*/

/* TODO:
	Check address error exception order, sleep versus exceptions.

	Make sure RecalcPendingIntPEX() is called in all places it needs to be called(which is arguably too many...).
*/

#ifdef MSB_FIRST
 #define NE32ASU8_IDX_ADJ(T, idx) (idx)
#else
 #define NE32ASU8_IDX_ADJ(T, idx) ( ((idx) & ~(sizeof(T) - 1)) ^ (4 - (sizeof(T))) )
#endif

SH7095::SH7095(const char* const name_arg, const unsigned event_id_dma_arg, uint8 (*exivecfn_arg)(void)) : event_id_dma(event_id_dma_arg), ExIVecFetch(exivecfn_arg), CBH_Setting(false), EIC_Setting(false), DM_Setting(false), cpu_name(name_arg)
{
 if(this == &CPU[1])
 {
  for(unsigned dm = 0; dm < 2; dm++)
  {
   //
   // Very fragile, be careful.
   //
   ResumePoint = nullptr;
   ResumeTableP[dm] = nullptr;
   timestamp = -1;
   FRT_WDT_NextTS = 0x7FFFFFFF;
   Pipe_ID = 0xFEU << 24;
   //
   if(dm)
    RunSlaveUntil_Debug(0);
   else
    RunSlaveUntil(0);
   //
   assert(ResumePoint == nullptr);
   assert(ResumeTableP[dm] != nullptr);
   assert(timestamp == -1);
   assert(FRT_WDT_NextTS == 0x7FFFFFFF);
   assert(Pipe_ID == (0xFEU << 24));
  }
 }
 //
 //
 Init(false, false);
}

template<unsigned which, int NeedSlaveCall, bool CacheBypassHack, typename T, unsigned region, bool CacheEnabled, int32 IsInstr>
static NO_INLINE MDFN_FASTCALL T C_MemReadRT(uint32 A) MDFN_HOT;

template<unsigned which, int NeedSlaveCall, typename T, unsigned region, bool CacheEnabled>
static NO_INLINE MDFN_FASTCALL void C_MemWriteRT(uint32 A, T V) MDFN_HOT;

// WARNING: Template arguments CacheEnabled and CacheBypassHack are only valid for region==0.
void SH7095::RecalcMRWFP_0(void)
{
 #define MAHL_(bs,w,nsc,cbh)									\
		 if(CCR & CCR_CE)								\
		 {										\
		  if(bs == 16) { MRFP16_I[0] = C_MemReadRT<w, nsc, cbh, uint16, 0x0, true, -1>; }	\
		  if(bs == 32) { MRFP32_I[0] = C_MemReadRT<w, nsc, cbh, uint32, 0x0, true, -1>; }	\
		  MRFP##bs[0] = C_MemReadRT <w, nsc, cbh, uint##bs, 0x0, true, false>;		\
		  MRFPI[0]    = C_MemReadRT <w, nsc, cbh, uint32,   0x0, true, true>;		\
		  MWFP##bs[0] = C_MemWriteRT<w, nsc, uint##bs, 0x0, true>;			\
		 }										\
		 else										\
		 {										\
		  if(bs == 16) { MRFP16_I[0] = C_MemReadRT<w, nsc, cbh, uint16, 0x0, false, false>; }\
		  if(bs == 32) { MRFP32_I[0] = C_MemReadRT<w, nsc, cbh, uint32, 0x0, false, false>; }\
		  MRFP##bs[0] =  C_MemReadRT <w, nsc, cbh, uint##bs, 0x0, false, false>;		\
		  MRFPI[0]    =  C_MemReadRT <w, nsc, cbh, uint32,   0x0, false, true>;		\
		  MWFP##bs[0] =  C_MemWriteRT<w, nsc, uint##bs, 0x0, false>;			\
		 }

 #define MAHL(w, nsc, cbh)		\
	{				\
	 MAHL_( 8, w, nsc, cbh)		\
	 MAHL_(16, w, nsc, cbh)		\
	 MAHL_(32, w, nsc, cbh) 	\
	}

 if(this == &CPU[0])
 {
  if(EIC_Setting)
  {
   if(DM_Setting)
    MAHL(0,   -1, false)
   else
    MAHL(0, true, false)
  }
  else if(CBH_Setting)
  {
   MAHL(0, false, true)
  }
  else
  {
   MAHL(0, false, false)
  }
 }
 else
 {
  if(!EIC_Setting && CBH_Setting)
  {
   MAHL(1, false, true)
  }
  else
  {
   MAHL(1, false, false)
  }
 }
 #undef MAHL_
 #undef MAHL
}

void SH7095::RecalcMRWFP_1_7(void)
{
 #define MAHL_P(w, nsc, region) {								\
		  MRFP8[region]  = C_MemReadRT<w, nsc, false, uint8,  region, false, false>;	\
		  MRFP16[region] = C_MemReadRT<w, nsc, false, uint16, region, false, false>;	\
		  MRFP32[region] = C_MemReadRT<w, nsc, false, uint32, region, false, false>;	\
		  MRFP16_I[region] = C_MemReadRT<w, nsc, false, uint16, region, false, false>;	\
		  MRFP32_I[region] = C_MemReadRT<w, nsc, false, uint32, region, false, false>;	\
		  MRFPI[region]  = C_MemReadRT<w, nsc, false, uint32, region, false, true>;	\
		  MWFP8[region]  = C_MemWriteRT<w, nsc, uint8,  region, false>;	\
		  MWFP16[region] = C_MemWriteRT<w, nsc, uint16, region, false>;	\
		  MWFP32[region] = C_MemWriteRT<w, nsc, uint32, region, false>;	\
		  }

 #define MAHL(nsc, region)					\
		  if(this == &CPU[0])				\
		  { MAHL_P(0, nsc, region) }			\
		  else						\
		  { MAHL_P(1, false, region) }

 if(EIC_Setting)
 {
  if(DM_Setting)
  {
   MAHL(-1,  1)
  }
  else
  {
   MAHL(true,  1)
  }
  MAHL(false, 2)
  MAHL(false, 3)
  MAHL(false, 4)
  MAHL(false, 5)
  MAHL(false, 6)
  MAHL(false, 7)
 }
 else
 {
  MAHL(false, 1)
  MAHL(false, 2)
  MAHL(false, 3)
  MAHL(false, 4)
  MAHL(false, 5)
  MAHL(false, 6)
  MAHL(false, 7)
 }

 #undef MAHL
 #undef MAHL_P
}

void SH7095::SetDebugMode(bool DebugMode)
{
 if(DM_Setting != DebugMode)
 {
  if(ResumePoint != nullptr)
  {
   bool found = false;

   for(unsigned i = 0; i < 512; i++)
   {
    if(ResumeTableP[DM_Setting][i] == ResumePoint)
    {
     ResumePoint = ResumeTableP[DebugMode][i];
     found = true;
     break;
    }
   }
   assert(found);
  }
  DM_Setting = DebugMode;
  //
  RecalcMRWFP_0();
  RecalcMRWFP_1_7();
 }
}

void SH7095::Init(const bool EmulateICache, const bool CacheBypassHack)
{
 CBH_Setting = CacheBypassHack;
 EIC_Setting = EmulateICache;
 RecalcMRWFP_0();
 RecalcMRWFP_1_7();
 //
 //
 //
 //
 // Initialize variables that won't be initialized elsewhere since they reflect the overall emulator timing state, or are cache variables
 // for signal inputs.
 //
 timestamp = 0;

 FRT.FTI = false;
 FRT.FTCI = false;
 IRL = 0;
 NMILevel = false;
 BSC.BCR1 &= 0x7FFF; //MD5Level = false;
 ExtHalt = false;
 ExtHaltDMA = false;

 ResumePoint = nullptr;

 TruePowerOn();
}

SH7095::~SH7095()
{

}

//
// Initialize everything for determinism, especially state left "undefined" by reset/power exception handling.
//
void SH7095::TruePowerOn(void)
{
 for(unsigned i = 0; i < 16; i++)
  R[i] = 0;

 for(unsigned i = 0; i < 16; i++)
  WB_until[i] = timestamp;

 UCRead_IF_Kludge = 0;

 MA_until = timestamp;
 MM_until = timestamp;
 write_finish_timestamp = timestamp;

 PC = 0;

 SR = 0;
 GBR = 0;
 VBR = 0;

 MACH = 0;
 MACL = 0;
 PR = 0;

 EPending = 0;
 Pipe_ID = 0;
 Pipe_IF = 0;
 IBuffer = 0;

 PC_IF = PC_ID = 0;

 memset(Cache, 0, sizeof(Cache));
 memset(Cache_LRU, 0, sizeof(Cache_LRU));
 CCRC_Replace_OR[0] = 0;
 CCRC_Replace_OR[1] = 0;
 CCRC_Replace_AND = 0;
 CCR = 0;
 //
 //
 //
 ResumePoint = nullptr;
 Resume_cent = nullptr;
 Resume_instr = 0;
 Resume_way_match = 0;
 Resume_uint8_A = 0;
 Resume_uint16_A = 0;
 Resume_uint32_A = 0;
 Resume_unmasked_A = 0;
 Resume_uint32_V = 0;
 Resume_uint16_V = 0;
 Resume_uint8_V = 0;

 Resume_MAC_L_m0 = 0;
 Resume_MAC_L_m1 = 0;

 Resume_MAC_W_m0 = 0;
 Resume_MAC_W_m1 = 0;

 Resume_ea = 0;
 Resume_new_PC = 0;
 Resume_new_SR = 0;

 Resume_ipr = 0;
 Resume_exnum = 0;
 Resume_vecnum = 0;
 //
 //
 //
 IPRA = 0;
 IPRB = 0;
 VCRWDT = 0;
 VCRA = 0;
 VCRB = 0;
 VCRC = 0;
 VCRD = 0;
 ICR = 0;
 //
 //
 //
 BSC.BCR1 &= 0x8000;
 BSC.BCR2 = 0;
 BSC.WCR = 0;
 BSC.MCR = 0;

 BSC.RTCSR = 0;
 BSC.RTCSRM = 0;
 BSC.RTCNT = 0;
 BSC.RTCOR = 0;

 BSC.sdram_finish_time = timestamp;
 BSC.last_mem_time = timestamp;
 BSC.last_mem_addr = 0;
 BSC.last_mem_type = 0;
 //
 //
 //
 ResumePoint = nullptr;
 //
 //
 //
 SBYCR = 0;
 Standby = false;
 //
 //
 //
 FRT.lastts = timestamp;

 // Don't change FRT.FTI and FRT.FTCI here.

 FRT.FRC = 0;
 FRT.OCR[0] = FRT.OCR[1] = 0;
 FRT.FICR = 0;
 FRT.TIER = 0;
 FRT.FTCSR = 0;
 FRT.FTCSRM = 0;
 FRT.TCR = 0;
 FRT.TOCR = 0;
 FRT.RW_Temp = 0;

 FRT_WDT_ClockDivider = 0;

 WDT.WTCSR = 0;
 WDT.WTCSRM = 0;
 WDT.WTCNT = 0;
 WDT.RSTCSR = 0;
 WDT.RSTCSRM = 0;

 FRT_WDT_Recalc_NET();
 //
 //
 //
 DMA_Timestamp = timestamp;
 DMA_SGEndTimestamp = timestamp;
 DMA_RoundRobinRockinBoppin = 0;
 DMA_PenaltyKludgeAmount = 0;
 DMA_PenaltyKludgeAccum = 0;
 memset(DMACH, 0, sizeof(DMACH));
 DMAOR = 0;
 DMAORM = 0;
 DMA_RecalcRunning();
 //
 //
 //
 divide_finish_timestamp = timestamp;
 DVSR = 0;
 DVDNT = 0;
 DVDNTH = 0;
 DVDNTL = 0;
 DVDNTH_Shadow = 0;
 DVDNTL_Shadow = 0;
 VCRDIV = 0;
 DVCR = 0;
 //
 //
 //
 SCI.SMR = 0;
 SCI.BRR = 0;
 SCI.SCR = 0;
 SCI.TDR = 0;
 SCI.SSR = 0;
 SCI.SSRM = 0;
 SCI.RDR = 0;
 SCI.RSR = 0;
 SCI.TSR = 0;
}

void SH7095::SetActive(bool active)
{
 if(active && timestamp == SS_EVENT_DISABLED_TS)
 {
  timestamp = SH7095_mem_timestamp;
  FRT.lastts = timestamp;

  DMA_Timestamp = SH7095_mem_timestamp;
  DMA_SGEndTimestamp = SH7095_mem_timestamp;

  SS_SetEventNT(&events[event_id_dma], SH7095_mem_timestamp + 1);
  //
  Reset(true);
 }
 else if(!active && timestamp != SS_EVENT_DISABLED_TS)
 {
  Reset(true);
  //
  timestamp = SS_EVENT_DISABLED_TS;
  SS_SetEventNT(&events[event_id_dma], SS_EVENT_DISABLED_TS);
 }
}

void SH7095::AdjustTS(int32 delta)
{
 if(MDFN_UNLIKELY(timestamp == SS_EVENT_DISABLED_TS))
  return;

 timestamp += delta;
 FRT.lastts += delta;

#define ATSD(v) v = std::max<sscpu_timestamp_t>(-1000000, v + (delta))
 ATSD(DMA_Timestamp);
 ATSD(DMA_SGEndTimestamp);

 ATSD(MA_until);
 ATSD(MM_until);

 for(unsigned i = 0; i < 16; i++)
  ATSD(WB_until[i]);

 ATSD(write_finish_timestamp);
 ATSD(divide_finish_timestamp);

 ATSD(BSC.sdram_finish_time);
 ATSD(BSC.last_mem_time);
#undef ATSD

 FRT_WDT_ClockDivider &= 0x00FFFFFF;
 FRT_WDT_Recalc_NET();
}


// de=1, dme=1, te=0, nmif=0, ae=0
INLINE bool SH7095::DMA_RunCond(unsigned ch)
{
 return ((DMAOR & 0x07) == 0x01) && ((DMACH[ch].CHCR & 0x03) == 0x01);
}

bool SH7095::DMA_InBurst(void)
{
 if((DMAOR & 0x08) && DMA_RunCond(0) && DMA_RunCond(1))
  return ((DMACH[0].CHCR | DMACH[1].CHCR) & 0x10);

 if(DMA_RunCond(0))
  return (DMACH[0].CHCR & 0x10);
 else if(DMA_RunCond(1))
  return (DMACH[1].CHCR & 0x10);

 return false;
}

void SH7095::DMA_CheckEnterBurstHack(void)
{
 if(DMA_InBurst())
  SetPEX(PEX_PSEUDO_DMABURST);
}


// RecalcPendingIntPEX() will be called higher up, at the end of DMA_Update()
//
// Call SH7095_Bus* directly instead of through ExtBusRead, at least until we can work
// out all this disparate timestamp nonsense properly(maybe around the time we add proper bus controller emulation? ;)).
//
INLINE void SH7095::DMA_DoTransfer(unsigned ch)
{
 static const int8 ainc[3][4] = 
 {
  { 0, 1, -1, -1 },
  { 0, 2, -2, -2 },
  { 0, 4, -4, -4 },
 };
 const unsigned ts = (DMACH[ch].CHCR >> 10) & 3;
 const unsigned sm = (DMACH[ch].CHCR >> 12) & 3;
 const unsigned dm = (DMACH[ch].CHCR >> 14) & 3;
 uint32 sar = DMACH[ch].SAR;
 uint32 dar = DMACH[ch].DAR;
 uint32 tcr = DMACH[ch].TCR;

 switch(ts)
 {
  case 0x00:	// 8-bit
	{
	 uint8 buffer;

	 buffer = BSC_BusRead<uint8>(sar & 0x07FFFFFF, false, &DMA_Timestamp);
	 BSC_BusWrite<uint8>(dar & 0x07FFFFFF, buffer, false, &DMA_Timestamp);

	 sar += ainc[0][sm];
 	 dar += ainc[0][dm];
	 tcr = (tcr - 1) & 0xFFFFFF;
	}
	break;

  case 0x01:	// 16-bit
	{
	 uint16 buffer;

	 buffer = BSC_BusRead<uint16>(sar & 0x07FFFFFE, false, &DMA_Timestamp);
	 BSC_BusWrite<uint16>(dar & 0x07FFFFFE, buffer, false, &DMA_Timestamp);

	 if(MDFN_UNLIKELY((sar | dar) & 0x1))
	 {
	  DMAOR |= 4;
	  DMAORM |= 4;
	  DMA_RecalcRunning();
	  SetPEX(PEX_DMAADDR);
	 }

	 sar += ainc[1][sm];
 	 dar += ainc[1][dm];
	 tcr = (tcr - 1) & 0xFFFFFF;
	}
	break;

  case 0x02:	// 32-bit
	{
	 uint32 buffer;

	 buffer = BSC_BusRead<uint32>(sar & 0x07FFFFFC, false, &DMA_Timestamp);
	 BSC_BusWrite<uint32>(dar & 0x07FFFFFC, buffer, false, &DMA_Timestamp);

	 if(MDFN_UNLIKELY((sar | dar) & 0x3))
	 {
	  DMAOR |= 4;
	  DMAORM |= 4;
          DMA_RecalcRunning();
	  SetPEX(PEX_DMAADDR);
	 }

	 sar += ainc[2][sm];
 	 dar += ainc[2][dm];
	 tcr = (tcr - 1) & 0xFFFFFF;
	}
	break;

  case 0x03:	// 4 * 32-bit, a mess...
	{
	 uint32 buffer[4];

	 if(MDFN_UNLIKELY((sar | dar) & 0x3))
	 {
	  DMAOR |= 4;
	  DMAORM |= 4;
	  DMA_RecalcRunning();
	  SetPEX(PEX_DMAADDR);
	 }

	 for(unsigned i = 0; i < 4; i++)
	 {
	  buffer[i] = BSC_BusRead<uint32>((sar + (i << 2)) & 0x07FFFFFC, (bool)i, &DMA_Timestamp);
	 }

	 sar += 0x10;

	 for(unsigned i = 0; i < 4; i++)
	 {
	  BSC_BusWrite<uint32>(dar & 0x07FFFFFC, buffer[i], false, &DMA_Timestamp);
	  dar += ainc[2][dm];
	  tcr = (tcr - 1) & 0xFFFFFF;
	  if(MDFN_UNLIKELY(!tcr))
	   break;
	 }
	}
	break;
 }

 if(!tcr)
 {
  SS_DBGTI(SS_DBG_SH2, "[%s] DMA %d finished.", cpu_name, ch);

  DMACH[ch].CHCR |= 2;
  DMACH[ch].CHCRM |= 2;
  DMA_RecalcRunning();
 }

 DMACH[ch].SAR = sar;
 DMACH[ch].DAR = dar;
 DMACH[ch].TCR = tcr;
}

sscpu_timestamp_t SH7095::DMA_Update(sscpu_timestamp_t et)
{
#ifdef MDFN_ENABLE_DEV_BUILD
 assert(timestamp != SS_EVENT_DISABLED_TS);
#endif

 if(MDFN_UNLIKELY(et < DMA_Timestamp))
 {
  // may happen...look into it.
  // SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] DMA_Update called with et(%d) < DMA_Timestamp(%d).\n", cpu_name, et, DMA_Timestamp);
  return DMA_Timestamp + 32;
 }
 else if(MDFN_UNLIKELY(ExtHaltDMA))
 {
  //printf("%s ExtHaltDMA 0x%02x!\n", cpu_name, ExtHaltDMA);
  DMA_Timestamp = et;
  return DMA_Timestamp + 128;
 }
 else
 {
  bool rr = DMA_RoundRobinRockinBoppin;

  if(DMAOR & 0x08) 	// Round robin
  {
   while(DMA_RunCond(0) || DMA_RunCond(1))
   {
    if(DMA_RunCond(rr))
    {
     if(DMA_Timestamp >= et)
      goto TimeOver;

     DMA_DoTransfer(rr);
    }
    rr = !rr;
   }
  }
  else	// ch 0 > ch1
  {
   while(DMA_RunCond(0))
   {
    if(DMA_Timestamp >= et)
     goto TimeOver;

    DMA_DoTransfer(0);
   }

   while(DMA_RunCond(1))
   {
    if(DMA_Timestamp >= et)
     goto TimeOver;

    DMA_DoTransfer(1);
   }
  }
  //
  //
  //
  TimeOver:;

  DMA_RoundRobinRockinBoppin = rr;
  DMA_Timestamp = std::max<sscpu_timestamp_t>(DMA_Timestamp, et - 128);

  DMA_CheckEnterBurstHack();
  RecalcPendingIntPEX();	// TODO: conditionalize(or make RecalcPendingIntPEX() less expensive).
 }

 return et + ((et < DMA_SGEndTimestamp) ? 32 : 128);
}


#ifdef MDFN_ENABLE_DEV_BUILD
void SH7095::CheckDMARace(uint32 addr, uint32 size, bool write)
{
 for(unsigned cpu = 0; cpu < 2; cpu++)
 {
  for(unsigned ch = 0; ch < 2; ch++)
  {
   auto& dd = CPU[cpu].DMADebug[ch];

   if(dd.rw[0][0] == ~0U)
    continue;

   for(uint32 A = addr; A != ((addr + size) & 0x07FFFFFF); A = (A + 1) & 0x07FFFFFF)
   {
    bool match = false;

    if(dd.rw[1][1] < dd.rw[1][0])
     match |= (A >= dd.rw[1][0] || A < dd.rw[1][1]);
    else
     match |= (A >= dd.rw[1][0] && A < dd.rw[1][1]);

    if(write)
    {
     if(dd.rw[0][1] < dd.rw[0][0])
      match |= (A >= dd.rw[0][0] || A < dd.rw[0][1]);
     else
      match |= (A >= dd.rw[0][0] && A < dd.rw[0][1]);
    }

    if(match)
    {
     SS_DBG(SS_DBG_SH2_DMARACE, "[%s] %u-byte %s 0x%07x races with %s DMA%u; SAR=0x%08x DAR=0x%08x, [0x%07x,0x%07x]->[0x%07x,0x%07x]\n", cpu_name, size, write ? "write to" : "read from", addr, CPU[cpu].cpu_name, ch, CPU[cpu].DMACH[ch].SAR, CPU[cpu].DMACH[ch].DAR, dd.rw[0][0], dd.rw[0][1] - 1, dd.rw[1][0], dd.rw[1][1] - 1);
     break;
    }
   }
  }
 }
}
#endif

// DMA_StartSG() must be paired with a DMA_Update(SH7095_mem_timestamp) somewhere before.
void SH7095::DMA_StartSG(void)
{
 DMA_SGEndTimestamp = DMA_Timestamp + 192;
 SS_SetEventNT(&events[event_id_dma], SH7095_mem_timestamp + 32);	// fixed + 32

 DMA_CheckEnterBurstHack();
}

// Must be called after DMACH[0].CHCR or DMACH[1].CHCR or DMAOR changes.
//
// If DMA_RunCond(...) returns false, SAR and DAR and TCR for that channel
// should not be used(due to caching of variables in DMA_DoTransfer()).
NO_INLINE void SH7095::DMA_RecalcRunning(void)
{
 DMA_PenaltyKludgeAmount = 0;

 for(unsigned ch = 0; ch < 2; ch++)
 {
  if(DMA_RunCond(ch))
  {
   const int32 npka = (((DMACH[ch].CHCR >> 10) & 3) == 3 && (DMACH[ch].SAR & DMACH[ch].DAR & 0x06000000) != 0x06000000) ? 23 : 19;

   DMA_PenaltyKludgeAmount = std::max<int32>(DMA_PenaltyKludgeAmount, npka);
  }
 }

#if 1
 if(MDFN_UNLIKELY(ss_horrible_hacks & HORRIBLEHACK_NOSH2DMAPENALTY))
  DMA_PenaltyKludgeAmount = 0;
#endif
 //
 //
 //
#ifdef MDFN_ENABLE_DEV_BUILD
 for(unsigned ch = 0; ch < 2; ch++)
 {
  const bool run_cond = DMA_RunCond(ch);
  const unsigned ts = (DMACH[ch].CHCR >> 10) & 3;
  const unsigned sm = (DMACH[ch].CHCR >> 12) & 3;
  const unsigned dm = (DMACH[ch].CHCR >> 14) & 3;
  const uint32 sar = DMACH[ch].SAR;
  const uint32 dar = DMACH[ch].DAR;
  const uint32 count = DMACH[ch].TCR ? DMACH[ch].TCR : 0x1000000;

  if(run_cond && DMADebug[ch].rw[0][0] == ~0U)
  {
   auto& dd = DMADebug[ch];

   if(ts == 3)
   {
    dd.rw[0][0] = sar & 0x07FFFFFF;
    dd.rw[0][1] = (dd.rw[0][0] + (count << 2)) & 0x07FFFFFF;
   }
   else
   {
    if(sm & 2)
    {
     dd.rw[0][1] = (sar + (1 << ts)) & 0x07FFFFFF;
     dd.rw[0][0] = (dd.rw[0][1] - (count << ts)) & 0x07FFFFFF;
    }
    else
    {
     dd.rw[0][0] = sar & 0x07FFFFFF;
     dd.rw[0][1] = (dd.rw[0][0] + ((sm ? count : 1) << ts)) & 0x07FFFFFF;
    }
   }
   //
   const unsigned ts_adj = std::min<unsigned>(2, ts);

   if(dm & 2)
   {
    dd.rw[1][1] = (dar + (1 << ts_adj)) & 0x07FFFFFF;
    dd.rw[1][0] = (dd.rw[1][1] - (count << ts_adj)) & 0x07FFFFFF;
   }
   else
   {
    dd.rw[1][0] = dar & 0x07FFFFFF;
    dd.rw[1][1] = (dd.rw[1][0] + ((dm ? count : 1) << ts_adj)) & 0x07FFFFFF;
   }
   //printf("%u, read:[0x%07x, 0x%07x) write:[0x%07x, 0x%07x)\n", ch, dd.rw[0][0], dd.rw[0][1], dd.rw[1][0], dd.rw[1][1]);
  }
  else if(!run_cond)
   DMADebug[ch].rw[0][0] = ~0U;

  if(run_cond && ts == 0x3 && ((sar | dar) & 0xF))
  {
   SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] DMA channel %u, 16-byte transfer size address misalignment, SAR=0x%08x DAR=0x%08x", cpu_name, ch, sar, dar);
  }
 }
#endif
}

INLINE void SH7095::DMA_BusTimingKludge(void)
{
 timestamp += DMA_PenaltyKludgeAccum;
 DMA_PenaltyKludgeAccum = 0;
}


//
//
//
void NO_INLINE SH7095::FRT_Reset(void)
{
 FRT.FRC = 0x00;
 FRT.OCR[0] = FRT.OCR[1] = 0x00;
 FRT.FICR = 0x00;
 FRT.TIER = 0x00;
 FRT.FTCSR = 0x00;
 FRT.FTCSRM = 0x00;
 FRT.TCR = 0x00;
 FRT.TOCR = 0x00;
 FRT.RW_Temp = 0x00;	// Reset or not?

 FRT_WDT_Recalc_NET();
 RecalcPendingIntPEX();
}

INLINE void SH7095::FRT_CheckOCR(void)
{
 if(FRT.FRC == FRT.OCR[0]) // OCRA
 {
  if(FRT.FTCSR & 0x0001)
   FRT.FRC = 0;

  if(!(FRT.FTCSR & 0x08))
  {
   FRT.FTCSR |= 0x08;
   FRT.FTCSRM |= 0x08;
   RecalcPendingIntPEX();
  }
 }

 if(FRT.FRC == FRT.OCR[1]) // OCRB
 {
  if(!(FRT.FTCSR & 0x04))
  {
   FRT.FTCSR |= 0x04;
   FRT.FTCSRM |= 0x04;
   RecalcPendingIntPEX();
  }
 }
}

INLINE void SH7095::FRT_ClockFRC(void)
{
 FRT.FRC++;
 if(!FRT.FRC)
 {
  if(!(FRT.FTCSR & 0x02))
  {
   FRT.FTCSR |= 0x02;	// OVF
   FRT.FTCSRM |= 0x02;
   RecalcPendingIntPEX();
  }
 }
 //
 //
 //
 FRT_CheckOCR();
}


static const uint8 wdt_cstab[8] = { 1, /**/ 6, 7, 8, 9, 10, /**/ 12, 13 };

//
// Call after:
//	WDT.WTCSR, WDT.WTCNT, FRT.TCR, FRT.OCR[0], FRT.OCR[1] changes due to register write or similar.
//	timestamp >= FRT_WDT_NextTS (after call to FRT_WDT_Update())
//
void SH7095::FRT_WDT_Recalc_NET(void)
{
 int32 rt = 1000;

 if((FRT.TCR & 0x3) != 0x3)	// when == 3, count on rising edge of external clock(not handled here).
 {
  const uint32 frt_clockshift = 3 + ((FRT.TCR & 0x3) << 1);	// /8, /32, /128, count at falling edge
  int32 next_frc = 0x10000;

  if(FRT.OCR[0] > FRT.FRC)
   next_frc = FRT.OCR[0];

  if(FRT.OCR[1] > FRT.FRC)
   next_frc = FRT.OCR[1];

  rt = ((next_frc - FRT.FRC) << frt_clockshift) - (FRT_WDT_ClockDivider & ((1 << frt_clockshift) - 1));
 }

 if(WDT.WTCSR & 0x28)	// TME(0x20) and internal use standby NMI recover bit(0x08)
 {
  const unsigned wdt_clockshift = wdt_cstab[WDT.WTCSR & 0x7];
  int32 wdt_rt;

  wdt_rt = ((0x100 - WDT.WTCNT) << wdt_clockshift) - (FRT_WDT_ClockDivider & ((1 << wdt_clockshift) - 1));
  rt = std::min<int32>(rt, wdt_rt);
 }

 assert(rt > 0);

 FRT_WDT_NextTS = timestamp + rt;
}

void SH7095::FRT_WDT_Update(void)
{
 assert(timestamp >= FRT.lastts);

 uint32 clocks = timestamp - FRT.lastts;

 //if(clocks >= 1000)
 // printf("%u, %d %d\n", clocks, timestamp, FRT.lastts);
 //assert(clocks < 1000);

 FRT.lastts = timestamp;

 //
 // 
 //
 const uint32 PreAddCD = FRT_WDT_ClockDivider;
 FRT_WDT_ClockDivider += clocks;

 if((FRT.TCR & 0x3) != 0x3)	// when == 3, count on rising edge of external clock(not handled here).
 {
  const uint32 frt_clockshift = 3 + ((FRT.TCR & 0x3) << 1);	// /8, /32, /128, count at falling edge
  uint32 divided_clocks = (FRT_WDT_ClockDivider >> frt_clockshift) - (PreAddCD >> frt_clockshift);

  while(divided_clocks-- > 0)
  {
   FRT_ClockFRC();
  }
 }

 // WDT:
 if(WDT.WTCSR & 0x28)	// TME(0x20) and internal use standby NMI recover bit(0x08)
 {
  const unsigned wdt_clockshift = wdt_cstab[WDT.WTCSR & 0x7];
  uint32 divided_clocks = (FRT_WDT_ClockDivider >> wdt_clockshift) - (PreAddCD >> wdt_clockshift);
  uint32 tmp_counter = WDT.WTCNT;

  tmp_counter += divided_clocks;
  WDT.WTCNT = tmp_counter;
  //
  //
  if(MDFN_UNLIKELY(tmp_counter >= 0x100))
  {
   if(MDFN_UNLIKELY(WDT.WTCSR & 0x08))
   {
    Standby = false;
    WDT.WTCNT = 0x00;
    WDT.WTCSR &= ~0x08;
   }
   else if(MDFN_UNLIKELY(WDT.WTCSR & 0x40))	// Watchdog timer mode
   {
    SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] WDT overflow in WDT mode!\n", cpu_name);
    WDT.RSTCSR |= 0x80;

    WDT.WTCNT = 0;
    WDT.WTCSR = 0;

    if(WDT.RSTCSR & 0x40)	// RSTE
     Reset(!(WDT.RSTCSR & 0x20), true);
   }
   else
   {
    if(!(WDT.WTCSR & 0x80))
    {
     WDT.WTCSR |= 0x80;
     WDT.WTCSRM |= 0x80;
     RecalcPendingIntPEX();
    }
   }
  }
 }
}

void SH7095::SetFTI(bool state)
{
 if(MDFN_UNLIKELY(timestamp == SS_EVENT_DISABLED_TS))
 {
  FRT.FTI = state;
  return;
 }

 FRT_WDT_Update();
 //
 //
 bool prev = FRT.FTI;
 FRT.FTI = state;

 if((prev ^ state) & (prev ^ (FRT.TCR >> 7)))
 {
  SS_DBGTI(SS_DBG_SH2, "[%s] FTI input capture triggered.", cpu_name);
  if((FRT.FTCSR & 0x80) || (FRT.FTCSRM & 0x80))
  {
   SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] FTI Input capture interrupt while software not ready? FTCSR=0x%02x, FTCSRM=0x%02x\n", cpu_name, FRT.FTCSR, FRT.FTCSRM);
  }

  FRT.FICR = FRT.FRC;
  if(!(FRT.FTCSR & 0x80))
  {
   FRT.FTCSR |= 0x80;
   FRT.FTCSRM |= 0x80;
  }
  RecalcPendingIntPEX();
 }
}

void SH7095::SetFTCI(bool state)
{
 bool prev = FRT.FTCI;
 FRT.FTCI = state;

 if((FRT.TCR & 0x3) == 0x3)
 {
  if(!prev && state)
   FRT_ClockFRC();
 }
}

void NO_INLINE SH7095::WDT_Reset(bool from_internal_wdt)
{
 WDT.WTCSR = 0x00;
 WDT.WTCSRM = 0x00;

 WDT.WTCNT = 0x00;

 if(!from_internal_wdt)
 {
  WDT.RSTCSR = 0x00;
  WDT.RSTCSRM = 0x00;
 }

 FRT_WDT_Recalc_NET();
 RecalcPendingIntPEX();
}

void NO_INLINE SH7095::WDT_StandbyReset(void)
{
 WDT.WTCSR &= 0x1F;
 WDT.WTCSRM &= 0x1F;

 WDT.RSTCSR = 0x00;
 WDT.RSTCSRM = 0x00;

 FRT_WDT_Recalc_NET();
 RecalcPendingIntPEX();
}

//
//
//
//
//

static INLINE uint64 DIVU64_Partial(uint64 dividend, uint32 divisor)
{
 bool M, Q;

 Q = dividend >> 63;
 M = divisor >> 31;

 for(unsigned x = 0; x < 3; x++)
 {
	if(!(Q ^ M))
	 dividend -= (uint64)divisor << 32;
	else
	 dividend += (uint64)divisor << 32;

	Q = dividend >> 63;
        dividend <<= 1;
	dividend |= Q ^ 1 ^ M;
 }

 return dividend;
}

INLINE void SH7095::DIVU_S32_S32(void)
{
 if(!DVSR)
 {
  divide_finish_timestamp = MA_until + 2 + 6;

  DVCR |= 1;
  RecalcPendingIntPEX();

  DVDNTH = (int32)DVDNT >> 29;

  if(!(DVCR & 2))
   DVDNT = DVDNTL = 0x7FFFFFFF + ((int32)DVDNT < 0);
  else
   DVDNT = DVDNTL = (DVDNT << 3) | (((int32)~DVDNT >> 31) & 7);
 }
 else
 {
  divide_finish_timestamp = MA_until + 1 + 39;

  if(DVSR == 0xFFFFFFFF && DVDNTL == 0x80000000)
  {
   DVDNT = DVDNTL = 0x80000000;
   DVDNTH = 0;
  }
  else
  {
   DVDNTH = (int32)DVDNTL % (int32)DVSR;
   DVDNT = DVDNTL = (int32)DVDNTL / (int32)DVSR;
  }
 }
 DVDNTH_Shadow = DVDNTH;
 DVDNTL_Shadow = DVDNTL;
}

INLINE void SH7095::DIVU_S64_S32(void)
{
 const int32 divisor = DVSR;
 const int64 dividend = ((int64)DVDNTH << 32) | DVDNTL;
 int64 quotient;

 if(!divisor)
  goto Overflow;

 if((uint64)dividend == (1ULL << 63) && (uint32)divisor == ~(uint32)0)
  goto Overflow;

 quotient = dividend / divisor;

 //printf("Divisor=%08x, Dividend=%016llx, Quotient=%016llx\n", divisor, dividend, quotient);

 if(quotient == 2147483648LL && divisor < 0 && (dividend % divisor) == 0)	// Ugh, maybe we should just implement it properly the long way...
  goto SkipOVCheck;

 if(quotient < -2147483647LL || quotient > 2147483647LL)
 {
  Overflow:
  divide_finish_timestamp = timestamp + 6;
  DVCR |= 1;
  RecalcPendingIntPEX();
  //
  uint64 tmp = DIVU64_Partial(dividend, divisor);
  DVDNTH = tmp >> 32;

  if(DVCR & 2)
   DVDNT = DVDNTL = tmp;
  else
   DVDNT = DVDNTL = 0x7FFFFFFF + ((int32)((dividend >> 32) ^ divisor) < 0);
 }
 else
 {
  SkipOVCheck:
  divide_finish_timestamp = timestamp + 39;
  DVDNTH = dividend % divisor;
  DVDNT = DVDNTL = quotient;
 }
 DVDNTH_Shadow = DVDNTH;
 DVDNTL_Shadow = DVDNTL;
}

//
//
// Begin SCI
//
//
void SH7095::SCI_Reset(void)
{
 SCI.SMR = 0x00;
 SCI.BRR = 0xFF;
 SCI.SCR = 0x00;
 SCI.TDR = 0xFF;
 SCI.SSR = 0x84;
 SCI.SSRM = 0x00;
 SCI.RDR = 0x00;
 //
 SCI.RSR = 0x00;
 SCI.TSR = 0x00;

 RecalcPendingIntPEX();
}


//
//
// End SCI
//
//

//
// Misaligned/wrong-sized accesses aren't handled correctly, it's a mess, but probably doesn't matter.
//
template<typename T>
NO_INLINE MDFN_HOT void SH7095::OnChipRegWrite(uint32 A, uint32 V)
{
 SS_DBGTI(SS_DBG_SH2_REGW, "[%s] %zu-byte write to on-chip register area; address=0x%08x value=0x%08x, PC=0x%08x\n", cpu_name, sizeof(T), A, V, PC);

 if(A & 0x100)
 {
  if(sizeof(T) == 2)
   A &= 0xFE;
  else
   A &= 0xFC;

  if(sizeof(T) == 1)
  {
   SetPEX(PEX_CPUADDR);
   V |= (uint8)V << 8;
  }

  switch(A)
  {
   default:
	SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unhandled %zu-byte write to on-chip high register area; address=0x%08x value=0x%08x\n", cpu_name, sizeof(T), A, V);
	break;

   //
   // Division Unit registers
   // 
   case 0x20:
   case 0x00:
	DVSR = V;
	break;

   case 0x24:
   case 0x04:
	DVDNT = V;
	DVDNTL = V;
	DVDNTH = (int32)V >> 31;
	DIVU_S32_S32();
	break;

   case 0x28:
   case 0x08:
	DVCR = V & 0x3;
	break;

   case 0x2C:
   case 0x0C:
	VCRDIV = V;
	break;

   case 0x30:
   case 0x10:
	DVDNTH = V;
	break;

   case 0x34:
   case 0x14:
	DVDNTL = V;
	DIVU_S64_S32();
	break;

   // ?
   case 0x38:
   case 0x18:
	DVDNTH_Shadow = V;
	break;

   case 0x3C:
   case 0x1C:
	DVDNTL_Shadow = V;
	break;
   //
   //
   //

   //
   // DMA registers
   //
   case 0x80:
   case 0x90:
	DMACH[(A >> 4) & 1].SAR = V;
	break;

   case 0x84:
   case 0x94:
	DMACH[(A >> 4) & 1].DAR = V;
	break;

   case 0x88:
   case 0x98:
	DMACH[(A >> 4) & 1].TCR = V & 0xFFFFFF;
	break;

   case 0x8C:
   case 0x9C:
	DMA_Update(SH7095_mem_timestamp);
	{
	 const unsigned ch = (A >> 4) & 1;

	 DMACH[ch].CHCR = (V & ~2) | (DMACH[ch].CHCR & (V | DMACH[ch].CHCRM) & 2);
	 SS_DBGTI(SS_DBG_SH2, "[%s] DMA %d CHCR Write: CHCR=0x%04x SAR=0x%08x DAR=0x%08x TCR=0x%04x", cpu_name, ch, DMACH[ch].CHCR, DMACH[ch].SAR, DMACH[ch].DAR, DMACH[ch].TCR);

	 if((DMACH[ch].CHCR & 0x1) && (DMACH[ch].CHCR & 0x3E8) != 0x200)
	 {
	  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unhandled CHCR on DMA channel %u: 0x%08x\n", cpu_name, ch, DMACH[ch].CHCR);
	 }
	}
	DMA_RecalcRunning();
	DMA_StartSG();
	RecalcPendingIntPEX();
	break;

   case 0xA0:
   case 0xA8:
	DMACH[(A >> 3) & 1].VCR = V;
	break;

   case 0xB0:
	DMA_Update(SH7095_mem_timestamp);
	DMAOR = (V & 0x9) | (DMAOR & (V | DMAORM) & 0x6);
	DMA_RecalcRunning();
	DMA_StartSG();
	break;

   //
   // BSC registers
   //
   case 0xE0:	// BCR1
	if(sizeof(T) == 4 && (V & 0xFFFF0000) == 0xA55A0000)
	{
 	 BSC.BCR1 = (BSC.BCR1 & 0x8000) | (V & 0x1FF7);

	 if((BSC.BCR1 & 0x7FFF) != 0x3F1)
	 {
	  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unusual BCR1 register value: 0x%04x\n", cpu_name, BSC.BCR1);
	 }
	}
	break;

   case 0xE4:	// BCR2
	if(sizeof(T) == 4 && (V & 0xFFFF0000) == 0xA55A0000)
	{
 	 BSC.BCR2 = V & 0xFC;

	 if(BSC.BCR2 != 0xFC)
	 {
	  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unusual BCR2 register value: 0x%02x\n", cpu_name, BSC.BCR2);
	 }
	}
	break;

   case 0xE8:	// WCR
	if(sizeof(T) == 4 && (V & 0xFFFF0000) == 0xA55A0000)
	{
 	 BSC.WCR = V & 0xFFFF;

	 if(BSC.WCR != 0x5555)
	 {
	  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unusual WCR register value: 0x%04x\n", cpu_name, BSC.WCR);
	 }
	}
	break;

   case 0xEC:	// MCR
	if(sizeof(T) == 4 && (V & 0xFFFF0000) == 0xA55A0000)
	{
 	 BSC.MCR = V & 0xFEFC;

	 if(BSC.MCR != 0x0078 && BSC.MCR != 0x0070)
	 {
	  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unusual MCR register value: 0x%04x\n", cpu_name, BSC.MCR);
	 }
	}
	break;

   case 0xF0:	// RTCSR
	if(sizeof(T) == 4 && (V & 0xFFFF0000) == 0xA55A0000)
	{
 	 BSC.RTCSR = (V & 0x78) | (BSC.RTCSR & 0x80 & (V | ~BSC.RTCSRM));

	 if((BSC.RTCSR & 0x78) != 0x08)
	 {
	  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unusual RTCSR register value: 0x%02x\n", cpu_name, BSC.RTCSR);
	 }
	}
	break;

   case 0xF4:	// RTCNT
	if(sizeof(T) == 4 && (V & 0xFFFF0000) == 0xA55A0000)
	{
 	 BSC.RTCNT = V & 0xFF;

	 SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] RTCNT written with: 0x%02x\n", cpu_name, BSC.RTCNT);
	}
	break;

   case 0xF8: // RTCOR
	if(sizeof(T) == 4 && (V & 0xFFFF0000) == 0xA55A0000)
	{
 	 BSC.RTCOR = V & 0xFF;

	 if(BSC.RTCOR != 0x36)
	 {
	  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unusual RTCOR register value: 0x%02x\n", cpu_name, BSC.RTCOR);
	 }
	}
	break;
  }
 }
 else
 {
  unsigned mask = 0xFFFF;
  unsigned shift = 0;

  if(sizeof(T) != 2)
  {
   shift = ((A & 1) ^ 1) << 3;
   mask = 0xFF << shift;

   if(sizeof(T) == 4)
    shift ^= 8;
  }

  if(sizeof(T) == 4)
   SetPEX(PEX_CPUADDR);

  switch(A & 0xFF)
  {
   default:
	SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unhandled %zu-byte write to on-chip low register area; address=0x%08x value=0x%08x\n", cpu_name, sizeof(T), A, V);
	break;

#if 0
   //
   // SCI registers.
   //
   case 0x00:
	SCI.SMR = V;
	break;

   case 0x01:
	SCI.BRR = V;
	break;

   case 0x02:
	SCI.SCR = V;
	RecalcPendingIntPEX();
	break;

   case 0x03:
	SCI.TDR = V;
	break;

   case 0x04:
	SCI.SSR = (SCI.SSR & ~SCI.SSRM & 0xF8) | (SCI.SSR & 0x06) | (V & 0x01);
	SCI.SSRM = 0;
	RecalcPendingIntPEX();
	break;
#endif
   //
   // Free-running timer registers.
   //
   //
   // TIER
   case 0x10:
	FRT_WDT_Update();
	//
	FRT.TIER = V;
	RecalcPendingIntPEX();
	break;

   // FTCSR
   case 0x11:
	FRT_WDT_Update();
	//
	FRT.FTCSR = (FRT.FTCSR & (FRT.FTCSRM | V) & 0x8E) | (V & 0x01);
	RecalcPendingIntPEX();
	FRT_CheckOCR();
	break;

   // FRCH
   case 0x12:
	FRT.RW_Temp = V;
	break;

   // FRCL
   case 0x13:
	FRT_WDT_Update();
	//
	FRT.FRC = (FRT.RW_Temp << 8) | (V & 0xFF);
	FRT_CheckOCR();
	FRT_WDT_Recalc_NET();
	break;

   // OCRA/B H
   case 0x14:
	FRT.RW_Temp = V;
	break;

   // OCRA/B L
   case 0x15:
	FRT_WDT_Update();
	//
	FRT.OCR[(FRT.TOCR >> 4) & 1] = (FRT.RW_Temp << 8) | V;
	FRT_CheckOCR();
	FRT_WDT_Recalc_NET();
	break;

   // TCR
   case 0x16:
	{
	 FRT_WDT_Update();
	 //
	 //const uint8 old_TCR = FRT.TCR;
 	 FRT.TCR = V;
#if 0
	 //
 	 // Maybe not worth emulating?:
	 //
	 if((old_TCR ^ FRT.TCR) & 3)
	 {
	  bool old_cs;
	  bool clock;

	  if((old_TCR & 0x3) == 3)
	   old_cs = FRT.FTCI;
	  else
	   old_cs = (FRT_WDT_.ClockDivider >> (3 - 1 + ((old_TCR & 0x3) << 1))) & 1;

	  if((V & 0x3) == 3)
	   clock = (!old_cs && FRT.FTCI);
	  else
	  {
	   bool new_cs = (FRT_WDT_ClockDivider >> (3 - 1 + ((FRT.TCR & 0x3) << 1))) & 1;

	   clock = (old_cs && !new_cs);
	  }

	  if(clock)
	   FRT_ClockFRC();
	 }
#endif
	 //
	 //
	 //
	 FRT_WDT_Recalc_NET();
	}
	break;

   // TOCR
   case 0x17:
	FRT.TOCR = V & 0x1F;
	break;

   //
   //
   //
   case 0x71:
   case 0x72:
	DMACH[(A & 1) ^ 1].DRCR = V & 0x3;
	break;


   //
   // WDT registers
   //
   case 0x80:
   case 0x88:
	FRT_WDT_Update();
	if(sizeof(T) == 2)
	{
	 if((V & 0xFF00) == 0x5A00)
	 {
	  if(WDT.WTCSR & 0x20)
	   WDT.WTCNT = V;
	 }
	 else if((V & 0xFF00) == 0xA500)
	 {
	  WDT.WTCSR = (WDT.WTCSR & (WDT.WTCSRM | V) & 0x80) | (V & 0x67);

	  if(WDT.WTCSR & 0x20)
	   SBYCR &= 0x7F;
	  else
	  {
	   WDT.WTCSR &= ~0x80;	// Seemingly undocumented...
	   WDT.WTCNT = 0;
	  }
	 }
	}
	WDT.RSTCSRM = 0;
	FRT_WDT_Recalc_NET();
	RecalcPendingIntPEX();
	break;

   case 0x82:
   case 0x8A:
	FRT_WDT_Update();
	if(sizeof(T) == 2)
	{
	 if(V == 0xA500)
	 {
	  // Clear OVF bit
	  WDT.RSTCSR &= ~WDT.RSTCSRM;
	 }
	 else if((V & 0xFF00) == 0x5A00)
	 {
	  // Write RSTE and RSTS bits
	  WDT.RSTCSR = (WDT.RSTCSR & 0x80) | (V & 0x60);
	 }
	}
	WDT.RSTCSRM = 0;
	break;

   case 0x81:
   case 0x83:
   case 0x84:
   case 0x85:
   case 0x86:
   case 0x87:
   case 0x89:
   case 0x8B:
   case 0x8C:
   case 0x8D:
   case 0x8E:
   case 0x8F:
	WDT.RSTCSRM = 0;
	break;

   //
   //
   //
   case 0x91:
	SBYCR = V;

	if(WDT.WTCSR & 0x20)
	 SBYCR &= 0x7F;

	if(SBYCR != 0)
	{
	 SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] SBYCR set to non-zero value: 0x%02x\n", cpu_name, V);
	}
	break;

   case 0x92:	// No 0x93...0x9F mirrors for writes.
	SetCCR(V);
	break;
   //
   //
   //
   case 0x60:
   case 0x61:
	IPRB = (IPRB &~ mask) | ((V << shift) & mask & 0xFF00);
	RecalcPendingIntPEX();
	break;

   case 0x62:
   case 0x63:
	VCRA = (VCRA &~ mask) | ((V << shift) & mask & 0x7F7F);
	break;

   case 0x64:
   case 0x65:
	VCRB = (VCRB &~ mask) | ((V << shift) & mask & 0x7F7F);
	break;

   case 0x66:
   case 0x67:
	VCRC = (VCRC &~ mask) | ((V << shift) & mask & 0x7F7F);
	break;

   case 0x68:
   case 0x69:
	VCRD = (VCRD &~ mask) | ((V << shift) & mask & 0x7F00);
	break;

   case 0xE0:
   case 0xE1:
	ICR = (ICR &~ mask) | ((V << shift) & mask & 0x0101);
	if(ICR & 0x0100)
	{
	 SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] NMIE=1\n", cpu_name);
	}
	RecalcPendingIntPEX();
	break;

   case 0xE2:
   case 0xE3:
	IPRA = (IPRA &~ mask) | ((V << shift) & mask & 0xFFF0);
	RecalcPendingIntPEX();
	break;

   case 0xE4:
   case 0xE5:
	VCRWDT = (VCRWDT &~ mask) | ((V << shift) & mask & 0x7F7F);
	break;
  }
 }
}

template<typename T>
INLINE T SH7095::OnChipRegRead_INLINE(uint32 A)
{
 if(A & 0x100)
 {
  uint32 ret = 0;

  MA_until++;

  if(sizeof(T) == 2)
   A &= 0xFE;
  else
   A &= 0xFC;

  if(sizeof(T) == 1)
   SetPEX(PEX_CPUADDR);

  switch(A)
  {
   default:
	SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unhandled %zu-byte read from on-chip high register area; address=0x%08x\n", cpu_name, sizeof(T), A);
	break;

   //
   // Division Unit registers
   // 
   case 0x20:
   case 0x22:
   case 0x00:
   case 0x02:
	MA_until = std::max<sscpu_timestamp_t>(MA_until, divide_finish_timestamp);
	ret = DVSR;
	break;

   case 0x24:
   case 0x26:
   case 0x04:
   case 0x06:
	MA_until = std::max<sscpu_timestamp_t>(MA_until, divide_finish_timestamp);
	ret = DVDNT;
	break;

   case 0x28:
   case 0x2A:
   case 0x08:
   case 0x0A:
	MA_until = std::max<sscpu_timestamp_t>(MA_until, divide_finish_timestamp);
	ret = DVCR;
	break;

   case 0x2C:
   case 0x2E:
   case 0x0C:
   case 0x0E:
	MA_until = std::max<sscpu_timestamp_t>(MA_until, divide_finish_timestamp);
	ret = VCRDIV;
	break;

   case 0x30:
   case 0x32:
   case 0x10:
   case 0x12:
	MA_until = std::max<sscpu_timestamp_t>(MA_until, divide_finish_timestamp);
	ret = DVDNTH;
	break;

   case 0x34:
   case 0x36:
   case 0x14:
   case 0x16:
	MA_until = std::max<sscpu_timestamp_t>(MA_until, divide_finish_timestamp);
	ret = DVDNTL;
	break;

   // ?
   case 0x38:
   case 0x3A:
   case 0x18:
   case 0x1A:
	MA_until = std::max<sscpu_timestamp_t>(MA_until, divide_finish_timestamp);
	ret = DVDNTH_Shadow;
	break;

   case 0x3C:
   case 0x3E:
   case 0x1C:
   case 0x1E:
	MA_until = std::max<sscpu_timestamp_t>(MA_until, divide_finish_timestamp);
	ret = DVDNTL_Shadow;
	break;
   //
   //
   //

   //
   // DMA registers
   //
   case 0x80:
   case 0x90:
	ret = DMACH[(A >> 4) & 1].SAR;
	break;

   case 0x84:
   case 0x94:
	ret = DMACH[(A >> 4) & 1].DAR;
	break;

   case 0x88:
   case 0x98:
	ret = DMACH[(A >> 4) & 1].TCR;
	break;

   case 0x8C:
   case 0x9C:
	{
	 const unsigned ch = (A >> 4) & 1;

	 ret = DMACH[ch].CHCR;
	 DMACH[ch].CHCRM = 0;
	}
	break;

   case 0xA0:
   case 0xA8:
	ret = DMACH[(A >> 3) & 1].VCR;
	break;

   case 0xB0:
	ret = DMAOR;
	DMAORM = 0;
	break;

   //
   // BSC registers
   //
   case 0xE0:	// BCR1
   case 0xE2:
	ret = BSC.BCR1;
	break;

   case 0xE4:	// BCR2
   case 0xE6:
	ret = BSC.BCR2;
	break;

   case 0xE8:	// WCR
   case 0xEA:
	ret = BSC.WCR;
	break;

   case 0xEC:	// MCR
   case 0xEE:
	ret = BSC.MCR;
	break;

   case 0xF0:	// RTCSR
   case 0xF2:
	ret = BSC.RTCSR;
	BSC.RTCSRM = BSC.RTCSR & 0x80;

	SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Read from RTCSR\n", cpu_name);
	break;

   case 0xF4:	// RTCNT
   case 0xF6:
	ret = BSC.RTCNT;

	SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Read from RTCNT\n", cpu_name);
	break;

   case 0xF8:	// RTCOR
   case 0xFA:
	ret = BSC.RTCOR;
	break;
  }

  if(sizeof(T) == 1)
   ret >>= ((A & 1) ^ 1) << 3;

  return ret;
 }
 else
 {
  const unsigned Am = (uint8)A;
  const unsigned shift = ((sizeof(T) != 2) ? (((A & 1) ^ 1) << 3) : 0);
  uint16 ret = 0;

  if(Am < 0x20)
   MA_until = (MA_until + 11) &~ 1; // FIXME: not quite right. //3;
  else if((Am >= 0x60 && Am < 0xA0) || Am >= 0xE0)
   MA_until += 3;
  else
   MA_until += 1;

  if(sizeof(T) == 4)
   SetPEX(PEX_CPUADDR);

  else switch(Am)
  {
   default:
	SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Unhandled %zu-byte read from on-chip low register area; address=0x%08x\n", cpu_name, sizeof(T), A);
	break;

#if 0
   //
   // SCI registers.
   //
   case 0x00:
	ret = SCI.SMR;
	break;

   case 0x01:
	ret = SCI.BRR;
	break;

   case 0x02:
	ret = SCI.SCR;
	break;

   case 0x03:
	ret = SCI.TDR;
	break;

   case 0x04:
	ret = SCI.SSR;
	SCI.SSRM = SCI.SSR & 0xF8;
	break;

   case 0x05:
	ret = SCI.RDR;
	break;
#endif
   //
   // FRT registers.  Some weirdness with 16-bit reads duplicating the lower 8 bits in the upper 8-bits, but the upper 8-bits are masked
   // with the last data written to the FRT area or something...not emulated here.
   //
   case 0x10:
	ret = FRT.TIER | 1;
	break;

   case 0x11:
	FRT_WDT_Update();
	//
	ret = FRT.FTCSR;
	FRT.FTCSRM = 0x00;
	break;

   case 0x12:
	FRT_WDT_Update();
	//
	FRT.RW_Temp = FRT.FRC;
	ret = FRT.FRC >> 8;
	break;

   case 0x13:
	ret = FRT.RW_Temp;
	break;

   case 0x14:
	ret = FRT.OCR[(FRT.TOCR >> 4) & 1] >> 8;
	break;

   case 0x15:
	ret = FRT.OCR[(FRT.TOCR >> 4) & 1] & 0xFF;
	break;

   case 0x16:
	ret = FRT.TCR;
	break;

   case 0x17:
	ret = FRT.TOCR | 0xE0;
	break;

   case 0x18:
	FRT.RW_Temp = FRT.FICR;
	ret = FRT.FICR >> 8;
	break;

   case 0x19:
	ret = FRT.RW_Temp;
	break;

   //
   //
   //
   case 0x71:
   case 0x72:
	ret = DMACH[(A & 1) ^ 1].DRCR;
	break;


   //
   // WDT registers
   //
   case 0x80:
   case 0x88:
	FRT_WDT_Update();
	ret = WDT.WTCSR | 0x18;
	WDT.WTCSRM = 0x00;
	break;

   case 0x81:
   case 0x89:
	FRT_WDT_Update();
	ret = WDT.WTCNT;
	break;

   case 0x82:
   case 0x85:
   case 0x86:
   case 0x87:
   case 0x8A:
   case 0x8D:
   case 0x8E:
   case 0x8F:
	ret = 0xFF;
	break;

   case 0x83:
   case 0x8B:
	FRT_WDT_Update();
	ret = WDT.RSTCSR | 0x1F;
	WDT.RSTCSRM = (WDT.RSTCSR & 0x80);
	break;

   // FIXME: WDT open bus of a sort.
   // case 0x84:
   // case 0x8C:

   //
   //
   //

   case 0x91:
	ret = SBYCR;
	break;

   case 0x92 ... 0x9F:
	//
	// TODO: Emulate jankiness of 16-bit reads from mirror addresses.
	//
	ret = CCR | (CCR << 8);
	break;
   //
   //
   //
   case 0x60:
   case 0x61:
	ret = IPRB >> shift;
	break;

   case 0x62:
   case 0x63:
	ret = VCRA >> shift;
	break;

   case 0x64:
   case 0x65:
	ret = VCRB >> shift;
	break;

   case 0x66:
   case 0x67:
	ret = VCRC >> shift;
	break;

   case 0x68:
   case 0x69:
	ret = VCRD >> shift;
	break;

   case 0x6A: case 0x6B: case 0x6C: case 0x6D: case 0x6E: case 0x6F:
	ret = 0xFFFF >> shift;
	break;

   case 0xE0:
   case 0xE1:
	ret = (ICR | (NMILevel << 15)) >> shift;
	break;

   case 0xE2:
   case 0xE3:
	ret = IPRA >> shift;
	break;

   case 0xE4:
   case 0xE5:
	ret = VCRWDT >> shift;
	break;

   case 0xE6: case 0xE7:
   case 0xE8: case 0xE9: case 0xEA: case 0xEB: case 0xEC: case 0xED: case 0xEE: case 0xEF:
   case 0xF0: case 0xF1: case 0xF2: case 0xF3: case 0xF4: case 0xF5: case 0xF6: case 0xF7:
   case 0xF8: case 0xF9: case 0xFA: case 0xFB: case 0xFC: case 0xFD: case 0xFE: case 0xFF:
	ret = 0xFFFF >> shift;
	break;
  }

  return ret;
 }
}

template<typename T>
void INLINE SH7095::BSC_BusWrite(uint32 A, T V, const bool BurstHax, int32* SH2DMAHax)
{
 uint32 DB = SH7095_DB;

 if(!BurstHax)
  SH7095_mem_timestamp += (SH7095_mem_timestamp == BSC.last_mem_time) & BSC.last_mem_type;

 if(A < 0x02000000)	// CS0, configured as 16-bit
 {
  if(sizeof(T) == 4)
  {
   // TODO/FIXME: Don't allow DMA transfers to occur between the two 16-bit accesses.
   //if(!SH2DMAHax)
   // SH7095_BusLock++;

   DB = (DB & 0xFFFF0000) | (V >> 16);
   BusRW_DB_CS0<uint16, true>(A, DB, BurstHax, SH2DMAHax);

   DB = (DB & 0xFFFF0000) | (uint16)V;
   BusRW_DB_CS0<uint16, true>(A | 2, DB, BurstHax, SH2DMAHax);

   //if(!SH2DMAHax)
   // SH7095_BusLock--;
  }
  else
  {
   const uint32 shift = ((A & 1) ^ (2 - sizeof(T))) << 3;
   const uint32 mask = (0xFFFF >> ((2 - sizeof(T)) * 8)) << shift;

   DB = (DB & ~mask) | (V << shift);
   BusRW_DB_CS0<T, true>(A, DB, BurstHax, SH2DMAHax);
  }
 }
 else if(A >= 0x06000000)	// CS3; 32-bit
 {
  const uint32 shift = ((A & 3) ^ (4 - sizeof(T))) << 3;
  const uint32 mask = (0xFFFFFFFF >> ((4 - sizeof(T)) * 8)) << shift;

  DB = (DB & ~mask) | (V << shift);
  BusRW_DB_CS3<T, true>(A, DB, BurstHax, SH2DMAHax);

  if(!BurstHax)
  {
   if(!SH2DMAHax)
   {
    if(SH7095_mem_timestamp < BSC.sdram_finish_time)
     SH7095_mem_timestamp = BSC.sdram_finish_time;

    SH7095_mem_timestamp += 2;
    BSC.sdram_finish_time = SH7095_mem_timestamp + 2;
   }
   else
    *SH2DMAHax += 3;
  }
 }
 else	// CS1, CS2; 32-bit
 {
  const uint32 shift = ((A & 3) ^ (4 - sizeof(T))) << 3;
  const uint32 mask = (0xFFFFFFFF >> ((4 - sizeof(T)) * 8)) << shift;

  DB = (DB & ~mask) | (V << shift);
  BusRW_DB_CS12<T, true>(A, DB, BurstHax, SH2DMAHax);
 }

 SH7095_DB = DB;

 if(!BurstHax)
 {
  BSC.last_mem_addr = A;
  BSC.last_mem_type = 0;
  BSC.last_mem_time = SH7095_mem_timestamp;
 }
}

template<typename T>
T INLINE SH7095::BSC_BusRead(uint32 A, const bool BurstHax, int32* SH2DMAHax)
{
 //
 //
 //
 uint32 DB = SH7095_DB;
 T ret;

 if(!BurstHax)
  SH7095_mem_timestamp += (SH7095_mem_timestamp == BSC.last_mem_time) & (bool)((BSC.last_mem_addr ^ A) & 0x06000000);

 if(A < 0x02000000)	// CS0, configured as 16-bit
 {
  if(sizeof(T) == 4)
  {
   // TODO/FIXME: Don't allow DMA transfers to occur between the two 16-bit accesses.
   //if(!SH2DMAHax)
   // SH7095_BusLock++;

   BusRW_DB_CS0<uint16, false>(A, DB, BurstHax, SH2DMAHax);
   ret = DB << 16;

   BusRW_DB_CS0<uint16, false>(A | 2, DB, BurstHax, SH2DMAHax);
   ret |= (uint16)DB;

   //if(!SH2DMAHax)
   // SH7095_BusLock--;
  }
  else
  {
   BusRW_DB_CS0<T, false>(A, DB, BurstHax, SH2DMAHax);
   ret = DB >> (((A & 1) ^ (2 - sizeof(T))) << 3);
  }
 }
 else if(A >= 0x06000000)	// CS3; 32-bit
 {
  BusRW_DB_CS3<T, false>(A, DB, BurstHax, SH2DMAHax);
  ret = DB >> (((A & 3) ^ (4 - sizeof(T))) << 3);

  // SDRAM leaves data bus in a weird state after read...
  // DB = 0;

  if(!BurstHax)
  {
   if(!SH2DMAHax)
   {
    if(SH7095_mem_timestamp < BSC.sdram_finish_time)
     SH7095_mem_timestamp = BSC.sdram_finish_time;

    SH7095_mem_timestamp += 7;
   }
   else
    *SH2DMAHax += 6;
  }
 }
 else	// CS1, CS2; 32-bit
 {
  BusRW_DB_CS12<T, false>(A, DB, BurstHax, SH2DMAHax);
  ret = DB >> (((A & 3) ^ (4 - sizeof(T))) << 3);
 }

 SH7095_DB = DB;

 if(!BurstHax)
 {
  BSC.last_mem_addr = A;
  BSC.last_mem_type = 1;
  BSC.last_mem_time = SH7095_mem_timestamp;
 }

 return ret;
}


template<bool SlavePenalty, typename T, bool BurstHax>
INLINE T SH7095::ExtBusRead_INLINE(uint32 A)
{
 T ret;

 A &= (1U << 27) - 1;

 if(timestamp > SH7095_mem_timestamp)
  SH7095_mem_timestamp = timestamp;

 //
 if(!BurstHax)
 {
  DMA_PenaltyKludgeAccum += DMA_PenaltyKludgeAmount;
 }
 //
#ifdef MDFN_ENABLE_DEV_BUILD
 CheckDMARace(A, sizeof(T), false);
#endif
 if(SlavePenalty && !BurstHax)
 {
  if(SH7095_mem_timestamp > (BSC.last_mem_time + 1))
   SH7095_mem_timestamp += 2;
  else
   SH7095_mem_timestamp++;
 }

 ret = BSC_BusRead<T>(A, BurstHax, NULL);

 if(SlavePenalty && !BurstHax)
 {
  SH7095_mem_timestamp++;
 }

 return ret;
}

template<bool SlavePenalty, typename T>
INLINE void SH7095::ExtBusWrite_INLINE(uint32 A, T V)
{
 A &= (1U << 27) - 1;

 if(timestamp > SH7095_mem_timestamp)
  SH7095_mem_timestamp = timestamp;

 //
 DMA_PenaltyKludgeAccum += DMA_PenaltyKludgeAmount;
 //
#ifdef MDFN_ENABLE_DEV_BUILD
 CheckDMARace(A, sizeof(T), true);
#endif

 if(SlavePenalty)
  SH7095_mem_timestamp++;

 BSC_BusWrite<T>(A, V, false, NULL);

 if(SlavePenalty)
 {
  if(SH7095_mem_timestamp < BSC.sdram_finish_time)
   SH7095_mem_timestamp = BSC.sdram_finish_time;

  SH7095_mem_timestamp++;
 }

 write_finish_timestamp = SH7095_mem_timestamp;
}

template<unsigned w, bool SlavePenalty, typename T, bool BurstHax>
static NO_INLINE MDFN_HOT T ExtBusRead_NI(uint32 A)
{
 return CPU[w].ExtBusRead_INLINE<SlavePenalty, T, BurstHax>(A);
}

template<unsigned w, bool SlavePenalty, typename T>
static NO_INLINE MDFN_HOT void ExtBusWrite_NI(uint32 A, T V)
{
 CPU[w].ExtBusWrite_INLINE<SlavePenalty, T>(A, V);
}

template<unsigned w, typename T>
static NO_INLINE MDFN_HOT T OnChipRegRead_NI(uint32 A)
{
 return CPU[w].OnChipRegRead_INLINE<T>(A);
}

template<typename T>
INLINE void SH7095::DevBuild_ReadLog(uint32 A)
{
#ifdef MDFN_ENABLE_DEV_BUILD
  if((A & 0xC7FFFFFF) >= 0x06000200 && (A & 0xC7FFFFFF) <= 0x060003FF)
  {
   const uint32 pcm = PC & 0x07FFFFFF;
   bool match = (pcm >= 0x100000) && (pcm < 0x06000600 || pcm >= 0x06000A00);

   if(match && !BWMIgnoreAddr[0][A & 0x1FF])
   {
    SS_DBG(SS_DBG_BIOS, "[%s] Read from BIOS area of RAM 0x%08x; PC=0x%08x\n", cpu_name, A, PC);
   }
  }

  if((A & 0xC7FFFFFF) >= 0x00000200/*0x00000004*//*0x00000000*/ && (A & 0xC7FFFFFF) <= 0x000FFFFF)
  {
   const uint32 pcm = PC & 0x07FFFFFF;
   bool match = (pcm >= 0x100000) && (pcm < 0x06000600 || pcm >= 0x06000A00);

   if(match)
    SS_DBG(SS_DBG_BIOS, "[%s] Read from BIOS ROM 0x%06x; PC=0x%08x\n", cpu_name, A, PC);
  }
#endif
}

template<typename T>
INLINE void SH7095::DevBuild_WriteLog(uint32 A, T V)
{
#ifdef MDFN_ENABLE_DEV_BUILD
  if((A & 0xC7FFFFFF) >= 0x06000200 && (A & 0xC7FFFFFF) <= 0x060003FF)
  {
   const uint32 pcm = PC & 0x07FFFFFF;
   bool match = (pcm >= 0x100000) && (pcm < 0x06000600 || pcm >= 0x06000800);

   if(match && !BWMIgnoreAddr[1][A & 0x1FF])
   {
    SS_DBG(SS_DBG_BIOS, "[%s] Write to BIOS area of RAM 0x%08x; PC=0x%08x\n", cpu_name, A, PC);
   }
  }
#endif
}

//
//
//
static const struct
{
 uint8 AND;
 uint8 OR;
} LRU_Update_Tab[4] =
{
 { (1 << 2) | (1 << 1) | (1 << 0), /**/ (0 << 5) | (0 << 4) | (0 << 3) },	// Way 0
 { (1 << 4) | (1 << 3) | (1 << 0), /**/ (1 << 5) | (0 << 2) | (0 << 1) },	// Way 1
 { (1 << 5) | (1 << 3) | (1 << 1), /**/ (1 << 4) | (1 << 2) | (0 << 0) },	// Way 2
 { (1 << 5) | (1 << 4) | (1 << 2), /**/ (1 << 3) | (1 << 1) | (1 << 0) },	// Way 3
};

static const int8 LRU_Replace_Tab[0x40] =
{
 /* 0x00 */ 0x03, 0x02,   -1, 0x02, 0x03,   -1, 0x01, 0x01,   -1, 0x02,   -1, 0x02,   -1,   -1, 0x01, 0x01,
 /* 0x10 */ 0x03,   -1,   -1,   -1, 0x03,   -1, 0x01, 0x01,   -1,   -1,   -1,   -1,   -1,   -1, 0x01, 0x01,
 /* 0x20 */ 0x03, 0x02,   -1, 0x02, 0x03,   -1,   -1,   -1,   -1, 0x02,   -1, 0x02,   -1,   -1,   -1,   -1,
 /* 0x30 */ 0x03,   -1,   -1,   -1, 0x03,   -1,   -1,   -1, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static INLINE uint32 cmov_eq_thing(const uint32 reg_compval, const uint32 mem_compval, uint32 var, const uint32 repl_var)
{
 #ifdef ARCH_X86
 asm(	"cmpl %1, %2\n\t"
	"cmove %3,%0\n\t"
	: "+r"(var)
	: "r"(reg_compval), "g"(mem_compval), "r"(repl_var)
	: "cc");
 #else
  #ifdef __GNUC__
   #warning "Conditional move inline assembly not being used."
  #endif
 var = ((reg_compval == mem_compval) ? repl_var : var);
 #endif

 return var;
}

INLINE void SH7095::Cache_AssocPurge(const uint32 A)
{
 const uint32 ATM = A & (0x7FFFF << 10);
 auto* cent = &Cache[(A >> 4) & 0x3F];

 SS_DBG(SS_DBG_SH2_CACHE_NOISY, "[%s] Associative purge; address=0x%08x\n", cpu_name, A);

 // Ignore two-way-mode bit in CCR here.
 cent->Tag[0] |= (ATM == cent->Tag[0]);	// Set invalid bit to 1.
 cent->Tag[1] |= (ATM == cent->Tag[1]);
 cent->Tag[2] |= (ATM == cent->Tag[2]);
 cent->Tag[3] |= (ATM == cent->Tag[3]);
}

INLINE int SH7095::Cache_FindWay(CacheEntry* const cent, const uint32 ATM)
{
#if defined(HAVE_SSE2_INTRINSICS)
 __m128i atm = _mm_set1_epi32(ATM);
 __m128i v1234 = _mm_setr_epi32(1, 2, 3, 4);
 __m128i tmp;

 tmp = _mm_cmpeq_epi32(_mm_load_si128((__m128i*)cent->Tag), atm);
 tmp = _mm_and_si128(tmp, v1234);
 tmp = _mm_max_epi16(tmp, _mm_shuffle_epi32(tmp, (3 << 0) | (2 << 2) | (1 << 4) | (0 << 6)));
 tmp = _mm_max_epi16(tmp, _mm_shuffle_epi32(tmp, (1 << 0) | (0 << 2)));

 return _mm_cvtsi128_si32(tmp) - 1;
#else
 int way_match = -1;

 way_match = cmov_eq_thing(ATM, cent->Tag[0], way_match, 0);
 way_match = cmov_eq_thing(ATM, cent->Tag[1], way_match, 1);
 way_match = cmov_eq_thing(ATM, cent->Tag[2], way_match, 2);
 way_match = cmov_eq_thing(ATM, cent->Tag[3], way_match, 3);

 return way_match;
#endif
}

template<typename T>
INLINE void SH7095::Cache_WriteUpdate(uint32 A, T V)
{
 const uint32 ATM = A & (0x7FFFF << 10);
 const unsigned ena = (A >> 4) & 0x3F;
 CacheEntry* cent = &Cache[ena];
 const int way_match = Cache_FindWay(cent, ATM);

 if(MDFN_LIKELY(way_match >= 0)) // Cache hit!
 {
  Cache_LRU[ena] = (Cache_LRU[ena] & LRU_Update_Tab[way_match].AND) | LRU_Update_Tab[way_match].OR;
  MDFN_ennsb<T, true>(&cent->Data[way_match][NE32ASU8_IDX_ADJ(T, A & 0x0F)], V);	// Ignore CCR OD bit here.
 }
}

template<typename T>
INLINE void SH7095::Cache_WriteAddressArray(uint32 A, T V)
{
 const unsigned way = (CCR >> 6) & 0x3;
 const unsigned ena = (A >> 4) & 0x3F;

 SS_DBG(SS_DBG_SH2_CACHE_NOISY, "[%s] %zu-byte write to cache address array area; address=0x%08x value=0x%x\n", cpu_name, sizeof(T), A, V);

 Cache[ena].Tag[way] = (A & (0x7FFFF << 10)) | (!(A & 0x4));
 Cache_LRU[ena] = (V >> 4) & 0x3F;
}

template<typename T>
INLINE void SH7095::Cache_WriteDataArray(uint32 A, T V)
{
 const unsigned way = (A >> 10) & 0x3;
 const unsigned ena = (A >> 4) & 0x3F;

 SS_DBG(SS_DBG_SH2_CACHE_NOISY, "[%s] %zu-byte write to cache data array area; address=0x%08x value=0x%x\n", cpu_name, sizeof(T), A, V);

 MDFN_ennsb<T, true>(&Cache[ena].Data[way][NE32ASU8_IDX_ADJ(T, A & 0x0F)], V);
}

template<typename T>
INLINE T SH7095::Cache_ReadAddressArray(uint32 A)
{
 const unsigned way = (CCR >> 6) & 0x3;
 const unsigned ena = (A >> 4) & 0x3F;

 SS_DBG(SS_DBG_SH2_CACHE_NOISY, "[%s] %zu-byte read from cache address array area; address=0x%08x\n", cpu_name, sizeof(T), A);

 return (Cache[ena].Tag[way] & (0x7FFFF << 10)) | ((~Cache[ena].Tag[way] & 1) << 2) | (Cache_LRU[ena] << 4);
}

template<typename T>
INLINE T SH7095::Cache_ReadDataArray(uint32 A)
{
 const unsigned way = (A >> 10) & 0x3;
 const unsigned ena = (A >> 4) & 0x3F;

 SS_DBG(SS_DBG_SH2_CACHE_NOISY, "[%s] %zu-byte read from cache data array area; address=0x%08x\n", cpu_name, sizeof(T), A);

 return MDFN_densb<T, true>(&Cache[ena].Data[way][NE32ASU8_IDX_ADJ(T, A & 0x0F)]);
}

template<typename T>
INLINE void SH7095::Cache_CheckReadIncoherency(CacheEntry* cent, const int way, const uint32 A)
{
 if((SH7095_FastMap[A >> SH7095_EXT_MAP_GRAN_BITS] + (A & ~((1U << SH7095_EXT_MAP_GRAN_BITS) - 1))) == (uintptr_t)fmap_dummy)
  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2_CACHE | SS_DBG_SH2_CACHE_NOISY, "[%s] Cacheable %zu-byte read from non-RAM address 0x%08x!\n", cpu_name, sizeof(T), A);
 else if(ne16_rbo_be<T>(SH7095_FastMap[A >> SH7095_EXT_MAP_GRAN_BITS], A) != MDFN_densb<T, true>(&cent->Data[way][NE32ASU8_IDX_ADJ(T, A & 0x0F)]))
  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2_CACHE | SS_DBG_SH2_CACHE_NOISY, "[%s] Cache incoherency for %zu-byte read from address 0x%08x!\n", cpu_name, sizeof(T), A);
}

#define MemRead(IsInstr, T, region, CacheEnabled, A_, outval_, A, unmasked_A, cent, way_match)			\
{														\
 __label__ EBRCase, MemReturn;											\
 T retval;													\
 retval = 0;													\
 A = (A_);													\
 unmasked_A = A;												\
														\
 if(IsInstr <= 0)												\
 {														\
  if(MDFN_UNLIKELY(A & (sizeof(T) - 1)))									\
  {														\
   SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Misaligned %zu-byte read from 0x%08x\n", cpu_name, sizeof(T), A);	\
   A &= ~(sizeof(T) - 1);											\
   SetPEX(PEX_CPUADDR);												\
  }														\
 }														\
														\
 if(IsInstr <= 0)												\
  MA_until = std::max<sscpu_timestamp_t>(MA_until, timestamp + 1);						\
 else														\
  timestamp = std::max<sscpu_timestamp_t>(MA_until, timestamp);							\
														\
 DevBuild_ReadLog<T>(A); 											\
														\
 switch(region)													\
 {														\
  case 0:													\
	if(MDFN_LIKELY(CacheEnabled))										\
	{													\
	 uint32 ATM;												\
														\
	 ATM = A & (0x7FFFF << 10);										\
	 cent = &Cache[(A >> 4) & 0x3F];									\
														\
	 way_match = Cache_FindWay(cent, ATM);									\
														\
	 if(MDFN_UNLIKELY(way_match < 0)) /* Cache miss! */							\
	 {													\
	  way_match = LRU_Replace_Tab[Cache_LRU[(A >> 4) & 0x3F] & CCRC_Replace_AND] | CCRC_Replace_OR[(bool)IsInstr];		\
														\
	  if(MDFN_UNLIKELY(way_match < 0))									\
	   goto EBRCase;											\
														\
	  /*                        */										\
	  /* Load cache line.       */										\
	  /*                        */										\
	  /*printf("Cache load line: %08x\n", A);*/								\
	  cent->Tag[way_match] = ATM;										\
	  /* Don't use ATM after this point. */									\
	  CHECK_EXIT_RESUME();											\
	  {													\
	   unsigned di = (A + 4 + 0) & 0xC; MDFN_ennsb<uint32, true>(&cent->Data[way_match][di], ExtBusRead(uint32, false, (A &~ 0xF) + di));	\
	  }													\
	  for(unsigned i = 4; i < 16; i += 4)									\
	  {													\
	   unsigned di = (A + 4 + i) & 0xC; MDFN_ennsb<uint32, true>(&cent->Data[way_match][di], ExtBusRead(uint32,  true, (A &~ 0xF) + di));	\
	  }													\
	  if(IsInstr <= 0)											\
	   MA_until = std::max<sscpu_timestamp_t>(MA_until, SH7095_mem_timestamp + 1);				\
	  else													\
	   timestamp = SH7095_mem_timestamp;									\
	 }													\
														\
	 Cache_CheckReadIncoherency<T>(cent, way_match, A);							\
														\
	 Cache_LRU[(A >> 4) & 0x3F] = (Cache_LRU[(A >> 4) & 0x3F] & LRU_Update_Tab[way_match].AND) | LRU_Update_Tab[way_match].OR;	\
														\
         /* Ugggghhhh.... */											\
         if(CacheBypassHack && FMIsWriteable[A >> SH7095_EXT_MAP_GRAN_BITS])					\
	 {													\
          retval = ne16_rbo_be<T>(SH7095_FastMap[A >> SH7095_EXT_MAP_GRAN_BITS], A);				\
	  goto MemReturn;											\
	 }													\
														\
  	 retval = MDFN_densb<T, true>(&cent->Data[way_match][NE32ASU8_IDX_ADJ(T, A & 0x0F)]);			\
	 goto MemReturn;											\
	}													\
	/* Fall-through, no break here */									\
  case 1:													\
	EBRCase:												\
	CHECK_EXIT_RESUME();											\
	{													\
	 retval = ExtBusRead(T, false, A);								\
														\
	 if(IsInstr <= 0)											\
	  MA_until = std::max<sscpu_timestamp_t>(MA_until, SH7095_mem_timestamp + 1);				\
	 else													\
	 {													\
	  timestamp = SH7095_mem_timestamp;									\
	  UCRead_IF_Kludge = true;										\
	 }													\
														\
	 goto MemReturn;											\
	}													\
														\
  case 2:													\
  case 5:													\
	/*								*/					\
	/* Associative purge(apparently returns open bus of some sort)	*/					\
	/*								*/					\
	Cache_AssocPurge(A);											\
	retval = ~0;												\
	goto MemReturn;												\
														\
  case 3:													\
	/*				   		*/							\
	/* Direct cache address/tag access 		*/							\
	/*				   		*/							\
	/* Note: bits 0, 1, 3, 29, 30, 31 are some sort	*/							\
	/*       of open-bus(unemulated). 		*/							\
	/*				   		*/							\
	retval = Cache_ReadAddressArray<T>(A);									\
	goto MemReturn;												\
														\
  case 4:													\
  case 6:													\
	/*			    */										\
	/* Direct cache data access */										\
	/*			    */										\
	retval = Cache_ReadDataArray<T>(A);									\
	goto MemReturn;												\
														\
  case 7:													\
	retval = OnChipRegRead(T, unmasked_A);									\
	goto MemReturn;												\
 }														\
 MemReturn: outval_ = retval;											\
}

#define MemWrite(T, region, CacheEnabled, A_, V_, A, unmasked_A, V)		\
{										\
 A = (A_);									\
 unmasked_A = A;								\
 V = (V_);									\
										\
 if(MDFN_UNLIKELY(A & (sizeof(T) - 1)))						\
 {										\
  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] Misaligned %zu-byte write of 0x%08x to 0x%08x\n", cpu_name, sizeof(T), V, A);	\
  A &= ~(sizeof(T) - 1);							\
  SetPEX(PEX_CPUADDR);								\
 }										\
										\
 MA_until = std::max<sscpu_timestamp_t>(MA_until, timestamp + 1);		\
										\
 DevBuild_WriteLog<T>(A, V);							\
										\
 switch(region)									\
 {										\
  case 0:									\
	if(MDFN_LIKELY(CacheEnabled))						\
	 Cache_WriteUpdate<T>(A, V);						\
	/* Fall-through, no break */						\
  case 1:									\
  	MA_until = std::max<sscpu_timestamp_t>(MA_until, write_finish_timestamp + 1);	\
										\
	if(!SH7095_BusLock) { CHECK_EXIT_RESUME(); }				\
	ExtBusWrite(T, A, V);							\
	break;									\
										\
  case 2:									\
  case 5:									\
	/*		      */						\
	/* Associative purge. */						\
	/*		      */						\
	Cache_AssocPurge(A);							\
	break;									\
										\
  case 3:									\
	/*				   */					\
	/* Direct cache address/tag access */					\
	/*				   */					\
	/* TODO: Check non-32 bit access   */					\
	timestamp++;								\
	MA_until = std::max<sscpu_timestamp_t>(MA_until, timestamp + 1);	\
										\
	Cache_WriteAddressArray<T>(A, V);					\
	break;									\
										\
  case 4:									\
  case 6:									\
	/*			    */						\
	/* Direct cache data access */						\
	/*			    */						\
	Cache_WriteDataArray<T>(A, V);						\
	break;									\
										\
  case 7:									\
	OnChipRegWrite<T>(unmasked_A, V);					\
	break;									\
 }										\
}

#define CHECK_EXIT_RESUME() { if(NeedSlaveCall > 0) CPU[1].RunSlaveUntil(timestamp); if(NeedSlaveCall < 0) CPU[1].RunSlaveUntil_Debug(timestamp); }
#define OnChipRegRead(T, A) OnChipRegRead_INLINE<T>(A)
#define ExtBusRead(T, BurstHax, A) ExtBusRead_NI<which, false, T, BurstHax>(A)
#define ExtBusWrite(T, A, V) ExtBusWrite_NI<which, false, T>(A, V)
template<unsigned which, int NeedSlaveCall, bool CacheBypassHack, typename T, unsigned region, bool CacheEnabled, int32 IsInstr>
INLINE T SH7095::MemReadRT(uint32 A)
{
 static_assert(region < 0x8, "Wrong region argument.");
 static_assert(!NeedSlaveCall || (!which && region < 2), "Wrong arguments.");
 static_assert(IsInstr >= 0 || (CacheEnabled && region == 0x0), "Wrong arguments.");
 T ret;
 uint32 unmasked_A;
 CacheEntry* cent;
 int way_match;

 MemRead(IsInstr, T, region, CacheEnabled, A, ret, A, unmasked_A, cent, way_match);

 return ret;
}

template<unsigned which, int NeedSlaveCall, typename T, unsigned region, bool CacheEnabled>
INLINE void SH7095::MemWriteRT(uint32 A, T V)
{
 static_assert(region < 0x8, "Wrong region argument.");
 static_assert(!NeedSlaveCall || (!which && region < 2), "Wrong arguments.");
 uint32 unmasked_A;

 MemWrite(T, region, CacheEnabled, A, V, A, unmasked_A, V);
}
#undef CHECK_EXIT_RESUME
#undef OnChipRegRead
#undef ExtBusRead
#undef ExtBusWrite

template<unsigned which, int NeedSlaveCall, bool CacheBypassHack, typename T, unsigned region, bool CacheEnabled, int32 IsInstr>
static NO_INLINE MDFN_HOT MDFN_FASTCALL T C_MemReadRT(uint32 A)
{
 return CPU[which].MemReadRT<which, NeedSlaveCall, CacheBypassHack, T, region, CacheEnabled, IsInstr>(A);
}

template<unsigned which, int NeedSlaveCall, typename T, unsigned region, bool CacheEnabled>
static NO_INLINE MDFN_HOT MDFN_FASTCALL void C_MemWriteRT(uint32 A, T V)
{
 CPU[which].MemWriteRT<which, NeedSlaveCall, T, region, CacheEnabled>(A, V);
}

INLINE void SH7095::SetCCR(uint8 V)
{
 if(CCR != V)
  SS_DBG(SS_DBG_SH2_CACHE | SS_DBG_SH2_CACHE_NOISY, "[%s] CCR changed: 0x%02x->0x%02x%s\n", cpu_name, CCR, V, (V & CCR_CP) ? " (CACHE PURGE!)" : "");

 if(V & CCR_CP)
 {
  for(unsigned entry = 0; entry < 64; entry++)
  {
   Cache_LRU[entry] = 0;
   for(unsigned way = 0; way < 4; way++)
    Cache[entry].Tag[way] |= 1;	// Set invalid bit to 1.
  }
  V &= ~CCR_CP;
 }

 //if(MDFN_LIKELY(CCR != V))
 {
  CCR = V;
  //
  //
  CCRC_Replace_AND = (CCR & CCR_TW) ? 0x1 : 0x3F;
  CCRC_Replace_OR[0] = (CCR & CCR_OD) ? -1 : 0;
  CCRC_Replace_OR[1] = (CCR & CCR_ID) ? -1 : 0;

  RecalcMRWFP_0();
 }
}




/*


*/
void NO_INLINE SH7095::Reset(bool power_on_reset, bool from_internal_wdt)
{
 if(timestamp == SS_EVENT_DISABLED_TS)
  return;

 if(power_on_reset)
 {
  FRT.lastts = timestamp;

  MA_until = timestamp;
  MM_until = timestamp;

  for(unsigned i = 0; i < 16; i++)
   WB_until[i] = timestamp;

  UCRead_IF_Kludge = 0;

  write_finish_timestamp = timestamp;
  divide_finish_timestamp = timestamp;

  DMA_Timestamp = timestamp;
  DMA_SGEndTimestamp = timestamp;
 }
 //
 VBR = 0;
 SR |= 0xF << 4;
 SetCCR(0);
 //
 if(power_on_reset)
 {
  BSC.BCR1 = (BSC.BCR1 & 0x8000) | 0x03F0;
  BSC.BCR2 = 0xFC;
  BSC.WCR = 0xAAFF;
  BSC.MCR = 0x0000;

  BSC.sdram_finish_time = timestamp;
  BSC.last_mem_time = timestamp;
  BSC.last_mem_addr = 0;
  BSC.last_mem_type = 0;

  BSC.RTCSR = 0x00;
  BSC.RTCSRM = 0x00;
  BSC.RTCNT = 0x00;
  BSC.RTCOR = 0x00;
 }
 //
#ifdef MDFN_ENABLE_DEV_BUILD
 for(unsigned ch = 0; ch < 2; ch++)
  DMADebug[ch].rw[0][0] = ~0U;
#endif

 for(unsigned ch = 0; ch < 2; ch++)
 {
  DMACH[ch].CHCR = 0x00;
  DMACH[ch].CHCRM = 0x00;
  DMACH[ch].DRCR = 0x00;
 }
 DMAOR = 0x00;
 DMA_RecalcRunning();
 RecalcPendingIntPEX();
 //
 INTC_Reset();
 //
 DVCR = 0;
 RecalcPendingIntPEX();
 //
 FRT_Reset();
 WDT_Reset(from_internal_wdt);
 //
 SCI_Reset();
 //
 SBYCR = 0;
 Standby = false;
 //
 //
 //
 EPending = 0;
 SetPEX(power_on_reset ? PEX_POWERON : PEX_RESET);
 Pipe_ID = EPending;
 ResumePoint = nullptr;
}

void NO_INLINE SH7095::INTC_Reset(void)
{
 IPRA = 0;
 IPRB = 0;
 VCRA = 0;
 VCRB = 0;
 VCRC = 0;
 VCRD = 0;
 VCRWDT = 0;
 ICR = 0;

 RecalcPendingIntPEX();
}

void SH7095::SetNMI(bool level)
{
 //printf("NMI: %d, %d %d\n", NMILevel, level, (bool)(ICR & 0x100));
 if(NMILevel != level && level == (bool)(ICR & 0x100))
 {
  SS_DBG(SS_DBG_WARNING | SS_DBG_SH2, "[%s] NMI - Standby=%u\n", cpu_name, Standby);

  SetPEX(PEX_NMI);

  if(Standby)
  {
   WDT.WTCSR |= 0x08;
   FRT_WDT_Recalc_NET();
  }
  else
  {
   DMAOR |= 0x02;	// TODO: NMIF; set always, or only when DMA was active?
   DMA_RecalcRunning();
  }
 }
 NMILevel = level;
}

void SH7095::SetMD5(bool level)
{
 BSC.BCR1 = (BSC.BCR1 & 0x7FFF) | (level << 15);
}

void SH7095::SetIRL(unsigned level)
{
 assert(level < 16);

 IRL = level;
 RecalcPendingIntPEX();
}

void SH7095::ForceInternalEventUpdates(void)
{
 if(MDFN_UNLIKELY(timestamp == SS_EVENT_DISABLED_TS))
  return;

 FRT_WDT_Update();
 FRT_WDT_Recalc_NET();
}

//
// Default priority(for same ipr value), highest to lowest: 
//  NMI
//  User break
//  IRL15
//  [...]
//  IRL1
//  DIVU
//  DMAC0
//  DMAC1
//  WDT
//  REF
//  SCI-ERI
//  SCI-RXI
//  SCI-TXI
//  SCI-TEI
//  FRT-ICI
//  FRT-OCI
//  FRT-OVI
//
//
uint8 INLINE SH7095::GetPendingInt(uint8* vecnum_out)
{
 unsigned ipr;
 unsigned vecnum;
 unsigned tmp_ipr;

 ipr = IRL;
 vecnum = (IRL >> 1) + VECNUM_INT_BASE;

 if(vecnum_out && (ICR & 0x1) && IRL > 0) // External vec fetch has side effects, make sure to only do it if vecnum_out is non-NULL and ICR & 0x1, and if this is the interrupt being serviced.
  vecnum = ~0U;

 //
 //
 //

 if((DVCR & 0x3) == 0x3 && (tmp_ipr = ((IPRA >> 12) & 0xF)) > ipr)
 {
  ipr = tmp_ipr;
  vecnum = (VCRDIV & 0x7F);
 }

 for(unsigned ch = 0; ch < 2; ch++)
 {
  if((DMACH[ch].CHCR & 0x6) == 0x6 && (tmp_ipr = ((IPRA >> 8) & 0xF)) > ipr)
  {
   ipr = tmp_ipr;
   vecnum = (DMACH[ch].VCR & 0x7F);
  }
 }

 if((WDT.WTCSR & 0x80) && (tmp_ipr = ((IPRA >> 4) & 0xF)) > ipr)
 {
  ipr = tmp_ipr;
  vecnum = (VCRWDT >> 8) & 0x7F;
 }

 //
 //
 //
#if 0
 {
  const uint32 sci_ip_tmp = (SCI.SSR & SCI.SCR & 0xC4) | (SCI.SSR & 0x38);

  if(sci_ip_tmp && (tmp_ipr = ((IPRB >> 12) & 0xF)) > ipr)
  {
   ipr = tmp_ipr;

   if(sci_ip_tmp & 0x38) // ERI(receive error; ORER, PER, FER)
    vecnum = (VCRA >> 8) & 0x7F;
   else if(sci_ip_tmp & 0x40)// RXI(receive data full; RDRF)
    vecnum = (VCRA >> 0) & 0x7F;
   else if(sci_ip_tmp & 0x80)// TXI(transmit data empty; TDRE)
    vecnum = (VCRB >> 8) & 0x7F;
   else if(sci_ip_tmp & 0x04)// TEI(transmit end; TEND)
    vecnum = (VCRB >> 0) & 0x7F;
  }
 }
#endif
 //
 //
 //
 const uint32 frt_ip_tmp = (FRT.FTCSR & FRT.TIER & 0x8E);
 if(frt_ip_tmp && (tmp_ipr = ((IPRB >> 8) & 0xF)) > ipr)
 {
  ipr = tmp_ipr;

  if(frt_ip_tmp & 0x80)	// ICI
   vecnum = (VCRC >> 8) & 0x7F;
  else if(frt_ip_tmp & 0x0C)	// OCIA+OCIB
   vecnum = (VCRC >> 0) & 0x7F;
  else 			// OVI
   vecnum = (VCRD >> 8) & 0x7F;
 }

 if(vecnum_out)
 {
  if(vecnum == ~0U)
   vecnum = ExIVecFetch();

  *vecnum_out = vecnum;
 }

 return ipr;
}

//
// Call after changes to:
//	IRL
//	SR
//
//	IPRA
//	IPRB
//
//	DMACH[*].CHCR
//
//	DVCR
//
//	FRT.FTCSR
//	FRT.TIER
//
void NO_INLINE SH7095::RecalcPendingIntPEX(void)
{
 if(GetPendingInt(NULL) > ((SR >> 4) & 0xF))
  SetPEX(PEX_INT);
 else
  ClearPEX(PEX_INT);
}

static const uint8 InstrDecodeTab[65536] =
{
 #include "sh7095_idecodetab.inc"
};

/*								*/
/* TODO: Stop reading from memory when an exception is pending? */
/*								*/
#define FetchIF()							\
{									\
 if(DebugMode)								\
  PC_IF = PC;								\
									\
 if(EmulateICache)							\
 {									\
  Pipe_IF = (uint16)IBuffer;						\
									\
  if(!(PC & 0x2))							\
  {									\
   MemReadInstr(PC, IBuffer);						\
   Pipe_IF = IBuffer >> 16;						\
  }									\
 }									\
 else									\
 {									\
  if(timestamp < (MA_until - ((int32)(PC & 0x2) << 28)))		\
   timestamp = MA_until;						\
									\
  Pipe_IF = *(uint16*)(SH7095_FastMap[PC >> SH7095_EXT_MAP_GRAN_BITS] + PC);	\
									\
  if(MDFN_UNLIKELY((int32)PC < 0))      /* Mr. Boooones */		\
   Pipe_IF = Cache_ReadDataArray<uint16>(PC);				\
 }									\
 timestamp++;								\
}

#define FetchIF_ForceIBufferFill()					\
{									\
 if(DebugMode)								\
  PC_IF = PC;								\
									\
 if(EmulateICache)							\
 {									\
  MemReadInstr(PC &~ 2, IBuffer);					\
  /*Pipe_IF = (uint16)(IBuffer >> (((PC & 2) ^ 2) << 3));*/		\
  Pipe_IF = (uint16)IBuffer;						\
  if(!(PC & 0x2))							\
   Pipe_IF = IBuffer >> 16;						\
 }									\
 else									\
 {									\
  if(timestamp < MA_until)						\
   timestamp = MA_until;						\
									\
  Pipe_IF = *(uint16*)(SH7095_FastMap[PC >> SH7095_EXT_MAP_GRAN_BITS] + PC);	\
									\
  if(MDFN_UNLIKELY((int32)PC < 0))      /* Mr. Boooones */		\
   Pipe_IF = Cache_ReadDataArray<uint16>(PC);				\
 }									\
 timestamp++;								\
}

#define DoID(IntPreventNext)						\
{									\
 uint32 op = InstrDecodeTab[Pipe_IF];					\
 uint32 epo = EPending;							\
									\
 if(IntPreventNext)							\
 {									\
  epo &= ~(1U << (PEX_INT + EPENDING_PEXBITS_SHIFT));			\
  if(!(epo & (0xFF << EPENDING_PEXBITS_SHIFT)))				\
   epo = 0;								\
 }									\
									\
 if(DebugMode)								\
  PC_ID = PC_IF;							\
									\
 Pipe_ID = Pipe_IF | (op << 24) | epo;					\
}

#define DoIDIF_MACRO(IntPreventNext)					\
{									\
 DoID(IntPreventNext);							\
 FetchIF();								\
}

/* */
/* Not totally correct, but simplifies things...probably :p */
/* */
#define DelayBranch(target_)						\
{									\
 {									\
  const uint32 target = (target_);					\
									\
  if(DebugMode > 0)							\
   DBG_AddBranchTrace(which, target, -1);				\
									\
  PC = target;								\
 }									\
									\
 /* Redecode the opcode from the 16-bit instruction to makes sure */	\
 /* exceptions won't be taken in the delay slot(due to op field   */	\
 /* being forced to 0xFF by OR'ing with EPending in the previous  */ 	\
 /* call to DoID()), and forces usage of the second half of the   */	\
 /* opcode table so we can generate illegal slot instruction      */	\
 /* exceptions as appropriate. */					\
 Pipe_ID = (uint16)Pipe_ID;						\
 Pipe_ID |= (InstrDecodeTab[Pipe_ID] | 0x80) << 24;			\
									\
 if(MDFN_UNLIKELY(PC & 1))						\
 {									\
  /* Pending for the instruction after the delay slot instruction. */	\
  SetPEX(PEX_CPUADDR);							\
 }									\
 else									\
 {									\
  /* This discards the previously-fetched instruction after the */	\
  /* delay slot instruction.  Poor, poor instruction. */		\
  if(EmulateICache)							\
   UCRead_IF_Kludge = false;						\
  FetchIF_ForceIBufferFill()						\
  if(EmulateICache)							\
   timestamp -= (PC >> 1) & UCRead_IF_Kludge; /* WTFBBQ?! */		\
 }									\
}

#define Branch(need_addbt, target_)					\
{									\
 {									\
  const uint32 target = (target_);					\
									\
  if(need_addbt)							\
   DBG_AddBranchTrace(which, target, -1);				\
									\
  PC = target;								\
 }									\
									\
 if(MDFN_UNLIKELY(PC & 1))						\
 {									\
  SetPEX(PEX_CPUADDR);							\
  DoID(false);								\
 }									\
 else									\
 {									\
  /* This sequence discards the previously-fetched two instructions */	\
  /* after the branch instruction. */					\
  if(EmulateICache)							\
   UCRead_IF_Kludge = false;						\
  FetchIF_ForceIBufferFill();						\
  if(EmulateICache)							\
   timestamp -= (PC >> 1) & UCRead_IF_Kludge; /* WTFBBQ?! */		\
  PC += 2;								\
  DoIDIF(false);							\
 }									\
}


/* Remember to use with BEGIN_OP_DLYIDIF instead of BEGIN_OP */
#define UCDelayBranch(target)						\
{									\
 if(DebugMode > 0)							\
  DBG_AddBranchTrace(which, target, -1);				\
									\
 PC = target;								\
									\
 if(DebugMode)								\
  PC_ID = PC_IF;							\
									\
 Pipe_ID = Pipe_IF | ((InstrDecodeTab[Pipe_IF] | 0x80) << 24);		\
									\
 timestamp++;								\
									\
 if(MDFN_UNLIKELY(PC & 1))						\
 {									\
  /* Pending for the instruction after the delay slot instruction. */	\
  SetPEX(PEX_CPUADDR);							\
 }									\
 else									\
 {									\
  FetchIF_ForceIBufferFill();						\
 }									\
}

/* Remember to use with BEGIN_OP_DLYIDIF instead of BEGIN_OP */
#define UCRelDelayBranch(disp) UCDelayBranch(PC + (disp))

#define CondRelBranch(cond, disp)	\
{					\
 if(cond)				\
  Branch(true, PC + (disp));		\
}

#define CondRelDelayBranch(cond, disp)	\
{					\
 if(cond)				\
  DelayBranch(PC + (disp));		\
}

/* Reset/Poweron exception handling. */
#define Exception_ResPow(exnum, vecnum, new_PC)				\
{									\
 timestamp += 2;							\
 timestamp = std::max<sscpu_timestamp_t>(MA_until, timestamp);		\
									\
 MemRead32(((vecnum) + 0) << 2, new_PC);				\
 MemRead32(((vecnum) + 1) << 2, R[15]);					\
									\
 if(DebugMode)								\
  DBG_AddBranchTrace(this - CPU, new_PC, (exnum), (vecnum));		\
									\
 SS_DBGTI(SS_DBG_SH2_EXCEPT, "[%s] Exception %s, New PC=0x%08x, New R15=0x%08x", cpu_name, ((exnum) == EXCEPTION_RESET ? "RESET" : "POWERON"), new_PC, R[15]); \
}

#define Exception(exnum, vecnum, new_PC)				\
{									\
 timestamp += 2;							\
 timestamp = std::max<sscpu_timestamp_t>(MA_until, timestamp);		\
									\
 /* Save SR to stack */							\
 /* Save PC to stack */							\
 /* Read exception vector table */					\
 R[15] -= 4;								\
 MemWrite32(R[15], SR);							\
 timestamp++;								\
 R[15] -= 4;								\
 MemWrite32(R[15], PC);							\
 timestamp++;								\
 timestamp++;								\
 MemRead32(VBR + ((vecnum) << 2), new_PC);				\
 timestamp++;								\
									\
 if(DebugMode)								\
  DBG_AddBranchTrace(this - CPU, new_PC, (exnum), (vecnum));		\
									\
 SS_DBGTI(SS_DBG_SH2_EXCEPT, "[%s] Exception %u, vecnum=0x%02x, VBR=0x%08x, saved PC=0x%08x, New PC=0x%08x, New R15=0x%08x", cpu_name, (exnum), (vecnum), VBR, PC, new_PC, R[15]); \
}


/*
 PC == 0
 instr = [?]
 ID = [?]
 IF = [0]

 PC == 2
 instr = [?]
 ID = [0]
 IF = [2]

 PC == 4
 instr = [0]
 ID = [2]
 IF = [4]

*/

#define DoIDIF(IntPreventNext) DoIDIF_NI<which, EmulateICache, DebugMode, IntPreventNext>()

#define OnChipRegRead(T, A) OnChipRegRead_INLINE<T>(A)
#define ExtBusRead(T, BurstHax, A) ExtBusRead_NI<which, false, T, BurstHax>(A)
#define ExtBusWrite(T, A, V) ExtBusWrite_NI<which, false, T>(A, V)

#define MemReadInstr(A, outval) { outval = (MRFPI[(A) >> 29](A)); }
#define MemRead8(A, outval) { outval = (MRFP8[(A) >> 29](A)); }
#define MemRead16(A, outval) { outval = (MRFP16[(A) >> 29](A)); }
#define MemRead32(A, outval) { outval = (MRFP32[(A) >> 29](A)); }
#define MemRead16_I(A, outval) { outval = (MRFP16_I[(A) >> 29](A)); }
#define MemRead32_I(A, outval) { outval = (MRFP32_I[(A) >> 29](A)); }

#define MemWrite8(A, V) MWFP8[(A) >> 29]((A), (V));
#define MemWrite16(A, V) MWFP16[(A) >> 29]((A), (V));
#define MemWrite32(A, V) MWFP32[(A) >> 29]((A), (V));
#define CHECK_EXIT_RESUME() { if(EmulateICache && !which) { if(DebugMode) CPU[1].RunSlaveUntil_Debug(timestamp); else CPU[1].RunSlaveUntil(timestamp); } }
#define CONST_VAR(T, n) const T n
#define RESUME_VAR(T, n) T n

template<bool EmulateICache, bool DebugMode, bool IntPreventNext>
INLINE void SH7095::DoIDIF_INLINE(void)
{
 DoIDIF_MACRO(IntPreventNext);
}

template<unsigned which, bool EmulateICache, bool DebugMode, bool IntPreventNext>
static NO_INLINE MDFN_HOT void DoIDIF_NI(void)
{
 CPU[which].DoIDIF_INLINE<EmulateICache, DebugMode, IntPreventNext>();
}

template<unsigned which, bool EmulateICache, bool DebugMode>
INLINE void SH7095::Step(void)
{
 //
 // Ideally, we would place SPEPRecover: after the FRT event check, but doing
 // so causes gcc(multiple versions) to produce inconceivably awful code under certain conditions
 // (such as disabling all the SS_DBG stuff at compile-time) because it thinks it's an important loop
 // or something?(even with all our branch hinting!)
 //
 SPEPRecover:;

 if(MDFN_UNLIKELY(timestamp >= FRT_WDT_NextTS))
 {
  FRT_WDT_Update();
  FRT_WDT_Recalc_NET();
 }

 const uint32 instr = (uint16)Pipe_ID;
 const unsigned instr_nyb1 = (instr >> 4) & 0xF;
 const unsigned instr_nyb2 = (instr >> 8) & 0xF;
// asm volatile("":: "a"(instr_nyb1), "d"(instr_nyb2));
 //
 #include "sh7095_ops.inc"
 //
}

#undef CHECK_EXIT_RESUME
#undef DoIDIF
#undef OnChipRegRead
#undef ExtBusRead
#undef ExtBusWrite
#undef MemReadInstr
#undef MemRead8
#undef MemRead16
#undef MemRead32
#undef MemRead16_I
#undef MemRead32_I
#undef MemWrite8
#undef MemWrite16
#undef MemWrite32
#undef CONST_VAR
#undef RESUME_VAR
//
//
//
//
//
#pragma GCC push_options
#pragma GCC optimize("O2,no-gcse") //no-unroll-loops,no-peel-loops,no-crossjumping")

#define DoIDIF(IntPreventNext) DoIDIF_MACRO(IntPreventNext)

#define OnChipRegRead(T, A) OnChipRegRead_NI<1, T>(A)
#define ExtBusRead(T, BurstHax, A) ExtBusRead_NI<1, true, T, BurstHax>(A)
#define ExtBusWrite(T, A, V) ExtBusWrite_NI<1, true, T>(A, V)

#define MemReadInstr(A, outval) MemRead(true,  uint32, ((A) >> 29), (CCR & CCR_CE), (A), outval, /**/ Resume_uint32_A, Resume_unmasked_A, Resume_cent, Resume_way_match)
#define MemRead8(A, outval)	MemRead(false, uint8,  ((A) >> 29), (CCR & CCR_CE), (A), outval, /**/ Resume_uint8_A,  Resume_unmasked_A, Resume_cent, Resume_way_match)
#define MemRead16(A, outval)	MemRead(false, uint16, ((A) >> 29), (CCR & CCR_CE), (A), outval, /**/ Resume_uint16_A, Resume_unmasked_A, Resume_cent, Resume_way_match)
#define MemRead32(A, outval)	MemRead(false, uint32, ((A) >> 29), (CCR & CCR_CE), (A), outval, /**/ Resume_uint32_A, Resume_unmasked_A, Resume_cent, Resume_way_match)
#define MemRead16_I(A, outval)	MemRead(-1,    uint16, ((A) >> 29), (CCR & CCR_CE), (A), outval, /**/ Resume_uint16_A, Resume_unmasked_A, Resume_cent, Resume_way_match)
#define MemRead32_I(A, outval)	MemRead(-1,    uint32, ((A) >> 29), (CCR & CCR_CE), (A), outval, /**/ Resume_uint32_A, Resume_unmasked_A, Resume_cent, Resume_way_match)

#define MemWrite8(A, V)  MemWrite(uint8,  ((A) >> 29), (CCR & CCR_CE), (A), (V), /**/ Resume_uint8_A,  Resume_unmasked_A, Resume_uint8_V)
#define MemWrite16(A, V) MemWrite(uint16, ((A) >> 29), (CCR & CCR_CE), (A), (V), /**/ Resume_uint16_A, Resume_unmasked_A, Resume_uint16_V)
#define MemWrite32(A, V) MemWrite(uint32, ((A) >> 29), (CCR & CCR_CE), (A), (V), /**/ Resume_uint32_A, Resume_unmasked_A, Resume_uint32_V)

#define CHECK_EXIT_RESUME__(n)		\
	{					\
	 if(timestamp >= bound_timestamp)	\
	 {					\
	  ResumePoint = &&Resume_ ## n;		\
	  return;				\
	 }					\
	 Resume_ ## n:;				\
	}

#define CHECK_EXIT_RESUME_(n) CHECK_EXIT_RESUME__(n)
#define CHECK_EXIT_RESUME() CHECK_EXIT_RESUME_(__COUNTER__)

#define instr Resume_instr
#define instr_nyb1 ((instr >> 4) & 0xF)
#define instr_nyb2 ((instr >> 8) & 0xF)
#define opexec_MAC_L_m0 Resume_MAC_L_m0
#define opexec_MAC_L_m1 Resume_MAC_L_m1
#define opexec_MAC_W_m0 Resume_MAC_W_m0
#define opexec_MAC_W_m1 Resume_MAC_W_m1
#define opexec_ea Resume_ea
#define opexec_new_PC Resume_new_PC
#define opexec_new_SR Resume_new_SR
#define opexec_ipr Resume_ipr
#define opexec_exnum Resume_exnum
#define opexec_vecnum Resume_vecnum
#define CONST_VAR(T, n) T n; n
#define RESUME_VAR(T, n) static_assert(std::is_same<T,decltype(n)>::value, "Resume variable type mismatch.")
#define SH7095_NEED_RESUME_TABLE_INIT 1


#define SH7095_DEBUG_MODE 0
#include "sh7095s_cnorm.inc"
static_assert(__COUNTER__ == 5000, "Unexpected __COUNTER__ value.");
NO_CLONE NO_INLINE MDFN_HOT void SH7095::RunSlaveUntil(const sscpu_timestamp_t bound_timestamp)
{
 #include "sh7095s_rsu.inc"
}
#undef SH7095_DEBUG_MODE

#define SH7095_DEBUG_MODE 1
#include "sh7095s_cnorm_dm.inc"
static_assert(__COUNTER__ == 10000, "Unexpected __COUNTER__ value.");
NO_CLONE NO_INLINE MDFN_COLD void SH7095::RunSlaveUntil_Debug(const sscpu_timestamp_t bound_timestamp)
{
 #include "sh7095s_rsu.inc"
}
#undef SH7095_DEBUG_MODE

#pragma GCC pop_options
#undef DoIDIF
#undef OnChipRegRead
#undef ExtBusRead
#undef ExtBusWrite
#undef MemReadInstr
#undef MemRead8
#undef MemRead16
#undef MemRead32
#undef MemRead16_I
#undef MemRead32_I
#undef MemWrite8
#undef MemWrite16
#undef MemWrite32
#undef CHECK_EXIT_RESUME__
#undef CHECK_EXIT_RESUME_
#undef CHECK_EXIT_RESUME
#undef instr
#undef instr_nyb1
#undef instr_nyb2
#undef opexec_MAC_L_m0
#undef opexec_MAC_L_m1
#undef opexec_MAC_W_m0
#undef opexec_MAC_W_m1
#undef opexec_ea
#undef opexec_new_PC
#undef opexec_new_SR
#undef opexec_ipr
#undef opexec_exnum
#undef opexec_vecnum
#undef CONST_VAR
#undef RESUME_VAR
#undef SH7095_NEED_RESUME_TABLE_INIT
//
//
//
//
//
//
void SH7095::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(R),
  SFVAR(PC),
  SFVAR(CtrlRegs),

  SFVAR(timestamp),
  SFVAR(MA_until),
  SFVAR(MM_until),
  SFVAR(write_finish_timestamp),
  SFVAR(WB_until),
  SFVAR(UCRead_IF_Kludge),
  SFVAR(SysRegs),

  SFVAR(EPending),
  SFVAR(Pipe_ID),
  SFVAR(Pipe_IF),

  SFVAR(IBuffer),

  SFPTR32(Cache->Tag, 4, 64, sizeof(*Cache), Cache),
  SFVARN(Cache_LRU, "Cache->LRU"),
  SFPTR32((uint32*)Cache->Data, 16, 64, sizeof(*Cache), Cache),	// Cast because it's stored as native-endian 32-bit.

  SFVAR(CCR),

  SFVAR(NMILevel),
  SFVAR(IRL),

  SFVAR(IPRA),
  SFVAR(IPRB),
  SFVAR(VCRWDT),
  SFVAR(VCRA),
  SFVAR(VCRB),
  SFVAR(VCRC),
  SFVAR(VCRD),
  SFVAR(ICR),

 //
 //
 //
  SFVAR(BSC.BCR1),
  SFVAR(BSC.BCR2),
  SFVAR(BSC.WCR),
  SFVAR(BSC.MCR),
  SFVAR(BSC.RTCSR),
  SFVAR(BSC.RTCSRM),
  SFVAR(BSC.RTCNT),
  SFVAR(BSC.RTCOR),

  SFVAR(BSC.sdram_finish_time),
  SFVAR(BSC.last_mem_time),
  SFVAR(BSC.last_mem_addr),
  SFVAR(BSC.last_mem_type),

  SFVAR(SBYCR),
  SFVAR(Standby),

  SFVAR(FRT.lastts),
  SFVAR(FRT.FTI),
  SFVAR(FRT.FTCI),
  SFVAR(FRT.FRC),
  SFVAR(FRT.OCR),
  SFVAR(FRT.FICR),
  SFVAR(FRT.TIER),
  SFVAR(FRT.FTCSR),
  SFVAR(FRT.FTCSRM),
  SFVAR(FRT.TCR),
  SFVAR(FRT.TOCR),
  SFVAR(FRT.RW_Temp),

  SFVAR(FRT_WDT_ClockDivider),

  SFVAR(FRT_WDT_NextTS),

  SFVAR(WDT.WTCSR),
  SFVAR(WDT.WTCSRM),
  SFVAR(WDT.WTCNT),
  SFVAR(WDT.RSTCSR),
  SFVAR(WDT.RSTCSRM),

 // SFVAR(DMA_ClockCounter),
 // SFVAR(DMA_SGCounter),
  SFVAR(DMA_Timestamp),
  SFVAR(DMA_SGEndTimestamp),
  SFVAR(DMA_RoundRobinRockinBoppin),

  SFVAR(DMA_PenaltyKludgeAmount),
  SFVAR(DMA_PenaltyKludgeAccum),

  SFVAR(DMACH->SAR, 2, sizeof(*DMACH), DMACH),
  SFVAR(DMACH->DAR, 2, sizeof(*DMACH), DMACH),
  SFVAR(DMACH->TCR, 2, sizeof(*DMACH), DMACH),
  SFVAR(DMACH->CHCR, 2, sizeof(*DMACH), DMACH),
  SFVAR(DMACH->CHCRM, 2, sizeof(*DMACH), DMACH),
  SFVAR(DMACH->VCR, 2, sizeof(*DMACH), DMACH),
  SFVAR(DMACH->DRCR, 2, sizeof(*DMACH), DMACH),

  SFVAR(DMAOR),
  SFVAR(DMAORM),

  SFVAR(divide_finish_timestamp),
  SFVAR(DVSR),
  SFVAR(DVDNT),
  SFVAR(DVDNTH),
  SFVAR(DVDNTL),
  SFVAR(DVDNTH_Shadow),
  SFVAR(DVDNTL_Shadow),
  SFVAR(VCRDIV),
  SFVAR(DVCR),

  SFVAR(SCI.SMR),
  SFVAR(SCI.BRR),
  SFVAR(SCI.SCR),
  SFVAR(SCI.TDR),
  SFVAR(SCI.SSR),
  SFVAR(SCI.SSRM),
  SFVAR(SCI.RDR),

  SFVAR(SCI.RSR),
  SFVAR(SCI.TSR),

  SFVAR(ExtHalt),
  SFVAR(ExtHaltDMA),

  SFVAR(PC_IF),
  SFVAR(PC_ID),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, sname);

 if(this == &CPU[1])
  StateAction_SlaveResume(sm, load, data_only, "SH2-S-Resume");
}

void SH7095::StateAction_SlaveResume(StateMem* sm, const unsigned load, const bool data_only, const char* sname)
{
 int32 ResumePointI = -1;
 uint32 Resume_cent_I = 0;

 if(!load)
 {
  if(ResumePoint)
  {
   for(uint32 i = 0; i < 512; i++)
   {
    if(ResumeTableP[DM_Setting][i] == ResumePoint)
    {
     ResumePointI = i;
     break;
    }
   }
   assert(ResumePointI >= 0);
  }
  //printf("State save resume point: %016llx (%d)\n", (unsigned long long)(uintptr_t)ResumePoint, ResumePointI);

  if(Resume_cent)
  {
   Resume_cent_I = Resume_cent - Cache;
   assert(Resume_cent_I < 0x40);
  }
 }

 SFORMAT StateRegs[] =
 {
  SFVAR(ResumePointI),
  SFVAR(Resume_uint8_A),
  SFVAR(Resume_uint16_A),
  SFVAR(Resume_uint32_A),
  SFVAR(Resume_unmasked_A),
  SFVAR(Resume_cent_I),
  SFVAR(Resume_way_match),
  SFVAR(Resume_uint8_V),
  SFVAR(Resume_uint16_V),
  SFVAR(Resume_uint32_V),
  SFVAR(Resume_instr),

  SFVAR(Resume_MAC_L_m0),
  SFVAR(Resume_MAC_L_m1),

  SFVAR(Resume_MAC_W_m0),
  SFVAR(Resume_MAC_W_m1),

  SFVAR(Resume_ea),
  SFVAR(Resume_new_PC),
  SFVAR(Resume_new_SR),

  SFVAR(Resume_ipr),
  SFVAR(Resume_exnum),
  SFVAR(Resume_vecnum),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, sname, load < 0x00102600);

 if(load)
 {
  ResumePoint = nullptr;

  if(ResumePointI >= 0)
  {
   ResumePoint = ResumeTableP[DM_Setting][ResumePointI & 511];
   assert(ResumePoint != nullptr);
  }
  //printf("State load resume point: %016llx (%d)\n", (unsigned long long)(uintptr_t)ResumePoint, ResumePointI);
  Resume_uint16_A &= ~1;
  Resume_uint32_A &= ~3;
  Resume_cent = &Cache[Resume_cent_I & 0x3F];
  Resume_way_match = std::max<int>(-1, std::min<int>(3, Resume_way_match));
  Resume_instr &= 0xFFFF;
 }
}

//
// Only call after all emulated devices variables and RAM have been loaded from the save state.
//
void SH7095::PostStateLoad(const unsigned state_version, const bool recorded_needicache, const bool needicache)
{
 //
 // Fixup cache tags.
 //
 for(unsigned entry = 0; entry < 64; entry++)
 {
  CacheEntry* const ce = &Cache[entry];

  for(unsigned way = 0; way < 4; way++)
  {
   const uint32 ATM = ce->Tag[way] & (0x7FFFF << 10);
   const bool invalid = ce->Tag[way] & ~(0x7FFFF << 10);	// Handles backwards compat when invalid was bit31 instead of bit0.

   ce->Tag[way] = ATM | invalid;
  }
 }
 //
 SetCCR(CCR);
 //
 if(!recorded_needicache && state_version < 0x00102600)
 {
  for(unsigned i = 0; i < 16; i++)
   WB_until[i] = timestamp - 100;
 }

 if(needicache && !recorded_needicache)
 {
  //
  // Handle loading a state where instruction cache emulation was not previously enabled in the emulator, but is enabled now(e.g. via database).
  //
  // May not cover all cases, needs more testing.
  //
  //printf("NeedEmuICache=%d, RecordedNeedEmuICache=%d\n", needicache, recorded_needicache);
  //
  //const uint32 old_IBuffer = IBuffer;
  const uint32 A = (PC - 2) & ~3;

  if((int32)A < 0)
   IBuffer = MDFN_densb<uint32, true>(&Cache[(A >> 4) & 0x3F].Data[(A >> 10) & 0x3][NE32ASU8_IDX_ADJ(uint32, A & 0x0F)]);
  else
   IBuffer = ne16_rbo_be<uint32>(SH7095_FastMap[A >> SH7095_EXT_MAP_GRAN_BITS], A);

  //printf("[%s] PC=0x%08x, IBuffer=0x%08x old_IBuffer=0x%08x --- 0x%08x\n", cpu_name, PC, IBuffer, old_IBuffer, ne16_rbo_be<uint32>(SH7095_FastMap[A >> SH7095_EXT_MAP_GRAN_BITS], A));
 }
 //
 //
 //
 if(state_version < 0x00102300)
 {
  ExtHaltDMA = ExtHalt;
 }

 if(state_version < 0x00102600 && timestamp >= 0x40000000)
 {
  timestamp = SS_EVENT_DISABLED_TS;
 }

 if(timestamp != SS_EVENT_DISABLED_TS)
 {
  if(state_version < 0x00102600)
  {
   DMA_Timestamp = SH7095_mem_timestamp - 128;
   DMA_SGEndTimestamp = SH7095_mem_timestamp + 192;

   BSC.sdram_finish_time = SH7095_mem_timestamp - 100;
   BSC.last_mem_time = SH7095_mem_timestamp - 100;
  }

  clamp(&timestamp, -1000000, 1000000);
  clamp(&FRT.lastts, -1000000, 1000000);
  clamp(&DMA_Timestamp, -1000000, 1000000);
  clamp(&DMA_SGEndTimestamp, -1000000, 1000000);

  clamp(&MA_until, -1000000, 1000000);
  clamp(&MM_until, -1000000, 1000000);

  for(unsigned i = 0; i < 16; i++)
   clamp(&WB_until[i], -1000000, 1000000);

  clamp(&write_finish_timestamp, -1000000, 1000000);
  clamp(&divide_finish_timestamp, -1000000, 1000000);

  clamp(&BSC.sdram_finish_time, -1000000, 1000000);
  clamp(&BSC.last_mem_time, -1000000, 1000000);
 }
 //
 //
 //
 UCRead_IF_Kludge &= 1;
}

//
//
//
//
//
//
//
//

INLINE uint32 SH7095::GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 uint32 ret = 0xDEADBEEF;

 switch(id)
 {
  case GSREG_PC_ID:
	ret = PC_ID;
	break;

  case GSREG_PC_IF:
	ret = PC_IF;
	break;

  case GSREG_PID:
	ret = Pipe_ID;
	break;

  case GSREG_PIF:
	ret = Pipe_IF;
	break;

  case GSREG_EP:
	ret = EPending;
	break;

  case GSREG_RPC:
	ret = PC;
	break;

  case GSREG_R0: case GSREG_R1: case GSREG_R2: case GSREG_R3: case GSREG_R4: case GSREG_R5: case GSREG_R6: case GSREG_R7:
  case GSREG_R8: case GSREG_R9: case GSREG_R10: case GSREG_R11: case GSREG_R12: case GSREG_R13: case GSREG_R14: case GSREG_R15:
	ret = R[id - GSREG_R0];
	break;

  case GSREG_SR:
	ret = SR;
	break;

  case GSREG_GBR:
	ret = GBR;
	break;

  case GSREG_VBR:
	ret = VBR;
	break;

  case GSREG_MACH:
	ret = MACH;
	break;

  case GSREG_MACL:
	ret = MACL;
	break;

  case GSREG_PR:
	ret = PR;
	break;

  //
  //
  //
  case GSREG_NMIL:
	ret = NMILevel;
	break;

  case GSREG_IRL:
	ret = IRL;
	break;

  case GSREG_IPRA:
	ret = IPRA;
	break;

  case GSREG_IPRB:
	ret = IPRB;
	break;

  case GSREG_VCRWDT:
	ret = VCRWDT;
	break;

  case GSREG_VCRA:
	ret = VCRA;
	break;

  case GSREG_VCRB:
	ret = VCRB;
	break;

  case GSREG_VCRC:
	ret = VCRC;
	if(special)
	{
	 trio_snprintf(special, special_len, "FIC: 0x%02x, FOC: 0x%02x", (ret >> 8) & 0x7F, ret & 0x7F);
	}
	break;

  case GSREG_VCRD:
	ret = VCRD;
	break;

  case GSREG_ICR:
	ret = ICR;
	break;
  //
  //
  //
  case GSREG_DVSR:
	ret = DVSR;
	break;

  case GSREG_DVDNT:
	ret = DVDNT;
	break;

  case GSREG_DVDNTH:
	ret = DVDNTH;
	break;

  case GSREG_DVDNTL:
	ret = DVDNTL;
	break;

  case GSREG_DVDNTHS:
	ret = DVDNTH_Shadow;
	break;

  case GSREG_DVDNTLS:
	ret = DVDNTL_Shadow;
	break;

  case GSREG_VCRDIV:
	ret = VCRDIV;
	break;

  case GSREG_DVCR:
	ret = DVCR;
	break;
  //
  //
  //
  case GSREG_WTCSR:
	ret = WDT.WTCSR;
	break;

  case GSREG_WTCSRM:
	ret = WDT.WTCSRM;
	break;

  case GSREG_WTCNT:
	ret = WDT.WTCNT;
	break;

  case GSREG_RSTCSR:
	ret = WDT.RSTCSR;
	break;

  case GSREG_RSTCSRM:
	ret = WDT.RSTCSRM;
	break;
  //
  //
  //
  case GSREG_DMAOR:
	ret = DMAOR;
	break;

  case GSREG_DMAORM:
	ret = DMAORM;
	break;

  case GSREG_DMA0_SAR:
  case GSREG_DMA1_SAR:
	ret = DMACH[id == GSREG_DMA1_SAR].SAR;
	break;

  case GSREG_DMA0_DAR:
  case GSREG_DMA1_DAR:
	ret = DMACH[id == GSREG_DMA1_DAR].DAR;
	break;

  case GSREG_DMA0_TCR:
  case GSREG_DMA1_TCR:
	ret = DMACH[id == GSREG_DMA1_TCR].TCR;
	break;

  case GSREG_DMA0_CHCR:
  case GSREG_DMA1_CHCR:
	ret = DMACH[id == GSREG_DMA1_CHCR].CHCR;
	break;

  case GSREG_DMA0_CHCRM:
  case GSREG_DMA1_CHCRM:
	ret = DMACH[id == GSREG_DMA1_CHCRM].CHCRM;
	break;

  case GSREG_DMA0_VCR:
  case GSREG_DMA1_VCR:
	ret = DMACH[id == GSREG_DMA1_VCR].VCR;
	break;

  case GSREG_DMA0_DRCR:
  case GSREG_DMA1_DRCR:
	ret = DMACH[id == GSREG_DMA1_DRCR].DRCR;
	break;
  //
  //
  //
  case GSREG_FRC:
	ret = FRT.FRC;
	break;

  case GSREG_OCR0:
	ret = FRT.OCR[0];
	break;

  case GSREG_OCR1:
	ret = FRT.OCR[1];
	break;

  case GSREG_FICR:
	ret = FRT.FICR;
	break;

  case GSREG_TIER:
	ret = FRT.TIER;
	break;

  case GSREG_FTCSR:
	ret = FRT.FTCSR;
	break;

  case GSREG_FTCSRM:
	ret = FRT.FTCSRM;
	break;

  case GSREG_TCR:
	ret = FRT.TCR;
	break;

  case GSREG_TOCR:
	ret = FRT.TOCR;
	break;

  case GSREG_RWT:
	ret = FRT.RW_Temp;
	break;
  //
  //
  //
  case GSREG_CCR:
	ret = CCR;
	if(special)
	{
	 trio_snprintf(special, special_len, "CE: %d, ID: %d, OD: %d, TW: %d, WS: %d",
		(bool)(CCR & CCR_CE),
		(bool)(CCR & CCR_ID),
		(bool)(CCR & CCR_OD),
		(bool)(CCR & CCR_TW),
		(CCR >> 6) & 0x3);
	}
	break;

  case GSREG_SBYCR:
	ret = SBYCR;
	break;
 }

 return ret;
}

void SH7095::SetRegister(const unsigned id, const uint32 value)
{
 switch(id)
 {
  //case GSREG_PC: break;

  case GSREG_PID:
	Pipe_ID = value;
	break;

  case GSREG_PIF:
	Pipe_IF = value;
	break;

  //case GSREG_EP:
  //	EPending = value;
  //	break;

  case GSREG_RPC:
	PC = value;
	break;

  case GSREG_R0: case GSREG_R1: case GSREG_R2: case GSREG_R3: case GSREG_R4: case GSREG_R5: case GSREG_R6: case GSREG_R7:
  case GSREG_R8: case GSREG_R9: case GSREG_R10: case GSREG_R11: case GSREG_R12: case GSREG_R13: case GSREG_R14: case GSREG_R15:
	R[id - GSREG_R0] = value;
	break;

  case GSREG_SR:
	SR = value & 0x3F3;
	RecalcPendingIntPEX();
	break;

  case GSREG_GBR:
	GBR = value;
	break;

  case GSREG_VBR:
	VBR = value;
	break;

  case GSREG_MACH:
	MACH = value;
	break;

  case GSREG_MACL:
	MACL = value;
	break;

  case GSREG_PR:
	PR = value;
	break;

  //
  //
  //
  case GSREG_FTCSR:	
	FRT.FTCSR = value & 0x8F;
	RecalcPendingIntPEX();
	FRT_CheckOCR();
	break;

  case GSREG_FTCSRM:	
	FRT.FTCSRM = value & 0x8F;
	break;
/*
  case GSREG_TCR:
	FRT.TCR = value;
	FRT_WDT_Recalc_NET();
	break;
*/
  //
  //
  //
  case GSREG_CCR:
	SetCCR(value);
	break;
 }
}

//
//
//
//
//
//
//
void MDFN_COLD SH7095::Disassemble(const uint16 instr, const uint32 PC, char* buffer, uint16 (*DisPeek16)(uint32), uint32 (*DisPeek32)(uint32))
{
 static const char* CR_Names[3] = { "SR", "GBR", "VBR" };
 static const char* SR_Names[3] = { "MACH", "MACL", "PR" };
 const unsigned instr_nyb1 = (instr >> 4) & 0xF;
 const unsigned instr_nyb2 = (instr >> 8) & 0xF;

 switch(InstrDecodeTab[instr])
 {
 #define BEGIN_DIS_OP(x) OP_##x {
 #define END_DIS_OP } break;

 default:
	trio_sprintf(buffer, ".word 0x%04x", instr);
	break;

 //
 // MOV #imm,Rn
 //
 BEGIN_DIS_OP(MOV_IMM_REG)
	const unsigned n = instr_nyb2;
	const int32 imm = (int8)instr;

	trio_sprintf(buffer, "MOV     #%d,R%u", imm, n);
 END_DIS_OP


 //
 // MOV.W @(disp,PC),Rn
 //
 BEGIN_DIS_OP(MOV_W_PCREL_REG)
	const unsigned n = instr_nyb2;
	const unsigned d = (instr >> 0) & 0xff;
	const uint32 ea = PC + (d << 1);

	trio_sprintf(buffer, "MOV.W   @(0x%03x,PC),R%u ! 0x%04x", (d << 1), n, DisPeek16(ea));
 END_DIS_OP


 //
 // MOV.L @(disp,PC),Rn
 //
 BEGIN_DIS_OP(MOV_L_PCREL_REG)
	const unsigned n = instr_nyb2;
	const unsigned d = (instr >> 0) & 0xff;
	const uint32 ea = (PC &~ 0x3) + (d << 2);

	trio_sprintf(buffer, "MOV.L   @(0x%03x,PC),R%u ! 0x%08x", (d << 2), n, DisPeek32(ea));
 END_DIS_OP


 //
 // MOV Rm,Rn
 //
 BEGIN_DIS_OP(MOV_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV     R%u,R%u", m, n);
 END_DIS_OP


 //
 // MOV.B Rm,@Rn
 //
 BEGIN_DIS_OP(MOV_B_REG_REGINDIR)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.B   R%u,@R%u", m, n);
 END_DIS_OP


 //
 // MOV.W Rm,@Rn
 //
 BEGIN_DIS_OP(MOV_W_REG_REGINDIR)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.W   R%u,@R%u", m, n);
 END_DIS_OP


 //
 // MOV.L Rm,@Rn
 //
 BEGIN_DIS_OP(MOV_L_REG_REGINDIR)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.L   R%u,@R%u", m, n);
 END_DIS_OP


 //
 // MOV.B @Rm,Rn
 //
 BEGIN_DIS_OP(MOV_B_REGINDIR_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.B   @R%u,R%u", m, n);
 END_DIS_OP


 //
 // MOV.W @Rm,Rn
 //
 BEGIN_DIS_OP(MOV_W_REGINDIR_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.W   @R%u,R%u", m, n);
 END_DIS_OP


 //
 // MOV.L @Rm,Rn
 //
 BEGIN_DIS_OP(MOV_L_REGINDIR_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.L   @R%u,R%u", m, n);
 END_DIS_OP


 //
 // MOV.B Rm,@-Rn
 //
 BEGIN_DIS_OP(MOV_B_REG_REGINDIRPD)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.B   R%u,@-R%u", m, n);
 END_DIS_OP


 //
 // MOV.W Rm,@-Rn
 //
 BEGIN_DIS_OP(MOV_W_REG_REGINDIRPD)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.W   R%u,@-R%u", m, n);
 END_DIS_OP


 //
 // MOV.L Rm,@-Rn
 //
 BEGIN_DIS_OP(MOV_L_REG_REGINDIRPD)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.L   R%u,@-R%u", m, n);
 END_DIS_OP


 //
 // MOV.B @Rm+,Rn
 //
 BEGIN_DIS_OP(MOV_B_REGINDIRPI_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.B   @R%u+,R%u", m, n);
 END_DIS_OP


 //
 // MOV.W @Rm+,Rn
 //
 BEGIN_DIS_OP(MOV_W_REGINDIRPI_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.W   @R%u+,R%u", m, n);
 END_DIS_OP


 //
 // MOV.L @Rm+,Rn
 //
 BEGIN_DIS_OP(MOV_L_REGINDIRPI_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.L   @R%u+,R%u", m, n);
 END_DIS_OP


 //
 // MOV.B R0,@(disp,Rn)
 //
 BEGIN_DIS_OP(MOV_B_REG0_REGINDIRDISP)
	const unsigned n = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;

	trio_sprintf(buffer, "MOV.B   R0,@(%u,R%u)", (d << 0), n);
 END_DIS_OP


 //
 // MOV.W R0,@(disp,Rn)
 //
 BEGIN_DIS_OP(MOV_W_REG0_REGINDIRDISP)
	const unsigned n = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;

	trio_sprintf(buffer, "MOV.W   R0,@(%u,R%u)", (d << 1), n);
 END_DIS_OP


 //
 // MOV.L Rm,@(disp,Rn)
 //
 BEGIN_DIS_OP(MOV_L_REG_REGINDIRDISP)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;

	trio_sprintf(buffer, "MOV.L   R%u,@(%u,R%u)", m, (d << 2), n);
 END_DIS_OP


 //
 // MOV.B @(disp,Rm),R0
 //
 BEGIN_DIS_OP(MOV_B_REGINDIRDISP_REG0)
	const unsigned m = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;

	trio_sprintf(buffer, "MOV.B   @(%u,R%u),R0", (d << 0), m);
 END_DIS_OP


 //
 // MOV.W @(disp,Rm),R0
 //
 BEGIN_DIS_OP(MOV_W_REGINDIRDISP_REG0)
	const unsigned m = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;

	trio_sprintf(buffer, "MOV.W   @(%u,R%u),R0", (d << 1), m);
 END_DIS_OP


 //
 // MOV.L @(disp,Rm),Rn
 //
 BEGIN_DIS_OP(MOV_L_REGINDIRDISP_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;

	trio_sprintf(buffer, "MOV.L   @(%u,R%u),R%u", (d << 2), m, n);
 END_DIS_OP


 //
 // MOV.B Rm,@(R0,Rn)
 //
 BEGIN_DIS_OP(MOV_B_REG_IDXREGINDIR)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.B   R%u,@(R0,R%u)", m, n);
 END_DIS_OP


 //
 // MOV.W Rm,@(R0,Rn)
 //
 BEGIN_DIS_OP(MOV_W_REG_IDXREGINDIR)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.W   R%u,@(R0,R%u)", m, n);
 END_DIS_OP


 //
 // MOV.L Rm,@(R0,Rn)
 //
 BEGIN_DIS_OP(MOV_L_REG_IDXREGINDIR)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.L   R%u,@(R0,R%u)", m, n);
 END_DIS_OP


 //
 // MOV.B @(R0,Rm),Rn
 //
 BEGIN_DIS_OP(MOV_B_IDXREGINDIR_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.B   @(R0,R%u),R%u", m, n);
 END_DIS_OP


 //
 // MOV.W @(R0,Rm),Rn
 //
 BEGIN_DIS_OP(MOV_W_IDXREGINDIR_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.W   @(R0,R%u),R%u", m, n);
 END_DIS_OP


 //
 // MOV.L @(R0,Rm),Rn
 //
 BEGIN_DIS_OP(MOV_L_IDXREGINDIR_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MOV.L   @(R0,R%u),R%u", m, n);
 END_DIS_OP


 //
 // MOV.B R0,@(disp,GBR)
 //
 BEGIN_DIS_OP(MOV_B_REG0_GBRINDIRDISP)
	const unsigned d = (instr >> 0) & 0xff;

	trio_sprintf(buffer, "MOV.B   R0,@(%u,GBR)", (d << 0));
 END_DIS_OP


 //
 // MOV.W R0,@(disp,GBR)
 //
 BEGIN_DIS_OP(MOV_W_REG0_GBRINDIRDISP)
	const unsigned d = (instr >> 0) & 0xff;

	trio_sprintf(buffer, "MOV.W   R0,@(%u,GBR)", (d << 1));
 END_DIS_OP


 //
 // MOV.L R0,@(disp,GBR)
 //
 BEGIN_DIS_OP(MOV_L_REG0_GBRINDIRDISP)
	const unsigned d = (instr >> 0) & 0xff;

	trio_sprintf(buffer, "MOV.L   R0,@(%u,GBR)", (d << 2));
 END_DIS_OP


 //
 // MOV.B @(disp,GBR),R0
 //
 BEGIN_DIS_OP(MOV_B_GBRINDIRDISP_REG0)
	const unsigned d = (instr >> 0) & 0xff;

	trio_sprintf(buffer, "MOV.B   @(%u,GBR),R0", (d << 0));
 END_DIS_OP


 //
 // MOV.W @(disp,GBR),R0
 //
 BEGIN_DIS_OP(MOV_W_GBRINDIRDISP_REG0)
	const unsigned d = (instr >> 0) & 0xff;

	trio_sprintf(buffer, "MOV.W   @(%u,GBR),R0", (d << 1));
 END_DIS_OP


 //
 // MOV.L @(disp,GBR),R0
 //
 BEGIN_DIS_OP(MOV_L_GBRINDIRDISP_REG0)
	const unsigned d = (instr >> 0) & 0xff;

	trio_sprintf(buffer, "MOV.L   @(%u,GBR),R0", (d << 2));
 END_DIS_OP


 //
 // MOVA @(disp,PC),R0
 //
 BEGIN_DIS_OP(MOVA_PCREL_REG0)
	const unsigned d = (instr >> 0) & 0xff;

	trio_sprintf(buffer, "MOVA    @(%u,PC),R0", (d << 2));
 END_DIS_OP


 //
 // MOVT Rn
 //
 BEGIN_DIS_OP(MOVT_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "MOVT    R%u", n);
 END_DIS_OP


 //
 // SWAP.B Rm,Rn
 //
 BEGIN_DIS_OP(SWAP_B_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "SWAP.B  R%u,R%u", m, n);
 END_DIS_OP


 //
 // SWAP.W Rm,Rn
 //
 BEGIN_DIS_OP(SWAP_W_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "SWAP.W  R%u,R%u", m, n);
 END_DIS_OP


 //
 // XTRCT Rm,Rn
 //
 BEGIN_DIS_OP(XTRCT_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "XTRCT   R%u,R%u", m, n);
 END_DIS_OP


 //
 // ADD Rm,Rn
 //
 BEGIN_DIS_OP(ADD_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "ADD     R%u,R%u", m, n);
 END_DIS_OP


 //
 // ADD #imm,Rn
 //
 BEGIN_DIS_OP(ADD_IMM_REG)
	const unsigned n = instr_nyb2;
	const int32 imm = (int8)instr;

	trio_sprintf(buffer, "ADD     #%d,R%u", imm, n);
 END_DIS_OP


 //
 // ADDC Rm,Rn
 //
 BEGIN_DIS_OP(ADDC_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "ADDC    R%u,R%u", m, n);
 END_DIS_OP


 //
 // ADDV Rm,Rn
 //
 BEGIN_DIS_OP(ADDV_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "ADDV    R%u,R%u", m, n);
 END_DIS_OP


 //
 // CMP/EQ #imm,R0
 //
 BEGIN_DIS_OP(CMP_EQ_IMM_REG0)
	const int32 imm = (int8)instr;

	trio_sprintf(buffer, "CMP/EQ  #%d,R0", imm);
 END_DIS_OP


 //
 // CMP/EQ Rm,Rn
 //
 BEGIN_DIS_OP(CMP_EQ_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "CMP/EQ  R%u,R%u", m, n);
 END_DIS_OP


 //
 // CMP/HS Rm,Rn
 //
 BEGIN_DIS_OP(CMP_HS_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "CMP/HS  R%u,R%u", m, n);
 END_DIS_OP


 //
 // CMP/GE Rm,Rn
 //
 BEGIN_DIS_OP(CMP_GE_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "CMP/GE  R%u,R%u", m, n);
 END_DIS_OP


 //
 // CMP/HI Rm,Rn
 //
 BEGIN_DIS_OP(CMP_HI_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "CMP/HI  R%u,R%u", m, n);
 END_DIS_OP


 //
 // CMP/GT Rm,Rn
 //
 BEGIN_DIS_OP(CMP_GT_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "CMP/GT  R%u,R%u", m, n);
 END_DIS_OP


 //
 // CMP/PZ Rn
 //
 BEGIN_DIS_OP(CMP_PZ_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "CMP/PZ  R%u", n);
 END_DIS_OP


 //
 // CMP/PL Rn
 //
 BEGIN_DIS_OP(CMP_PL_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "CMP/PL  R%u", n);
 END_DIS_OP


 //
 // CMP/STR Rm,Rn
 //
 BEGIN_DIS_OP(CMP_STR_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "CMP/STR R%u,R%u", m, n);
 END_DIS_OP


 //
 // DIV1 Rm,Rn
 //
 BEGIN_DIS_OP(DIV1_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "DIV1    R%u,R%u", m, n);
 END_DIS_OP


 //
 // DIV0S Rm,Rn
 //
 BEGIN_DIS_OP(DIV0S_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "DIV0S   R%u,R%u", m, n);
 END_DIS_OP


 //
 // DIV0U 
 //
 BEGIN_DIS_OP(DIV0U)
	trio_sprintf(buffer, "DIV0U");
 END_DIS_OP


 //
 // DMULS.L Rm,Rn
 //
 BEGIN_DIS_OP(DMULS_L_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "DMULS.L R%u,R%u", m, n);
 END_DIS_OP


 //
 // DMULU.L Rm,Rn
 //
 BEGIN_DIS_OP(DMULU_L_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "DMULU.L R%u,R%u", m, n);
 END_DIS_OP


 //
 // DT Rn
 //
 BEGIN_DIS_OP(DT)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "DT      R%u", n);
 END_DIS_OP


 //
 // EXTS.B Rm,Rn
 //
 BEGIN_DIS_OP(EXTS_B_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "EXTS.B  R%u,R%u", m, n);
 END_DIS_OP


 //
 // EXTS.W Rm,Rn
 //
 BEGIN_DIS_OP(EXTS_W_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "EXTS.W  R%u,R%u", m, n);
 END_DIS_OP


 //
 // EXTU.B Rm,Rn
 //
 BEGIN_DIS_OP(EXTU_B_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "EXTU.B  R%u,R%u", m, n);
 END_DIS_OP


 //
 // EXTU.W Rm,Rn
 //
 BEGIN_DIS_OP(EXTU_W_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "EXTU.W  R%u,R%u", m, n);
 END_DIS_OP


 //
 // MAC.L @Rm+,@Rn+
 //
 BEGIN_DIS_OP(MAC_L)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MAC.L   @R%u+,@R%u+", m, n);
 END_DIS_OP


 //
 // MAC.W @Rm+,@Rn+
 //
 BEGIN_DIS_OP(MAC_W)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MAC.W   @R%u+,@R%u+", m, n);
 END_DIS_OP


 //
 // MUL.L Rm,Rn
 //
 BEGIN_DIS_OP(MUL_L_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MUL.L   R%u,R%u", m, n);
 END_DIS_OP


 //
 // MULS.W Rm,Rn
 //
 BEGIN_DIS_OP(MULS_W_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MULS.W  R%u,R%u", m, n);
 END_DIS_OP


 //
 // MULU.W Rm,Rn
 //
 BEGIN_DIS_OP(MULU_W_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "MULU.W  R%u,R%u", m, n);
 END_DIS_OP


 //
 // NEG Rm,Rn
 //
 BEGIN_DIS_OP(NEG_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "NEG     R%u,R%u", m, n);
 END_DIS_OP


 //
 // NEGC Rm,Rn
 //
 BEGIN_DIS_OP(NEGC_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "NEGC    R%u,R%u", m, n);
 END_DIS_OP


 //
 // SUB Rm,Rn
 //
 BEGIN_DIS_OP(SUB_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "SUB     R%u,R%u", m, n);
 END_DIS_OP


 //
 // SUBC Rm,Rn
 //
 BEGIN_DIS_OP(SUBC_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "SUBC    R%u,R%u", m, n);
 END_DIS_OP


 //
 // SUBV Rm,Rn
 //
 BEGIN_DIS_OP(SUBV_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "SUBV    R%u,R%u", m, n);
 END_DIS_OP


 //
 // AND Rm,Rn
 //
 BEGIN_DIS_OP(AND_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "AND     R%u,R%u", m, n);
 END_DIS_OP


 //
 // AND #imm,R0
 //
 BEGIN_DIS_OP(AND_IMM_REG0)
	const unsigned imm = (uint8)instr;

	trio_sprintf(buffer, "AND     #%u,R0", imm);
 END_DIS_OP


 //
 // AND.B #imm,@(R0,GBR)
 //
 BEGIN_DIS_OP(AND_B_IMM_IDXGBRINDIR)
	const unsigned imm = (uint8)instr;

	trio_sprintf(buffer, "AND.B   #%u,@(R0,GBR)", imm);
 END_DIS_OP


 //
 // NOT Rm,Rn
 //
 BEGIN_DIS_OP(NOT_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "NOT     R%u,R%u", m, n);
 END_DIS_OP


 //
 // OR Rm,Rn
 //
 BEGIN_DIS_OP(OR_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "OR      R%u,R%u", m, n);
 END_DIS_OP


 //
 // OR #imm,R0
 //
 BEGIN_DIS_OP(OR_IMM_REG0)
	const unsigned imm = (uint8)instr;

	trio_sprintf(buffer, "OR      #%u,R0", imm);
 END_DIS_OP


 //
 // OR.B #imm,@(R0,GBR)
 //
 BEGIN_DIS_OP(OR_B_IMM_IDXGBRINDIR)
	const unsigned imm = (uint8)instr;

	trio_sprintf(buffer, "OR.B    #%u,@(R0,GBR)", imm);
 END_DIS_OP


 //
 // TAS.B @Rn
 //
 BEGIN_DIS_OP(TAS_B_REGINDIR)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "TAS.B   @R%u", n);
 END_DIS_OP


 //
 // TST Rm,Rn
 //
 BEGIN_DIS_OP(TST_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "TST     R%u,R%u", m, n);
 END_DIS_OP


 //
 // TST #imm,R0
 //
 BEGIN_DIS_OP(TST_IMM_REG0)
	const unsigned imm = (uint8)instr;

	trio_sprintf(buffer, "TST     #%u,R0", imm);
 END_DIS_OP


 //
 // TST.B #imm,@(R0,GBR)
 //
 BEGIN_DIS_OP(TST_B_IMM_IDXGBRINDIR)
	const unsigned imm = (uint8)instr;

	trio_sprintf(buffer, "TST.B   #%u,@(R0,GBR)", imm);
 END_DIS_OP


 //
 // XOR Rm,Rn
 //
 BEGIN_DIS_OP(XOR_REG_REG)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	trio_sprintf(buffer, "XOR     R%u,R%u", m, n);
 END_DIS_OP


 //
 // XOR #imm,R0
 //
 BEGIN_DIS_OP(XOR_IMM_REG0)
	const unsigned imm = (uint8)instr;

	trio_sprintf(buffer, "XOR     #%u,R0", imm);
 END_DIS_OP


 //
 // XOR.B #imm,@(R0,GBR)
 //
 BEGIN_DIS_OP(XOR_B_IMM_IDXGBRINDIR)
	const unsigned imm = (uint8)instr;

	trio_sprintf(buffer, "XOR.B   #%u,@(R0,GBR)", imm);
 END_DIS_OP


 //
 // ROTL Rn
 //
 BEGIN_DIS_OP(ROTL_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "ROTL    R%u", n);
 END_DIS_OP


 //
 // ROTR Rn
 //
 BEGIN_DIS_OP(ROTR_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "ROTR    R%u", n);
 END_DIS_OP


 //
 // ROTCL Rn
 //
 BEGIN_DIS_OP(ROTCL_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "ROTCL   R%u", n);
 END_DIS_OP


 //
 // ROTCR Rn
 //
 BEGIN_DIS_OP(ROTCR_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "ROTCR   R%u", n);
 END_DIS_OP


 //
 // SHAR Rn
 //
 BEGIN_DIS_OP(SHAR_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "SHAR    R%u", n);
 END_DIS_OP


 //
 // SHLL Rn
 //
 BEGIN_DIS_OP(SHLL_REG)
	const unsigned n = instr_nyb2;

	if(instr & 0x20)
	 trio_sprintf(buffer, "SHAL    R%u", n);
	else
	 trio_sprintf(buffer, "SHLL    R%u", n);
 END_DIS_OP


 //
 // SHLR Rn
 //
 BEGIN_DIS_OP(SHLR_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "SHLR    R%u", n);
 END_DIS_OP


 //
 // SHLL2 Rn
 //
 BEGIN_DIS_OP(SHLL2_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "SHLL2   R%u", n);
 END_DIS_OP


 //
 // SHLR2 Rn
 //
 BEGIN_DIS_OP(SHLR2_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "SHLR2   R%u", n);
 END_DIS_OP


 //
 // SHLL8 Rn
 //
 BEGIN_DIS_OP(SHLL8_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "SHLL8   R%u", n);
 END_DIS_OP


 //
 // SHLR8 Rn
 //
 BEGIN_DIS_OP(SHLR8_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "SHLR8   R%u", n);
 END_DIS_OP


 //
 // SHLL16 Rn
 //
 BEGIN_DIS_OP(SHLL16_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "SHLL16  R%u", n);
 END_DIS_OP


 //
 // SHLR16 Rn
 //
 BEGIN_DIS_OP(SHLR16_REG)
	const unsigned n = instr_nyb2;

	trio_sprintf(buffer, "SHLR16  R%u", n);
 END_DIS_OP


 //
 // BF 
 //
 BEGIN_DIS_OP(BF)
	trio_sprintf(buffer, "BF      0x%08x", (uint32)(PC + ((uint32)(int8)instr << 1)));
 END_DIS_OP


 //
 // BF/S 
 //
 BEGIN_DIS_OP(BF_S)
	trio_sprintf(buffer, "BF/S    0x%08x", (uint32)(PC + ((uint32)(int8)instr << 1)));
 END_DIS_OP


 //
 // BT 
 //
 BEGIN_DIS_OP(BT)
	trio_sprintf(buffer, "BT      0x%08x", (uint32)(PC + ((uint32)(int8)instr << 1)));
 END_DIS_OP


 //
 // BT/S 
 //
 BEGIN_DIS_OP(BT_S)
	trio_sprintf(buffer, "BT/S    0x%08x", (uint32)(PC + ((uint32)(int8)instr << 1)));
 END_DIS_OP


 //
 // BRA 
 //
 BEGIN_DIS_OP(BRA)
	trio_sprintf(buffer, "BRA     0x%08x", (uint32)(PC + ((uint32)sign_x_to_s32(12, instr) << 1)));
 END_DIS_OP


 //
 // BRAF Rm
 //
 BEGIN_DIS_OP(BRAF_REG)
	const unsigned m = instr_nyb2;

	trio_sprintf(buffer, "BRAF    R%u", m);
 END_DIS_OP


 //
 // BSR 
 //
 BEGIN_DIS_OP(BSR)
	trio_sprintf(buffer, "BSR     0x%08x", (uint32)(PC + ((uint32)sign_x_to_s32(12, instr) << 1)));
 END_DIS_OP


 //
 // BSRF Rm
 //
 BEGIN_DIS_OP(BSRF_REG)
	const unsigned m = instr_nyb2;

	trio_sprintf(buffer, "BSRF    R%u", m);
 END_DIS_OP


 //
 // JMP @Rm
 //
 BEGIN_DIS_OP(JMP_REGINDIR)
	const unsigned m = instr_nyb2;

	trio_sprintf(buffer, "JMP     @R%u", m);
 END_DIS_OP


 //
 // JSR @Rm
 //
 BEGIN_DIS_OP(JSR_REGINDIR)
	const unsigned m = instr_nyb2;

	trio_sprintf(buffer, "JSR     @R%u", m);
 END_DIS_OP


 //
 // RTS 
 //
 BEGIN_DIS_OP(RTS)
	trio_sprintf(buffer, "RTS");
 END_DIS_OP


 //
 // CLRT 
 //
 BEGIN_DIS_OP(CLRT)
	trio_sprintf(buffer, "CLRT");
 END_DIS_OP


 //
 // CLRMAC 
 //
 BEGIN_DIS_OP(CLRMAC)
	trio_sprintf(buffer, "CLRMAC");
 END_DIS_OP


 //
 // LDC 
 //
 BEGIN_DIS_OP(LDC)
	const unsigned m = instr_nyb2;
	const unsigned cri = (instr >> 4) & 0x3;

	trio_sprintf(buffer, "LDC     R%u, %s", m, CR_Names[cri]);
 END_DIS_OP

 //
 // LDC.L 
 //
 BEGIN_DIS_OP(LDC_L)
	const unsigned m = instr_nyb2;
	const unsigned cri = (instr >> 4) & 0x3;

	trio_sprintf(buffer, "LDC.L   @R%u+, %s", m, CR_Names[cri]);
 END_DIS_OP


 //
 // LDS 
 //
 BEGIN_DIS_OP(LDS)
	const unsigned m = instr_nyb2;
	const unsigned sri = (instr >> 4) & 0x3;

	trio_sprintf(buffer, "LDS     R%u, %s", m, SR_Names[sri]);
 END_DIS_OP


 //
 // LDS.L 
 //
 BEGIN_DIS_OP(LDS_L)
	const unsigned m = instr_nyb2;
	const unsigned sri = (instr >> 4) & 0x3;

	trio_sprintf(buffer, "LDS.L   @R%u+, %s", m, SR_Names[sri]);
 END_DIS_OP


 //
 // NOP 
 //
 BEGIN_DIS_OP(NOP)
	trio_sprintf(buffer, "NOP");
 END_DIS_OP


 //
 // RTE 
 //
 BEGIN_DIS_OP(RTE)
	trio_sprintf(buffer, "RTE");
 END_DIS_OP


 //
 // SETT 
 //
 BEGIN_DIS_OP(SETT)
	trio_sprintf(buffer, "SETT");
 END_DIS_OP


 //
 // SLEEP 
 //
 BEGIN_DIS_OP(SLEEP)
	trio_sprintf(buffer, "SLEEP");
 END_DIS_OP

 //
 // STC 
 //
 BEGIN_DIS_OP(STC)
	const unsigned n = instr_nyb2;
	const unsigned cri = (instr >> 4) & 0x3;

	trio_sprintf(buffer, "STS     %s, R%u", CR_Names[cri], n);
 END_DIS_OP


 //
 // STC.L 
 //
 BEGIN_DIS_OP(STC_L)
	const unsigned n = instr_nyb2;
	const unsigned cri = (instr >> 4) & 0x3;

	trio_sprintf(buffer, "STC.L   %s, @-R%u", CR_Names[cri], n);
 END_DIS_OP


 //
 // STS 
 //
 BEGIN_DIS_OP(STS)
	const unsigned n = instr_nyb2;
	const unsigned sri = (instr >> 4) & 0x3;

	trio_sprintf(buffer, "STS     %s, R%u", SR_Names[sri], n);
 END_DIS_OP


 //
 // STS.L 
 //
 BEGIN_DIS_OP(STS_L)
	const unsigned n = instr_nyb2;
	const unsigned sri = (instr >> 4) & 0x3;

	trio_sprintf(buffer, "STS.L   %s, @-R%u", SR_Names[sri], n);
 END_DIS_OP


 //
 // TRAPA #imm
 //
 BEGIN_DIS_OP(TRAPA)
	const unsigned imm = (uint8)instr;

	trio_sprintf(buffer, "TRAPA   #%u", imm);
 END_DIS_OP

 #undef BEGIN_DIS_OP
 #undef END_DIS_OP
 }
}

//
//
//
//
INLINE void SH7095::CheckRWBreakpoints(void (*MRead)(unsigned len, uint32 addr), void (*MWrite)(unsigned len, uint32 addr)) const
{
 uint32 lpid = Pipe_ID;
 //
 //
 //
 //SPEPRecover:;
 const uint32 instr = (uint16)lpid;
 const unsigned instr_nyb1 = (instr >> 4) & 0xF;
 const unsigned instr_nyb2 = (instr >> 8) & 0xF;

 switch(lpid >> 24)
 {
 #include "sh7095_opdefs.inc"
 #define BEGIN_BP_OP(x) OP_##x { 
 #define END_BP_OP } break;

 //
 // MOV.W @(disp,PC),Rn
 //
 BEGIN_BP_OP(MOV_W_PCREL_REG)
	const unsigned d = (instr >> 0) & 0xff;
	const uint32 ea = PC + (d << 1);

	MRead(2, ea);
 END_BP_OP


 //
 // MOV.L @(disp,PC),Rn
 //
 BEGIN_BP_OP(MOV_L_PCREL_REG)
	const unsigned d = (instr >> 0) & 0xff;
	const uint32 ea = (PC &~ 0x3) + (d << 2);

	MRead(4, ea);
 END_BP_OP


 //
 // MOV.B Rm,@Rn
 //
 BEGIN_BP_OP(MOV_B_REG_REGINDIR)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[n];

	MWrite(1, ea);
 END_BP_OP


 //
 // MOV.W Rm,@Rn
 //
 BEGIN_BP_OP(MOV_W_REG_REGINDIR)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[n];

	MWrite(2, ea);
 END_BP_OP


 //
 // MOV.L Rm,@Rn
 //
 BEGIN_BP_OP(MOV_L_REG_REGINDIR)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[n];

	MWrite(4, ea);
 END_BP_OP


 //
 // MOV.B @Rm,Rn
 //
 BEGIN_BP_OP(MOV_B_REGINDIR_REG)
	const unsigned m = instr_nyb1;
	const uint32 ea = R[m];

	MRead(1, ea);
 END_BP_OP


 //
 // MOV.W @Rm,Rn
 //
 BEGIN_BP_OP(MOV_W_REGINDIR_REG)
	const unsigned m = instr_nyb1;
	const uint32 ea = R[m];

	MRead(2, ea);
 END_BP_OP


 //
 // MOV.L @Rm,Rn
 //
 BEGIN_BP_OP(MOV_L_REGINDIR_REG)
	const unsigned m = instr_nyb1;
	const uint32 ea = R[m];

	MRead(4, ea);
 END_BP_OP


 //
 // MOV.B Rm,@-Rn
 //
 BEGIN_BP_OP(MOV_B_REG_REGINDIRPD)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[n] - 1;

	MWrite(1, ea);
 END_BP_OP


 //
 // MOV.W Rm,@-Rn
 //
 BEGIN_BP_OP(MOV_W_REG_REGINDIRPD)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[n] - 2;

	MWrite(2, ea);
 END_BP_OP


 //
 // MOV.L Rm,@-Rn
 //
 BEGIN_BP_OP(MOV_L_REG_REGINDIRPD)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[n] - 4;

	MWrite(4, ea);
 END_BP_OP


 //
 // MOV.B @Rm+,Rn
 //
 BEGIN_BP_OP(MOV_B_REGINDIRPI_REG)
	const unsigned m = instr_nyb1;
	const uint32 ea = R[m];

	MRead(1, ea);
 END_BP_OP


 //
 // MOV.W @Rm+,Rn
 //
 BEGIN_BP_OP(MOV_W_REGINDIRPI_REG)
	const unsigned m = instr_nyb1;
	const uint32 ea = R[m];

	MRead(2, ea);
 END_BP_OP


 //
 // MOV.L @Rm+,Rn
 //
 BEGIN_BP_OP(MOV_L_REGINDIRPI_REG)
	const unsigned m = instr_nyb1;
	const uint32 ea = R[m];

	MRead(4, ea);
 END_BP_OP


 //
 // MOV.B R0,@(disp,Rn)
 //
 BEGIN_BP_OP(MOV_B_REG0_REGINDIRDISP)
	const unsigned n = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;
	const uint32 ea = R[n] + (d << 0);

	MWrite(1, ea);
 END_BP_OP


 //
 // MOV.W R0,@(disp,Rn)
 //
 BEGIN_BP_OP(MOV_W_REG0_REGINDIRDISP)
	const unsigned n = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;
	const uint32 ea = R[n] + (d << 1);

	MWrite(2, ea);
 END_BP_OP


 //
 // MOV.L Rm,@(disp,Rn)
 //
 BEGIN_BP_OP(MOV_L_REG_REGINDIRDISP)
	const unsigned n = instr_nyb2;
	const unsigned d = (instr >> 0) & 0xf;
	const uint32 ea = R[n] + (d << 2);

	MWrite(4, ea);
 END_BP_OP


 //
 // MOV.B @(disp,Rm),R0
 //
 BEGIN_BP_OP(MOV_B_REGINDIRDISP_REG0)
	const unsigned m = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;
	const uint32 ea = R[m] + (d << 0);

	MRead(1, ea);
 END_BP_OP


 //
 // MOV.W @(disp,Rm),R0
 //
 BEGIN_BP_OP(MOV_W_REGINDIRDISP_REG0)
	const unsigned m = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;
	const uint32 ea = R[m] + (d << 1);

	MRead(2, ea);
 END_BP_OP


 //
 // MOV.L @(disp,Rm),Rn
 //
 BEGIN_BP_OP(MOV_L_REGINDIRDISP_REG)
	const unsigned m = instr_nyb1;
	const unsigned d = (instr >> 0) & 0xf;
	const uint32 ea = R[m] + (d << 2);

	MRead(4, ea);
 END_BP_OP


 //
 // MOV.B Rm,@(R0,Rn)
 //
 BEGIN_BP_OP(MOV_B_REG_IDXREGINDIR)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[0] + R[n];

	MWrite(1, ea);
 END_BP_OP


 //
 // MOV.W Rm,@(R0,Rn)
 //
 BEGIN_BP_OP(MOV_W_REG_IDXREGINDIR)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[0] + R[n];

	MWrite(2, ea);
 END_BP_OP


 //
 // MOV.L Rm,@(R0,Rn)
 //
 BEGIN_BP_OP(MOV_L_REG_IDXREGINDIR)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[0] + R[n];

	MWrite(4, ea);
 END_BP_OP


 //
 // MOV.B @(R0,Rm),Rn
 //
 BEGIN_BP_OP(MOV_B_IDXREGINDIR_REG)
	const unsigned m = instr_nyb1;
	const uint32 ea = R[0] + R[m];

	MRead(1, ea);
 END_BP_OP


 //
 // MOV.W @(R0,Rm),Rn
 //
 BEGIN_BP_OP(MOV_W_IDXREGINDIR_REG)
	const unsigned m = instr_nyb1;
	const uint32 ea = R[0] + R[m];

	MRead(2, ea);
 END_BP_OP


 //
 // MOV.L @(R0,Rm),Rn
 //
 BEGIN_BP_OP(MOV_L_IDXREGINDIR_REG)
	const unsigned m = instr_nyb1;
	const uint32 ea = R[0] + R[m];

	MRead(4, ea);
 END_BP_OP


 //
 // MOV.B R0,@(disp,GBR)
 //
 BEGIN_BP_OP(MOV_B_REG0_GBRINDIRDISP)
	const unsigned d = (instr >> 0) & 0xff;
	const uint32 ea = GBR + (d << 0);

	MWrite(1, ea);
 END_BP_OP


 //
 // MOV.W R0,@(disp,GBR)
 //
 BEGIN_BP_OP(MOV_W_REG0_GBRINDIRDISP)
	const unsigned d = (instr >> 0) & 0xff;
	const uint32 ea = GBR + (d << 1);

	MWrite(2, ea);
 END_BP_OP


 //
 // MOV.L R0,@(disp,GBR)
 //
 BEGIN_BP_OP(MOV_L_REG0_GBRINDIRDISP)
	const unsigned d = (instr >> 0) & 0xff;
	const uint32 ea = GBR + (d << 2);

	MWrite(4, ea);
 END_BP_OP


 //
 // MOV.B @(disp,GBR),R0
 //
 BEGIN_BP_OP(MOV_B_GBRINDIRDISP_REG0)
	const unsigned d = (instr >> 0) & 0xff;
	const uint32 ea = GBR + (d << 0);

	MRead(1, ea);
 END_BP_OP


 //
 // MOV.W @(disp,GBR),R0
 //
 BEGIN_BP_OP(MOV_W_GBRINDIRDISP_REG0)
	const unsigned d = (instr >> 0) & 0xff;
	const uint32 ea = GBR + (d << 1);

	MRead(2, ea);
 END_BP_OP


 //
 // MOV.L @(disp,GBR),R0
 //
 BEGIN_BP_OP(MOV_L_GBRINDIRDISP_REG0)
	const unsigned d = (instr >> 0) & 0xff;
	const uint32 ea = GBR + (d << 2);

	MRead(4, ea);
 END_BP_OP


 //
 // MAC.L @Rm+,@Rn+
 //
 BEGIN_BP_OP(MAC_L)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	MRead(4, R[m]);
        MRead(4, R[n] + ((m == n) << 2));
 END_BP_OP


 //
 // MAC.W @Rm+,@Rn+
 //
 BEGIN_BP_OP(MAC_W)
	const unsigned n = instr_nyb2;
	const unsigned m = instr_nyb1;

	MRead(2, R[m]);
        MRead(2, R[n] + ((m == n) << 1));
 END_BP_OP


 //
 // AND.B #imm,@(R0,GBR)
 //
 BEGIN_BP_OP(AND_B_IMM_IDXGBRINDIR)
	const uint32 ea = R[0] + GBR;

	MRead(1, ea);
	MWrite(1, ea);
 END_BP_OP

 //
 // OR.B #imm,@(R0,GBR)
 //
 BEGIN_BP_OP(OR_B_IMM_IDXGBRINDIR)
	const uint32 ea = R[0] + GBR;

	MRead(1, ea);
	MWrite(1, ea);
 END_BP_OP


 //
 // TAS.B @Rn
 //
 BEGIN_BP_OP(TAS_B_REGINDIR)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[n];

	MRead(1, ea);
	MWrite(1, ea);
 END_BP_OP


 //
 // TST.B #imm,@(R0,GBR)
 //
 BEGIN_BP_OP(TST_B_IMM_IDXGBRINDIR)
	const uint32 ea = R[0] + GBR;

	MRead(1, ea);
 END_BP_OP


 //
 // XOR.B #imm,@(R0,GBR)
 //
 BEGIN_BP_OP(XOR_B_IMM_IDXGBRINDIR)
	const uint32 ea = R[0] + GBR;

	MRead(1, ea);
	MWrite(1, ea);
 END_BP_OP


 //
 // LDC.L 
 //
 BEGIN_BP_OP(LDC_L)
	const unsigned m = instr_nyb2;
	const uint32 ea = R[m];

	MRead(4, ea);
 END_BP_OP


 //
 // LDS.L 
 //
 BEGIN_BP_OP(LDS_L)
	const unsigned m = instr_nyb2;
	const uint32 ea = R[m];

	MRead(4, ea);
 END_BP_OP


 //
 // RTE 
 //
 BEGIN_BP_OP(RTE)
	MRead(4, R[15]);
	MRead(4, 4 + R[15]);
 END_BP_OP

 //
 // STC.L 
 //
 BEGIN_BP_OP(STC_L)
	const unsigned n = instr_nyb2;
	const uint32 ea = R[n] - 4;

	MWrite(4, ea);
 END_BP_OP

 //
 // STS.L 
 //
 BEGIN_BP_OP(STS_L)	// Pipeline same as ordinary store instruction
	const unsigned n = instr_nyb2;
	const uint32 ea = R[n] - 4;

	MWrite(4, ea);
 END_BP_OP


#if 0
 //
 // TRAPA #imm
 //
 // Saved PC is the address of the instruction after the TRAPA instruction
 //
 BEGIN_BP_OP_DLYIDIF(TRAPA)
	const unsigned imm = (uint8)instr;

	BP_EXCEPT(EXCEPTION_TRAP, imm);
 END_BP_OP


 //
 // Illegal Instruction
 //
 BEGIN_BP_OP_DLYIDIF(ILLEGAL)
	BP_EXCEPT(EXCEPTION_ILLINSTR, VECNUM_ILLINSTR);
 END_BP_OP

 //
 // Illegal Slot Instruction
 //
 BEGIN_BP_OP_DLYIDIF(SLOT_ILLEGAL)
	BP_EXCEPT(EXCEPTION_ILLSLOT, VECNUM_ILLSLOT);
 END_BP_OP

 //
 // Pending exception(address error/interrupt)
 //
 BEGIN_BP_OP_DLYIDIF(PSEUDO_EPENDING)
	#define TPP(x) (Pipe_ID & (1U << ((x) + EPENDING_PEXBITS_SHIFT)))

	if(MDFN_UNLIKELY(TPP(PEX_PSEUDO_EXTHALT)))
	 return;
	else if(MDFN_UNLIKELY(TPP(PEX_POWERON) || TPP(PEX_RESET)))
	{
         if(TPP(PEX_POWERON))
	  BP_EXCEPT(EXCEPTION_POWERON, VECNUM_POWERON);
	 else
	  BP_EXCEPT(EXCEPTION_RESET, VECNUM_RESET);
	}
	else if(MDFN_UNLIKELY(TPP(PEX_PSEUDO_DMABURST)))
	 return;
	else if(MDFN_UNLIKELY(TPP(PEX_CPUADDR)))
	 BP_EXCEPT(EXCEPTION_CPUADDR, VECNUM_CPUADDR);
	else if(MDFN_UNLIKELY(TPP(PEX_DMAADDR)))
	 BP_EXCEPT(EXCEPTION_DMAADDR, VECNUM_DMAADDR);
	else if(TPP(PEX_NMI))
	 BP_EXCEPT(EXCEPTION_NMI, VECNUM_NMI);
	else	// Int
	{
	 uint8 ipr = GetPendingInt(NULL);

	 if(MDFN_LIKELY(ipr > ((SR >> 4) & 0xF)))
	 {
	  uint8 vecnum;

	  // Note: GetPendingInt() may call ExIVecFetch(), which may call SetIRL with a new value, so be
	  // careful to use the "old" value here.
	  GetPendingInt(&vecnum);
	  BP_EXCEPT(EXCEPTION_INT, vecnum);
	 }
	 else
	 {
	  lpid = (uint16)lpid;
	  lpid |= InstrDecodeTab[lpid] << 24;
	  goto SPEPRecover;
	 }
	}
END_BP_OP
#endif

 #undef BEGIN_BP_OP
 #undef END_BP_OP
 }
}
