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
#include "video_driver.h"

#import <PVSupport/PVSupport-Swift.h>
#include "core.h"
#include "runloop.h"
@import PVLoggingObjC;

#pragma clang diagnostic push
#pragma clang diagnostic error "-Wall"

bool inside_loop     = true;
//static bool first_run = true;
volatile bool has_init = false;

extern bool core_frame(retro_ctx_frame_info_t *info);
extern bool runloop_ctl(enum runloop_ctl_state state, void *data);

#include <mach/mach.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <assert.h>
#include <poll.h>
#include <termios.h>
#include <fcntl.h>
#include <semaphore.h>
#include <stdarg.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <unistd.h>

void move_pthread_to_realtime_scheduling_class(pthread_t pthread)
{
    mach_timebase_info_data_t timebase_info;
    mach_timebase_info(&timebase_info);

    const uint64_t NANOS_PER_MSEC = 1000000ULL;
    double clock2abs = ((double)timebase_info.denom / (double)timebase_info.numer) * NANOS_PER_MSEC;

    thread_time_constraint_policy_data_t policy;
    policy.period      = 0;
    policy.computation = (uint32_t)(5 * clock2abs); // 5 ms of work
    policy.constraint  = (uint32_t)(10 * clock2abs);
    policy.preemptible = FALSE;

    int kr = thread_policy_set(pthread_mach_thread_np(pthread_self()),
                               THREAD_TIME_CONSTRAINT_POLICY,
                               (thread_policy_t)&policy,
                               THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    if (kr != KERN_SUCCESS) {
        mach_error("thread_policy_set:", kr);
        exit(1);
    }
}

void MakeCurrentThreadRealTime()
{
    move_pthread_to_realtime_scheduling_class(pthread_self());
}

@interface PVLibRetroGLESCore ()
{
    dispatch_semaphore_t glesWaitToBeginFrameSemaphore;
    dispatch_semaphore_t coreWaitToEndFrameSemaphore;
    dispatch_semaphore_t coreWaitForExitSemaphore;

    dispatch_queue_t _callbackQueue;
    NSMutableDictionary *_callbackHandlers;
}
@end

void input_poll(void);

void gl_swap() {
    GET_CURRENT_OR_RETURN();
    [current swapBuffers];
}

@implementation PVLibRetroGLESCore

- (instancetype)init {
    if (self = [super init]) {
        glesWaitToBeginFrameSemaphore = dispatch_semaphore_create(0);
        coreWaitToEndFrameSemaphore    = dispatch_semaphore_create(0);
        coreWaitForExitSemaphore       = dispatch_semaphore_create(0);
    }
    return self;
}

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
-(EAGLContext*)bestContext {
    EAGLContext* context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    self.glesVersion = GLESVersion3;
    if (context == nil)
    {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        self.glesVersion = GLESVersion2;
    }

    return context;
}
#endif

//- (BOOL)loadFileAtPath:(NSString *)path error:(NSError * _Nullable __autoreleasing *)error {
//#if !TARGET_OS_MACCATALYST
//    EAGLContext* context = [self bestContext];
//    ILOG(@"%i", context.API);
//#endif
//
//    return [super loadFileAtPath:path error:error];
//}

- (BOOL)rendersToOpenGL { return YES; }
- (BOOL)isDoubleBuffered { return YES; }
- (GLenum)pixelFormat { return GL_UNSIGNED_SHORT_5_6_5; }
- (GLenum)pixelType { return GL_UNSIGNED_BYTE; }
- (GLenum)internalPixelFormat { return GL_RGBA; }
- (GLenum)depthFormat {
        // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
    return GL_DEPTH_COMPONENT16;
}
- (const void *)videoBuffer { return NULL; }

- (dispatch_time_t)frameTime {
    float frameTime = 1.0/[self frameInterval];
//    __block BOOL expired = NO;
    dispatch_time_t killTime = dispatch_time(DISPATCH_TIME_NOW, frameTime * NSEC_PER_SEC);
    return killTime;
}

- (void)videoInterrupt {
//    dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);
//
//    dispatch_semaphore_wait(glesWaitToBeginFrameSemaphore, [self frameTime]);
}

- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
//    dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
//
//    dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, [self frameTime]);
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
    has_init = false;

    self->shouldStop = YES;
    dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);

    [self.frontBufferCondition lock];
    [self.frontBufferCondition signal];
    [self.frontBufferCondition unlock];
    
    [super stopEmulation];
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
        [NSThread detachNewThreadSelector:@selector(runGLESRenderThread) toTarget:self withObject:nil];
    }
}


