/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* scu_dsp_common.inc:
**  Copyright (C) 2015-2018 Mednafen Team
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

#if (defined(__x86_64__) && defined(__code_model_small__) && !defined(__PIC__) && !defined(__pic__)) || SIZEOF_VOID_P <= 4
 #define DSP_INSTR_BASE_UIPT 0
 #define DSP_INSTR_RECOVER_TCAST uint32
#else
 #define DSP_INSTR_BASE_UIPT ((uintptr_t)DSP_Init)
 #define DSP_INSTR_RECOVER_TCAST int32
#endif

// See loop in "SCU_UpdateDSP()" in scu.inc, and END/ENDI handling in scu_dsp_misc.cpp
enum { DSP_EndCCSubVal = 1000000 };

void DSP_Init(void);
void DSP_FinishPRAMDMA(void);

union DSPR48
{
#ifdef MSB_FIRST
 struct
 {
  uint16 dummy;
  uint16 H;
  uint32 L;
 };
#else
 struct
 {
  uint32 L;
  uint16 H;
  uint16 dummy;
 };
#endif
 uint64 T;	// Upper 16 bits may be non-zero "garbage", so don't assume they're zero in code that reads from this variable.
};

struct DSPS
{
 sscpu_timestamp_t LastTS;
 int32 CycleCounter;
 int32 T0_Until;
 //
 enum
 {
  // No execute = 0x00000000		<= 0
  // Paused + No execute = 0x80000000	<= 0
  // Paused + Execute = 0x80000001	<= 0
  // Execute = 0x00000001	> 0
  STATE_MASK_PAUSE = 0x80000000,
  STATE_MASK_EXECUTE = 0x00000001,
 };
 int32 State;

 INLINE bool IsRunning(void)	// returns true if not stopped and not paused.
 {
  return State > 0;
 }

 uint64 NextInstr;

 uint8 PC;
 uint8 RA;

 bool FlagZ;
 bool FlagS;
 bool FlagV;
 bool FlagC;

 bool FlagEnd;

 uint8 TOP;
 uint16 LOP;	// 12 bits

 DSPR48 AC;
 DSPR48 P;

 union
 {
  uint8 CT[4];	// 6 bits(each)
  uint32 CT32;
 };

 uint32 RX;
 uint32 RY;

 uint32 RAO;
 uint32 WAO;

 uint32 DataRAM[4][64];

 uint64 ProgRAM[256];	// Upper 32 bits = actual raw instruction, lower 32 bits = horrible emulator handler pointer madness

 //
 // See comments at top of scu.inc regarding DSP DMA to program RAM.
 //
 uint32 PRAMDMABuf[256];
 uint32 PRAMDMABufCount;
};


// ALU Op: bits 26-29	- *16
//   X Op: bits 23-25	- * 8
//   Y Op: bits 17-19	- * 8
//  D1 Op: bits 12-13	- * 4
extern void (*const DSP_GenFuncTable[2][16][8][8][4])(void);

// Hold/Format/Direction: bits 12-14
//  Hold: bit 14
//  Format: bit 13
//  Direction: bit 12
// RAM: bits 8-10
//
extern void (*const DSP_DMAFuncTable[2][8][8])(void);

//
// Dest: bits 26-29
// Condition: bits 19-25
//
extern void (*const DSP_MVIFuncTable[2][16][128])(void);

//
// Condition: bits 19-25
//
extern void (*const DSP_JMPFuncTable[2][128])(void);


//
// LPS, BTM, END, ENDI(bits 29-31 = 0x7)
// bits 27-28
//
extern void (*const DSP_MiscFuncTable[2][4])(void);

extern DSPS DSP;

template<bool looped = false>
static INLINE uint64 DSP_DecodeInstruction(const uint32 instr)
{
 void (*aal)(void);

 switch((instr >> 28) & 0xF)
 {
  default:
	aal = DSP_GenFuncTable[looped][0][0][0][0];
	break;

  case 0x0:
  case 0x1:
  case 0x2:
  case 0x3:
	aal = DSP_GenFuncTable[looped][(instr >> 26) & 0xF][(instr >> 23) & 0x7][(instr >> 17) & 0x7][(instr >> 12) & 0x3];
	break;

  case 0x8:
  case 0x9:
  case 0xA:
  case 0xB:
	aal = DSP_MVIFuncTable[looped][(instr >> 26) & 0xF][(instr >> 19) & 0x7F];
	break;

  case 0xC:
	aal = DSP_DMAFuncTable[looped][(instr >> 12) & 0x7][(instr >> 8) & 0x7];
	break;

  case 0xD:
	aal = DSP_JMPFuncTable[looped][(instr >> 19) & 0x7F];
	break;

  case 0xE:
  case 0xF:
	aal = DSP_MiscFuncTable[looped][(instr >> 27) & 0x3];
	break;
 }

 return ((uint64)instr << 32) | (uint32)((uintptr_t)aal - DSP_INSTR_BASE_UIPT);
}

template<bool looped>
static INLINE uint32 DSP_InstrPre(void)
{
 const uint32 instr = DSP.NextInstr >> 32;

 if(!looped || !DSP.LOP)
 {
  DSP.NextInstr = DSP.ProgRAM[DSP.PC];
  DSP.PC++;
 }

 if(looped)
  DSP.LOP = (DSP.LOP - 1) & 0x0FFF;

 return instr;
}

template<unsigned cond>
static INLINE bool DSP_TestCond(void)
{
 if(!(cond & 0x40))
  return true;
 //
 //
 //
 bool ret = false;

 if(cond & 0x1)
  ret |= DSP.FlagZ;

 if(cond & 0x2)
  ret |= DSP.FlagS;

 if(cond & 0x4)
  ret |= DSP.FlagC;

 if(cond & 0x8)
  ret |= (DSP.T0_Until < DSP.CycleCounter);

 //if(cond & 0x10)	// ?

 return ret == (bool)(cond & 0x20);
}

