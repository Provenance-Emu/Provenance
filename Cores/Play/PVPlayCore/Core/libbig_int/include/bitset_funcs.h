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
    bitset functions include:
        1) functions, listed below
*/
#ifndef BIG_INT_BITSET_FUNCS_H
#define BIG_INT_BITSET_FUNCS_H

#include "big_int.h"

/* type of pointer to function. It is used in big_int_rand function */
typedef int (*big_int_rnd_fp)(void);

#ifdef __cplusplus
extern "C" {
#endif

BIG_INT_API void big_int_bit_length(const big_int *a, unsigned int *len);

BIG_INT_API void big_int_bit1_cnt(const big_int *a, unsigned int *cnt);

BIG_INT_API int big_int_subint(const big_int *a, size_t start_bit, size_t bit_len,
    int is_invert, big_int *answer);

BIG_INT_API int big_int_or(const big_int *a, const big_int *b, size_t start_bit, big_int *answer);

BIG_INT_API int big_int_and(const big_int *a, const big_int *b, size_t start_bit, big_int *answer);

BIG_INT_API int big_int_andnot(const big_int *a, const big_int *b, size_t start_bit, big_int *answer);

BIG_INT_API int big_int_xor(const big_int *a, const big_int *b, size_t start_bit, big_int *answer);

BIG_INT_API int big_int_set_bit(const big_int *a, size_t n_bit, big_int *answer);

BIG_INT_API int big_int_clr_bit(const big_int *a, size_t n_bit, big_int *answer);

BIG_INT_API int big_int_inv_bit(const big_int *a, size_t n_bit, big_int *answer);

BIG_INT_API int big_int_test_bit(const big_int *a, size_t n_bit, int *bit_value);

BIG_INT_API int big_int_scan1_bit(const big_int *a, size_t pos_start, size_t *pos_found);

BIG_INT_API int big_int_scan0_bit(const big_int *a, size_t pos_start, size_t *pos_found);

BIG_INT_API int big_int_hamming_distance(const big_int *a, const big_int *b, unsigned int *distance);

BIG_INT_API int big_int_rshift(const big_int *a, int n_bits, big_int *answer);

BIG_INT_API int big_int_lshift(const big_int *a, int n_bits, big_int *answer);

BIG_INT_API int big_int_rand(big_int_rnd_fp rand_func, size_t n_bits, big_int *answer);

#ifdef __cplusplus
}
#endif

#endif
