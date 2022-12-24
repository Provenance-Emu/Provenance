//
//  PVDolphinCore.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore.h"
//#include "DolHost.h"
//#include "OpenEmuAudioStream.h"
//#include <stdatomic.h>
#import "PVDolphinCore+Controls.h"
#import "PVDolphinCore+Audio.h"
#import "PVDolphinCore+Video.h"
#import <PVDolphin/PVDolphin-Swift.h>

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/PVLogging.h>

/* Dolphin Includes */
#include "AudioCommon/AudioCommon.h"
#include "AudioCommon/SoundStream.h"

#include "Common/CPUDetect.h"
#include "Common/CommonPaths.h"
#include "Common/CommonTypes.h"
#include "Common/FileUtil.h"
#include "Common/IniFile.h"
#include "Common/Logging/LogManager.h"
#include "Common/MsgHandler.h"
#include "Common/Thread.h"
#include "Common/Version.h"

#include "Core/Boot/Boot.h"
#include "Core/BootManager.h"
#include "Core/Config/GraphicsSettings.h"
#include "Core/Config/MainSettings.h"
#include "Core/Config/SYSCONFSettings.h"
#include "Core/ConfigManager.h"
#include "Core/Core.h"
#include "Core/Host.h"
#include "Core/HW/CPU.h"
#include "Core/HW/DVD/DVDInterface.h"
#include "Core/HW/ProcessorInterface.h"
#include "Core/HW/VideoInterface.h"
#include "Core/HW/Wiimote.h"
#include "Core/HW/WiimoteCommon/WiimoteHid.h"
#include "Core/HW/WiimoteReal/WiimoteReal.h"
#include "Core/HW/WiimoteEmu/WiimoteEmu.h"
#include "Core/FreeLookManager.h"
#include "Core/HW/GCKeyboard.h"
#include "Core/HW/GCPad.h"
#include "Core/HW/SI/SI.h"
#include "Core/HW/SI/SI_Device.h"
#include "Core/IOS/IOS.h"
#include "Core/IOS/STM/STM.h"
#include "Core/PowerPC/PowerPC.h"
#include "Core/State.h"
#include "Core/WiiUtils.h"

#include "UICommon/CommandLineParse.h"
#include "UICommon/UICommon.h"
#include "UICommon/DiscordPresence.h"

#include "InputCommon/InputConfig.h"
#include "InputCommon/ControllerEmu/ControlGroup/Attachments.h"
#include "InputCommon/ControllerEmu/ControlGroup/Cursor.h"
#include "InputCommon/ControllerEmu/Control/Control.h"
#include "InputCommon/ControlReference/ControlReference.h"
#include "InputCommon/ControllerInterface/Touch/ButtonManager.h"

#include "VideoCommon/AsyncRequests.h"
#include "VideoCommon/Fifo.h"
#include "VideoCommon/RenderBase.h"
#include "VideoCommon/VideoBackendBase.h"
#include "VideoCommon/VideoConfig.h"
#include "VideoCommon/OnScreenDisplay.h"
#include "VideoBackends/Vulkan/VideoBackend.h"
#include "VideoBackends/Vulkan/VulkanContext.h"

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4

__weak PVDolphinCore *_current = 0;
UIView *m_view = nullptr;
CAMetalLayer* m_metal_layer = nullptr;
CAEAGLLayer *m_gl_layer = nullptr;
Common::Flag s_running{true};
Common::Flag s_shutdown_requested{false};
Common::Flag s_tried_graceful_shutdown{false};
Common::Event s_update_main_frame_event;
std::mutex s_host_identity_lock;
bool s_have_wm_user_stop = false;
bool s_game_metadata_is_valid = false;
bool _isInitialized;
bool MsgAlert(const char* caption, const char* text, bool yes_no, Common::MsgType style);
void UpdateWiiPointer();

#pragma mark - Private
@interface PVDolphinCore() {

}

@end

#pragma mark - PVDolphinCore Begin

