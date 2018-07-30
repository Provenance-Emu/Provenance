/* ioapi_buf.c -- IO base function header for compress/uncompress .zip
   files using zlib + zip or unzip API

   This version of ioapi is designed to buffer IO.

   Copyright (C) 2012-2017 Nathan Moinvaziri
      https://github.com/nmoinvaz/minizip

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "zlib.h"
#include "ioapi.h"

#include "ioapi_buf.h"

#ifndef IOBUF_BUFFERSIZE
#  define IOBUF_BUFFERSIZE (UINT16_MAX)
#endif

#if defined(_WIN32)
#  include <conio.h>
#  define PRINTF  _cprintf
#  define VPRINTF _vcprintf
#else
#  define PRINTF  printf
#  define VPRINTF vprintf
#endif

//#define IOBUF_VERBOSE

#ifdef __GNUC__
#ifndef max
#define max(x,y) ({ \
const __typeof__(x) _x = (x);	\
const __typeof__(y) _y = (y);	\
(void) (&_x == &_y);		\
_x > _y ? _x : _y; })
#endif /* __GNUC__ */

#ifndef min
#define min(x,y) ({ \
const __typeof__(x) _x = (x);	\
const __typeof__(y) _y = (y);	\
(void) (&_x == &_y);		\
_x < _y ? _x : _y; })
#endif
#endif

typedef struct ourstream_s {
  char      readbuf[IOBUF_BUFFERSIZE];
  uint32_t  readbuf_len;
  uint32_t  readbuf_pos;
  uint32_t  readbuf_hits;
  uint32_t  readbuf_misses;
  char      writebuf[IOBUF_BUFFERSIZE];
  uint32_t  writebuf_len;
  uint32_t  writebuf_pos;
  uint32_t  writebuf_hits;
  uint32_t  writebuf_misses;
  uint64_t  position;
  voidpf    stream;
} ourstream_t;

#if defined(IOBUF_VERBOSE)
#  define print_buf(o,s,f,...) print_buf_internal(o,s,f,__VA_ARGS__);
#else
#  define print_buf(o,s,f,...)
#endif

void print_buf_internal(ZIP_UNUSED voidpf opaque, voidpf stream, char *format, ...)
{
    ourstream_t *streamio = (ourstream_t *)stream;
    va_list arglist;
    PRINTF("Buf stream %p - ", streamio);
    va_start(arglist, format);
    VPRINTF(format, arglist);
    va_end(arglist);
}

voidpf fopen_buf_internal_func(ZIP_UNUSED voidpf opaque, voidpf stream, ZIP_UNUSED uint32_t number_disk, ZIP_UNUSED int mode)
{
    ourstream_t *streamio = NULL;
    if (stream == NULL)
        return NULL;
    streamio = (ourstream_t *)malloc(sizeof(ourstream_t));
    if (streamio == NULL)
        return NULL;
    memset(streamio, 0, sizeof(ourstream_t));
    streamio->stream = stream;
    print_buf(opaque, streamio, "open [num %d mode %d]\n", number_disk, mode);
    return streamio;
}

voidpf ZCALLBACK fopen_buf_func(voidpf opaque, const char *filename, int mode)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    voidpf stream = bufio->filefunc.zopen_file(bufio->filefunc.opaque, filename, mode);
    return fopen_buf_internal_func(opaque, stream, 0, mode);
}

voidpf ZCALLBACK fopen64_buf_func(voidpf opaque, const void *filename, int mode)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    voidpf stream = bufio->filefunc64.zopen64_file(bufio->filefunc64.opaque, filename, mode);
    return fopen_buf_internal_func(opaque, stream, 0, mode);
}

voidpf ZCALLBACK fopendisk_buf_func(voidpf opaque, voidpf stream_cd, uint32_t number_disk, int mode)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream_cd;
    voidpf *stream = bufio->filefunc.zopendisk_file(bufio->filefunc.opaque, streamio->stream, number_disk, mode);
    return fopen_buf_internal_func(opaque, stream, number_disk, mode);
}

voidpf ZCALLBACK fopendisk64_buf_func(voidpf opaque, voidpf stream_cd, uint32_t number_disk, int mode)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream_cd;
    voidpf stream = bufio->filefunc64.zopendisk64_file(bufio->filefunc64.opaque, streamio->stream, number_disk, mode);
    return fopen_buf_internal_func(opaque, stream, number_disk, mode);
}

