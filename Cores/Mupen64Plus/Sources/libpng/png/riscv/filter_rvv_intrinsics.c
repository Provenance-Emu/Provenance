/* filter_rvv_intrinsics.c - RISC-V Vector optimized filter functions
 *
 * Copyright (c) 2023 Google LLC
 * Written by Manfred SCHLAEGL, 2022
 *            Dragoș Tiselice <dtiselice@google.com>, May 2023.
 *            Filip Wasil     <f.wasil@samsung.com>, March 2025.
 *
 * This code is released under the libpng license.
 * For conditions of distribution and use, see the disclaimer
 * and license in png.h
 */

#include "../pngpriv.h"

#ifdef PNG_READ_SUPPORTED

#if PNG_RISCV_RVV_IMPLEMENTATION == 1 /* intrinsics code from pngpriv.h */

#include <riscv_vector.h>

void
png_read_filter_row_up_rvv(png_row_infop row_info, png_bytep row,
    png_const_bytep prev_row)
{
   size_t len = row_info->rowbytes;

   for (size_t vl; len > 0; len -= vl, row += vl, prev_row += vl) {
      vl = __riscv_vsetvl_e8m8(len);

      vuint8m8_t prev_vals = __riscv_vle8_v_u8m8(prev_row, vl);
      vuint8m8_t row_vals = __riscv_vle8_v_u8m8(row, vl);

      row_vals = __riscv_vadd_vv_u8m8(row_vals, prev_vals, vl);

      __riscv_vse8_v_u8m8(row, row_vals, vl);
   }
}

static inline void
png_read_filter_row_sub_rvv(size_t len, size_t bpp, unsigned char* row)
{
   png_bytep rp_end = row + len;

   /*
    * row:      | a | x |
    *
    * a = a + x
    *
    * a .. [v0](e8)
    * x .. [v8](e8)
    */

   asm volatile ("vsetvli      zero, %0, e8, m1" : : "r" (bpp));

   /* a = *row */
   asm volatile ("vle8.v       v0, (%0)" : : "r" (row));
   row += bpp;

   while (row < rp_end) {

      /* x = *row */
      asm volatile ("vle8.v       v8, (%0)" : : "r" (row));
      /* a = a + x */
      asm volatile ("vadd.vv      v0, v0, v8");

      /* *row = a */
      asm volatile ("vse8.v       v0, (%0)" : : "r" (row));
      row += bpp;
   }
}

void
png_read_filter_row_sub3_rvv(png_row_infop row_info, png_bytep row,
    png_const_bytep prev_row)
{
   size_t len = row_info->rowbytes;

   png_read_filter_row_sub_rvv(len, 3, row);

   PNG_UNUSED(prev_row)
}

void
png_read_filter_row_sub4_rvv(png_row_infop row_info, png_bytep row,
    png_const_bytep prev_row)
{
   size_t len = row_info->rowbytes;

   png_read_filter_row_sub_rvv(len, 4, row);

   PNG_UNUSED(prev_row)
}

static inline void
png_read_filter_row_avg_rvv(size_t len, size_t bpp, unsigned char* row,
    const unsigned char* prev_row)
{
   png_bytep rp_end = row + len;

   /*
    * row:      | a | x |
    * prev_row: |   | b |
    *
    * a ..   [v2](e8)
    * b ..   [v4](e8)
    * x ..   [v8](e8)
    * tmp .. [v12-v13](e16)
    */

   /* first pixel */

   asm volatile ("vsetvli      zero, %0, e8, m1" : : "r" (bpp));

   /* b = *prev_row */
   asm volatile ("vle8.v       v4, (%0)" : : "r" (prev_row));
   prev_row += bpp;

   /* x = *row */
   asm volatile ("vle8.v       v8, (%0)" : : "r" (row));

   /* b = b / 2 */
   asm volatile ("vsrl.vi      v4, v4, 1");
   /* a = x + b */
   asm volatile ("vadd.vv      v2, v4, v8");

   /* *row = a */
   asm volatile ("vse8.v       v2, (%0)" : : "r" (row));
   row += bpp;

   /* remaining pixels */

   while (row < rp_end) {

      /* b = *prev_row */
      asm volatile ("vle8.v       v4, (%0)" : : "r" (prev_row));
      prev_row += bpp;

      /* x = *row */
      asm volatile ("vle8.v       v8, (%0)" : : "r" (row));

      /* tmp = a + b */
      asm volatile ("vwaddu.vv    v12, v2, v4"); /* add with widening */
      /* a = tmp/2 */
      asm volatile ("vnsrl.wi     v2, v12, 1");  /* divide/shift with narrowing */
      /* a += x */
      asm volatile ("vadd.vv      v2, v2, v8");

      /* *row = a */
      asm volatile ("vse8.v       v2, (%0)" : : "r" (row));
      row += bpp;
   }
}

