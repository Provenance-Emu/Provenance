/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* cpu.h:
**  Copyright (C) 2011-2016 Mednafen Team
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

#ifndef __MDFN_PSX_CPU_H
#define __MDFN_PSX_CPU_H

/*
 Load delay notes:

	// Takes 1 less
	".set noreorder\n\t"
	".set nomacro\n\t"
	"lw %0, 0(%2)\n\t"
	"nop\n\t"
	"nop\n\t"
	"or %0, %1, %1\n\t"

	// cycle than this:
	".set noreorder\n\t"
	".set nomacro\n\t"
	"lw %0, 0(%2)\n\t"
	"nop\n\t"
	"or %0, %1, %1\n\t"
	"nop\n\t"


	// Both of these
	".set noreorder\n\t"
	".set nomacro\n\t"
	"lw %0, 0(%2)\n\t"
	"nop\n\t"
	"nop\n\t"
	"or %1, %0, %0\n\t"

	// take same...(which is kind of odd).
	".set noreorder\n\t"
	".set nomacro\n\t"
	"lw %0, 0(%2)\n\t"
	"nop\n\t"
	"or %1, %0, %0\n\t"
	"nop\n\t"
*/

#include "gte.h"

namespace MDFN_IEN_PSX
{

class PS_CPU
{
 public:

 PS_CPU() MDFN_COLD;
 ~PS_CPU() MDFN_COLD;

 // FAST_MAP_* enums are in BYTES(8-bit), not in 32-bit units("words" in MIPS context), but the sizes
 // will always be multiples of 4.
 enum { FAST_MAP_SHIFT = 16 };
 enum { FAST_MAP_PSIZE = 1 << FAST_MAP_SHIFT };

 void SetFastMap(void *region_mem, uint32 region_address, uint32 region_size);

 INLINE void SetEventNT(const pscpu_timestamp_t next_event_ts_arg)
 {
  next_event_ts = next_event_ts_arg;
 }

 pscpu_timestamp_t Run(pscpu_timestamp_t timestamp_in, bool BIOSPrintMode, bool ILHMode);

 void Power(void) MDFN_COLD;

 // which ranges 0-5, inclusive
 void AssertIRQ(unsigned which, bool asserted);

 void SetHalt(bool status);

 // TODO eventually: factor BIU address decoding directly in the CPU core somehow without hurting speed.
 void SetBIU(uint32 val);
 uint32 GetBIU(void);

 void StateAction(StateMem *sm, const unsigned load, const bool data_only);

 private:

 uint32 GPR[32 + 1];	// GPR[32] Used as dummy in load delay simulation(indexing past the end of real GPR)

 uint32 LO;
 uint32 HI;


 uint32 BACKED_PC;
 uint32 BACKED_new_PC;

 uint32 IPCache;
 uint8 BDBT;

 uint8 ReadAbsorb[0x20 + 1];
 uint8 ReadAbsorbWhich;
 uint8 ReadFudge;

 void RecalcIPCache(void);
 bool Halted;

 uint32 BACKED_LDWhich;
 uint32 BACKED_LDValue;
 uint32 LDAbsorb;

 pscpu_timestamp_t next_event_ts;
 pscpu_timestamp_t gte_ts_done;
 pscpu_timestamp_t muldiv_ts_done;

 uint32 BIU;

 const uint32 addr_mask[8] = { 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0x7FFFFFFF, 0x1FFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF };

 enum
 {
  CP0REG_BPC = 3,		// PC breakpoint address.
  CP0REG_BDA = 5,		// Data load/store breakpoint address.
  CP0REG_TAR = 6,		// Target address(???)
  CP0REG_DCIC = 7,		// Cache control
  CP0REG_BADA = 8,
  CP0REG_BDAM = 9,		// Data load/store address mask.
  CP0REG_BPCM = 11,		// PC breakpoint address mask.
  CP0REG_SR = 12,
  CP0REG_CAUSE = 13,
  CP0REG_EPC = 14,
  CP0REG_PRID = 15		// Product ID
 };

 struct
 {
  union
  {
   uint32 Regs[32];
   struct
   {
    uint32 Unused00;
    uint32 Unused01;
    uint32 Unused02;
    uint32 BPC;		// RW
    uint32 Unused04;
    uint32 BDA;		// RW
    uint32 TAR;		// R
    uint32 DCIC;	// RW
    uint32 BADA;	// R
    uint32 BDAM;	// R/W
    uint32 Unused0A;
    uint32 BPCM;	// R/W
    uint32 SR;		// R/W
    uint32 CAUSE;	// R/W(partial)
    uint32 EPC;		// R
    uint32 PRID;	// R
   };
  };
 } CP0;