@implementation PVDolphinCore
{
	//DolHost *dol_host;
	uint16_t *_soundBuffer;
	bool _isWii;
	float _frameInterval;
	NSString *autoLoadStatefileName;
	NSString *_dolphinCoreModule;
	CGSize _dolphinCoreAspect;
	CGSize _dolphinCoreScreen;
	NSString *_romPath;
}

- (instancetype)init {
	if (self = [super init]) {
		_videoWidth  = 640;
		_videoHeight = 480;
		_videoBitDepth = 32; // ignored
		videoDepthBitDepth = 0; // TODO
		sampleRate = 44100;
		isNTSC = YES;
		dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
		_callbackQueue = dispatch_queue_create("org.provenance-emu.dolphin.CallbackHandlerQueue", queueAttributes);
		//dol_host = DolHost::GetInstance();
		[self parseOptions];
	}
	_current = self;
	return self;
}

- (void)dealloc {
	_current = nil;
}

#pragma mark - PVEmulatorCore
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
	const char *dataPath;
	[self initControllBuffers];
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
	if([[self systemIdentifier] isEqualToString:@"com.provenance.gamecube"])
	{
		_dolphinCoreModule = @"gc";
		_isWii = false;
		_frameInterval = 60;
		_dolphinCoreAspect = CGSizeMake(4, 3);
		_dolphinCoreScreen = CGSizeMake(640, 480);
		_videoWidth=640;
		_videoHeight=480;
	}
	else
	{
		_dolphinCoreModule = @"Wii";
		_isWii = true;
		_frameInterval = 60;
		_dolphinCoreAspect = CGSizeMake(16,9);
		_dolphinCoreScreen = CGSizeMake(832, 456);
		_videoWidth=832;
		_videoHeight=456;
	}
	//	dol_host->Init([[self supportDirectoryPath] fileSystemRepresentation], [path fileSystemRepresentation] );
	[self parseOptions];
	return YES;
}

