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
#include <assert.h> /* for assert() */
#include <string.h> /* for memcpy */
#include "str_funcs.h"

/**
    Copy array of chars [str] with length [str_len] into [dst] string

    Returns error number:
        0 - no errors
        1 - memory reallocating error
*/
int big_int_str_copy_s(const char *str, size_t str_len, big_int_str *dst)
{
    assert(str != NULL);
    assert(dst != NULL);

    if (big_int_str_realloc(dst, str_len)) {
        return 1;
    }

    memcpy(dst->str, str, str_len);
    dst->str[str_len] = '\0';

    dst->len = str_len;

    return 0;
}

/**
    Creates and returns empty string with pre-allocated length of [len].
    On error returns NULL
*/
big_int_str * big_int_str_create(size_t len)
{
    big_int_str *s;
    char *str;

    ++len;
    str = (char *) bi_malloc(sizeof(char) * len);
    if (str == NULL) {
        return NULL;
    }

    *str = '\0';

    s = (big_int_str *) bi_malloc(sizeof(big_int_str));
    if (s == NULL) {
        bi_free(str);
        return NULL;
    }

    s->str = str;
    s->len = 0;
    s->len_allocated = len;

    return s;
}

/**
    Frees memory, allocated for [s]. Pointer to [s] can be NULL
*/
void big_int_str_destroy(big_int_str *s)
{
    if (s == NULL) {
        return;
    }

    bi_free(s->str);
    bi_free(s);
}

/**
    Reallocates memory for string [s] up to [len] chars.

    Returns error number:
        0 - no errors
        1 - error during reallocating memory
*/
int big_int_str_realloc(big_int_str *s, size_t len)
{
    assert(s != NULL);

    len++;
    if (s->len_allocated < len) {
        s->str = (char *) bi_realloc(s->str, sizeof(char) * len);
        if (s->str == NULL) {
            return 1;
        }
        s->len_allocated = len;
    }
    return 0;
}

/**
    Copies [src] string to [dst].

    Returns error number:
        0 - no errors
        1 - error during reallocating memory
*/
int big_int_str_copy(const big_int_str *src, big_int_str *dst)
{
    assert(dst != NULL);
    assert(src != NULL);

    if (src == dst) {
        /* nothing to do */
        return 0;
    }

    if (big_int_str_realloc(dst, src->len)) {
        return 1;
    }

    memcpy(dst->str, src->str, sizeof(char) * src->len);
    dst->str[src->len] = '\0';

    dst->len = src->len;

    return 0;
}

/**
    Returns the duplicate of string [s],
    which must be destoyed by big_int_str_destroy() function.
    On error returns NULL.
*/
big_int_str * big_int_str_dup(const big_int_str *s)
{
    big_int_str *new_s;

    assert(s != NULL);

    new_s = big_int_str_create(s->len);
    if (new_s == NULL) {
        return NULL;
    }
    memcpy(new_s->str, s->str, sizeof(char) * s->len);
    new_s->len = s->len;

    return new_s;
}
