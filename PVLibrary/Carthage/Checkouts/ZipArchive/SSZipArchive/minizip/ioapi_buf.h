/* ioapi_buf.h -- IO base function header for compress/uncompress .zip
   files using zlib + zip or unzip API

   This version of ioapi is designed to buffer IO.

   Copyright (C) 2012-2017 Nathan Moinvaziri
      https://github.com/nmoinvaz/minizip

   This program is distributed under the terms of the same license as zlib.
   See the accompanying LICENSE file for the full text of the license.
*/

#ifndef _IOAPI_BUF_H
#define _IOAPI_BUF_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zlib.h"
#include "ioapi.h"

#ifdef __cplusplus
extern "C" {
#endif

voidpf   ZCALLBACK fopen_buf_func(voidpf opaque, const char* filename, int mode);
voidpf   ZCALLBACK fopen64_buf_func(voidpf opaque, const void* filename, int mode);
voidpf   ZCALLBACK fopendisk_buf_func(voidpf opaque, voidpf stream_cd, uint32_t number_disk, int mode);
voidpf   ZCALLBACK fopendisk64_buf_func(voidpf opaque, voidpf stream_cd, uint32_t number_disk, int mode);
uint32_t ZCALLBACK fread_buf_func(voidpf opaque, voidpf stream, void* buf, uint32_t size);
uint32_t ZCALLBACK fwrite_buf_func(voidpf opaque, voidpf stream, const void* buf, uint32_t size);
long     ZCALLBACK ftell_buf_func(voidpf opaque, voidpf stream);
uint64_t ZCALLBACK ftell64_buf_func(voidpf opaque, voidpf stream);
long     ZCALLBACK fseek_buf_func(voidpf opaque, voidpf stream, uint32_t offset, int origin);
long     ZCALLBACK fseek64_buf_func(voidpf opaque, voidpf stream, uint64_t offset, int origin);
int      ZCALLBACK fclose_buf_func(voidpf opaque,voidpf stream);
int      ZCALLBACK ferror_buf_func(voidpf opaque,voidpf stream);

typedef struct ourbuffer_s {
  zlib_filefunc_def   filefunc;
  zlib_filefunc64_def filefunc64;
} ourbuffer_t;

void fill_buffer_filefunc(zlib_filefunc_def* pzlib_filefunc_def, ourbuffer_t *ourbuf);
void fill_buffer_filefunc64(zlib_filefunc64_def* pzlib_filefunc_def, ourbuffer_t *ourbuf);

#ifdef __cplusplus
}
#endif

#endif
