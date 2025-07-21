//
//  PVDolphinCore.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore.h"
#import "PVDolphinCore+Controls.h"
#import "PVDolphinCore+Audio.h"
#import "PVDolphinCore+Video.h"
#import <PVDolphin/PVDolphin-Swift.h>

#import <Foundation/Foundation.h>
#import <PVDolphin/PVDolphin-Swift.h>
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVEmulatorCore;

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

/* Dolphin Includes */
//#include "Core/MachineContext.h"
#include "AudioCommon/AudioCommon.h"
#include "AudioCommon/SoundStream.h"

#include "Common/CPUDetect.h"
#include "Common/CommonPaths.h"
#include "Common/CommonTypes.h"
#include "Common/FileUtil.h"
#include "Common/IniFile.h"
#include "Common/FileSearch.h"
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
#include "Core/PowerPC/MMU.h"
#ifdef HAVE_JIT
#include "Core/PowerPC/JitInterface.h"
#endif

#include "Core/Config/MainSettings.h"

#include "Core/System.h"
#include "Core/Config/GraphicsSettings.h"

#include "UICommon/CommandLineParse.h"
#include "UICommon/UICommon.h"
#include "UICommon/DiscordPresence.h"

#include "InputCommon/InputConfig.h"
#include "InputCommon/ControllerEmu/ControlGroup/Attachments.h"
#include "InputCommon/ControllerEmu/ControlGroup/Cursor.h"
#include "InputCommon/ControllerEmu/Control/Control.h"
#include "InputCommon/ControlReference/ControlReference.h"
#include "InputCommon/ControllerInterface/iOS/StateManager.h"

#include "VideoCommon/AsyncRequests.h"
#include "VideoCommon/Fifo.h"
#include "VideoCommon/RenderBase.h"
#include "VideoCommon/VertexLoaderManager.h"
#include "VideoCommon/VideoBackendBase.h"
#include "VideoCommon/VideoConfig.h"
#include "VideoCommon/OnScreenDisplay.h"
#include "VideoCommon/Present.h"
#include "VideoBackends/Vulkan/VideoBackend.h"
#include "VideoBackends/Vulkan/VulkanContext.h"

#include "Core/GeckoCode.h"
#include "Core/GeckoCodeConfig.h"
#include "Core/ActionReplay.h"
#include "Core/ARDecrypt.h"
#include "Core/HW/Memmap.h"
#include "Core/PowerPC/PowerPC.h"

#include "FastmemUtil.h"

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define IS_IPHONE() ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)

static Common::Flag s_running{true};
static Common::Flag s_shutdown_requested{false};
static Common::Flag s_tried_graceful_shutdown{false};
static Common::Event s_update_main_frame_event;
static bool s_have_wm_user_stop = false;
static bool s_game_metadata_is_valid = false;
static std::mutex s_host_identity_lock;
static bool _isOff = false;
static bool can_enable_fastmem = CanEnableFastmem();
static bool hacky_fastmem = GetFastmemType() == DOLFastmemTypeHacky;
__weak PVDolphinCoreBridge *_current = 0;
bool _isInitialized;
std::string user_dir;
static bool MsgAlert(const char* caption, const char* text, bool yes_no, Common::MsgType style);
static void UpdateWiiPointer();

#pragma mark - Private
@interface PVDolphinCoreBridge() {

}

@end

#pragma mark - PVDolphinCore Begin

@implementation PVDolphinCoreBridge
{
    //DolHost *dol_host;
    uint16_t *_soundBuffer;
    float _frameInterval;
    NSString *autoLoadStatefileName;
    NSString *_dolphinCoreModule;
    CGSize _dolphinCoreAspect;
    CGSize _dolphinCoreScreen;
    NSString *_romPath;
}

