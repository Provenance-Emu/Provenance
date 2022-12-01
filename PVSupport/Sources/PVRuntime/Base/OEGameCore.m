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

#import "OEGameCore.h"
#import "OEGameCoreController.h"
#import "OEAbstractAdditions.h"
#import "OEDiffQueue.h"
#import "OEAudioBuffer.h"
#import "OERingBuffer.h"
#import "OETimingUtils.h"
#import "OELogging.h"
#import <os/signpost.h>

#ifndef BOOL_STR
#define BOOL_STR(b) ((b) ? "YES" : "NO")
#endif

NSString *const OEGameCoreErrorDomain = @"org.openemu.GameCore.ErrorDomain";

@implementation OEGameCore
{
    NSThread *_gameCoreThread;
    CFRunLoopRef _gameCoreRunLoop;

    void (^_stopEmulationHandler)(void);
    void (^_frameCallback)(NSTimeInterval frameInterval);

    OERingBuffer __strong **ringBuffers;

    OEDiffQueue            *rewindQueue;
    NSUInteger              rewindCounter;

    BOOL                    shouldStop;
    BOOL                    singleFrameStep;
    BOOL                    isRewinding;
    BOOL                    isPausedExecution;

    NSTimeInterval          lastRate;

    NSUInteger frameCounter;
}

@synthesize nextFrameTime;

static Class GameCoreClass = Nil;

+ (void)initialize
{
    if(self == [OEGameCore class])
    {
        GameCoreClass = [OEGameCore class];
    }
}

- (instancetype)init
{
    self = [super init];
    if(self != nil)
    {
        NSUInteger count = [self audioBufferCount];
        ringBuffers = (__strong OERingBuffer **)calloc(count, sizeof(OERingBuffer *));
    }
    return self;
}

- (void)dealloc
{
    for(NSUInteger i = 0, count = [self audioBufferCount]; i < count; i++)
        ringBuffers[i] = nil;

    free(ringBuffers);
}

- (NSString *)pluginName
{
    return [[self owner] pluginName];
}

- (NSString *)biosDirectoryPath
{
    return [[self owner] biosDirectoryPath];
}

- (NSString *)supportDirectoryPath
{
    return [[self owner] supportDirectoryPath];
}

- (NSString *)batterySavesDirectoryPath
{
    return [[self supportDirectoryPath] stringByAppendingPathComponent:@"Battery Saves"];
}

- (BOOL)supportsRewinding
{
    return [[self owner] supportsRewindingForSystemIdentifier:[self systemIdentifier]];
}

- (NSUInteger)rewindInterval
{
    return [[self owner] rewindIntervalForSystemIdentifier:[self systemIdentifier]];
}

- (NSUInteger)rewindBufferSeconds
{
    return [[self owner] rewindBufferSecondsForSystemIdentifier:[self systemIdentifier]];
}

- (OEDiffQueue *)rewindQueue
{
    if(rewindQueue == nil) {
        NSUInteger capacity = ceil(([self frameInterval]*[self rewindBufferSeconds]) / ([self rewindInterval]+1));
        rewindQueue = [[OEDiffQueue alloc] initWithCapacity:capacity];
    }
    return rewindQueue;
}

#pragma mark - Execution

- (void)setFrameCallback:(void (^)(NSTimeInterval frameInterval))block
{
    _frameCallback = block;
}

- (void)performBlock:(void(^)(void))block
{
    if (_gameCoreRunLoop == nil) {
        block();
        return;
    }

    CFRunLoopPerformBlock(_gameCoreRunLoop, kCFRunLoopCommonModes, block);
}

- (void)_gameCoreThreadWithStartEmulationCompletionHandler:(void (^)(void))startCompletionHandler
{
    @autoreleasepool {
        _gameCoreRunLoop = CFRunLoopGetCurrent();

        [self startEmulation];

        if (startCompletionHandler != nil)
            dispatch_async(dispatch_get_main_queue(), startCompletionHandler);

        [self runGameLoop:nil];

        _gameCoreRunLoop = nil;
    }
}

- (void)setupEmulationWithCompletionHandler:(void (^)(void))completionHandler
{
    [self setupEmulation];

    if (completionHandler != nil)
        completionHandler();
}

