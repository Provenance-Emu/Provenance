template<unsigned TA_NumFractBits>
static INLINE void DoMAC(const int16* wave, const int16* coeffs, int32 count, int32* accum_output)
{
 static_assert(TA_NumFractBits >= (3 + 1), "TA_NumFractBits too small.");
 int32 acc0[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
 int32 acc1[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
 int c;

 for(c = 0; c < (count >> 1); c += 8)
 {
  acc0[0] += ((int32)wave[c + 0] * coeffs[c + 0]);
  acc0[1] += ((int32)wave[c + 1] * coeffs[c + 1]);
  acc0[2] += ((int32)wave[c + 2] * coeffs[c + 2]);
  acc0[3] += ((int32)wave[c + 3] * coeffs[c + 3]);
  acc0[4] += ((int32)wave[c + 4] * coeffs[c + 4]);
  acc0[5] += ((int32)wave[c + 5] * coeffs[c + 5]);
  acc0[6] += ((int32)wave[c + 6] * coeffs[c + 6]);
  acc0[7] += ((int32)wave[c + 7] * coeffs[c + 7]);
 }

 acc0[0] >>= 3 + 1;
 acc0[1] >>= 3 + 1;
 acc0[2] >>= 3 + 1;
 acc0[3] >>= 3 + 1;
 acc0[4] >>= 3 + 1;
 acc0[5] >>= 3 + 1;
 acc0[6] >>= 3 + 1;
 acc0[7] >>= 3 + 1;


 for(; c < count; c += 8)
 {
  acc1[0] += ((int32)wave[c + 0] * coeffs[c + 0]);
  acc1[1] += ((int32)wave[c + 1] * coeffs[c + 1]);
  acc1[2] += ((int32)wave[c + 2] * coeffs[c + 2]);
  acc1[3] += ((int32)wave[c + 3] * coeffs[c + 3]);
  acc1[4] += ((int32)wave[c + 4] * coeffs[c + 4]);
  acc1[5] += ((int32)wave[c + 5] * coeffs[c + 5]);
  acc1[6] += ((int32)wave[c + 6] * coeffs[c + 6]);
  acc1[7] += ((int32)wave[c + 7] * coeffs[c + 7]);
 }

 acc1[0] >>= 3 + 1;
 acc1[1] >>= 3 + 1;
 acc1[2] >>= 3 + 1;
 acc1[3] >>= 3 + 1;
 acc1[4] >>= 3 + 1;
 acc1[5] >>= 3 + 1;
 acc1[6] >>= 3 + 1;
 acc1[7] >>= 3 + 1;

 *accum_output = (acc0[0] + acc0[1] + acc0[2] + acc0[3] + acc0[4] + acc0[5] + acc0[6] + acc0[7] +
		  acc1[0] + acc1[1] + acc1[2] + acc1[3] + acc1[4] + acc1[5] + acc1[6] + acc1[7]) >> (TA_NumFractBits - (3 + 1));
}

