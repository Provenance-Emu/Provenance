template<unsigned TA_NumFractBits>
static INLINE void DoMAC_AltiVec(const int16 *wave, const int16 *coeffs, int32 count, int32 *accum_output)
{
	  static_assert(TA_NumFractBits >= (3 + 1), "TA_NumFractBits too small.");
          vector signed int acc0, acc1, acc2, acc3;
	  vector unsigned int vecsrEBp1 = vec_splats((unsigned int)3 + 1);
	  vector unsigned int vecsr16m1 = vec_splats((unsigned int)TA_NumFractBits - (3 + 1));
          vector signed int zerosi = vec_splat_s32(0);
          vector signed short wd0, fd0;
          vector signed short wd1, fd1;
	  vector signed int tmp;
	  int32 ino;

#if 0
	  {
	   const uint8 blocksize = 1 * sizeof(int16);
	   const uint8 blockcount = (count + 15) / 16;
	   const int16 blockstride = blocksize;

	   vec_dstt(coeffs, (blocksize << 3) | (blockcount << 8) | (blockstride << 16), 0);
	  }
#endif

          acc0 = zerosi;
	  acc1 = zerosi;
	  acc2 = zerosi;
	  acc3 = zerosi;

          for(ino = 0; ino < count; ino += (16 << 1))
          {
           wd0 = vec_ld(ino, wave);
           fd0 = vec_ld(ino, coeffs);
           acc0 = vec_msums(wd0, fd0, acc0);

           wd1 = vec_ld(ino + (8 << 1), wave);
           fd1 = vec_ld(ino + (8 << 1), coeffs);
           acc1 = vec_msums(wd1, fd1, acc1);
          }

          acc0 = vec_sra(acc0, vecsrEBp1);
          acc1 = vec_sra(acc1, vecsrEBp1);

          for(; ino < (count << 1); ino += (16 << 1))
          {
           wd0 = vec_ld(ino, wave);
           fd0 = vec_ld(ino, coeffs);
           acc2 = vec_msums(wd0, fd0, acc2);

           wd1 = vec_ld(ino + (8 << 1), wave);
           fd1 = vec_ld(ino + (8 << 1), coeffs);
           acc3 = vec_msums(wd1, fd1, acc3);
          }

	  acc2 = vec_sra(acc2, vecsrEBp1);
	  acc3 = vec_sra(acc3, vecsrEBp1);

	  //
	  //
	  tmp = vec_add(vec_add(acc0, acc2), vec_add(acc1, acc3));
	  tmp = vec_splat(vec_sums(tmp, zerosi), 3);
	  tmp = vec_sra(tmp, vecsr16m1);

	  vec_ste(tmp, 0, accum_output);
}

