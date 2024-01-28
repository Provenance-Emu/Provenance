//
//  PVPPSSPPCore.m
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//
#import "PVPPSSPPCore.h"
#import "PVPPSSPPCore+Controls.h"
#import "PVPPSSPPCore+Audio.h"
#import "PVPPSSPPCore+Video.h"
#import <PVPPSSPP/PVPPSSPP-Swift.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVLogging/PVLogging.h>
#import "OGLGraphicsContext.h"
#import "VulkanGraphicsContext.h"

/* PPSSPP Includes */
#import <dlfcn.h>
#import <pthread.h>
#import <signal.h>
#import <string>
#import <stdio.h>
#import <stdlib.h>
#import <sys/syscall.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <mach/machine.h>

#import <AudioToolbox/AudioToolbox.h>

#include "Common/Common.h"
#include "Common/MemoryUtil.h"
#include "Common/Profiler/Profiler.h"
#include "Common/CPUDetect.h"
#include "Common/Log.h"
#include "Common/LogManager.h"
#include "Common/TimeUtil.h"
#include "Common/File/FileUtil.h"
#include "Common/Serialize/Serializer.h"
#include "Common/ConsoleListener.h"
#include "Common/Input/InputState.h"
#include "Common/Input/KeyCodes.h"
#include "Common/Thread/ThreadUtil.h"
#include "Common/Thread/ThreadManager.h"
#include "Common/File/VFS/VFS.h"
#include "Common/Data/Text/I18n.h"
#include "Common/StringUtils.h""
#include "Common/System/System.h"
#include "Common/System/Request.h"
#include "Common/System/Display.h"
#include "Common/System/NativeApp.h"
#include "Common/GraphicsContext.h"
#include "Common/Net/Resolve.h"
#include "Common/UI/Screen.h"
#include "Common/GPU/thin3d.h"
#include "Common/GPU/thin3d_create.h"
#include "Common/GPU/OpenGL/GLRenderManager.h"
#include "Common/GPU/OpenGL/GLFeatures.h"
#include "Common/System/NativeApp.h"
#include "Common/File/VFS/VFS.h"
#include "Common/Log.h"
#include "Common/TimeUtil.h"
#include "Common/GraphicsContext.h"

#include "GPU/GPUState.h"
#include "GPU/GPUInterface.h""

#include "Core/Config.h"
#include "Core/ConfigValues.h"
#include "Core/ConfigSettings.h"
#include "Core/Core.h"
#include "Core/CoreParameter.h"
#include "Core/HW/MemoryStick.h"
#include "Core/MemMap.h"
#include "Core/System.h"
#include "Core/CoreTiming.h"
#include "Core/HW/Display.h"
#include "Core/CwCheat.h"
#include "Core/ELF/ParamSFO.h"
#include "Core/SaveState.h"
#include "Core/System.h"
#include "iOSCoreAudio.h"
#define IS_IPHONE() ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)

#pragma mark - Private
@interface PVPPSSPPCore() {
}
@end
#pragma mark - PVPPSSPPCore Begin
@implementation PVPPSSPPCore
{
	CoreParameter _coreParam;
	float _frameInterval;
	bool loggingEnabled;
	NSString *autoLoadStatefileName;
	NSString *_romPath;
}

- (instancetype)init {
	if (self = [super init]) {
        self.alwaysUseMetal = true;
        self.skipLayout = true;
		if (IS_IPHONE()) {
			_videoWidth  = 480;
			_videoHeight = 272;
		} else {
			_videoWidth  = 640;
			_videoHeight = 480;
		}
        isPaused = true;
        sampleRate = 44100;
		isNTSC = YES;
		dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
		_callbackQueue = dispatch_queue_create("org.provenance-emu.PPSSPP.CallbackHandlerQueue", queueAttributes);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(optionUpdated:) name:@"OptionUpdated" object:nil];
		[self parseOptions];
	}
    _current = self;
	return self;
}

