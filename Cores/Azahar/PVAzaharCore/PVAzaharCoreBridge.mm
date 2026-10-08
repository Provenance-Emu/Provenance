#import "PVAzaharCoreBridge.h"
#import "PVAzaharCoreBridge+Private.h"
#import "PVAzaharCoreBridge+Video.h"
#import <PVAzahar/PVAzahar-Swift.h>
#import <PVLogging/PVLoggingObjC.h>
@import PVCoreBridge;  // defines the protocols the public header only forward-declares
#include <chrono>
#include <csetjmp>
#include <csignal>
#include <cstring>
#include <dlfcn.h>
#include <libkern/OSCacheControl.h>
#include <pthread.h>
#include <sys/mman.h>
#include "Glue/AzaharCamera.h"
#include "Glue/AzaharEmuWindow.h"
#include "Glue/AzaharInput.h"
#include "common/file_util.h"
#include "common/logging/backend.h"
#include "common/logging/filter.h"
#include "common/settings.h"
#include "core/hle/service/service.h"
#include "core/core.h"
#include "core/frontend/applets/default_applets.h"
#include "core/hle/service/cam/cam.h"
#include "network.h"   // azahar's network/network.h; see HEADER_SEARCH_PATHS in project.yml
#include "audio_core/sink_details.h"


namespace {
/// Shared by runOnEmuThreadAndWait: and its job. `finished` is set when the job is destroyed,
/// whether it ran or was dropped at stop, so a waiter never sleeps out the timeout for nothing.
struct PVAzaharWaitState {
    std::mutex m;
    std::condition_variable cv;
    bool ran = false;
    bool finished = false;
};
struct PVAzaharJobCompletion {
    explicit PVAzaharJobCompletion(std::shared_ptr<PVAzaharWaitState> s) : state(std::move(s)) {}
    PVAzaharJobCompletion(const PVAzaharJobCompletion&) = delete;
    PVAzaharJobCompletion& operator=(const PVAzaharJobCompletion&) = delete;
    ~PVAzaharJobCompletion() {
        { std::lock_guard lock(state->m); state->finished = true; }
        state->cv.notify_all();
    }
    const std::shared_ptr<PVAzaharWaitState> state;
};

#if !TARGET_OS_SIMULATOR
volatile sig_atomic_t s_jitProbeSignal = 0;
sigjmp_buf s_jitProbeJump;
void PVAzaharJITProbeSignalHandler(int sig) {
    s_jitProbeSignal = sig;
    siglongjmp(s_jitProbeJump, 1);
}
#endif
} // namespace

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

// Residual -Wprotocol on this @implementation is inherited from ObjCBridgedCoreBridge, not from this core:
// EmulatorCoreSavesSerializer's misspelled loadStateToFileAtPath:error: and EmulatorCoreControllerDataSource's
// controllerN properties are satisfied (or not) by the PVCoreObjCBridge base. Controls, viewport positioning
// and save states are declared on their own categories, so a missing method there still warns.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
@implementation PVAzaharCoreBridge

- (instancetype)init {
    if ((self = [super init])) {
        _running = false; _paused = false; _loaded = false; _stopRequested = false;
        _emuThreadExited = true; _stopping = false;
        self.skipEmulationLoop = YES;   // azahar runs its own loop (see startEmulation)
        self.skipLayout = YES;          // we draw into our own view (Dolphin pattern)
        self.resolutionFactor = 1; self.cpuClockPercent = 100; self.new3DSMode = NO;
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
    return PVAzaharCore.userRootURL.path;   // Documents/Azahar on iOS, Caches/Azahar on tvOS
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error {
    NSString *userDir = [self userDirectoryPath];
    NSError *dirError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:userDir withIntermediateDirectories:YES attributes:nil error:&dirError]) {
        ELOG(@"[PVAzahar] could not create user directory %@: %@", userDir, dirError);
    }
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
    const bool jit = [self probeJITAvailable];
    _jitActive = jit;
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
    // Service::Init does `lle_modules.at(name)` for every HLE module; azahar's frontends
    // populate this map from their config. Default every module to HLE (false).
    for (const auto& module : Service::service_module_map) {
        v.lle_modules.emplace(module.name, false);
    }
#if TARGET_OS_TV
    v.camera_name[0] = v.camera_name[1] = v.camera_name[2] = "blank";
#else
    // Indexed by Service::CAM::CameraIndex: OuterRightCamera, InnerCamera, OuterLeftCamera.
    v.camera_name[Service::CAM::OuterRightCamera] = AzaharCamera::kRearRightCamera;
    v.camera_name[Service::CAM::InnerCamera] = AzaharCamera::kFrontCamera;
    v.camera_name[Service::CAM::OuterLeftCamera] = AzaharCamera::kRearLeftCamera;
#endif
    AzaharInput::ApplyProfile();
    ILOG(@"[PVAzahar] settings applied: jit=%d fastinterp=%d res=%ld layout=%ld", jit, !jit,
         (long)self.resolutionFactor, (long)self.layoutOption);
}

