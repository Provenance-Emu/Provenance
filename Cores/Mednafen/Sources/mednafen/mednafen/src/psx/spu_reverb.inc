/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* spu_reverb.inc:
**  Copyright (C) 2011-2020 Mednafen Team
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

static INLINE int16 ReverbNeg(int16 samp)
{
 if(samp == -32768)
  return 0x7FFF;

 return -samp;
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
 if(SPUControl & 0x80)
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
   downsampled[lr] = Reverb4422(&RDSB[lr][(RvbResPos - 38) & 0x3F]);

  //
  // Run algorithm
  //
  for(unsigned lr = 0; lr < 2; lr++)
  {
   const int16 IIR_INPUT_A = ReverbSat((((RD_RVB(IIR_SRC_A[lr ^ 0]) * IIR_COEF) >> 14) + ((downsampled[lr] * IN_COEF[lr]) >> 14)) >> 1);
   const int16 IIR_INPUT_B = ReverbSat((((RD_RVB(IIR_SRC_B[lr ^ 1]) * IIR_COEF) >> 14) + ((downsampled[lr] * IN_COEF[lr]) >> 14)) >> 1);
   const int16 IIR_A = ReverbSat((((IIR_INPUT_A * IIR_ALPHA) >> 14) + (IIASM(IIR_ALPHA, RD_RVB(IIR_DEST_A[lr], -1)) >> 14)) >> 1);
   const int16 IIR_B = ReverbSat((((IIR_INPUT_B * IIR_ALPHA) >> 14) + (IIASM(IIR_ALPHA, RD_RVB(IIR_DEST_B[lr], -1)) >> 14)) >> 1);

   WR_RVB(IIR_DEST_A[lr], IIR_A);
   WR_RVB(IIR_DEST_B[lr], IIR_B);

   const int32 ACC = ((RD_RVB(ACC_SRC_A[lr]) * ACC_COEF_A) >> 14) +
		     ((RD_RVB(ACC_SRC_B[lr]) * ACC_COEF_B) >> 14) +
		     ((RD_RVB(ACC_SRC_C[lr]) * ACC_COEF_C) >> 14) +
		     ((RD_RVB(ACC_SRC_D[lr]) * ACC_COEF_D) >> 14);

   const int16 FB_A = RD_RVB(MIX_DEST_A[lr] - FB_SRC_A);
   const int16 FB_B = RD_RVB(MIX_DEST_B[lr] - FB_SRC_B);
   const int16 MDA = ReverbSat((ACC + ((FB_A * ReverbNeg(FB_ALPHA)) >> 14)) >> 1);
   const int16 MDB = ReverbSat(FB_A + ((((MDA * FB_ALPHA) >> 14) + ((FB_B * ReverbNeg(FB_X)) >> 14)) >> 1));
   const int16 IVB = ReverbSat(FB_B + ((MDB * FB_X) >> 15));

   WR_RVB(MIX_DEST_A[lr], MDA);
   WR_RVB(MIX_DEST_B[lr], MDB);
#if 0
   {
    static uint32 sqcounter;
    RUSB[lr][(RvbResPos >> 1) | 0x20] = RUSB[lr][RvbResPos >> 1] = ((sqcounter & 0xFF) == 0) ? 0x8000 : 0x0000; //((sqcounter & 0x80) ? 0x7000 : 0x9000);
    sqcounter += lr;
   }
#else
   RUSB[lr][(RvbResPos >> 1) | 0x20] = RUSB[lr][RvbResPos >> 1] = IVB;	// Output sample
#endif
  }
  //
  //
  //
  ReverbCur = (ReverbCur + 1) & 0x3FFFF;
  if(!ReverbCur)
   ReverbCur = ReverbWA;

  for(unsigned lr = 0; lr < 2; lr++)
   upsampled[lr] = Reverb2244<false>(&RUSB[lr][((RvbResPos >> 1) - 19) & 0x1F]);
 }
 else
 {
  for(unsigned lr = 0; lr < 2; lr++)
   upsampled[lr] = Reverb2244<true>(&RUSB[lr][((RvbResPos >> 1) - 19) & 0x1F]);
 }

 RvbResPos = (RvbResPos + 1) & 0x3F;

 for(unsigned lr = 0; lr < 2; lr++)
 {
#if 0
  if(!lr)
   printf("%d\n", (-upsampled[lr]) >> 1);
#endif

  out[lr] = upsampled[lr];
 }
}

