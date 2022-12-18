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
#include "big_int.h"
#include "low_level_funcs.h"

/**
    Calculates
        c = a and b

    Restrictions:
        1) [c] must points to array of size max(length(a), length(b))
*/
void low_level_and(const big_int_word *a, const big_int_word *a_end,
                   const big_int_word *b, const big_int_word *b_end,
                   big_int_word *c)
{
    while (a < a_end && b < b_end) {
        *c++ = *a++ & *b++;
    }
    while (++a <= a_end) {
        *c++ = 0;
    }
    while (++b <= b_end) {
        *c++ = 0;
    }
}
