//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVLibRetroGLESCore.h"

#include "dynamic.h"

#import <PVSupport/PVSupport-Swift.h>
#include "core.h"

#pragma clang diagnostic push
#pragma clang diagnostic error "-Wall"

@interface PVLibRetroGLESCore ()
{
    dispatch_semaphore_t glesWaitToBeginFrameSemaphore;
    dispatch_semaphore_t coreWaitToEndFrameSemaphore;
    dispatch_queue_t _callbackQueue;
    NSMutableDictionary *_callbackHandlers;
}
@end

void input_poll(void);

@implementation PVLibRetroGLESCore

- (instancetype)init {
    if (self = [super init]) {
        glesWaitToBeginFrameSemaphore = dispatch_semaphore_create(0);
        coreWaitToEndFrameSemaphore    = dispatch_semaphore_create(0);
    }
    return self;
}

- (BOOL)rendersToOpenGL { return YES; }
- (BOOL)isDoubleBuffered { return YES; }
- (GLenum)pixelType { return GL_UNSIGNED_BYTE; }
- (GLenum)pixelFormat { return GL_BGRA; }
- (GLenum)internalPixelFormat { return GL_RGBA; }
- (const void *)videoBuffer { return NULL; }

- (dispatch_time_t)frameTime {
    float frameTime = 1.0/[self frameInterval];
//    __block BOOL expired = NO;
    dispatch_time_t killTime = dispatch_time(DISPATCH_TIME_NOW, frameTime * NSEC_PER_SEC);
    return killTime;
}

- (void)videoInterrupt {
    dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);
    
    dispatch_semaphore_wait(glesWaitToBeginFrameSemaphore, [self frameTime]);
}

- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
    dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
    
    dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, [self frameTime]);
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

- (void)setPauseEmulation:(BOOL)flag
{
    [super setPauseEmulation:flag];

    if (flag)
    {
        dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
        [self.frontBufferCondition lock];
        [self.frontBufferCondition signal];
        [self.frontBufferCondition unlock];
    }
}

- (void)stopEmulation {
    shouldStop = YES;
    [super stopEmulation];
    
    dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];
}

- (void)resetEmulation {
    [super resetEmulation];
    dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];
}


- (void)startEmulation {
    if(!self.isRunning) {
        [super startEmulation];
        [NSThread detachNewThreadSelector:@selector(runGLESEmuThread) toTarget:self withObject:nil];
    }
}

- (void)runGLESEmuThread {
    @autoreleasepool
    {
        [self.renderDelegate startRenderingOnAlternateThread];

        do {
            switch (self->core_poll_type)
            {
                case POLL_TYPE_EARLY:
                    input_poll();
                    break;
                case POLL_TYPE_LATE:
                    core_input_polled = false;
                    break;
            }
            if (core->retro_run)
                core->retro_run();
            if (core_poll_type == POLL_TYPE_LATE && !core_input_polled)
                input_poll();
        } while(!self.isRunning);
        
        // Unlock rendering thread
        dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

        [super stopEmulation];

//        if(CoreShutdown() != M64ERR_SUCCESS) {
//            ELOG(@"Core shutdown failed");
//        }else {
//            ILOG(@"Core shutdown successfully");
//        }
    }
}


@end

#pragma clang diagnostic pop
