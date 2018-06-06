/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* spu.h:
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

#ifndef __MDFN_PSX_SPU_H
#define __MDFN_PSX_SPU_H

#include <mednafen/resampler/resampler.h>

namespace MDFN_IEN_PSX
{

enum
{
 ADSR_ATTACK = 0,
 ADSR_DECAY = 1,
 ADSR_SUSTAIN = 2,
 ADSR_RELEASE = 3
};

struct SPU_ADSR
{
 uint16 EnvLevel;	// We typecast it to (int16) in several places, but keep it here as (uint16) to prevent signed overflow/underflow, which compilers
			// may not treat consistently.
 uint32 Divider;
 uint32 Phase;

 bool AttackExp;
 bool SustainExp;
 bool SustainDec;
 bool ReleaseExp;

 int32 AttackRate;	// Ar
 int32 DecayRate;	// Dr * 4
 int32 SustainRate;	// Sr
 int32 ReleaseRate;	// Rr * 4

 int32 SustainLevel;	// (Sl + 1) << 11
};

class PS_SPU;
class SPU_Sweep
{
 friend class PS_SPU;		// For save states - FIXME(remove in future?)

 public:
 SPU_Sweep() { }
 ~SPU_Sweep() { }

 void Power(void);

 void WriteControl(uint16 value);
 int16 ReadVolume(void);

 void WriteVolume(int16 value);

 void Clock(void);

 private:
 uint16 Control;
 uint16 Current;	// We typecast it to (int16) in several places, but keep it here as (uint16) to prevent signed overflow/underflow, which compilers
			// may not treat consistently.
 uint32 Divider;
};

struct SPU_Voice
{
 int16 DecodeBuffer[0x20];
 int16 DecodeM2;
 int16 DecodeM1;

 uint32 DecodePlayDelay;
 uint32 DecodeWritePos;
 uint32 DecodeReadPos;
 uint32 DecodeAvail;

 uint8 DecodeShift;
 uint8 DecodeWeight;
 uint8 DecodeFlags;

 bool IgnoreSampLA;

 SPU_Sweep Sweep[2];

 uint16 Pitch;
 uint32 CurPhase;

 uint32 StartAddr;

 uint32 CurAddr;

 uint32 ADSRControl;

 uint32 LoopAddr;

 int32 PreLRSample;	// After enveloping, but before L/R volume.  Range of -32768 to 32767

 SPU_ADSR ADSR;
};

class PS_SPU
{
 public:

 PS_SPU() MDFN_COLD;
 ~PS_SPU() MDFN_COLD;

 void StateAction(StateMem *sm, const unsigned load, const bool data_only);

 void Power(void) MDFN_COLD;
 void Write(pscpu_timestamp_t timestamp, uint32 A, uint16 V);
 uint16 Read(pscpu_timestamp_t timestamp, uint32 A);

 void WriteDMA(uint32 V);
 uint32 ReadDMA(void);

 void StartFrame(double rate, uint32 quality);
 int32 EndFrame(int16 *SoundBuf, bool reverse);

 int32 UpdateFromCDC(int32 clocks);
 //pscpu_timestamp_t Update(pscpu_timestamp_t timestamp);

 private:

 void CheckIRQAddr(uint32 addr);
 void WriteSPURAM(uint32 addr, uint16 value);
 uint16 ReadSPURAM(uint32 addr);

 void RunDecoder(SPU_Voice *voice);

 void CacheEnvelope(SPU_Voice *voice);
 void ResetEnvelope(SPU_Voice *voice);
 void ReleaseEnvelope(SPU_Voice *voice);
 void RunEnvelope(SPU_Voice *voice);


 void RunReverb(const int32* in, int32* out);
 void RunNoise(void);
 bool GetCDAudio(int32 &l, int32 &r);

 SPU_Voice Voices[24];

 uint32 NoiseDivider;
 uint32 NoiseCounter;
 uint16 LFSR;

 uint32 FM_Mode;
 uint32 Noise_Mode;
 uint32 Reverb_Mode;

 uint32 ReverbWA;

 SPU_Sweep GlobalSweep[2];	// Doesn't affect reverb volume!

 int32 ReverbVol[2];

 int32 CDVol[2];
 int32 ExternVol[2];
 
 uint32 IRQAddr;

 uint32 RWAddr;

 uint16 SPUControl;

 uint32 VoiceOn;
 uint32 VoiceOff;

 uint32 BlockEnd;

 uint32 CWA;

 union
 {
  uint16 Regs[0x100];
  struct
  {
   uint16 VoiceRegs[0xC0];
   union
   {
    uint16 GlobalRegs[0x20];
    struct
    {
     uint16 _Global0[0x17];
     uint16 SPUStatus;
     uint16 _Global1[0x08];
    };
   };
   union
   {
    uint16 ReverbRegs[0x20];

