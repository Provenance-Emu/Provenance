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
#ifndef MEMORY_MANAGER_H
#define MEMORY_MANAGER_H
#include <stddef.h> /* for size_t */

/*
    memory manager functions:

    bi_malloc() substitutes malloc
    bi_realloc() substitutes realloc
    bi_free() substitutes free
*/

void *bi_malloc(size_t n);
void *bi_realloc(void *p, size_t n);
void bi_free(void *p);

/*
#define bi_malloc malloc
#define bi_realloc realloc
#define bi_free free
*/

#endif
