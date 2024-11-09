/*
 Copyright (c) 2009, OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "OERingBuffer.h"
@import RingBuffer;
@import PVLoggingObjC;
@import Accelerate;  /// For vDSP operations
#import <stdatomic.h>  /// For atomic operations
#import <os/lock.h>    /// For memory fences

__attribute__((objc_direct_members))
@implementation OERingBuffer
@synthesize bytesWritten;
@synthesize bytesRead;

- (instancetype)init {
    return [self initWithLength:1];
}

- (instancetype)initWithLength:(BufferSize)length {
    if((self = [super init])) {
        if (!TPCircularBufferInit(&buffer, length)) {
            return nil;  /// Handle initialization failure
        }
        atomic_thread_fence(memory_order_release);  /// Modern memory barrier
    }
    return self;
}

- (void)dealloc {
    TPCircularBufferCleanup(&buffer);
}

- (BufferSize)length {
    return buffer.length;
}

- (void)setLength:(BufferSize)length {
    TPCircularBufferCleanup(&buffer);
    TPCircularBufferInit(&buffer, length);
    atomic_thread_fence(memory_order_release);
}

- (BufferSize)write:(const void *)inBuffer size:(BufferSize)length {
    if (inBuffer == nil || length == 0) {
        return 0;
    }

    /// Prevent buffer overflow
    if (length > buffer.length) {
        ELOG(@"Buffer overflow prevented - attempted write of %d bytes to %d byte buffer",
             length, buffer.length);
        return 0;
    }

    bytesWritten += length;
    VLOG(@"bytesWritten: %i", bytesWritten);
    return TPCircularBufferProduceBytes(&buffer, inBuffer, length);
}

- (BufferSize)read:(void *)outBuffer preferredSize:(BufferSize)len {
    if (outBuffer == nil || len == 0) {
        return 0;
    }

    BufferSize availableBytes = 0;
    void *head = TPCircularBufferTail(&buffer, &availableBytes);

    /// Handle empty buffer
    if (availableBytes == 0) {
        DLOG(@"Buffer underrun - filling with silence");
        memset(outBuffer, 0, len);
        bytesRead += len;
        return len;
    }

    /// Calculate how much we can read
    BufferSize bytesToRead = MIN(availableBytes, len);

    /// Handle reads
    if (head + bytesToRead <= (void *)((char *)buffer.buffer + buffer.length)) {
        /// Single contiguous read
        memcpy(outBuffer, head, bytesToRead);
    } else {
        /// Split read required
        BufferSize firstPart = (BufferSize)((char *)buffer.buffer + buffer.length - (char *)head);
        memcpy(outBuffer, head, firstPart);
        memcpy((char *)outBuffer + firstPart, buffer.buffer, bytesToRead - firstPart);
    }

    TPCircularBufferConsume(&buffer, bytesToRead);
    bytesRead += bytesToRead;
    VLOG(@"bytesRead: %i", bytesRead);

    /// Fill remaining space with silence if needed
    if (bytesToRead < len) {
        DLOG(@"Partial read: %d/%d bytes - filling rest with silence",
             bytesToRead, len);
        memset((char *)outBuffer + bytesToRead, 0, len - bytesToRead);
        bytesRead += (len - bytesToRead);
        return len;
    }

    return bytesToRead;
}

- (BufferSize)availableBytesForWriting {
    BufferSize availableBytes = 0;
    TPCircularBufferHead(&buffer, &availableBytes);
    return availableBytes;
}

- (BufferSize)availableBytesForReading {
    BufferSize availableBytes = 0;
    TPCircularBufferTail(&buffer, &availableBytes);
    return availableBytes;
}

- (void)reset {
    TPCircularBufferClear(&buffer);
    [self setLength:buffer.length];
    bytesRead = 0;    /// Reset counters
    bytesWritten = 0;
    atomic_thread_fence(memory_order_release);
}

- (BufferSize)availableBytes {
    return [self availableBytesForReading];
}

@end
