//
//  PVDolphinCore.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

//#import "PVDolphinCore.h"
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
#import <CoreHaptics/CoreHaptics.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <assert.h>

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

// Function to reset all static/global state for iOS dynamic library reloading
static void ResetDolphinStaticState() {
    NSLog(@"🐬 [RESET] Resetting Dolphin static/global state for iOS dynamic library reload");

    // CRITICAL: Ensure the host identity lock is unlocked before reset
    // This prevents deadlock on second core load
    try {
        // Try to unlock if it's currently locked (non-blocking check)
        if (s_host_identity_lock.try_lock()) {
            s_host_identity_lock.unlock();
            NSLog(@"🐬 [RESET] Host identity lock was unlocked");
        } else {
            NSLog(@"🐬 [RESET] Host identity lock was already unlocked or in use");
        }
    } catch (...) {
        NSLog(@"🐬 [RESET] Exception while checking host identity lock state");
    }

    // Reset static flags and events
    s_running.Set(true);
    s_shutdown_requested.Set(false);
    s_tried_graceful_shutdown.Set(false);
    s_update_main_frame_event.Reset();
    s_have_wm_user_stop = false;
    s_game_metadata_is_valid = false;
    _isOff = false;
    _isInitialized = false;

    // Reset Dolphin core systems that may have static state
    try {
        // Reset Core system state
        if (Core::GetState(Core::System::GetInstance()) != Core::State::Uninitialized) {
            Core::Stop(Core::System::GetInstance());
            while (Core::GetState(Core::System::GetInstance()) != Core::State::Uninitialized) {
                Common::SleepCurrentThread(10);
            }
        }

        // Reset PowerPC state (use correct API)
//        auto& ppc = Core::System::GetInstance().GetPowerPC();
//        ppc.Reset();

        // Reset memory system
        auto& memory = Core::System::GetInstance().GetMemory();
        memory.Shutdown();

        // Reset CPU state
        auto& cpu = Core::System::GetInstance().GetCPU();
        cpu.Reset();

        // Reset video backend state
        if (g_video_backend) {
            g_video_backend->Shutdown();
        }

        // Reset audio system
        AudioCommon::ShutdownSoundStream(Core::System::GetInstance());

        // Reset controller interface
        g_controller_interface.Shutdown();

        // CRITICAL: Shutdown UICommon to reset its static state
        try {
            UICommon::Shutdown();
            NSLog(@"🐬 [RESET] UICommon shutdown completed in reset");
        } catch (...) {
            NSLog(@"🐬 [RESET] UICommon shutdown failed in reset - continuing");
        }

        // Reset configuration to defaults (if method exists)
        try {
            Config::ClearCurrentRunLayer();
        } catch (...) {
            // Method may not exist in all Dolphin versions, ignore
        }

        NSLog(@"🐬 [RESET] Static state reset complete");
    } catch (const std::exception& e) {
        NSLog(@"🐬 [ERROR] Exception during state reset: %s", e.what());
    } catch (...) {
        NSLog(@"🐬 [ERROR] Unknown exception during state reset");
    }
}

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

    // === GRAPHICS SETTINGS ===

    // Resolution upscaling
    Config::SetBase(Config::GFX_EFB_SCALE, self.resFactor);
    Config::SetBase(Config::GFX_MAX_EFB_SCALE, 8); // 16 but dolphini uses 8

    // Graphics renderer
    if (self.gsPreference == 0) {
        Config::SetBase(Config::MAIN_GFX_BACKEND, std::string("Vulkan"));
        Config::SetBase(Config::MAIN_OSD_MESSAGES, true);
    } else if (self.gsPreference == 1) {
        Config::SetBase(Config::MAIN_GFX_BACKEND, std::string("OGL"));
        Config::SetBase(Config::MAIN_OSD_MESSAGES, false);
    } else if (self.gsPreference == 2) {
        Config::SetBase(Config::MAIN_GFX_BACKEND, std::string("Metal"));
        Config::SetBase(Config::MAIN_OSD_MESSAGES, true);
    }

    // Aspect Ratio
    Config::SetBase(Config::GFX_ASPECT_RATIO, (AspectMode)self.aspectRatio);

    // V-Sync
    Config::SetBase(Config::GFX_VSYNC, self.vsync);

    // Anisotropic Filtering
    Config::SetBase(Config::GFX_ENHANCE_MAX_ANISOTROPY, self.anisotropicFiltering);

    // Texture Filtering
    Config::SetBase(Config::GFX_ENHANCE_FORCE_TEXTURE_FILTERING, self.isBilinear ? TextureFilteringMode::Linear : TextureFilteringMode::Default);

    // FPS Display
    Config::SetBase(Config::GFX_SHOW_FPS, self.showFPS);

    // === GRAPHICS ENHANCEMENTS ===

    // Scaled EFB Copy
    Config::SetBase(Config::GFX_HACK_COPY_EFB_SCALED, self.scaledEFBCopy);

    // Disable Fog
    Config::SetBase(Config::GFX_DISABLE_FOG, self.disableFog);

    // Per-Pixel Lighting
    Config::SetBase(Config::GFX_ENABLE_PIXEL_LIGHTING, self.pixelLighting);

    // Force True Color
    Config::SetBase(Config::GFX_ENHANCE_FORCE_TRUE_COLOR, self.forceTrueColor);

    // === GRAPHICS HACKS (DolphinQt Parity) ===

    // Skip EFB Access from CPU (inverted logic - true means disable access)
    Config::SetBase(Config::GFX_HACK_EFB_ACCESS_ENABLE, !self.skipEFBAccessFromCPU);

    // Ignore Format Changes (inverted logic - true means emulate format changes)
    Config::SetBase(Config::GFX_HACK_EFB_EMULATE_FORMAT_CHANGES, !self.ignoreFormatChanges);

    // Store EFB Copies to Texture Only (skip copy to RAM)
    Config::SetBase(Config::GFX_HACK_SKIP_EFB_COPY_TO_RAM, self.storeEFBCopiesToTextureOnly);

    // Defer EFB Copies
    Config::SetBase(Config::GFX_HACK_DEFER_EFB_COPIES, self.deferEFBCopies);

    // Texture Cache Accuracy (note: this may need special handling as it's not a simple bool)
    // For now, map: 0=Safe (false), 1=Medium (false), 2=Fast (true)
    Config::SetBase(Config::GFX_HACK_FAST_TEXTURE_SAMPLING, (self.textureCacheAccuracy == 2));

    // Store XFB Copies to Texture Only (skip copy to RAM)
    Config::SetBase(Config::GFX_HACK_SKIP_XFB_COPY_TO_RAM, self.storeXFBCopiesToTextureOnly);

    // Immediate XFB
    Config::SetBase(Config::GFX_HACK_IMMEDIATE_XFB, self.immediateXFB);

    // Skip Duplicate XFBs
    Config::SetBase(Config::GFX_HACK_SKIP_DUPLICATE_XFBS, self.skipDuplicateXFBs);

    // GPU Texture Decoding
    Config::SetBase(Config::GFX_ENABLE_GPU_TEXTURE_DECODING, self.gpuTextureDecoding);

    // Fast Depth Calculation
    Config::SetBase(Config::GFX_FAST_DEPTH_CALC, self.fastDepthCalculation);

    // Disable Bounding Box (inverted logic - true means disable, false means enable)
    Config::SetBase(Config::GFX_HACK_BBOX_ENABLE, !self.disableBoundingBox);

    // Save Texture Cache to State
    Config::SetBase(Config::GFX_SAVE_TEXTURE_CACHE_TO_STATE, self.saveTextureCacheToState);

    // Vertex Rounding
    Config::SetBase(Config::GFX_HACK_VERTEX_ROUNDING, self.vertexRounding);

    // VI Skip
    Config::SetBase(Config::GFX_HACK_VI_SKIP, self.viSkip);

    // === SHADER SETTINGS ===

    // Shader Compilation Mode
    Config::SetBase(Config::GFX_SHADER_COMPILATION_MODE, (ShaderCompilationMode)self.shaderCompilationMode);

    // Wait for Shaders
    Config::SetBase(Config::GFX_WAIT_FOR_SHADERS_BEFORE_STARTING, self.waitForShaders);

    // === ANTI-ALIASING ===

    // MSAA
    if (self.gsPreference == 0) { // Vulkan supports MSAA better
        Config::SetBase(Config::GFX_MSAA, self.msaa);
        Config::SetBase(Config::GFX_SSAA, self.ssaa);
    } else {
        Config::SetBase(Config::GFX_MSAA, self.msaa > 0 ? self.msaa : 1);
        Config::SetBase(Config::GFX_SSAA, false); // SSAA typically not supported on OpenGL/Metal on iOS
    }

    // === CPU/EMULATION SETTINGS ===

    // CPU Core with JIT detection and fallback
    int8_t effectiveCpuType = self.cpuType;

    // JIT availability check - if user wants JIT but it's not available, fall back
    if (self.cpuType == 2) {
        bool jitAvailable = [self checkJITAvailable];
        if (!jitAvailable) {
            NSLog(@"⚠️ JIT requested but not available. Falling back to Cached Interpreter for better performance than Interpreter.");
            effectiveCpuType = 1; // Fall back to CachedInterpreter
        } else {
            NSLog(@"✅ JIT is available and will be used for maximum performance.");
        }
    }

    if (effectiveCpuType == 0) {
        Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::Interpreter);
        NSLog(@"🐌 CPU Core: Interpreter (Slowest, Most Compatible)");
    } else if (effectiveCpuType == 1) {
        Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::CachedInterpreter);
        NSLog(@"⚡ CPU Core: Cached Interpreter (Balanced Performance)");
    } else if (effectiveCpuType == 2) {
#if defined(__x86_64__)
        Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::JIT64);
        NSLog(@"🚀 CPU Core: JIT64 (Maximum Performance)");
