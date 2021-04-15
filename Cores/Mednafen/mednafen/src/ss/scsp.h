/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* scsp.h:
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

class SS_SCSP
{
 public:

 SS_SCSP() MDFN_COLD;
 ~SS_SCSP() MDFN_COLD;

 void StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname) MDFN_COLD;

 void Reset(bool powering_up) MDFN_COLD;
 void RunSample(int16* outlr);

 template<typename T, bool IsWrite>
 void RW(uint32 A, T& V); //, void (*time_sucker)();

 INLINE uint16* GetEXTSPtr(void)
 {
  return EXTS;
 }

 INLINE uint16* GetRAMPtr(void)
 {
  return RAM;
 }

 enum
 {
  GSREG_MVOL = 0,
  GSREG_DAC18B,
  GSREG_MEM4MB,
  GSREG_RBC,
  GSREG_MSLC,

  GSREG_SCIEB,
  GSREG_SCIPD,
  GSREG_MCIEB,
  GSREG_MCIPD,

  GSREG_EFREG0, GSREG_EFREG1, GSREG_EFREG2, GSREG_EFREG3, GSREG_EFREG4, GSREG_EFREG5, GSREG_EFREG6, GSREG_EFREG7,
  GSREG_EFREG8, GSREG_EFREG9, GSREG_EFREGA, GSREG_EFREGB, GSREG_EFREGC, GSREG_EFREGD, GSREG_EFREGE, GSREG_EFREGF
 };

 uint32 GetRegister(const unsigned id, char* const special, const uint32 special_len) MDFN_COLD;
 void SetRegister(const unsigned id, const uint32 value) MDFN_COLD;

 private:

 void RecalcSoundInt(void);
 void RecalcMainInt(void);

 enum
 {
  ENV_PHASE_ATTACK = 0,
  ENV_PHASE_DECAY1 = 1,
  ENV_PHASE_DECAY2 = 2,
  ENV_PHASE_RELEASE = 3
 };

 uint16 SlotRegs[0x20][0x10];

 struct Slot
 {
  uint32 StartAddr;	// 20 bits, memory address.
  uint16 LoopStart;	// 16 bits, in samples.
  uint16 LoopEnd;	// 16 bits, in samples.
  //
  bool KeyBit;
  //
  bool WF8Bit;
  uint8 LoopMode;
  enum
  {
   LOOP_DISABLED = 0,
   LOOP_NORMAL = 1,
   LOOP_REVERSE = 2,
   LOOP_ALTERNATING = 3
  };

  uint8 SourceControl;
  enum
  {
   SOURCE_MEMORY = 0,
   SOURCE_NOISE = 1,
   SOURCE_ZERO = 2,
   SOURCE_UNDEFINED = 3
  };

  uint16 SBXOR;

  uint8 EnvRates[4];

  bool AttackHold;
  bool AttackLoopLink;
  uint8 DecayLevel;

  uint8 KRS;
  uint8 TotalLevel;
  bool EGBypass;	// When true, force EG output to 0(no attenuation), but TL and ALFO still have an effect
  bool SoundDirect;	// When true, bypass EG, TL, ALFO volume control

  bool StackWriteInhibit;

  uint8 ModLevel;
  uint8 ModInputX;
  uint8 ModInputY;

  uint8 Octave;
  uint16 FreqNum;

  uint8 ALFOModLevel;
  uint8 ALFOWaveform;

  uint8 PLFOModLevel;
  uint8 PLFOWaveform;
 
  uint8 LFOFreq;

  bool LFOReset;

  // DSP mix stack
  uint8 ToDSPSelect;
  uint8 ToDSPLevel;

  int16 DirectVolume[2];	// 1.14 fixed point, derived from DISDL and DIPAN
  int16 EffectVolume[2];	// 1.14 fixed point, derived from EFSDL and EFPAN
  //
  //
  uint32 ShortWaveMask;
  bool ShortWave;
  uint16 CurrentAddr;
  uint32 PhaseWhacker;
  bool InLoop;
  bool LoopSub;
  bool WFAllowAccess;
  uint8 EnvPhase;	// ENV_PHASE_ATTACK ... ENV_PHASE_RELEASE (0...3)
  uint32 EnvLevel;	// 0 ... 0x3FF
  bool EnvGCBTPrev;

  uint8 LFOCounter;
  uint16 LFOTimeCounter;
 } Slots[32];

 uint16 EXTS[2];

 void RecalcShortWaveMask(Slot* s);

 void RunEG(Slot* s, const unsigned key_eg_scale);

 uint8 GetALFO(Slot* s);
 int GetPLFO(Slot* s);
 void RunLFO(Slot* s);

 uint16 SoundStack[0x40];
 uint16 SoundStackDelayer[4];

 uint16 MasterVolume;	// 1.8 fixed point, derived from MVOL
 uint8 MVOL;
 bool DAC18bit;
 bool Mem4Mb;

 uint32 SlotMonitorWhich;
 uint16 SlotMonitorData;

 bool KeyExecute;
 uint32 LFSR;
 uint32 GlobalCounter;

 const uint16 SB_XOR_Table[4] = { 0x0000, 0x7FFF, 0x8000, 0xFFFF };

 //
 //
 enum
 {
  MIDIF_INPUT_EMPTY = 0x01,
  MIDIF_INPUT_FULL  = 0x02,
  MIDIF_INPUT_OFLOW = 0x04,
  MIDIF_OUTPUT_EMPTY= 0x08,
  MIDIF_OUTPUT_FULL = 0x10
 };
 struct
 {
  uint8 InputFIFO[4];
  uint8 InputRP, InputWP, InputCount;

  uint8 OutputFIFO[4];
  uint8 OutputRP, OutputWP, OutputCount;

  uint8 Flags;

  //
  INLINE uint8 ReadInput(void)
  {
   uint8 ret = InputFIFO[InputRP]; // May not be correct for InputCount == 0; test.

   if(InputCount)
   {
    InputRP = (InputRP + 1) & 0x3;
    InputCount--;
    Flags &= ~MIDIF_INPUT_FULL;
    if(!InputCount)
     Flags |= MIDIF_INPUT_EMPTY;
   }

   return ret;
  }

  INLINE void WriteOutput(uint8 V)
  {
   if(OutputCount == 4)	// May not be correct; test.
    return;

   OutputFIFO[OutputWP] = V;
   OutputWP = (OutputWP + 1) & 0x3;
   OutputCount++;

   Flags &= ~MIDIF_OUTPUT_EMPTY;
   if(OutputCount == 4)
    Flags |= MIDIF_OUTPUT_FULL;
  }

  void Reset(void)
  {
   memset(InputFIFO, 0, sizeof(InputFIFO));
   memset(OutputFIFO, 0, sizeof(OutputFIFO));

   InputRP = InputWP = InputCount = 0;
   OutputRP = OutputWP = OutputCount = 0;

   Flags = MIDIF_INPUT_EMPTY | MIDIF_OUTPUT_EMPTY;
  }
 } MIDI;
 //
 //
 uint16 SCIEB;
 uint16 SCIPD;

 uint16 MCIEB;
 uint16 MCIPD;

 uint8 SCILV[3];
 //
 //
 struct
 {
  uint8 Control;
  uint8 Counter;
  bool PrevClockIn;
  int32 Reload;
 } Timers[3];
 //
 //
 // DMEA, DRGA, and DTLG are apparently not altered by executing DMA.
 //
 uint32 DMEA;
 uint16 DRGA;
 uint16 DTLG;

 bool DMA_Execute;
 bool DMA_Direction;
 bool DMA_Gate;

 void RunDMA(void);
 //
 //
 uint8 RBP;
 uint8 RBL;
 void RunDSP(void);

 struct DSPS
 {
  uint64 MPROG[0x80];
  uint32 TEMP[0x80];	// 24 bit
  uint32 MEMS[0x20];	// 24 bit
  uint16 COEF[64];	// 13 bit
  uint16 MADRS[32];	// 16 bit

  uint32 MIXS[0x10];	// 20 bit
  uint16 EFREG[0x10];

  uint32 INPUTS;	// 24 bit

  uint32 SFT_REG;	// 26 bit
  uint16 FRC_REG;	// 13 bit
  uint32 Y_REG;		// 24 bit, latches INPUTS
  uint16 ADRS_REG;	// 12 bit, latches output of A_SEL(which selects between shifter output and upper 8 bits of INPUTS

  uint16 MDEC_CT;

  uint32 RWAddr;

  bool WritePending;
  uint16 WriteValue;

  uint8 ReadPending;	// = 1 (NOFL=0), =2 (NOFL=1) at time or MRT
  uint32 ReadValue;

  bool MPROG_Dirty;
 } DSP;
 //
 //

 uint16 RAM[262144 * 2];	// *2 for dummy so we don't have to have so many conditionals in the playback code.

#ifdef MDFN_SS_SCSP_DSP_DYNAREC
 alignas(8) uint8 DynaRecPool[65536];
#endif
};