- (void)setupEmulation
{
}

- (void)startEmulationWithCompletionHandler:(void (^)(void))completionHandler
{
    _gameCoreThread = [[NSThread alloc] initWithTarget:self selector:@selector(_gameCoreThreadWithStartEmulationCompletionHandler:) object:completionHandler];
    _gameCoreThread.name = @"org.openemu.core-thread";
    _gameCoreThread.qualityOfService = NSQualityOfServiceUserInteractive;

    [_gameCoreThread start];
}

- (void)resetEmulationWithCompletionHandler:(void (^)(void))completionHandler
{
    [self performBlock:^{
        [self resetEmulation];

        if (completionHandler)
            dispatch_async(dispatch_get_main_queue(), completionHandler);
    }];
}

- (void)runStartUpFrameWithCompletionHandler:(void(^)(void))handler
{
    [self OE_executeFrame];
    handler();
}

- (void)runGameLoop:(id)anArgument
{
#if 0
    __block NSTimeInterval gameTime = 0;
    __block int wasZero=1;
#endif

    OESetThreadRealtime(1. / (_rate * [self frameInterval]), .007, .03); // guessed from bsnes
    nextFrameTime = OEMonotonicTime();

    while(!shouldStop)
    {
    @autoreleasepool
    {
#if 0
        gameTime += 1. / [self frameInterval];
        if(wasZero && gameTime >= 1)
        {
            NSUInteger audioBytesGenerated = ringBuffers[0].bytesWritten;
            double expectedRate = [self audioSampleRateForBuffer:0];
            NSUInteger audioSamplesGenerated = audioBytesGenerated/(2*[self channelCount]);
            double realRate = audioSamplesGenerated/gameTime;
            NSLog(@"AUDIO STATS: sample rate %f, real rate %f", expectedRate, realRate);
            wasZero = 0;
        }
#endif
        
        [_delegate gameCoreWillBeginFrame];

        BOOL executing = _rate > 0 || singleFrameStep || isPausedExecution;

        if(executing && isRewinding)
        {
            if (singleFrameStep) {
                singleFrameStep = isRewinding = NO;
            }

            os_signpost_interval_begin(OE_LOG_CORE_REWIND, OS_SIGNPOST_ID_EXCLUSIVE, "pop");
            NSData *state = [[self rewindQueue] pop];
            os_signpost_interval_end(OE_LOG_CORE_REWIND, OS_SIGNPOST_ID_EXCLUSIVE, "pop");
            if(state)
            {
                [self OE_executeFrame]; // Core callout

                os_signpost_interval_begin(OE_LOG_CORE_REWIND, OS_SIGNPOST_ID_EXCLUSIVE, "deserializeState");
                [self deserializeState:state withError:nil];
                os_signpost_interval_end(OE_LOG_CORE_REWIND, OS_SIGNPOST_ID_EXCLUSIVE, "deserializeState");
            }
            
        }
        else if(executing)
        {
            singleFrameStep = NO;

            if([self supportsRewinding] && rewindCounter == 0)
            {
                os_signpost_interval_begin(OE_LOG_CORE_REWIND, OS_SIGNPOST_ID_EXCLUSIVE, "serializeState");
                NSData *state = [self serializeStateWithError:nil];
                os_signpost_interval_end(OE_LOG_CORE_REWIND, OS_SIGNPOST_ID_EXCLUSIVE, "serializeState");
                if(state)
                {
                    os_signpost_interval_begin(OE_LOG_CORE_REWIND, OS_SIGNPOST_ID_EXCLUSIVE, "push");
                    [[self rewindQueue] push:state];
                    os_signpost_interval_end(OE_LOG_CORE_REWIND, OS_SIGNPOST_ID_EXCLUSIVE, "push");
                }
                rewindCounter = [self rewindInterval];
            }
            else
            {
                rewindCounter--;
            }

            [self OE_executeFrame]; // Core callout
        }
        
        [_delegate gameCoreWillEndFrame];

        NSTimeInterval frameRate = self.frameInterval; // the frameInterval property is incorrectly named
        NSTimeInterval adjustedRate = _rate ?: 1;
        NSTimeInterval advance = 1.0 / (frameRate * adjustedRate);
        nextFrameTime += advance;
        frameCounter++;

        // Sleep till next time.
        NSTimeInterval realTime = OEMonotonicTime();

        // If we are running more than a second behind, synchronize
        NSTimeInterval timeOver = realTime - nextFrameTime;
        if(timeOver >= 1.0)
        {
            os_log_debug(OE_LOG_DEFAULT, "Synchronizing because we are %g seconds behind", timeOver);
            nextFrameTime = realTime;
        }

        OEWaitUntil(nextFrameTime);
        
        if (_frameCallback)
            _frameCallback(1.0 / frameRate);

        // Service the event loop, which may now contain HID events, exactly once.
        // TODO: If paused, this burns CPU waiting to unpause, because it still runs at 1x rate.
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, 0);
    }
    }

    [[self delegate] gameCoreDidFinishFrameRefreshThread:self];
}