    struct
    {
     uint16 FB_SRC_A;
     uint16 FB_SRC_B;
     int16 IIR_ALPHA;
     int16 ACC_COEF_A;
     int16 ACC_COEF_B;
     int16 ACC_COEF_C;
     int16 ACC_COEF_D;
     int16 IIR_COEF;
     int16 FB_ALPHA;
     int16 FB_X;
     uint16 IIR_DEST_A0;
     uint16 IIR_DEST_A1;
     uint16 ACC_SRC_A0;
     uint16 ACC_SRC_A1;
     uint16 ACC_SRC_B0;
     uint16 ACC_SRC_B1;
     uint16 IIR_SRC_A0;
     uint16 IIR_SRC_A1;
     uint16 IIR_DEST_B0;
     uint16 IIR_DEST_B1;
     uint16 ACC_SRC_C0;
     uint16 ACC_SRC_C1;
     uint16 ACC_SRC_D0;
     uint16 ACC_SRC_D1;
     uint16 IIR_SRC_B1;
     uint16 IIR_SRC_B0;
     uint16 MIX_DEST_A0;
     uint16 MIX_DEST_A1;
     uint16 MIX_DEST_B0;
     uint16 MIX_DEST_B1;
     int16 IN_COEF_L;
     int16 IN_COEF_R;
    };
   };
  };
 };

 uint16 AuxRegs[0x10];

 int16 RDSB[2][128];
 int16 RUSB[2][64];
 int32 RvbResPos;

 uint32 ReverbCur;

 uint32 Get_Reverb_Offset(uint32 offset);
 int16 RD_RVB(uint16 raw_offs, int32 extra_offs = 0);
 void WR_RVB(uint16 raw_offs, int16 sample);

 bool IRQAsserted;

 //pscpu_timestamp_t lastts;
 int32 clock_divider;

 uint16 SPURAM[524288 / sizeof(uint16)];

 int last_rate;
 uint32 last_quality;
 SpeexResamplerState *resampler;

 // Buffers 44.1KHz samples, should have enough for two(worst-case scenario) video frames(2* ~735 frames NTSC, 2* ~882 PAL) plus jitter plus enough for the resampler leftovers.
 // We'll just go with 4096 because powers of 2 are AWESOME and such.
 uint32 IntermediateBufferPos;
 int16 IntermediateBuffer[4096][2];

 public:
 enum
 {
  GSREG_SPUCONTROL = 0,

  GSREG_FM_ON,
  GSREG_NOISE_ON,
  GSREG_REVERB_ON,

  GSREG_CDVOL_L,
  GSREG_CDVOL_R,

  GSREG_MAINVOL_CTRL_L,
  GSREG_MAINVOL_CTRL_R,

  GSREG_MAINVOL_L,
  GSREG_MAINVOL_R,

  GSREG_RVBVOL_L,
  GSREG_RVBVOL_R,

  GSREG_RWADDR,

  GSREG_IRQADDR,

  GSREG_REVERBWA,

  GSREG_VOICEON,
  GSREG_VOICEOFF,
  GSREG_BLOCKEND,

  // Note: the order of these should match the reverb reg array
  GSREG_FB_SRC_A,
  GSREG_FB_SRC_B,
  GSREG_IIR_ALPHA,
  GSREG_ACC_COEF_A,
  GSREG_ACC_COEF_B,
  GSREG_ACC_COEF_C,
  GSREG_ACC_COEF_D,
  GSREG_IIR_COEF,
  GSREG_FB_ALPHA,
  GSREG_FB_X,
  GSREG_IIR_DEST_A0,
  GSREG_IIR_DEST_A1,
  GSREG_ACC_SRC_A0,
  GSREG_ACC_SRC_A1,
  GSREG_ACC_SRC_B0,
  GSREG_ACC_SRC_B1,
  GSREG_IIR_SRC_A0,
  GSREG_IIR_SRC_A1,
  GSREG_IIR_DEST_B0,
  GSREG_IIR_DEST_B1,
  GSREG_ACC_SRC_C0,
  GSREG_ACC_SRC_C1,
  GSREG_ACC_SRC_D0,
  GSREG_ACC_SRC_D1,
  GSREG_IIR_SRC_B1,
  GSREG_IIR_SRC_B0,
  GSREG_MIX_DEST_A0,
  GSREG_MIX_DEST_A1,
  GSREG_MIX_DEST_B0,
  GSREG_MIX_DEST_B1,
  GSREG_IN_COEF_L,
  GSREG_IN_COEF_R,


  // Multiply v * 256 for each extra voice
  GSREG_V0_VOL_CTRL_L  = 0x8000,
  GSREG_V0_VOL_CTRL_R,
  GSREG_V0_VOL_L,
  GSREG_V0_VOL_R,
  GSREG_V0_PITCH,
  GSREG_V0_STARTADDR,
  GSREG_V0_ADSR_CTRL,
  GSREG_V0_ADSR_LEVEL,
  GSREG_V0_LOOP_ADDR,
  GSREG_V0_READ_ADDR
 };

 uint32 GetRegister(unsigned int which, char *special, const uint32 special_len);
 void SetRegister(unsigned int which, uint32 value);

 uint16 PeekSPURAM(uint32 address);
 void PokeSPURAM(uint32 address, uint16 value);
};


}

#endif
