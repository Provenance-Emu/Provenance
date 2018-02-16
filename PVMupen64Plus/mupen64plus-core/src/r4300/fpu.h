/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - fpu.h                                                   *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
 *   Copyright (C) 2010 Ari64                                              *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef M64P_R4300_FPU_H
#define M64P_R4300_FPU_H

#include <math.h>
#include <stdint.h>

#include "cp1_private.h"
#include "r4300.h"

#ifdef _MSC_VER
  #define M64P_FPU_INLINE static __inline
  #include <float.h>

  typedef enum { FE_TONEAREST = 0, FE_TOWARDZERO, FE_UPWARD, FE_DOWNWARD } eRoundType;
  static void fesetround(eRoundType RoundType)
  {
    static const unsigned int msRound[4] = { _RC_NEAR, _RC_CHOP, _RC_UP, _RC_DOWN };
    unsigned int oldX87, oldSSE2;
    __control87_2(msRound[RoundType], _MCW_RC, &oldX87, &oldSSE2);
  }
  static __inline double round(double x) { return floor(x + 0.5); }
  static __inline float roundf(float x) { return (float) floor(x + 0.5); }
  static __inline double trunc(double x) { return (double) (int) x; }
  static __inline float truncf(float x) { return (float) (int) x; }
  #define isnan _isnan
#else
  #define M64P_FPU_INLINE static inline
  #include <fenv.h>
#endif

#define FCR31_CMP_BIT UINT32_C(0x800000)


M64P_FPU_INLINE void set_rounding(void)
{
  switch(FCR31 & 3) {
  case 0: /* Round to nearest, or to even if equidistant */
    fesetround(FE_TONEAREST);
    break;
  case 1: /* Truncate (toward 0) */
    fesetround(FE_TOWARDZERO);
    break;
  case 2: /* Round up (toward +Inf) */
    fesetround(FE_UPWARD);
    break;
  case 3: /* Round down (toward -Inf) */
    fesetround(FE_DOWNWARD);
    break;
  }
}

M64P_FPU_INLINE void cvt_s_w(const int32_t *source,float *dest)
{
  set_rounding();
  *dest = (float) *source;
}
M64P_FPU_INLINE void cvt_d_w(const int32_t *source,double *dest)
{
  *dest = (double) *source;
}
M64P_FPU_INLINE void cvt_s_l(const int64_t *source,float *dest)
{
  set_rounding();
  *dest = (float) *source;
}
M64P_FPU_INLINE void cvt_d_l(const int64_t *source,double *dest)
{
  set_rounding();
  *dest = (double) *source;
}
M64P_FPU_INLINE void cvt_d_s(const float *source,double *dest)
{
  *dest = (double) *source;
}
M64P_FPU_INLINE void cvt_s_d(const double *source,float *dest)
{
  set_rounding();
  *dest = (float) *source;
}

M64P_FPU_INLINE void round_l_s(const float *source,int64_t *dest)
{
  *dest = (int64_t) roundf(*source);
}
M64P_FPU_INLINE void round_w_s(const float *source,int32_t *dest)
{
  *dest = (int32_t) roundf(*source);
}
M64P_FPU_INLINE void trunc_l_s(const float *source,int64_t *dest)
{
  *dest = (int64_t) truncf(*source);
}
M64P_FPU_INLINE void trunc_w_s(const float *source,int32_t *dest)
{
  *dest = (int32_t) truncf(*source);
}
M64P_FPU_INLINE void ceil_l_s(const float *source,int64_t *dest)
{
  *dest = (int64_t) ceilf(*source);
}
M64P_FPU_INLINE void ceil_w_s(const float *source,int32_t *dest)
{
  *dest = (int32_t) ceilf(*source);
}
M64P_FPU_INLINE void floor_l_s(const float *source,int64_t *dest)
{
  *dest = (int64_t) floorf(*source);
}
M64P_FPU_INLINE void floor_w_s(const float *source,int32_t *dest)
{
  *dest = (int32_t) floorf(*source);
}