void* libPvr_GetRenderTarget() {
    return 0;
}

void* libPvr_GetRenderSurface() {
    return 0;

}

bool gl_init(void*, void*) {
    return true;
}

bool gles_init()
{

    if (!gl_init((void*)libPvr_GetRenderTarget(),
                 (void*)libPvr_GetRenderSurface()))
            return false;

#if defined(GLES) && HOST_OS != OS_DARWIN && !defined(TARGET_NACL32)
    #ifdef TARGET_PANDORA
    fbdev=open("/dev/fb0", O_RDONLY);
    #else
    eglSwapInterval(gl.setup.display,1);
    #endif
#endif

    //clean up all buffers ...
    for (int i=0;i<10;i++)
    {
        glClearColor(0.f, 0.f, 0.f, 0.f);
        glClear(GL_COLOR_BUFFER_BIT);
        gl_swap();
    }

    return true;
}

static bool video_driver_cached_frame(void)
{
   retro_ctx_frame_info_t info;
//   void *recording  = recording_driver_get_data_ptr();

   if (runloop_ctl(RUNLOOP_CTL_IS_IDLE, NULL))
      return false; /* Maybe return false here for indication of idleness? */

   /* Cannot allow recording when pushing duped frames. */
//   recording_driver_clear_data_ptr();

   /* Not 100% safe, since the library might have
    * freed the memory, but no known implementations do this.
    * It would be really stupid at any rate ...
    */
   info.data        = NULL;
   info.width       = video_driver_state.frame_cache.width;
   info.height      = video_driver_state.frame_cache.height;
   info.pitch       = video_driver_state.frame_cache.pitch;

   if (video_driver_state.frame_cache.data != RETRO_HW_FRAME_BUFFER_VALID)
      info.data = video_driver_state.frame_cache.data;

   core_frame(&info);

//   recording_driver_set_data_ptr(recording);

   return true;
}

- (void)runGLESRenderThread {
    @autoreleasepool
    {
        [[NSThread currentThread] setName:@"runGLESRenderThread"];
        [self.renderDelegate startRenderingOnAlternateThread];
//        BOOL success = gles_init();
//        assert(success);
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    EAGLContext* context = [self bestContext];
    ILOG(@"%i", context.API);
#endif
        [NSThread detachNewThreadSelector:@selector(runGLESEmuThread) toTarget:self withObject:nil];

//        CFAbsoluteTime lastTime = CFAbsoluteTimeGetCurrent();

        while (!has_init) {}
        while ( !shouldStop )
        {
            [self.frontBufferCondition lock];
            while (!shouldStop && self.isFrontBufferReady) [self.frontBufferCondition wait];
            [self.frontBufferCondition unlock];

//            CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
//            CFTimeInterval deltaTime = now - lastTime;
            while ( !shouldStop
                   && !video_driver_cached_frame()
//                   && core_poll()
                   ) {}
            [self swapBuffers];
//            lastTime = now;
        }
    }
}



- (void)runGLESEmuThread {
    @autoreleasepool
    {
        [[NSThread currentThread] setName:@"runGLESEmuThread"];
        [self libretroMain];
        // Core returns

        // Unlock rendering thread
        dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

        [super stopEmulation];
    }
}


- (void)libretroMain {
   
    MakeCurrentThreadRealTime();

//    [self.renderDelegate startRenderingOnAlternateThread];
    has_init = true;
    
    
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
    } while(!shouldStop);

    has_init = false;
    
    dispatch_semaphore_signal(coreWaitForExitSemaphore);
}

- (CGSize)bufferSize {
    return CGSizeMake(2048, 2048);
}

@end

#pragma clang diagnostic pop
