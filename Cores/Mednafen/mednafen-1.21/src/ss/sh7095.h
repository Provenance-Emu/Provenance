/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* sh7095.h:
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

#ifndef __MDFN_SH7095_H
#define __MDFN_SH7095_H

class SH7095 final
{
 public:

 SH7095(const char* const name_arg, const unsigned dma_event_id_arg, uint8 (*exivecfn_arg)(void)) MDFN_COLD;
 ~SH7095() MDFN_COLD;

 void Init(const bool CacheBypassHack) MDFN_COLD;

 void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname) MDFN_COLD;

 void ForceInternalEventUpdates(void);
 void AdjustTS(int32 delta, bool force_set = false);

 void TruePowerOn(void) MDFN_COLD;
 void Reset(bool power_on_reset, bool from_internal_wdt = false) MDFN_COLD;
 void SetNMI(bool level);
 void SetIRL(unsigned level);
 void SetMD5(bool level);

 void SetFTI(bool state);
 void SetFTCI(bool state);

 INLINE void SetExtHalt(bool state)
 {
  ExtHalt = state;

  if(ExtHalt)
   SetPEX(PEX_PSEUDO_EXTHALT);	// Only SetPEX() here, ClearPEX() is called in the pseudo exception handling code as necessary.
 }

 template<unsigned which, bool EmulateICache, bool DebugMode>
 void Step(void);


 //private:
 uint32 R[16];
 uint32 PC;

 // Control registers
 union
 {
  struct
  {
   uint32 SR;
   uint32 GBR;
   uint32 VBR;
  };
  uint32 CtrlRegs[3];
 };

 sscpu_timestamp_t timestamp;
 sscpu_timestamp_t MA_until;
 sscpu_timestamp_t MM_until;
 sscpu_timestamp_t write_finish_timestamp;
#if 0
 sscpu_timestamp_t WB_until[16];
