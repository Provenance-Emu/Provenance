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
#include <assert.h>
#include "big_int.h"
#include "low_level_funcs.h"

/**
    Calculates
        c = a * a

    Restrictions:
        1) length(a) > 0
        2) [c] must points to array of size 2*length(a)
        3) address [c] cannot be equal to [a]
*/
void low_level_sqr(const big_int_word *a, const big_int_word *a_end, big_int_word *c)
{
    big_int_dword tmp1, tmp2;
    const big_int_word *aa, *bb;
    big_int_word *cc, *cc1, *c_end;
    big_int_word flag_c, tmp;

    assert(a_end - a > 0);
    assert(a != c);

    c_end = c + 2 * (a_end - a);
    /* calculate squares */
    cc = c;
    aa = a;
    do {
        tmp1 = *aa++;
        tmp1 *= tmp1;
        *cc++ = BIG_INT_LO_WORD(tmp1);
        *cc++ = BIG_INT_HI_WORD(tmp1);
    } while (aa < a_end);

    /* shift [c] by 1 bit to the right (divide by 2) */
    cc = c_end;
    flag_c = 0;
    do {
        flag_c <<= BIG_INT_WORD_BITS_CNT - 1;
        tmp = *(--cc);
        *cc = (tmp >> 1) | flag_c;
        flag_c = tmp & 1;
    } while (c < cc);

    /* calculate off-diagonal sums */
    bb = a;
    cc1 = c;
    while (++bb < a_end) {
        cc = ++cc1;
        tmp1 = *cc;
        tmp2 = *bb;
        aa = a;
        do {
            tmp1 += tmp2 * (*aa++);
            *cc++ = BIG_INT_LO_WORD(tmp1);
            tmp1 >>= BIG_INT_WORD_BITS_CNT;
            tmp1 += *cc;
        } while (aa < bb);
        *cc++ = BIG_INT_LO_WORD(tmp1);
        while (cc < c_end && BIG_INT_HI_WORD(tmp1)) {
            tmp1 >>= BIG_INT_WORD_BITS_CNT;
            tmp1 += *cc;
            *cc++ = BIG_INT_LO_WORD(tmp1);
        }
    }

    /* shift [c] by 1 bit to the left (multiply by 2) */
    cc = c;
    do {
        tmp = *cc;
        *cc++ = (tmp << 1) | flag_c;
        flag_c = tmp >> (BIG_INT_WORD_BITS_CNT - 1);
    } while (cc < c_end);
}