void
png_read_filter_row_avg3_rvv(png_row_infop row_info, png_bytep row,
    png_const_bytep prev_row)
{
   size_t len = row_info->rowbytes;

   png_read_filter_row_avg_rvv(len, 3, row, prev_row);

   PNG_UNUSED(prev_row)
}

void
png_read_filter_row_avg4_rvv(png_row_infop row_info, png_bytep row,
    png_const_bytep prev_row)
{
   size_t len = row_info->rowbytes;

   png_read_filter_row_avg_rvv(len, 4, row, prev_row);

   PNG_UNUSED(prev_row)
}

#define MIN_CHUNK_LEN 256
#define MAX_CHUNK_LEN 2048

static inline vuint8m1_t
prefix_sum(vuint8m1_t chunk, unsigned char* carry, size_t vl,
    size_t max_chunk_len)
{
   size_t r;

   for (r = 1; r < MIN_CHUNK_LEN; r <<= 1) {
      vbool8_t shift_mask = __riscv_vmsgeu_vx_u8m1_b8(__riscv_vid_v_u8m1(vl), r, vl);
      chunk = __riscv_vadd_vv_u8m1_mu(shift_mask, chunk, chunk, __riscv_vslideup_vx_u8m1(__riscv_vundefined_u8m1(), chunk, r, vl), vl);
   }

   for (r = MIN_CHUNK_LEN; r < MAX_CHUNK_LEN && r < max_chunk_len; r <<= 1) {
      vbool8_t shift_mask = __riscv_vmsgeu_vx_u8m1_b8(__riscv_vid_v_u8m1(vl), r, vl);
      chunk = __riscv_vadd_vv_u8m1_mu(shift_mask, chunk, chunk, __riscv_vslideup_vx_u8m1(__riscv_vundefined_u8m1(), chunk, r, vl), vl);
   }

   chunk = __riscv_vadd_vx_u8m1(chunk, *carry, vl);
   *carry = __riscv_vmv_x_s_u8m1_u8(__riscv_vslidedown_vx_u8m1(chunk, vl - 1, vl));

   return chunk;
}

static inline vint16m1_t
abs_diff(vuint16m1_t a, vuint16m1_t b, size_t vl)
{
   vint16m1_t diff = __riscv_vreinterpret_v_u16m1_i16m1(__riscv_vsub_vv_u16m1(a, b, vl));
   vint16m1_t neg = __riscv_vneg_v_i16m1(diff, vl);

   return __riscv_vmax_vv_i16m1(diff, neg, vl);
}

static inline vint16m1_t
abs_sum(vint16m1_t a, vint16m1_t b, size_t vl)
{
   vint16m1_t sum = __riscv_vadd_vv_i16m1(a, b, vl);
   vint16m1_t neg = __riscv_vneg_v_i16m1(sum, vl);

   return __riscv_vmax_vv_i16m1(sum, neg, vl);
}

