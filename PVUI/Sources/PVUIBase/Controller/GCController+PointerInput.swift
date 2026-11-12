//
//  GCController+PointerInput.swift
//  PVUI
//
//  Reads a pad's touchpad by sampling, never through handlers.
//

import Foundation
import GameController
import PVCoreBridge
import PVSupport

public extension GCController {
    /// The hardware pad behind the wrappers the app puts in front of it
    /// (`PVRemappedController`, `PVPhysicalProfileController`), or this controller.
    var hardwareController: GCController {
        var controller = self
        while let inner = controller.wrappedController {
            controller = inner
        }
        return controller
    }

    private var wrappedController: GCController? {
        if let remapped = self as? PVRemappedController { return remapped.base }
        #if canImport(UIKit)
        if let profile = self as? PVPhysicalProfileController { return profile.base }
        #endif
        return nil
    }

    /// Whether the pad has a touchpad (DualSense, DualShock 4).
    var hasTouchpad: Bool {
        let gamepad = hardwareController.extendedGamepad
        return gamepad is GCDualSenseGamepad || gamepad is GCDualShockGamepad
    }

    /// The touchpad's fingers and click right now, or nil when the pad has no touchpad.
    var touchpadSample: TouchpadSample? {
        let gamepad = hardwareController.extendedGamepad
        if let dualSense = gamepad as? GCDualSenseGamepad {
            return TouchpadSample(
                primaryX: dualSense.touchpadPrimary.xAxis.value, primaryY: dualSense.touchpadPrimary.yAxis.value,
                secondaryX: dualSense.touchpadSecondary.xAxis.value, secondaryY: dualSense.touchpadSecondary.yAxis.value,
                isClicked: dualSense.touchpadButton.isPressed)
        }
        if let dualShock = gamepad as? GCDualShockGamepad {
            return TouchpadSample(
                primaryX: dualShock.touchpadPrimary.xAxis.value, primaryY: dualShock.touchpadPrimary.yAxis.value,
                secondaryX: dualShock.touchpadSecondary.xAxis.value, secondaryY: dualShock.touchpadSecondary.yAxis.value,
                isClicked: dualShock.touchpadButton.isPressed)
        }
        return nil
    }

    /// Whether the touchpad is pressed down. False for a pad without one.
    var isTouchpadClicked: Bool {
        touchpadSample?.isClicked ?? false
    }
}
