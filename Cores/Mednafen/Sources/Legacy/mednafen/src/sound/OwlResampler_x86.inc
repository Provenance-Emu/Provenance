//
// Don't use vzeroall in AVX code unless we mark ymm8-ymm15/xmm8-xmm15 as clobbers on x86_64
// (Also, remember to mark xmm* instead of ymm* as clobbers if __AVX__ isn't defined!)

#if defined(__x86_64__) && !defined(__ILP32__)
#define X86_REGC "r"
#define X86_REGAT ""
#else
#define X86_REGC "e"
#define X86_REGAT "l"
#endif

static INLINE void DoMAC_AVX_32X(float* wave, float* coeffs, int32 count, int32* accum_output)
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

"vcvtss2si %%xmm6, %%ecx\n\t"
 : "=D" (dummy), "=S" (dummy), "=c" (tmp)
 : "D" (wave), "S" (coeffs), "c" (count >> 5)
#ifdef __AVX__
 : "ymm0", "ymm1", "ymm2", "ymm3", "ymm4", "ymm5", "ymm6", "ymm7", "cc", "memory"
#elif defined(__SSE__)
 : "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7", "cc", "memory"
#else
 : "cc", "memory"
#endif
);

 *accum_output = tmp;
}

static INLINE void DoMAC_AVX_32X_P16(float* wave, float* coeffs, int32 count, int32* accum_output)
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

"vcvtss2si %%xmm6, %%ecx\n\t"
 : "=D" (dummy), "=S" (dummy), "=c" (tmp)
 : "D" (wave), "S" (coeffs), "c" (count >> 5)
#ifdef __AVX__
 : "ymm0", "ymm1", "ymm2", "ymm3", "ymm4", "ymm5", "ymm6", "ymm7", "cc", "memory"
#elif defined(__SSE__)
 : "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7", "cc", "memory"
#else
 : "cc", "memory"
#endif
);

 *accum_output = tmp;
}



static INLINE void DoMAC_SSE_16X(float *wave, float *coeffs, int32 count, int32 *accum_output)
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

"cvtss2si %%xmm7, %%ecx\n\t"
"movl %%ecx, (%%" X86_REGC "dx)\n\t"
 : "=D" (dummy), "=S" (dummy), "=c" (dummy)
 : "D" (wave), "S" (coeffs), "c" (count >> 4), "d" (accum_output)
#ifdef __SSE__
 : "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7", "cc", "memory"
#else
 : "cc", "memory"
#endif
);
}

