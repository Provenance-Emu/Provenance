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
    Calculates quotient and reminder of a / b
    Quotient saves to address [c], reminder - to address [a].

    Restrictions:
        1) length(a) >= length(b) > 0
        2) highest bit of [b] must be set to 1
        3) a >= b
        4) address [a] cannot be equal to [b]
        5) [c] must points to array with size length(a) - length(b) + 1
        6) address [c] cannot be equal to [a] or [b].
*/
void low_level_div(big_int_word *a, big_int_word *a_end,
                   const big_int_word *b, const big_int_word *b_end,
                   big_int_word *c, big_int_word *c_end)
{
    big_int_dword tmp1, tmp2, flag_c;
    big_int_word *aa, *cc;
    const big_int_word *bb;
    big_int_dword b_h, b_l, q, r;
    size_t b_len = b_end - b;

    assert(b_end - b > 0);
    assert(a_end - a >= b_end - b);
    assert((*(b_end - 1) >> (BIG_INT_WORD_BITS_CNT - 1)) == 1);
    assert(a != b);
    assert(c != a && c != b);

    aa = a_end;
    cc = c_end;
    /*
        if size of [b] is 1, use simple algorithm for dividing
    */
    if (b_len == 1) {
        b_l = *b;
        tmp1 = *(--aa);
        do {
            *aa = 0;
            tmp1 <<= BIG_INT_WORD_BITS_CNT;
            tmp1 |= *(--aa);
            *(--cc) = BIG_INT_LO_WORD(tmp1 / b_l);
            tmp1 %= b_l;
        } while (cc > c);
        *aa = BIG_INT_LO_WORD(tmp1);
        return;
    }

    /*
        size of [b] is greater than 1. Use another algorithm
    */
    b_h = *(b_end - 1);
    b_l = *(b_end - 2);
    do {
        /* calculate the guess of current digit of quotient */
        tmp1 = *(--aa);
        tmp1 <<= BIG_INT_WORD_BITS_CNT;
        tmp1 |= *(aa - 1);
        q = tmp1 / b_h;
        r = tmp1 % b_h;
        while (q > BIG_INT_MAX_WORD_NUM) {
            q--;
            r += b_h;
        }
        /* correct the guess of current digit of quotient */
        if (r <= BIG_INT_MAX_WORD_NUM) {
            tmp1 = b_l * q;
            tmp2 = (r << BIG_INT_WORD_BITS_CNT) | *(aa - 2);
            if (tmp1 > tmp2) {
                q--;
                tmp1 -= b_l;
                tmp2 += b_h << BIG_INT_WORD_BITS_CNT;
                r += b_h;
                if (r <= BIG_INT_MAX_WORD_NUM && tmp1 > tmp2) {
                    q--;
                }
            }
        }
        /* subtract b * q from [aa] */
        if (q != 0) {
            aa -= b_len;
            bb = b;
            tmp1 = 0;
            flag_c = 0;
            do {
                tmp1 += *(bb++) * q;
                tmp1 += flag_c;
                flag_c = BIG_INT_LO_WORD(tmp1) > *aa ? 1 : 0;
                *(aa++) -= BIG_INT_LO_WORD(tmp1);
                tmp1 >>= BIG_INT_WORD_BITS_CNT;
            } while (bb < b_end);
            tmp1 += flag_c;
            flag_c = BIG_INT_LO_WORD(tmp1) > *aa ? 1 : 0;
            *aa = 0;

            /* do correction, if nessesary */
            if (flag_c) {
                q--;
                aa -= b_len;
                bb = b;
                tmp1 = 0;
                do {
                    tmp1 += *bb++;
                    tmp1 += *aa;
                    *(aa++) = BIG_INT_LO_WORD(tmp1);
                    tmp1 >>= BIG_INT_WORD_BITS_CNT;
                } while (bb < b_end);
            }
        }
        *(--cc) = BIG_INT_LO_WORD(q);
    } while (cc > c);
}
