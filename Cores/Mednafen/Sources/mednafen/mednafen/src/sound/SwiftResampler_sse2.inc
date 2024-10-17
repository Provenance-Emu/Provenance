//
// 16 macs per loop iteration
//
template<unsigned TA_NumFractBits>
static INLINE void DoMAC_SSE2_Intrin(const int16* wave, const int16* coeffs, int32 count, int32* accum_output)
{
 static_assert(TA_NumFractBits >= (3 + 1), "TA_NumFractBits too small.");
 __m128i accum0, accum1;
 __m128i sum;

 count = (count + 0xF) >> 4;

 accum0 = accum1 = _mm_setzero_si128();

 do
 {
  __m128i tmp0 = _mm_madd_epi16(_mm_loadu_si128((__m128i *)(wave + 0)), _mm_load_si128((__m128i *)(coeffs + 0)));
  __m128i tmp1 = _mm_madd_epi16(_mm_loadu_si128((__m128i *)(wave + 8)), _mm_load_si128((__m128i *)(coeffs + 8)));

  accum0 = _mm_add_epi32(accum0, _mm_srai_epi32(tmp0, 1));
  accum1 = _mm_add_epi32(accum1, _mm_srai_epi32(tmp1, 1));

  wave += 16;
  coeffs += 16;
 } while(MDFN_LIKELY(--count));

 accum0 = _mm_srai_epi32(accum0, 3);
 accum1 = _mm_srai_epi32(accum1, 3);

 sum = _mm_add_epi32(accum0, accum1);
 sum = _mm_add_epi32(sum, _mm_shuffle_epi32(sum, (3 << 0) | (2 << 2) | (1 << 4) | (0 << 6)));
 sum = _mm_add_epi32(sum, _mm_shuffle_epi32(sum, (1 << 0) | (0 << 2)));

 sum = _mm_srai_epi32(sum, TA_NumFractBits - (3 + 1));

#ifdef _MSC_VER
 _mm_store_ss((float *)accum_output, *(__m128*)&sum);
#else
 _mm_store_ss((float *)accum_output, (__m128)sum);
#endif
}

