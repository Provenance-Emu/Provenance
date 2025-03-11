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
 * This file is the modified version of sync_queue.h file living in ffmpeg source code under the fftools folder. We
 * manually update it each time we depend on a new ffmpeg version. Below you can see the list of changes applied
 * by us to develop ffmpeg-kit library.
 *
 * ffmpeg-kit changes by ARTHENICA LTD
 *
 * 07.2023
 * --------------------------------------------------------
 * - FFmpeg 6.0 changes migrated
 */

#ifndef FFTOOLS_SYNC_QUEUE_H
#define FFTOOLS_SYNC_QUEUE_H

#include <stdint.h>

#include "libavcodec/packet.h"

#include "libavutil/frame.h"

enum SyncQueueType {
    SYNC_QUEUE_PACKETS,
    SYNC_QUEUE_FRAMES,
};

typedef union SyncQueueFrame {
    AVFrame  *f;
    AVPacket *p;
} SyncQueueFrame;

#define SQFRAME(frame) ((SyncQueueFrame){ .f = (frame) })
#define SQPKT(pkt)     ((SyncQueueFrame){ .p = (pkt) })

typedef struct SyncQueue SyncQueue;

/**
 * Allocate a sync queue of the given type.
 *
 * @param buf_size_us maximum duration that will be buffered in microseconds
 */
SyncQueue *sq_alloc(enum SyncQueueType type, int64_t buf_size_us);
void       sq_free(SyncQueue **sq);

/**
 * Add a new stream to the sync queue.
 *
 * @param limiting whether the stream is limiting, i.e. no other stream can be
 *                 longer than this one
 * @return
 * - a non-negative stream index on success
 * - a negative error code on error
 */
int sq_add_stream(SyncQueue *sq, int limiting);

/**
 * Set the timebase for the stream with index stream_idx. Should be called
 * before sending any frames for this stream.
 */
void sq_set_tb(SyncQueue *sq, unsigned int stream_idx, AVRational tb);

/**
 * Limit the number of output frames for stream with index stream_idx
 * to max_frames.
 */
void sq_limit_frames(SyncQueue *sq, unsigned int stream_idx,
                     uint64_t max_frames);

/**
 * Submit a frame for the stream with index stream_idx.
 *
 * On success, the sync queue takes ownership of the frame and will reset the
 * contents of the supplied frame. On failure, the frame remains owned by the
 * caller.
 *
 * Sending a frame with NULL contents marks the stream as finished.
 *
 * @return
 * - 0 on success
 * - AVERROR_EOF when no more frames should be submitted for this stream
 * - another a negative error code on failure
 */
int sq_send(SyncQueue *sq, unsigned int stream_idx, SyncQueueFrame frame);

/**
 * Read a frame from the queue.
 *
 * @param stream_idx index of the stream to read a frame for. May be -1, then
 *                   try to read a frame from any stream that is ready for
 *                   output.
 * @param frame output frame will be written here on success. The frame is owned
 *              by the caller.
 *
 * @return
 * - a non-negative index of the stream to which the returned frame belongs
 * - AVERROR(EAGAIN) when more frames need to be submitted to the queue
 * - AVERROR_EOF when no more frames will be available for this stream (for any
 *               stream if stream_idx is -1)
 * - another negative error code on failure
 */
int sq_receive(SyncQueue *sq, int stream_idx, SyncQueueFrame frame);

#endif // FFTOOLS_SYNC_QUEUE_H