M64P_FPU_INLINE void round_l_d(const double *source,int64_t *dest)
{
  *dest = (int64_t) round(*source);
}
M64P_FPU_INLINE void round_w_d(const double *source,int32_t *dest)
{
  *dest = (int32_t) round(*source);
}
M64P_FPU_INLINE void trunc_l_d(const double *source,int64_t *dest)
{
  *dest = (int64_t) trunc(*source);
}
M64P_FPU_INLINE void trunc_w_d(const double *source,int32_t *dest)
{
  *dest = (int32_t) trunc(*source);
}
M64P_FPU_INLINE void ceil_l_d(const double *source,int64_t *dest)
{
  *dest = (int64_t) ceil(*source);
}
M64P_FPU_INLINE void ceil_w_d(const double *source,int32_t *dest)
{
  *dest = (int32_t) ceil(*source);
}
M64P_FPU_INLINE void floor_l_d(const double *source,int64_t *dest)
{
  *dest = (int64_t) floor(*source);
}
M64P_FPU_INLINE void floor_w_d(const double *source,int32_t *dest)
{
  *dest = (int32_t) floor(*source);
}

M64P_FPU_INLINE void cvt_w_s(const float *source,int32_t *dest)
{
  switch(FCR31&3)
  {
    case 0: round_w_s(source,dest);return;
    case 1: trunc_w_s(source,dest);return;
    case 2: ceil_w_s(source,dest);return;
    case 3: floor_w_s(source,dest);return;
  }
}
M64P_FPU_INLINE void cvt_w_d(const double *source,int32_t *dest)
{
  switch(FCR31&3)
  {
    case 0: round_w_d(source,dest);return;
    case 1: trunc_w_d(source,dest);return;
    case 2: ceil_w_d(source,dest);return;
    case 3: floor_w_d(source,dest);return;
  }
}
M64P_FPU_INLINE void cvt_l_s(const float *source,int64_t *dest)
{
  switch(FCR31&3)
  {
    case 0: round_l_s(source,dest);return;
    case 1: trunc_l_s(source,dest);return;
    case 2: ceil_l_s(source,dest);return;
    case 3: floor_l_s(source,dest);return;
  }
}
M64P_FPU_INLINE void cvt_l_d(const double *source,int64_t *dest)
{
  switch(FCR31&3)
  {
    case 0: round_l_d(source,dest);return;
    case 1: trunc_l_d(source,dest);return;
    case 2: ceil_l_d(source,dest);return;
    case 3: floor_l_d(source,dest);return;
  }
}

