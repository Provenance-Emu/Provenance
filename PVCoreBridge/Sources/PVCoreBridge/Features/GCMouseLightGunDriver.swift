//
//  GCMouseLightGunDriver.swift
//  PVCoreBridge
//
//  Created by Claude (Agent) on 2026-03-18.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Bridges GCMouse (USB/Bluetooth HID mice, iPadOS pointer) to the
//  LightGunResponder protocol.
//
//  How it works:
//  - On iOS/iPadOS 14+ a physical mouse enumerates as a GCMouse.
//  - GCMouse provides only *relative* deltas (no absolute position).
//  - This driver accumulates deltas into an absolute cursor position
//    clamped to [0, 1] in both axes, then forwards the normalised point
//    to the core's LightGunResponder.
//  - On iPadOS with UIPointerInteraction the absolute position is used
//    directly (more accurate; see EmulatorTouchMouseHandler in the
//    RetroArch wrapper for the UIPointerInteraction path).
//
//  Usage:
//    let driver = GCMouseLightGunDriver()
//    driver.sensitivity = 1.0
//    driver.attach(to: myCore)   // core must conform to LightGunResponder
//    // …later…
//    driver.detach()
//

import Foundation
import PVLogging

#if canImport(GameController)
import GameController
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Drives a ``LightGunResponder`` from `GCMouse` delta events and/or an
/// iPadOS `UIPointerInteraction` absolute position.
///
/// All currently-connected `GCMouse` devices are observed on attach, and
/// newly-connected mice are picked up automatically via `GCMouseDidConnect`.
///
/// Instantiate once and call ``attach(to:)`` when a core starts,
/// ``detach()`` when it stops.
@objc public final class GCMouseLightGunDriver: NSObject {

    // MARK: - Configuration

    /// Cursor sensitivity multiplier for delta-based input (default 1.0).
    /// Higher values make the crosshair move faster per mouse count.
    @objc public var sensitivity: CGFloat = 1.0

    /// When `true` the driver delivers events to the attached core.
    /// Set to `false` to temporarily suspend without detaching.
    @objc public var isEnabled: Bool = true

    // MARK: - State

    private weak var responder: (AnyObject & LightGunResponder)?

    /// Accumulated normalised cursor position in [0, 1] × [0, 1].
    private var cursorX: CGFloat = 0.5
    private var cursorY: CGFloat = 0.5

    private var triggerDown = false
    private var reloadDown = false
    private var auxADown = false

    // MARK: - Observation tokens

#if canImport(GameController)
    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
#endif

    // MARK: - Lifecycle

    public override init() {
        super.init()
    }

    deinit {
        detach()
    }

    /// Start delivering mouse input to `core`.
    @objc public func attach(to core: AnyObject & LightGunResponder) {
        detach()
        responder = core
        cursorX = 0.5
        cursorY = 0.5
        triggerDown = false
        reloadDown = false
        auxADown = false
        _registerMouseObservers()
        _hookConnectedMice()
    }

    /// Stop delivering input and release the core reference.
    /// Sends synthetic release events for trigger, reload, and auxA if currently held,
    /// so the core is not left in a permanently pressed state.
    @objc public func detach() {
        _unhookConnectedMice()
        _unregisterMouseObservers()
        // Release held buttons before dropping the responder reference
        if triggerDown {
            triggerDown = false
            responder?.lightGunTriggerUp()
        }
        if reloadDown {
            reloadDown = false
            responder?.lightGunReloadUp?()
        }
        if auxADown {
            auxADown = false
            responder?.lightGunAuxAUp?()
        }
        responder = nil
    }

    // MARK: - Absolute position (from UIPointerInteraction or touch)

    /// Called by the UI layer when an absolute screen position is known
    /// (e.g. iPadOS pointer, Apple Pencil). Coordinates are in screen points;
    /// `viewSize` is the emulator view's bounds.
    @objc public func absolutePositionChanged(to point: CGPoint,
                                              in viewSize: CGSize,
                                              isOffscreen: Bool) {
        guard isEnabled, viewSize.width > 0, viewSize.height > 0 else { return }
        cursorX = max(0, min(1, point.x / viewSize.width))
        cursorY = max(0, min(1, point.y / viewSize.height))
        _deliverPosition(isOffscreen: isOffscreen)
    }

