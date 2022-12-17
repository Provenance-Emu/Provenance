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
#include "memory_manager.h"

#include <stdlib.h>

void *bi_malloc(size_t n)
{
    return malloc(n);
}

void *bi_realloc(void *p, size_t n)
{
    return realloc(p, n);
}

void bi_free(void *p)
{
    free(p);
}