- (instancetype)init {
    if (self = [super init]) {
        self.alwaysUseMetal = true;
        self.skipLayout = true;
        _videoWidth  = 640;
        _videoHeight = 480;
        _videoBitDepth = 32; // ignored
        videoDepthBitDepth = 0; // TODO
        sampleRate = 44100;
        isNTSC = YES;
        dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
        _callbackQueue = dispatch_queue_create("org.provenance-emu.dolphin.CallbackHandlerQueue", queueAttributes);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(optionUpdated:) name:@"OptionUpdated" object:nil];
        [self parseOptions];
    }
    _current=self;
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
        _frameInterval = 120;
        _dolphinCoreAspect = CGSizeMake(4, 3);
        _dolphinCoreScreen = CGSizeMake(640, 480);
        _videoWidth=640;
        _videoHeight=480;
    }
    else
    {
        _dolphinCoreModule = @"Wii";
        _isWii = true;
        _frameInterval = 120;
        _dolphinCoreAspect = CGSizeMake(16,9);
        _dolphinCoreScreen = CGSizeMake(832, 456);
        _videoWidth=832;
        _videoHeight=456;
    }
    [self parseOptions];
    return YES;
}

/* Config at dolphin-ios/Source/Core/Core/Config */
- (void)setOptionValues {
    [self parseOptions];
    Config::Load();

    // Resolution upscaling
    Config::SetBase(Config::GFX_EFB_SCALE, self.resFactor);
    Config::SetBase(Config::GFX_MAX_EFB_SCALE, 8); // 16 but dolphini uses 8

    // Graphics renderer
    if (self.gsPreference == 0) {
        Config::SetBase(Config::MAIN_GFX_BACKEND, "Vulkan");
        Config::SetBase(Config::MAIN_OSD_MESSAGES, true);
    } else if (self.gsPreference == 1) {
        Config::SetBase(Config::MAIN_GFX_BACKEND, "OGL");
        Config::SetBase(Config::MAIN_OSD_MESSAGES, false);
    }
    // PopulateBackendInfo is called automatically during initialization

    // CPU
    if (self.cpuType == 0) {
        Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::Interpreter);
    } else if (self.cpuType == 1) {
        Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::CachedInterpreter);
    } else if (self.cpuType == 2) {
#if defined(__x86_64__)
        Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::JIT64);
#else
        Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::JITARM64);
#endif
    }

    // SDCard
    Config::SetBase(Config::MAIN_WII_SD_CARD, true);
    Config::SetBase(Config::MAIN_ALLOW_SD_WRITES, true);

    // Filtering
    Config::SetBase(Config::GFX_ENHANCE_FORCE_TEXTURE_FILTERING, self.isBilinear ? TextureFilteringMode::Linear : TextureFilteringMode::Default);

    // Fast Mem
    if (self.fastMemory) {
        Config::SetBase(Config::MAIN_FASTMEM, self.fastMemory);
        Config::SetBase(Config::MAIN_FASTMEM, self.fastMemory);
        if (can_enable_fastmem) {
            // MAIN_DEBUG_HACKY_FASTMEM has been removed in modern Dolphin
            // Fastmem behavior is automatically determined by the system
        }
    }
    Config::SetBase(Config::GFX_SHOW_FPS, false);

    // Anti Aliasing
    if (self.gsPreference == 0) {
        Config::SetBase(Config::GFX_MSAA, self.msaa);
        Config::SetBase(Config::GFX_SSAA, self.ssaa);
    } else {
        Config::SetBase(Config::GFX_MSAA, 1);
        Config::SetBase(Config::GFX_SSAA, false);
    }

    // Cheats
    Config::SetBase(Config::MAIN_ENABLE_CHEATS, self.enableCheatCode);

    // CPU Overclock
    Config::SetBase(Config::MAIN_CPU_THREAD, true);
    Config::SetBase(Config::MAIN_OVERCLOCK, self.cpuOClock);
    Config::SetBase(Config::MAIN_OVERCLOCK_ENABLE, self.cpuOClock > 1);

    // CPU High Level / Low Level Emulation
    Config::SetBase(Config::MAIN_DSP_HLE, true);
    Core::SetIsThrottlerTempDisabled(false);

    // Wait for Shaders
    Config::SetBase(Config::GFX_WAIT_FOR_SHADERS_BEFORE_STARTING, true);

    // iOS Power Management
    Config::SetBase(Config::MAIN_ANALYTICS_ENABLED, false);           // Disable analytics for privacy/performance
    // Wiimote
    Config::SetBase(Config::SYSCONF_WIIMOTE_MOTOR, false);
    Config::SetBase(Config::MAIN_WII_KEYBOARD, false);
    Config::SetBase(Config::MAIN_WIIMOTE_CONTINUOUS_SCANNING, false);
    Config::SetBase(Config::MAIN_BLUETOOTH_PASSTHROUGH_ENABLED, false);

    // Social
    Discord::SetDiscordPresenceEnabled(false);

    // Alerts
    Common::SetEnableAlert(false);

    // Audio
    // Volume is handled by Settings::Instance().SetVolume() in DolphinQt
    // bAutomaticStart is no longer needed in modern Dolphin

    // Debug Settings
    Config::SetBase(Config::MAIN_ENABLE_DEBUGGING, false);
    // m_ShowFrameCount is handled by video config now
}

