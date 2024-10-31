/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 Input rates supported:
	Approximately 1.5MHz to 2MHz

 Output rates supported:
	22050-192000

 Cautions:
	The resampler may (dummy) read SwiftResampler::MaxWaveOverRead bytes past the end of the input sample data passed to Do().

	More than 25ms worth of samples must not be passed in any single call to Do(), or an internal buffer may overflow.

	Certain combinations of input rates and output rates may cause excessive memory usage and poor cache utilization,
	so be sure to at least test with common output rates(e.g. 22050, 32000, 44100, 48000, 64000, 96000, 192000).

	Try not to use more than 95% of the 16-bit input sample range, as certain pathological patterns of samples may cause overflow
	in the internal MAC loops.

	Try to keep the volume set with SetVolume() low enough that if it were applied to the input samples, they would
	remain below 75% of the 16-bit input sample range.

	Avoid using the internal volume control and highpass filter functionality if input samples are expected
	to regularly exceed 75% of the 16-bit input sample range.
*/

#include <mednafen/mednafen.h>
#include "DSPUtility.h"
#include "SwiftResampler.h"
#include <mednafen/cputest/cputest.h>

#if defined(HAVE_ALTIVEC_INTRINSICS) && defined(HAVE_ALTIVEC_H)
 #include <altivec.h>
#endif

#ifdef HAVE_NEON_INTRINSICS
 #include <arm_neon.h>
#endif

#if defined(HAVE_SSE2_INTRINSICS)
 #include <xmmintrin.h>
 #include <emmintrin.h>
#endif

