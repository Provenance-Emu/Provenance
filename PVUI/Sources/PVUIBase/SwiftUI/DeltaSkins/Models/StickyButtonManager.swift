import Foundation
import Combine
import PVLogging

/// Manages "sticky" button state: when a button is toggled sticky, it stays
/// held (pressed) until the user taps it a second time to release it.
///
/// Usage:
/// - Call `handlePress(_:)` when a button touch begins.
/// - Call `handleRelease(_:)` when a button touch ends.
/// - The returned ``Action`` tells the caller whether to forward a real
///   press/release to the emulator core, or to suppress it.
@MainActor
public final class StickyButtonManager: ObservableObject {

    // MARK: - Types

    /// Instruction returned to the caller after processing a touch event.
    public enum Action {
        /// Forward a press event to the emulator core.
        case press
        /// Forward a release event to the emulator core.
        case release
        /// Do nothing — the event was absorbed by the sticky logic.
        case ignore
    }

    // MARK: - Published state

    /// The set of button IDs that are currently locked in the "sticky-on" state.
    /// Views can observe this to display a visual indicator (e.g. lock icon).
    @Published public private(set) var stickyButtons: Set<String> = []

    // MARK: - Private state

    /// Buttons currently physically held down by the user.
    private var physicallyPressed: Set<String> = []

    /// Timestamps of last press per button, for double-tap detection.
    private var lastPressTimestamps: [String: Date] = [:]

    /// Maximum interval between two taps to count as a double-tap.
    private let doubleTapInterval: TimeInterval = 0.35

    // MARK: - Public API

    /// Process a button press touch event.
    ///
    /// Returns the action the caller should take:
    /// - `.press` — send a press to the emulator core.
    /// - `.ignore` — the sticky system absorbed the event.
    public func handlePress(_ buttonId: String) -> Action {
        let now = Date()

        // Check for double-tap
        if let lastPress = lastPressTimestamps[buttonId],
           now.timeIntervalSince(lastPress) < doubleTapInterval {
            // Double-tap detected
            lastPressTimestamps.removeValue(forKey: buttonId)

            if stickyButtons.contains(buttonId) {
                // Button was sticky-on: release it
                DLOG("Sticky: releasing sticky button \(buttonId)")
                stickyButtons.remove(buttonId)
                physicallyPressed.insert(buttonId)
                return .release
            } else {
                // Button was not sticky: make it sticky.
                // The first tap already sent press+release to the core, so we must
                // send a new press now to actually hold the button down in the emulator.
                DLOG("Sticky: toggling ON sticky for \(buttonId)")
                stickyButtons.insert(buttonId)
                physicallyPressed.insert(buttonId)
                return .press
            }
        }

        lastPressTimestamps[buttonId] = now

        // If the button is sticky-on and user presses again (single tap, first of potential double),
        // we need to release it on this press.
        if stickyButtons.contains(buttonId) {
            // Don't release yet — wait to see if it's a double tap.
            // For now, just track the press time. The release handler will decide.
            physicallyPressed.insert(buttonId)
            return .ignore
        }

        // Normal press
        physicallyPressed.insert(buttonId)
        return .press
    }

    /// Process a button release touch event.
    ///
    /// Returns the action the caller should take:
    /// - `.release` — send a release to the emulator core.
    /// - `.ignore` — the sticky system absorbed the event (button stays held).
    public func handleRelease(_ buttonId: String) -> Action {
        physicallyPressed.remove(buttonId)

        if stickyButtons.contains(buttonId) {
            // Button is sticky-on: suppress the release so it stays held.
            DLOG("Sticky: suppressing release for sticky button \(buttonId)")
            return .ignore
        }

        // Normal release
        return .release
    }

    /// Release all sticky buttons at once (e.g. when pausing or leaving emulator).
    /// Returns the set of button IDs that were released.
    @discardableResult
    public func releaseAll() -> Set<String> {
        let released = stickyButtons
        stickyButtons.removeAll()
        physicallyPressed.removeAll()
        lastPressTimestamps.removeAll()
        return released
    }

    /// Check if a specific button is in the sticky-on state.
    public func isSticky(_ buttonId: String) -> Bool {
        stickyButtons.contains(buttonId)
    }
}
