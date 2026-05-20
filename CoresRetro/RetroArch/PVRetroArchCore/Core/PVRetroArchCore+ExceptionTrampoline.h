//
//  PVRetroArchCore+ExceptionTrampoline.h
//  PVRetroArch
//
//  Public surface for the C++ exception trampoline. Posters and
//  observers reference the typed `NSNotificationName` declared here
//  rather than retyping the underlying string at every call site.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted on the main queue when the thick RetroArch wrapper catches an
/// unhandled C++ / `NSException` thrown from inside the dlopened libretro
/// core (typically `vk::DeviceLostError` from a core's own Vulkan-HPP
/// layer). `userInfo[@"reason"]` carries the exception's `what()` /
/// `NSException.reason` string when available.
///
/// Swift consumers: see the `Notification.Name` extension in
/// `PVThinLibretroCore.swift` for the typed accessor.
FOUNDATION_EXPORT NSNotificationName const PVRetroArchCoreDidThrowNotification;

#ifdef __cplusplus
extern "C" {
#endif

/// Drop-in replacement for RetroArch's `runloop_iterate()`. Wraps the
/// call in `try/catch` + `@try/@catch` so a libretro core crash
/// produces a notification instead of `__cxa_throw → abort`. Returns
/// `runloop_iterate`'s value on success, `-1` on caught exception
/// (which RA treats as "exit loop").
int pv_safe_runloop_iterate(void);

/// Clear the cached "core threw" flag — call from `loadFileAtPath:` so
/// a fresh game doesn't inherit a dead-core state from the previous
/// session.
void pv_safe_runloop_reset_throw_flag(void);

/// Read the cached "core threw" flag. ObjC VC layer can use this to
/// skip frame presentation / input forwarding when the core is dead.
bool pv_safe_runloop_did_throw(void);

/// Install a `std::set_terminate` handler that catches exceptions on
/// ANY thread (not just the runloop thread `pv_safe_runloop_iterate`
/// covers). Idempotent — safe to call from each game load. Logs the
/// exception via os_log and posts
/// `PVRetroArchCoreDidThrowNotification` before the inevitable abort.
void pv_safe_install_terminate_handler(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
