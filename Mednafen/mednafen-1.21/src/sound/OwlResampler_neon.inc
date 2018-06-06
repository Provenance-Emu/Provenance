//
//
//
static INLINE void DoMAC_NEON(float* wave, float* coeffs, int32 count, int32* accum_output)
{
 register float32x4_t acc0, acc1, acc2, acc3;

 acc0 = acc1 = acc2 = acc3 = vdupq_n_f32(0);

 count >>= 4;

 do
 {
  acc0 = vmlaq_f32(acc0, vld1q_f32(MDFN_ASSUME_ALIGNED(coeffs +  0, sizeof(float32x4_t))), vld1q_f32(wave +  0));
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

 vst1_lane_s32(accum_output, vcvt_s32_f32(sum2), 0);
}

