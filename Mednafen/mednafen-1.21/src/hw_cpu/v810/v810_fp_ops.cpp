/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* v810_fp_ops.cpp:
**  Copyright (C) 2014-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include "v810_fp_ops.h"

bool V810_FP_Ops::fp_is_zero(uint32 v)
{
 return((v & 0x7FFFFFFF) == 0);
}

#if 0
bool V810_FP_Ops::fp_is_nan(uint32 v)
{
 return((v & 0x7FFFFFFF) > (255 << 23));
}

bool V810_FP_Ops::fp_is_inf(uint32 v)
{
 return((v & 0x7FFFFFFF) == (255 << 23));
}
#endif

bool V810_FP_Ops::fp_is_inf_nan_sub(uint32 v)
{
 if((v & 0x7FFFFFFF) == 0)
  return(false);

 switch((v >> 23) & 0xFF)
 {
  case 0x00:
  case 0xff:
	return(true);
 }
 return(false);
}

void V810_FP_Ops::fpim_decode(fpim* df, uint32 v)
{
 df->exp = ((v >> 23) & 0xFF) - 127;
 df->f = (v & 0x7FFFFF) | ((v & 0x7FFFFFFF) ? 0x800000 : 0);
 df->sign = v >> 31;
}

void V810_FP_Ops::fpim_round(fpim* df)
{
 int vbc = 64 - MDFN_lzcount64(df->f);

 if(vbc > 24)
 {
  const unsigned sa = vbc - 24;

  if(1) // round to nearest
  {
   uint64 old_f = df->f;

   df->f = (df->f + ((df->f >> sa) & 1) + ((1ULL << (sa - 1)) - 1)) & ~((1ULL << sa) - 1);

   if(df->f != old_f)
   {
    //printf("Inexact mr\n");
    exception_flags |= flag_inexact;
   }
  }
  else
   abort();
 }
}

void V810_FP_Ops::fpim_round_int(fpim* df, bool truncate)
{
 if(df->exp < 23)
 {
  const unsigned sa = 23 - df->exp;
  uint64 old_f = df->f;

  //if(sa >= 2)
  // printf("RI: %lld, %d\n", df->f, sa);

  // round to nearest
  if(sa > 24)
   df->f = 0;
  else
  {
   if(truncate)
    df->f = df->f & ~((1ULL << sa) - 1);
   else
    df->f = (df->f + ((df->f >> sa) & 1) + ((1ULL << (sa - 1)) - 1)) & ~((1ULL << sa) - 1);
  }

  if(df->f != old_f)
  {
   //printf("Inexact\n");
   exception_flags |= flag_inexact;
  }
 }
}

uint32 V810_FP_Ops::fpim_encode(fpim* df)
{
 const int lzc = MDFN_lzcount64(df->f);
 int tmp_exp = df->exp - lzc;
 uint64 tmp_walrus = df->f << (lzc & 0x3F);
 int tmp_sign = df->sign;

 tmp_exp += 40;
 tmp_walrus >>= 40;

 if(tmp_walrus == 0)
  tmp_exp = -127;
 else if(tmp_exp <= -127)
 {
  exception_flags |= flag_underflow | flag_inexact;
  //printf("Subnormal: %lld. %d\n", tmp_walrus, tmp_exp);
  if(1)
  {
   tmp_exp = -127;
   tmp_walrus = 0;
  }
  else
  {
   tmp_walrus >>= -(tmp_exp + 126);
   tmp_exp = -127;
  }
 }
 else if(tmp_exp >= 128)
 {
  exception_flags |= flag_overflow;
  //printf("Overflow!\n");

  if(1)
   tmp_exp -= 192;
  else
  {
   tmp_exp = 128;
   tmp_walrus = 0;
  }

 }
 return (tmp_sign << 31) | ((tmp_exp + 127) << 23) | (tmp_walrus & 0x7FFFFF);
}

uint32 V810_FP_Ops::mul(uint32 a, uint32 b)
{
 fpim ins[2];
 fpim res;

 if(fp_is_inf_nan_sub(a) || fp_is_inf_nan_sub(b))
 {
  exception_flags |= flag_reserved;
  return(~0U);
 }

 fpim_decode(&ins[0], a);
 fpim_decode(&ins[1], b);

 //printf("%08x %08x - %d %d %d - %d %d %d\n", a, b, a_exp, a_walrus, a_sign, b_exp, b_walrus, b_sign);

 res.exp = ins[0].exp + ins[1].exp - 23;
 res.f = ins[0].f * ins[1].f;
 res.sign = ins[0].sign ^ ins[1].sign;

 fpim_round(&res);

 return fpim_encode(&res);
}

