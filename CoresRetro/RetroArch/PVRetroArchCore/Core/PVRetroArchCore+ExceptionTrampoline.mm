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
#include <exception>
#include <stdexcept>
#include <string>
#include <atomic>

// RA headers — we need the runloop API.
#include "../../RetroArch/retroarch.h"

NS_ASSUME_NONNULL_BEGIN

/// Notification name posted on main when the thick wrapper catches an
/// unhandled exception from the running core. The emulator VC observes
/// this to show a "core crashed — return to library" UI instead of
/// silently spinning on a dead core.
NSString * const PVRetroArchCoreDidThrowNotification =
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

NS_ASSUME_NONNULL_END
