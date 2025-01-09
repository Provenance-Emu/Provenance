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
        c = a - b

    Restrictions:
        1) [a] >= [b]
        2) length(a) >= length(b) > 0
        3) [c] must points to array of size length(a)
        4) address [b] cannot be equal to [c]
*/
void low_level_sub(big_int_word *a, big_int_word *a_end,
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
            flag_c = (*a <= *b) ? 1 : 0;
            *c = *a++;
            *c++ += ~(*b++);
        } else {
            flag_c = (*a < *b) ? 1 : 0;
            *c++ = *a++ - *b++;
        }
    } while (b < b_end);
    while (flag_c && a < a_end) {
        flag_c = *a ? 0 : 1;
        *c++ = *a++ - 1;
    }
    while (a < a_end) {
        *c++ = *a++;
    }
}
