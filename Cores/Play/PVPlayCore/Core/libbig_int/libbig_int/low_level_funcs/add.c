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
        c = a + b

    Restrictions:
        1) length(a) >= length(b) > 0
        2) [c] must points to preallocated array of size length(a) + 1
        3) address [b] cannot be equal to address [c]
*/
void low_level_add(big_int_word *a, big_int_word *a_end,
                   const big_int_word *b, const big_int_word *b_end,
                   big_int_word *c)
{
    big_int_word flag_c;

    assert(b_end - b > 0);
    assert(a_end - a >= b_end - b);
    assert(b != c);

    flag_c = 0;
    do {
        if (flag_c) {
            *c = 1 + *a++;
            if (!*c) flag_c = 1;
            else flag_c = 0;
            *c += *b;
            if (*c++ < *b++) flag_c = 1;
        } else {
            *c = *a++ + *b;
            if (*c++ < *b++) flag_c = 1;
            else flag_c = 0;
        }
    } while (b < b_end);

    if (a == a_end) {
        /* length(a) = length(b). Sets flag_c to the highest digit of [c] */
        *c = flag_c;
    } else {
        /* length(a) > length(b) */
        if (flag_c) {
            /* move flag_c up to the higher digits */
            do {
                *c = 1 + *a++;
            } while (a < a_end && !*c++);

            if (a == a_end) {
                /* [a] ends up. Sets flag_c to the highest digit of [c] */
                if (!*c++) {
                    *c = 1;
                }
                else {
                    *c = 0;
                }
            } else {
                /* flag_c == 0, but [a] is not ends up. Copy higher digits from [a] to [c] */
                if (a != c) {
                    do {
                        *c++ = *a++;
                    } while (a < a_end);
                } else {
                    /* a==c. So, go to the end of [c] */
                    c = a_end;
                }
                *c = 0; /* set the higher digit to zero */
            }
        } else {
            /* flag_c == 0, but [a] is not ends up. Copy higher digits from [a] to [c] */
            if (a != c) {
                do {
                    *c++ = *a++;
                } while (a < a_end);
            } else {
                /* a==c. So, go to the end of [c] */
                c = a_end;
            }
            *c = 0; /* set the higher digit to zero */
        }
    }
}
