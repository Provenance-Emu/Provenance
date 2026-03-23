//
//  GyroMouseAdapter.swift
//  PVCoreBridge
//
//  Created by Claude (Agent) on 2026-03-22.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Drives a ``MouseResponder`` from gyroscope rotation-rate input.
//
//  Sources:
//  - GCController.controllers().first(where:)?.motion?.rotationRate  (DualSense, Switch Pro)
//  - CMMotionManager.deviceMotion.rotationRate                        (iPhone/iPad IMU fallback)
//
//  The adapter accumulates rotationRate.x / .y (rad/s) into a virtual cursor
//  position in [0,1]×[0,1], applies a configurable dead zone and low-pass
//  filter, then calls `MouseResponder.mouseMoved(atPoint:)` on the active core.
//
//  Usage:
//    let adapter = GyroMouseAdapter()
//    adapter.attach(to: myCore)
//    // …pause / background…
//    adapter.isEnabled = false
//    // …later…
//    adapter.detach()
//

import CoreGraphics
import Foundation
import PVLogging

#if canImport(GameController)
import GameController
#endif

#if canImport(CoreMotion)
import CoreMotion
#endif

/// Input source preference for ``GyroMouseAdapter``.
@objc public enum GyroMouseInputSource: Int {
    /// Use GCController motion first; fall back to device IMU when no controller is connected.
    case auto       = 0
    /// Only use GCController `GCMotion`.
    case controller = 1
    /// Only use the device IMU (`CMMotionManager`), even when a controller is connected.
    case deviceIMU  = 2
}

/// Drives a ``MouseResponder`` from gyroscope rotation-rate input.
///
/// Instantiate once per session and call ``attach(to:)`` when a mouse-capable
/// core starts, ``detach()`` when it stops.
///
/// - Thread safety: Public API is main-thread-confined. Motion callbacks hop
///   to the main actor via `Task { @MainActor in ... }` before mutating state.
///   `@MainActor` enforces this at the type-system level (Swift 6–compatible);
///   matches the pattern used by ``GCMouseLightGunDriver``.
@MainActor
@objc public final class GyroMouseAdapter: NSObject {

    // MARK: - Configuration

    /// Sensitivity multiplier. Higher = faster cursor movement per rad/s.
    /// Range 0.1 – 5.0; default 1.0.
    @objc public var sensitivity: Double = 1.0

    /// Dead zone in rad/s. Rotation rates whose absolute value is below this
    /// threshold are ignored to prevent cursor drift when the controller/device
    /// is nominally stationary.  Default 0.05 rad/s.
    @objc public var deadZone: Double = 0.05

    /// Low-pass filter coefficient α ∈ (0, 1].
    /// Lower = more smoothing, higher = more responsive.  Default 0.3.
    @objc public var smoothingAlpha: Double = 0.3

    /// Preferred input source. Default `.auto`.
    @objc public var inputSource: GyroMouseInputSource = .auto

    /// When `false` events are not delivered (e.g. while paused). Default `true`.
    ///
    /// Toggling this property also stops/starts the CoreMotion IMU (if active) to
    /// conserve battery when the game is paused.  GCController observers remain
    /// registered so reconnect events are still handled.
    @objc public var isEnabled: Bool = true {
        didSet {
            guard isEnabled != oldValue else { return }
            if isEnabled {
                // Reset timestamp so the first frame after re-enable uses the nominal
                // dt (1/60) instead of computing a large elapsed gap.
                lastCallbackTime = 0
                // Restart IMU if we should be using it.
#if canImport(CoreMotion)
                if _shouldUseIMU() { _startIMU() }
#endif
            } else {
                // Stop the IMU at 60 Hz to conserve battery while paused.
                // GCController hook stays active (minimal cost) so reconnects
                // are still observed; _applyRotation guards on isEnabled.
                lastCallbackTime = 0
#if canImport(CoreMotion)
                _stopIMU()
#endif
            }
        }
    }

    // MARK: - State (main-thread only)

    private weak var responder: (AnyObject & MouseResponder)?

    /// Normalised cursor position in [0, 1] × [0, 1].
    private var cursorX: Double = 0.5
    private var cursorY: Double = 0.5

    /// Exponential moving average of the filtered rotation rates.
    private var filteredX: Double = 0.0
    private var filteredY: Double = 0.0

