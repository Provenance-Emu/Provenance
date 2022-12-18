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
        c = a * b

    Restrictions:
        1) length(a) >= length(b) > 0
        2) [c] must points to array of size length(a) + length(b),
        3) address [c] cannot be equal to [a] or [b].
*/
void low_level_mul(const big_int_word *a, const big_int_word *a_end,
                   const big_int_word *b, const big_int_word *b_end,
                   big_int_word *c)
{
    big_int_dword tmp1, tmp2;
    const big_int_word *aa, *bb;
    big_int_word *cc;
    big_int_word *c_end;

    assert(b_end - b > 0);
    assert(a_end - a >= b_end - b);
    assert(a != c);
    assert(b != c);

    /* fill [c] by zeros */
    c_end = c + (a_end - a) + (b_end - b);
    cc = c;
    do {
        *cc++ = 0;
    } while (cc < c_end);

    /* main loop */
    bb = b;
    do {
        cc = c++;
        tmp1 = *cc;
        tmp2 = *bb++;
        aa = a;
        do {
            tmp1 += tmp2 * (*aa++);
            *cc++ = BIG_INT_LO_WORD(tmp1);
            tmp1 >>= BIG_INT_WORD_BITS_CNT;
            tmp1 += *cc;
        } while (aa < a_end);
        *cc = BIG_INT_LO_WORD(tmp1);
    } while (bb < b_end);
}