long fflush_buf(voidpf opaque, voidpf stream)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream;
    uint32_t total_bytes_to_write = 0;
    uint32_t bytes_to_write = streamio->writebuf_len;
    uint32_t bytes_left_to_write = streamio->writebuf_len;
    long bytes_written = 0;

    while (bytes_left_to_write > 0)
    {
        if (bufio->filefunc64.zwrite_file != NULL)
            bytes_written = bufio->filefunc64.zwrite_file(bufio->filefunc64.opaque, streamio->stream, streamio->writebuf + (bytes_to_write - bytes_left_to_write), bytes_left_to_write);
        else
            bytes_written = bufio->filefunc.zwrite_file(bufio->filefunc.opaque, streamio->stream, streamio->writebuf + (bytes_to_write - bytes_left_to_write), bytes_left_to_write);

        streamio->writebuf_misses += 1;

        print_buf(opaque, stream, "write flush [%d:%d len %d]\n", bytes_to_write, bytes_left_to_write, streamio->writebuf_len);

        if (bytes_written < 0)
            return bytes_written;

        total_bytes_to_write += bytes_written;
        bytes_left_to_write -= bytes_written;
        streamio->position += bytes_written;
    }
    streamio->writebuf_len = 0;
    streamio->writebuf_pos = 0;
    return total_bytes_to_write;
}

uint32_t ZCALLBACK fread_buf_func(voidpf opaque, voidpf stream, void *buf, uint32_t size)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream;
    uint32_t buf_len = 0;
    uint32_t bytes_to_read = 0;
    uint32_t bytes_to_copy = 0;
    uint32_t bytes_left_to_read = size;
    uint32_t bytes_read = 0;

    print_buf(opaque, stream, "read [size %ld pos %lld]\n", size, streamio->position);

    if (streamio->writebuf_len > 0)
    {
        print_buf(opaque, stream, "switch from write to read, not yet supported [%lld]\n", streamio->position);
    }

    while (bytes_left_to_read > 0)
    {
        if ((streamio->readbuf_len == 0) || (streamio->readbuf_pos == streamio->readbuf_len))
        {
            if (streamio->readbuf_len == IOBUF_BUFFERSIZE)
            {
                streamio->readbuf_pos = 0;
                streamio->readbuf_len = 0;
            }

            bytes_to_read = IOBUF_BUFFERSIZE - (streamio->readbuf_len - streamio->readbuf_pos);

            if (bufio->filefunc64.zread_file != NULL)
                bytes_read = bufio->filefunc64.zread_file(bufio->filefunc64.opaque, streamio->stream, streamio->readbuf + streamio->readbuf_pos, bytes_to_read);
            else
                bytes_read = bufio->filefunc.zread_file(bufio->filefunc.opaque, streamio->stream, streamio->readbuf + streamio->readbuf_pos, bytes_to_read);

            streamio->readbuf_misses += 1;
            streamio->readbuf_len += bytes_read;
            streamio->position += bytes_read;

            print_buf(opaque, stream, "filled [read %d/%d buf %d:%d pos %lld]\n", bytes_read, bytes_to_read, streamio->readbuf_pos, streamio->readbuf_len, streamio->position);

            if (bytes_read == 0)
                break;
        }

        if ((streamio->readbuf_len - streamio->readbuf_pos) > 0)
        {
            bytes_to_copy = min(bytes_left_to_read, (uint32_t)(streamio->readbuf_len - streamio->readbuf_pos));
            memcpy((char *)buf + buf_len, streamio->readbuf + streamio->readbuf_pos, bytes_to_copy);

            buf_len += bytes_to_copy;
            bytes_left_to_read -= bytes_to_copy;

            streamio->readbuf_hits += 1;
            streamio->readbuf_pos += bytes_to_copy;

            print_buf(opaque, stream, "emptied [copied %d remaining %d buf %d:%d pos %lld]\n", bytes_to_copy, bytes_left_to_read, streamio->readbuf_pos, streamio->readbuf_len, streamio->position);
        }
    }

    return size - bytes_left_to_read;
}

