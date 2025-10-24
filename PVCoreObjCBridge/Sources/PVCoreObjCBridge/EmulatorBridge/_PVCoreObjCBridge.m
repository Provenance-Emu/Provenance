//
//  PVCoreObjCBridge.m
//  Provenance
//
//  Created by James Addyman on 31/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "_PVCoreObjCBridge.h"
@import PVAudio;
@import PVCoreAudio;
@import PVLogging;
@import PVLoggingObjC;
@import PVObjCUtils;
@import AVFoundation;
@import CoreGraphics;
@import PVCoreBridge;
@import PVSettings;
#import "NSObject+PVAbstractAdditions.h"
#include <pthread.h>
#include <mach/mach.h>
#include <mach/thread_policy.h>

#if !TARGET_OS_OSX
@import UIKit;
#else
@import AppKit;
#endif

/* Timing */
#include <mach/mach_time.h>
#import <QuartzCore/QuartzCore.h>

#define PVTimestamp() (((double)mach_absolute_time()) * 1.0e-09  * timebase_ratio)
//#define PVTimestamp() CACurrentMediaTime()
#define GetSecondsSince(x) (PVTimestamp() - x)

static Class PVEmulatorCoreClass = Nil;
static NSTimeInterval defaultFrameInterval = 60.0;

// Different machines have different mach_absolute_time to ms ratios
// calculate this on init
static double timebase_ratio;

/**
 * Makes the current thread real-time with the specified priority.
 * This function uses the mach thread policy to set real-time parameters.
 *
 * @param period The period in seconds (e.g., 0.005 for 5ms)
 * @param computation The computation time needed within each period (e.g., 0.003 for 3ms)
 * @param constraint The maximum time by which thread scheduling can be delayed (e.g., 0.004 for 4ms)
 * @param preemptible Whether the thread can be preempted (YES for most cases)
 * @return YES if successful, NO otherwise
 */
BOOL iMakeCurrentThreadRealTime(double period, double computation, double constraint, BOOL preemptible);


NSString *const PVEmulatorCoreErrorDomain = @"org.provenance-emu.EmulatorCore.ErrorDomain";

@interface PVCoreObjCBridge()
@property (nonatomic, strong, readwrite, nonnull) NSLock  *emulationLoopThreadLock;
@property (nonatomic, strong, readwrite, nonnull) NSCondition  *frontBufferCondition;
@property (nonatomic, strong, readwrite, nonnull) NSLock  *frontBufferLock;

@property (nonatomic, assign) CGFloat  framerateMultiplier;
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, assign) BOOL isDoubleBufferedCached;
#if TARGET_OS_IOS
@property (nonatomic, strong, readwrite, nullable) UIImpactFeedbackGenerator* rumbleGenerator;
#endif
@end

//PV_OBJC_DIRECT_MEMBERS
@implementation PVCoreObjCBridge

+ (void)initialize {
    if (self == [PVCoreObjCBridge class]) {
        PVEmulatorCoreClass = [PVCoreObjCBridge class];
    }

	if (timebase_ratio == 0) {
		mach_timebase_info_data_t s_timebase_info;
		(void) mach_timebase_info(&s_timebase_info);

		timebase_ratio = (float)s_timebase_info.numer / s_timebase_info.denom;
	}
}

- (instancetype)init {
	if ((self = [super init])) {
        NSUInteger count         = [self audioBufferCount];
        ringBuffers              = [[NSMutableArray<id<RingBufferProtocol>> alloc] init];
        _emulationLoopThreadLock = [NSLock new];
        _frontBufferCondition    = [NSCondition new];
        _frontBufferLock         = [NSLock new];
        _isFrontBufferReady      = NO;
        _gameSpeed               = GameSpeedNormal;
        _isDoubleBufferedCached = [self isDoubleBuffered];
        _skipEmulationLoop       = NO;
        _alwaysUseMetal          = NO;
        _skipLayout              = NO;
        _extractArchive          = YES;
        _isOn                    = NO;
	}

	return self;
}
- (void)initialize {
}

- (void)dealloc {
    if(self.isRunning) {
        [self stopEmulation];
    }
}

