#ifdef __x86_64__
#define X86_REGC "r"
#define X86_REGAT ""
#else
#define X86_REGC "e"
#define X86_REGAT "l"
#endif

template<unsigned TA_NumFractBits>
static INLINE void DoMAC_SSE2(const int16 *wave, const int16 *coeffs, int32 count, int32 *accum_output)
{
 // Multiplies 32 coefficients at a time.
 static_assert(TA_NumFractBits >= (3 + 1), "TA_NumFractBits too small.");
 int dummy;

/*
	?di = wave pointer
	?si = coeffs pointer
	ecx = count / 32
	edx = 32-bit int output pointer

	
*/
 // Will read 16 bytes of input waveform past end.
 asm volatile(
"pxor %%xmm3, %%xmm3\n\t"	// For a loop optimization

"pxor %%xmm4, %%xmm4\n\t"
"pxor %%xmm5, %%xmm5\n\t"
"pxor %%xmm6, %%xmm6\n\t"
"pxor %%xmm7, %%xmm7\n\t"

"movups  0(%%" X86_REGC "di), %%xmm0\n\t"
"1:\n\t"

"movups  16(%%" X86_REGC "di), %%xmm1\n\t"
"pmaddwd  0(%%" X86_REGC "si), %%xmm0\n\t"
"paddd   %%xmm3, %%xmm7\n\t"

"movups  32(%%" X86_REGC "di), %%xmm2\n\t"
"pmaddwd 16(%%" X86_REGC "si), %%xmm1\n\t"
"paddd   %%xmm0, %%xmm4\n\t"

"movups  48(%%" X86_REGC "di), %%xmm3\n\t"
"pmaddwd 32(%%" X86_REGC "si), %%xmm2\n\t"
"paddd   %%xmm1, %%xmm5\n\t"

"movups  64(%%" X86_REGC "di), %%xmm0\n\t"
"pmaddwd 48(%%" X86_REGC "si), %%xmm3\n\t"
"paddd   %%xmm2, %%xmm6\n\t"

"add" X86_REGAT " $64, %%" X86_REGC "si\n\t"
"add" X86_REGAT " $64, %%" X86_REGC "di\n\t"
"subl $1, %%ecx\n\t"
"jnz 1b\n\t"

"paddd  %%xmm3, %%xmm7\n\t"	// For a loop optimization

"psrad $3, %%xmm4\n\t"
"psrad $3, %%xmm5\n\t"
"psrad $3, %%xmm6\n\t"
"psrad $3, %%xmm7\n\t"

//
// Add the four summation xmm regs together into one xmm register, xmm7
//
"paddd  %%xmm4, %%xmm5\n\t"
"paddd  %%xmm6, %%xmm7\n\t"
"paddd  %%xmm5, %%xmm7\n\t"

//
// Pre shift right by 1(and shift the rest, 15 bits, later) so we don't overflow during horizontal addition(could occur with large input
// amplitudes approaching the limits of the signed 16-bit range)
//
"psrad      $1, %%xmm7\n\t"

//
// Now for the "fun" horizontal addition...
//
// 
"movaps %%xmm7, %%xmm4\n\t"
// (3 * 2^0) + (2 * 2^2) + (1 * 2^4) + (0 * 2^6) = 27
"shufps $27, %%xmm7, %%xmm4\n\t"
"paddd  %%xmm4, %%xmm7\n\t"

// At this point, xmm7:
// (3 + 0), (2 + 1), (1 + 2), (0 + 3)
//
// (1 * 2^0) + (0 * 2^2) = 1
"movaps %%xmm7, %%xmm4\n\t"
"shufps $1, %%xmm7, %%xmm4\n\t"
"paddd %%xmm4, %%xmm7\n\t"
"psrad %7, %%xmm7\n\t"
"movss %%xmm7, (%%" X86_REGC "dx)\n\t"
 : "=D" (dummy), "=S" (dummy), "=c" (dummy)
 : "D" (wave), "S" (coeffs), "c" ((count + 0x1F) >> 5), "d" (accum_output), "i"(TA_NumFractBits - (3 + 1))
#ifdef __SSE__
 : "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7", "cc", "memory"
#else
 : "cc", "memory"
#endif
);
}

