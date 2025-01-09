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
    Modular arithmetic functions include:
        1) functions, listed below
*/
#ifndef BIG_INT_MODULAR_ARITHMETIC_H
#define BIG_INT_MODULAR_ARITHMETIC_H

#include "big_int.h"

#ifdef __cplusplus
extern "C" {
#endif

BIG_INT_API int big_int_addmod(const big_int *a, const big_int *b,
    const big_int *modulus, big_int *answer);

BIG_INT_API int big_int_submod(const big_int *a, const big_int *b,
    const big_int *modulus, big_int *answer);

BIG_INT_API int big_int_mulmod(const big_int *a, const big_int *b,
    const big_int *modulus, big_int *answer);

BIG_INT_API int big_int_divmod(const big_int *a, const big_int *b,
    const big_int *modulus, big_int *answer);

BIG_INT_API int big_int_powmod(const big_int *a, const big_int *b,
    const big_int *modulus, big_int *answer);

BIG_INT_API int big_int_factmod(const big_int *a, const big_int *modulus, big_int *answer);

BIG_INT_API int big_int_absmod(const big_int *a, const big_int *modulus, big_int *answer);

BIG_INT_API int big_int_invmod(const big_int *a, const big_int *modulus, big_int *answer);

BIG_INT_API int big_int_sqrmod(const big_int *a, const big_int *modulus, big_int *answer);

BIG_INT_API int big_int_cmpmod(const big_int *a, const big_int *b,
    const big_int *modulus, int *cmp_flag);

#ifdef __cplusplus
}
#endif

#endif
