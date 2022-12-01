// Copyright (c) 2018, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <Foundation/Foundation.h>

/**
 Reads the specified amount of bytes into the destination buffer.
 
 @param buffer Pointer to where to store the data after reading.
 @param bytesRequested Amount of bytes to be read.
 
 @returns The number of bytes read.
 */
typedef NSUInteger (^OEAudioBufferReadBlock)(void * buffer, NSUInteger bytesRequested);

@protocol OEAudioBuffer <NSObject>

/**
 * Reads the specified amount of bytes from the buffer.
 * @param buffer Pointer to where to store the data after reading.
 * @param len Amount of bytes to be read.
 * @returns The amount of bytes effectively read.
 */
- (NSUInteger)read:(void *)buffer maxLength:(NSUInteger)len;

/**
 * Writes the specified amount of bytes to the buffer.
 * @param buffer Pointer to the data to be written.
 * @param length Amount of bytes to be written.
 * @returns The amount of bytes effectively written.
 */
- (NSUInteger)write:(const void *)buffer maxLength:(NSUInteger)length;

/**
 * The maximum amount of bytes that can be read at once.
 */
@property(readonly) NSUInteger length;

@optional

/**
 Returns a block which can be used to read data from the buffer.
 */
- (OEAudioBufferReadBlock)readBlock;

@end