- (NSError * _Nonnull)createError:(NSString * _Nonnull)message {
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: message,
                               NSLocalizedFailureReasonErrorKey: @"Core does not implement this method.",
                               NSLocalizedRecoverySuggestionErrorKey: @"Write this method."
                               };

    NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                            code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                        userInfo:userInfo];
    return newError;
}

- (void)setFramerateMultiplier:(CGFloat)framerateMultiplier {
    if ( _framerateMultiplier != framerateMultiplier ) {
        _framerateMultiplier = framerateMultiplier;
        NSLog(@"multiplier: %.1f", framerateMultiplier);
    }
    gameInterval = 1.0 / ([self frameInterval] * framerateMultiplier);
}

#if !TARGET_OS_TV && !TARGET_OS_OSX && !TARGET_OS_WATCH
- (Float64) getSampleRate {
    return [[AVAudioSession sharedInstance] sampleRate];
}

- (BOOL) setPreferredSampleRate:(double)preferredSampleRate error:(NSError **)error {
    double preferredSampleRate2 = preferredSampleRate ?: 48000;
    return [[AVAudioSession sharedInstance] setPreferredSampleRate:preferredSampleRate2 error:error];
}
#endif

-(NSUInteger)discCount {
    return 0;
}

static NSString *_coreClassName;
+ (NSString *)coreClassName {
    // options are identified by classname
    if (_coreClassName && ([_coreClassName containsString:@"dylib"] || [_coreClassName containsString:@"framework"])) {
        return _coreClassName;
    }
    return NSStringFromClass(self);
}
+ (void)setCoreClassName:(NSString *)name {
    _coreClassName=name;
}
static NSString *_systemName;
+ (NSString *)systemName {
    if (_systemName)
        return _systemName;
    return NSStringFromClass(self);
}
+ (void)setSystemName:(NSString *)name {
    _systemName=name;
}
//@end

//@implementation PVCoreObjCBridge (Rumble)

//@dynamic supportsRumble;

- (BOOL) suppportRumble { return NO; }

#if !TARGET_OS_TV && !TARGET_OS_WATCH
-(BOOL)startHaptic {
    if (!NSThread.isMainThread) {
        __block BOOL started = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            started = [self startHaptic];
        });
        return started;
    }

#if !TARGET_OS_OSX && !TARGET_OS_WATCH && !TARGET_OS_VISION
    if (self.supportsRumble && !(self.controller1 != nil && !self.controller1.isAttachedToDevice)) {
        self.rumbleGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [self.rumbleGenerator prepare];
        return YES;
    }
#endif

    return NO;
}

-(void)stopHaptic {
#if !TARGET_OS_OSX && !TARGET_OS_WATCH && !TARGET_OS_VISION
    if (!NSThread.isMainThread) {
        MAKEWEAK(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            MAKESTRONG_RETURN_IF_NIL(self);
            [strongself stopHaptic];
        });
        return;
    }
    self.rumbleGenerator = nil;
#endif
}
#else
// Unsupported
-(void)startHaptic { }
-(void)stopHaptic { }
#endif

//@end

//@implementation PVCoreObjCBridge (Runloop)

//@dynamic gameSpeed;
//@dynamic isOn;

#pragma mark - Execution


- (BOOL)loadFileAtPath:(NSString *)path {
    [self doesNotImplementSelector:_cmd];
    return NO;
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    return [self loadFileAtPath:path];
}