#else
        Config::SetBase(Config::MAIN_CPU_CORE, PowerPC::CPUCore::JITARM64);
        NSLog(@"🚀 CPU Core: JITARM64 (Maximum Performance)");
#endif
    }

    // CPU Overclock
    float clockMultiplier = self.cpuOClock / 100.0f;
    Config::SetBase(Config::MAIN_OVERCLOCK, clockMultiplier);
    Config::SetBase(Config::MAIN_OVERCLOCK_ENABLE, clockMultiplier != 1.0f);

    // Dual Core
    Config::SetBase(Config::MAIN_CPU_THREAD, self.dualCore);

    // Idle Skipping
    Config::SetBase(Config::MAIN_SYNC_ON_SKIP_IDLE, self.idleSkipping);

    // Fast Memory
    if (self.fastMemory) {
        Config::SetBase(Config::MAIN_FASTMEM, self.fastMemory);
        if (can_enable_fastmem) {
            // Fastmem behavior is automatically determined by the system in modern Dolphin
        }
    }

    // Cheats
    Config::SetBase(Config::MAIN_ENABLE_CHEATS, self.enableCheatCode);

        // === ADVANCED EMULATION SETTINGS ===

    // VI Overclock (frequency override)
    if (self.enableVBIOverride) {
        // Map percentage (4–501%) to factor for MAIN_VI_OVERCLOCK
        float factor = self.vbiFrequencyRange / 100.0f;
        if (factor < 0.04f) factor = 0.04f;
        if (factor > 5.01f) factor = 5.01f;
        Config::SetBase(Config::MAIN_VI_OVERCLOCK_ENABLE, true);
        Config::SetBase(Config::MAIN_VI_OVERCLOCK, factor);
    } else {
        Config::SetBase(Config::MAIN_VI_OVERCLOCK_ENABLE, false);
        Config::SetBase(Config::MAIN_VI_OVERCLOCK, 1.0f);
    }

    // Memory Management Unit
    Config::SetBase(Config::MAIN_MMU, self.enableMMU);

    // Pause on Panic
    Config::SetBase(Config::MAIN_AUTO_DISC_CHANGE, !self.pauseOnPanic);

    // Write-Back Cache
    Config::SetBase(Config::MAIN_ACCURATE_NANS, self.enableWriteBackCache);

    // Speed Limit
    if (self.speedLimit == 0) {
        Config::SetBase(Config::MAIN_EMULATION_SPEED, 0.0f); // Unlimited
    } else {
        float speedMultiplier = self.speedLimit / 100.0f;
        Config::SetBase(Config::MAIN_EMULATION_SPEED, speedMultiplier);
    }

    // Fallback Region
    Config::SetBase(Config::MAIN_FALLBACK_REGION, (DiscIO::Region)self.fallbackRegion);

    // === AUDIO SETTINGS ===

    // Audio Backend
    if (self.audioBackend == 0) {
        Config::SetBase(Config::MAIN_AUDIO_BACKEND, std::string("Cubeb"));
    } else if (self.audioBackend == 1) {
        Config::SetBase(Config::MAIN_AUDIO_BACKEND, std::string("OpenAL"));
    } else if (self.audioBackend == 2) {
        Config::SetBase(Config::MAIN_AUDIO_BACKEND, std::string("Null"));
    }

    // Audio stretching setting removed in modern Dolphin; do not set MAIN_AUDIO_STRETCH

    // Volume (handled by the audio system)
    Config::SetBase(Config::MAIN_AUDIO_VOLUME, self.volume);

    // === SYSTEM SETTINGS ===

    // Skip GameCube IPL/BIOS
    Config::SetBase(Config::MAIN_SKIP_IPL, self.skipIPL);

    // Wii Language
    Config::SetBase(Config::SYSCONF_LANGUAGE, self.wiiLanguage);

    // === SYSTEM CONFIGURATION ===

    // SDCard (always enabled for compatibility)
    Config::SetBase(Config::MAIN_WII_SD_CARD, true);
    Config::SetBase(Config::MAIN_ALLOW_SD_WRITES, true);

    // Disc speed emulation disabled for faster loading
    Config::SetBase(Config::MAIN_FAST_DISC_SPEED, true);

    // CPU High Level / Low Level Emulation
    Config::SetBase(Config::MAIN_DSP_HLE, true);
    Config::SetBase(Config::MAIN_DSP_THREAD, true);
    Core::SetIsThrottlerTempDisabled(false);

    // === DEBUG AND LOGGING ===

    // Debug Settings
    Config::SetBase(Config::MAIN_ENABLE_DEBUGGING, self.enableLogging);

    // OSD Messages (logging configuration is handled in setupEmulation)
    Config::SetBase(Config::MAIN_OSD_MESSAGES, self.enableLogging);

    // === iOS OPTIMIZATIONS ===

    // iOS Power Management
    Config::SetBase(Config::MAIN_ANALYTICS_ENABLED, false); // Disable analytics for privacy/performance

    // Wiimote settings optimized for iOS
    // Note: SYSCONF_WIIMOTE_MOTOR is configured in setupHapticFeedback based on device capability and user preference
    Config::SetBase(Config::MAIN_WII_KEYBOARD, false);
    Config::SetBase(Config::MAIN_WIIMOTE_CONTINUOUS_SCANNING, false);
    Config::SetBase(Config::MAIN_BLUETOOTH_PASSTHROUGH_ENABLED, false);

    // Social features disabled
    Discord::SetDiscordPresenceEnabled(false);

    // Alerts disabled for iOS
    Common::SetEnableAlert(false);
}