M64P_FPU_INLINE void c_f_s()
{
  FCR31 &= ~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_un_s(const float *source,const float *target)
{
  FCR31=(isnan(*source) || isnan(*target)) ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
                          
M64P_FPU_INLINE void c_eq_s(const float *source,const float *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31&=~FCR31_CMP_BIT;return;}
  FCR31 = *source==*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ueq_s(const float *source,const float *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31|=FCR31_CMP_BIT;return;}
  FCR31 = *source==*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_olt_s(const float *source,const float *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31&=~FCR31_CMP_BIT;return;}
  FCR31 = *source<*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ult_s(const float *source,const float *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31|=FCR31_CMP_BIT;return;}
  FCR31 = *source<*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_ole_s(const float *source,const float *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31&=~FCR31_CMP_BIT;return;}
  FCR31 = *source<=*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ule_s(const float *source,const float *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31|=FCR31_CMP_BIT;return;}
  FCR31 = *source<=*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_sf_s(const float *source,const float *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31&=~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ngle_s(const float *source,const float *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31&=~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_seq_s(const float *source,const float *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source==*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ngl_s(const float *source,const float *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source==*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_lt_s(const float *source,const float *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source<*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_nge_s(const float *source,const float *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source<*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_le_s(const float *source,const float *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source<=*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ngt_s(const float *source,const float *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source<=*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_f_d()
{
  FCR31 &= ~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_un_d(const double *source,const double *target)
{
  FCR31=(isnan(*source) || isnan(*target)) ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
                          
M64P_FPU_INLINE void c_eq_d(const double *source,const double *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31&=~FCR31_CMP_BIT;return;}
  FCR31 = *source==*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ueq_d(const double *source,const double *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31|=FCR31_CMP_BIT;return;}
  FCR31 = *source==*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_olt_d(const double *source,const double *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31&=~FCR31_CMP_BIT;return;}
  FCR31 = *source<*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ult_d(const double *source,const double *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31|=FCR31_CMP_BIT;return;}
  FCR31 = *source<*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_ole_d(const double *source,const double *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31&=~FCR31_CMP_BIT;return;}
  FCR31 = *source<=*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ule_d(const double *source,const double *target)
{
  if (isnan(*source) || isnan(*target)) {FCR31|=FCR31_CMP_BIT;return;}
  FCR31 = *source<=*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_sf_d(const double *source,const double *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31&=~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ngle_d(const double *source,const double *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31&=~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_seq_d(const double *source,const double *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source==*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ngl_d(const double *source,const double *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source==*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_lt_d(const double *source,const double *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source<*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_nge_d(const double *source,const double *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source<*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}

M64P_FPU_INLINE void c_le_d(const double *source,const double *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source<=*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}
M64P_FPU_INLINE void c_ngt_d(const double *source,const double *target)
{
  //if (isnan(*source) || isnan(*target)) // FIXME - exception
  FCR31 = *source<=*target ? FCR31|FCR31_CMP_BIT : FCR31&~FCR31_CMP_BIT;
}


M64P_FPU_INLINE void add_s(const float *source1,const float *source2,float *target)
{
  set_rounding();
  *target=(*source1)+(*source2);
}
M64P_FPU_INLINE void sub_s(const float *source1,const float *source2,float *target)
{
  set_rounding();
  *target=(*source1)-(*source2);
}
M64P_FPU_INLINE void mul_s(const float *source1,const float *source2,float *target)
{
  set_rounding();
  *target=(*source1)*(*source2);
}
M64P_FPU_INLINE void div_s(const float *source1,const float *source2,float *target)
{
  set_rounding();
  *target=(*source1)/(*source2);
}
M64P_FPU_INLINE void sqrt_s(const float *source,float *target)
{
  set_rounding();
  *target=sqrtf(*source);
}
M64P_FPU_INLINE void abs_s(const float *source,float *target)
{
  *target=fabsf(*source);
}
M64P_FPU_INLINE void mov_s(const float *source,float *target)
{
  *target=*source;
}
M64P_FPU_INLINE void neg_s(const float *source,float *target)
{
  *target=-(*source);
}
M64P_FPU_INLINE void add_d(const double *source1,const double *source2,double *target)
{
  set_rounding();
  *target=(*source1)+(*source2);
}
M64P_FPU_INLINE void sub_d(const double *source1,const double *source2,double *target)
{
  set_rounding();
  *target=(*source1)-(*source2);
}
M64P_FPU_INLINE void mul_d(const double *source1,const double *source2,double *target)
{
  set_rounding();
  *target=(*source1)*(*source2);
}
M64P_FPU_INLINE void div_d(const double *source1,const double *source2,double *target)
{
  set_rounding();
  *target=(*source1)/(*source2);
}
M64P_FPU_INLINE void sqrt_d(const double *source,double *target)
{
  set_rounding();
  *target=sqrt(*source);
}
M64P_FPU_INLINE void abs_d(const double *source,double *target)
{
  *target=fabs(*source);
}
M64P_FPU_INLINE void mov_d(const double *source,double *target)
{
  *target=*source;
}
M64P_FPU_INLINE void neg_d(const double *source,double *target)
{
  *target=-(*source);
}

#endif /* M64P_R4300_FPU_H */