uint32_t ZCALLBACK fwrite_buf_func(voidpf opaque, voidpf stream, const void *buf, uint32_t size)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream;
    uint32_t bytes_to_write = size;
    uint32_t bytes_left_to_write = size;
    uint32_t bytes_to_copy = 0;
    int64_t ret = 0;

    print_buf(opaque, stream, "write [size %ld len %d pos %lld]\n", size, streamio->writebuf_len, streamio->position);

    if (streamio->readbuf_len > 0)
    {
        streamio->position -= streamio->readbuf_len;
        streamio->position += streamio->readbuf_pos;

        streamio->readbuf_len = 0;
        streamio->readbuf_pos = 0;

        print_buf(opaque, stream, "switch from read to write [%lld]\n", streamio->position);

        if (bufio->filefunc64.zseek64_file != NULL)
            ret = bufio->filefunc64.zseek64_file(bufio->filefunc64.opaque, streamio->stream, streamio->position, ZLIB_FILEFUNC_SEEK_SET);
        else
            ret = bufio->filefunc.zseek_file(bufio->filefunc.opaque, streamio->stream, (uint32_t)streamio->position, ZLIB_FILEFUNC_SEEK_SET);

        if (ret != 0)
            return (uint32_t)-1;
    }

    while (bytes_left_to_write > 0)
    {
        bytes_to_copy = min(bytes_left_to_write, (uint32_t)(IOBUF_BUFFERSIZE - min(streamio->writebuf_len, streamio->writebuf_pos)));

        if (bytes_to_copy == 0)
        {
            if (fflush_buf(opaque, stream) <= 0)
                return 0;

            continue;
        }

        memcpy(streamio->writebuf + streamio->writebuf_pos, (char *)buf + (bytes_to_write - bytes_left_to_write), bytes_to_copy);

        print_buf(opaque, stream, "write copy [remaining %d write %d:%d len %d]\n", bytes_to_copy, bytes_to_write, bytes_left_to_write, streamio->writebuf_len);

        bytes_left_to_write -= bytes_to_copy;

        streamio->writebuf_pos += bytes_to_copy;
        streamio->writebuf_hits += 1;
        if (streamio->writebuf_pos > streamio->writebuf_len)
            streamio->writebuf_len += streamio->writebuf_pos - streamio->writebuf_len;
    }

    return size - bytes_left_to_write;
}

uint64_t ftell_buf_internal_func(ZIP_UNUSED voidpf opaque, voidpf stream, uint64_t position)
{
    ourstream_t *streamio = (ourstream_t *)stream;
    streamio->position = position;
    print_buf(opaque, stream, "tell [pos %llu readpos %d writepos %d err %d]\n", streamio->position, streamio->readbuf_pos, streamio->writebuf_pos, errno);
    if (streamio->readbuf_len > 0)
        position -= (streamio->readbuf_len - streamio->readbuf_pos);
    if (streamio->writebuf_len > 0)
        position += streamio->writebuf_pos;
    return position;
}

long ZCALLBACK ftell_buf_func(voidpf opaque, voidpf stream)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream;
    uint64_t position = bufio->filefunc.ztell_file(bufio->filefunc.opaque, streamio->stream);
    return (long)ftell_buf_internal_func(opaque, stream, position);
}

uint64_t ZCALLBACK ftell64_buf_func(voidpf opaque, voidpf stream)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream;
    uint64_t position = bufio->filefunc64.ztell64_file(bufio->filefunc64.opaque, streamio->stream);
    return ftell_buf_internal_func(opaque, stream, position);
}

int fseek_buf_internal_func(voidpf opaque, voidpf stream, uint64_t offset, int origin)
{
    ourstream_t *streamio = (ourstream_t *)stream;

    print_buf(opaque, stream, "seek [origin %d offset %llu pos %lld]\n", origin, offset, streamio->position);

    switch (origin)
    {
        case ZLIB_FILEFUNC_SEEK_SET:

            if (streamio->writebuf_len > 0)
            {
                if ((offset >= streamio->position) && (offset <= streamio->position + streamio->writebuf_len))
                {
                    streamio->writebuf_pos = (uint32_t)(offset - streamio->position);
                    return 0;
                }
            }
            if ((streamio->readbuf_len > 0) && (offset < streamio->position) && (offset >= streamio->position - streamio->readbuf_len))
            {
                streamio->readbuf_pos = (uint32_t)(offset - (streamio->position - streamio->readbuf_len));
                return 0;
            }
            if (fflush_buf(opaque, stream) < 0)
                return -1;
            streamio->position = offset;
            break;

        case ZLIB_FILEFUNC_SEEK_CUR:

            if (streamio->readbuf_len > 0)
            {
                if (offset <= (streamio->readbuf_len - streamio->readbuf_pos))
                {
                    streamio->readbuf_pos += (uint32_t)offset;
                    return 0;
                }
                offset -= (streamio->readbuf_len - streamio->readbuf_pos);
                streamio->position += offset;
            }
            if (streamio->writebuf_len > 0)
            {
                if (offset <= (streamio->writebuf_len - streamio->writebuf_pos))
                {
                    streamio->writebuf_pos += (uint32_t)offset;
                    return 0;
                }
                //offset -= (streamio->writebuf_len - streamio->writebuf_pos);
            }

            if (fflush_buf(opaque, stream) < 0)
                return -1;

            break;

        case ZLIB_FILEFUNC_SEEK_END:

            if (streamio->writebuf_len > 0)
            {
                streamio->writebuf_pos = streamio->writebuf_len;
                return 0;
            }
            break;
    }

    streamio->readbuf_len = 0;
    streamio->readbuf_pos = 0;
    streamio->writebuf_len = 0;
    streamio->writebuf_pos = 0;
    return 1;
}