#pragma mark - Running
- (void)setupEmulation {
    // CRITICAL: Reset all static/global state to prevent iOS dynamic library issues
    ResetDolphinStaticState();

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

    // CRITICAL: Shutdown UICommon first to prevent deadlock on second load
    // UICommon::Init() has static state that must be cleaned up between sessions
    try {
        UICommon::Shutdown();
        NSLog(@"🐬 [SETUP] UICommon shutdown completed");
    } catch (...) {
        NSLog(@"🐬 [SETUP] UICommon shutdown failed or was not initialized - continuing");
    }

    UICommon::Init();
    NSLog(@"🐬 [SETUP] UICommon initialized, User Directory set to '%s'", user_dir.c_str());

    // Initialize logging system EARLY - before any other configuration
    Common::Log::LogManager::Init();

    // Apply critical settings immediately after Dolphin initialization
    // This ensures BIOS skip is set before any game loading attempts
    [self parseOptions];  // Parse options FIRST to get current enableLogging value
    Config::Load();

    // Configure logging to output to iOS console AFTER parsing options
    if (self.enableLogging) {
        NSLog(@"🐬 Dolphin Debug Logging ENABLED (user setting: %s)", self.enableLogging ? "true" : "false");
        Common::Log::LogManager::GetInstance()->SetLogLevel(Common::Log::LogLevel::LINFO);
        Common::Log::LogManager::GetInstance()->SetEnable(Common::Log::LogType::OSREPORT, true);
        Common::Log::LogManager::GetInstance()->SetEnable(Common::Log::LogType::CORE, true);
        Common::Log::LogManager::GetInstance()->SetEnable(Common::Log::LogType::BOOT, true);
        Common::Log::LogManager::GetInstance()->SetEnable(Common::Log::LogType::VIDEO, true);
        Common::Log::LogManager::GetInstance()->SetEnable(Common::Log::LogType::AUDIO, true);
        // Enable console listener for iOS output
        Common::Log::LogManager::GetInstance()->EnableListener(Common::Log::LogListener::CONSOLE_LISTENER, true);
    } else {
        NSLog(@"🐬 Dolphin Debug Logging DISABLED (user setting: %s)", self.enableLogging ? "true" : "false");
        Common::Log::LogManager::GetInstance()->SetLogLevel(Common::Log::LogLevel::LERROR);
        Common::Log::LogManager::GetInstance()->EnableListener(Common::Log::LogListener::CONSOLE_LISTENER, false);
    }

    // CRITICAL: Skip GameCube BIOS - must be set early to prevent BIOS loading errors
    Config::SetBase(Config::MAIN_SKIP_IPL, self.skipIPL);
    NSLog(@"GameCube BIOS skip set to: %s", self.skipIPL ? "true" : "false");
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
    NSLog(@"🐬 [DEBUG] startDolphin: Beginning Dolphin initialization");
    std::unique_lock<std::mutex> guard(s_host_identity_lock);
    __block WindowSystemInfo wsi;
    wsi.type = WindowSystemType::iOS;
    wsi.display_connection = nullptr;
    dispatch_sync(dispatch_get_main_queue(), ^{
        // Use Provenance's Metal view layer as the render surface
        if (self.renderDelegate && self.renderDelegate.mtlView) {
            wsi.render_surface = (__bridge void*)self.renderDelegate.mtlView.layer;
            NSLog(@"🐬 [DEBUG] Using Metal view layer for rendering");
        } else {
            wsi.render_surface = (__bridge void*)m_view.layer;
            NSLog(@"🐬 [WARNING] Fallback to regular view layer - may not render properly");
        }
    });
    wsi.render_surface_scale = [UIScreen mainScreen].scale;
    NSLog(@"🐬 [DEBUG] WindowSystemInfo configured for iOS");

    VideoBackendBase::ActivateBackend(Config::Get(Config::MAIN_GFX_BACKEND));
    NSLog(@"🐬 [DEBUG] Using GFX backend: %s", Config::Get(Config::MAIN_GFX_BACKEND).c_str());

    // Initialize ControllerInterface for iOS input backend
    g_controller_interface.Initialize(wsi);
    NSLog(@"🐬 [DEBUG] ControllerInterface initialized for iOS input backend");

    std::string gamePath=std::string([_romPath UTF8String]);
    std::vector<std::string> normalized_game_paths;
    normalized_game_paths.push_back(gamePath);
    NSLog(@"🐬 [DEBUG] Game path: %s", gamePath.c_str());

    [self setupControllers];
    NSLog(@"🐬 [DEBUG] Controllers setup complete");

    NSLog(@"🐬 [DEBUG] Attempting to boot game...");
    if (!BootManager::BootCore(Core::System::GetInstance(), BootParameters::GenerateFromFile(normalized_game_paths), wsi))
    {
        NSLog(@"🐬 [ERROR] Could not boot %s", [_romPath UTF8String]);
        return;
    }
    NSLog(@"🐬 [DEBUG] BootCore succeeded, setting up audio...");

    AudioCommon::SetSoundStreamRunning(Core::System::GetInstance(), true);
    NSLog(@"🐬 [DEBUG] Audio stream started, waiting for core to start...");

    while (Core::GetState(Core::System::GetInstance()) == Core::State::Starting && !Core::IsRunning(Core::System::GetInstance()))
    {
        NSLog(@"🐬 [DEBUG] Core state: Starting, waiting...");
        Common::SleepCurrentThread(100);
    }
    _isInitialized = true;
    _isOff = false;
    NSLog(@"🐬 [SUCCESS] VM Started! Core state: %d, IsRunning: %s",
          (int)Core::GetState(Core::System::GetInstance()),
          Core::IsRunning(Core::System::GetInstance()) ? "YES" : "NO");

    NSLog(@"🐬 [DEBUG] Entering main emulation loop...");
    int loopCount = 0;
    bool guardLocked = true; // Track guard state

    while (_isInitialized)
    {
        if (guardLocked) {
            guard.unlock();
            guardLocked = false;
        }

        // Log every 60 iterations (roughly once per second at 60 FPS)
        #ifdef DEBUG
        if (loopCount % 60 == 0) {
            NSLog(@"🐬 [DEBUG] Emulation loop iteration %d, Core state: %d, IsRunning: %s",
                  loopCount,
                  (int)Core::GetState(Core::System::GetInstance()),
                  Core::IsRunning(Core::System::GetInstance()) ? "YES" : "NO");
        }
        loopCount++;
        #endif

        // Wait for events with timeout to prevent indefinite blocking
        if (s_update_main_frame_event.WaitFor(std::chrono::milliseconds(16))) {
            // Event received, process jobs
            if (!guardLocked) {
                guard.lock();
                guardLocked = true;
            }
            Core::HostDispatchJobs(Core::System::GetInstance());
        } else {
            // Timeout - continue emulation loop anyway
            if (!guardLocked) {
                guard.lock();
                guardLocked = true;
            }
            Core::HostDispatchJobs(Core::System::GetInstance());

            // Manually trigger frame update if emulation is running
            if (Core::IsRunning(Core::System::GetInstance())) {
                // Signal the event to keep the loop active
                s_update_main_frame_event.Set();
            }
        }
    }

    // CRITICAL: Ensure guard is unlocked before method exits
    if (guardLocked) {
        guard.unlock();
        guardLocked = false;
        NSLog(@"🐬 [DEBUG] Guard unlocked before startDolphin method exit");
    }

    _isOff=true;
}

