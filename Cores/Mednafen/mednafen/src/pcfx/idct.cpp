/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* idct.cpp:
**  Copyright (C) 2019 Mednafen Team
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

/* References:
	'Practical Fast 1-D DCT Algorithms With 11 Multiplications', 1989, by
	Christoph Loeffler, Adriaan Ligtenberg, and George S. Moschytz
*/

#include <mednafen/types.h>
#include "idct.h"

namespace MDFN_IEN_PCFX
{

#if 0
static NO_INLINE void NF_IDCT_1D(float* c, float* o)
{
 #define SNORP(a0, a1) { float tmp = (c[a0] + c[a1]); c[a1] = (c[a0] - c[a1]); c[a0] = tmp; }
 float r[2];
 SNORP(7, 1)
 r[0] = c[5] * 1.4142135623730951;
 r[1] = c[3] * 1.4142135623730951;
 c[3] = r[0];
 c[5] = r[1];

 //
 //
 //
 r[0] = c[2] *  0.5411961001461970 + c[6] * -1.3065629648763766;
 r[1] = c[2] *  1.3065629648763766 + c[6] *  0.5411961001461970;
 c[2] = r[0];
 c[6] = r[1];
 SNORP(7, 5)
 SNORP(3, 1)
 SNORP(0, 4)
 //
 //
 //
 r[0] = c[7] * -0.5555702330196022 + c[1] *  0.8314696123025452;
 r[1] = c[7] *  0.8314696123025452 + c[1] *  0.5555702330196022;
 c[7] = r[0];
 c[1] = r[1];
 r[0] = c[3] *  0.1950903220161282 + c[5] *  0.9807852804032304;
 r[1] = c[3] * -0.9807852804032304 + c[5] *  0.1950903220161282;
 c[3] = r[0];
 c[5] = r[1];
 SNORP(0, 6)
 SNORP(4, 2)
 //
 //
 //
 o[0 * 8] = (c[0] + c[1]);
 o[1 * 8] = (c[4] + c[5]);
 o[2 * 8] = (c[2] + c[3]);
 o[3 * 8] = (c[6] + c[7]);
 o[4 * 8] = (c[6] - c[7]);
 o[5 * 8] = (c[2] - c[3]);
 o[6 * 8] = (c[4] - c[5]);
 o[7 * 8] = (c[0] - c[1]);
 #undef SNORP
}

static INLINE void NF_IDCT(float* c)
{
 float buf[64];

 for(unsigned i = 0; i < 8; i++)
  NF_IDCT_1D(&c[i * 8], &buf[i]);

 for(unsigned i = 0; i < 8; i++)
  NF_IDCT_1D(&buf[i * 8], &c[i]);

 for(unsigned i = 0; i < 64; i++)
  c[i] /= 2;
}
#endif

//#define IDCT_ACCURACY_TEST 1

enum : unsigned { IDCT_PRESHIFT = 9 };
#define EFF_RSHIFT_1D_COEFF	2	// Must be >= 2
#define EFF_RSHIFT_1D_POST	6
#define EFF_RSHIFT_2D ((EFF_RSHIFT_1D_COEFF) * 2 + EFF_RSHIFT_1D_POST - 1)	// -1 is from sqrt(2) * sqrt(2)
#define C_COEFF(m) ((int32)((1LL << (32 - EFF_RSHIFT_1D_COEFF)) * (m) + 0.5))

#define SNORP(a0, a1) { int32 tmp = (c[a0] + c[a1]); c[a1] = (c[a0] - c[a1]); c[a0] = tmp; }

#if 0
static INLINE int32 MUL_32x32_H32(int32 c, int32 v)
{
 int32 ret;

 asm("mulhw %0, %1, %2\n\t" : "=r"(ret) : "r"(c), "r"(v));

 return ret;
 //return ((int64)v * c) >> 32;
}
#else
static INLINE int32 MUL_32x32_H32(const int32& c, int32 v)
{
#if 0
 int32 ret, dummy;

 asm("imull %3\n\t"
	: "=d"(ret), "=a"(dummy)
	: "a"(v), "m"(c)
	: "cc");
 return ret;
#else
 return ((int64)v * c) >> 32;
#endif
}
#endif

template<unsigned psh>
static INLINE void IDCT_1D(int32* __restrict__ c_in, int32* __restrict__ o)
{
 static const int32 coeffs[10] =
 {
  1779033704,

  C_COEFF( 0.5411961001461970), 
  C_COEFF(-1.8477590650225736),
  C_COEFF( 0.7653668647301796),

  C_COEFF(-0.5555702330196022),
  C_COEFF( 1.3870398453221474),
  C_COEFF( 0.2758993792829430),

  C_COEFF( 0.1950903220161282),
  C_COEFF( 0.7856949583871022),
  C_COEFF(-1.1758756024193586),
 };
 int32 c[8];
 int32 r;
 int32 m;

 if(!psh)
 {
  c[0] = c_in[0] << (IDCT_PRESHIFT - EFF_RSHIFT_1D_COEFF); 
  c[4] = c_in[4] << (IDCT_PRESHIFT - EFF_RSHIFT_1D_COEFF);

  c[7] = (c_in[7] + c_in[1]) << IDCT_PRESHIFT;
  c[1] = (c_in[7] - c_in[1]) << IDCT_PRESHIFT;

  c[3] = (46341 * c_in[5]) >> (15 - IDCT_PRESHIFT);
  c[5] = (46341 * c_in[3]) >> (15 - IDCT_PRESHIFT);
  //
  //
  //
  //C_COEFF( 0.5411961001461970), 
  //C_COEFF(-1.8477590650225736),
  //C_COEFF( 0.7653668647301796),
  m = 35468 * (c_in[2] + c_in[6]);
  c[2] = (-121095 * c_in[6] + m) >> (16 - IDCT_PRESHIFT + EFF_RSHIFT_1D_COEFF);
  c[6] = (  50159 * c_in[2] + m) >> (16 - IDCT_PRESHIFT + EFF_RSHIFT_1D_COEFF);
/*
  c_in[2] <<= IDCT_PRESHIFT;
  c_in[6] <<= IDCT_PRESHIFT;
  m = MUL_32x32_H32(coeffs[1], (c_in[2] + c_in[6]));
  c[2] = MUL_32x32_H32(coeffs[2], c_in[6]) + m;
  c[6] = MUL_32x32_H32(coeffs[3], c_in[2]) + m;
*/
 }
 else
 {
  c[0] = (c_in[0] >> EFF_RSHIFT_1D_COEFF) + ((1 << psh) >> 1);
  c[4] = c_in[4] >> EFF_RSHIFT_1D_COEFF;

  c[7] = c_in[7] + c_in[1];
  c[1] = c_in[7] - c_in[1];

  //c[3] = c_in[5] + MUL_32x32_H32(coeffs[0], c_in[5]);
  //c[5] = c_in[3] + MUL_32x32_H32(coeffs[0], c_in[3]);
  //c[3] = c_in[5] + ((13572 * c_in[5]) >> 15);
  //c[5] = c_in[3] + ((13572 * c_in[3]) >> 15);
  c[3] = (c_in[5] * 181) >> 7;
  c[5] = (c_in[3] * 181) >> 7;
/*
  //c[3] = (c_in[5] * 181 + 64) >> 7;
  //c[5] = (c_in[3] * 181 + 64) >> 7;
  //
  //
  //
*/
  m = MUL_32x32_H32(coeffs[1], (c_in[2] + c_in[6]));
  c[2] = MUL_32x32_H32(coeffs[2], c_in[6]) + m;
  c[6] = MUL_32x32_H32(coeffs[3], c_in[2]) + m;

  //c[3] = (46341 * c_in[5]) >> (15 + EFF_RSHIFT_1D_COEFF);
  //c[5] = (46341 * c_in[3]) >> (15 + EFF_RSHIFT_1D_COEFF);
  //
  //
  //
  //C_COEFF( 0.5411961001461970), 
  //C_COEFF(-1.8477590650225736),
  //C_COEFF( 0.7653668647301796),
  //m = 35468 * (c_in[2] + c_in[6]);
  //c[2] = (-121095 * c_in[6] + m) >> (16 + EFF_RSHIFT_1D_COEFF);
  //c[6] = (  50159 * c_in[2] + m) >> (16 + EFF_RSHIFT_1D_COEFF);
 }
 SNORP(0, 4)
 SNORP(7, 5)
 SNORP(3, 1)
 //
 //
 //
 m = MUL_32x32_H32(coeffs[4], (c[7] + c[1]));
 r    = MUL_32x32_H32(coeffs[5], c[1]) + m;
 c[1] = MUL_32x32_H32(coeffs[6], c[7]) - m;
 //c[1] = ((565LL * c[7]) >> 13) - m;
 c[7] = r;
 //
 //
 //
 //m = (799 * (c[3] + c[5])) >> (12 + EFF_RSHIFT_1D_COEFF); 
 m = MUL_32x32_H32(coeffs[7], (c[3] + c[5]));
 r    = MUL_32x32_H32(coeffs[8], c[5]) + m;
 c[5] = MUL_32x32_H32(coeffs[9], c[3]) + m;
 c[3] = r;

 SNORP(0, 6)
 SNORP(4, 2)
 //
 //
 //
 o[0 * 8] = (c[0] + c[1]) >> psh;
 o[1 * 8] = (c[4] + c[5]) >> psh;
 o[2 * 8] = (c[2] + c[3]) >> psh;
 o[3 * 8] = (c[6] + c[7]) >> psh;
 o[4 * 8] = (c[6] - c[7]) >> psh;
 o[5 * 8] = (c[2] - c[3]) >> psh;
 o[6 * 8] = (c[4] - c[5]) >> psh;
 o[7 * 8] = (c[0] - c[1]) >> psh;
}

template<unsigned psh>
static INLINE void IDCT_1D_Multi(int32* __restrict__ c, int32* __restrict__ o)
{
 for(unsigned i = 0; i < 8; i++)
  IDCT_1D<psh>(&c[i * 8], &o[i]);
}

void IDCT(int32* c)
{
 int32 buf[64];

 static_assert(IDCT_PRESHIFT == EFF_RSHIFT_2D, "IDCT_PRESHIFT != EFF_RSHIFT_2D");

 IDCT_1D_Multi<0>(c, buf);
 IDCT_1D_Multi<EFF_RSHIFT_1D_POST>(buf, c);
}

}