    // MARK: - GCController observation

#if canImport(GameController)
    private var controllerConnectObserver: NSObjectProtocol?
    private var controllerDisconnectObserver: NSObjectProtocol?
    private weak var hookedController: GCController?
#endif

    // MARK: - CoreMotion

#if canImport(CoreMotion)
    private var motionManager: CMMotionManager?
#endif

    /// Whether the device IMU is currently providing input.
    private var imuActive: Bool = false

    /// Timestamp of the last `_applyRotation` call, used to compute actual dt.
    private var lastCallbackTime: TimeInterval = 0

    /// Monotonically-increasing counter incremented on every `_stopInput()` call.
    /// Captured at callback-registration time; Tasks from a previous session
    /// silently no-op when the captured token no longer matches the current one.
    private var _sessionToken: UInt64 = 0

    // MARK: - Lifecycle

    public override init() {
        super.init()
    }

    deinit {
        detach()
    }

    /// Start delivering gyro-driven mouse input to `core`.
    ///
    /// The core must conform to ``MouseResponder`` and its `gameSupportsMouse`
    /// must return `true`; otherwise the adapter starts but immediately delivers
    /// no events (guarded at call site for clarity, but attach is unconditional).
    @objc public func attach(to core: AnyObject & MouseResponder) {
        detach()
        responder        = core
        cursorX          = 0.5
        cursorY          = 0.5
        filteredX        = 0.0
        filteredY        = 0.0
        lastCallbackTime = 0
        _startInput()
    }

    /// Stop delivering input and release the core reference.
    @objc public func detach() {
        _stopInput()
        responder = nil
    }

    // MARK: - Input start / stop

    private func _startInput() {
#if canImport(GameController)
        _observeControllerNotifications()
        _hookCurrentController()
#endif

#if canImport(CoreMotion)
        if _shouldUseIMU() {
            _startIMU()
        }
#endif
    }

    private func _stopInput() {
        // Invalidate all pending motion Tasks from the outgoing session.
        _sessionToken &+= 1
#if canImport(GameController)
        _unhookCurrentController()
        _removeControllerObservers()
#endif
#if canImport(CoreMotion)
        _stopIMU()
#endif
    }

    // MARK: - GCController motion

#if canImport(GameController)

    private func _observeControllerNotifications() {
        let nc = NotificationCenter.default
        controllerConnectObserver = nc.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?._onControllerChanged()
            }
        }
        controllerDisconnectObserver = nc.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?._onControllerChanged()
            }
        }
    }

    private func _removeControllerObservers() {
        if let obs = controllerConnectObserver    { NotificationCenter.default.removeObserver(obs) }
        if let obs = controllerDisconnectObserver { NotificationCenter.default.removeObserver(obs) }
        controllerConnectObserver    = nil
        controllerDisconnectObserver = nil
    }

    private func _onControllerChanged() {
        _unhookCurrentController()
#if canImport(CoreMotion)
        _stopIMU()
#endif
        _hookCurrentController()
#if canImport(CoreMotion)
        if _shouldUseIMU() { _startIMU() }
#endif
    }

    private func _hookCurrentController() {
        guard inputSource != .deviceIMU else { return }
        guard let controller = GCController.controllers().first(where: { $0.motion != nil }),
              let motion = controller.motion else { return }

        hookedController = controller
        let token = _sessionToken
        motion.valueChangedHandler = { [weak self] motionData in
            let rx = motionData.rotationRate.x
            let ry = motionData.rotationRate.y
            Task { @MainActor [weak self] in
                guard let self, self._sessionToken == token else { return }
                self._applyRotation(rawX: rx, rawY: ry)
            }
        }
        ILOG("GyroMouseAdapter: hooked GCController motion (\(controller.vendorName ?? "unknown"))")
    }

    private func _unhookCurrentController() {
        hookedController?.motion?.valueChangedHandler = nil
        hookedController = nil
    }

#endif // canImport(GameController)

    // MARK: - CoreMotion IMU fallback