- (void)startEmulation {
    self.skipEmulationLoop = true;  // Dolphin handles its own emulation loop
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

    // Stop motion updates to save battery
    [self stopMotionUpdates];

    self.shouldStop = YES;
    _isInitialized = false;
    g_controller_interface.Shutdown();
    Core::SetState(Core::System::GetInstance(), Core::State::Running);
    Core::System::GetInstance().GetProcessorInterface().PowerButton_Tap();
    Core::Stop(Core::System::GetInstance());
    s_update_main_frame_event.Set();
    while (Core::System::GetInstance().GetCPU().GetState() != CPU::State::PowerDown ||
           Core::GetState(Core::System::GetInstance()) != Core::State::Uninitialized ||
           _isInitialized) {
        Common::SleepCurrentThread(20);
    }
    Core::System::GetInstance().GetMemory().ShutdownFastmemArena();
    Core::System::GetInstance().GetMemory().Shutdown();
    Core::System::GetInstance().GetPowerPC().Shutdown();
    g_video_backend->Shutdown();

    // CRITICAL: Ensure host identity lock is unlocked before cleanup
    try {
        s_host_identity_lock.unlock();
        NSLog(@"🐬 [STOP] Host identity lock unlocked during stopEmulation");
    } catch (...) {
        NSLog(@"🐬 [STOP] Host identity lock was already unlocked or exception occurred");
    }

    [m_view removeFromSuperview];
    [m_view_controller dismissViewControllerAnimated:NO completion:nil];
    m_gl_layer = nullptr;
    m_metal_layer = nullptr;
    m_view_controller = nullptr;
    m_view=nullptr;
    AudioCommon::ShutdownSoundStream(Core::System::GetInstance());

    // CRITICAL: Shutdown UICommon before resetting state
    try {
        UICommon::Shutdown();
        NSLog(@"🐬 [STOP] UICommon shutdown completed in stopEmulation");
    } catch (...) {
        NSLog(@"🐬 [STOP] UICommon shutdown failed in stopEmulation - continuing");
    }

    // Reset all static/global state for next load
    ResetDolphinStaticState();
}
/// Haptic feedback is now handled automatically by Dolphin's Motor output system
/// See setupHapticFeedback method in Controls for implementation

