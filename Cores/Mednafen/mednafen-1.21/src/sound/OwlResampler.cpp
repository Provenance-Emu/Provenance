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

// Don't pass more than about 40ms worth of audio data to Resample()
// at a time.

#include <mednafen/mednafen.h>
#include <mednafen/state.h>
#include "OwlResampler.h"
#include "../cputest/cputest.h"

#if defined(ARCH_POWERPC_ALTIVEC) && defined(HAVE_ALTIVEC_H)
 #include <altivec.h>
#endif

#ifdef __ARM_NEON__
 #include <arm_neon.h>
#endif

#ifdef __FAST_MATH__
 #error "OwlResampler.cpp not compatible with unsafe math optimizations!"
#endif

OwlBuffer::OwlBuffer()
{
 assert(sizeof(I32_F_Pudding) == 4);
 assert(sizeof(float) == 4);

 memset(HRBuf, 0, sizeof(HRBuf));

 accum = 0;
 filter_state[0] = 0;
 filter_state[1] = 0;

 leftover = 0;

 InputIndex = 0;
 InputPhase = 0;

 debias = 0;
}


OwlBuffer::~OwlBuffer()
{



}

void OwlBuffer::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix, const unsigned scount)
{
 unsigned InBuf = scount;

 SFORMAT StateRegs[] =
 {
  SFVAR(accum),
  SFVAR(leftover),

  SFVAR(filter_state),

  SFVAR(InputIndex),

  SFVAR(InputPhase),

  SFVAR(debias),

  SFVAR(InBuf),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, sname_prefix);

 if(load)
 {
  if(leftover < 0)
   leftover = 0;

  if(leftover > HRBUF_LEFTOVER_PADDING)
   leftover = HRBUF_LEFTOVER_PADDING;

  if(InBuf > 65536)
   InBuf = 65536;
 }

 char lod_sname[256];
 snprintf(lod_sname, sizeof(lod_sname), "%s_LOD", sname_prefix);

 SFORMAT StateRegs_LOD[] =
 {
  SFPTR32(Buf() - leftover, leftover + InBuf + HRBUF_OVERFLOW_PADDING),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs_LOD, lod_sname);
}

template<unsigned DoExMix, bool Integrate, unsigned IntegrateShift, bool Lowpass, bool Highpass, bool FloatOutput>
static int32 ProcessLoop(unsigned count, int32 a, int32* b, int32* exmix0 = NULL, int32* exmix1 = NULL, unsigned lp_shift = 0, unsigned hp_shift = 0, int64* f_in = NULL)
{
 int64 lp_f;
 int64 hp_f;

 if(Lowpass)
 {
  lp_f = f_in[0];
 }

 if(Highpass)
 {
  hp_f = f_in[1];
 }

 while(count--)
 {
  int32 tmp;

  if(Integrate)
  {
   a += *b;
   tmp = a >> IntegrateShift;
  }
  else
   tmp = *b;

  if(Lowpass)
  {
   lp_f += ((int64)((uint64)(int64)tmp << 16) - lp_f) >> lp_shift;
   tmp = lp_f >> 16;
  }

  if(Highpass)
  {
   hp_f += ((int64)((uint64)(int64)tmp << 16) - hp_f) >> hp_shift;
   tmp = tmp - (hp_f >> 16);
  }

  if(DoExMix >= 1)
  {
   tmp += *exmix0;
   exmix0++;
  }

  if(DoExMix >= 2)
  {
   tmp += *exmix1;
   exmix1++;
  }

  if(FloatOutput)
   *(float*)b = tmp;
  else
   *b = tmp;

  b++;
 }

 if(Lowpass)
  f_in[0] = lp_f;

 if(Highpass)
  f_in[1] = hp_f;

 return(a);
}

void OwlBuffer::ResampleSkipped(unsigned count)
{
 memmove(HRBuf, &HRBuf[count], HRBUF_OVERFLOW_PADDING * sizeof(HRBuf[0]));
 memset(&HRBuf[HRBUF_OVERFLOW_PADDING], 0, count * sizeof(HRBuf[0]));
}

