//
//  PVRetroArchCore+ExceptionTrampoline.mm
//  PVRetroArch
//
//  Thin C++/ObjC++ trampoline that wraps RetroArch's `runloop_iterate`
//  and any other libretro call sites we drive in a try/catch boundary,
//  so unhandled C++ exceptions thrown from inside a dlopened libretro
//  core (most commonly `vk::DeviceLostError` from flycast's own
//  `vk::Device::waitForFences` on iOS GPU pressure, but every Vulkan-HPP
//  core can rethrow similarly) don't propagate up through
//  `__cxa_throw` → `_objc_terminate` → `abort` and kill the whole app.
//
//  iOS uses a single system-shared `/usr/lib/libc++abi.dylib`, so
//  exceptions thrown from inside one dlopened image CAN be caught at
//  a try/catch in a different translation unit — but the catch site
//  must be in a C++-aware compilation unit. RA's `runloop.c` is pure
//  C and `PVRetroArchCore+RetroArchUI.m` is Objective-C with no C++
//  exception machinery, so we add a tiny ObjC++ shim.
//
//  Call site change: where `runloop_iterate()` was called directly
//  from `rarch_draw_observer`, we now call `pv_safe_runloop_iterate()`.
//  Same return value, same semantics — minus the hard crash on
//  unhandled exceptions.
//

#import <Foundation/Foundation.h>
#import "PVRetroArchCore+ExceptionTrampoline.h"
#include <exception>
#include <stdexcept>
#include <string>
#include <atomic>

// RA headers — we need the runloop API.
#include "../../RetroArch/retroarch.h"

NS_ASSUME_NONNULL_BEGIN

// Definition of the notification-name constant declared in the header.
NSNotificationName const PVRetroArchCoreDidThrowNotification =
    @"PVRetroArchCoreDidThrowNotification";

namespace {

/// Posts the crash notification on main, dedup'd via an atomic so a
/// runaway core that throws every frame doesn't spam the notification
/// queue. Reset only on a fresh game load (see
/// `pv_safe_runloop_reset_throw_flag()` below).
std::atomic<bool> g_coreDidThrow{false};

void postCoreDidThrowNotificationOnce(NSString *reason) {
    bool expected = false;
    if (!g_coreDidThrow.compare_exchange_strong(expected, true)) {
        return; // already posted
    }
    NSDictionary *info = reason ? @{ @"reason": reason } : @{};
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
         postNotificationName:PVRetroArchCoreDidThrowNotification
         object:nil
         userInfo:info];
    });
}

}  // namespace

extern "C" {

/// Drop-in replacement for `runloop_iterate()` that catches C++ /
/// NSException throws from inside the core. Returns -1 when an
/// exception was caught (caller should treat like "core wants to
/// exit"). On success, returns whatever `runloop_iterate()` returned.
int pv_safe_runloop_iterate(void) {
    if (g_coreDidThrow.load(std::memory_order_relaxed)) {
        // Core is dead — return -1 so the caller exits its draw observer
        // path cleanly instead of re-entering a known-bad core.
        return -1;
    }

    @try {
        try {
            return runloop_iterate();
        } catch (const std::exception &e) {
            NSString *reason = [NSString stringWithUTF8String:e.what()];
            NSLog(@"[PV-SAFE-RETRO] core threw std::exception in runloop_iterate: %@", reason);
            postCoreDidThrowNotificationOnce(reason);
            return -1;
        } catch (...) {
            NSLog(@"[PV-SAFE-RETRO] core threw unknown C++ exception in runloop_iterate");
            postCoreDidThrowNotificationOnce(@"unknown C++ exception");
            return -1;
        }
    } @catch (NSException *exc) {
        NSLog(@"[PV-SAFE-RETRO] core threw NSException in runloop_iterate: %@", exc);
        postCoreDidThrowNotificationOnce(exc.reason ?: @"NSException");
        return -1;
    }
}

/// Called on a fresh game load to clear the dead-core flag so the next
/// runloop iteration actually exercises the core again.
void pv_safe_runloop_reset_throw_flag(void) {
    g_coreDidThrow.store(false, std::memory_order_relaxed);
}

/// Read-only inspector for the dead-core flag. Allows the ObjC VC layer
/// to skip presenting frames / running input if the core is dead.
bool pv_safe_runloop_did_throw(void) {
    return g_coreDidThrow.load(std::memory_order_relaxed);
}

}  // extern "C"

// MARK: - Global terminate handler
//
// The try/catch in `pv_safe_runloop_iterate` only catches exceptions thrown
// on the runloop thread. Libretro cores can spawn internal worker threads
// (flycast's threaded renderer is the typical case); when one of those
// threads throws an uncaught C++ exception it bypasses our trampoline and
// goes straight to `_objc_terminate → abort`.
//
// Install a `std::set_terminate` handler at first-load time so we at least:
//   1. log the exception type/`what()` to os_log + Console.app
//   2. post the `PVRetroArchCoreDidThrowNotification` so the UI can show
//      the "core stopped working" panel before the OS reaps the process
//   3. give the notification ~250 ms to deliver before re-aborting
//
// Returning from a `std::terminate` handler without calling `std::abort()`
// is undefined behaviour, but at least we get a clean breadcrumb before
// the inevitable kill.

namespace {

std::terminate_handler g_previousTerminateHandler = nullptr;

[[noreturn]] void pv_terminate_handler() {
    // What was being thrown when terminate was called.
    NSString *reason = @"unhandled exception (no current_exception)";
    if (auto eptr = std::current_exception()) {
        try {
            std::rethrow_exception(eptr);
        } catch (const std::exception &e) {
            reason = [NSString stringWithUTF8String:e.what()];
        } catch (const std::string &s) {
            reason = [NSString stringWithUTF8String:s.c_str()];
        } catch (const char *s) {
            reason = [NSString stringWithUTF8String:s];
        } catch (...) {
            reason = @"unknown C++ exception";
        }
    }

    NSLog(@"[PV-TERMINATE] unhandled exception: %@ — posting crash "
          @"notification before abort", reason);

    // Best-effort: try to deliver the notification synchronously on a
    // dispatch_async to main, then sleep briefly so the main thread
    // gets a chance to drain. We're already past the point of no
    // return; this is purely a telemetry/UX nicety.
    @autoreleasepool {
        postCoreDidThrowNotificationOnce(reason);
    }
    // Give the main runloop ~250 ms to receive the post + present the
    // alert. Anything thrown again in that window is the previous
    // handler's problem.
    usleep(250 * 1000);

    if (g_previousTerminateHandler) {
        g_previousTerminateHandler();
    }
    std::abort();
}

}  // namespace

extern "C" void pv_safe_install_terminate_handler(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        g_previousTerminateHandler = std::set_terminate(pv_terminate_handler);
        NSLog(@"[PV-TERMINATE] installed global std::terminate handler");
    });
}

NS_ASSUME_NONNULL_END
