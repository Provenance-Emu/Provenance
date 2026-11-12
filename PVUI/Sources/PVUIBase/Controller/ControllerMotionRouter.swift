//
//  ControllerMotionRouter.swift
//  PVUI
//
//  Shaking a pad shakes the game's controller.
//

import Foundation
import GameController
import PVCoreBridge
import PVLogging
import PVSystems
import QuartzCore

#if canImport(UIKit)
import UIKit

/// One game's link between the players' pads' accelerometers and the core's shake input.
///
/// Every pad with motion sensors is sampled on each display refresh; each player has a
/// `ShakeDetector`. Nothing here installs a handler on a controller element.
@MainActor
final class ControllerMotionRouter {

    private weak var host: PVEmulatorViewController?
    private var displayLink: OwnedDisplayLink?
    private var observers: [NSObjectProtocol] = []

    /// Per player (1-based, as `PVControllerManager` numbers them).
    private var detectors: [Int: ShakeDetector] = [:]
    /// Pads whose sensors this router switched on, so it switches only those off.
    private var activatedPads: [ObjectIdentifier: GCMotion] = [:]
    /// The game is paused or the app is not active; nothing is delivered.
    private var isSuspended = false
    private var shakeEnabled = true
    private var settingsAreStale = true

    init(host: PVEmulatorViewController) {
        self.host = host
    }

    private var motionCore: MotionResponder? {
        guard let responder = host?.core as? MotionResponder, responder.gameSupportsShake else { return nil }
        return responder
    }

    // MARK: - Lifecycle

    func start() {
        guard displayLink == nil, motionCore != nil else { return }
        let center = NotificationCenter.default
        for name in [ControllerPointerSettingsStore.didChangeNotification, UserDefaults.didChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.settingsAreStale = true }
            })
        }
        let link = OwnedDisplayLink(owner: self) { [weak self] in self?.tick() }
        link.start()
        displayLink = link
        ILOG("Controller motion: shake routed to the core")
    }

    func stop() {
        releaseAll()
        displayLink?.stop()
        displayLink = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        for motion in activatedPads.values { motion.sensorsActive = false }
        activatedPads.removeAll()
    }

    // MARK: - Sampling

    private func tick() {
        if settingsAreStale { reloadSettings() }
        guard let core = motionCore, let host else { return }
        guard shakeEnabled, !host.isShowingMenu, UIApplication.shared.applicationState == .active else {
            if !isSuspended {
                isSuspended = true
                releaseAll()
            }
            return
        }
        isSuspended = false

        let now = CACurrentMediaTime()
        let pads = PVControllerManager.shared.allLiveControllers
        for (player, pad) in pads {
            guard let motion = pad.hardwareController.motion else { continue }
            activateSensorsIfNeeded(motion, on: pad.hardwareController)
            var detector = detectors[player] ?? ShakeDetector()
            let change = detector.update(acceleration: Self.totalAcceleration(of: motion), at: now)
            detectors[player] = detector
            if let change { core.setShaking(change, forPlayer: player - 1) }
        }
        /// A pad that went away lets go of its shake.
        for player in detectors.keys where pads[player] == nil {
            release(player: player, on: core)
        }
    }

    /// Acceleration including gravity, in g, whatever the pad reports.
    private static func totalAcceleration(of motion: GCMotion) -> SIMD3<Double> {
        if motion.hasGravityAndUserAcceleration {
            return SIMD3(motion.gravity.x + motion.userAcceleration.x,
                         motion.gravity.y + motion.userAcceleration.y,
                         motion.gravity.z + motion.userAcceleration.z)
        }
        return SIMD3(motion.acceleration.x, motion.acceleration.y, motion.acceleration.z)
    }

    private func activateSensorsIfNeeded(_ motion: GCMotion, on pad: GCController) {
        guard motion.sensorsRequireManualActivation, !motion.sensorsActive else { return }
        motion.sensorsActive = true
        activatedPads[ObjectIdentifier(pad)] = motion
    }

    private func reloadSettings() {
        settingsAreStale = false
        guard let host else { return }
        let system = SystemIdentifier(rawValue: host.core.systemIdentifier ?? "")
        shakeEnabled = ControllerPointerSettingsStore.shared
            .resolved(system: system, gameMD5: host.core.romMD5).shakeEnabled
    }

    // MARK: - Release

    private func releaseAll() {
        guard let core = host?.core as? MotionResponder else {
            detectors.removeAll()
            return
        }
        for player in Array(detectors.keys) { release(player: player, on: core) }
    }

    private func release(player: Int, on core: MotionResponder) {
        guard var detector = detectors.removeValue(forKey: player) else { return }
        if detector.reset() == false { core.setShaking(false, forPlayer: player - 1) }
    }
}
#endif