void OwlBuffer::Integrate(unsigned count, unsigned lp_shift, unsigned hp_shift, RavenBuffer* mixin0, RavenBuffer* mixin1)
{
 //lp_shift = hp_shift = 0;
 if(lp_shift != 0 || hp_shift != 0)
 {
  if(mixin0 && mixin1)
   accum = ProcessLoop<2, true, 3, true, true, true>(count, accum, Buf(), mixin0->Buf(), mixin1->Buf(),	lp_shift, hp_shift, filter_state);
  else if(mixin0)
   accum = ProcessLoop<1, true, 3, true, true, true>(count, accum, Buf(), mixin0->Buf(), NULL,		lp_shift, hp_shift, filter_state);
  else
   accum = ProcessLoop<0, true, 3, true, true, true>(count, accum, Buf(), NULL, 	 NULL,		lp_shift, hp_shift, filter_state);
 }
 else
 {
  if(mixin0 && mixin1)
   accum = ProcessLoop<2, true, 3, false, false, true>(count, accum, Buf(), mixin0->Buf(), mixin1->Buf());
  else if(mixin0)
   accum = ProcessLoop<1, true, 3, false, false, true>(count, accum, Buf(), mixin0->Buf());
  else
   accum = ProcessLoop<0, true, 3, false, false, true>(count, accum, Buf());
 }

 if(accum >= 32767 * 256 * 8 || accum <= -32767 * 256 * 8)
 {
  //printf("Possible delta sample loss; accum=%d\n", accum);
 }
}

//
//
//

RavenBuffer::RavenBuffer()
{
 memset(BB, 0, sizeof(BB));

 accum = 0;

 filter_state[0] = 0;
 filter_state[1] = 0;
}


RavenBuffer::~RavenBuffer()
{



}



void RavenBuffer::Process(unsigned count, bool integrate, unsigned lp_shift)
{
 if(integrate)
 {
  if(lp_shift != 0)
   accum = ProcessLoop<0, true, 3, true,  false, false>(count, accum, Buf(), NULL, NULL, lp_shift, 0, filter_state);
  else
   accum = ProcessLoop<0, true, 3, false, false, false>(count, accum, Buf(), NULL, NULL, lp_shift, 0);
 }
 else
 {
  if(lp_shift != 0)
   accum = ProcessLoop<0, false, 0, true,  false, false>(count, accum, Buf(), NULL, NULL, lp_shift, 0, filter_state);
  else
   accum = ProcessLoop<0, false, 0, false, false, false>(count, accum, Buf(), NULL, NULL, lp_shift, 0);
 }
}

void RavenBuffer::Finish(unsigned count)
{
 memmove(BB, &BB[count], OwlBuffer::HRBUF_OVERFLOW_PADDING * sizeof(BB[0]));
 memset(&BB[OwlBuffer::HRBUF_OVERFLOW_PADDING], 0, count * sizeof(BB[0]));
}



static void kaiser_window( double* io, int count, double beta )
{
        int const accuracy = 16; //12;

        double* end = io + count;

        double beta2    = beta * beta * (double) -0.25;
        double to_fract = beta2 / ((double) count * count);
        double i        = 0;
        double rescale = 0; // Doesn't need an initializer, to shut up gcc

        for ( ; io < end; ++io, i += 1 )
        {
                double x = i * i * to_fract - beta2;
                double u = x;
                double k = x + 1;

                double n = 2;
                do
                {
                        u *= x / (n * n);
                        n += 1;
                        k += u;
                }
                while ( k <= u * (1 << accuracy) );

                if ( !i )
                        rescale = 1 / k; // otherwise values get large

                *io *= k * rescale;
        }
}

static void gen_sinc( double* out, int size, double cutoff, double kaiser )
{
	assert( size % 2 == 0 ); // size must be enev
 
	int const half_size = size / 2;
	double* const mid = &out [half_size];
 
	// Generate right half of sinc
	for ( int i = 0; i < half_size; i++ )
	{
		double angle = (i * 2 + 1) * (M_PI / 2);
		mid [i] = sin( angle * cutoff ) / angle;
	}
 
	kaiser_window( mid, half_size, kaiser );
 
	// Mirror for left half
	for ( int i = 0; i < half_size; i++ )
		out [i] = mid [half_size - 1 - i];
}
 
static void normalize( double* io, int size, double gain = 1.0 )
{
	double sum = 0;
	for ( int i = 0; i < size; i++ )
		sum += io [i];

	double scale = gain / sum;
	for ( int i = 0; i < size; i++ )
		io [i] *= scale;
}