/// Port of -[PVDolphinCoreBridge checkJITAvailable]: allocate a MAP_JIT page, write
/// `mov w0,#1; ret`, make it RX and call it with SIGTRAP/SIGBUS/SIGSEGV/SIGILL trapped. This sees what the
/// process can really do (debugger, StikJIT, entitlements, TXM) rather than a flag that may not be set.
- (BOOL)probeJITAvailable {
#if TARGET_OS_SIMULATOR
    return YES;
#else
    const size_t pageSize = static_cast<size_t>(getpagesize());
    void *page = mmap(nullptr, pageSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_JIT, -1, 0);
    if (page == MAP_FAILED) {
        ILOG(@"[PVAzahar] JIT probe: MAP_JIT allocation failed");
        return NO;
    }
    const uint32_t code[] = { 0x52800020 /* mov w0, #1 */, 0xD65F03C0 /* ret */ };
    // pthread_jit_write_protect_np is missing from the iOS 26 / tvOS SDKs; look it up at runtime.
    typedef void (*PVJITWriteProtect)(int);
    const auto writeProtect = reinterpret_cast<PVJITWriteProtect>(dlsym(RTLD_DEFAULT, "pthread_jit_write_protect_np"));
    if (writeProtect) { writeProtect(0); }
    memcpy(page, code, sizeof(code));
    if (writeProtect) { writeProtect(1); }
    if (mprotect(page, pageSize, PROT_READ | PROT_EXEC) != 0) {
        ILOG(@"[PVAzahar] JIT probe: mprotect RX failed");
        munmap(page, pageSize);
        return NO;
    }
    sys_icache_invalidate(page, sizeof(code));

    struct sigaction handler = {}, oldTrap, oldBus, oldSegv, oldIll;
    sigemptyset(&handler.sa_mask);
    handler.sa_handler = PVAzaharJITProbeSignalHandler;
    sigaction(SIGTRAP, &handler, &oldTrap);
    sigaction(SIGBUS, &handler, &oldBus);
    sigaction(SIGSEGV, &handler, &oldSegv);
    sigaction(SIGILL, &handler, &oldIll);
    s_jitProbeSignal = 0;
    BOOL works = NO;
    if (sigsetjmp(s_jitProbeJump, 1) == 0) {
        works = reinterpret_cast<int (*)(void)>(page)() == 1;
    } else {
        WLOG(@"[PVAzahar] JIT probe: execution raised signal %d", static_cast<int>(s_jitProbeSignal));
    }
    sigaction(SIGTRAP, &oldTrap, nullptr);
    sigaction(SIGBUS, &oldBus, nullptr);
    sigaction(SIGSEGV, &oldSegv, nullptr);
    sigaction(SIGILL, &oldIll, nullptr);
    munmap(page, pageSize);
    ILOG(@"[PVAzahar] JIT probe: %@", works ? @"available" : @"unavailable");
    return works;
#endif
}

- (BOOL)startsEmulationAsynchronously { return YES; }

/// Main thread. Hands the boot outcome to the Swift core exactly once.
- (void)finishBootWithFailure:(NSString *)message {
    dispatch_assert_queue(dispatch_get_main_queue());
    if (_stopRequested) { return; }   // torn down (or tearing down) while the boot result was in flight
    void (^started)(void) = self.onEmulationStarted;
    void (^failed)(NSString *) = self.onEmulationFailed;
    self.onEmulationStarted = nil;
    self.onEmulationFailed = nil;
    if (message) {
        if (failed) { failed(message); }
    } else if (started) {
        started();
    }
}

