//
//  PVEmulatorCore.m
//  Provenance
//
//  Created by James Addyman on 31/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVEmulatorCore.h"
#import "NSObject+PVAbstractAdditions.h"
#import "OERingBuffer.h"
#import "RealTimeThread.h"
@import PVLoggingObjC;
#import "DebugUtils.h"
@import AVFoundation;

#if !TARGET_OS_OSX
@import UIKit;
#else
@import AppKit;
#endif

/* Timing */
#include <mach/mach_time.h>
#import <QuartzCore/QuartzCore.h>

#define PVTimestamp(x) (((double)mach_absolute_time(x)) * 1.0e-09  * timebase_ratio)
//#define PVTimestamp() CACurrentMediaTime()
#define GetSecondsSince(x) (PVTimestamp() - x)

static Class PVEmulatorCoreClass = Nil;
static NSTimeInterval defaultFrameInterval = 60.0;

// Different machines have different mach_absolute_time to ms ratios
// calculate this on init
static double timebase_ratio;

NSString *const PVEmulatorCoreErrorDomain = @"org.provenance-emu.EmulatorCore.ErrorDomain";

@interface PVEmulatorCore()
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
@implementation PVEmulatorCore

+ (void)initialize {
    if (self == [PVEmulatorCore class]) {
        PVEmulatorCoreClass = [PVEmulatorCore class];
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
        ringBuffers              = (__strong OERingBuffer **)calloc(count, sizeof(OERingBuffer *));
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
    [self stopEmulation];

	for (NSUInteger i = 0, count = [self audioBufferCount]; i < count; i++)
	{
		ringBuffers[i] = nil;
	}
	
    free(ringBuffers);
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

#pragma mark - Execution

- (void)startEmulation {
	if ([self class] != PVEmulatorCoreClass) {
		if (!_isRunning) {
#if !TARGET_OS_TV && !TARGET_OS_OSX
            [self startHaptic];
            NSError *error;
			BOOL success = [self setPreferredSampleRate:[self audioSampleRate] error:&error];
            if(!success || error != nil) {
                ELOG(@"%@", error.localizedDescription);
            }
#endif
			self.isRunning  = YES;
			shouldStop = NO;
            self.isOn = YES;
            self.gameSpeed = GameSpeedNormal;
            if (!_skipEmulationLoop) {
                MAKEWEAK(self);
                [NSThread detachNewThreadWithBlock:^{
                    MAKESTRONG(self);
                    [strongself emulationLoopThread];
                }];
            } else {
                [self setIsFrontBufferReady:YES];
            }
		}
	}
}

- (void)resetEmulation {
	[self doesNotImplementSelector:_cmd];
}

#if !TARGET_OS_TV
-(BOOL)startHaptic {
    if (!NSThread.isMainThread) {
        __block BOOL started = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            started = [self startHaptic];
        });
        return started;
    }

#if !TARGET_OS_OSX
    if (self.supportsRumble && !(self.controller1 != nil && !self.controller1.isAttachedToDevice)) {
        self.rumbleGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [self.rumbleGenerator prepare];
        return YES;
    }
#endif

    return NO;
}

-(void)stopHaptic {
#if !TARGET_OS_OSX
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
    shouldStop = YES;
    self.isRunning  = NO;

    [self setIsFrontBufferReady:NO];
    [self.frontBufferCondition signal];

    if(message) {
        // TODO: Show the message to the user.
    }
        //    [self.emulationLoopThreadLock lock]; // make sure emulator loop has ended
        //    [self.emulationLoopThreadLock unlock];
    self.isOn = false;
}

- (void)updateControllers {
    //subclasses may implement for polling
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
    MakeCurrentThreadRealTime();

    //Emulation loop
    while (UNLIKELY(!shouldStop)) {

        [self updateControllers];
        
        @synchronized (self) {
			if (_isRunning) {
                if (self.isSpeedModified)
                {
                    [self executeFrame];
                }
                else
                {
                    @synchronized(self)
                    {
                        [self executeFrame];
                    }
                }
            }
        }
        frameCount += 1;

        nextEmuTick += gameInterval;
        sleepTime = nextEmuTick - GetSecondsSince(origin);
        
        if (_isDoubleBufferedCached)
        {
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
        case GameSpeedSlow:
            self.framerateMultiplier = 0.2;
            break;
        case GameSpeedNormal:
            self.framerateMultiplier = 1.0;
            break;
        case GameSpeedFast:
            self.framerateMultiplier = 5.0;
            break;
    }
}

- (BOOL)isSpeedModified {
	return self.gameSpeed != GameSpeedNormal;
}

- (void)setFramerateMultiplier:(CGFloat)framerateMultiplier {
    if ( _framerateMultiplier != framerateMultiplier ) {
        _framerateMultiplier = framerateMultiplier;
        NSLog(@"multiplier: %.1f", framerateMultiplier);
    }
    gameInterval = 1.0 / ([self frameInterval] * framerateMultiplier);
}

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

#if !TARGET_OS_TV && !TARGET_OS_OSX
- (Float64) getSampleRate {
    return [[AVAudioSession sharedInstance] sampleRate];
}

- (BOOL) setPreferredSampleRate:(double)preferredSampleRate error:(NSError **)error {
	double preferredSampleRate2 = preferredSampleRate ?: 48000;
    return [[AVAudioSession sharedInstance] setPreferredSampleRate:preferredSampleRate2 error:error];
}
#endif

- (void)executeFrame {
	[self doesNotImplementOptionalSelector:_cmd];
}

- (BOOL)loadFileAtPath:(NSString *)path {
    [self doesNotImplementSelector:_cmd];
    return NO;
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error
{
    return [self loadFileAtPath:path];
}

#pragma mark - Video

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

- (NSTimeInterval)frameInterval {
	return defaultFrameInterval;
}

- (BOOL)isDoubleBuffered {
    return NO;
}

- (void)swapBuffers {
    NSAssert(!self.isDoubleBuffered, @"Cores that are double-buffered must implement swapBuffers!");
}

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
                               maxLength:maxLength];
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

- (OERingBuffer *)ringBufferAtIndex:(NSUInteger)index {
	if (UNLIKELY(ringBuffers[index] == nil)) {
        ringBuffers[index] = [[OERingBuffer alloc] initWithLength:(uint32_t)[self audioBufferSizeForBuffer:index] * 16];
	}
	
    return ringBuffers[index];
}

-(NSUInteger)discCount {
    return 0;
}

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
- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    NSError *error;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL success = [self saveStateToFileAtPath:fileName error:&error];
#pragma clang diagnostic pop
    block(success, error);
}

// Over load to support async
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    NSError *error;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    BOOL success = [self loadStateFromFileAtPath:fileName error:&error];
#pragma clang diagnostic pop
    block(success, error);
}

-(BOOL)supportsSaveStates {
	return YES;
}

- (void)sendEvent:(UIEvent *)event {
}
static NSString *_coreClassName;
+ (NSString *)coreClassName {
    // options are identified by classname
    if (_coreClassName && [_coreClassName containsString:@"dylib"])
        return _coreClassName;
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
@end
