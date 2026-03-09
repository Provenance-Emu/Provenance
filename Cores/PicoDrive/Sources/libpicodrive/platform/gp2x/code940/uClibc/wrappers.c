#include "math.h"

double pow(double x, double y)
{
	return __ieee754_pow(x, y);
}
double __pow_finite(double x, double y)
{
	return __ieee754_pow(x, y);
}


double log(double x)
{
	return __ieee754_log(x);
}
double __log_finite(double x)
{
	return __ieee754_log(x);
}