template<unsigned TA_NumFractBits>
static INLINE void DoMAC_MMX(const int16 *wave, const int16 *coeffs, int32 count, int32 *accum_output)
{
 // Multiplies 16 coefficients at a time.
 static_assert(TA_NumFractBits >= (3 + 1), "TA_NumFractBits too small.");
 int dummy;

/*
 MMX register usage:
	mm0: Temporary sample load and multiply register
	mm2: Temporary sample load and multiply register

	mm1: accumulator, 2 32-bit signed values
	mm3: accumulator, 2 32-bit signed values

	mm4: accumulator, 2 32-bit signed values
	mm5: accumulator, 2 32-bit signed values

	mm6: Temporary sample load and multiply register, temporary summation register
	mm7: Temporary sample load and multiply register
	
*/
 asm volatile(
"pxor %%mm1, %%mm1\n\t"
"pxor %%mm3, %%mm3\n\t"
"pxor %%mm4, %%mm4\n\t"
"pxor %%mm5, %%mm5\n\t"
"1:\n\t"

"movq (%%" X86_REGC "di), %%mm0\n\t"
"pmaddwd (%%" X86_REGC "si), %%mm0\n\t"

"movq 8(%%" X86_REGC "di), %%mm2\n\t"
"psrad $1, %%mm0\n\t"
"pmaddwd 8(%%" X86_REGC "si), %%mm2\n\t"

"movq 16(%%" X86_REGC "di), %%mm6\n\t"
"psrad $1, %%mm2\n\t"
"pmaddwd 16(%%" X86_REGC "si), %%mm6\n\t"

"movq 24(%%" X86_REGC "di), %%mm7\n\t"
"psrad $1, %%mm6\n\t"
"pmaddwd 24(%%" X86_REGC "si), %%mm7\n\t"

"paddd %%mm0, %%mm1\n\t"
"paddd %%mm2, %%mm3\n\t"
"psrad $1, %%mm7\n\t"
"paddd %%mm6, %%mm4\n\t"
"paddd %%mm7, %%mm5\n\t"

"add" X86_REGAT " $32, %%" X86_REGC "si\n\t"
"add" X86_REGAT " $32, %%" X86_REGC "di\n\t"
"subl $1, %%ecx\n\t"
"jnz 1b\n\t"

//
"psrad $3, %%mm1\n\t"
"psrad $3, %%mm3\n\t"
"psrad $3, %%mm4\n\t"
"psrad $3, %%mm5\n\t"

// Now, mm1, mm3, mm4, mm5 contain 8 32-bit sums that need to be added together.

"paddd %%mm5, %%mm3\n\t"
"paddd %%mm4, %%mm1\n\t"
"paddd %%mm3, %%mm1\n\t"
"movq %%mm1, %%mm6\n\t"
"psrlq $32, %%mm6\n\t"
"paddd %%mm6, %%mm1\n\t"

"psrad %7, %%mm1\n\t"
//"psrad $16, %%mm1\n\t"
"movd %%mm1, (%%" X86_REGC "dx)\n\t"
 : "=D" (dummy), "=S" (dummy), "=c" (dummy)
 : "D" (wave), "S" (coeffs), "c" ((count + 0xF) >> 4), "d" (accum_output), "i"(TA_NumFractBits - (3 + 1))
 : "cc", "memory"
#ifdef __MMX__
 		 , "mm0", "mm1", "mm2", "mm3", "mm4", "mm5", "mm6", "mm7"
#else
 		 // gcc has a bug or weird design flaw or something in it that keeps this from working properly: , "st", "st(1)", "st(2)", "st(3)", "st(4)", "st(5)", "st(6)", "st(7)"	
#endif
);
}

