#include <stdio.h>
#include <math.h>
#include <assert.h>
#include <stdlib.h>

void normalize(double* coeffs, unsigned num_coeffs, double v)
{
 double sum = 0;

 for(unsigned i = 0; i < num_coeffs; i++)
  sum += coeffs[i];

 double multiplier = v / sum;

 for(unsigned i = 0; i < num_coeffs; i++)
  coeffs[i] *= multiplier;
}

int main(int argc, char* argv[])
{
 int count = atoi(argv[1]);
 int hc = count / 2;
 double tmp[32];

 assert(count & 1);

 for(int i = 0; i < count; i++)
 {
  double k = i - hc;

  tmp[i] = 0.42 + 0.50 * cos(M_PI * k / hc) + 0.08 * cos(2 * M_PI * k / hc);
 }

 normalize(tmp, count, 1.0);

 printf(" { ");
 for(int i = 0; i < count; i++)
 {
  tmp[i] = floor(0.5 + tmp[i] * 100000000) / 100000000;

  printf("% .8f, ", tmp[i]);
 }
 printf(" }\n");

 float a = 0, b = 0;

 for(unsigned i = 0; i < 32; i++)
 {
  a += (i & 1) * tmp[i];
  b += ((i & 1) ^ 1) * tmp[i];
 }

 printf("%f %f\n", 255 * a, 255 * b);

 return 0;
}