/// JIT availability detection
/// Based on DolphiniOS's JitManager logic - JIT is available when process is debugged
/// or on simulator, which allows dynamic code execution
-(BOOL)checkJITAvailable {
#if TARGET_OS_SIMULATOR
    // JIT is always available on iOS Simulator
    return YES;
#else
    // Check if process is being debugged, which enables JIT
    // This covers AltStore, SideStore, Xcode debugging, etc.
    return [self isProcessDebugged];
#endif
}

/// Check if the current process is being debugged
/// This is the primary way JIT becomes available on iOS devices
-(BOOL)isProcessDebugged {
    int junk;
    int mib[4];
    struct kinfo_proc info;
    size_t size;

    info.kp_proc.p_flag = 0;

    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();

    size = sizeof(info);
    junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
    assert(junk == 0);

    // Check if P_TRACED flag is set, indicating the process is being debugged
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

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
        } else if(self.gsPreference == 2) {
            // Metal backend - reuse Vulkan view controller since both use CAMetalLayer
            DolphinVulkanViewController *cgsh_view_controller=[[DolphinVulkanViewController alloc]
                                                               initWithResFactor:self.resFactor
                                                               videoWidth: self.videoWidth
                                                               videoHeight: self.videoHeight
                                                               core: self];
            m_metal_layer=(CAMetalLayer *)cgsh_view_controller.view.layer;
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
        } else if(self.gsPreference == 2) {
            // Metal backend - reuse Vulkan view controller since both use CAMetalLayer
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
    if (id == HostMessageID::WMUserJobDispatch) {
        // Use async dispatch like original Dolphin iOS
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            Core::HostDispatchJobs(Core::System::GetInstance());
        });
        // Also signal the event for our existing loop (for compatibility)
        s_update_main_frame_event.Set();
    } else if (id == HostMessageID::WMUserStop) {
        s_have_wm_user_stop = true;
        if (Core::IsRunning(Core::System::GetInstance()))
            Core::QueueHostJob([](Core::System& system) { Core::Stop(system); });
    } else if (id == HostMessageID::WMUserCreate) {
        NSLog(@"User Create Called %i\n", (int)id);
    }
}

void Host_UpdateTitle(const std::string &title) {
  NSLog(@"Update Title called: %s\n", title.c_str());
}

void Host_UpdateDisasmDialog() {
  NSLog(@"Update Disasm Dialog called\n");
}

void Host_UpdateMainFrame() {
  NSLog(@"UpdateMainFrame called\n");
}

void Host_RequestRenderWindowSize(int width, int height) {
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
	return true;
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
