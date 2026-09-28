///
/// TapDragDetector.swift
/// PVUI
///
/// Recognises the laptop-trackpad "tap, then touch again and drag" gesture:
/// a touch that lands shortly after a tap holds the left button down until the
/// finger lifts, so windows, icons and selections can be dragged.
///

import Foundation

struct TapDragDetector {
    /// How soon after a tap the next touch must land to grab (seconds).
    static let defaultWindow: TimeInterval = 0.3

    let window: TimeInterval
    private var lastTapTime: TimeInterval?

    init(window: TimeInterval = TapDragDetector.defaultWindow) {
        self.window = window
    }

    /// Records a completed tap (a click already sent to the core).
    mutating func tapEnded(at time: TimeInterval) {
        lastTapTime = time
    }

    /// Returns true when the touch starting at `time` should press and hold the left button.
    /// Each tap arms at most one grab.
    mutating func touchBegan(at time: TimeInterval) -> Bool {
        defer { lastTapTime = nil }
        guard let lastTapTime else { return false }
        return time - lastTapTime <= window
    }
}
