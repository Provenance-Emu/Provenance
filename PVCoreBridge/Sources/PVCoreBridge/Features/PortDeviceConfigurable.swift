//
//  PortDeviceConfigurable.swift
//  PVCoreBridge
//
//  Created by Claude (Agent) on 2026-03-17.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Protocol for cores that support per-port device type configuration
//  (e.g. JOYPAD → MOUSE for Mario Paint, JOYPAD → LIGHTGUN for Lethal Enforcers).
//

import Foundation

/// Describes a single device type that a libretro core reports it supports on a given port.
public struct PortDeviceDescriptor: Sendable, Equatable {
    /// Human-readable name reported by the core (e.g. "SNES Mouse", "Justifier").
    public let name: String
    /// libretro device type constant (RETRO_DEVICE_JOYPAD = 1, RETRO_DEVICE_MOUSE = 2, …).
    public let deviceType: UInt

    public init(name: String, deviceType: UInt) {
        self.name = name
        self.deviceType = deviceType
    }
}

/// Standard libretro device type constants mirrored in Swift for convenience.
public enum LibretroDeviceType: UInt {
    case none     = 0
    case joypad   = 1
    case mouse    = 2
    case keyboard = 3
    case lightgun = 4
    case analog   = 5
    case pointer  = 6

    public var localizedName: String {
        switch self {
        case .none:     return String(localized: "None")
        case .joypad:   return String(localized: "Gamepad")
        case .mouse:    return String(localized: "Mouse")
        case .keyboard: return String(localized: "Keyboard")
        case .lightgun: return String(localized: "Light Gun")
        case .analog:   return String(localized: "Analog")
        case .pointer:  return String(localized: "Pointer")
        }
    }

    /// Returns the SF Symbol name that best represents this device type in the UI.
    public var symbolName: String {
        switch self {
        case .none:     return "nosign"
        case .joypad:   return "gamecontroller"
        case .mouse:    return "computermouse"
        case .keyboard: return "keyboard"
        case .lightgun: return "scope"
        case .analog:   return "gamecontroller.fill"
        case .pointer:  return "hand.point.up"
        }
    }
}

/// Protocol implemented by cores that let users configure which device type is
/// connected to each controller port (mirrors RetroArch's Input → Port N Device Type).
public protocol PortDeviceConfigurable: AnyObject {
    /// Per-port list of device types that the core supports, reported via
    /// `RETRO_ENVIRONMENT_SET_CONTROLLER_INFO`. Index 0 = port 1, etc.
    /// Empty if the core does not report any controller info.
    var controllerPortDescriptors: [[PortDeviceDescriptor]] { get }

    /// Returns the currently-active device type for the given port (0-based).
    func currentDeviceType(forPort port: Int) -> UInt

    /// Change the device type for the given port and persist the selection.
    func setDeviceType(_ deviceType: UInt, forPort port: Int)
}
