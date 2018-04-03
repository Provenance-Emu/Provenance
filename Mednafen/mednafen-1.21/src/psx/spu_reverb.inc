/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* spu_reverb.inc:
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

static int16 ReverbSat(int32 samp) MDFN_WARN_UNUSED_RESULT;
static INLINE int16 ReverbSat(int32 samp)
{
 if(samp > 32767)
  samp = 32767;

 if(samp < -32768)
  samp = -32768;

 return(samp);
}


INLINE uint32 PS_SPU::Get_Reverb_Offset(uint32 in_offset)
{
 uint32 offset = ReverbCur + (in_offset & 0x3FFFF);

 offset += ReverbWA & ((int32)(offset << 13) >> 31);
 offset &= 0x3FFFF;

 // For debugging in case there are any problems with games misprogramming the reverb registers in a race-conditiony manner that
 // causes important data in SPU RAM to be trashed:
 //if(offset < ReverbWA)
 // printf("BARF: offset=%05x reverbwa=%05x reverbcur=%05x in_offset=%05x\n", offset, ReverbWA, ReverbCur, in_offset & 0x3FFFF);

 return(offset);
}

int16 NO_INLINE PS_SPU::RD_RVB(uint16 raw_offs, int32 extra_offs)
{
 return ReadSPURAM(Get_Reverb_Offset((raw_offs << 2) + extra_offs));
}

void NO_INLINE PS_SPU::WR_RVB(uint16 raw_offs, int16 sample)
{
 WriteSPURAM(Get_Reverb_Offset(raw_offs << 2), sample);
}

//
// Zeroes optimized out; middle removed too(it's 16384)
static const int16 ResampTable[20] =
{
 -1, 2, -10, 35, -103, 266, -616, 1332, -2960, 10246, 10246, -2960, 1332, -616, 266, -103, 35, -10, 2, -1,
};

static INLINE int32 Reverb4422(const int16 *src)
{
 int32 out = 0;	// 32-bits is adequate(it won't overflow)

 for(unsigned i = 0; i < 20; i++)
  out += ResampTable[i] * src[i * 2];

 // Middle non-zero
 out += 0x4000 * src[19];

 out >>= 15;

 clamp(&out, -32768, 32767);

 return(out);
}

template<bool phase>
static INLINE int32 Reverb2244(const int16 *src)
{
 int32 out;	// 32-bits is adequate(it won't overflow)

 if(phase)
 {
  // Middle non-zero
  out = src[9];
 }
 else
 {
  out = 0;

  for(unsigned i = 0; i < 20; i++)
   out += ResampTable[i] * src[i];

  out >>= 14;

  clamp(&out, -32768, 32767);
 }

 return(out);
}

static int32 IIASM(const int16 IIR_ALPHA, const int16 insamp)
{
 if(MDFN_UNLIKELY(IIR_ALPHA == -32768))
 {
  //const int32 iai_adj = sign_x_to_s32(17, (32768 - IIR_ALPHA));
  //tmp = iai_adj * in_samp

  if(insamp == -32768)
   return 0;
  else
   return insamp * -65536;
 }
 else
  return insamp * (32768 - IIR_ALPHA);
}

