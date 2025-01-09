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
#ifndef BIG_INT_STR_TYPES_H
#define BIG_INT_STR_TYPES_H

#include <stddef.h> /* for size_t declaration */

typedef struct {
    char *str;
    size_t len;
    size_t len_allocated;
} big_int_str;

#endif
