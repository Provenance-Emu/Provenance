//
//  PauseMenuTriggerMonitor.swift
//  PVUI
//
//  Samples the connected pads for their pause-menu triggers while a game runs.
//

import Foundation
import GameController
import PVLogging
import PVSupport
import QuartzCore

public extension GCController {
    /// Physical-profile names of a capture button, the same ones `PVShareLikeButtonForController`
    /// looks up. Only "Button Share" is confirmed in GameController's own strings.
    private static let captureButtonNames = [GCInputButtonShare, "Button Capture"]

    /// The capture button that is separate from `buttonOptions` (Xbox Share, Switch Pro
    /// Capture). On a PlayStation pad the Create/Share button is `buttonOptions` itself,
    /// which games use as Select, so those pads have none.
    var pauseMenuShareButton: GCControllerButtonInput? {
        guard let gamepad = extendedGamepad,
              !(gamepad is GCDualSenseGamepad), !(gamepad is GCDualShockGamepad) else { return nil }
        let buttons = physicalInputProfile.buttons
        return Self.captureButtonNames
            .compactMap { buttons[$0] }
            .first { $0 !== gamepad.buttonOptions }
    }

    /// What this pad offers the pause binding.
    var pauseMenuCapabilities: PauseMenuPadCapabilities {
        let gamepad = extendedGamepad
        return PauseMenuPadCapabilities(
            hasExtendedProfile: gamepad != nil,
            hasOptions: gamepad?.buttonOptions != nil,
            hasShareButton: gamepad != nil && pauseMenuShareButton != nil,
            hasHome: gamepad?.buttonHome != nil,
            hasThumbstickButtons: gamepad?.leftThumbstickButton != nil && gamepad?.rightThumbstickButton != nil,
            hasProfileTrigger: hasPauseMenuProfileTrigger)
    }

    private var hasPauseMenuProfileTrigger: Bool {
        #if canImport(UIKit)
        return (self as? PVPhysicalProfileController)?.pauseTrigger != nil
        #else
        return false
        #endif
    }

    /// The current state of the buttons the pause triggers read.
    var pauseMenuButtonSample: PauseMenuButtonSample {
        guard let gamepad = extendedGamepad else { return PauseMenuButtonSample() }
        return PauseMenuButtonSample(
            options: gamepad.buttonOptions?.isPressed ?? false,
            menu: gamepad.buttonMenu.isPressed,
            share: pauseMenuShareButton?.isPressed ?? false,
            home: gamepad.buttonHome?.isPressed ?? false,
            leftThumbstickButton: gamepad.leftThumbstickButton?.isPressed ?? false,
            rightThumbstickButton: gamepad.rightThumbstickButton?.isPressed ?? false)
    }

    /// Keeps the system's own gestures (screenshot and clip recording on Share/Create,
    /// Game Center on Home) off the buttons the pause triggers read, so a press reaches the app.
    func disablePauseMenuSystemGestures() {
        let gamepad = extendedGamepad
        let buttons = [gamepad?.buttonOptions, gamepad?.buttonMenu, gamepad?.buttonHome, pauseMenuShareButton]
        for button in buttons.compactMap({ $0 }) where button.isBoundToSystemGesture {
            button.preferredSystemGestureState = .disabled
        }
    }
}

#if canImport(UIKit)
/// Watches every connected extended gamepad for its pause-menu triggers.
///
/// One instance lives for the length of a game. It reads button state on the display's
/// refresh, which neither overwrites a core's own button handlers nor can be overwritten by them.
@MainActor
final class PauseMenuTriggerMonitor {
    private let systemUsesSelect: Bool
    private let controllers: () -> [GCController]
    private let onTrigger: (PauseMenuTrigger) -> Void
    private var detectors: [ObjectIdentifier: PauseMenuTriggerDetector] = [:]
    private var displayLink: OwnedDisplayLink?

    init(systemUsesSelect: Bool,
         controllers: @escaping () -> [GCController],
         onTrigger: @escaping (PauseMenuTrigger) -> Void) {
        self.systemUsesSelect = systemUsesSelect
        self.controllers = controllers
        self.onTrigger = onTrigger
    }

    /// The pause inputs of a pad under this monitor's system.
    func bindingPlan(for controller: GCController) -> PauseMenuBindingPlan {
        PauseMenuBindingPolicy.plan(for: controller.pauseMenuCapabilities, systemUsesSelect: systemUsesSelect)
    }

    func start() {
        guard displayLink == nil else { return }
        let link = OwnedDisplayLink(owner: self) { [weak self] in self?.sample() }
        link.start()
        displayLink = link
    }

    func stop() {
        displayLink?.stop()
        displayLink = nil
        detectors.removeAll()
    }

    private func sample() {
        let pads = controllers()
        var seen: Set<ObjectIdentifier> = []
        /// Snapshots are the keyboard-backed controller, which has its own menu shortcut.
        for pad in pads where pad.extendedGamepad != nil && !pad.isSnapshot {
            let id = ObjectIdentifier(pad)
            seen.insert(id)
            var detector = detectors[id] ?? makeDetector(for: pad)
            let fired = detector.update(with: pad.pauseMenuButtonSample)
            detectors[id] = detector
            if let fired {
                ILOG("Pause trigger \(fired.rawValue) from \(pad.vendorName ?? "unknown")")
                onTrigger(fired)
            }
        }
        detectors = detectors.filter { seen.contains($0.key) }
    }

    private func makeDetector(for pad: GCController) -> PauseMenuTriggerDetector {
        let plan = bindingPlan(for: pad)
        pad.disablePauseMenuSystemGestures()
        ILOG("Pause triggers for \(pad.vendorName ?? "unknown"): \(plan.triggers.map(\.rawValue).joined(separator: ", "))")
        return PauseMenuTriggerDetector(plan: plan)
    }
}

/// Calls `onTick` on every display refresh for as long as `owner` is alive.
///
/// `CADisplayLink` retains its target, so the target is this object rather than the
/// owner. The link ends itself on the first refresh after the owner is gone, which
/// covers an owner released without `stop()`. `onTick` must not capture the owner strongly.
@MainActor
final class OwnedDisplayLink: NSObject {
    private weak var owner: AnyObject?
    private let onTick: () -> Void
    private var link: CADisplayLink?

    init(owner: AnyObject, onTick: @escaping () -> Void) {
        self.owner = owner
        self.onTick = onTick
    }

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard owner != nil else {
            link.invalidate()
            return
        }
        onTick()
    }
}
#endif