- (void)dealloc {
	g_threadManager.Teardown();
}

#pragma mark - PVEmulatorCore
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
	const char *dataPath;
	NSString *configPath = self.saveStatesPath;
	dataPath = [[coreBundle resourcePath] fileSystemRepresentation];
	[[NSFileManager defaultManager] createDirectoryAtPath:configPath
							  withIntermediateDirectories:YES
											   attributes:nil
													error:nil];
	NSString *batterySavesDirectory = self.batterySavesPath;
	[[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory
							  withIntermediateDirectories:YES
											   attributes:nil
													error:NULL];
	_romPath = [path copy];
	[self setOptionValues];
	return YES;
}

#pragma mark - Running
- (void)setupEmulation {
    (@"Setup Emulation");
    [self setOptionValues];
	int argc = 2;
	const char* argv[] = { "" ,[_romPath UTF8String], NULL };
	NSString* saveDirectory = [self.batterySavesPath stringByAppendingPathComponent:@"/saves/"];
	std::string user_dir = std::string([saveDirectory UTF8String]);
	NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *resourcePath = [[[NSBundle bundleForClass:[PVPPSSPPCore class]]  resourcePath] stringByAppendingString:@"/assets/"];
	NSLog(@"Bundle Path is at %s\n", [resourcePath UTF8String]);
	// Copy over font files if needed
	NSString *fontSourceDirectory = [resourcePath stringByAppendingString:@"/assets/"];
	g_Config.flash0Directory = Path([fontSourceDirectory UTF8String]);
	g_Config.internalDataDirectory = Path([saveDirectory UTF8String]);
	g_Config.memStickDirectory = g_Config.internalDataDirectory;
	g_Config.defaultCurrentDirectory = g_Config.internalDataDirectory;
	std::string error_string;
    NSLog(@"PSP Init");
    NativeInit(argc, argv, documentsPath.UTF8String, resourcePath.UTF8String, NULL);
    [self setOptionValues];
    while (!_isInitialized && !PSP_InitUpdate(&error_string))
        sleep_ms(10);
	if (!PSP_IsInited()){
        NSLog(@"PSP Init Error %s", error_string.c_str());
        std::string error_string;
        PSP_Shutdown();
    }
    Memory::MemoryMap_Setup(0);
    while (!_isInitialized && !PSP_InitStart(PSP_CoreParameter(), &error_string)) {
        sleep_ms(500);
        PSP_Shutdown();
        Memory::MemoryMap_Shutdown(0);
        Memory::MemoryMap_Setup(0);
        sleep_ms(500);
        NSLog(@"%s", error_string.c_str());
    }
}