#if canImport(CoreMotion)

    /// Returns `true` when the device IMU should be active.
    private func _shouldUseIMU() -> Bool {
        guard inputSource != .controller else { return false }
        if inputSource == .deviceIMU { return true }
        // .auto: use IMU only when no controller with motion support is available
#if canImport(GameController)
        if GCController.controllers().contains(where: { $0.motion != nil }) { return false }
#endif
        return true
    }

    private func _startIMU() {
        guard !imuActive else { return }
        let manager = CMMotionManager()
        guard manager.isDeviceMotionAvailable else {
            ILOG("GyroMouseAdapter: device motion unavailable — no IMU fallback")
            return
        }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        // `to: .main` already delivers this closure on the main queue, so
        // use `MainActor.assumeIsolated` to call the @MainActor-isolated method
        // without spawning a new Task (avoids per-sample Task overhead at 60 Hz).
        let token = _sessionToken
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motionData, error in
            guard error == nil, let m = motionData else { return }
            let rx = m.rotationRate.x
            let ry = m.rotationRate.y
            MainActor.assumeIsolated { [weak self] in
                guard let self, self._sessionToken == token else { return }
                self._applyRotation(rawX: rx, rawY: ry)
            }
        }
        motionManager = manager
        imuActive     = true
        ILOG("GyroMouseAdapter: IMU started at 60 Hz")
    }

    private func _stopIMU() {
        motionManager?.stopDeviceMotionUpdates()
        motionManager = nil
        imuActive     = false
    }

#endif // canImport(CoreMotion)

    // MARK: - Signal processing

    /// Applies dead zone, low-pass filter, sensitivity, and accumulates into the cursor.
    ///
    /// - Parameters:
    ///   - rawX: Raw rotation rate around X axis (pitch, rad/s) — maps to vertical cursor movement.
    ///   - rawY: Raw rotation rate around Y axis (yaw,   rad/s) — maps to horizontal cursor movement.
    ///
    /// Coordinate mapping matches the physical expectation:
    ///   - Tilting the device/controller forward (negative pitch) moves the cursor UP.
    ///   - Rotating the device/controller right (positive yaw)    moves the cursor RIGHT.
    private func _applyRotation(rawX: Double, rawY: Double) {
        guard isEnabled, let responder, responder.gameSupportsMouse else { return }

        // Dead zone
        let dz    = deadZone
        let inX   = abs(rawX) > dz ? rawX : 0.0
        let inY   = abs(rawY) > dz ? rawY : 0.0

        // Exponential moving average (low-pass)
        let alpha = max(0.01, min(1.0, smoothingAlpha))
        filteredX = alpha * inX + (1.0 - alpha) * filteredX
        filteredY = alpha * inY + (1.0 - alpha) * filteredY

        // Compute actual dt from elapsed time; treat a fresh start or a long gap
        // (> 250 ms) as a nominal frame to avoid cursor jumps.
        let now = Date.timeIntervalSinceReferenceDate
        let dt: Double
        if lastCallbackTime == 0 {
            // First call after attach or re-enable: use nominal frame duration.
            dt = 1.0 / 60.0
        } else {
            let rawDt = now - lastCallbackTime
            if rawDt > 0.25 {
                // Long gap (e.g. motion callback stalled while isEnabled was true):
                // treat like a fresh start so the cursor doesn't jump.
                dt = 1.0 / 60.0
            } else {
                dt = min(max(rawDt, 1.0 / 240.0), 1.0 / 15.0)
            }
        }
        lastCallbackTime = now

        let scale = sensitivity * dt

        // Accumulate cursor (pitch = vertical, yaw = horizontal)
        cursorX = max(0.0, min(1.0, cursorX + filteredY * scale))
        cursorY = max(0.0, min(1.0, cursorY - filteredX * scale))

        _deliverPosition()
    }

    private func _deliverPosition() {
        let point = CGPoint(x: cursorX, y: cursorY)
        responder?.mouseMoved(atPoint: point)
        // Keep the cursor overlay (`MouseCursorOverlayView`) in sync.
        // Matches the notification posted by `GCMouseMouseResponderDriver`.
        NotificationCenter.default.post(
            name: .PVMousePositionDidChange,
            object: nil,
            userInfo: [PVMousePositionKey: NSValue(cgPoint: point)]
        )
    }

    // MARK: - Testing support

    /// Feeds a synthetic rotation sample through the full signal chain.
    /// Intended for `@testable` unit tests only — do not call from production code.
    internal func _testApplyRotation(rawX: Double, rawY: Double) {
        _applyRotation(rawX: rawX, rawY: rawY)
    }
}
