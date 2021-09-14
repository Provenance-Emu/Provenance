/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* DSPUtility.cpp:
**  Copyright (C) 2018 Mednafen Team
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

/*
 References:
	Digital Filters, Third Edition; R.W. Hamming
*/

#include <mednafen/types.h>
#include "DSPUtility.h"

#ifdef __FAST_MATH__
 #error "DSPUtility.cpp not compatible with unsafe math optimizations!"
#endif

namespace Mednafen
{

namespace DSPUtility
{

static INLINE double I_0(double x)
{
 int n = 1;
 double diff = 1.0;
 double sum = 1.0;

 x /= 2;
 x *= x;

 do
 {
  diff *= x / (n * n);
  sum += diff;

  //printf("%d, %e %e %e\n", n, diff, sum, diff / sum);
  n++;
 } while((diff / sum) >= (1.0 / 16777216));

 return sum;
}

void generate_kaiser_sinc_lp(double* coeffs, unsigned num_coeffs, double tb_center, double alpha)
{
 double f_s = tb_center;
 double f_p = 0;
 int N = num_coeffs / 2;
 const double scale = 1.0 / I_0(alpha);

 if(num_coeffs & 1)
 {
  coeffs[N + 0] = 2 * (f_s - f_p);

  for(int i = 0; i < N; i++)
  {
   double k = 1 + i;
   double c_k = (sin(M_PI * 2 * k * f_s) - sin(M_PI * 2 * k * f_p)) / (M_PI * k);
   double w_k = I_0(alpha * sqrt(1.0 - pow(((double)k / N), 2)));
   double r = scale * c_k * w_k;

   coeffs[N + 1 + i] = r;
   coeffs[N - 1 - i] = r;
  }
 }
 else
 {
  for(int i = 0; i < N; i++)
  {
   double k = 0.5 + i;
   double c_k = (sin(M_PI * 2 * k * f_s) - sin(M_PI * 2 * k * f_p)) / (M_PI * k);
   double w_k = I_0(alpha * sqrt(1.0 - pow(((double)k / N), 2)));
   double r = scale * c_k * w_k;

   coeffs[N + i] = r;
   coeffs[N - i - 1] = r;
  }
 }
}

void normalize(double* coeffs, unsigned num_coeffs, double v)
{
/*
 double sum_a = 0;
 double sum_b = 0;

 for(unsigned i = 0; i < num_coeffs / 2; i++)
  sum_a += coeffs[i];

 for(unsigned i = 0; i < num_coeffs / 2; i++)
  sum_b += coeffs[num_coeffs - 1 - i];

 double sum = sum_a + sum_b + ((num_coeffs & 1) ? coeffs[num_coeffs / 2] : 0);
*/

 double sum = 0;
 for(unsigned i = 0; i < num_coeffs; i++)
  sum += coeffs[i];

 double multiplier = v / sum;

 //printf("sum: %f\n", sum);

 for(unsigned i = 0; i < num_coeffs; i++)
  coeffs[i] *= multiplier;
}

}

}
