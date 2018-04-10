//
//  PVReicastCore.m
//  PVReicast
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVReicastCore.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>


// Reicast imports
#include "types.h"
#include "profiler/profiler.h"
#include "cfg/cfg.h"
#include "rend/rend.h"
#include "rend/TexCache.h"
#include "hw/maple/maple_devs.h"
#include "hw/maple/maple_if.h"

__weak PVReicastCore *_current = 0;

@interface PVReicastCore()
- (void)pollControllers;
@property(nonatomic, strong, nullable) NSString *diskPath;
@end

// Reicast function declerations
extern int screen_width,screen_height;
bool rend_single_frame();
bool gles_init();
extern int reicast_main(int argc, char* argv[]);
void common_linux_setup();
int dc_init(int argc,wchar* argv[]);
void dc_run();
void dc_term();

bool inside_loop     = true;
static bool first_run = true;;

#pragma mark - Reicast C++ interface
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
#include "hw/sh4/dyna/blockmanager.h"
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

#pragma mark Debugging calls

int msgboxf(const wchar* text,unsigned int type,...)
{
	va_list args;

	wchar temp[2048];
	va_start(args, type);
	vsprintf(temp, text, args);
	va_end(args);

	//printf(NULL,temp,VER_SHORTNAME,type | MB_TASKMODAL);
	puts(temp);
	return 0;
}

int darw_printf(const wchar* text,...) {
	va_list args;

	wchar temp[2048];
	va_start(args, text);
	vsprintf(temp, text, args);
	va_end(args);

	NSLog(@"%s", temp);

	return 0;
}

#pragma mark C Lifecycle calls
void os_DoEvents() {
    GET_CURRENT_OR_RETURN();
    [current videoInterrupt];
////
////	is_dupe = false;
//	[current updateControllers];
//
//	if (settings.UpdateMode || settings.UpdateModeForced)
//	{
//		inside_loop = false;
//		rend_end_render();
//	}
}

u32  os_Push(void*, u32, bool) {
	return 1;
}

void os_SetWindowText(const char* t) {
	puts(t);
}

void os_CreateWindow() {

}

void UpdateInputState(u32 port) {
	GET_CURRENT_OR_RETURN();
	[current pollControllers];
}

void UpdateVibration(u32 port, u32 value) {

}