static inline void
png_read_filter_row_paeth_rvv(size_t len, size_t bpp, unsigned char* row,
    const unsigned char* prev)
{
   png_bytep rp_end = row + len;

   /*
    * row:      | a | x |
    * prev:     | c | b |
    *
    * mask ..   [v0]
    * a ..      [v2](e8)
    * b ..      [v4](e8)
    * c ..      [v6](e8)
    * x ..      [v8](e8)
    * p ..      [v12-v13](e16)
    * pa ..     [v16-v17](e16)
    * pb ..     [v20-v21](e16)
    * pc ..     [v24-v25](e16)
    * tmpmask ..[v31]
    */

   /* first pixel */

   asm volatile ("vsetvli      zero, %0, e8, m1" : : "r" (bpp));

   /* a = *row + *prev_row */
   asm volatile ("vle8.v       v2, (%0)" : : "r" (row));
   asm volatile ("vle8.v       v6, (%0)" : : "r" (prev));
   prev += bpp;
   asm volatile ("vadd.vv      v2, v2, v6");

   /* *row = a */
   asm volatile ("vse8.v       v2, (%0)" : : "r" (row));
   row += bpp;

   /* remaining pixels */
   while (row < rp_end) {

      /* b = *prev_row */
      asm volatile ("vle8.v       v4, (%0)" : : "r" (prev));
      prev += bpp;

      /* x = *row */
      asm volatile ("vle8.v       v8, (%0)" : : "r" (row));

      /* sub (widening to 16bit) */
      /* p = b - c */
      asm volatile ("vwsubu.vv    v12, v4, v6");
      /* pc = a - c */
      asm volatile ("vwsubu.vv    v24, v2, v6");

      /* switch to widened */
      asm volatile ("vsetvli      zero, %0, e16, m2" : : "r" (bpp));

      /* pa = abs(p) -> pa = p < 0 ? -p : p */
      asm volatile ("vmv.v.v      v16, v12");             /* pa = p */
      asm volatile ("vmslt.vx     v0, v16, zero");        /* set mask[i] if pa[i] < 0 */
      asm volatile ("vrsub.vx     v16, v16, zero, v0.t"); /* invert negative values in pa; vd[i] = 0 - vs2[i] (if mask[i])
                                                           * could be replaced by vneg in rvv >= 1.0
                                                           */

      /* pb = abs(p) -> pb = pc < 0 ? -pc : pc */
      asm volatile ("vmv.v.v      v20, v24");             /* pb = pc */
      asm volatile ("vmslt.vx     v0, v20, zero");        /* set mask[i] if pc[i] < 0 */
      asm volatile ("vrsub.vx     v20, v20, zero, v0.t"); /* invert negative values in pb; vd[i] = 0 - vs2[i] (if mask[i])
                                                           * could be replaced by vneg in rvv >= 1.0
                                                           */

      /* pc = abs(p + pc) -> pc = (p + pc) < 0 ? -(p + pc) : p + pc */
      asm volatile ("vadd.vv      v24, v24, v12");        /* pc = p + pc */
      asm volatile ("vmslt.vx     v0, v24, zero");        /* set mask[i] if pc[i] < 0 */
      asm volatile ("vrsub.vx     v24, v24, zero, v0.t"); /* invert negative values in pc; vd[i] = 0 - vs2[i] (if mask[i])
                                                           * could be replaced by vneg in rvv >= 1.0
                                                           */

      /*
       * if (pb < pa) {
       *   pa = pb;
       *   a = b;   (see (*1))
       * }
       */
      asm volatile ("vmslt.vv     v0, v20, v16");         /* set mask[i] if pb[i] < pa[i] */
      asm volatile ("vmerge.vvm   v16, v16, v20, v0");    /* pa[i] = pb[i] (if mask[i]) */

      /*
       * if (pc < pa)
       *   a = c;   (see (*2))
       */
      asm volatile ("vmslt.vv     v31, v24, v16");        /* set tmpmask[i] if pc[i] < pa[i] */

      /* switch to narrow */
      asm volatile ("vsetvli      zero, %0, e8, m1" : : "r" (bpp));

      /* (*1) */
      asm volatile ("vmerge.vvm   v2, v2, v4, v0");       /* a = b (if mask[i]) */

      /* (*2) */
      asm volatile ("vmand.mm     v0, v31, v31");         /* mask = tmpmask
                                                           * vmand works for rvv 0.7 up to 1.0
                                                           * could be replaced by vmcpy in 0.7.1/0.8.1
                                                           * or vmmv.m in 1.0
                                                           */
      asm volatile ("vmerge.vvm   v2, v2, v6, v0");       /* a = c (if mask[i]) */

      /* a += x */
      asm volatile ("vadd.vv      v2, v2, v8");

      /* *row = a */
      asm volatile ("vse8.v       v2, (%0)" : : "r" (row));
      row += bpp;

      /* prepare next iteration (prev is already in a) */
      /* c = b */
      asm volatile ("vmv.v.v      v6, v4");
   }
}

void
png_read_filter_row_paeth3_rvv(png_row_infop row_info, png_bytep row,
    png_const_bytep prev_row)
{
   size_t len = row_info->rowbytes;

   png_read_filter_row_paeth_rvv(len, 3, row, prev_row);

   PNG_UNUSED(prev_row)
}

void
png_read_filter_row_paeth4_rvv(png_row_infop row_info, png_bytep row,
    png_const_bytep prev_row)
{
   size_t len = row_info->rowbytes;

   png_read_filter_row_paeth_rvv(len, 4, row, prev_row);

   PNG_UNUSED(prev_row)
}

#endif /* PNG_RISCV_RVV_IMPLEMENTATION */
#endif /* READ */