//
// Take care to thoroughly test the reverb resampling code when modifying anything that uses RvbResPos.
//
INLINE void PS_SPU::RunReverb(const int32* in, int32* out)
{
 int32 upsampled[2] = { 0, 0 };

 for(unsigned lr = 0; lr < 2; lr++)
 {
  RDSB[lr][RvbResPos | 0x00] = in[lr];
  RDSB[lr][RvbResPos | 0x40] = in[lr];	// So we don't have to &/bounds check in our MAC loop
 }

 if(RvbResPos & 1)
 {
  int32 downsampled[2];

  for(unsigned lr = 0; lr < 2; lr++)
   downsampled[lr] = Reverb4422(&RDSB[lr][(RvbResPos - 39) & 0x3F]);

  //
  // Run algorithm
  ///
  if(SPUControl & 0x80)
  {
   int16 IIR_INPUT_A0, IIR_INPUT_A1, IIR_INPUT_B0, IIR_INPUT_B1;
   int16 IIR_A0, IIR_A1, IIR_B0, IIR_B1;
   int16 ACC0, ACC1;
   int16 FB_A0, FB_A1, FB_B0, FB_B1;

   IIR_INPUT_A0 = ReverbSat(((RD_RVB(IIR_SRC_A0) * IIR_COEF) >> 15) + ((downsampled[0] * IN_COEF_L) >> 15));
   IIR_INPUT_A1 = ReverbSat(((RD_RVB(IIR_SRC_A1) * IIR_COEF) >> 15) + ((downsampled[1] * IN_COEF_R) >> 15));
   IIR_INPUT_B0 = ReverbSat(((RD_RVB(IIR_SRC_B0) * IIR_COEF) >> 15) + ((downsampled[0] * IN_COEF_L) >> 15));
   IIR_INPUT_B1 = ReverbSat(((RD_RVB(IIR_SRC_B1) * IIR_COEF) >> 15) + ((downsampled[1] * IN_COEF_R) >> 15));

   IIR_A0 = ReverbSat((((IIR_INPUT_A0 * IIR_ALPHA) >> 14) + (IIASM(IIR_ALPHA, RD_RVB(IIR_DEST_A0, -1)) >> 14)) >> 1);
   IIR_A1 = ReverbSat((((IIR_INPUT_A1 * IIR_ALPHA) >> 14) + (IIASM(IIR_ALPHA, RD_RVB(IIR_DEST_A1, -1)) >> 14)) >> 1);
   IIR_B0 = ReverbSat((((IIR_INPUT_B0 * IIR_ALPHA) >> 14) + (IIASM(IIR_ALPHA, RD_RVB(IIR_DEST_B0, -1)) >> 14)) >> 1);
   IIR_B1 = ReverbSat((((IIR_INPUT_B1 * IIR_ALPHA) >> 14) + (IIASM(IIR_ALPHA, RD_RVB(IIR_DEST_B1, -1)) >> 14)) >> 1);

   WR_RVB(IIR_DEST_A0, IIR_A0);
   WR_RVB(IIR_DEST_A1, IIR_A1);
   WR_RVB(IIR_DEST_B0, IIR_B0);
   WR_RVB(IIR_DEST_B1, IIR_B1);

   ACC0 = ReverbSat((((RD_RVB(ACC_SRC_A0) * ACC_COEF_A) >> 14) +
	   	     ((RD_RVB(ACC_SRC_B0) * ACC_COEF_B) >> 14) +
	   	     ((RD_RVB(ACC_SRC_C0) * ACC_COEF_C) >> 14) +
	   	     ((RD_RVB(ACC_SRC_D0) * ACC_COEF_D) >> 14)) >> 1);

   ACC1 = ReverbSat((((RD_RVB(ACC_SRC_A1) * ACC_COEF_A) >> 14) +
	   	     ((RD_RVB(ACC_SRC_B1) * ACC_COEF_B) >> 14) +
	   	     ((RD_RVB(ACC_SRC_C1) * ACC_COEF_C) >> 14) +
	   	     ((RD_RVB(ACC_SRC_D1) * ACC_COEF_D) >> 14)) >> 1);

   FB_A0 = RD_RVB(MIX_DEST_A0 - FB_SRC_A);
   FB_A1 = RD_RVB(MIX_DEST_A1 - FB_SRC_A);
   FB_B0 = RD_RVB(MIX_DEST_B0 - FB_SRC_B);
   FB_B1 = RD_RVB(MIX_DEST_B1 - FB_SRC_B);

   WR_RVB(MIX_DEST_A0, ReverbSat(ACC0 - ((FB_A0 * FB_ALPHA) >> 15)));
   WR_RVB(MIX_DEST_A1, ReverbSat(ACC1 - ((FB_A1 * FB_ALPHA) >> 15)));

   WR_RVB(MIX_DEST_B0, ReverbSat(((FB_ALPHA * ACC0) >> 15) - ((FB_A0 * (int16)(0x8000 ^ FB_ALPHA)) >> 15) - ((FB_B0 * FB_X) >> 15)));
   WR_RVB(MIX_DEST_B1, ReverbSat(((FB_ALPHA * ACC1) >> 15) - ((FB_A1 * (int16)(0x8000 ^ FB_ALPHA)) >> 15) - ((FB_B1 * FB_X) >> 15)));
  }

  // 
  // Get output samples
  //
  RUSB[0][(RvbResPos >> 1) | 0x20] = RUSB[0][RvbResPos >> 1] = (RD_RVB(MIX_DEST_A0) + RD_RVB(MIX_DEST_B0)) >> 1;
  RUSB[1][(RvbResPos >> 1) | 0x20] = RUSB[1][RvbResPos >> 1] = (RD_RVB(MIX_DEST_A1) + RD_RVB(MIX_DEST_B1)) >> 1;

  ReverbCur = (ReverbCur + 1) & 0x3FFFF;
  if(!ReverbCur)
   ReverbCur = ReverbWA;

  for(unsigned lr = 0; lr < 2; lr++)
   upsampled[lr] = Reverb2244<true>(&RUSB[lr][((RvbResPos - 39) & 0x3F) >> 1]);
 }
 else
 {
  for(unsigned lr = 0; lr < 2; lr++)
   upsampled[lr] = Reverb2244<false>(&RUSB[lr][((RvbResPos - 39) & 0x3F) >> 1]);
 }

 RvbResPos = (RvbResPos + 1) & 0x3F;

 for(unsigned lr = 0; lr < 2; lr++)
  out[lr] = upsampled[lr];
}