#endif

 INLINE void SetT(bool new_value) { SR &= ~1; SR |= new_value; }
 INLINE bool GetT(void) { return SR & 1; }

 INLINE bool GetS(void) { return (bool)(SR & 0x002); }
 INLINE bool GetQ(void) { return (bool)(SR & 0x100); }
 INLINE bool GetM(void) { return (bool)(SR & 0x200); }
 INLINE void SetQ(bool new_q) { SR = (SR &~ 0x100) | (new_q << 8); }
 INLINE void SetM(bool new_m) { SR = (SR &~ 0x200) | (new_m << 9); }

 // System registers
 union
 {
  struct
  {
   uint32 MACH;
   uint32 MACL;
   uint32 PR;
  };
  uint32 SysRegs[3];
 };

 INLINE uint64 GetMAC64(void) { return MACL | ((uint64)MACH << 32); }
 INLINE void SetMAC64(uint64 nv) { MACL = nv; MACH = nv >> 32; }

 enum // must be in range of 0 ... 7
 {
  PEX_POWERON = 0,
  PEX_RESET   = 1,
  PEX_CPUADDR = 2,
  PEX_DMAADDR = 3,
  PEX_INT     = 4,
  PEX_NMI     = 5,
  PEX_PSEUDO_DMABURST = 6,
  PEX_PSEUDO_EXTHALT = 7
 };
 enum { EPENDING_PEXBITS_SHIFT = 16 };
 enum { EPENDING_OP_OR = 0xFF000000 };

 uint32 EPending;

 INLINE void SetPEX(const unsigned which)
 {
  EPending |= (1U << (which + EPENDING_PEXBITS_SHIFT));
  EPending |= EPENDING_OP_OR;
 }

 INLINE void ClearPEX(const unsigned which)
 {
  EPending &= ~(1U << (which + EPENDING_PEXBITS_SHIFT));

  if(!(EPending & (0xFF << EPENDING_PEXBITS_SHIFT)))
   EPending = 0;
 }

 uint32 Pipe_ID;
 uint32 Pipe_IF;

 enum
 {
  EXCEPTION_POWERON = 0,// Power-on
  EXCEPTION_RESET,	// "Manual" reset
  EXCEPTION_ILLINSTR,	// General illegal instruction
  EXCEPTION_ILLSLOT,	// Slot illegal instruction
  EXCEPTION_CPUADDR,	// CPU address error
  EXCEPTION_DMAADDR,	// DMA Address error
  EXCEPTION_NMI,	// NMI
  EXCEPTION_BREAK,	// User break
  EXCEPTION_TRAP,	// Trap instruction
  EXCEPTION_INT,	// Interrupt
 };

 enum
 {
  VECNUM_POWERON   =  0,	// Power-on
  VECNUM_RESET     =  2,	// "Manual" reset
  VECNUM_ILLINSTR  =  4,	// General illegal instruction
  VECNUM_ILLSLOT   =  6,	// Slot illegal instruction
  VECNUM_CPUADDR   =  9,	// CPU address error
  VECNUM_DMAADDR   = 10,	// DMA Address error
  VECNUM_NMI	   = 11,	// NMI
  VECNUM_BREAK     = 12,	// User break

  VECNUM_TRAP_BASE = 32,	// Trap instruction
  VECNUM_INT_BASE  = 64,	// Interrupt
 };

 enum
 {
  EPENDING_IVECNUM_SHIFT = 8,	// 8 bits
  EPENDING_E_SHIFT = 16,	// 8 bits
  EPENDING_IPRIOLEV_SHIFT = 28	// 4 bits
 };

 template<bool DebugMode>
 uint32 Exception(const unsigned exnum, const unsigned vecnum);

 //
 //
 //
 uint32 IBuffer;

 uint32 (MDFN_FASTCALL *MRFPI[8])(uint32 A);

 uint8 (MDFN_FASTCALL *MRFP8[8])(uint32 A);
 uint16 (MDFN_FASTCALL *MRFP16[8])(uint32 A);
 uint32 (MDFN_FASTCALL *MRFP32[8])(uint32 A);

 void (MDFN_FASTCALL *MWFP8[8])(uint32 A, uint8);
 void (MDFN_FASTCALL *MWFP16[8])(uint32 A, uint16);
 void (MDFN_FASTCALL *MWFP32[8])(uint32 A, uint32);

 //
 //
 // Cache:
 //
 //
 struct
 {
  // Rather than have separate validity bits, we're putting an INvalidity bit(invalid when =1)
  // in the upper bit of the Tag variables.
  uint32 Tag[4];
  uint8 LRU;
  alignas(4) uint8 Data[4][16];
 } Cache[64];

 uint8 CCR;

 void SetCCR(uint8 V);
 enum { CCR_CE = 0x01 };	// Cache Enable
 enum { CCR_ID = 0x02 };	// Instruction Replacement Disable
 enum { CCR_OD = 0x04 };	// Data Replacement Disable
 enum { CCR_TW = 0x08 };	// Two-Way Mode
 enum { CCR_CP = 0x10 };	// Cache Purge
 enum { CCR_W0 = 0x40 };	//
 enum { CCR_W1 = 0x80 };	//
 void AssocPurge(const uint32 A);

 template<typename T>
 void Write_UpdateCache(uint32 A, T V);
 //
 // End cache stuff
 //

 //
 //
 // Interrupt controller registers and related state
 //
 // 
 void INTC_Reset(void) MDFN_COLD;

 bool NMILevel;
 uint8 IRL;

 uint16 IPRA;
 uint16 IPRB;
 uint16 VCRWDT;
 uint16 VCRA;
 uint16 VCRB;
 uint16 VCRC;
 uint16 VCRD;
 uint16 ICR;

 //
 //
 //
 struct
 {
  uint16 BCR1;
  uint8 BCR2;
  uint16 WCR;
  uint16 MCR;

  uint8 RTCSR;
  uint8 RTCSRM;
  uint8 RTCNT;
  uint8 RTCOR;
 } BSC;

 //
 //
 //
 uint8 SBYCR;
 bool Standby;

 //
 //
 // Free-running timer registers and related state
 //
 //
 struct
 {
  sscpu_timestamp_t lastts;	// Internal timestamp related.

  bool FTI;
  bool FTCI;

  uint16 FRC;
  uint16 OCR[2];
  uint16 FICR;
  uint8 TIER;
  uint8 FTCSR;
  uint8 FTCSRM;	// Bits set to 1 like FTCSR, but unconditionally reset all bits to 0 on FTCSR read.
  uint8 TCR;
  uint8 TOCR;
  uint8 RW_Temp;
 } FRT;

 void FRT_Reset(void) MDFN_COLD;

 void FRT_CheckOCR(void);
 void FRT_ClockFRC(void);

 void FRT_WDT_Update(void);
 void FRT_WDT_Recalc_NET(void);
 uint32 FRT_WDT_ClockDivider;
 sscpu_timestamp_t FRT_WDT_NextTS;

 //
 //
 // Watchdog timer registers and related state.
 //
 //
 struct
 {
  uint8 WTCSR;	// We don't let a CPU program set bit3 to 1, but we do set bit3 to 1 as part of the standby NMI recovery process(for internal use).
  uint8 WTCSRM;
  uint8 WTCNT;
  uint8 RSTCSR;
  uint8 RSTCSRM;
 } WDT;

 void WDT_Reset(bool from_internal_wdt) MDFN_COLD;	// Reset-reset only, NOT standby reset!
 void WDT_StandbyReset(void) MDFN_COLD;

 //
 // DMA unit registers and related state
 //
 bool DMA_RunCond(unsigned ch);
 bool DMA_InBurst(void);
 void DMA_CheckEnterBurstHack(void);
 void DMA_DoTransfer(unsigned ch);
 sscpu_timestamp_t DMA_Update(sscpu_timestamp_t);	// Takes/return external timestamp
 void DMA_StartSG(void);

 void DMA_RecalcRunning(void);
 void DMA_BusTimingKludge(void);

 const unsigned event_id_dma;
 sscpu_timestamp_t dma_lastts;	// External SH7095_mem_timestamp related.

 int32 DMA_ClockCounter;
 int32 DMA_SGCounter;	// When negative, smaller granularity scheduling for DMA_Update()
 bool DMA_RoundRobinRockinBoppin;

 uint32 DMA_PenaltyKludgeAmount;
 uint32 DMA_PenaltyKludgeAccum;

 struct
 {
  uint32 SAR;
  uint32 DAR;
  uint32 TCR;	// 24-bit, value of 0 = 2^24 tranfers
  uint16 CHCR;
  uint16 CHCRM;
  uint8 VCR;
  uint8 DRCR;
 } DMACH[2];

 uint8 DMAOR;
 uint8 DMAORM;


 //
 //
 // Division unit registers and related state
 //
 //
 void DIVU_S32_S32(void);
 void DIVU_S64_S32(void);

 sscpu_timestamp_t divide_finish_timestamp;
 uint32 DVSR;
 uint32 DVDNT;
 uint32 DVDNTH;
 uint32 DVDNTL;
 uint32 DVDNTH_Shadow;
 uint32 DVDNTL_Shadow;
 uint16 VCRDIV;
 uint8 DVCR;

 struct
 {
  uint8 SMR;	// Mode
  uint8 BRR;	// Bit rate
  uint8 SCR;	// Control
  uint8 TDR;	// Transmit data
  uint8 SSR, SSRM;	// Status
  uint8 RDR;	// Receive data

  uint8 RSR;	// Receive shift register
  uint8 TSR;	// Transmit shift register
 } SCI;

 void SCI_Reset(void) MDFN_COLD;

 const char* const cpu_name;

 //
 //
 //
 bool ExtHalt;

 uint8 (*const ExIVecFetch)(void);
 uint8 GetPendingInt(uint8*);
 void RecalcPendingIntPEX(void);

 template<bool EmulateICache, bool DebugMode>
 INLINE void FetchIF(bool ForceIBufferFill);

 template<bool EmulateICache, bool DebugMode, bool DelaySlot, bool IntPreventNext, bool SkipFetchIF>
 void DoIDIF_Real(void);

 template<typename T, bool BurstHax>
 T ExtBusRead(uint32 A);

 template<typename T>
 void ExtBusWrite(uint32 A, T V);

 template<typename T>
 void OnChipRegWrite(uint32 A, uint32 V);

 template<typename T>
 T OnChipRegRead(uint32 A);

 template<typename T, unsigned region, bool CacheEnabled, bool TwoWayMode, bool IsInstr, bool CacheBypassHack>
 T MemReadRT(uint32 A);

 template<typename T>
 T MemRead(uint32 A);

 template<typename T, unsigned region, bool CacheEnabled>
 void MemWriteRT(uint32 A, T V);

 template<typename T>
 void MemWrite(uint32 A, T V);


 template<unsigned which, bool EmulateICache, int DebugMode, bool delayed>
 INLINE void Branch(uint32 target);

 template<unsigned which, bool EmulateICache, int DebugMode, bool delayed>
 INLINE void CondRelBranch(bool cond, uint32 disp);


 template<unsigned which, bool EmulateICache, int DebugMode>
 INLINE void UCDelayBranch(uint32 target);

 template<unsigned which, bool EmulateICache, int DebugMode>
 INLINE void UCRelDelayBranch(uint32 disp);


 //
 //
 //
 //
 //
 //
 public:

 enum
 {
  // GSREG_PC_ID and GSREG_PC_IF are only valid when Step<true>() was called most recently(but they may be invalid
  // for a while after <false>, too...).
  GSREG_PC_ID = 0,
  GSREG_PC_IF,

  GSREG_PID,
  GSREG_PIF,

  GSREG_EP,

  GSREG_RPC,

  GSREG_R0,  GSREG_R1,  GSREG_R2,  GSREG_R3,  GSREG_R4,  GSREG_R5,  GSREG_R6,  GSREG_R7,
  GSREG_R8,  GSREG_R9,  GSREG_R10, GSREG_R11, GSREG_R12, GSREG_R13, GSREG_R14, GSREG_R15,

  GSREG_SR,
  GSREG_GBR,
  GSREG_VBR,

  GSREG_MACH,
  GSREG_MACL,
  GSREG_PR,
  //
  //
  //
  GSREG_NMIL,
  GSREG_IRL,
  GSREG_IPRA,
  GSREG_IPRB,
  GSREG_VCRWDT,
  GSREG_VCRA,
  GSREG_VCRB,
  GSREG_VCRC,
  GSREG_VCRD,
  GSREG_ICR,
  //
  //
  //
  GSREG_DVSR,
  GSREG_DVDNT,
  GSREG_DVDNTH,
  GSREG_DVDNTL,
  GSREG_DVDNTHS,
  GSREG_DVDNTLS,
  GSREG_VCRDIV,
  GSREG_DVCR,

  //
  //
  //
  GSREG_WTCSR,
  GSREG_WTCSRM,
  GSREG_WTCNT,
  GSREG_RSTCSR,
  GSREG_RSTCSRM,
  //
  //
  //
  GSREG_DMAOR,
  GSREG_DMAORM,

  GSREG_DMA0_SAR,
  GSREG_DMA0_DAR,
  GSREG_DMA0_TCR,
  GSREG_DMA0_CHCR,
  GSREG_DMA0_CHCRM,
  GSREG_DMA0_VCR,
  GSREG_DMA0_DRCR,

  GSREG_DMA1_SAR,
  GSREG_DMA1_DAR,
  GSREG_DMA1_TCR,
  GSREG_DMA1_CHCR,
  GSREG_DMA1_CHCRM,
  GSREG_DMA1_VCR,
  GSREG_DMA1_DRCR,

  GSREG_FRC,
  GSREG_OCR0,
  GSREG_OCR1,
  GSREG_FICR,
  GSREG_TIER,
  GSREG_FTCSR,
  GSREG_FTCSRM,
  GSREG_TCR,
  GSREG_TOCR,
  GSREG_RWT,
 };

 uint32 GetRegister(const unsigned id, char* const special, const uint32 special_len);
 void SetRegister(const unsigned id, const uint32 value) MDFN_COLD;

 void CheckRWBreakpoints(void (*MRead)(unsigned len, uint32 addr), void (*MWrite)(unsigned len, uint32 addr)) const;
 static void Disassemble(const uint16 instr, const uint32 PC, char* buffer, uint16 (*DisPeek16)(uint32), uint32 (*DisPeek32)(uint32));
 private:
 bool CBH_Setting;
 uint32 PC_IF, PC_ID;	// Debug-related variables.
};

#endif