int get_mic_data(unsigned char* ) {
	return 0;
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

void gl_term() {

}

void gl_swap() {
	GET_CURRENT_OR_RETURN();
	[current swapBuffers];
}

#pragma mark Audio Callbacks

#include "oslib/audiobackend_coreaudio.h"

static void coreaudio_init()
{

}

static u32 coreaudio_push(void* frame, u32 samples, bool wait)
{
	GET_CURRENT_OR_RETURN(0);
	//	while (samples_ptr != 0 && wait)
	//		;
	//
	//	if (samples_ptr == 0) {\

	[[current ringBufferAtIndex:0] write:(const unsigned char *)frame maxLength:samples * 4];
	//	});
	/* Yeah, right */
	//    while (samples_ptr != 0 && wait) ;
	//
	//    if (samples_ptr == 0) {
	//        memcpy(&samples_temp[samples_ptr], frame, samples * 4);
	//        samples_ptr += samples * 4;
	//    }
	//
	return 1;
}

static void coreaudio_term()
{
	GET_CURRENT_OR_RETURN();
}

audiobackend_t audiobackend_coreaudio = {
	"coreaudio", // Slug
	"Core Audio", // Name
	&coreaudio_init,
	&coreaudio_push,
	&coreaudio_term
};

#pragma mark - PVReicastCore Begin


// Reicast controller data
u16 kcode[4];
u8 rt[4];
u8 lt[4];
u32 vks[4];
s8 joyx[4], joyy[4];

@implementation PVReicastCore
{
	dispatch_semaphore_t mupenWaitToBeginFrameSemaphore;
	dispatch_semaphore_t coreWaitToEndFrameSemaphore;
    dispatch_semaphore_t coreWaitForExitSemaphore;

	dispatch_queue_t _callbackQueue;
	NSMutableDictionary *_callbackHandlers;
}

- (instancetype)init
{
	if (self = [super init]) {
		mupenWaitToBeginFrameSemaphore = dispatch_semaphore_create(0);
		coreWaitToEndFrameSemaphore    = dispatch_semaphore_create(0);
        coreWaitForExitSemaphore       = dispatch_semaphore_create(0);

		_videoWidth  = screen_width = 640;
		_videoHeight = screen_height = 480;
		_videoBitDepth = 32; // ignored
		videoDepthBitDepth = 0; // TODO

		sampleRate = 44100;

		isNTSC = YES;

		memset(&kcode, 0xFFFF, sizeof(kcode));
		bzero(&rt, sizeof(rt));
		bzero(&lt, sizeof(lt));

		_callbackQueue = dispatch_queue_create("org.openemu.Reicast.CallbackHandlerQueue", DISPATCH_QUEUE_SERIAL);
		_callbackHandlers = [[NSMutableDictionary alloc] init];
	}
	_current = self;
	return self;
}

- (void)dealloc
{
#if !__has_feature(objc_arc)
	dispatch_release(mupenWaitToBeginFrameSemaphore);
	dispatch_release(coreWaitToEndFrameSemaphore);
    dispatch_release(coreWaitForExitSemaphore);
#endif

	_current = nil;
}

#pragma mark - PVEmulatorCore
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error
{
	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
	const char *dataPath;

	[self copyShadersIfMissing];

	// TODO: Proper path
	NSString *configPath = self.saveStatesPath;
	dataPath = [[coreBundle resourcePath] fileSystemRepresentation];

	[[NSFileManager defaultManager] createDirectoryAtPath:configPath withIntermediateDirectories:YES attributes:nil error:nil];

	NSString *batterySavesDirectory = self.batterySavesPath;
	[[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];


//	if (!success) {
//		NSDictionary *userInfo = @{
//								   NSLocalizedDescriptionKey: @"Failed to load game.",
//								   NSLocalizedFailureReasonErrorKey: @"Reicast failed to load GLES graphics.",
//								   NSLocalizedRecoverySuggestionErrorKey: @"Provenance may not be compiled correctly."
//								   };
//
//		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
//												code:PVEmulatorCoreErrorCodeCouldNotLoadRom
//											userInfo:userInfo];
//
//		*error = newError;
//		return NO;
//	}

	self.diskPath = path;

	// 	while(!rend_single_frame()) ; // Where should this go?

//	// Reicast part
//	common_linux_setup();
//
//	settings.profile.run_counts=0;
//
//	dc_init(argc,argv);
//
//	dc_run();

	return YES;
}


- (void)copyShadersIfMissing {

	NSArray *shaders = @[@"Shader.vsh",@"Shader.fsh"];
	NSString *destinationFolder = self.BIOSPath;
	NSFileManager *fm = [NSFileManager defaultManager];

	for (NSString* shader in shaders) {
		NSString *destinationPath = [destinationFolder stringByAppendingPathComponent:shader];
		ILOG(@"Checking for shader %@", destinationPath);
		if( ![fm fileExistsAtPath:destinationPath]  ) {
			NSString *source = [[NSBundle bundleForClass:[self class]] pathForResource:[shader stringByDeletingPathExtension] ofType:[shader pathExtension]];
			[fm copyItemAtPath:source
						toPath:destinationPath
						 error:nil];
			ILOG(@"Copied %@ from %@ to %@", shader, source, destinationPath);
		}
	}
}
volatile bool has_init = false;

#pragma mark - Running
- (void)startEmulation
{
	if(!isRunning)
	{

		[super startEmulation];
        [NSThread detachNewThreadSelector:@selector(runReicastRenderThread) toTarget:self withObject:nil];
	}

}

- (void)runReicastEmuThread
{
	@autoreleasepool
	{
		[self reicastMain];

		// Core returns

		// Unlock rendering thread
		dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

		[super stopEmulation];
	}
}

- (void)runReicastRenderThread
{
    @autoreleasepool
    {
        [self.renderDelegate startRenderingOnAlternateThread];
        BOOL success = gles_init();
        assert(success);
        [NSThread detachNewThreadSelector:@selector(runReicastEmuThread) toTarget:self withObject:nil];
        
        while (!has_init) {}
        while ( !shouldStop )
        {
            [self.frontBufferCondition lock];
            while (self.isFrontBufferReady) [self.frontBufferCondition wait];
            [self.frontBufferCondition unlock];
            
            while ( !rend_single_frame() ) {}
            [self swapBuffers];
        }
    }
}

- (void)reicastMain {
	//    #if !TARGET_OS_SIMULATOR
	install_prof_handler(1);
	//   #endif

	char *Args[3];
	const char *P;

	P = (const char *)[self.diskPath UTF8String];
	Args[0] = "dc";
	Args[1] = "-config";
	Args[2] = P&&P[0]? (char *)malloc(strlen(P)+32):0;

	if(Args[2])
	{
		strcpy(Args[2],"config:image=");
		strcat(Args[2],P);
	}

	MakeCurrentThreadRealTime();

	int argc = Args[2]? 3:1;

	set_user_config_dir(self.BIOSPath.UTF8String);
	set_user_data_dir(self.batterySavesPath.UTF8String);

	printf("Config dir is: %s\n", get_writable_config_path("/").c_str());
	printf("Data dir is:   %s\n", get_writable_data_path("/").c_str());

	common_linux_setup();

	settings.profile.run_counts=0;

	reicast_main(argc, Args);
    
    dispatch_semaphore_signal(coreWaitForExitSemaphore);
}

int reicast_main(int argc, wchar* argv[]) {
	int status = dc_init(argc, argv);
	NSLog(@"Reicast init status: %i", status);
	has_init = true;

	dc_run();
	return 0;
}

- (void)videoInterrupt
{
	//dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

	//dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)swapBuffers
{
	[self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
	//dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);

	//dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)executeFrame
{
	[self executeFrameSkippingFrame:NO];
}

- (void)setPauseEmulation:(BOOL)flag
{
	[super setPauseEmulation:flag];
	if (flag)
	{
		dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
		[self.frontBufferCondition lock];
		[self.frontBufferCondition signal];
		[self.frontBufferCondition unlock];
	}
}

- (void)stopEmulation
{
	// TODO: Call reicast stop command here
	dc_term();
	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);
	[self.frontBufferCondition lock];
	[self.frontBufferCondition signal];
	[self.frontBufferCondition unlock];

	[super stopEmulation];
}

- (void)resetEmulation
{
	// TODO: Call reicast reset command here
	plugins_Reset(true);
	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
	[self.frontBufferCondition lock];
	[self.frontBufferCondition signal];
	[self.frontBufferCondition unlock];
}

#pragma mark - Video
- (CGSize)bufferSize
{
	return CGSizeMake(1024, 512);
}

- (CGRect)screenRect
{
	return CGRectMake(0, 0, _videoWidth, _videoHeight);
}

- (CGSize)aspectSize
{
	return CGSizeMake(_videoWidth, _videoHeight);
}

- (BOOL)rendersToOpenGL
{
	return YES;
}

- (const void *)videoBuffer
{
	return NULL;
}

- (GLenum)pixelFormat
{
	return GL_RGBA;
}

- (GLenum)pixelType
{
	return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat
{
	return GL_RGBA;
}

#pragma mark - Audio

- (NSTimeInterval)frameInterval
{
	return isNTSC ? 60 : 50;
}

- (NSUInteger)channelCount
{
	return 2;
}

- (double)audioSampleRate
{
	return sampleRate;
}

#pragma mark - Save States
- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
	return NO;
}
- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
}


- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
	return NO;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{

}

#pragma mark - Control

#define DC_BTN_C		(1)
#define DC_BTN_B		(1<<1)
#define DC_BTN_A		(1<<2)
#define DC_BTN_START	(1<<3)
#define DC_DPAD_UP		(1<<4)
#define DC_DPAD_DOWN	(1<<5)
#define DC_DPAD_LEFT	(1<<6)
#define DC_DPAD_RIGHT	(1<<7)
#define DC_BTN_Z		(1<<8)
#define DC_BTN_Y		(1<<9)
#define DC_BTN_X		(1<<10)
#define DC_BTN_D		(1<<11)
#define DC_DPAD2_UP		(1<<12)
#define DC_DPAD2_DOWN	(1<<13)
#define DC_DPAD2_LEFT	(1<<14)
#define DC_DPAD2_RIGHT	(1<<15)

#define DC_AXIS_LT		(0X10000)
#define DC_AXIS_RT		(0X10001)
#define DC_AXIS_X		(0X20000)
#define DC_AXIS_Y		(0X20001)

- (void)pollControllers
{
	for (NSInteger playerIndex = 0; playerIndex < 4; playerIndex++)
	{
		GCController *controller = nil;

		if (self.controller1 && playerIndex == 0)
		{
			controller = self.controller1;
		}
		else if (self.controller2 && playerIndex == 1)
		{
			controller = self.controller2;
		}
		else if (self.controller3 && playerIndex == 3)
		{
			controller = self.controller3;
		}
		else if (self.controller4 && playerIndex == 4)
		{
			controller = self.controller4;
		}

		if ([controller extendedGamepad])
		{
			GCExtendedGamepad *gamepad     = [controller extendedGamepad];
			GCControllerDirectionPad *dpad = [gamepad dpad];

			dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
			dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
			dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
			dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);

			gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
			gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
			gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
			gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);

			gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
			gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);

			gamepad.leftTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Z) : kcode[playerIndex] |= (DC_BTN_Z);
			gamepad.rightTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_START) : kcode[playerIndex] |= (DC_BTN_START);


			float xvalue = gamepad.leftThumbstick.xAxis.value;
			s8 x=(s8)(xvalue*127);
			joyx[0] = x;

			float yvalue = gamepad.leftThumbstick.yAxis.value;
			s8 y=(s8)(yvalue*127 * - 1); //-127 ... + 127 range
			joyy[0] = y;

		} else if ([controller gamepad]) {
			GCGamepad *gamepad = [controller gamepad];
			GCControllerDirectionPad *dpad = [gamepad dpad];

			dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
			dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
			dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
			dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);

			gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
			gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
			gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
			gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);

			gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
			gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);
		}
