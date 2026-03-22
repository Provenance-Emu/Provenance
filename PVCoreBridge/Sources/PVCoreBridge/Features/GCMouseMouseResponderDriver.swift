//
//  GCMouseMouseResponderDriver.swift
//  PVCoreBridge
//
//  Created by Claude (Agent) on 2026-03-22.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Bridges GCMouse (USB/Bluetooth HID mice, iPadOS pointer) to the
//  MouseResponder protocol used by emulator cores.
//
//  How it works:
//  - On iOS/iPadOS 14+ a physical mouse enumerates as a GCMouse.
//  - GCMouse provides only *relative* deltas (no absolute position).
//  - This driver accumulates deltas into an absolute cursor position
//    clamped to [0, 1] in both axes, then forwards the normalised point
//    to the core's MouseResponder methods.
//  - Left button  → leftMouseDown / leftMouseUp
//  - Right button → rightMouseDown / rightMouseUp
//  - Middle button → middleMouseDown / middleMouseUp
//
//  Usage:
//    let driver = GCMouseMouseResponderDriver()
//    driver.sensitivity = 1.0
//    driver.attach(to: myCore)   // core must conform to MouseResponder
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

/// Drives a ``MouseResponder`` from `GCMouse` delta events.
///
/// All currently-connected `GCMouse` devices are observed on attach, and
/// newly-connected mice are picked up automatically via `GCMouseDidConnect`.
///
/// Instantiate once and call ``attach(to:)`` when a core starts,
/// ``detach()`` when it stops.
@objc public final class GCMouseMouseResponderDriver: NSObject, @unchecked Sendable {

    // MARK: - Configuration

    /// Cursor sensitivity multiplier for delta-based input (default 1.0).
    /// Higher values move the virtual cursor faster per mouse count.
    @objc public var sensitivity: CGFloat = 1.0

    /// When `true` the driver delivers events to the attached core.
    /// Set to `false` to temporarily suspend without detaching.
    @objc public var isEnabled: Bool = true

    // MARK: - State

    private weak var responder: (AnyObject & MouseResponder)?

    /// Accumulated normalised cursor position in [0, 1] × [0, 1].
    private var cursorX: CGFloat = 0.5
    private var cursorY: CGFloat = 0.5

    private var leftDown = false
    private var rightDown = false
    private var middleDown = false

    // MARK: - Observation tokens

#if canImport(GameController)
    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
#endif

    // MARK: - Session tracking

    /// Monotonic counter incremented on every ``attach(to:)`` call.
    /// Button handler `Task { @MainActor }` closures capture this value; if it
    /// has changed by the time they execute (detach / re-attach raced), the
    /// stale events are discarded rather than routing to the new responder.
    private var _session: Int = 0

    // MARK: - Lifecycle

    public override init() {
        super.init()
    }

    deinit {
        detach()
    }

    /// Start delivering mouse input to `core`.
    @objc public func attach(to core: AnyObject & MouseResponder) {
        detach()
        _session &+= 1
        responder = core
        cursorX = 0.5
        cursorY = 0.5
        leftDown = false
        rightDown = false
        middleDown = false
        _registerMouseObservers()
        _hookConnectedMice()
    }

    /// Stop delivering input and release the core reference.
    /// Sends synthetic release events for any held buttons so the core is not
    /// left in a permanently pressed state.
    @objc public func detach() {
        _unhookConnectedMice()
        _unregisterMouseObservers()
        // Release held buttons before dropping the responder reference
        if leftDown {
            leftDown = false
            responder?.leftMouseUp()
        }
        if rightDown {
            rightDown = false
            responder?.rightMouseUp()
        }
        if middleDown {
            middleDown = false
            responder?.middleMouseUp?()
        }
        responder = nil
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
            ILOG("GCMouseMouseResponderDriver: mouse connected — \(mouse.description)")
        }
        disconnectObserver = nc.addObserver(
            forName: .GCMouseDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let mouse = note.object as? GCMouse else { return }
            self?._unhookMouse(mouse)
            ILOG("GCMouseMouseResponderDriver: mouse disconnected — \(mouse.description)")
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

        // Delta movement handler — GCMouse may invoke this off the main thread.
        // Deltas are captured as value types (CGFloat) before the hop to avoid
        // shared mutable state being accessed off-actor. DispatchQueue.main.async
        // is used instead of Task { @MainActor } to minimise per-event overhead
        // at high mouse polling rates.
        input?.mouseMovedHandler = { [weak self] _, deltaX, deltaY in
            let dx = CGFloat(deltaX)
            let dy = CGFloat(deltaY)
            DispatchQueue.main.async { [weak self] in
                self?._applyDelta(dx: dx, dy: dy)
            }
        }

        // Left button → leftMouseDown / leftMouseUp
        // Capture the session at event time; discard if stale.
        input?.leftButton.pressedChangedHandler = { [weak self] _, _, pressed in
            let session = self?._session ?? -1
            Task { @MainActor [weak self] in
                guard let self, self._session == session, self.isEnabled else { return }
                self.leftDown = pressed
                let point = CGPoint(x: self.cursorX, y: self.cursorY)
                if pressed {
                    self.responder?.leftMouseDown(atPoint: point)
                } else {
                    self.responder?.leftMouseUp()
                }
            }
        }

        // Right button → rightMouseDown / rightMouseUp
        input?.rightButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            let session = self?._session ?? -1
            Task { @MainActor [weak self] in
                guard let self, self._session == session, self.isEnabled else { return }
                self.rightDown = pressed
                let point = CGPoint(x: self.cursorX, y: self.cursorY)
                if pressed {
                    self.responder?.rightMouseDown(atPoint: point)
                } else {
                    self.responder?.rightMouseUp()
                }
            }
        }

        // Middle button → middleMouseDown / middleMouseUp (optional protocol method)
        input?.middleButton?.pressedChangedHandler = { [weak self] _, _, pressed in
            let session = self?._session ?? -1
            Task { @MainActor [weak self] in
                guard let self, self._session == session, self.isEnabled else { return }
                self.middleDown = pressed
                let point = CGPoint(x: self.cursorX, y: self.cursorY)
                if pressed {
                    self.responder?.middleMouseDown?(atPoint: point)
                } else {
                    self.responder?.middleMouseUp?()
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
        // Scale delta by sensitivity / a virtual 800-count "screen" so that
        // sensitivity=1 feels natural for a typical 400–800 DPI HID mouse.
        let scale: CGFloat = sensitivity / 800.0
        cursorX = max(0, min(1, cursorX + dx * scale))
        cursorY = max(0, min(1, cursorY + dy * scale))
        _deliverPosition()
    }

    private func _deliverPosition() {
        let point = CGPoint(x: cursorX, y: cursorY)
        responder?.mouseMoved(atPoint: point)
    }
}