#pragma mark - Running
- (void)setupEmulation {
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString* saveDirectory = [self.batterySavesPath stringByAppendingPathComponent:@"../DolphinData" ];

    // Copy Sys Bundle
    NSString *sysPath = [[NSBundle bundleForClass:[PVDolphinCore class]] pathForResource:@"Sys" ofType:nil];
    if (![fm fileExistsAtPath: saveDirectory]) {
        if(![fm copyItemAtPath:sysPath toPath:saveDirectory error:&error]) {
            NSLog(@"Error copying the sys files: %@", [error description]);
        }
    }

    // Copy Wii Files (needed to boot some games)
    NSString *wiiPath = [[NSBundle bundleForClass:[PVDolphinCore class]] pathForResource:@"Sys/Wii" ofType:nil];
    NSString* wiiDestDirectory = [self.batterySavesPath stringByAppendingPathComponent:@"../DolphinData/Wii" ];
    [self syncResources:wiiPath to:wiiDestDirectory overWrite:false];

    // Copy gecko code handler from resource bundle
    NSString *filePath = [[NSBundle bundleForClass:[PVDolphinCore class]] pathForResource:@"Sys/codehandler.bin" ofType:nil];
    NSString *codeHandler = [saveDirectory stringByAppendingPathComponent:@"codehandler.bin"];
    if (![fm fileExistsAtPath: codeHandler]) {
        if(![fm copyItemAtPath:filePath toPath:codeHandler error:&error]) {
            NSLog(@"Error copying the gecko handler: %@", [error description]);
        }
    }
    user_dir = std::string([saveDirectory UTF8String]);
    Common::RegisterMsgAlertHandler(&MsgAlert);
    UICommon::SetUserDirectory(user_dir);
    UICommon::CreateDirectories();
    UICommon::Init();
    NSLog(@"User Directory set to '%s'\n", user_dir.c_str());
    NSString *configPath = [[NSBundle bundleForClass:[PVDolphinCore class]] pathForResource:@"Config" ofType:nil];
    NSString *configDirectory = [self.batterySavesPath stringByAppendingPathComponent:@"../DolphinData/Config" ];
    [self syncResources:configPath to:configDirectory overWrite:true];
}
- (void)syncResource:(NSString*)from to:(NSString*)to {
    if (!from)
        return;
    NSLog(@"Syncing %@ to %@", from, to);
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSData *fileData = [NSData dataWithContentsOfFile:from];
    [fileData writeToFile:to atomically:NO];
}
- (void)syncResources:(NSString*)from to:(NSString*)to overWrite:(bool)overwrite{
    if (!from)
        return;
    NSLog(@"Syncing %@ to %@", from, to);
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSArray* files = [fm contentsOfDirectoryAtPath:from error:&error];
    if (![fm fileExistsAtPath: to]) {
        [fm createDirectoryAtPath:to withIntermediateDirectories:true attributes:nil error:nil];
    }
    for (NSString *file in files) {
        NSString *src=  [NSString stringWithFormat:@"%@/%@", from, file];
        NSString *dst = [NSString stringWithFormat:@"%@/%@", to, file];
        NSLog(@"Syncing %@ %@", src, dst);
        if (overwrite) {
            [self syncResource:src to:dst];
        } else if (![fm fileExistsAtPath: dst]) {
            [fm copyItemAtPath:src toPath:dst error:nil];
        }
    }
}
- (void)startVM:(UIView *)view {
    NSLog(@"Starting VM\n");
    m_view=view;
    // Ensure core is stopped (otherwise game lags)
    Core::Stop(Core::System::GetInstance());
    while (Core::GetState(Core::System::GetInstance()) != Core::State::Uninitialized) {
        sleep(1);
    }
    [NSThread detachNewThreadSelector:@selector(startDolphin) toTarget:self withObject:nil];
}