- (void)stopEmulation
{
    [_renderDelegate suspendFPSLimiting];
    shouldStop = YES;
    os_log_debug(OE_LOG_DEFAULT, "Ending thread");
    [self didStopEmulation];
}

- (void)stopEmulationWithCompletionHandler:(void(^)(void))completionHandler;
{
    [self performBlock:^{
        self->_stopEmulationHandler = [completionHandler copy];

        if (self.hasAlternateRenderingThread)
            [self->_renderDelegate willRenderFrameOnAlternateThread];
        else
            [self->_renderDelegate willExecute];

        [self stopEmulation];
    }];
}

- (void)didStopEmulation
{
    if(_stopEmulationHandler != nil)
        dispatch_async(dispatch_get_main_queue(), _stopEmulationHandler);

    _stopEmulationHandler = nil;
}

- (void)startEmulation
{
    if ([self class] == GameCoreClass) return;
    if (_rate != 0) return;

    [_renderDelegate resumeFPSLimiting];
    self.rate = 1;
}

#pragma mark - ABSTRACT METHODS

- (void)resetEmulation
{
    [self doesNotImplementSelector:_cmd];
}

- (void)OE_executeFrame
{
    os_signpost_interval_begin(OE_LOG_CORE_RUN, OS_SIGNPOST_ID_EXCLUSIVE, "OE_executeFrame");
    [_renderDelegate willExecute];
    
    os_signpost_interval_begin(OE_LOG_CORE_RUN, OS_SIGNPOST_ID_EXCLUSIVE, "executeFrame");
    [self executeFrame];
    os_signpost_interval_end(OE_LOG_CORE_RUN, OS_SIGNPOST_ID_EXCLUSIVE, "executeFrame");
    
    [_renderDelegate didExecute];
    os_signpost_interval_end(OE_LOG_CORE_RUN, OS_SIGNPOST_ID_EXCLUSIVE, "OE_executeFrame");
}

- (void)executeFrame
{
    [self doesNotImplementSelector:_cmd];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (BOOL)loadFileAtPath:(NSString *)path
{
    [self doesNotImplementSelector:_cmd];
    return NO;
}
#pragma clang diagostic pop

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    return [self loadFileAtPath:path];
#pragma clang diagnostic pop
}

#pragma mark - Video

- (OEIntRect)screenRect
{
    return (OEIntRect){ {}, [self bufferSize]};
}

- (OEIntSize)bufferSize
{
    [self doesNotImplementSelector:_cmd];
    return (OEIntSize){};
}