/* Config at dolphin-ios/Source/Core/Core/Config */
- (void)setOptionValues {
	[self parseOptions];
	// Resolution upscaling
	Config::SetBase(Config::GFX_EFB_SCALE, self.resFactor);
	Config::SetBase(Config::GFX_MAX_EFB_SCALE, 16);

	// Graphics renderer
	if (self.gsPreference == 0) {
		Config::SetBase(Config::MAIN_GFX_BACKEND, "Vulkan");
		Config::SetBase(Config::MAIN_OSD_MESSAGES, true);
	} else if (self.gsPreference == 1) {
		Config::SetBase(Config::MAIN_GFX_BACKEND, "OGL");
		Config::SetBase(Config::MAIN_OSD_MESSAGES, false);
	}

	// CPU
	if (self.cpuType == 0) {
		SConfig::GetInstance().cpu_core = PowerPC::CPUCore::Interpreter;
		SConfig::GetInstance().m_DSPEnableJIT = false;
		SConfig::GetInstance().bJITOff = true;
		SConfig::GetInstance().bJITLoadStoreOff=true;
		SConfig::GetInstance().bJITLoadStoreFloatingOff=true;
		SConfig::GetInstance().bJITLoadStorePairedOff=true;
		SConfig::GetInstance().bJITFloatingPointOff=true;
		SConfig::GetInstance().bJITIntegerOff=true;
		SConfig::GetInstance().bJITPairedOff=true;
		SConfig::GetInstance().bJITSystemRegistersOff=true;
		SConfig::GetInstance().bJITBranchOff=true;
		SConfig::GetInstance().bJITRegisterCacheOff=true;
		Config::SetBase(Config::MAIN_JIT_FOLLOW_BRANCH, false);
		Config::SetBase(Config::MAIN_DSP_JIT, false);
	} else if (self.cpuType == 1) {
		SConfig::GetInstance().cpu_core = PowerPC::CPUCore::CachedInterpreter;
		SConfig::GetInstance().m_DSPEnableJIT = false;
	}

	// Filtering
	Config::SetBase(Config::GFX_ENHANCE_FORCE_FILTERING, self.isBilinear);

	// Fast Mem
	SConfig::GetInstance().bFastmem = self.fastMemory;

	// Anti Aliasing
    if (self.gsPreference == 0) {
        Config::SetBase(Config::GFX_MSAA, self.msaa);
        Config::SetBase(Config::GFX_SSAA, self.ssaa);
    } else {
        Config::SetBase(Config::GFX_MSAA, 1);
        Config::SetBase(Config::GFX_SSAA, false);
    }

	// Cheats
	SConfig::GetInstance().bEnableCheats = true;

	// CPU Overclock
	Config::SetBase(Config::MAIN_CPU_THREAD, true);
	SConfig::GetInstance().m_OCFactor = self.cpuOClock;
	SConfig::GetInstance().m_OCEnable = true;

	// CPU High Level / Low Level Emulation (Low Level is slower but better)
	SConfig::GetInstance().bDSPHLE = true;
	//Core::SetIsThrottlerTempDisabled(true);

	// Wiimote
	//SConfig::GetInstance().m_WiimoteContinuousScanning = true;
	Config::SetBase(Config::SYSCONF_WIIMOTE_MOTOR, false);

	// Wait for Shaders
	Config::SetBase(Config::GFX_WAIT_FOR_SHADERS_BEFORE_STARTING, true);

	// Must be set to false (will crash if set to other values)
	SConfig::GetInstance().bMMU = false;
	//SConfig::GetInstance().bDSPThread = false;
	//Config::SetBase(Config::GFX_ENABLE_GPU_TEXTURE_DECODING, false);

	// Sync
	Config::SetBase(Config::MAIN_SYNC_ON_SKIP_IDLE, true);
	Config::SetBase(Config::MAIN_SYNC_GPU, false);
	Config::SetBase(Config::MAIN_SYNC_GPU_MAX_DISTANCE, 200000);
	Config::SetBase(Config::MAIN_SYNC_GPU_MIN_DISTANCE, -200000);
	Config::SetBase(Config::MAIN_SYNC_GPU_OVERCLOCK, 1.0);
	Config::SetBase(Config::MAIN_FPRF, false);
	Config::SetBase(Config::MAIN_ACCURATE_NANS, false);
	Config::SetBase(Config::MAIN_TIMING_VARIANCE, 40);
	Config::SetBase(Config::MAIN_SKIP_IPL, true);

	//Audio
	Config::SetBase(Config::MAIN_AUDIO_LATENCY, 22);

	//Debug Settings
	SConfig::GetInstance().bEnableDebugging = false;
	SConfig::GetInstance().m_ShowFrameCount = false;

	// Graphics Multithreading
	//Config::SetBase(Config::GFX_BACKEND_MULTITHREADING, false);
	//Config::SetBase(Config::GFX_SAVE_TEXTURE_CACHE_TO_STATE, false);
	//Config::SetBase(Config::GFX_SHADER_COMPILATION_MODE, ShaderCompilationMode::Synchronous);
	//Config::SetBase(Config::GFX_SHADER_COMPILER_THREADS, 1);
	//Config::SetBase(Config::GFX_SHADER_PRECOMPILER_THREADS, 1);

	// Social
	Discord::SetDiscordPresenceEnabled(false);

	// Alerts
	Common::SetEnableAlert(false);

	SConfig::GetInstance().SaveSettings();
}

#pragma mark - Running
- (void)setupEmulation {
	std::string user_dir = std::string([[self.batterySavesPath stringByAppendingPathComponent:@"/saves/"] UTF8String]);
	Common::RegisterMsgAlertHandler(&MsgAlert);
	UICommon::SetUserDirectory(user_dir);
	UICommon::CreateDirectories();
	UICommon::Init();
	ELOG(@"User Directory set to '%s'\n", user_dir.c_str());
}