- (void)startDolphin {
    std::unique_lock<std::mutex> guard(s_host_identity_lock);
    __block WindowSystemInfo wsi;
    wsi.type = WindowSystemType::iOS;
    wsi.display_connection = nullptr;
    dispatch_sync(dispatch_get_main_queue(), ^{
        wsi.render_surface = (__bridge void*)m_view.layer;
    });
    wsi.render_surface_scale = [UIScreen mainScreen].scale;
    VideoBackendBase::ActivateBackend(Config::Get(Config::MAIN_GFX_BACKEND));
    NSLog(@"Using GFX backend: %s\n", Config::Get(Config::MAIN_GFX_BACKEND).c_str());

    // Initialize ControllerInterface for iOS input backend
    g_controller_interface.Initialize(wsi);
    NSLog(@"🎮 ControllerInterface initialized for iOS input backend");

    std::string gamePath=std::string([_romPath UTF8String]);
    std::vector<std::string> normalized_game_paths;
    normalized_game_paths.push_back(gamePath);
    [self setupControllers];
    if (!BootManager::BootCore(Core::System::GetInstance(), BootParameters::GenerateFromFile(normalized_game_paths), wsi))
    {
        NSLog(@"Could not boot %s\n", [_romPath UTF8String]);
        return;
    }
    AudioCommon::SetSoundStreamRunning(Core::System::GetInstance(), true);
    while (Core::GetState(Core::System::GetInstance()) == Core::State::Starting && !Core::IsRunning(Core::System::GetInstance()))
    {
        Common::SleepCurrentThread(100);
    }
    _isInitialized = true;
    _isOff = false;
    NSLog(@"VM Started\n");
    while (_isInitialized)
    {
        guard.unlock();
        s_update_main_frame_event.Wait();
        guard.lock();
        Core::HostDispatchJobs(Core::System::GetInstance());
    }
    _isOff=true;
}

- (void)startEmulation {
    self.skipEmulationLoop = true;
    [self prepareAudio];
    [self setupEmulation];

    [self setOptionValues];
    [self setupView];
    [super startEmulation];
}

- (void)setPauseEmulation:(BOOL)flag {
    Core::State state = flag ? Core::State::Paused : Core::State::Running;
    Core::SetState(Core::System::GetInstance(), state);
    [super setPauseEmulation:flag];
}