- (OEIntSize)aspectSize
{
    return (OEIntSize){ 1, 1 };
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (const void *)videoBuffer
{
    [self doesNotImplementSelector:_cmd];
    return NULL;
}
#pragma clang diagnostic pop

- (GLenum)pixelFormat
{
    [self doesNotImplementSelector:_cmd];
    return 0;
}

- (GLenum)pixelType
{
    [self doesNotImplementSelector:_cmd];
    return 0;
}

- (GLenum)internalPixelFormat
{
    return GL_RGB;
}

- (NSInteger)bytesPerRow
{
    // This default implementation returns bufferSize.width * bytesPerPixel
    // Calculating bytes per pixel from the OpenGL enums needs a lot of entries.

    GLenum pixelFormat = self.pixelFormat;
    GLenum pixelType = self.pixelType;
    int nComponents = 0, bytesPerComponent = 0, bytesPerPixel = 0;

    switch (pixelFormat) {
        case GL_LUMINANCE:
            nComponents = 1;
            break;
        case GL_RGB:
#if TARGET_OS_OSX
        case GL_BGR:
#endif
            nComponents = 3;
            break;
        case GL_RGBA:
        case GL_BGRA:
            nComponents = 4;
            break;
    }

    switch (pixelType) {
        case GL_UNSIGNED_BYTE:
            bytesPerComponent = 1;
            break;
        case GL_UNSIGNED_SHORT_5_6_5:
#if TARGET_OS_OSX
        case GL_UNSIGNED_SHORT_5_6_5_REV:
#endif
        case GL_UNSIGNED_SHORT_4_4_4_4:
        case GL_UNSIGNED_SHORT_4_4_4_4_REV:
        case GL_UNSIGNED_SHORT_5_5_5_1:
        case GL_UNSIGNED_SHORT_1_5_5_5_REV:
            bytesPerPixel = 2;
            break;
#if TARGET_OS_OSX
        case GL_UNSIGNED_INT_8_8_8_8:
        case GL_UNSIGNED_INT_8_8_8_8_REV:
        case GL_UNSIGNED_INT_10_10_10_2:
#endif
        case GL_UNSIGNED_INT_2_10_10_10_REV:
            bytesPerPixel = 4;
            break;
    }

    if (!bytesPerPixel) bytesPerPixel = nComponents * bytesPerComponent;
    NSAssert(bytesPerPixel, @"Couldn't calculate bytesPerRow: %#x %#x", pixelFormat, pixelType);

    return bytesPerPixel * self.bufferSize.width;
}

- (BOOL)hasAlternateRenderingThread
{
    return NO;
}

- (BOOL)needsDoubleBufferedFBO
{
    return NO;
}

- (OEGameCoreRendering)gameCoreRendering {
    return OEGameCoreRendering2DVideo;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

- (const void*)getVideoBufferWithHint:(void *)hint
{
    return [self videoBuffer];
}

#pragma clang diagnostic pop

- (BOOL)tryToResizeVideoTo:(OEIntSize)size
{
    if (self.gameCoreRendering == OEGameCoreRendering2DVideo)
        return NO;

    return YES;
}

- (NSTimeInterval)frameInterval
{
    return 60.0;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)fastForward:(BOOL)flag
{
    float newrate = flag ? 5.0 : 1.0;
  
    if (self.isEmulationPaused) {
        lastRate = newrate;
    } else {
        self.rate = newrate;
    }
}
#pragma clang diagnostic pop

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)rewind:(BOOL)flag
{
    if(flag && [self supportsRewinding] && ![[self rewindQueue] isEmpty])
    {
        isRewinding = YES;
    }
    else
    {
        isRewinding = NO;
    }
}
#pragma clang diagnostic pop

- (void)setPauseEmulation:(BOOL)paused
{
    if (self.rate == 0 && paused)  return;
    if (self.rate != 0 && !paused) return;

    // Set rate to 0 and store the previous rate.
    if (paused) {
        lastRate = self.rate;
        self.rate = 0;
    } else {
        self.rate = lastRate;
    }
}

- (BOOL)isEmulationPaused
{
    return _rate == 0;
}

- (void)stepFrameForward
{
    singleFrameStep = YES;
}

- (void)stepFrameBackward
{
    singleFrameStep = isRewinding = YES;
}

- (void)setRate:(float)rate
{
    os_log_debug(OE_LOG_DEFAULT, "Rate change %f -> %f", _rate, rate);

    _rate = rate;
    if (_rate > 0.001)
      OESetThreadRealtime(1./(_rate * [self frameInterval]), .007, .03);
}

- (void)beginPausedExecution
{
    if (isPausedExecution == YES) return;

    isPausedExecution = YES;
    [_renderDelegate suspendFPSLimiting];
    [_audioDelegate pauseAudio];
}

- (void)endPausedExecution
{
    if (isPausedExecution == NO) return;

    isPausedExecution = NO;
    [_renderDelegate resumeFPSLimiting];
    [_audioDelegate resumeAudio];
}

#pragma mark - Audio

- (id<OEAudioBuffer>)audioBufferAtIndex:(NSUInteger)index
{
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self ringBufferAtIndex:index];
    #pragma clang diagnostic pop
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (OERingBuffer *)ringBufferAtIndex:(NSUInteger)index
{
    NSAssert1(index < [self audioBufferCount], @"The index %lu is too high", index);
    
    OERingBuffer *result = ringBuffers[index];
    if(result == nil) {
        /* ring buffer is 0.05 seconds
         * the larger the buffer, the higher the maximum possible audio lag */
        double frameSampleCount = [self audioSampleRateForBuffer:index] * 0.1;
        NSUInteger channelCount = [self channelCountForBuffer:index];
        NSUInteger bytesPerSample = [self audioBitDepth] / 8;
        NSAssert(frameSampleCount, @"frameSampleCount is 0");
        NSUInteger len = channelCount * bytesPerSample * frameSampleCount;
        NSUInteger coreRequestedLen = [self audioBufferSizeForBuffer:index] * 2;
        len = MAX(coreRequestedLen, len);
        
        result = [[OERingBuffer alloc] initWithLength:len];
        [result setDiscardPolicy:OERingBufferDiscardPolicyOldest];
        [result setAnticipatesUnderflow:YES];
        ringBuffers[index] = result;
    }

    return result;
}
#pragma clang diagnostic pop

- (NSUInteger)audioBufferCount
{
    return 1;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

- (void)getAudioBuffer:(void *)buffer frameCount:(NSUInteger)frameCount bufferIndex:(NSUInteger)index
{
    [[self ringBufferAtIndex:index] read:buffer maxLength:frameCount * [self channelCountForBuffer:index] * sizeof(UInt16)];
}

#pragma clang diagnostic pop

- (NSUInteger)channelCount
{
    [self doesNotImplementSelector:_cmd];
    return 0;
}

- (double)audioSampleRate
{
    [self doesNotImplementSelector:_cmd];
    return 0;
}

- (NSUInteger)audioBitDepth
{
    return 16;
}

- (NSUInteger)channelCountForBuffer:(NSUInteger)buffer
{
    if(buffer == 0) return [self channelCount];

    os_log_error(OE_LOG_DEFAULT, "Buffer count is greater than 1, must implement %{public}@", NSStringFromSelector(_cmd));

    [self doesNotImplementSelector:_cmd];
    return 0;
}

- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer
{
    double frameSampleCount = [self audioSampleRateForBuffer:buffer] / [self frameInterval];
    NSUInteger channelCount = [self channelCountForBuffer:buffer];
    NSUInteger bytesPerSample = [self audioBitDepth] / 8;
    NSAssert(frameSampleCount, @"frameSampleCount is 0");
    return channelCount * bytesPerSample * frameSampleCount;
}

- (double)audioSampleRateForBuffer:(NSUInteger)buffer
{
    if(buffer == 0) return [self audioSampleRate];

    os_log_error(OE_LOG_DEFAULT, "Buffer count is greater than 1, must implement %{public}@", NSStringFromSelector(_cmd));

    [self doesNotImplementSelector:_cmd];
    return 0;
}


#pragma mark - Save state

- (NSData *)serializeStateWithError:(NSError **)outError
{
    return nil;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError
{
    return NO;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void(^)(BOOL success, NSError *error))block
{
    block(NO, [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreDoesNotSupportSaveStatesError userInfo:nil]);
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void(^)(BOOL success, NSError *error))block
{
    block(NO, [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreDoesNotSupportSaveStatesError userInfo:nil]);
}

#pragma mark - Cheats

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
}

#pragma mark - Misc

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)changeDisplayMode;
{
}
#pragma clang diagnostic pop

#pragma mark - Discs

- (NSUInteger)discCount
{
    return 1;
}

- (void)setDisc:(NSUInteger)discNumber
{
}

#pragma mark - File Insertion

- (void)insertFileAtURL:(NSURL *)url completionHandler:(void(^)(BOOL success, NSError *error))block
{
    block(NO, [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotLoadROMError userInfo:nil]);
}

#pragma mark - Display Mode

- (NSArray<NSDictionary<NSString *, id> *> *)displayModes
{
    return nil;
}

- (void)changeDisplayWithMode:(NSString *)displayMode
{
}

@end