uint32 V810_FP_Ops::add(uint32 a, uint32 b)
{
 fpim ins[2];
 fpim res;
 int64 ft[2];
 int64 tr;
 int max_exp;

 if(fp_is_inf_nan_sub(a) || fp_is_inf_nan_sub(b))
 {
  exception_flags |= flag_reserved;
  return(~0U);
 }

 if(a == b && !(a & 0x7FFFFFFF))
 {
  return(a & 0x80000000);
 }

 fpim_decode(&ins[0], a);
 fpim_decode(&ins[1], b);

 max_exp = std::max<int>(ins[0].exp, ins[1].exp);

 //printf("%d:%08llx %d:%08llx\n", ins[0].exp, ins[0].f, ins[1].exp, ins[1].f);

 for(unsigned i = 0; i < 2; i++)
 {
  unsigned sd = (max_exp - ins[i].exp);

  ft[i] = ins[i].f << 24;

  if(sd >= 48)
  {
   if(ft[i] != 0)
    ft[i] = 1;
  }
  else
  {
   int64 nft = ft[i] >> sd;

   if(ft[i] != (nft << sd))
   {
    nft |= 1;
   }
   //{
   // puts("FPR");
  // }

   ft[i] = nft;
  }

  if(ins[i].sign)
   ft[i] = -ft[i];
 }

 //printf("SOON: %08llx %08llx\n", ft[0], ft[1]);

 tr = ft[0] + ft[1];
 if(tr < 0)
 {
  tr = -tr;
  res.sign = true;
 }
 else
  res.sign = false;

 res.f = tr;
 res.exp = max_exp - 24;

 fpim_round(&res);

 return fpim_encode(&res);
}

uint32 V810_FP_Ops::sub(uint32 a, uint32 b)
{
 return add(a, b ^ 0x80000000);
}

uint32 V810_FP_Ops::div(uint32 a, uint32 b)
{
 fpim ins[2];
 fpim res;
 uint64 mtmp;

 if(fp_is_inf_nan_sub(a) || fp_is_inf_nan_sub(b))
 {
  exception_flags |= flag_reserved;
  return(~0U);
 }

 if(fp_is_zero(a) && fp_is_zero(b))
 {
  exception_flags |= flag_invalid;
  return(~0U);
 }

 fpim_decode(&ins[0], a);
 fpim_decode(&ins[1], b);

 res.sign = ins[0].sign ^ ins[1].sign;

 if(ins[1].f == 0)
 {
  //puts("Divide by zero!");
  exception_flags |= flag_divbyzero;
  return((res.sign << 31) | (255 << 23));
 }
 else
 {
  res.exp = ins[0].exp - ins[1].exp - 2 - 1; // + 23 - 2;
  res.f = ((ins[0].f << 24) / ins[1].f) << 2;
  mtmp = ((ins[0].f << 24) % ins[1].f) << 1;

  //printf("%lld %lld\n", (ins[0].f << 23) % ins[1].f, ins[1].f);

  if(mtmp > ins[1].f)
   res.f |= 3;
  else if(mtmp == ins[1].f)
   res.f |= 2;
  else if(mtmp > 0)
   res.f |= 1;
 }

 fpim_round(&res);

 return fpim_encode(&res);
}

int V810_FP_Ops::cmp(uint32 a, uint32 b)
{
 fpim ins[2];

 if(fp_is_inf_nan_sub(a) || fp_is_inf_nan_sub(b))
 {
  exception_flags |= flag_reserved;
  return(~0U);
 }

 fpim_decode(&ins[0], a);
 fpim_decode(&ins[1], b);

 if(ins[0].exp > ins[1].exp)
  return(ins[0].sign ? -1 : 1);

 if(ins[0].exp < ins[1].exp)
  return(ins[1].sign ? 1 : -1);

 if(ins[0].f > ins[1].f)
  return(ins[0].sign ? -1 : 1);

 if(ins[0].f < ins[1].f)
  return(ins[1].sign ? 1 : -1);

 if((ins[0].sign ^ ins[1].sign) && ins[0].f != 0)
  return(ins[0].sign ? -1 : 1);

 return(0);
}

uint32 V810_FP_Ops::itof(uint32 v)
{
 fpim res;

 res.sign = (bool)(v & 0x80000000);
 res.exp = 23;
 res.f = res.sign ? (0x80000000 - (v & 0x7FFFFFFF)) : (v & 0x7FFFFFFF);

 fpim_round(&res);

 return fpim_encode(&res);
}


uint32 V810_FP_Ops::ftoi(uint32 v, bool truncate)
{
 fpim ins;
 int sa;
 int ret;

 if(fp_is_inf_nan_sub(v))
 {
  exception_flags |= flag_reserved;
  return(~0U);
 }

 fpim_decode(&ins, v);
 fpim_round_int(&ins, truncate);

 sa = ins.exp - 23;

 if(sa < 0)
 {
  if(sa <= -32)
   ret = 0;
  else
   ret = ins.f >> -sa;
 }
 else
 {
  if(sa >= 8)
  {
   if(sa == 8 && ins.f == 0x800000 && ins.sign)
    return(0x80000000);
   else
   {
    ret = ~0U;
    exception_flags |= flag_invalid;
   }
  }
  else
  {
   ret = ins.f << sa;
  }
 }
 //printf("%d\n", sa);

 if(ins.sign)
  ret = -ret;

 return(ret);
}

