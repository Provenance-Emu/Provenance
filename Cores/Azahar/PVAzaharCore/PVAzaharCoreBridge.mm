#import "PVAzaharCoreBridge.h"
#import "PVAzaharCoreBridge+Private.h"
#import "PVAzaharCoreBridge+Video.h"
#import <PVAzahar/PVAzahar-Swift.h>
#import <PVLogging/PVLoggingObjC.h>
@import PVCoreBridge;  // defines the protocols the public header only forward-declares
#include <chrono>
#include <pthread.h>
#include "Glue/AzaharEmuWindow.h"
#include "Glue/AzaharInput.h"
#include "common/file_util.h"
#include "common/logging/backend.h"
#include "common/logging/filter.h"
#include "common/settings.h"
#include "core/core.h"
#include "core/frontend/applets/default_applets.h"
#include "network/network.h"
#include "audio_core/sink_details.h"

/// PVJIT exports this via @_cdecl; weak so a build without PVJIT reads "no JIT" instead of failing to link.
extern "C" bool PVJITManagerIsAcquired(void) __attribute__((weak));

static NSString * const PVAzaharUserDirectoryName = @"Azahar";

/// UI index (Default, Single, Large, Side by Side, Hybrid) -> azahar layout. SeparateWindows is skipped.
static Settings::LayoutOption PVAzaharLayoutOption(NSInteger index) {
    switch (index) {
    case 1: return Settings::LayoutOption::SingleScreen;
    case 2: return Settings::LayoutOption::LargeScreen;
    case 3: return Settings::LayoutOption::SideScreen;
    case 4: return Settings::LayoutOption::HybridScreen;
    default: return Settings::LayoutOption::Default;
    }
}

@implementation PVAzaharCoreBridge

- (instancetype)init {
    if ((self = [super init])) {
        _running = false; _paused = false; _loaded = false;
        self.skipEmulationLoop = YES;   // azahar runs its own loop (see startEmulation)
        self.skipLayout = YES;          // we draw into our own view (Dolphin pattern)
        self.resolutionFactor = 1; self.cpuClockPercent = 100; self.new3DSMode = YES;
        self.hardwareShader = YES; self.accurateMultiplication = YES; self.asyncShaderCompilation = YES;
        self.asyncPresentation = YES; self.diskShaderCache = YES; self.audioStretching = YES;
        self.realtimeAudio = YES; self.frameLimitPercent = 100; self.regionValue = -1;
    }
    return self;
}

- (void)dealloc {
    // The emu thread's lambda holds the last strong reference only if the host dropped the bridge
    // without stopping it; that release runs on the emu thread itself, which cannot join itself.
    if (_emuThread.joinable()) { _emuThread.detach(); }
}

