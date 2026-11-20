//
//  DrawableStarvationBackoff.swift
//  PVUIBase
//

import Foundation

/// Spaces out drawable requests while a `CAMetalLayer` has none to give.
///
/// `nextDrawable` runs on the main thread and, with `allowsNextDrawableTimeout`,
/// holds it for about a second before returning nil. Asking again on every frame
/// keeps the main thread blocked almost all the time: the app cannot answer a
/// scene update or a request to terminate, and the watchdog kills it (0x8BADF00D
/// with the main thread in `PVMetalViewController.directRender`). After a missing
/// drawable the renderer waits before it asks again, a little longer each time.
struct DrawableStarvationBackoff {
    /// The wait after the first missing drawable, in seconds.
    static let initialDelay: TimeInterval = 0.25
    /// The longest wait between two requests, in seconds.
    static let maximumDelay: TimeInterval = 2

    /// Missing drawables in a row.
    private(set) var consecutiveMisses = 0
    private var retryTime: TimeInterval = 0

    /// Whether the renderer should leave this frame undrawn.
    func shouldSkipDraw(at now: TimeInterval) -> Bool {
        consecutiveMisses > 0 && now < retryTime
    }

    /// The layer returned no drawable.
    mutating func recordMiss(at now: TimeInterval) {
        consecutiveMisses += 1
        retryTime = now + Self.delay(afterMisses: consecutiveMisses)
    }

    /// The layer returned a drawable, or its pool was rebuilt.
    mutating func reset() {
        consecutiveMisses = 0
        retryTime = 0
    }

    /// The wait after `misses` missing drawables in a row: doubles from
    /// `initialDelay` up to `maximumDelay`.
    static func delay(afterMisses misses: Int) -> TimeInterval {
        guard misses > 0 else { return 0 }
        let doublings = min(misses - 1, 8)
        return min(initialDelay * TimeInterval(1 << doublings), maximumDelay)
    }
}
