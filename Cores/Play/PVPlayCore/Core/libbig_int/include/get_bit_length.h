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
    get_bit_length() calculates ceil(log2(num))
*/
#ifndef GET_BIT_LENGTH_H
#define GET_BIT_LENGTH_H

#include "big_int.h"

/**
    calculates and returns ceil(log2(num))
*/

static size_t get_bit_length(big_int_word num)
{
    size_t n_bits = 0;
    while (num) {
        num >>= 1;
        ++n_bits;
    }
    return n_bits;
}

#endif