- (NSString *)userDirectoryPath {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [docs stringByAppendingPathComponent:PVAzaharUserDirectoryName];
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error {
    NSString *userDir = [self userDirectoryPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:userDir withIntermediateDirectories:YES attributes:nil error:nil];
    FileUtil::SetUserPath(std::string([userDir fileSystemRepresentation]) + "/");

    static std::once_flag logOnce;
    std::call_once(logOnce, [] {
        Common::Log::Initialize();           // console backend -> stderr -> Console.app
        Common::Log::SetColorConsoleBackendEnabled(false);
        Common::Log::Start();
        Common::Log::Filter filter;
        filter.ParseFilterString("*:Info");
        Common::Log::SetGlobalFilter(filter);
    });

    _romPath = [path copy];
    _loaded = false;
    return YES;            // Load happens on the emu thread in startEmulation (needs the layer)
}

- (void)applySettingsFromOptions {
    auto& v = Settings::values;
    const bool jit = PVJITManagerIsAcquired != nullptr && PVJITManagerIsAcquired();
    v.use_cpu_jit.SetValue(jit);
    v.use_fastinterp.SetValue(!jit);
    v.graphics_api.SetValue(Settings::GraphicsAPI::Vulkan);
    v.physical_device.SetValue(0);
    v.resolution_factor.SetValue(static_cast<u32>(MAX(1, self.resolutionFactor)));
    v.layout_option.SetValue(PVAzaharLayoutOption(self.layoutOption));
    v.swap_screen.SetValue(self.swapScreens);
    v.is_new_3ds.SetValue(self.new3DSMode);
    v.cpu_clock_percentage.SetValue(static_cast<s32>(self.cpuClockPercent));
    v.use_hw_shader.SetValue(self.hardwareShader);
    v.shaders_accurate_mul.SetValue(self.accurateMultiplication);
    v.async_shader_compilation.SetValue(self.asyncShaderCompilation);
    v.async_presentation.SetValue(self.asyncPresentation);
    v.use_disk_shader_cache.SetValue(self.diskShaderCache);
    v.texture_filter.SetValue(static_cast<Settings::TextureFilter>(self.textureFilter));
    v.enable_audio_stretching.SetValue(self.audioStretching);
    v.enable_realtime_audio.SetValue(self.realtimeAudio);
    v.region_value.SetValue(static_cast<s32>(self.regionValue));
    v.frame_limit.SetValue(static_cast<double>(self.frameLimitPercent));
    v.render_3d.SetValue(Settings::StereoRenderOption::Off);
    v.factor_3d.SetValue(0);
    v.output_type.SetValue(AudioCore::SinkType::CoreAudio);
    v.use_display_refresh_rate_detection.SetValue(true);
    v.camera_name[0] = v.camera_name[1] = v.camera_name[2] = "blank";   // Task 8 overrides on iOS
    AzaharInput::ApplyProfile();
    ILOG(@"[PVAzahar] settings applied: jit=%d fastinterp=%d res=%ld layout=%ld", jit, !jit,
         (long)self.resolutionFactor, (long)self.layoutOption);
}

- (void)startEmulation {
    [self applySettingsFromOptions];
    [self setupRenderView];          // +Video, main thread; creates _window
    if (!_window) {
        ELOG(@"[PVAzahar] no render window; cannot start");
        return;
    }
    _running = true; _paused = false;
    std::string romPath([_romPath fileSystemRepresentation]);
    __weak PVAzaharCoreBridge *weakSelf = self;
    // The thread keeps `self` alive until it exits; stopEmulationWithMessage: joins it.
    _emuThread = std::thread([self, weakSelf, romPath] {
        pthread_setname_np("Azahar Emulation");
        auto& system = Core::System::GetInstance();
        AzaharInput::RegisterFactories();
        Frontend::RegisterDefaultApplets(system);
        Network::Init();
        system.ApplySettings();
        const auto result = system.Load(*_window, romPath);
        if (result == Core::System::ResultStatus::Success) {
            _loaded = true;
            bool guestShutdown = false;
            while (_running) {
                {
                    std::unique_lock lock(_jobMutex);
                    while (!_jobs.empty()) {
                        auto job = std::move(_jobs.front());
                        _jobs.pop_front();
                        lock.unlock();
                        job();
                        lock.lock();
                    }
                    if (_paused && _running) {
                        _jobCV.wait_for(lock, std::chrono::milliseconds(16));
                        continue;
                    }
                }
                const auto status = system.RunLoop();   // no bridge lock held here
                if (status == Core::System::ResultStatus::ShutdownRequested) {
                    guestShutdown = _running;   // false: we asked for it in stopEmulationWithMessage:
                    break;
                }
                if (status != Core::System::ResultStatus::Success) {
                    WLOG(@"[PVAzahar] RunLoop status %d", static_cast<int>(status));
                }
            }
            system.Shutdown();
            _loaded = false;
            if (guestShutdown) {
                _running = false;
                dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf stopEmulationWithMessage:nil]; });
            }
        } else {
            WLOG(@"[PVAzahar] Core::System::Load failed: %d", static_cast<int>(result));
            _running = false;
            const int code = static_cast<int>(result);
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf stopEmulationWithMessage:[NSString stringWithFormat:@"Azahar could not load this title (%d)", code]];
            });
        }
        Network::Shutdown();
        AzaharInput::UnregisterFactories();
    });
    [super startEmulation];
}

- (void)setPauseEmulation:(BOOL)flag {
    _paused = flag;          // atomic; the emu loop sees it after the current RunLoop slice
    _jobCV.notify_all();
    [super setPauseEmulation:flag];
}

/// The base `stopEmulation` calls this, and so do the load-failure and guest-shutdown paths, so all
/// teardown lives here. Main thread. Idempotent.
- (void)stopEmulationWithMessage:(NSString *)message {
    _running = false; _paused = false;
    if (_loaded) { Core::System::GetInstance().RequestShutdown(); }   // thread-safe signal
    _jobCV.notify_all();
    if (_emuThread.joinable()) {
        if (_emuThread.get_id() == std::this_thread::get_id()) {
            _emuThread.detach();   // never expected; joining ourselves would throw
        } else {
            _emuThread.join();
        }
    }
    {
        std::lock_guard lock(_jobMutex);
        _jobs.clear();   // queued jobs capture self; drop them now the loop is gone
    }
    [self teardownRenderView];
    _window.reset();
    [super stopEmulationWithMessage:message];
}

- (void)resetEmulation {
    [self runOnEmuThread:[] { Core::System::GetInstance().Reset(); }];
}

- (void)executeFrame {}   // own loop

- (void)runOnEmuThread:(std::function<void()>)job {
    { std::lock_guard lock(_jobMutex); _jobs.push_back(std::move(job)); }
    _jobCV.notify_all();
}

- (BOOL)runOnEmuThreadAndWait:(std::function<void()>)job timeout:(NSTimeInterval)seconds {
    if (!_running) { return NO; }
    if (_emuThread.get_id() == std::this_thread::get_id()) { job(); return YES; }   // already there
    auto done = std::make_shared<std::atomic<bool>>(false);
    [self runOnEmuThread:[job = std::move(job), done] { job(); done->store(true); }];
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::duration<double>(seconds);
    while (!done->load()) {
        if (std::chrono::steady_clock::now() > deadline) { return NO; }
        std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
    return YES;
}

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error { return NO; } // Task 8

@end
