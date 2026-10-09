#pragma once
// Private to the PVAzahar framework: C++ ivars shared by the bridge's categories. Include only from .mm files.
#import "PVAzaharCoreBridge.h"
#include <atomic>
#include <condition_variable>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <thread>
#include <pthread.h>
#include "common/settings.h"

/// UI index (Default, Single, Large, Side by Side, Hybrid) -> azahar layout. SeparateWindows is skipped.
static inline Settings::LayoutOption PVAzaharLayoutOption(NSInteger index) {
    switch (index) {
    case 1: return Settings::LayoutOption::SingleScreen;
    case 2: return Settings::LayoutOption::LargeScreen;
    case 3: return Settings::LayoutOption::SideScreen;
    case 4: return Settings::LayoutOption::HybridScreen;
    default: return Settings::LayoutOption::Default;
    }
}
/// UI index (Top Full Width, Original) -> azahar portrait layout. Custom is driven by skins, not the option.
static inline Settings::PortraitLayoutOption PVAzaharPortraitLayoutOption(NSInteger index) {
    return index == 1 ? Settings::PortraitLayoutOption::PortraitOriginal
                      : Settings::PortraitLayoutOption::PortraitTopFullWidth;
}

class AzaharEmuWindow;

/// std::thread stand-in with a bigger stack. iOS gives secondary threads 512 KB, and glslang's
/// recursive parser overflowed that while compiling shaders on the emulation thread.
class AzaharEmuThread {
public:
    static constexpr size_t kStackBytes = 16 * 1024 * 1024;
    AzaharEmuThread() = default;
    template <class F> explicit AzaharEmuThread(F&& fn) { start(std::function<void()>(std::forward<F>(fn))); }
    AzaharEmuThread(const AzaharEmuThread&) = delete;
    AzaharEmuThread& operator=(const AzaharEmuThread&) = delete;
    AzaharEmuThread& operator=(AzaharEmuThread&& o) noexcept {
        _tid = o._tid; _joinable = o._joinable; o._joinable = false; return *this;
    }
    ~AzaharEmuThread() { if (_joinable) { pthread_detach(_tid); } }
    bool joinable() const { return _joinable; }
    bool isCurrent() const { return _joinable && pthread_equal(_tid, pthread_self()); }
    void join() { if (_joinable) { pthread_join(_tid, nullptr); _joinable = false; } }
    void detach() { if (_joinable) { pthread_detach(_tid); _joinable = false; } }
private:
    static void* trampoline(void* p) {
        auto* fn = static_cast<std::function<void()>*>(p);
        (*fn)();
        delete fn;
        return nullptr;
    }
    void start(std::function<void()> fn) {
        pthread_attr_t attr;
        pthread_attr_init(&attr);
        pthread_attr_setstacksize(&attr, kStackBytes);
        auto* heapFn = new std::function<void()>(std::move(fn));
        if (pthread_create(&_tid, &attr, &trampoline, heapFn) == 0) { _joinable = true; } else { delete heapFn; }
        pthread_attr_destroy(&attr);
    }
    pthread_t _tid{};
    bool _joinable = false;
};

@interface PVAzaharCoreBridge () {
@public
    std::unique_ptr<AzaharEmuWindow> _window;
    AzaharEmuThread _emuThread;
    std::atomic<bool> _running;      // emu thread alive
    std::atomic<bool> _paused;       // RunLoop skipped while true
    std::mutex _jobMutex;
    std::condition_variable _jobCV;  // wakes a paused loop
    std::deque<std::function<void()>> _jobs;   // run on the emu thread between RunLoop calls
    std::atomic<bool> _loaded;       // Core::System::Load succeeded
    std::atomic<bool> _stopRequested; // set by stop before the join; the emu thread skips the loop
    std::atomic<std::thread::id> _emuThreadId;  // set inside the emu thread; default id when none runs
    std::atomic<bool> _emuThreadExited; // last statement of the emu thread; stop pumps main until it is set
    std::atomic<bool> _stopping;        // stopEmulationWithMessage: in progress (its pumped run loop can re-enter it)
    NSString *_romPath;              // set in loadFileAtPath:, loaded on the emu thread
    UIView *_renderView;             // PVAzaharRenderView, added to touchViewController.view
    NSArray<NSLayoutConstraint *> *_renderViewConstraints;
    BOOL _useCustomRenderViewLayout;
    BOOL _skinLayoutActive;          // a dual-screen skin supplied both screen rects (custom layout)
    CGRect _skinTopPx, _skinBottomPx; // skin screen rects in render-view pixels, relative to the view
    CGSize _skinUnionPx;             // drawable size those rects were computed for
    CGSize _lastDrawablePx;          // last size handed to the window; relayout reuses it
    std::atomic<bool> _leftStickDrivesCStick;   // PV3DSButtonAnalogMode toggles it
}
/// Jobs run on the emu thread between RunLoop slices (also while paused), and are dropped
/// unrun when emulation stops.
- (void)runOnEmuThread:(std::function<void()>)job;          // async
/// Returns YES once the job has run; NO on timeout, when not running, or if it was dropped at stop.
/// The job may outlive a timeout; capture only by value or shared_ptr, never by reference.
- (BOOL)runOnEmuThreadAndWait:(std::function<void()>)job timeout:(NSTimeInterval)seconds;
/// Bridge properties -> Settings::values. Called on main before the emu thread starts; any call
/// after that must go through runOnEmuThread: followed by Core::System::ApplySettings().
- (void)applySettingsFromOptions;
/// Executes a MAP_JIT test page (Dolphin's probe); YES on the simulator.
- (BOOL)probeJITAvailable;
- (NSString *)userDirectoryPath;     // PVAzaharCore.userRootURL: <Documents>/Azahar (iOS), <Caches>/Azahar (tvOS)
@end

@interface PVAzaharCoreBridge (Cheats)
- (BOOL)applyCheat:(NSString *)code index:(UInt8)index enabled:(BOOL)enabled;   // +Cheats.mm; setCheat: forwards here
@end

@interface PVAzaharCoreBridge (Audio)
- (void)configureAudioSession;       // +Audio.mm; startEmulation calls it
@end
