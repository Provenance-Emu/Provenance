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
    Basic bunctions include:
        1) service functions, listed in service_funcs.h
        2) functions, listed below
*/
#ifndef BIG_INT_BASIC_FUNCS_H
#define BIG_INT_BASIC_FUNCS_H

#include "big_int.h"
#include "service_funcs.h"

#ifdef __cplusplus
extern "C" {
#endif

BIG_INT_API void big_int_cmp_abs(const big_int *a, const big_int *b, int *cmp_flag);

BIG_INT_API void big_int_cmp(const big_int *a, const big_int *b, int *cmp_flag);

BIG_INT_API void big_int_sign(const big_int *a, sign_type *sign);

BIG_INT_API void big_int_is_zero(const big_int *a, int *is_zero);

BIG_INT_API void big_int_is_one(const big_int *a, int *is_one);

BIG_INT_API int big_int_abs(const big_int *a, big_int *answer);

BIG_INT_API int big_int_neg(const big_int *a, big_int *answer);

BIG_INT_API int big_int_inc(const big_int *a, big_int *answer);

BIG_INT_API int big_int_dec(const big_int *a, big_int *answer);

BIG_INT_API int big_int_sqr(const big_int *a, big_int *answer);

BIG_INT_API int big_int_mul(const big_int *a, const big_int *b, big_int *answer);

BIG_INT_API int big_int_div(const big_int *a, const big_int *b, big_int *answer);

BIG_INT_API int big_int_mod(const big_int *a, const big_int *b, big_int *answer);

BIG_INT_API int big_int_add(const big_int *a, const big_int *b, big_int *answer);

BIG_INT_API int big_int_sub(const big_int *a, const big_int *b, big_int *answer);

BIG_INT_API int big_int_muladd(const big_int *a, const big_int *b, const big_int *c, big_int *answer);

BIG_INT_API int big_int_div_extended(const big_int *a, const big_int *b, big_int *q, big_int *r);

#ifdef __cplusplus
}
#endif

#endif
