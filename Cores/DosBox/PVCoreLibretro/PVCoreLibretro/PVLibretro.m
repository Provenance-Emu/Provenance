//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVLibretro.h"

#import <PVSupport/PVSupport-Swift.h>

#if !TARGET_OS_MACCATALYST
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

#pragma clang diagnostic push
#pragma clang diagnostic error "-Wall"

#define WIDTH 256
#define HEIGHT 240

@interface PVLibRetroCore ()
{
    uint32_t *videoBuffer;
    NSUInteger currentDisc;
}
@end

@implementation PVLibRetroCore
static __weak PVLibRetroCore *_current;

- (instancetype)init {
    if((self = [super init]))
    {
        videoBuffer = (uint32_t *)malloc(WIDTH * HEIGHT * 4);
        currentDisc = 1;
    }

    _current = self;

    return self;
}

- (void)dealloc {
    free(videoBuffer);
}

- (void)internalSwapDisc:(NSUInteger)discNumber {
    if (discNumber == currentDisc) {
        WLOG(@"Won't swap for same disc number <%lul>", (unsigned long)discNumber);
        return;
    }
    currentDisc = discNumber;
    
    [self setPauseEmulation:NO];


    // DO Swap
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    NSURL *batterySavesDirectory = [NSURL fileURLWithPath:[self batterySavesPath]];
    [[NSFileManager defaultManager] createDirectoryAtURL:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:nil];

    return YES;
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
//    for (unsigned y = 0; y < HEIGHT; y++)
//        for (unsigned x = 0; x < WIDTH; x++, pXBuf++)
//            videoBuffer[y * WIDTH + x] = palette[*pXBuf];
//
//    for (int i = 0; i < soundSize; i++)
//        soundBuffer[i] = (soundBuffer[i] << 16) | (soundBuffer[i] & 0xffff);
//
//    [[self ringBufferAtIndex:0] write:soundBuffer maxLength:soundSize << 2];
}

- (void)resetEmulation {
}

- (void)stopEmulation {
    // Stop
    [super stopEmulation];
}

- (NSTimeInterval)frameInterval {
    return 1.0 / 60.0;
}

# pragma mark - Video

- (const void *)videoBuffer {
    return videoBuffer;
}

- (CGRect)screenRect {
    return CGRectMake(0, 0, WIDTH, HEIGHT);
}

- (CGSize)aspectSize
{
    return CGSizeMake(4, 3);
}

- (CGSize)bufferSize
{
    return CGSizeMake(WIDTH, HEIGHT);
}

- (GLenum)pixelFormat {
    return GL_BGRA;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat {
    return GL_RGBA;
}

# pragma mark - Audio

- (double)audioSampleRate {
    return 44100;
}

- (NSUInteger)channelCount {
    return 2;
}

# pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    @synchronized(self) {
        // Save
        return YES;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error {
    @synchronized(self) {
        BOOL success = NO; //Load()
        if (!success) {
            if(error != NULL) {
                NSDictionary *userInfo = @{
                                           NSLocalizedDescriptionKey: @"Failed to save state.",
                                           NSLocalizedFailureReasonErrorKey: @"Core failed to load save state.",
                                           NSLocalizedRecoverySuggestionErrorKey: @""
                                           };

                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];

                *error = newError;
            }
        }
        return success;
    }
}
@end
#pragma clang diagnostic pop
