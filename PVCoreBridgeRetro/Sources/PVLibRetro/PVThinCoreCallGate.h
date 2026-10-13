//
//  PVThinCoreCallGate.h
//  PVCoreBridgeRetro
//
//  Serializes every call the thin libretro wrapper makes into a core: the
//  emulation loop's frame (`retro_run` and the per-frame callbacks), save and
//  load state (`retro_serialize_size` / `retro_serialize` / `retro_unserialize`),
//  `retro_reset`, the SRAM flush, and the final teardown (`context_destroy`,
//  `retro_unload_game`, `retro_deinit`). libretro cores are not thread-safe:
//  two of those running at once, on two threads, is undefined behaviour inside
//  the dylib. flycast's save path and its teardown both take the same internal
//  `std::mutex`, which is how a save state running on a GCD worker during quit
//  turned into a watchdog kill (0x8BADF00D).
//
//  The gate is a recursive lock plus a "tearing down" latch:
//    - `-enterWithTimeout:` acquires the gate, bounded. It refuses (returns NO)
//      once teardown has begun, so no core call can start after it.
//    - `-enterForTeardownWithTimeout:` latches teardown, then waits for any
//      in-flight call to finish. The thread that holds it becomes the teardown
//      owner: its own nested `-enterWithTimeout:` calls still succeed, every
//      other thread's are refused.
//    - `-reopen` clears the latch for the next session.
//
//  Recursive on purpose: the frame can call back into gated methods on the same
//  thread (a pending reset after a core-option change runs `retro_reset` from
//  inside the frame).
//
//  Never take the gate on the main thread without a bound: the emulation thread
//  holds it for a whole frame, and a frame can wait on the main queue.
//
//  Foundation only, no libretro types, so it is unit-testable on its own.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Pass to the timeout parameters to wait without a bound. Only for threads
/// that may legitimately park (the dedicated teardown thread, a test), never
/// for the main thread.
FOUNDATION_EXPORT const NSTimeInterval PVThinCoreCallGateWaitForever;

NS_SWIFT_SENDABLE
@interface PVThinCoreCallGate : NSObject

/// YES from `-beginTeardown` (or `-enterForTeardownWithTimeout:`) until `-reopen`.
@property (atomic, readonly, getter=isTearingDown) BOOL tearingDown;

/// Acquire the gate for one core call.
///
/// Returns NO, without holding the gate, when teardown has begun (and the
/// calling thread is not the teardown owner) or when the gate could not be
/// acquired within `timeout` seconds. A negative timeout waits forever. Every
/// YES must be balanced by exactly one `-leave` on the same thread.
- (BOOL)enterWithTimeout:(NSTimeInterval)timeout;

/// Release one level acquired by `-enterWithTimeout:`.
- (void)leave;

/// `-enterWithTimeout:`, run `block`, `-leave`. Returns NO, without running
/// `block`, when the gate refused or timed out.
- (BOOL)performWithTimeout:(NSTimeInterval)timeout block:(NS_NOESCAPE void (^)(void))block;

/// Latch teardown: from now on `-enterWithTimeout:` refuses on every thread
/// except the eventual teardown owner. Does not wait. Idempotent.
- (void)beginTeardown;

/// Latch teardown (as `-beginTeardown`), then wait up to `timeout` seconds for
/// the call in flight, if any, to leave. On YES the calling thread holds the
/// gate as the teardown owner and must call `-leaveTeardown` when done. On NO
/// (timed out) the gate is not held, and teardown stays latched.
- (BOOL)enterForTeardownWithTimeout:(NSTimeInterval)timeout;

/// Release the gate taken by `-enterForTeardownWithTimeout:`. Teardown stays
/// latched: nothing may call into the core again until `-reopen`.
- (void)leaveTeardown;

/// Clear the teardown latch so a new session can call into the core. Waits
/// (unbounded) for the gate, so call it only when no core call can be running.
- (void)reopen;

@end

NS_ASSUME_NONNULL_END
