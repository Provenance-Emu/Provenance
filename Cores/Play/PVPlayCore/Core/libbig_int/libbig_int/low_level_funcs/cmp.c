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
    Compares [a] with [b] with the same length [len].

    Returns:
        1, if [a] > [b]
        0, if [a] = [b]
        -1, if [a] < [b]

    Restrictions:
        - [len] must be greater than 0
*/
int low_level_cmp(const big_int_word *a, const big_int_word *b, size_t len)
{
    const big_int_word *a_end, *b_end;

    assert(len > 0);

    if (a == b) {
        /* [a] equlas to [b] */
        return 0;
    }

    a_end = a + len;
    b_end = b + len;
    do {
        if (*(--a_end) != *(--b_end)) break;
    } while (a_end > a);

    if (*a_end == *b_end) {
        /* [a] = [b] */
        return 0;
    }
    if (*a_end > *b_end) {
        /* [a] > [b] */
        return 1;
    }
    /* [a] < [b] */
    return -1;
}
