//
//  OverlayInputSinkAdapter.swift
//  PVUIBase
//
//  Phase 1 bridge between the programmatic touch overlay and the emulator core.
//

import Foundation
import CoreGraphics
import PVTouchOverlay

/// The overlay speaks skin tokens, and `DeltaSkinInputHandler` already dispatches skin
/// tokens to every system's responder protocol, so this adapter only forwards.
/// `@preconcurrency`: the overlay calls the sink from its main-thread touch handlers.
@MainActor
public final class OverlayInputSinkAdapter: @preconcurrency OverlayInputSink {
    private let handler: DeltaSkinInputHandler

    public init(handler: DeltaSkinInputHandler) {
        self.handler = handler
    }

    public func overlayPress(_ id: OverlayInputID) {
        handler.buttonPressed(id.token)
    }

    public func overlayRelease(_ id: OverlayInputID) {
        handler.buttonReleased(id.token)
    }

    public func overlayStick(_ side: OverlayStickSide, x horizontal: Float, y vertical: Float) {
        handler.analogStickMoved(side.token, x: horizontal, y: vertical)
    }

    /// The skin path has no analog trigger input, so a trigger is a digital button.
    public func overlayAnalogTrigger(_ id: OverlayInputID, value: Float) {
        if value > 0 {
            handler.buttonPressed(id.token)
        } else {
            handler.buttonReleased(id.token)
        }
    }

    public func overlaySurface(_ role: OverlaySurfaceRole, normalized: CGPoint, phase: OverlaySurfacePhase) {
        switch (role, phase) {
        case (.dsScreen, .began), (.dsScreen, .moved):
            handler.ndsBottomScreenTouched(at: normalized)
        case (.dsScreen, .ended):
            handler.ndsBottomScreenTouchReleased()
        case (.wiiPointer, _), (.lightGun, _), (.trackpad, _):
            break // Not in the Phase 1 bindings; the existing pointer overlays handle these.
        }
    }

    public func overlayAction(_ action: OverlayAction) {
        guard let token = Self.handlerToken(for: action) else { return }
        handler.buttonPressed(token)
        // The handler opens the pause menu on the press; it has no release to send.
        if action != .menu {
            handler.buttonReleased(token)
        }
    }

    public func overlayHardwareSwitch(descriptorID: String, isOn: Bool) {
        // Phase 2: no Phase 1 binding has console switches.
    }

    /// Function tokens `DeltaSkinInputHandler.buttonPressed(_:)` recognises. The handler has
    /// no keyboard or mouse toggle, and an unknown token would fall through to the gameplay
    /// path (where a system's button enum maps it to a real button), so those are dropped.
    private static func handlerToken(for action: OverlayAction) -> String? {
        switch action {
        case .menu: return "menu"
        case .quickSave: return "quicksave"
        case .quickLoad: return "quickload"
        case .fastForward: return "togglefastforward"
        case .screenshot: return "screenshot"
        case .toggleKeyboard, .toggleMouse: return nil
        }
    }
}