long ZCALLBACK fseek_buf_func(voidpf opaque, voidpf stream, uint32_t offset, int origin)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream;
    long ret = -1;
    if (bufio->filefunc.zseek_file == NULL)
        return ret;
    ret = fseek_buf_internal_func(opaque, stream, offset, origin);
    if (ret == 1)
        ret = bufio->filefunc.zseek_file(bufio->filefunc.opaque, streamio->stream, offset, origin);
    return ret;
}

long ZCALLBACK fseek64_buf_func(voidpf opaque, voidpf stream, uint64_t offset, int origin)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream;
    long ret = -1;
    if (bufio->filefunc64.zseek64_file == NULL)
        return ret;
    ret = fseek_buf_internal_func(opaque, stream, offset, origin);
    if (ret == 1)
        ret = bufio->filefunc64.zseek64_file(bufio->filefunc64.opaque, streamio->stream, offset, origin);
    return ret;
}

int ZCALLBACK fclose_buf_func(voidpf opaque, voidpf stream)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream;
    int ret = 0;
    fflush_buf(opaque, stream);
    print_buf(opaque, stream, "close\n");
    if (streamio->readbuf_hits + streamio->readbuf_misses > 0)
        print_buf(opaque, stream, "read efficency %.02f%%\n", (streamio->readbuf_hits / ((float)streamio->readbuf_hits + streamio->readbuf_misses)) * 100);
    if (streamio->writebuf_hits + streamio->writebuf_misses > 0)
        print_buf(opaque, stream, "write efficency %.02f%%\n", (streamio->writebuf_hits / ((float)streamio->writebuf_hits + streamio->writebuf_misses)) * 100);
    if (bufio->filefunc64.zclose_file != NULL)
        ret = bufio->filefunc64.zclose_file(bufio->filefunc64.opaque, streamio->stream);
    else
        ret = bufio->filefunc.zclose_file(bufio->filefunc.opaque, streamio->stream);
    free(streamio);
    return ret;
}

int ZCALLBACK ferror_buf_func(voidpf opaque, voidpf stream)
{
    ourbuffer_t *bufio = (ourbuffer_t *)opaque;
    ourstream_t *streamio = (ourstream_t *)stream;
    if (bufio->filefunc64.zerror_file != NULL)
        return bufio->filefunc64.zerror_file(bufio->filefunc64.opaque, streamio->stream);
    return bufio->filefunc.zerror_file(bufio->filefunc.opaque, streamio->stream);
}

void fill_buffer_filefunc(zlib_filefunc_def *pzlib_filefunc_def, ourbuffer_t *ourbuf)
{
    pzlib_filefunc_def->zopen_file = fopen_buf_func;
    pzlib_filefunc_def->zopendisk_file = fopendisk_buf_func;
    pzlib_filefunc_def->zread_file = fread_buf_func;
    pzlib_filefunc_def->zwrite_file = fwrite_buf_func;
    pzlib_filefunc_def->ztell_file = ftell_buf_func;
    pzlib_filefunc_def->zseek_file = fseek_buf_func;
    pzlib_filefunc_def->zclose_file = fclose_buf_func;
    pzlib_filefunc_def->zerror_file = ferror_buf_func;
    pzlib_filefunc_def->opaque = ourbuf;
}

void fill_buffer_filefunc64(zlib_filefunc64_def *pzlib_filefunc_def, ourbuffer_t *ourbuf)
{
    pzlib_filefunc_def->zopen64_file = fopen64_buf_func;
    pzlib_filefunc_def->zopendisk64_file = fopendisk64_buf_func;
    pzlib_filefunc_def->zread_file = fread_buf_func;
    pzlib_filefunc_def->zwrite_file = fwrite_buf_func;
    pzlib_filefunc_def->ztell64_file = ftell64_buf_func;
    pzlib_filefunc_def->zseek64_file = fseek64_buf_func;
    pzlib_filefunc_def->zclose_file = fclose_buf_func;
    pzlib_filefunc_def->zerror_file = ferror_buf_func;
    pzlib_filefunc_def->opaque = ourbuf;
}
