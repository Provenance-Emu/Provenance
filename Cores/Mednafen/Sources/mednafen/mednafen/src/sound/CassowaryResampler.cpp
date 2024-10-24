/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* CassowaryResampler.cpp:
**  Copyright (C) 2023 Mednafen Team
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

#include <mednafen/mednafen.h>
#include "DSPUtility.h"

#include "CassowaryResampler.h"

#define RESAMPLERMAC_FLOATOUT 1
#include "ResamplerMAC.h"

namespace Mednafen
{

void CassowaryResampler::SetOutputRate(double output_rate, bool force_recalc)
{
 if(!output_rate)
  return;
 //
 double ratio = output_rate / input_rate;

 phase_accum_inc = (uint64)floor(0.5 + (1.0 / (ratio * div[0] * div[1] * div[2])) * 4294967296.0);

 //printf("%f, %llu\n", ratio, phase_accum_inc);

 if(coeffs_halve_ratio && fabs(1.0 - ratio / coeffs_halve_ratio) < 0.01 && !force_recalc)
  return;
 //
 //
 //
 std::unique_ptr<double[]> filterbuf(new double[num_coeffs[2]]);
 double fc;


 // Check frequency response for ultrasonic source tones if increasing beyond
 // 0.20, and increase quarter*_num_coeffs if necessary.
 fc = std::min<double>(0.20, ((div[0] * div[1]) * ratio - (6.4 / num_coeffs[2] * 0.5)) / 2.0);

 //printf("%f\n", fc);

 DSPUtility::generate_kaiser_sinc_lp(filterbuf.get(), num_coeffs[2], fc, 10.056);
 DSPUtility::normalize(filterbuf.get(), num_coeffs[2], 1.0);

 for(unsigned i = 0; i < num_coeffs[2]; i++)
 {
  double v = filterbuf[i];

  if(fabs(v) < (1.0 / (1 << 20) / num_coeffs[2]))
  {
   //printf("halve %u: %.20f\n", i, v);
   v = 0;
  }

  coeffs_stage2[i] = v;
 }
 //
 coeffs_halve_ratio = ratio;
}

static INLINE uint32 ResamplePart(float* src, int32 src_count, float* dest, uint32* leftover, int32 src_inc, const float* coeffs, int num_coeffs)
{
 int32 s;
 int32 s_bound;
 float* d = dest;

 s = 0;
 s_bound = src_count - (num_coeffs - 1);

#if defined(HAVE_SSE_INTRINSICS) && defined(__x86_64__)
 if(num_coeffs == 32 && src_inc == 4)
 {
  __m128 coeffs0 = _mm_load_ps(coeffs + 16);
  __m128 coeffs1 = _mm_load_ps(coeffs + 20);
  __m128 coeffs2 = _mm_load_ps(coeffs + 24);
  __m128 coeffs3 = _mm_load_ps(coeffs + 28);
  __m128 wave0 = _mm_loadu_ps(src +  0);
  __m128 wave1 = _mm_loadu_ps(src +  4);
  __m128 wave2 = _mm_loadu_ps(src +  8);
  __m128 wave3 = _mm_loadu_ps(src + 12);
  __m128 wave4 = _mm_loadu_ps(src + 16);
  __m128 wave5 = _mm_loadu_ps(src + 20);
  __m128 wave6 = _mm_loadu_ps(src + 24);
  __m128 wave7;

  wave0 = _mm_shuffle_ps(wave0, wave0, 27);
  wave1 = _mm_shuffle_ps(wave1, wave1, 27);
  wave2 = _mm_shuffle_ps(wave2, wave2, 27);
  wave3 = _mm_shuffle_ps(wave3, wave3, 27);

  while(s < s_bound)
  {
   __m128 accum = _mm_setzero_ps();
   const float* wave = src + s;
   __m128 w;

   wave7 = _mm_loadu_ps(wave + 28);

   w = _mm_add_ps(wave3, wave4);
   w = _mm_mul_ps(w, coeffs0);
   accum = _mm_add_ps(accum, w);

   w = _mm_add_ps(wave2, wave5);
   w = _mm_mul_ps(w, coeffs1);
   accum = _mm_add_ps(accum, w);

   w = _mm_add_ps(wave1, wave6);
   w = _mm_mul_ps(w, coeffs2);
   accum = _mm_add_ps(accum, w);

   w = _mm_add_ps(wave0, wave7);
   w = _mm_mul_ps(w, coeffs3);
   accum = _mm_add_ps(accum, w);

   wave0 = wave1;
   wave1 = wave2;
   wave2 = wave3;
   wave3 = _mm_shuffle_ps(wave4, wave4, 27);
   wave4 = wave5;
   wave5 = wave6;
   wave6 = wave7;
   //
   //
   __m128 sum = accum;
   sum = _mm_add_ps(sum, _mm_shuffle_ps(sum, sum, (3 << 0) + (2 << 2) + (1 << 4) + (0 << 6)));
   sum = _mm_add_ps(sum, _mm_shuffle_ps(sum, sum, (1 << 0)));
   *d = _mm_cvtss_f32(sum);

   d++;
   s += src_inc;
  }
 }
 else
#endif
 {
  while(MDFN_LIKELY(s < s_bound))
  {
   const float* wave = src + s;

   if(0)
   {
    //
   }
#if defined(HAVE_SSE_INTRINSICS) || defined(ARCH_X86)
   else if(1)
   {
    DoMAC_SSE_16X(wave, coeffs, (num_coeffs + 0xF) &~ 0xF, d);
   }
#endif
#if defined(HAVE_NEON_INTRINSICS)
   else if(1)
   {
    DoMAC_NEON(wave, coeffs, (num_coeffs + 0xF) &~ 0xF, d);
   }
#endif
#if defined(HAVE_ALTIVEC_INTRINSICS)
   else if(1)
   {
    DoMAC_AltiVec(wave, coeffs, (num_coeffs + 0xF) &~ 0xF, d);
   }
#endif
   else
   {
    DoMAC(src + s, coeffs, num_coeffs, d);
   }

   d++;
   s += src_inc;
  }
 }

 assert(src_count >= s);

 *leftover = std::max<int32>(0, src_count - s);

 return d - dest;
}

void CassowaryResampler::ResampleStage012(float* MDFN_RESTRICT src, uint32 src_count, uint32* MDFN_RESTRICT leftover)
{
 uint32 lo = 0;

 state.buf0_offs += ResamplePart(src, src_count, state.buf0 + state.buf0_offs, &lo, div[0], coeffs_stage0, num_coeffs[0]);
 *leftover = lo;

 state.buf1_offs += ResamplePart(state.buf0, state.buf0_offs, state.buf1 + state.buf1_offs, &lo, div[1], coeffs_stage1, num_coeffs[1]);
 memmove(state.buf0, state.buf0 + state.buf0_offs - lo, lo * sizeof(double));
 state.buf0_offs = lo;

 state.buf2_offs += ResamplePart(state.buf1, state.buf1_offs, state.buf2 + state.buf2_offs, &lo, div[2], coeffs_stage2, num_coeffs[2]);
 memmove(state.buf1, state.buf1 + state.buf1_offs - lo, lo * sizeof(double));
 state.buf1_offs = lo;
}

uint32 CassowaryResampler::ResampleStage3(int16* MDFN_RESTRICT dest, uint32 dest_max)
{
#if 0
 for(uint32 i = 0; i < state.buf2_offs; i++)
  dest[i] = ((int32)state.buf2[i] + 0x80) >> 8;
 uint32 ret = state.buf2_offs;

 state.buf2_offs = 0;

 return ret;
#endif
 uint32 dest_offs = 0;

 while(((state.phase_accum >> 32) + phaseip_num_coeffs) <= state.buf2_offs)
 {
  unsigned phase_index = (uint32)state.phase_accum >> (32 - phaseip_num_phases_log2);
  float phase_ip = (state.phase_accum & ((1U << (32 - phaseip_num_phases_log2)) - 1)) * (1.0f / (1U << (32 - phaseip_num_phases_log2)));
  float accum = 0;
  const float* inbuf = state.buf2 + (state.phase_accum >> 32);
  const float* cpa = coeffs_phaseip[phase_index + 0];
  const float* cpb = coeffs_phaseip[phase_index + 1];
  //
  //
  state.phase_accum += phase_accum_inc;
  //
  //
  if(0)
  {
   //
  }
#if defined(HAVE_SSE_INTRINSICS)
  else if(1)
  {
   __m128 pip = _mm_set1_ps(phase_ip);
   __m128 accum0;

   accum0 = _mm_setzero_ps();
   for(int i = 0; i < phaseip_num_coeffs; i += 4)
   {
    __m128 coeff_a, coeff_b;
    __m128 coeff;

    coeff_a = _mm_load_ps(cpa + i);
    coeff_b = _mm_load_ps(cpb + i);
    coeff = _mm_add_ps(coeff_a, _mm_mul_ps(pip, _mm_sub_ps(coeff_b, coeff_a)));
    accum0 = _mm_add_ps(accum0, _mm_mul_ps(coeff, _mm_loadu_ps(inbuf + i)));
   }
   //
   __m128 sum = accum0;
   sum = _mm_add_ps(sum, _mm_shuffle_ps(sum, sum, (3 << 0) + (2 << 2) + (1 << 4) + (0 << 6)));
   sum = _mm_add_ps(sum, _mm_shuffle_ps(sum, sum, (1 << 0)));

   accum = _mm_cvtss_f32(sum);
  }
#endif
#if defined(HAVE_NEON_INTRINSICS)
  else if(1)
  {
   // TODO: Test
   register float32x4_t pip = vdupq_n_f32(phase_ip);
   register float32x4_t accum0;

   accum0 = vdupq_n_f32(0);
   for(int i = 0; i < phaseip_num_coeffs; i += 4)
   {
    register float32x4_t coeff_a, coeff_b;
    register float32x4_t coeff;

    coeff_a = vld1q_f32(MDFN_ASSUME_ALIGNED(cpa + i, 16));
    coeff_b = vld1q_f32(MDFN_ASSUME_ALIGNED(cpb + i, 16));
    coeff = vaddq_f32(coeff_a, vmulq_f32(pip, vsubq_f32(coeff_b, coeff_a)));
    accum0 = vmlaq_f32(accum0, coeff, vld1q_f32(inbuf + i));
   }

   register float32x4_t sum4;
   register float32x2_t sum2;

   sum4 = accum0;
   sum2 = vadd_f32(vget_high_f32(sum4), vget_low_f32(sum4));
   sum2 = vpadd_f32(sum2, sum2);

   accum = vget_lane_f32(sum2, 0);
  }
#endif
  else
  {
   for(int i = 0; i < phaseip_num_coeffs; i++)
   {
    float coeff_a = cpa[i];
    float coeff_b = cpb[i];
    float coeff = coeff_a + (coeff_b - coeff_a) * phase_ip;

    accum += coeff * inbuf[i];
   }
  }
  //
  {
   int32 s = ((int32)accum + 0x80) >> 8;

   if(s < -32768)
    s = -32768;
 
   if(s > 32767)
    s = 32767;

   if(MDFN_LIKELY(dest_offs < dest_max))
    dest[dest_offs++] = s;
  }
 }
 //
 const uint32 pai = std::min<uint32>(state.buf2_offs, state.phase_accum >> 32);

 memmove(state.buf2, state.buf2 + pai, (state.buf2_offs - pai) * sizeof(double));
 state.buf2_offs -= pai;
 state.phase_accum -= (uint64)pai << 32;

 return dest_offs;
}

uint32 CassowaryResampler::Resample(float* MDFN_RESTRICT src, uint32 src_count, int16* MDFN_RESTRICT dest, uint32 dest_max, uint32* MDFN_RESTRICT leftover)
{
 uint32 ret;

 assert(src_count <= 65536);

 ResampleStage012(src, src_count, leftover);

 ret = ResampleStage3(dest, dest_max);

 //printf("%u %u %u %u\n", *leftover, state.buf0_offs, state.buf1_offs, state.buf2_offs);

 return ret;
}

CassowaryResampler::CassowaryResampler(double input_rate_) : input_rate(input_rate_)
{
 state.buf0_offs = 0;
 state.buf1_offs = 0;
 state.buf2_offs = 0;
 state.phase_accum = 0;

 memset(state.buf0, 0, sizeof(state.buf0));
 memset(state.buf1, 0, sizeof(state.buf1));
 memset(state.buf2, 0, sizeof(state.buf2));

 memset(num_coeffs, 0, sizeof(num_coeffs));
 memset(div, 0, sizeof(div));

 memset(coeffs_stage0, 0, sizeof(coeffs_stage0));
 memset(coeffs_stage1, 0, sizeof(coeffs_stage1));
 memset(coeffs_stage2, 0, sizeof(coeffs_stage2));
 memset(coeffs_phaseip, 0, sizeof(coeffs_phaseip));

 coeffs_halve_ratio = 0;
 phase_accum_inc = 0;
 //
 //
 //
 if(input_rate >= 3.2e6)
 {
  // TODO: Test(specifically, 3579545 Hz input)
  num_coeffs[0] = 32;
  num_coeffs[1] = 96;

  div[0] = 4;
  div[1] = 7;
 }
 else if(input_rate < 1.8e6)
 {
  num_coeffs[0] = 48;
  num_coeffs[1] = 48;
  div[0] = 5;
  div[1] = 3;
 }
 else
 {
  num_coeffs[0] = 32;
  num_coeffs[1] = 48;
  div[0] = 4;
  div[1] = 4;
 }

 num_coeffs[2] = 255;
 div[2] = 2;

 assert(num_coeffs[0] <= max_coeffs_stage0);
 assert(num_coeffs[1] <= max_coeffs_stage1);
 assert(num_coeffs[2] <= max_coeffs_stage2);

 for(unsigned stage = 0; stage < 2; stage++)
 {
  float* const p[2] = { coeffs_stage0, coeffs_stage1 };
  unsigned nc = num_coeffs[stage];
  unsigned d = div[stage];

  std::unique_ptr<double[]> filterbuf(new double[nc]);

  DSPUtility::generate_kaiser_sinc_lp(filterbuf.get(), nc, 1.0 / d / 2, 11.0);
  DSPUtility::normalize(filterbuf.get(), nc, 1.0);

  for(unsigned i = 0; i < nc; i++)
  {
   double v = filterbuf[i];

   if(fabs(v) < (1.0 / (1 << 20) / nc))
   {
    //printf("stage%u %u: %.20f\n", stage, i, v);
    v = 0;
   }

   p[stage][i] = v;
   //printf(" % .12f,\n", v);
  }
 }

 {
  const int32 n = phaseip_num_coeffs * phaseip_num_phases;
  std::unique_ptr<double[]> filterbuf(new double[n]);

  DSPUtility::generate_kaiser_sinc_lp(filterbuf.get(), n, 0.425 / phaseip_num_phases, 10.056);
  DSPUtility::normalize(filterbuf.get(), n, phaseip_num_phases);

  for(int phase = 0; phase < phaseip_num_phases + 1; phase++)
  {
   for(int coeff = 0; coeff < phaseip_num_coeffs + 1; coeff++)
   {
    int32 index = coeff * phaseip_num_phases + (phaseip_num_phases - 1 - phase);
    float v;

    if(index < 0 || index >= n)
     v = 0;
    else
    {
     v = filterbuf[index];

     if(fabs(v) < (1.0 / (1 << 20) / phaseip_num_coeffs))
     {
      //printf("phaseip[%u][%u]: %.20f\n", phase, coeff, v);
      v = 0;
     }
    }

    coeffs_phaseip[phase][coeff] = v;
   }
  }
 }
}

CassowaryResampler::~CassowaryResampler()
{

}

}