 uint8 MULT_Tab24[24];

 struct __ICache
 {
  /*
   TV:
	Mask 0x00000001: 0x0 = icache enabled((BIU & 0x800) == 0x800), 0x1 = icache disabled(changed in bulk on BIU value changes; preserve everywhere else!)
	Mask 0x00000002: 0x0 = valid, 0x2 = invalid
	Mask 0x00000FFC: Always 0
	Mask 0xFFFFF000: Tag.
  */
  uint32 TV;
  uint32 Data;
 };

 union
 {
  __ICache ICache[1024];
  uint32 ICache_Bulk[2048];
 };

 MultiAccessSizeMem<1024, false> ScratchRAM;

 //PS_GTE GTE;

 uintptr_t FastMap[1 << (32 - FAST_MAP_SHIFT)];
 uint8 DummyPage[FAST_MAP_PSIZE];

 enum
 {
  EXCEPTION_INT = 0,
  EXCEPTION_MOD = 1,
  EXCEPTION_TLBL = 2,
  EXCEPTION_TLBS = 3,
  EXCEPTION_ADEL = 4, // Address error on load
  EXCEPTION_ADES = 5, // Address error on store
  EXCEPTION_IBE = 6, // Instruction bus error
  EXCEPTION_DBE = 7, // Data bus error
  EXCEPTION_SYSCALL = 8, // System call
  EXCEPTION_BP = 9, // Breakpoint
  EXCEPTION_RI = 10, // Reserved instruction
  EXCEPTION_COPU = 11,  // Coprocessor unusable
  EXCEPTION_OV = 12	// Arithmetic overflow
 };

 uint32 Exception(uint32 code, uint32 PC, const uint32 NP, const uint32 instr) MDFN_WARN_UNUSED_RESULT;

 template<bool DebugMode, bool BIOSPrintMode, bool ILHMode> pscpu_timestamp_t RunReal(pscpu_timestamp_t timestamp_in) NO_INLINE;

 template<typename T> T PeekMemory(uint32 address) MDFN_COLD;
 template<typename T> void PokeMemory(uint32 address, T value) MDFN_COLD;
 template<typename T> T ReadMemory(pscpu_timestamp_t &timestamp, uint32 address, bool DS24 = false, bool LWC_timing = false);
 template<typename T> void WriteMemory(pscpu_timestamp_t &timestamp, uint32 address, uint32 value, bool DS24 = false);

 uint32 ReadInstruction(pscpu_timestamp_t &timestamp, uint32 address);

 //
 // Mednafen debugger stuff follows:
 //
 public:
 void SetCPUHook(void (*cpuh)(const pscpu_timestamp_t timestamp, uint32 pc), void (*addbt)(uint32 from, uint32 to, bool exception));
 void CheckBreakpoints(void (*callback)(bool write, uint32 address, unsigned int len), uint32 instr);

 enum
 {
  GSREG_GPR = 0,
  GSREG_PC = 32,
  GSREG_PC_NEXT,
  GSREG_IN_BD_SLOT,
  GSREG_LO,
  GSREG_HI,
  //
  //
  GSREG_BPC,
  GSREG_BDA,
  GSREG_TAR,
  GSREG_DCIC,
  GSREG_BADA,
  GSREG_BDAM,
  GSREG_BPCM,
  GSREG_SR,
  GSREG_CAUSE,
  GSREG_EPC
 };

 uint32 GetRegister(unsigned int which, char *special, const uint32 special_len);
 void SetRegister(unsigned int which, uint32 value);
 bool PeekCheckICache(uint32 PC, uint32 *iw);

 uint8 PeekMem8(uint32 A);
 uint16 PeekMem16(uint32 A);
 uint32 PeekMem32(uint32 A);

 void PokeMem8(uint32 A, uint8 V);
 void PokeMem16(uint32 A, uint16 V);
 void PokeMem32(uint32 A, uint32 V);

 private:
 void (*CPUHook)(const pscpu_timestamp_t timestamp, uint32 pc);
 void (*ADDBT)(uint32 from, uint32 to, bool exception);
};

}

#endif
