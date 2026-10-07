//
//  PVThinLibretroCore+LayoutVariant.swift
//  PVCoreBridgeRetro
//
//  Controller layout variants (Genesis 3-/6-button, PlayStation digital/DualShock) on the
//  thin wrapper. Both are libretro port devices the core declares through
//  RETRO_ENVIRONMENT_SET_CONTROLLER_INFO, so a variant is applied and read back through the
//  `PortDeviceConfigurable` path the Port Devices picker already uses.
//
//  Device names come from the cores' controller info, matched loosely so any core that
//  serves the system works:
//   • Genesis Plus GX — "MD Joypad 3 Button" / "MD Joypad 6 Button" (the "+ 4-WayPlay" and
//     "+ Teamplayer" multitap entries are skipped).
//   • PCSX-ReARMed — "standard" (RETRO_DEVICE_JOYPAD) / "analog" / "dualshock". Its pad type
//     is not a core option: `libretro_core_options.h` has no `pcsx_rearmed_pad*type` key.
//   • Beetle PSX — "PlayStation Controller" (RETRO_DEVICE_JOYPAD) / "DualShock" / "DualAnalog".
//

import Foundation
import PVCoreBridge
import PVLogging
import PVSystems

extension PVThinLibretroCore: ConsoleVariantConfigurable {

    public func applyControllerLayoutVariant(_ variantID: String) {
        guard let descriptors = controllerPortDescriptors.first,
              let device = Self.portDevice(for: variantID, in: descriptors) else {
            WLOG("ThinCore: no port device for controller layout variant \(variantID)")
            return
        }
        setDeviceType(device.deviceType, forPort: 0)
        ILOG("ThinCore: controller layout variant \(variantID) -> port 0 device '\(device.name)'")
        NotificationCenter.default.post(
            name: .controllerLayoutVariantDidChange, object: self,
            userInfo: [ControllerLayoutVariantNotificationKey.variantID: variantID])
    }

    /// Only a port-0 device the player chose (saved for this core and game) counts: every
    /// port starts as the plain joypad, which on PlayStation would otherwise read back as the
    /// digital pad and outrank the settings for every untouched game.
    public var currentControllerLayoutVariantID: String? {
        guard let system = SystemIdentifier(rawValue: systemIdentifier ?? ""),
              let descriptors = controllerPortDescriptors.first else { return nil }
        let hasStoredDevice = UserDefaults.standard.object(forKey: portDevicePersistenceKey(port: 0)) != nil
        return Self.variantID(currentDevice: currentDeviceType(forPort: 0), hasStoredDevice: hasStoredDevice,
                              in: descriptors, system: system)
    }

    // MARK: Device matching

    private static let joypadDevice = LibretroDeviceType.joypad.rawValue

    /// The port-0 device that realises `variantID`, or `nil` when the core offers none.
    static func portDevice(for variantID: String, in descriptors: [PortDeviceDescriptor]) -> PortDeviceDescriptor? {
        switch variantID {
        case ControllerLayoutVariant.genesis3Button.id:
            return descriptors.first { genesisButtonCount(of: $0) == .three }
        case ControllerLayoutVariant.genesis6Button.id:
            return descriptors.first { genesisButtonCount(of: $0) == .six }
        case ControllerLayoutVariant.psxDigital.id:
            return descriptors.first { $0.deviceType == joypadDevice }
        case ControllerLayoutVariant.psxDualShock.id:
            return descriptors.first { $0.name.localizedCaseInsensitiveContains("dualshock") }
        default:
            return nil
        }
    }

    /// The variant port 0 reports: `nil` unless the device was chosen and stands for one.
    static func variantID(currentDevice: UInt, hasStoredDevice: Bool, in descriptors: [PortDeviceDescriptor],
                          system: SystemIdentifier) -> String? {
        guard hasStoredDevice, let device = descriptors.first(where: { $0.deviceType == currentDevice }) else {
            return nil
        }
        return variantID(for: device, system: system)
    }

    /// The variant a port device stands for on `system`, or `nil` when it is none of them
    /// (e.g. Genesis "Joypad Auto", a light gun or a mouse).
    static func variantID(for device: PortDeviceDescriptor, system: SystemIdentifier) -> String? {
        switch system {
        case .Genesis, .Sega32X, .SegaCD:
            switch genesisButtonCount(of: device) {
            case .three: return ControllerLayoutVariant.genesis3Button.id
            case .six: return ControllerLayoutVariant.genesis6Button.id
            case nil: return nil
            }
        case .PSX:
            if device.name.localizedCaseInsensitiveContains("dualshock")
                || device.name.localizedCaseInsensitiveContains("analog") {
                return ControllerLayoutVariant.psxDualShock.id
            }
            return device.deviceType == joypadDevice ? ControllerLayoutVariant.psxDigital.id : nil
        default:
            return nil
        }
    }

    private enum GenesisPad { case three, six }

    /// A single Genesis pad of 3 or 6 buttons; multitap entries ("… + Teamplayer") are not one.
    private static func genesisButtonCount(of device: PortDeviceDescriptor) -> GenesisPad? {
        let name = device.name.lowercased()
        guard !name.contains("+") else { return nil }
        if name.contains("6 button") { return .six }
        if name.contains("3 button") { return .three }
        return nil
    }
}
