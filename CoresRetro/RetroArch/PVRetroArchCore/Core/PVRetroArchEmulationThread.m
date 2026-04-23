//
//  PVRetroArchEmulationThread.m
//  PVRetroArch
//

#import "PVRetroArchEmulationThread.h"
#import <Foundation/Foundation.h>
#import <pthread.h>

static NSThread *s_emuThread = nil;
static CFRunLoopRef s_emuRunLoop = NULL;
static dispatch_semaphore_t s_emuRunLoopReady;
static pthread_once_t s_startOnce = PTHREAD_ONCE_INIT;
static volatile BOOL s_emuStopRequested = NO;

@interface PVRetroArchEmuThreadRunner : NSObject
+ (void)threadMain:(id)object;
@end

@implementation PVRetroArchEmuThreadRunner

+ (void)threadMain:(id)object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"com.provenance.retroarch.emu"];
        [[NSThread currentThread] setThreadPriority:0.9];

        CFRunLoopRef rl = CFRunLoopGetCurrent();
        s_emuRunLoop = rl;

        // Keep the runloop alive — without an attached source, CFRunLoopRun
        // returns immediately. NSPort gives us a no-op source we can later
        // remove to let the runloop exit.
        NSPort *keepAlivePort = [NSPort port];
        [[NSRunLoop currentRunLoop] addPort:keepAlivePort forMode:NSRunLoopCommonModes];

        dispatch_semaphore_signal(s_emuRunLoopReady);

        while (!s_emuStopRequested) {
            @autoreleasepool {
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0e10, false);
            }
        }

        [[NSRunLoop currentRunLoop] removePort:keepAlivePort forMode:NSRunLoopCommonModes];
        s_emuRunLoop = NULL;
    }
}

@end

static void pv_retro_emu_thread_start_impl(void) {
    s_emuRunLoopReady = dispatch_semaphore_create(0);
    s_emuStopRequested = NO;
    s_emuThread = [[NSThread alloc] initWithTarget:[PVRetroArchEmuThreadRunner class]
                                          selector:@selector(threadMain:)
                                            object:nil];
    s_emuThread.qualityOfService = NSQualityOfServiceUserInteractive;
    [s_emuThread start];

    // Wait (briefly) for the thread to install its runloop. Bounded so a
    // pathological start does not hang the caller forever.
    dispatch_semaphore_wait(s_emuRunLoopReady,
                            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)));
}

void pv_retro_emu_thread_start(void) {
    pthread_once(&s_startOnce, pv_retro_emu_thread_start_impl);
}

CFRunLoopRef pv_retro_emu_thread_runloop(void) {
    return s_emuRunLoop;
}

void pv_retro_emu_thread_wakeup(void) {
    CFRunLoopRef rl = s_emuRunLoop;
    if (rl) {
        CFRunLoopWakeUp(rl);
    }
}

void pv_retro_emu_thread_stop(void) {
    s_emuStopRequested = YES;
    CFRunLoopRef rl = s_emuRunLoop;
    if (rl) {
        CFRunLoopStop(rl);
    }
}
