//
//  MednafenGameCore+PortDevices.swift
//  MednafenGameCore
//
//  Adds PortDeviceConfigurable conformance to Mednafen so the iOS pause-menu
//  "Port Devices" tile appears for systems that have multiple input device
//  options (SNES Mouse / SuperScope, NES Zapper, PSX DualShock / Mouse / GunCon,
//  Saturn 3D Pad / Mouse / Stunner, PCE Mouse).
//
//  `setDeviceType` persists the user's choice to a per-(md5, coreId, port)
//  UserDefaults key. The native side is wired through
//  MednafenGameCoreBridge+UserPortDevice.mm — at game load the bridge reads
//  the stored value and translates it into the Mednafen device-name string
//  passed to `game->SetInput(port, ...)`. Mid-game changes require a restart
//  because Mednafen latches input devices during MDFNI_LoadGame.
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
        ILOG("[Mednafen.PortDevices] setDeviceType=\(deviceType) port=\(port) — persisted. Reload the game to apply (Mednafen latches input devices at MDFNI_LoadGame).")
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
