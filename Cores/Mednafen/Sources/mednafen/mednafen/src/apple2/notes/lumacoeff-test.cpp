// g++ -Wall -O2 -o lumacoeff-test lumacoeff-test.cpp
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static inline double I_0(double x)
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


int main(int argc, char* argv[])
{
 //double alpha = 4.554298;
 //double tb_center = 0.132957;
 const int ncoeffs = 15; //13;

 for(double alpha = 2.0; alpha < 8.0; alpha *= 1.001)
 {
  double tbcenter_max = 0;
  double tbcenter_max_coeffs[ncoeffs];

  for(double tb_center = 0.10; tb_center <= 0.2; tb_center *= 1.001)
  {
   bool ok = true;
   double coeffs[ncoeffs];

   generate_kaiser_sinc_lp(coeffs, ncoeffs, tb_center, alpha);
   normalize(coeffs, ncoeffs, 1.0);

   for(int pat = 0x0; pat < 0x10; pat++)
   {
    double sum = 0;
    double expected = 255.0 * ((bool)(pat & 1) + (bool)(pat & 2) + (bool)(pat & 4) + (bool)(pat & 8)) / 4.0;

    for(int i = 0; i < ncoeffs; i++)
     sum += coeffs[i] * ((pat >> (i & 3)) & 1);

    {
     double err = fabs(255.0 * sum - expected);

     if((pat == 0x5 || pat == 0xA) && err >= 0.10)
      ok = false;

     //printf("%02x %f\n", pat, err);

#if 0
     if(err >= 0.319) //0.25)
      ok = false;

     if(coeffs[ncoeffs / 2] < 0.284)
      ok = false;
#else
     if(err >= (26.5 / 2))
      ok = false;

     if(coeffs[ncoeffs / 2] < 0.36)
      ok = false;
#endif
    }
   }

   if(ok && tb_center > tbcenter_max)
   {
    tbcenter_max = tb_center;
    memcpy(tbcenter_max_coeffs, coeffs, sizeof(coeffs));
   }
  }

  if(tbcenter_max)
  {
   printf("  // alpha: %f, tb_center: %f\n", alpha, tbcenter_max);
   {
    double tmp2[16];
    for(int i = 0; i < 16; i++)
    {
     double a = 0;

     for(int j = 0; j < ncoeffs; j++)
     {
      int o = i + j - ncoeffs / 2;

      a += tbcenter_max_coeffs[j] * ((o >= 8) ? 1 : 0);
     }
     tmp2[i] = a;
    }
    printf("  // ");
    for(int i = 0; i < 16; i++)
    {
     if(i == 8)
      printf("*** ");
     printf("% .3f ", tmp2[i]);
    }
    printf("\n");
   }
   printf("  { ");
   for(int i = 0; i < ncoeffs; i++)
    printf("% .8f, ", tbcenter_max_coeffs[i]);
   printf(" },\n\n");
  }
 }

 return 0;
}
