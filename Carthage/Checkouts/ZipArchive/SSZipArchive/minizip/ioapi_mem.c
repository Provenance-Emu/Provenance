/* ioapi_mem.c -- IO base function header for compress/uncompress .zip
   files using zlib + zip or unzip API

   This version of ioapi is designed to access memory rather than files.
   We do use a region of memory to put data in to and take it out of. We do
   not have auto-extending buffers and do not inform anyone else that the
   data has been written. It is really intended for accessing a zip archive
   embedded in an application such that I can write an installer with no
   external files. Creation of archives has not been attempted, although
   parts of the framework are present.

   Based on Unzip ioapi.c version 0.22, May 19th, 2003

   Copyright (C) 2012-2017 Nathan Moinvaziri
     https://github.com/nmoinvaz/minizip
   Copyright (C) 2003 Justin Fletcher
   Copyright (C) 1998-2003 Gilles Vollant
     http://www.winimage.com/zLibDll/minizip.html

   This file is under the same license as the Unzip tool it is distributed
   with.
*/


#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zlib.h"
#include "ioapi.h"

#include "ioapi_mem.h"

#ifndef IOMEM_BUFFERSIZE
#  define IOMEM_BUFFERSIZE (UINT16_MAX)
#endif

voidpf ZCALLBACK fopen_mem_func(voidpf opaque, ZIP_UNUSED const char *filename, int mode)
{
    ourmemory_t *mem = (ourmemory_t *)opaque;
    if (mem == NULL)
        return NULL; /* Mem structure passed in was null */

    if (mode & ZLIB_FILEFUNC_MODE_CREATE)
    {
        if (mem->grow)
        {
            mem->size = IOMEM_BUFFERSIZE;
            mem->base = (char *)malloc(mem->size);
        }

        mem->limit = 0; /* When writing we start with 0 bytes written */
    }
    else
        mem->limit = mem->size;

    mem->cur_offset = 0;

    return mem;
}

voidpf ZCALLBACK fopendisk_mem_func(ZIP_UNUSED voidpf opaque, ZIP_UNUSED voidpf stream, ZIP_UNUSED uint32_t number_disk, ZIP_UNUSED int mode)
{
    /* Not used */
    return NULL;
}

uint32_t ZCALLBACK fread_mem_func(ZIP_UNUSED voidpf opaque, voidpf stream, void *buf, uint32_t size)
{
    ourmemory_t *mem = (ourmemory_t *)stream;

    if (size > mem->size - mem->cur_offset)
        size = mem->size - mem->cur_offset;

    memcpy(buf, mem->base + mem->cur_offset, size);
    mem->cur_offset += size;

    return size;
}

uint32_t ZCALLBACK fwrite_mem_func(ZIP_UNUSED voidpf opaque, voidpf stream, const void *buf, uint32_t size)
{
    ourmemory_t *mem = (ourmemory_t *)stream;
    uint32_t newmemsize = 0;
    char *newbase = NULL;

    if (size > mem->size - mem->cur_offset)
    {
        if (mem->grow)
        {
            newmemsize = mem->size;
            if (size < IOMEM_BUFFERSIZE)
                newmemsize += IOMEM_BUFFERSIZE;
            else
                newmemsize += size;
            newbase = (char *)malloc(newmemsize);
            memcpy(newbase, mem->base, mem->size);
            free(mem->base);
            mem->base = newbase;
            mem->size = newmemsize;
        }
        else
            size = mem->size - mem->cur_offset;
    }
    memcpy(mem->base + mem->cur_offset, buf, size);
    mem->cur_offset += size;
    if (mem->cur_offset > mem->limit)
        mem->limit = mem->cur_offset;

    return size;
}

long ZCALLBACK ftell_mem_func(ZIP_UNUSED voidpf opaque, voidpf stream)
{
    ourmemory_t *mem = (ourmemory_t *)stream;
    return mem->cur_offset;
}

long ZCALLBACK fseek_mem_func(ZIP_UNUSED voidpf opaque, voidpf stream, uint32_t offset, int origin)
{
    ourmemory_t *mem = (ourmemory_t *)stream;
    uint32_t new_pos = 0;
    switch (origin)
    {
        case ZLIB_FILEFUNC_SEEK_CUR:
            new_pos = mem->cur_offset + offset;
            break;
        case ZLIB_FILEFUNC_SEEK_END:
            new_pos = mem->limit + offset;
            break;
        case ZLIB_FILEFUNC_SEEK_SET:
            new_pos = offset;
            break;
        default:
            return -1;
    }

    if (new_pos > mem->size)
        return 1; /* Failed to seek that far */
    mem->cur_offset = new_pos;
    return 0;
}

int ZCALLBACK fclose_mem_func(ZIP_UNUSED voidpf opaque, ZIP_UNUSED voidpf stream)
{
    /* Even with grow = 1, caller must always free() memory */
    return 0;
}

int ZCALLBACK ferror_mem_func(ZIP_UNUSED voidpf opaque, ZIP_UNUSED voidpf stream)
{
    /* We never return errors */
    return 0;
}

void fill_memory_filefunc(zlib_filefunc_def *pzlib_filefunc_def, ourmemory_t *ourmem)
{
    pzlib_filefunc_def->zopen_file = fopen_mem_func;
    pzlib_filefunc_def->zopendisk_file = fopendisk_mem_func;
    pzlib_filefunc_def->zread_file = fread_mem_func;
    pzlib_filefunc_def->zwrite_file = fwrite_mem_func;
    pzlib_filefunc_def->ztell_file = ftell_mem_func;
    pzlib_filefunc_def->zseek_file = fseek_mem_func;
    pzlib_filefunc_def->zclose_file = fclose_mem_func;
    pzlib_filefunc_def->zerror_file = ferror_mem_func;
    pzlib_filefunc_def->opaque = ourmem;
}
