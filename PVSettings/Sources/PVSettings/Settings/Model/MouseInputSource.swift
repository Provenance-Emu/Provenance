//
//  MouseInputSource.swift
//  PVSettings
//
//  Created by Provenance Emu on 2026-03-22.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import Defaults

/// Selects which physical input device drives mouse/pointer events
/// forwarded to the emulated mouse peripheral.
///
/// The `.auto` case lets the engine pick an appropriate available source
/// at runtime based on connected devices and platform capabilities.
/// The exact selection strategy may evolve over time.
public enum MouseInputSource: String, Codable, Equatable, Hashable,
    UserDefaultsRepresentable, Defaults.Serializable, CaseIterable, Sendable {

    /// Automatically select the best available input source.
    case auto = "auto"

    /// Use the on-screen virtual touch trackpad.
    case touchscreen = "touchscreen"

    /// Use the DualSense / DualShock 4 capacitive touchpad as a trackpad.
    case controllerTouchpad = "controllerTouchpad"

    /// Use gyroscope / accelerometer motion as mouse look.
    case gyro = "gyro"

    /// Use a connected USB or Bluetooth HID mouse (`GCMouse`).
    case physicalMouse = "physicalMouse"

    // MARK: Display

    public var displayName: String {
        switch self {
        case .auto:              return "Auto"
        case .touchscreen:       return "Touchscreen"
        case .controllerTouchpad: return "Controller Touchpad"
        case .gyro:              return "Gyroscope"
        case .physicalMouse:     return "Physical Mouse"
        }
    }

    public var subtitle: String {
        switch self {
        case .auto:
            return "Automatically choose the best available input"
        case .touchscreen:
            return "Use the on-screen virtual trackpad"
        case .controllerTouchpad:
            return "Use DualSense / DS4 capacitive touchpad"
        case .gyro:
            return "Tilt the device to move the cursor"
        case .physicalMouse:
            return "Use a USB or Bluetooth mouse"
        }
    }

    public var symbolName: String {
        switch self {
        case .auto:              return "wand.and.stars"
        case .touchscreen:       return "hand.tap"
        case .controllerTouchpad: return "gamecontroller"
        case .gyro:              return "gyroscope"
        case .physicalMouse:     return "computermouse"
        }
    }
}