    // MARK: - GCMouse observation

    private func _registerMouseObservers() {
#if canImport(GameController)
        let nc = NotificationCenter.default
        connectObserver = nc.addObserver(
            forName: .GCMouseDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let mouse = note.object as? GCMouse else { return }
            self?._hookMouse(mouse)
            ILOG("GCMouseLightGunDriver: mouse connected — \(mouse.description)")
        }
        disconnectObserver = nc.addObserver(
            forName: .GCMouseDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let mouse = note.object as? GCMouse else { return }
            self?._unhookMouse(mouse)
            ILOG("GCMouseLightGunDriver: mouse disconnected — \(mouse.description)")
        }
#endif
    }

    private func _unregisterMouseObservers() {
#if canImport(GameController)
        if let obs = connectObserver    { NotificationCenter.default.removeObserver(obs) }
        if let obs = disconnectObserver { NotificationCenter.default.removeObserver(obs) }
        connectObserver    = nil
        disconnectObserver = nil
#endif
    }

    private func _hookConnectedMice() {
#if canImport(GameController)
        for mouse in GCMouse.mice() {
            _hookMouse(mouse)
        }
#endif
    }

    private func _unhookConnectedMice() {
#if canImport(GameController)
        for mouse in GCMouse.mice() {
            _unhookMouse(mouse)
        }
#endif
    }

    private func _hookMouse(_ mouse: GCMouse) {
#if canImport(GameController)
        guard #available(iOS 14.0, tvOS 14.0, *) else { return }
        let input = mouse.mouseInput

        // Delta movement handler — GCMouse may invoke this off the main thread;
        // capture deltas before the hop to avoid any data races.
        input?.mouseMovedHandler = { [weak self] _, deltaX, deltaY in
            let dx = CGFloat(deltaX)
            let dy = CGFloat(deltaY)
            Task { @MainActor [weak self] in
                self?._applyDelta(dx: dx, dy: dy)
            }
        }

        // Left button → trigger
        input?.leftButton.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor [weak self] in
                guard let self, self.isEnabled else { return }
                self.triggerDown = pressed
                if pressed {
                    self.responder?.lightGunTriggerDown()
                } else {
                    self.responder?.lightGunTriggerUp()
                }
            }
        }

        // Right button → reload (off-screen)
        input?.rightButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor [weak self] in
                guard let self, self.isEnabled else { return }
                if pressed {
                    self.reloadDown = true
                    self.responder?.lightGunReloadDown?()
                } else {
                    self.reloadDown = false
                    self.responder?.lightGunReloadUp?()
                }
            }
        }

        // Middle button → aux A
        input?.middleButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor [weak self] in
                guard let self, self.isEnabled else { return }
                self.auxADown = pressed
                if pressed {
                    self.responder?.lightGunAuxADown?()
                } else {
                    self.responder?.lightGunAuxAUp?()
                }
            }
        }
#endif
    }

    private func _unhookMouse(_ mouse: GCMouse) {
#if canImport(GameController)
        guard #available(iOS 14.0, tvOS 14.0, *) else { return }
        let input = mouse.mouseInput
        input?.mouseMovedHandler = nil
        input?.leftButton.pressedChangedHandler = nil
        input?.rightButton?.pressedChangedHandler = nil
        input?.middleButton?.pressedChangedHandler = nil
#endif
    }

    // MARK: - Delta accumulation

    private func _applyDelta(dx: CGFloat, dy: CGFloat) {
        guard isEnabled else { return }
        // Scale delta by sensitivity / screen dimension to get normalised movement.
        // A raw HID mouse typically reports ~400–800 counts/inch; we normalise
        // against a virtual 800-count-wide "screen" so sensitivity=1 feels natural.
        let scale: CGFloat = sensitivity / 800.0
        cursorX = max(0, min(1, cursorX + dx * scale))
        cursorY = max(0, min(1, cursorY + dy * scale))
        _deliverPosition(isOffscreen: false)
    }

    private func _deliverPosition(isOffscreen: Bool) {
        let point = CGPoint(x: cursorX, y: cursorY)
        responder?.lightGunMovedToPoint(point, isOffscreen: isOffscreen || reloadDown)
    }
}