- (void) emulationLoopThread {

    // For FPS computation
    int frameCount = 0;
    int framesTorn = 0;

    NSTimeInterval fpsCounter = PVTimestamp();

    //Setup Initial timing
    NSTimeInterval origin = PVTimestamp();

    NSTimeInterval sleepTime = 0;
    NSTimeInterval nextEmuTick = GetSecondsSince(origin);

    [self.emulationLoopThreadLock lock];

    //Become a real-time thread:
    //@ 9:40 iMakeCurrentThreadRealTime();

    // Calculate parameters based on self.frameInterval
    double period = 1.0 / self.frameInterval;
    double computation = period * 0.8;  // 80% of period
    double constraint = period * 0.9;   // 90% of period

    // For reference:
    // For 60 FPS (16.67ms per frame): period=0.01667, computation=0.01333, constraint=0.01500
    // For 120 FPS (8.33ms per frame): period=0.00833, computation=0.00666, constraint=0.00750

    if (iMakeCurrentThreadRealTime(period, computation, constraint, YES)) {
        ILOG(@"Thread is now real-time at %.1f FPS (period=%.5fs, computation=%.5fs, constraint=%.5fs)",
             self.frameInterval, period, computation, constraint);
    } else {
        ELOG(@"Failed to make thread real-time, emulation may experience timing issues");
    }

    //Emulation loop
    while (UNLIKELY(!_shouldStop)) {

        [self updateControllers];

        @synchronized (self) {
            if (_isRunning) {
                if (self.isSpeedModified) {
                    // TODO: Is this correct? We should expose the skip version
                    [self executeFrame];
                } else {
                    [self executeFrame];
                }
            }
        }
        frameCount += 1;

        nextEmuTick += gameInterval;
        sleepTime = nextEmuTick - GetSecondsSince(origin);

        if (_isDoubleBufferedCached) {
            NSDate* bufferSwapLimit = [[NSDate date] dateByAddingTimeInterval:sleepTime];
            if ([self.frontBufferLock tryLock] || [self.frontBufferLock lockBeforeDate:bufferSwapLimit]) {
                [self swapBuffers];
                [self.frontBufferLock unlock];

                [self.frontBufferCondition lock];
                [self setIsFrontBufferReady:YES];
                [self.frontBufferCondition signal];
                [self.frontBufferCondition unlock];
            } else {
                [self swapBuffers];
                ++framesTorn;

                [self setIsFrontBufferReady:YES];
            }

            sleepTime = nextEmuTick - GetSecondsSince(origin);
        }

        if(sleepTime >= 0) {
            //#if !defined(DEBUG)
            [NSThread sleepForTimeInterval:sleepTime];
            //#endif
        }
        else if (sleepTime < -0.1) {
            // We're behind, we need to reset emulation time,
            // otherwise emulation will "catch up" to real time
            origin = PVTimestamp();
            nextEmuTick = GetSecondsSince(origin);
        }

        // Compute FPS
        NSTimeInterval timeSinceLastFPS = GetSecondsSince(fpsCounter);
        if (timeSinceLastFPS >= 0.5) {
            self.emulationFPS = (double)frameCount / timeSinceLastFPS;
            self.renderFPS = (double)(frameCount - framesTorn) / timeSinceLastFPS;
            frameCount = 0;
            framesTorn = 0;
            fpsCounter = PVTimestamp();
        }
    }

    [self.emulationLoopThreadLock unlock];
}

- (void)setGameSpeed:(GameSpeed)gameSpeed {
    _gameSpeed = gameSpeed;

    switch (gameSpeed) {
        case GameSpeedVerySlow:
            self.framerateMultiplier = 0.25;
            break;
        case GameSpeedSlow:
            self.framerateMultiplier = 0.5;
            break;
        case GameSpeedNormal:
            self.framerateMultiplier = 1.0;
            break;
        case GameSpeedFast:
            self.framerateMultiplier = 2.0;
            break;
        case GameSpeedVeryFast:
            self.framerateMultiplier = 5.0;
            break;
    }
}

- (BOOL)isSpeedModified {
    return self.gameSpeed != GameSpeedNormal;
}

- (void)startEmulation {
    if ([self class] != PVEmulatorCoreClass) {
        if (!_isRunning) {
#if !TARGET_OS_TV && !TARGET_OS_OSX && !TARGET_OS_WATCH
            [self startHaptic];
            NSError *error;
            BOOL success = [self setPreferredSampleRate:[self audioSampleRate] error:&error];
            if(!success || error != nil) {
                ELOG(@"%@", error.localizedDescription);
            }
#endif
            self.isRunning  = YES;
            _shouldStop = NO;
            self.isOn = YES;
            self.gameSpeed = GameSpeedNormal;
            if (!_skipEmulationLoop) {
                MAKEWEAK(self);
                NSThread *emuThread = [[NSThread alloc] initWithBlock:^{
                    MAKESTRONG_RETURN_IF_NIL(self);
                    [strongself emulationLoopThread];
                }];
                emuThread.name = @"PV Emulation";
                emuThread.stackSize = 2 * 1024 * 1024; // Increase stack to avoid ___chkstk_darwin faults
                [emuThread start];
            } else {
                [self setIsFrontBufferReady:YES];
            }
        }
    }
}

