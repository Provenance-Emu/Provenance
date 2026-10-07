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

class AzaharEmuWindow;

@interface PVAzaharCoreBridge () {
@public
    std::unique_ptr<AzaharEmuWindow> _window;
    std::thread _emuThread;
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