namespace Mednafen
{
//
//
//

#include "SwiftResampler_generic.inc"

#ifdef ARCH_X86
 #include "SwiftResampler_x86.inc"
#endif

#if defined(HAVE_SSE2_INTRINSICS)
 #include "SwiftResampler_sse2.inc"
#endif

#ifdef HAVE_ALTIVEC_INTRINSICS
 #include "SwiftResampler_altivec.inc"
#endif

#ifdef HAVE_NEON_INTRINSICS
 #include "SwiftResampler_neon.inc"
#endif


template<size_t align_mask>
INLINE uint32 SwiftResampler::ResampLoop(int16* in, int32* out, uint32 max, void (*MAC_Function)(const int16* wave, const int16* coeffs, int32 count, int32* accum_output))
{
 uint32 count = 0;

 while(InputIndex < max)
 {
  const size_t align_index = InputIndex & align_mask;
  int16* wave = &in[InputIndex &~ align_mask];
  int16* coeffs = &FIR_ENTRY(align_index, InputPhase, 0);
  int32 coeff_count = FIR_CoCounts[align_index];

  MAC_Function(wave, coeffs, coeff_count, out);

  out++;
  count++;

  InputPhase = PhaseNext[InputPhase];
  InputIndex += PhaseStep[InputPhase];
 }

 return count;
}

template<unsigned TA_SIMD_Type, unsigned TA_NumFractBits>
int32 SwiftResampler::T_Resample(int16 *in, int16 *out, uint32 maxoutlen, uint32 inlen, int32 *leftover)
{
	uint32 max;
	uint32 count;
	int32 *boobuf = &IntermediateBuffer[0];
	int32 *I32Out = boobuf;

	{
	 int64 max_temp = inlen;

	 max_temp -= NumCoeffs;

	 if(max_temp < 0) 
	 {
  	  puts("Eep");
  	  max_temp = 0;
	 }
	 max = max_temp;
	}
	//printf("%d %d\n", inlen, max);

	if(0)
	{

	}
        #ifdef ARCH_X86
	else if(TA_SIMD_Type == SIMD_SSE2)
	{
	 count = ResampLoop(in, I32Out, max, DoMAC_SSE2<TA_NumFractBits>);
	}
        else if(TA_SIMD_Type == SIMD_MMX)
        {
	 //
	 // FIXME: doing emms in a separate inline asm block below the while() loop isn't guaranteed safe...
	 //
	 asm volatile("" ::: "memory");
	 count = ResampLoop<0x3>(in, I32Out, max, DoMAC_MMX<TA_NumFractBits>);
	 asm volatile("emms\n\t" ::: "memory");
	}
	#endif
	#if defined(HAVE_SSE2_INTRINSICS)
	else if(TA_SIMD_Type == SIMD_SSE2_INTRIN)
	{
	 count = ResampLoop(in, I32Out, max, DoMAC_SSE2_Intrin<TA_NumFractBits>);
	}
	#endif
	#ifdef HAVE_ALTIVEC_INTRINSICS
        else if(TA_SIMD_Type == SIMD_ALTIVEC)
	{
	 count = ResampLoop<0x7>(in, I32Out, max, DoMAC_AltiVec<TA_NumFractBits>);
	}
	#endif
	#ifdef HAVE_NEON_INTRINSICS
	else if(TA_SIMD_Type == SIMD_NEON)
	{
	 count = ResampLoop(in, I32Out, max, DoMAC_NEON<TA_NumFractBits>);
	}
	#endif
	else
	{
	 count = ResampLoop(in, I32Out, max, DoMAC<TA_NumFractBits>);
	}

        *leftover = inlen - InputIndex;

	InputIndex = 0;

	if(*leftover < 0) 
	{
	 //printf("Oops: %d\n", *leftover);
         InputIndex = (0 - *leftover);
	 *leftover = 0;
	}

	if(!debias_multiplier)
	{
         if(SoundVolume == 256)
 	 {
          for(uint32 x = 0; x < count; x++)
           out[x] = boobuf[x];
	 }
	 else
	 {
          for(uint32 x = 0; x < count; x++)
	   out[x] = (boobuf[x] * SoundVolume) >> 8;
	 }
	}
	else
	{
	 for(uint32 x = 0; x < count; x++)
	 {
	  int32 sample = boobuf[x];
          debias += ((int64)((int32)((uint32)sample << 16) - debias) * debias_multiplier) >> 32;
	  out[x] = ((sample - (debias >> 16)) * SoundVolume) >> 8;
	 }
	}

	return count;
}

SwiftResampler::~SwiftResampler()
{

}

void SwiftResampler::SetVolume(double newvolume)
{
 SoundVolume = (int32)(newvolume * 256);
}

SwiftResampler::SwiftResampler(double input_rate, double output_rate, double rate_error, double hp_tc, int quality)
{
 //
 // Don't set NumFractBits higher than 19, or lower than 15.
 //
 const unsigned NumFractBits = 19;
 double ratio = (double)output_rate / input_rate;
 double cutoff;
 double required_bandwidth;
 double k_beta;
 double k_d;

 SetVolume(1.0);

 InputRate = input_rate;
 OutputRate = output_rate;
 RateError = rate_error;
 Quality = quality;

 IntermediateBuffer.resize(OutputRate * 4 / 50);	// *4 for safety padding, / min(50,60), an approximate calculation

 const uint32 cpuext = cputest_get_flags();

 MDFN_printf("SwiftResampler.cpp debug info:\n");
 MDFN_indent(1);

 if(quality == -2)
 {
  k_beta = 4.538;
  k_d = 2.93;
  NumCoeffs = 192;
 }
 else if(quality == -1)
 {
  k_beta = 4.538;
  k_d = 2.93;
  NumCoeffs = 256;
 }
 else if(quality == 0)
 {
  k_beta = 5.658;
  k_d = 3.62;
  NumCoeffs = 352;
 }
 else if(quality == 1)
 {
  k_beta = 7.865;
  k_d = 5.0;
  NumCoeffs = 512;
 }
 else if(quality == 2)
 {
  k_beta = 8.960;
  k_d = 5.7;
  NumCoeffs = 768;
 }
 else if(quality == 3)
 {
  k_beta = 10.056;
  k_d = 6.4;
  NumCoeffs = 1024;
 }
 else
 {
  MDFN_indent(-1);
  throw(-1);
 }

 unsigned macperiter; // Must be power of 2.

 if(0)
 {
  abort();
 }
 #if defined(ARCH_X86)
 else if((cpuext & (CPUTEST_FLAG_SSE2 | CPUTEST_FLAG_SSE2SLOW)) == CPUTEST_FLAG_SSE2 && (cpuext & (CPUTEST_FLAG_3DNOW | CPUTEST_FLAG_ATOM | CPUTEST_FLAG_AVX | CPUTEST_FLAG_SSE42)))
 {
  Resample_ = &SwiftResampler::T_Resample<SIMD_SSE2, NumFractBits>;
  SIMDTypeString = "SSE2 (assembly)";
  NumAlignments = 1;
  macperiter = 32;
  assert(16 <= MaxWaveOverRead);
 }
 else if(cpuext & CPUTEST_FLAG_MMX)
 {
  Resample_ = &SwiftResampler::T_Resample<SIMD_MMX, NumFractBits>;
  SIMDTypeString = "MMX (assembly)";
  NumAlignments = 4;
  macperiter = 16;
 }
 #endif
 #if defined(HAVE_SSE2_INTRINSICS)
 else if(cpuext & (CPUTEST_FLAG_SSE2 | CPUTEST_FLAG_SSE2SLOW))
 {
  Resample_ = &SwiftResampler::T_Resample<SIMD_SSE2_INTRIN, NumFractBits>;
  SIMDTypeString = "SSE2 (intrinsics)";
  NumAlignments = 1;
  macperiter = 16;
  assert(16 <= MaxWaveOverRead);
 }
 #endif
 #if defined(HAVE_ALTIVEC_INTRINSICS)
 else if(cpuext & CPUTEST_FLAG_ALTIVEC)
 {
  Resample_ = &SwiftResampler::T_Resample<SIMD_ALTIVEC, NumFractBits>;
  SIMDTypeString = "AltiVec";
  NumAlignments = 8;
  macperiter = 16;
 }
 #endif
 #if defined(HAVE_NEON_INTRINSICS)
 else if(1)
 {
  Resample_ = &SwiftResampler::T_Resample<SIMD_NEON, NumFractBits>;
  SIMDTypeString = "NEON";
  NumAlignments = 1;
  //macperiter = 32;
  //assert(16 <= MaxWaveOverRead);
  macperiter = 16;
  assert(8 <= MaxWaveOverRead);
 } 
 #endif
 else
 {
  Resample_ = &SwiftResampler::T_Resample<SIMD_NONE, NumFractBits>;
  SIMDTypeString = "None";
  NumAlignments = 1;
  macperiter = 8;
 }

 MDFN_printf("SIMD: %s\n", SIMDTypeString);

 NumCoeffs = (NumCoeffs + (macperiter - 1)) &~ (macperiter - 1);
 NumCoeffs_Padded = (NumCoeffs + (NumAlignments - 1) + (macperiter - 1)) &~ (macperiter - 1);

 assert(NumCoeffs <= MaxLeftover);

 #if !defined(ARCH_X86) && !defined(HAVE_SSE2_INTRINSICS) && !defined(HAVE_ALTIVEC_INTRINSICS) && !defined(HAVE_NEON_INTRINSICS)
  #warning "SwiftResampler is being compiled without SIMD support."
 #endif

 //printf("%d, %d\n", NumCoeffs, NumCoeffs_Padded);

 required_bandwidth = k_d / NumCoeffs;

 MDFN_printf("%f\n", required_bandwidth);	

 // Get the number of phases required, and adjust ratio.
 {
  double s_ratio = (double)input_rate / output_rate;
  double findo = 0;
  uint32 count = 0;
  uint32 findo_i;

  do
  {
   count++;
   findo += s_ratio;
  } while( fabs(1.0 - ((floor(0.5 + findo) / count) / s_ratio)) > rate_error);

  s_ratio = floor(0.5 + findo) / count;
  findo_i = (uint32) floor(0.5 + findo);
  ratio = 1 / s_ratio;
  NumPhases = count;

  PhaseNext.reset(new uint32[NumPhases]);
  PhaseStep.reset(new uint32[NumPhases]);

  uint32 last_indoo = 0;
  for(unsigned int i = 0; i < NumPhases; i++)
  {
   uint32 index_pos = i * findo_i / NumPhases;

   PhaseNext[i] = (i + 1) % (NumPhases);
   PhaseStep[i] = index_pos - last_indoo;
   last_indoo = index_pos;
  }
  PhaseStep[0] = findo_i - last_indoo;

  Ratio_Dividend = findo_i;
  Ratio_Divisor = NumPhases;

  MDFN_printf("Phases: %d, Output rate: %f, %d %d\n", NumPhases, input_rate * ratio, Ratio_Dividend, Ratio_Divisor);

  MDFN_printf("Desired rate error: %.10f, Actual rate error: %.10f\n", rate_error, fabs((double)input_rate / output_rate * ratio - 1));
 }

 // Optimize cutoff for maximum sound frequencies humans can perceive, keep individual coefficient values from
 // becoming too large, and keep dogs from freaking out with some games that "silence"
 // sounds by making their fundamental frequencies beyond the range of typical human hearing.
 //
 // (For when output playback rate is considerably higher than 48KHz)
 //
 // This also incidentally handles the case of UPSAMPLING to a higher rate(at least when upsampling from the NES
 // CPU frequency), so if this code is removed/disabled, code to handle that case will need to be added.
 {
  double cutoff_robot = (ratio - required_bandwidth) / NumPhases;
  double cutoff_human = ((24000 * 2) / input_rate) / NumPhases; // Not subtracting required_bandwidth here is intentional.

  if(cutoff_human < cutoff_robot)
  {
   //puts("HUMANS WIN THIS ROUND");
   cutoff = cutoff_human;
  }
  else
   cutoff = cutoff_robot;
 }

 MDFN_printf("Cutoff: %f, %f\n", cutoff, required_bandwidth);

 if(cutoff <= 0)
 {
  MDFN_printf("Cutoff frequency is <= 0: %f\n", cutoff);
 }

 FIR_Coeffs.reset(new int16*[NumAlignments * NumPhases]);

 CoeffsBuffer.resize((256 / sizeof(int16)) + NumCoeffs_Padded * (NumAlignments * NumPhases));

 for(unsigned int i = 0; i < NumAlignments * NumPhases; i++)
  FIR_Coeffs[i] = (int16*)(((uintptr_t)&CoeffsBuffer[0] + 0xFF) &~ 0xFF) + (i * NumCoeffs_Padded);

 MDFN_printf("FIR table memory usage: %zu bytes\n", CoeffsBuffer.size() * sizeof(int16));
 //
 //
 //
 std::unique_ptr<double[]> FilterBuf(new double[NumCoeffs * NumPhases]);
 std::unique_ptr<std::pair<unsigned, int>[]> SortBuf(new std::pair<unsigned, int>[NumCoeffs]);

 DSPUtility::generate_kaiser_sinc_lp(FilterBuf.get(), NumCoeffs * NumPhases, cutoff / 2.0, k_beta);
 DSPUtility::normalize(FilterBuf.get(), NumCoeffs * NumPhases);

 #if 0
 for(int i = 0; i < NumCoeffs * NumPhases; i++)
  fprintf(stderr, "%.20f\n", FilterBuf[i]);
 #endif

 FIR_CoCounts.reset(new uint32[NumAlignments]);
 FIR_CoCounts[0] = NumCoeffs;

 for(unsigned int phase = 0; phase < NumPhases; phase++)
 {
  const unsigned sp = (NumPhases - 1 - (((uint64)phase * Ratio_Dividend) % NumPhases));
  const unsigned tp = phase;

  //
  //
  {
   double sum_error = 0;
   double sum_d = 0;
   int32 sum_i = 0;
   for(unsigned i = 0; i < NumCoeffs; i++)
   {
    double c = FilterBuf[i * NumPhases + sp] * (1 << NumFractBits) * NumPhases;
    int32 ci = (int32)floor(0.5 + c);

    assert(ci >= -32768 && ci <= 32767);

    sum_i += ci;
    sum_d += c;
    FIR_ENTRY(0, tp, i) = (int16)ci;
    SortBuf[i] = { i, (int16)ci };
   }
#if 1
   std::sort(&SortBuf[0], &SortBuf[NumCoeffs], [](const std::pair<unsigned, int>& a, const std::pair<unsigned, int>& b) { return abs(a.second) > abs(b.second); });

   sum_error = std::min<double>(1 << NumFractBits, sum_d) - sum_i;
   for(double threshold = 0.50 + 1.0 / 16; sum_error; threshold += 1.0 / 16)
   {
    //printf("threshold: %f\n", threshold);
    for(unsigned i = 0; i < NumCoeffs; i++)
    {
     const size_t idx = SortBuf[i].first;
     const double c = FilterBuf[idx * NumPhases + sp] * (1 << NumFractBits) * NumPhases;
     int32 eadj = 0;

     if(sum_error >= 0.75)
      eadj = 1;
     else if(sum_error <= -0.75)
      eadj = -1;
     else
     {
      sum_error = 0;
      break;
     }

     int32 s = FIR_ENTRY(0, tp, idx) + eadj;

     if(fabs(s - c) < threshold && s >= -32768 && s < 32767)
     {
      FIR_ENTRY(0, tp, idx) = s;
      sum_error -= eadj;
     }
    } 
   }
   //printf("%f, %d, %f\n", sum_d, sum_i, sum_error);
#endif
  }
  //
  //
  //
  {
   int32 neg_sum = 0;
   int32 pos_sum = 0;
   int32 sum = 0;
   int32 sum_absv = 0;
   int32 sum_absv8[8] = { 0 };
   int32 sum_absv8_alt[2][8] = { { 0 } };
   int32 sum_absv16[16] = { 0 };
   int32 max = 0, min = 0;

   //printf("amp_mult: %f\n", amp_mult);
   for(unsigned int i = 0; i < NumCoeffs; i++)
   {
    const int32 tmpco = FIR_ENTRY(0, tp, i);

    sum += tmpco;
    sum_absv += abs(tmpco);
    sum_absv8[i & 0x7] += abs(tmpco);
    sum_absv8_alt[i >= (NumCoeffs >> 1)][i & 0x7] += abs(tmpco);
    sum_absv16[i & 0xF] += abs(tmpco);

    if(tmpco > max)
     max = tmpco;

    if(tmpco < min)
     min = tmpco;

    if(tmpco > 0)
     pos_sum += tmpco;
    else
     neg_sum += tmpco;
   }

   double wcru = 0;

   for(int i = 0; i < 8; i++)
   {
    double tmp_wcru = (-32768.0 * sum_absv8[i] / 2) / -2147483648.0;

    if(tmp_wcru > wcru)
     wcru = tmp_wcru;
   }

   for(int a = 0; a < 2; a++)
   {
    for(int i = 0; i < 8; i++)
    {
     double tmp_wcru = (-32768.0 * sum_absv8_alt[a][i]) / -2147483648.0;

     if(tmp_wcru > wcru)
      wcru = tmp_wcru;
    }
   }

   for(int i = 0; i < 16; i++)
   {
    double tmp_wcru = (-32768.0 * sum_absv16[i]) / -2147483648.0;

    if(tmp_wcru > wcru)
     wcru = tmp_wcru;
   }

   //
   // If wcru > 1.0, it indicates that the MAC loop(s) may suffer from integer overflows.
   // though as long as it's < 1.05, it shouldn't cause problems(at least not with the NES sound emulation code this resampler is currently paired with).
   //
   MDFN_printf("Phase %d: min=%d max=%d, neg_sum=%d, pos_sum=%d, sum=%d, sum_absv=%d, wcru=%.4f\n", phase, min, max, neg_sum, pos_sum, sum, sum_absv, wcru);
  }
 }

 for(unsigned int ali = 1; ali < NumAlignments; ali++)
 {
  for(unsigned int phase = 0; phase < NumPhases; phase++)
  {
   FIR_CoCounts[ali] = NumCoeffs + ali;
   for(unsigned int i = 0; i < NumCoeffs; i++)
   {
    FIR_ENTRY(ali, phase, i + ali) = FIR_ENTRY(0, phase, i);
   }
  }
 }

 InputIndex = 0;
 InputPhase = 0;

 debias = 0;

 if(hp_tc > 0)
 {
  double tdm = (pow(2.0 - pow(M_E, -1.0), 1.0 / (hp_tc * output_rate)) - 1.0);

  //printf("%f\n", tdm);
  assert(tdm >= 0.0 && tdm <= 0.4);

  debias_multiplier = ((int64)1 << 32) * tdm;
  assert(debias_multiplier >= 0);
  //printf("%d\n", debias_multiplier);
 }
 else
  debias_multiplier = 0;

 MDFN_indent(-1);
 //
 //
 //
#if 0
 fprintf(stderr, " { ");

 for(unsigned phase = 0; phase < NumPhases; phase++)
 {
  fprintf(stderr, "%u, ", PhaseStep[phase]);
 }
 fprintf(stderr, "},\n");
 fprintf(stderr, " {{\n");
 for(unsigned phase = 0; phase < NumPhases; phase++)
 {
  fprintf(stderr, "  {");
  for(unsigned i = 0; i < NumCoeffs; i++)
  {
   fprintf(stderr, " %d, ", FIR_ENTRY(0, phase, i));
  }
  fprintf(stderr, " },\n");
 }
 fprintf(stderr, " }}\n");

#endif
}

}
