import Foundation
import PVSettings
import PVLogging
import Defaults
#if canImport(QuartzCore)
import QuartzCore
#endif

/// Manages turbo/autofire state for skin buttons.
///
/// When turbo is enabled for a button, the manager rapidly toggles
/// press/release at the rate configured in ``Defaults.Keys.turboRateHz``.
/// The caller provides a press/release callback; the manager drives timing.
///
/// All public API must be called from the main thread (CADisplayLink fires on
/// the main run-loop).
public final class TurboManager: ObservableObject, @unchecked Sendable {

    // MARK: - Published state

    /// The set of button IDs that currently have turbo enabled.
    @Published public private(set) var turboButtons: Set<String> = []

    // MARK: - Callback

    /// Called by the timer to press (true) or release (false) a button.
    public var buttonAction: ((_ buttonId: String, _ isPressed: Bool) -> Void)?

    // MARK: - Internal state

    /// Buttons that the user is currently *holding down* (finger on screen).
    /// Turbo only fires while the button is held.
    private var heldButtons: Set<String> = []

    /// Display-link timer that drives the turbo toggling.
    private var displayLink: CADisplayLink?

    /// Tracks the current on/off phase per button so we can alternate.
    private var buttonPhase: [String: Bool] = [:]

    /// Timestamp of the last toggle per button, used to throttle to the configured rate.
    private var lastToggle: [String: CFTimeInterval] = [:]

    // MARK: - Lifecycle

    public init() {}

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Public API

    /// Toggle turbo mode for the given button ID.
    /// Returns `true` if turbo is now active, `false` if it was turned off.
    @discardableResult
    public func toggleTurbo(for buttonId: String) -> Bool {
        if turboButtons.contains(buttonId) {
            turboButtons.remove(buttonId)
            buttonPhase.removeValue(forKey: buttonId)
            lastToggle.removeValue(forKey: buttonId)
            DLOG("Turbo OFF for \(buttonId)")
            updateTimer()
            return false
        } else {
            turboButtons.insert(buttonId)
            buttonPhase[buttonId] = false
            DLOG("Turbo ON for \(buttonId)")
            updateTimer()
            return true
        }
    }

    /// Returns whether the given button currently has turbo enabled.
    public func isTurboActive(for buttonId: String) -> Bool {
        turboButtons.contains(buttonId)
    }

    /// Call when the user presses down on a button (finger touches screen).
    public func buttonDown(_ buttonId: String) {
        heldButtons.insert(buttonId)
        if turboButtons.contains(buttonId) {
            // Start in the "pressed" phase immediately
            buttonPhase[buttonId] = true
            buttonAction?(buttonId, true)
            lastToggle[buttonId] = CACurrentMediaTime()
            updateTimer()
        }
    }

    /// Call when the user lifts their finger from a button.
    public func buttonUp(_ buttonId: String) {
        heldButtons.remove(buttonId)
        if turboButtons.contains(buttonId) {
            // Ensure the button is released
            buttonPhase[buttonId] = false
            buttonAction?(buttonId, false)
            updateTimer()
        }
    }

    /// Remove all turbo assignments.
    public func clearAll() {
        turboButtons.removeAll()
        buttonPhase.removeAll()
        lastToggle.removeAll()
        heldButtons.removeAll()
        updateTimer()
    }

    // MARK: - Timer management

    private func updateTimer() {
        let needsTimer = !turboButtons.isEmpty && !heldButtons.isDisjoint(with: turboButtons)
        if needsTimer && displayLink == nil {
            let link = CADisplayLink(target: TurboDisplayLinkTarget(handler: { [weak self] in
                self?.tick()
            }), selector: #selector(TurboDisplayLinkTarget.step))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else if !needsTimer && displayLink != nil {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    private func tick() {
        guard Defaults[.turboEnabled] else {
            // Stop the display link when turbo is globally disabled
            displayLink?.invalidate()
            displayLink = nil
            return
        }
        let rateHz = max(2.0, min(30.0, Defaults[.turboRateHz]))
        let interval: CFTimeInterval = 1.0 / (rateHz * 2.0) // half-period (press + release = 1 full cycle)
        let now = CACurrentMediaTime()

        for buttonId in turboButtons where heldButtons.contains(buttonId) {
            let last = lastToggle[buttonId] ?? 0
            if now - last >= interval {
                let currentPhase = buttonPhase[buttonId] ?? false
                let newPhase = !currentPhase
                buttonPhase[buttonId] = newPhase
                lastToggle[buttonId] = now
                buttonAction?(buttonId, newPhase)
            }
        }
    }
}

// MARK: - CADisplayLink target (prevents retain cycle)

/// A small helper that forwards CADisplayLink callbacks without creating a
/// retain cycle between the display link and TurboManager.
private final class TurboDisplayLinkTarget: NSObject {
    let handler: () -> Void
    init(handler: @escaping () -> Void) { self.handler = handler }
    @objc func step() { handler() }
}
