/***********************************************************************
    Copyright 2004, 2005 Alexander Valyalkin

    These sources is free software. You can redistribute it and/or
    modify it freely. You can use it with any free or commercial
    software.

    These sources is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY. Without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

    You may contact the author by:
       e-mail:  valyala@gmail.com
*************************************************************************/
/**
    Number theory functions indclude:
        1) modular arithmetic functions, defined in modular_arithmetic.h
        2) functions, listed below
*/
#ifndef BIG_INT_NUMBER_THEORY_H
#define BIG_INT_NUMBER_THEORY_H

#include "big_int.h"
#include "modular_arithmetic.h"

#ifdef __cplusplus
extern "C" {
#endif

BIG_INT_API int big_int_gcd(const big_int *a, const big_int *b, big_int *answer);

BIG_INT_API int big_int_gcd_extended(const big_int *a, const big_int *b,
    big_int *gcd, big_int *x, big_int *y);

BIG_INT_API int big_int_pow(const big_int *a, int power, big_int *answer);

BIG_INT_API int big_int_sqrt(const big_int *a, big_int *answer);

BIG_INT_API int big_int_sqrt_rem(const big_int *a, big_int *answer);

BIG_INT_API int big_int_fact(int n, big_int *answer);

BIG_INT_API int big_int_miller_test(const big_int *a, const big_int *base, int *is_prime);

BIG_INT_API int big_int_is_prime(const big_int *a, unsigned int primes_to,
    int level, int *is_prime);

BIG_INT_API int big_int_next_prime(const big_int *a, big_int *answer);

BIG_INT_API int big_int_jacobi(const big_int *a, const big_int *b, int *jacobi);

#ifdef __cplusplus
}
#endif

#endif
