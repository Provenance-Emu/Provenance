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
    Low level functions indclude:
        1) functions, listed below
*/
#ifndef LOW_LEVEL_FUNCS_H
#define LOW_LEVEL_FUNCS_H

#include "big_int.h"

#ifdef __cplusplus
extern "C" {
#endif

void low_level_add(big_int_word *a, big_int_word *a_end,
                   const big_int_word *b, const big_int_word *b_end,
                   big_int_word *c);

void low_level_sub(big_int_word *a, big_int_word *a_end,
                   const big_int_word *b, const big_int_word *b_end,
                   big_int_word *c);

void low_level_mul(const big_int_word *a, const big_int_word *a_end,
                   const big_int_word *b, const big_int_word *b_end,
                   big_int_word *c);

void low_level_div(big_int_word *a, big_int_word *a_end,
                   const big_int_word *b, const big_int_word *b_end,
                   big_int_word *c, big_int_word *c_end);

int low_level_cmp(const big_int_word *a, const big_int_word *b, size_t len);

void low_level_or(const big_int_word *a, const big_int_word *a_end,
                  const big_int_word *b, const big_int_word *b_end,
                  big_int_word *c);

void low_level_and(const big_int_word *a, const big_int_word *a_end,
                   const big_int_word *b, const big_int_word *b_end,
                   big_int_word *c);

void low_level_andnot(const big_int_word *a, const big_int_word *a_end,
                      const big_int_word *b, const big_int_word *b_end,
                      big_int_word *c);

void low_level_xor(const big_int_word *a, const big_int_word *a_end,
                   const big_int_word *b, const big_int_word *b_end,
                   big_int_word *c);

void low_level_sqr(const big_int_word *a, const big_int_word *a_end, big_int_word *c);

#ifdef __cplusplus
}
#endif

#endif
