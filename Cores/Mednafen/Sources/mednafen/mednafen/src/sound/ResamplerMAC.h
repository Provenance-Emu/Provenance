/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* ResamplerMAC.h:
**  Copyright (C) 2013-2023 Mednafen Team
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
#ifndef __MDFN_SOUND_RESAMPLERMAC_H
#define __MDFN_SOUND_RESAMPLERMAC_H

#if defined(HAVE_ALTIVEC_INTRINSICS) && defined(HAVE_ALTIVEC_H)
 #include <altivec.h>
#endif

#ifdef HAVE_NEON_INTRINSICS
 #include <arm_neon.h>
#endif

#if defined(HAVE_SSE_INTRINSICS)
 #include <xmmintrin.h>
#endif

#if !defined(RESAMPLERMAC_FLOATOUT) || ((RESAMPLERMAC_FLOATOUT != 0) && (RESAMPLERMAC_FLOATOUT != 1))
 #error "Bad or missing RESAMPLERMAC_FLOATOUT define"
#endif

#if RESAMPLERMAC_FLOATOUT
 #define RESAMPLERMAC_OUTTYPE float
#else
 #define RESAMPLERMAC_OUTTYPE int32
#endif

namespace Mednafen
{

static INLINE void DoMAC(const float* wave, const float *coeffs, int32 count, RESAMPLERMAC_OUTTYPE* accum_output)
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
//
// Don't use vzeroall in AVX code unless we mark ymm8-ymm15/xmm8-xmm15 as clobbers on x86_64
// (Also, remember to mark xmm* instead of ymm* as clobbers if __AVX__ isn't defined!)
//
#if defined(__x86_64__) && !defined(__ILP32__)
#define X86_REGC "r"
#define X86_REGAT ""
#else
#define X86_REGC "e"
#define X86_REGAT "l"
#endif

#ifdef HAVE_INLINEASM_AVX
static INLINE void DoMAC_AVX_32X(const float* wave, const float *coeffs, int32 count, RESAMPLERMAC_OUTTYPE* accum_output)
{
 // Multiplies 32 coefficients at a time.
 int dummy;
 int32 tmp;

 //printf("%f\n", adj);
/*
	?di = wave pointer
	?si = coeffs pointer
	ecx = count / 16
	edx = 32-bit int output pointer

	
*/
 // Will read 32 bytes of input waveform past end.
 asm volatile(
//".arch bdver1\n\t"
"vxorps %%ymm3, %%ymm3, %%ymm3\n\t"	// For a loop optimization

"vxorps %%ymm4, %%ymm4, %%ymm4\n\t"
"vxorps %%ymm5, %%ymm5, %%ymm5\n\t"
"vxorps %%ymm6, %%ymm6, %%ymm6\n\t"
"vxorps %%ymm7, %%ymm7, %%ymm7\n\t"

"vmovups  0(%%" X86_REGC "di), %%ymm0\n\t"
"1:\n\t"

"vmovups 32(%%" X86_REGC "di), %%ymm1\n\t"
"vmulps   0(%%" X86_REGC "si), %%ymm0, %%ymm0\n\t"
"vaddps  %%ymm3, %%ymm7, %%ymm7\n\t"

"vmovups 64(%%" X86_REGC "di), %%ymm2\n\t"
"vmulps  32(%%" X86_REGC "si), %%ymm1, %%ymm1\n\t"
"vaddps  %%ymm0, %%ymm4, %%ymm4\n\t"

"vmovups 96(%%" X86_REGC "di), %%ymm3\n\t"
"vmulps  64(%%" X86_REGC "si), %%ymm2, %%ymm2\n\t"
"vaddps  %%ymm1, %%ymm5, %%ymm5\n\t"

"vmovups 128(%%" X86_REGC "di), %%ymm0\n\t"
"vmulps  96(%%" X86_REGC "si), %%ymm3, %%ymm3\n\t"
"vaddps  %%ymm2, %%ymm6, %%ymm6\n\t"

"add" X86_REGAT " $128, %%" X86_REGC "si\n\t"
"add" X86_REGAT " $128, %%" X86_REGC "di\n\t"
"subl $1, %%ecx\n\t"
"jnz 1b\n\t"

"vaddps  %%ymm3, %%ymm7, %%ymm7\n\t"	// For a loop optimization

//
// Add the four summation ymm regs together into one ymm register, ymm7
//
"vaddps  %%ymm4, %%ymm5, %%ymm5\n\t"
"vaddps  %%ymm6, %%ymm7, %%ymm7\n\t"
"vaddps  %%ymm5, %%ymm7, %%ymm7\n\t"

//
// Horizontal addition.
//
// A,B,C,D, E,F,G,H
"vhaddps %%ymm7, %%ymm7, %%ymm7\n\t"
// A+B, C+D, A+B, C+D, E+F, G+H, E+F, G+H,
"vhaddps %%ymm7, %%ymm7, %%ymm7\n\t"
"vextractf128 $1, %%ymm7, %%xmm6\n\t"
"vaddss %%xmm7, %%xmm6, %%xmm6\n\t"
// A+B+C+D, A+B+C+D, A+B+C+D, A+B+C+D, E+F+G+H, E+F+G+H, E+F+G+H, E+F+G+H,
//"vhaddps %%ymm5, %%ymm5, %%ymm5\n\t"
// A+B+C+D+E+F+G+H

#if RESAMPLERMAC_FLOATOUT
"vmovss %%xmm6, (%%" X86_REGC "dx)\n\t"
#else
"vcvtss2si %%xmm6, %%ecx\n\t"
#endif
 : "=D" (dummy), "=S" (dummy), "=c" (tmp)
 : "D" (wave), "S" (coeffs), "c" (count >> 5), "d" (accum_output)
#ifdef __AVX__
 : "ymm0", "ymm1", "ymm2", "ymm3", "ymm4", "ymm5", "ymm6", "ymm7", "cc", "memory"
#elif defined(__SSE__)
 : "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7", "cc", "memory"
#else
 : "cc", "memory"
#endif
);
#if !RESAMPLERMAC_FLOATOUT
 *accum_output = tmp;
#endif
}

static INLINE void DoMAC_AVX_32X_P16(const float* wave, const float *coeffs, int32 count, RESAMPLERMAC_OUTTYPE* accum_output)
{
 // Multiplies 32 coefficients at a time.
 int dummy;
 int32 tmp;

 //printf("%f\n", adj);
/*
	?di = wave pointer
	?si = coeffs pointer
	ecx = count / 16
	edx = 32-bit int output pointer

	
*/

 asm volatile(
"vxorps %%ymm3, %%ymm3, %%ymm3\n\t"	// For a loop optimization

"vxorps %%ymm4, %%ymm4, %%ymm4\n\t"
"vxorps %%ymm5, %%ymm5, %%ymm5\n\t"
"vxorps %%ymm6, %%ymm6, %%ymm6\n\t"
"vxorps %%ymm7, %%ymm7, %%ymm7\n\t"

"vmovups  0(%%" X86_REGC "di), %%ymm0\n\t"
"1:\n\t"

"vmovups 32(%%" X86_REGC "di), %%ymm1\n\t"
"vmulps   0(%%" X86_REGC "si), %%ymm0, %%ymm0\n\t"
"vaddps  %%ymm3, %%ymm7, %%ymm7\n\t"

"vmovups 64(%%" X86_REGC "di), %%ymm2\n\t"
"vmulps  32(%%" X86_REGC "si), %%ymm1, %%ymm1\n\t"
"vaddps  %%ymm0, %%ymm4, %%ymm4\n\t"

"vmovups 96(%%" X86_REGC "di), %%ymm3\n\t"
"vmulps  64(%%" X86_REGC "si), %%ymm2, %%ymm2\n\t"
"vaddps  %%ymm1, %%ymm5, %%ymm5\n\t"

"vmovups 128(%%" X86_REGC "di), %%ymm0\n\t"
"vmulps  96(%%" X86_REGC "si), %%ymm3, %%ymm3\n\t"
"vaddps  %%ymm2, %%ymm6, %%ymm6\n\t"

"add" X86_REGAT " $128, %%" X86_REGC "si\n\t"
"add" X86_REGAT " $128, %%" X86_REGC "di\n\t"
"subl $1, %%ecx\n\t"
"jnz 1b\n\t"

/////
"vmovups 32(%%" X86_REGC "di), %%ymm1\n\t"
"vmulps   0(%%" X86_REGC "si), %%ymm0, %%ymm0\n\t"
"vaddps  %%ymm3, %%ymm7, %%ymm7\n\t"
"vmulps  32(%%" X86_REGC "si), %%ymm1, %%ymm1\n\t"
"vaddps  %%ymm0, %%ymm4, %%ymm4\n\t"
/////
"vaddps  %%ymm1, %%ymm5, %%ymm5\n\t"	// For a loop optimization

//
// Add the four summation ymm regs together into one ymm register, ymm7
//
"vaddps  %%ymm4, %%ymm5, %%ymm5\n\t"
"vaddps  %%ymm6, %%ymm7, %%ymm7\n\t"
"vaddps  %%ymm5, %%ymm7, %%ymm7\n\t"

//
// Horizontal addition.
//
// A,B,C,D, E,F,G,H
"vhaddps %%ymm7, %%ymm7, %%ymm7\n\t"
// A+B, C+D, A+B, C+D, E+F, G+H, E+F, G+H,
"vhaddps %%ymm7, %%ymm7, %%ymm7\n\t"
"vextractf128 $1, %%ymm7, %%xmm6\n\t"
"vaddss %%xmm7, %%xmm6, %%xmm6\n\t"
// A+B+C+D, A+B+C+D, A+B+C+D, A+B+C+D, E+F+G+H, E+F+G+H, E+F+G+H, E+F+G+H,
//"vhaddps %%ymm5, %%ymm5, %%ymm5\n\t"
// A+B+C+D+E+F+G+H

#if RESAMPLERMAC_FLOATOUT
"vmovss %%xmm6, (%%" X86_REGC "dx)\n\t"
#else
"vcvtss2si %%xmm6, %%ecx\n\t"
#endif
 : "=D" (dummy), "=S" (dummy), "=c" (tmp)
 : "D" (wave), "S" (coeffs), "c" (count >> 5), "d" (accum_output)
#ifdef __AVX__
 : "ymm0", "ymm1", "ymm2", "ymm3", "ymm4", "ymm5", "ymm6", "ymm7", "cc", "memory"
#elif defined(__SSE__)
 : "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7", "cc", "memory"
#else
 : "cc", "memory"
#endif
);
#if !RESAMPLERMAC_FLOATOUT
 *accum_output = tmp;
#endif
}
#endif

static INLINE void DoMAC_SSE_16X(const float* wave, const float *coeffs, int32 count, RESAMPLERMAC_OUTTYPE* accum_output)
{
 // Multiplies 16 coefficients at a time.
 int dummy;

 //printf("%f\n", adj);
/*
	?di = wave pointer
	?si = coeffs pointer
	ecx = count / 16
	edx = 32-bit int output pointer

	
*/
 // Will read 16 bytes of input waveform past end.
 asm volatile(
"xorps %%xmm3, %%xmm3\n\t"	// For a loop optimization

"xorps %%xmm4, %%xmm4\n\t"
"xorps %%xmm5, %%xmm5\n\t"
"xorps %%xmm6, %%xmm6\n\t"
"xorps %%xmm7, %%xmm7\n\t"

"movups  0(%%" X86_REGC "di), %%xmm0\n\t"
"1:\n\t"

"movups 16(%%" X86_REGC "di), %%xmm1\n\t"
"mulps   0(%%" X86_REGC "si), %%xmm0\n\t"
"addps  %%xmm3, %%xmm7\n\t"

"movups 32(%%" X86_REGC "di), %%xmm2\n\t"
"mulps  16(%%" X86_REGC "si), %%xmm1\n\t"
"addps  %%xmm0, %%xmm4\n\t"

"movups 48(%%" X86_REGC "di), %%xmm3\n\t"
"mulps  32(%%" X86_REGC "si), %%xmm2\n\t"
"addps  %%xmm1, %%xmm5\n\t"

"movups 64(%%" X86_REGC "di), %%xmm0\n\t"
"mulps  48(%%" X86_REGC "si), %%xmm3\n\t"
"addps  %%xmm2, %%xmm6\n\t"

"add" X86_REGAT " $64, %%" X86_REGC "si\n\t"
"add" X86_REGAT " $64, %%" X86_REGC "di\n\t"
"subl $1, %%ecx\n\t"
"jnz 1b\n\t"

"addps  %%xmm3, %%xmm7\n\t"	// For a loop optimization

//
// Add the four summation xmm regs together into one xmm register, xmm7
//
"addps  %%xmm4, %%xmm5\n\t"
"addps  %%xmm6, %%xmm7\n\t"
"addps  %%xmm5, %%xmm7\n\t"

//
// Now for the "fun" horizontal addition...
//
// 
"movaps %%xmm7, %%xmm4\n\t"
// (3 * 2^0) + (2 * 2^2) + (1 * 2^4) + (0 * 2^6) = 27
"shufps $27, %%xmm7, %%xmm4\n\t"
"addps  %%xmm4, %%xmm7\n\t"

// At this point, xmm7:
// (3 + 0), (2 + 1), (1 + 2), (0 + 3)
//
// (1 * 2^0) + (0 * 2^2) = 1
"movaps %%xmm7, %%xmm4\n\t"
"shufps $1, %%xmm7, %%xmm4\n\t"
"addss %%xmm4, %%xmm7\n\t"	// No sense in doing packed addition here.

#if RESAMPLERMAC_FLOATOUT
"movss %%xmm7, (%%" X86_REGC "dx)\n\t"
#else
"cvtss2si %%xmm7, %%ecx\n\t"
"movl %%ecx, (%%" X86_REGC "dx)\n\t"
#endif
 : "=D" (dummy), "=S" (dummy), "=c" (dummy)
 : "D" (wave), "S" (coeffs), "c" (count >> 4), "d" (accum_output)
#ifdef __SSE__
 : "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7", "cc", "memory"
#else
 : "cc", "memory"
#endif
);
}
//
//
//
#elif defined(HAVE_SSE_INTRINSICS)
//
//
//
// Will read 16 bytes of input waveform past end.
static INLINE void DoMAC_SSE_16X(const float* wave, const float *coeffs, int32 count, RESAMPLERMAC_OUTTYPE* accum_output)
{
 __m128 accum0, accum1, accum2, accum3;
 __m128 tmp0, tmp1, tmp2, tmp3;
 
 count >>= 4;

 tmp3 = accum0 = accum1 = accum2 = accum3 = _mm_setzero_ps();

 tmp0 = _mm_loadu_ps(wave +  0);
 do
 {
  tmp1 = _mm_loadu_ps(wave +  4);
  tmp0 = _mm_mul_ps(tmp0, _mm_load_ps(coeffs +  0));
  accum3 = _mm_add_ps(accum3, tmp3);
 
  tmp2 = _mm_loadu_ps(wave +  8);
  tmp1 = _mm_mul_ps(tmp1, _mm_load_ps(coeffs +  4));
  accum0 = _mm_add_ps(accum0, tmp0);

  tmp3 = _mm_loadu_ps(wave + 12);
  tmp2 = _mm_mul_ps(tmp2, _mm_load_ps(coeffs +  8));
  accum1 = _mm_add_ps(accum1, tmp1);

  tmp0 = _mm_loadu_ps(wave + 16);
  tmp3 = _mm_mul_ps(tmp3, _mm_load_ps(coeffs + 12));
  accum2 = _mm_add_ps(accum2, tmp2);

  wave += 16;
  coeffs += 16;
 } while(MDFN_LIKELY(--count));

 accum3 = _mm_add_ps(accum3, tmp3);
 //
 //
 //
 __m128 sum;
 sum = _mm_add_ps(_mm_add_ps(accum0, accum1), _mm_add_ps(accum2, accum3));
 sum = _mm_add_ps(sum, _mm_shuffle_ps(sum, sum, (3 << 0) + (2 << 2) + (1 << 4) + (0 << 6)));
 sum = _mm_add_ps(sum, _mm_shuffle_ps(sum, sum, (1 << 0)));

#if RESAMPLERMAC_FLOATOUT
 *accum_output = _mm_cvtss_f32(sum);
#else
 *accum_output = _mm_cvtss_si32(sum);
#endif
}
//
//
//
#endif

#ifdef HAVE_ALTIVEC_INTRINSICS
//
//
//
static INLINE void DoMAC_AltiVec(const float* wave, const float *coeffs, int32 count, RESAMPLERMAC_OUTTYPE* accum_output)
{
 register vector float acc0, acc1, acc2, acc3;

 acc0 = (vector float)vec_splat_u8(0);
 acc1 = acc0;
 acc2 = acc0;
 acc3 = acc0;

 count >>= 4;

 if(!((uintptr_t)wave & 0xF))
 {
  register vector float w, c;
  do
  {
   w = vec_ld(0, wave);
   c = vec_ld(0, coeffs);
   acc0 = vec_madd(w, c, acc0);

   w = vec_ld(16, wave);
   c = vec_ld(16, coeffs);
   acc1 = vec_madd(w, c, acc1);

   w = vec_ld(32, wave);
   c = vec_ld(32, coeffs);
   acc2 = vec_madd(w, c, acc2);

   w = vec_ld(48, wave);
   c = vec_ld(48, coeffs);
   acc3 = vec_madd(w, c, acc3);

   coeffs += 16;
   wave += 16;
  } while(--count);
 }
 else
 {
  register vector unsigned char lperm;
  register vector float loado;

  lperm = vec_lvsl(0, wave);
  loado = vec_ld(0, wave);

  do
  {
   register vector float tl;
   register vector float w;
   register vector float c;

   tl = vec_ld(15 + 0, wave);
   w = vec_perm(loado, tl, lperm);
   c = vec_ld(0, coeffs);
   loado = tl;
   acc0 = vec_madd(w, c, acc0);

   tl = vec_ld(15 + 16, wave);
   w = vec_perm(loado, tl, lperm);
   c = vec_ld(16, coeffs);
   loado = tl;
   acc1 = vec_madd(w, c, acc1);

   tl = vec_ld(15 + 32, wave);
   w = vec_perm(loado, tl, lperm);
   c = vec_ld(32, coeffs);
   loado = tl;
   acc2 = vec_madd(w, c, acc2);

   tl = vec_ld(15 + 48, wave);
   w = vec_perm(loado, tl, lperm);
   c = vec_ld(48, coeffs);
   loado = tl;
   acc3 = vec_madd(w, c, acc3);

   coeffs += 16;
   wave += 16;
  } while(--count);
 }

 {
  vector float sum;
  vector float sums0;

  sum = vec_add(vec_add(acc0, acc1), vec_add(acc2, acc3));
  sums0 = vec_sld(sum, sum, 8);
  sum = vec_add(sum, sums0);
  sums0 = vec_sld(sum, sum, 4);
  sum = vec_add(sum, sums0);

#if RESAMPLERMAC_FLOATOUT
  vec_ste(sum, 0, accum_output);
#else
  vector signed int sum_i = vec_cts(sum, 0);
  vec_ste(sum_i, 0, accum_output);
#endif
 }
}
//
//
//
#endif

#ifdef HAVE_NEON_INTRINSICS
//
//
//
static INLINE void DoMAC_NEON(const float* wave, const float *coeffs, int32 count, RESAMPLERMAC_OUTTYPE* accum_output)
{
 register float32x4_t acc0, acc1, acc2, acc3;

 acc0 = acc1 = acc2 = acc3 = vdupq_n_f32(0);

 count >>= 4;

 do
 {
  acc0 = vmlaq_f32(acc0, vld1q_f32(MDFN_ASSUME_ALIGNED(coeffs     , sizeof(float32x4_t))), vld1q_f32(wave +  0));
  acc1 = vmlaq_f32(acc1, vld1q_f32(MDFN_ASSUME_ALIGNED(coeffs +  4, sizeof(float32x4_t))), vld1q_f32(wave +  4));
  acc2 = vmlaq_f32(acc2, vld1q_f32(MDFN_ASSUME_ALIGNED(coeffs +  8, sizeof(float32x4_t))), vld1q_f32(wave +  8));
  acc3 = vmlaq_f32(acc3, vld1q_f32(MDFN_ASSUME_ALIGNED(coeffs + 12, sizeof(float32x4_t))), vld1q_f32(wave + 12));

  coeffs += 16;
  wave += 16;
 } while(MDFN_LIKELY(--count));
 //
 //
 //
 register float32x4_t sum4;
 register float32x2_t sum2;

 sum4 = vaddq_f32(vaddq_f32(acc0, acc1), vaddq_f32(acc2, acc3));
 sum2 = vadd_f32(vget_high_f32(sum4), vget_low_f32(sum4));
 sum2 = vpadd_f32(sum2, sum2);

#if RESAMPLERMAC_FLOATOUT
 vst1_lane_f32(accum_output, sum2, 0);
#else
 vst1_lane_s32(accum_output, vcvt_s32_f32(sum2), 0);
#endif
}
//
//
//
#endif

}

#endif
