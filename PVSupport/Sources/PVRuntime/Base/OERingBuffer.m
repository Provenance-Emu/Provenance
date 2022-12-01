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
#import "TPCircularBuffer.h"
#import <os/lock.h>
#import <os/log.h>
#import "OELogging.h"

@implementation OERingBuffer
{
    os_unfair_lock fifoLock;
    atomic_uint bytesRead;
    atomic_uint bytesWritten;
#ifdef DEBUG
    BOOL suppressRepeatedLog;
#endif
}

- (instancetype)init
{
    return [self initWithLength:1];
}

- (instancetype)initWithLength:(NSUInteger)length
{
    if((self = [super init]))
    {
        TPCircularBufferInit(&buffer, (int)length);
        fifoLock = OS_UNFAIR_LOCK_INIT;
        _discardPolicy = OERingBufferDiscardPolicyNewest;
    }
    return self;
}

- (void)dealloc
{
    TPCircularBufferCleanup(&buffer);
}

- (NSUInteger)length
{
    return buffer.length;
}

- (void)setLength:(NSUInteger)length
{
    TPCircularBufferCleanup(&buffer);
    TPCircularBufferInit(&buffer, (int)length);
}

- (NSUInteger)write:(const void *)inBuffer maxLength:(NSUInteger)length
{
    NSUInteger res;

    atomic_fetch_add(&bytesWritten, length);
    
    res = TPCircularBufferProduceBytes(&buffer, inBuffer, (int)length);
    if (!res) {
        #ifdef DEBUG
        NSUInteger freeBytes = self.freeBytes;
        os_log_error(OE_LOG_AUDIO_WRITE, "Tried to write %lu bytes, but only %lu bytes free (%lu used)", length, freeBytes, self.availableBytes);
        #endif
    }
    
    if (!res && _discardPolicy == OERingBufferDiscardPolicyOldest) {
        os_unfair_lock_lock(&fifoLock);

        if (length > buffer.length) {
            NSUInteger discard = length - buffer.length;
            #ifdef DEBUG
            os_log_error(OE_LOG_AUDIO_WRITE, "discarding %lu bytes because buffer is too small (%lu bytes used)", discard, self.availableBytes);
            #endif
            length = buffer.length;
            inBuffer += discard;
        }
        
        NSInteger overflow = MAX(0, (buffer.fillCount + length) - buffer.length);
        if (overflow > 0)
            TPCircularBufferConsume(&buffer, (uint32_t)overflow);
        res = TPCircularBufferProduceBytes(&buffer, inBuffer, (int)length);
        
        os_unfair_lock_unlock(&fifoLock);
    }

    return res;
}

static NSUInteger readBuffer(OERingBuffer *buf, void *outBuffer, NSUInteger len)
{
    uint32_t availableBytes = 0;
    OERingBufferDiscardPolicy discardPolicy = buf->_discardPolicy;
    if (discardPolicy == OERingBufferDiscardPolicyOldest)
        os_unfair_lock_lock(&buf->fifoLock);
    
    void *head = TPCircularBufferTail(&buf->buffer, &availableBytes);

    if (buf->_anticipatesUnderflow) {
        if (availableBytes < 2*len) {
            #ifdef DEBUG
            if (!buf->suppressRepeatedLog) {
                os_log_info(OE_LOG_AUDIO_READ, "available bytes %d <= requested %lu bytes * 2; not returning any byte", availableBytes, len);
                buf->suppressRepeatedLog = YES;
            }
            #endif
            availableBytes = 0;
        } else {
            #ifdef DEBUG
            buf->suppressRepeatedLog = NO;
            #endif
        }
    } else if (availableBytes < len) {
        #ifdef DEBUG
        if (!buf->suppressRepeatedLog) {
            os_log_error(OE_LOG_AUDIO_READ, "tried to consume %lu bytes, but only %d available; will not be logged again until next underflow", len, availableBytes);
            buf->suppressRepeatedLog = YES;
        }
        #endif
    } else {
        #ifdef DEBUG
        buf->suppressRepeatedLog = NO;
        #endif
    }

    availableBytes = MIN(availableBytes, (int)len);
    memcpy(outBuffer, head, availableBytes);
    TPCircularBufferConsume(&buf->buffer, availableBytes);
    
    if (discardPolicy == OERingBufferDiscardPolicyOldest)
        os_unfair_lock_unlock(&buf->fifoLock);

    atomic_fetch_add(&buf->bytesRead, availableBytes);
    return availableBytes;
}

- (NSUInteger)read:(void *)outBuffer maxLength:(NSUInteger)len
{
    return readBuffer(self, outBuffer, len);
}

- (OEAudioBufferReadBlock)readBlock
{
    return ^(void *buffer, NSUInteger len){
        return readBuffer(self, buffer, len);
    };
}

- (NSUInteger)availableBytes
{
    return buffer.fillCount;
}

- (NSUInteger)bytesWritten
{
    return atomic_load(&bytesWritten);
}

- (NSUInteger)freeBytes
{
    return buffer.length - buffer.fillCount;
}

@end
