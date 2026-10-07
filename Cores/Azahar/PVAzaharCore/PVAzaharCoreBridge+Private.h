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
    NSString *_romPath;              // set in loadFileAtPath:, loaded on the emu thread
    UIView *_renderView;             // PVAzaharRenderView, added to touchViewController.view
    NSArray<NSLayoutConstraint *> *_renderViewConstraints;
    BOOL _useCustomRenderViewLayout;
}
- (void)runOnEmuThread:(std::function<void()>)job;          // async
- (BOOL)runOnEmuThreadAndWait:(std::function<void()>)job timeout:(NSTimeInterval)seconds; // sync, NO on timeout
- (void)applySettingsFromOptions;    // bridge properties -> Settings::values
- (NSString *)userDirectoryPath;     // <Documents>/Azahar/
- (void)configureAudioSession;       // defined in +Audio.mm (Task 8), which also adds the call
@end