static INLINE void DoMAC(float *wave, float *coeffs, int32 count, int32 *accum_output)
{
 float acc[4] = { 0, 0, 0, 0 };

 for(int c = 0; MDFN_LIKELY(c < count); c += 4)
 {
  acc[0] += wave[c + 0] * coeffs[c + 0];
  acc[1] += wave[c + 1] * coeffs[c + 1];
  acc[2] += wave[c + 2] * coeffs[c + 2];
  acc[3] += wave[c + 3] * coeffs[c + 3];
 }

 *accum_output = (acc[0] + acc[2]) + (acc[1] + acc[3]);
}



#ifdef ARCH_X86
 #include "OwlResampler_x86.inc"
#endif

#ifdef ARCH_POWERPC_ALTIVEC
 #include "OwlResampler_altivec.inc"
#endif

#ifdef __ARM_NEON__
 #include "OwlResampler_neon.inc"
#endif


template<typename T, unsigned sa>
static T SDP2(T v)
{
 T tmp;

 tmp = (v >> ((sizeof(T) * 8) - 1)) & (((T)1 << sa) - 1);
 
 return ((v + tmp) >> sa);
}

enum
{
 SIMD_NONE = 0,

#ifdef ARCH_X86
 SIMD_SSE_16X,

#ifdef HAVE_INLINEASM_AVX
 SIMD_AVX_32X,
 SIMD_AVX_32X_P16,
#else
 #warning "Compiling without AVX inline assembly."
#endif
#elif defined(ARCH_POWERPC_ALTIVEC)
 SIMD_ALTIVEC,
#elif defined __ARM_NEON__
 SIMD_NEON
#endif
};

template<unsigned TA_SIMD_Type>
NO_INLINE int32 OwlResampler::T_Resample(OwlBuffer* in, const uint32 in_count, int16* out, const uint32 max_out_count, const bool reverse)
{
	if(reverse)
	{
	 int32* a = in->Buf();
	 int32* b = in->Buf() + in_count - 1;

	 while(MDFN_LIKELY(a < b))
	 {
	  std::swap<int32>(*a, *b);
	  a++;
	  b--;
	 }
	}

	//
	//
	//
	uint32 count = 0;
	int32* I32Out = &IntermediateBuffer[0];
	const uint32 in_count_WLO = in->leftover + in_count;
	const uint32 max = std::max<int64>(0, (int64)in_count_WLO - NumCoeffs);
        uint32 InputPhase = in->InputPhase;
        uint32 InputIndex = in->InputIndex;
	OwlBuffer::I32_F_Pudding* InSamps = in->BufPudding() - in->leftover;
	int32 leftover;

	if(MDFN_UNLIKELY(InputPhase >= NumPhases))
	{
	 fprintf(stderr, "[BUG] InputPhase >= NumPhases\n");	// Save states can also trigger this.
	 InputPhase = 0;
	}

        while(InputIndex < max)
        {
         float* wave = &InSamps[InputIndex].f;
         float* coeffs = &PInfos[InputPhase].Coeffs[0];
         int32 coeff_count = NumCoeffs;

	 switch(TA_SIMD_Type)
  	 {
	  default:
	  case SIMD_NONE:
		DoMAC(wave, coeffs, coeff_count, I32Out);
		break;

#ifdef ARCH_X86
	  case SIMD_SSE_16X:
		DoMAC_SSE_16X(wave, coeffs, coeff_count, I32Out);
		break;
#ifdef HAVE_INLINEASM_AVX
	  case SIMD_AVX_32X:
		DoMAC_AVX_32X(wave, coeffs, coeff_count, I32Out);
		break;

	  case SIMD_AVX_32X_P16:
		DoMAC_AVX_32X_P16(wave, coeffs, coeff_count, I32Out);
		break;
#endif

#elif defined(ARCH_POWERPC_ALTIVEC)
	  case SIMD_ALTIVEC:
		DoMAC_AltiVec(wave, coeffs, coeff_count, I32Out);
		break;
#elif defined __ARM_NEON__
	  case SIMD_NEON:
		DoMAC_NEON(wave, coeffs, coeff_count, I32Out);
		break;
#endif
	 }

         I32Out++;
         count++;

         InputPhase = PInfos[InputPhase].Next;
         InputIndex += PInfos[InputPhase].Step;
        }

#if defined(ARCH_X86) && defined(HAVE_INLINEASM_AVX)
	if(TA_SIMD_Type == SIMD_AVX_32X || TA_SIMD_Type == SIMD_AVX_32X_P16)
	{
	 asm volatile("vzeroupper\n\t" : : :
	 #if defined(__AVX__)
	 "ymm0", "ymm1", "ymm2", "ymm3", "ymm4", "ymm5", "ymm6", "ymm7"
	  #if defined(__x86_64__)
	  , "ymm8", "ymm9", "ymm10", "ymm11", "ymm12", "ymm13", "ymm14", "ymm15"
	  #endif
	 #endif
	 );
	}
#endif

        if(InputIndex > in_count_WLO)
	{
	 leftover = 0;
	 InputIndex -= in_count_WLO;
	}
	else
	{
	 leftover = (int32)in_count_WLO - (int32)InputIndex;
	 InputIndex = 0;
	}

#if 0
	for(uint32 x = 0; x < count; x++)
	{
 	 int s = IntermediateBuffer[x] >> 8;

	 if(s < -32768 || s > 32767)
	 {
	  //printf("Flow: %6d\n", s);
	  if(s < -32768)
	   s = -32768;
	  else if(s > 32767)
	   s = 32767;
	 }
	 out[x * 2] = s;
	}
#else
	{
	 int64 debias = in->debias;

 	 for(uint32 x = 0; x < count; x++)
	 {
 	  int32 sample = IntermediateBuffer[x];
	  int32 s;

          debias += (((int64)((uint64)(int64)sample << 16) - debias) * debias_multiplier) >> 16;
          s = SDP2<int32, 8>(sample - (debias >> 16));
	  if(s < -32768 || s > 32767)
	  {
	   //printf("Flow: %6d\n", s);
	   if(s < -32768)
	    s = -32768;
	   else if(s > 32767)
	    s = 32767;
	  }
	  out[x * 2] = s;
	 }

	 in->debias = debias;
	}
#endif
        memmove(in->Buf() - leftover,
	        in->Buf() + in_count - leftover,
		sizeof(int32) * (leftover + OwlBuffer::HRBUF_OVERFLOW_PADDING));

        memset(in->Buf() + OwlBuffer::HRBUF_OVERFLOW_PADDING, 0, sizeof(int32) * in_count);

	in->leftover = leftover;
	in->InputPhase = InputPhase;
	in->InputIndex = InputIndex;

	return count;
}