- (void)resetEmulation {
    [self doesNotImplementSelector:_cmd];
}

// GameCores that render direct to OpenGL rather than a buffer should override this and return YES
// If the GameCore subclass returns YES, the renderDelegate will set the appropriate GL Context
// So the GameCore subclass can just draw to OpenGL
- (BOOL)rendersToOpenGL {
    return NO;
}

- (void)setPauseEmulation:(BOOL)flag {
    if (flag) {
        [self stopHaptic];
        self.isRunning = NO;
    } else {
        [self startHaptic];
        self.isRunning = YES;
    }
}

- (BOOL)isEmulationPaused {
    return !_isRunning;
}


- (void)stopEmulation {
    [self stopEmulationWithMessage:nil];
}

-(void)stopEmulationWithMessage:(NSString *_Nullable)message {
    [self stopHaptic];
    _shouldStop = YES;
    self.isRunning  = NO;

    [self setIsFrontBufferReady:NO];
    [self.frontBufferCondition signal];

    if(message) {
        // Implementation to show message to user
        dispatch_async(dispatch_get_main_queue(), ^{
            #if TARGET_OS_OSX
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Emulation Stopped"];
            [alert setInformativeText:message];
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            #else
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Emulation Stopped"
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

            UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            [topController presentViewController:alert animated:YES completion:nil];
            #endif
        });
    }
    [self.emulationLoopThreadLock lock]; // make sure emulator loop has ended
    [self.emulationLoopThreadLock unlock];
    self.isOn = false;
}

//@end

//@implementation PVCoreObjCBridge (Controllers)


#if !TARGET_OS_OSX && !TARGET_OS_WATCH
- (UIViewController *)touchViewController {
    return _touchViewController;
}

- (void)setTouchViewController:(UIViewController *)touchViewController {
    if (_touchViewController != touchViewController) {
        _touchViewController = touchViewController;
    }
}
#endif

#if !TARGET_OS_WATCH
-(void)setController1:(GCController *)controller1 {
    if(![controller1 isEqual:_controller1]) {
        _controller1 = controller1;
    }

    if (self.supportsRumble) {
        if (controller1 != nil && !controller1.isAttachedToDevice) {
            // Eats battery to have it running if we don't need it
            [self stopHaptic];
        } else {
            [self startHaptic];
        }
    }
}

- (GCController *)controller1 {
    return _controller1;
}

- (GCController *)controller2 {
    return _controller2;
}

- (void)setController2:(GCController *)controller2 {
    if (_controller2 != controller2) {
        _controller2 = controller2;
    }
}

- (GCController *)controller3 {
    return _controller3;
}

- (void)setController3:(GCController *)controller3 {
    if (_controller3 != controller3) {
        _controller3 = controller3;
    }
}

- (GCController *)controller4 {
    return _controller4;
}

- (void)setController4:(GCController *)controller4 {
    if (_controller4 != controller4) {
        _controller4 = controller4;
    }
}
- (GCController *)controller5 {
    return _controller5;
}

- (void)setController5:(GCController *)controller5 {
    if (_controller5 != controller5) {
        _controller5 = controller5;
    }
}
- (GCController *)controller6 {
    return _controller6;
}

- (void)setController6:(GCController *)controller6 {
    if (_controller6 != controller6) {
        _controller6 = controller6;
    }
}
- (GCController *)controller7 {
    return _controller7;
}

- (void)setController7:(GCController *)controller7 {
    if (_controller7 != controller7) {
        _controller7 = controller7;
    }
}
- (GCController *)controller8 {
    return _controller8;
}

