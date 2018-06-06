//
//
//
static INLINE void DoMAC_AltiVec(float* wave, float* coeffs, int32 count, int32* accum_output)
{
 register vector float acc0, acc1, acc2, acc3;

 acc0 = (vector float)vec_splat_u8(0);
 acc1 = acc0;
 acc2 = acc0;
 acc3 = acc0;


 count >>= 4;

 if(!((uint64)wave & 0xF))
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
  vector signed int sum_i;

  sum = vec_add(vec_add(acc0, acc1), vec_add(acc2, acc3));
  sums0 = vec_sld(sum, sum, 8);
  sum = vec_add(sum, sums0);
  sums0 = vec_sld(sum, sum, 4);
  sum = vec_add(sum, sums0);

  sum_i = vec_cts(sum, 0);
  vec_ste(sum_i, 0, accum_output);
 }
}

