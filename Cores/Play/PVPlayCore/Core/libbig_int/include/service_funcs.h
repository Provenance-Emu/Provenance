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
    Service functions include:
        1) string functions, such as big_int_str_*()
        2) functions, listed below
*/
#ifndef BIG_INT_SERVICE_FUNCS_H
#define BIG_INT_SERVICE_FUNCS_H

#include "big_int.h"
#include "str_funcs.h"

#ifdef __cplusplus
extern "C" {
#endif

BIG_INT_API const char * big_int_version();

BIG_INT_API const char * big_int_build_date();

BIG_INT_API big_int * big_int_create(size_t len);

BIG_INT_API big_int * big_int_dup(const big_int *a);

BIG_INT_API void big_int_destroy(big_int *a);

BIG_INT_API void big_int_clear_zeros(big_int *a);

BIG_INT_API int big_int_copy(const big_int *src, big_int *dst);

BIG_INT_API int big_int_realloc(big_int *a, size_t len);

BIG_INT_API int big_int_from_str(const big_int_str *s, unsigned int base, big_int *answer);

BIG_INT_API int big_int_to_str(const big_int *a, unsigned int base, big_int_str *s);

BIG_INT_API int big_int_from_int(int value, big_int *a);

BIG_INT_API int big_int_to_int(const big_int *a, int *value);

BIG_INT_API int big_int_base_convert(const big_int_str *src, big_int_str *dst,
    unsigned int base_from, unsigned int base_to);

BIG_INT_API int big_int_serialize(const big_int *a, int is_sign, big_int_str *s);

BIG_INT_API int big_int_unserialize(const big_int_str *s, int is_sign, big_int *a);

#ifdef __cplusplus
}
#endif

#endif