#if TARGET_OS_TV
		else if ([controller microGamepad]) {
			GCMicroGamepad *gamepad = [controller microGamepad];
			GCControllerDirectionPad *dpad = [gamepad dpad];
		}
#endif
	}
}

const int DreamcastMap[]  = { DC_DPAD_UP, DC_DPAD_DOWN, DC_DPAD_LEFT, DC_DPAD_RIGHT, DC_BTN_A, DC_BTN_B, DC_BTN_X, DC_BTN_Y, DC_AXIS_LT, DC_AXIS_RT, DC_BTN_START};

-(void)didPushDreamcastButton:(enum PVDreamcastButton)button forPlayer:(NSInteger)player {
	if (button == PVDreamcastButtonL) {
		lt[player] |= 0xff * true;
	} else if (button == PVDreamcastButtonR) {
		rt[player] |= 0xff * true;
	} else {
		int mapped = DreamcastMap[button];
		kcode[player] &= ~(mapped);
	}
}

-(void)didReleaseDreamcastButton:(enum PVDreamcastButton)button forPlayer:(NSInteger)player {
	if (button == PVDreamcastButtonL) {
		lt[player] |= 0xff * false;
	} else if (button == PVDreamcastButtonR) {
		rt[player] |= 0xff * false;
	} else {
		int mapped = DreamcastMap[button];
		kcode[player] |= (mapped);
	}
}

- (void)didMoveDreamcastJoystickDirection:(enum PVDreamcastButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
	/*
	float xvalue = gamepad.leftThumbstick.xAxis.value;
	s8 x=(s8)(xvalue*127);
	joyx[0] = x;

	float yvalue = gamepad.leftThumbstick.yAxis.value;
	s8 y=(s8)(yvalue*127 * - 1); //-127 ... + 127 range
	joyy[0] = y;
	*/
}

-(void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
	[self didMoveDreamcastJoystickDirection:(enum PVDreamcastButton)button withValue:value forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
	[self didPushDreamcastButton:(PVDreamcastButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
	[self didReleaseDreamcastButton:(PVDreamcastButton)button forPlayer:player];
}

@end