/* Config */
- (void)setVolume {
    [self parseOptions];
    g_Config.iGlobalVolume = self.volume;
    g_Config.bEnableSound = self.volume != 0;
    PSP_CoreParameter().enableSound = self.volume != 0;
    ConfigSetting("GlobalVolume", &g_Config.iGlobalVolume, VOLUME_FULL, CfgFlag::PER_GAME);
}
- (void)setOptionValues {
    NSLog(@"Set Option Values");
	[self parseOptions];
	// Option Interface
	g_Config.iMultiSampleLevel = self.msaa;
	g_Config.iInternalResolution = self.resFactor;
	g_Config.iCpuCore = self.cpuType;
	g_Config.iAnisotropyLevel = self.taOption;
	g_Config.iTexScalingType = self.tutypeOption;
	g_Config.iTexScalingLevel = self.tuOption;
	g_Config.iTexFiltering = self.tfOption;
	g_Config.bFastMemory = self.fastMemory;
	g_Config.iGPUBackend = self.gsPreference;
	g_Config.bDisplayStretch = self.stretchOption;
    g_Config.iButtonPreference = self.buttonPref;
    
	// Internal Options
	g_Config.bEnableCheats = true;
	g_Config.bEnableNetworkChat = false;
	g_Config.bDiscordPresence = false;
	g_Config.bHideSlowWarnings = true;
	g_Config.bShowTouchControls = false;
	g_Config.bIgnoreBadMemAccess = true;
	g_Config.iScreenRotation = ROTATION_LOCKED_HORIZONTAL;
	g_Config.iInternalScreenRotation = ROTATION_LOCKED_HORIZONTAL;
	g_Config.bSeparateSASThread = true;
	g_Config.bPauseOnLostFocus = true;
	g_Config.bCacheFullIsoInRam = false;
	g_Config.bPreloadFunctions = true;
    g_Config.bEnableSound = true;

	// Core Options
	PSP_CoreParameter().fileToStart     = Path(std::string([_romPath UTF8String]));
	PSP_CoreParameter().mountIso.clear();
    PSP_CoreParameter().startBreak      = false;
	PSP_CoreParameter().enableSound     = true;
	PSP_CoreParameter().headLess        = false;
	PSP_CoreParameter().renderWidth  = self.videoWidth * self.resFactor;
	PSP_CoreParameter().renderHeight = self.videoHeight * self.resFactor;
	PSP_CoreParameter().renderScaleFactor = self.resFactor;
	PSP_CoreParameter().pixelWidth   = self.videoWidth * self.resFactor;
	PSP_CoreParameter().pixelHeight  = self.videoHeight * self.resFactor;
	PSP_CoreParameter().cpuCore  =     (CPUCore)self.cpuType;
	if (self.gsPreference == 0)
		PSP_CoreParameter().gpuCore  =   GPUCORE_GLES;
    else if (self.gsPreference == 3)
        PSP_CoreParameter().gpuCore  =   GPUCORE_VULKAN;
    [self setVolume];
    if (g_Config.bEnableSound) {
           iOSCoreAudioShutdown();
           iOSCoreAudioInit();
    }
}

- (void)startVM:(UIView *)view {
	NSLog(@"Start VM (Initialization State %d)\n", _isInitialized);
	[self runVM];
	[self setupControllers];
	NSLog(@"VM Started\n");
}