void OwlResampler::ResetBufResampState(OwlBuffer* buf)
{
 memset(buf->HRBuf, 0, sizeof(buf->HRBuf[0]) * OwlBuffer::HRBUF_LEFTOVER_PADDING);
 buf->InputPhase = 0;
}


OwlResampler::~OwlResampler()
{

}

//
// Flush denormals, and coefficients that could lead to denormals, to zero.
//
static float FilterDenormal(float v)
{
 union
 {
  float f;
  uint32 i;
 } cat_pun;

 cat_pun.f = v;

 if(((cat_pun.i >> 23) & 0xFF) <= 24)	// Maybe < 24 is more correct?
 {
  MDFN_printf("Small FP coefficient detected: 0x%08x --- raw_sign=%d, raw_exp=0x%02x, raw_mantissa=0x%06x\n", cat_pun.i, cat_pun.i >> 31, (cat_pun.i >> 23) & 0xFF, cat_pun.i & ((1U << 23) - 1));
  return(0);
 }

 return(v);
}

OwlResampler::OwlResampler(double input_rate, double output_rate, double rate_error, double debias_corner, int quality, double nyq_fudge)
{
 std::unique_ptr<double[]> FilterBuf;
 double ratio = (double)output_rate / input_rate;
 double cutoff;
 double required_bandwidth;
 double k_beta;
 double k_d;

 for(int i = 0; i < 256; i++)
 {
  int a = SDP2<int32, 3>(i);
  int b = SDP2<int32, 3>(-i);
  int c = i / (1 << 3);

  assert(a == -b && a == c);
 }

 assert(sizeof(OwlBuffer::I32_F_Pudding) == 4);

 InputRate = input_rate;
 OutputRate = output_rate;
 RateError = rate_error;
 DebiasCorner = debias_corner;
 Quality = quality;

 IntermediateBuffer.resize(OutputRate * 4 / 50);	// *4 for safety padding, / min(50,60), an approximate calculation

 const uint32 cpuext = cputest_get_flags();

 MDFN_printf("OwlResampler.cpp debug info:\n");
 MDFN_indent(1);

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

  PInfos.resize(NumPhases);

  uint32 last_indoo = 0;
  for(unsigned int i = 0; i < NumPhases; i++)
  {
   uint32 index_pos = i * findo_i / NumPhases;

   PInfos[i].Next = (i + 1) % (NumPhases);
   PInfos[i].Step = index_pos - last_indoo;
   last_indoo = index_pos;
  }
  PInfos[0].Step = findo_i - last_indoo;

  Ratio_Dividend = findo_i;
  Ratio_Divisor = NumPhases;

  MDFN_printf("Phases: %d, Output rate: %f, %d %d\n", NumPhases, input_rate * ratio, Ratio_Dividend, Ratio_Divisor);

  MDFN_printf("Desired maximum rate error: %.10f, Actual rate error: %.10f\n", rate_error, fabs((double)input_rate / output_rate * ratio - 1));
 }

 static const struct
 {
  double beta;
  double d;
  double obw;
 } QualityTable[7] =
 {
  {  5.658, 3.62,  0.65 },
  {  6.764, 4.32,  0.70 },
  {  7.865, 5.00,  0.75 },
  {  8.960, 5.70,  0.80 },
  { 10.056, 6.40,  0.85 },
  { 10.056, 6.40,  0.90 },

  { 10.056, 6.40,  0.9333 }, // 1.0 - (6.40 / 96)
 };

 assert(quality >= 0 && quality <= 6);

 k_beta = QualityTable[quality].beta;
 k_d = QualityTable[quality].d;


 //
 // As far as filter frequency response design goes, we clamp the output rate parameter
 // to keep PCE CD and PC-FX CD-DA sample amplitudes from going wild since we're not resampling CD-DA totally properly.
 //
