//
//  PauseToggleCoalescer.swift
//  PVUI
//

import Foundation

/// Collapses the several pause signals one physical button press can produce
/// into a single pause-menu toggle.
///
/// The pause menu is a blind toggle fed by independent input paths that all
/// post `PauseGame`: the tvOS `UIPress.menu` recognizer, `GCController`
/// `buttonOptions`, the L3+R3 combo (each stick button has its own handler)
/// and the legacy `controllerPausedHandler`. Which of them fire for a given
/// press depends on the controller and OS version, and when two do, the
/// second toggle closes the menu the first one just opened.
struct PauseToggleCoalescer {
    /// Longer than the gap between duplicate signals for one press (same run
    /// loop turn up to a press's down/up interval), shorter than a deliberate
    /// second press.
    static let defaultWindow: TimeInterval = 0.4

    let window: TimeInterval
    private var lastAcceptedUptime: TimeInterval?

    init(window: TimeInterval = PauseToggleCoalescer.defaultWindow) {
        self.window = window
    }

    /// Returns `true` when a toggle arriving at `uptime` should be acted on,
    /// `false` when it is a duplicate of the one accepted just before it.
    mutating func shouldAccept(at uptime: TimeInterval) -> Bool {
        if let last = lastAcceptedUptime, uptime >= last, uptime - last < window {
            return false
        }
        lastAcceptedUptime = uptime
        return true
    }
}