-(void) prepareAudio {
    NSError *error = nil;
    [[AVAudioSession sharedInstance]
     setCategory:AVAudioSessionCategoryAmbient
     mode:AVAudioSessionModeDefault
     options:AVAudioSessionCategoryOptionAllowBluetooth |
     AVAudioSessionCategoryOptionAllowAirPlay |
     AVAudioSessionCategoryOptionAllowBluetoothA2DP |
     AVAudioSessionCategoryOptionMixWithOthers
     error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
}

- (void)startEmulation {
    NSLog(@"Start Emulation");
    [self prepareAudio];
    self.isViewReady = false;
    self.isGFXReady = false;
    _isInitialized = false;
	g_threadManager.Init(cpu_info.num_cores, cpu_info.logical_cpu_count);
	[self startGame];
	[super startEmulation];
}

- (void)setPauseEmulation:(BOOL)flag {
    NSLog(@"We are right now Paused: %d %d -> %d\n", isPaused, self.isEmulationPaused, flag);
    if (flag == isPaused) return;
    if (flag != isPaused || flag != self.isEmulationPaused) {
        Core_EnableStepping(flag, "ui.lost_focus", 0);
	}
    isPaused=flag;
    [super setPauseEmulation:flag];
}

- (void)stopEmulation {
    [self setPauseEmulation:true];
	_isInitialized = false;
	self->shouldStop = true;
	[self stopGame:true];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    //NativeShutdown();
    LogManager::Shutdown();
    net::Shutdown();
    Memory::MemoryMap_Shutdown(0);
    g_threadManager.Teardown();
    [super stopEmulation];
}

- (void)startGame {
    NSLog(@"Start Game");
	g_threadManager.Init(cpu_info.num_cores, cpu_info.logical_cpu_count);
	self.skipEmulationLoop = true;
	[self setupView];
}

- (void)stopGame:(bool)deinitViews {
	[self stopVM:deinitViews];
}

- (void)resetEmulation {
    [self stopGame:false];
    sleep(3);
    [self startGame];
}

-(void)optionUpdated:(NSNotification *)notification {
    NSLog(@"Option Updated\n");
    NSDictionary *info = notification.userInfo;
    for (NSString* key in info.allKeys) {
        NSString *value=[info valueForKey:key];
        [self processOption:key value:value];
        NSLog(@"Received Option key:%s value:%s\n",key.UTF8String, value.UTF8String);
    }
}

-(void)processOption:(NSString *)key value:(NSString*)value {
    typedef void (^Process)();
    NSDictionary *actions = @{
        @"Audio Volume":
        ^{
            [self setVolume];
        },
    };
    Process action=[actions objectForKey:key];
    if (action)
        action();
}
@end


/* PPSSPP system messages (Required Handling) */
std::string System_GetProperty(SystemProperty prop);
std::vector<std::string> System_GetPropertyStringVec(SystemProperty prop);
int System_GetPropertyInt(SystemProperty prop);
float System_GetPropertyFloat(SystemProperty prop);
bool System_GetPropertyBool(SystemProperty prop);
void System_SendMessage(const char *command, const char *parameter);
void System_Toast(const char *text);
void System_AskForPermission(SystemPermission permission);
PermissionStatus System_GetPermissionStatus(SystemPermission permission);
FOUNDATION_EXTERN void AudioServicesPlaySystemSoundWithVibration(unsigned long, objc_object*, NSDictionary*);
BOOL SupportsTaptic();
void Vibrate(int mode);
bool get_debugged();
kern_return_t catch_exception_raise(mach_port_t exception_port,
									mach_port_t thread,
									mach_port_t task,
									exception_type_t exception,
									exception_data_t code,
									mach_msg_type_number_t code_count);
void *exception_handler(void *argument);

static int (*csops)(pid_t pid, unsigned int ops, void * useraddr, size_t usersize);
static boolean_t (*exc_server)(mach_msg_header_t *, mach_msg_header_t *);
static int (*ptrace)(int request, pid_t pid, caddr_t addr, int data);

#define CS_OPS_STATUS    0        /* return status */
#define CS_DEBUGGED    0x10000000    /* process is currently or has previously been debugged and allowed to run with invalid pages */
#define PT_ATTACHEXC    14        /* attach to running process with signal exception */
#define PT_DETACH    11        /* stop tracing a process */
#define ptrace(a, b, c, d) syscall(SYS_ptrace, a, b, c, d)

static float g_safeInsetLeft = 0.0;
static float g_safeInsetRight = 0.0;
static float g_safeInsetTop = 0.0;
static float g_safeInsetBottom = 0.0;

static int g_iosVersionMajor;
static std::string version;

kern_return_t catch_exception_raise(mach_port_t exception_port,
									mach_port_t thread,
									mach_port_t task,
									exception_type_t exception,
									exception_data_t code,
									mach_msg_type_number_t code_count) {
	return KERN_FAILURE;
}

void *exception_handler(void *argument) {
	auto port = *reinterpret_cast<mach_port_t *>(argument);
#if !TARGET_OS_TV
	mach_msg_server(exc_server, 2048, port, 0);
#endif
	return NULL;
}

std::string System_GetProperty(SystemProperty prop) {
	switch (prop) {
		case SYSPROP_NAME:
			version = [[[UIDevice currentDevice] systemVersion] UTF8String];
			return StringFromFormat("iOS %s", version.c_str());
		case SYSPROP_LANGREGION:
			return [[[NSLocale currentLocale] objectForKey:NSLocaleIdentifier] UTF8String];
		default:
			return "";
	}
}

std::vector<std::string> System_GetPropertyStringVec(SystemProperty prop) {
	switch (prop) {
	case SYSPROP_TEMP_DIRS:
	default:
		return std::vector<std::string>();
	}
}

int System_GetPropertyInt(SystemProperty prop) {
	switch (prop) {
		case SYSPROP_AUDIO_SAMPLE_RATE:
			return 44100;
		case SYSPROP_DEVICE_TYPE:
			return DEVICE_TYPE_MOBILE;
		case SYSPROP_SYSTEMVERSION:
			return g_iosVersionMajor;
		default:
			return -1;
	}
}

float System_GetPropertyFloat(SystemProperty prop) {
	switch (prop) {
	case SYSPROP_DISPLAY_REFRESH_RATE:
		return 120.f;
	case SYSPROP_DISPLAY_SAFE_INSET_LEFT:
		return g_safeInsetLeft;
	case SYSPROP_DISPLAY_SAFE_INSET_RIGHT:
		return g_safeInsetRight;
	case SYSPROP_DISPLAY_SAFE_INSET_TOP:
		return g_safeInsetTop;
	case SYSPROP_DISPLAY_SAFE_INSET_BOTTOM:
		return g_safeInsetBottom;
	default:
		return -1;
	}
}

bool System_GetPropertyBool(SystemProperty prop) {
	switch (prop) {
		case SYSPROP_HAS_BACK_BUTTON:
			return false;
		case SYSPROP_APP_GOLD:
#ifdef GOLD
			return true;
#else
			return false;
#endif
		case SYSPROP_CAN_JIT:
			return true;
		default:
			return false;
	}
}

void System_SendMessage(const char *command, const char *parameter) {
	if (!strcmp(command, "finish")) {
	} else if (!strcmp(command, "sharetext")) {
		NSString *text = [NSString stringWithUTF8String:parameter];
		NSLog(@"Text %s\n", text);
	} else if (!strcmp(command, "camera_command")) {
	} else if (!strcmp(command, "gps_command")) {
	} else if (!strcmp(command, "safe_insets")) {
		float left, right, top, bottom;
		if (4 == sscanf(parameter, "%f:%f:%f:%f", &left, &right, &top, &bottom)) {
			g_safeInsetLeft = left;
			g_safeInsetRight = right;
			g_safeInsetTop = top;
			g_safeInsetBottom = bottom;
		}
	}
	NSLog(@"Command %s Received\n",command);
}

void System_Toast(const char *text) {}
void System_AskForPermission(SystemPermission permission) {}

PermissionStatus System_GetPermissionStatus(SystemPermission permission) { return PERMISSION_STATUS_GRANTED; }

FOUNDATION_EXTERN void AudioServicesPlaySystemSoundWithVibration(unsigned long, objc_object*, NSDictionary*);

BOOL SupportsTaptic()
{
	return NO;
}

void Vibrate(int mode) {
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	NSArray *pattern = @[@YES, @30, @NO, @2];

	dictionary[@"VibePattern"] = pattern;
	dictionary[@"Intensity"] = @2;

	AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary);
}
void System_Vibrate(int mode) {

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSArray *pattern = @[@YES, @30, @NO, @2];

    dictionary[@"VibePattern"] = pattern;
    dictionary[@"Intensity"] = @2;

    AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary);
}

@implementation CLLocationManager
@end
std::vector<std::string> __cameraGetDeviceList() {
}
void OpenDirectory(const char *path) {
}
void LaunchBrowser(char const* url) {
}

void System_Notify(SystemNotification notification) {
        switch (notification) {
        }
}
bool System_MakeRequest(SystemRequestType type, int requestId, const std::string &param1, const std::string &param2, int param3) {
    return false;
}
void System_ShowFileInFolder(const char *path) {}
void System_LaunchUrl(LaunchUrlType urlType, char const* url) {}

std::vector<std::string> System_GetCameraDeviceList() {
    std::vector<std::string> deviceList;
    deviceList.empty();
    return deviceList;
}