- (void)startVM:(UIView *)view {
	ELOG(@"Starting VM\n");
	dispatch_async(dispatch_get_global_queue(0, 0), ^{
		std::unique_lock<std::mutex> guard(s_host_identity_lock);
		__block WindowSystemInfo wsi;
		wsi.type = WindowSystemType::IPhoneOS;
		wsi.display_connection = nullptr;
		dispatch_sync(dispatch_get_main_queue(), ^{
			wsi.render_surface = (__bridge void*)view.layer;
		});
		wsi.render_surface_scale = [UIScreen mainScreen].scale;
		VideoBackendBase::ActivateBackend(Config::Get(Config::MAIN_GFX_BACKEND));
		ELOG(@"Using GFX backend: %s\n", Config::Get(Config::MAIN_GFX_BACKEND).c_str());
		std::string gamePath=std::string([_romPath UTF8String]);
		std::vector<std::string> normalized_game_paths;
		normalized_game_paths.push_back(gamePath);
		[self setupControllers];
		if (!BootManager::BootCore(BootParameters::GenerateFromFile(normalized_game_paths), wsi))
		{
			ELOG(@"Could not boot %s\n", [_romPath UTF8String]);
			return;
		}
		AudioCommon::SetSoundStreamRunning(true);
		while (Core::GetState() == Core::State::Starting && !Core::IsRunning())
		{
			Common::SleepCurrentThread(100);
		}
		_isInitialized = true;
        [self refreshScreenSize];
		while (_isInitialized)
		{
			guard.unlock();
			s_update_main_frame_event.Wait();
			guard.lock();
			Core::HostDispatchJobs();
		}
		ELOG(@"VM Started\n");
	});
}

- (void)startEmulation {
    // Skip Emulation Loop since the core has its own loop
    self.skipEmulationLoop = true;
	[self setupEmulation];
	[self setOptionValues];
	[self setupView];
	[super startEmulation];
	//		[self.renderDelegate willRenderFrameOnAlternateThread];
	//		dol_host->SetPresentationFBO((int)[[self.renderDelegate presentationFramebuffer] integerValue]);
	//if(dol_host->LoadFileAtPath())
	//_frameInterval = dol_host->GetFrameInterval();
	//Disable the OE framelimiting
	//	[self.renderDelegate suspendFPSLimiting];
	//	if(!self.isRunning) {
	//		[super startEmulation];
	////        [NSThread detachNewThreadSelector:@selector(runReicastRenderThread) toTarget:self withObject:nil];
	//	}
}

- (void)runReicastEmuThread {
	@autoreleasepool
	{
		//[self reicastMain];
		// Core returns
		// Unlock rendering thread
		//dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);
		[super stopEmulation];
	}
}

- (void)setPauseEmulation:(BOOL)flag {
	//dol_host->Pause(flag);
	Core::State state = flag ? Core::State::Paused : Core::State::Running;
	Core::SetState(state);
	[super setPauseEmulation:flag];
}

- (void)stopEmulation {
	[super stopEmulation];
	self->shouldStop = YES;
	_isInitialized = false;
	Core::SetState(Core::State::Running);
	ProcessorInterface::PowerButton_Tap();
	Core::Stop();
	while (CPU::GetState() != CPU::State::PowerDown)
		Common::SleepCurrentThread(1000);
	Core::Shutdown();
	s_host_identity_lock.unlock();
	//dol_host->RequestStop();
	//dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
	//dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);
	//[self.frontBufferCondition lock];
	//[self.frontBufferCondition signal];
	//[self.frontBufferCondition unlock];
}

- (void)resetEmulation {
	ProcessorInterface::ResetButton_Tap();
	//dol_host->Reset();
	//dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
	//[self.frontBufferCondition lock];
	//[self.frontBufferCondition signal];
	//[self.frontBufferCondition unlock];
}

- (void)refreshScreenSize {
	if (Core::IsRunningAndStarted() && g_renderer)
		g_renderer->ResizeSurface();
}

