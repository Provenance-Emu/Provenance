//
//  MednafenGameCore+PortDevices.swift
//  MednafenGameCore
//
//  Adds PortDeviceConfigurable conformance to Mednafen so the iOS pause-menu
//  "Port Devices" tile appears for systems that have multiple input device
//  options (SNES Mouse / SuperScope, NES Zapper, PSX DualShock / Mouse,
//  Saturn 3D Pad / Mouse / Stunner, etc.).
//
//  IMPORTANT: This is a scaffold. `setDeviceType` persists the user's choice
//  to UserDefaults but does NOT yet round-trip into Mednafen's native input
//  config (MDFNI_SetInput). That hookup needs C++ bridge work and a game
//  restart to apply. Logging a warning until the bridge call is wired.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVPrimitives

extension MednafenGameCore: PortDeviceConfigurable {

    // MARK: - Public API

    public var controllerPortDescriptors: [[PortDeviceDescriptor]] {
        guard let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "") else {
            return []
        }
        return Self.portDescriptors(for: sysID)
    }

    public func currentDeviceType(forPort port: Int) -> UInt {
        let stored = UserDefaults.standard.integer(forKey: Self.persistenceKey(forPort: port, core: self))
        if stored > 0 { return UInt(stored) }
        // Default to JOYPAD when nothing has been chosen.
        return LibretroDeviceType.joypad.rawValue
    }

    public func setDeviceType(_ deviceType: UInt, forPort port: Int) {
        UserDefaults.standard.set(Int(deviceType), forKey: Self.persistenceKey(forPort: port, core: self))
        WLOG("[Mednafen.PortDevices] setDeviceType=\(deviceType) port=\(port) — persisted to UserDefaults; native MDFNI_SetInput hookup pending. Restart the game to apply.")
    }

    // MARK: - Per-system topology

    /// Returns the device-type descriptors Mednafen exposes for each system.
    /// Only systems with a meaningful choice (more than just gamepad) are listed;
    /// others return an empty array so the pause-menu tile stays hidden.
    static func portDescriptors(for system: SystemIdentifier) -> [[PortDeviceDescriptor]] {
        switch system {

        case .SNES:
            // Port 2 is where Mouse / Super Scope / Justifier plug in.
            return [
                [PortDeviceDescriptor(name: "Gamepad", deviceType: LibretroDeviceType.joypad.rawValue)],
                [
                    PortDeviceDescriptor(name: "Gamepad", deviceType: LibretroDeviceType.joypad.rawValue),
                    PortDeviceDescriptor(name: "SNES Mouse", deviceType: LibretroDeviceType.mouse.rawValue),
                    PortDeviceDescriptor(name: "Super Scope", deviceType: LibretroDeviceType.lightgun.rawValue)
                ]
            ]

        case .NES:
            // Port 2 hosts the Zapper for light-gun games.
            return [
                [PortDeviceDescriptor(name: "Gamepad", deviceType: LibretroDeviceType.joypad.rawValue)],
                [
                    PortDeviceDescriptor(name: "Gamepad", deviceType: LibretroDeviceType.joypad.rawValue),
                    PortDeviceDescriptor(name: "Zapper", deviceType: LibretroDeviceType.lightgun.rawValue)
                ]
            ]

        case .PSX:
            // PSX supports DualShock + analog devices + mouse + guncon on both ports.
            let both: [PortDeviceDescriptor] = [
                PortDeviceDescriptor(name: "Gamepad", deviceType: LibretroDeviceType.joypad.rawValue),
                PortDeviceDescriptor(name: "DualShock", deviceType: LibretroDeviceType.analog.rawValue),
                PortDeviceDescriptor(name: "Mouse", deviceType: LibretroDeviceType.mouse.rawValue),
                PortDeviceDescriptor(name: "GunCon", deviceType: LibretroDeviceType.lightgun.rawValue)
            ]
            return [both, both]

        case .Saturn:
            // Saturn pad / 3D Control Pad / Mouse / Stunner. Both ports.
            let both: [PortDeviceDescriptor] = [
                PortDeviceDescriptor(name: "Gamepad", deviceType: LibretroDeviceType.joypad.rawValue),
                PortDeviceDescriptor(name: "3D Control Pad", deviceType: LibretroDeviceType.analog.rawValue),
                PortDeviceDescriptor(name: "Mouse", deviceType: LibretroDeviceType.mouse.rawValue),
                PortDeviceDescriptor(name: "Stunner", deviceType: LibretroDeviceType.lightgun.rawValue)
            ]
            return [both, both]

        case .PCE, .PCECD:
            // PC Engine accepts a mouse on port 1 in addition to the regular pad.
            return [
                [
                    PortDeviceDescriptor(name: "Gamepad", deviceType: LibretroDeviceType.joypad.rawValue),
                    PortDeviceDescriptor(name: "Mouse", deviceType: LibretroDeviceType.mouse.rawValue)
                ]
            ]

        default:
            // VB, WonderSwan, NeoGeo Pocket, Lynx etc. only have one input type
            // so there's nothing meaningful to pick — hide the tile.
            return []
        }
    }

    // MARK: - Persistence key

    /// Matches the libretro core's per-game key convention so PortDevicePickerView
    /// (which reads via currentDeviceType) sees the same value path on both backends.
    private static func persistenceKey(forPort port: Int, core: MednafenGameCore) -> String {
        let md5 = core.romMD5 ?? "_"
        let coreId = core.coreIdentifier ?? "Mednafen"
        return "MednafenGameCore.\(md5).\(coreId).portDeviceType.port\(port)"
    }
}
