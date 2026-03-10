#include <sys/types.h>

int __kernel_rem_pio2(double *x, double *y, int e0, int nx, int prec, const int32_t *ipio2);
double __kernel_sin(double x, double y, int iy);
double __kernel_cos(double x, double y);

double __ieee754_pow(double x, double y);
double __ieee754_sqrt(double x);
double __ieee754_log(double x);
int32_t __ieee754_rem_pio2(double x, double *y);

double fabs(double x);
double scalbn(double x, int n);
double copysign(double x, double y);
double floor(double x);
