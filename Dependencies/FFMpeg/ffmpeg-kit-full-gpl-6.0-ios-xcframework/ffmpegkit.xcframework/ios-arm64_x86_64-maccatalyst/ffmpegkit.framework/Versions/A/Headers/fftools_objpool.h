/*
 * This file is part of FFmpeg.
 * Copyright (c) 2023 ARTHENICA LTD
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

/*
 * This file is the modified version of objpool.h file living in ffmpeg source code under the fftools folder. We
 * manually update it each time we depend on a new ffmpeg version. Below you can see the list of changes applied
 * by us to develop ffmpeg-kit library.
 *
 * ffmpeg-kit changes by ARTHENICA LTD
 *
 * 07.2023
 * --------------------------------------------------------
 * - FFmpeg 6.0 changes migrated
 */

#ifndef FFTOOLS_OBJPOOL_H
#define FFTOOLS_OBJPOOL_H

typedef struct ObjPool ObjPool;

typedef void* (*ObjPoolCBAlloc)(void);
typedef void  (*ObjPoolCBReset)(void *);
typedef void  (*ObjPoolCBFree)(void **);

void     objpool_free(ObjPool **op);
ObjPool *objpool_alloc(ObjPoolCBAlloc cb_alloc, ObjPoolCBReset cb_reset,
                       ObjPoolCBFree cb_free);
ObjPool *objpool_alloc_packets(void);
ObjPool *objpool_alloc_frames(void);

int  objpool_get(ObjPool *op, void **obj);
void objpool_release(ObjPool *op, void **obj);

#endif // FFTOOLS_OBJPOOL_H
