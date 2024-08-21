// Will read 16 bytes of input waveform past end.
static INLINE void DoMAC_SSE_16X(float *wave, float *coeffs, int32 count, int32 *accum_output)
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

 *accum_output = _mm_cvtss_si32(sum);
}