- (void)setController8:(GCController *)controller8 {
    if (_controller8 != controller8) {
        _controller8 = controller8;
    }
}
#endif

#if !TARGET_OS_OSX  && !TARGET_OS_WATCH
- (void)sendEvent:(UIEvent *)event {
}
#endif

- (void)updateControllers {
    //subclasses may implement for polling
    VLOG(@"STUB");
}

//@end

//@implementation PVCoreObjCBridge (Saves)
#pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    if (!self.supportsSaveStates) {
        *error = [self createError:@"Core does not support save states"];
        return NO;
    }

    NSString *message = [NSString stringWithFormat:@"Failed to save state at path: %@", path];
    if (error) {
        *error = [self createError:message];
    }

    [self doesNotImplementSelector:_cmd];
    return NO;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)path error:(NSError**)error {
    if (!self.supportsSaveStates) {
        *error = [self createError:@"Core does not support save states"];
        return NO;
    }

    [self doesNotImplementSelector:_cmd];
    return NO;
}

// Over load to support async
- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    NSError *error;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL success = [self saveStateToFileAtPath:fileName error:&error];
#pragma clang diagnostic pop
    block(error);
}

// Over load to support async
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    NSError *error;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL success = [self loadStateFromFileAtPath:fileName error:&error];
#pragma clang diagnostic pop
    block(error);
}

-(BOOL)supportsSaveStates {
    return YES;
}

//@end

//@implementation PVCoreObjCBridge (Video)

#pragma mark - Video

- (void)executeFrame {
    [self doesNotImplementOptionalSelector:_cmd];
}

- (const void *)videoBuffer {
    [self doesNotImplementSelector:_cmd];
    return NULL;
}

- (CGRect)screenRect
{
    [self doesNotImplementSelector:_cmd];
    return CGRectZero;
}

- (CGSize)aspectSize
{
    [self doesNotImplementSelector:_cmd];
    return CGSizeZero;
}

- (CGSize)bufferSize
{
    [self doesNotImplementSelector:_cmd];
    return CGSizeZero;
}

#warning "TODO: Replace all occurances of `bufferSize` with `videoBufferSize`"
- (CGSize)videBufferSize
{
    return [self bufferSize];
}

#if !TARGET_OS_WATCH
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
    [self doesNotImplementSelector:_cmd];
    return 0;
}

- (GLenum)depthFormat {
    // 0, GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24
    return 0;
}
#endif

- (NSTimeInterval)frameInterval {
    return defaultFrameInterval;
}

- (BOOL)isDoubleBuffered {
    return NO;
}

- (void)swapBuffers {
    NSAssert(!self.isDoubleBuffered, @"Cores that are double-buffered must implement swapBuffers!");
}

//@end

//@implementation PVCoreObjCBridge (Audio)

#pragma mark - Audio

- (double)audioSampleRate {
    [self doesNotImplementSelector:_cmd];
    return 0;
}

- (NSUInteger)channelCount {
    [self doesNotImplementSelector:_cmd];
    return 0;
}

- (NSUInteger)audioBufferCount {
    return 1;
}

- (void)getAudioBuffer:(void *)buffer frameCount:(uint32_t)frameCount bufferIndex:(NSUInteger)index {
    uint32_t maxLength = (uint32_t)(frameCount * [self channelCountForBuffer:index] * self.audioBitDepth);
    [[self ringBufferAtIndex:index] read:buffer
                           preferredSize:maxLength];
}

- (NSUInteger)audioBitDepth {
    return 16;
}

- (NSUInteger)channelCountForBuffer:(NSUInteger)buffer {
    if (buffer == 0) {
        return [self channelCount];
    }

    ELOG(@"Buffer counts greater than 1 must implement %@", NSStringFromSelector(_cmd));
    [self doesNotImplementSelector:_cmd];

    return 0;
}

- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer {
    // 4 frames is a complete guess
    double frameSampleCount = [self audioSampleRateForBuffer:buffer] / [self frameInterval];
    NSUInteger channelCount = [self channelCountForBuffer:buffer];
    NSUInteger bytesPerSample = [self audioBitDepth] / 8;
    //    NSAssert(frameSampleCount, @"frameSampleCount is 0");
    return channelCount*bytesPerSample * frameSampleCount;
}

