template<unsigned TA_NumFractBits>
static INLINE void DoMAC_NEON(const int16* wave, const int16* coeffs, int32 count, int32* accum_output)
{
 static_assert(TA_NumFractBits >= 3, "TA_NumFractBits too small.");
 register int32x4_t accum0, accum1, accum2, accum3;
 register int16x4_t ctmp0, ctmp1, ctmp2, ctmp3;
 register int16x4_t wtmp0, wtmp1, wtmp2, wtmp3;

 //coeffs = MDFN_ASSUME_ALIGNED(coeffs, sizeof(ctmp0));

 count = (count + 0xF) >> 4;

 accum0 = accum1 = accum2 = accum3 = vdupq_n_s32(0);

 wtmp0 = vld1_s16(wave);
 wave += 4;
 do
 {
  ctmp0 = vld1_s16(MDFN_ASSUME_ALIGNED(coeffs, sizeof(ctmp0)));
  coeffs += 4;
  wtmp1 = vld1_s16(wave);
  wave += 4;
  accum0 = vmlal_s16(accum0, ctmp0, wtmp0);

  ctmp1 = vld1_s16(MDFN_ASSUME_ALIGNED(coeffs, sizeof(ctmp0)));
  coeffs += 4;
  wtmp2 = vld1_s16(wave);
  wave += 4;
  accum1 = vmlal_s16(accum1, ctmp1, wtmp1);

  ctmp2 = vld1_s16(MDFN_ASSUME_ALIGNED(coeffs, sizeof(ctmp0)));
  coeffs += 4;
  wtmp3 = vld1_s16(wave);
  wave += 4;
  accum2 = vmlal_s16(accum2, ctmp2, wtmp2);

  ctmp3 = vld1_s16(MDFN_ASSUME_ALIGNED(coeffs, sizeof(ctmp0)));
  coeffs += 4;
  wtmp0 = vld1_s16(wave);
  wave += 4;
  accum3 = vmlal_s16(accum3, ctmp3, wtmp3);
 } while(MDFN_LIKELY(--count));

 register int32x4_t tmp = vhaddq_s32(vhaddq_s32(accum0, accum1), vhaddq_s32(accum2, accum3));	// >> 2
 register int32x2_t sum = vhadd_s32(vget_high_s32(tmp), vget_low_s32(tmp));			// >> 1
 register int64x1_t sum64 = vpaddl_s32(sum);
 register int32x2_t sumout = vreinterpret_s32_s64(vshr_n_s64(sum64, TA_NumFractBits - 3));

 vst1_lane_s32(accum_output, sumout, 0);
}