- (void)stopEmulation {
    [super stopEmulation];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.shouldStop = YES;
    _isInitialized = false;
    g_controller_interface.Shutdown();
    Core::SetState(Core::System::GetInstance(), Core::State::Running);
    Core::System::GetInstance().GetProcessorInterface().PowerButton_Tap();
    Core::Stop(Core::System::GetInstance());
    s_update_main_frame_event.Set();
    while (Core::System::GetInstance().GetCPU().GetState() != CPU::State::PowerDown ||
           Core::GetState(Core::System::GetInstance()) != Core::State::Uninitialized ||
           !_isOff) {
        sleep(1);
    }
    Core::Shutdown(Core::System::GetInstance());
    VertexLoaderManager::Clear();
    Core::System::GetInstance().GetFifo().ExitGpuLoop();
    Core::System::GetInstance().GetFifo().Shutdown();
    Core::System::GetInstance().GetMemory().ShutdownFastmemArena();
    Core::System::GetInstance().GetMemory().Shutdown();
    Core::System::GetInstance().GetPowerPC().Shutdown();
    g_video_backend->Shutdown();
    s_host_identity_lock.unlock();
    [m_view removeFromSuperview];
    [m_view_controller dismissViewControllerAnimated:NO completion:nil];
    m_gl_layer = nullptr;
    m_metal_layer = nullptr;
    m_view_controller = nullptr;
    m_view=nullptr;
    AudioCommon::ShutdownSoundStream(Core::System::GetInstance());
    g_renderer.release();
}
-(void)startHaptic { }
-(void)stopHaptic { }

- (void)resetEmulation {
	Core::System::GetInstance().GetProcessorInterface().ResetButton_Tap();
}