- (void)setupView {
	UIViewController *gl_view_controller = (UIViewController *)self.renderDelegate;
	auto screenBounds = [[UIScreen mainScreen] bounds];
	if(self.gsPreference == 0)
	{
		DolphinVulkanViewController *cgsh_view_controller=[[DolphinVulkanViewController alloc]
													  initWithResFactor:self.resFactor
													  videoWidth: self.videoWidth
													  videoHeight: self.videoHeight
													  core: self];
		m_metal_layer=(CAMetalLayer *)cgsh_view_controller.view.layer;
		m_view=cgsh_view_controller.view;
        m_view.contentMode = UIViewContentModeScaleToFill;
        [gl_view_controller addChildViewController:cgsh_view_controller];
        [cgsh_view_controller didMoveToParentViewController:gl_view_controller];
	} else if(self.gsPreference == 1) {
		DolphinOGLViewController *cgsh_view_controller=[[DolphinOGLViewController alloc]
													  initWithResFactor:self.resFactor
													  videoWidth: self.videoWidth
													  videoHeight: self.videoHeight
													  core: self];
		m_gl_layer=(CAEAGLLayer *)cgsh_view_controller.view.layer;
		m_view=cgsh_view_controller.view;
		m_view.contentMode = UIViewContentModeScaleToFill;
        [gl_view_controller addChildViewController:cgsh_view_controller];
        [cgsh_view_controller didMoveToParentViewController:gl_view_controller];
	}
	if ([gl_view_controller respondsToSelector:@selector(mtlview)]) {
        self.renderDelegate.mtlview.autoresizesSubviews=true;
        self.renderDelegate.mtlview.clipsToBounds=true;
		[self.renderDelegate.mtlview addSubview:m_view];
		[m_view.topAnchor constraintEqualToAnchor:self.renderDelegate.mtlview.topAnchor constant:0].active = true;
		[m_view.leadingAnchor constraintEqualToAnchor:self.renderDelegate.mtlview.leadingAnchor constant:0].active = true;
		[m_view.trailingAnchor constraintEqualToAnchor:self.renderDelegate.mtlview.trailingAnchor constant:0].active = true;
		[m_view.bottomAnchor constraintEqualToAnchor:self.renderDelegate.mtlview.bottomAnchor constant:0].active = true;
	} else {
        gl_view_controller.view.autoresizesSubviews=true;
        gl_view_controller.view.clipsToBounds=true;
		[gl_view_controller.view addSubview:m_view];
		[m_view.topAnchor constraintEqualToAnchor:gl_view_controller.parentViewController.view.topAnchor constant:0].active = true;
		[m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.parentViewController.view.leadingAnchor constant:0].active = true;
		[m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.parentViewController.view.trailingAnchor constant:0].active = true;
		[m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.parentViewController.view.bottomAnchor constant:0].active = true;
	}
}
@end

/* Dolphin Host (Required by Core) */
void Host_NotifyMapLoaded()
{
}
void Host_RefreshDSPDebuggerWindow()
{
}

bool Host_UIBlocksControllerState()
{
  return false;
}

void Host_Message(HostMessageID id)
{
  ELOG(@"message id: %i\n", (int)id);
  if (id == HostMessageID::WMUserJobDispatch)
	  s_update_main_frame_event.Set();
  else if (id == HostMessageID::WMUserStop) {
	s_have_wm_user_stop = true;
	if (Core::IsRunning())
	  Core::QueueHostJob(&Core::Stop);
  } else if (id == HostMessageID::WMUserCreate)
	ELOG(@"User Create Called\n", (int)id);
}

void Host_UpdateTitle(const std::string& title)
{
}

void Host_UpdateDisasmDialog()
{
}

void Host_UpdateMainFrame()
{
	ELOG(@"UpdateMainFrame called\n");
}


void Host_RequestRenderWindowSize(int width, int height)
{
	ELOG(@"Requested Render Window Size %d %d\n",width,height);
	UpdateWiiPointer();
}

void Host_TargetRectangleWasUpdated()
{
	UpdateWiiPointer();
}

bool Host_UINeedsControllerState()
{
	return false;
}

bool Host_RendererHasFocus()
{
	return true;
}

bool Host_RendererIsFullscreen()
{
	return false;
}

void Host_YieldToUI()
{
}

void Host_UpdateProgressDialog(const char* caption, int position, int total)
{
}

void Host_TitleChanged()
{
}

std::vector<std::string> Host_GetPreferredLocales()
{
  return {};
}

bool Host_RendererHasFullFocus()
{
  return true;
}

bool MsgAlert(const char* caption, const char* text, bool yes_no, Common::MsgType style)
{
	ELOG(@"Message %s %s\n", caption, text);
	return true;
}

void UpdateWiiPointer()
{
	ELOG(@"Update Wii Pointer\n");
}
