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
    String functions include:
        1) functions, listed below
*/
#ifndef BIG_INT_STR_FUNCS_H
#define BIG_INT_STR_FUNCS_H

#include "big_int.h"
#include "str_types.h"

#ifdef __cplusplus
extern "C" {
#endif

BIG_INT_API big_int_str * big_int_str_create(size_t len);

BIG_INT_API big_int_str * big_int_str_dup(const big_int_str *s);

BIG_INT_API void big_int_str_destroy(big_int_str *s);

BIG_INT_API int big_int_str_copy(const big_int_str *src, big_int_str *dst);

BIG_INT_API int big_int_str_copy_s(const char *str, size_t str_len, big_int_str *dst);

BIG_INT_API int big_int_str_realloc(big_int_str *s, size_t len);

#ifdef __cplusplus
}
#endif

#endif