- (double)audioSampleRateForBuffer:(NSUInteger)buffer {
    if(buffer == 0) {
        return [self audioSampleRate];
    }

    ELOG(@"Buffer count is greater than 1, must implement %@", NSStringFromSelector(_cmd));
    [self doesNotImplementSelector:_cmd];
    return 0;
}

- (id<RingBufferProtocol>)ringBufferAtIndex:(NSUInteger)index {
    if (UNLIKELY(ringBuffers.count <= index)) {
        NSInteger length = [self audioBufferSizeForBuffer:index] * 32;
        RingBufferType bufferType = [PVSettingsWrapper audioRingBufferType];

        id<RingBufferProtocol> newRingBuffer = [RingBufferFactory makeWithType:bufferType withLength:length];
        [ringBuffers addObject:newRingBuffer];
        return newRingBuffer;
    }

    return ringBuffers[index];
}
@end

/**
 * Makes the current thread real-time with the specified priority.
 * This function uses the mach thread policy to set real-time parameters.
 *
 * @param period The period in seconds (e.g., 0.005 for 5ms)
 * @param computation The computation time needed within each period (e.g., 0.003 for 3ms)
 * @param constraint The maximum time by which thread scheduling can be delayed (e.g., 0.004 for 4ms)
 * @param preemptible Whether the thread can be preempted (YES for most cases)
 * @return YES if successful, NO otherwise
 */
BOOL iMakeCurrentThreadRealTime(double period, double computation, double constraint, BOOL preemptible) {
    // Get the current thread
    thread_t thread = mach_thread_self();

    // Set up the time constraints for real-time behavior
    thread_time_constraint_policy_data_t policy;
    mach_msg_type_number_t count = THREAD_TIME_CONSTRAINT_POLICY_COUNT;
    boolean_t get_default = FALSE;

    // Convert seconds to absolute time units
    uint32_t absoluteTimeFrequency = 0; // unused but kept for clarity

    // Get the timebase info to convert seconds to absolute time
    mach_timebase_info_data_t timebaseInfo;
    mach_timebase_info(&timebaseInfo);

    // Calculate the conversion factor from seconds to absolute time
    double absoluteTimeToSecondsRatio = ((double)timebaseInfo.denom / (double)timebaseInfo.numer) * 1e-9;

    // Clamp to avoid invalid relationships
    if (computation > constraint) computation = constraint * 0.8;
    if (constraint > period) constraint = period * 0.95;
    if (computation <= 0) computation = period * 0.5;
    if (constraint <= 0) constraint = period * 0.75;

    policy.period = (uint32_t)(period / absoluteTimeToSecondsRatio);
    policy.computation = (uint32_t)(computation / absoluteTimeToSecondsRatio);
    policy.constraint = (uint32_t)(constraint / absoluteTimeToSecondsRatio);
    policy.preemptible = preemptible;

    // Set the thread policy
    kern_return_t result = thread_policy_set(
        thread,
        THREAD_TIME_CONSTRAINT_POLICY,
        (thread_policy_t)&policy,
        THREAD_TIME_CONSTRAINT_POLICY_COUNT
    );

    // If hard real-time fails, try a relaxed profile once
    if (result != KERN_SUCCESS) {
        double rperiod = period;
        double rcomp = period * 0.5;
        double rconst = period * 0.75;
        policy.period = (uint32_t)(rperiod / absoluteTimeToSecondsRatio);
        policy.computation = (uint32_t)(rcomp / absoluteTimeToSecondsRatio);
        policy.constraint = (uint32_t)(rconst / absoluteTimeToSecondsRatio);
        policy.preemptible = TRUE;
        result = thread_policy_set(thread, THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&policy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    }

    // Fallback: elevate QoS to userInteractive if still failing
    if (result != KERN_SUCCESS) {
        pthread_t pt = pthread_self();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }

    // Release the thread port right that was allocated by mach_thread_self()
    mach_port_deallocate(mach_task_self(), thread);

    return result == KERN_SUCCESS;
}