- (void)startEmulation {
    if (_running || _emuThread.joinable()) {
        WLOG(@"[PVAzahar] startEmulation called while the emu thread exists; ignoring");
        return;
    }
    [self applySettingsFromOptions];
    [self configureAudioSession];
    [self setupRenderView];          // +Video, main thread; creates _window
    if (!_window) {
        ELOG(@"[PVAzahar] no render window; cannot start");
        [self finishBootWithFailure:@"Azahar could not create its render view"];
        return;
    }
    _running = true; _paused = false; _stopRequested = false; _emuThreadExited = false;
    std::string romPath([_romPath fileSystemRepresentation]);
    __weak PVAzaharCoreBridge *weakSelf = self;
    // The thread keeps `self` alive until it exits; stopEmulationWithMessage: joins it.
    _emuThread = std::thread([self, weakSelf, romPath] {
        pthread_setname_np("Azahar Emulation");
        _emuThreadId = std::this_thread::get_id();
        auto& system = Core::System::GetInstance();
        AzaharInput::RegisterFactories();
        AzaharCamera::RegisterFactories();
        Frontend::RegisterDefaultApplets(system);
        Network::Init();
        system.ApplySettings();
        const auto result = system.Load(*_window, romPath);
        if (result == Core::System::ResultStatus::Success) {
            _loaded = true;
            if (!_stopRequested) {
                dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf finishBootWithFailure:nil]; });
            }
            bool guestShutdown = false;
            // A stop that arrived during Load (before _loaded was set) could not RequestShutdown;
            // _stopRequested makes us leave without entering the loop.
            while (_running && !_stopRequested) {
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
                NSString *message = [NSString stringWithFormat:@"Azahar could not load this title (%d)", code];
                PVAzaharCoreBridge *strongSelf = weakSelf;
                if (!strongSelf || strongSelf->_stopRequested) { return; }   // host already stopped us
                // stopEmulationWithMessage: clears the boot blocks, so take the failure block first.
                // nil message: the host presents `failed`'s error; the base would show a second alert.
                void (^failed)(NSString *) = strongSelf.onEmulationFailed;
                [strongSelf stopEmulationWithMessage:nil];
                if (failed) { failed(message); }
            });
        }
        Network::Shutdown();
        AzaharInput::UnregisterFactories();
        {
            std::lock_guard lock(_jobMutex);
            _jobs.clear();   // nothing will run them now; releases any runOnEmuThreadAndWait: waiter
        }
        _emuThreadId = std::thread::id();
        _emuThreadExited = true;   // after this the thread touches nothing of ours; stop may join
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
    // The wait below pumps the main run loop, which can deliver a queued guest-shutdown stop.
    if (_stopping.exchange(true)) {
        ILOG(@"[PVAzahar] stop already in progress; ignoring re-entrant stop");
        return;
    }
    _stopRequested = true;
    _running = false; _paused = false;
    self.onEmulationStarted = nil;     // a boot result still queued for main must not reach the host
    self.onEmulationFailed = nil;
    if (_loaded) { Core::System::GetInstance().RequestShutdown(); }   // thread-safe signal
    _jobCV.notify_all();
    if (_emuThread.joinable()) {
        if (_emuThread.get_id() == std::this_thread::get_id()) {
            _emuThread.detach();   // never expected; joining ourselves would throw
        } else {
            // Kept unbounded on purpose: a half-torn-down Core::System is worse than a wait. On main, the
            // run loop keeps turning while we wait: MoltenVK dispatch_syncs to main for surface/swapchain
            // work, so a quit during Load or a resize would otherwise deadlock. (A stop issued from inside a
            // main-queue block cannot drain the main queue this way; GCD does not re-enter it.)
            ILOG(@"[PVAzahar] joining emu thread");
            if ([NSThread isMainThread]) {
                while (!_emuThreadExited) { CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true); }
            }
            _emuThread.join();
            ILOG(@"[PVAzahar] joined emu thread");
        }
    }
    {
        std::lock_guard lock(_jobMutex);
        _jobs.clear();   // queued jobs capture self; drop them now the loop is gone
    }
    [self teardownRenderView];   // hops to main itself when called off-main (e.g. from dealloc)
    _window.reset();
    [super stopEmulationWithMessage:message];
    _stopping = false;
}

- (void)resetEmulation {
    if (_loaded) { Core::System::GetInstance().RequestReset(); }   // signal; the loop resets itself
}

- (void)executeFrame {}   // own loop

- (void)runOnEmuThread:(std::function<void()>)job {
    if (!_running) {
        static std::once_flag dropLogOnce;
        std::call_once(dropLogOnce, [] { WLOG(@"[PVAzahar] emu job dropped: emulation is not running"); });
        return;
    }
    { std::lock_guard lock(_jobMutex); _jobs.push_back(std::move(job)); }
    _jobCV.notify_all();
}

- (BOOL)runOnEmuThreadAndWait:(std::function<void()>)job timeout:(NSTimeInterval)seconds {
    if (!_running) { return NO; }
    if (_emuThreadId.load() == std::this_thread::get_id()) { job(); return YES; }   // already there
    auto state = std::make_shared<PVAzaharWaitState>();
    auto completion = std::make_shared<PVAzaharJobCompletion>(state);
    [self runOnEmuThread:[job = std::move(job), state, completion] {
        job();
        std::lock_guard lock(state->m);
        state->ran = true;
    }];
    completion.reset();   // only the queued job holds it now; its destruction marks `finished`
    const auto deadline = std::chrono::steady_clock::now()
        + std::chrono::duration_cast<std::chrono::steady_clock::duration>(std::chrono::duration<double>(seconds));
    std::unique_lock lock(state->m);
    state->cv.wait_until(lock, deadline, [&state] { return state->finished; });
    return state->ran ? YES : NO;
}

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error {
    return [self applyCheat:code index:cheatIndex enabled:enabled];   // +Cheats.mm
}

@end
#pragma clang diagnostic pop