- (void)refreshScreenSize {
    if (Core::IsRunningOrStarting(Core::System::GetInstance()) && g_presenter)
        g_presenter->ResizeSurface();
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
- (void)setupView {
	UIViewController *gl_view_controller = (UIViewController *)self.renderDelegate;
	auto screenBounds = [[UIScreen mainScreen] bounds];
    if (self.touchViewController) {
        UIViewController *gl_view_controller = (UIViewController *)self.renderDelegate;
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        if(self.gsPreference == 0)
        {
            DolphinVulkanViewController *cgsh_view_controller=[[DolphinVulkanViewController alloc]
                                                               initWithResFactor:self.resFactor
                                                               videoWidth: self.videoWidth
                                                               videoHeight: self.videoHeight
                                                               core: self];
            m_metal_layer=(CAMetalLayer *)cgsh_view_controller.view.layer;
            m_view_controller=(UIViewController *)cgsh_view_controller;
            m_view=cgsh_view_controller.view;
            m_view.contentMode = UIViewContentModeScaleToFill;
        } else if(self.gsPreference == 1) {
            DolphinOGLViewController *cgsh_view_controller=[[DolphinOGLViewController alloc]
                                                            initWithResFactor:self.resFactor
                                                            videoWidth: self.videoWidth
                                                            videoHeight: self.videoHeight
                                                            core: self];
            m_gl_layer=(CAEAGLLayer *)cgsh_view_controller.view.layer;
            m_view_controller=(UIViewController *)cgsh_view_controller;
            m_view=cgsh_view_controller.view;
            m_view.contentMode = UIViewContentModeScaleToFill;
        }

        m_view=m_view_controller.view;
        UIViewController *rootController = m_view_controller;
        [self.touchViewController.view addSubview:m_view];
        [self.touchViewController addChildViewController:rootController];
        [rootController didMoveToParentViewController:self.touchViewController];
        [self.touchViewController.view sendSubviewToBack:m_view];
        [rootController.view setHidden:false];
        rootController.view.translatesAutoresizingMaskIntoConstraints = false;
        [[rootController.view.topAnchor constraintEqualToAnchor:self.touchViewController.view.topAnchor] setActive:YES];
        [[rootController.view.bottomAnchor constraintEqualToAnchor:self.touchViewController.view.bottomAnchor] setActive:YES];
        [[rootController.view.leadingAnchor constraintEqualToAnchor:self.touchViewController.view.leadingAnchor] setActive:YES];
        [[rootController.view.trailingAnchor constraintEqualToAnchor:self.touchViewController.view.trailingAnchor] setActive:YES];
        self.touchViewController.view.userInteractionEnabled=true;
        self.touchViewController.view.autoresizesSubviews=true;
        self.touchViewController.view.userInteractionEnabled=true;
#if !TARGET_OS_TV
        self.touchViewController.view.multipleTouchEnabled=true;
#endif
    } else {
        if(self.gsPreference == 0)
        {
            DolphinVulkanViewController *cgsh_view_controller=[[DolphinVulkanViewController alloc]
                                                               initWithResFactor:self.resFactor
                                                               videoWidth: self.videoWidth
                                                               videoHeight: self.videoHeight
                                                               core: self];
            m_metal_layer=(CAMetalLayer *)cgsh_view_controller.view.layer;
            m_view_controller=(UIViewController *)cgsh_view_controller;
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
            m_view_controller=(UIViewController *)cgsh_view_controller;
            m_view=cgsh_view_controller.view;
            m_view.contentMode = UIViewContentModeScaleToFill;
            [gl_view_controller addChildViewController:cgsh_view_controller];
            [cgsh_view_controller didMoveToParentViewController:gl_view_controller];
        }
        if ([gl_view_controller respondsToSelector:@selector(mtlView)]) {
            self.renderDelegate.mtlView.autoresizesSubviews=true;
            self.renderDelegate.mtlView.clipsToBounds=true;
            [self.renderDelegate.mtlView addSubview:m_view];
            [m_view.topAnchor constraintEqualToAnchor:self.renderDelegate.mtlView.topAnchor constant:0].active = true;
            [m_view.leadingAnchor constraintEqualToAnchor:self.renderDelegate.mtlView.leadingAnchor constant:0].active = true;
            [m_view.trailingAnchor constraintEqualToAnchor:self.renderDelegate.mtlView.trailingAnchor constant:0].active = true;
            [m_view.bottomAnchor constraintEqualToAnchor:self.renderDelegate.mtlView.bottomAnchor constant:0].active = true;
        } else {
            gl_view_controller.view.autoresizesSubviews=true;
            gl_view_controller.view.clipsToBounds=true;
            [gl_view_controller.view addSubview:m_view];
            [m_view.widthAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.widthAnchor].active=true;
            [m_view.heightAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.heightAnchor constant: 0].active=true;
            [m_view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor constant:0].active = true;
            [m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor constant:0].active = true;
            [m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor constant:0].active = true;
            [m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor constant:0].active = true;
        }
    }
}
-(void)optionUpdated:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    for (NSString* key in info.allKeys) {
        NSString *value=[info valueForKey:key];
        [self processOption:key value:value];
        printf("Received Option key:%s value:%s\n",key.UTF8String, value.UTF8String);
    }
}
-(void)processOption:(NSString *)key value:(NSString*)value {
    typedef void (^Process)();
    NSDictionary *actions = @{
        @MAP_MULTIPLAYER:
        ^{
            self.multiPlayer = [value isEqualToString:@"true"];
            [self setupControllers];
        },
        @"Audio Volume":
        ^{
            [self setOptionValues];
        },
    };
    Process action=[actions objectForKey:key];
    if (action)
        action();
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
    NSLog(@"message id: %i\n", (int)id);
  if (id == HostMessageID::WMUserJobDispatch)
	  s_update_main_frame_event.Set();
  else if (id == HostMessageID::WMUserStop) {
	s_have_wm_user_stop = true;
	if (Core::IsRunning(Core::System::GetInstance()))
	  Core::QueueHostJob([](Core::System& system) { Core::Stop(system); });
  } else if (id == HostMessageID::WMUserCreate)
      NSLog(@"User Create Called %i\n", (int)id);
}

void Host_UpdateTitle(const std::string& title)
{
}

void Host_UpdateDisasmDialog()
{
}

void Host_UpdateMainFrame()
{
    NSLog(@"UpdateMainFrame called\n");
}


void Host_RequestRenderWindowSize(int width, int height)
{
    NSLog(@"Requested Render Window Size %d %d\n",width,height);
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
    NSLog(@"Message %s %s\n", caption, text);
	return true;
}

void UpdateWiiPointer()
{
    NSLog(@"Update Wii Pointer\n");
    if (Core::IsRunningOrStarting(Core::System::GetInstance()) && g_presenter) {
        g_presenter->ResizeSurface();
//        ciface::iOS::StateManager::GetInstance()->SetButtonPressed(4, ciface::iOS::ButtonType::WIIMOTE_IR_RECENTER, true);
    }
}