#define OWLRESAMP_FCALC_RATE_CLAMP 128000.0 //192000.0 //96000.0 //48000.0

 // A little SOMETHING to widen the transition band a bit to reduce computational complexity with higher output rates.
 const double something = std::min<double>(OWLRESAMP_FCALC_RATE_CLAMP, (48000.0 + std::min<double>(OWLRESAMP_FCALC_RATE_CLAMP, output_rate)) / 2 / QualityTable[quality].obw);

 //
 // Note: Cutoff calculation is performed again(though slightly differently) down below after the SIMD check.
 //
 cutoff = QualityTable[quality].obw * (std::min<double>(something, std::min<double>(input_rate, output_rate)) / input_rate);

 required_bandwidth = (std::min<double>(OWLRESAMP_FCALC_RATE_CLAMP, std::min<double>(input_rate, output_rate)) / input_rate) - cutoff;

 NumCoeffs = ceil(k_d / required_bandwidth);

 MDFN_printf("Initial number of coefficients per phase: %u\n", NumCoeffs);
 MDFN_printf("Initial nominal cutoff frequency: %f\n", InputRate * cutoff / 2);

 //
 // Put this lower limit BEFORE the SIMD stuff, otherwise the NumCoeffs calculation will be off.
 //
 if(NumCoeffs < 16)
  NumCoeffs = 16;

 if(0)
 {
  abort();	// The sky is falling AAAAAAAAAAAAA
 }
 #ifdef ARCH_X86
 #ifdef HAVE_INLINEASM_AVX
 else if((cpuext & CPUTEST_FLAG_AVX) && (NumCoeffs + 0xF) >= 32)
 {
  MDFN_printf("SIMD: AVX\n");

  // AVX loop can't handle less than 32 MACs properly.
  NumCoeffs = std::max<uint32>(32, NumCoeffs);

  // Past 32 MACs, AVX loop granularity is 16 MACs(with some ugly maaaagic~)
  NumCoeffs = (NumCoeffs + 0xF) &~ 0xF;

  if(NumCoeffs & 0x10)
   Resample_ = &OwlResampler::T_Resample<SIMD_AVX_32X_P16>;
  else
   Resample_ = &OwlResampler::T_Resample<SIMD_AVX_32X>;
 }
 #endif
 else if(cpuext & CPUTEST_FLAG_SSE)
 {
  MDFN_printf("SIMD: SSE\n");

  // SSE loop does 16 MACs per iteration.
  NumCoeffs = (NumCoeffs + 0xF) &~ 0xF;
  Resample_ = &OwlResampler::T_Resample<SIMD_SSE_16X>;
 }
 #endif
 #ifdef ARCH_POWERPC_ALTIVEC
 else if(1)
 {
  MDFN_printf("SIMD: AltiVec\n");

  // AltiVec loop does 16 MACs per iteration.
  NumCoeffs = (NumCoeffs + 0xF) &~ 0xF;
  Resample_ = &OwlResampler::T_Resample<SIMD_ALTIVEC>;
 }
 #endif
 #ifdef __ARM_NEON__
 else if(1)
 {
  MDFN_printf("SIMD: NEON\n");

  // NEON loop does 16 MACs per iteration.
  NumCoeffs = (NumCoeffs + 0xF) &~ 0xF;
  Resample_ = &OwlResampler::T_Resample<SIMD_NEON>;
 }
 #endif
 else
 {
  // Default loop does 4 MACs per iteration.
  NumCoeffs = (NumCoeffs + 3) &~ 3;
  Resample_ = &OwlResampler::T_Resample<SIMD_NONE>;
 }
 //
 // Don't alter NumCoeffs anymore from here on.
 //

 #if !defined(ARCH_X86) && !defined(ARCH_POWERPC_ALTIVEC) && !defined(__ARM_NEON__)
  #warning "OwlResampler is being compiled without SIMD support."
 #endif

 //
 // Adjust cutoff now that NumCoeffs may have been increased.
 //
 cutoff = std::min<double>(QualityTable[quality].obw * something / input_rate, (std::min<double>(input_rate, output_rate) / input_rate - ((double)k_d / NumCoeffs)));

 cutoff *= nyq_fudge;
 if(ceil(cutoff) > 1.0)
  cutoff = 1.0;  


 MDFN_printf("Adjusted number of coefficients per phase: %u\n", NumCoeffs);
 MDFN_printf("Adjusted nominal cutoff frequency: %f\n", InputRate * cutoff / 2);

 assert(NumCoeffs <= OwlBuffer::HRBUF_LEFTOVER_PADDING);

 CoeffsBuffer.resize((256 / sizeof(float)) + NumCoeffs * NumPhases);

 for(unsigned int i = 0; i < NumPhases; i++)
  PInfos[i].Coeffs = (float *)(((uintptr_t)&CoeffsBuffer[0] + 0xFF) &~ 0xFF) + (i * NumCoeffs);

 MDFN_printf("Impulse response table memory usage: %zu bytes\n", CoeffsBuffer.size() * sizeof(float));

 FilterBuf.reset(new double[NumCoeffs * NumPhases]);
 gen_sinc(&FilterBuf[0], NumCoeffs * NumPhases, cutoff / NumPhases, k_beta);
 normalize(&FilterBuf[0], NumCoeffs * NumPhases); 

 #if 0
 for(int i = 0; i < NumCoeffs * NumPhases; i++)
  fprintf(stderr, "%.20f\n", FilterBuf[i]);
 #endif

 for(unsigned int phase = 0; phase < NumPhases; phase++)
 {
  //double sum_d = 0;
  //float sum_f4[4] = { 0, 0, 0, 0 };

  const unsigned sp = (NumPhases - 1 - (((uint64)phase * Ratio_Dividend) % NumPhases));
  const unsigned tp = phase;

  for(unsigned int i = 0; i < NumCoeffs; i++)
  {
   double tmpcod = FilterBuf[i * NumPhases + sp] * NumPhases;	// Tasty cod.

   PInfos[tp].Coeffs[i] = FilterDenormal(tmpcod);
   //sum_d += PInfos[tp].Coeffs[i];
   //sum_f4[i % 4] += PInfos[tp].Coeffs[i];
  }

#if 0
  {
   double sf4t = (sum_f4[0] + sum_f4[2]) + (sum_f4[1] + sum_f4[3]);
   double sd_div_sf4t = sum_d / sf4t;

   MDFN_printf("Phase %4u: sum_d=%.10f, sum_f4t=%.10f, sum_d div sum_f4t=%.10f(*65536=%f, dB=%.8f)\n", sp, sum_d, (double)sf4t, sd_div_sf4t, 65536.0 * sd_div_sf4t, fabs(20 * log10(sum_d / sf4t)));
  }
#endif
 }

 assert(debias_corner < (output_rate / 16));
 debias_multiplier = (uint32)(((uint64)1 << 16) * debias_corner / output_rate);

 MDFN_indent(-1);

 //abort();

 #if 0
 {
  static float dummy_wave[1024];
  static float dummy_coeffs[1024];
  int32 dummy_out;
  uint32 begin_time = MDFND_GetTime();

  for(int i = 0; i < 1024 * 1024; i++)
  {
   DoMAC_AVX_32X(dummy_wave, dummy_coeffs, 1024, &dummy_out);
   //DoMAC_SSE_16X(dummy_wave, dummy_coeffs, 1024, &dummy_out);
  }

  printf("%u\n", MDFND_GetTime() - begin_time);
  abort();
 }
 #endif
}
