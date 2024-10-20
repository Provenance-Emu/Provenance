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

#import <Foundation/Foundation.h>
#if SWIFT_PACKAGE
#import "TPCircularBuffer.h"
#else
#import "TPCircularBuffer.h"
#endif

@protocol RingBufferProtocol;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface OERingBuffer : NSObject <RingBufferProtocol>
#pragma clang diagnostic pop
{
@public
    TPCircularBuffer buffer;
}

- (nullable instancetype)initWithLength:(BufferSize)length NS_SWIFT_NAME(init(withLength:)) NS_DESIGNATED_INITIALIZER;

@property           BufferSize length;
@property(readonly) BufferSize availableBytesForWriting;
@property(readonly) BufferSize availableBytesForReading;
@property(readonly) BufferSize bytesWritten;
@property(readonly) BufferSize bytesRead;
@property(readonly) BufferSize availableBytes;

/// Reads available bytes into a buffer
/// - Parameters:
///   - buffer: buffer to copy bytes into
///   - len: amount of bytes requested
///  - Return: Amount of bytes copied
- (BufferSize)read:(void *_Nonnull)buffer preferredSize:(BufferSize)len;

/// Copies data from buffer into RingBuffer
/// - Parameters:
///   - buffer: buffer to copy data from
///   - length: length of the buffer
///  - Return: Bool true if written else false
- (BufferSize)write:(const void *_Nonnull)buffer size:(BufferSize)length;


/// Resets the RingBuffer to empty size
/// Note: Does not erase any memory
- (void)reset;
@end
